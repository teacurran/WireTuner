/// Base schema DDL for WireTuner event sourcing (version 1).
///
/// This schema implements the data model defined in:
/// docs/reference/03_System_Structure_and_Data.md Section 3.6
///
/// See also: base_schema.sql (documented SQL version)
library;

/// SQL statements for creating the base schema.
///
/// Includes:
/// - metadata table
/// - events table (append-only log)
/// - snapshots table
/// - Performance indexes
///
/// Note: PRAGMA statements (WAL mode, foreign keys) are handled by
/// ConnectionFactory.onOpen() and should not be included here to avoid
/// conflicts with the database factory configuration.
const List<String> baseSchemaStatements = [
  // metadata table: Document-level properties
  '''
  CREATE TABLE metadata (
    document_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    format_version INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    author TEXT
  )
  ''',

  // events table: Append-only event log
  '''
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
  ''',

  // snapshots table: Periodic document state captures
  '''
  CREATE TABLE snapshots (
    snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL,
    event_sequence INTEGER NOT NULL,
    snapshot_data BLOB NOT NULL,
    created_at INTEGER NOT NULL,
    compression TEXT NOT NULL,
    FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE
  )
  ''',

  // Index for event replay queries
  '''
  CREATE INDEX idx_events_document_sequence
  ON events(document_id, event_sequence)
  ''',

  // Index for snapshot lookup
  '''
  CREATE INDEX idx_snapshots_document
  ON snapshots(document_id, event_sequence DESC)
  ''',
];
