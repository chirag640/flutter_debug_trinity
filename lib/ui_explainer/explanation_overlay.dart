import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'layout_decision_recorder.dart';
import 'explanation_engine.dart';

/// An overlay widget that shows layout explanations in debug mode.
///
/// Displays a floating action button that opens a panel showing:
/// - Recent layout decisions
/// - Overflow detections with explanations
/// - Fix suggestions for each issue
///
/// **Debug only** — completely removed in release builds.
///
/// ## Usage
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return ExplanationOverlay(child: child ?? const SizedBox());
///   },
///   home: const MyHomePage(),
/// )
/// ```
class ExplanationOverlay extends StatefulWidget {
  /// The child widget to overlay.
  final Widget child;

  /// Whether to show the overlay toggle button.
  /// Defaults to `kDebugMode`.
  final bool enabled;

  const ExplanationOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
  });

  @override
  State<ExplanationOverlay> createState() => _ExplanationOverlayState();
}

class _ExplanationOverlayState extends State<ExplanationOverlay> {
  bool _showPanel = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_showPanel)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            bottom: 80,
            child: _ExplanationPanel(
              onClose: () => setState(() => _showPanel = false),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'trinity_explanation_overlay',
            mini: true,
            backgroundColor:
                _showPanel ? const Color(0xFFE94560) : const Color(0xFF0F3460),
            onPressed: () => setState(() => _showPanel = !_showPanel),
            child: Icon(
              _showPanel ? Icons.close : Icons.bug_report,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _ExplanationPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final decisions = LayoutDecisionRecorder.instance.buffer;
    final overflows = LayoutDecisionRecorder.instance.overflows;
    final explanations = ExplanationEngine.explainAllOverflows();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF1A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F3460),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Layout Explainer (${overflows.length} overflows / '
                    '${decisions.length} decisions)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: explanations.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No layout overflows detected.\n\n'
                        'Overflows will appear here when they occur.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: explanations.length,
                    itemBuilder: (context, index) {
                      return _ExplanationCard(
                        explanation: explanations[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final LayoutExplanation explanation;

  const _ExplanationCard({required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: Color(0xFFE94560),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation.title,
                    style: const TextStyle(
                      color: Color(0xFFE94560),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detail
            Text(
              explanation.detail,
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),

            // Suggestions
            if (explanation.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Suggested Fixes:',
                style: TextStyle(
                  color: Color(0xFFFFD60A),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...explanation.suggestions.map((fix) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _confidenceColor(fix.confidence),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fix.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              if (fix.codeHint != null) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    fix.codeHint!,
                                    style: const TextStyle(
                                      color: Color(0xFF4EC9B0),
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
                  )),
            ],
          ],
        ),
      ),
    );
  }

  static Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF4EC9B0);
    if (confidence >= 0.5) return const Color(0xFFFFD60A);
    return const Color(0xFFE94560);
  }
}
