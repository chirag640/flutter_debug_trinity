import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_debug_trinity/flutter_debug_trinity.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterDebugTrinity.initialize();

    runApp(
      const RecoverableApp(
        child: MyDemoApp(),
      ),
    );
  }, FlutterDebugTrinity.zonedErrorHandler);
}

class MyDemoApp extends StatelessWidget {
  const MyDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Debug Trinity Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F3460),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Wrap with ExplanationOverlay for layout debugging
        return ExplanationOverlay(child: child ?? const SizedBox());
      },
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  int _counter = 0;
  final List<String> _eventLog = [];
  StreamSubscription<CausalEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    // Listen to all events from the bus — stored for cancellation in dispose()
    _eventSub = TrinityEventBus.instance.stream.listen((event) {
      if (mounted) {
        setState(() {
          _eventLog.add(
            '[${event.type.name}] ${event.description}',
          );
          // Keep last 20 entries
          if (_eventLog.length > 20) {
            _eventLog.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void _incrementCounter() {
    CausalityZone.run('user_tap_increment', () {
      setState(() => _counter++);
      // Emit a user action event
      TrinityEventBus.instance.emit(CausalEvent(
        type: CausalEventType.userAction,
        description: 'Counter incremented to $_counter',
        metadata: {'counter_value': _counter},
      ));
    });
  }

  void _triggerRecoverableCrash() {
    CausalityZone.run('demo_crash', () {
      throw StateError('Demo crash — this is intentional!');
    });
  }

  void _triggerOverflow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _OverflowDemoPage()),
    );
  }

  void _openVisualizer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Causality Visualizer')),
          body: const CausalityVisualizer(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_debug_trinity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Open Causality Visualizer',
            onPressed: _openVisualizer,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Counter section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Counter', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '$_counter',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _incrementCounter,
                      icon: const Icon(Icons.add),
                      label: const Text('Increment'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Demo actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Demo Actions',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _triggerRecoverableCrash,
                      icon: const Icon(Icons.warning, color: Colors.red),
                      label: const Text('Trigger Crash (recovers)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(30),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _triggerOverflow,
                      icon: const Icon(Icons.width_wide),
                      label: const Text('Trigger Overflow Demo'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openVisualizer,
                      icon: const Icon(Icons.account_tree),
                      label: const Text('Open Causality Visualizer'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live event log
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Live Event Log',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${TrinityEventBus.instance.buffer.length} total',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: _eventLog.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tap buttons above to generate events',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _eventLog.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      _eventLog[index],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A demo page that intentionally causes a layout overflow
/// to demonstrate the ExplanationOverlay and fix suggestions.
class _OverflowDemoPage extends StatelessWidget {
  const _OverflowDemoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overflow Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This page demonstrates layout overflow detection.\n'
              'The row below intentionally overflows.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Intentional overflow
            Container(
              width: 200,
              color: Colors.grey.withAlpha(30),
              child: const Row(
                children: [
                  Text(
                    'This text is intentionally very long to cause a horizontal overflow in the Row widget',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Check the bug report FAB (bottom-right) to see\n'
              'the explanation and fix suggestions.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
