# Pen Tool Reference

**Tool ID:** `pen`
**Version:** 1.1 (Enhanced with Bezier handles)
**Iteration:** I3.T6, I3.T7
**Status:** Implemented

---

## Overview

The Pen Tool enables creation of vector paths with precise control over straight lines and Bezier curves. Users can create complex shapes by placing anchor points, dragging out curve handles during placement, and adjusting handles after creation. The tool supports both straight-line segments and curved segments with full control over Bezier control points (BCPs).

**Key Capabilities:**
- Click to place straight-line anchor points
- Drag to create Bezier curve anchors with handles
- Symmetrical handles by default (smooth curves)
- Corner/independent handles with Alt modifier
- Angle constraints with Shift modifier (45° increments)
- Handle adjustment mode for refining curves
- Path closing by clicking on first anchor
- Double-click or Enter to finish path creation
- Escape to cancel path creation

---

## Table of Contents

- [Usage](#usage)
- [Interaction Modes](#interaction-modes)
- [Keyboard Modifiers](#keyboard-modifiers)
- [Path Creation Workflow](#path-creation-workflow)
- [Handle Behavior](#handle-behavior)
- [Event Emission](#event-emission)
- [Visual Feedback](#visual-feedback)
- [Technical Details](#technical-details)

---

## Usage

### Activation

The Pen Tool is activated via the tool manager:

```dart
toolManager.activateTool('pen');
```

### Basic Workflow

1. **Activate the Pen Tool** (default: `P` key)
2. **Click** to place anchor points for straight lines
3. **Drag** from an anchor position to create curves with handles
4. **Finish** the path by double-clicking, pressing Enter, or clicking the first anchor (to close)
5. **Cancel** with Escape key if needed

---

## Interaction Modes

### 1. Straight Line Anchors (Click)

**Purpose:** Create paths with sharp corners and straight segments.

**Interaction:**
1. Click at the desired anchor position
2. Immediately release without dragging
3. Continue placing subsequent anchors

**Behavior:**
- Creates an anchor with `anchorType: line`
- No Bezier handles are generated
- Segment from previous anchor to this anchor is a straight line
- Shift key constrains anchor position to 45° angles from previous anchor

**Use Case:**
Creating geometric shapes, polygons, or technical diagrams with precise straight edges.

---

### 2. Bezier Curve Anchors (Drag)

**Purpose:** Create smooth, flowing curves with precise control over curvature.

**Interaction:**
1. Click at the desired anchor position
2. **Drag** at least 5 world units (drag threshold) before releasing
3. Release to commit the anchor with handles
4. Continue placing subsequent anchors

**Behavior:**
- Creates an anchor with `anchorType: bezier`
- Generates two handles: `handleIn` and `handleOut`
- Handle positions are stored as **relative offsets** from the anchor position
- By default, creates **symmetrical handles** (handleIn = -handleOut) for smooth curves
- Shift key constrains handle angle to 45° increments (0°, 45°, 90°, 135°, 180°, etc.)
- Alt key creates **independent handles** (handleIn = null) for corner anchors

**Mathematical Representation:**
```dart
// Anchor at position (x, y)
// User drags to (x + dx, y + dy)
handleOut = Point(x: dx, y: dy)         // Relative offset
handleIn  = Point(x: -dx, y: -dy)       // Mirrored for smooth curve
```

**Use Case:**
Creating organic shapes, character outlines, logos, or any artwork requiring smooth curves.

---

### 3. Handle Adjustment Mode

**Purpose:** Refine curve handles after anchor placement without creating new anchors.

**Interaction:**
1. After placing a curve anchor, **click on that same anchor**
2. Drag to adjust the handle direction and magnitude
3. Release to commit the adjustment

**Behavior:**
- Enters `adjustingHandles` state for the last placed anchor
- Emits `ModifyAnchorEvent` instead of creating a new anchor
- Supports same modifiers as initial handle creation (Alt for independent, Shift for angle constraint)
- Returns to normal `creatingPath` state after release

**Use Case:**
Fine-tuning curve shapes immediately after placement without finishing the path.

---

## Keyboard Modifiers

All keyboard modifiers work during both initial handle creation and handle adjustment.

### Shift - Angle Constraint

**Function:** Constrains handle angles to 45° increments (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)

**When to Use:**
- Creating perfectly horizontal or vertical curves
- Aligning handles to diagonal angles
- Maintaining consistent curve directions across multiple anchors

**Visual Effect:**
- Handle snaps to nearest 45° angle from anchor position
- Handle length is preserved, only direction is constrained
- Works for both straight-line anchor positioning and Bezier handle direction

**Example:**
```
User drags to 30° angle → Snaps to 0° (horizontal)
User drags to 50° angle → Snaps to 45° (diagonal)
User drags to 95° angle → Snaps to 90° (vertical)
```

---

### Alt (Option) - Independent Handles

**Function:** Creates corner/independent handles instead of symmetrical handles

**When to Use:**
- Creating sharp direction changes (cusps) in a curve
- Connecting a curve to a straight segment
- Creating asymmetric curves with different in/out curvatures

**Behavior:**
- **Without Alt:** `handleIn = -handleOut` (symmetrical, smooth curve)
- **With Alt:** `handleIn = null` (independent handles, allows corner)

**Visual Effect:**
- Only the outgoing handle (handleOut) is created during drag
- Incoming handle (handleIn) is not constrained to mirror the outgoing handle
- Subsequent anchors can create their own independent incoming handles

**Example Use Case:**
Creating a teardrop shape where the tip has a sharp point (corner anchor) but the body is smooth (symmetrical anchors).

---

### Modifier Combinations

| Keys Pressed | Effect on Handle Creation |
|--------------|---------------------------|
| *None* | Smooth curve, symmetrical handles, free angle |
| Shift | Smooth curve, symmetrical handles, angle constrained to 45° |
| Alt | Corner anchor, independent handles, free angle |
| Shift + Alt | Corner anchor, independent handles, angle constrained to 45° |

---

## Path Creation Workflow

### Starting a Path

**First Click:**
1. Click at the starting position
2. Emits `StartGroupEvent` (begins undo group)
3. Emits `CreatePathEvent` with the first anchor position
4. Tool enters `creatingPath` state

**Default Styling:**
- Stroke color: `#000000` (black)
- Stroke width: `2.0` pixels
- No fill by default

---

### Adding Anchors

**Subsequent Clicks/Drags:**
- Emit `AddAnchorEvent` for each new anchor
- Anchor type determined by drag distance:
  - `< 5.0` world units → `AnchorType.line` (straight)
  - `≥ 5.0` world units → `AnchorType.bezier` (curve)

---

### Finishing a Path

The pen tool provides three ways to complete path creation:

#### 1. Double-Click
**Action:** Click at the same position twice within 500ms

**Behavior:**
- Creates final anchor if second click is in a new position
- Emits `FinishPathEvent` with `closed: false`
- Emits `EndGroupEvent` to close undo group
- Tool returns to `idle` state

---

#### 2. Press Enter
**Action:** Press the Enter key while creating a path

**Behavior:**
- Completes the path as an open path
- Does NOT add an additional anchor
- Emits `FinishPathEvent` with `closed: false`
- Emits `EndGroupEvent`
- Tool returns to `idle` state

---

#### 3. Close Path (Click First Anchor)
**Action:** Click on the first anchor position

**Behavior:**
- Path must have at least 3 anchors to close
- Click within 10 world units of first anchor
- Creates a closed path connecting last anchor to first
- Emits `FinishPathEvent` with `closed: true`
- Emits `EndGroupEvent`
- Tool returns to `idle` state

**Use Case:**
Creating closed shapes like polygons, irregular outlines, or enclosed areas.

---

### Canceling a Path

**Action:** Press the Escape key while creating a path

**Behavior:**
- Emits `EndGroupEvent` to close undo group
- Does NOT emit `FinishPathEvent` (incomplete path ignored by event handlers)
- Tool returns to `idle` state
- All anchors placed so far are discarded

---

## Handle Behavior

### Symmetrical Handles (Default)

**Characteristics:**
- `handleIn = -handleOut` (exact mirror)
- Both handles have equal length
- Opposite directions (180° apart)
- Creates smooth, continuous curves through anchor points
- Known as "smooth" anchors in design tools like Illustrator

**Mathematical Constraint:**
```dart
if handleOut = (dx, dy)
then handleIn = (-dx, -dy)
```

**Curve Continuity:**
Provides **C1 continuity** (continuous first derivative) at the anchor point, ensuring visually smooth curves.

---

### Independent Handles (Alt Modifier)

**Characteristics:**
- `handleIn = null` during creation
- Only `handleOut` is set
- Allows asymmetric curves or sharp corners
- Known as "corner" anchors in design tools

**Use Cases:**
1. **Cusps:** Sharp direction changes (e.g., teardrop tip)
2. **Curve-to-Line Transitions:** Smoothly entering/exiting straight segments
3. **Asymmetric Curves:** Different curvature on each side of anchor

**Curve Continuity:**
Provides **C0 continuity** (positional continuity only) at the anchor point, allowing directional discontinuities.

---

### Handle Storage Format

Handles are stored as **relative offsets** from the anchor position, not absolute world coordinates.

**Rationale:**
1. **Coordinate-System Independence:** Events replay correctly regardless of viewport pan/zoom
2. **Transformation Invariance:** Handles scale correctly when paths are transformed
3. **Storage Efficiency:** Smaller JSON payloads
4. **Geometric Clarity:** Handle length and angle are immediately apparent

**Example:**
```json
{
  "eventType": "AddAnchorEvent",
  "position": {"x": 200.0, "y": 150.0},
  "anchorType": "bezier",
  "handleOut": {"x": 50.0, "y": -30.0},     // Relative to anchor
  "handleIn": {"x": -50.0, "y": 30.0}       // Relative to anchor
}
```

---

## Event Emission

### Event Sequence

Typical event sequence for creating a 3-anchor path with curves:

```
1. StartGroupEvent (groupId: "pen-tool-abc123")
2. CreatePathEvent (pathId: "path_001", startAnchor: {x: 100, y: 100})
3. AddAnchorEvent (pathId: "path_001", position: {x: 200, y: 150}, anchorType: bezier, handleOut: {x: 50, y: -30}, handleIn: {x: -50, y: 30})
4. AddAnchorEvent (pathId: "path_001", position: {x: 300, y: 100}, anchorType: bezier, handleOut: {x: 40, y: 20}, handleIn: {x: -40, y: -20})
5. FinishPathEvent (pathId: "path_001", closed: false)
6. EndGroupEvent (groupId: "pen-tool-abc123")
```

---

### Event Sampling

**Drag Threshold:** 5.0 world units

**Purpose:**
- Prevent unintentional curve creation from hand jitter/tremor
- Distinguish intentional drags from quick clicks
- Improve user experience on trackpads and tablets

**Implementation:**
```dart
final dragDistance = sqrt((dx * dx) + (dy * dy));
if (dragDistance < 5.0) {
  _addStraightLineAnchor();  // Treat as click
} else {
  _addBezierAnchor();        // Treat as drag
}
```

---

### Undo Grouping

**Granularity:** Entire path creation is one undo action

**Behavior:**
- All events from `StartGroupEvent` to `EndGroupEvent` share the same `groupId`
- Pressing Undo removes the entire path atomically
- Canceled paths (Escape) still emit `EndGroupEvent` to close the group

**Rationale:**
Users expect "Undo" to remove the whole path they just drew, not just the last anchor.

---

## Visual Feedback

The pen tool provides real-time visual feedback through an overlay painter.

### Preview Overlay Components

1. **Last Anchor Indicator:**
   - Small circle at the last placed anchor position
   - Helps user orient to path endpoint

2. **Segment Preview Line:**
   - Dashed line from last anchor to current hover position
   - Shows where next segment will be placed
   - Updates in real-time as cursor moves

3. **Handle Preview (During Drag):**
   - Shows handle direction and length during drag gesture
   - Displays both `handleIn` and `handleOut` if symmetrical
   - Only shows `handleOut` if Alt is pressed (independent handles)

4. **First Anchor Highlight (Close Mode):**
   - When hovering near first anchor with 3+ anchors placed
   - Visual indicator that clicking will close the path

---

### Overlay Integration

The pen tool exposes preview state via the `previewState` getter:

```dart
final painter = PenPreviewOverlayPainter(
  state: penTool.previewState,
  viewportController: viewportController,
);
```

This state is consumed by the canvas overlay layer to render visual feedback without coupling rendering logic to tool state management.

---

## Technical Details

### Coordinate Systems

**Screen Coordinates:**
- Flutter pointer events (PointerDownEvent, PointerMoveEvent) use screen-space pixels
- Origin at top-left of widget
- Affected by viewport pan and zoom

**World Coordinates:**
- All event payloads use world-space coordinates
- Origin at document's world space origin
- Independent of viewport transformations
- Conversion: `_viewportController.screenToWorld(event.localPosition)`

**Critical Requirement:**
All geometry math (distance calculations, angle constraints, handle offsets) must be performed in **world coordinates** for deterministic event replay.

---

### Drag Threshold (5.0 World Units)

**Purpose:**
Differentiate clicks from drags to prevent unintended curve creation.

**Implementation:**
```dart
final dragDistance = _calculateDistance(
  _dragStartPosition!,
  _currentDragPosition ?? _dragStartPosition!,
);

if (dragDistance < 5.0) {
  _addStraightLineAnchor();
} else {
  _addBezierAnchor();
}
```

**Why 5.0?**
- Large enough to filter out jitter from trackpads/mice
- Small enough that intentional curves are detected
- Perceptually invisible threshold (< 10 screen pixels at typical zoom levels)

---

### Angle Constraint Algorithm (Shift Key)

**Snap Increments:** π/4 radians (45°)

**Implementation:**
```dart
Point _constrainToAngle(Point from, Point to) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;

  // Calculate angle and distance
  final angle = atan2(dy, dx);
  final distance = sqrt(dx * dx + dy * dy);

  // Snap to nearest 45° increment
  const increment = pi / 4;  // 45 degrees
  final snappedAngle = (angle / increment).round() * increment;

  // Reconstruct position at snapped angle
  final constrainedX = from.x + cos(snappedAngle) * distance;
  final constrainedY = from.y + sin(snappedAngle) * distance;

  return Point(x: constrainedX, y: constrainedY);
}
```

**Key Properties:**
- Preserves distance (handle length)
- Only modifies direction (angle)
- Rounds to nearest increment (not floor/ceil)

---

### Double-Click Detection

**Thresholds:**
- **Time:** 500 milliseconds between clicks
- **Distance:** 10.0 world units spatial tolerance

**Implementation:**
```dart
bool _isDoubleClick(Point worldPos, int timestamp) {
  if (_lastClickTime == null || _lastClickPosition == null) {
    return false;
  }

  final timeDelta = timestamp - _lastClickTime!;
  final distance = _calculateDistance(_lastClickPosition!, worldPos);

  return timeDelta <= 500 && distance <= 10.0;
}
```

**Rationale:**
- 500ms is standard OS double-click threshold
- 10.0 world units allows for slight mouse movement between clicks

---

### Path Closing Detection

**Requirements:**
- Path must have at least 3 anchors (minimum for closed shape)
- Click within 10.0 world units of first anchor
- Same distance threshold as double-click for consistency

**Implementation:**
```dart
bool _isClickOnFirstAnchor(Point worldPos) {
  if (_firstAnchorPosition == null || _anchorCount < 3) {
    return false;
  }

  final distance = _calculateDistance(worldPos, _firstAnchorPosition!);
  return distance < 10.0;
}
```

---

### State Machine

The pen tool implements a simple state machine:

```
┌─────┐  activate   ┌──────────────┐  first click   ┌───────────────┐
│ Idle├────────────►│ Idle (armed) ├───────────────►│ Creating Path │
└─────┘             └──────────────┘                 └───────┬───────┘
                                                             │
                              ┌──────────────────────────────┘
                              │ click on last anchor
                              ▼
                    ┌──────────────────┐
                    │ Adjusting Handles│
                    └─────────┬────────┘
                              │ pointer up
                              ▼
                    ┌──────────────────┐
                    │  Creating Path   │◄──────────┐
                    └─────────┬────────┘           │
                              │                    │
                              │ add anchor         │ (loop)
                              └────────────────────┘
                              │
                              │ finish (Enter, double-click, or close)
                              ▼
                         ┌─────┐
                         │ Idle│
                         └─────┘
```

**States:**
1. **Idle:** No active path, waiting for first click
2. **Creating Path:** Active path, accepting new anchors
3. **Adjusting Handles:** Temporarily adjusting handles on last anchor

---

## Performance Characteristics

### Event Volume

**Typical Path (10 anchors):**
- StartGroupEvent: 1
- CreatePathEvent: 1
- AddAnchorEvent: 9
- FinishPathEvent: 1
- EndGroupEvent: 1
- **Total:** 13 events

**Memory Footprint:**
- ~200 bytes per anchor (JSON)
- ~2 KB for typical path
- Handles stored as doubles (8 bytes × 4 = 32 bytes per Bezier anchor)

---

### Rendering Performance

**Overlay Refresh:**
- Updates on every `onPointerMove` event (~60 FPS)
- Lightweight: only repaints overlay, not full canvas
- Uses CustomPainter for efficient partial repaints

**Path Rendering:**
- Bezier curves rendered using Flutter's native `Path.cubicTo()`
- GPU-accelerated on supported platforms
- No performance degradation up to ~10,000 anchors per path (typical use case: < 100)

---

## Examples

### Creating a Simple Curve

```dart
// User workflow:
// 1. Activate pen tool
// 2. Click at (100, 100) - first anchor
// 3. Click-drag from (200, 100) to (250, 80) - curve anchor
// 4. Click at (300, 100) - straight anchor
// 5. Press Enter to finish

// Events emitted:
StartGroupEvent(groupId: "pen-tool-abc123")
CreatePathEvent(pathId: "path_001", startAnchor: {x: 100, y: 100})
AddAnchorEvent(
  pathId: "path_001",
  position: {x: 200, y: 100},
  anchorType: bezier,
  handleOut: {x: 50, y: -20},
  handleIn: {x: -50, y: 20}
)
AddAnchorEvent(
  pathId: "path_001",
  position: {x: 300, y: 100},
  anchorType: line
)
FinishPathEvent(pathId: "path_001", closed: false)
EndGroupEvent(groupId: "pen-tool-abc123")
```

---

### Creating a Closed Triangle

```dart
// User workflow:
// 1. Click at (100, 100) - first anchor
// 2. Click at (200, 100) - second anchor
// 3. Click at (150, 50) - third anchor
// 4. Click on first anchor (100, 100) to close

// Events emitted:
StartGroupEvent(groupId: "pen-tool-xyz789")
CreatePathEvent(pathId: "path_002", startAnchor: {x: 100, y: 100})
AddAnchorEvent(pathId: "path_002", position: {x: 200, y: 100}, anchorType: line)
AddAnchorEvent(pathId: "path_002", position: {x: 150, y: 50}, anchorType: line)
FinishPathEvent(pathId: "path_002", closed: true)  // Note: closed = true
EndGroupEvent(groupId: "pen-tool-xyz789")
```

---

### Using Shift and Alt Modifiers

```dart
// User workflow:
// 1. Click at (100, 100) - first anchor
// 2. Hold Shift, click-drag from (200, 100) to (250, 120)
//    → Handle angle snaps to 0° (horizontal)
// 3. Hold Alt, click-drag from (300, 150) to (320, 180)
//    → Creates corner anchor with independent handles
// 4. Press Enter to finish

// Events emitted:
StartGroupEvent(groupId: "pen-tool-mod123")
CreatePathEvent(pathId: "path_003", startAnchor: {x: 100, y: 100})
AddAnchorEvent(
  pathId: "path_003",
  position: {x: 200, y: 100},
  anchorType: bezier,
  handleOut: {x: 56.57, y: 0.0},     // Snapped to horizontal (0°)
  handleIn: {x: -56.57, y: 0.0}      // Symmetric
)
AddAnchorEvent(
  pathId: "path_003",
  position: {x: 300, y: 150},
  anchorType: bezier,
  handleOut: {x: 20, y: 30},         // Independent handles
  handleIn: null                      // No incoming handle (corner)
)
FinishPathEvent(pathId: "path_003", closed: false)
EndGroupEvent(groupId: "pen-tool-mod123")
```

---

## Keyboard Shortcuts Summary

| Shortcut | Function | Context |
|----------|----------|---------|
| **Click** | Place straight-line anchor | Always |
| **Click-Drag** | Create Bezier curve anchor | Drag distance ≥ 5 units |
| **Shift** | Constrain angles to 45° | During drag or anchor placement |
| **Alt** | Independent/corner handles | During Bezier curve creation |
| **Shift + Alt** | Constrain angle + independent handles | During Bezier curve creation |
| **Enter** | Finish path (open) | While creating path |
| **Escape** | Cancel path creation | While creating path |
| **Double-Click** | Finish path (open) | While creating path |
| **Click First Anchor** | Close path (closed) | While creating path with 3+ anchors |
| **Click Last Anchor** | Adjust handles | Immediately after placing curve anchor |

---

## Related Documentation

- **Architecture:** [Tool Framework Design](../../.codemachine/artifacts/architecture/04_Behavior_and_Communication.md#tool-framework)
- **Event Schema:** [Path Events Reference](../event_schema.md#pen-tool-events-path-creation)
- **Implementation:** [`lib/application/tools/pen/pen_tool.dart`](../../../lib/application/tools/pen/pen_tool.dart)
- **Tests:** [`test/widget/pen_tool_bezier_test.dart`](../../../test/widget/pen_tool_bezier_test.dart)
- **Vector Model:** [Bezier Curves and Anchors](../vector_model.md)

---

**Document Version:** 1.1
**Last Updated:** 2025-11-09
**Maintainer:** WireTuner Tool Team
**Iteration:** I3.T7
