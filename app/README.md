# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Stadia Maps

The bin map uses `flutter_map` with Stadia Maps' Alidade Smooth tiles. Paste
your Stadia Maps API key between the quotes for `kStadiaMapsApiKey` in
`lib/app_config.dart`. The key is embedded in the app and is not a secret; use
a client key with appropriate restrictions and usage limits. Without a key,
the map displays a setup prompt instead of requesting tiles, and address
search is unavailable. Bin search works without a key; submit an address query
to search it with Stadia's geocoding service.

The current bin coordinates are illustrative positions around Elmina Township
and are stored as Firestore GeoPoints in the `bins` collection. Replace them
with verified bin coordinates when available. Bin details request a pedestrian
road-route distance and estimated walking time from Stadia's routing API using
the device GPS location. Navigate draws the Stadia pedestrian route on the
in-app map but does not provide turn-by-turn instructions or live rerouting.

## Firebase

The app initializes Firebase for Android and iOS. Users can sign in with
email/password or Google. New users can create an email/password account from
the sign-in screen, choose a username, and confirm their password. If a Google
sign-in uses an email already registered with another provider, sign in with
that existing account first, then open **Settings → Account settings → Sign-in
methods → Link Google account**. Linked providers use the same Firebase user
and app data; separate Firebase accounts cannot be merged automatically.
Google sign-in must be enabled in Firebase Authentication and configured for
the target platform. Users can choose a profile picture from their device; it
is uploaded to the user's Cloud Storage folder and its download URL is saved to
Firebase Authentication so it is available across devices. Existing locally
saved profile pictures are uploaded on their next load. Bin Map reads the
`bins` collection in real time. Saved addresses are stored per user in
`users/{uid}/savedAddresses`; each includes the complete address and a
Firestore GeoPoint selected from a backend Stadia geocoding result or pinned
manually on the Stadia-powered map in Settings. The geocoding API key is stored
as the `STADIA_MAPS_API_KEY` Cloud Functions secret and is not sent by the app.
CO₂ savings are stored in `users/{uid}.co2SavedKg` and initialized
to `0` when the signed-in user first opens a screen that displays the total.
Clients can read only their own total and cannot edit it after initialization;
the app does not currently increment the total from marketplace or recycling
activity. Firestore rules allow authenticated users to read bins and deny
client-side bin writes.

### Nearby-bin notifications

On Android and iOS, the app requests notification and background-location
permissions after sign-in. Users can later manage both switches in Settings.
After sign-in, the app registers the device and stores its location in
`users/{uid}/notificationDevices/{deviceId}` while nearby bin alerts are
enabled. Location updates are sent after the device moves at least 100 m.
The Cloud Functions backend compares that location with bin coordinates and
sends an FCM notification when the nearest recycle bin or the nearest domestic
bin is full. Each bin type is evaluated independently, so a full bin can
trigger an alert for either or both types. Turning off push notifications or
signing out stops location updates and removes the saved location. On Android,
background location may need to be changed to “Allow all the time” in system
settings. On iOS, configure the APNs key in Firebase Console and enable Push
Notifications for the Runner target before testing.

Deploy the Firestore rules and the server-side notification triggers from this
directory after selecting the Firebase project:

```sh
firebase deploy --project tbd-hackathon-app --only firestore:rules,functions
```

Cloud Functions deployment requires a Firebase project with billing enabled.
`functions/` contains the Node.js 22 TypeScript source; `npm install` and
`npm run build` there validate the backend before deployment.
Before deploying address geocoding, set the Stadia API key as a Functions
secret once:

```sh
firebase functions:secrets:set STADIA_MAPS_API_KEY --project tbd-hackathon-app
```

Then deploy the Functions as shown above. Address lookup requires a signed-in
user and only returns geocoding results identified as Malaysia.

The email/password provider and Firestore rules are configured in
`firebase.json`, `firestore.rules`, and `firestore.indexes.json`. Enable the
Google provider in Firebase Authentication and configure platform OAuth
credentials (including Android SHA fingerprints) in the Firebase Console.
Cloud Storage access is restricted by `storage.rules` to each signed-in user's
own `profilePictures/{uid}` folder; profile image uploads are limited to 5 MB
and image content types. Initialize Cloud Storage for the Firebase project in
the Firebase Console before deploying the rules. Use the same `asia-southeast1`
region as Firestore if a regional bucket is offered; a bucket's location cannot
be changed later. Deploy these rules with:

```sh
firebase deploy --project tbd-hackathon-app --only storage
```
