# Event Payload Specification

This document provides a comprehensive specification of all event payload structures in the WireTuner event sourcing system. Each event type is formally defined with field descriptions, data types, constraints, and metadata about sampling and performance characteristics.

## Table of Contents

- [Overview](#overview)
- [Common Structures](#common-structures)
- [Path Events](#path-events)
- [Object Events](#object-events)
- [Style Events](#style-events)
- [Selection Events](#selection-events)
- [Viewport Events](#viewport-events)
- [File Events](#file-events)
- [Validation](#validation)
- [Sampling and Performance Metadata](#sampling-and-performance-metadata)
- [Schema Evolution and Upgrade Strategy](#schema-evolution-and-upgrade-strategy)

## Overview

WireTuner uses an event-sourced architecture where all user interactions and document changes are captured as immutable events. Each event contains:

1. **Envelope fields**: Common metadata (eventId, timestamp, eventType)
2. **Payload fields**: Event-specific data

Events are serialized to JSON for storage in SQLite and must conform to the [JSON Schema](./event_payload.schema.json) defined in this specification.

**Schema Version**: Draft 2020-12
**Total Event Types**: 17
**Schema URI**: `https://wiretuner.dev/schemas/event-payload.schema.json`

## Common Structures

### Event Envelope

All events share these base fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `eventId` | string | Yes | Unique identifier for this event (UUID or similar) |
| `timestamp` | integer | Yes | Unix timestamp in milliseconds when event was created |
| `eventType` | string | Yes | Discriminator for polymorphic deserialization (matches class name) |

### Point

Represents a 2D coordinate:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `x` | number | Yes | X coordinate (supports negative values) |
| `y` | number | Yes | Y coordinate (supports negative values) |

### Style Properties

Optional visual styling fields used by several events:

| Field | Type | Required | Description | Pattern/Constraints |
|-------|------|----------|-------------|---------------------|
| `fillColor` | string | No | Fill color in hex format | `^#[0-9A-Fa-f]{6}$` |
| `strokeColor` | string | No | Stroke color in hex format | `^#[0-9A-Fa-f]{6}$` |
| `strokeWidth` | number | No | Stroke width in pixels | `>= 0` |
| `opacity` | number | No | Opacity from 0.0 to 1.0 | `0.0 <= x <= 1.0` |

### Enumerations

#### AnchorType

| Value | Description |
|-------|-------------|
| `line` | Linear anchor with no curve handles (default) |
| `bezier` | Bezier anchor with control handles for curves |

#### ShapeType

| Value | Description |
|-------|-------------|
| `rectangle` | Rectangle shape |
| `ellipse` | Ellipse shape |
| `star` | Star shape |
| `polygon` | Polygon shape |

#### SelectionMode

| Value | Description |
|-------|-------------|
| `replace` | Replace existing selection (default) |
| `add` | Add to existing selection (union) |
| `toggle` | Toggle selection state |
| `subtract` | Subtract from existing selection |

---

## Path Events

Path events capture the lifecycle of pen-drawn vector paths from creation through anchor modification.

### CreatePathEvent

**Event Type**: `CreatePathEvent`
**Description**: Dispatched when user starts creating a path with the pen tool.
**Sampling**: First event only (no sampling applied)
**Related**: T004, T020

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "CreatePathEvent" | - |
| `pathId` | string | Yes | Unique identifier for this path | - |
| `startAnchor` | Point | Yes | Initial anchor point | - |
| `fillColor` | string | No | Fill color (hex) | null |
| `strokeColor` | string | No | Stroke color (hex) | null |
| `strokeWidth` | number | No | Stroke width (px) | null |
| `opacity` | number | No | Opacity (0.0-1.0) | null |

**Example**:
```json
{
  "eventId": "evt_001",
  "timestamp": 1699305600000,
  "eventType": "CreatePathEvent",
  "pathId": "path_001",
  "startAnchor": {"x": 100.0, "y": 200.0},
  "strokeColor": "#000000",
  "strokeWidth": 2.0
}
```

### AddAnchorEvent

**Event Type**: `AddAnchorEvent`
**Description**: Dispatched when user adds a new point to an active path.
**Sampling**: 16ms cadence during pen drag (targeting 60 FPS)
**Related**: T004, T020

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "AddAnchorEvent" | - |
| `pathId` | string | Yes | Path identifier | - |
| `position` | Point | Yes | New anchor position | - |
| `anchorType` | AnchorType | No | Anchor type | "line" |
| `handleIn` | Point | No | Incoming Bezier handle | null |
| `handleOut` | Point | No | Outgoing Bezier handle | null |

**Example**:
```json
{
  "eventId": "evt_002",
  "timestamp": 1699305616000,
  "eventType": "AddAnchorEvent",
  "pathId": "path_001",
  "position": {"x": 150.0, "y": 250.0},
  "anchorType": "bezier",
  "handleIn": {"x": 140.0, "y": 240.0},
  "handleOut": {"x": 160.0, "y": 260.0}
}
```

### FinishPathEvent

**Event Type**: `FinishPathEvent`
**Description**: Dispatched when user finishes drawing a path.
**Sampling**: Final event only (no sampling)
**Related**: T004, T020

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "FinishPathEvent" | - |
| `pathId` | string | Yes | Path identifier | - |
| `closed` | boolean | No | Whether path is closed | false |

**Example**:
```json
{
  "eventId": "evt_003",
  "timestamp": 1699305620000,
  "eventType": "FinishPathEvent",
  "pathId": "path_001",
  "closed": true
}
```

### ModifyAnchorEvent

**Event Type**: `ModifyAnchorEvent`
**Description**: Dispatched when user modifies an existing anchor point.
**Sampling**: 16ms cadence during drag operations
**Related**: T004, T020, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ModifyAnchorEvent" | - |
| `pathId` | string | Yes | Path identifier | - |
| `anchorIndex` | integer | Yes | Index of anchor to modify (0-based) | - |
| `position` | Point | No | New position | null |
| `handleIn` | Point | No | New incoming handle | null |
| `handleOut` | Point | No | New outgoing handle | null |
| `anchorType` | AnchorType | No | New anchor type | null |

**Note**: All modification fields are optional; omitted fields remain unchanged.

**Example**:
```json
{
  "eventId": "evt_004",
  "timestamp": 1699305625000,
  "eventType": "ModifyAnchorEvent",
  "pathId": "path_001",
  "anchorIndex": 1,
  "position": {"x": 155.0, "y": 255.0}
}
```

---

## Object Events

Object events handle creation, movement, and deletion of geometric objects.

### CreateShapeEvent

**Event Type**: `CreateShapeEvent`
**Description**: Dispatched when user creates a parametric shape.
**Sampling**: First event only
**Related**: T004

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "CreateShapeEvent" | - |
| `shapeId` | string | Yes | Unique shape identifier | - |
| `shapeType` | ShapeType | Yes | Type of shape | - |
| `parameters` | object | Yes | Shape-specific parameters | - |
| `fillColor` | string | No | Fill color (hex) | null |
| `strokeColor` | string | No | Stroke color (hex) | null |
| `strokeWidth` | number | No | Stroke width (px) | null |
| `opacity` | number | No | Opacity (0.0-1.0) | null |

**Parameters by Shape Type**:

| ShapeType | Parameters | Description |
|-----------|------------|-------------|
| rectangle | x, y, width, height, cornerRadius | x/y = top-left position, cornerRadius optional |
| ellipse | centerX, centerY, radiusX, radiusY | - |
| star | centerX, centerY, outerRadius, innerRadius, points | points = number of star points |
| polygon | varies | Implementation-specific |

**Example**:
```json
{
  "eventId": "evt_005",
  "timestamp": 1699305630000,
  "eventType": "CreateShapeEvent",
  "shapeId": "shape_001",
  "shapeType": "rectangle",
  "parameters": {
    "x": 50.0,
    "y": 50.0,
    "width": 200.0,
    "height": 100.0,
    "cornerRadius": 10.0
  },
  "fillColor": "#FF5733"
}
```

### MoveObjectEvent

**Event Type**: `MoveObjectEvent`
**Description**: Dispatched when user moves objects on canvas.
**Sampling**: 16ms cadence during drag
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "MoveObjectEvent" | - |
| `objectIds` | string[] | Yes | Objects to move | - |
| `delta` | Point | Yes | Translation delta | - |

**Note**: Supports batch operations; `objectIds` can be empty array (no-op).

**Example**:
```json
{
  "eventId": "evt_006",
  "timestamp": 1699305635000,
  "eventType": "MoveObjectEvent",
  "objectIds": ["path_001", "shape_001"],
  "delta": {"x": 10.0, "y": -5.0}
}
```

### DeleteObjectEvent

**Event Type**: `DeleteObjectEvent`
**Description**: Dispatched when user deletes objects.
**Sampling**: No sampling (discrete action)
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "DeleteObjectEvent" | - |
| `objectIds` | string[] | Yes | Objects to delete | - |

**Example**:
```json
{
  "eventId": "evt_007",
  "timestamp": 1699305640000,
  "eventType": "DeleteObjectEvent",
  "objectIds": ["path_001"]
}
```

---

## Style Events

### ModifyStyleEvent

**Event Type**: `ModifyStyleEvent`
**Description**: Dispatched when user changes visual properties of an object.
**Sampling**: Debounced to final value (color picker releases generate single event)
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ModifyStyleEvent" | - |
| `objectId` | string | Yes | Object to modify | - |
| `fillColor` | string | No | New fill color | null |
| `strokeColor` | string | No | New stroke color | null |
| `strokeWidth` | number | No | New stroke width | null |
| `opacity` | number | No | New opacity | null |

**Note**: Omitted fields leave corresponding properties unchanged.

**Example**:
```json
{
  "eventId": "evt_008",
  "timestamp": 1699305645000,
  "eventType": "ModifyStyleEvent",
  "objectId": "shape_001",
  "fillColor": "#00FF00",
  "opacity": 0.8
}
```

---

## Selection Events

Selection events manage which objects are selected on the canvas.

### SelectObjectsEvent

**Event Type**: `SelectObjectsEvent`
**Description**: Dispatched when user selects objects.
**Sampling**: No sampling (discrete action)
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "SelectObjectsEvent" | - |
| `objectIds` | string[] | Yes | Objects to select | - |
| `mode` | SelectionMode | No | Selection mode | "replace" |

**Example**:
```json
{
  "eventId": "evt_009",
  "timestamp": 1699305650000,
  "eventType": "SelectObjectsEvent",
  "objectIds": ["path_001", "shape_001"],
  "mode": "add"
}
```

### DeselectObjectsEvent

**Event Type**: `DeselectObjectsEvent`
**Description**: Dispatched when user deselects specific objects.
**Sampling**: No sampling
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "DeselectObjectsEvent" | - |
| `objectIds` | string[] | Yes | Objects to deselect | - |

**Example**:
```json
{
  "eventId": "evt_010",
  "timestamp": 1699305655000,
  "eventType": "DeselectObjectsEvent",
  "objectIds": ["path_001"]
}
```

### ClearSelectionEvent

**Event Type**: `ClearSelectionEvent`
**Description**: Dispatched when user clears all selections.
**Sampling**: No sampling
**Related**: T004, T021

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ClearSelectionEvent" | - |

**Example**:
```json
{
  "eventId": "evt_011",
  "timestamp": 1699305660000,
  "eventType": "ClearSelectionEvent"
}
```

---

## Viewport Events

Viewport events track pan, zoom, and reset operations on the canvas view.

### ViewportPanEvent

**Event Type**: `ViewportPanEvent`
**Description**: Dispatched when user pans the viewport.
**Sampling**: 16ms cadence during pan gesture
**Latency Budget**: < 16ms replay overhead per event
**Related**: T004, T019

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ViewportPanEvent" | - |
| `delta` | Point | Yes | Translation delta | - |

**Example**:
```json
{
  "eventId": "evt_012",
  "timestamp": 1699305665000,
  "eventType": "ViewportPanEvent",
  "delta": {"x": 50.0, "y": -30.0}
}
```

### ViewportZoomEvent

**Event Type**: `ViewportZoomEvent`
**Description**: Dispatched when user zooms the viewport.
**Sampling**: Throttled to significant zoom changes (> 5% delta)
**Related**: T004, T019

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ViewportZoomEvent" | - |
| `factor` | number | Yes | Multiplicative zoom factor | - |
| `focalPoint` | Point | Yes | Zoom center (canvas coords) | - |

**Note**: `factor` can be negative or zero (tested edge cases), though typical values are positive.

**Example**:
```json
{
  "eventId": "evt_013",
  "timestamp": 1699305670000,
  "eventType": "ViewportZoomEvent",
  "factor": 2.0,
  "focalPoint": {"x": 400.0, "y": 300.0}
}
```

### ViewportResetEvent

**Event Type**: `ViewportResetEvent`
**Description**: Dispatched when user resets viewport to default view.
**Sampling**: No sampling
**Related**: T004, T019

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "ViewportResetEvent" | - |

**Example**:
```json
{
  "eventId": "evt_014",
  "timestamp": 1699305675000,
  "eventType": "ViewportResetEvent"
}
```

---

## File Events

File events mark document save/load operations in the event log.

### SaveDocumentEvent

**Event Type**: `SaveDocumentEvent`
**Description**: Marker for document save checkpoint.
**Sampling**: No sampling (lifecycle marker)
**Related**: T004, T033

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "SaveDocumentEvent" | - |
| `filePath` | string | No | Save path | null |

**Example**:
```json
{
  "eventId": "evt_015",
  "timestamp": 1699305680000,
  "eventType": "SaveDocumentEvent",
  "filePath": "/path/to/document.wiretuner"
}
```

### LoadDocumentEvent

**Event Type**: `LoadDocumentEvent`
**Description**: Marker for document load start.
**Sampling**: No sampling
**Related**: T004, T034

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "LoadDocumentEvent" | - |
| `filePath` | string | Yes | Load path | - |

**Example**:
```json
{
  "eventId": "evt_016",
  "timestamp": 1699305685000,
  "eventType": "LoadDocumentEvent",
  "filePath": "/path/to/document.wiretuner"
}
```

### DocumentLoadedEvent

**Event Type**: `DocumentLoadedEvent`
**Description**: Marker for successful document load completion.
**Sampling**: No sampling
**Related**: T004, T034

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `eventId` | string | Yes | Unique event identifier | - |
| `timestamp` | integer | Yes | Unix timestamp (ms) | - |
| `eventType` | string | Yes | Always "DocumentLoadedEvent" | - |
| `filePath` | string | Yes | Loaded file path | - |
| `eventCount` | integer | Yes | Number of events replayed | - |

**Example**:
```json
{
  "eventId": "evt_017",
  "timestamp": 1699305690000,
  "eventType": "DocumentLoadedEvent",
  "filePath": "/path/to/document.wiretuner",
  "eventCount": 1234
}
```

---

## Validation

### Schema Validation Command

The JSON Schema can be validated using the AJV CLI validator:

```bash
npm exec ajv compile -s docs/specs/event_payload.schema.json
```

To validate event fixtures against the schema:

```bash
npm exec ajv validate \
  -s docs/specs/event_payload.schema.json \
  -d "test/fixtures/events/*.json"
```

### Dart Schema Validation

For runtime validation in Dart, use the `json_schema` package:

```dart
import 'package:json_schema/json_schema.dart';

final schema = JsonSchema.create(schemaJson);
final isValid = schema.validate(eventJson);
```

See `test/unit/event_schema_validation_test.dart` for automated validation tests.

---

## Sampling and Performance Metadata

### Sampling Strategies by Event Type

| Event Type | Sampling Strategy | Cadence | Rationale |
|------------|-------------------|---------|-----------|
| CreatePathEvent | None (discrete) | Single event | Lifecycle marker |
| AddAnchorEvent | Time-based | 16ms (~60 FPS) | Balance fidelity vs event volume |
| FinishPathEvent | None (discrete) | Single event | Lifecycle marker |
| ModifyAnchorEvent | Time-based | 16ms (~60 FPS) | Balance fidelity vs event volume |
| MoveObjectEvent | Time-based | 16ms (~60 FPS) | Balance fidelity vs event volume |
| CreateShapeEvent | None (discrete) | Single event | Atomic creation |
| DeleteObjectEvent | None (discrete) | Single event | Atomic deletion |
| ModifyStyleEvent | Debounced | On release | User expects final value only |
| SelectObjectsEvent | None (discrete) | Single event | Selection is atomic |
| DeselectObjectsEvent | None (discrete) | Single event | Selection is atomic |
| ClearSelectionEvent | None (discrete) | Single event | Selection is atomic |
| ViewportPanEvent | Time-based | 16ms (~60 FPS) | Balance smoothness vs event volume |
| ViewportZoomEvent | Change-based | > 5% delta | Significant changes only |
| ViewportResetEvent | None (discrete) | Single event | Atomic operation |
| SaveDocumentEvent | None (discrete) | Single event | Lifecycle marker |
| LoadDocumentEvent | None (discrete) | Single event | Lifecycle marker |
| DocumentLoadedEvent | None (discrete) | Single event | Lifecycle marker |

### Replay Performance Targets

- **Target**: 10,000 events replay in < 1 second
- **Snapshot frequency**: Every 1,000 events (reduces replay to ~50ms)
- **Single event overhead**: < 0.1ms
- **Viewport event tolerance**: Negative/zero factors allowed for edge cases

---

## Schema Evolution and Upgrade Strategy

### Versioning Approach

WireTuner uses **schema-per-version** strategy:

1. **Current schema**: `event_payload.schema.json` (no version suffix = latest)
2. **Future schemas**: `event_payload.v2.schema.json`, etc.
3. **Backward compatibility**: Old events remain valid indefinitely

### Adding New Event Types

To add a new event type:

1. Add event class to appropriate `*_events.dart` file using Freezed
2. Register in `lib/api/event_schema.dart`:
   - Add to `eventFromJson()` switch statement
   - Add to `validEventTypes` list
3. Update `docs/specs/event_payload.schema.json`:
   - Add new `$defs` entry for the event
   - Add reference to root `oneOf` array
4. Update this document with event specification
5. Add validation tests in `test/unit/event_schema_validation_test.dart`

### Adding Fields to Existing Events

**Breaking changes** (adding required fields):
1. Create new event type (e.g., `CreatePathEventV2`)
2. Maintain backward compatibility for old event type
3. Update schema with both versions

**Non-breaking changes** (adding optional fields):
1. Add optional field to Freezed class
2. Update schema with new optional property
3. Update documentation
4. Tests must fail when schema is not updated (acceptance criteria)

### Schema Validation in CI/CD

Include in continuous integration:

```bash
# Validate schema syntax
npm exec ajv compile -s docs/specs/event_payload.schema.json

# Validate all event fixtures
npm exec ajv validate -s docs/specs/event_payload.schema.json -d "test/fixtures/events/*.json"

# Run Dart validation tests
flutter test test/unit/event_schema_validation_test.dart
```

### Migration Tools

For schema upgrades requiring migration:

1. **Event transformer functions**: Map old event format to new
2. **Schema migration scripts**: Batch-update SQLite event log
3. **Versioned deserializers**: Route to appropriate parser by schema version marker

---

## References

- **JSON Schema Specification**: [Draft 2020-12](https://json-schema.org/draft/2020-12/json-schema-core.html)
- **Event Lifecycle**: [event_lifecycle.md](./event_lifecycle.md)
- **Architecture**: [System Structure and Data](../../.codemachine/artifacts/architecture/03_System_Structure_and_Data.md)
- **Source Code**: [lib/api/event_schema.dart](../../lib/api/event_schema.dart)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-07
**Maintainer**: WireTuner Development Team
