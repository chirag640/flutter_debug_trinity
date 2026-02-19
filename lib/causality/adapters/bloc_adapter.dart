import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/causal_event.dart';
import '../../core/context_zone.dart';
import '../../core/trinity_event_bus.dart';

/// A [BlocObserver] that records all Bloc/Cubit state transitions and
/// errors as causal events in the [TrinityEventBus].
///
/// ## Usage
/// ```dart
/// void main() {
///   Bloc.observer = CausalityBlocObserver();
///   // ...
/// }
/// ```
///
/// Every `onChange`, `onTransition`, and `onError` is recorded.
/// In release builds, this observer is a no-op (all recording is assert-guarded).
class CausalityBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description: '${bloc.runtimeType}: state changed',
        metadata: {
          'bloc_type': bloc.runtimeType.toString(),
          'current_state_type': change.currentState.runtimeType.toString(),
          'next_state_type': change.nextState.runtimeType.toString(),
        },
      ));
      return true;
    }());
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.stateChange,
        description: '${bloc.runtimeType}: ${transition.event.runtimeType}',
        metadata: {
          'bloc_type': bloc.runtimeType.toString(),
          'event_type': transition.event.runtimeType.toString(),
          'current_state_type': transition.currentState.runtimeType.toString(),
          'next_state_type': transition.nextState.runtimeType.toString(),
        },
      ));
      return true;
    }());
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.crashEvent,
        description: '${bloc.runtimeType}: error',
        metadata: {
          'bloc_type': bloc.runtimeType.toString(),
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString().substring(
                0,
                error.toString().length > 500 ? 500 : error.toString().length,
              ),
          'stack_top_3': stackTrace.toString().split('\n').take(3).join('\n'),
        },
      ));
      return true;
    }());
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    assert(() {
      final context = CausalityZone.currentContext();
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.userAction,
        description: '${bloc.runtimeType}: event ${event.runtimeType}',
        metadata: {
          'bloc_type': bloc.runtimeType.toString(),
          'event_type': event.runtimeType.toString(),
        },
      ));
      return true;
    }());
  }
}
