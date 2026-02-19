import 'layout_decision_recorder.dart';
import 'constraint_chain_analyzer.dart';
import 'fix_suggestion.dart';

// Re-export FixSuggestion so existing imports continue to work.
export 'fix_suggestion.dart' show FixSuggestion, FixCategory;

/// A human-readable explanation of why a layout decision happened.
class LayoutExplanation {
  /// The layout decision being explained.
  final LayoutDecision decision;

  /// Human-readable title (one line summary).
  final String title;

  /// Detailed explanation of WHY this happened.
  final String detail;

  /// The constraint chain from the widget to its root, if available.
  final List<ConstraintChainLink>? constraintChain;

  /// Suggested fixes, if any.
  final List<FixSuggestion> suggestions;

  const LayoutExplanation({
    required this.decision,
    required this.title,
    required this.detail,
    this.constraintChain,
    this.suggestions = const [],
  });

  @override
  String toString() => 'LayoutExplanation($title)';
}

/// Generates human-readable explanations for layout decisions.
///
/// Uses a template-based system to match common layout patterns
/// and produce developer-friendly explanations with fix suggestions.
///
/// ## Usage
/// ```dart
/// final decisions = LayoutDecisionRecorder.instance.overflows;
/// for (final decision in decisions) {
///   final explanation = ExplanationEngine.explain(decision);
///   print(explanation.title);
///   print(explanation.detail);
///   for (final fix in explanation.suggestions) {
///     print('  Fix: ${fix.description}');
///   }
/// }
/// ```
class ExplanationEngine {
  /// Generate an explanation for a single layout decision.
  static LayoutExplanation explain(LayoutDecision decision) {
    if (decision.overflowed) {
      return _explainOverflow(decision);
    }
    return _explainNormal(decision);
  }

  /// Explain all recent overflows from the recorder's buffer.
  static List<LayoutExplanation> explainAllOverflows() {
    return LayoutDecisionRecorder.instance.overflows
        .map((d) => explain(d))
        .toList();
  }

  static LayoutExplanation _explainOverflow(LayoutDecision decision) {
    final constraints = decision.constraintsReceived;
    final size = decision.sizeReported;
    final suggestions = <FixSuggestion>[];

    // Determine the axis of overflow
    final widthOverflow = size.width > constraints.maxWidth;
    final heightOverflow = size.height > constraints.maxHeight;

    String title;
    final detailBuffer = StringBuffer();

    if (widthOverflow && heightOverflow) {
      title = '${decision.widgetType} overflows in both axes';
    } else if (widthOverflow) {
      title = '${decision.widgetType} overflows horizontally';
    } else {
      title = '${decision.widgetType} overflows vertically';
    }

    // Build detail
    detailBuffer.writeln(
      'The widget ${decision.widgetType} was given constraints: $constraints',
    );
    detailBuffer.writeln(
      'But it computed a size of: $size',
    );

    if (widthOverflow) {
      final excess = size.width - constraints.maxWidth;
      detailBuffer.writeln(
        'Width exceeds max by ${excess.toStringAsFixed(1)} pixels.',
      );
      suggestions.addAll(_suggestWidthFixes(decision));
    }

    if (heightOverflow) {
      final excess = size.height - constraints.maxHeight;
      detailBuffer.writeln(
        'Height exceeds max by ${excess.toStringAsFixed(1)} pixels.',
      );
      suggestions.addAll(_suggestHeightFixes(decision));
    }

    return LayoutExplanation(
      decision: decision,
      title: title,
      detail: detailBuffer.toString(),
      suggestions: suggestions,
    );
  }

  static LayoutExplanation _explainNormal(LayoutDecision decision) {
    return LayoutExplanation(
      decision: decision,
      title: '${decision.widgetType} laid out normally',
      detail: 'Constraints: ${decision.constraintsReceived}, '
          'Size: ${decision.sizeReported}. No issues detected.',
    );
  }

  static List<FixSuggestion> _suggestWidthFixes(LayoutDecision decision) {
    final widgetType = decision.widgetType.toLowerCase();
    final suggestions = <FixSuggestion>[];

    if (widgetType.contains('flex') || widgetType.contains('row')) {
      suggestions.add(const FixSuggestion(
        description: 'Wrap overflowing children in Flexible or Expanded',
        codeHint: 'Row(children: [Expanded(child: Text(...)), ...])',
        confidence: 0.9,
        priority: 0,
      ));
      suggestions.add(const FixSuggestion(
        description: 'Use SingleChildScrollView with horizontal scrolling',
        codeHint:
            'SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))',
        confidence: 0.7,
        priority: 1,
      ));
    }

    if (widgetType.contains('text') || widgetType.contains('paragraph')) {
      suggestions.add(const FixSuggestion(
        description: 'Add overflow: TextOverflow.ellipsis to the Text widget',
        codeHint: "Text('...', overflow: TextOverflow.ellipsis)",
        confidence: 0.85,
        priority: 0,
      ));
      suggestions.add(const FixSuggestion(
        description: 'Wrap the Text in a Flexible widget',
        codeHint: 'Flexible(child: Text(...))',
        confidence: 0.8,
        priority: 1,
      ));
    }

    // Generic suggestion
    if (suggestions.isEmpty) {
      suggestions.add(const FixSuggestion(
        description:
            'Constrain the widget width with SizedBox or ConstrainedBox',
        codeHint:
            'ConstrainedBox(constraints: BoxConstraints(maxWidth: 300), child: ...)',
        confidence: 0.5,
        priority: 2,
      ));
    }

    return suggestions;
  }

  static List<FixSuggestion> _suggestHeightFixes(LayoutDecision decision) {
    final widgetType = decision.widgetType.toLowerCase();
    final suggestions = <FixSuggestion>[];

    if (widgetType.contains('flex') || widgetType.contains('column')) {
      suggestions.add(const FixSuggestion(
        description: 'Wrap overflowing children in Flexible or Expanded',
        codeHint: 'Column(children: [Expanded(child: ListView(...)), ...])',
        confidence: 0.9,
        priority: 0,
      ));
      suggestions.add(const FixSuggestion(
        description: 'Use SingleChildScrollView to allow vertical scrolling',
        codeHint: 'SingleChildScrollView(child: Column(...))',
        confidence: 0.7,
        priority: 1,
      ));
    }

    if (widgetType.contains('list') || widgetType.contains('scroll')) {
      suggestions.add(const FixSuggestion(
        description: 'Wrap ListView in Expanded when inside a Column',
        codeHint: 'Column(children: [Expanded(child: ListView(...))])',
        confidence: 0.9,
        priority: 0,
      ));
    }

    // Generic suggestion
    if (suggestions.isEmpty) {
      suggestions.add(const FixSuggestion(
        description: 'Constrain the widget height or wrap in a scrollable',
        codeHint:
            'ConstrainedBox(constraints: BoxConstraints(maxHeight: 400), child: ...)',
        confidence: 0.5,
        priority: 2,
      ));
    }

    return suggestions;
  }
}
