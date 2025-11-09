#!/usr/bin/env dart
/// CLI tool for exporting/importing event history for debugging.
///
/// This is a dev-only tool for exporting subsections of event logs
/// and re-importing them for crash reproduction and debugging workflows.
///
/// **Usage:**
/// ```bash
/// # Export event range
/// dart tools/history_export.dart export \
///   --document-id=doc-123 \
///   --start=5000 \
///   --end=5500 \
///   --output=tmp/history_5000-5500.debug.json
///
/// # Import event history
/// dart tools/history_export.dart import \
///   --document-id=doc-123 \
///   --input=tmp/history_5000-5500.debug.json
/// ```
///
/// **Security Warning:**
/// - Exported files bypass encryption and may contain sensitive data
/// - Do NOT share exported history files externally
/// - Use only for local debugging and reproduction workflows
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';

// ANSI color codes for terminal output
const _red = '\x1B[31m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _blue = '\x1B[34m';
const _reset = '\x1B[0m';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('export', _buildExportParser())
    ..addCommand('import', _buildImportParser())
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool || results.command == null) {
      _printUsage(parser);
      exit(0);
    }

    final command = results.command!;
    switch (command.name) {
      case 'export':
        await _handleExport(command);
        break;
      case 'import':
        await _handleImport(command);
        break;
      default:
        _printError('Unknown command: ${command.name}');
        _printUsage(parser);
        exit(1);
    }
  } on FormatException catch (e) {
    _printError('Invalid arguments: $e');
    _printUsage(parser);
    exit(1);
  } catch (e, stackTrace) {
    _printError('Fatal error: $e');
    print(stackTrace);
    exit(1);
  }
}

ArgParser _buildExportParser() {
  return ArgParser()
    ..addOption(
      'document-id',
      abbr: 'd',
      mandatory: true,
      help: 'Document UUID to export events from',
    )
    ..addOption(
      'start',
      abbr: 's',
      mandatory: true,
      help: 'Starting event sequence number (inclusive)',
    )
    ..addOption(
      'end',
      abbr: 'e',
      mandatory: true,
      help: 'Ending event sequence number (inclusive)',
    )
    ..addOption(
      'output',
      abbr: 'o',
      mandatory: true,
      help: 'Output file path (e.g., tmp/history.debug.json)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose logging',
    );
}

ArgParser _buildImportParser() {
  return ArgParser()
    ..addOption(
      'document-id',
      abbr: 'd',
      mandatory: true,
      help: 'Target document UUID for import',
    )
    ..addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: 'Input file path (e.g., tmp/history.debug.json)',
    )
    ..addFlag(
      'skip-validation',
      negatable: false,
      help: 'Skip event schema validation (faster but risky)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose logging',
    );
}

Future<void> _handleExport(ArgResults args) async {
  final documentId = args['document-id'] as String;
  final startSeq = int.parse(args['start'] as String);
  final endSeq = int.parse(args['end'] as String);
  final outputPath = args['output'] as String;
  final verbose = args['verbose'] as bool;

  _printInfo('Starting history export...');
  _printInfo('  Document ID: $documentId');
  _printInfo('  Event range: $startSeq - $endSeq');
  _printInfo('  Output file: $outputPath');

  // Validation
  if (startSeq < 0) {
    _printError('Start sequence must be >= 0');
    exit(1);
  }
  if (startSeq > endSeq) {
    _printError('Start sequence must be <= end sequence');
    exit(1);
  }

  final eventCount = endSeq - startSeq + 1;
  if (eventCount > HistoryExporter.kMaxExportEvents) {
    _printError(
      'Event range ($eventCount) exceeds maximum (${HistoryExporter.kMaxExportEvents}). '
      'Use smaller ranges to prevent memory exhaustion.',
    );
    exit(1);
  }

  _printWarning('\n⚠️  SECURITY WARNING ⚠️');
  _printWarning('Exported files bypass encryption and may contain sensitive data.');
  _printWarning('Do NOT share exported history files externally.');
  _printWarning('Use only for local debugging and reproduction workflows.\n');

  // Initialize services
  // Note: In a real implementation, you'd construct actual EventStoreGateway
  // and other dependencies from your application context. This is a stub.
  _printError('\n❌ NOT IMPLEMENTED: Event store integration pending');
  _printInfo('This CLI tool is a stub. To use it:');
  _printInfo('1. Implement event store gateway initialization');
  _printInfo('2. Wire up HistoryExporter with actual dependencies');
  _printInfo('3. Remove this error and uncomment export logic below\n');

  exit(1);

  /*
  // TODO(I4.T10): Uncomment when event store is available
  final logger = Logger(level: verbose ? Level.debug : Level.info);
  final eventStore = /* TODO: Initialize from app context */;
  final snapshotSerializer = SnapshotSerializer(enableCompression: true);
  final eventReplayer = /* TODO: Initialize from app context */;
  final config = EventCoreDiagnosticsConfig.debug();

  final exporter = HistoryExporter(
    eventStore: eventStore,
    snapshotSerializer: snapshotSerializer,
    eventReplayer: eventReplayer,
    logger: logger,
    config: config,
  );

  // Perform export
  final exportData = await exporter.exportRange(
    documentId: documentId,
    startSequence: startSeq,
    endSequence: endSeq,
  );

  // Write to file
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);

  final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
  await outputFile.writeAsString(jsonString);

  _printSuccess('\n✅ Export completed successfully!');
  _printInfo('  Output file: $outputPath');
  _printInfo('  Event count: ${exportData['metadata']['eventCount']}');
  _printInfo('  File size: ${(await outputFile.length()) ~/ 1024} KB');
  */
}

