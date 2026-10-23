import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_config.dart';
import 'firebase_options.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  Object? _startupError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      try {
        final preferences = await SharedPreferences.getInstance();
        final savedLanguage = preferences.getString('app_language');
        appLocale.value = supportedAppLocales.firstWhere(
          (locale) => locale.languageCode == savedLanguage,
          orElse: () => const Locale('en'),
        );
      } on Object catch (error, stackTrace) {
        debugPrint('Could not load saved language: $error\n$stackTrace');
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (mounted) setState(() => _ready = true);
    } on Object catch (error, stackTrace) {
      debugPrint('App startup failed: $error\n$stackTrace');
      if (mounted) setState(() => _startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const VertivEraApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B9C5A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _startupError == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.recycling, size: 76, color: Colors.white),
                      SizedBox(height: 20),
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Starting VertivEra...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'VertivEra could not finish starting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        'Startup error: $_startupError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
