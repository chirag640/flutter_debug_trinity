import 'package:flutter/material.dart';
import '../../core/causal_event.dart';
import '../../core/causal_graph.dart';
import '../../core/trinity_event_bus.dart';
import 'dart:async';
import 'dart:math' as math;

/// A panel that visualizes the causal graph as an interactive DAG.
///
/// Each node represents a [CausalEvent] and edges represent parent-child
/// causal relationships. Tapping a node shows its details and highlights
/// its ancestor/descendant chain.
///
/// Designed to be embedded in the DevTools extension or used as an
/// in-app debug overlay.
class GraphPanel extends StatefulWidget {
  /// Maximum number of nodes to display.
  final int maxNodes;

  const GraphPanel({
    super.key,
    this.maxNodes = 100,
  });

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  List<CausalEvent> _events = [];
  CausalEvent? _selectedEvent;
  Set<String> _highlightedIds = {};
  StreamSubscription<CausalEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _refreshGraph();
    _subscription = TrinityEventBus.instance.stream.listen((_) {
      _refreshGraph();
    });
  }

  void _refreshGraph() {
    if (!mounted) return;
    final buffer = TrinityEventBus.instance.buffer;
    setState(() {
      _events = buffer.length > widget.maxNodes
          ? buffer.sublist(buffer.length - widget.maxNodes)
          : List.of(buffer);
    });
  }

  void _selectEvent(CausalEvent event) {
    final ancestors = CausalGraph.instance.getAncestors(event.id);
    final descendants = CausalGraph.instance.getDescendants(event.id);

    setState(() {
      _selectedEvent = event;
      _highlightedIds = {
        event.id,
        ...ancestors.map((e) => e.id),
        ...descendants.map((e) => e.id),
      };
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            children: [
              // Graph view
              Expanded(
                flex: 3,
                child: _events.isEmpty
                    ? const Center(
                        child: Text(
                          'No events in the causal graph.\n'
                          'Interact with the app to build the graph.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _GraphView(
                        events: _events,
                        selectedEvent: _selectedEvent,
                        highlightedIds: _highlightedIds,
                        onEventTap: _selectEvent,
                      ),
              ),
              // Detail pane
              if (_selectedEvent != null)
                SizedBox(
                  width: 280,
                  child: _EventDetailPane(
                    event: _selectedEvent!,
                    onClose: () => setState(() {
                      _selectedEvent = null;
                      _highlightedIds = {};
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF2D2D2D),
      child: Row(
        children: [
          const Icon(Icons.account_tree, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            'Causal Graph (${_events.length} nodes)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            onPressed: _refreshGraph,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Interactive graph view using CustomPaint.
class _GraphView extends StatelessWidget {
  final List<CausalEvent> events;
  final CausalEvent? selectedEvent;
  final Set<String> highlightedIds;
  final void Function(CausalEvent) onEventTap;

  const _GraphView({
    required this.events,
    this.selectedEvent,
    required this.highlightedIds,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: SizedBox(
              width: math.max(constraints.maxWidth, events.length * 50.0),
              height: math.max(constraints.maxHeight, 400),
              child: CustomPaint(
                painter: _GraphPainter(
                  events: events,
                  highlightedIds: highlightedIds,
                ),
                child: Stack(
                  children: [
                    for (int i = 0; i < events.length; i++)
                      Positioned(
                        left: _nodeX(i, events.length,
                            math.max(constraints.maxWidth, events.length * 50)),
                        top: _nodeY(events[i], events,
                            math.max(constraints.maxHeight, 400)),
                        child: _GraphNode(
                          event: events[i],
                          isSelected: events[i].id == selectedEvent?.id,
                          isHighlighted: highlightedIds.contains(events[i].id),
                          onTap: () => onEventTap(events[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _nodeX(int index, int total, double width) {
    if (total <= 1) return width / 2 - 20;
    return (index / (total - 1)) * (width - 60) + 10;
  }

  double _nodeY(CausalEvent event, List<CausalEvent> allEvents, double height) {
    // Group by depth (distance from root)
    final depth = _getDepth(event, allEvents);
    return 40.0 + (depth * 70.0);
  }

  int _getDepth(CausalEvent event, List<CausalEvent> allEvents) {
    if (event.parentId == null) return 0;
    final parent = allEvents.cast<CausalEvent?>().firstWhere(
          (e) => e?.id == event.parentId,
          orElse: () => null,
        );
    if (parent == null) return 0;
    return 1 + _getDepth(parent, allEvents);
  }
}

class _GraphPainter extends CustomPainter {
  final List<CausalEvent> events;
  final Set<String> highlightedIds;

  _GraphPainter({required this.events, required this.highlightedIds});

  @override
  void paint(Canvas canvas, Size size) {
    // Paint edges (parent → child lines)
    final eventIndex = <String, int>{};
    for (int i = 0; i < events.length; i++) {
      eventIndex[events[i].id] = i;
    }

    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final event in events) {
      if (event.parentId != null && eventIndex.containsKey(event.parentId)) {
        final isHighlighted = highlightedIds.contains(event.id) &&
            highlightedIds.contains(event.parentId);

        paint.color =
            isHighlighted ? const Color(0xFFFFD700) : const Color(0xFF444444);

        final parentIdx = eventIndex[event.parentId]!;
        final childIdx = eventIndex[event.id]!;
        final total = events.length;

        final px = total <= 1
            ? size.width / 2
            : (parentIdx / (total - 1)) * (size.width - 60) + 30;
        final py = 40.0 + (_getDepth(events[parentIdx]) * 70.0) + 20;

        final cx = total <= 1
            ? size.width / 2
            : (childIdx / (total - 1)) * (size.width - 60) + 30;
        final cy = 40.0 + (_getDepth(events[childIdx]) * 70.0);

        canvas.drawLine(Offset(px, py), Offset(cx, cy), paint);
      }
    }
  }

  int _getDepth(CausalEvent event) {
    if (event.parentId == null) return 0;
    final parent = events.cast<CausalEvent?>().firstWhere(
          (e) => e?.id == event.parentId,
          orElse: () => null,
        );
    if (parent == null) return 0;
    return 1 + _getDepth(parent);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      events != oldDelegate.events ||
      highlightedIds != oldDelegate.highlightedIds;
}

class _GraphNode extends StatelessWidget {
  final CausalEvent event;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _GraphNode({
    required this.event,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isHighlighted
                  ? color.withValues(alpha: 0.6)
                  : color.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : isHighlighted
                  ? Border.all(color: const Color(0xFFFFD700), width: 1.5)
                  : null,
        ),
        child: Center(
          child: Text(
            _typeAbbrev(event.type),
            style: TextStyle(
              color:
                  isSelected || isHighlighted ? Colors.white : Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  static Color _eventColor(CausalEventType type) {
    switch (type) {
      case CausalEventType.userAction:
        return const Color(0xFF4CAF50);
      case CausalEventType.stateChange:
        return const Color(0xFF2196F3);
      case CausalEventType.networkEvent:
        return const Color(0xFFFF9800);
      case CausalEventType.uiRebuild:
        return const Color(0xFF9C27B0);
      case CausalEventType.crashEvent:
        return const Color(0xFFF44336);
      case CausalEventType.layoutDecision:
        return const Color(0xFF00BCD4);
      case CausalEventType.custom:
        return const Color(0xFF607D8B);
    }
  }

  static String _typeAbbrev(CausalEventType type) {
    switch (type) {
      case CausalEventType.userAction:
        return 'UA';
      case CausalEventType.stateChange:
        return 'SC';
      case CausalEventType.networkEvent:
        return 'NE';
      case CausalEventType.uiRebuild:
        return 'UI';
      case CausalEventType.crashEvent:
        return 'CR';
      case CausalEventType.layoutDecision:
        return 'LD';
      case CausalEventType.custom:
        return 'CU';
    }
  }
}

/// Detail pane showing all info about a selected event.
class _EventDetailPane extends StatelessWidget {
  final CausalEvent event;
  final VoidCallback onClose;

  const _EventDetailPane({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final rootCause = CausalGraph.instance.findRootCause(event.id);
    final ancestors = CausalGraph.instance.getAncestors(event.id);
    final descendants = CausalGraph.instance.getDescendants(event.id);

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF2D2D2D),
            child: Row(
              children: [
                const Text(
                  'Event Details',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('ID', event.id.substring(0, 8)),
                  _detailRow('Type', event.type.name),
                  _detailRow('Description', event.description),
                  _detailRow('Time', event.timestamp.toIso8601String()),
                  if (event.parentId != null)
                    _detailRow('Parent', event.parentId!.substring(0, 8)),
                  if (event.duration != null)
                    _detailRow(
                        'Duration', '${event.duration!.inMilliseconds}ms'),
                  const Divider(color: Color(0xFF444444)),
                  _detailRow('Ancestors', '${ancestors.length}'),
                  _detailRow('Descendants', '${descendants.length}'),
                  if (rootCause != null && rootCause.id != event.id)
                    _detailRow('Root Cause', rootCause.description),
                  if (event.metadata.isNotEmpty) ...[
                    const Divider(color: Color(0xFF444444)),
                    const Text('Metadata:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...event.metadata.entries.map(
                      (e) => _detailRow(e.key, '${e.value}'),
                    ),
                  ],
                  // Ancestor chain
                  if (ancestors.length > 1) ...[
                    const Divider(color: Color(0xFF444444)),
                    const Text('Causal Chain:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    for (int i = 0; i < ancestors.length; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i * 8.0),
                        child: Text(
                          '${i > 0 ? "└─ " : ""}${ancestors[i].description}',
                          style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 10,
                              fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
