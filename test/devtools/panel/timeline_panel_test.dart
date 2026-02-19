import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/devtools/panel/timeline_panel.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('TimelinePanel', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimelinePanel()),
        ),
      );

      expect(find.byType(TimelinePanel), findsOneWidget);
    });

    testWidgets('shows empty state when no events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimelinePanel()),
        ),
      );

      expect(find.textContaining('No events'), findsOneWidget);
    });

    testWidgets('has filter chips for event types', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimelinePanel()),
        ),
      );

      expect(find.byType(FilterChip), findsWidgets);
    });

    testWidgets('can be constructed with const', (tester) async {
      const panel = TimelinePanel();
      expect(panel, isA<TimelinePanel>());
    });

    testWidgets('has pause/play control', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TimelinePanel()),
        ),
      );

      // Should have a pause/play icon
      expect(
        find.byIcon(Icons.pause).evaluate().isNotEmpty ||
            find.byIcon(Icons.play_arrow).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
