/// A folder in the conversation hierarchy tree.
class Folder {
  final String id;
  final String name;
  final String? parentId; // null = root level
  final DateTime createdAt;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  Folder copyWith({String? name, String? parentId}) => Folder(
        id: id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
        id: map['id'] as String,
        name: map['name'] as String,
        parentId: map['parent_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
