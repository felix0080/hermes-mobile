import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
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
  List<Conversation> _conversations = [];
  final List<Message> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isConnected = true;
  StreamSubscription<String>? _streamSub;

  List<Message> get messages => List.unmodifiable(_messages);
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  String? get activeConversationId => _activeConversationId;
  bool get isLoading => _isLoading;
  bool get isListening => _speech.isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isConnected => _isConnected;
  SpeechService get speech => _speech;

  /// Initialize storage and load latest conversation.
  Future<void> init() async {
    await _storage.open();
    _conversations = await _storage.listConversations();
    if (_conversations.isNotEmpty) {
      await loadConversation(_conversations.first.id);
    } else {
      await newConversation();
    }
    notifyListeners();
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
    _conversations = await _storage.listConversations();
    notifyListeners();
  }

  /// Create a new conversation.
  Future<void> newConversation() async {
    _streamSub?.cancel();
    final conv = await _storage.createConversation(title: 'New Chat');
    _activeConversationId = conv.id;
    _messages.clear();
    _sessionId = null;
    _isLoading = false;
    _conversations = await _storage.listConversations();
    notifyListeners();
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String id) async {
    await _storage.deleteConversation(id);
    _conversations = await _storage.listConversations();
    if (id == _activeConversationId) {
      if (_conversations.isNotEmpty) {
        await loadConversation(_conversations.first.id);
      } else {
        await newConversation();
      }
    }
    notifyListeners();
  }

  /// Check server connection and update status.
  Future<void> checkConnection() async {
    _isConnected = await _api.healthCheck();
    notifyListeners();
  }

  /// Auto-title conversation from first user message.
  void _autoTitle(String text) {
    if (_activeConversationId == null) return;
    final conv = _conversations.firstWhere(
      (c) => c.id == _activeConversationId,
      orElse: () => _conversations.first,
    );
    if (conv.title == 'New Chat') {
      final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      _storage.renameConversation(_activeConversationId!, title);
      _storage.listConversations().then((list) {
        _conversations = list;
        notifyListeners();
      });
    }
  }

  /// Add a user message and get AI response.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isLoading) return;
    if (_activeConversationId == null) await newConversation();

    final userMsg = Message(
      id: _uuid.v4(),
      content: content.trim(),
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    await _storage.addMessage(_activeConversationId!, userMsg);
    _conversations = await _storage.listConversations();
    notifyListeners();

    // Auto-title
    _autoTitle(content.trim());

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
          _storage.listConversations().then((list) {
            _conversations = list;
          });
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
  List<Map<String, String>> _buildApiMessages() {
    return _messages
        .where((m) => !m.isStreaming || m.content.isNotEmpty)
        .map((m) => {
              'role': m.role.name,
              'content': m.content,
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

  @override
  void dispose() {
    _streamSub?.cancel();
    _speech.dispose();
    _storage.close();
    super.dispose();
  }
}
