import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/message.dart';
import 'package:hermes_mobile/models/conversation.dart';
import 'package:hermes_mobile/config/app_config.dart';

void main() {
  group('Message', () {
    test('creates user message with correct defaults', () {
      final msg = Message(
        id: '1',
        content: 'Hello',
        role: MessageRole.user,
        timestamp: DateTime(2026, 6, 15),
      );
      expect(msg.id, '1');
      expect(msg.content, 'Hello');
      expect(msg.role, MessageRole.user);
      expect(msg.isStreaming, false);
    });

    test('creates assistant message with streaming', () {
      final msg = Message(
        id: '2',
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime(2026),
        isStreaming: true,
      );
      expect(msg.isStreaming, true);
      expect(msg.content, '');
    });

    test('copyWith updates content and streaming flag', () {
      final msg = Message(
        id: '1',
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime(2026),
        isStreaming: true,
      );
      final updated = msg.copyWith(content: 'Hi', isStreaming: false);
      expect(updated.content, 'Hi');
      expect(updated.isStreaming, false);
      expect(updated.id, msg.id);
      expect(updated.role, msg.role);
    });

    test('toMap and fromMap are inverses', () {
      final msg = Message(
        id: 'abc-123',
        content: 'Test message',
        role: MessageRole.assistant,
        timestamp: DateTime(2026, 6, 15, 10, 30),
      );
      final restored = Message.fromMap(msg.toMap());
      expect(restored.id, msg.id);
      expect(restored.content, msg.content);
      expect(restored.role, msg.role);
      expect(restored.timestamp, msg.timestamp);
    });

    test('MessageRole.fromString handles all valid roles', () {
      expect(MessageRole.fromString('user'), MessageRole.user);
      expect(MessageRole.fromString('assistant'), MessageRole.assistant);
      expect(MessageRole.fromString('system'), MessageRole.system);
    });

    test('MessageRole.fromString falls back to user for invalid', () {
      expect(MessageRole.fromString('unknown'), MessageRole.user);
      expect(MessageRole.fromString(''), MessageRole.user);
    });
  });

  group('Conversation', () {
    test('toMap and fromMap are inverses', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Test Chat',
        createdAt: DateTime(2026, 6, 15),
        updatedAt: DateTime(2026, 6, 15, 12, 0),
        messageCount: 5,
      );
      final restored = Conversation.fromMap(conv.toMap());
      expect(restored.id, conv.id);
      expect(restored.title, conv.title);
      expect(restored.createdAt, conv.createdAt);
      expect(restored.updatedAt, conv.updatedAt);
    });

    test('default messageCount is 0', () {
      final conv = Conversation(
        id: 'c1',
        title: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(conv.messageCount, 0);
    });
  });

  group('AppConfig', () {
    test('defaultBaseUrl is localhost:8642', () {
      expect(AppConfig.defaultBaseUrl, 'http://localhost:8642');
    });

    test('defaultApiKey is hermes-mobile-dev', () {
      expect(AppConfig.defaultApiKey, 'hermes-mobile-dev');
    });

    test('defaultModel is hermes-agent', () {
      expect(AppConfig.defaultModel, 'hermes-agent');
    });

    test('sseDataPrefix and sseDoneMessage are correct', () {
      expect(AppConfig.sseDataPrefix, 'data: ');
      expect(AppConfig.sseDoneMessage, '[DONE]');
    });
  });
}
