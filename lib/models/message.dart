class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isStreaming;
  final List<String> imagePaths;

  const Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
    this.imagePaths = const [],
  });

  Message copyWith({
    String? content,
    bool? isStreaming,
    List<String>? imagePaths,
  }) {
    return Message(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'role': role.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        content: map['content'] as String,
        role: MessageRole.fromString(map['role'] as String),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

enum MessageRole {
  user,
  assistant,
  system;

  static MessageRole fromString(String s) => MessageRole.values.firstWhere(
        (e) => e.name == s,
        orElse: () => MessageRole.user,
      );
}
