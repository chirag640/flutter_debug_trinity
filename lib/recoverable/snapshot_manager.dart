import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a serializable snapshot of the app's meaningful state.
///
/// Used by [SnapshotManager] to persist state for crash recovery.
/// Every field is independently validated during deserialization — a corrupt
/// field becomes its empty default, never crashes the recovery process.
class AppSnapshot {
  /// Unique identifier for this snapshot.
  final String snapshotId;

  /// The navigation stack at snapshot time (e.g. ['/', '/products', '/cart']).
  final List<String> routeStack;

  /// Scroll positions by route or widget key.
  final Map<String, double> scrollPositions;

  /// Form field values keyed by form ID or field name.
  final Map<String, dynamic> formInputs;

  /// Custom app state serialized by the developer's [SnapshotSerializer].
  final Map<String, dynamic> customState;

  /// When this snapshot was taken.
  final DateTime timestamp;

  const AppSnapshot({
    required this.snapshotId,
    required this.routeStack,
    required this.scrollPositions,
    required this.formInputs,
    required this.customState,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'routeStack': routeStack,
        'scrollPositions': scrollPositions,
        'formInputs': formInputs,
        'customState': customState,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Safe deserialization: every field is validated independently.
  /// A corrupt field falls back to its default — never throws.
  factory AppSnapshot.fromJsonSafe(Map<String, dynamic> json) {
    return AppSnapshot(
      snapshotId: _safeString(json['snapshotId']) ?? 'unknown',
      routeStack: _safeStringList(json['routeStack']) ?? ['/'],
      scrollPositions: _safeDoubleMap(json['scrollPositions']) ?? {},
      formInputs: _safeMap(json['formInputs']) ?? {},
      customState: _safeMap(json['customState']) ?? {},
      timestamp: _safeDateTime(json['timestamp']) ?? DateTime.now(),
    );
  }

  static String? _safeString(dynamic v) => v is String ? v : null;

  static List<String>? _safeStringList(dynamic v) =>
      v is List ? v.whereType<String>().toList() : null;

  static Map<String, double>? _safeDoubleMap(dynamic v) {
    if (v is! Map) return null;
    try {
      return v.map<String, double>(
        (key, value) => MapEntry(
          key.toString(),
          (value is num) ? value.toDouble() : 0.0,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _safeMap(dynamic v) {
    if (v is! Map) return null;
    try {
      return Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _safeDateTime(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  @override
  String toString() =>
      'AppSnapshot(id=$snapshotId, routes=$routeStack, time=$timestamp)';
}

/// Manages persist/restore of [AppSnapshot] via SharedPreferences.
///
/// ## Crash Loop Detection
///
/// Tracks how many times the app has launched within a short window.
/// If the app crashes 3+ times within 60 seconds, [isInCrashLoop] returns true,
/// signaling that the recovery UI should bypass all Flutter widgets and show
/// a minimal platform-native fallback.
class SnapshotManager {
  SnapshotManager._internal();

  /// The singleton instance.
  static final SnapshotManager instance = SnapshotManager._internal();

  static const String _snapshotKey = 'trinity_snapshot';
  static const String _crashCountKey = 'trinity_crash_count';
  static const String _lastLaunchKey = 'trinity_last_launch';

  /// Save an [AppSnapshot] to persistent storage.
  Future<void> record(AppSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('[Trinity] Failed to record snapshot: $e');
    }
  }

  /// Restore the last saved snapshot.
  ///
  /// Returns null if no snapshot exists or if the stored data is corrupt.
  /// Corrupt data is automatically wiped.
  Future<AppSnapshot?> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snapshotKey);
      if (raw == null) return null;

      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        await wipe();
        return null;
      }
      return AppSnapshot.fromJsonSafe(json);
    } catch (_) {
      await wipe();
      return null;
    }
  }

  /// Wipe the stored snapshot. Called on corrupt data or user "Start Fresh".
  Future<void> wipe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_snapshotKey);
    } catch (e) {
      debugPrint('[Trinity] Failed to wipe snapshot: $e');
    }
  }

  /// Checks if the app is in a crash loop (3+ crashes within 60 seconds).
  ///
  /// Call once at app startup. If this returns true, show a minimal
  /// recovery view that doesn't depend on any Flutter widgets.
  Future<bool> isInCrashLoop() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_crashCountKey) ?? 0;
      final lastMs = prefs.getInt(_lastLaunchKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastMs;

      if (elapsed > 60000) {
        // More than 60 seconds since last launch — reset counter
        await prefs.setInt(_crashCountKey, 1);
        await prefs.setInt(_lastLaunchKey, now);
        return false;
      } else {
        final newCount = count + 1;
        await prefs.setInt(_crashCountKey, newCount);
        await prefs.setInt(_lastLaunchKey, now);
        return newCount >= 3;
      }
    } catch (_) {
      return false;
    }
  }

  /// Resets the crash counter. Call after a successful app launch
  /// (i.e. the user interacted without crashing).
  Future<void> resetCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashCountKey);
      await prefs.remove(_lastLaunchKey);
    } catch (_) {
      // Silently fail — this is non-critical
    }
  }
}
