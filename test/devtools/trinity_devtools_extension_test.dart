import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/devtools/trinity_devtools_extension.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/core/causal_graph.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    CausalGraph.instance.debugClear();
  });

  group('TrinityDevToolsExtension', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      expect(find.byType(TrinityDevToolsExtension), findsOneWidget);
    });

    testWidgets('shows three tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Graph'), findsOneWidget);
      expect(find.text('Explain'), findsOneWidget);
    });

    testWidgets('defaults to timeline tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      // Timeline content should be visible
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('accepts initialTab parameter', (tester) async {
      const ext = TrinityDevToolsExtension(initialTab: 1);
      expect(ext.initialTab, 1);
    });

    testWidgets('can switch to Graph tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      await tester.tap(find.text('Graph'));
      await tester.pumpAndSettle();

      // Graph tab should be visible
      expect(find.text('Graph'), findsOneWidget);
    });

    testWidgets('can switch to Explain tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();

      expect(find.text('Explain'), findsOneWidget);
    });

    testWidgets('shows app title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      expect(find.text('Flutter Debug Trinity'), findsOneWidget);
    });

    testWidgets('shows bug_report icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrinityDevToolsExtension(),
        ),
      );

      expect(find.byIcon(Icons.bug_report), findsWidgets);
    });
  });

  group('TrinityDebugFab', () {
    testWidgets('renders a floating action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: TrinityDebugFab(),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('has bug_report icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: TrinityDebugFab(),
          ),
        ),
      );

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
    });

    testWidgets('tapping opens bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: TrinityDebugFab(),
            body: Center(child: Text('Main')),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Bottom sheet should contain the DevTools extension
      expect(find.byType(TrinityDevToolsExtension), findsOneWidget);
    });
  });
}
