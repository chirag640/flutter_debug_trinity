import 'package:flutter/material.dart';
import '../../core/causal_event.dart';
import '../../core/trinity_event_bus.dart';
import '../../ui_explainer/layout_decision_recorder.dart';
import '../../ui_explainer/explanation_engine.dart';
import '../../ui_explainer/fix_suggestion.dart' hide FixSuggestion;
import 'dart:async';

/// A panel that displays layout explanations from the UI Explainer system.
///
/// Shows overflow detections, constraint chain analysis, and fix suggestions
/// in a developer-friendly format. Updates in real-time as layout events
/// are emitted.
class ExplanationPanel extends StatefulWidget {
  const ExplanationPanel({super.key});

  @override
  State<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<ExplanationPanel> {
  final List<_ExplanationEntry> _entries = [];
  StreamSubscription<CausalEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    // Load existing overflows
    for (final d in LayoutDecisionRecorder.instance.overflows) {
      _entries.add(_ExplanationEntry(
        decision: d,
        explanation: ExplanationEngine.explain(d),
        suggestions: FixSuggestionEngine.suggest(d),
        timestamp: d.timestamp,
      ));
    }

    // Subscribe to layout decision events
    _subscription = TrinityEventBus.instance.stream
        .where((e) => e.type == CausalEventType.layoutDecision)
        .listen(_onLayoutEvent);
  }

  void _onLayoutEvent(CausalEvent event) {
    // Try to find the matching LayoutDecision from the recorder
    final overflows = LayoutDecisionRecorder.instance.overflows;
    if (overflows.isNotEmpty) {
      final latest = overflows.last;
      final explanation = ExplanationEngine.explain(latest);
      final suggestions = FixSuggestionEngine.suggest(latest);

      setState(() {
        _entries.add(_ExplanationEntry(
          decision: latest,
          explanation: explanation,
          suggestions: suggestions,
          timestamp: DateTime.now(),
        ));

        // Keep only last 50 entries
        if (_entries.length > 50) {
          _entries.removeRange(0, _entries.length - 50);
        }
      });
    }
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
          child: _entries.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Color(0xFF4CAF50), size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No layout issues detected.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Layout explanations will appear here\n'
                        'when overflow or constraint issues occur.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF666666), fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[_entries.length - 1 - index];
                    return _ExplanationCard(entry: entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final overflowCount = _entries.where((e) => e.decision.overflowed).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF2D2D2D),
      child: Row(
        children: [
          const Icon(Icons.format_align_left, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            'Layout Explanations ($overflowCount overflows)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.white70, size: 18),
            onPressed: () => setState(() => _entries.clear()),
            tooltip: 'Clear',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ExplanationEntry {
  final LayoutDecision decision;
  final LayoutExplanation explanation;
  final List<FixSuggestion> suggestions;
  final DateTime timestamp;

  _ExplanationEntry({
    required this.decision,
    required this.explanation,
    required this.suggestions,
    required this.timestamp,
  });
}

class _ExplanationCard extends StatefulWidget {
  final _ExplanationEntry entry;

  const _ExplanationCard({required this.entry});

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isOverflow = entry.decision.overflowed;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    isOverflow
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: isOverflow
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF4CAF50),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.explanation.title,
                      style: TextStyle(
                        color:
                            isOverflow ? const Color(0xFFFF9800) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Widget type and constraints
              Text(
                '${entry.decision.widgetType} · '
                '${entry.decision.constraintsReceived}',
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Expanded detail
              if (_expanded) ...[
                const Divider(color: Color(0xFF333333)),
                // Detail text
                Text(
                  entry.explanation.detail,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                  ),
                ),
                // Fix suggestions
                if (entry.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Suggested Fixes:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...entry.suggestions
                      .map((fix) => _FixSuggestionTile(fix: fix)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FixSuggestionTile extends StatelessWidget {
  final FixSuggestion fix;

  const _FixSuggestionTile({required this.fix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence indicator
          Container(
            width: 32,
            height: 16,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: _confidenceColor(fix.confidence).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                '${(fix.confidence * 100).toInt()}%',
                style: TextStyle(
                  color: _confidenceColor(fix.confidence),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fix.description,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                if (fix.codeHint != null) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fix.codeHint!,
                      style: const TextStyle(
                        color: Color(0xFF80CBC4),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF4CAF50);
    if (confidence >= 0.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
