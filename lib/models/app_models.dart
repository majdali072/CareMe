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
  });

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
  final String title;
  final String time;
  final String type;
  final String location;

  Appointment({
    required this.date,
    required this.title,
    required this.time,
    required this.type,
    required this.location,
  });

  Appointment copyWith({
    int? date,
    String? title,
    String? time,
    String? type,
    String? location,
  }) {
    return Appointment(
      date: date ?? this.date,
      title: title ?? this.title,
      time: time ?? this.time,
      type: type ?? this.type,
      location: location ?? this.location,
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
