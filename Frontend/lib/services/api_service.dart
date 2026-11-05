import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../models/study_folder.dart';
import '../models/study_document.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get defaultBaseUrl {
  return 'https://co-study-backend.onrender.com/api';
}

  late String baseUrl = defaultBaseUrl;

  void setBaseUrl(String newUrl) {
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
  }

  // -------------------------------------------------------------
  // Health & AI Providers
  // -------------------------------------------------------------

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health/')).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<AIProviderInfo>> getAIProviders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ai/providers/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['providers'] as List<dynamic>? ?? [];
        return list.map((p) => AIProviderInfo.fromJson(p as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading AI providers: $e');
    }
    return [];
  }

  // -------------------------------------------------------------
  // Study Folders
  // -------------------------------------------------------------

  Future<List<StudyFolder>> getFolders() async {
    final response = await http.get(Uri.parse('$baseUrl/folders/'));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((f) => StudyFolder.fromJson(f as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load folders (${response.statusCode})');
  }

  Future<StudyFolder> createFolder(String name, String description) async {
    final response = await http.post(
      Uri.parse('$baseUrl/folders/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': description}),
    );
    if (response.statusCode == 201) {
      return StudyFolder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create folder: ${response.body}');
  }

  Future<void> deleteFolder(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/folders/$id/'));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete folder');
    }
  }

  // -------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------

  Future<List<StudyDocument>> getDocuments({int? folderId}) async {
    final uri = folderId != null
        ? Uri.parse('$baseUrl/documents/?folder=$folderId')
        : Uri.parse('$baseUrl/documents/');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      final docs = list.map((d) => StudyDocument.fromJson(d as Map<String, dynamic>)).toList();
      if (folderId != null) {
        return docs.where((d) => d.folderId == folderId).toList();
      }
      return docs;
    }
    throw Exception('Failed to load documents (${response.statusCode})');
  }

  Future<StudyDocument> getDocument(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/documents/$id/'));
    if (response.statusCode == 200) {
      return StudyDocument.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load document details');
  }

  Future<void> deleteDocument(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/documents/$id/'));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete document');
    }
  }

  // -------------------------------------------------------------
  // File Upload (Single & Multi)
  // -------------------------------------------------------------

  Future<List<StudyDocument>> uploadFiles(
    List<PlatformFile> files, {
    int? folderId,
    String? title,
  }) async {
    final uri = Uri.parse('$baseUrl/documents/upload/');
    final request = http.MultipartRequest('POST', uri);

    if (folderId != null) {
      request.fields['folder_id'] = folderId.toString();
    }
    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }

    for (final file in files) {
      if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('files', file.path!, filename: file.name),
        );
      } else {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('files', bytes, filename: file.name),
        );
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['documents'] as List<dynamic>? ?? [];
      return list.map((d) => StudyDocument.fromJson(d as Map<String, dynamic>)).toList();
    }
    throw Exception('Upload failed (${response.statusCode}): ${response.body}');
  }

  // -------------------------------------------------------------
  // AI Explain & Q&A
  // -------------------------------------------------------------

  Future<String> explainDocument(int docId, {String? provider, String? model}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/documents/$docId/explain/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (provider != null) 'provider': provider,
        if (model != null) 'model': model,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['summary'] as String? ?? 'No explanation generated.';
    }
    throw Exception('Explanation request failed: ${response.body}');
  }

  Future<ChatMessage> askDocument(
    int docId,
    String question, {
    String? provider,
    String? model,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/documents/$docId/ask/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        if (provider != null) 'provider': provider,
        if (model != null) 'model': model,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatMessage.fromJson(data);
    }
    throw Exception('Ask question failed: ${response.body}');
  }

  Future<ChatMessage> askFolder(
    int folderId,
    String question, {
    String? provider,
    String? model,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/folders/$folderId/ask/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        if (provider != null) 'provider': provider,
        if (model != null) 'model': model,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatMessage.fromJson(data);
    }
    throw Exception('Ask folder failed: ${response.body}');
  }

  Future<List<ChatMessage>> getDocumentHistory(int docId) async {
    final response = await http.get(Uri.parse('$baseUrl/documents/$docId/history/'));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<ChatMessage>> getFolderHistory(int folderId) async {
    final response = await http.get(Uri.parse('$baseUrl/folders/$folderId/history/'));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
