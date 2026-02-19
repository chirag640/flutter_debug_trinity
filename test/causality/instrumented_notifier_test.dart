import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/context_zone.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/causality/adapters/instrumented_notifier.dart';

class TestService with InstrumentedNotifier {
  void doWork() {
    emitCause('work_started');
  }

  void doWorkWithMeta() {
    emitCause('work_done', metadata: {'key': 'value'});
  }

  void doCustomType() {
    emitCause('user_tapped', type: CausalEventType.userAction);
  }
}

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('InstrumentedNotifier', () {
    test('emitCause emits event to bus', () {
      final service = TestService();
      service.doWork();

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer, hasLength(1));
      expect(buffer.first.description, contains('TestService'));
      expect(buffer.first.description, contains('work_started'));
      expect(buffer.first.type, CausalEventType.stateChange);
    });

    test('emitCause includes metadata', () {
      final service = TestService();
      service.doWorkWithMeta();

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer.first.metadata['key'], 'value');
    });

    test('emitCause uses custom event type', () {
      final service = TestService();
      service.doCustomType();

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer.first.type, CausalEventType.userAction);
    });

    test('emitCause links to causal zone context', () async {
      final service = TestService();

      await CausalityZone.run('parent_context', () {
        service.doWork();
      });

      final buffer = TrinityEventBus.instance.buffer;
      // Zone context event + service event
      expect(buffer.length, greaterThanOrEqualTo(1));

      // The service event should have a parentId from the zone
      final serviceEvent = buffer.firstWhere(
        (e) => e.description.contains('work_started'),
      );
      expect(serviceEvent.parentId, isNotNull);
    });

    test('emitCause without zone sets parentId to null', () {
      final service = TestService();
      service.doWork();

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer.first.parentId, isNull);
    });

    test('multiple emitCause calls all recorded', () {
      final service = TestService();
      service.doWork();
      service.doWorkWithMeta();
      service.doCustomType();

      expect(TrinityEventBus.instance.buffer, hasLength(3));
    });
  });
}
