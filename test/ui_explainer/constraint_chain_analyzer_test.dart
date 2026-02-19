import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/ui_explainer/constraint_chain_analyzer.dart';

void main() {
  group('ConstraintChainLink', () {
    test('isTight returns true for tight BoxConstraints', () {
      const link = ConstraintChainLink(
        widgetType: 'RenderConstrainedBox',
        constraints: BoxConstraints.tightFor(width: 100, height: 100),
        depth: 0,
      );
      expect(link.isTight, isTrue);
    });

    test('isTight returns false for loose BoxConstraints', () {
      const link = ConstraintChainLink(
        widgetType: 'RenderFlex',
        constraints: BoxConstraints(maxWidth: 400),
        depth: 0,
      );
      expect(link.isTight, isFalse);
    });

    test('toString includes depth and widget type', () {
      const link = ConstraintChainLink(
        widgetType: 'RenderBox',
        constraints: BoxConstraints(maxWidth: 300),
        size: Size(200, 100),
        depth: 2,
      );
      expect(link.toString(), contains('depth=2'));
      expect(link.toString(), contains('RenderBox'));
    });
  });

  group('ConstraintChainAnalyzer', () {
    test('findTightCulprit skips target (index 0)', () {
      final chain = [
        const ConstraintChainLink(
          widgetType: 'Target',
          constraints: BoxConstraints.tightFor(width: 50),
          depth: 0,
        ),
        const ConstraintChainLink(
          widgetType: 'LooseParent',
          constraints: BoxConstraints(maxWidth: 400),
          depth: 1,
        ),
      ];

      final culprit = ConstraintChainAnalyzer.findTightCulprit(chain);
      expect(culprit, isNull);
    });

    test('findTightCulprit finds first tight parent', () {
      final chain = [
        const ConstraintChainLink(
          widgetType: 'Target',
          constraints: BoxConstraints(maxWidth: 50),
          depth: 0,
        ),
        const ConstraintChainLink(
          widgetType: 'LooseParent',
          constraints: BoxConstraints(maxWidth: 400),
          depth: 1,
        ),
        const ConstraintChainLink(
          widgetType: 'TightGrandparent',
          constraints: BoxConstraints.tightFor(width: 200, height: 200),
          depth: 2,
        ),
      ];

      final culprit = ConstraintChainAnalyzer.findTightCulprit(chain);
      expect(culprit, isNotNull);
      expect(culprit!.widgetType, 'TightGrandparent');
    });

    test('explain generates readable output', () {
      final chain = [
        const ConstraintChainLink(
          widgetType: 'Target',
          constraints: BoxConstraints(maxWidth: 100),
          size: Size(200, 50),
          depth: 0,
        ),
        const ConstraintChainLink(
          widgetType: 'TightParent',
          constraints: BoxConstraints.tightFor(width: 100, height: 100),
          size: Size(100, 100),
          depth: 1,
        ),
      ];

      final explanation = ConstraintChainAnalyzer.explain(chain);
      expect(explanation, contains('Constraint Chain Analysis'));
      expect(explanation, contains('Target'));
      expect(explanation, contains('TightParent'));
      expect(explanation, contains('LIKELY CULPRIT'));
    });

    test('explain handles empty chain', () {
      final explanation = ConstraintChainAnalyzer.explain([]);
      expect(explanation, contains('Empty'));
    });
  });
}
