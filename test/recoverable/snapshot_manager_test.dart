import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/recoverable/snapshot_manager.dart';

void main() {
  group('AppSnapshot', () {
    test('toJson includes all fields', () {
      final snapshot = AppSnapshot(
        snapshotId: 'snap-1',
        routeStack: ['/', '/home'],
        scrollPositions: {'home': 150.5},
        formInputs: {'email': 'test@test.com'},
        customState: {'theme': 'dark'},
        timestamp: DateTime(2024, 1, 15, 10, 30),
      );

      final json = snapshot.toJson();
      expect(json['snapshotId'], 'snap-1');
      expect(json['routeStack'], ['/', '/home']);
      expect(json['scrollPositions'], {'home': 150.5});
      expect(json['formInputs'], {'email': 'test@test.com'});
      expect(json['customState'], {'theme': 'dark'});
      expect(json['timestamp'], contains('2024-01-15'));
    });

    test('fromJsonSafe handles valid data', () {
      final json = {
        'snapshotId': 'snap-2',
        'routeStack': ['/', '/products'],
        'scrollPositions': {'list': 200.0},
        'formInputs': {'search': 'flutter'},
        'customState': {'cart_count': 3},
        'timestamp': '2024-01-15T10:30:00.000',
      };

      final snapshot = AppSnapshot.fromJsonSafe(json);
      expect(snapshot.snapshotId, 'snap-2');
      expect(snapshot.routeStack, ['/', '/products']);
      expect(snapshot.scrollPositions['list'], 200.0);
      expect(snapshot.formInputs['search'], 'flutter');
    });

    test('fromJsonSafe handles corrupt snapshotId', () {
      final snapshot = AppSnapshot.fromJsonSafe({
        'snapshotId': 42, // not a string
        'routeStack': ['/'],
        'scrollPositions': <String, dynamic>{},
        'formInputs': <String, dynamic>{},
        'customState': <String, dynamic>{},
        'timestamp': '2024-01-15T10:30:00.000',
      });
      expect(snapshot.snapshotId, 'unknown'); // fallback
    });

    test('fromJsonSafe handles corrupt routeStack', () {
      final snapshot = AppSnapshot.fromJsonSafe({
        'snapshotId': 'test',
        'routeStack': 'not a list',
        'scrollPositions': <String, dynamic>{},
        'formInputs': <String, dynamic>{},
        'customState': <String, dynamic>{},
        'timestamp': '2024-01-15T10:30:00.000',
      });
      expect(snapshot.routeStack, ['/']); // fallback
    });

    test('fromJsonSafe handles corrupt scrollPositions', () {
      final snapshot = AppSnapshot.fromJsonSafe({
        'snapshotId': 'test',
        'routeStack': ['/'],
        'scrollPositions': 'not a map',
        'formInputs': <String, dynamic>{},
        'customState': <String, dynamic>{},
        'timestamp': '2024-01-15T10:30:00.000',
      });
      expect(snapshot.scrollPositions, isEmpty); // fallback
    });

    test('fromJsonSafe handles corrupt timestamp', () {
      final before = DateTime.now();
      final snapshot = AppSnapshot.fromJsonSafe({
        'snapshotId': 'test',
        'routeStack': ['/'],
        'scrollPositions': <String, dynamic>{},
        'formInputs': <String, dynamic>{},
        'customState': <String, dynamic>{},
        'timestamp': 'not-a-date',
      });
      // Falls back to DateTime.now()
      expect(
          snapshot.timestamp
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
    });

    test('fromJsonSafe handles completely empty map', () {
      final snapshot = AppSnapshot.fromJsonSafe({});
      expect(snapshot.snapshotId, 'unknown');
      expect(snapshot.routeStack, ['/']);
      expect(snapshot.scrollPositions, isEmpty);
      expect(snapshot.formInputs, isEmpty);
      expect(snapshot.customState, isEmpty);
    });

    test('fromJsonSafe handles mixed valid/invalid fields', () {
      final snapshot = AppSnapshot.fromJsonSafe({
        'snapshotId': 'valid-id',
        'routeStack': 42, // invalid
        'scrollPositions': {'pos': 100.0}, // valid
        'formInputs': null, // invalid
        'customState': {'key': 'value'}, // valid
        'timestamp': '2024-06-15T12:00:00.000', // valid
      });
      expect(snapshot.snapshotId, 'valid-id');
      expect(snapshot.routeStack, ['/']); // fallback
      expect(snapshot.scrollPositions['pos'], 100.0);
      expect(snapshot.formInputs, isEmpty); // fallback
      expect(snapshot.customState['key'], 'value');
    });

    test('toString includes id and routes', () {
      final snapshot = AppSnapshot(
        snapshotId: 'debug',
        routeStack: ['/home'],
        scrollPositions: {},
        formInputs: {},
        customState: {},
        timestamp: DateTime.now(),
      );
      expect(snapshot.toString(), contains('debug'));
      expect(snapshot.toString(), contains('/home'));
    });
  });
}
