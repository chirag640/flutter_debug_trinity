import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';
import 'package:flutter_debug_trinity/core/causal_graph.dart';
import 'package:flutter_debug_trinity/core/context_zone.dart';

/// Integration tests verifying the end-to-end flow:
/// EventBus → CausalGraph → Ancestor/Descendant queries
void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    CausalGraph.instance.dispose();
  });

  group('EventBus → CausalGraph integration', () {
    test('events emitted on bus are auto-added to graph', () async {
      CausalGraph.instance.connectToBus();

      final event = CausalEvent(
        type: CausalEventType.userAction,
        description: 'tap button',
      );

      TrinityEventBus.instance.emit(event);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(CausalGraph.instance.eventIds, contains(event.id));
    });

    test('parent-child relationship preserved through bus', () async {
      CausalGraph.instance.connectToBus();

      final parent = CausalEvent(
        type: CausalEventType.userAction,
        description: 'tap',
      );
      final child = CausalEvent(
        parentId: parent.id,
        type: CausalEventType.stateChange,
        description: 'state updated',
      );

      TrinityEventBus.instance.emit(parent);
      TrinityEventBus.instance.emit(child);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ancestors = CausalGraph.instance.getAncestors(child.id);
      expect(ancestors.map((e) => e.id), contains(parent.id));
    });

    test('multi-level chain is traversable', () async {
      CausalGraph.instance.connectToBus();

      final root = CausalEvent(
        type: CausalEventType.userAction,
        description: 'root action',
      );
      final middle = CausalEvent(
        parentId: root.id,
        type: CausalEventType.stateChange,
        description: 'middle',
      );
      final leaf = CausalEvent(
        parentId: middle.id,
        type: CausalEventType.uiRebuild,
        description: 'leaf',
      );

      TrinityEventBus.instance.emit(root);
      TrinityEventBus.instance.emit(middle);
      TrinityEventBus.instance.emit(leaf);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final rootCause = CausalGraph.instance.findRootCause(leaf.id);
      expect(rootCause?.id, root.id);
    });

    test('descendants are discoverable from root', () async {
      CausalGraph.instance.connectToBus();

      final root = CausalEvent(
        type: CausalEventType.userAction,
        description: 'click',
      );
      final child1 = CausalEvent(
        parentId: root.id,
        type: CausalEventType.networkEvent,
        description: 'api call',
      );
      final child2 = CausalEvent(
        parentId: root.id,
        type: CausalEventType.stateChange,
        description: 'optimistic update',
      );

      TrinityEventBus.instance.emit(root);
      TrinityEventBus.instance.emit(child1);
      TrinityEventBus.instance.emit(child2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final descendants = CausalGraph.instance.getDescendants(root.id);
      expect(descendants, hasLength(2));
    });

    test('graph toJson includes all events', () async {
      CausalGraph.instance.connectToBus();

      for (int i = 0; i < 5; i++) {
        TrinityEventBus.instance.emit(CausalEvent(
          type: CausalEventType.custom,
          description: 'event $i',
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final json = CausalGraph.instance.toJson();
      expect(json['events'], hasLength(5));
    });

    test('graph tracks event count correctly', () async {
      CausalGraph.instance.connectToBus();

      for (int i = 0; i < 100; i++) {
        TrinityEventBus.instance.emit(CausalEvent(
          type: CausalEventType.stateChange,
          description: 'event $i',
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(CausalGraph.instance.length, 100);
    });
  });

  group('CausalityZone → EventBus integration', () {
    test('zone context is available during execution', () {
      CausalityContext? capturedContext;

      CausalityZone.run(
        'test-zone',
        () {
          capturedContext = CausalityZone.currentContext();
        },
      );

      expect(capturedContext, isNotNull);
      expect(capturedContext!.originDescription, 'test-zone');
    });

    test('zone context propagates event ID that can be used as parent', () {
      String? zoneEventId;

      CausalityZone.run(
        'test',
        () {
          final ctx = CausalityZone.currentContext();
          zoneEventId = ctx?.eventId;
        },
      );

      expect(zoneEventId, isNotNull);

      // Use the zone event ID as a parent for a new event
      final child = CausalEvent(
        parentId: zoneEventId,
        type: CausalEventType.stateChange,
        description: 'child of zone',
      );
      TrinityEventBus.instance.emit(child);

      expect(child.parentId, zoneEventId);
    });
  });

  group('Bus buffer behavior', () {
    test('buffer maintains insertion order', () {
      final ids = <String>[];
      for (int i = 0; i < 10; i++) {
        final e = CausalEvent(
          type: CausalEventType.custom,
          description: 'event $i',
        );
        ids.add(e.id);
        TrinityEventBus.instance.emit(e);
      }

      final bufferIds =
          TrinityEventBus.instance.buffer.map((e) => e.id).toList();
      expect(bufferIds, ids);
    });

    test('stream emits events in real-time', () async {
      final received = <CausalEvent>[];
      final sub = TrinityEventBus.instance.stream.listen(received.add);

      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'test',
      ));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, hasLength(1));

      await sub.cancel();
    });

    test('debugClear empties buffer', () {
      for (int i = 0; i < 5; i++) {
        TrinityEventBus.instance.emit(CausalEvent(
          type: CausalEventType.custom,
          description: 'e$i',
        ));
      }
      expect(TrinityEventBus.instance.buffer, hasLength(5));

      TrinityEventBus.instance.debugClear();
      expect(TrinityEventBus.instance.buffer, isEmpty);
    });
  });

  group('CausalEvent serialization round-trip', () {
    test('event survives toJson/fromJson with all fields', () {
      final original = CausalEvent(
        parentId: 'p1',
        type: CausalEventType.networkEvent,
        description: 'API call to /users',
        metadata: {'url': '/users', 'method': 'GET', 'status': 200},
      );

      final json = original.toJson();
      final restored = CausalEvent.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.parentId, 'p1');
      expect(restored.type, CausalEventType.networkEvent);
      expect(restored.description, 'API call to /users');
      expect(restored.metadata['url'], '/users');
      expect(restored.metadata['status'], 200);
    });

    test('event survives round-trip without optional fields', () {
      final original = CausalEvent(
        type: CausalEventType.userAction,
        description: 'tap',
      );

      final json = original.toJson();
      final restored = CausalEvent.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.parentId, isNull);
      // fromJson returns empty map when metadata is absent
      expect(restored.metadata, anyOf(isNull, isEmpty));
    });
  });
}
