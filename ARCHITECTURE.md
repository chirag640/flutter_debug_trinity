# ARCHITECTURE.md — flutter_debug_trinity

## How the Three Sub-Systems Form One Unified Engine

---

## 1. The Core Problem This Architecture Solves

Three separate packages with their own event models, their own overlays, their own DevTools
panels — that is three different tools a developer has to open, correlate, and reason about
simultaneously. The insight behind `flutter_debug_trinity` is that all three share the same
fundamental need: **a causal chain of events across time**.

- `recoverable_app` needs to know WHAT state existed before the crash
- `ui_explainer` needs to know WHY the layout engine received a specific constraint
- `causality_flutter` needs to know WHAT USER ACTION started the chain

When these three systems share one event bus and one graph, each individually becomes 10x
more powerful. A layout overflow is no longer just "Column overflowed by 42px" — it is
"Column overflowed by 42px BECAUSE `AuthProvider` emitted a new state BECAUSE the user
tapped Login 340ms ago."

---

## 2. The Central Event Bus — TrinityEventBus

Every event from every sub-system flows through a single broadcast stream.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TrinityEventBus                              │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ recoverable  │  │ ui_explainer │  │   causality_flutter      │  │
│  │              │  │              │  │                          │  │
│  │ CrashEvent   │  │LayoutDecision│  │ UserAction               │  │
│  │ SnapshotEvent│  │ OverflowEvent│  │ StateChange              │  │
│  │              │  │ GestureEvent │  │ NetworkEvent             │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘  │
│         │                 │                      │                  │
│         └─────────────────┴──────────────────────┘                  │
│                           │                                         │
│                    emit(CausalEvent)                                 │
│                           │                                         │
│            ┌──────────────▼──────────────────┐                      │
│            │         CausalGraph              │                      │
│            │  (directed acyclic graph of      │                      │
│            │   all events + parent edges)     │                      │
│            └─────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key rules:**

1. Every event has an `id` (UUID v4) and an optional `parentId`.
2. `parentId` is always read from `CausalityZone.currentContext()` — it is set automatically
   by the Zone, not manually by the developer.
3. No sub-system imports from another sub-system. All cross-system communication is via
   `TrinityEventBus`. This keeps the dependency graph clean.

---

## 3. The CausalityZone — The Invisible Thread

Dart Zones carry arbitrary metadata through async call chains. `CausalityZone` injects a
`CausalityContext` into every Zone where a user action initiates.

```
User taps Login button
        │
        ▼ (GestureDetector.onTap)
┌───────────────────────────────┐
│  CausalityZone.run(           │
│    'user_tapped_login',        │
│    () async {                  │  ← Zone forks here with new CausalityContext
│                                │    causal_id = UUID('a1b2c3...')
│      await authService.login() │  ← Zone propagates through await
│                                │
│      stateManager.update()     │  ← Zone still readable here
│                                │    Zone['causal_id'] = 'a1b2c3...'
│    }                           │
│  )                             │
└───────────────────────────────┘
        │
        │  authService.login() body:
        ▼
┌───────────────────────────────────┐
│  final ctx = CausalityZone        │
│                .currentContext(); │ ← reads 'a1b2c3...' from Zone
│                                   │
│  // emit NetworkEvent to graph    │
│  bus.emit(NetworkEvent(           │
│    id: newUUID(),                 │
│    parentId: ctx.eventId,         │ ← parentId = 'a1b2c3...'
│    description: 'POST /login',    │
│  ));                              │
└───────────────────────────────────┘
```

This is why Zone propagation is architecturally central — without it, every developer would
have to manually pass context objects through every function call, which is impractical.

---

## 4. How recoverable_app Integrates

```
main() → runZonedGuarded() → sets CausalityZone globally
                                      │
                           ┌──────────▼──────────────┐
                           │  RecoverableApp widget   │
                           │  (wraps MaterialApp)     │
                           └──────────┬───────────────┘
                                      │
                           ┌──────────▼──────────────┐
                           │  ErrorInterceptor        │
                           │                          │
                           │  FlutterError.onError ──►│── emit CrashEvent(
                           │  PlatformDispatcher ────►│      parentId: CausalityZone
                           │  runZonedGuarded ───────►│        .currentContext()
                           │                          │    )
                           └──────────┬───────────────┘
                                      │
                             CrashEvent lands in CausalGraph
                             with parentId = the UserAction
                             that triggered the crash
                                      │
                           ┌──────────▼──────────────┐
                           │  SnapshotManager         │
                           │  reads CausalGraph to    │
                           │  find last good snapshot │
                           │  before the crash event  │
                           └─────────────────────────┘
```