Future<void> _handleImport(ArgResults args) async {
  final documentId = args['document-id'] as String;
  final inputPath = args['input'] as String;
  final skipValidation = args['skip-validation'] as bool;
  final verbose = args['verbose'] as bool;

  _printInfo('Starting history import...');
  _printInfo('  Document ID: $documentId');
  _printInfo('  Input file: $inputPath');
  _printInfo('  Schema validation: ${skipValidation ? "disabled" : "enabled"}');

  // Read input file
  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    _printError('Input file not found: $inputPath');
    exit(1);
  }

  _printWarning('\n⚠️  IMPORT WARNING ⚠️');
  _printWarning('Import will replay events and modify document state.');
  _printWarning('Ensure you have backups before proceeding.\n');

  _printError('\n❌ NOT IMPLEMENTED: Event store integration pending');
  _printInfo('This CLI tool is a stub. To use it:');
  _printInfo('1. Implement event store gateway initialization');
  _printInfo('2. Wire up HistoryExporter with actual dependencies');
  _printInfo('3. Remove this error and uncomment import logic below\n');

  exit(1);

  /*
  // TODO(I4.T10): Uncomment when event store is available
  final jsonString = await inputFile.readAsString();
  final importData = jsonDecode(jsonString) as Map<String, dynamic>;

  final logger = Logger(level: verbose ? Level.debug : Level.info);
  final eventStore = /* TODO: Initialize from app context */;
  final snapshotSerializer = SnapshotSerializer(enableCompression: true);
  final eventReplayer = /* TODO: Initialize from app context */;
  final config = EventCoreDiagnosticsConfig.debug();

  final exporter = HistoryExporter(
    eventStore: eventStore,
    snapshotSerializer: snapshotSerializer,
    eventReplayer: eventReplayer,
    logger: logger,
    config: config,
  );

  // Perform import
  final finalSequence = await exporter.importFromJson(
    importData: importData,
    documentId: documentId,
    validateSchema: !skipValidation,
  );

  _printSuccess('\n✅ Import completed successfully!');
  _printInfo('  Final sequence: $finalSequence');
  _printInfo('  Event count: ${importData['metadata']['eventCount']}');
  */
}

void _printUsage(ArgParser parser) {
  print('''
${_blue}WireTuner History Export/Import CLI Tool$_reset

${_yellow}⚠️  DEV-ONLY FEATURE - DO NOT USE IN PRODUCTION ⚠️$_reset

This tool exports/imports event log subsections for debugging and crash reproduction.

${_green}USAGE:$_reset

  Export event range:
    dart tools/history_export.dart export \\
      --document-id=<uuid> \\
      --start=<sequence> \\
      --end=<sequence> \\
      --output=<file.debug.json>

  Import event history:
    dart tools/history_export.dart import \\
      --document-id=<uuid> \\
      --input=<file.debug.json>

${_green}COMMANDS:$_reset

${parser.usage}

${_green}EXAMPLES:$_reset

  # Export events 5000-5500 to debug file
  dart tools/history_export.dart export \\
    -d doc-123 -s 5000 -e 5500 -o tmp/crash.debug.json

  # Import debug file with verbose logging
  dart tools/history_export.dart import \\
    -d doc-456 -i tmp/crash.debug.json -v

  # Import without schema validation (faster)
  dart tools/history_export.dart import \\
    -d doc-789 -i tmp/crash.debug.json --skip-validation

${_yellow}SECURITY WARNINGS:$_reset
  • Exported files bypass encryption and may contain sensitive data
  • Do NOT share exported history files externally
  • Use only for local debugging and reproduction workflows
  • Mark exported files with .debug.json extension for visibility

${_green}SEE ALSO:$_reset
  docs/reference/history_debug.md - Full documentation and workflows
''');
}

void _printInfo(String message) {
  print('$_blue[INFO]$_reset $message');
}

void _printSuccess(String message) {
  print('$_green[SUCCESS]$_reset $message');
}

void _printWarning(String message) {
  print('$_yellow[WARNING]$_reset $message');
}

void _printError(String message) {
  print('$_red[ERROR]$_reset $message');
}
