# FLUTTER DEBUG TRINITY — MASTER CONTEXT FILE

> Living memory document. Update this file every session. Never delete history — append DONE markers.

---

## WHAT THIS PROJECT IS

One unified Dart/Flutter package called **`flutter_debug_trinity`** that ships three tightly integrated
sub-systems under a single import, zero-config entry point.

| Sub-system          | Role                                         | Key Hook Point                                                    |
| ------------------- | -------------------------------------------- | ----------------------------------------------------------------- |
| `recoverable_app`   | Intercepts all crash types, restores session | `FlutterError.onError` + `runZonedGuarded` + `PlatformDispatcher` |
| `ui_explainer`      | Explains layout decisions in plain English   | `RenderObject.performLayout()` mixins                             |
| `causality_flutter` | Causal graph across async state changes      | Dart Zone metadata propagation                                    |

All three talk to a **shared central event bus** (`TrinityEventBus`). Every event from every
sub-system flows into the same `CausalGraph`. This means:

- A crash recorded by `recoverable_app` appears as a node in `causality_flutter`'s graph.
- An overflow detected by `ui_explainer` is linked to the state mutation that caused it.
- The DevTools extension shows ALL three event streams in one unified timeline.

---

## CURRENT STATUS — UPDATE EVERY SESSION

```
DATE LAST UPDATED : 2025-07-08
CURRENT PHASE     : IMPLEMENTATION COMPLETE
CURRENT WEEK      : N/A
ACTIVE TASK       : None — full implementation done
BLOCKERS          : None
NEXT ACTION       : Publish to pub.dev or integrate into your apps

VERIFICATION:
  flutter analyze : No issues found!
  flutter test    : 118/118 passed
```

---

## THE UNIFIED PACKAGE ARCHITECTURE (CONCEPTUAL MAP)

```
flutter_debug_trinity/
│
├── lib/
│   ├── flutter_debug_trinity.dart          ← Single export barrel
│   │
│   ├── core/
│   │   ├── trinity_event_bus.dart          ← Shared event bus (ALL events go here)
│   │   ├── causal_event.dart               ← Unified event model
│   │   ├── causal_graph.dart               ← DAG storage + traversal
│   │   └── context_zone.dart               ← Zone-based causality propagation
│   │
│   ├── recoverable/
│   │   ├── recoverable_app.dart            ← Top-level widget wrapper
│   │   ├── error_interceptor.dart          ← All 3 error zones
│   │   ├── snapshot_manager.dart           ← State serialization + restore
│   │   ├── fallback_ui.dart                ← Crash-proof recovery screen
│   │   ├── error_fingerprint.dart          ← Hash + classify errors
│   │   └── graceful_degrader.dart          ← Inline error widgets
│   │
│   ├── ui_explainer/
│   │   ├── explainable_render_box.dart     ← RenderBox mixin
│   │   ├── layout_decision_recorder.dart   ← Circular buffer of events
│   │   ├── constraint_chain_analyzer.dart  ← Walk tree to find root
│   │   ├── explanation_engine.dart         ← Events → plain English
│   │   ├── fix_suggestion.dart             ← Pattern → fix mapping
│   │   └── explanation_overlay.dart        ← Debug overlay widget
│   │
│   ├── causality/
│   │   ├── causality_zone.dart             ← Zone with CausalityContext
│   │   ├── event_graph.dart                ← DAG + pruning + serialization
│   │   ├── adapters/
│   │   │   ├── provider_adapter.dart
│   │   │   ├── bloc_adapter.dart
│   │   │   ├── riverpod_adapter.dart
│   │   │   └── network_adapter.dart
│   │   └── causality_visualizer.dart       ← In-app overlay
│   │
│   └── devtools/
│       ├── trinity_devtools_extension.dart ← DevTools panel entry
│       ├── service_extension_bridge.dart   ← VM service protocol
│       └── panel/
│           ├── timeline_panel.dart
│           ├── graph_panel.dart
│           └── explanation_panel.dart
│
├── test/
│   ├── recoverable/
│   ├── ui_explainer/
│   └── causality/
│
├── example/
│   └── lib/
│       └── main.dart                       ← Demo app showing all 3 in action
│
├── CONTEXT.md                              ← THIS FILE — always update
├── PROJECT_STATE.json                      ← Machine-readable progress state
├── ARCHITECTURE.md                         ← Deep design decisions
├── IMPLEMENTATION_GUIDE.md                 ← Exact code steps
└── pubspec.yaml
```

