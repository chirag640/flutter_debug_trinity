import 'package:flutter/rendering.dart';
import 'layout_decision_recorder.dart';

/// Mixin for any [RenderBox] subclass.
///
/// Automatically records a [LayoutDecision] after every `performLayout()` call.
/// Detects overflow by comparing the computed size against the received constraints.
///
/// **Zero overhead in release builds** — all recording is inside `assert()`.
///
/// ## Usage
///
/// Apply to a custom render object:
/// ```dart
/// class MyRenderBox extends RenderBox with ExplainableRenderBox {
///   @override
///   void performLayout() {
///     size = constraints.constrain(const Size(300, 100));
///     // ExplainableRenderBox automatically records this decision
///   }
/// }
/// ```
///
/// Or use the convenience [ExplainableRenderProxyBox] for wrapping:
/// ```dart
/// class DebugWrapper extends SingleChildRenderObjectWidget {
///   @override
///   RenderObject createRenderObject(BuildContext context) {
///     return ExplainableRenderProxyBox();
///   }
/// }
/// ```
mixin ExplainableRenderBox on RenderBox {
  /// Override to provide a custom name. Defaults to `runtimeType.toString()`.
  String get explainableWidgetType => runtimeType.toString();

  @override
  void performLayout() {
    super.performLayout();

    assert(() {
      final overflowed = size.width > constraints.maxWidth ||
          size.height > constraints.maxHeight;

      LayoutDecisionRecorder.instance.record(LayoutDecision(
        widgetType: explainableWidgetType,
        constraintsReceived: constraints,
        sizeReported: size,
        overflowed: overflowed,
        timestamp: DateTime.now(),
      ));
      return true;
    }());
  }
}

/// A [RenderProxyBox] with automatic layout decision recording.
///
/// Wrap any widget's render object with this to get explainable layout
/// tracking without modifying the original widget.
class ExplainableRenderProxyBox extends RenderProxyBox
    with ExplainableRenderBox {
  ExplainableRenderProxyBox({RenderBox? child}) : super(child);

  @override
  String get explainableWidgetType => 'ProxyBox(${child?.runtimeType})';
}
