import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/devtools/panel/graph_panel.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/core/causal_graph.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    CausalGraph.instance.debugClear();
  });

  group('GraphPanel', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GraphPanel()),
        ),
      );

      expect(find.byType(GraphPanel), findsOneWidget);
    });

    testWidgets('shows empty state when no events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GraphPanel()),
        ),
      );

      expect(find.textContaining('No events'), findsOneWidget);
    });

    testWidgets('can be constructed with const', (tester) async {
      const panel = GraphPanel();
      expect(panel, isA<GraphPanel>());
    });

    testWidgets('has a refresh/clear control', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GraphPanel()),
        ),
      );

      // Should have a refresh or clear icon
      final hasRefresh = find.byIcon(Icons.refresh).evaluate().isNotEmpty;
      final hasDelete = find.byIcon(Icons.delete_outline).evaluate().isNotEmpty;
      expect(hasRefresh || hasDelete, isTrue);
    });
  });
}
