import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Classification of how severe an error is.
///
/// Used by [ErrorClassifier] to determine the recovery strategy:
/// - [recoverable]: transient — retry or ignore (e.g., timeout, 503).
/// - [degraded]: partial functionality loss — show fallback (e.g., parsing error).
/// - [fatal]: unrecoverable — must restart (e.g., null ref in core widget).
enum ErrorSeverity {
  /// Transient error. Retry or ignore.
  recoverable,

  /// Partial functionality loss. Display fallback.
  degraded,

  /// Unrecoverable. Recovery UI required.
  fatal,
}

/// A fingerprint uniquely identifying an error class.
///
/// Two error instances that have the same root cause (same error type
/// and same top 3 stack frames) will share the same fingerprint, even
/// if they occur at different times or with different field values.
class ErrorFingerprint {
  /// The SHA-256 hash fingerprint string.
  final String hash;

  /// The error type name used in the fingerprint.
  final String errorType;

  /// The top stack frames used in the fingerprint.
  final List<String> topFrames;

  const ErrorFingerprint({
    required this.hash,
    required this.errorType,
    required this.topFrames,
  });

  /// Compute a fingerprint from an error and its stack trace.
  ///
  /// The fingerprint is a SHA-256 hash of:
  ///   `errorType + top3StackFrames`
  ///
  /// This groups "same-root-cause" crashes together regardless of
  /// field values, timestamps, or unrelated stack frames.
  factory ErrorFingerprint.compute(Object error, StackTrace stackTrace) {
    final errorType = error.runtimeType.toString();
    final frames = _extractTopFrames(stackTrace, count: 3);
    final input = '$errorType|${frames.join('|')}';
    final digest = sha256.convert(utf8.encode(input));

    return ErrorFingerprint(
      hash: digest.toString(),
      errorType: errorType,
      topFrames: frames,
    );
  }

  /// Extract the top [count] meaningful stack frames from a [StackTrace].
  ///
  /// Filters out:
  /// - Dart SDK internal frames (dart:*)
  /// - Flutter framework frames (package:flutter/*)
  /// - Empty or malformed frames
  static List<String> _extractTopFrames(StackTrace trace, {int count = 3}) {
    final lines = trace.toString().split('\n');
    final meaningful = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Skip Dart SDK internals (dart:core, dart:async, etc.)
      // In stack traces, Dart SDK frames look like:
      //   #0  _Something (dart:async/zone.dart:1234)
      // We match (dart: and line-start dart:
      if (trimmed.contains('(dart:')) continue;
      if (RegExp(r'^#\d+\s+dart:').hasMatch(trimmed)) continue;
      // Skip Flutter framework internals
      if (trimmed.contains('package:flutter/')) continue;

      // Normalize: strip leading #N prefix
      final normalized = trimmed.replaceFirst(RegExp(r'^#\d+\s+'), '');
      meaningful.add(normalized);
      if (meaningful.length >= count) break;
    }

    return meaningful;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorFingerprint &&
          runtimeType == other.runtimeType &&
          hash == other.hash;

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() => 'ErrorFingerprint($errorType, hash=$hash)';
}

/// Classifies errors into severity levels based on error type patterns.
///
/// Uses a rule-based system matching the error's `runtimeType` name:
/// - Fatal: assertion, null, range, state, type errors
/// - Degraded: format, codec, argument errors
/// - Recoverable: network-related, timeout errors
///
/// If no rule matches, defaults to [ErrorSeverity.degraded].
class ErrorClassifier {
  /// Classify an error into a [ErrorSeverity] level.
  static ErrorSeverity classify(Object error) {
    final typeName = error.runtimeType.toString().toLowerCase();

    // Fatal — framework assertions, null dereferences, state corruption
    if (_matchesAny(typeName, _fatalPatterns)) {
      return ErrorSeverity.fatal;
    }

    // Recoverable — transient network / timeout errors
    if (_matchesAny(typeName, _recoverablePatterns)) {
      return ErrorSeverity.recoverable;
    }

    // Degraded — parsing, conversion, argument issues
    if (_matchesAny(typeName, _degradedPatterns)) {
      return ErrorSeverity.degraded;
    }

    // Default to degraded
    return ErrorSeverity.degraded;
  }

  static bool _matchesAny(String typeName, List<String> patterns) {
    return patterns.any((pattern) => typeName.contains(pattern));
  }

  static const _fatalPatterns = [
    'assertion',
    'null',
    'nosuchmethoderror',
    'rangeerror',
    'stateerror',
    'typeerror',
    'stackoverflow',
    'outofmemory',
  ];

  static const _recoverablePatterns = [
    'socket',
    'timeout',
    'http',
    'network',
    'connection',
    'handshake',
    'certificate',
    'dns',
  ];

  static const _degradedPatterns = [
    'format',
    'codec',
    'argument',
    'cast',
    'conversion',
    'parse',
    'json',
    'encoding',
  ];
}
