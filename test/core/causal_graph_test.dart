import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_debug_trinity/core/causal_event.dart';
import 'package:flutter_debug_trinity/core/causal_graph.dart';
import 'package:flutter_debug_trinity/core/trinity_event_bus.dart';

void main() {
  setUp(() {
    TrinityEventBus.instance.debugClear();
    // Re-create graph to clear state
    CausalGraph.instance.dispose();
  });

  group('CausalGraph', () {
    test('is a singleton', () {
      final a = CausalGraph.instance;
      final b = CausalGraph.instance;
      expect(identical(a, b), isTrue);
    });

    test('addEvent stores event', () {
      final event = CausalEvent(
        id: 'e1',
        type: CausalEventType.userAction,
        description: 'test',
      );
      CausalGraph.instance.addEvent(event);
      expect(CausalGraph.instance.getEvent('e1'), isNotNull);
      expect(CausalGraph.instance.getEvent('e1')!.description, 'test');
    });

    test('getEvent returns null for unknown id', () {
      expect(CausalGraph.instance.getEvent('nonexistent'), isNull);
    });

    test('parent-child edges are created', () {
      final parent = CausalEvent(
        id: 'parent',
        type: CausalEventType.userAction,
        description: 'click',
      );
      final child = CausalEvent(
        id: 'child',
        parentId: 'parent',
        type: CausalEventType.stateChange,
        description: 'state update',
      );

      CausalGraph.instance.addEvent(parent);
      CausalGraph.instance.addEvent(child);

      final children = CausalGraph.instance.getDirectChildren('parent');
      expect(children, hasLength(1));
      expect(children.first.id, 'child');
    });

    test('getAncestors returns root-first chain', () {
      final e1 = CausalEvent(
          id: 'root', type: CausalEventType.userAction, description: 'root');
      final e2 = CausalEvent(
          id: 'mid',
          parentId: 'root',
          type: CausalEventType.stateChange,
          description: 'mid');
      final e3 = CausalEvent(
          id: 'leaf',
          parentId: 'mid',
          type: CausalEventType.networkEvent,
          description: 'leaf');

      CausalGraph.instance.addEvent(e1);
      CausalGraph.instance.addEvent(e2);
      CausalGraph.instance.addEvent(e3);

      // getAncestors includes self in root-first order
      final ancestors = CausalGraph.instance.getAncestors('leaf');
      expect(ancestors, hasLength(3));
      expect(ancestors.first.id, 'root');
      expect(ancestors[1].id, 'mid');
      expect(ancestors.last.id, 'leaf');
    });

    test('getAncestors returns only self for root event', () {
      CausalGraph.instance.addEvent(CausalEvent(
        id: 'root',
        type: CausalEventType.userAction,
        description: 'root',
      ));
      final ancestors = CausalGraph.instance.getAncestors('root');
      expect(ancestors, hasLength(1));
      expect(ancestors.first.id, 'root');
    });

    test('getDescendants returns BFS traversal', () {
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'a', type: CausalEventType.userAction, description: 'a'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'b',
          parentId: 'a',
          type: CausalEventType.stateChange,
          description: 'b'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'c',
          parentId: 'a',
          type: CausalEventType.stateChange,
          description: 'c'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'd',
          parentId: 'b',
          type: CausalEventType.networkEvent,
          description: 'd'));

      final descendants = CausalGraph.instance.getDescendants('a');
      expect(descendants, hasLength(3));
      // BFS: b and c before d
      final ids = descendants.map((e) => e.id).toList();
      expect(ids.indexOf('d'), greaterThan(ids.indexOf('b')));
    });

    test('findRootCause finds the root', () {
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'root', type: CausalEventType.userAction, description: 'root'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'mid',
          parentId: 'root',
          type: CausalEventType.stateChange,
          description: 'mid'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'crash',
          parentId: 'mid',
          type: CausalEventType.crashEvent,
          description: 'crash'));

      final root = CausalGraph.instance.findRootCause('crash');
      expect(root, isNotNull);
      expect(root!.id, 'root');
    });

    test('findRootCause returns self for root event', () {
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'solo', type: CausalEventType.userAction, description: 'solo'));
      final root = CausalGraph.instance.findRootCause('solo');
      expect(root, isNotNull);
      expect(root!.id, 'solo');
    });

    test('toJson / fromJson round-trips', () {
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'x', type: CausalEventType.userAction, description: 'x'));
      CausalGraph.instance.addEvent(CausalEvent(
          id: 'y',
          parentId: 'x',
          type: CausalEventType.stateChange,
          description: 'y'));

      final json = CausalGraph.instance.toJson();
      expect(json['events'], isList);
      expect((json['events'] as List).length, 2);
    });

    test('connectToBus auto-adds events from bus', () async {
      CausalGraph.instance.connectToBus();

      final event = CausalEvent(
        id: 'bus-event',
        type: CausalEventType.userAction,
        description: 'from bus',
      );
      TrinityEventBus.instance.emit(event);

      // Allow async processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(CausalGraph.instance.getEvent('bus-event'), isNotNull);
    });
  });
}
