import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice input/output service.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _ttsInitialized = false;

  bool get isListening => _isListening;

  /// Initialize TTS engine.
  Future<void> initTts() async {
    if (_ttsInitialized) return;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ttsInitialized = true;
  }

  /// Start listening for speech, returns transcribed text when done.
  Future<String?> listen() async {
    final available = await _speech.initialize(
      onError: (_) {}, // Suppress init errors gracefully
    );
    if (!available) return null;

    final completer = Completer<String?>();
    String lastWords = '';

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          lastWords = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            if (!completer.isCompleted) {
              completer.complete(lastWords.isNotEmpty ? lastWords : null);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          autoPunctuation: true,
        ),
      );
    } catch (_) {
      _isListening = false;
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return completer.future;
    }

    // Timeout after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        _speech.stop();
        _isListening = false;
        completer.complete(lastWords.isNotEmpty ? lastWords : null);
      }
    });

    return completer.future;
  }

  /// Stop listening.
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }

  /// Whether TTS is currently speaking (tracked internally).
  bool _speaking = false;

  bool get isCurrentlySpeaking => _speaking;

  /// Speak the given text.
  Future<void> speak(String text) async {
    await initTts();
    _speaking = true;
    await _tts.speak(text);
    _speaking = false;
  }

  /// Stop speaking.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _speaking = false;
  }

  void dispose() {
    _tts.stop();
  }
}