---

## PHASE ROADMAP — MASTER CHECKLIST

Mark items: `[ ]` = not started, `[~]` = in progress, `[x]` = done

---

### PHASE 0 — Foundation (Weeks 1–2)

> Goal: Understand everything before writing production code. No skipping.

#### Zone & Async Mastery

- [ ] Read Dart Zones official docs in full (`dart.dev/articles/zones`)
- [ ] Experiment: `Zone.current.fork(zoneValues: {'causal_id': 1})` and prove value survives `await`
- [ ] Prove Zone context survives: `Future.delayed` → `then` → inner `await`
- [ ] Document which async constructs break Zone propagation (isolates do, async\* partially does)
- [ ] Study `runZonedGuarded` — understand how it wraps `FlutterError.onError`
- [ ] Write 10 Zone experiments as standalone Dart scripts in `experiments/zones/`

#### Flutter Error Architecture Mastery

- [ ] Read Flutter source: `FlutterError.onError` (framework/lib/src/foundation/assertions.dart)
- [ ] Read Flutter source: `ErrorWidget.builder` (how the red screen is constructed)
- [ ] Experiment: throw in `build()`, `initState()`, `async callback` — log which zone catches each
- [ ] Study `PlatformDispatcher.instance.onError` — what it catches vs `FlutterError.onError`
- [ ] Write tiny 'error logger' app: catches from all 3 zones, logs to console, no recovery yet

#### Render Pipeline Mastery

- [ ] Read entire `RenderObject` class (flutter/lib/src/rendering/object.dart)
- [ ] Read `RenderBox` — understand `BoxConstraints`, `performLayout()`, `Size`, `Offset`
- [ ] Study `GestureArenaManager.sweep()` — understand winner selection
- [ ] Override `performLayout()` in a custom `RenderBox`, print constraints received + size reported
- [ ] Map a 3-screen app's widget tree → render tree manually on paper

#### Deliverable: Phase 0 Complete When

- [ ] You can explain Zone propagation across 3 await boundaries verbally
- [ ] You can predict which error zone catches a given exception type
- [ ] You can draw the constraint propagation tree of any simple Flutter screen

---

### PHASE 1 — Core Infrastructure (Weeks 3–4)

> Goal: Build the shared backbone all 3 sub-systems depend on.

#### TrinityEventBus

- [ ] Create `CausalEventType` enum: `UserAction`, `StateChange`, `NetworkEvent`, `UIRebuild`, `CrashEvent`, `LayoutDecision`, `Custom`
- [ ] Create `CausalEvent` model: `id` (UUID), `parentId` (nullable), `type`, `description`, `timestamp`, `metadata` (Map), `duration` (for async spans)
- [ ] Implement `TrinityEventBus` singleton: `emit(CausalEvent)`, `stream` (broadcast StreamController), `buffer` (last 500 events circular)
- [ ] Write 20 unit tests for `CausalEvent` serialization with all edge cases

#### CausalityZone

- [ ] Implement `CausalityContext`: `eventId`, `parentEventId`, `originDescription`, `timestamp`
- [ ] Implement `CausalityZone.run(description, fn)`: forks current Zone with `CausalityContext`, runs `fn` inside it
- [ ] Implement `CausalityZone.currentContext()`: reads context from `Zone.current`
- [ ] Prove: context from `CausalityZone.run()` is readable inside a `Future` created inside it, after 3 await boundaries
- [ ] Write 15 unit tests covering Zone propagation scenarios

#### CausalGraph (DAG)

- [ ] Implement `CausalGraph`: in-memory DAG, nodes are `CausalEvent`, edges are `(childId → parentId)`
- [ ] `addEvent(event)`: adds node, sets parent edge if `parentId` not null
- [ ] `getAncestors(eventId)`: returns ordered chain from event to root
- [ ] `getDescendants(eventId)`: returns all events caused by this event
- [ ] `findRootCause(eventId)`: returns the root `UserAction` or `NetworkEvent` ancestor
- [ ] Graph pruning: sliding window of last 300 seconds OR last 2000 events, whichever triggers first
- [ ] `toJson()` / `fromJson()`: full graph serialization for bug reports
- [ ] Write 30 unit tests for all graph operations including pruning edge cases

