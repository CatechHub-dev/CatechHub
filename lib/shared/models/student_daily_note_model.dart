class StudentDailyNote {
  final String id;
  final String studentId;
  final String meetingId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentDailyNote({
    required this.id,
    required this.studentId,
    required this.meetingId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentDailyNote.fromMap(String id, Map<String, dynamic> data) {
    return StudentDailyNote(
      id: id,
      studentId: data['studentId'] ?? '',
      meetingId: data['meetingId'] ?? '',
      text: data['text'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'meetingId': meetingId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  StudentDailyNote copyWith({
    String? id,
    String? studentId,
    String? meetingId,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentDailyNote(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      meetingId: meetingId ?? this.meetingId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
