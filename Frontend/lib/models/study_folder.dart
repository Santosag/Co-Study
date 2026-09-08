class StudyFolder {
  final int id;
  final String name;
  final String description;
  final int totalDocuments;
  final DateTime createdAt;

  StudyFolder({
    required this.id,
    required this.name,
    required this.description,
    required this.totalDocuments,
    required this.createdAt,
  });

  factory StudyFolder.fromJson(Map<String, dynamic> json) {
    return StudyFolder(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Untitled Folder',
      description: json['description'] as String? ?? '',
      totalDocuments: json['total_documents'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}
