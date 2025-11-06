# Event Types Reference

This document describes all event types in the WireTuner event sourcing system. Events are immutable records of user actions that modify the document state. They are persisted to SQLite and can be replayed to reconstruct or time-travel through document history.

## Table of Contents

- [Common Fields](#common-fields)
- [Path Events](#path-events)
  - [CreatePathEvent](#createpathevent)
  - [AddAnchorEvent](#addanchorevent)
  - [FinishPathEvent](#finishpathevent)
  - [ModifyAnchorEvent](#modifyanchorevent)
- [Object Events](#object-events)
  - [MoveObjectEvent](#moveobjectevent)
  - [CreateShapeEvent](#createshapeevent)
- [Style Events](#style-events)
  - [ModifyStyleEvent](#modifystyleevent)
- [Supporting Types](#supporting-types)
  - [Point](#point)
  - [AnchorType](#anchortype)
  - [ShapeType](#shapetype)

---

## Common Fields

All events extend `EventBase` and include these required fields:

| Field | Type | Description |
|-------|------|-------------|
| `eventId` | String | Unique identifier for this event (UUID or timestamp-based) |
| `timestamp` | int | Unix timestamp in milliseconds when the event was created |
| `eventType` | String | Discriminator for polymorphic deserialization (matches class name) |

---

## Path Events

Events related to creating and modifying vector paths using the pen tool.

### CreatePathEvent

Creates a new path with an initial anchor point.

**Usage:** Dispatched when the user starts drawing a path with the pen tool.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `pathId`: String - Unique identifier for the new path
- `startAnchor`: Point - Initial anchor position

**Optional Fields:**
- `fillColor`: String? - Fill color (hex format, e.g., "#FF5733")
- `strokeColor`: String? - Stroke color (hex format)
- `strokeWidth`: double? - Stroke width in pixels
- `opacity`: double? - Opacity (0.0 to 1.0)

**Example JSON:**
```json
{
  "eventType": "CreatePathEvent",
  "eventId": "evt_001",
  "timestamp": 1699305600000,
  "pathId": "path_001",
  "startAnchor": {"x": 100.0, "y": 200.0},
  "fillColor": "#FF5733",
  "strokeColor": "#000000",
  "strokeWidth": 2.0,
  "opacity": 1.0
}
```

---

### AddAnchorEvent

Adds an anchor point to an existing path.

**Usage:** Dispatched when the user adds a new point while drawing a path.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `pathId`: String - ID of the path to modify
- `position`: Point - Position of the new anchor

**Optional Fields:**
- `anchorType`: AnchorType - Type of anchor (default: `line`)
- `handleIn`: Point? - Incoming Bezier control handle (for `bezier` anchors)
- `handleOut`: Point? - Outgoing Bezier control handle (for `bezier` anchors)

**Example JSON (Line Anchor):**
```json
{
  "eventType": "AddAnchorEvent",
  "eventId": "evt_002",
  "timestamp": 1699305601000,
  "pathId": "path_001",
  "position": {"x": 150.0, "y": 250.0},
  "anchorType": "line"
}
```

**Example JSON (Bezier Anchor):**
```json
{
  "eventType": "AddAnchorEvent",
  "eventId": "evt_003",
  "timestamp": 1699305602000,
  "pathId": "path_001",
  "position": {"x": 200.0, "y": 300.0},
  "anchorType": "bezier",
  "handleIn": {"x": 190.0, "y": 290.0},
  "handleOut": {"x": 210.0, "y": 310.0}
}
```

---

### FinishPathEvent

Marks a path as complete.

**Usage:** Dispatched when the user finishes drawing a path (double-click, press Enter, etc.).

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `pathId`: String - ID of the path to finish

**Optional Fields:**
- `closed`: bool - Whether the path is closed (default: `false`)

**Example JSON:**
```json
{
  "eventType": "FinishPathEvent",
  "eventId": "evt_004",
  "timestamp": 1699305603000,
  "pathId": "path_001",
  "closed": true
}
```

---

### ModifyAnchorEvent

Modifies properties of an existing anchor point.

**Usage:** Dispatched when the user moves an anchor, adjusts its handles, or converts it between line and Bezier types.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `pathId`: String - ID of the path containing the anchor
- `anchorIndex`: int - Zero-based index of the anchor in the path

**Optional Fields (at least one must be provided):**
- `position`: Point? - New position of the anchor
- `handleIn`: Point? - New incoming Bezier control handle
- `handleOut`: Point? - New outgoing Bezier control handle
- `anchorType`: AnchorType? - New anchor type

**Example JSON:**
```json
{
  "eventType": "ModifyAnchorEvent",
  "eventId": "evt_005",
  "timestamp": 1699305604000,
  "pathId": "path_001",
  "anchorIndex": 1,
  "position": {"x": 155.0, "y": 255.0},
  "handleIn": {"x": 145.0, "y": 245.0},
  "handleOut": {"x": 165.0, "y": 265.0},
  "anchorType": "bezier"
}
```

---

## Object Events

Events that apply to multiple object types (paths, shapes, etc.).

### MoveObjectEvent

Moves one or more objects by a delta offset.

**Usage:** Dispatched when the user drags objects with the selection tool.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `objectIds`: List<String> - IDs of objects to move
- `delta`: Point - Offset to apply to each object's position

**Example JSON:**
```json
{
  "eventType": "MoveObjectEvent",
  "eventId": "evt_006",
  "timestamp": 1699305605000,
  "objectIds": ["path_001", "shape_002", "path_003"],
  "delta": {"x": 10.0, "y": -5.0}
}
```

---

### CreateShapeEvent

Creates a parametric shape (rectangle, ellipse, star, polygon).

**Usage:** Dispatched when the user creates a shape using one of the shape tools.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `shapeId`: String - Unique identifier for the new shape
- `shapeType`: ShapeType - Type of shape to create
- `parameters`: Map<String, double> - Shape-specific parameters (see examples below)

**Optional Fields:**
- `fillColor`: String? - Fill color (hex format)
- `strokeColor`: String? - Stroke color (hex format)
- `strokeWidth`: double? - Stroke width in pixels
- `opacity`: double? - Opacity (0.0 to 1.0)

**Example JSON (Rectangle):**
```json
{
  "eventType": "CreateShapeEvent",
  "eventId": "evt_007",
  "timestamp": 1699305606000,
  "shapeId": "shape_001",
  "shapeType": "rectangle",
  "parameters": {
    "x": 50.0,
    "y": 50.0,
    "width": 200.0,
    "height": 100.0,
    "cornerRadius": 10.0
  },
  "fillColor": "#FF5733",
  "strokeColor": "#000000",
  "strokeWidth": 2.0
}
```

**Example JSON (Ellipse):**
```json
{
  "eventType": "CreateShapeEvent",
  "eventId": "evt_008",
  "timestamp": 1699305607000,
  "shapeId": "shape_002",
  "shapeType": "ellipse",
  "parameters": {
    "centerX": 100.0,
    "centerY": 100.0,
    "radiusX": 50.0,
    "radiusY": 30.0
  },
  "fillColor": "#3498DB"
}
```

**Example JSON (Star):**
```json
{
  "eventType": "CreateShapeEvent",
  "eventId": "evt_009",
  "timestamp": 1699305608000,
  "shapeId": "shape_003",
  "shapeType": "star",
  "parameters": {
    "centerX": 300.0,
    "centerY": 200.0,
    "outerRadius": 50.0,
    "innerRadius": 25.0,
    "points": 5.0
  },
  "fillColor": "#FFD700"
}
```

---

## Style Events

Events that modify visual properties of objects.

### ModifyStyleEvent

Changes the visual style properties of an object.

**Usage:** Dispatched when the user modifies an object's appearance using the properties panel.

**Required Fields:**
- `eventId`: String
- `timestamp`: int
- `objectId`: String - ID of the object to modify

**Optional Fields (at least one must be provided):**
- `fillColor`: String? - New fill color (hex format)
- `strokeColor`: String? - New stroke color (hex format)
- `strokeWidth`: double? - New stroke width in pixels
- `opacity`: double? - New opacity (0.0 to 1.0)

**Example JSON:**
```json
{
  "eventType": "ModifyStyleEvent",
  "eventId": "evt_010",
  "timestamp": 1699305609000,
  "objectId": "path_001",
  "fillColor": "#FF5733",
  "strokeColor": "#000000",
  "strokeWidth": 3.0,
  "opacity": 0.8
}
```

---

## Supporting Types

### Point

Represents a 2D coordinate.

**Fields:**
- `x`: double - X coordinate
- `y`: double - Y coordinate

**JSON Format:**
```json
{"x": 100.0, "y": 200.0}
```

---

### AnchorType

Enum representing the type of anchor point in a path.

**Values:**
- `line` - Linear anchor with no curve handles
- `bezier` - Bezier anchor with control handles for curves

**JSON Format:** Serialized as string (e.g., `"line"`, `"bezier"`)

---

### ShapeType

Enum representing the type of parametric shape.

**Values:**
- `rectangle` - Rectangle with optional corner radius
- `ellipse` - Ellipse with X and Y radii
- `star` - Star with configurable points and radii
- `polygon` - Regular polygon with configurable sides

**JSON Format:** Serialized as string (e.g., `"rectangle"`, `"ellipse"`)

---

## Event Flow Patterns

### Creating a Path

Typical event sequence when a user creates a path:

1. **CreatePathEvent** - User clicks to start path
2. **AddAnchorEvent** - User adds second point
3. **AddAnchorEvent** - User adds third point (repeat as needed)
4. **FinishPathEvent** - User finishes the path

### Moving Objects

1. **MoveObjectEvent** - User drags one or more selected objects

### Modifying a Path

1. **ModifyAnchorEvent** - User adjusts anchor position or handles
2. **ModifyStyleEvent** - User changes fill/stroke properties

### Creating and Styling a Shape

1. **CreateShapeEvent** - User draws a shape
2. **ModifyStyleEvent** - User changes the shape's appearance

---

## Polymorphic Deserialization

Use the `eventFromJson()` function from `api/event_schema.dart` to deserialize events polymorphically:

```dart
import 'package:wiretuner/api/event_schema.dart' as event_schema;

final json = {
  'eventType': 'CreatePathEvent',
  'eventId': 'evt_001',
  'timestamp': 1699305600000,
  'pathId': 'path_001',
  'startAnchor': {'x': 100.0, 'y': 200.0},
};

final event = event_schema.eventFromJson(json);
// Returns a CreatePathEvent instance
```

The `eventType` field is used as a discriminator to dispatch to the correct event class's `fromJson` constructor.

---

## Notes

- All events are **immutable** - once created, their fields cannot be changed.
- Events are stored as JSON in the SQLite `events` table.
- Event replay is deterministic - replaying the same event sequence always produces the same document state.
- High-frequency events (e.g., during drag operations) should be throttled to ~50ms intervals to avoid overwhelming the event log.
