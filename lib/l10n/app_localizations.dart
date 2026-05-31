import 'package:flutter/material.dart';

import 'translations.dart';

/// The app ships in English only.
const List<Locale> kSupportedLocales = [
  Locale('en'),
];

/// Look up localized strings. Usage: `AppLocalizations.of(context).t('key')`.
/// Falls back to the key itself if a string is missing.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String t(String key, [Map<String, String>? params]) {
    final raw = kTranslations['en']?[key] ?? key;
    if (params == null || params.isEmpty) return raw;
    var out = raw;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kSupportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// The app is English-only, so any candidate resolves to English.
Locale resolveSupportedLocale(Locale? candidate) => const Locale('en');
