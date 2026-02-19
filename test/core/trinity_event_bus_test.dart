import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('TrinityEventBus', () {
    test('is a singleton', () {
      final a = TrinityEventBus.instance;
      final b = TrinityEventBus.instance;
      expect(identical(a, b), isTrue);
    });

    test('emit adds event to buffer', () {
      final event = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      );
      TrinityEventBus.instance.emit(event);
      expect(TrinityEventBus.instance.buffer, contains(event));
    });

    test('stream receives emitted events', () async {
      final completer = Completer<CausalEvent>();
      final sub = TrinityEventBus.instance.stream.listen(
        (e) => completer.complete(e),
      );

      final event = CausalEvent(
        type: CausalEventType.stateChange,
        description: 'stream test',
      );
      TrinityEventBus.instance.emit(event);

      final received = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(received.id, event.id);
      await sub.cancel();
    });

    test('buffer is bounded at 500', () {
      for (int i = 0; i < 600; i++) {
        TrinityEventBus.instance.emit(CausalEvent(
          type: CausalEventType.custom,
          description: 'event $i',
        ));
      }
      expect(TrinityEventBus.instance.buffer.length, 500);
      // First event should be #100 (0-99 evicted)
      expect(
        TrinityEventBus.instance.buffer.first.description,
        'event 100',
      );
    });

    test('buffer is unmodifiable', () {
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      ));
      expect(
        () => TrinityEventBus.instance.buffer.add(CausalEvent(
          type: CausalEventType.custom,
          description: 'hack',
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('bufferWhere filters by type', () {
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'action',
      ));
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.networkEvent,
        description: 'request',
      ));
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'action2',
      ));

      final actions =
          TrinityEventBus.instance.bufferWhere(CausalEventType.userAction);
      expect(actions, hasLength(2));
      expect(
          actions.every((e) => e.type == CausalEventType.userAction), isTrue);
    });

    test('debugClear empties buffer', () {
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      ));
      expect(TrinityEventBus.instance.buffer, isNotEmpty);

      TrinityEventBus.instance.debugClear();
      expect(TrinityEventBus.instance.buffer, isEmpty);
    });

    test('multiple subscribers receive same event', () async {
      final c1 = Completer<CausalEvent>();
      final c2 = Completer<CausalEvent>();

      final sub1 = TrinityEventBus.instance.stream.listen(
        (e) {
          if (!c1.isCompleted) c1.complete(e);
        },
      );
      final sub2 = TrinityEventBus.instance.stream.listen(
        (e) {
          if (!c2.isCompleted) c2.complete(e);
        },
      );

      final event = CausalEvent(
        type: CausalEventType.userAction,
        description: 'broadcast test',
      );
      TrinityEventBus.instance.emit(event);

      final r1 = await c1.future.timeout(const Duration(seconds: 1));
      final r2 = await c2.future.timeout(const Duration(seconds: 1));
      expect(r1.id, event.id);
      expect(r2.id, event.id);

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
