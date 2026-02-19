import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/recoverable/error_fingerprint.dart';

void main() {
  group('ErrorFingerprint', () {
    test('compute produces stable hash for same error+stack', () {
      const error = FormatException('bad JSON');
      final stack = StackTrace.fromString('''
#0      main (test.dart:10)
#1      runTest (runner.dart:20)
#2      runAll (runner.dart:30)
''');

      final fp1 = ErrorFingerprint.compute(error, stack);
      final fp2 = ErrorFingerprint.compute(error, stack);

      expect(fp1.hash, fp2.hash);
      expect(fp1, equals(fp2));
    });

    test('different errors produce different hashes', () {
      final stack = StackTrace.fromString('#0 main (test.dart:10)');
      final fp1 = ErrorFingerprint.compute(const FormatException('a'), stack);
      final fp2 = ErrorFingerprint.compute(StateError('b'), stack);

      expect(fp1.hash, isNot(fp2.hash));
    });

    test('different stacks produce different hashes', () {
      const error = FormatException('same');
      final s1 = StackTrace.fromString(
          '#0      functionA (package:myapp/a.dart:10:5)');
      final s2 = StackTrace.fromString(
          '#0      functionB (package:myapp/b.dart:20:3)');

      final fp1 = ErrorFingerprint.compute(error, s1);
      final fp2 = ErrorFingerprint.compute(error, s2);

      expect(fp1.hash, isNot(fp2.hash));
    });

    test('captures error type', () {
      final fp = ErrorFingerprint.compute(
        RangeError('out of range'),
        StackTrace.fromString('#0 main (test.dart:1)'),
      );
      expect(fp.errorType, 'RangeError');
    });

    test('filters out dart: internal frames', () {
      final stack = StackTrace.fromString('''
#0      dart:core/int.dart (internal)
#1      myFunction (package:myapp/my_file.dart:42:5)
#2      dart:async/zone.dart (internal)
#3      anotherFunction (package:myapp/other.dart:10:3)
''');
      final fp = ErrorFingerprint.compute(Exception('test'), stack);
      // Should have extracted myFunction and anotherFunction, not dart: frames
      expect(fp.topFrames.length, 2);
      expect(fp.topFrames[0], contains('myFunction'));
      expect(fp.topFrames[1], contains('anotherFunction'));
    });

    test('equality by hash', () {
      const fp1 = ErrorFingerprint(
        hash: 'abc123',
        errorType: 'Test',
        topFrames: ['frame1'],
      );
      const fp2 = ErrorFingerprint(
        hash: 'abc123',
        errorType: 'Other',
        topFrames: ['frame2'],
      );
      expect(fp1, equals(fp2));
    });

    test('toString includes type and hash', () {
      const fp = ErrorFingerprint(
        hash: 'deadbeef',
        errorType: 'TestError',
        topFrames: [],
      );
      expect(fp.toString(), contains('TestError'));
      expect(fp.toString(), contains('deadbeef'));
    });
  });

  group('ErrorClassifier', () {
    test('classifies fatal errors', () {
      expect(ErrorClassifier.classify(AssertionError()), ErrorSeverity.fatal);
      expect(ErrorClassifier.classify(StateError('bad')), ErrorSeverity.fatal);
      expect(ErrorClassifier.classify(RangeError('out')), ErrorSeverity.fatal);
    });

    test('classifies degraded errors', () {
      expect(ErrorClassifier.classify(const FormatException('bad')),
          ErrorSeverity.degraded);
      expect(ErrorClassifier.classify(ArgumentError('wrong')),
          ErrorSeverity.degraded);
    });

    test('defaults to degraded for unknown errors', () {
      expect(ErrorClassifier.classify(Exception('generic')),
          ErrorSeverity.degraded);
    });

    test('classifies custom error by type name', () {
      // A custom error whose type name doesn't match any pattern
      final custom = _CustomUnknownError();
      expect(ErrorClassifier.classify(custom), ErrorSeverity.degraded);
    });
  });
}

class _CustomUnknownError implements Exception {
  @override
  String toString() => 'CustomUnknownError';
}
