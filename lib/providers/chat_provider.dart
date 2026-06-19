import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/folder.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

/// Manages chat messages and API communication.
class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SpeechService _speech = SpeechService();
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();

  String? _activeConversationId;
  String? _currentServerId;
  List<Folder> _folders = [];
  List<Conversation> _conversations = [];
  final List<Message> _messages = [];
  List<TreeNode> _tree = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isConnected = true;
  StreamSubscription<String>? _streamSub;

  List<Message> get messages => List.unmodifiable(_messages);
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  List<Folder> get folders => List.unmodifiable(_folders);
  List<TreeNode> get tree => List.unmodifiable(_tree);
  String? get activeConversationId => _activeConversationId;
  bool get isLoading => _isLoading;
  bool get isListening => _speech.isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isConnected => _isConnected;
  SpeechService get speech => _speech;

  /// Initialize storage and load data.
  Future<void> init({String? serverId}) async {
    await _storage.open();
    _currentServerId = serverId;
    await _refreshData();
  }

  /// Reload folders, conversations, and tree.
  Future<void> _refreshData() async {
    _folders = await _storage.allFolders();
    _conversations = await _storage.allConversations();
    _buildTree();
    notifyListeners();
  }

  /// Build tree structure for UI.
  void _buildTree() {
    _tree = [];
    if (_folders.isEmpty && _conversations.isEmpty) return;

    final folderMap = <String?, List<Folder>>{};
    for (final f in _folders) {
      folderMap.putIfAbsent(f.parentId, () => []).add(f);
    }
    final convMap = <String?, List<Conversation>>{};
    for (final c in _conversations) {
      convMap.putIfAbsent(c.folderId, () => []).add(c);
    }

    void addNode(String? parentId, int depth) {
      final folders = folderMap[parentId] ?? [];
      for (final f in folders) {
        _tree.add(TreeNode(folder: f, depth: depth, isExpanded: false));
        final convs = convMap[f.id] ?? [];
        for (final c in convs) {
          _tree.add(TreeNode(conversation: c, depth: depth + 1));
        }
        addNode(f.id, depth + 1);
      }
      if (parentId == null) {
        final convs = convMap[null] ?? [];
        for (final c in convs) {
          _tree.add(TreeNode(conversation: c, depth: depth));
        }
      }
    }

    addNode(null, 0);
  }

  /// Load messages for a conversation from storage.
  Future<void> loadConversation(String id) async {
    _streamSub?.cancel();
    _activeConversationId = id;
    _messages.clear();
    _sessionId = null;
    _isLoading = false;

    final msgs = await _storage.getMessages(id);
    _messages.addAll(msgs);
    notifyListeners();
  }

  /// Create a new conversation.
  Future<Conversation> newConversation({String? folderId}) async {
    _streamSub?.cancel();
    final conv = await _storage.createConversation(
      title: 'New Chat',
      folderId: folderId,
      serverId: _currentServerId,
    );
    _activeConversationId = conv.id;
    _messages.clear();
    _sessionId = null;
    _isLoading = false;
    await _refreshData();
    return conv;
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String id) async {
    await _storage.deleteConversation(id);
    if (id == _activeConversationId) {
      _activeConversationId = null;
      _messages.clear();
    }
    await _refreshData();
  }

  // ─────────────────────────── folders ───────────────────────────

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final f = await _storage.createFolder(name: name, parentId: parentId);
    await _refreshData();
    return f;
  }

  Future<void> deleteFolder(String id) async {
    await _storage.deleteFolder(id);
    await _refreshData();
  }

  Future<void> renameFolder(String id, String name) async {
    await _storage.renameFolder(id, name);
    await _refreshData();
  }

  Future<void> moveConversation(String convId, String? folderId) async {
    await _storage.updateConversationFolder(convId, folderId);
    await _refreshData();
  }

  Future<void> renameConversation(String id, String title) async {
    await _storage.renameConversation(id, title);
    await _refreshData();
  }

  /// Get binding server ID for a conversation. Returns non-null to trigger auto-switch.
  Future<String?> getConversationServer(String convId) async {
    final convs = await _storage.allConversations();
    final conv = convs.firstWhere((c) => c.id == convId, orElse: () => convs.first);
    return conv.serverId;
  }

  /// Check server connection and update status.
  Future<void> checkConnection() async {
    _isConnected = await _api.healthCheck();
    notifyListeners();
  }


  /// Add a user message and get AI response.
  Future<void> sendMessage(String content, {List<String> imagePaths = const []}) async {
    if ((content.trim().isEmpty && imagePaths.isEmpty) || _isLoading) return;
    if (_activeConversationId == null) await newConversation();

    final userMsg = Message(
      id: _uuid.v4(),
      content: content.trim(),
      role: MessageRole.user,
      timestamp: DateTime.now(),
      imagePaths: imagePaths,
    );
    _messages.add(userMsg);
    await _storage.addMessage(_activeConversationId!, userMsg);
    notifyListeners();
    // Add placeholder for streaming
    final assistantMsg = Message(
      id: _uuid.v4(),
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    _messages.add(assistantMsg);
    _isLoading = true;
    notifyListeners();

    final apiMessages = _buildApiMessages();

    try {
      final stream = _api.chatStream(
        messages: apiMessages,
        sessionId: _sessionId,
      );

      final buffer = StringBuffer();
      _streamSub = stream.listen(
        (chunk) {
          buffer.write(chunk);
          _messages[_messages.length - 1] = assistantMsg.copyWith(
            content: buffer.toString(),
          );
          notifyListeners();
        },
        onDone: () {
          final finalMsg = assistantMsg.copyWith(
            content: buffer.toString(),
            isStreaming: false,
          );
          _messages[_messages.length - 1] = finalMsg;
          _storage.addMessage(_activeConversationId!, finalMsg);
          _buildTree();
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          final errorMsg = assistantMsg.copyWith(
            content: 'Error: $error',
            isStreaming: false,
          );
          _messages[_messages.length - 1] = errorMsg;
          _storage.addMessage(_activeConversationId!, errorMsg);
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      final errorMsg = assistantMsg.copyWith(
        content: 'Connection failed: $e',
        isStreaming: false,
      );
      _messages[_messages.length - 1] = errorMsg;
      _storage.addMessage(_activeConversationId!, errorMsg);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Build OpenAI-format message list from local history.
  /// Supports multimodal content with image_url parts.
  List<Map<String, dynamic>> _buildApiMessages() {
    return _messages
        .where((m) => !m.isStreaming || m.content.isNotEmpty)
        .map((m) {
          if (m.imagePaths.isNotEmpty) {
            // Multimodal: content is an array of text + image_url parts
            final parts = <Map<String, dynamic>>[];
            if (m.content.isNotEmpty) {
              parts.add({'type': 'text', 'text': m.content});
            }
            for (final path in m.imagePaths) {
              // Read image file and encode as base64 data URL
              final bytes = _readFileSync(path);
              if (bytes != null) {
                final b64 = base64Encode(bytes);
                final ext = path.split('.').last.toLowerCase();
                final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                parts.add({
                  'type': 'image_url',
                  'image_url': {'url': 'data:$mime;base64,$b64'},
                });
              }
            }
            return {'role': m.role.name, 'content': parts};
          }
          return {'role': m.role.name, 'content': m.content};
        })
        .toList();
  }

  /// Start voice input.
  Future<String?> startListening() async => _speech.listen();

  /// Stop voice input.
  Future<void> stopListeningAndSend() async => _speech.stopListening();

  /// Toggle TTS playback.
  Future<void> toggleSpeech() async {
    if (_isSpeaking) {
      await _speech.stopSpeaking();
      _isSpeaking = false;
    } else {
      final lastAssistant = _messages.lastWhere(
        (m) => m.role == MessageRole.assistant && !m.isStreaming,
        orElse: () => _messages.last,
      );
      if (lastAssistant.content.isNotEmpty) {
        _isSpeaking = true;
        notifyListeners();
        await _speech.speak(lastAssistant.content);
        _isSpeaking = false;
      }
    }
    notifyListeners();
  }

  /// Cancel streaming.
  void cancelStreaming() {
    _streamSub?.cancel();
    if (_messages.isNotEmpty && _messages.last.isStreaming) {
      _messages[_messages.length - 1] = _messages.last.copyWith(
        isStreaming: false,
      );
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Delete a single message by ID.
  Future<void> deleteMessage(String messageId) async {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// Retry the last user message (remove last assistant msg, resend).
  Future<void> retryLastMessage() async {
    if (_messages.isEmpty) return;
    // Find last user message
    final lastUserIndex = _messages.lastIndexWhere(
      (m) => m.role == MessageRole.user,
    );
    if (lastUserIndex < 0) return;
    final content = _messages[lastUserIndex].content;
    // Remove everything from last user message onward
    _messages.removeRange(lastUserIndex, _messages.length);
    notifyListeners();
    // Resend
    await sendMessage(content);
  }

  /// Switch server and reload conversations for new context.
  void switchServer({
    required String baseUrl,
    required String apiKey,
  }) {
    _streamSub?.cancel();
    _api.updateConfig(baseUrl: baseUrl, apiKey: apiKey);
    _activeConversationId = null;
    _messages.clear();
    _sessionId = null;
    _isLoading = false;
    _isSpeaking = false;
    notifyListeners();
  }

  /// Synchronous file read for image encoding.
  static List<int>? _readFileSync(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _speech.dispose();
    _storage.close();
    super.dispose();
  }
}

/// Tree node for folder/conversation hierarchy display.
class TreeNode {
  final Folder? folder;
  final Conversation? conversation;
  final int depth;
  bool isExpanded;

  TreeNode({
    this.folder,
    this.conversation,
    required this.depth,
    this.isExpanded = false,
  });

  bool get isFolder => folder != null;
}
