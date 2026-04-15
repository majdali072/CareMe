import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';

/// Schedules local-notification reminders for medications.
///
/// Approach: for each (day-of-week, time) pair in `med.schedule`, enumerate
/// every matching occurrence in the window [max(startDate, today), endDate]
/// (or today + [lifetimeHorizon] if `isLifetime`) and schedule one-shot
/// notifications at those times. One-shots (instead of weekly-repeating) let
/// us respect endDate cleanly and avoid orphan notifications.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inited = false;
  static const Duration lifetimeHorizon = Duration(days: 60);

  static const Map<String, int> _dayToWeekday = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // fallback: UTC
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Runtime permission (Android 13+ / iOS).
    if (!kIsWeb) {
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}
    }

    _inited = true;
  }

  /// Schedule every occurrence for `med` within its active window.
  /// Silently no-ops when the medication has no id, no schedule, or no times.
  static Future<void> scheduleMedication(Medication med) async {
    await init();
    if (med.id == null || med.schedule == null || med.schedule!.isEmpty) {
      return;
    }

    // Start cleanly: cancel any prior reminders for this med id.
    await cancelMedication(med.id!);

    final now = DateTime.now();
    final start = med.startDate != null && med.startDate!.isAfter(now)
        ? med.startDate!
        : now;

    final DateTime end;
    if (med.isLifetime == true) {
      end = now.add(lifetimeHorizon);
    } else if (med.endDate != null) {
      end = med.endDate!;
    } else {
      end = now.add(lifetimeHorizon);
    }

    if (end.isBefore(start)) return;

    const androidDetails = AndroidNotificationDetails(
      'meds_channel',
      'Medication Reminders',
      channelDescription: 'Reminders to take scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    for (final entry in med.schedule!) {
      final weekday = _dayToWeekday[entry.day.toLowerCase()];
      if (weekday == null) continue;

      for (final timeStr in entry.times) {
        final parsed = _parseTime(timeStr);
        if (parsed == null) continue;

        // Step day-by-day within window, pick matching weekdays, fire at time.
        DateTime cursor = DateTime(start.year, start.month, start.day);
        while (!cursor.isAfter(end)) {
          if (cursor.weekday == weekday) {
            final fireAt = DateTime(
              cursor.year,
              cursor.month,
              cursor.day,
              parsed.hour,
              parsed.minute,
            );
            if (fireAt.isAfter(now)) {
              final id = _notifId(med.id!, fireAt);
              try {
                await _plugin.zonedSchedule(
                  id,
                  'Time for ${med.name}',
                  'Take ${med.dosage}${med.purpose.isNotEmpty ? " — ${med.purpose}" : ""}',
                  tz.TZDateTime.from(fireAt, tz.local),
                  details,
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime,
                  payload: 'medication:${med.id}',
                );
              } catch (e) {
                debugPrint('Failed to schedule med notif: $e');
              }
            }
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }
    }
  }

  /// Cancel every notification whose payload belongs to `medId`.
  static Future<void> cancelMedication(String medId) async {
    await init();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == 'medication:$medId') {
          await _plugin.cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('cancelMedication failed: $e');
    }
  }

  /// Reschedule every active medication. Use after login/data load.
  static Future<void> rescheduleAll(List<Medication> meds) async {
    await init();
    for (final m in meds) {
      await scheduleMedication(m);
    }
  }

  static _TimeOfDay? _parseTime(String raw) {
    final s = raw.trim().toUpperCase();
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(s);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3);
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return _TimeOfDay(hour, minute);
  }

  /// Deterministic 31-bit id per (med, fire moment).
  static int _notifId(String medId, DateTime fireAt) {
    final key = '$medId|${fireAt.millisecondsSinceEpoch}';
    return key.hashCode & 0x7fffffff;
  }
}

class _TimeOfDay {
  final int hour;
  final int minute;
  _TimeOfDay(this.hour, this.minute);
}
