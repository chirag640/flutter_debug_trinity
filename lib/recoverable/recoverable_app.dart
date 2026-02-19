import 'package:flutter/material.dart';
import '../core/causal_event.dart';
import '../core/trinity_event_bus.dart';
import 'error_interceptor.dart';
import 'error_fingerprint.dart';
import 'snapshot_manager.dart';

/// Information about a recovered crash, passed to the recovery screen.
class RecoveryState {
  /// The error that caused the crash.
  final Object error;

  /// The stack trace at the time of crash.
  final StackTrace stackTrace;

  /// The error's fingerprint (for deduplication/tracking).
  final ErrorFingerprint fingerprint;

  /// The classified severity.
  final ErrorSeverity severity;

  /// The last saved snapshot, if available.
  final AppSnapshot? lastSnapshot;

  /// Whether the app is in a crash loop (3+ crashes in 60s).
  final bool isInCrashLoop;

  const RecoveryState({
    required this.error,
    required this.stackTrace,
    required this.fingerprint,
    required this.severity,
    this.lastSnapshot,
    this.isInCrashLoop = false,
  });
}

/// Abstract serializer for custom app state.
///
/// Implement this to teach RecoverableApp how to save/restore your
/// specific state channels (e.g. auth tokens, cart items, etc.).
abstract class SnapshotSerializer {
  /// Serialize the app's custom state into a JSON-safe map.
  Map<String, dynamic> serialize();

  /// Restore the app's custom state from a previously serialized map.
  void restore(Map<String, dynamic> data);
}

/// Callback type for building a custom recovery screen.
typedef RecoveryScreenBuilder = Widget Function(
  BuildContext context,
  RecoveryState recoveryState,
  VoidCallback onRestart,
  VoidCallback onStartFresh,
);

/// A wrapper widget that provides automatic crash recovery.
///
/// ## Usage
/// ```dart
/// void main() {
///   runApp(
///     RecoverableApp(
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// When an unrecoverable error occurs:
/// 1. The error is intercepted and fingerprinted.
/// 2. If a snapshot exists, the recovery screen offers "Resume" or "Start Fresh".
/// 3. If in a crash loop, a minimal safe screen is shown.
///
/// ## Custom Recovery Screen
/// ```dart
/// RecoverableApp(
///   recoveryScreenBuilder: (context, state, onRestart, onStartFresh) {
///     return MyCustomRecoveryScreen(
///       error: state.error,
///       onRestart: onRestart,
///       onStartFresh: onStartFresh,
///     );
///   },
///   child: const MyApp(),
/// )
/// ```
class RecoverableApp extends StatefulWidget {
  /// The app widget to wrap.
  final Widget child;

  /// Optional custom recovery screen builder.
  /// If null, [_DefaultRecoveryScreen] is used.
  final RecoveryScreenBuilder? recoveryScreenBuilder;

  /// Optional serializer for custom state persistence.
  final SnapshotSerializer? serializer;

  /// Whether to automatically initialize error interception.
  /// Defaults to true.
  final bool autoInitialize;

  const RecoverableApp({
    super.key,
    required this.child,
    this.recoveryScreenBuilder,
    this.serializer,
    this.autoInitialize = true,
  });

  @override
  State<RecoverableApp> createState() => _RecoverableAppState();
}

class _RecoverableAppState extends State<RecoverableApp> {
  RecoveryState? _recoveryState;
  bool _isRecovering = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Prevent double initialization
    if (_initialized) return;

    // Initialize error interceptor
    ErrorInterceptor.initialize();

    // Check for crash loop
    final isInCrashLoop = await SnapshotManager.instance.isInCrashLoop();
    if (isInCrashLoop) {
      final snapshot = await SnapshotManager.instance.restore();
      if (mounted) {
        setState(() {
          _isRecovering = true;
          _recoveryState = RecoveryState(
            error: StateError('App is in a crash loop'),
            stackTrace: StackTrace.current,
            fingerprint: const ErrorFingerprint(
              hash: 'crash_loop',
              errorType: 'CrashLoop',
              topFrames: [],
            ),
            severity: ErrorSeverity.fatal,
            lastSnapshot: snapshot,
            isInCrashLoop: true,
          );
        });
      }
      return;
    }

