import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_config.dart';
import 'screens/splash_page.dart';

class VertivEraApp extends StatelessWidget {
  final Stream<User?>? authStateChanges;

  const VertivEraApp({super.key, this.authStateChanges});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, _) => MaterialApp(
        title: 'VertivEra',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: SplashPage(authStateChanges: authStateChanges),
      ),
    );
  }

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kGreen,
    brightness: b,
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
