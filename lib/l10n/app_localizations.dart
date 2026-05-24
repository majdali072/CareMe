import 'package:flutter/material.dart';

import 'translations.dart';

/// All languages the app supports. We currently ship English and Arabic.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('ar'),
];

/// Display metadata for each supported language. Order here is what the
/// language picker in Settings renders.
class LanguageOption {
  final Locale locale;
  final String englishName;
  final String nativeName;
  final String flag;
  const LanguageOption(
      {required this.locale,
      required this.englishName,
      required this.nativeName,
      required this.flag});
}

const List<LanguageOption> kLanguageOptions = [
  LanguageOption(
      locale: Locale('en'),
      englishName: 'English',
      nativeName: 'English',
      flag: '\u{1F1FA}\u{1F1F8}'),
  LanguageOption(
      locale: Locale('ar'),
      englishName: 'Arabic',
      nativeName: 'العربية',
      flag: '\u{1F1F8}\u{1F1E6}'),
];

/// Look up localized strings. Usage: `AppLocalizations.of(context).t('key')`.
/// Falls back to English, then to the key itself, if a translation is missing.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String t(String key, [Map<String, String>? params]) {
    final lang = locale.languageCode;
    final raw =
        kTranslations[lang]?[key] ?? kTranslations['en']?[key] ?? key;
    if (params == null || params.isEmpty) return raw;
    var out = raw;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  bool get isRtl => locale.languageCode == 'ar';

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

/// Resolves a locale candidate against our supported set. Used by the
/// LocaleController during first-run device-language detection. Anything
/// outside English/Arabic falls back to English.
Locale resolveSupportedLocale(Locale? candidate) {
  if (candidate == null) return const Locale('en');
  for (final l in kSupportedLocales) {
    if (l.languageCode == candidate.languageCode) return l;
  }
  return const Locale('en');
}

/// Debug helper: warn if Arabic is missing keys present in English. Runs
/// only in debug mode.
void debugAssertTranslationsComplete() {
  assert(() {
    final base = kTranslations['en']!.keys.toSet();
    final arKeys = kTranslations['ar']!.keys.toSet();
    final missing = base.difference(arKeys);
    if (missing.isNotEmpty) {
      debugPrint('[i18n] ar missing ${missing.length} keys: '
          '${missing.take(6).join(", ")}${missing.length > 6 ? "..." : ""}');
    }
    return true;
  }());
}
