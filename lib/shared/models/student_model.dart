class Student {
  final String id;
  final String name;
  final String surname;
  final String? classId;
  final DateTime birthDate;

  final String motherName;
  final String motherSurname;

  final String fatherName;
  final String fatherSurname;

  final String motherPhone;
  final String fatherPhone;
  final String studentPhone;

  final String? allergies;
  final String? autonomousExits;
  final String? notes;

  Student({
    required this.id,
    required this.name,
    required this.surname,
    required this.birthDate,
    required this.motherName,
    required this.motherSurname,
    required this.fatherName,
    required this.fatherSurname,
    required this.motherPhone,
    required this.fatherPhone,
    required this.studentPhone,
    this.classId,
    this.allergies,
    this.autonomousExits,
    this.notes,
  });

  factory Student.fromMap(String id, Map<String, dynamic> data) {
    return Student(
      id: id,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      birthDate: DateTime.tryParse(data['birthDate']?.toString() ?? '') ??
          DateTime.now(),
      classId: data['classId'],

      motherName: data['motherName'] ?? '',
      motherSurname: data['motherSurname'] ?? '',

      fatherName: data['fatherName'] ?? '',
      fatherSurname: data['fatherSurname'] ?? '',

      motherPhone: data['motherPhone'] ?? '',
      fatherPhone: data['fatherPhone'] ?? '',
      studentPhone: data['studentPhone'] ?? '',

      allergies: data['allergies'],
      autonomousExits: data['autonomousExits'],
      notes: data['notes'],
    );
  }

  /// Ordine alfabetico A→Z per cognome, poi nome.
  static int compareBySurname(Student a, Student b) {
    final bySurname = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
    if (bySurname != 0) return bySurname;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static List<Student> sortedBySurname(Iterable<Student> students) {
    return students.toList()..sort(compareBySurname);
  }

  Student copyWith({
    String? id,
    String? name,
    String? surname,
    String? classId,
    DateTime? birthDate,
    String? motherName,
    String? motherSurname,
    String? fatherName,
    String? fatherSurname,
    String? motherPhone,
    String? fatherPhone,
    String? studentPhone,
    String? allergies,
    String? autonomousExits,
    String? notes,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      birthDate: birthDate ?? this.birthDate,
      classId: classId ?? this.classId,
      motherName: motherName ?? this.motherName,
      motherSurname: motherSurname ?? this.motherSurname,
      fatherName: fatherName ?? this.fatherName,
      fatherSurname: fatherSurname ?? this.fatherSurname,
      motherPhone: motherPhone ?? this.motherPhone,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      studentPhone: studentPhone ?? this.studentPhone,
      allergies: allergies ?? this.allergies,
      autonomousExits: autonomousExits ?? this.autonomousExits,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'surname': surname,
      'birthDate': birthDate.toIso8601String(),
      'classId': classId,

      'motherName': motherName,
      'motherSurname': motherSurname,

      'fatherName': fatherName,
      'fatherSurname': fatherSurname,

      'motherPhone': motherPhone,
      'fatherPhone': fatherPhone,
      'studentPhone': studentPhone,

      'allergies': allergies,
      'autonomousExits': autonomousExits,
      'notes': notes,
    };
  }
}
