import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/causal_event.dart';
import '../../core/context_zone.dart';
import '../../core/trinity_event_bus.dart';

/// A [ChangeNotifier] that automatically tracks state mutations in the
/// [TrinityEventBus] causal graph.
///
/// Extend this instead of [ChangeNotifier] to get automatic causality tracking.
///
/// ## Usage
/// ```dart
/// class CartModel extends CausalChangeNotifier {
///   final List<String> _items = [];
///   List<String> get items => List.unmodifiable(_items);
///
///   void addItem(String item) {
///     _items.add(item);
///     notifyListeners(); // Automatically emits a causal event
///   }
/// }
/// ```
class CausalChangeNotifier extends ChangeNotifier {
  /// Override to provide a custom description for the causal event.
  /// Defaults to `runtimeType: state_changed`.
  String get causalDescription => '$runtimeType: state_changed';

  @override
  void notifyListeners() {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description: causalDescription,
        metadata: {
          'notifier_type': runtimeType.toString(),
          'has_causal_parent': context != null,
        },
      ));
      return true;
    }());
    super.notifyListeners();
  }
}

/// A [ProxyProvider]-compatible wrapper that tracks when the proxy rebuilds.
///
/// ## Usage
/// ```dart
/// ProxyProvider<AuthService, CartService>(
///   update: (ctx, auth, prev) {
///     return CausalProxyUpdate.track(
///       'CartService',
///       () => CartService(auth),
///     );
///   },
/// )
/// ```
class CausalProxyUpdate {
  /// Track a proxy provider update as a causal event.
  static T track<T>(String providerName, T Function() create) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description: 'ProxyProvider: $providerName rebuilt',
        metadata: {
          'provider_name': providerName,
          'result_type': T.toString(),
        },
      ));
      return true;
    }());
    return create();
  }
}
