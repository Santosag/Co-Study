class StudyDocument {
  final int id;
  final int? folderId;
  final String title;
  final String? fileUrl;
  final String fileType;
  final int fileSize;
  final int pageCount;
  final String extractedTextPreview;
  final String? extractedText;
  final String summary;
  final DateTime uploadedAt;

  StudyDocument({
    required this.id,
    this.folderId,
    required this.title,
    this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.pageCount,
    required this.extractedTextPreview,
    this.extractedText,
    required this.summary,
    required this.uploadedAt,
  });

  factory StudyDocument.fromJson(Map<String, dynamic> json) {
    return StudyDocument(
      id: json['id'] as int,
      folderId: json['folder'] as int?,
      title: json['title'] as String? ?? 'Untitled Document',
      fileUrl: json['file_url'] as String?,
      fileType: (json['file_type'] as String? ?? 'txt').toUpperCase(),
      fileSize: json['file_size'] as int? ?? 0,
      pageCount: json['page_count'] as int? ?? 1,
      extractedTextPreview: json['extracted_text_preview'] as String? ?? '',
      extractedText: json['extracted_text'] as String?,
      summary: json['summary'] as String? ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
