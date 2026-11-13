import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BrowserLocale {
  static final supported = <Locale>[
    const Locale('pt', 'BR'),
    for (final code in kMaterialSupportedLanguages) Locale(code),
  ];

  static String tag(Locale locale) => locale.toLanguageTag();

  static Locale? fromTag(String? value) {
    for (final locale in supported) {
      if (tag(locale) == value) return locale;
    }
    return null;
  }

  static const names = {
    'pt-BR': 'Português (Brasil)',
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'ar': 'العربية',
    'he': 'עברית',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'hi': 'हिन्दी',
    'ru': 'Русский',
    'uk': 'Українська',
  };

  static String label(Locale locale) => names[tag(locale)] ?? tag(locale);

  static bool portuguese(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'pt';
}
