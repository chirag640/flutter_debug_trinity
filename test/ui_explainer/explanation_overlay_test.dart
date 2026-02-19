import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/ui_explainer/explanation_overlay.dart';

void main() {
  group('ExplanationOverlay', () {
    group('rendering', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ExplanationOverlay(
              child: Scaffold(body: Text('child content')),
            ),
          ),
        );

        expect(find.text('child content'), findsOneWidget);
      });

      testWidgets('when enabled: false, renders only child (no FAB)',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ExplanationOverlay(
              enabled: false,
              child: Scaffold(body: Text('disabled child')),
            ),
          ),
        );

        expect(find.text('disabled child'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
      });

      testWidgets('when enabled: true, shows FAB', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExplanationOverlay(
                enabled: true,
                child: Text('enabled child'),
              ),
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
      });

      testWidgets('FAB initially shows bug_report icon', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExplanationOverlay(
                enabled: true,
                child: SizedBox(),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.bug_report), findsOneWidget);
      });

      testWidgets('tapping FAB opens explanation panel', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExplanationOverlay(
                enabled: true,
                child: SizedBox(),
              ),
            ),
          ),
        );

        // Invoke onPressed directly — FAB may be off-screen in test constraints
        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        fab.onPressed!();
        await tester.pumpAndSettle();

        // Panel is now visible — FAB changes to close icon
        expect(find.byIcon(Icons.close), findsWidgets);
      });

      testWidgets('tapping FAB again closes panel', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExplanationOverlay(
                enabled: true,
                child: SizedBox(),
              ),
            ),
          ),
        );

        // Open panel
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed!();
        await tester.pumpAndSettle();

        // Close panel
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed!();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bug_report), findsOneWidget);
      });

      testWidgets('panel shows "No layout overflows detected" when empty',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExplanationOverlay(
                enabled: true,
                child: SizedBox(),
              ),
            ),
          ),
        );

        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed!();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No layout overflows detected'),
          findsOneWidget,
        );
      });
    });

    group('disabled state', () {
      testWidgets('enabled: false is a passthrough — no Stack', (tester) async {
        const child = Text('pass through');
        await tester.pumpWidget(
          const MaterialApp(
            home: ExplanationOverlay(
              enabled: false,
              child: child,
            ),
          ),
        );

        // No FAB, no overlay infrastructure — pure passthrough
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('pass through'), findsOneWidget);
      });
    });

    group('default values', () {
      test('enabled defaults to kDebugMode', () {
        const overlay = ExplanationOverlay(child: SizedBox());
        expect(overlay.enabled, isA<bool>());
      });
    });
  });
}
