import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BinNotificationSettings {
  final bool pushEnabled;
  final bool binAlertsEnabled;
  final String? warning;
  final bool hasSavedSettings;

  const BinNotificationSettings({
    required this.pushEnabled,
    required this.binAlertsEnabled,
    this.warning,
    required this.hasSavedSettings,
  });
}

class BinNotificationPermissionException implements Exception {
  final String message;

  const BinNotificationPermissionException(this.message);
}

class BinNotificationService {
  static const _deviceIdPreferenceKey = 'bin_notification_device_id';
  static const _startupPermissionsGrantedKey =
      'notification_startup_permissions_granted';
  static const _minimumLocationChangeMeters = 100.0;
  static const _locationPermissionChannel = MethodChannel(
    'com.example.app/background_location',
  );

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final Location _location;

  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _activeUserId;
  String? _deviceId;
  GeoPoint? _lastSavedLocation;

  BinNotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    Location? location,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _location = location ?? Location();

  Future<BinNotificationSettings> loadSettings(String userId) async {
    final deviceId = await _getDeviceId();
    final document = await _deviceDocument(userId, deviceId).get();
    final data = document.data();
    final pushEnabled = data?['pushEnabled'] == true;
    final binAlertsEnabled = data?['binAlertsEnabled'] == true;
    String? warning;

    if (pushEnabled) {
      try {
        await updateSettings(
          userId,
          pushEnabled: pushEnabled,
          binAlertsEnabled: binAlertsEnabled,
        );
      } on Exception catch (error) {
        debugPrint('Unable to restore bin notification settings: $error');
        warning = error is BinNotificationPermissionException
            ? error.message
            : 'Could not restart notification services.';
      }
    }

    return BinNotificationSettings(
      pushEnabled: pushEnabled,
      binAlertsEnabled: binAlertsEnabled,
      warning: warning,
      hasSavedSettings: document.exists,
    );
  }

