# flutter_debug_trinity

> One package. Three systems. Complete observability for Flutter apps.

[![Tests](https://img.shields.io/badge/tests-232%20passing-brightgreen)](#)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.10.0-blue)](#)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.0.0-blue)](#)

| Sub-system          | What it answers                               |
| ------------------- | --------------------------------------------- |
| `recoverable_app`   | What do I show the user when the app crashes? |
| `ui_explainer`      | Why does my layout look wrong?                |
| `causality_flutter` | Why did ANY of this happen?                   |

All three share one **causal event graph** via `TrinityEventBus`. Every crash, layout decision,
and state change is a node. Every causal relationship is an edge. When something goes wrong you
trace backwards from symptom to root cause in one graph view.

---

## 5-Minute Quickstart

```dart
// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_debug_trinity/flutter_debug_trinity.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterDebugTrinity.initialize(); // sets up all hooks
    runApp(
      RecoverableApp(          // wraps your existing MaterialApp
        child: MyApp(),
      ),
    );
  }, FlutterDebugTrinity.zonedErrorHandler);
}
```

That's it. Your app now:

- Recovers from all Flutter crash types
- Offers the user 'Restore Session' or 'Start Fresh'
- Records every error into the causal graph with its origin event

---

## Features

### Crash Recovery (`recoverable_app`)

- **Three error zones**: `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded` handler
- **Error fingerprinting**: SHA-256 hashing of error type + stack frames for deduplication
- **App state snapshots**: Automatically persists route stack, scroll positions, form inputs
- **Crash-loop detection**: Detects repeated crashes and offers a clean-start option
- **Graceful degrader**: Component-level error boundaries with `GracefulDegrader` widget
- **Pre-built fallback UIs**: `FallbackScreen` and `ErrorBanner` widgets

### Layout Explainer (`ui_explainer`)

- **Layout decision recording**: Tracks constraints received vs. size reported for every RenderBox
- **Constraint chain analysis**: Traces the constraint chain from root to overflowing widget
- **Explanation engine**: Generates plain-English explanations of layout overflow
- **Fix suggestions**: Context-aware code-fix recommendations (Expanded, scrollable, BoxFit, etc.)
- **Explanation overlay**: Debug overlay showing layout explanations in real-time

### Causality Tracking (`causality_flutter`)

- **Causal DAG**: Directed acyclic graph linking every event to its cause
- **Root-cause tracing**: `findRootCause()` walks the graph from any symptom to its origin
- **Impact analysis**: `getDescendants()` shows all downstream effects of an event
- **State management adapters**: `InstrumentedNotifier`, plus adapters for Provider, Bloc, and Riverpod
- **Network adapter**: Wraps Dio/http to emit causal events for API calls
- **CausalityZone**: Dart Zone-based context propagation for event parentage

### DevTools Extension

- **Service extension bridge**: 6 VM service extensions for real-time DevTools communication
- **Timeline panel**: Filterable event timeline with type-based filtering
- **Graph panel**: DAG visualization of the causal graph
- **Explanation panel**: Layout explanation viewer with fix suggestions
- **TrinityDebugFab**: Floating action button to inspect the trinity state in-app

---

## Add Causality to Your State

```dart
class CartService with InstrumentedNotifier {
  Future<void> addItem(String itemId) async {
    emitCause('add_item_started', metadata: {'item': itemId});
    await _api.post('/cart', body: {'itemId': itemId});
    emitCause('add_item_completed');
    notifyListeners();
  }
}
```

---

## Add Explainable Layout

```dart
// Replace Column with ExplainableColumn — identical API
ExplainableColumn(
  children: [...],
)
// If it overflows: you get a plain-English explanation + fix suggestion
// AND it's linked in the causal graph to the state mutation that triggered the rebuild
```

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                 TrinityEventBus                  │
│          (singleton broadcast bus)                │
│      Every event flows through here              │
└──────┬──────────┬──────────────┬─────────────────┘
       │          │              │
  ┌────▼────┐ ┌───▼──────┐ ┌───▼──────────────┐
  │Recover  │ │UIExplain │ │Causality         │
  │• Error  │ │• Layout  │ │• InstrumentedNot │
  │  Zones  │ │  Recorder│ │• Provider Adapter│
  │• Snap-  │ │• Explain │ │• Bloc Adapter    │
  │  shots  │ │  Engine  │ │• Riverpod Adapter│
  │• Finger-│ │• Fix     │ │• Network Adapter │
  │  prints │ │  Suggest │ │• CausalityZone   │
  └─────────┘ └──────────┘ └──────────────────┘
       │          │              │
  ┌────▼──────────▼──────────────▼─────────────────┐
  │              CausalGraph (DAG)                 │
  │     Auto-pruning, ancestor/descendant queries  │
  └────────────────────┬───────────────────────────┘
                       │
  ┌────────────────────▼───────────────────────────┐
  │          DevTools Extension                    │
  │  ServiceExtensionBridge + 3 tabbed panels      │
  └────────────────────────────────────────────────┘
```

---

## Project Files

| File                                               | Purpose                                                                                            |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [CONTEXT.md](CONTEXT.md)                           | **Master memory file.** Current phase, all todos, decision log, session log. Update every session. |
| [PROJECT_STATE.json](PROJECT_STATE.json)           | Machine-readable progress state. Every task status.                                                |
| [ARCHITECTURE.md](ARCHITECTURE.md)                 | How the three sub-systems connect. Data flow diagrams. Public API contract.                        |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Exact code to write, in exact order, with tests.                                                   |
| [pubspec.yaml](pubspec.yaml)                       | Package definition and pinned dependencies.                                                        |

---

## Testing

```bash
flutter test           # Run all 232 tests
flutter analyze        # Static analysis — 0 issues
```

### Test Coverage

| Module                                                                       | Tests   |
| ---------------------------------------------------------------------------- | ------- |
| Core (event bus, graph, zones)                                               | 44      |
| Recoverable (interceptor, snapshots, fingerprint, fallback UI)               | 58      |
| UI Explainer (recorder, render box, chain, engine, overlay, fix suggestions) | 53      |
| Causality (adapters, visualizer)                                             | 30      |
| DevTools (bridge, panels, extension)                                         | 25      |
| Integration + barrel exports                                                 | 22      |
| **Total**                                                                    | **232** |

---

## Current Status

All implementation phases complete. Package is fully functional with:

- 28+ source files across 4 sub-systems + DevTools
- 232 passing tests
- Zero analysis warnings
- Clean static analysis
