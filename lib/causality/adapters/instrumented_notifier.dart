import '../../core/causal_event.dart';
import '../../core/context_zone.dart';
import '../../core/trinity_event_bus.dart';

/// Generic mixin for any class that performs state mutations.
///
/// Call [emitCause] at every mutation site to record the state change
/// in the [TrinityEventBus] and link it to the current causal context.
///
/// **Zero overhead in release builds** — [emitCause] is wrapped in assert().
///
/// ## Usage
/// ```dart
/// class AuthService with InstrumentedNotifier {
///   Future<void> login(String email) async {
///     emitCause('login_started', metadata: {'email': email});
///     final result = await _api.login(email);
///     emitCause('login_completed', metadata: {'user_id': result.userId});
///   }
/// }
/// ```
mixin InstrumentedNotifier {
  /// Emit a causal event linked to the current [CausalityZone] context.
  ///
  /// [description] should be a human-readable label like 'cart_item_added'.
  /// [metadata] can contain any JSON-safe data relevant to the mutation.
  /// [type] defaults to [CausalEventType.stateChange].
  void emitCause(
    String description, {
    Map<String, dynamic>? metadata,
    CausalEventType type = CausalEventType.stateChange,
  }) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: type,
        description: '$runtimeType: $description',
        metadata: metadata ?? const {},
      ));
      return true;
    }());
  }
}
