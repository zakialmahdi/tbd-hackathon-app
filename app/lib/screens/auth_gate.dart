import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/bin_notification_service.dart';
import 'auth_page.dart';

const _permissionSettingsChannel = MethodChannel(
  'com.example.app/background_location',
);

class AuthGate extends StatefulWidget {
  final Stream<User?>? authStateChanges;
  final Widget authenticatedChild;

  const AuthGate({
    super.key,
    this.authStateChanges,
    required this.authenticatedChild,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges =
        widget.authStateChanges ?? AuthService().authStateChanges;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _authStateChanges,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not check sign-in status: ${snapshot.error}'),
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == null) return const AuthPage();
      return _StartupPermissionGate(child: widget.authenticatedChild);
    },
  );
}

class _StartupPermissionGate extends StatefulWidget {
  final Widget child;

  const _StartupPermissionGate({required this.child});

  @override
  State<_StartupPermissionGate> createState() => _StartupPermissionGateState();
}

class _StartupPermissionGateState extends State<_StartupPermissionGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestPermissions());
    });
  }

  Future<void> _requestPermissions() async {
    if (!mounted ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        Firebase.apps.isEmpty) {
      return;
    }

    try {
      final warning = await BinNotificationService()
          .requestPermissionsAtStartup();
      if (warning == null || !mounted) return;
      debugPrint('Sign-in notification permission: $warning');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permissions needed for bin alerts'),
          content: Text(
            '$warning\n\nOn Android 11 and newer, open App info > '
            'Permissions > Location and choose "Allow all the time".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _permissionSettingsChannel.invokeMethod<bool>(
                  'openAppSettings',
                );
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Unable to request sign-in notification permissions: '
        '$error\n$stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
