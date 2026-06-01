class MedScheduleEntry {
  final String day;
  final List<String> times;

  MedScheduleEntry({required this.day, required this.times});

  factory MedScheduleEntry.fromJson(Map<String, dynamic> json) =>
      MedScheduleEntry(
        day: json['day'] as String,
        times: List<String>.from(json['times'] ?? []),
      );

  Map<String, dynamic> toJson() => {'day': day, 'times': times};
}

class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final String purpose;
  final String sideEffects;
  final List<MedScheduleEntry>? schedule;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isLifetime;
  final bool isHistory;
  /// "Taken when needed" / PRN. No schedule, no reminders, no start/end.
  final bool isPrn;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    required this.purpose,
    required this.sideEffects,
    this.schedule,
    this.startDate,
    this.endDate,
    this.isLifetime,
    this.isHistory = false,
    this.isPrn = false,
  });

  /// True if the medication should be shown in the History section.
  /// History when explicitly marked OR when the end date has passed.
  bool get isPastOrHistory {
    if (isHistory) return true;
    if (isPrn) return false; // PRN meds never auto-expire
    if (isLifetime == true) return false;
    if (endDate == null) return false;
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final end0 = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return end0.isBefore(today0);
  }

  /// Auto-computed frequency string for display + AI context.
  /// Sums all scheduled times across the week and renders something readable.
  String get computedFrequency {
    if (isPrn) return 'As needed';
    final s = schedule;
    if (s == null || s.isEmpty) return frequency.isNotEmpty ? frequency : '—';
    final totalTimes = s.fold<int>(0, (sum, e) => sum + e.times.length);
    if (totalTimes == 0) return '—';
    final daysWithTimes = s.where((e) => e.times.isNotEmpty).length;
    if (daysWithTimes == 7) {
      final perDay = totalTimes / 7;
      if (totalTimes % 7 == 0) {
        final n = totalTimes ~/ 7;
        return n == 1 ? 'Daily' : 'Daily, $n× per day';
      }
      return 'Daily, ~${perDay.toStringAsFixed(1)}× per day';
    }
    final timeWord = totalTimes == 1 ? 'time' : 'times';
    final dayWord = daysWithTimes == 1 ? 'day' : 'days';
    return '$totalTimes $timeWord per week ($daysWithTimes $dayWord)';
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      time: json['time'] ?? '',
      purpose: json['purpose'] ?? '',
      sideEffects: json['sideEffects'] ?? '',
      schedule: (json['schedule'] as List<dynamic>?)
          ?.map((e) => MedScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      isLifetime: json['isLifetime'] as bool? ?? false,
      isHistory: json['isHistory'] as bool? ?? false,
      isPrn: json['isPrn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'time': time,
        'purpose': purpose,
        'sideEffects': sideEffects,
        'schedule': schedule?.map((e) => e.toJson()).toList(),
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isLifetime': isLifetime ?? false,
        'isHistory': isHistory,
        'isPrn': isPrn,
      };

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? frequency,
    String? time,
    String? purpose,
    String? sideEffects,
    List<MedScheduleEntry>? schedule,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLifetime,
    bool? isHistory,
    bool? isPrn,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      time: time ?? this.time,
      purpose: purpose ?? this.purpose,
      sideEffects: sideEffects ?? this.sideEffects,
      schedule: schedule ?? this.schedule,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isLifetime: isLifetime ?? this.isLifetime,
      isHistory: isHistory ?? this.isHistory,
      isPrn: isPrn ?? this.isPrn,
    );
  }
}

class LabTest {
  final String? id;
  final String name;
  final String date;
  final String doctor;
  final String fileName;
  final String fileId;

  LabTest({
    this.id,
    required this.name,
    required this.date,
    required this.doctor,
    required this.fileName,
    this.fileId = '',
  });

  bool get hasFile => fileId.isNotEmpty;

