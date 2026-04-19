import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../models/app_models.dart';

/// Handles FCM push notifications for medication reminders.
/// The backend sends notifications at the right time via Firebase.
/// This service handles:
/// 1. Firebase initialization
/// 2. FCM token registration with backend
/// 3. Foreground notification display
/// 4. Permission requests
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  /// Initialize Firebase, request permissions, register token, set up listeners.
  static Future<void> init() async {
    if (_inited) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Already initialized
    }

    // Request notification permission (Android 13+ / iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications for foreground display
    await _localPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Create notification channel (Android 8+)
    final androidPlugin = _localPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'meds_channel',
          'Medication Reminders',
          description: 'Reminders to take scheduled medications',
          importance: Importance.max,
        ),
      );
    }

    // Listen for foreground messages and show them as local notifications
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _inited = true;
  }

  /// Register the device's FCM token with the backend.
  /// Call this after login.
  static Future<bool> registerToken() async {
    try {
      await init();
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('[FCM] No token available');
        return false;
      }
      debugPrint('[FCM] Token: ${token.substring(0, 20)}...');

      await ApiService.registerFcmToken(token);
      debugPrint('[FCM] Token registered with backend');

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await ApiService.registerFcmToken(newToken);
          debugPrint('[FCM] Token refreshed and re-registered');
        } catch (_) {}
      });

      return true;
    } catch (e) {
      debugPrint('[FCM] Registration failed: $e');
      return false;
    }
  }

  /// Handle foreground FCM messages by showing a local notification.
  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localPlugin.show(
      notification.hashCode,
      notification.title ?? 'CareMe',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meds_channel',
          'Medication Reminders',
          channelDescription: 'Reminders to take scheduled medications',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Send a test push notification via the backend.
  /// Returns status message.
  static Future<String> sendTestNotification() async {
    try {
      await init();
      final token = await _fcm.getToken();
      if (token == null) return 'ERROR: No FCM token';

      final result = await ApiService.testFcmNotification();
      return 'Test sent!\n$result';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  // ── Next reminder time (for UI countdown) ─────────────────────────────────

  static const Map<String, int> _dayToWeekday = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static DateTime? nextReminderTime(Medication med) {
    if (med.schedule == null || med.schedule!.isEmpty) return null;
    final now = DateTime.now();
    DateTime? earliest;

    for (final entry in med.schedule!) {
      final weekday = _dayToWeekday[entry.day.toLowerCase()];
      if (weekday == null) continue;
      for (final timeStr in entry.times) {
        final tp = _parseTime(timeStr);
        if (tp == null) continue;
        var candidate = DateTime(now.year, now.month, now.day, tp[0], tp[1]);
        int daysAhead = weekday - now.weekday;
        if (daysAhead < 0) daysAhead += 7;
        candidate = candidate.add(Duration(days: daysAhead));
        if (candidate.isBefore(now)) candidate = candidate.add(const Duration(days: 7));
        if (med.startDate != null && candidate.isBefore(med.startDate!)) continue;
        if (med.isLifetime != true && med.endDate != null && candidate.isAfter(med.endDate!)) continue;
        if (earliest == null || candidate.isBefore(earliest)) earliest = candidate;
      }
    }
    return earliest;
  }

  static List<int>? _parseTime(String raw) {
    final s = raw.trim().toUpperCase();
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(s);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3);
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return [hour, minute];
  }
}