#### Deliverable: Phase 1 Complete When

- [ ] `TrinityEventBus` emits events and `CausalGraph` stores them with correct parent chains
- [ ] Zone context survives in all test scenarios
- [ ] All Phase 1 unit tests green

---

### PHASE 2 — recoverable_app (Weeks 5–6)

> Goal: Complete crash recovery with session restoration.

#### ErrorInterceptor — All 3 Zones

- [ ] Implement `ErrorInterceptor.initialize()`: sets all 3 error hooks simultaneously
  - [ ] `FlutterError.onError` — catches widget build errors
  - [ ] `PlatformDispatcher.instance.onError` — catches unhandled async errors
  - [ ] `runZonedGuarded` wrapper — catches legacy async errors
- [ ] Each hook: emits a `CrashEvent` to `TrinityEventBus` with error type, message, sanitized stack trace
- [ ] Never swallow errors silently — always log to `TrinityEventBus` even if recovering
- [ ] Write tests: throw from each zone, verify event emitted with correct parentId chain

#### SnapshotManager

- [ ] Design `AppSnapshot` model: `routeStack` (List<String>), `scrollPositions` (Map<String, double>), `formInputs` (Map<String, dynamic>), `customState` (Map<String, dynamic>), `timestamp`, `snapshotId`
- [ ] Implement `SnapshotManager.record(AppSnapshot)`: serializes to `SharedPreferences` as JSON
- [ ] Implement `SnapshotManager.restore()`: deserializes, validates every field independently with try/catch per field
- [ ] Implement `SnapshotManager.wipe()`: called on corrupt snapshot or user 'Start Fresh'
- [ ] Snapshot triggers: on every route change, on user form input after 3s debounce, on explicit `SnapshotManager.checkpoint()` call
- [ ] Corruption handling: if any field fails validation, log the failure, set that field to null, continue restoring the rest
- [ ] Write 25 tests: round-trip serialization, partial corruption recovery, wipe flow

#### FallbackUI

- [ ] Implement `RecoveryApp`: a completely standalone `MaterialApp` — zero custom widgets, no providers, no business logic, cannot import from app code
- [ ] Recovery screen shows: friendly message, error type (not full stack), 3 buttons: Restore Last Session / Start Fresh / Copy Error Report
- [ ] 'Copy Error Report': generates JSON with `fingerprint`, `severity`, `snapshotId`, `deviceInfo`, sanitized error — NO PII
- [ ] Widget switcher: `RecoverableApp` wrapper uses `ValueNotifier<bool>` at root, switches between `app` and `RecoveryApp` when error flag set
- [ ] Crash loop detection: `SharedPreferences` crash counter. If counter >= 3 within 60 seconds of launch, show minimal native-style view bypassing Flutter widgets
- [ ] Write 20 integration tests: verify recovery screen appears within 500ms of crash detection

#### ErrorFingerprint

- [ ] Implement `ErrorFingerprint.compute(exception, stackTrace)`: SHA-256 hash of `exception.runtimeType.toString() + top3StackFrames`
- [ ] Implement `ErrorClassifier.classify(exception)` → `ErrorSeverity.recoverable | degraded | fatal`
  - `SocketException`, `TimeoutException` → `recoverable`
  - `StateError`, `TypeError` → `degraded`
  - `StackOverflowError`, `OutOfMemoryError` → `fatal`
- [ ] For `recoverable`: show inline retry widget only, no full recovery screen
- [ ] For `degraded`: show recovery screen, offer restore or fresh
- [ ] For `fatal`: show recovery screen, disable restore option, start fresh only
- [ ] Write 30 tests covering every severity path

#### RecoverableApp — Public API

- [ ] Implement `RecoverableApp` widget: wraps `MaterialApp`, accepts:
  - `child` (your MaterialApp)
  - `snapshotSerializer` (optional — custom serialization hook)
  - `fallbackBuilder` (optional — custom recovery screen)
  - `errorClassifier` (optional — custom severity rules)
  - `onError` (optional — called with `CausalEvent` for every error)
- [ ] Zero-config usage: `RecoverableApp(child: MyApp())` — everything works with defaults
- [ ] Write README section: quickstart in 5 lines of code

#### Deliverable: Phase 2 Complete When

- [ ] App survives all 3 crash types and shows recovery screen within 500ms
- [ ] Session restores correctly after process kill
- [ ] All crash events appear in `CausalGraph` linked to their origin events
- [ ] 50+ unit + integration tests green

