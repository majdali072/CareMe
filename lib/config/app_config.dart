/// Compile-time configuration loaded from `--dart-define` flags.
///
/// Run with:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=xxx
///
/// Keeping the key out of source. It still needs to be registered in the
/// platform-native config (AndroidManifest.xml, AppDelegate.swift, web/index.html)
/// for the map SDK itself, but for Dart-side Geocoding HTTP calls we read it
/// from here.
class AppConfig {
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static bool get hasMapsKey => googleMapsApiKey.isNotEmpty;
}
