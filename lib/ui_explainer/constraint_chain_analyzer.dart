import 'package:flutter/rendering.dart';

/// Analyzes the constraint chain from a render object up to the root.
///
/// When a layout overflow occurs, answering "why?" requires tracing
/// the constraint chain: which ancestor imposed the tight constraint?
///
/// This class walks the render tree upward and captures each ancestor's
/// constraints, so the developer can see the entire constraint pipeline.
///
/// ## Usage
/// ```dart
/// final chain = ConstraintChainAnalyzer.analyze(myRenderBox);
/// for (final link in chain) {
///   print('${link.widgetType}: ${link.constraints}');
/// }
/// ```
class ConstraintChainLink {
  /// The render object type name.
  final String widgetType;

  /// The constraints this render object received from its parent.
  final Constraints constraints;

  /// The size this render object reported (if it's a RenderBox).
  final Size? size;

  /// Depth in the tree (0 = target, increasing = toward root).
  final int depth;

  const ConstraintChainLink({
    required this.widgetType,
    required this.constraints,
    this.size,
    required this.depth,
  });

  /// Whether this link has tight constraints (no flexibility).
  bool get isTight {
    if (constraints is BoxConstraints) {
      return (constraints as BoxConstraints).isTight;
    }
    return false;
  }

  @override
  String toString() => 'ConstraintChainLink(depth=$depth, $widgetType, '
      'constraints=$constraints, size=$size, tight=$isTight)';
}

/// Walks the render tree upward from a [RenderObject] and captures
/// the constraint chain.
class ConstraintChainAnalyzer {
  /// Analyze the constraint chain from [target] up to the root
  /// (or up to [maxDepth] ancestors).
  ///
  /// Returns a list of [ConstraintChainLink]s ordered from the target
  /// (depth 0) to the furthest ancestor analyzed.
  static List<ConstraintChainLink> analyze(
    RenderObject target, {
    int maxDepth = 20,
  }) {
    final chain = <ConstraintChainLink>[];
    RenderObject? current = target;
    int depth = 0;

    while (current != null && depth <= maxDepth) {
      Size? size;
      if (current is RenderBox && current.hasSize) {
        size = current.size;
      }

      // ignore: invalid_use_of_protected_member
      final currentConstraints = current.constraints;
      chain.add(ConstraintChainLink(
        widgetType: current.runtimeType.toString(),
        constraints: currentConstraints,
        size: size,
        depth: depth,
      ));

      current = current.parent;
      depth++;
    }

    return chain;
  }

  /// Find the first ancestor in the chain that imposes tight constraints.
  ///
  /// This is typically the "culprit" that causes overflow — it doesn't
  /// give enough space to its descendants.
  static ConstraintChainLink? findTightCulprit(
    List<ConstraintChainLink> chain,
  ) {
    // Skip the target itself (index 0), look at parents
    for (int i = 1; i < chain.length; i++) {
      if (chain[i].isTight) return chain[i];
    }
    return null;
  }

  /// Generate a human-readable explanation of the constraint chain.
  static String explain(List<ConstraintChainLink> chain) {
    if (chain.isEmpty) return 'Empty constraint chain.';

    final buffer = StringBuffer();
    buffer.writeln('Constraint Chain Analysis:');
    buffer.writeln('─' * 50);

    for (final link in chain) {
      final indent = '  ' * link.depth;
      final tight = link.isTight ? ' ⚠️ TIGHT' : '';
      buffer.writeln(
        '$indent[${link.depth}] ${link.widgetType}$tight',
      );
      buffer.writeln(
        '$indent    constraints: ${link.constraints}',
      );
      if (link.size != null) {
        buffer.writeln(
          '$indent    size: ${link.size}',
        );
      }
    }

    final culprit = findTightCulprit(chain);
    if (culprit != null) {
      buffer.writeln();
      buffer.writeln('LIKELY CULPRIT: ${culprit.widgetType} at depth '
          '${culprit.depth} imposes tight constraints.');
    }

    return buffer.toString();
  }
}