---

### PHASE 3 — ui_explainer (Weeks 7–8)

> Goal: Translate layout engine events into human-readable explanations.

#### LayoutDecisionRecorder

- [ ] Implement `LayoutDecisionRecorder` singleton: circular buffer of last 200 `LayoutDecision` events
- [ ] `LayoutDecision` model: `widgetKey`, `widgetType`, `constraintsReceived` (BoxConstraints), `sizeReported` (Size), `parentWidgetKey`, `timestamp`, `overflowed` (bool)
- [ ] `record(LayoutDecision)`: add to buffer, if `overflowed == true`, also emit `LayoutDecision` event to `TrinityEventBus` with parentId from current `CausalityZone`
- [ ] Write 15 unit tests

#### ExplainableRenderBox Mixin

- [ ] Implement `ExplainableRenderBox` mixin on `RenderBox`:
  - Override `performLayout()`: call `super.performLayout()`, then record to `LayoutDecisionRecorder`
  - After layout: compare each child's `size` to the constraints given. If `size.width > constraints.maxWidth` or `size.height > constraints.maxHeight`, set `overflowed = true`
- [ ] Implement `ExplainableColumn`, `ExplainableRow`, `ExplainableStack` — standard layout widgets with the mixin applied
- [ ] All code wrapped in `assert(() { ...; return true; }())` — zero overhead in release builds
- [ ] Write integration tests: build widget with forced overflow, verify event emitted

#### ConstraintChainAnalyzer

- [ ] `analyze(overflowEvent)`: walks UP the render tree from the overflowed widget
  - Collects every ancestor widget's `constraintsReceived`
  - Finds the first ancestor that introduced an unbounded constraint (maxWidth == double.infinity or maxHeight == double.infinity)
  - Returns `ConstraintChain`: ordered list of `ChainNode(widgetType, constraintReceived, sizeReported, isRootCause)`
- [ ] `identifyUnboundedSource(chain)`: returns the specific widget type and configuration that caused unbounded constraints
- [ ] Write 20 unit tests with different overflow scenarios: Column in ListView, Nested Scrollables, Text in unbounded Row

#### ExplanationEngine

- [ ] Template system for each event type:
  - Overflow: `"Overflow in [widgetType] ([location]): [childWidget] requested [requestedSize] but [parentWidget] only allowed [constraintMax] because [reason]"`
  - Unbounded: `"[widgetType] received unbounded [axis] constraint from [parentType] — any child requesting intrinsic size will overflow"`
  - GestureConflict: `"[WinnerRecognizer] won arena against [LoserRecognizer] because [reason]"`
  - Repaint: `"[widgetType] repainted because [cause]: setState / animation tick / parent repaint"`
- [ ] `explain(event)` → `String`: returns the filled template
- [ ] Write 25 tests for explanation accuracy

#### FixSuggestion Engine

- [ ] Map known patterns to fix suggestions:
  - `Column` inside `SingleChildScrollView` with unbounded children → `"Wrap children in Expanded or give explicit SizedBox height"`
  - Nested `ListView` → `"Set shrinkWrap: true on inner ListView or replace with Column"`
  - `Row` with multiple `Text` widgets and no `Expanded` → `"Wrap Text widgets in Expanded or Flexible"`
  - `Stack` overflow → `"Use Positioned with explicit constraints or Overflow.clip"`
- [ ] `suggest(overflowEvent, chain)` → `List<FixSuggestion>`: returns ranked suggestions
- [ ] Write 20 tests

#### ExplanationOverlay

- [ ] Debug-mode overlay widget: activated via `FloatingActionButton` or `WidgetsApp.shortcuts`
- [ ] Shows last 10 layout events as floating cards over affected widgets using `Overlay`
- [ ] Each card: widget type, explanation, top fix suggestion, 'Copy' button
- [ ] Cards auto-dismiss after 8 seconds
- [ ] Entire overlay wrapped in `kDebugMode` guard — compiles to nothing in release

#### Deliverable: Phase 3 Complete When

- [ ] `ExplainableColumn` detects and explains its own overflow with root cause
- [ ] `ConstraintChainAnalyzer` correctly identifies unbounded constraint source in 5 test cases
- [ ] Explanation appears in overlay within 100ms of overflow detection
- [ ] Layout events appear in `CausalGraph` linked to their state change causes
- [ ] 60+ tests green

