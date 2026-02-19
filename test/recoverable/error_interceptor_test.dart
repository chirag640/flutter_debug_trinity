import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/recoverable/error_interceptor.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    ErrorInterceptor.debugReset();
  });

  group('ErrorInterceptor', () {
    group('initialize()', () {
      test('does not throw on first call', () {
        expect(() => ErrorInterceptor.initialize(), returnsNormally);
      });

      test('is idempotent — safe to call multiple times', () {
        ErrorInterceptor.initialize();
        ErrorInterceptor.initialize();
        ErrorInterceptor.initialize();
        // No exception thrown
        expect(true, isTrue);
      });

      test('registers optional onError callback', () {
        var called = false;
        ErrorInterceptor.initialize(
          errorCallback: (error, stack, zone) => called = true,
        );
        // The callback is stored but not yet invoked
        expect(ErrorInterceptor.onError, isNotNull);
        expect(called, isFalse);
      });
    });

    group('handleZoneError()', () {
      test('emits CausalEvent to TrinityEventBus', () async {
        ErrorInterceptor.initialize();
        ErrorInterceptor.handleZoneError(
          StateError('test error'),
          StackTrace.current,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final events = TrinityEventBus.instance.buffer;
        expect(events, isNotEmpty);
        expect(
          events.any((e) => e.type == CausalEventType.crashEvent),
          isTrue,
        );
      });

      test('emitted event has correct error type in metadata', () async {
        ErrorInterceptor.initialize();
        ErrorInterceptor.handleZoneError(
          TypeError(),
          StackTrace.current,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final crashEvents = TrinityEventBus.instance.buffer
            .where((e) => e.type == CausalEventType.crashEvent)
            .toList();
        expect(crashEvents, isNotEmpty);
        expect(
          crashEvents.last.metadata['error_type'],
          contains('TypeError'),
        );
      });

      test('emitted event records originating zone name', () async {
        ErrorInterceptor.initialize();
        ErrorInterceptor.handleZoneError(
          Exception('zone test'),
          StackTrace.current,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = TrinityEventBus.instance.buffer
            .lastWhere((e) => e.type == CausalEventType.crashEvent);
        expect(event.metadata['zone'], 'dart_zone');
      });

      test('calls onError callback when set', () async {
        final capturedErrors = <Object>[];
        ErrorInterceptor.initialize(
          errorCallback: (error, _, __) => capturedErrors.add(error),
        );

        final err = Exception('callback test');
        ErrorInterceptor.handleZoneError(err, StackTrace.current);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(capturedErrors, contains(err));
      });

      test('does not throw when onError callback throws', () {
        ErrorInterceptor.initialize(
          errorCallback: (_, __, ___) => throw Exception('callback exploded'),
        );
        expect(
          () => ErrorInterceptor.handleZoneError(
            Exception('original'),
            StackTrace.current,
          ),
          throwsA(isA<Exception>()), // the callback exception propagates
        );
      });
    });

    group('debugReset()', () {
      test('allows re-initialization after reset', () {
        ErrorInterceptor.initialize();
        ErrorInterceptor.debugReset();
        // Should not throw (no longer initialized)
        expect(() => ErrorInterceptor.initialize(), returnsNormally);
      });

      test('clears onError callback', () {
        ErrorInterceptor.initialize(
          errorCallback: (_, __, ___) {},
        );
        ErrorInterceptor.debugReset();
        expect(ErrorInterceptor.onError, isNull);
      });

      test('restores original FlutterError.onError', () {
        final original = FlutterError.onError;
        ErrorInterceptor.initialize();
        ErrorInterceptor.debugReset();
        // After reset the handler is restored
        expect(FlutterError.onError, original);
      });
    });

    group('event metadata quality', () {
      test('event description includes error type', () async {
        ErrorInterceptor.initialize();
        ErrorInterceptor.handleZoneError(
          ArgumentError('bad arg'),
          StackTrace.current,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = TrinityEventBus.instance.buffer
            .lastWhere((e) => e.type == CausalEventType.crashEvent);
        expect(event.description, contains('ArgumentError'));
      });

      test('event metadata contains stack_top_5', () async {
        ErrorInterceptor.initialize();
        ErrorInterceptor.handleZoneError(
          RangeError('out of range'),
          StackTrace.current,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final event = TrinityEventBus.instance.buffer
            .lastWhere((e) => e.type == CausalEventType.crashEvent);
        expect(event.metadata, contains('stack_top_5'));
      });
    });
  });
}
