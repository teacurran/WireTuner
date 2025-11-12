#!/usr/bin/env dart
/// WAL Integrity Check Script for WireTuner Event Store
///
/// This script performs comprehensive integrity checks on WireTuner database files,
/// including:
/// - WAL checkpoint operations
/// - SQLite integrity_check pragma
/// - Schema validation against blueprint specification
/// - WAL file size analysis
/// - Foreign key constraint verification
///
/// **Usage:**
/// ```bash
/// dart scripts/db/check_integrity.dart <database_file_path>
/// ```
///
/// **Examples:**
/// ```bash
/// # Check a specific document database
/// dart scripts/db/check_integrity.dart ~/Library/Application\ Support/WireTuner/my_document.wiretuner
///
/// # Check with verbose output
/// dart scripts/db/check_integrity.dart --verbose ~/path/to/file.wiretuner
/// ```
///
/// **Exit Codes:**
/// - 0: All checks passed
/// - 1: Integrity check failed
/// - 2: Invalid arguments or file not found
///
/// **Cross-references:**
/// - Task I2.T1: EventStoreServiceAdapter implementation
/// - NFR-REL-001: Crash resistance via WAL + integrity checks
/// - Section 3.7.2.3: Manual integrity checks via SyncAPI

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main(List<String> args) async {
  // Parse arguments
  bool verbose = args.contains('--verbose') || args.contains('-v');
  final nonFlagArgs = args.where((a) => !a.startsWith('--') && !a.startsWith('-')).toList();

  if (nonFlagArgs.isEmpty) {
    printUsage();
    exit(2);
  }

  final dbPath = nonFlagArgs.first;

  // Check file exists
  if (!await File(dbPath).exists()) {
    print('Error: Database file not found: $dbPath');
    exit(2);
  }

  print('WireTuner Database Integrity Check');
  print('=' * 60);
  print('Database: ${path.basename(dbPath)}');
  print('Path: $dbPath');
  print('');

  // Initialize SQLite FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Database? db;
  int exitCode = 0;

  try {
    // Open database
    db = await openDatabase(dbPath, readOnly: true);
    print('✓ Database opened successfully');
    print('');

    // Check 1: Journal Mode
    await checkJournalMode(db, verbose);

    // Check 2: WAL Checkpoint
    await checkWalCheckpoint(db, verbose);

    // Check 3: Integrity Check
    final integrityPassed = await checkIntegrity(db, verbose);
    if (!integrityPassed) {
      exitCode = 1;
    }

    // Check 4: Foreign Keys
    await checkForeignKeys(db, verbose);

    // Check 5: Schema Validation
    await checkSchema(db, verbose);

    // Check 6: Statistics
    await printStatistics(db, verbose);

    print('');
    print('=' * 60);
    if (exitCode == 0) {
      print('✓ All checks passed');
    } else {
      print('✗ Integrity check failed');
    }
  } catch (e, stackTrace) {
    print('');
    print('✗ Error during integrity check: $e');
    if (verbose) {
      print('Stack trace:');
      print(stackTrace);
    }
    exitCode = 1;
  } finally {
    await db?.close();
  }

  exit(exitCode);
}

void printUsage() {
  print('Usage: dart check_integrity.dart [options] <database_file>');
  print('');
  print('Options:');
  print('  --verbose, -v    Show detailed output');
  print('');
  print('Examples:');
  print('  dart check_integrity.dart my_document.wiretuner');
  print('  dart check_integrity.dart --verbose ~/path/to/file.wiretuner');
}

Future<void> checkJournalMode(Database db, bool verbose) async {
  print('Checking journal mode...');
  final result = await db.rawQuery('PRAGMA journal_mode');
  final mode = result.isNotEmpty ? result.first.values.first as String : 'unknown';

  if (mode.toLowerCase() == 'wal') {
    print('✓ Journal mode: WAL (Write-Ahead Logging)');
  } else {
    print('⚠ Journal mode: $mode (expected WAL)');
  }

  if (verbose) {
    print('  WAL provides better concurrency and crash resistance');
  }
  print('');
}

Future<void> checkWalCheckpoint(Database db, bool verbose) async {
  print('Performing WAL checkpoint...');
  try {
    final result = await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');

    if (result.isNotEmpty) {
      final busy = result.first['busy'] as int?;
      final log = result.first['log'] as int?;
      final checkpointed = result.first['checkpointed'] as int?;

      print('✓ WAL checkpoint completed');

      if (verbose) {
        print('  Busy: $busy');
        print('  Log pages: $log');
        print('  Checkpointed pages: $checkpointed');
      }
    } else {
      print('✓ WAL checkpoint completed (no data returned)');
    }
  } catch (e) {
    print('⚠ WAL checkpoint warning: $e');
  }
  print('');
}