  Future<String?> requestAtStartupIfNeeded(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_startupPermissionsGrantedKey) != true) {
      return 'Allow notification and background location access to enable '
          'nearby bin alerts. You can change permissions in Settings.';
    }

    try {
      await updateSettings(userId, pushEnabled: true, binAlertsEnabled: true);
      return null;
    } on Exception catch (error) {
      debugPrint('Unable to request startup notification permissions: $error');
      if (error is BinNotificationPermissionException) return error.message;
      return 'Could not enable nearby bin alerts. You can try again in Settings.';
    }
  }

  Future<String?> requestPermissionsAtStartup() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_startupPermissionsGrantedKey) == true) {
      return null;
    }
    try {
      final notificationPermission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (notificationPermission.authorizationStatus ==
          AuthorizationStatus.denied) {
        throw const BinNotificationPermissionException(
          'Allow notifications in your device settings to receive bin alerts.',
        );
      }

      var serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw const BinNotificationPermissionException(
          'Turn on location services to use nearby bin alerts.',
        );
      }

      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        throw const BinNotificationPermissionException(
          'Allow location access to use nearby bin alerts.',
        );
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final alwaysAllowed = await _locationPermissionChannel
            .invokeMethod<bool>('requestAlwaysLocationAuthorization')
            .timeout(const Duration(seconds: 60), onTimeout: () => false);
        if (alwaysAllowed != true) {
          throw const BinNotificationPermissionException(
            'Allow location access all the time in Settings to use nearby bin alerts.',
          );
        }
      }

      await _location.changeNotificationOptions(
        channelName: 'Nearby bin alerts',
        title: 'VertivEra nearby bin alerts',
        subtitle: 'Location is active',
        description: 'Finding your closest bin for full-bin alerts.',
      );
      if (!await _location.enableBackgroundMode()) {
        throw const BinNotificationPermissionException(
          'Allow location access all the time to use nearby bin alerts.',
        );
      }
      await _location.enableBackgroundMode(enable: false);
      await preferences.setBool(_startupPermissionsGrantedKey, true);
      return null;
    } on Exception catch (error) {
      debugPrint('Unable to request startup permissions: $error');
      await preferences.setBool(_startupPermissionsGrantedKey, false);
      if (error is BinNotificationPermissionException) return error.message;
      if (defaultTargetPlatform == TargetPlatform.android &&
          error is PlatformException) {
        return 'Android requires background location access for nearby bin '
            'alerts. In App info > Permissions > Location, choose '
            '"Allow all the time".';
      }
      return 'Could not set up notification permissions. You can try again '
          'in Settings.';
    }
  }

  Future<void> updateSettings(
    String userId, {
    required bool pushEnabled,
    required bool binAlertsEnabled,
  }) async {
    final deviceId = await _getDeviceId();
    final alertsEnabled = pushEnabled && binAlertsEnabled;
    String? token;
    GeoPoint? currentLocation;

    if (pushEnabled) {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        throw const BinNotificationPermissionException(
          'Allow notifications in your device settings to enable alerts.',
        );
      }
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // The backend sends with Firebase Admin Messaging, which requires the
      // FCM token rather than the Firebase Installation ID from register().
      // ignore: deprecated_member_use
      token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        throw const BinNotificationPermissionException(
          'Could not register this device for push notifications. Try again.',
        );
      }
    }

    try {
      if (alertsEnabled) {
        currentLocation = await _prepareLocationTracking();
      } else {
        await _stopLocationTracking();
      }

      final data = <String, Object>{
        'token': token ?? '',
        'pushEnabled': pushEnabled,
        'binAlertsEnabled': binAlertsEnabled,
        'enabled': alertsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'location': currentLocation ?? FieldValue.delete(),
      };
      await _deviceDocument(
        userId,
        deviceId,
      ).set(data, SetOptions(merge: true));
      _activeUserId = pushEnabled ? userId : null;
      if (currentLocation != null) {
        _lastSavedLocation = currentLocation;
        _listenForLocationChanges(userId, deviceId);
      }
      if (pushEnabled) {
        await _watchTokenRefresh(userId, deviceId);
      } else {
        await _tokenSubscription?.cancel();
        _tokenSubscription = null;
      }
    } catch (_) {
      if (alertsEnabled) await _stopLocationTracking();
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
      _activeUserId = null;
      rethrow;
    }
  }

  Future<void> stopForSignOut(String userId) async {
    await stopLocalTracking();

    final deviceId = await _getDeviceId();
    final deviceDocument = _deviceDocument(userId, deviceId);
    if ((await deviceDocument.get()).exists) {
      await deviceDocument.set({
        'enabled': false,
        'pushEnabled': false,
        'binAlertsEnabled': false,
        'token': '',
        'location': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> stopLocalTracking() async {
    await _stopLocationTracking();
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _activeUserId = null;
  }

  Future<GeoPoint> _prepareLocationTracking() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) {
      throw const BinNotificationPermissionException(
        'Turn on location services to use nearby bin alerts.',
      );
    }

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw const BinNotificationPermissionException(
        'Allow location access to use nearby bin alerts.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final alwaysAllowed = await _locationPermissionChannel
          .invokeMethod<bool>('requestAlwaysLocationAuthorization')
          .timeout(const Duration(seconds: 60), onTimeout: () => false);
      if (alwaysAllowed != true) {
        throw const BinNotificationPermissionException(
          'Allow location access all the time in Settings to use nearby bin alerts.',
        );
      }
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 60000,
      distanceFilter: _minimumLocationChangeMeters,
      pausesLocationUpdatesAutomatically: false,
    );
    await _location.changeNotificationOptions(
      channelName: 'Nearby bin alerts',
      title: 'VertivEra nearby bin alerts',
      subtitle: 'Location is active',
      description: 'Finding your closest bin for full-bin alerts.',
    );
    final backgroundEnabled = await _location.enableBackgroundMode();
    if (!backgroundEnabled) {
      throw const BinNotificationPermissionException(
        'Background location is unavailable. Allow location access all the time in device settings.',
      );
    }

    final currentLocation = await _location.getLocation();
    final latitude = currentLocation.latitude;
    final longitude = currentLocation.longitude;
    if (latitude == null || longitude == null) {
      throw const BinNotificationPermissionException(
        'Your current location is unavailable.',
      );
    }
    await _locationSubscription?.cancel();
    return GeoPoint(latitude, longitude);
  }

  void _listenForLocationChanges(String userId, String deviceId) {
    _locationSubscription = _location.onLocationChanged.listen(
      (location) =>
          unawaited(_handleLocationUpdate(userId, deviceId, location)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Background location stream failed: $error\n$stackTrace');
      },
    );
  }

  Future<void> _handleLocationUpdate(
    String userId,
    String deviceId,
    LocationData location,
  ) async {
    try {
      await _saveLocation(userId, deviceId, location);
    } on Exception catch (error, stackTrace) {
      debugPrint('Unable to save background location: $error\n$stackTrace');
    }
  }

  Future<void> _saveLocation(
    String userId,
    String deviceId,
    LocationData location,
  ) async {
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (latitude == null || longitude == null) return;

    final point = GeoPoint(latitude, longitude);
    final previous = _lastSavedLocation;
    if (previous != null &&
        _distanceMeters(previous, point) < _minimumLocationChangeMeters) {
      return;
    }

    await _deviceDocument(userId, deviceId).set({
      'location': point,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _lastSavedLocation = point;
  }

  Future<void> _watchTokenRefresh(String userId, String deviceId) async {
    await _tokenSubscription?.cancel();
    // Keep the FCM token current; onRegistered emits a Firebase Installation ID.
    // ignore: deprecated_member_use
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) async {
        if (_activeUserId != userId) return;
        try {
          await _deviceDocument(userId, deviceId).set({
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } on Exception catch (error) {
          debugPrint('Unable to update the FCM token: $error');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh listener failed: $error\n$stackTrace');
      },
    );
  }

  Future<void> _stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _lastSavedLocation = null;
    if (await _location.isBackgroundModeEnabled()) {
      await _location.enableBackgroundMode(enable: false);
    }
  }

  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdPreferenceKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return existing;
    }

    final random = Random.secure();
    final generated = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await preferences.setString(_deviceIdPreferenceKey, generated);
    _deviceId = generated;
    return generated;
  }

  DocumentReference<Map<String, dynamic>> _deviceDocument(
    String userId,
    String deviceId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notificationDevices')
        .doc(deviceId);
  }

  double _distanceMeters(GeoPoint from, GeoPoint to) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _radians(to.latitude - from.latitude);
    final longitudeDelta = _radians(to.longitude - from.longitude);
    final a =
        sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
        cos(_radians(from.latitude)) *
            cos(_radians(to.latitude)) *
            sin(longitudeDelta / 2) *
            sin(longitudeDelta / 2);
    return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * pi / 180;
}
