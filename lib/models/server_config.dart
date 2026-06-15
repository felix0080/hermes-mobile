/// Configuration for a single Hermes API Server.
class ServerConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey = '',
  });

  ServerConfig copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'api_key': apiKey,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['base_url'] as String,
        apiKey: json['api_key'] as String? ?? '',
      );

  /// Default local server.
  static ServerConfig defaultServer() => const ServerConfig(
        id: 'default',
        name: 'Local',
        baseUrl: 'http://localhost:8642',
        apiKey: 'hermes-mobile-dev',
      );
}