**Key integration property:** The snapshot stored during recovery is linked to the causal
chain. When a developer views the DevTools panel, they can see exactly what state the app
was in at the moment the crash's root-cause event fired.

---

## 5. How ui_explainer Integrates

```
ExplainableColumn.performLayout()
        │
        ├── calls super.performLayout()
        │
        ├── checks: child.size vs constraints
        │
        └── if overflow detected:
              │
              ├── ConstraintChainAnalyzer.analyze(overflowEvent)
              │     └── walks up render tree finding unbounded constraint source
              │
              ├── ExplanationEngine.explain(chain) → human-readable string
              │
              ├── FixSuggestion.suggest(pattern) → actionable fix
              │
              └── bus.emit(LayoutDecision(
                    id: newUUID(),
                    parentId: CausalityZone.currentContext()?.eventId,
                                ↑
                    This is the KEY LINK:
                    If this layout rebuild was triggered by a StateChange
                    (e.g., Provider notified listeners → Consumer rebuilt → Column rebuilt),
                    the Zone context carried from that notification is still here.
                    The LayoutDecision.parentId points directly to the StateChange
                    that caused the widget to rebuild with different constraints.
                  ))
```

**What this gives you:** When you see "Column overflowed" in the DevTools panel, you click
on that event. The panel shows you not just "Column got unbounded height from ListView" —
it shows "Column got unbounded height from ListView BECAUSE Provider<CartState> emitted
a new value BECAUSE the user tapped AddToCart 120ms ago."

---

## 6. How causality_flutter Integrates

causality_flutter is simultaneously a producer and consumer of the graph:

- **Producer:** via adapters (Provider, Bloc, Riverpod, Network) it emits `StateChange` and
  `NetworkEvent` nodes
- **Consumer:** via `CausalityVisualizer` it reads the graph and renders it

```
Provider Adapter
        │
        ├── ChangeNotifier.notifyListeners() called
        │
        ├── Adapter reads CausalityZone.currentContext()
        │     → finds parentId = 'a1b2c3' (the UserAction)
        │
        └── bus.emit(StateChange(
              id: 's1...',
              parentId: 'a1b2c3',    ← UserAction
              description: 'CartProvider emitted',
            ))

                    ↓
            (widget tree rebuilds)

Consumer widget rebuild (tracked by Provider adapter wrapper)
        │
        └── bus.emit(UIRebuild(
              id: 'r1...',
              parentId: 's1...',     ← StateChange
              description: 'CartItemList rebuilt',
            ))

                    ↓
            (if CartItemList contains ExplainableColumn)

ExplainableColumn.performLayout()
        │
        └── bus.emit(LayoutDecision(
              id: 'l1...',
              parentId: 'r1...',     ← UIRebuild
              description: 'ExplainableColumn layout',
            ))
```

**Final graph for this interaction:**

```
UserAction (tap AddToCart)  [a1b2c3]
    └── StateChange (CartProvider emitted)  [s1...]
            └── UIRebuild (CartItemList rebuilt)  [r1...]
                    └── LayoutDecision (Column overflowed)  [l1...]
```

`findRootCause('l1...')` → returns `UserAction [a1b2c3]`.

---

## 7. Data Flow Diagram — Full System

