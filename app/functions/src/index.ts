import { getApp, initializeApp } from "firebase-admin/app";
import { getFirestore, GeoPoint } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const firestore = getFirestore(getApp());
const earthRadiusMeters = 6_371_000;
const binTypes = ["Recycle", "Domestic"] as const;
const stadiaMapsApiKey = defineSecret("STADIA_MAPS_API_KEY");

type BinType = (typeof binTypes)[number];

interface BinLocation {
  id: string;
  name: string;
  type: BinType;
  status: string;
  location: GeoPoint;
}

function distanceMeters(from: GeoPoint, to: GeoPoint): number {
  const radians = (degrees: number) => (degrees * Math.PI) / 180;
  const latitudeDelta = radians(to.latitude - from.latitude);
  const longitudeDelta = radians(to.longitude - from.longitude);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(from.latitude)) *
      Math.cos(radians(to.latitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isGeoPoint(value: unknown): value is GeoPoint {
  return value instanceof GeoPoint;
}

function sameLocation(first: unknown, second: unknown): boolean {
  return (
    isGeoPoint(first) &&
    isGeoPoint(second) &&
    first.latitude === second.latitude &&
    first.longitude === second.longitude
  );
}

function errorCode(error: unknown): string | undefined {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof error.code === "string"
  ) {
    return error.code;
  }
  return undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export const geocodeSavedAddress = onCall(
  { secrets: [stadiaMapsApiKey], region: "asia-southeast1" },
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to search for an address.",
      );
    }

    const data = request.data as { address?: unknown } | null;
    const address =
      typeof data?.address === "string" ? data.address.trim() : "";
    if (address.length < 3 || address.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "Enter an address between 3 and 500 characters.",
      );
    }

    const url = new URL("https://api.stadiamaps.com/geocoding/v1/search");
    url.searchParams.set("text", address);
    url.searchParams.set("api_key", stadiaMapsApiKey.value());
    url.searchParams.set("boundary.country", "MY");
    url.searchParams.set("limit", "5");

    let response: Response;
    try {
      response = await fetch(url, {
        signal: AbortSignal.timeout(10_000),
      });
    } catch (error) {
      logger.error("Stadia geocoding request failed", error);
      throw new HttpsError(
        "unavailable",
        "Address search is temporarily unavailable. Try again.",
      );
    }
    if (!response.ok) {
      logger.error("Stadia geocoding returned an error", {
        status: response.status,
      });
      throw new HttpsError(
        "unavailable",
        "Address search is temporarily unavailable. Try again.",
      );
    }

    let body: unknown;
    try {
      body = await response.json();
    } catch (error) {
      logger.error("Could not parse Stadia geocoding response", error);
      throw new HttpsError(
        "internal",
        "Address search returned an invalid response.",
      );
    }

    if (!isRecord(body) || !Array.isArray(body.features)) {
      throw new HttpsError(
        "internal",
        "Address search returned an invalid response.",
      );
    }

    const results = body.features.flatMap((feature: unknown) => {
      if (
        !isRecord(feature) ||
        !isRecord(feature.geometry) ||
        !Array.isArray(feature.geometry.coordinates) ||
        !isRecord(feature.properties)
      ) {
        return [];
      }

      const coordinates = feature.geometry.coordinates;
      const properties = feature.properties;
      if (
        coordinates.length < 2 ||
        typeof coordinates[0] !== "number" ||
        typeof coordinates[1] !== "number"
      ) {
        return [];
      }

      const countryCode = properties.country_a ?? properties.country_code;
      const countryName = properties.country;
      const isMalaysia =
        (typeof countryCode === "string" &&
          ["MY", "MYS"].includes(countryCode.toUpperCase())) ||
        (typeof countryName === "string" &&
          countryName.toLowerCase() === "malaysia");
      const longitude = coordinates[0];
      const latitude = coordinates[1];
      if (
        !isMalaysia ||
        longitude < -180 ||
        longitude > 180 ||
        latitude < -90 ||
        latitude > 90
      ) {
        return [];
      }

      const label = properties.label;
      const locality = properties.locality ?? properties.region;
      return [
        {
          label:
            typeof label === "string" && label.trim().length > 0
              ? label
              : "Address result",
          detail:
            typeof locality === "string" && locality.trim().length > 0
              ? locality
              : "Malaysia",
          latitude,
          longitude,
        },
      ];
    });

    return { results };
  },
);

