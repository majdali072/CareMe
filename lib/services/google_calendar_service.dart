import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      gcal.CalendarApi.calendarScope,
    ],
  );

  static const _kSyncEnabled = 'gcal_sync_enabled';

  static Future<bool> get isSyncEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSyncEnabled) ?? false;
  }

  static Future<void> setSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSyncEnabled, value);
  }

  static Future<GoogleSignInAccount?> _ensureSignedIn() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    return account;
  }

  /// Connect to Google Calendar (prompts sign-in if needed).
  /// Returns true if successfully connected.
  static Future<bool> connect() async {
    try {
      final account = await _ensureSignedIn();
      if (account == null) return false;
      await setSyncEnabled(true);
      return true;
    } catch (e) {
      debugPrint('Google Calendar connect failed: $e');
      return false;
    }
  }

  /// Disconnect Google Calendar sync.
  static Future<void> disconnect() async {
    await setSyncEnabled(false);
  }

  /// Creates an event on the user's primary Google Calendar.
  /// Returns the created event id, or null if the user cancelled / failed.
  static Future<String?> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    Duration duration = const Duration(hours: 1),
  }) async {
    try {
      final account = await _ensureSignedIn();
      if (account == null) return null;

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return null;

      final api = gcal.CalendarApi(client);
      final event = gcal.Event(
        summary: title,
        description: description,
        location: location,
        start: gcal.EventDateTime(
          dateTime: start.toUtc(),
          timeZone: 'UTC',
        ),
        end: gcal.EventDateTime(
          dateTime: start.add(duration).toUtc(),
          timeZone: 'UTC',
        ),
      );
      final created = await api.events.insert(event, 'primary');
      return created.id;
    } catch (e) {
      debugPrint('Google Calendar createEvent failed: $e');
      return null;
    }
  }

  /// Deletes an event from Google Calendar by its event ID.
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final account = await _ensureSignedIn();
      if (account == null) return false;

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return false;

      final api = gcal.CalendarApi(client);
      await api.events.delete('primary', eventId);
      return true;
    } catch (e) {
      debugPrint('Google Calendar deleteEvent failed: $e');
      return false;
    }
  }

  /// Sync all CareMe appointments to Google Calendar.
  /// Creates events that don't exist yet (based on title matching).
  static Future<int> syncAppointments(List<Appointment> appointments) async {
    if (appointments.isEmpty) return 0;

    try {
      final account = await _ensureSignedIn();
      if (account == null) return 0;

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return 0;

      final api = gcal.CalendarApi(client);

      // Fetch existing CareMe events to avoid duplicates
      final existing = await api.events.list(
        'primary',
        q: '[CareMe]',
        timeMin: DateTime.now().subtract(const Duration(days: 365)).toUtc(),
        maxResults: 250,
      );
      final existingTitles = (existing.items ?? [])
          .map((e) => e.summary ?? '')
          .toSet();

      int created = 0;
      final now = DateTime.now();

      for (final apt in appointments) {
        final taggedTitle = '[CareMe] ${apt.title}';
        if (existingTitles.contains(taggedTitle)) continue;

        // Parse time like "10:00 AM" or "14:30"
        DateTime start;
        try {
          final timeParts = apt.time.replaceAll(RegExp(r'[APap][Mm]'), '').trim().split(':');
          int hour = int.parse(timeParts[0]);
          final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
          if (apt.time.toUpperCase().contains('PM') && hour != 12) hour += 12;
          if (apt.time.toUpperCase().contains('AM') && hour == 12) hour = 0;
          start = DateTime(now.year, now.month, apt.date, hour, minute);
        } catch (_) {
          start = DateTime(now.year, now.month, apt.date, 9, 0);
        }

        final event = gcal.Event(
          summary: taggedTitle,
          description: 'Type: ${apt.type}\nSynced from CareMe',
          location: apt.location,
          start: gcal.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC'),
          end: gcal.EventDateTime(dateTime: start.add(const Duration(hours: 1)).toUtc(), timeZone: 'UTC'),
        );

        await api.events.insert(event, 'primary');
        created++;
      }

      return created;
    } catch (e) {
      debugPrint('Google Calendar syncAppointments failed: $e');
      return 0;
    }
  }

  /// Fetch upcoming events from Google Calendar.
  static Future<List<gcal.Event>> fetchUpcomingEvents({int maxResults = 20}) async {
    try {
      final account = await _ensureSignedIn();
      if (account == null) return [];

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return [];

      final api = gcal.CalendarApi(client);
      final events = await api.events.list(
        'primary',
        timeMin: DateTime.now().toUtc(),
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } catch (e) {
      debugPrint('Google Calendar fetchUpcomingEvents failed: $e');
      return [];
    }
  }
}
