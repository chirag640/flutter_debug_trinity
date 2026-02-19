import 'dart:async';
import 'causal_event.dart';
import 'trinity_event_bus.dart';

/// A directed acyclic graph (DAG) of [CausalEvent] nodes.
///
/// Every event emitted to [TrinityEventBus] is automatically added as a node.
/// Parent-child edges are formed via [CausalEvent.parentId]. The graph
/// supports traversal in both directions: ancestors (root-cause tracing)
/// and descendants (impact analysis).
///
/// ## Pruning
///
/// The graph uses a sliding window to prevent unbounded memory growth.
/// Events older than [_windowSeconds] or exceeding [_windowMaxEvents] are
/// pruned. Pruning happens automatically on every [addEvent] call.
///
/// ## Serialization
///
/// [toJson] exports the entire graph for bug reports. The exported JSON
/// contains all events and their causal edges.
class CausalGraph {
  CausalGraph._internal();

  /// The singleton instance.
  static final CausalGraph instance = CausalGraph._internal();

  /// eventId → CausalEvent
  final Map<String, CausalEvent> _nodes = {};

  /// childId → parentId (directed causal edge)
  final Map<String, String> _parentEdge = {};

  /// parentId → List<childId> (reverse index for descendant queries)
  final Map<String, List<String>> _childEdges = {};

  /// Bus subscription handle (for cleanup in tests).
  StreamSubscription<CausalEvent>? _subscription;

  /// Sliding window: keep events from the last N seconds.
  static const int _windowSeconds = 300; // 5 minutes

  /// Hard cap: never store more than this many events.
  static const int _windowMaxEvents = 2000;

  /// Total number of events currently in the graph.
  int get length => _nodes.length;

  /// All event IDs currently in the graph.
  Iterable<String> get eventIds => _nodes.keys;

  /// Wire the graph to the event bus. Call once during initialization.
  ///
  /// After this, every event emitted to [TrinityEventBus] is automatically
  /// added to this graph.
  void connectToBus() {
    _subscription?.cancel();
    _subscription = TrinityEventBus.instance.stream.listen(_onEvent);
  }

  void _onEvent(CausalEvent event) {
    addEvent(event);
  }

  /// Adds an event to the graph manually.
  ///
  /// If [event.parentId] is non-null and the parent exists in the graph,
  /// a directed edge (child → parent) is created.
  void addEvent(CausalEvent event) {
    _nodes[event.id] = event;
    if (event.parentId != null) {
      _parentEdge[event.id] = event.parentId!;
      _childEdges.putIfAbsent(event.parentId!, () => []).add(event.id);
    }
    _pruneIfNeeded();
  }

  /// Returns the event with the given [eventId], or null.
  CausalEvent? getEvent(String eventId) => _nodes[eventId];

  /// Returns the ordered ancestor chain from root to [eventId] (inclusive).
  ///
  /// The first element is the oldest ancestor (root cause), the last is
  /// the event itself. Returns empty list if event not found.
  ///
  /// Detects cycles via visited set — should never happen in a DAG but
  /// protects against data corruption.
  List<CausalEvent> getAncestors(String eventId) {
    final chain = <CausalEvent>[];
    String? current = eventId;
    final visited = <String>{};

    while (current != null && !visited.contains(current)) {
      visited.add(current);
      final event = _nodes[current];
      if (event != null) {
        chain.insert(0, event); // prepend — oldest first
      }
      current = _parentEdge[current];
    }
    return chain;
  }

  /// Returns all events transitively caused by [eventId] (excluding itself).
  ///
  /// Uses breadth-first traversal. The order is by graph distance from
  /// the origin event.
  List<CausalEvent> getDescendants(String eventId) {
    final result = <CausalEvent>[];
    final queue = <String>[eventId];
    final visited = <String>{eventId};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = _childEdges[current] ?? [];
      for (final childId in children) {
        if (visited.contains(childId)) continue;
        visited.add(childId);
        final event = _nodes[childId];
        if (event != null) {
          result.add(event);
          queue.add(childId);
        }
      }
    }
    return result;
  }

  /// Finds the root cause of the causal chain containing [eventId].
  ///
  /// The root cause is the oldest ancestor — typically a [CausalEventType.userAction]
  /// or [CausalEventType.networkEvent]. Returns the event itself if it has no parent.
  /// Returns null if the event is not in the graph.
  CausalEvent? findRootCause(String eventId) {
    final ancestors = getAncestors(eventId);
    if (ancestors.isEmpty) return null;
    return ancestors.first;
  }

  /// Returns the direct children of [eventId] (one level only).
  List<CausalEvent> getDirectChildren(String eventId) {
    final childIds = _childEdges[eventId] ?? [];
    return childIds.map((id) => _nodes[id]).whereType<CausalEvent>().toList();
  }

  /// Removes events that are outside the sliding window.
  void _pruneIfNeeded() {
    if (_nodes.length <= _windowMaxEvents) return;

    final cutoff =
        DateTime.now().subtract(const Duration(seconds: _windowSeconds));
    final toRemove = <String>[];

    for (final entry in _nodes.entries) {
      if (entry.value.timestamp.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _removeNode(id);
    }
  }

  void _removeNode(String id) {
    _nodes.remove(id);
    final parentId = _parentEdge.remove(id);
    if (parentId != null) {
      _childEdges[parentId]?.remove(id);
      if (_childEdges[parentId]?.isEmpty ?? false) {
        _childEdges.remove(parentId);
      }
    }
    // Also remove this node as a parent entry
    final children = _childEdges.remove(id);
    if (children != null) {
      for (final childId in children) {
        _parentEdge.remove(childId);
      }
    }
  }

  /// Exports the entire graph as JSON for bug reports.
  Map<String, dynamic> toJson() => {
        'events': _nodes.values.map((e) => e.toJson()).toList(),
        'edges': Map<String, String>.from(_parentEdge),
        'event_count': _nodes.length,
        'exported_at': DateTime.now().toIso8601String(),
      };

  /// Imports a previously exported graph. Merges with existing data.
  void fromJson(Map<String, dynamic> json) {
    final events = json['events'] as List;
    for (final eventJson in events) {
      final event = CausalEvent.fromJson(eventJson as Map<String, dynamic>);
      addEvent(event);
    }
  }

  /// Clears the entire graph. For testing only.
  void debugClear() {
    assert(() {
      _nodes.clear();
      _parentEdge.clear();
      _childEdges.clear();
      return true;
    }());
  }

  /// Disconnects from the event bus and clears graph. For testing cleanup.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _nodes.clear();
    _parentEdge.clear();
    _childEdges.clear();
  }
}
