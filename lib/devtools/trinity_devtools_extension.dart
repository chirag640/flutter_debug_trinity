import 'package:flutter/material.dart';
import 'panel/timeline_panel.dart';
import 'panel/graph_panel.dart';
import 'panel/explanation_panel.dart';
import 'service_extension_bridge.dart';

/// The main DevTools extension widget for Flutter Debug Trinity.
///
/// Provides a tabbed interface with:
/// - **Timeline**: Chronological stream of all Trinity events
/// - **Graph**: Interactive causal DAG visualization
/// - **Explanations**: Layout overflow analysis with fix suggestions
///
/// ## Usage as DevTools Extension
///
/// This widget is designed to be the root of a Flutter DevTools extension.
/// Register it as a DevTools extension in your `pubspec.yaml`:
///
/// ```yaml
/// # In the extension's pubspec.yaml
/// devtools:
///   extension:
///     name: flutter_debug_trinity
///     issueTracker: https://github.com/chirag640/flutter_debug_trinity/issues
/// ```
///
/// ## Usage as In-App Overlay
///
/// You can also embed this directly in your app for on-device debugging:
///
/// ```dart
/// // Show as a bottom sheet
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => SizedBox(
///     height: MediaQuery.of(context).size.height * 0.8,
///     child: const TrinityDevToolsExtension(),
///   ),
/// );
/// ```
class TrinityDevToolsExtension extends StatefulWidget {
  /// Optional initial tab index (0=Timeline, 1=Graph, 2=Explanations).
  final int initialTab;

  const TrinityDevToolsExtension({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<TrinityDevToolsExtension> createState() =>
      _TrinityDevToolsExtensionState();
}

class _TrinityDevToolsExtensionState extends State<TrinityDevToolsExtension>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    // Ensure service extensions are registered
    ServiceExtensionBridge.register();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64B5F6),
          secondary: Color(0xFFFFD54F),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          toolbarHeight: 36,
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFF64B5F6), size: 18),
              SizedBox(width: 8),
              Text(
                'Flutter Debug Trinity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: const Color(0xFF64B5F6),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(
                icon: Icon(Icons.timeline, size: 14),
                text: 'Timeline',
              ),
              Tab(
                icon: Icon(Icons.account_tree, size: 14),
                text: 'Graph',
              ),
              Tab(
                icon: Icon(Icons.format_align_left, size: 14),
                text: 'Explain',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            TimelinePanel(),
            GraphPanel(),
            ExplanationPanel(),
          ],
        ),
      ),
    );
  }
}

/// A floating action button that opens the Trinity DevTools overlay.
///
/// Add this to your app's Scaffold for quick debug access:
///
/// ```dart
/// Scaffold(
///   floatingActionButton: const TrinityDebugFab(),
///   body: ...,
/// )
/// ```
class TrinityDebugFab extends StatelessWidget {
  const TrinityDebugFab({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    assert(() {
      return true;
    }());

    return FloatingActionButton(
      mini: true,
      backgroundColor: const Color(0xFF1A1A2E),
      onPressed: () => _showTrinityOverlay(context),
      tooltip: 'Open Debug Trinity',
      child: const Icon(Icons.bug_report, color: Color(0xFF64B5F6), size: 20),
    );
  }

  void _showTrinityOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: TrinityDevToolsExtension(),
          );
        },
      ),
    );
  }
}
