/// Unified crash recovery, explainable UI, and causality tracking for Flutter.
///
/// ## Quick Start
/// ```dart
/// import 'package:flutter_debug_trinity/flutter_debug_trinity.dart';
///
/// void main() {
///   runZonedGuarded(() {
///     WidgetsFlutterBinding.ensureInitialized();
///     FlutterDebugTrinity.initialize();
///     runApp(RecoverableApp(child: const MyApp()));
///   }, FlutterDebugTrinity.zonedErrorHandler);
/// }
/// ```
library flutter_debug_trinity;

// ── Core ─────────────────────────────────────────────────────────────────────
export 'core/causal_event.dart';
export 'core/trinity_event_bus.dart';
export 'core/context_zone.dart';
export 'core/causal_graph.dart';

// ── Recoverable App ──────────────────────────────────────────────────────────
export 'recoverable/recoverable_app.dart';
export 'recoverable/snapshot_manager.dart';
export 'recoverable/error_fingerprint.dart';
export 'recoverable/graceful_degrader.dart';
export 'recoverable/fallback_ui.dart';
// ErrorInterceptor is used internally — not exported directly.
// Use FlutterDebugTrinity.initialize() instead.

// ── UI Explainer ─────────────────────────────────────────────────────────────
export 'ui_explainer/layout_decision_recorder.dart';
export 'ui_explainer/explainable_render_box.dart';
export 'ui_explainer/constraint_chain_analyzer.dart';
export 'ui_explainer/explanation_engine.dart';
export 'ui_explainer/explanation_overlay.dart';
export 'ui_explainer/fix_suggestion.dart' hide FixSuggestion, FixCategory;

// ── Causality Adapters ──────────────────────────────────────────────────────
export 'causality/adapters/instrumented_notifier.dart';
export 'causality/adapters/provider_adapter.dart';
export 'causality/adapters/bloc_adapter.dart';
export 'causality/adapters/riverpod_adapter.dart';
export 'causality/adapters/network_adapter.dart';
export 'causality/causality_visualizer.dart';

// ── DevTools Extension ──────────────────────────────────────────────────────
export 'devtools/trinity_devtools_extension.dart';
export 'devtools/service_extension_bridge.dart';

// ── Entry Point ──────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'recoverable/error_interceptor.dart';
import 'core/causal_graph.dart';
import 'core/trinity_event_bus.dart';

/// The main entry point for flutter_debug_trinity.
///
/// Call [initialize] once in `main()`, before `runApp()`.
/// In release builds, all methods are no-ops.
class FlutterDebugTrinity {
  FlutterDebugTrinity._();

  static bool _initialized = false;

  /// Initialize the debug trinity system.
  ///
  /// Sets up:
  /// - Error interception (all 3 Flutter error zones)
  /// - Trinity event bus (shared broadcast bus)
  /// - Causal graph (DAG with auto-subscription to bus)
  ///
  /// **In release builds, this is a complete no-op.**
  static void initialize() {
    if (!kDebugMode) return;
    if (_initialized) return;

    ErrorInterceptor.initialize();
    // Ensure singletons are created and wired
    CausalGraph.instance.connectToBus();
    TrinityEventBus.instance;

    _initialized = true;
    debugPrint('[Trinity] Debug trinity initialized.');
  }

  /// Use as the error handler for `runZonedGuarded()`.
  ///
  /// ```dart
  /// runZonedGuarded(() {
  ///   runApp(const MyApp());
  /// }, FlutterDebugTrinity.zonedErrorHandler);
  /// ```
  static void zonedErrorHandler(Object error, StackTrace stack) {
    if (!kDebugMode) return;
    ErrorInterceptor.handleZoneError(error, stack);
  }

  /// Whether the system has been initialized.
  static bool get isInitialized => _initialized;

  /// Reset the entire system. For testing only.
  @visibleForTesting
  static void debugReset() {
    assert(() {
      _initialized = false;
      TrinityEventBus.instance.debugClear();
      ErrorInterceptor.debugReset();
      return true;
    }());
  }
}
