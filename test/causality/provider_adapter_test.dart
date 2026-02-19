import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/causality/adapters/provider_adapter.dart';

class TestNotifier extends CausalChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

class CustomDescNotifier extends CausalChangeNotifier {
  @override
  String get causalDescription => 'custom: my_event';

  void trigger() => notifyListeners();
}

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
  });

  group('CausalChangeNotifier', () {
    test('notifyListeners emits causal event', () {
      final notifier = TestNotifier();
      notifier.increment();

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer, hasLength(1));
      expect(buffer.first.type, CausalEventType.stateChange);
      expect(buffer.first.description, contains('TestNotifier'));
    });

    test('metadata includes notifier_type', () {
      final notifier = TestNotifier();
      notifier.increment();

      final event = TrinityEventBus.instance.buffer.first;
      expect(event.metadata['notifier_type'], 'TestNotifier');
    });

    test('custom causalDescription is used', () {
      final notifier = CustomDescNotifier();
      notifier.trigger();

      final event = TrinityEventBus.instance.buffer.first;
      expect(event.description, 'custom: my_event');
    });

    test('still calls super.notifyListeners()', () {
      final notifier = TestNotifier();
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.increment();
      expect(callCount, 1);
      expect(notifier.count, 1);
    });

    test('multiple notifications emit multiple events', () {
      final notifier = TestNotifier();
      notifier.increment();
      notifier.increment();
      notifier.increment();

      expect(TrinityEventBus.instance.buffer, hasLength(3));
    });
  });

  group('CausalProxyUpdate', () {
    test('track returns the created value', () {
      final result = CausalProxyUpdate.track('MyProvider', () => 42);
      expect(result, 42);
    });

    test('track emits causal event', () {
      CausalProxyUpdate.track('CartService', () => 'created');

      final buffer = TrinityEventBus.instance.buffer;
      expect(buffer, hasLength(1));
      expect(buffer.first.description, contains('ProxyProvider'));
      expect(buffer.first.description, contains('CartService'));
    });

    test('track metadata includes provider_name', () {
      CausalProxyUpdate.track('AuthService', () => null);

      final event = TrinityEventBus.instance.buffer.first;
      expect(event.metadata['provider_name'], 'AuthService');
    });
  });
}
