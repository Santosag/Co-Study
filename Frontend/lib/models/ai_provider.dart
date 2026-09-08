class AIProviderInfo {
  final String id;
  final String name;
  final bool isConfigured;
  final String defaultModel;
  final bool isDefault;
  final String description;

  AIProviderInfo({
    required this.id,
    required this.name,
    required this.isConfigured,
    required this.defaultModel,
    required this.isDefault,
    required this.description,
  });

  factory AIProviderInfo.fromJson(Map<String, dynamic> json) {
    return AIProviderInfo(
      id: json['id'] as String? ?? 'gemini',
      name: json['name'] as String? ?? 'Gemini',
      isConfigured: json['is_configured'] as bool? ?? false,
      defaultModel: json['default_model'] as String? ?? 'gemini-2.5-flash',
      isDefault: json['is_default'] as bool? ?? false,
      description: json['description'] as String? ?? '',
    );
  }
}
