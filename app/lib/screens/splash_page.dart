import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_config.dart';
import 'auth_gate.dart';
import 'home_shell.dart';

class SplashPage extends StatefulWidget {
  final Stream<User?>? authStateChanges;

  const SplashPage({super.key, this.authStateChanges});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_continueStartup());
  }

  Future<void> _continueStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGate(
          authStateChanges: widget.authStateChanges,
          authenticatedChild: HomeShell(
            authStateChanges: widget.authStateChanges,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kGreen,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.recycling, size: 88, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'VertivEra',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Waste less. Circle more.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
