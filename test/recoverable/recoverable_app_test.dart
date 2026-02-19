import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/recoverable/recoverable_app.dart';
import 'package:flutter_debug_trinity/recoverable/error_fingerprint.dart';
import 'package:flutter_debug_trinity/recoverable/error_interceptor.dart';
import 'package:flutter_debug_trinity/recoverable/snapshot_manager.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    ErrorInterceptor.debugReset();
  });

  group('RecoverableApp', () {
    group('normal rendering', () {
      testWidgets('renders child when no crash occurred', (tester) async {
        await tester.pumpWidget(
          const RecoverableApp(
            autoInitialize: false,
            child: MaterialApp(
              home: Scaffold(body: Text('Hello World')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello World'), findsOneWidget);
      });

      testWidgets('renders child widget directly', (tester) async {
        const key = Key('child');
        await tester.pumpWidget(
          const RecoverableApp(
            autoInitialize: false,
            child: MaterialApp(
              home: Scaffold(body: SizedBox(key: key)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(key), findsOneWidget);
      });

      testWidgets('autoInitialize: false does not throw', (tester) async {
        await tester.pumpWidget(
          const RecoverableApp(
            autoInitialize: false,
            child: MaterialApp(home: Scaffold(body: Text('test'))),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('test'), findsOneWidget);
      });
    });

    group('RecoveryState model', () {
      test('can be constructed with required fields', () {
        final state = RecoveryState(
          error: Exception('crash'),
          stackTrace: StackTrace.current,
          fingerprint: const ErrorFingerprint(
            hash: 'abc123',
            errorType: 'Exception',
            topFrames: ['frame1', 'frame2'],
          ),
          severity: ErrorSeverity.fatal,
        );

        expect(state.error, isA<Exception>());
        expect(state.isInCrashLoop, isFalse);
        expect(state.lastSnapshot, isNull);
      });

      test('isInCrashLoop defaults to false', () {
        final state = RecoveryState(
          error: Exception('e'),
          stackTrace: StackTrace.current,
          fingerprint: const ErrorFingerprint(
            hash: 'h',
            errorType: 'Exception',
            topFrames: [],
          ),
          severity: ErrorSeverity.recoverable,
        );
        expect(state.isInCrashLoop, isFalse);
      });

      test('isInCrashLoop can be set to true', () {
        final state = RecoveryState(
          error: Exception('loop'),
          stackTrace: StackTrace.current,
          fingerprint: const ErrorFingerprint(
            hash: 'loop',
            errorType: 'Exception',
            topFrames: [],
          ),
          severity: ErrorSeverity.fatal,
          isInCrashLoop: true,
        );
        expect(state.isInCrashLoop, isTrue);
      });

      test('can store lastSnapshot', () {
        final snap = AppSnapshot(
          snapshotId: 'snap-1',
          routeStack: ['/home'],
          scrollPositions: {},
          formInputs: {},
          customState: {},
          timestamp: DateTime(2024, 1, 1),
        );

        final state = RecoveryState(
          error: Exception('e'),
          stackTrace: StackTrace.current,
          fingerprint: const ErrorFingerprint(
            hash: 'h',
            errorType: 'Exception',
            topFrames: [],
          ),
          severity: ErrorSeverity.recoverable,
          lastSnapshot: snap,
        );
        expect(state.lastSnapshot, isNotNull);
        expect(state.lastSnapshot!.snapshotId, 'snap-1');
      });
    });

    group('custom recovery screen', () {
      testWidgets('custom recoveryScreenBuilder is used when set',
          (tester) async {
        const customText = 'Custom Recovery Screen';
        Widget? builtWidget;

        await tester.pumpWidget(
          RecoverableApp(
            autoInitialize: false,
            recoveryScreenBuilder: (context, state, onRestart, onStartFresh) {
              builtWidget = const Text(customText);
              return const MaterialApp(
                home: Scaffold(body: Text(customText)),
              );
            },
            child: const MaterialApp(
              home: Scaffold(body: Text('child')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Without a crash, child is shown (builder not invoked yet)
        expect(find.text('child'), findsOneWidget);
        expect(builtWidget, isNull);
      });
    });

    group('SnapshotSerializer interface', () {
      test('can implement SnapshotSerializer', () {
        final serializer = _TestSnapshotSerializer();
        expect(serializer.serialize(), isA<Map<String, dynamic>>());
      });

      test('restore can be implemented', () {
        final serializer = _TestSnapshotSerializer();
        // No exception thrown
        expect(() => serializer.restore({'key': 'value'}), returnsNormally);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSnapshotSerializer implements SnapshotSerializer {
  @override
  Map<String, dynamic> serialize() => {'key': 'value'};

  @override
  void restore(Map<String, dynamic> data) {}
}
