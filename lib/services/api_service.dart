import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// OpenAI-compatible API client for Hermes API Server.
class ApiService {
  final Dio _dio;

  String _baseUrl;
  String _apiKey;
  String _model;

  ApiService({
    String baseUrl = AppConfig.defaultBaseUrl,
    String apiKey = AppConfig.defaultApiKey,
    String model = AppConfig.defaultModel,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _model = model,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 5),
        ));

  String get baseUrl => _baseUrl;

  void updateConfig({String? baseUrl, String? apiKey, String? model}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (apiKey != null) _apiKey = apiKey;
    if (model != null) _model = model;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  /// Send a chat completion request and stream the response.
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    String? sessionId,
  }) async* {
    final body = {
      'model': _model,
      'messages': messages,
      'stream': true,
    };

    final headers = Map<String, String>.from(_headers);
    headers['Accept'] = 'text/event-stream';
    if (sessionId != null) {
      headers['X-Hermes-Session-Id'] = sessionId;
    }

    final response = await _dio.post<ResponseBody>(
      '$_baseUrl/v1/chat/completions',
      data: body,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
    );

    final rawStream = response.data!.stream;
    final stream = rawStream
        .map((bytes) => utf8.decode(bytes))
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith(AppConfig.sseDataPrefix)) {
        final data = line.substring(AppConfig.sseDataPrefix.length);
        if (data == AppConfig.sseDoneMessage) break;

        try {
          final json = jsonDecode(data);
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'];
            if (delta != null && delta['content'] != null) {
              yield delta['content'] as String;
            }
          }
        } catch (_) {
          // Skip malformed SSE lines
        }
      }
    }
  }

  /// Check if the API server is reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('$_baseUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
