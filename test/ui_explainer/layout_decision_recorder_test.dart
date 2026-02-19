import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/ui_explainer/layout_decision_recorder.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    LayoutDecisionRecorder.instance.debugClear();
    TrinityEventBus.instance.debugClear();
  });

  group('LayoutDecision', () {
    test('creates with all required fields', () {
      final decision = LayoutDecision(
        widgetType: 'RenderFlex',
        constraintsReceived:
            const BoxConstraints(maxWidth: 400, maxHeight: 800),
        sizeReported: const Size(500, 100),
        overflowed: true,
        timestamp: DateTime.now(),
      );
      expect(decision.widgetType, 'RenderFlex');
      expect(decision.overflowed, isTrue);
      expect(decision.causalEventId, isNull);
    });

    test('toString includes widget type and size', () {
      final decision = LayoutDecision(
        widgetType: 'RenderParagraph',
        constraintsReceived: const BoxConstraints(maxWidth: 200),
        sizeReported: const Size(300, 20),
        overflowed: true,
        timestamp: DateTime.now(),
      );
      expect(decision.toString(), contains('RenderParagraph'));
      expect(decision.toString(), contains('overflowed=true'));
    });
  });

  group('LayoutDecisionRecorder', () {
    test('is a singleton', () {
      final a = LayoutDecisionRecorder.instance;
      final b = LayoutDecisionRecorder.instance;
      expect(identical(a, b), isTrue);
    });

    test('records decisions to buffer', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Test',
        constraintsReceived: const BoxConstraints(maxWidth: 100),
        sizeReported: const Size(50, 50),
        overflowed: false,
        timestamp: DateTime.now(),
      ));
      expect(LayoutDecisionRecorder.instance.buffer, hasLength(1));
    });

    test('buffer is bounded at 200', () {
      for (int i = 0; i < 250; i++) {
        LayoutDecisionRecorder.instance.record(LayoutDecision(
          widgetType: 'Widget$i',
          constraintsReceived: const BoxConstraints(),
          sizeReported: const Size(10, 10),
          overflowed: false,
          timestamp: DateTime.now(),
        ));
      }
      expect(LayoutDecisionRecorder.instance.buffer.length, 200);
    });

    test('overflows filter returns only overflowed decisions', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Normal',
        constraintsReceived: const BoxConstraints(maxWidth: 100),
        sizeReported: const Size(50, 50),
        overflowed: false,
        timestamp: DateTime.now(),
      ));
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Overflowed',
        constraintsReceived: const BoxConstraints(maxWidth: 100),
        sizeReported: const Size(200, 50),
        overflowed: true,
        timestamp: DateTime.now(),
      ));

      expect(LayoutDecisionRecorder.instance.overflows, hasLength(1));
      expect(LayoutDecisionRecorder.instance.overflows.first.widgetType,
          'Overflowed');
    });

    test('overflow emits event to TrinityEventBus', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'RenderFlex',
        constraintsReceived:
            const BoxConstraints(maxWidth: 300, maxHeight: 600),
        sizeReported: const Size(500, 100),
        overflowed: true,
        timestamp: DateTime.now(),
      ));

      final events = TrinityEventBus.instance.buffer;
      expect(events, isNotEmpty);
      expect(events.last.description, contains('RenderFlex'));
      expect(events.last.description, contains('overflow'));
    });

    test('non-overflow does not emit to bus', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Normal',
        constraintsReceived: const BoxConstraints(maxWidth: 500),
        sizeReported: const Size(100, 100),
        overflowed: false,
        timestamp: DateTime.now(),
      ));
      expect(TrinityEventBus.instance.buffer, isEmpty);
    });

    test('debugClear empties buffer', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Test',
        constraintsReceived: const BoxConstraints(),
        sizeReported: const Size(10, 10),
        overflowed: false,
        timestamp: DateTime.now(),
      ));
      expect(LayoutDecisionRecorder.instance.buffer, isNotEmpty);

      LayoutDecisionRecorder.instance.debugClear();
      expect(LayoutDecisionRecorder.instance.buffer, isEmpty);
    });

    test('buffer is unmodifiable', () {
      expect(
        () => LayoutDecisionRecorder.instance.buffer.add(LayoutDecision(
          widgetType: 'Hack',
          constraintsReceived: const BoxConstraints(),
          sizeReported: const Size(0, 0),
          overflowed: false,
          timestamp: DateTime.now(),
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