function binsFromSnapshot(
  snapshot: FirebaseFirestore.QuerySnapshot,
): BinLocation[] {
  return snapshot.docs.flatMap((document) => {
    const data = document.data();
    if (
      typeof data.name !== "string" ||
      (data.type !== "Recycle" && data.type !== "Domestic") ||
      typeof data.status !== "string" ||
      !isGeoPoint(data.location)
    ) {
      logger.warn("Skipping bin with invalid notification fields", {
        binId: document.id,
      });
      return [];
    }
    return [
      {
        id: document.id,
        name: data.name,
        type: data.type,
        status: data.status,
        location: data.location,
      },
    ];
  });
}

async function notifyIfClosestBinOfEachTypeIsFull(
  deviceReference: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const deviceSnapshot = await deviceReference.get();
  if (!deviceSnapshot.exists) return;

  const device = deviceSnapshot.data();
  if (
    device?.enabled !== true ||
    typeof device.token !== "string" ||
    device.token.length === 0 ||
    !isGeoPoint(device.location)
  ) {
    return;
  }

  const binSnapshot = await firestore.collection("bins").get();
  const bins = binsFromSnapshot(binSnapshot);

  for (const type of binTypes) {
    const alertedBinField =
      type === "Recycle"
        ? "lastAlertedRecycleBinId"
        : "lastAlertedDomesticBinId";
    let nearest: BinLocation | undefined;
    let nearestDistance = Number.POSITIVE_INFINITY;
    for (const bin of bins) {
      if (bin.type !== type) continue;
      const distance = distanceMeters(device.location, bin.location);
      if (distance < nearestDistance) {
        nearest = bin;
        nearestDistance = distance;
      }
    }

    if (nearest?.status !== "full") {
      if (device[alertedBinField] != null) {
        await firestore.runTransaction(async (transaction) => {
          const currentSnapshot = await transaction.get(deviceReference);
          const current = currentSnapshot.data();
          if (
            current?.enabled === true &&
            current[alertedBinField] != null &&
            sameLocation(current.location, device.location)
          ) {
            transaction.update(deviceReference, { [alertedBinField]: null });
          }
        });
      }
      continue;
    }
    if (device[alertedBinField] === nearest.id) continue;

    const token = await firestore.runTransaction(async (transaction) => {
      const latestSnapshot = await transaction.get(deviceReference);
      const latestDevice = latestSnapshot.data();
      if (
        latestDevice?.enabled !== true ||
        latestDevice[alertedBinField] === nearest.id ||
        !sameLocation(latestDevice.location, device.location) ||
        typeof latestDevice.token !== "string" ||
        latestDevice.token.length === 0
      ) {
        return null;
      }
      transaction.update(deviceReference, { [alertedBinField]: nearest.id });
      return latestDevice.token;
    });
    if (token == null) continue;

    try {
      const messageId = await getMessaging().send({
        token,
        notification: {
          title: `Your nearest ${type.toLowerCase()} bin is full`,
          body: `${nearest.name} is full. Open VertivEra to find another bin.`,
        },
        data: { binId: nearest.id, binType: type },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      });
      logger.info("Sent closest-bin notification", {
        binId: nearest.id,
        binType: type,
        messageId,
      });
    } catch (error) {
      const code = errorCode(error);
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        await deviceReference.update({ enabled: false });
        logger.warn("Disabled a device with an invalid FCM token");
        return;
      }

      await deviceReference.update({ [alertedBinField]: null });
      logger.error("Could not send closest-bin notification", {
        binId: nearest.id,
        binType: type,
        error,
      });
      throw error;
    }
  }
}

export const onBinBecomingFull = onDocumentWritten(
  { document: "bins/{binId}", retry: true },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const becameFull = after?.status === "full" && before?.status !== "full";
    const stoppedBeingFull =
      before?.status === "full" && after?.status !== "full";
    if (!becameFull && !stoppedBeingFull) return;

    const devices = await firestore
      .collectionGroup("notificationDevices")
      .where("enabled", "==", true)
      .get();
    await Promise.all(
      devices.docs.map((device) =>
        notifyIfClosestBinOfEachTypeIsFull(device.ref),
      ),
    );
  },
);

export const onNotificationDeviceChanged = onDocumentWritten(
  { document: "users/{userId}/notificationDevices/{deviceId}", retry: true },
  async (event) => {
    const afterSnapshot = event.data?.after;
    const before = event.data?.before.data();
    const after = afterSnapshot?.data();
    if (after?.enabled !== true) return;

    const locationChanged =
      !isGeoPoint(before?.location) ||
      !isGeoPoint(after.location) ||
      before.location.latitude !== after.location.latitude ||
      before.location.longitude !== after.location.longitude;
    const settingsChanged =
      before?.enabled !== after.enabled ||
      before?.token !== after.token ||
      locationChanged;
    if (!settingsChanged) return;

    if (afterSnapshot != null) {
      await notifyIfClosestBinOfEachTypeIsFull(afterSnapshot.ref);
    }
  },
);
