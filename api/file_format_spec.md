# WireTuner File Format Specification

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Document Type:** Normative Specification

---

<!-- anchor: file-format-spec -->
## Document Information

**Audience:** WireTuner implementers, integration partners, plugin developers
**Purpose:** Defines the authoritative `.wiretuner` file format specification including SQLite schema, binary snapshot format, semantic versioning rules, compatibility guarantees, and migration strategies.
**Related Documents:**
- [File Versioning Notes](../docs/reference/file_versioning_notes.md) - Comprehensive reference material
- [Data Snapshot ERD](../docs/diagrams/data_snapshot_erd.mmd) - Entity-relationship diagram
- [Architecture Decision 3](../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite) - SQLite rationale

**RFC 2119 Compliance:** This specification uses the key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" as defined in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## Table of Contents

1. [Overview](#overview)
2. [File Format Container](#file-format-container)
3. [SQLite Schema Specification](#sqlite-schema-specification)
4. [Snapshot Binary Format](#snapshot-binary-format)
5. [Semantic Versioning](#semantic-versioning)
6. [Compatibility Matrix](#compatibility-matrix)
7. [Migration Strategies](#migration-strategies)
8. [Downgrade Workflows](#downgrade-workflows)
9. [Verification & Validation](#verification-validation)
10. [Appendices](#appendices)

---

<!-- anchor: overview -->
## 1. Overview

### 1.1. Scope

This document specifies the `.wiretuner` file format used by WireTuner to persist vector documents. The format is based on SQLite and uses event sourcing principles to enable:

- Infinite undo/redo via event history navigation
- Crash-resistant ACID-compliant persistence
- Complete workflow reconstruction and audit trails
- Forward compatibility through automatic migration
- Corruption detection via CRC32 checksums

### 1.2. Design Principles

The `.wiretuner` file format adheres to the following principles:

1. **Graceful Degradation**: Older applications MUST detect (but need not open) newer file formats
2. **Forward Compatibility**: Newer applications MUST open older file formats via automatic migration
3. **Corruption Detection**: All snapshot data MUST be protected by CRC32 checksums
4. **Version Transparency**: File format version MUST be visible in both `metadata.format_version` and snapshot headers
5. **Self-Contained**: `.wiretuner` files MUST be standard SQLite databases readable by any SQLite 3.x tool
6. **Portable**: Files MUST be platform-independent (macOS, Windows, Linux)

### 1.3. Normative vs. Informative

- **Normative sections** (containing MUST/REQUIRED/SHALL) define contractual requirements for conforming implementations
- **Informative sections** (containing examples, rationale, recommendations) provide guidance but are not mandatory

---

<!-- anchor: file-format-container -->
## 2. File Format Container

### 2.1. File Extension

`.wiretuner` files MUST use the `.wiretuner` file extension.

### 2.2. Container Format

`.wiretuner` files MUST be valid SQLite 3.x database files.

**Rationale (Informative):** SQLite provides:
- **ACID guarantees**: Ensures event log integrity during crashes
- **Embedded**: No separate database server required
- **Portable**: Cross-platform compatibility
- **Tool Support**: Readable with standard SQLite tools (`sqlite3`, DB Browser, etc.)

### 2.3. SQLite Version Requirements

Implementations MUST support SQLite 3.7.0 or later (released 2010-07-21).

**Recommended:** SQLite 3.35.0+ for improved Write-Ahead Logging (WAL) performance.

### 2.4. SQLite Pragmas

Implementations SHOULD use the following SQLite pragmas for optimal performance and safety:

```sql
PRAGMA journal_mode = WAL;           -- Write-Ahead Logging for crash safety
PRAGMA synchronous = NORMAL;         -- Balance performance and durability
PRAGMA foreign_keys = ON;            -- Enforce referential integrity
PRAGMA busy_timeout = 5000;          -- 5-second timeout for lock contention
```

---

<!-- anchor: sqlite-schema-specification -->
## 3. SQLite Schema Specification

### 3.1. Schema Overview

The `.wiretuner` file format contains three core tables:

1. **`metadata`**: Document-level information and format version
2. **`events`**: Append-only event log capturing all user actions
3. **`snapshots`**: Periodic serialized document states for fast loading

**Entity-Relationship Diagram (Informative):** See [data_snapshot_erd.mmd](../docs/diagrams/data_snapshot_erd.mmd)

### 3.2. `metadata` Table

The `metadata` table MUST contain exactly one row per document.

#### 3.2.1. Schema Definition

```sql
CREATE TABLE metadata (
  document_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  format_version INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  author TEXT
);
```

#### 3.2.2. Field Specifications

| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| `document_id` | TEXT | PRIMARY KEY, NOT NULL | Unique document identifier (MUST be UUIDv4 format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`) |
| `title` | TEXT | NOT NULL | Human-readable document title (max 255 characters RECOMMENDED) |
| `format_version` | INTEGER | NOT NULL | Schema version number (current: `1`). MUST be checked before opening document. |
| `created_at` | INTEGER | NOT NULL | Unix timestamp in **seconds** (UTC) when document was created |
| `modified_at` | INTEGER | NOT NULL | Unix timestamp in **seconds** (UTC) of last modification |
| `author` | TEXT | OPTIONAL | Author name or identifier (reserved for future collaboration features) |

#### 3.2.3. Version Detection

Implementations MUST read `metadata.format_version` before attempting to open a document:

- If `format_version > current_implementation_version`: Refuse to open, display upgrade warning
- If `format_version < current_implementation_version`: Trigger automatic migration (see §7)
- If `format_version == current_implementation_version`: Open normally

### 3.3. `events` Table

The `events` table MUST be append-only (no updates or deletes except for compaction operations).

#### 3.3.1. Schema Definition

```sql
CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  event_sequence INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  event_payload TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  user_id TEXT,
  FOREIGN KEY (document_id) REFERENCES metadata(document_id)
);

CREATE INDEX idx_events_sequence ON events(document_id, event_sequence);
```

#### 3.3.2. Field Specifications

| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| `event_id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | Auto-incrementing unique event identifier |
| `document_id` | TEXT | NOT NULL, FOREIGN KEY | References `metadata.document_id` |
| `event_sequence` | INTEGER | NOT NULL | Zero-based sequence number, unique per document. MUST be monotonically increasing. |
| `event_type` | TEXT | NOT NULL | Event discriminator (e.g., `"CreatePathEvent"`, `"MoveAnchorEvent"`) |
| `event_payload` | TEXT | NOT NULL | JSON-serialized event data. MUST be valid JSON. |
| `timestamp` | INTEGER | NOT NULL | Unix timestamp in **milliseconds** (UTC) when event occurred |
| `user_id` | TEXT | OPTIONAL | User identifier (reserved for future collaboration features) |

#### 3.3.3. Event Sequencing Rules

- `event_sequence` MUST start at `0` for the first event in a document
- `event_sequence` MUST increment by exactly `1` for each subsequent event
- Gaps in `event_sequence` indicate data corruption and MUST trigger error handling

#### 3.3.4. Event Payload Format

Event payloads MUST be valid JSON objects. The structure is event-type-specific and defined in the [Event Schema Reference](../docs/reference/event_schema.md) (informative).

**Example:**
```json
{
  "type": "MoveAnchorEvent",
  "path_id": "550e8400-e29b-41d4-a716-446655440000",
  "anchor_index": 3,
  "new_position": {"x": 125.5, "y": 200.0}
}
```

### 3.4. `snapshots` Table

The `snapshots` table stores periodic serialized document states to avoid replaying the entire event log.

#### 3.4.1. Schema Definition

```sql
CREATE TABLE snapshots (
  snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  event_sequence INTEGER NOT NULL,
  snapshot_data BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  compression TEXT NOT NULL,
  FOREIGN KEY (document_id) REFERENCES metadata(document_id)
);

CREATE INDEX idx_snapshots_sequence ON snapshots(document_id, event_sequence DESC);
```

#### 3.4.2. Field Specifications

| Field | Type | Constraint | Description |
|-------|------|-------------|-------------|
| `snapshot_id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | Auto-incrementing unique snapshot identifier |
| `document_id` | TEXT | NOT NULL, FOREIGN KEY | References `metadata.document_id` |
| `event_sequence` | INTEGER | NOT NULL | Snapshot taken **after** replaying events up to and including this sequence number |
| `snapshot_data` | BLOB | NOT NULL | Binary snapshot data (see §4 for format specification) |
| `created_at` | INTEGER | NOT NULL | Unix timestamp in **seconds** (UTC) when snapshot was created |
| `compression` | TEXT | NOT NULL | Compression method: `"gzip"` or `"none"` (MUST match snapshot header) |

#### 3.4.3. Snapshot Frequency

Implementations SHOULD create a new snapshot every **1000 events** to balance storage overhead and replay performance.

**Rationale (Informative):** 1000 events ≈ 5-10 minutes of active editing. Too frequent = wasted storage; too infrequent = slow document loading.

---

<!-- anchor: snapshot-binary-format -->
## 4. Snapshot Binary Format

### 4.1. Format Overview

Snapshot data stored in `snapshots.snapshot_data` MUST use a versioned binary format with integrity checks.

### 4.2. Binary Header Specification

The snapshot MUST begin with a 20-byte fixed header:

| Offset | Size | Type   | Description | Requirement |
|--------|------|--------|-------------|-------------|
| 0-3    | 4    | ASCII  | Magic bytes: `"WTSS"` (0x57, 0x54, 0x53, 0x53) | REQUIRED |
| 4      | 1    | uint8  | Snapshot format version (current: `1`) | REQUIRED |
| 5      | 1    | uint8  | Compression flag (`0` = none, `1` = gzip) | REQUIRED |
| 6-9    | 4    | uint32 | Uncompressed payload size in bytes (little-endian) | REQUIRED |
| 10-13  | 4    | uint32 | CRC32 checksum of **uncompressed** payload (little-endian) | REQUIRED |
| 14-19  | 6    | zeros  | Reserved for future use (MUST be zero) | REQUIRED |

### 4.3. Magic Bytes

The magic bytes `"WTSS"` (WireTuner Snapshot Store) MUST appear at offset 0-3 to enable quick format detection.

### 4.4. Snapshot Format Version

Offset 4 MUST contain the snapshot format version number:
- Current version: `1`
- This version is independent of `metadata.format_version` and allows snapshot format evolution

### 4.5. Compression Flag

Offset 5 MUST indicate the compression method:
- `0` = No compression (raw UTF-8 JSON)
- `1` = GZip compression (RFC 1952)

The value MUST match the `snapshots.compression` column.

### 4.6. Uncompressed Size

Offsets 6-9 MUST contain the uncompressed payload size in bytes (little-endian uint32).

**Purpose (Informative):** Enables memory pre-allocation and progress tracking during decompression.

### 4.7. CRC32 Checksum

Offsets 10-13 MUST contain the CRC-32/ISO-HDLC checksum of the **uncompressed** payload (little-endian uint32).

**Algorithm Specification:**
- Polynomial: `0xEDB88320` (reversed representation)
- Initial value: `0xFFFFFFFF`
- Final XOR: `0xFFFFFFFF`

**Validation:** Implementations MUST validate the CRC32 before deserializing the payload. On mismatch, implementations MUST throw an error and attempt recovery (see §9.2).

### 4.8. Payload Format

Bytes 20+ contain the snapshot payload:

- **Uncompressed (flag = 0):** Raw UTF-8 JSON document state
- **Compressed (flag = 1):** GZip-compressed (RFC 1952) UTF-8 JSON document state

The JSON structure represents the serialized `Document` object and is defined in the [Vector Model Specification](../docs/reference/vector_model.md) (informative).

### 4.9. Example Binary Layout (Informative)

```
Offset    Hex                                       ASCII/Description
--------  ----------------------------------------  -------------------
00000000: 57 54 53 53 01 01 00 00  01 00 A3 2F 4B 12 00 00  │ WTSS....../K..... │
          │         │  │  │         │              │
          │         │  │  │         │              └─ Reserved (zeros)
          │         │  │  │         └─ CRC32: 0x124B2FA3
          │         │  │  └─ Uncompressed size: 256 bytes
          │         │  └─ Compression flag: 1 (gzip)
          │         └─ Snapshot version: 1
          └─ Magic bytes: "WTSS"

00000010: 00 00 00 00 1F 8B 08 00  00 00 00 00 00 03 ...    │ .....(gzip data)  │
          │         │
          │         └─ GZip payload begins (RFC 1952 format)
          └─ Reserved bytes (zeros)
```

---

<!-- anchor: semantic-versioning -->
## 5. Semantic Versioning

### 5.1. Versioning Scheme

The `.wiretuner` file format uses **semantic versioning** for `metadata.format_version`:

```
format_version = MAJOR
```

**Current Version:** `1`

### 5.2. Version Increment Rules

#### 5.2.1. Major Version Increments

Increment `format_version` when making **backward-incompatible** changes:

- Adding new required tables or columns
- Changing column data types or constraints
- Altering snapshot binary format in non-backward-compatible ways
- Introducing features that older applications cannot safely ignore

**Example:** Adding gradient support that requires new event types and snapshot fields → `format_version = 2`

#### 5.2.2. Backward-Compatible Changes

The following changes DO NOT require version increments:

- Adding optional columns with default values
- Creating new indexes for performance
- Extending snapshot header reserved bytes (14-19)
- Adding new event types that older apps can ignore

**Rationale (Informative):** These changes allow forward-compatible evolution without forcing upgrades.

### 5.3. Version History Table

| Version | Release Date | Major Changes |
|---------|--------------|---------------|
| `1`     | 2025-11-09   | Initial format specification with event sourcing schema, versioned snapshot headers, CRC32 validation |
| `0`     | (Legacy)     | Pre-release format with unversioned gzip/JSON snapshots (deprecated, migration supported) |

---

<!-- anchor: compatibility-matrix -->
## 6. Compatibility Matrix

### 6.1. Compatibility Guarantees

This section defines normative compatibility rules between file format versions and application versions.

| File Version | App Version | Can Open? | Behavior |
|--------------|-------------|-----------|----------|
| `1`          | `1`         | ✅ Yes    | Full compatibility, no migration required |
| `2`          | `1`         | ❌ No     | MUST display upgrade warning, MUST refuse to open |
| `0` (legacy) | `1`         | ✅ Yes    | MUST trigger automatic migration (see §7.2) |

### 6.2. Compatibility Rules

#### 6.2.1. Forward Compatibility (Newer App, Older File)

Applications MUST support opening files from **all previous major versions** via automatic migration.

**Requirement:** When `file.format_version < app_version`, the application MUST:
1. Detect the version mismatch
2. Trigger the appropriate migration strategy (§7)
3. Update `metadata.format_version` to the current version
4. Log the migration event

#### 6.2.2. Backward Compatibility (Older App, Newer File)

Applications MUST refuse to open files from **newer major versions**.

**Requirement:** When `file.format_version > app_version`, the application MUST:
1. Display an error dialog with upgrade instructions (see §8.2)
2. Refuse to open the file
3. NOT attempt any file modifications

#### 6.2.3. Cross-Version Editing

Editing files with older applications after saving in a newer version is NOT supported and MUST result in an error.

**Example:** A file saved as v2 cannot be opened in a v1 application, even if the user downgrades the application.

### 6.3. Future Version Support (Informative)

Future versions (v2, v3, etc.) will follow the same compatibility rules:

- v2 applications MUST open v1 and v0 files
- v3 applications MUST open v2, v1, and v0 files
- v1 applications MUST refuse to open v2 and v3 files

---

<!-- anchor: migration-strategies -->
## 7. Migration Strategies

### 7.1. Automatic Migration (Forward Compatibility)

When opening a document with `format_version < current_version`, the application MUST automatically migrate the file.

#### 7.1.1. Migration Trigger

Migration MUST occur during document opening, before the document is presented to the user.

#### 7.1.2. Migration Safety

Implementations SHOULD use SQLite transactions and WAL mode to ensure atomicity:

```sql
BEGIN TRANSACTION;
-- Perform migration steps
COMMIT;
```

If migration fails, implementations MUST roll back the transaction and display an error.

### 7.2. Migration Path: Version 0 → Version 1

#### 7.2.1. Legacy Format Detection

**Legacy v0 snapshots** lack the versioned header and may be:
- **Raw GZip:** BLOB starts with `0x1f, 0x8b` (GZip magic bytes)
- **Raw JSON:** BLOB starts with `{` (0x7B, UTF-8 JSON)

#### 7.2.2. Migration Procedure

Implementations MUST perform the following steps:

1. **Detect legacy format:**
   - Read first 4 bytes of `snapshots.snapshot_data`
   - If not `"WTSS"` (0x57, 0x54, 0x53, 0x53), assume legacy format

2. **Extract payload:**
   - If GZip: Decompress to UTF-8 JSON
   - If JSON: Use raw BLOB as UTF-8 JSON

3. **Parse JSON:**
   - Deserialize document state
   - Validate structure

4. **Re-serialize with v1 header:**
   - Compute CRC32 of uncompressed JSON
   - Build 20-byte header (magic, version=1, compression flag, size, CRC32, reserved)
   - Optionally re-compress payload

5. **Update database:**
   ```sql
   UPDATE snapshots SET snapshot_data = ? WHERE snapshot_id = ?;
   UPDATE metadata SET format_version = 1 WHERE document_id = ?;
   ```

6. **Log migration:**
   - Write to application log: `"Migrated document {document_id} from v0 to v1"`

#### 7.2.3. Performance

Migration SHOULD complete in **< 500ms** for typical documents (< 10 MB).

#### 7.2.4. Error Handling

If migration fails (e.g., corrupt legacy data):
- Roll back transaction
- Display error: `"Unable to migrate legacy file format. File may be corrupted."`
- Refuse to open document

### 7.3. Future Migration Paths (Informative)

Future migrations (v1 → v2, v2 → v3) SHOULD follow the same pattern:

1. Detect version mismatch
2. Apply version-specific transformations
3. Update `format_version`
4. Log migration

**Recommendation:** For complex migrations, implement incremental migrations (v1 → v2 → v3) rather than direct jumps.

---

<!-- anchor: downgrade-workflows -->
## 8. Downgrade Workflows

### 8.1. Save As (Export to Older Version)

Applications MAY provide a "Save As" feature to export documents to older format versions.

#### 8.1.1. Downgrade Detection

When a user requests "Save As v1" from a v2 application, the application MUST:

1. **Analyze feature compatibility:**
   - Identify features used in the document that are not supported in v1
   - Example: Gradients (v2 feature) cannot be represented in v1

2. **Display downgrade warning:**
   ```
   Warning: Downgrade to Version 1

   The following features will be lost or altered:
   - 3 objects with gradient fills (will convert to solid fills)
   - 1 layer group (will flatten to individual layers)

   Continue with downgrade?
   [Cancel] [Proceed]
   ```

3. **Perform downgrade:**
   - Remove or simplify unsupported features
   - Update `format_version` to target version
   - Optionally save a backup copy

#### 8.1.2. Downgrade Constraints

Implementations MUST NOT allow silent data loss. All downgrades MUST either:

- Warn the user about data loss, OR
- Convert incompatible features to compatible approximations

### 8.2. Opening Newer Files in Older Applications

When an older application encounters a newer file format, it MUST display a clear error message.

#### 8.2.1. Error Dialog Template

```
Incompatible File Version

This file was created with WireTuner version {detected_version} or newer.
You are running version {current_version}.

Please upgrade to the latest version of WireTuner to open this file.

Download: https://wiretuner.app/download

[Close]
```

#### 8.2.2. Technical Details (Optional)

Advanced users MAY be shown additional technical information:

```
File Format Version: 2
Application Supports: 1
Document ID: 550e8400-e29b-41d4-a716-446655440000
Created: 2025-11-09T14:23:00Z
```

### 8.3. Snapshot Format Version Mismatch

If a snapshot header indicates `snapshot_version > current_serializer_version`:

1. **Log warning:**
   ```
   Warning: Snapshot version mismatch (snapshot: 2, app: 1)
   ```

2. **Attempt best-effort deserialization:**
   - Try to parse payload using current deserializer
   - If successful, continue with non-blocking warning

3. **Fallback to event replay:**
   - If deserialization fails, discard snapshot
   - Replay events from last compatible snapshot

4. **Display user warning:**
   ```
   Partial Snapshot Support

   Some snapshots in this document use a newer format.
   Performance may be reduced.

   Consider upgrading to the latest version.

   [Dismiss] [Check for Updates]
   ```

---

<!-- anchor: verification-validation -->
## 9. Verification & Validation

### 9.1. File Integrity Checks

Implementations SHOULD perform the following integrity checks on document load:

#### 9.1.1. SQLite Database Validation

```sql
PRAGMA integrity_check;
```

If the result is not `"ok"`, the database is corrupted and MUST NOT be opened.

#### 9.1.2. Schema Validation

Verify that all required tables and columns exist:

```sql
SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots');
```

If any table is missing, display error: `"Invalid .wiretuner file: missing required tables"`

#### 9.1.3. Metadata Validation

```sql
SELECT COUNT(*) FROM metadata;
```

MUST return exactly `1`. If zero or multiple rows, the file is invalid.

### 9.2. Snapshot CRC32 Validation

Implementations MUST validate snapshot checksums before deserialization.

#### 9.2.1. Validation Procedure

```python
def validate_snapshot(snapshot_data: bytes) -> bytes:
    # 1. Extract header
    magic = snapshot_data[0:4]
    if magic != b'WTSS':
        raise FormatError("Invalid snapshot magic bytes")

    version = snapshot_data[4]
    compression_flag = snapshot_data[5]
    uncompressed_size = struct.unpack('<I', snapshot_data[6:10])[0]
    expected_crc32 = struct.unpack('<I', snapshot_data[10:14])[0]

    # 2. Extract and decompress payload
    payload_compressed = snapshot_data[20:]
    if compression_flag == 1:  # gzip
        payload_uncompressed = gzip.decompress(payload_compressed)
    else:
        payload_uncompressed = payload_compressed

    # 3. Validate CRC32
    computed_crc32 = zlib.crc32(payload_uncompressed) & 0xFFFFFFFF
    if computed_crc32 != expected_crc32:
        raise CRC32Error(f"Checksum mismatch: expected {expected_crc32:08X}, got {computed_crc32:08X}")

    return payload_uncompressed
```

#### 9.2.2. Corruption Recovery

On CRC32 validation failure:

1. **Log error:**
   ```
   CRC32 checksum validation failed: expected 0x124B2FA3, got 0x89ABCDEF.
   Snapshot at event_sequence {seq} is corrupted.
   ```

2. **Discard corrupted snapshot**

3. **Fall back to previous snapshot:**
   - Find the most recent snapshot with `event_sequence < corrupted_sequence`
   - Replay events from that snapshot to current sequence

4. **Display user warning:**
   ```
   Snapshot Corruption Detected

   A snapshot was corrupted and has been recovered by replaying events.
   Document loading may be slower.

   Consider re-saving the document to rebuild snapshots.

   [OK]
   ```

### 9.3. Event Sequence Validation

Implementations SHOULD validate event sequence integrity on document load:

```sql
SELECT event_sequence FROM events WHERE document_id = ? ORDER BY event_sequence;
```

Verify:
- First event has `event_sequence = 0`
- No gaps in sequence (each event = previous + 1)
- No duplicate sequence numbers

If gaps or duplicates are found, the event log is corrupted and MUST trigger error handling.

### 9.4. QA Integration

This specification ties to the following QA artifacts (informative):

- **History Panel Checklist:** [docs/qa/history_panel_checklist.md](../docs/qa/history_panel_checklist.md) - Validates undo/redo and event replay
- **Crash Recovery Suite:** Verifies ACID guarantees and WAL mode behavior
- **File Format Compatibility Tests:** Validates migration paths (v0 → v1, future versions)

**Verification Strategy:** All format changes MUST pass the compatibility test suite before release.

---

<!-- anchor: appendices -->
## 10. Appendices

### Appendix A: Metadata JSON Example

**Informative representation** of the `metadata` table row as JSON:

```json
{
  "document_id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "My Vector Design",
  "format_version": 1,
  "created_at": 1699545600,
  "modified_at": 1699632000,
  "author": "alice@example.com"
}
```

**Timestamps (Informative):**
- `created_at`: `1699545600` = 2023-11-09T16:00:00Z (UTC)
- `modified_at`: `1699632000` = 2023-11-10T16:00:00Z (UTC)

### Appendix B: Complete Example Event

**Informative example** of an `events` table row:

```json
{
  "event_id": 42,
  "document_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_sequence": 41,
  "event_type": "MoveAnchorEvent",
  "event_payload": {
    "path_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "anchor_index": 3,
    "new_position": {
      "x": 125.5,
      "y": 200.0
    }
  },
  "timestamp": 1699545615234,
  "user_id": null
}
```

**Timestamp (Informative):**
- `timestamp`: `1699545615234` = 2023-11-09T16:00:15.234Z (UTC)

### Appendix C: Snapshot Document Header Example

**Informative example** of the JSON payload stored in `snapshots.snapshot_data` (uncompressed):

```json
{
  "document_header": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "My Vector Design",
    "format_version": 1,
    "created_at": "2023-11-09T16:00:00Z",
    "modified_at": "2023-11-10T16:00:00Z",
    "event_sequence": 1000,
    "checksum": "0x124B2FA3"
  },
  "document_state": {
    "viewport": {
      "pan": {"x": 0, "y": 0},
      "zoom": 1.0
    },
    "objects": [
      {
        "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        "type": "Path",
        "anchors": [
          {"position": {"x": 100, "y": 100}, "handleIn": null, "handleOut": null},
          {"position": {"x": 200, "y": 100}, "handleIn": null, "handleOut": {"x": 220, "y": 100}}
        ],
        "style": {
          "fill": "#FF5733",
          "stroke": "#000000",
          "strokeWidth": 2.0
        }
      }
    ]
  }
}
```

**Note:** Timestamps use RFC 3339 format in JSON (ISO 8601). The SQLite `metadata` table stores Unix timestamps as integers for compact storage.

### Appendix D: CRC32 Test Vectors

**Informative test vectors** for CRC-32/ISO-HDLC validation:

| Input (UTF-8) | Expected CRC32 (hex) |
|---------------|----------------------|
| `""` (empty)  | `0x00000000` |
| `"123456789"` | `0xCBF43926` |
| `"The quick brown fox jumps over the lazy dog"` | `0x414FA339` |

### Appendix E: Compatibility Matrix (Expanded)

**Informative extended compatibility scenarios** for future versions:

| File Version | App Version | Migration Path | Data Loss? |
|--------------|-------------|----------------|------------|
| v0 (legacy)  | v1          | v0 → v1        | No         |
| v1           | v1          | None           | No         |
| v1           | v2          | None (forward-compatible) | No |
| v2           | v1          | **Not supported** | N/A (refused) |
| v2           | v2          | None           | No         |
| v2           | v3          | None (forward-compatible) | No |
| v3           | v2          | **Not supported** | N/A (refused) |

### Appendix F: References

#### Normative References

- [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt) - Key words for use in RFCs to Indicate Requirement Levels
- [RFC 1952](https://www.ietf.org/rfc/rfc1952.txt) - GZIP file format specification
- [SQLite Documentation](https://www.sqlite.org/docs.html) - SQLite 3.x specification

#### Informative References

- [File Versioning Notes](../docs/reference/file_versioning_notes.md) - Detailed implementation guidance
- [Data Snapshot ERD](../docs/diagrams/data_snapshot_erd.mmd) - Visual schema diagram
- [Architecture Decision 3](../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite) - SQLite rationale
- [Vector Model Specification](../docs/reference/vector_model.md) - JSON document structure
- [Event Schema Reference](../docs/reference/event_schema.md) - Event payload definitions

### Appendix G: Version History

| Spec Version | Date       | Changes |
|--------------|------------|---------|
| 1.0          | 2025-11-09 | Initial normative specification |

---

## Document Maintenance

**Maintainer:** WireTuner Architecture Team
**Review Cycle:** After each format version increment or upon request
**Next Review:** Upon proposal of format version 2 or after I5.T3 completion
**Feedback:** Submit issues to [WireTuner GitHub Repository](https://github.com/wiretuner/wiretuner/issues)

**Change Control:** Amendments to this specification require:
1. Proposal via GitHub issue with rationale
2. Review by architecture team
3. Update to version history table
4. Corresponding updates to reference documentation

---

**End of Specification**

*This document is the authoritative source for `.wiretuner` file format implementation. All implementations MUST conform to the normative requirements defined herein.*
