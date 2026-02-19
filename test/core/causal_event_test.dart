import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';

void main() {
  group('CausalEventType', () {
    test('has all expected values', () {
      expect(CausalEventType.values, hasLength(7));
      expect(CausalEventType.values, contains(CausalEventType.userAction));
      expect(CausalEventType.values, contains(CausalEventType.stateChange));
      expect(CausalEventType.values, contains(CausalEventType.networkEvent));
      expect(CausalEventType.values, contains(CausalEventType.uiRebuild));
      expect(CausalEventType.values, contains(CausalEventType.crashEvent));
      expect(CausalEventType.values, contains(CausalEventType.layoutDecision));
      expect(CausalEventType.values, contains(CausalEventType.custom));
    });
  });

  group('CausalEvent', () {
    test('auto-generates id when not provided', () {
      final e1 = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test1',
      );
      final e2 = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test2',
      );
      expect(e1.id, isNotEmpty);
      expect(e2.id, isNotEmpty);
      expect(e1.id, isNot(e2.id)); // unique IDs
    });

    test('accepts custom id', () {
      final e = CausalEvent(
        id: 'custom-id-123',
        type: CausalEventType.stateChange,
        description: 'test',
      );
      expect(e.id, 'custom-id-123');
    });

    test('parentId is nullable', () {
      final withParent = CausalEvent(
        parentId: 'parent-1',
        type: CausalEventType.stateChange,
        description: 'child',
      );
      final withoutParent = CausalEvent(
        type: CausalEventType.stateChange,
        description: 'orphan',
      );
      expect(withParent.parentId, 'parent-1');
      expect(withoutParent.parentId, isNull);
    });

    test('timestamp auto-generates', () {
      final before = DateTime.now();
      final e = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      );
      final after = DateTime.now();
      expect(e.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(
          e.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('metadata defaults to empty map', () {
      final e = CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      );
      expect(e.metadata, isEmpty);
    });

    test('metadata can contain values', () {
      final e = CausalEvent(
        type: CausalEventType.networkEvent,
        description: 'test',
        metadata: {'url': 'https://example.com', 'status': 200},
      );
      expect(e.metadata['url'], 'https://example.com');
      expect(e.metadata['status'], 200);
    });

    test('duration is nullable', () {
      final withDuration = CausalEvent(
        type: CausalEventType.networkEvent,
        description: 'request',
        duration: const Duration(milliseconds: 350),
      );
      final withoutDuration = CausalEvent(
        type: CausalEventType.userAction,
        description: 'tap',
      );
      expect(withDuration.duration, const Duration(milliseconds: 350));
      expect(withoutDuration.duration, isNull);
    });

    group('toJson / fromJson', () {
      test('round-trips correctly', () {
        final original = CausalEvent(
          id: 'test-id',
          parentId: 'parent-id',
          type: CausalEventType.networkEvent,
          description: 'HTTP GET /api',
          metadata: {'status': 200},
          duration: const Duration(milliseconds: 100),
        );
        final json = original.toJson();
        final restored = CausalEvent.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.parentId, original.parentId);
        expect(restored.type, original.type);
        expect(restored.description, original.description);
        expect(restored.metadata['status'], 200);
        expect(restored.duration, const Duration(milliseconds: 100));
      });

      test('toJson includes all fields', () {
        final e = CausalEvent(
          id: 'abc',
          parentId: 'def',
          type: CausalEventType.crashEvent,
          description: 'crash',
          metadata: {'key': 'value'},
          duration: const Duration(seconds: 1),
        );
        final json = e.toJson();
        expect(json['id'], 'abc');
        expect(json['parentId'], 'def');
        expect(json['type'], 'crashEvent');
        expect(json['description'], 'crash');
        expect(json['metadata'], {'key': 'value'});
        expect(json['duration_ms'], 1000);
      });

      test('fromJson with null parentId', () {
        final json = {
          'id': 'test',
          'type': 'userAction',
          'description': 'test',
          'timestamp': DateTime.now().toIso8601String(),
          'metadata': <String, dynamic>{},
        };
        final e = CausalEvent.fromJson(json);
        expect(e.parentId, isNull);
      });

      test('fromJson throws on invalid type', () {
        final json = {
          'id': 'test',
          'type': 'invalidType',
          'description': 'test',
          'timestamp': DateTime.now().toIso8601String(),
          'metadata': <String, dynamic>{},
        };
        expect(() => CausalEvent.fromJson(json), throwsA(isA<ArgumentError>()));
      });
    });

    group('equality', () {
      test('events with same id are equal', () {
        final e1 = CausalEvent(
          id: 'same-id',
          type: CausalEventType.userAction,
          description: 'first',
        );
        final e2 = CausalEvent(
          id: 'same-id',
          type: CausalEventType.stateChange,
          description: 'second',
        );
        expect(e1, equals(e2));
      });

      test('events with different ids are not equal', () {
        final e1 = CausalEvent(
          id: 'id-1',
          type: CausalEventType.userAction,
          description: 'same',
        );
        final e2 = CausalEvent(
          id: 'id-2',
          type: CausalEventType.userAction,
          description: 'same',
        );
        expect(e1, isNot(equals(e2)));
      });

      test('hashCode based on id', () {
        final e1 = CausalEvent(
          id: 'hash-test',
          type: CausalEventType.userAction,
          description: 'test',
        );
        final e2 = CausalEvent(
          id: 'hash-test',
          type: CausalEventType.stateChange,
          description: 'other',
        );
        expect(e1.hashCode, equals(e2.hashCode));
      });
    });

    test('toString includes id and type', () {
      final e = CausalEvent(
        id: 'str-test',
        type: CausalEventType.userAction,
        description: 'button_tap',
      );
      final str = e.toString();
      expect(str, contains('str-test'));
      expect(str, contains('userAction'));
      expect(str, contains('button_tap'));
    });
  });
}
