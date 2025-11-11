import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/infrastructure/persistence/migrations/migration.dart';
import 'package:wiretuner/infrastructure/persistence/migrations/migration_manager.dart';
import 'package:wiretuner/infrastructure/persistence/migrations/version_1_to_2.dart';

/// Mock migration for testing (v2 → v3).
class MockVersion2To3Migration implements Migration {
  bool wasApplied = false;

  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  Future<void> apply(Transaction txn) async {
    wasApplied = true;
    Logger().d('MockVersion2To3Migration applied');
    // Create a test table to verify migration ran
    await txn.execute('CREATE TABLE test_v3_table (id INTEGER PRIMARY KEY)');
  }
}

/// Mock migration for testing (v3 → v4).
class MockVersion3To4Migration implements Migration {
  bool wasApplied = false;

  @override
  int get fromVersion => 3;

  @override
  int get toVersion => 4;

  @override
  Future<void> apply(Transaction txn) async {
    wasApplied = true;
    Logger().d('MockVersion3To4Migration applied');
    await txn.execute('CREATE TABLE test_v4_table (id INTEGER PRIMARY KEY)');
  }
}

/// Migration that intentionally fails for testing rollback.
class FailingMigration implements Migration {
  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  Future<void> apply(Transaction txn) async {
    throw Exception('Intentional migration failure for testing');
  }
}

/// Invalid migration (non-sequential version jump).
class InvalidMigration implements Migration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 3; // Skips version 2

  @override
  Future<void> apply(Transaction txn) async {}
}

