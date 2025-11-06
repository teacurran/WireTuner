# Task Briefing Package

This package contains all necessary information and strategic guidance for the Coder Agent.

---

## 1. Current Task Details

This is the full specification of the task you must complete.

```json
{
  "task_id": "I1.T5",
  "iteration_id": "I1",
  "iteration_goal": "Establish project infrastructure, initialize Flutter project, integrate SQLite, and document event sourcing architecture",
  "description": "Create SQLite schema for event sourcing: define `metadata`, `events`, and `snapshots` tables as specified in architecture blueprint Section 3.6 (Data Model ERD). Implement SQL DDL in `lib/infrastructure/persistence/schema.dart`. Add migration logic to DatabaseProvider to create tables on first run. Write unit tests to verify schema creation.",
  "agent_type_hint": "DatabaseAgent",
  "inputs": "Architecture blueprint Section 3.6 (Data Model ERD - SQLite Tables), Ticket T002 (SQLite Integration)",
  "target_files": [
    "lib/infrastructure/persistence/schema.dart",
    "lib/infrastructure/persistence/database_provider.dart",
    "test/infrastructure/persistence/schema_test.dart"
  ],
  "input_files": [
    "lib/infrastructure/persistence/database_provider.dart"
  ],
  "deliverables": "SQL DDL for metadata, events, snapshots tables, Migration logic executed on database initialization, Indexes on (document_id, event_sequence) for events table, Unit tests confirming tables created with correct schema",
  "acceptance_criteria": "`flutter test test/infrastructure/persistence/schema_test.dart` passes, Database schema matches ERD in architecture blueprint, Indexes created for efficient event replay queries, PRAGMA journal_mode=WAL enabled for crash resistance, Schema version tracking for future migrations",
  "dependencies": ["I1.T4"],
  "parallelizable": false,
  "done": false
}
```

---

## 2. Architectural & Planning Context

The following are the relevant sections from the architecture and plan documents, which I found by analyzing the task description.

### Context: data-model-erd (from 03_System_Structure_and_Data.md)

```markdown
<!-- anchor: data-model-erd -->
#### Diagram (PlantUML - ERD)

~~~plantuml
@startuml

title Entity-Relationship Diagram - WireTuner Persistent Data

' SQLite Tables
entity metadata {
  *document_id : TEXT <<PK>>
  --
  title : TEXT
  format_version : INTEGER
  created_at : INTEGER (Unix timestamp)
  modified_at : INTEGER (Unix timestamp)
  author : TEXT (optional)
}

entity events {
  *event_id : INTEGER <<PK, AUTOINCREMENT>>
  --
  document_id : TEXT <<FK>>
  event_sequence : INTEGER (0-based, unique per document)
  event_type : TEXT (e.g., "CreatePath", "MoveAnchor")
  event_payload : TEXT (JSON serialized)
  timestamp : INTEGER (Unix timestamp milliseconds)
  user_id : TEXT (future: for collaboration)
}

entity snapshots {
  *snapshot_id : INTEGER <<PK, AUTOINCREMENT>>
  --
  document_id : TEXT <<FK>>
  event_sequence : INTEGER (snapshot taken after this event)
  snapshot_data : BLOB (serialized Document)
  created_at : INTEGER (Unix timestamp)
  compression : TEXT (e.g., "gzip", "none")
}

' Relationships
metadata ||--o{ events : "contains"
metadata ||--o{ snapshots : "has"

' Notes
note right of events
  Append-only log.
  Indexed on (document_id, event_sequence)
  for efficient replay.
  Typical size: ~100-500 bytes per event.
end note

note right of snapshots
  Created every 1000 events.
  BLOB size: ~10KB-1MB depending on complexity.
  Enables fast document loading without
  replaying entire event history.
end note

@enduml
~~~
```

### Context: nfr-reliability (from 01_Context_and_Drivers.md)

```markdown
<!-- anchor: nfr-reliability -->
#### Reliability
- **Target**: Zero data loss, corruption-resistant file format
- **Rationale**: Professional work cannot be lost due to crashes
- **Impact**: Event sourcing provides natural audit trail, SQLite ACID guarantees
- **Measurement**: Crash recovery testing, file corruption resistance tests
```

### Context: stack-persistence (from 02_Architecture_Overview.md)

