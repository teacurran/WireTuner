import 'package:flutter/material.dart';

/// Root application widget for WireTuner.
/// Configures Material Design 3 theme and application routing.
class App extends StatelessWidget {
  /// Creates the application root widget.
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WireTuner',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _PlaceholderHomePage(),
      );
}

/// Placeholder home page for initial project setup.
/// Will be replaced with the main editor interface in future iterations.
class _PlaceholderHomePage extends StatelessWidget {
  /// Creates the placeholder home page.
  const _PlaceholderHomePage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('WireTuner'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Text(
            'WireTuner - Vector Drawing Application',
            style: TextStyle(fontSize: 24),
          ),
        ),
      );
}
