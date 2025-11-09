import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Manages SQLite schema creation and migrations for WireTuner event sourcing.
///
/// This class implements the data model defined in the architecture blueprint
/// Section 3.6 (Data Model ERD), providing three core tables:
/// - metadata: Document-level information
/// - events: Append-only event log for event sourcing
/// - snapshots: Periodic snapshots for fast document loading
class SchemaManager {
  static final Logger _logger = Logger();

  /// Creates the complete database schema for WireTuner.
  ///
  /// This method:
  /// 1. Enables WAL mode for crash resistance
  /// 2. Enables foreign key constraints for referential integrity
  /// 3. Creates the metadata, events, and snapshots tables
  /// 4. Creates indexes for efficient event replay queries
  ///
  /// [db] The database instance to create the schema in.
  static Future<void> createSchema(Database db) async {
    _logger.i('Starting schema creation...');

    // Enable WAL mode for crash resistance and better concurrent read performance
    await _enableWALMode(db);

    // Enable foreign key constraints for referential integrity
    await _enableForeignKeys(db);

    // Create tables in dependency order
    await _createMetadataTable(db);
    await _createEventsTable(db);
    await _createSnapshotsTable(db);

    // Create indexes for performance
    await _createIndexes(db);

    _logger.i('Schema creation completed successfully');
  }

  /// Enables Write-Ahead Logging (WAL) mode for crash resistance.
  ///
  /// WAL mode provides:
  /// - Better crash resistance
  /// - Improved concurrent read performance
  /// - Reduced chance of database corruption
  static Future<void> _enableWALMode(Database db) async {
    _logger.d('Enabling WAL mode...');
    await db.execute('PRAGMA journal_mode=WAL;');
    _logger.d('WAL mode enabled');
  }

  /// Enables foreign key constraint enforcement.
  ///
  /// Foreign keys are disabled by default in SQLite. Enabling them ensures
  /// referential integrity between metadata, events, and snapshots tables.
  static Future<void> _enableForeignKeys(Database db) async {
    _logger.d('Enabling foreign key constraints...');
    await db.execute('PRAGMA foreign_keys=ON;');
    _logger.d('Foreign key constraints enabled');
  }

  /// Creates the metadata table for document-level information.
  ///
  /// The metadata table stores one row per document, containing:
  /// - document_id: Unique identifier (PRIMARY KEY)
  /// - title: Document title
  /// - format_version: Schema version for future compatibility
  /// - created_at: Unix timestamp of creation
  /// - modified_at: Unix timestamp of last modification
  /// - author: Optional author name
  static Future<void> _createMetadataTable(Database db) async {
    _logger.d('Creating metadata table...');
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
    _logger.d('Metadata table created');
  }

  /// Creates the events table for the append-only event log.
  ///
  /// The events table is the core of the event sourcing architecture:
  /// - event_id: Auto-incrementing primary key
  /// - document_id: Foreign key to metadata table
  /// - event_sequence: 0-based sequence number unique per document
  /// - event_type: Type of event (e.g., "CreatePath", "MoveAnchor")
  /// - event_payload: JSON-serialized event data
  /// - timestamp: Unix timestamp in milliseconds
  /// - user_id: For future collaboration features
  ///
  /// The UNIQUE constraint on (document_id, event_sequence) ensures
  /// no duplicate sequence numbers within a document.
  static Future<void> _createEventsTable(Database db) async {
    _logger.d('Creating events table...');
    await db.execute('''
      CREATE TABLE events (
        event_id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT NOT NULL,
        event_sequence INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        event_payload TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        user_id TEXT,
        FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
        UNIQUE(document_id, event_sequence)
      )
    ''');
    _logger.d('Events table created');
  }

  /// Creates the snapshots table for periodic document state captures.
  ///
  /// Snapshots enable fast document loading without replaying the entire
  /// event history. Created every 1000 events as per architecture blueprint.
  ///
  /// - snapshot_id: Auto-incrementing primary key
  /// - document_id: Foreign key to metadata table
  /// - event_sequence: Snapshot taken after this event sequence number
  /// - snapshot_data: BLOB containing serialized Document object
  /// - created_at: Unix timestamp of snapshot creation
  /// - compression: Compression method ("gzip", "none", etc.)
  static Future<void> _createSnapshotsTable(Database db) async {
    _logger.d('Creating snapshots table...');
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
    _logger.d('Snapshots table created');
  }

  /// Creates performance indexes for efficient queries.
  ///
  /// The composite index on (document_id, event_sequence) in the events table
  /// is critical for fast event replay, which is the most common query pattern:
  /// "SELECT all events for document X in sequence order"
  static Future<void> _createIndexes(Database db) async {
    _logger.d('Creating indexes...');

    // Critical index for event replay queries
    await db.execute('''
      CREATE INDEX idx_events_document_sequence
      ON events(document_id, event_sequence)
    ''');
    _logger.d('Index idx_events_document_sequence created');

    // Index for snapshot lookup by document
    await db.execute('''
      CREATE INDEX idx_snapshots_document
      ON snapshots(document_id, event_sequence DESC)
    ''');
    _logger.d('Index idx_snapshots_document created');

    _logger.d('All indexes created successfully');
  }

  /// Verifies schema integrity by checking table and index existence.
  ///
  /// This method can be used in tests or during application startup to
  /// ensure the schema is correctly created.
  ///
  /// Returns true if all required tables and indexes exist, false otherwise.
  static Future<bool> verifySchema(Database db) async {
    _logger.d('Verifying schema integrity...');

    try {
      // Check tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
      );

      if (tables.length != 3) {
        _logger.w(
            'Schema verification failed: Expected 3 tables, found ${tables.length}');
        return false;
      }

      // Check indexes exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_events_document_sequence', 'idx_snapshots_document')",
      );

      if (indexes.length != 2) {
        _logger.w(
            'Schema verification failed: Expected 2 indexes, found ${indexes.length}');
        return false;
      }

      _logger.i('Schema verification passed');
      return true;
    } catch (e) {
      _logger.e('Schema verification error: $e');
      return false;
    }
  }
}
