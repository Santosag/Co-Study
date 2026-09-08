class ChatMessage {
  final int id;
  final int? documentId;
  final int? folderId;
  final String question;
  final String answer;
  final String providerUsed;
  final String modelUsed;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    this.documentId,
    this.folderId,
    required this.question,
    required this.answer,
    required this.providerUsed,
    required this.modelUsed,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? (json['message_id'] as int? ?? 0),
      documentId: json['document'] as int? ?? (json['document_id'] as int?),
      folderId: json['folder'] as int? ?? (json['folder_id'] as int?),
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      providerUsed: json['provider_used'] as String? ?? (json['provider'] as String? ?? ''),
      modelUsed: json['model_used'] as String? ?? (json['model'] as String? ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
