# io_services

SQLite persistence gateway for WireTuner event sourcing architecture.

## Overview

This package provides the database infrastructure layer for WireTuner's event sourcing implementation, including:

- **Connection Factory**: Manages SQLite database connections with pooling support for multi-document/multi-window scenarios
- **Database Configuration**: Flexible configuration for file-based and in-memory databases
- **Migration Runner**: Schema migration system with SQL script support
- **Event Gateway**: Concrete implementation of the `EventStoreGateway` interface from `event_core`

## Architecture

The package implements the persistence layer defined in the WireTuner architecture blueprint (Section 3.6 - Data Model):

```
┌─────────────────────────────────────────────────────────┐
│                    event_core                            │
│              (EventStoreGateway interface)               │
└─────────────────────┬───────────────────────────────────┘
                      │ implements
┌─────────────────────▼───────────────────────────────────┐
│                   io_services                            │
│                                                           │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │ ConnectionFactory│  │   SqliteEventGateway         │ │
│  │  - FFI init      │  │   - persistEvent()           │ │
│  │  - Path resolve  │  │   - persistEventBatch()      │ │
│  │  - Pool mgmt     │  │   - getEvents()              │ │
│  └──────────────────┘  │   - getLatestSequenceNumber()│ │
│                        │   - pruneEventsBeforeSeq()   │ │
│  ┌──────────────────┐  └──────────────────────────────┘ │
│  │ MigrationRunner  │                                    │
│  │  - base_schema   │                                    │
│  │  - version mgmt  │                                    │
│  └──────────────────┘                                    │
└───────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│            sqflite_common_ffi (SQLite)                   │
│    .wiretuner files (metadata, events, snapshots)       │
└─────────────────────────────────────────────────────────┘
```

## Schema

The SQLite schema consists of three core tables:

### metadata
Document-level properties (title, version, timestamps)

### events
Append-only event log with:
- `document_id`: Foreign key to metadata
- `event_sequence`: 0-based monotonic sequence (unique per document)
- `event_type`: Event discriminator (e.g., "CreatePath", "MoveAnchor")
- `event_payload`: JSON-serialized event data
- `timestamp`: Unix milliseconds

### snapshots
Periodic document state captures (every 1000 events):
- `document_id`: Foreign key to metadata
- `event_sequence`: Snapshot taken after this event
- `snapshot_data`: BLOB (compressed serialized document)
- `compression`: Compression method ("gzip", "none")

**Key Features:**
- WAL mode for crash resistance
- Foreign key constraints for referential integrity
- Composite indexes for efficient event replay
- CASCADE delete for cleanup

See [base_schema.sql](lib/src/migrations/base_schema.sql) for the complete DDL with detailed comments.

## Usage

### 1. Initialize the Connection Factory

```dart
import 'package:io_services/io_services.dart';

final factory = ConnectionFactory();
await factory.initialize(); // Initializes SQLite FFI for desktop
```

### 2. Open a Database Connection

**File-based database:**
```dart
final db = await factory.openConnection(
  documentId: 'doc-123',
  config: DatabaseConfig.file(filePath: 'my_document.wiretuner'),
);
```

**In-memory database (for tests):**
```dart
final db = await factory.openConnection(
  documentId: 'test-doc',
  config: DatabaseConfig.inMemory(),
);
```

### 3. Create an Event Gateway

```dart
final gateway = SqliteEventGateway(
  db: db,
  documentId: 'doc-123',
);
```

### 4. Persist Events

**Single event:**
```dart
await gateway.persistEvent({
  'eventId': uuid.v4(),
  'eventType': 'CreatePath',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'sequenceNumber': 0,
  'pathId': 'path-1',
  // ... other event-specific fields
});
```

**Batch events (atomic transaction):**
```dart
await gateway.persistEventBatch([
  {'eventType': 'Event1', 'sequenceNumber': 0, ...},
  {'eventType': 'Event2', 'sequenceNumber': 1, ...},
  {'eventType': 'Event3', 'sequenceNumber': 2, ...},
]);
```

### 5. Retrieve Events

```dart
// Get all events from sequence 0 onwards
final events = await gateway.getEvents(fromSequence: 0);

// Get events in a range
final recentEvents = await gateway.getEvents(
  fromSequence: 100,
  toSequence: 200,
);
```

### 6. Connection Management

```dart
// Close specific connection
await factory.closeConnection('doc-123');

// Close all connections (e.g., on app shutdown)
await factory.closeAll();
```

## Multi-Document Support

The `ConnectionFactory` maintains a connection pool keyed by `documentId`, enabling multiple documents/windows to have independent database handles:

```dart
// Window 1: Open document A
final dbA = await factory.openConnection(
  documentId: 'doc-a',
  config: DatabaseConfig.file(filePath: 'doc_a.wiretuner'),
);

// Window 2: Open document B
final dbB = await factory.openConnection(
  documentId: 'doc-b',
  config: DatabaseConfig.file(filePath: 'doc_b.wiretuner'),
);

// Both connections are independent and pooled
assert(factory.activeConnectionCount == 2);
```

## Error Handling

The package provides actionable error messages for common failure scenarios:

**Permission errors:**
```
Failed to open database for document "doc-123": Permission denied.
Ensure the application has write permissions to the database directory.
Path: /Users/...
```

**Missing metadata (foreign key violation):**
```
Document "doc-123" does not exist in the metadata table.
Ensure the document is created before persisting events.
```

**Duplicate sequence number:**
```
Event sequence 42 already exists for document "doc-123".
This indicates a concurrency issue or duplicate event submission.
```

## Testing

The package includes comprehensive tests validating:
- Schema creation and migration
- WAL mode and foreign key constraints
- Connection pooling and isolation
- File-based and in-memory database modes
- Event persistence and retrieval
- Error handling and edge cases

Run tests:
```bash
cd packages/io_services
flutter test
```

## SQL Migration System

The migration system is extensible for future schema changes:

**Current version:** 1 (base_schema.sql)

**Adding a new migration:**
1. Create `lib/src/migrations/v2_migration.sql`
2. Update `MigrationRunner.currentVersion` to 2
3. Add case to `_applyMigration()`:
   ```dart
   case 2:
     await _applyV2Migration();
     break;
   ```

The migration runner automatically detects the database version and applies pending migrations in sequence.

## Integration with event_core

This package implements the `EventStoreGateway` interface defined in `event_core`, providing the concrete persistence layer for the event pipeline:

```
EventRecorder (event_core)
    └─> EventStoreGateway (interface)
            └─> SqliteEventGateway (io_services) ← implements
                    └─> SQLite Database
```

See the `event_core` package for the complete event sourcing pipeline.

## Platform Support

- **macOS**: Fully supported (tested on macOS 14+)
- **Windows**: Fully supported (tested on Windows 10+)
- **Linux**: Should work (requires sqflite_common_ffi support)

Database files are stored in platform-specific locations:
- macOS: `~/Library/Application Support/WireTuner/`
- Windows: `%APPDATA%\WireTuner\`

## References

- Architecture Blueprint: `docs/reference/03_System_Structure_and_Data.md`
- ADR: Event Sourcing Architecture: `docs/reference/06_Rationale_and_Future.md` (Decision 1)
- Base Schema SQL: `lib/src/migrations/base_schema.sql`
- EventStoreGateway Interface: `packages/event_core/lib/src/event_store_gateway.dart`
