import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'app.dart';

/// WireTuner application entry point.
/// Initializes logging and runs the application.
void main() {
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

  runApp(const App());
}
