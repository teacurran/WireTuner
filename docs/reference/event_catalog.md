# Event Catalog Reference

<!-- anchor: event-catalog-reference -->

**Version:** 2.0
**Date:** 2025-11-11
**Status:** Active
**Related Documents:** [Event Schema Reference](./event_schema.md) | [ADR 003](../adr/003-event-sourcing-architecture.md) | [Task I2.T1](../../.codemachine/artifacts/plan/02_Iteration_I2.md#task-i2-t1)

---

## Overview

This document provides a comprehensive catalog of all event types supported by WireTuner's event sourcing system. Each event type represents a specific user action or system operation that modifies document state. All events conform to the [Universal Event Envelope](./event_schema.md#universal-event-envelope) and follow the validation rules defined in the [Event Schema Reference](./event_schema.md).

**Purpose:**
- Enumerate all concrete event types and their discriminators
- Map event types to functional requirements (FR IDs)
- Document event-specific payload fields beyond the universal envelope
- Provide quick reference for event type usage patterns

**Organization:**
- Events are grouped by functional domain (Path Creation, Selection, Viewport, etc.)
- Each event includes: type discriminator, FR mapping, sampling strategy, and payload schema
- All events inherit the universal envelope fields documented in [event_schema.md:50](./event_schema.md#universal-event-envelope)

---

## Table of Contents

- [Universal Event Envelope Reference](#universal-event-envelope-reference)
- [Event Store Schema Columns](#event-store-schema-columns)
- [Path Creation Events](#path-creation-events)
- [Path Modification Events](#path-modification-events)
- [Shape Creation Events](#shape-creation-events)
- [Selection Events](#selection-events)
- [Transform Events](#transform-events)
- [Style Events](#style-events)
- [Viewport Events](#viewport-events)
- [Layer Management Events](#layer-management-events)
- [Artboard Events](#artboard-events)
- [Document Events](#document-events)
- [Event Type Summary Table](#event-type-summary-table)

---

## Universal Event Envelope Reference

All events in this catalog inherit the following required metadata fields from the universal event envelope. These fields are **NOT repeated** in individual event payload definitions below.

| Field Name | Type | Description | Reference |
|------------|------|-------------|-----------|
| `eventId` | string (UUID) | Globally unique identifier for this event instance | [event_schema.md:58](./event_schema.md#universal-event-envelope) |
| `timestamp` | integer | Event creation time in Unix milliseconds | [event_schema.md:59](./event_schema.md#universal-event-envelope) |
| `eventType` | string | Discriminator for polymorphic deserialization | [event_schema.md:60](./event_schema.md#universal-event-envelope) |
| `eventSequence` | integer | Zero-based sequential index within the document | [event_schema.md:61](./event_schema.md#universal-event-envelope) |
| `documentId` | string (UUID) | Document to which this event belongs | [event_schema.md:62](./event_schema.md#universal-event-envelope) |

**Optional Envelope Extensions:**

| Field Name | Type | Description | Reference |
|------------|------|-------------|-----------|
| `samplingIntervalMs` | integer | Sampling interval (50ms for high-frequency events) | [event_schema.md:145](./event_schema.md#sampling-metadata-and-validation) |
| `undoGroupId` | string (UUID) | Groups related events into atomic undo action | [event_schema.md:221](./event_schema.md#undo-grouping-and-atomicity) |
| `undoGroupStart` | boolean | Marks first event in undo group | [event_schema.md:222](./event_schema.md#undo-grouping-and-atomicity) |
| `undoGroupEnd` | boolean | Marks last event in undo group | [event_schema.md:223](./event_schema.md#undo-grouping-and-atomicity) |
| `userId` | string (UUID) | User who created this event | [event_schema.md:282](./event_schema.md#collaboration-ready-fields) |
| `sessionId` | string (UUID) | Editing session identifier | [event_schema.md:283](./event_schema.md#collaboration-ready-fields) |
| `deviceId` | string | Device identifier | [event_schema.md:284](./event_schema.md#collaboration-ready-fields) |

---

## Event Store Schema Columns

<!-- anchor: event-store-schema-columns -->

This section documents the finalized SQLite schema columns for the `events` table as implemented in Task I2.T1. These columns extend the universal event envelope with persistence-specific metadata required for replay, auto-save, and collaboration features.

### Events Table Schema (v2)

The `events` table stores all event records with the following columns:

| Column Name | SQLite Type | Description | Corresponds To |
|-------------|-------------|-------------|----------------|
| `event_id` | TEXT PRIMARY KEY | Unique event identifier (TEXT format, e.g., "evt_123") | EventBase.eventId |
| `document_id` | TEXT NOT NULL | Foreign key to documents table | EventBase.documentId |
| `sequence` | INTEGER NOT NULL UNIQUE | Zero-based sequential index for replay ordering | EventBase.eventSequence |
| `artboard_id` | TEXT | Optional foreign key to artboards table (NULL if document-level event) | Artboard scoping for FR-ARTBOARD-001 |
| `timestamp` | TEXT NOT NULL | ISO 8601 timestamp (e.g., "2025-11-11T10:30:00.000Z") | EventBase.timestamp (converted from Unix milliseconds) |
| `user_id` | TEXT NOT NULL | User who created this event (defaults to "local-user" for single-player) | EventBase.userId |
| `event_type` | TEXT NOT NULL | Event type discriminator (e.g., "CreatePathEvent") | EventBase.eventType |
| `event_data` | TEXT NOT NULL | JSON-serialized event payload containing all event-specific fields | EventBase.toJson() |
| `sampled_path` | TEXT | Optional JSON array of sampled points for high-frequency events (50ms sampling) | Supports FR-PATH-002 (anchor sampling) |
| `operation_id` | TEXT | Optional grouping ID for undo/redo operations | EventBase.undoGroupId |

### Cross-References to Functional Requirements

- **FR-014 (Auto-save):** The `sequence` column ensures deterministic replay order for auto-saved event batches. EventStoreServiceAdapter batches events and flushes periodically (5s timeout or 50 events) to minimize WAL growth while maintaining crash resistance.

- **FR-015 (Manual Save):** Manual save operations call `EventStoreServiceAdapter.flushBatch()` immediately, followed by `performIntegrityCheck()` to ensure WAL is checkpointed and database integrity is verified before user confirmation.

- **FR-ARTBOARD-001 (Artboard Scoping):** The `artboard_id` column enables per-artboard event filtering for NavigatorService thumbnail updates and artboard-specific replay operations.

- **FR-PATH-002 (Anchor Sampling):** The `sampled_path` column stores JSON arrays of sampled anchor points during continuous drag operations, reducing event count while preserving smooth playback during replay.

### WAL Integrity and Auto-Save Integration

The EventStoreServiceAdapter implements the following behaviors to satisfy FR-014/FR-015:

1. **Auto-save Batching:** Events are accumulated in memory and flushed to SQLite every 5 seconds OR when 50 events are pending (whichever comes first). This reduces WAL write frequency while maintaining <5s data loss window.

2. **WAL Checkpoint on Manual Save:** When user triggers manual save (Cmd+S), the system:
   - Calls `flushBatch()` to commit pending events
   - Runs `PRAGMA wal_checkpoint(TRUNCATE)` to merge WAL into main DB file
   - Runs `PRAGMA integrity_check` to verify database health
   - Updates UI save indicator only after integrity check passes

3. **Crash Recovery:** On application startup after crash:
   - SQLite automatically replays WAL transactions (ACID guarantee)
   - Application calls `performIntegrityCheck()` to verify recovery success
   - ReplayService validates document state hash against last known snapshot
   - User is notified if recovery required manual intervention

4. **Event Count Tracking:** The `documents.event_count` column is incremented after each event batch commit, enabling:
   - SnapshotManager to trigger snapshot creation at 1000-event intervals
   - TelemetryService to report per-document editing activity
   - SyncAPI to detect documents requiring cloud backup

### Migration Notes

The schema evolved from v1 (simple `metadata`/`events`/`snapshots`) to v2 (full blueprint schema with `documents`/`artboards`/`layers`/`events`/`snapshots`/`export_jobs`) via `SchemaMigrationManager` (see `lib/infrastructure/persistence/migrations.dart`).

Key migration changes:
- `metadata` table renamed to `documents` with additional columns
- `events.event_id` changed from INTEGER AUTOINCREMENT to TEXT PRIMARY KEY
- `events.event_sequence` renamed to `events.sequence` for consistency
- `events.event_payload` renamed to `events.event_data`
- Added `artboard_id`, `sampled_path`, `operation_id` columns
- Timestamp format changed from INTEGER (Unix milliseconds) to TEXT (ISO 8601)

Existing v1 databases are migrated automatically on first open after upgrade.

---

## Path Creation Events

### CreatePathEvent

**Event Type Discriminator:** `CreatePathEvent`
**Functional Requirement:** FR-PATH-001 (Pen Tool Path Creation)
**Sampling Strategy:** None (discrete lifecycle marker)
**Undo Behavior:** Start of undo group for path creation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `pathId` | string | Yes | Unique identifier for new path | Must be valid UUID |
| `startAnchor` | Point | Yes | Initial anchor position | `{x: number, y: number}` |
| `fillColor` | string | No | Fill color (hex) | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeColor` | string | No | Stroke color (hex) | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeWidth` | number | No | Stroke width in pixels | >= 0 |
| `opacity` | number | No | Opacity | 0.0 to 1.0 |

**Example:** See [event_schema.md:340](./event_schema.md#createpathevent)

---

### AddAnchorEvent

**Event Type Discriminator:** `AddAnchorEvent`
**Functional Requirement:** FR-PATH-002 (Anchor Point Addition)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during drag operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `pathId` | string | Yes | Target path identifier | Must reference existing path |
| `position` | Point | Yes | New anchor position | `{x: number, y: number}` |
| `anchorType` | AnchorType | No | Anchor type | `"line"` or `"bezier"` (default: `"line"`) |
| `handleIn` | Point | No | Incoming Bezier control point | `{x: number, y: number}` |
| `handleOut` | Point | No | Outgoing Bezier control point | `{x: number, y: number}` |

**Example:** See [event_schema.md:374](./event_schema.md#addanchorevent-sampled)

---

### FinishPathEvent

**Event Type Discriminator:** `FinishPathEvent`
**Functional Requirement:** FR-PATH-003 (Path Finalization)
**Sampling Strategy:** None (discrete lifecycle marker)
**Undo Behavior:** End of undo group for path creation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `pathId` | string | Yes | Path identifier to finalize | Must reference existing path |
| `closed` | boolean | No | Whether path is closed | Default: false |

**Example:** See [event_schema.md:403](./event_schema.md#finishpathevent)

---

## Path Modification Events

### ModifyAnchorEvent

**Event Type Discriminator:** `ModifyAnchorEvent`
**Functional Requirement:** FR-PATH-004 (Anchor Point Modification)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during drag operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `pathId` | string | Yes | Target path identifier | Must reference existing path |
| `anchorIndex` | integer | Yes | Index of anchor to modify | 0-based, must be valid index |
| `position` | Point | No | New anchor position | `{x: number, y: number}` |
| `handleIn` | Point | No | New incoming handle | `{x: number, y: number}` |
| `handleOut` | Point | No | New outgoing handle | `{x: number, y: number}` |
| `anchorType` | AnchorType | No | New anchor type | `"line"`, `"bezier"`, `"corner"`, `"smooth"`, `"symmetric"` |

---

### DeleteAnchorEvent

**Event Type Discriminator:** `DeleteAnchorEvent`
**Functional Requirement:** FR-PATH-005 (Anchor Point Deletion)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `pathId` | string | Yes | Target path identifier | Must reference existing path |
| `anchorIndex` | integer | Yes | Index of anchor to delete | 0-based, must be valid index |

---

## Shape Creation Events

### CreateShapeEvent

**Event Type Discriminator:** `CreateShapeEvent`
**Functional Requirement:** FR-SHAPE-001 (Parametric Shape Creation)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `shapeId` | string | Yes | Unique shape identifier | Must be valid UUID |
| `shapeType` | ShapeType | Yes | Shape type | `"rectangle"`, `"ellipse"`, `"star"`, `"polygon"` |
| `parameters` | object | Yes | Shape-specific parameters | See shape parameters table below |
| `fillColor` | string | No | Fill color (hex) | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeColor` | string | No | Stroke color (hex) | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeWidth` | number | No | Stroke width in pixels | >= 0 |
| `opacity` | number | No | Opacity | 0.0 to 1.0 |

**Shape Parameters by Type:**

| ShapeType | Parameters | Description |
|-----------|------------|-------------|
| `rectangle` | `x`, `y`, `width`, `height`, `cornerRadius?` | Top-left position + dimensions |
| `ellipse` | `centerX`, `centerY`, `radiusX`, `radiusY` | Center position + radii |
| `star` | `centerX`, `centerY`, `outerRadius`, `innerRadius`, `points` | Center + radii + point count |
| `polygon` | `centerX`, `centerY`, `radius`, `sides` | Center + bounding radius + side count |

**Example:** See [event_schema.md:500](./event_schema.md#createshapeevent)

---

## Selection Events

### SelectObjectsEvent

**Event Type Discriminator:** `SelectObjectsEvent`
**Functional Requirement:** FR-SELECT-001 (Object Selection)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Array of object IDs to select | Must reference existing objects |
| `mode` | SelectionMode | No | Selection mode | `"replace"`, `"add"`, `"toggle"`, `"subtract"` (default: `"replace"`) |

**Example:** See [event_schema.md:433](./event_schema.md#selectobjectsevent)

---

### DeselectAllEvent

**Event Type Discriminator:** `DeselectAllEvent`
**Functional Requirement:** FR-SELECT-002 (Selection Clearing)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:** None (uses only universal envelope)

---

## Transform Events

### MoveObjectEvent

**Event Type Discriminator:** `MoveObjectEvent`
**Functional Requirement:** FR-TRANSFORM-001 (Object Translation)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during drag operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Objects to move | Must reference existing objects |
| `delta` | Point | Yes | Translation delta | `{x: number, y: number}` |

**Example:** See [event_schema.md:459](./event_schema.md#moveobjectevent-sampled)

---

### RotateObjectEvent

**Event Type Discriminator:** `RotateObjectEvent`
**Functional Requirement:** FR-TRANSFORM-002 (Object Rotation)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during drag operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Objects to rotate | Must reference existing objects |
| `angle` | number | Yes | Rotation angle in radians | -2π to 2π |
| `pivotPoint` | Point | No | Rotation pivot point | Default: object center |

---

### ScaleObjectEvent

**Event Type Discriminator:** `ScaleObjectEvent`
**Functional Requirement:** FR-TRANSFORM-003 (Object Scaling)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during drag operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Objects to scale | Must reference existing objects |
| `scaleX` | number | Yes | Horizontal scale factor | > 0 |
| `scaleY` | number | Yes | Vertical scale factor | > 0 |
| `pivotPoint` | Point | No | Scale origin point | Default: object center |

---

## Style Events

### ModifyStyleEvent

**Event Type Discriminator:** `ModifyStyleEvent`
**Functional Requirement:** FR-STYLE-001 (Style Property Modification)
**Sampling Strategy:** Debounced to final value (on pointer release)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Objects to restyle | Must reference existing objects |
| `fillColor` | string | No | New fill color | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeColor` | string | No | New stroke color | Pattern: `^#[0-9A-Fa-f]{6}$` |
| `strokeWidth` | number | No | New stroke width | >= 0 |
| `opacity` | number | No | New opacity | 0.0 to 1.0 |
| `blendMode` | BlendMode | No | New blend mode | Valid blend mode enum value |

---

## Viewport Events

### ViewportPanEvent

**Event Type Discriminator:** `ViewportPanEvent`
**Functional Requirement:** FR-VIEWPORT-001 (Canvas Panning)
**Sampling Strategy:** 50ms intervals during continuous drag
**Undo Behavior:** Part of undo group during pan operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `delta` | Point | Yes | Pan offset delta | `{x: number, y: number}` |

---

### ViewportZoomEvent

**Event Type Discriminator:** `ViewportZoomEvent`
**Functional Requirement:** FR-VIEWPORT-002 (Canvas Zoom)
**Sampling Strategy:** 50ms intervals during continuous zoom
**Undo Behavior:** Part of undo group during zoom operations

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `zoomDelta` | number | Yes | Zoom level change | Typically -1.0 to 1.0 per event |
| `focalPoint` | Point | No | Zoom center point | Default: viewport center |

---

## Layer Management Events

### CreateLayerEvent

**Event Type Discriminator:** `CreateLayerEvent`
**Functional Requirement:** FR-LAYER-001 (Layer Creation)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `layerId` | string | Yes | Unique layer identifier | Must be valid UUID |
| `artboardId` | string | Yes | Parent artboard ID | Must reference existing artboard |
| `name` | string | No | Layer name | Default: "Layer N" |
| `visible` | boolean | No | Initial visibility | Default: true |
| `locked` | boolean | No | Initial lock state | Default: false |
| `zIndex` | integer | No | Z-order position | Default: top of stack |

---

### DeleteLayerEvent

**Event Type Discriminator:** `DeleteLayerEvent`
**Functional Requirement:** FR-LAYER-002 (Layer Deletion)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `layerId` | string | Yes | Layer to delete | Must reference existing layer |

---

### ReorderLayerEvent

**Event Type Discriminator:** `ReorderLayerEvent`
**Functional Requirement:** FR-LAYER-003 (Layer Reordering)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `layerId` | string | Yes | Layer to reorder | Must reference existing layer |
| `newZIndex` | integer | Yes | New z-order position | >= 0 |

---

## Artboard Events

### CreateArtboardEvent

**Event Type Discriminator:** `CreateArtboardEvent`
**Functional Requirement:** FR-ARTBOARD-001 (Artboard Creation)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `artboardId` | string | Yes | Unique artboard identifier | Must be valid UUID |
| `name` | string | No | Artboard name | Default: "Artboard N" |
| `boundsX` | number | Yes | X position | Canvas coordinates |
| `boundsY` | number | Yes | Y position | Canvas coordinates |
| `boundsWidth` | number | Yes | Width | > 0 |
| `boundsHeight` | number | Yes | Height | > 0 |
| `backgroundColor` | string | No | Background color | Pattern: `^#[0-9A-Fa-f]{6}$`, default: `"#FFFFFF"` |
| `preset` | ArtboardPreset | No | Preset dimensions | e.g., `"iPhone14"`, `"A4"`, etc. |

---

### ModifyArtboardEvent

**Event Type Discriminator:** `ModifyArtboardEvent`
**Functional Requirement:** FR-ARTBOARD-002 (Artboard Modification)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `artboardId` | string | Yes | Artboard to modify | Must reference existing artboard |
| `name` | string | No | New name | - |
| `boundsX` | number | No | New X position | - |
| `boundsY` | number | No | New Y position | - |
| `boundsWidth` | number | No | New width | > 0 |
| `boundsHeight` | number | No | New height | > 0 |
| `backgroundColor` | string | No | New background color | Pattern: `^#[0-9A-Fa-f]{6}$` |

---

### DeleteArtboardEvent

**Event Type Discriminator:** `DeleteArtboardEvent`
**Functional Requirement:** FR-ARTBOARD-003 (Artboard Deletion)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `artboardId` | string | Yes | Artboard to delete | Must reference existing artboard |

---

## Document Events

### CreateDocumentEvent

**Event Type Discriminator:** `CreateDocumentEvent`
**Functional Requirement:** FR-DOC-001 (Document Initialization)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Not undoable (lifecycle marker)

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `title` | string | No | Document title | Default: "Untitled" |
| `author` | string | No | Document author | Default: current user |
| `fileFormatVersion` | string | Yes | File format version | SemVer format (e.g., "1.0.0") |

---

### ModifyDocumentMetadataEvent

**Event Type Discriminator:** `ModifyDocumentMetadataEvent`
**Functional Requirement:** FR-DOC-002 (Document Metadata Update)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `title` | string | No | New document title | - |
| `author` | string | No | New author name | - |

---

### DeleteObjectEvent

**Event Type Discriminator:** `DeleteObjectEvent`
**Functional Requirement:** FR-DOC-003 (Object Deletion)
**Sampling Strategy:** None (discrete action)
**Undo Behavior:** Atomic operation

**Payload Fields:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `objectIds` | string[] | Yes | Objects to delete | Must reference existing objects |

---

## Event Type Summary Table

The following table provides a quick reference of all event types, their functional requirement mappings, and sampling strategies.

| Event Type Discriminator | FR ID | Sampling Strategy | Undo Grouping | Category |
|--------------------------|-------|-------------------|---------------|----------|
| `CreatePathEvent` | FR-PATH-001 | None | Start group | Path Creation |
| `AddAnchorEvent` | FR-PATH-002 | 50ms | In group | Path Creation |
| `FinishPathEvent` | FR-PATH-003 | None | End group | Path Creation |
| `ModifyAnchorEvent` | FR-PATH-004 | 50ms | In group | Path Modification |
| `DeleteAnchorEvent` | FR-PATH-005 | None | Atomic | Path Modification |
| `CreateShapeEvent` | FR-SHAPE-001 | None | Atomic | Shape Creation |
| `SelectObjectsEvent` | FR-SELECT-001 | None | Atomic | Selection |
| `DeselectAllEvent` | FR-SELECT-002 | None | Atomic | Selection |
| `MoveObjectEvent` | FR-TRANSFORM-001 | 50ms | In group | Transform |
| `RotateObjectEvent` | FR-TRANSFORM-002 | 50ms | In group | Transform |
| `ScaleObjectEvent` | FR-TRANSFORM-003 | 50ms | In group | Transform |
| `ModifyStyleEvent` | FR-STYLE-001 | Debounced | Atomic | Style |
| `ViewportPanEvent` | FR-VIEWPORT-001 | 50ms | In group | Viewport |
| `ViewportZoomEvent` | FR-VIEWPORT-002 | 50ms | In group | Viewport |
| `CreateLayerEvent` | FR-LAYER-001 | None | Atomic | Layer Management |
| `DeleteLayerEvent` | FR-LAYER-002 | None | Atomic | Layer Management |
| `ReorderLayerEvent` | FR-LAYER-003 | None | Atomic | Layer Management |
| `CreateArtboardEvent` | FR-ARTBOARD-001 | None | Atomic | Artboard |
| `ModifyArtboardEvent` | FR-ARTBOARD-002 | None | Atomic | Artboard |
| `DeleteArtboardEvent` | FR-ARTBOARD-003 | None | Atomic | Artboard |
| `CreateDocumentEvent` | FR-DOC-001 | None | Not undoable | Document |
| `ModifyDocumentMetadataEvent` | FR-DOC-002 | None | Atomic | Document |
| `DeleteObjectEvent` | FR-DOC-003 | None | Atomic | Document |

---

## Validation & Testing

### Event Catalog Compliance Checklist

Use this checklist to ensure new event types conform to catalog standards:

- [ ] Event type discriminator matches Dart class name exactly
- [ ] Functional requirement ID documented (FR-XXX-NNN format)
- [ ] Sampling strategy specified (None, 50ms, Debounced)
- [ ] Undo behavior documented (Atomic, In group, Start/End group, Not undoable)
- [ ] All payload fields documented with types and constraints
- [ ] Required fields marked explicitly
- [ ] Optional fields include default values where applicable
- [ ] Event type added to summary table
- [ ] Example JSON provided in event_schema.md (if applicable)

### Testing Coverage

All event types in this catalog must have corresponding test coverage in:
- `packages/event_core/test/events/` (unit tests for event serialization/deserialization)
- `packages/event_core/test/integration/` (integration tests for event replay)
- `test/widget_tests/` (UI tests for event generation from user actions)

---

## References

### Architecture Documents
- [Event Schema Reference](./event_schema.md) - Universal envelope and validation rules
- [ADR 003: Event Sourcing Architecture](../adr/003-event-sourcing-architecture.md) - Foundational design decisions
- [System Structure and Data Model](../../.codemachine/artifacts/architecture/02_System_Structure_and_Data.md) - Domain model context

### Implementation
- `lib/domain/events/` - Dart event class implementations
- `lib/api/event_schema.dart` - Event serialization/deserialization logic
- `lib/infrastructure/persistence/event_recorder.dart` - Event persistence layer

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-10
**Next Review:** After completion of I2 (Event System MVP Implementation)
