class SchoolClass {
  final String id;
  final String name;
  final List<String> studentIds;
  final List<String> catechistIds;

  SchoolClass({
    required this.id,
    required this.name,
    required this.studentIds,
    required this.catechistIds,
  });

  SchoolClass copyWith({
    String? id,
    String? name,
    List<String>? studentIds,
    List<String>? catechistIds,
  }) {
    return SchoolClass(
      id: id ?? this.id,
      name: name ?? this.name,
      studentIds: studentIds ?? this.studentIds,
      catechistIds: catechistIds ?? this.catechistIds,
    );
  }

  factory SchoolClass.fromMap(String id, Map<String, dynamic> data) {
    return SchoolClass(
      id: id,
      name: data['name'] ?? '',
      studentIds: (data['studentIds'] as List? ?? [])
          .map((value) => value.toString())
          .toList(),
      catechistIds: (data['catechistIds'] as List? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentIds': studentIds,
      'catechistIds': catechistIds,
    };
  }
}