```markdown
<!-- anchor: stack-persistence -->
#### Data & Persistence

| Component | Technology | Package/Library | Justification |
|-----------|-----------|-----------------|---------------|
| **Event Store** | SQLite | `sqflite_common_ffi` | Embedded database, ACID compliance, zero-config, portable files |
| **Schema** | SQL DDL | - | Direct SQL for event log, snapshot, document tables |
| **File Format** | .wiretuner (SQLite) | - | Self-contained file format, readable with standard SQLite tools |
```

### Context: constraint-technology (from 01_Context_and_Drivers.md)

```markdown
<!-- anchor: constraint-technology -->
#### Technology Constraints
- **Flutter Framework**: Required for cross-platform desktop development
  - **Justification**: Enables single codebase for macOS/Windows, mature CustomPainter API
  - **Trade-off**: Larger binary size vs. native development, but acceptable for desktop

- **SQLite Database**: Required for event log and snapshot storage
  - **Justification**: Embedded, zero-configuration, ACID-compliant, portable file format
  - **Trade-off**: Not suitable for concurrent access, but single-user focus makes this acceptable

- **Dart Language**: Mandated by Flutter framework
  - **Justification**: Strong typing, null safety, good performance for UI applications
  - **Trade-off**: Smaller ecosystem than JavaScript/Python, but adequate for desktop apps
```

### Context: reliability-data-integrity (from 05_Operational_Architecture.md)

```markdown
<!-- anchor: reliability-data-integrity -->
##### Data Integrity

**Event Log Integrity:**
- **Checksums**: SQLite's internal page checksums detect corruption
- **Validation**: On document load, verify event sequence numbers are contiguous
- **Error Handling**: If gap detected, warn user and skip to next valid event

**Snapshot Integrity:**
- **Versioning**: Each snapshot tagged with format version
- **Validation**: Deserialize snapshot, check for null fields, validate object IDs

**Export Integrity:**
- **SVG Validation**: Validate generated SVG against SVG 1.1 schema before writing
- **PDF Validation**: Check PDF structure integrity (valid xref table, trailer)
```

---

## 3. Codebase Analysis & Strategic Guidance

The following analysis is based on my direct review of the current codebase. Use these notes and tips to guide your implementation.

### Relevant Existing Code

