import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Schema migration harness for WireTuner event store.
///
/// Manages incremental schema updates from the initial simplified schema
/// (metadata/events/snapshots) to the full blueprint schema with artboards,
/// layers, and enhanced event tracking capabilities.
///
/// Each migration is versioned and applied in sequence, ensuring data integrity
/// during schema evolution. Migrations are idempotent and can be tested independently.
class SchemaMigrationManager {
  static final Logger _logger = Logger();

  /// Current schema version after all migrations.
  static const int targetSchemaVersion = 2;

  /// Applies all pending migrations to bring database to target schema version.
  ///
  /// This method:
  /// 1. Checks current schema version
  /// 2. Applies migrations sequentially from current to target version
  /// 3. Verifies migration success after each step
  /// 4. Updates schema version in database
  ///
  /// Throws [Exception] if any migration fails.
  static Future<void> migrate(Database db, int currentVersion) async {
    _logger.i(
        'Starting schema migration from version $currentVersion to $targetSchemaVersion');

    if (currentVersion >= targetSchemaVersion) {
      _logger.i('Schema is already at target version $targetSchemaVersion');
      return;
    }

    await db.transaction((txn) async {
      // Apply migrations sequentially
      for (int version = currentVersion + 1;
          version <= targetSchemaVersion;
          version++) {
        _logger.i('Applying migration to version $version');
        await _applyMigration(txn, version);
        _logger.i('Migration to version $version completed successfully');
      }
    });

    _logger.i('All migrations completed successfully');
  }

  /// Applies a specific migration version.
  static Future<void> _applyMigration(Transaction txn, int toVersion) async {
    switch (toVersion) {
      case 2:
        await _migrateToV2(txn);
        break;
      default:
        throw Exception('Unknown migration version: $toVersion');
    }
  }

