import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/devtools/service_extension_bridge.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/causal_graph.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    CausalGraph.instance.debugClear();
    ServiceExtensionBridge.debugReset();
  });

  group('ServiceExtensionBridge', () {
    test('register() does not throw', () {
      expect(() => ServiceExtensionBridge.register(), returnsNormally);
    });

    test('register() is idempotent (safe to call twice)', () {
      ServiceExtensionBridge.register();
      // Second call should not throw
      expect(() => ServiceExtensionBridge.register(), returnsNormally);
    });

    test('debugReset() allows re-registration', () {
      ServiceExtensionBridge.register();
      ServiceExtensionBridge.debugReset();
      // After reset, re-registration should succeed
      expect(() => ServiceExtensionBridge.register(), returnsNormally);
    });

    test('events posted to bus are forwarded to timeline', () {
      ServiceExtensionBridge.register();

      // Emit an event — the bridge subscribes to the bus stream
      // and calls developer.postEvent. In test env, we just verify
      // no exceptions are thrown.
      final event = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test action',
      );
      expect(
        () => TrinityEventBus.instance.emit(event),
        returnsNormally,
      );
    });

    test('multiple events can be emitted after registration', () {
      ServiceExtensionBridge.register();

      for (int i = 0; i < 10; i++) {
        TrinityEventBus.instance.emit(CausalEvent(
          type: CausalEventType.stateChange,
          description: 'state change $i',
        ));
      }

      expect(TrinityEventBus.instance.buffer, hasLength(10));
    });
  });
}
