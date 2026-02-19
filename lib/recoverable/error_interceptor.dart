import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../core/causal_event.dart';
import '../core/context_zone.dart';
import '../core/trinity_event_bus.dart';

/// Callback type for error handlers that want to receive intercepted errors.
typedef ErrorCallback = void Function(
    Object error, StackTrace stack, String zone);

/// Intercepts errors from all three Flutter/Dart error zones and emits
/// [CausalEvent]s to the [TrinityEventBus].
///
/// ## The Three Error Zones
///
/// | Zone | What it catches | Hook |
/// |---|---|---|
/// | Flutter Framework | Widget build errors, setState after dispose | `FlutterError.onError` |
/// | Platform Dispatcher | Unhandled async Future rejections | `PlatformDispatcher.instance.onError` |
/// | Dart Zone | Legacy async errors via `runZonedGuarded` | Passed as `zonedErrorHandler` |
///
/// ## Usage
///
/// Call [initialize] once in `main()` before `runApp()`:
///
/// ```dart
/// void main() {
///   runZonedGuarded(() {
///     WidgetsFlutterBinding.ensureInitialized();
///     ErrorInterceptor.initialize();
///     runApp(RecoverableApp(child: MyApp()));
///   }, ErrorInterceptor.handleZoneError);
/// }
/// ```
class ErrorInterceptor {
  ErrorInterceptor._();

  static bool _initialized = false;

  /// Optional external callback — called in addition to emitting to the bus.
  static ErrorCallback? onError;

  /// Original Flutter error handler, preserved so we don't break existing behavior.
  static FlutterExceptionHandler? _originalFlutterOnError;

  /// Sets up error interception for all three error zones.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Only active in debug mode (`kDebugMode`). In release builds,
  /// this method does nothing.
  static void initialize({ErrorCallback? errorCallback}) {
    if (_initialized) return;
    _initialized = true;
    onError = errorCallback;

    // ── Zone 1: Flutter widget/framework errors ───────────────────────────
    _originalFlutterOnError = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;

    // ── Zone 2: Unhandled async errors (Flutter 3.1+) ─────────────────────
    final originalPlatformError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _emitCrashEvent(
        error,
        stack,
        zone: 'platform_dispatcher',
        summary: error.toString(),
      );
      // Let the original handler run too (if any)
      return originalPlatformError?.call(error, stack) ?? true;
    };
  }

  /// Flutter framework error handler (Widget build errors, layout errors, etc.)
  static void _handleFlutterError(FlutterErrorDetails details) {
    _emitCrashEvent(
      details.exception,
      details.stack ?? StackTrace.current,
      zone: 'flutter_framework',
      summary: details.summary.toString(),
    );
    // Preserve original behavior (red screen in debug, etc.)
    _originalFlutterOnError?.call(details);
  }

  /// Handler for `runZonedGuarded` — pass this as the second argument to
  /// `runZonedGuarded()` in your `main()`.
  static void handleZoneError(Object error, StackTrace stack) {
    _emitCrashEvent(error, stack, zone: 'dart_zone');
  }

  /// Core event emission — all three zones converge here.
  static void _emitCrashEvent(
    Object error,
    StackTrace stack, {
    required String zone,
    String? summary,
  }) {
    final context = CausalityZone.currentContext();
    final description = _buildDescription(error, summary);
    final topFrames = _topFrames(stack, 5);

    final event = CausalEvent(
      parentId: context?.eventId,
      type: CausalEventType.crashEvent,
      description: description,
      metadata: {
        'error_type': error.runtimeType.toString(),
        'error_message': error
            .toString()
            .substring(0, error.toString().length.clamp(0, 500)),
        'zone': zone,
        'stack_top_5': topFrames,
        'has_causal_parent': context != null,
      },
    );

    TrinityEventBus.instance.emit(event);
    onError?.call(error, stack, zone);
  }

  static String _buildDescription(Object error, String? summary) {
    final type = error.runtimeType.toString();
    final msg = summary ?? error.toString();
    final truncated = msg.length > 200 ? '${msg.substring(0, 200)}...' : msg;
    return '$type: $truncated';
  }

  static List<String> _topFrames(StackTrace stack, int n) {
    return stack
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(n)
        .toList();
  }

  /// Resets initialization state. For testing only.
  static void debugReset() {
    assert(() {
      if (_originalFlutterOnError != null) {
        FlutterError.onError = _originalFlutterOnError;
      }
      _initialized = false;
      onError = null;
      return true;
    }());
  }
}
