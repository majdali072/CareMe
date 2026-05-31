import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Holds the app's current [Locale]. The app is English-only, so this is a
/// fixed English locale; the notifier is kept so [main.dart] can keep building
/// the [MaterialApp] against it.
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));
}
