import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../core/causal_event.dart';
import '../core/causal_graph.dart';
import '../core/trinity_event_bus.dart';

/// Bridges between the in-app Trinity system and the Dart VM service
/// protocol, enabling real-time communication with DevTools extensions.
///
/// This registers service extensions that the DevTools panel can
/// call to query the current state of the causal graph, event buffer,
/// and real-time event stream.
///
/// ## Registered Service Extensions
///
/// - `ext.flutter_debug_trinity.getEventBuffer` — Returns the last 500 events
/// - `ext.flutter_debug_trinity.getCausalGraph` — Returns the full DAG as JSON
/// - `ext.flutter_debug_trinity.getAncestors` — Returns ancestor chain for an event
/// - `ext.flutter_debug_trinity.getDescendants` — Returns descendant tree for an event
/// - `ext.flutter_debug_trinity.findRootCause` — Finds root cause of an event
/// - `ext.flutter_debug_trinity.getStats` — Returns system statistics
class ServiceExtensionBridge {
  ServiceExtensionBridge._();

  static bool _registered = false;

  /// Track which extensions are registered with the VM (can never be unregistered).
  static final Set<String> _vmRegisteredExtensions = {};

  /// Register all Trinity service extensions with the VM.
  ///
  /// Call this once during initialization. No-op in release builds.
  /// Safe to call multiple times — subsequent calls are ignored.
  static void register() {
    if (!kDebugMode) return;
    if (_registered) return;
    _registered = true;

    // Post events to DevTools timeline
    TrinityEventBus.instance.stream.listen(_postEventToTimeline);

    // Register query extensions
    _registerExtension(
      'ext.flutter_debug_trinity.getEventBuffer',
      _handleGetEventBuffer,
    );
    _registerExtension(
      'ext.flutter_debug_trinity.getCausalGraph',
      _handleGetCausalGraph,
    );
    _registerExtension(
      'ext.flutter_debug_trinity.getAncestors',
      _handleGetAncestors,
    );
    _registerExtension(
      'ext.flutter_debug_trinity.getDescendants',
      _handleGetDescendants,
    );
    _registerExtension(
      'ext.flutter_debug_trinity.findRootCause',
      _handleFindRootCause,
    );
    _registerExtension(
      'ext.flutter_debug_trinity.getStats',
      _handleGetStats,
    );

    debugPrint('[Trinity] Service extensions registered.');
  }

  static void _registerExtension(
    String name,
    Future<developer.ServiceExtensionResponse> Function(
      String method,
      Map<String, String> parameters,
    ) handler,
  ) {
    // VM extensions can never be unregistered — skip if already registered.
    if (_vmRegisteredExtensions.contains(name)) return;
    _vmRegisteredExtensions.add(name);
    developer.registerExtension(name, handler);
  }

  /// Post each event to the Dart developer timeline for DevTools.
  static void _postEventToTimeline(CausalEvent event) {
    developer.postEvent('trinity.event', {
      'id': event.id,
      'parentId': event.parentId,
      'type': event.type.name,
      'description': event.description,
      'timestamp': event.timestamp.toIso8601String(),
    });
  }

  // ── Handler: getEventBuffer ───────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleGetEventBuffer(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final limit = int.tryParse(parameters['limit'] ?? '') ?? 100;
      final buffer = TrinityEventBus.instance.buffer;
      final events = buffer.length > limit
          ? buffer.sublist(buffer.length - limit)
          : buffer;

      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'events': events.map((e) => e.toJson()).toList(),
          'total': buffer.length,
          'returned': events.length,
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  // ── Handler: getCausalGraph ───────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleGetCausalGraph(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final graph = CausalGraph.instance;
      return developer.ServiceExtensionResponse.result(
        jsonEncode(graph.toJson()),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  // ── Handler: getAncestors ─────────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleGetAncestors(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final eventId = parameters['eventId'];
      if (eventId == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Missing required parameter: eventId',
        );
      }

      final ancestors = CausalGraph.instance.getAncestors(eventId);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'eventId': eventId,
          'ancestors': ancestors.map((e) => e.toJson()).toList(),
          'depth': ancestors.length,
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  // ── Handler: getDescendants ───────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleGetDescendants(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final eventId = parameters['eventId'];
      if (eventId == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Missing required parameter: eventId',
        );
      }

      final descendants = CausalGraph.instance.getDescendants(eventId);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'eventId': eventId,
          'descendants': descendants.map((e) => e.toJson()).toList(),
          'count': descendants.length,
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  // ── Handler: findRootCause ────────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleFindRootCause(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final eventId = parameters['eventId'];
      if (eventId == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Missing required parameter: eventId',
        );
      }

      final rootCause = CausalGraph.instance.findRootCause(eventId);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'eventId': eventId,
          'rootCause': rootCause?.toJson(),
          'found': rootCause != null,
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  // ── Handler: getStats ──────────────────────────────────────────────────

  static Future<developer.ServiceExtensionResponse> _handleGetStats(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      final buffer = TrinityEventBus.instance.buffer;
      final graph = CausalGraph.instance;

      // Count events by type
      final typeCounts = <String, int>{};
      for (final event in buffer) {
        final typeName = event.type.name;
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
      }

      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'bufferSize': buffer.length,
          'bufferMax': 500,
          'graphJson': graph.toJson(),
          'eventTypeCounts': typeCounts,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        e.toString(),
      );
    }
  }

  /// Reset registration state. For testing only.
  @visibleForTesting
  static void debugReset() {
    assert(() {
      _registered = false;
      return true;
    }());
  }
}
