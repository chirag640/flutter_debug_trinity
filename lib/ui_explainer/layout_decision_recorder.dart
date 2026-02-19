import 'package:flutter/rendering.dart';
import '../core/causal_event.dart';
import '../core/context_zone.dart';
import '../core/trinity_event_bus.dart';

/// Represents a single layout decision made by a [RenderBox].
///
/// Captured automatically by [ExplainableRenderBox] mixin on every
/// `performLayout()` call. Only recorded in debug builds (assert-guarded).
class LayoutDecision {
  /// The widget type name (e.g. 'RenderFlex', 'RenderParagraph').
  final String widgetType;

  /// The [BoxConstraints] received from the parent.
  final BoxConstraints constraintsReceived;

  /// The [Size] reported by [`RenderBox.size`] after layout.
  final Size sizeReported;

  /// Whether the child requested more space than parent allowed.
  final bool overflowed;

  /// When this layout decision was recorded.
  final DateTime timestamp;

  /// Linked event ID in the [TrinityEventBus], if available.
  final String? causalEventId;

  const LayoutDecision({
    required this.widgetType,
    required this.constraintsReceived,
    required this.sizeReported,
    required this.overflowed,
    required this.timestamp,
    this.causalEventId,
  });

  @override
  String toString() => 'LayoutDecision($widgetType, '
      'constraints=$constraintsReceived, '
      'size=$sizeReported, '
      'overflowed=$overflowed)';
}

/// Records layout decisions in a circular buffer.
///
/// Layout fires on **every frame** during animation, so a bounded buffer
/// is essential to avoid unbounded memory growth.
///
/// The buffer holds the most recent 200 decisions. When an overflow is
/// detected, the recorder automatically emits a [CausalEvent] of type
/// [CausalEventType.layoutDecision] to the [TrinityEventBus].
///
/// All recording is wrapped in `assert()` — zero overhead in release.
class LayoutDecisionRecorder {
  LayoutDecisionRecorder._internal();

  /// The singleton instance.
  static final LayoutDecisionRecorder instance =
      LayoutDecisionRecorder._internal();

  /// Maximum number of decisions to keep.
  static const int maxBufferSize = 200;

  final List<LayoutDecision> _buffer = [];

  /// Unmodifiable view of the current buffer.
  List<LayoutDecision> get buffer => List.unmodifiable(_buffer);

  /// All decisions where [LayoutDecision.overflowed] is true.
  List<LayoutDecision> get overflows =>
      _buffer.where((d) => d.overflowed).toList();

  /// Record a layout decision. Only executes in debug mode.
  void record(LayoutDecision decision) {
    assert(() {
      _buffer.add(decision);
      if (_buffer.length > maxBufferSize) _buffer.removeAt(0);

      if (decision.overflowed) {
        final context = CausalityZone.currentContext();
        TrinityEventBus.instance.emit(CausalEvent(
          parentId: context?.eventId,
          type: CausalEventType.layoutDecision,
          description: '${decision.widgetType} overflow: '
              'requested ${decision.sizeReported}, '
              'max ${decision.constraintsReceived.biggest}',
          metadata: {
            'widget_type': decision.widgetType,
            'overflowed': true,
            'requested_width': decision.sizeReported.width,
            'requested_height': decision.sizeReported.height,
            'max_width': decision.constraintsReceived.maxWidth,
            'max_height': decision.constraintsReceived.maxHeight,
          },
        ));
      }
      return true;
    }());
  }

  /// Clear the buffer. Only works in debug mode.
  void debugClear() {
    assert(() {
      _buffer.clear();
      return true;
    }());
  }
}
