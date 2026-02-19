import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/causality/adapters/bloc_adapter.dart';

// Simple test Cubit
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

// Simple test Bloc
abstract class CounterEvent {}

class IncrementEvent extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
  }
}

void main() {
  late CausalityBlocObserver observer;

  setUp(() {
    TrinityEventBus.instance.debugClear();
    observer = CausalityBlocObserver();
    Bloc.observer = observer;
  });

  group('CausalityBlocObserver', () {
    test('onChange records state change for Cubit', () {
      final cubit = CounterCubit();
      cubit.increment();

      final events = TrinityEventBus.instance.buffer.where(
        (e) => e.description.contains('CounterCubit'),
      );
      expect(events, isNotEmpty);

      final stateEvent = events.firstWhere(
        (e) => e.description.contains('state changed'),
      );
      expect(stateEvent.type, CausalEventType.stateChange);
      expect(stateEvent.metadata['bloc_type'], 'CounterCubit');

      cubit.close();
    });

    test('onTransition records transition for Bloc', () async {
      final bloc = CounterBloc();
      bloc.add(IncrementEvent());

      // Give the bloc time to process
      await Future.delayed(const Duration(milliseconds: 50));

      final events = TrinityEventBus.instance.buffer.where(
        (e) =>
            e.description.contains('CounterBloc') &&
            e.description.contains('IncrementEvent'),
      );
      expect(events, isNotEmpty);

      await bloc.close();
    });

    test('onEvent records events for Bloc', () async {
      final bloc = CounterBloc();
      bloc.add(IncrementEvent());

      await Future.delayed(const Duration(milliseconds: 50));

      final userActionEvents = TrinityEventBus.instance.buffer.where(
        (e) =>
            e.type == CausalEventType.userAction &&
            e.description.contains('CounterBloc'),
      );
      expect(userActionEvents, isNotEmpty);

      await bloc.close();
    });

    test('onError records error as crash event', () {
      final cubit = CounterCubit();

      // Manually trigger onError through the observer
      observer.onError(cubit, Exception('test error'), StackTrace.current);

      final errorEvents = TrinityEventBus.instance.buffer.where(
        (e) =>
            e.type == CausalEventType.crashEvent &&
            e.description.contains('CounterCubit'),
      );
      expect(errorEvents, isNotEmpty);

      final errorEvent = errorEvents.first;
      expect(errorEvent.metadata['error_type'], '_Exception');

      cubit.close();
    });

    test('error metadata truncates long messages', () {
      final cubit = CounterCubit();
      final longError = 'x' * 1000;

      observer.onError(cubit, longError, StackTrace.current);

      final errorEvent = TrinityEventBus.instance.buffer.firstWhere(
        (e) => e.type == CausalEventType.crashEvent,
      );
      expect(
        (errorEvent.metadata['error_message'] as String).length,
        lessThanOrEqualTo(500),
      );

      cubit.close();
    });
  });
}
