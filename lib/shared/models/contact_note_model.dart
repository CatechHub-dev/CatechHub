class ContactNote {
  final String id;
  final String studentId;
  final DateTime dateTime;
  final String medium; // 'de_visu', 'whatsapp', 'cellulare'
  final String notes;

  ContactNote({
    required this.id,
    required this.studentId,
    required this.dateTime,
    required this.medium,
    required this.notes,
  });

  factory ContactNote.fromMap(String id, Map<String, dynamic> data) {
    return ContactNote(
      id: id,
      studentId: data['studentId'] ?? '',
      dateTime: DateTime.tryParse(data['dateTime']?.toString() ?? '') ??
          DateTime.now(),
      medium: data['medium'] ?? 'de_visu',
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'dateTime': dateTime.toIso8601String(),
      'medium': medium,
      'notes': notes,
    };
  }

  static String mediumLabel(String medium) {
    switch (medium) {
      case 'de_visu':
        return 'De visu';
      case 'whatsapp':
        return 'WhatsApp';
      case 'cellulare':
        return 'Cellulare';
      default:
        return medium;
    }
  }
}