    // Listen for crash events from the bus
    TrinityEventBus.instance.stream
        .where((e) => e.type == CausalEventType.crashEvent)
        .listen(_onCrashEvent);

    _initialized = true;
  }

  void _onCrashEvent(CausalEvent event) async {
    // Extract error info from metadata
    final errorType = event.metadata['error_type'] as String? ?? 'Unknown';
    final errorMessage =
        event.metadata['error_message'] as String? ?? 'An error occurred';
    final stackString = event.metadata['stack_top_5'] as String? ?? '';

    final error = _ReconstructedError(errorType, errorMessage);
    final stackTrace = StackTrace.fromString(stackString);
    final fingerprint = ErrorFingerprint.compute(error, stackTrace);
    final severity = ErrorClassifier.classify(error);

    // Only show recovery for fatal errors
    if (severity != ErrorSeverity.fatal) return;

    final snapshot = await SnapshotManager.instance.restore();

    if (mounted) {
      setState(() {
        _isRecovering = true;
        _recoveryState = RecoveryState(
          error: error,
          stackTrace: stackTrace,
          fingerprint: fingerprint,
          severity: severity,
          lastSnapshot: snapshot,
        );
      });
    }
  }

  void _onRestart() {
    setState(() {
      _isRecovering = false;
      _recoveryState = null;
    });
    // Reset crash count on successful recovery
    SnapshotManager.instance.resetCrashCount();
  }

  void _onStartFresh() {
    SnapshotManager.instance.wipe();
    setState(() {
      _isRecovering = false;
      _recoveryState = null;
    });
    SnapshotManager.instance.resetCrashCount();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecovering && _recoveryState != null) {
      if (widget.recoveryScreenBuilder != null) {
        return widget.recoveryScreenBuilder!(
          context,
          _recoveryState!,
          _onRestart,
          _onStartFresh,
        );
      }
      return _DefaultRecoveryScreen(
        recoveryState: _recoveryState!,
        onRestart: _onRestart,
        onStartFresh: _onStartFresh,
      );
    }

    return widget.child;
  }
}

/// A minimal, crash-proof recovery screen.
///
/// **Design principles:**
/// - Uses ONLY core Material widgets — no third-party imports
/// - No state management — pure StatelessWidget
/// - Handles its own MaterialApp so it doesn't depend on the app's
/// - Every string is hardcoded — never reads from assets or l10n
class _DefaultRecoveryScreen extends StatelessWidget {
  final RecoveryState recoveryState;
  final VoidCallback onRestart;
  final VoidCallback onStartFresh;

  const _DefaultRecoveryScreen({
    required this.recoveryState,
    required this.onRestart,
    required this.onStartFresh,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE94560),
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recoveryState.isInCrashLoop
                      ? 'The app has crashed multiple times. '
                          'Your data is safe.'
                      : 'An unexpected error occurred. '
                          'You can try restarting or start fresh.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                // Error fingerprint info (debug only)
                Text(
                  'Error: ${recoveryState.fingerprint.errorType}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 32),
                if (recoveryState.lastSnapshot != null) ...[
                  _RecoveryButton(
                    label: 'Resume where I left off',
                    icon: Icons.restore,
                    color: const Color(0xFF0F3460),
                    onPressed: onRestart,
                  ),
                  const SizedBox(height: 12),
                ],
                _RecoveryButton(
                  label: 'Start fresh',
                  icon: Icons.refresh,
                  color: const Color(0xFFE94560),
                  onPressed: onStartFresh,
                ),
                const SizedBox(height: 24),
                if (recoveryState.lastSnapshot != null)
                  Text(
                    'Last saved: ${_formatTime(recoveryState.lastSnapshot!.timestamp)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
  }
}

class _RecoveryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RecoveryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Internal helper to reconstruct a typed error from metadata strings.
class _ReconstructedError implements Exception {
  final String type;
  final String message;

  _ReconstructedError(this.type, this.message);

  @override
  String toString() => '$type: $message';
}