---

### PHASE 4 — causality_flutter (Weeks 9–10)

> Goal: Full causal graph with state adapters for all major architectures.

#### Provider Adapter

- [ ] Wrap `ChangeNotifier.notifyListeners()` via custom `InstrumentedChangeNotifier` base class:
  - `notifyListeners()` emits `StateChange` event to `TrinityEventBus` with `parentId` from `CausalityZone.currentContext()`
- [ ] Wrap `Consumer<T>` widget rebuild: emit `UIRebuild` event with `parentId` pointing to the `StateChange` event
- [ ] Write 15 tests: tap button → state change → rebuild, verify 3-node chain in graph

#### Bloc Adapter

- [ ] Implement `CausalityBlocObserver extends BlocObserver`:
  - `onEvent`: emit `UserAction` event (or `NetworkEvent` for remote events)
  - `onTransition`: emit `StateChange` event with `parentId` = the `onEvent` event id
  - `onError`: emit `CrashEvent` with full chain
- [ ] Register via `Bloc.observer = CausalityBlocObserver()`
- [ ] Write 20 tests including multi-Bloc chains

#### Riverpod Adapter

- [ ] Implement `CausalityProviderObserver extends ProviderObserver`:
  - `didUpdateProvider`: emit `StateChange` with metadata including provider name + previous/next value diff
  - Inter-provider invalidation: if provider A invalidates provider B, emit edge A→B in graph
- [ ] Add `ProviderContainer(observers: [CausalityProviderObserver()])` to app setup
- [ ] Write 20 tests including provider dependency chains

#### Network Adapter

- [ ] Implement `CausalityDioInterceptor extends Interceptor`:
  - `onRequest`: emit `NetworkEvent` (type: request) with `parentId` from current Zone context, store event id in request extra map
  - `onResponse`: emit `NetworkEvent` (type: response) with `parentId` = request event id, duration = response.timestamp - request.timestamp
  - `onError`: emit `CrashEvent` with `parentId` = request event id
- [ ] Same for `http` package via `CausalityHttpClient extends http.BaseClient`
- [ ] Write 25 tests including timeout, error, and cancel scenarios

#### Generic Adapter — InstrumentedNotifier

- [ ] Implement `InstrumentedNotifier` mixin: `emitCause(String description, {Map<String, dynamic>? metadata})` method
  - Reads `CausalityZone.currentContext()` for auto-parentId
  - Emits `StateChange` to `TrinityEventBus`
- [ ] Any class can `with InstrumentedNotifier` and call `emitCause()` at mutation sites
- [ ] Write 10 tests

#### CausalityVisualizer — In-App Overlay

- [ ] Activated via shake gesture (`sensors_plus`) or dev-menu long-press
- [ ] Shows last 20 events as vertical timeline with color coding:
  - `UserAction` → blue
  - `NetworkEvent` → orange
  - `StateChange` → green
  - `UIRebuild` → purple
  - `CrashEvent` → red
  - `LayoutDecision` → yellow
- [ ] Tap event → expand to show full causal chain ancestors + descendants
- [ ] 'Root Cause' button: highlights the root event in the chain
- [ ] 'Export Graph' button: serializes full graph to JSON, copies to clipboard

#### Deliverable: Phase 4 Complete When

- [ ] Full chain traced: tap button → network call → response → state change → 3 widgets rebuild → each link visible in graph
- [ ] Provider, Bloc, and Riverpod adapters each produce correct graph structures
- [ ] In-app visualizer shows chains clearly
- [ ] 80+ unit + integration tests green

---

### PHASE 5 — DevTools Extension (Weeks 11–12)

> Goal: Professional-grade DevTools panel integrating all three sub-systems.

#### Service Extension Bridge

- [ ] Register service extensions via `registerExtension` in `dart:developer`
  - `ext.trinity.graph`: returns serialized `CausalGraph` JSON
  - `ext.trinity.events`: returns last 200 events with full metadata
  - `ext.trinity.layout`: returns `LayoutDecisionRecorder` buffer
  - `ext.trinity.snapshots`: returns `SnapshotManager` snapshot list
- [ ] Polling: DevTools panel polls `ext.trinity.events` every 500ms
- [ ] Live streaming: use `postEvent()` from `dart:developer` for real-time push

