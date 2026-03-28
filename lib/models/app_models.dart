class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final String purpose;
  final String sideEffects;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    required this.purpose,
    required this.sideEffects,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'time': time,
        'purpose': purpose,
        'sideEffects': sideEffects,
      };

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? frequency,
    String? time,
    String? purpose,
    String? sideEffects,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      time: time ?? this.time,
      purpose: purpose ?? this.purpose,
      sideEffects: sideEffects ?? this.sideEffects,
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
