import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/models/server_config.dart';

void main() {
  group('ServerConfig', () {
    test('creates with required fields', () {
      final s = ServerConfig(
        id: 's1',
        name: 'Test',
        baseUrl: 'http://test:8642',
      );
      expect(s.id, 's1');
      expect(s.name, 'Test');
      expect(s.baseUrl, 'http://test:8642');
      expect(s.apiKey, '');
    });

    test('creates with all fields', () {
      final s = ServerConfig(
        id: 's1',
        name: 'Test',
        baseUrl: 'http://test:8642',
        apiKey: 'key123',
      );
      expect(s.apiKey, 'key123');
    });

    test('copyWith updates name', () {
      final s = ServerConfig(id: '1', name: 'Old', baseUrl: 'http://a');
      final updated = s.copyWith(name: 'New');
      expect(updated.name, 'New');
      expect(updated.id, '1');
      expect(updated.baseUrl, 'http://a');
    });

    test('toJson and fromJson are inverses', () {
      final s = ServerConfig(
        id: 'abc',
        name: 'My Server',
        baseUrl: 'http://10.0.0.1:8642',
        apiKey: 'secret',
      );
      final restored = ServerConfig.fromJson(s.toJson());
      expect(restored.id, s.id);
      expect(restored.name, s.name);
      expect(restored.baseUrl, s.baseUrl);
      expect(restored.apiKey, s.apiKey);
    });

    test('fromJson with missing api_key defaults to empty', () {
      final s = ServerConfig.fromJson({
        'id': '1',
        'name': 'Test',
        'base_url': 'http://x',
      });
      expect(s.apiKey, '');
    });

    test('defaultServer has sensible values', () {
      final s = ServerConfig.defaultServer();
      expect(s.id, 'default');
      expect(s.name, 'Local');
      expect(s.baseUrl, 'http://localhost:8642');
      expect(s.apiKey, 'hermes-mobile-dev');
    });
  });

  group('ApiService config', () {
    // Test that ApiService.updateConfig works correctly
    // (tests in api_service_test.dart cover this)
  });
}
