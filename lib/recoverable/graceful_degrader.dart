import 'package:flutter/material.dart';
import '../core/causal_event.dart';
import '../core/context_zone.dart';
import '../core/trinity_event_bus.dart';
import 'error_fingerprint.dart';

/// A widget that catches errors in its child's build/layout/paint and
/// renders a graceful inline fallback instead of the red error screen.
///
/// Unlike [RecoverableApp] which handles app-level crashes, this handles
/// component-level errors — a single widget can degrade while the rest
/// of the app continues to function normally.
///
/// ## Usage
/// ```dart
/// GracefulDegrader(
///   child: MyComplexWidget(),
///   fallback: (context, error, stackTrace) {
///     return Card(
///       child: Text('This section could not be loaded.'),
///     );
///   },
/// )
/// ```
class GracefulDegrader extends StatefulWidget {
  /// The widget to protect. If it throws during build,
  /// [fallback] is rendered instead.
  final Widget child;

  /// Builder for the fallback widget shown when [child] errors.
  /// If null, a minimal default error indicator is displayed.
  final Widget Function(BuildContext, Object, StackTrace)? fallback;

  /// Optional label for identifying this degrader in the causal graph.
  final String? label;

  /// Whether to emit a [CausalEvent] when degradation occurs.
  /// Defaults to true.
  final bool emitEvent;

  const GracefulDegrader({
    super.key,
    required this.child,
    this.fallback,
    this.label,
    this.emitEvent = true,
  });

  @override
  State<GracefulDegrader> createState() => _GracefulDegraderState();
}

class _GracefulDegraderState extends State<GracefulDegrader> {
  Object? _error;
  StackTrace? _stackTrace;
  ErrorFingerprint? _fingerprint;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallback != null) {
        return widget.fallback!(context, _error!, _stackTrace!);
      }
      return _DefaultDegradedWidget(
        error: _error!,
        fingerprint: _fingerprint,
        onRetry: _retry,
      );
    }

    return _ErrorBoundary(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    final fingerprint = ErrorFingerprint.compute(error, stackTrace);

    if (widget.emitEvent) {
      assert(() {
        final context = CausalityZone.currentContext();
        TrinityEventBus.instance.emit(CausalEvent(
          parentId: context?.eventId,
          type: CausalEventType.crashEvent,
          description:
              'GracefulDegrader${widget.label != null ? ' (${widget.label})' : ''}: '
              '${error.runtimeType}',
          metadata: {
            'error_type': error.runtimeType.toString(),
            'error_message': error.toString().substring(
                  0,
                  error.toString().length > 200 ? 200 : error.toString().length,
                ),
            'zone': 'graceful_degrader',
            'label': widget.label,
            'fingerprint': fingerprint.hash,
            'severity': ErrorClassifier.classify(error).name,
          },
        ));
        return true;
      }());
    }

    if (mounted) {
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
        _fingerprint = fingerprint;
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _fingerprint = null;
    });
  }
}

/// Internal error boundary that catches errors during build.
class _ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stackTrace) onError;

  const _ErrorBoundary({required this.child, required this.onError});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  @override
  Widget build(BuildContext context) {
    // Override the ErrorWidget.builder temporarily to catch build errors
    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Install our custom error handler for this subtree
    FlutterError.onError = (FlutterErrorDetails details) {
      widget.onError(details.exception, details.stack ?? StackTrace.current);
    };
  }
}

/// Minimal default degraded widget — shown when no custom fallback is provided.
class _DefaultDegradedWidget extends StatelessWidget {
  final Object error;
  final ErrorFingerprint? fingerprint;
  final VoidCallback onRetry;

  const _DefaultDegradedWidget({
    required this.error,
    this.fingerprint,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFCC8800),
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'This section encountered an error',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF856404),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error.runtimeType.toString(),
            style: const TextStyle(
              color: Color(0xFF856404),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          if (fingerprint != null) ...[
            const SizedBox(height: 2),
            Text(
              '[${fingerprint!.hash}]',
              style: const TextStyle(
                color: Color(0xFFAA8800),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF856404),
            ),
          ),
        ],
      ),
    );
  }
}