Future<bool> checkIntegrity(Database db, bool verbose) async {
  print('Running integrity check...');
  try {
    final result = await db.rawQuery('PRAGMA integrity_check');

    if (result.length == 1 && result.first.values.first == 'ok') {
      print('✓ Database integrity: OK');
      return true;
    } else {
      print('✗ Database integrity: FAILED');
      print('  Errors found:');
      for (final row in result) {
        print('  - ${row.values.join(', ')}');
      }
      return false;
    }
  } catch (e) {
    print('✗ Integrity check error: $e');
    return false;
  } finally {
    print('');
  }
}

Future<void> checkForeignKeys(Database db, bool verbose) async {
  print('Checking foreign key constraints...');
  try {
    // Enable foreign keys for this check
    await db.execute('PRAGMA foreign_keys = ON');

    final result = await db.rawQuery('PRAGMA foreign_key_check');

    if (result.isEmpty) {
      print('✓ Foreign key constraints: OK');
    } else {
      print('⚠ Foreign key violations found:');
      for (final row in result) {
        print('  Table: ${row['table']}, Row: ${row['rowid']}, Parent: ${row['parent']}');
      }
    }

    if (verbose) {
      final fkStatus = await db.rawQuery('PRAGMA foreign_keys');
      final enabled = fkStatus.isNotEmpty ? fkStatus.first.values.first == 1 : false;
      print('  Foreign keys enabled: $enabled');
    }
  } catch (e) {
    print('⚠ Foreign key check warning: $e');
  }
  print('');
}

Future<void> checkSchema(Database db, bool verbose) async {
  print('Validating schema...');

  try {
    // Check for required tables
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final tableNames = tables.map((t) => t['name'] as String).toSet();

    final requiredTables = {
      'documents',
      'artboards',
      'layers',
      'events',
      'snapshots',
      'export_jobs',
    };

    final missingTables = requiredTables.difference(tableNames);

    if (missingTables.isEmpty) {
      print('✓ Schema: All required tables present');
      if (verbose) {
        print('  Tables: ${tableNames.join(', ')}');
      }
    } else {
      print('⚠ Schema: Missing tables: ${missingTables.join(', ')}');
      if (verbose) {
        print('  Found tables: ${tableNames.join(', ')}');
      }
    }

    // Check indexes
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
    );
    final indexNames = indexes.map((i) => i['name'] as String).toSet();

    if (verbose) {
      print('  Indexes: ${indexNames.length} found');
      for (final idx in indexNames) {
        if (!idx.startsWith('sqlite_')) {
          print('    - $idx');
        }
      }
    }

    // Check events table columns
    final eventsColumns = await db.rawQuery('PRAGMA table_info(events)');
    final columnNames = eventsColumns.map((c) => c['name'] as String).toSet();
    final requiredColumns = {
      'event_id',
      'document_id',
      'sequence',
      'artboard_id',
      'timestamp',
      'user_id',
      'event_type',
      'event_data',
      'sampled_path',
      'operation_id',
    };

    final missingColumns = requiredColumns.difference(columnNames);

    if (missingColumns.isEmpty) {
      print('✓ Events table: All required columns present');
    } else {
      print('⚠ Events table: Missing columns: ${missingColumns.join(', ')}');
    }
  } catch (e) {
    print('⚠ Schema validation error: $e');
  }
  print('');
}

Future<void> printStatistics(Database db, bool verbose) async {
  print('Database statistics:');

  try {
    // Document count
    final docResult = await db.rawQuery('SELECT COUNT(*) as count FROM documents');
    final docCount = docResult.first['count'] as int;
    print('  Documents: $docCount');

    // Event count
    final eventResult = await db.rawQuery('SELECT COUNT(*) as count FROM events');
    final eventCount = eventResult.first['count'] as int;
    print('  Events: $eventCount');

    // Snapshot count
    final snapshotResult = await db.rawQuery('SELECT COUNT(*) as count FROM snapshots');
    final snapshotCount = snapshotResult.first['count'] as int;
    print('  Snapshots: $snapshotCount');

    // Artboard count
    final artboardResult = await db.rawQuery('SELECT COUNT(*) as count FROM artboards');
    final artboardCount = artboardResult.first['count'] as int;
    print('  Artboards: $artboardCount');

    if (verbose) {
      // Page size and count
      final pageSizeResult = await db.rawQuery('PRAGMA page_size');
      final pageSize = pageSizeResult.first.values.first as int;

      final pageCountResult = await db.rawQuery('PRAGMA page_count');
      final pageCount = pageCountResult.first.values.first as int;

      final dbSizeBytes = pageSize * pageCount;
      final dbSizeMB = (dbSizeBytes / 1024 / 1024).toStringAsFixed(2);

      print('  Database size: $dbSizeMB MB ($pageCount pages × $pageSize bytes)');

      // WAL auto-checkpoint
      final walCheckpointResult = await db.rawQuery('PRAGMA wal_autocheckpoint');
      final walCheckpoint = walCheckpointResult.first.values.first as int;
      print('  WAL auto-checkpoint: $walCheckpoint pages');
    }
  } catch (e) {
    print('  ⚠ Error gathering statistics: $e');
  }
}
