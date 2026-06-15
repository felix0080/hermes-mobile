import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/message.dart';

void main() {
  group('Message', () {
    test('creates user message correctly', () {
      final msg = Message(
        id: '1',
        content: 'Hello',
        role: MessageRole.user,
        timestamp: DateTime(2026, 6, 15),
      );

      expect(msg.role, MessageRole.user);
      expect(msg.content, 'Hello');
      expect(msg.isStreaming, false);
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
    });

    test('toMap and fromMap are inverses', () {
      final msg = Message(
        id: 'abc-123',
        content: 'Test message',
        role: MessageRole.assistant,
        timestamp: DateTime(2026, 6, 15, 10, 30),
      );

      final map = msg.toMap();
      final restored = Message.fromMap(map);

      expect(restored.id, msg.id);
      expect(restored.content, msg.content);
      expect(restored.role, msg.role);
      expect(restored.timestamp, msg.timestamp);
    });

    test('MessageRole.fromString handles all roles', () {
      expect(MessageRole.fromString('user'), MessageRole.user);
      expect(MessageRole.fromString('assistant'), MessageRole.assistant);
      expect(MessageRole.fromString('system'), MessageRole.system);
      expect(MessageRole.fromString('unknown'), MessageRole.user);
    });
  });
}
