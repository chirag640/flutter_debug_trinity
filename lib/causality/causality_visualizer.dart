import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/causal_event.dart';
import '../../core/causal_graph.dart';
import '../../core/trinity_event_bus.dart';

/// A debug-only widget that visualizes the causal graph in real time.
///
/// Shows a scrollable list of causal events with parent-child relationships,
/// event types, timestamps, and metadata. Useful for understanding the
/// causal chain during debugging.
///
/// **Completely removed in release builds** via `kDebugMode` check.
///
/// ## Usage
/// ```dart
/// // In a debug drawer or settings screen:
/// CausalityVisualizer()
/// ```
class CausalityVisualizer extends StatefulWidget {
  /// Maximum number of events to display.
  final int maxEvents;

  /// Whether to auto-scroll to the latest event.
  final bool autoScroll;

  const CausalityVisualizer({
    super.key,
    this.maxEvents = 100,
    this.autoScroll = true,
  });

  @override
  State<CausalityVisualizer> createState() => _CausalityVisualizerState();
}

class _CausalityVisualizerState extends State<CausalityVisualizer> {
  final ScrollController _scrollController = ScrollController();
  List<CausalEvent> _events = [];
  String? _selectedEventId;
  StreamSubscription<CausalEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    // Listen for new events — subscription stored so it can be cancelled in dispose()
    _subscription = TrinityEventBus.instance.stream.listen((_) {
      if (mounted) {
        _loadEvents();
        if (widget.autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  void _loadEvents() {
    final buffer = TrinityEventBus.instance.buffer;
    setState(() {
      _events = buffer.length > widget.maxEvents
          ? buffer.sublist(buffer.length - widget.maxEvents)
          : buffer.toList();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF161B22),
            child: Row(
              children: [
                const Icon(Icons.account_tree,
                    color: Color(0xFF58A6FF), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Causality Graph (${_events.length} events)',
                  style: const TextStyle(
                    color: Color(0xFFC9D1D9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Filter chips
                _FilterChip(
                  label: 'All',
                  isSelected: true,
                  onTap: () => _loadEvents(),
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: _events.isEmpty
                ? const Center(
                    child: Text(
                      'No events yet.\nInteract with the app to see causal events.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF484F58), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      final isSelected = event.id == _selectedEventId;
                      return _EventCard(
                        event: event,
                        isSelected: isSelected,
                        onTap: () => _onEventTap(event),
                      );
                    },
                  ),
          ),

          // Detail panel for selected event
          if (_selectedEventId != null) _buildDetailPanel(),
        ],
      ),
    );
  }

  void _onEventTap(CausalEvent event) {
    setState(() {
      _selectedEventId = _selectedEventId == event.id ? null : event.id;
    });
  }

  Widget _buildDetailPanel() {
    final event = CausalGraph.instance.getEvent(_selectedEventId!);
    if (event == null) return const SizedBox.shrink();

    final ancestors = CausalGraph.instance.getAncestors(event.id);
    final descendants = CausalGraph.instance.getDescendants(event.id);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _DetailRow('ID', event.id),
            if (event.parentId != null) _DetailRow('Parent', event.parentId!),
            _DetailRow('Type', event.type.name),
            _DetailRow('Time', event.timestamp.toIso8601String()),
            if (event.duration != null)
              _DetailRow('Duration', '${event.duration!.inMilliseconds}ms'),
            const SizedBox(height: 8),
            if (ancestors.isNotEmpty)
              Text(
                'Ancestors: ${ancestors.length} (root: ${ancestors.first.description})',
                style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
              ),
            if (descendants.isNotEmpty)
              Text(
                'Descendants: ${descendants.length}',
                style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11),
              ),
            if (event.metadata.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Metadata:',
                style: TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...event.metadata.entries.map((e) => _DetailRow(
                    e.key,
                    e.value.toString(),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F6FEB) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1F6FEB) : const Color(0xFF30363D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8B949E),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CausalEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1F6FEB) : const Color(0xFF21262D),
          ),
        ),
        child: Row(
          children: [
            // Type indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _eventColor(event.type),
                shape: BoxShape.circle,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC9D1D9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.type.name} · ${_formatTime(event.timestamp)}',
                    style: const TextStyle(
                      color: Color(0xFF484F58),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Parent indicator
            if (event.parentId != null)
              const Icon(
                Icons.link,
                color: Color(0xFF484F58),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  static Color _eventColor(CausalEventType type) {
    return switch (type) {
      CausalEventType.userAction => const Color(0xFF58A6FF),
      CausalEventType.stateChange => const Color(0xFF3FB950),
      CausalEventType.networkEvent => const Color(0xFFD2A8FF),
      CausalEventType.uiRebuild => const Color(0xFF79C0FF),
      CausalEventType.crashEvent => const Color(0xFFF85149),
      CausalEventType.layoutDecision => const Color(0xFFE3B341),
      CausalEventType.custom => const Color(0xFF8B949E),
    };
  }

  static String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFC9D1D9),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