  factory LabTest.fromJson(Map<String, dynamic> json) {
    return LabTest(
      id: json['id'],
      name: json['name'] ?? '',
      date: json['date'] ?? '',
      doctor: json['doctor'] ?? '',
      fileName: json['fileName'] ?? '',
      fileId: json['fileId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date,
        'doctor': doctor,
        'fileName': fileName,
      };
}

class Appointment {
  final int date;
  final DateTime? fullDate;
  final String title;
  final String time;
  final String type;
  final String location;
  final String doctor;
  final String? googleEventId;

  Appointment({
    required this.date,
    this.fullDate,
    required this.title,
    required this.time,
    required this.type,
    required this.location,
    this.doctor = '',
    this.googleEventId,
  });

  /// True if the appointment is in the past (date has already happened).
  /// Falls back to false when no full date is available (legacy entries).
  bool get isPast {
    if (fullDate == null) return false;
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final apt0 =
        DateTime(fullDate!.year, fullDate!.month, fullDate!.day);
    return apt0.isBefore(today0);
  }

  Appointment copyWith({
    int? date,
    DateTime? fullDate,
    String? title,
    String? time,
    String? type,
    String? location,
    String? doctor,
    String? googleEventId,
  }) {
    return Appointment(
      date: date ?? this.date,
      fullDate: fullDate ?? this.fullDate,
      title: title ?? this.title,
      time: time ?? this.time,
      type: type ?? this.type,
      location: location ?? this.location,
      doctor: doctor ?? this.doctor,
      googleEventId: googleEventId ?? this.googleEventId,
    );
  }

  /// Serialize for local persistence (so appointments survive app restarts and
  /// Google Calendar sign-in, which can recreate the activity).
  Map<String, dynamic> toJson() => {
        'date': date,
        'fullDate': fullDate?.toIso8601String(),
        'title': title,
        'time': time,
        'type': type,
        'location': location,
        'doctor': doctor,
        'googleEventId': googleEventId,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final fullDate = (json['fullDate'] is String)
        ? DateTime.tryParse(json['fullDate'] as String)
        : null;
    return Appointment(
      date: (json['date'] as int?) ?? fullDate?.day ?? 1,
      fullDate: fullDate,
      title: json['title']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      doctor: json['doctor']?.toString() ?? '',
      googleEventId: json['googleEventId']?.toString(),
    );
  }
}

class ChatMessage {
  final int id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// A single chat thread between the user and CareAI. Each time the user
/// re-enters the chatbot screen we open a fresh session so the conversations
/// stay separated; older sessions are still browsable from the history sheet
/// for up to 7 days.
class ChatSession {
  final String id;
  final DateTime startedAt;
  final List<ChatMessage> messages;

  /// AI-generated short title summarizing the whole conversation. Null until
  /// generated; the history list falls back to the first user message.
  String? title;

  ChatSession({
    required this.id,
    required this.startedAt,
    required this.messages,
    this.title,
  });

  /// Timestamp of the most recent message (for retention + sort).
  /// Falls back to [startedAt] when the session is empty.
  DateTime get lastActivity {
    if (messages.isEmpty) return startedAt;
    return messages.last.timestamp;
  }

  /// True when no real user/AI exchange has happened yet — used so the host
  /// can tell whether re-entering the screen should reuse the empty session
  /// instead of creating yet another empty one.
  bool get isEmpty =>
      messages.where((m) => m.id != 1).isEmpty;

  /// Short label for the history list. Uses the first user message as a
  /// preview, or a fallback when nothing has been sent yet.
  String previewTitle() {
    final firstUser = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(id: -1, text: '', isUser: false, timestamp: startedAt),
    );
    final raw = firstUser.text.trim();
    if (raw.isEmpty) return '';
    return raw.length <= 60 ? raw : '${raw.substring(0, 57)}…';
  }

  /// Title to show in the history list: the AI-generated [title] when
  /// available, otherwise a preview of the first user message.
  String displayTitle() {
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return previewTitle();
  }
}
