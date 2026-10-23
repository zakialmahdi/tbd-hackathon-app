import 'package:flutter/material.dart';

const kGreen = Color(0xFF1B9C5A);
const kStadiaMapsApiKey = 'a1c7aaba-dfd5-49a6-8e40-5a7bd85b1e96';
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

const supportedAppLocales = <Locale>[
  Locale('en'),
  Locale('ms'),
  Locale('zh'),
  Locale('ta'),
];

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

String languageName(Locale locale) => switch (locale.languageCode) {
  'ms' => 'Bahasa Melayu',
  'zh' => '中文',
  'ta' => 'தமிழ்',
  _ => 'English',
};
