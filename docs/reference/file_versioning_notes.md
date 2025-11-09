# File Versioning and Compatibility Notes

**Document Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Related Documents:** [Vector Model Specification](vector_model.md) | [Event Schema Reference](event_schema.md) | [System Structure](../../.codemachine/artifacts/architecture/03_System_Structure_and_Data.md)

---

## Overview

This document describes WireTuner's file format versioning strategy, compatibility guarantees, snapshot serialization format, and migration handling for the `.wiretuner` file format.

**Key Design Principles:**

1. **Graceful Degradation:** Older applications can detect (but not necessarily open) newer file formats
2. **Forward Compatibility:** Newer applications can open older file formats via automatic migration
3. **Corruption Detection:** CRC32 checksums detect data corruption with high reliability
4. **Version Transparency:** File format version is visible in both SQLite schema and snapshot headers

---

## Table of Contents

- [File Format Overview](#file-format-overview)
- [Snapshot Binary Format](#snapshot-binary-format)
- [Version Compatibility Matrix](#version-compatibility-matrix)
- [Migration Strategy](#migration-strategy)
- [Downgrade Warnings](#downgrade-warnings)
- [Corruption Detection](#corruption-detection)
- [Future Evolution](#future-evolution)

---

## File Format Overview

WireTuner uses SQLite as its native file format (`.wiretuner` files), containing three main tables:

### SQLite Schema (Version 1)

**metadata table:**
```sql
CREATE TABLE metadata (
  document_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  format_version INTEGER NOT NULL,  -- Current: 1
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  author TEXT
);
```

**events table:**
```sql
CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  event_sequence INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  event_payload TEXT NOT NULL,  -- JSON
  timestamp INTEGER NOT NULL,
  user_id TEXT,
  FOREIGN KEY (document_id) REFERENCES metadata(document_id)
);
```

**snapshots table:**
```sql
CREATE TABLE snapshots (
  snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT NOT NULL,
  event_sequence INTEGER NOT NULL,
  snapshot_data BLOB NOT NULL,      -- Binary snapshot (see below)
  created_at INTEGER NOT NULL,
  compression TEXT NOT NULL,        -- "gzip" | "none"
  FOREIGN KEY (document_id) REFERENCES metadata(document_id)
);
```

**Version Field:** The `metadata.format_version` field indicates the schema version. All readers must check this field before attempting to load a document.

**Current Version:** `format_version = 1`

---

## Snapshot Binary Format

Snapshots stored in the `snapshot_data` BLOB column use a versioned binary format with integrity checks.

### Binary Header Specification (20 bytes)

| Offset | Size | Type   | Description                                                        |
|--------|------|--------|--------------------------------------------------------------------|
| 0-3    | 4    | ASCII  | Magic bytes: "WTSS" (0x57, 0x54, 0x53, 0x53)                       |
| 4      | 1    | uint8  | Snapshot format version (currently 1)                              |
| 5      | 1    | uint8  | Compression flag (0 = none, 1 = gzip)                              |
| 6-9    | 4    | uint32 | Uncompressed size (little-endian)                                  |
| 10-13  | 4    | uint32 | CRC32 checksum of uncompressed payload (little-endian)             |
| 14-19  | 6    | zeros  | Reserved for future use                                            |

### Payload Format (byte 20+)

- **Uncompressed:** Raw UTF-8 JSON document state
- **Compressed (gzip):** GZip-compressed UTF-8 JSON document state

### Design Rationale

- **Magic Bytes ("WTSS"):** Enable quick format detection and distinguish from legacy formats
- **Format Version:** Allows snapshot format evolution independent of SQLite schema version
- **Compression Flag:** Supports per-snapshot compression decisions (e.g., compress large docs, leave small docs uncompressed)
- **Uncompressed Size:** Enables memory pre-allocation and progress tracking during decompression
- **CRC32 Checksum:** Detects corruption with ~99.99997% confidence (1 in 4 billion false negative rate)
- **Reserved Bytes:** Future extensions (e.g., encryption flags, schema migration hints)

### Example Binary Layout

```
00000000: 57 54 53 53 01 01 00 00  01 00 A3 2F 4B 12 00 00  │WTSS....../K.....│
00000010: 00 00 00 00 1F 8B 08 00  00 00 00 00 00 03 ...    │................│
          │         │  │  │         │              │
          │         │  │  │         │              └─ Gzip payload
          │         │  │  │         └─ Reserved (zeros)
          │         │  │  └─ CRC32: 0x124B2FA3
          │         │  └─ Uncompressed size: 256 bytes
          │         └─ Compression flag: 1 (gzip)
          └─ Magic + version: "WTSS" v1
```

---

## Version Compatibility Matrix

This matrix defines compatibility guarantees between file format versions and application versions.

### Format Version 1 (Current)

| File Version | App Version | Can Open? | Behavior                                                                 |
|--------------|-------------|-----------|--------------------------------------------------------------------------|
| v1           | v1          | ✅ Yes    | Full compatibility                                                       |
| v2           | v1          | ⚠️ No     | Detects newer version, displays upgrade warning, refuses to open         |
| v0 (legacy)  | v1          | ✅ Yes    | Automatic migration: legacy gzip/JSON snapshots → v1 header format       |

### Compatibility Rules

1. **Forward Compatibility (Newer App, Older File):** Always supported via automatic migration
2. **Backward Compatibility (Older App, Newer File):** Never supported; app displays version error
3. **Cross-Version Editing:** Not supported (opening v2 file in v1 app fails with error)

---

## Migration Strategy

### Automatic Migration (Forward Compatibility)

When opening a document with `format_version < current_version`, the application automatically migrates the file to the current version.

#### Migration Process (v0 → v1)

**Legacy Format Detection:**
- **Legacy Gzip:** Raw gzip BLOB with magic bytes `0x1f, 0x8b`
- **Legacy JSON:** Raw UTF-8 JSON with no header

**Migration Steps:**
1. Detect legacy format (no versioned header)
2. Decompress if gzip-compressed
3. Parse JSON document state
4. Re-serialize with v1 header format (magic bytes + version + CRC)
5. Update `snapshots.snapshot_data` BLOB
6. Update `metadata.format_version` to 1
7. Log migration in application logs

**Performance:** Migration occurs on-demand during document load. Typical migration time: <100ms for medium documents.

**Safety:** Original file is preserved via SQLite WAL mode until migration completes successfully.

#### Future Migration Placeholders (v1 → v2)

**TODO:** When format version 2 is introduced, implement the following:

- [ ] Add `migration_log` table tracking version upgrades
- [ ] Support incremental migrations (v1 → v2 → v3) rather than direct jumps
- [ ] Warn user if migration is irreversible (e.g., new features not backward-compatible)
- [ ] Provide "Export as v1" option for downgrade scenarios

**Schema Evolution Example:**

```sql
-- Future: Version 2 might add gradient support
ALTER TABLE events ADD COLUMN gradient_data TEXT;
UPDATE metadata SET format_version = 2;
```

---

## Downgrade Warnings

### Scenario: Opening Newer File in Older App

**Example:** User opens a `.wiretuner` file created by version 2 (future) in version 1 (current).

**Application Behavior:**

1. Read `metadata.format_version`
2. Detect `format_version = 2` > `current_version = 1`
3. Display error dialog:

   > **Incompatible File Version**
   >
   > This file was created with WireTuner version 2.0 or newer.
   > You are running version 1.0.
   >
   > Please upgrade to the latest version of WireTuner to open this file.
   >
   > Download: https://wiretuner.app/download

4. Refuse to open the file (prevent data corruption)

### Snapshot Format Version Mismatch

**Scenario:** Snapshot header indicates `snapshot_version = 2`, but app only supports `snapshot_version = 1`.

**Application Behavior:**

1. Log warning: `"Snapshot version mismatch: snapshot version 2, serializer version 1"`
2. Attempt deserialization anyway (best-effort compatibility)
3. If deserialization fails, fall back to event replay from last compatible snapshot
4. Display non-blocking warning to user:

   > **Partial Snapshot Support**
   >
   > Some snapshots in this document use a newer format. Performance may be reduced.
   > Consider upgrading to the latest version.

---

## Corruption Detection

### CRC32 Checksum Validation

**Algorithm:** CRC-32/ISO-HDLC (polynomial: 0xEDB88320, initial value: 0xFFFFFFFF)

**Validation Process:**

1. Read snapshot header (bytes 0-19)
2. Extract expected CRC32 (bytes 10-13)
3. Extract payload (bytes 20+)
4. Decompress payload if needed
5. Compute CRC32 of uncompressed JSON bytes
6. Compare computed CRC32 with expected CRC32
7. If mismatch: throw `FormatException` with corruption error

**Error Handling:**

```
CRC32 checksum validation failed: expected 0x124B2FA3, got 0x89ABCDEF.
Snapshot data is corrupted.
```

**Recovery Strategy:**

1. If snapshot is corrupted, discard it
2. Fall back to previous snapshot (if available)
3. Replay events from last good snapshot to current sequence
4. Log corruption event for debugging

**Corruption Probability:**

- CRC32 detects ~99.9999% of all corruptions (1 in 4 billion false negative rate)
- For mission-critical data, future versions may add:
  - SHA-256 checksums (slower but stronger)
  - Error-correcting codes (Reed-Solomon)
  - Snapshot redundancy (store 2-3 copies)

### Decompression Errors

**Scenario:** Gzip decompression fails (corrupted compressed data).

**Application Behavior:**

1. Catch decompression exception
2. Re-throw as `FormatException: "CRC32 checksum validation failed: decompression error indicates corrupted data"`
3. Trigger corruption recovery flow (fall back to previous snapshot)

**Rationale:** Decompression failures almost always indicate corruption, so we report them as CRC failures for consistent error handling.

---

## Future Evolution

### Planned Version 2 Features

**TODO (Future Milestone):**

- [ ] Add gradient and pattern fill support
- [ ] Extend snapshot format to include thumbnail previews
- [ ] Add encryption support (AES-256-GCM) for sensitive documents
- [ ] Implement snapshot deduplication (store diffs instead of full snapshots)

### Snapshot Format Extensions

**Reserved Header Bytes (14-19):** Available for future flags:

| Byte | Potential Use                          |
|------|----------------------------------------|
| 14   | Encryption flag (0 = none, 1 = AES-256)|
| 15   | Diff encoding flag (0 = full, 1 = diff)|
| 16-17| Schema migration hint (uint16)        |
| 18-19| Checksum type (0 = CRC32, 1 = SHA-256) |

### Backward Compatibility Commitment

**Guarantee:** WireTuner will always be able to open files from previous major versions (v1, v2, v3, etc.).

**Breaking Changes:** Major version increments (v1 → v2) may introduce non-reversible migrations. Users will be warned before upgrading.

---

## Cross-References

### Architecture Documents

- [Constraint: Compatibility Requirements](../../.codemachine/artifacts/architecture/01_Context_and_Drivers.md#constraint-compatibility) - File format versioning approach
- [Decision 3: SQLite for Event Storage](../../.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-sqlite) - Rationale for SQLite as native format
- [Decision 4: Version Field in Schema](./.codemachine/artifacts/architecture/01_Context_and_Drivers.md#constraint-compatibility) - Migration logic for older files

### Implementation Files

- **Snapshot Serializer:** `packages/event_core/lib/src/snapshot_serializer.dart` - Binary format encoding/decoding
- **SQLite Schema:** `packages/io_services/lib/src/migrations/base_schema.sql` - Database structure
- **Migration Runner:** `packages/io_services/lib/src/migrations/migration_runner.dart` - Schema version management

### Related Specifications

- [Vector Model Specification](vector_model.md) - JSON document structure
- [Event Schema Reference](event_schema.md) - Event payload format
- [Data Snapshot ERD](../diagrams/data_snapshot_erd.md) - Entity-relationship diagram

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-09
**Next Review:** After completion of I3.T1 (Tool Agent Integration) or when format version 2 is proposed
