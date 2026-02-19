import 'dart:async';

import 'package:uuid/uuid.dart';

/// Metadata carried through Dart Zones across async boundaries.
///
/// When [CausalityZone.run] forks a new Zone, this context is injected
/// as a Zone value. Any code running inside that Zone (including code
/// after `await` boundaries) can read it via [CausalityZone.currentContext].
///
/// This is the mechanism that links a user tap to the network call it triggers
/// to the state change that results, without requiring developers to manually
/// pass context objects through every function call.
class CausalityContext {
  /// Unique ID for this causal origin event.
  final String eventId;

  /// The parent event's ID, if this context was created inside an existing
  /// [CausalityZone.run] call. Forms the parent edge in the [CausalGraph].
  final String? parentEventId;

  /// Human-readable description of what initiated this causal chain.
  /// Examples: "user_tapped_login", "timer_refresh", "push_notification".
  final String originDescription;

  /// When this causal chain started.
  final DateTime timestamp;

  const CausalityContext({
    required this.eventId,
    this.parentEventId,
    required this.originDescription,
    required this.timestamp,
  });

  @override
  String toString() =>
      'CausalityContext($originDescription, id=$eventId, parent=$parentEventId)';
}

/// Private key for Zone values. Using [Object] instead of a String avoids
/// collisions with any other Zone-based library.
final Object _causalityKey = Object();

/// Provides causal context propagation through Dart Zones.
///
/// **The core insight:** Dart Zones carry arbitrary metadata that survives
/// across `await` boundaries, `Future.then()` chains, `StreamController`
/// callbacks, and any other standard async mechanism — without requiring
/// any changes to the async code itself.
///
/// ## Usage
///
/// ```dart
/// // In a gesture handler:
/// CausalityZone.run('user_tapped_login', () async {
///   await authService.login(email); // Zone context survives this await
///   stateManager.update(result);    // Zone context still readable
/// });
///
/// // Anywhere downstream:
/// final context = CausalityZone.currentContext();
/// print(context?.originDescription); // "user_tapped_login"
/// ```
///
/// ## What breaks Zone propagation
///
/// - **Isolates:** Zone context does NOT cross isolate boundaries (use
///   `ReceivePort` bridge with manual context threading).
/// - **Platform channels:** Native callbacks do NOT carry Zone context.
/// - **C FFI:** Does not propagate Zones.
class CausalityZone {
  CausalityZone._();

  static const Uuid _uuid = Uuid();

  /// Runs [fn] inside a new Zone that carries a [CausalityContext].
  ///
  /// If called inside an existing [CausalityZone.run], the new context's
  /// [CausalityContext.parentEventId] automatically points to the outer
  /// context's [CausalityContext.eventId], forming a chain.
  ///
  /// Returns the result of [fn]. Works with both sync and async functions —
  /// async functions will carry the Zone context through all their `await`s.
  static T run<T>(String description, T Function() fn) {
    final parentContext = currentContext();
    final context = CausalityContext(
      eventId: _uuid.v4(),
      parentEventId: parentContext?.eventId,
      originDescription: description,
      timestamp: DateTime.now(),
    );
    return Zone.current.fork(zoneValues: {_causalityKey: context}).run(fn);
  }

  /// Returns the [CausalityContext] for the current execution context,
  /// or `null` if not running inside a [CausalityZone.run] call.
  ///
  /// Safe to call from anywhere — returns null outside causality zones
  /// instead of throwing.
  static CausalityContext? currentContext() {
    return Zone.current[_causalityKey] as CausalityContext?;
  }

  /// Creates and returns a new [CausalityContext] without forking a Zone.
  ///
  /// Use this when you need a context object (e.g. to store in a request's
  /// extra map) but don't want to fork the current Zone.
  static CausalityContext createContext(String description) {
    final parentContext = currentContext();
    return CausalityContext(
      eventId: _uuid.v4(),
      parentEventId: parentContext?.eventId,
      originDescription: description,
      timestamp: DateTime.now(),
    );
  }
}
