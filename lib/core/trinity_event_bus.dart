import 'dart:async';
import 'causal_event.dart';

/// Singleton broadcast event bus shared by all three trinity sub-systems.
///
/// Every [CausalEvent] from recoverable_app, ui_explainer, and causality_flutter
/// flows through this bus. The [CausalGraph] subscribes to it, DevTools polls
/// the [buffer], and any user code can listen via [stream].
///
/// **Rule:** No sub-system imports from another sub-system. All cross-system
/// communication happens through this bus.
class TrinityEventBus {
  TrinityEventBus._internal();

  /// The singleton instance. All sub-systems use this.
  static final TrinityEventBus instance = TrinityEventBus._internal();

  final StreamController<CausalEvent> _controller =
      StreamController<CausalEvent>.broadcast();

  /// Circular buffer of the last [_bufferMax] events.
  /// DevTools extension polls this every 500ms.
  final List<CausalEvent> _buffer = [];
  static const int _bufferMax = 500;

  /// Broadcast stream — multiple listeners can subscribe simultaneously.
  Stream<CausalEvent> get stream => _controller.stream;

  /// Unmodifiable view of the event buffer (oldest first).
  List<CausalEvent> get buffer => List.unmodifiable(_buffer);

  /// The current buffer size.
  int get bufferLength => _buffer.length;

  /// Emit an event to all listeners and add it to the buffer.
  ///
  /// The buffer is a FIFO circular queue: when [_bufferMax] is exceeded,
  /// the oldest event is evicted.
  void emit(CausalEvent event) {
    _buffer.add(event);
    if (_buffer.length > _bufferMax) {
      _buffer.removeAt(0);
    }
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Closes the stream controller. Call only on app dispose.
  void dispose() {
    _controller.close();
  }

  /// Clears the buffer. Only works in debug/test mode (inside assert).
  void debugClear() {
    assert(() {
      _buffer.clear();
      return true;
    }());
  }

  /// Returns events filtered by [type]. Useful for DevTools panels
  /// that show only crash events, only layout events, etc.
  List<CausalEvent> bufferWhere(CausalEventType type) {
    return _buffer.where((e) => e.type == type).toList();
  }

  /// Returns the last event in the buffer, or null if empty.
  CausalEvent? get lastEvent => _buffer.isNotEmpty ? _buffer.last : null;
}
