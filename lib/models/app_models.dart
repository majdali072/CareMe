class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String time;
  final String purpose;
  final String sideEffects;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
    required this.purpose,
    required this.sideEffects,
  });

  Medication copyWith({
    String? name,
    String? dosage,
    String? frequency,
    String? time,
    String? purpose,
    String? sideEffects,
  }) {
    return Medication(
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
  final String name;
  final String date;
  final String doctor;
  final String fileName;

  LabTest({
    required this.name,
    required this.date,
    required this.doctor,
    required this.fileName,
  });
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