#### DevTools Panel (separate package: `causality_devtools`)

- [ ] Timeline Panel (left): vertical chronological event stream, color coded by type, filterable
- [ ] Graph Panel (center): topological-sort layout DAG, zoom + pan, root cause auto-highlight
- [ ] Explanation Panel (right): plain-English explanation of selected event, fix suggestions if layout event
- [ ] Click-to-source: clicking widget node in graph opens source file in VS Code at exact line (via `vm_service` source mapping)
- [ ] Filter bar: by event type, by time range, by search string in description
- [ ] Export button: full graph as JSON for sharing bug reports

#### Deliverable: Phase 5 Complete When

- [ ] DevTools extension installs without errors
- [ ] Real-time event stream appears in panel while app runs
- [ ] Click-to-source works for at least `Provider` and `Bloc` adapters
- [ ] Graph correctly visualizes a 10-event causal chain from demo app

---

### PHASE 6 — Polish, Testing & Publication (Weeks 13–14)

> Goal: Production-ready, tested, published.

#### Performance Audit

- [ ] Profile on a 50-screen app with 100+ providers
- [ ] Verify CPU overhead < 3% in debug mode, 0% in release (assert-guards)
- [ ] Memory: graph pruning keeps heap growth < 5MB per hour of use
- [ ] Zero-cost in release: run `flutter build apk --release` and verify no trinity code in AOT output

#### Test Coverage

- [ ] `recoverable_app`: 50+ unit tests, 20 integration tests
- [ ] `ui_explainer`: 60+ unit tests, 15 integration tests
- [ ] `causality_flutter`: 80+ unit tests, 30 integration tests
- [ ] Total: 200+ tests, coverage > 85%

#### Documentation

- [ ] README: 5-minute quickstart (3 lines of code to add all three systems)
- [ ] ARCHITECTURE.md: deep technical explanation for contributors
- [ ] API docs: every public class and method has dartdoc comments
- [ ] Migration guide: how to add to existing app

#### Publication

- [ ] Publish `flutter_debug_trinity` to pub.dev
- [ ] Publish `causality_devtools` to pub.dev (DevTools extension)
- [ ] CHANGELOG.md documenting v0.1.0 features
- [ ] Example app on pub.dev pointing to demo video

---

## DECISION LOG

> Record every important technical decision here so future-you doesn't re-debate it.

