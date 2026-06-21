class Catechesi {
  final String id;
  final String title;
  final List<String> tags;
  final List<String> biblicalReferences;
  final List<String> websiteReferences;
  final List<String> photoIds;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Catechesi({
    required this.id,
    required this.title,
    required this.tags,
    required this.biblicalReferences,
    required this.websiteReferences,
    required this.photoIds,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Catechesi copyWith({
    String? id,
    String? title,
    List<String>? tags,
    List<String>? biblicalReferences,
    List<String>? websiteReferences,
    List<String>? photoIds,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Catechesi(
      id: id ?? this.id,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      biblicalReferences: biblicalReferences ?? this.biblicalReferences,
      websiteReferences: websiteReferences ?? this.websiteReferences,
      photoIds: photoIds ?? this.photoIds,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tags': tags,
      'biblicalReferences': biblicalReferences,
      'websiteReferences': websiteReferences,
      'photoIds': photoIds,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Catechesi.fromMap(String id, Map<String, dynamic> data) {
    return Catechesi(
      id: id,
      title: data['title'] ?? '',
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      biblicalReferences: (data['biblicalReferences'] as List<dynamic>?)?.cast<String>() ?? [],
      websiteReferences: (data['websiteReferences'] as List<dynamic>?)?.cast<String>() ?? [],
      photoIds: (data['photoIds'] as List<dynamic>?)?.cast<String>() ?? [],
      description: data['description'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
