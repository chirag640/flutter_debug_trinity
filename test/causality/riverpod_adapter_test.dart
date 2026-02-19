import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/causality/adapters/riverpod_adapter.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('CausalityProviderObserver', () {
    test('didAddProvider emits state change event', () {
      final observer = CausalityProviderObserver();
      final container = ProviderContainer(observers: [observer]);

      // A simple provider that gets initialized on read
      final testProvider = Provider<int>((ref) => 42, name: 'testCounter');

      // Reading the provider triggers didAddProvider
      container.read(testProvider);

      final events = TrinityEventBus.instance.buffer.where(
        (e) =>
            e.description.contains('testCounter') &&
            e.description.contains('added'),
      );
      expect(events, isNotEmpty);

      final event = events.first;
      expect(event.type, CausalEventType.stateChange);
      expect(event.metadata['action'], 'add');
      expect(event.metadata['provider_name'], 'testCounter');

      container.dispose();
    });

    test('didUpdateProvider emits state change for StateProvider', () {
      final observer = CausalityProviderObserver();
      final container = ProviderContainer(observers: [observer]);
      final counterProvider = StateProvider<int>((ref) => 0, name: 'counter');

      // Read to initialize
      container.read(counterProvider);

      TrinityEventBus.instance.debugClear();

      // Update the state
      container.read(counterProvider.notifier).state = 1;

      final updateEvents = TrinityEventBus.instance.buffer.where(
        (e) => e.description.contains('updated'),
      );
      expect(updateEvents, isNotEmpty);

      final event = updateEvents.first;
      expect(event.metadata['action'], 'update');

      container.dispose();
    });

    test('didDisposeProvider emits state change on dispose', () {
      final observer = CausalityProviderObserver();
      final container = ProviderContainer(observers: [observer]);
      final testProvider = Provider<String>((ref) => 'hello', name: 'greeting');

      container.read(testProvider);
      TrinityEventBus.instance.debugClear();

      container.dispose();

      final disposeEvents = TrinityEventBus.instance.buffer.where(
        (e) => e.description.contains('disposed'),
      );
      expect(disposeEvents, isNotEmpty);

      final event = disposeEvents.first;
      expect(event.metadata['action'], 'dispose');
    });

    test('unnamed provider uses runtimeType', () {
      final observer = CausalityProviderObserver();
      final container = ProviderContainer(observers: [observer]);
      final unnamedProvider = Provider<int>((ref) => 99);

      container.read(unnamedProvider);

      final events = TrinityEventBus.instance.buffer.where(
        (e) => e.description.contains('added'),
      );
      expect(events, isNotEmpty);

      final event = events.first;
      expect(event.metadata['provider_name'], 'unnamed');

      container.dispose();
    });
  });
}
