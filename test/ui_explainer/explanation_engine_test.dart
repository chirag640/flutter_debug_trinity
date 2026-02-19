import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/ui_explainer/layout_decision_recorder.dart';
import 'package:flutter_debug_trinity/ui_explainer/explanation_engine.dart';

void main() {
  setUp(() {
    LayoutDecisionRecorder.instance.debugClear();
  });

  group('ExplanationEngine', () {
    test('explains horizontal overflow', () {
      final decision = LayoutDecision(
        widgetType: 'RenderFlex',
        constraintsReceived:
            const BoxConstraints(maxWidth: 300, maxHeight: 600),
        sizeReported: const Size(500, 100),
        overflowed: true,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      expect(explanation.title, contains('horizontally'));
      expect(explanation.detail, contains('200.0')); // excess pixels
      expect(explanation.suggestions, isNotEmpty);
    });

    test('explains vertical overflow', () {
      final decision = LayoutDecision(
        widgetType: 'RenderFlex',
        constraintsReceived:
            const BoxConstraints(maxWidth: 300, maxHeight: 400),
        sizeReported: const Size(200, 600),
        overflowed: true,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      expect(explanation.title, contains('vertically'));
    });

    test('explains both-axis overflow', () {
      final decision = LayoutDecision(
        widgetType: 'RenderBox',
        constraintsReceived:
            const BoxConstraints(maxWidth: 200, maxHeight: 200),
        sizeReported: const Size(400, 400),
        overflowed: true,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      expect(explanation.title, contains('both axes'));
    });

    test('explains normal layout', () {
      final decision = LayoutDecision(
        widgetType: 'RenderBox',
        constraintsReceived: const BoxConstraints(maxWidth: 400),
        sizeReported: const Size(200, 100),
        overflowed: false,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      expect(explanation.title, contains('normally'));
      expect(explanation.suggestions, isEmpty);
    });

    test('suggests Flexible/Expanded for Row overflow', () {
      final decision = LayoutDecision(
        widgetType: 'RenderFlex',
        constraintsReceived: const BoxConstraints(maxWidth: 300),
        sizeReported: const Size(500, 50),
        overflowed: true,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      final descriptions =
          explanation.suggestions.map((s) => s.description).toList();
      expect(
          descriptions
              .any((d) => d.contains('Flexible') || d.contains('Expanded')),
          isTrue);
    });

    test('suggests TextOverflow.ellipsis for text overflow', () {
      final decision = LayoutDecision(
        widgetType: 'RenderParagraph',
        constraintsReceived: const BoxConstraints(maxWidth: 100),
        sizeReported: const Size(300, 20),
        overflowed: true,
        timestamp: DateTime.now(),
      );

      final explanation = ExplanationEngine.explain(decision);
      final descriptions =
          explanation.suggestions.map((s) => s.description).toList();
      expect(descriptions.any((d) => d.contains('ellipsis')), isTrue);
    });

    test('explainAllOverflows reads from recorder', () {
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Normal',
        constraintsReceived: const BoxConstraints(maxWidth: 400),
        sizeReported: const Size(100, 100),
        overflowed: false,
        timestamp: DateTime.now(),
      ));
      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: 'Overflowed',
        constraintsReceived: const BoxConstraints(maxWidth: 200),
        sizeReported: const Size(400, 50),
        overflowed: true,
        timestamp: DateTime.now(),
      ));

      final explanations = ExplanationEngine.explainAllOverflows();
      expect(explanations, hasLength(1));
      expect(explanations.first.decision.widgetType, 'Overflowed');
    });
  });

  group('FixSuggestion', () {
    test('toString includes description', () {
      const fix = FixSuggestion(
        description: 'Wrap in Expanded',
        confidence: 0.9,
      );
      expect(fix.toString(), contains('Wrap in Expanded'));
    });

    test('confidence and priority', () {
      const fix = FixSuggestion(
        description: 'test',
        confidence: 0.85,
        priority: 1,
      );
      expect(fix.confidence, 0.85);
      expect(fix.priority, 1);
    });
  });
}
