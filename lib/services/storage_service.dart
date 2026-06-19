import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/conversation.dart';
import '../models/folder.dart';
import '../models/message.dart';

/// SQLite-backed persistence for folders, conversations, and messages.
class StorageService {
  static const String _dbName = 'hermes.db';
  static const int _schemaVersion = 2;

  static const String _tableFolders = 'folders';
  static const String _tableConversations = 'conversations';
  static const String _tableMessages = 'messages';

  Database? _db;

  Future<void> open({String? databasePath}) async {
    if (_db != null) return;
    final path = databasePath ?? await _defaultPath();
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

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
    await db.execute('''CREATE TABLE $_tableFolders (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT,
      sort_order INTEGER DEFAULT 0, created_at TEXT NOT NULL,
      FOREIGN KEY (parent_id) REFERENCES $_tableFolders(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE $_tableConversations (
      id TEXT PRIMARY KEY, title TEXT NOT NULL,
      folder_id TEXT, server_id TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY (folder_id) REFERENCES $_tableFolders(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE $_tableMessages (
      id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL,
      content TEXT NOT NULL, role TEXT NOT NULL, timestamp TEXT NOT NULL,
      FOREIGN KEY (conversation_id) REFERENCES $_tableConversations(id) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX idx_msg_conv ON $_tableMessages(conversation_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''CREATE TABLE $_tableFolders (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT,
        sort_order INTEGER DEFAULT 0, created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES $_tableFolders(id) ON DELETE CASCADE
      )''');
      try {
        await db.execute('ALTER TABLE $_tableConversations ADD COLUMN folder_id TEXT');
        await db.execute('ALTER TABLE $_tableConversations ADD COLUMN server_id TEXT');
      } catch (_) {}
    }
  }

  Future<Database> _requireDb() async {
    if (_db == null) await open();
    return _db!;
  }

  // ─────────────────────────── folders ───────────────────────────

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final db = await _requireDb();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final f = Folder(id: id, name: name, parentId: parentId, createdAt: DateTime.now());
    await db.insert(_tableFolders, f.toMap());
    return f;
  }

  Future<List<Folder>> listFolders({String? parentId}) async {
    final db = await _requireDb();
    final rows = parentId == null
        ? await db.query(_tableFolders, where: 'parent_id IS NULL', orderBy: 'sort_order')
        : await db.query(_tableFolders, where: 'parent_id = ?', whereArgs: [parentId], orderBy: 'sort_order');
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<Folder>> allFolders() async {
    final db = await _requireDb();
    final rows = await db.query(_tableFolders, orderBy: 'sort_order');
    return rows.map(Folder.fromMap).toList();
  }

  Future<void> renameFolder(String id, String name) async {
    final db = await _requireDb();
    await db.update(_tableFolders, {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveFolder(String id, String? parentId) async {
    final db = await _requireDb();
    await db.update(_tableFolders, {'parent_id': parentId}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFolder(String id) async {
    final db = await _requireDb();
    await db.delete(_tableFolders, where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────── conversations ────────────────────────

  Future<Conversation> createConversation({
    required String title,
    String? folderId,
    String? serverId,
  }) async {
    final db = await _requireDb();
    final now = DateTime.now();
    final conv = Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      folderId: folderId,
      serverId: serverId,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(_tableConversations, conv.toMap());
    return conv;
  }

  Future<List<Conversation>> listConversations({String? folderId, String? serverId}) async {
    final db = await _requireDb();
    String where = '1=1';
    List<dynamic> args = [];
    if (folderId != null) {
      where += ' AND folder_id = ?';
      args.add(folderId);
    }
    if (serverId != null) {
      where += ' AND server_id = ?';
      args.add(serverId);
    }
    final rows = await db.rawQuery('''SELECT c.*, (SELECT COUNT(*) FROM $_tableMessages m
      WHERE m.conversation_id = c.id) AS message_count
      FROM $_tableConversations c WHERE $where ORDER BY c.updated_at DESC''', args);
    return rows.map(Conversation.fromMap).toList();
  }

  Future<List<Conversation>> allConversations() async {
    final db = await _requireDb();
    final rows = await db.rawQuery('''SELECT c.*, (SELECT COUNT(*) FROM $_tableMessages m
      WHERE m.conversation_id = c.id) AS message_count
      FROM $_tableConversations c ORDER BY c.updated_at DESC''');
    return rows.map(Conversation.fromMap).toList();
  }

  Future<void> updateConversationFolder(String convId, String? folderId) async {
    final db = await _requireDb();
    await db.update(_tableConversations, {'folder_id': folderId}, where: 'id = ?', whereArgs: [convId]);
  }

  Future<void> renameConversation(String id, String title) async {
    final db = await _requireDb();
    await db.update(_tableConversations, {'title': title}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> touchConversation(String id, {DateTime? at}) async {
    final db = await _requireDb();
    await db.update(_tableConversations, {'updated_at': (at ?? DateTime.now()).toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteConversation(String id) async {
    final db = await _requireDb();
    await db.delete(_tableConversations, where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────── messages ───────────────────────────

  Future<void> addMessage(String conversationId, Message msg) async {
    final db = await _requireDb();
    await db.insert(_tableMessages, {
      'id': msg.id, 'conversation_id': conversationId,
      'content': msg.content, 'role': msg.role.name,
      'timestamp': msg.timestamp.toIso8601String(),
    });
    await db.update(_tableConversations, {'updated_at': msg.timestamp.toIso8601String()},
        where: 'id = ?', whereArgs: [conversationId]);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await _requireDb();
    final rows = await db.query(_tableMessages,
        where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'timestamp ASC');
    return rows.map(Message.fromMap).toList();
  }
}