```
                    USER TAPS BUTTON
                          │
                          ▼
              ┌─────────────────────┐
              │   GestureDetector   │
              │   .onTap callback   │
              │                     │
              │  CausalityZone.run( │ ◄─── Zone context injected here
              │    'tap_add_cart',  │
              │    fn               │
              │  )                  │
              └────────┬────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
 ┌──────────────────┐    ┌─────────────────────┐
 │ State adapter    │    │  Network adapter     │
 │ (e.g. Bloc)      │    │  (e.g. Dio           │
 │                  │    │   interceptor)       │
 │ emits            │    │                      │
 │ StateChange ────►│    │  emits               │
 │ to TrinityBus    │    │  NetworkEvent ──────►│
 └──────────────────┘    └─────────────────────┘
          │                         │
          └────────────┬────────────┘
                       │
                       ▼
            ┌──────────────────┐
            │  TrinityEventBus │
            │  (broadcast      │
            │   StreamCtrl)    │
            └────────┬─────────┘
                     │
          ┌──────────┼──────────────────────┐
          │          │                      │
          ▼          ▼                      ▼
 ┌──────────────┐ ┌─────────┐    ┌──────────────────┐
 │ CausalGraph  │ │Snapshot │    │ DevTools Service  │
 │ (stores all  │ │Manager  │    │ Extension         │
 │  events as   │ │(records │    │ (streams events   │
 │  DAG nodes)  │ │ state)  │    │  to panel)        │
 └──────────────┘ └─────────┘    └──────────────────┘
          │
          │  (on widget rebuild after state change)
          ▼
 ┌────────────────────────────┐
 │ ExplainableColumn          │
 │ .performLayout()           │
 │                            │
 │ → detects overflow         │
 │ → ConstraintChainAnalyzer  │
 │ → ExplanationEngine        │
 │ → emits LayoutDecision     │
 │   parentId = UIRebuild id  │
 └────────────────────────────┘
          │
          ▼
 ┌────────────────────────────┐
 │  DevTools panel shows:     │
 │                            │
 │  tap_add_cart              │
 │    └── POST /cart/items    │
 │    └── CartState changed   │
 │          └── CartList      │
 │               rebuilt      │
 │                └── Column  │
 │                   overflowed│
 │                   by 42px  │
 │                   BECAUSE  │
 │                   Text had │
 │                   no       │
 │                   Expanded │
 └────────────────────────────┘
```

---

## 8. Zero-Cost Release Build Architecture

Every instrumentation site uses one of two patterns:

**Pattern A — assert guard (for RenderObject overrides):**

```dart
@override
void performLayout() {
  super.performLayout();
  assert(() {
    // All recording code here
    // Dart compiler removes this entire block in release
    _recorder.record(LayoutDecision(...));
    return true;
  }());
}
```

**Pattern B — kDebugMode compile-time constant:**

```dart
void initialize() {
  if (kDebugMode) {  // Dart tree-shakes the entire block in release
    FlutterError.onError = _interceptError;
    // ... rest of hooks
  }
}
```

**Pattern C — Conditional import:**

```dart
// lib/flutter_debug_trinity.dart
export 'src/trinity_stub.dart'     // empty stubs
  if (dart.library.io) 'src/trinity_impl.dart'; // full impl in debug
```

The result: `flutter build apk --release` produces an APK with zero sizeof contribution
from `flutter_debug_trinity`. Confirmed by running `flutter analyze --target-platform=android`
and checking that no trinity symbols appear in the AOT snapshot.

---

## 9. Public API Contract (the surface test against)

These are the only things a user of the package needs to touch. Everything else is internal.

```dart
// ── Entry point ──────────────────────────────────────────────────────────────
class FlutterDebugTrinity {
  static void initialize({
    TrinityConfig? config,  // optional: event buffer size, sample rate, etc.
  });
  static void Function(Object, StackTrace) get zonedErrorHandler;
}

// ── Crash Recovery ───────────────────────────────────────────────────────────
class RecoverableApp extends StatelessWidget {
  const RecoverableApp({
    required Widget child,
    SnapshotSerializer? snapshotSerializer,
    WidgetBuilder? fallbackBuilder,
    ErrorClassifier? errorClassifier,
    void Function(CausalEvent)? onError,
  });
}

abstract class SnapshotSerializer {
  Map<String, dynamic> serialize();
  void restore(Map<String, dynamic> snapshot);
}

// ── UI Explainer ─────────────────────────────────────────────────────────────
class ExplainableColumn extends MultiChildRenderObjectWidget { ... }
class ExplainableRow extends MultiChildRenderObjectWidget { ... }
class ExplainableStack extends MultiChildRenderObjectWidget { ... }
// Drop-in replacements — same constructor signatures as their Flutter counterparts

// ── Causality ────────────────────────────────────────────────────────────────
mixin InstrumentedNotifier {
  void emitCause(String description, {Map<String, dynamic>? metadata});
}

class CausalityBlocObserver extends BlocObserver { ... }
class CausalityProviderObserver extends ProviderObserver { ... }
class CausalityDioInterceptor extends Interceptor { ... }
class CausalityHttpClient extends http.BaseClient { ... }

// ── Zone ─────────────────────────────────────────────────────────────────────
class CausalityZone {
  static T run<T>(String description, T Function() fn);
  static CausalityContext? currentContext();
}
```

**Constraint:** Any change to these public types is a breaking change requiring a major
version bump. All other classes are implementation details and may change in any release.
