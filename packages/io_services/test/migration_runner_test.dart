import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:io_services/io_services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI once for all tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationRunner', () {
    late Database db;
    late MigrationRunner runner;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        onOpen: (db) async {
          // Enable foreign keys for all test connections
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
      runner = MigrationRunner(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('runMigrations()', () {
      test('applies base schema migration (version 1)', () async {
        await runner.runMigrations(targetVersion: 1);

        // Verify tables were created
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
        );

        expect(tables, hasLength(3));
      });

      test('sets database version correctly', () async {
        await runner.runMigrations(targetVersion: 1);

        final version = await db.getVersion();
        expect(version, equals(1));
      });

      test('is idempotent (safe to run multiple times)', () async {
        await runner.runMigrations();
        await runner.runMigrations(); // Should not throw

        final version = await db.getVersion();
        expect(version, equals(MigrationRunner.currentVersion));
      });

      test('skips migration if already at target version', () async {
        await db.setVersion(1);

        // Should return early without error
        await runner.runMigrations(targetVersion: 1);

        final version = await db.getVersion();
        expect(version, equals(1));
      });

      test('throws StateError for downgrade attempt', () async {
        await db.setVersion(2);

        expect(
          () => runner.runMigrations(targetVersion: 1),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError for undefined migration version', () async {
        expect(
          () => runner.runMigrations(targetVersion: 999),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('verifySchema()', () {
      test('returns true for valid schema', () async {
        await runner.runMigrations();

        final isValid = await runner.verifySchema();
        expect(isValid, isTrue);
      });

      test('returns false when tables are missing', () async {
        // Create only one table
        await db.execute('''
          CREATE TABLE metadata (
            document_id TEXT PRIMARY KEY
          )
        ''');

        final isValid = await runner.verifySchema();
        expect(isValid, isFalse);
      });

      test('returns false when indexes are missing', () async {
        // Create tables but not indexes
        await db.execute('''
          CREATE TABLE metadata (
            document_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            format_version INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            author TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE events (
            event_id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id TEXT NOT NULL,
            event_sequence INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            event_payload TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            user_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE snapshots (
            snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id TEXT NOT NULL,
            event_sequence INTEGER NOT NULL,
            snapshot_data BLOB NOT NULL,
            created_at INTEGER NOT NULL,
            compression TEXT NOT NULL
          )
        ''');

        final isValid = await runner.verifySchema();
        expect(isValid, isFalse);
      });

      test('returns false when foreign keys are disabled', () async {
        await runner.runMigrations();

        // Disable foreign keys
        await db.execute('PRAGMA foreign_keys = OFF');

        final isValid = await runner.verifySchema();
        expect(isValid, isFalse);
      });
    });

    group('base schema validation', () {
      setUp(() async {
        await runner.runMigrations();
      });

      test('metadata table has correct structure', () async {
        final columns = await db.rawQuery('PRAGMA table_info(metadata)');

        final columnMap = {
          for (var col in columns) col['name'] as String: col,
        };

        expect(columnMap.keys, containsAll([
          'document_id',
          'title',
          'format_version',
          'created_at',
          'modified_at',
          'author',
        ]));

        expect(columnMap['document_id']!['pk'], equals(1));
        expect(columnMap['title']!['notnull'], equals(1));
      });

      test('events table has correct structure', () async {
        final columns = await db.rawQuery('PRAGMA table_info(events)');

        final columnMap = {
          for (var col in columns) col['name'] as String: col,
        };

        expect(columnMap.keys, containsAll([
          'event_id',
          'document_id',
          'event_sequence',
          'event_type',
          'event_payload',
          'timestamp',
          'user_id',
        ]));

        expect(columnMap['event_id']!['pk'], equals(1));
      });

      test('snapshots table has correct structure', () async {
        final columns = await db.rawQuery('PRAGMA table_info(snapshots)');

        final columnMap = {
          for (var col in columns) col['name'] as String: col,
        };

        expect(columnMap.keys, containsAll([
          'snapshot_id',
          'document_id',
          'event_sequence',
          'snapshot_data',
          'created_at',
          'compression',
        ]));

        expect(columnMap['snapshot_id']!['pk'], equals(1));
        expect(columnMap['snapshot_data']!['type'], equals('BLOB'));
      });

      test('UNIQUE constraint on (document_id, event_sequence)', () async {
        // Insert metadata
        await db.insert('metadata', {
          'document_id': 'doc1',
          'title': 'Test',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        // Insert first event
        await db.insert('events', {
          'document_id': 'doc1',
          'event_sequence': 0,
          'event_type': 'Event1',
          'event_payload': '{}',
          'timestamp': 1234567890,
        });

        // Try to insert duplicate sequence
        expect(
          () => db.insert('events', {
            'document_id': 'doc1',
            'event_sequence': 0,
            'event_type': 'Event2',
            'event_payload': '{}',
            'timestamp': 1234567891,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('foreign key constraints are enforced', () async {
        // Try to insert event without metadata
        expect(
          () => db.insert('events', {
            'document_id': 'nonexistent',
            'event_sequence': 0,
            'event_type': 'Event1',
            'event_payload': '{}',
            'timestamp': 1234567890,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('CASCADE delete removes related events and snapshots', () async {
        // Insert metadata
        await db.insert('metadata', {
          'document_id': 'doc1',
          'title': 'Test',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        // Insert event
        await db.insert('events', {
          'document_id': 'doc1',
          'event_sequence': 0,
          'event_type': 'Event1',
          'event_payload': '{}',
          'timestamp': 1234567890,
        });

        // Insert snapshot
        await db.insert('snapshots', {
          'document_id': 'doc1',
          'event_sequence': 0,
          'snapshot_data': Uint8List.fromList([1, 2, 3]),
          'created_at': 1234567890,
          'compression': 'none',
        });

        // Delete metadata
        await db.delete('metadata', where: 'document_id = ?', whereArgs: ['doc1']);

        // Verify cascading delete
        final events = await db.query('events');
        final snapshots = await db.query('snapshots');

        expect(events, isEmpty);
        expect(snapshots, isEmpty);
      });

      test('indexes are created', () async {
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index'",
        );

        final indexNames = indexes.map((idx) => idx['name'] as String).toList();

        expect(indexNames, contains('idx_events_document_sequence'));
        expect(indexNames, contains('idx_snapshots_document'));
      });

      test('foreign keys are enabled', () async {
        final result = await db.rawQuery('PRAGMA foreign_keys');
        expect(result.first['foreign_keys'], equals(1));
      });
    });
  });
}
