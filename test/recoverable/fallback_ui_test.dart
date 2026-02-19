import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/recoverable/fallback_ui.dart';
import 'package:flutter_debug_trinity/recoverable/error_fingerprint.dart';
import 'package:flutter_debug_trinity/recoverable/snapshot_manager.dart';

void main() {
  group('FallbackScreen', () {
    testWidgets('renders with default title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('An unexpected error occurred.'), findsOneWidget);
    });

    testWidgets('renders with custom title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            title: 'Oops!',
            subtitle: 'Please try again.',
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.text('Oops!'), findsOneWidget);
      expect(find.text('Please try again.'), findsOneWidget);
    });

    testWidgets('shows crash loop message when isInCrashLoop is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            isInCrashLoop: true,
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(
        find.textContaining('crashed multiple times'),
        findsOneWidget,
      );
    });

    testWidgets('shows fingerprint info when provided', (tester) async {
      const fingerprint = ErrorFingerprint(
        hash: 'abc123',
        errorType: 'TestError',
        topFrames: ['frame1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            fingerprint: fingerprint,
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.textContaining('TestError'), findsOneWidget);
      expect(find.textContaining('abc123'), findsOneWidget);
    });

    testWidgets('shows "Start fresh" button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.text('Start fresh'), findsOneWidget);
    });

    testWidgets('fires onStartFresh callback when button pressed',
        (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            onRestart: () {},
            onStartFresh: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.text('Start fresh'));
      expect(pressed, isTrue);
    });

    testWidgets('shows resume button when lastSnapshot is provided',
        (tester) async {
      final snapshot = AppSnapshot(
        snapshotId: 'snap-1',
        routeStack: ['/'],
        scrollPositions: {},
        formInputs: {},
        customState: {'key': 'value'},
        timestamp: DateTime(2024, 1, 15, 10, 30, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            lastSnapshot: snapshot,
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.text('Resume where I left off'), findsOneWidget);
    });

    testWidgets('fires onRestart callback when resume pressed', (tester) async {
      var pressed = false;
      final snapshot = AppSnapshot(
        snapshotId: 'snap-2',
        routeStack: ['/'],
        scrollPositions: {},
        formInputs: {},
        customState: {'key': 'value'},
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            lastSnapshot: snapshot,
            onRestart: () => pressed = true,
            onStartFresh: () {},
          ),
        ),
      );

      await tester.tap(find.text('Resume where I left off'));
      expect(pressed, isTrue);
    });

    testWidgets('shows last saved timestamp when snapshot provided',
        (tester) async {
      final snapshot = AppSnapshot(
        snapshotId: 'snap-3',
        routeStack: ['/'],
        scrollPositions: {},
        formInputs: {},
        customState: {},
        timestamp: DateTime(2024, 1, 15, 10, 30, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            lastSnapshot: snapshot,
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.textContaining('Last saved'), findsOneWidget);
      expect(find.textContaining('2024-01-15'), findsOneWidget);
    });

    testWidgets('hides resume button when no snapshot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FallbackScreen(
            onRestart: () {},
            onStartFresh: () {},
          ),
        ),
      );

      expect(find.text('Resume where I left off'), findsNothing);
    });

    test('default values are correct', () {
      final widget = FallbackScreen(
        onRestart: () {},
        onStartFresh: () {},
      );

      expect(widget.title, 'Something went wrong');
      expect(widget.subtitle, 'An unexpected error occurred.');
      expect(widget.isInCrashLoop, isFalse);
      expect(widget.fingerprint, isNull);
      expect(widget.lastSnapshot, isNull);
    });
  });

  group('ErrorBanner', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorBanner(message: 'Network error'),
          ),
        ),
      );

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('defaults to recoverable severity', (tester) async {
      const banner = ErrorBanner(message: 'test');
      expect(banner.severity, ErrorSeverity.recoverable);
    });

    testWidgets('accepts custom severity', (tester) async {
      const banner = ErrorBanner(
        message: 'test',
        severity: ErrorSeverity.fatal,
      );
      expect(banner.severity, ErrorSeverity.fatal);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Error occurred',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('fires onRetry callback', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      expect(retried, isTrue);
    });

    testWidgets('shows dismiss button when onDismiss provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Error',
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('fires onDismiss callback', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Error',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('all three severity levels render without error',
        (tester) async {
      for (final severity in ErrorSeverity.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorBanner(
                message: 'Test $severity',
                severity: severity,
              ),
            ),
          ),
        );
        expect(find.text('Test $severity'), findsOneWidget);
      }
    });
  });
}
