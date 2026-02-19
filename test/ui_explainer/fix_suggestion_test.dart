import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/ui_explainer/fix_suggestion.dart';
import 'package:flutter_debug_trinity/ui_explainer/layout_decision_recorder.dart';
import 'package:flutter_debug_trinity/ui_explainer/constraint_chain_analyzer.dart';

void main() {
  group('FixSuggestion', () {
    test('can be constructed with required fields only', () {
      const fix = FixSuggestion(description: 'Test fix');
      expect(fix.description, 'Test fix');
      expect(fix.codeHint, isNull);
      expect(fix.confidence, 0.5);
      expect(fix.priority, 0);
      expect(fix.category, FixCategory.general);
    });

    test('can be constructed with all fields', () {
      const fix = FixSuggestion(
        description: 'Wrap in Expanded',
        codeHint: 'Expanded(child: ...)',
        confidence: 0.9,
        priority: 1,
        category: FixCategory.addWrapper,
      );
      expect(fix.description, 'Wrap in Expanded');
      expect(fix.codeHint, 'Expanded(child: ...)');
      expect(fix.confidence, 0.9);
      expect(fix.priority, 1);
      expect(fix.category, FixCategory.addWrapper);
    });

    test('toString includes description and category', () {
      const fix = FixSuggestion(
        description: 'Add scroll',
        category: FixCategory.addScrollable,
        confidence: 0.8,
      );
      final str = fix.toString();
      expect(str, contains('Add scroll'));
      expect(str, contains('addScrollable'));
    });
  });

  group('FixCategory', () {
    test('has all expected values', () {
      expect(FixCategory.values, hasLength(6));
      expect(FixCategory.values, contains(FixCategory.addWrapper));
      expect(FixCategory.values, contains(FixCategory.changeProperty));
      expect(FixCategory.values, contains(FixCategory.replaceWidget));
      expect(FixCategory.values, contains(FixCategory.addScrollable));
      expect(FixCategory.values, contains(FixCategory.constrainDimensions));
      expect(FixCategory.values, contains(FixCategory.general));
    });
  });

  group('FixSuggestionEngine', () {
    LayoutDecision makeDecision({
      String widgetType = 'RenderFlex',
      BoxConstraints? constraints,
      Size? size,
      bool overflowed = true,
    }) {
      return LayoutDecision(
        widgetType: widgetType,
        constraintsReceived: constraints ??
            const BoxConstraints(
              minWidth: 0,
              maxWidth: 300,
              minHeight: 0,
              maxHeight: 600,
            ),
        sizeReported: size ?? const Size(500, 200),
        overflowed: overflowed,
        timestamp: DateTime.now(),
      );
    }

    test('returns empty list for non-overflow decisions', () {
      final decision = makeDecision(overflowed: false);
      final result = FixSuggestionEngine.suggest(decision);
      expect(result, isEmpty);
    });

    test('suggests Expanded/Flexible for Row with width overflow', () {
      final decision = makeDecision(
        widgetType: 'RenderFlex',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(500, 100), // width overflow
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.any((s) => s.description.contains('Expanded')),
        isTrue,
      );
    });

    test('suggests scrollable for Row with width overflow', () {
      final decision = makeDecision(
        widgetType: 'Row',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(500, 100),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) =>
            s.category == FixCategory.addScrollable ||
            s.description.contains('scrollable')),
        isTrue,
      );
    });

    test('suggests Expanded/scrollable for Column with height overflow', () {
      final decision = makeDecision(
        widgetType: 'Column',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 400,
        ),
        size: const Size(200, 700), // height overflow
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.any((s) => s.description.contains('Expanded')),
        isTrue,
      );
    });

    test('suggests TextOverflow.ellipsis for Text with width overflow', () {
      final decision = makeDecision(
        widgetType: 'RenderParagraph',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 200,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(400, 20), // width overflow
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.any((s) => s.description.contains('ellipsis')),
        isTrue,
      );
    });

    test('suggests maxLines for Text overflow', () {
      final decision = makeDecision(
        widgetType: 'Text',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 200,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(400, 20),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) => s.description.contains('maxLines')),
        isTrue,
      );
    });

    test('suggests BoxFit for Image overflow', () {
      final decision = makeDecision(
        widgetType: 'RenderImage',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 200,
          minHeight: 0,
          maxHeight: 200,
        ),
        size: const Size(500, 500),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.any((s) => s.description.contains('BoxFit')),
        isTrue,
      );
    });

    test('suggests SizedBox/AspectRatio for Image overflow', () {
      final decision = makeDecision(
        widgetType: 'Image',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 200,
          minHeight: 0,
          maxHeight: 200,
        ),
        size: const Size(500, 500),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) =>
            s.category == FixCategory.constrainDimensions ||
            s.description.contains('SizedBox')),
        isTrue,
      );
    });

    test('suggests Expanded for ListView inside Column (height overflow)', () {
      final decision = makeDecision(
        widgetType: 'ListView',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 400,
        ),
        size: const Size(300, 800),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
      expect(
        suggestions.any((s) => s.description.contains('Expanded')),
        isTrue,
      );
    });

    test('suggests shrinkWrap for ListView overflow', () {
      final decision = makeDecision(
        widgetType: 'ListView',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 400,
        ),
        size: const Size(300, 800),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) => s.description.contains('shrinkWrap')),
        isTrue,
      );
    });

    test('suggests width constraint for unbounded width overflow', () {
      final decision = makeDecision(
        widgetType: 'SomeWidget',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(1000, 100),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) => s.description.contains('unbounded width')),
        isTrue,
      );
    });

    test('suggests height constraint for unbounded height overflow', () {
      final decision = makeDecision(
        widgetType: 'SomeWidget',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: double.infinity,
        ),
        size: const Size(100, 1000),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(
        suggestions.any((s) => s.description.contains('unbounded height')),
        isTrue,
      );
    });

    test('returns generic fallback for unknown widget type', () {
      final decision = makeDecision(
        widgetType: 'UnknownWidget',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 200,
          minHeight: 0,
          maxHeight: 200,
        ),
        size: const Size(400, 400),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      expect(suggestions, isNotEmpty);
    });

    test('suggestions are sorted by priority', () {
      final decision = makeDecision(
        widgetType: 'Row',
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
          minHeight: 0,
          maxHeight: 600,
        ),
        size: const Size(500, 100),
      );

      final suggestions = FixSuggestionEngine.suggest(decision);
      for (int i = 0; i < suggestions.length - 1; i++) {
        expect(suggestions[i].priority,
            lessThanOrEqualTo(suggestions[i + 1].priority));
      }
    });

    group('suggestFromChain', () {
      test('adds unbounded constraint suggestion for chain with infinity', () {
        final decision = makeDecision(
          widgetType: 'RenderFlex',
          constraints: const BoxConstraints(
            minWidth: 0,
            maxWidth: 300,
            minHeight: 0,
            maxHeight: 600,
          ),
          size: const Size(500, 200),
        );

        final chain = [
          const ConstraintChainLink(
            widgetType: 'RenderFlex',
            constraints: BoxConstraints(
              minWidth: 0,
              maxWidth: 300,
              minHeight: 0,
              maxHeight: 600,
            ),
            depth: 0,
          ),
          const ConstraintChainLink(
            widgetType: 'RenderView',
            constraints: BoxConstraints(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: 600,
            ),
            depth: 1,
          ),
        ];

        final suggestions =
            FixSuggestionEngine.suggestFromChain(decision, chain);
        expect(
          suggestions.any((s) =>
              s.description.contains('Unbounded constraint') &&
              s.description.contains('RenderView')),
          isTrue,
        );
      });

      test('does not add chain suggestion when no unbounded link', () {
        final decision = makeDecision(
          widgetType: 'Row',
          constraints: const BoxConstraints(
            minWidth: 0,
            maxWidth: 300,
            minHeight: 0,
            maxHeight: 600,
          ),
          size: const Size(500, 100),
        );

        final chain = [
          const ConstraintChainLink(
            widgetType: 'RenderFlex',
            constraints: BoxConstraints(
              minWidth: 0,
              maxWidth: 300,
              minHeight: 0,
              maxHeight: 600,
            ),
            depth: 0,
          ),
        ];

        final baseSuggestions = FixSuggestionEngine.suggest(decision);
        final chainSuggestions =
            FixSuggestionEngine.suggestFromChain(decision, chain);

        // Should have the same number (no extra unbounded suggestion)
        expect(chainSuggestions.length, baseSuggestions.length);
      });

      test('chain suggestion has high confidence', () {
        final decision = makeDecision();

        final chain = [
          const ConstraintChainLink(
            widgetType: 'RenderFlex',
            constraints: BoxConstraints(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: 600,
            ),
            depth: 0,
          ),
        ];

        final suggestions =
            FixSuggestionEngine.suggestFromChain(decision, chain);
        final unboundedSuggestion = suggestions.firstWhere(
          (s) => s.description.contains('Unbounded constraint'),
        );
        expect(unboundedSuggestion.confidence, greaterThanOrEqualTo(0.8));
      });
    });
  });
}
