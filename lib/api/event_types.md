# Event Types Documentation

This document describes all event types in the WireTuner event sourcing system.

## Overview

Events are immutable records of user actions and state changes. They form an append-only log that can be replayed to reconstruct document state. All events extend `EventBase` and include:

- `eventId`: Unique identifier (String)
- `timestamp`: Unix timestamp in milliseconds (int)
- `eventType`: Discriminator for polymorphic deserialization (String)

## Event Hierarchy

```
EventBase (sealed)
├── Path Events
│   ├── CreatePathEvent
│   ├── AddAnchorEvent
│   ├── FinishPathEvent
│   └── ModifyAnchorEvent
├── Object Events
│   ├── MoveObjectEvent
│   └── CreateShapeEvent
└── Style Events
    └── ModifyStyleEvent
```

---

## Path Events

Events related to creating and modifying vector paths.

### CreatePathEvent

Creates a new path with an initial anchor point.

**Usage**: Dispatched when user starts drawing with pen tool

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `pathId` (required): Unique identifier for the new path
- `startAnchor` (required): Initial anchor point (Point with x, y)
- `fillColor` (optional): Fill color as hex string (e.g., "#FF5733")
- `strokeColor` (optional): Stroke color as hex string
- `strokeWidth` (optional): Stroke width in pixels
- `opacity` (optional): Opacity value (0.0 to 1.0)

**Example JSON**:
```json
{
  "eventType": "CreatePathEvent",
  "eventId": "evt_001",
  "timestamp": 1699305600000,
  "pathId": "path_001",
  "startAnchor": {
    "x": 100.0,
    "y": 200.0
  },
  "strokeColor": "#000000",
  "strokeWidth": 2.0,
  "fillColor": null,
  "opacity": 1.0
}
```

**Event Flow**: User clicks → PenTool → CreatePathEvent → EventRecorder → SQLite

---

### AddAnchorEvent

Adds an anchor point to an existing path.

**Usage**: Dispatched when user adds a new point while drawing

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `pathId` (required): ID of the path to modify
- `position` (required): Anchor position (Point with x, y)
- `anchorType` (optional, default: `line`): Type of anchor (`line` or `bezier`)
- `handleIn` (optional): Incoming Bezier control handle (Point)
- `handleOut` (optional): Outgoing Bezier control handle (Point)

**Example JSON**:
```json
{
  "eventType": "AddAnchorEvent",
  "eventId": "evt_002",
  "timestamp": 1699305601000,
  "pathId": "path_001",
  "position": {
    "x": 150.0,
    "y": 250.0
  },
  "anchorType": "bezier",
  "handleIn": {
    "x": 140.0,
    "y": 240.0
  },
  "handleOut": {
    "x": 160.0,
    "y": 260.0
  }
}
```

**Event Flow**: User clicks/drags → PenTool → AddAnchorEvent → EventRecorder → SQLite

---

### FinishPathEvent

Marks a path as complete.

**Usage**: Dispatched when user finishes drawing a path

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `pathId` (required): ID of the path to finish
- `closed` (optional, default: `false`): Whether to close the path

**Example JSON**:
```json
{
  "eventType": "FinishPathEvent",
  "eventId": "evt_003",
  "timestamp": 1699305602000,
  "pathId": "path_001",
  "closed": true
}
```

**Event Flow**: User presses Enter/Esc or clicks start anchor → PenTool → FinishPathEvent

---

### ModifyAnchorEvent

Modifies properties of an existing anchor point.

**Usage**: Dispatched when user moves or adjusts anchor handles

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `pathId` (required): ID of the path containing the anchor
- `anchorIndex` (required): Zero-based index of the anchor to modify
- `position` (optional): New anchor position (Point)
- `handleIn` (optional): New incoming control handle (Point)
- `handleOut` (optional): New outgoing control handle (Point)
- `anchorType` (optional): Change anchor type (`line` or `bezier`)

**Example JSON**:
```json
{
  "eventType": "ModifyAnchorEvent",
  "eventId": "evt_004",
  "timestamp": 1699305603000,
  "pathId": "path_001",
  "anchorIndex": 1,
  "position": {
    "x": 155.0,
    "y": 255.0
  },
  "handleIn": {
    "x": 145.0,
    "y": 245.0
  }
}
```

**Event Flow**: User drags anchor/handle → SelectTool → ModifyAnchorEvent

---

## Object Events

Events related to manipulating objects on the canvas.

### MoveObjectEvent

Moves one or more objects by a delta offset.

**Usage**: Dispatched when user drags selected objects

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `objectIds` (required): List of object IDs to move
- `delta` (required): Movement delta (Point with x, y)

**Example JSON**:
```json
{
  "eventType": "MoveObjectEvent",
  "eventId": "evt_005",
  "timestamp": 1699305604000,
  "objectIds": ["path_001", "shape_002"],
  "delta": {
    "x": 10.0,
    "y": -5.0
  }
}
```

