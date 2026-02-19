import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/causal_event.dart';
import '../../core/context_zone.dart';
import '../../core/trinity_event_bus.dart';

/// A [ProviderObserver] that records all Riverpod provider state changes
/// as causal events in the [TrinityEventBus].
///
/// ## Usage
/// ```dart
/// void main() {
///   runApp(
///     ProviderScope(
///       observers: [CausalityProviderObserver()],
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// Records:
/// - Provider additions (initialization)
/// - Provider updates (state changes)
/// - Provider disposals
/// - Provider errors
///
/// All recording is assert-guarded — zero overhead in release builds.
class CausalityProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description: 'Riverpod: ${provider.name ?? provider.runtimeType} added',
        metadata: {
          'provider_name': provider.name ?? 'unnamed',
          'provider_type': provider.runtimeType.toString(),
          'value_type': value.runtimeType.toString(),
          'action': 'add',
        },
      ));
      return true;
    }());
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description:
            'Riverpod: ${provider.name ?? provider.runtimeType} updated',
        metadata: {
          'provider_name': provider.name ?? 'unnamed',
          'provider_type': provider.runtimeType.toString(),
          'previous_value_type': previousValue.runtimeType.toString(),
          'new_value_type': newValue.runtimeType.toString(),
          'action': 'update',
        },
      ));
      return true;
    }());
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description:
            'Riverpod: ${provider.name ?? provider.runtimeType} disposed',
        metadata: {
          'provider_name': provider.name ?? 'unnamed',
          'provider_type': provider.runtimeType.toString(),
          'action': 'dispose',
        },
      ));
      return true;
    }());
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.crashEvent,
        description: 'Riverpod: ${provider.name ?? provider.runtimeType} error',
        metadata: {
          'provider_name': provider.name ?? 'unnamed',
          'provider_type': provider.runtimeType.toString(),
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString().substring(
                0,
                error.toString().length > 500 ? 500 : error.toString().length,
              ),
          'stack_top_3': stackTrace.toString().split('\n').take(3).join('\n'),
          'action': 'error',
        },
      ));
      return true;
    }());
  }
}
