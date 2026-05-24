import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'api_service.dart';

/// Holds the app's current [Locale] and persists changes across launches.
///
/// First-run behaviour: if the user has never explicitly picked a language,
/// we read the phone's system locale from [PlatformDispatcher] and snap it
/// onto our supported set (English / Arabic). Anything outside that set
/// falls back to English.
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const String _prefKey = 'app_locale';

  /// Whatever UI is currently showing listens to this. [main.dart] rebuilds
  /// the [MaterialApp] when the value changes.
  final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);

    Locale resolved;
    if (stored != null && stored.isNotEmpty) {
      resolved = resolveSupportedLocale(Locale(stored));
    } else {
      // No stored preference -- detect phone default.
      final sysLocale = PlatformDispatcher.instance.locale;
      resolved = resolveSupportedLocale(sysLocale);
    }

    locale.value = resolved;
    ApiService.setLocale(resolved.languageCode);
  }

  Future<void> setLocale(Locale next) async {
    final resolved = resolveSupportedLocale(next);
    if (resolved.languageCode == locale.value.languageCode) return;
    locale.value = resolved;
    ApiService.setLocale(resolved.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, resolved.languageCode);
  }
}
