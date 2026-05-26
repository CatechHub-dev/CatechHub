class PlanningMeeting {
  final String id;
  final String classId;
  final String createdBy;
  final DateTime date;
  final String title;
  final String activity;
  final String notes;

  /// Riunione di catechisti: in programmazione ma senza appello presenze.
  final bool isReunion;

  PlanningMeeting({
    required this.id,
    required this.classId,
    required this.createdBy,
    required this.date,
    required this.title,
    required this.activity,
    required this.notes,
    this.isReunion = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'createdBy': createdBy,
      'date': date.toIso8601String(),
      'title': title,
      'activity': activity,
      'notes': notes,
      'isReunion': isReunion,
    };
  }

  factory PlanningMeeting.fromMap(String id, Map<String, dynamic> data) {
    final date = DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now();
    final legacyTitle = data['title']?.toString().trim();

    return PlanningMeeting(
      id: id,
      classId: data['classId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      date: date,
      title: legacyTitle == null || legacyTitle.isEmpty
          ? 'Giornata del ${date.day}/${date.month}/${date.year}'
          : legacyTitle,
      activity: data['activity'] ?? '',
      notes: data['notes'] ?? data['publicNotes'] ?? '',
      isReunion: data['isReunion'] == true,
    );
  }
}
