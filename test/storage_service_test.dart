import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'package:hermes_mobile/services/storage_service.dart';
import 'package:hermes_mobile/models/message.dart';
import 'package:hermes_mobile/models/conversation.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<StorageService> freshStorage() async {
    final storage = StorageService();
    await storage.open(databasePath: inMemoryDatabasePath);
    return storage;
  }

  group('StorageService - conversations', () {
    test('createConversation persists and returns conversation', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'Hello chat');

      expect(conv.id, isNotEmpty);
      expect(conv.title, 'Hello chat');
      expect(conv.createdAt, conv.updatedAt);
    });

    test('listConversations returns sorted by updatedAt DESC', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final first = await storage.createConversation(title: 'first');
      // Ensure different timestamps (DateTime.now() resolution may match)
      await Future.delayed(const Duration(milliseconds: 10));
      final second = await storage.createConversation(title: 'second');
      await storage.touchConversation(first.id,
          at: DateTime.now().add(const Duration(minutes: 1)));

      final list = await storage.listConversations();

      expect(list.length, 2);
      expect(list.first.id, first.id);
      expect(list.last.id, second.id);
    });

    test('listConversations includes message counts', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'counted');
      await storage.addMessage(
        conv.id,
        Message(
          id: 'm1',
          content: 'hi',
          role: MessageRole.user,
          timestamp: DateTime.now(),
        ),
      );
      await storage.addMessage(
        conv.id,
        Message(
          id: 'm2',
          content: 'hello',
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
        ),
      );

      final list = await storage.listConversations();
      expect(list.single.messageCount, 2);
    });

    test('deleteConversation removes conversation and its messages', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'doomed');
      await storage.addMessage(
        conv.id,
        Message(
          id: 'm1',
          content: 'msg',
          role: MessageRole.user,
          timestamp: DateTime.now(),
        ),
      );

      await storage.deleteConversation(conv.id);

      final list = await storage.listConversations();
      expect(list, isEmpty);

      final messages = await storage.getMessages(conv.id);
      expect(messages, isEmpty);
    });

    test('renameConversation updates title', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'old');

      await storage.renameConversation(conv.id, 'new title');

      final list = await storage.listConversations();
      expect(list.single.title, 'new title');
    });
  });

  group('StorageService - messages', () {
    test('addMessage persists and getMessages returns ordered ASC', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'c');

      final t1 = DateTime(2026, 6, 15, 10, 0, 0);
      final t2 = DateTime(2026, 6, 15, 10, 0, 1);

      await storage.addMessage(
        conv.id,
        Message(
          id: 'a',
          content: 'second',
          role: MessageRole.assistant,
          timestamp: t2,
        ),
      );
      await storage.addMessage(
        conv.id,
        Message(
          id: 'u',
          content: 'first',
          role: MessageRole.user,
          timestamp: t1,
        ),
      );

      final messages = await storage.getMessages(conv.id);
      expect(messages.map((m) => m.id).toList(), ['u', 'a']);
    });

    test('addMessage touches conversation updatedAt', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'c');
      final later = DateTime.now().add(const Duration(hours: 1));

      await storage.addMessage(
        conv.id,
        Message(
          id: 'm',
          content: 'msg',
          role: MessageRole.user,
          timestamp: later,
        ),
      );

      final list = await storage.listConversations();
      expect(list.single.updatedAt.difference(later).inSeconds, lessThan(1));
    });

    test('getMessages for unknown conversation returns empty', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final messages = await storage.getMessages('does-not-exist');
      expect(messages, isEmpty);
    });

    test('persisted messages round-trip role and content', () async {
      final storage = await freshStorage();
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'c');
      final original = Message(
        id: 'x',
        content: 'Hello world',
        role: MessageRole.assistant,
        timestamp: DateTime(2026, 6, 15, 10, 30),
      );
      await storage.addMessage(conv.id, original);

      final restored = (await storage.getMessages(conv.id)).single;
      expect(restored.id, original.id);
      expect(restored.content, original.content);
      expect(restored.role, MessageRole.assistant);
      expect(restored.timestamp, original.timestamp);
    });
  });

  group('StorageService - schema', () {
    test('open is idempotent', () async {
      final storage = StorageService();
      await storage.open(databasePath: inMemoryDatabasePath);
      await storage.open(databasePath: inMemoryDatabasePath);
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'still works');
      expect(conv.id, isNotEmpty);
    });

    test('close allows reopen', () async {
      final storage = StorageService();
      await storage.open(databasePath: inMemoryDatabasePath);
      await storage.close();
      await storage.open(databasePath: inMemoryDatabasePath);
      addTearDown(storage.close);

      final conv = await storage.createConversation(title: 'reopened');
      expect(conv.id, isNotEmpty);
    });
  });

  // Unused import guard: keep sqlite_api referenced for the factory override.
  test('databaseFactory override is set', () {
    expect(databaseFactory, isNotNull);
  });
}
