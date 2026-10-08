import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// D15 — Arabic + RTL only. Applied at [MaterialApp] root (UI-1).
class AppLocaleConfig {
  const AppLocaleConfig._();

  static const Locale locale = Locale('ar');

  static const List<Locale> supportedLocales = [locale];

  static const TextDirection textDirection = TextDirection.rtl;

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
