import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/conversation.dart';
import '../models/message.dart';

/// SQLite-backed persistence for conversations and messages.
///
/// Schema:
///   conversations(id TEXT PK, title, created_at, updated_at)
///   messages(id TEXT PK, conversation_id FK, content, role, timestamp)
class StorageService {
  static const String _dbName = 'hermes.db';
  static const int _schemaVersion = 1;

  static const String _tableConversations = 'conversations';
  static const String _tableMessages = 'messages';

  Database? _db;

  /// Open (or reuse) the underlying database. Pass [databasePath] to override
  /// the default location — primarily for tests.
  Future<void> open({String? databasePath}) async {
    if (_db != null) return;
    final path = databasePath ?? await _defaultPath();
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  /// Close the database. Safe to call multiple times; subsequent [open] will
  /// re-create the handle.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableConversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tableMessages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        content TEXT NOT NULL,
        role TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (conversation_id)
          REFERENCES $_tableConversations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_messages_conversation_id
        ON $_tableMessages(conversation_id)
    ''');
  }

  Future<Database> _requireDb() async {
    if (_db == null) await open();
    return _db!;
  }

  // --------------------------- conversations ---------------------------

  /// Insert a new conversation row and return the inserted record.
  Future<Conversation> createConversation({required String title}) async {
    final db = await _requireDb();
    final now = DateTime.now();
    final conv = Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(_tableConversations, conv.toMap());
    return conv;
  }

  /// List all conversations sorted by updatedAt DESC, with message counts.
  Future<List<Conversation>> listConversations() async {
    final db = await _requireDb();
    final rows = await db.rawQuery('''
      SELECT c.id AS id,
             c.title AS title,
             c.created_at AS created_at,
             c.updated_at AS updated_at,
             (SELECT COUNT(*) FROM $_tableMessages m
               WHERE m.conversation_id = c.id) AS message_count
      FROM $_tableConversations c
      ORDER BY c.updated_at DESC
    ''');
    return rows.map(Conversation.fromMap).toList();
  }

  /// Rename a conversation. No-op if [id] does not exist.
  Future<void> renameConversation(String id, String title) async {
    final db = await _requireDb();
    await db.update(
      _tableConversations,
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Bump updatedAt on a conversation. Used to re-sort after activity.
  Future<void> touchConversation(String id, {DateTime? at}) async {
    final db = await _requireDb();
    await db.update(
      _tableConversations,
      {'updated_at': (at ?? DateTime.now()).toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a conversation and its messages (via cascade).
  Future<void> deleteConversation(String id) async {
    final db = await _requireDb();
    await db.delete(
      _tableConversations,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------ messages -----------------------------

  /// Persist a message and update its parent conversation's updatedAt.
  Future<void> addMessage(String conversationId, Message msg) async {
    final db = await _requireDb();
    await db.insert(_tableMessages, {
      'id': msg.id,
      'conversation_id': conversationId,
      'content': msg.content,
      'role': msg.role.name,
      'timestamp': msg.timestamp.toIso8601String(),
    });
    await db.update(
      _tableConversations,
      {'updated_at': msg.timestamp.toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Fetch all messages for a conversation ordered by timestamp ASC.
  Future<List<Message>> getMessages(String conversationId) async {
    final db = await _requireDb();
    final rows = await db.query(
      _tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(Message.fromMap).toList();
  }
}
