## 0.1.0

### The Complete Debug Trinity

First full release of `flutter_debug_trinity` — a unified crash recovery, layout explanation, and causality tracking system for Flutter.

#### Core

- `TrinityEventBus` — singleton broadcast event bus with circular buffer (500 events)
- `CausalEvent` — typed, serializable event model with parent/child relationships
- `CausalGraph` — directed acyclic graph with auto-pruning, ancestor/descendant queries, and JSON export
- `CausalityZone` — Dart Zone–based context propagation for automatic event parentage

#### Recoverable App

- `ErrorInterceptor` — hooks into Flutter's three error zones (FlutterError, PlatformDispatcher, runZonedGuarded)
- `SnapshotManager` — persists route stack, scroll positions, form inputs, and custom state for crash recovery
- `ErrorFingerprint` — SHA-256 fingerprinting with severity classification for deduplication
- `RecoverableApp` — drop-in widget that wraps your MaterialApp with full crash recovery
- `GracefulDegrader` — component-level error boundary with retry and fallback support
- `FallbackScreen` / `ErrorBanner` — pre-built recovery UIs with crash-loop detection

#### UI Explainer

- `LayoutDecisionRecorder` — records constraints/size for every RenderBox
- `ExplainableRenderBox` — custom RenderBox that emits layout decisions to the event bus
- `ConstraintChainAnalyzer` — traces constraint chains from root to overflowing widget
- `ExplanationEngine` — generates plain-English explanations with severity levels
- `ExplanationOverlay` — debug overlay showing live layout explanations
- `FixSuggestionEngine` — context-aware fix recommendations (Expanded, scrollable, BoxFit, etc.)

#### Causality Adapters

- `InstrumentedNotifier` — ChangeNotifier mixin that emits causal events
- `ProviderAdapter` — Provider/ChangeNotifierProvider integration
- `BlocAdapter` — flutter_bloc BlocObserver integration
- `RiverpodAdapter` — flutter_riverpod ProviderObserver integration
- `NetworkAdapter` — Dio interceptor + http Client wrapper for API call tracing

#### DevTools Extension

- `ServiceExtensionBridge` — 6 VM service extensions for real-time DevTools communication
- `TimelinePanel` — filterable event timeline with type-based color coding
- `GraphPanel` — DAG visualization of the causal graph
- `ExplanationPanel` — layout explanation viewer with fix suggestions
- `TrinityDevToolsExtension` — tabbed DevTools panel entry point
- `TrinityDebugFab` — floating action button for in-app inspection

#### Testing

- 232 passing tests across 22 test files
- Zero analysis warnings
- Integration tests verifying end-to-end event bus → causal graph flow
