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
  /// Returns the number of notifications scheduled (0 if none).
  static Future<int> scheduleMedication(Medication med) async {
    await init();
    if (med.id == null || med.schedule == null || med.schedule!.isEmpty) {
      debugPrint('NOTIF: skipped - id=${med.id}, schedule=${med.schedule}');
      return 0;
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

    debugPrint('NOTIF: scheduling "${med.name}" from $start to $end');

    if (end.isBefore(start)) {
      debugPrint('NOTIF: skipped - end is before start');
      return 0;
    }

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

    int scheduled = 0;

    for (final entry in med.schedule!) {
      final weekday = _dayToWeekday[entry.day.toLowerCase()];
      debugPrint('NOTIF: day="${entry.day}" -> weekday=$weekday, times=${entry.times}');
      if (weekday == null) continue;

      for (final timeStr in entry.times) {
        final parsed = _parseTime(timeStr);
        debugPrint('NOTIF: parsing time "$timeStr" -> ${parsed != null ? "${parsed.hour}:${parsed.minute}" : "FAILED"}');
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
                scheduled++;
              } catch (e) {
                debugPrint('NOTIF: ERROR scheduling at $fireAt: $e');
              }
            }
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }
    }

    debugPrint('NOTIF: scheduled $scheduled notifications for "${med.name}"');

    // Show a confirmation so the user knows reminders were set
    if (scheduled > 0) {
      await _plugin.show(
        _notifId(med.id!, now),
        'Reminders set for ${med.name}',
        '$scheduled reminder(s) scheduled',
        details,
      );
    }

    return scheduled;
  }

  /// Fire a test notification immediately + schedule one 15 seconds later.
  /// Returns a debug string with scheduling info.
  static Future<String> showTestNotification() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'meds_channel',
      'Medication Reminders',
      channelDescription: 'Reminders to take scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Instant notification
    await _plugin.show(
      0,
      'CareMe Test (instant)',
      'This is the instant notification - it works!',
      details,
    );

    // Scheduled notification 15 seconds from now (same method as medications)
    final fireAt = DateTime.now().add(const Duration(seconds: 15));
    final tzFireAt = tz.TZDateTime.from(fireAt, tz.local);
    String debugInfo = 'Timezone: ${tz.local.name}\n'
        'Now: ${DateTime.now()}\n'
        'Scheduled for: $tzFireAt';

    try {
      await _plugin.zonedSchedule(
        99999,
        'CareMe Test (scheduled)',
        'This scheduled notification fired! Medication reminders will work.',
        tzFireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test',
      );
      final pending = await _plugin.pendingNotificationRequests();
      debugInfo += '\nPending notifications: ${pending.length}';
    } catch (e) {
      debugInfo += '\nSchedule ERROR: $e';
    }

    return debugInfo;
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
