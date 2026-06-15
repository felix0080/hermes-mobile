import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';

/// Manages chat messages and API communication.
class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SpeechService _speech = SpeechService();
  final Uuid _uuid = const Uuid();

  final List<Message> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isSpeaking = false;
  StreamSubscription<String>? _streamSub;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isListening => _speech.isListening;
  bool get isSpeaking => _isSpeaking;
  SpeechService get speech => _speech;

  /// Add a user message and get AI response.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isLoading) return;

    // Add user message
    final userMsg = Message(
      id: _uuid.v4(),
      content: content.trim(),
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
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

    // Build message history for API
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
          _messages[_messages.length - 1] = assistantMsg.copyWith(
            content: buffer.toString(),
            isStreaming: false,
          );
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _messages[_messages.length - 1] = assistantMsg.copyWith(
            content: 'Error: $error',
            isStreaming: false,
          );
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _messages[_messages.length - 1] = assistantMsg.copyWith(
        content: 'Connection failed: $e',
        isStreaming: false,
      );
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
  Future<String?> startListening() async {
    return await _speech.listen();
  }

  /// Stop voice input and send transcribed text.
  Future<void> stopListeningAndSend() async {
    await _speech.stopListening();
  }

  /// Toggle TTS playback for the last assistant message.
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

  /// Clear current conversation.
  void clearConversation() {
    _streamSub?.cancel();
    _messages.clear();
    _sessionId = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Update API config and clear conversation for new server.
  void switchServer({
    required String baseUrl,
    required String apiKey,
  }) {
    _streamSub?.cancel();
    _api.updateConfig(baseUrl: baseUrl, apiKey: apiKey);
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
    super.dispose();
  }
}
