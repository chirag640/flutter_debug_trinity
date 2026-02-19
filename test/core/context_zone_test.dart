import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/context_zone.dart';

void main() {
  group('CausalityContext', () {
    test('creates with required fields', () {
      final ctx = CausalityContext(
        eventId: 'evt-1',
        originDescription: 'test context',
        timestamp: DateTime.now(),
      );
      expect(ctx.eventId, 'evt-1');
      expect(ctx.originDescription, 'test context');
      expect(ctx.parentEventId, isNull);
      expect(ctx.timestamp, isNotNull);
    });

    test('parentEventId is optional', () {
      final ctx = CausalityContext(
        eventId: 'evt-2',
        parentEventId: 'parent-1',
        originDescription: 'child',
        timestamp: DateTime.now(),
      );
      expect(ctx.parentEventId, 'parent-1');
    });
  });

  group('CausalityZone', () {
    test('currentContext returns null outside a zone', () {
      expect(CausalityZone.currentContext(), isNull);
    });

    test('run creates a zone with context', () {
      CausalityZone.run('test_action', () {
        final ctx = CausalityZone.currentContext();
        expect(ctx, isNotNull);
        expect(ctx!.originDescription, 'test_action');
        expect(ctx.eventId, isNotEmpty);
      });
    });

    test('run returns the function result', () {
      final result = CausalityZone.run('compute', () => 42);
      expect(result, 42);
    });

    test('nested zones link parent-child', () {
      CausalityZone.run('outer', () {
        final outerCtx = CausalityZone.currentContext()!;

        CausalityZone.run('inner', () {
          final innerCtx = CausalityZone.currentContext()!;
          expect(innerCtx.parentEventId, outerCtx.eventId);
          expect(innerCtx.originDescription, 'inner');
        });
      });
    });

    test('context is isolated between runs', () {
      String? firstId;
      String? secondId;

      CausalityZone.run('first', () {
        firstId = CausalityZone.currentContext()?.eventId;
      });

      CausalityZone.run('second', () {
        secondId = CausalityZone.currentContext()?.eventId;
      });

      expect(firstId, isNotNull);
      expect(secondId, isNotNull);
      expect(firstId, isNot(secondId));
    });

    test('createContext generates unique IDs', () {
      final ctx1 = CausalityZone.createContext('a');
      final ctx2 = CausalityZone.createContext('b');
      expect(ctx1.eventId, isNot(ctx2.eventId));
    });

    test('triple-nested zones preserve chain', () {
      CausalityZone.run('level1', () {
        final l1 = CausalityZone.currentContext()!;

        CausalityZone.run('level2', () {
          final l2 = CausalityZone.currentContext()!;
          expect(l2.parentEventId, l1.eventId);

          CausalityZone.run('level3', () {
            final l3 = CausalityZone.currentContext()!;
            expect(l3.parentEventId, l2.eventId);
          });
        });
      });
    });
  });
}