void main() {
  // Initialize FFI once for all tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationManager', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        onOpen: (db) async {
          // Enable foreign keys for all test connections
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );

      // Create base schema (v1) for testing
      await _createBaseSchema(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('constructor validation', () {
      test('accepts valid sequential migrations', () {
        expect(
          () => MigrationManager(migrations: [
            Version1To2Migration(),
            MockVersion2To3Migration(),
          ]),
          returnsNormally,
        );
      });

      test('throws ArgumentError for non-sequential migration', () {
        expect(
          () => MigrationManager(migrations: [
            InvalidMigration(), // v1 → v3 (skips v2)
          ]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for duplicate fromVersion', () {
        expect(
          () => MigrationManager(migrations: [
            Version1To2Migration(),
            Version1To2Migration(), // Duplicate
          ]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts empty migration list', () {
        expect(
          () => MigrationManager(migrations: []),
          returnsNormally,
        );
      });
    });

    group('applyMigrations()', () {
      test('returns no-op result when fromVersion equals toVersion', () async {
        final manager = MigrationManager(migrations: []);

        final result = await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 1,
        );

        expect(result.fromVersion, equals(1));
        expect(result.toVersion, equals(1));
        expect(result.migrationsApplied, equals(0));
        expect(result.wasMigrated, isFalse);
        expect(result.durationMs, equals(0));
      });

      test('applies single migration (v1 → v2)', () async {
        final v1to2 = Version1To2Migration();
        final manager = MigrationManager(migrations: [v1to2]);

        final result = await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 2,
        );

        expect(result.fromVersion, equals(1));
        expect(result.toVersion, equals(2));
        expect(result.migrationsApplied, equals(1));
        expect(result.wasMigrated, isTrue);
        expect(result.durationMs, greaterThanOrEqualTo(0));

        // Verify metadata was updated
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(2));
      });

      test('applies multi-step migration (v1 → v2 → v3)', () async {
        final v1to2 = Version1To2Migration();
        final v2to3 = MockVersion2To3Migration();
        final manager = MigrationManager(migrations: [v1to2, v2to3]);

        final result = await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 3,
        );

        expect(result.fromVersion, equals(1));
        expect(result.toVersion, equals(3));
        expect(result.migrationsApplied, equals(2));
        expect(result.wasMigrated, isTrue);

        // Verify both migrations were applied
        expect(v2to3.wasApplied, isTrue);

        // Verify metadata was updated to v3
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(3));

        // Verify v3 test table was created
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='test_v3_table'",
        );
        expect(tables, hasLength(1));
      });

      test('applies three-step migration (v1 → v2 → v3 → v4)', () async {
        final v1to2 = Version1To2Migration();
        final v2to3 = MockVersion2To3Migration();
        final v3to4 = MockVersion3To4Migration();
        final manager = MigrationManager(
          migrations: [v1to2, v2to3, v3to4],
        );

        final result = await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 4,
        );

        expect(result.fromVersion, equals(1));
        expect(result.toVersion, equals(4));
        expect(result.migrationsApplied, equals(3));

        // Verify all migrations were applied
        expect(v2to3.wasApplied, isTrue);
        expect(v3to4.wasApplied, isTrue);

        // Verify metadata was updated to v4
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(4));

        // Verify both test tables exist
        final v3Table = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='test_v3_table'",
        );
        expect(v3Table, hasLength(1));

        final v4Table = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='test_v4_table'",
        );
        expect(v4Table, hasLength(1));
      });

      test('throws MigrationException when migration path does not exist',
          () async {
        final manager = MigrationManager(migrations: []);

        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: 1,
            toVersion: 2,
          ),
          throwsA(isA<MigrationException>()),
        );
      });

      test('throws MigrationException when migration fails', () async {
        final manager = MigrationManager(migrations: [
          Version1To2Migration(),
          FailingMigration(), // v2 → v3 fails
        ]);

        // First migration should succeed
        await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 2,
        );

        // Second migration should fail
        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: 2,
            toVersion: 3,
          ),
          throwsA(isA<MigrationException>()),
        );

        // Verify metadata was NOT updated to v3 (rollback)
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(2));
      });

      test('throws MigrationException for downgrade attempt', () async {
        final manager = MigrationManager(migrations: []);

        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: 3,
            toVersion: 1,
          ),
          throwsA(isA<MigrationException>()),
        );
      });

      test('throws ArgumentError for negative version numbers', () async {
        final manager = MigrationManager(migrations: []);

        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: -1,
            toVersion: 1,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: 1,
            toVersion: -1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('metadata update fails if metadata table is empty', () async {
        // Delete metadata row
        await db.delete('metadata');

        final manager = MigrationManager(migrations: [Version1To2Migration()]);

        expect(
          () => manager.applyMigrations(
            db: db,
            fromVersion: 1,
            toVersion: 2,
          ),
          throwsA(isA<MigrationException>()),
        );
      });
    });

    group('MigrationResult', () {
      test('wasMigrated returns true when migrations applied', () {
        final result = MigrationResult(
          fromVersion: 1,
          toVersion: 3,
          migrationsApplied: 2,
          durationMs: 100,
        );

        expect(result.wasMigrated, isTrue);
      });

      test('wasMigrated returns false when no migrations applied', () {
        final result = MigrationResult(
          fromVersion: 1,
          toVersion: 1,
          migrationsApplied: 0,
          durationMs: 0,
        );

        expect(result.wasMigrated, isFalse);
      });

      test('toString() includes version and timing info', () {
        final result = MigrationResult(
          fromVersion: 1,
          toVersion: 3,
          migrationsApplied: 2,
          durationMs: 150,
        );

        final str = result.toString();
        expect(str, contains('v1'));
        expect(str, contains('v3'));
        expect(str, contains('2'));
        expect(str, contains('150ms'));
      });
    });

    group('Version1To2Migration', () {
      test('has correct version numbers', () {
        final migration = Version1To2Migration();

        expect(migration.fromVersion, equals(1));
        expect(migration.toVersion, equals(2));
      });

      test('apply() is a no-op stub', () async {
        final migration = Version1To2Migration();

        // Should not throw
        await db.transaction((txn) async {
          await migration.apply(txn);
        });

        // No new tables should be created beyond base schema
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
        );

        // All three base tables should still exist
        expect(tables, hasLength(3));
      });
    });

    group('transaction safety', () {
      test('migration runs in transaction (atomic)', () async {
        final manager = MigrationManager(migrations: [Version1To2Migration()]);

        // Migration should complete atomically
        final result = await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 2,
        );

        expect(result.wasMigrated, isTrue);

        // Verify metadata was updated within same transaction
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(2));
      });

      test('failed migration rolls back changes', () async {
        final manager = MigrationManager(migrations: [
          Version1To2Migration(),
          FailingMigration(),
        ]);

        // v1 → v2 succeeds
        await manager.applyMigrations(
          db: db,
          fromVersion: 1,
          toVersion: 2,
        );

        // v2 → v3 fails
        try {
          await manager.applyMigrations(
            db: db,
            fromVersion: 2,
            toVersion: 3,
          );
        } catch (e) {
          // Expected
        }

        // Verify metadata was NOT updated to v3 (rolled back)
        final metadata = await db.query('metadata', limit: 1);
        expect(metadata.first['format_version'], equals(2));
      });
    });

    group('integration with LoadService pattern', () {
      test('detects current version from metadata', () async {
        final manager = MigrationManager(migrations: [
          Version1To2Migration(),
          MockVersion2To3Migration(),
        ]);

        // Simulate LoadService reading metadata
        final metadata = await db.query('metadata', limit: 1);
        final currentVersion = metadata.first['format_version'] as int;

        expect(currentVersion, equals(1));

        // Simulate LoadService calling manager
        const targetVersion = 3;
        if (currentVersion < targetVersion) {
          final result = await manager.applyMigrations(
            db: db,
            fromVersion: currentVersion,
            toVersion: targetVersion,
          );

          expect(result.wasMigrated, isTrue);
        }

        // Verify version updated
        final updatedMetadata = await db.query('metadata', limit: 1);
        expect(updatedMetadata.first['format_version'], equals(3));
      });

      test('no-op when already at target version', () async {
        final manager = MigrationManager(migrations: []);

        // Simulate opening document with current version
        final metadata = await db.query('metadata', limit: 1);
        final currentVersion = metadata.first['format_version'] as int;

        const targetVersion = 1;
        final result = await manager.applyMigrations(
          db: db,
          fromVersion: currentVersion,
          toVersion: targetVersion,
        );

        expect(result.wasMigrated, isFalse);
        expect(result.migrationsApplied, equals(0));
      });
    });
  });
}

