import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/study_folder.dart';
import '../models/study_document.dart';
import '../models/chat_message.dart';
import '../models/ai_provider.dart';
import '../services/api_service.dart';

class StudyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<StudyFolder> _folders = [];
  List<StudyDocument> _documents = [];
  List<AIProviderInfo> _aiProviders = [];
  List<ChatMessage> _activeChat = [];

  String _selectedProvider = 'gemini';
  String? _selectedModel;
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isChatLoading = false;
  String? _error;

  List<StudyFolder> get folders => _folders;
  List<StudyDocument> get documents => _documents;
  List<AIProviderInfo> get aiProviders => _aiProviders;
  List<ChatMessage> get activeChat => _activeChat;
  String get selectedProvider => _selectedProvider;
  String? get selectedModel => _selectedModel;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  String? get error => _error;
  String get currentBaseUrl => _api.baseUrl;

  void setSelectedProvider(String providerId, {String? model}) {
    _selectedProvider = providerId;
    _selectedModel = model;
    notifyListeners();
  }

  void setBaseUrl(String newUrl) {
    _api.setBaseUrl(newUrl);
    checkConnection();
  }

  Future<void> init() async {
    await checkConnection();
    if (_isConnected) {
      await Future.wait([
        fetchAIProviders(),
        fetchFolders(),
        fetchDocuments(),
      ]);
    }
  }

  Future<void> checkConnection() async {
    _isConnected = await _api.checkHealth();
    notifyListeners();
  }

  Future<void> fetchAIProviders() async {
    _aiProviders = await _api.getAIProviders();
    final defaultProvider = _aiProviders.where((p) => p.isDefault).firstOrNull;
    if (defaultProvider != null) {
      _selectedProvider = defaultProvider.id;
      _selectedModel = defaultProvider.defaultModel;
    }
    notifyListeners();
  }

  Future<void> fetchFolders() async {
    _setLoading(true);
    try {
      _folders = await _api.getFolders();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchDocuments({int? folderId}) async {
    _setLoading(true);
    try {
      _documents = await _api.getDocuments(folderId: folderId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<StudyFolder?> createFolder(String name, String description) async {
    _setLoading(true);
    try {
      final newFolder = await _api.createFolder(name, description);
      _folders.insert(0, newFolder);
      notifyListeners();
      return newFolder;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadFiles(List<PlatformFile> files, {int? folderId, String? title}) async {
    _setLoading(true);
    try {
      final uploadedDocs = await _api.uploadFiles(files, folderId: folderId, title: title);
      _documents.insertAll(0, uploadedDocs);
      await fetchFolders(); // refresh folder document counts
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> explainDocument(int docId) async {
    _setLoading(true);
    try {
      final summary = await _api.explainDocument(
        docId,
        provider: _selectedProvider,
        model: _selectedModel,
      );
      final idx = _documents.indexWhere((d) => d.id == docId);
      if (idx != -1) {
        _documents[idx] = StudyDocument(
          id: _documents[idx].id,
          folderId: _documents[idx].folderId,
          title: _documents[idx].title,
          fileUrl: _documents[idx].fileUrl,
          fileType: _documents[idx].fileType,
          fileSize: _documents[idx].fileSize,
          pageCount: _documents[idx].pageCount,
          extractedTextPreview: _documents[idx].extractedTextPreview,
          extractedText: _documents[idx].extractedText,
          summary: summary,
          uploadedAt: _documents[idx].uploadedAt,
        );
      }
      notifyListeners();
      return summary;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadChatHistory({int? docId, int? folderId}) async {
    _isChatLoading = true;
    _activeChat = [];
    notifyListeners();

    try {
      if (docId != null) {
        _activeChat = await _api.getDocumentHistory(docId);
      } else if (folderId != null) {
        _activeChat = await _api.getFolderHistory(folderId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isChatLoading = false;
      notifyListeners();
    }
  }

  Future<ChatMessage?> ask({
    required String question,
    int? docId,
    int? folderId,
  }) async {
    _isChatLoading = true;
    notifyListeners();

    try {
      ChatMessage msg;
      if (docId != null) {
        msg = await _api.askDocument(
          docId,
          question,
          provider: _selectedProvider,
          model: _selectedModel,
        );
      } else if (folderId != null) {
        msg = await _api.askFolder(
          folderId,
          question,
          provider: _selectedProvider,
          model: _selectedModel,
        );
      } else {
        throw Exception('Must provide either docId or folderId');
      }

      _activeChat.add(msg);
      notifyListeners();
      return msg;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isChatLoading = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