| Date       | Decision                                                                  | Rationale                                                                                                             | Alternatives Rejected                                                                                                             |
| ---------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 2026-02-18 | Unified package (`flutter_debug_trinity`) rather than 3 separate packages | Shared `TrinityEventBus` and `CausalityZone` are required by all 3 — splitting creates a hard dependency problem      | Separate packages with a `trinity_core` — rejected because it creates 4 pub.dev packages with confusing version lock requirements |
| 2026-02-18 | Zone metadata for async causality propagation                             | Only mechanism in Dart runtime that survives async boundary without code changes                                      | Thread-local storage (doesn't exist in Dart); explicit context passing (requires changing all user code)                          |
| 2026-02-18 | `assert(() { ...; return true; }())` for zero release overhead            | Dart's `assert` is compiled away in release. This is the canonical pattern for debug-only code with non-trivial logic | `kDebugMode` at call sites — rejected because it's not enforced by compiler, developer can forget it                              |
| 2026-02-18 | Circular buffer (200 events) for `LayoutDecisionRecorder`                 | Layout can fire thousands of times per second during animation. Unbounded buffer = OOM                                | LRU cache — rejected because layout events are time-ordered, not frequency-ordered                                                |

---

## KNOWN RISKS AND MITIGATIONS

| Risk                                                          | Probability | Impact       | Mitigation                                                                                                                       |
| ------------------------------------------------------------- | ----------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| Zone propagation breaks in isolate-based code                 | High        | Medium       | Document clearly. Isolate-sent events must use `ReceivePort` bridge back to main isolate with manual causality context threading |
| `performLayout()` override breaks with Flutter engine updates | Medium      | High         | Pin to Flutter SDK version range in pubspec. CI runs on 3 Flutter versions: stable, beta, master                                 |
| `CausalGraph` memory growth in long sessions                  | High        | High         | Sliding window pruning is mandatory Phase 1 feature, not optional                                                                |
| Recovery screen itself crashes                                | Low         | Catastrophic | `RecoveryApp` imports ZERO app code, uses only Material widgets, has crash-count circuit breaker to native view                  |
| pub.dev score below 130                                       | Medium      | Medium       | Dartdoc all public APIs, write example app, ensure 0 analysis warnings                                                           |

---

## EXPERIMENT LOG

> Every time you run an experiment, log the result here. This is your lab notebook.

### Zone Experiments (Week 1 target)

```
EXPERIMENT: Zone value survives await
DATE: TBD
CODE: experiments/zones/zone_await_propagation.dart
RESULT: TBD
```

```
EXPERIMENT: Zone value inside Future.then() chain
DATE: TBD
CODE: experiments/zones/zone_then_chain.dart
RESULT: TBD
```

```
EXPERIMENT: Zone value inside StreamController broadcast
DATE: TBD
CODE: experiments/zones/zone_stream.dart
RESULT: TBD
```

```
EXPERIMENT: Zone value inside compute() isolate
DATE: TBD
CODE: experiments/zones/zone_isolate.dart
RESULT: EXPECTED FAIL — Zones do not cross isolate boundaries
```

### Error Zone Experiments (Week 1 target)

```
EXPERIMENT: throw in build() — which zone catches it?
DATE: TBD
CODE: experiments/errors/build_throw.dart
RESULT: TBD (expect FlutterError.onError)
```

```
EXPERIMENT: throw in async callback off widget tree
DATE: TBD
CODE: experiments/errors/async_throw.dart
RESULT: TBD (expect PlatformDispatcher.onError)
```

---

## SESSION LOG

> Append a line every work session so you can see velocity and continuity.

| Date       | Duration | Phase | What Was Done                                                               | What's Next                           |
| ---------- | -------- | ----- | --------------------------------------------------------------------------- | ------------------------------------- |
| 2026-02-18 | —        | 0     | Project initialized. Context, state, architecture, and guide files created. | Start Phase 0 Week 1 Zone experiments |

---

## QUICK REFERENCE — DART ZONES CHEATSHEET

```dart
// Create a zone with custom values
final zone = Zone.current.fork(
  zoneValues: {'causal_id': 'event-123', 'parent_id': null},
);

// Run code inside the zone
zone.run(() async {
  // Anywhere inside here (even after awaits):
  final id = Zone.current['causal_id']; // 'event-123'
  await Future.delayed(Duration(seconds: 1));
  final stillId = Zone.current['causal_id']; // 'event-123' — survives await
});

// The CausalityZone.run() pattern we'll build:
CausalityZone.run('user_tapped_login', () async {
  // Zone value is set here
  final result = await authService.login(); // Zone preserved
  stateManager.set(result); // Zone still readable here
  // stateManager can call CausalityZone.currentContext() to get parentId
});
```

---

## QUICK REFERENCE — ERROR INTERCEPTION PATTERN

```dart
void initializeErrorInterception() {
  // 1. Flutter widget errors
  FlutterError.onError = (FlutterErrorDetails details) {
    _emitCrashEvent(details.exception, details.stack, zone: 'flutter');
  };

  // 2. Async errors outside widget tree (Flutter 3.1+)
  PlatformDispatcher.instance.onError = (error, stack) {
    _emitCrashEvent(error, stack, zone: 'platform');
    return true; // true = we handled it, don't also crash
  };
}

// 3. runZonedGuarded wraps main() — catches legacy async errors
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(RecoverableApp(child: MyApp()));
  }, (error, stack) {
    _emitCrashEvent(error, stack, zone: 'dart');
  });
}
```

---

## QUICK REFERENCE — MINIMAL ZERO-CONFIG USAGE (target public API)

```dart
// main.dart — the entire integration is 4 lines
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterDebugTrinity.initialize(); // sets up all hooks
    runApp(
      RecoverableApp(          // crash recovery
        child: MyApp(),
      ),
    );
  }, FlutterDebugTrinity.zonedErrorHandler);
}

// In any state class:
class AuthService with InstrumentedNotifier {
  Future<void> login(String email) async {
    emitCause('login_started', metadata: {'email_hash': email.hashCode});
    final result = await api.login(email); // Zone propagates causal context
    emitCause('login_completed');
    notifyListeners();
  }
}

// In any Column that might overflow:
ExplainableColumn(  // drop-in replacement for Column
  children: [...],
)
// If it overflows: explanation in overlay + causal graph link to what caused the state change
// that led to this layout
```
