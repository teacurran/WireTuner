-- WireTuner Event Sourcing Schema v1
--
-- This schema implements the data model defined in:
-- docs/reference/03_System_Structure_and_Data.md Section 3.6
--
-- Design Rationale:
-- - Append-only `events` table ensures immutability and supports efficient replay
-- - Periodic `snapshots` table reduces replay time (1000 events = ~50ms vs ~1min)
-- - `metadata` table stores document-level info separate from event stream
-- - ACID guarantees via SQLite transactions prevent partial writes during crashes
-- - Foreign key constraints enforce referential integrity
-- - WAL mode provides crash resistance and concurrent read performance

-- ============================================================================
-- PRAGMA Configuration
-- ============================================================================

-- Enable Write-Ahead Logging for crash resistance and concurrent reads
PRAGMA journal_mode=WAL;

-- Enable foreign key constraint enforcement (disabled by default in SQLite)
PRAGMA foreign_keys=ON;

-- ============================================================================
-- Table: metadata
-- ============================================================================
-- Stores one row per document with document-level properties
CREATE TABLE metadata (
  document_id TEXT PRIMARY KEY,      -- Unique identifier for the document
  title TEXT NOT NULL,               -- Display name for the document
  format_version INTEGER NOT NULL,   -- Schema version for future compatibility
  created_at INTEGER NOT NULL,       -- Unix timestamp (seconds) of creation
  modified_at INTEGER NOT NULL,      -- Unix timestamp (seconds) of last modification
  author TEXT                        -- Optional author name
);

-- ============================================================================
-- Table: events
-- ============================================================================
-- Append-only event log for event sourcing architecture
-- Each row represents a single user interaction captured at 50ms sampling rate
CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-incrementing unique ID
  document_id TEXT NOT NULL,                   -- Foreign key to metadata table
  event_sequence INTEGER NOT NULL,             -- 0-based sequence number (unique per document)
  event_type TEXT NOT NULL,                    -- Event discriminator (e.g., "CreatePath", "MoveAnchor")
  event_payload TEXT NOT NULL,                 -- JSON-serialized event data
  timestamp INTEGER NOT NULL,                  -- Unix timestamp in milliseconds
  user_id TEXT,                                -- For future collaboration features

  -- Constraints
  FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE,
  UNIQUE(document_id, event_sequence)  -- Prevent duplicate sequence numbers within a document
);

-- ============================================================================
-- Table: snapshots
-- ============================================================================
-- Periodic document state captures for fast loading without full event replay
-- Snapshots are created every 1000 events as per architecture decision
CREATE TABLE snapshots (
  snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-incrementing unique ID
  document_id TEXT NOT NULL,                      -- Foreign key to metadata table
  event_sequence INTEGER NOT NULL,                -- Snapshot taken after this event sequence
  snapshot_data BLOB NOT NULL,                    -- Serialized Document object
  created_at INTEGER NOT NULL,                    -- Unix timestamp of snapshot creation
  compression TEXT NOT NULL,                      -- Compression method ("gzip", "none", etc.)

  -- Constraints
  FOREIGN KEY (document_id) REFERENCES metadata(document_id) ON DELETE CASCADE
);

-- ============================================================================
-- Performance Indexes
-- ============================================================================

-- Critical index for event replay queries: "SELECT all events for document X in sequence order"
-- Composite index on (document_id, event_sequence) enables efficient range scans
CREATE INDEX idx_events_document_sequence
ON events(document_id, event_sequence);

-- Index for snapshot lookup: find most recent snapshot before a given sequence number
-- DESC ordering on event_sequence enables efficient "latest snapshot" queries
CREATE INDEX idx_snapshots_document
ON snapshots(document_id, event_sequence DESC);
