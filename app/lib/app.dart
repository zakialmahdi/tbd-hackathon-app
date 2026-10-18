import 'package:flutter/material.dart';

import 'app_config.dart';
import 'screens/splash_page.dart';

class VertivEraApp extends StatelessWidget {
  const VertivEraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'VertivEra',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const SplashPage(),
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
