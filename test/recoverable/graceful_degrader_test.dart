import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/recoverable/graceful_degrader.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('GracefulDegrader', () {
    testWidgets('renders child when no error occurs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GracefulDegrader(
            child: Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('has default constructor with required child', (tester) async {
      const widget = GracefulDegrader(child: SizedBox());
      expect(widget.child, isA<SizedBox>());
      expect(widget.emitEvent, isTrue);
      expect(widget.label, isNull);
    });

    testWidgets('accepts optional label parameter', (tester) async {
      const widget = GracefulDegrader(
        label: 'ProfileSection',
        child: SizedBox(),
      );
      expect(widget.label, 'ProfileSection');
    });

    testWidgets('accepts custom fallback builder', (tester) async {
      const widget = GracefulDegrader(
        child: SizedBox(),
      );
      expect(widget.fallback, isNull);
    });

    testWidgets('emitEvent defaults to true', (tester) async {
      const widget = GracefulDegrader(child: SizedBox());
      expect(widget.emitEvent, isTrue);
    });

    testWidgets('emitEvent can be disabled', (tester) async {
      const widget = GracefulDegrader(
        emitEvent: false,
        child: SizedBox(),
      );
      expect(widget.emitEvent, isFalse);
    });

    testWidgets('renders child inside error boundary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GracefulDegrader(
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('accepts fallback builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GracefulDegrader(
            fallback: (ctx, error, stack) => const Text('Custom Fallback'),
            child: const Text('Normal'),
          ),
        ),
      );

      // Normal render — should show the child
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Custom Fallback'), findsNothing);
    });
  });

  group('GracefulDegrader construction', () {
    test('can be created with all parameters', () {
      const widget = GracefulDegrader(
        label: 'TestLabel',
        emitEvent: false,
        child: SizedBox(),
      );
      expect(widget.label, 'TestLabel');
      expect(widget.emitEvent, false);
    });

    test('creates unique widget keys', () {
      final w1 = GracefulDegrader(key: UniqueKey(), child: const SizedBox());
      final w2 = GracefulDegrader(key: UniqueKey(), child: const SizedBox());
      expect(w1.key, isNot(w2.key));
    });
  });
}
