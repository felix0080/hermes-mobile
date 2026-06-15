import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/services/api_service.dart';

void main() {
  group('ApiService', () {
    test('constructs with default config', () {
      final api = ApiService();
      expect(api.baseUrl, 'http://localhost:8642');
    });

    test('constructs with custom config', () {
      final api = ApiService(
        baseUrl: 'http://192.168.1.100:8642',
        apiKey: 'test-key',
      );
      expect(api.baseUrl, 'http://192.168.1.100:8642');
    });

    test('updateConfig changes baseUrl', () {
      final api = ApiService();
      api.updateConfig(baseUrl: 'http://new-host:8642');
      expect(api.baseUrl, 'http://new-host:8642');
    });

    test('updateConfig with partial args preserves others', () {
      final api = ApiService(baseUrl: 'http://a:8642', apiKey: 'k1');
      api.updateConfig(apiKey: 'k2');
      expect(api.baseUrl, 'http://a:8642');
    });

    test('updateConfig ignores null args', () {
      final api = ApiService(baseUrl: 'http://orig:8642');
      api.updateConfig();
      expect(api.baseUrl, 'http://orig:8642');
    });
  });
}
