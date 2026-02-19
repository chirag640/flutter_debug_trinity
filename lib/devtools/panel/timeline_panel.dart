import 'package:flutter/material.dart';
import '../../core/causal_event.dart';
import '../../core/trinity_event_bus.dart';
import 'dart:async';

/// A timeline panel that shows all Trinity events in chronological order.
///
/// This panel displays events as a scrollable timeline with color-coded
/// event types, timestamps, and parent-child relationships.
///
/// Designed to be embedded in the DevTools extension panel or used
/// as an in-app debug overlay.
class TimelinePanel extends StatefulWidget {
  /// Maximum visible events in the timeline.
  final int maxVisibleEvents;

  /// Whether to auto-scroll to the latest event.
  final bool autoScroll;

  /// Optional filter for event types to display.
  final Set<CausalEventType>? typeFilter;

  const TimelinePanel({
    super.key,
    this.maxVisibleEvents = 200,
    this.autoScroll = true,
    this.typeFilter,
  });

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  final List<CausalEvent> _events = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<CausalEvent>? _subscription;
  Set<CausalEventType> _activeFilters = {};
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _activeFilters = widget.typeFilter ?? CausalEventType.values.toSet();

    // Load existing buffer
    _events.addAll(TrinityEventBus.instance.buffer);

    // Subscribe to live events
    _subscription = TrinityEventBus.instance.stream.listen(_onEvent);
  }

  void _onEvent(CausalEvent event) {
    if (_isPaused) return;
    if (!_activeFilters.contains(event.type)) return;

    setState(() {
      _events.add(event);
      if (_events.length > widget.maxVisibleEvents) {
        _events.removeAt(0);
      }
    });

    if (widget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildFilterChips(),
        Expanded(
          child: _events.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet.\nInteract with the app to see events.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _events.length,
                  itemBuilder: (context, index) =>
                      _TimelineEventTile(event: _events[index]),
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
          const Icon(Icons.timeline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            'Timeline (${_events.length} events)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white70,
              size: 18,
            ),
            onPressed: () => setState(() => _isPaused = !_isPaused),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white70, size: 18),
            onPressed: () => setState(() => _events.clear()),
            tooltip: 'Clear',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF252525),
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: CausalEventType.values.map((type) {
          final isActive = _activeFilters.contains(type);
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(
                type.name,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
              selected: isActive,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _activeFilters.add(type);
                  } else {
                    _activeFilters.remove(type);
                  }
                });
              },
              selectedColor: _eventColor(type).withValues(alpha: 0.3),
              backgroundColor: const Color(0xFF333333),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
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
}

class _TimelineEventTile extends StatelessWidget {
  final CausalEvent event;

  const _TimelineEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _TimelinePanelState._eventColor(event.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: const BorderSide(color: Color(0xFF333333), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 72,
            child: Text(
              _formatTime(event.timestamp),
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.type.name,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.parentId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'parent: ${event.parentId!.substring(0, 8)}...',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    String padMs(int n) => n.toString().padLeft(3, '0');
    return '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}.${padMs(dt.millisecond)}';
  }
}