**Event Flow**: User drags selection → SelectTool → (throttled) → MoveObjectEvent

**Note**: High-frequency events like drag are typically throttled to ~50ms intervals.

---

### CreateShapeEvent

Creates a parametric shape (rectangle, ellipse, star, polygon).

**Usage**: Dispatched when user creates a shape with shape tools

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `shapeId` (required): Unique identifier for the new shape
- `shapeType` (required): Type of shape (`rectangle`, `ellipse`, `star`, `polygon`)
- `parameters` (required): Map of shape-specific parameters
  - Rectangle: `width`, `height`, `x`, `y`, `cornerRadius`
  - Ellipse: `centerX`, `centerY`, `radiusX`, `radiusY`
  - Star: `centerX`, `centerY`, `outerRadius`, `innerRadius`, `points`
  - Polygon: `centerX`, `centerY`, `radius`, `sides`
- `fillColor` (optional): Fill color as hex string
- `strokeColor` (optional): Stroke color as hex string
- `strokeWidth` (optional): Stroke width in pixels
- `opacity` (optional): Opacity value (0.0 to 1.0)

**Example JSON** (Rectangle):
```json
{
  "eventType": "CreateShapeEvent",
  "eventId": "evt_006",
  "timestamp": 1699305605000,
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

**Example JSON** (Star):
```json
{
  "eventType": "CreateShapeEvent",
  "eventId": "evt_007",
  "timestamp": 1699305606000,
  "shapeId": "shape_002",
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

**Event Flow**: User drags shape tool → ShapeTool → CreateShapeEvent

---

## Style Events

Events related to modifying visual properties.

### ModifyStyleEvent

Changes the visual style of an object.

**Usage**: Dispatched when user changes fill, stroke, or opacity in style panel

**Fields**:
- `eventId` (required): Unique event identifier
- `timestamp` (required): Event creation time
- `objectId` (required): ID of the object to style
- `fillColor` (optional): New fill color as hex string
- `strokeColor` (optional): New stroke color as hex string
- `strokeWidth` (optional): New stroke width in pixels
- `opacity` (optional): New opacity value (0.0 to 1.0)

**Example JSON**:
```json
{
  "eventType": "ModifyStyleEvent",
  "eventId": "evt_008",
  "timestamp": 1699305607000,
  "objectId": "path_001",
  "fillColor": "#FF5733",
  "strokeWidth": 3.0
}
```

**Event Flow**: User changes style panel → StylePanel → ModifyStyleEvent

**Note**: Only specified fields are modified; others remain unchanged (partial update).

---

## Common Patterns

### Event Sequences

**Creating a Simple Path:**
```
1. CreatePathEvent(pathId: "p1", startAnchor: {x: 0, y: 0})
2. AddAnchorEvent(pathId: "p1", position: {x: 100, y: 0})
3. AddAnchorEvent(pathId: "p1", position: {x: 100, y: 100})
4. FinishPathEvent(pathId: "p1", closed: false)
```

**Drawing and Styling:**
```
1. CreatePathEvent(pathId: "p1", ...)
2. AddAnchorEvent(pathId: "p1", ...)
3. FinishPathEvent(pathId: "p1")
4. ModifyStyleEvent(objectId: "p1", fillColor: "#FF0000")
```

### Serialization Notes

- All events implement `toJson()` and `fromJson(Map<String, dynamic>)`
- Use `eventFromJson()` factory (from `api/event_schema.dart`) for polymorphic deserialization
- Optional fields serialize as `null` when not provided
- The `eventType` field is automatically provided by each class
- Point objects serialize as `{"x": double, "y": double}`
- Enum values serialize as strings (e.g., `"line"`, `"bezier"`)

### Event Replay

Events are replayed in sequence order to reconstruct document state:

```dart
// Pseudocode
final events = await loadEventsFromDatabase(documentId);
var documentState = Document.empty();

for (final eventJson in events) {
  final event = eventFromJson(eventJson);
  documentState = documentState.applyEvent(event);
}
```

---

## Data Types

### Point
```dart
{
  "x": double,  // X coordinate
  "y": double   // Y coordinate
}
```

### AnchorType
- `"line"`: Linear anchor with no curve
- `"bezier"`: Bezier anchor with control handles

### ShapeType
- `"rectangle"`: Rectangle or rounded rectangle
- `"ellipse"`: Ellipse or circle
- `"star"`: Star polygon
- `"polygon"`: Regular polygon

---

## Event Size Guidelines

Typical event sizes (JSON serialized):
- CreatePathEvent: ~150-200 bytes
- AddAnchorEvent: ~200-300 bytes (with handles)
- MoveObjectEvent: ~100-150 bytes
- ModifyStyleEvent: ~100-200 bytes

Storage estimates:
- 1000 events ≈ 150-200 KB
- 10,000 events ≈ 1.5-2 MB