/// Helper to create base schema (v1) for testing.
Future<void> _createBaseSchema(Database db) async {
  // Create metadata table
  await db.execute('''
    CREATE TABLE metadata (
      document_id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      format_version INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      modified_at INTEGER NOT NULL,
      author TEXT
    )
  ''');

  // Create events table
  await db.execute('''
    CREATE TABLE events (
      event_id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id TEXT NOT NULL,
      event_sequence INTEGER NOT NULL,
      event_type TEXT NOT NULL,
      event_payload TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      user_id TEXT,
      UNIQUE (document_id, event_sequence),
      FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE
    )
  ''');

  // Create snapshots table
  await db.execute('''
    CREATE TABLE snapshots (
      snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id TEXT NOT NULL,
      event_sequence INTEGER NOT NULL,
      snapshot_data BLOB NOT NULL,
      created_at INTEGER NOT NULL,
      compression TEXT NOT NULL,
      FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE
    )
  ''');

  // Create indexes
  await db.execute('''
    CREATE INDEX idx_events_document_sequence ON events(document_id, event_sequence)
  ''');

  await db.execute('''
    CREATE INDEX idx_snapshots_document ON snapshots(document_id)
  ''');

  // Insert test metadata
  await db.insert('metadata', {
    'document_id': 'test-doc-1',
    'title': 'Test Document',
    'format_version': 1,
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'modified_at': DateTime.now().millisecondsSinceEpoch,
    'author': 'Test Author',
  });
}
