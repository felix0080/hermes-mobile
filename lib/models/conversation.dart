class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
    id: map['id'] as String,
    title: map['title'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    messageCount: map['message_count'] as int? ?? 0,
  );
}
