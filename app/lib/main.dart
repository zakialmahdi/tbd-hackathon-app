import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_config.dart';
import 'firebase_options.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final savedLanguage = preferences.getString('app_language');
  final initialLocale = supportedAppLocales.firstWhere(
    (locale) => locale.languageCode == savedLanguage,
    orElse: () => const Locale('en'),
  );
  appLocale.value = initialLocale;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Exception catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not initialize Firebase: $error'),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const VertivEraApp());
}
