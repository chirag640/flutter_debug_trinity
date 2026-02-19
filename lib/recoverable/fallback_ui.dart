import 'package:flutter/material.dart';
import 'error_fingerprint.dart';
import 'snapshot_manager.dart';

/// A collection of pre-built fallback UI components for crash recovery
/// and degraded states.
///
/// These are built exclusively with core Material widgets and have no
/// external dependencies. They are designed to be crash-proof — if these
/// fail, the architecture has failed.

/// A full-screen fallback for fatal crashes.
///
/// This is used by [RecoverableApp] when not providing a custom
/// `recoveryScreenBuilder`. Can also be used standalone.
///
/// ```dart
/// FallbackScreen(
///   title: 'Something went wrong',
///   subtitle: 'The app encountered an unexpected error.',
///   onRestart: () => Navigator.of(context).pushReplacementNamed('/'),
///   onStartFresh: () {
///     SnapshotManager.instance.wipe();
///     Navigator.of(context).pushReplacementNamed('/');
///   },
/// )
/// ```
class FallbackScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final ErrorFingerprint? fingerprint;
  final AppSnapshot? lastSnapshot;
  final VoidCallback onRestart;
  final VoidCallback onStartFresh;
  final bool isInCrashLoop;

  const FallbackScreen({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle = 'An unexpected error occurred.',
    this.fingerprint,
    this.lastSnapshot,
    required this.onRestart,
    required this.onStartFresh,
    this.isInCrashLoop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE94560),
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isInCrashLoop
                    ? 'The app has crashed multiple times. '
                        'Your data is safe — try starting fresh.'
                    : subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (fingerprint != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${fingerprint!.errorType} [${fingerprint!.hash}]',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (lastSnapshot != null) ...[
                _FallbackButton(
                  label: 'Resume where I left off',
                  icon: Icons.restore,
                  color: const Color(0xFF0F3460),
                  onPressed: onRestart,
                ),
                const SizedBox(height: 12),
              ],
              _FallbackButton(
                label: 'Start fresh',
                icon: Icons.refresh,
                color: const Color(0xFFE94560),
                onPressed: onStartFresh,
              ),
              if (lastSnapshot != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Last saved: ${_formatTimestamp(lastSnapshot!.timestamp)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
  }
}

class _FallbackButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _FallbackButton({
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

/// A compact error banner suitable for showing at the top/bottom of a screen.
///
/// Less intrusive than a full fallback screen — used for recoverable errors
/// that don't need the full recovery flow.
class ErrorBanner extends StatelessWidget {
  final String message;
  final ErrorSeverity severity;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.message,
    this.severity = ErrorSeverity.recoverable,
    this.onDismiss,
    this.onRetry,
  });

  Color get _backgroundColor {
    switch (severity) {
      case ErrorSeverity.recoverable:
        return const Color(0xFFFFF3CD);
      case ErrorSeverity.degraded:
        return const Color(0xFFF8D7DA);
      case ErrorSeverity.fatal:
        return const Color(0xFFDC3545);
    }
  }

  Color get _textColor {
    switch (severity) {
      case ErrorSeverity.recoverable:
        return const Color(0xFF856404);
      case ErrorSeverity.degraded:
        return const Color(0xFF721C24);
      case ErrorSeverity.fatal:
        return Colors.white;
    }
  }

  IconData get _icon {
    switch (severity) {
      case ErrorSeverity.recoverable:
        return Icons.info_outline;
      case ErrorSeverity.degraded:
        return Icons.warning_amber_rounded;
      case ErrorSeverity.fatal:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _textColor, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: Icon(Icons.refresh, color: _textColor, size: 18),
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close, color: _textColor, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
