/// Application configuration constants.
class AppConfig {
  AppConfig._();

  /// Default Hermes API Server URL.
  static const String defaultBaseUrl = 'http://localhost:8642';

  /// Default API key for local dev.
  static const String defaultApiKey = 'hermes-mobile-dev';

  /// Default model name sent to API.
  static const String defaultModel = 'hermes-agent';

  /// Streaming response chunk delimiter for SSE.
  static const String sseDataPrefix = 'data: ';
  static const String sseDoneMessage = '[DONE]';
}
