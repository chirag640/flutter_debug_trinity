import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/devtools/panel/explanation_panel.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('ExplanationPanel', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExplanationPanel()),
        ),
      );

      expect(find.byType(ExplanationPanel), findsOneWidget);
    });

    testWidgets('shows empty state when no explanations exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExplanationPanel()),
        ),
      );

      expect(find.textContaining('No layout issues detected'), findsOneWidget);
    });

    testWidgets('can be constructed with const', (tester) async {
      const panel = ExplanationPanel();
      expect(panel, isA<ExplanationPanel>());
    });

    testWidgets('has a clear control', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExplanationPanel()),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
