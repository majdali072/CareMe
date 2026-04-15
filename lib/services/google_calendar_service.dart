import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      gcal.CalendarApi.calendarScope,
    ],
  );

  static Future<GoogleSignInAccount?> _ensureSignedIn() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    return account;
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
}
