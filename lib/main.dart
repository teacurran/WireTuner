import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'infrastructure/persistence/database_provider.dart';

/// WireTuner application entry point.
/// Initializes logging, database provider, and runs the application.
Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger for application-wide logging
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  logger.i('WireTuner application starting...');

  // Initialize database provider
  try {
    final databaseProvider = DatabaseProvider();
    await databaseProvider.initialize();
    logger.i('Database provider initialized successfully');
  } catch (e) {
    logger.e('Failed to initialize database provider', error: e);
    // Continue running the app even if database initialization fails
    // This allows the UI to show an error message to the user
  }

  runApp(const App());
}