*   **File:** `lib/infrastructure/persistence/database_provider.dart`
    *   **Summary:** This file implements the complete database connection lifecycle management. It includes initialization of SQLite FFI, opening/closing database connections, path resolution for platform-specific directories (macOS: `~/Library/Application Support/WireTuner/`, Windows: `%APPDATA%\WireTuner\`), and placeholder callbacks for schema creation (`_onCreate`) and migrations (`_onUpgrade`).
    *   **Current State:** The `_onCreate` method at line 188 currently has a comment stating "Schema creation will be implemented in task I1.T5" - **this is YOUR task**.
    *   **Recommendation:** You MUST modify the `_onCreate` method in `database_provider.dart` to invoke your schema creation logic. You SHOULD import your new `schema.dart` file and call a function like `createSchema(db)` from within `_onCreate`.
    *   **Critical Detail:** The `DatabaseProvider` already handles versioning via `currentSchemaVersion = 1` (line 31) and passes this to SQLite's `openDatabase` function with `onCreate` and `onUpgrade` callbacks. Your schema creation will automatically be triggered on first database creation.

*   **File:** `pubspec.yaml`
    *   **Summary:** This is the Flutter project configuration file. All required dependencies are already installed: `sqflite_common_ffi: ^2.3.0`, `path_provider: ^2.1.0`, `path: ^1.9.0`, and `logger: ^2.0.0`.
    *   **Recommendation:** You do NOT need to add any new dependencies. All SQLite functionality is available through the already-installed `sqflite_common_ffi` package.

### Implementation Tips & Notes

*   **Tip: WAL Mode for Crash Resistance:** The acceptance criteria explicitly requires `PRAGMA journal_mode=WAL`. WAL (Write-Ahead Logging) provides better crash resistance and concurrent read performance. You MUST execute this pragma during schema creation. Add it as: `await db.execute('PRAGMA journal_mode=WAL;');`

*   **Tip: Index Creation is Critical:** The architecture blueprint emphasizes that the `events` table must have a composite index on `(document_id, event_sequence)` for efficient event replay. The typical query pattern is: "SELECT all events for document X in sequence order". Create this index in your schema: `CREATE INDEX idx_events_document_sequence ON events(document_id, event_sequence);`

*   **Tip: Foreign Key Constraints:** While the ERD shows foreign key relationships between `metadata.document_id` and `events.document_id`/`snapshots.document_id`, SQLite foreign key enforcement is OFF by default. You SHOULD enable it with `PRAGMA foreign_keys=ON;` to maintain referential integrity during development. However, be aware this is a per-connection setting and may need to be enabled each time the database opens.

*   **Tip: Event Sequence Uniqueness:** The `event_sequence` column is described as "0-based, unique per document". You SHOULD enforce this uniqueness with a composite UNIQUE constraint: `UNIQUE(document_id, event_sequence)`. This prevents duplicate sequence numbers for the same document.

*   **Note: Schema Organization:** I recommend creating a `SchemaManager` class in your new `schema.dart` file with static methods like `createSchema(Database db)`, `createMetadataTable(Database db)`, `createEventsTable(Database db)`, and `createSnapshotsTable(Database db)`. This keeps the code modular and testable.

*   **Note: Logging Strategy:** The existing `DatabaseProvider` uses the `Logger` package extensively (see line 40: `final Logger _logger = Logger();`). You SHOULD follow this pattern in your schema creation code. Log when tables are created, when indexes are built, and when pragmas are set. This will aid debugging and provide visibility during development.

*   **Note: Test Structure:** The existing test file `test/infrastructure/persistence/database_provider_test.dart` provides a good pattern for your schema tests. You SHOULD use in-memory databases for testing (pass `:memory:` as the database path or use `inMemoryDatabasePath` constant if available in sqflite). This makes tests fast and isolated.

*   **Warning: Asynchronous Execution Required:** All database operations in the sqflite package are asynchronous. You MUST use `await` for every `db.execute()` call. The `_onCreate` callback signature is already `Future<void>`, so you can use async/await freely.

*   **Warning: SQL Injection Not a Concern Here:** Since you're writing DDL (Data Definition Language) statements with no user input, SQL injection is not a risk for this task. However, be aware that future tasks involving DML (Data Manipulation Language) with event payloads MUST use parameterized queries.

### Acceptance Criteria Checklist

To ensure you meet all requirements, verify:

1. ✅ **Three tables created:** `metadata`, `events`, `snapshots` with exact column names and types from ERD
2. ✅ **Primary keys defined:** `metadata.document_id` (TEXT), `events.event_id` (INTEGER AUTOINCREMENT), `snapshots.snapshot_id` (INTEGER AUTOINCREMENT)
3. ✅ **Foreign key references:** `events.document_id → metadata.document_id`, `snapshots.document_id → metadata.document_id`
4. ✅ **Index on events table:** `CREATE INDEX idx_events_document_sequence ON events(document_id, event_sequence);`
5. ✅ **WAL mode enabled:** `PRAGMA journal_mode=WAL;`
6. ✅ **Foreign keys enabled (optional but recommended):** `PRAGMA foreign_keys=ON;`
7. ✅ **Schema version tracking:** Already handled by `DatabaseProvider.currentSchemaVersion = 1`
8. ✅ **Unit tests pass:** Tests MUST verify all tables exist, have correct columns, correct data types, and indexes are created
9. ✅ **Integration with DatabaseProvider:** The `_onCreate` method MUST call your schema creation code

### Example Code Structure (DO NOT COPY VERBATIM - USE AS GUIDANCE)

```dart
// lib/infrastructure/persistence/schema.dart
class SchemaManager {
  static Future<void> createSchema(Database db) async {
    // Enable pragmas
    // Create tables
    // Create indexes
    // Log completion
  }
}

// In database_provider.dart, modify _onCreate:
Future<void> _onCreate(Database db, int version) async {
  _logger.i('Database created with version $version');
  await SchemaManager.createSchema(db);
  _logger.i('Schema creation completed successfully');
}
```

---

## Final Recommendations

1. **Start by creating `lib/infrastructure/persistence/schema.dart`** with the `SchemaManager` class containing all DDL statements.

2. **Modify `database_provider.dart`'s `_onCreate` method** to call `SchemaManager.createSchema(db)`.

3. **Write comprehensive unit tests in `test/infrastructure/persistence/schema_test.dart`** that:
   - Create an in-memory database
   - Call the schema creation
   - Query `sqlite_master` table to verify tables and indexes exist
   - Verify column types and constraints using `PRAGMA table_info(table_name);`

4. **Run `flutter test test/infrastructure/persistence/schema_test.dart`** to verify everything works.

5. **Run `flutter analyze`** to ensure no linting errors.

Good luck! This is a critical foundation task for the entire event sourcing architecture.
