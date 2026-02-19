import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/causality/adapters/network_adapter.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('CausalityHttpClient', () {
    test('records request and response events', () async {
      final mockClient = http_testing.MockClient(
        (request) async => http.Response('{"ok": true}', 200),
      );
      final causalClient = CausalityHttpClient(mockClient);

      await causalClient.get(Uri.parse('https://api.example.com/data'));

      final events = TrinityEventBus.instance.buffer.where(
        (e) => e.type == CausalEventType.networkEvent,
      );

      // Should have request + response events
      expect(events.length, greaterThanOrEqualTo(2));

      final requestEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'request',
      );
      expect(requestEvent.description, contains('GET'));
      expect(requestEvent.metadata['url'], contains('api.example.com'));

      final responseEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'response',
      );
      expect(responseEvent.metadata['status_code'], 200);
      expect(responseEvent.description, contains('200'));
    });

    test('response links to request via parentId', () async {
      final mockClient = http_testing.MockClient(
        (request) async => http.Response('ok', 200),
      );
      final causalClient = CausalityHttpClient(mockClient);

      await causalClient.get(Uri.parse('https://api.example.com/users'));

      final events = TrinityEventBus.instance.buffer
          .where((e) => e.type == CausalEventType.networkEvent)
          .toList();

      final requestEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'request',
      );
      final responseEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'response',
      );

      expect(responseEvent.parentId, requestEvent.id);
    });

    test('records error events on failure', () async {
      final mockClient = http_testing.MockClient(
        (request) => Future.error(http.ClientException('Network down')),
      );
      final causalClient = CausalityHttpClient(mockClient);

      try {
        await causalClient.get(Uri.parse('https://api.example.com/fail'));
      } catch (_) {
        // Expected
      }

      final events = TrinityEventBus.instance.buffer.where(
        (e) => e.type == CausalEventType.networkEvent,
      );

      // At minimum, the request event should exist
      expect(events, isNotEmpty);
      final requestEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'request',
      );
      expect(requestEvent.description, contains('GET'));

      // Error event should also exist
      final errorEvents = events.where(
        (e) => e.metadata['phase'] == 'error',
      );
      expect(errorEvents, isNotEmpty);
    });

    test('records POST request with correct method', () async {
      final mockClient = http_testing.MockClient(
        (request) async => http.Response('created', 201),
      );
      final causalClient = CausalityHttpClient(mockClient);

      await causalClient.post(
        Uri.parse('https://api.example.com/items'),
        body: '{"name":"test"}',
      );

      final events = TrinityEventBus.instance.buffer.where(
        (e) => e.type == CausalEventType.networkEvent,
      );

      final requestEvent = events.firstWhere(
        (e) => e.metadata['phase'] == 'request',
      );
      expect(requestEvent.metadata['method'], 'POST');
      expect(requestEvent.description, contains('POST'));
    });
  });

  group('CausalityDioInterceptor', () {
    test('can be instantiated', () {
      final interceptor = CausalityDioInterceptor();
      expect(interceptor, isNotNull);
    });
  });
}
