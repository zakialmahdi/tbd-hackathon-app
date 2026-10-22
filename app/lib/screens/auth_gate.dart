import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'auth_page.dart';

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
      return widget.authenticatedChild;
    },
  );
}