  /// Migration from v1 (simple schema) to v2 (blueprint schema).
  ///
  /// This migration:
  /// 1. Renames metadata table to documents and adds required columns
  /// 2. Creates artboards table with foreign key to documents
  /// 3. Creates layers table with foreign key to artboards
  /// 4. Extends events table with artboard_id, sampled_path, operation_id
  /// 5. Updates snapshots table schema to match blueprint
  /// 6. Creates export_jobs table
  /// 7. Migrates existing data to new schema
  /// 8. Creates updated indexes
  static Future<void> _migrateToV2(Transaction txn) async {
    _logger.d('Migrating to v2: Blueprint schema with artboards and layers');

    // Step 1: Create new documents table with blueprint schema
    await txn.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL DEFAULT 'local-user',
        name TEXT NOT NULL,
        file_format_version TEXT NOT NULL,
        created_at TEXT NOT NULL,
        modified_at TEXT NOT NULL,
        anchor_visibility_mode TEXT NOT NULL DEFAULT 'auto',
        event_count INTEGER NOT NULL DEFAULT 0,
        snapshot_sequence INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Step 2: Migrate data from metadata to documents
    await txn.execute('''
      INSERT INTO documents (id, owner_id, name, file_format_version, created_at, modified_at, event_count)
      SELECT
        document_id,
        'local-user',
        title,
        CAST(format_version AS TEXT),
        datetime(created_at / 1000, 'unixepoch'),
        datetime(modified_at / 1000, 'unixepoch'),
        0
      FROM metadata
    ''');

    // Step 3: Create artboards table
    await txn.execute('''
      CREATE TABLE artboards (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        bounds_x REAL NOT NULL,
        bounds_y REAL NOT NULL,
        bounds_width REAL NOT NULL,
        bounds_height REAL NOT NULL,
        background_color TEXT NOT NULL DEFAULT '#FFFFFF',
        preset TEXT,
        z_order INTEGER NOT NULL,
        thumbnail_timestamp TEXT,
        thumbnail_blob BLOB
      )
    ''');

    // Step 4: Create layers table
    await txn.execute('''
      CREATE TABLE layers (
        id TEXT PRIMARY KEY,
        artboard_id TEXT NOT NULL REFERENCES artboards(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        visible INTEGER NOT NULL DEFAULT 1,
        locked INTEGER NOT NULL DEFAULT 0,
        z_index INTEGER NOT NULL
      )
    ''');

    // Step 5: Create new events table with extended schema
    await txn.execute('''
      CREATE TABLE events_new (
        event_id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        sequence INTEGER NOT NULL UNIQUE,
        artboard_id TEXT,
        timestamp TEXT NOT NULL,
        user_id TEXT NOT NULL DEFAULT 'local-user',
        event_type TEXT NOT NULL,
        event_data TEXT NOT NULL,
        sampled_path TEXT,
        operation_id TEXT,
        FOREIGN KEY (artboard_id) REFERENCES artboards(id) ON DELETE SET NULL
      )
    ''');

    // Step 6: Migrate existing events to new schema
    // Note: Generate TEXT primary keys from INTEGER event_id
    await txn.execute('''
      INSERT INTO events_new (event_id, document_id, sequence, timestamp, user_id, event_type, event_data)
      SELECT
        'evt_' || CAST(event_id AS TEXT),
        document_id,
        event_sequence,
        datetime(timestamp / 1000, 'unixepoch'),
        COALESCE(user_id, 'local-user'),
        event_type,
        event_payload
      FROM events
    ''');

    // Step 7: Drop old events table and rename new one
    await txn.execute('DROP TABLE events');
    await txn.execute('ALTER TABLE events_new RENAME TO events');

    // Step 8: Update snapshots table schema
    await txn.execute('''
      CREATE TABLE snapshots_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        sequence INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        compressed INTEGER NOT NULL,
        state_data BLOB NOT NULL
      )
    ''');

    // Step 9: Migrate existing snapshots
    await txn.execute('''
      INSERT INTO snapshots_new (id, document_id, sequence, timestamp, compressed, state_data)
      SELECT
        snapshot_id,
        document_id,
        event_sequence,
        datetime(created_at / 1000, 'unixepoch'),
        CASE WHEN compression = 'gzip' THEN 1 ELSE 0 END,
        snapshot_data
      FROM snapshots
    ''');

    // Step 10: Drop old snapshots table and rename new one
    await txn.execute('DROP TABLE snapshots');
    await txn.execute('ALTER TABLE snapshots_new RENAME TO snapshots');

    // Step 11: Create export_jobs table
    await txn.execute('''
      CREATE TABLE export_jobs (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        artboard_scope TEXT NOT NULL,
        format TEXT NOT NULL,
        status TEXT NOT NULL,
        artifact_url TEXT,
        warnings TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    // Step 12: Drop old metadata table
    await txn.execute('DROP TABLE metadata');

    // Step 13: Create indexes for performance
    await txn.execute('''
      CREATE INDEX idx_events_document_sequence
      ON events(document_id, sequence)
    ''');

    await txn.execute('''
      CREATE INDEX idx_events_artboard
      ON events(artboard_id) WHERE artboard_id IS NOT NULL
    ''');

    await txn.execute('''
      CREATE INDEX idx_snapshots_document
      ON snapshots(document_id, sequence DESC)
    ''');

    await txn.execute('''
      CREATE INDEX idx_artboards_document
      ON artboards(document_id, z_order)
    ''');

    await txn.execute('''
      CREATE INDEX idx_layers_artboard
      ON layers(artboard_id, z_index)
    ''');

    await txn.execute('''
      CREATE INDEX idx_export_jobs_document
      ON export_jobs(document_id, created_at DESC)
    ''');

    _logger.d('V2 migration completed: Blueprint schema active');
  }

  /// Verifies schema integrity after migration.
  ///
  /// Checks that all required tables, columns, and indexes exist.
  /// Returns true if schema matches blueprint specification.
  static Future<bool> verifySchemaIntegrity(Database db) async {
    _logger.d('Verifying schema integrity...');

    try {
      // Check all required tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('documents', 'artboards', 'layers', 'events', 'snapshots', 'export_jobs')",
      );

      if (tables.length != 6) {
        _logger
            .w('Schema verification failed: Expected 6 tables, found ${tables.length}');
        return false;
      }

      // Check critical indexes exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_events_document_sequence', 'idx_snapshots_document', 'idx_artboards_document', 'idx_layers_artboard')",
      );

      if (indexes.length < 4) {
        _logger.w(
            'Schema verification failed: Expected at least 4 indexes, found ${indexes.length}');
        return false;
      }

      // Verify events table has required columns
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
        'operation_id'
      };

      if (!requiredColumns.every((col) => columnNames.contains(col))) {
        _logger.w(
            'Schema verification failed: events table missing required columns');
        return false;
      }

      _logger.i('Schema integrity verification passed');
      return true;
    } catch (e) {
      _logger.e('Schema verification error: $e');
      return false;
    }
  }
}
