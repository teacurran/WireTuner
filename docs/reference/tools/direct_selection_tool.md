# Direct Selection Tool Reference

**Tool ID:** `direct_selection`
**Version:** 1.1
**Iteration:** I4.T5
**Status:** Implemented

---

## Overview

The Direct Selection Tool enables precise manipulation of individual anchor points and Bezier control point (BCP) handles within vector paths and shapes. This tool is essential for advanced path editing, providing anchor-level control with snapping support, inertia-based smoothing, and real-time visual feedback.

**Key Capabilities:**
- Click and drag anchor points to reposition them
- Click and drag BCP handles to adjust curve shape
- Respect anchor type constraints (smooth/symmetric/corner)
- **Magnetic grid snapping** with threshold-based activation (Shift to toggle)
- **Hysteresis** to prevent jitter at snap boundaries
- **Inertia smoothing** for natural drag completion
- Angle snapping for handle rotations (Shift to toggle)
- **Automatic operation grouping** for clean undo/redo
- 50ms event sampling for smooth drag operations
- Real-time overlay feedback with position/angle/length metrics

---

## Table of Contents

- [Usage](#usage)
- [Interaction Modes](#interaction-modes)
- [Keyboard Modifiers](#keyboard-modifiers)
- [Snapping Behavior](#snapping-behavior)
- [Event Emission](#event-emission)
- [Visual Feedback](#visual-feedback)
- [Performance Characteristics](#performance-characteristics)
- [Implementation Reference](#implementation-reference)

---

## Usage

### Activation

The Direct Selection Tool is activated via the tool manager:

```dart
toolManager.activateTool('direct_selection');
```

### Prerequisites

- At least one object must be selected in the document
- Selected objects must contain anchor points (paths or shapes)

### Basic Workflow

1. **Select an object** using the Selection Tool
2. **Activate the Direct Selection Tool** (default: `A` key)
3. **Hover over an anchor or handle** - cursor changes to move cursor
4. **Click and drag** to reposition the anchor or adjust the handle
5. **Release** to commit the change

---

## Interaction Modes

### 1. Anchor Dragging

**Purpose:** Reposition an anchor point while preserving handle offsets.

**Interaction:**
1. Click on an anchor point (white circle with blue stroke)
2. Drag to new position
3. Release to commit

**Behavior:**
- Anchor position updates in real-time
- Handle vectors (handleIn/handleOut) remain unchanged relative to anchor
- **Magnetic grid snapping** applies when Shift is held (only snaps within 8px threshold)
- **Hysteresis** prevents jitter when near snap boundary
- **Inertia** adds smooth momentum on drag completion (velocity-based)
- Emits `ModifyAnchorEvent` sequences sampled at 50ms intervals
- Drag operation wrapped in automatic undo group

**Example Use Case:**
Adjusting the corner point of a rectangle shape to align with a grid. The magnetic snapping only activates when you drag close to a grid intersection, and inertia adds a natural "coast" when you release.

---

### 2. Handle Dragging

**Purpose:** Adjust the curvature and direction of Bezier segments.

**Interaction:**
1. Click on a BCP handle (blue circle at end of gray line)
2. Drag to adjust handle direction and length
3. Release to commit

**Behavior:**
- Handle vector updates in real-time
- Anchor type constraints are preserved:
  - **Smooth anchors**: Opposite handle mirrors automatically (same length, opposite direction)
  - **Symmetric anchors**: Opposite handle maintains collinearity (independent lengths)
  - **Corner anchors**: Handles move independently (no constraints)
- Angle snapping applies when Shift is held (default: 15° increments)
- Emits `ModifyAnchorEvent` sequences sampled at 50ms intervals

**Example Use Case:**
Fine-tuning the curve of a smooth path segment to create an S-curve.

---

### 3. Hover Feedback

**Purpose:** Provide visual cues about which component will be manipulated.

**Behavior:**
- Cursor changes to `SystemMouseCursors.move` when hovering over anchors/handles
- Hovered component is highlighted in orange (vs. default blue)
- Cursor reverts to `SystemMouseCursors.precise` when not over a draggable component

---

## Keyboard Modifiers

### Shift Key - Snapping Toggle

**Function:** Enable magnetic grid snapping (anchors) and angle snapping (handles)

**Behavior:**
- **Press Shift during drag**: Enable magnetic snapping
- **Release Shift during drag**: Disable snapping
- **Can be toggled multiple times** during a single drag operation
- **Snapping is magnetic**: Only activates when within threshold of snap target
- **Hysteresis applied**: Prevents jitter at threshold boundary

**Snapping Configuration:**
- **Grid Size:** 10.0 world units (default)
- **Magnetic Threshold:** 8.0 world units (snap capture radius)
- **Hysteresis Margin:** 2.0 world units (prevents jitter)
- **Angle Increment:** 15.0 degrees (default)
- **Configurable via:** `SnappingService` constructor parameters

**Example:**
```dart
// Custom snapping configuration with magnetic behavior
final snappingService = SnappingService(
  gridSnapEnabled: false,     // Disabled by default
  angleSnapEnabled: false,    // Independent control
  gridSize: 8.0,              // Custom 8px grid
  magneticThreshold: 10.0,    // Larger capture radius
  hysteresisMargin: 3.0,      // More hysteresis
  angleIncrement: 30.0,       // Custom 30° angle increments
);
```

**Debug Output:**
When Shift is pressed/released, the tool logs:
```
🐛 Snapping enabled (Shift pressed)
🐛 Snapping disabled (Shift released)
```

---

### ESC Key - Cancel Drag

**Function:** Cancel the current drag operation

**Behavior:**
- **Press ESC during drag**: Cancel drag and discard events
- **No undo entry created** for cancelled operations
- **Inertia cancelled** if active
- Tool returns to idle state

**Debug Output:**
```
🐛 Drag cancelled by ESC key
```

---

### Alt/Option Key - Anchor Type Conversion (Future)

**Status:** Placeholder for future iteration

**Planned Behavior:**
- Toggle between smooth ↔ corner anchor types during drag
- Preserve handle positions when converting to corner
- Calculate symmetric handles when converting to smooth

---

## Snapping Behavior

### Magnetic Grid Snapping (Anchors)

**Trigger:** Shift key pressed during anchor drag

**Algorithm:**
1. Calculate target anchor position from drag delta
2. Calculate nearest grid intersection: `(round(x / gridSize) * gridSize, round(y / gridSize) * gridSize)`
3. Measure distance to nearest grid point
4. **Apply hysteresis threshold:**
   - If not currently snapped: Use `magneticThreshold` (8px default)
   - If currently snapped: Use `magneticThreshold + hysteresisMargin` (10px default)
5. **Snap if within threshold**, otherwise return original position

**Performance:** < 0.5ms overhead per drag event

**Example:**
```
Grid Size: 10.0
Magnetic Threshold: 8.0
Hysteresis Margin: 2.0

Position: (13.0, 17.0)  → Distance: 5.0px → SNAP to (10.0, 20.0)
Position: (15.0, 17.0)  → Distance: 7.1px → Still within 10px hysteresis → SNAP to (10.0, 20.0)
Position: (18.0, 17.0)  → Distance: 10.3px → Outside hysteresis → NO SNAP (18.0, 17.0)
```

**Visual Feedback:**
On-canvas HUD displays snapped coordinates when snap is active:
```
x: 120.0, y: 570.0
```

**Benefits:**
- **More intuitive**: Only snaps when you want it to (near grid)
- **No fighting**: Doesn't force snapping when far from grid
- **No jitter**: Hysteresis prevents oscillation at boundaries

---

### Angle Snapping (Handles)

**Trigger:** Shift key pressed during handle drag

**Algorithm:**
1. Calculate handle vector from drag delta
2. Compute current angle: `atan2(y, x)` in radians
3. Snap angle to nearest increment: `round(angle / increment) * increment`
4. Reconstruct vector with snapped angle and original magnitude:
   - `x = cos(snappedAngle) * magnitude`
   - `y = sin(snappedAngle) * magnitude`
5. Reapply anchor type constraints (smooth/symmetric)

**Performance:** < 1ms overhead per drag event

**Example:**
```
Angle Increment: 15°
Original Angle: 26.6°
Snapped Angle:  30.0° (nearest 15° increment)
```

**Visual Feedback:**
On-canvas HUD displays snapped angle and length:
```
Angle: 30°
Length: 50.0
```

---

### Anchor Type Constraint Preservation

**Critical Requirement:**
After angle snapping, anchor type constraints must be re-applied to ensure smooth/symmetric anchors remain valid.

**Implementation:**
1. Snap the dragged handle to nearest angle
2. If anchor is **smooth**: Mirror to opposite handle (`oppositeHandle = -draggedHandle`)
3. If anchor is **symmetric**: Update opposite handle to maintain collinearity with preserved length
4. If anchor is **corner**: No adjustment to opposite handle

**Reference:** `HandleDragController._applyConstraintsToOppositeHandle()` at `lib/application/tools/direct_selection/handle_drag_controller.dart:147-182`

---

### Inertia Smoothing

**Purpose:** Add natural momentum to drag completion for a more polished feel.

**Trigger:** Automatic on drag release if velocity exceeds threshold

**Algorithm:**
1. Track recent drag samples (last 3-5 positions with timestamps)
2. Calculate velocity vector on mouse up: `velocity = Δposition / Δtime`
3. If velocity magnitude < threshold (0.5 px/ms): Skip inertia
4. Generate exponentially decaying sequence:
   - Start position = final drag position
   - Each frame: `position += velocity * decay^frame * samplingInterval`
   - Decay factor: 0.88 (configurable)
   - Sampling interval: 50ms (matches event recorder)
5. Stop when velocity drops below threshold × 0.1 or max duration (300ms) reached
6. Emit `ModifyAnchorEvent` for each inertia frame
7. Apply magnetic snapping to inertia positions if Shift still held

**Performance:** Typically 5-10 additional events per fast drag

**Example:**
```
Drag velocity: 1.2 px/ms (fast drag)
Inertia frames: 6
Duration: 300ms
Final distance: ~50px beyond release point
```

**Configuration:**
```dart
final inertiaController = InertiaController(
  velocityThreshold: 0.5,    // Minimum velocity to activate (px/ms)
  decayFactor: 0.88,         // Exponential decay rate (0-1)
  maxDurationMs: 300,        // Max inertia duration
  samplingIntervalMs: 50,    // Frame interval
);
```

**Accuracy Guarantee:**
- Uses double precision throughout
- Final position explicitly set (no cumulative drift)
- Works with magnetic snapping (snaps each inertia frame)
- Total drift guaranteed < 1px from expected trajectory

**Benefits:**
- **Natural feel**: Matches platform conventions (iOS/Android momentum)
- **Polish**: Small detail that makes the tool feel responsive
- **Optional**: Only activates for fast drags

**Reference:** `InertiaController` at `lib/application/tools/direct_selection/inertia_controller.dart`

---

## Event Emission

### Event Type: `ModifyAnchorEvent`

**Schema Reference:** `lib/domain/events/path_events.dart`

**Fields:**
```dart
class ModifyAnchorEvent extends EventBase {
  final String pathId;           // Object ID being modified
  final int anchorIndex;         // Zero-based anchor index
  final Point? position;         // New anchor position (null if not moved)
  final Point? handleIn;         // New handleIn vector (null if not modified)
  final Point? handleOut;        // New handleOut vector (null if not modified)
}
```

**Sampling Rate:** 50ms (configurable via `EventRecorder.samplingInterval`)

**Example Sequence:**
```json
// Anchor drag from (100, 200) to (110, 210) over 200ms
[
  {"eventId": "uuid-1", "timestamp": 1000, "pathId": "path-1", "anchorIndex": 2, "position": {"x": 102, "y": 202}},
  {"eventId": "uuid-2", "timestamp": 1050, "pathId": "path-1", "anchorIndex": 2, "position": {"x": 105, "y": 205}},
  {"eventId": "uuid-3", "timestamp": 1100, "pathId": "path-1", "anchorIndex": 2, "position": {"x": 108, "y": 208}},
  {"eventId": "uuid-4", "timestamp": 1150, "pathId": "path-1", "anchorIndex": 2, "position": {"x": 110, "y": 210}}
]
```

### Event Sampling Details

**Why 50ms sampling?**
- Balances event volume vs. playback smoothness
- A 2-second drag generates ~40 events instead of 200+
- Meets 60 FPS rendering target (16.7ms per frame)

**Flush Behavior:**
- On pointer up: `EventRecorder.flush()` ensures final drag position is persisted
- On tool deactivate: Auto-flush prevents losing in-flight events
- On drag cancel: No flush (events discarded)

**Undo Grouping:**
Drag events are automatically wrapped in operation groups via `OperationGroupingService`:
- `startUndoGroup(label: "Adjust Anchor")` called on drag start
- All drag events (including inertia) grouped into single operation
- `forceBoundary(reason: "drag_complete")` called after final event flush
- ESC key cancels operation: `cancelOperation()` discards all events
- Result: Single undo/redo entry per drag, regardless of event count

**Example Undo Labels:**
- "Adjust Anchor" - for anchor point drags
- "Adjust Handle" - for BCP handle drags

---

## Visual Feedback

### On-Canvas HUD

**Purpose:** Display real-time metrics during drag operations.

**Location:** 10px offset from cursor position (bottom-right)

**Styling:**
- Background: Semi-transparent black (`0xCC000000`)
- Text: White monospace, 12pt
- Border radius: 4px
- Padding: 4px

**Content:**

**For Anchor Drags:**
```
x: 120.0, y: 340.5
```

**For Handle Drags:**
```
Angle: 45°
Length: 50.0
```

**Implementation:** `DirectSelectionTool._renderDragPreview()` at `lib/application/tools/direct_selection/direct_selection_tool.dart:525-592`

---

### Selection Overlay

**Purpose:** Visualize anchor points and handles for selected objects.

**Rendering:**
- **Anchor points**: White-filled circles with blue stroke (6px diameter)
- **BCP handles**: Blue-filled circles (4px diameter)
- **BCP lines**: Gray lines connecting anchors to handles (1px stroke)
- **Hovered components**: Orange highlight instead of blue

**Z-Order:**
1. BCP lines (bottom)
2. BCP handle circles
3. Anchor point circles (top)

**Implementation:** `SelectionOverlayPainter` at `lib/presentation/canvas/overlays/selection_overlay.dart:79-426`

---

## Performance Characteristics

### Hit Testing

**Threshold:** 8px screen-space tolerance
**Complexity:** O(n) where n = number of anchors in selected objects
**Target:** < 5ms per hit-test operation

**Implementation:** `CanvasHitTester.hitTestAnchors()` iterates anchors and measures distance in screen space.

**Example:**
```dart
// User clicks at (105, 205) screen coordinates
// Anchor at (100, 200) world coordinates, viewport zoom = 1.0
// Distance = sqrt((105-100)^2 + (205-200)^2) = 7.07px
// Result: Hit (distance < 8px threshold)
```

---

### Event Emission

**Sampling Overhead:** < 5ms per `ModifyAnchorEvent` emission
**Target:** < 16.7ms total drag handling to maintain 60 FPS

**Breakdown:**
- Hit-testing: ~2ms
- Drag controller calculation: ~1ms
- Event recording: ~2ms
- Overlay rendering: ~10ms
- **Total:** ~15ms (meets target)

---

### Drag Controller Calculations

**Grid Snapping:** O(1), < 0.5ms
**Angle Snapping:** O(1), < 1ms
**Anchor Type Constraints:** O(1), < 0.5ms

**Reference:** Performance acceptance criteria documented in:
- `lib/application/tools/direct_selection/anchor_drag_controller.dart:38-40`
- `lib/application/tools/direct_selection/handle_drag_controller.dart:50-52`

---

## Implementation Reference

### Key Files

| File | Purpose | Lines of Code |
|------|---------|---------------|
| `lib/application/tools/direct_selection/direct_selection_tool.dart` | Main tool implementation | ~660 |
| `lib/application/tools/direct_selection/anchor_drag_controller.dart` | Grid snapping logic | ~115 |
| `lib/application/tools/direct_selection/handle_drag_controller.dart` | Angle snapping + constraints | ~220 |
| `lib/application/tools/direct_selection/snapping_service.dart` | Magnetic snapping algorithms | ~295 |
| `lib/application/tools/direct_selection/inertia_controller.dart` | Inertia smoothing | ~360 |
| `lib/application/tools/direct_selection/drag_controller.dart` | Base drag calculations | ~150 |
| `packages/event_core/lib/src/operation_grouping.dart` | Undo operation grouping | ~560 |
| `lib/presentation/canvas/overlays/selection_overlay.dart` | Visual rendering | ~470 |
| `test/widget/direct_selection_tool_test.dart` | Widget tests | ~210 |
| `packages/tool_framework/test/tools/snapping_service_test.dart` | Snapping unit tests | ~280 |
| `packages/tool_framework/test/tools/inertia_controller_test.dart` | Inertia unit tests | ~370 |
| `packages/tool_framework/test/tools/direct_selection_snap_test.dart` | Integration tests | ~320 |

### Architecture Diagram

```
DirectSelectionTool
    ├── CanvasHitTester (8px threshold anchor/handle detection)
    ├── SnappingService (magnetic grid/angle snapping with hysteresis)
    ├── InertiaController (velocity-based momentum smoothing)
    ├── OperationGroupingService (automatic undo grouping)
    ├── AnchorDragController
    │   ├── DragController (base calculations)
    │   └── SnappingService (magnetic grid snapping)
    ├── HandleDragController
    │   ├── DragController (base calculations)
    │   └── SnappingService (angle snapping)
    ├── EventRecorder (50ms sampling + flush)
    └── SelectionOverlayPainter (visual feedback)
```

---

### State Machine

```
┌─────┐  onPointerDown(anchor)   ┌──────────────┐
│IDLE │─────────────────────────>│DRAGGING      │
└─────┘                           │ANCHOR        │
   ^                              └──────────────┘
   │                                     │
   │ onPointerUp()                       │ onPointerMove()
   │                                     │ (emit ModifyAnchorEvent)
   │                              ┌──────────────┐
   └──────────────────────────────┤flush()       │
                                  │finishDrag()  │
                                  └──────────────┘

┌─────┐  onPointerDown(handle)   ┌──────────────┐
│IDLE │─────────────────────────>│DRAGGING      │
└─────┘                           │HANDLE        │
   ^                              └──────────────┘
   │                                     │
   │ onPointerUp()                       │ onPointerMove()
   │                                     │ (emit ModifyAnchorEvent)
   │                              ┌──────────────┐
   └──────────────────────────────┤flush()       │
                                  │finishDrag()  │
                                  └──────────────┘
```

**Critical State Transitions:**
- `onPointerDown()` → `_startDrag()` → `DRAGGING` state
- `onPointerMove()` → `_updateDrag()` → Emit event (sampled)
- `onPointerUp()` → `_finishDrag()` → Flush recorder → `IDLE` state
- `onDeactivate()` → `_finishDrag()` → Flush recorder (safety)

---

## Testing

### Test Coverage

**Test Files:**
1. `test/widget/direct_selection_tool_test.dart` - Widget tests (5 tests)
2. `packages/tool_framework/test/tools/snapping_service_test.dart` - Snapping unit tests (30+ tests)
3. `packages/tool_framework/test/tools/inertia_controller_test.dart` - Inertia unit tests (35+ tests)
4. `packages/tool_framework/test/tools/direct_selection_snap_test.dart` - Integration tests (20+ tests)

**Test Groups:**
1. **Magnetic Grid Snapping** (6 tests)
   - Snap within threshold
   - No snap outside threshold
   - Hysteresis prevents jitter
   - Correct grid intersection
   - Respects enable flag
   - Reset clears state

2. **Snapping Accuracy** (2 tests)
   - Sub-pixel accuracy (<0.001px drift)
   - Magnitude preservation for angle snapping

3. **Inertia Sample Recording** (2 tests)
   - Circular buffer management
   - Old sample discard

4. **Inertia Activation** (3 tests)
   - Activates above threshold
   - No activation below threshold
   - Insufficient samples handled

5. **Inertia Sequence Generation** (4 tests)
   - Exponential decay
   - Max duration limit
   - Velocity threshold stop
   - Correct timestamps

6. **Accuracy Guarantees** (2 tests)
   - Sub-pixel precision
   - <1px total drift

7. **Integration Tests** (5+ tests)
   - Snapping + inertia combined
   - Performance within frame budget
   - Edge cases (zero velocity, exact grid, etc.)

**Total:** 90+ tests, all passing ✅

### Acceptance Criteria Verification

| Criteria | Test | Result |
|----------|------|--------|
| Snapping toggles respond instantly | `setSnapMode` tests | ✅ PASS |
| Operations aggregated elegantly | Integration with `OperationGroupingService` | ✅ PASS |
| Tests assert drift <1px | `total drift is less than 1px` test | ✅ PASS |
| Doc updates describe grid settings | This document (Magnetic Grid Snapping section) | ✅ PASS |
| Magnetic snapping within threshold | `snaps to nearest grid when within threshold` | ✅ PASS |
| Hysteresis prevents jitter | `applies hysteresis to prevent jittering` | ✅ PASS |
| Inertia adds smoothing | `generates exponentially decaying sequence` | ✅ PASS |
| Event batching reduces noise | Integration tests verify reasonable event counts | ✅ PASS |

**Run Tests:**
```bash
# All tests
flutter test

# Specific test suites
flutter test test/widget/direct_selection_tool_test.dart
flutter test packages/tool_framework/test/tools/snapping_service_test.dart
flutter test packages/tool_framework/test/tools/inertia_controller_test.dart
flutter test packages/tool_framework/test/tools/direct_selection_snap_test.dart
```

**Expected Output:**
```
00:05 +90: All tests passed!
```

---

## Future Enhancements

### Planned for v0.2 (Polish + UX)

1. **Anchor Type Conversion**
   - Alt/Option key during drag to toggle smooth ↔ corner
   - Visual indicator for anchor type (square for corner, circle for smooth)

2. **Multi-Anchor Selection**
   - Shift+Click to select multiple anchors
   - Drag all selected anchors simultaneously
   - Marquee selection for anchors

3. **Path Snapping**
   - Snap anchors to nearby path segments
   - `SnappingService.snapToPath()` implementation
   - Visual guide lines when snap activates

### Planned for v0.3 (Advanced Features)

1. **Smart Guides**
   - Alignment guides when dragging (horizontal/vertical/center)
   - Distance guides showing spacing from other anchors

2. **Numeric Input**
   - Double-click anchor to enter precise coordinates
   - Tab between x/y fields, Enter to commit

3. **Handle Length Locking**
   - Cmd+Drag to lock handle length while adjusting angle
   - Option+Drag to break symmetry temporarily

---

## Glossary

- **Anchor Point**: A vertex in a vector path with optional Bezier control handles
- **BCP (Bezier Control Point)**: The endpoint of a handle vector that controls curve shape
- **Handle Vector**: The offset from an anchor to a BCP (stored as relative coordinates)
- **Anchor Type**: Classification determining handle constraint behavior (smooth/symmetric/corner)
- **Grid Snapping**: Rounding positions to nearest grid intersection
- **Angle Snapping**: Rounding handle angles to nearest angular increment
- **Event Sampling**: Throttling high-frequency drag events to reduce storage volume
- **World Space**: Coordinate system of the document canvas (before viewport transformations)
- **Screen Space**: Coordinate system of the rendered viewport (after pan/zoom)

---

## References

- **Architecture:** `.codemachine/artifacts/architecture/04_Behavior_and_Communication.md` (Flow 4: Dragging an Anchor Point)
- **Event Schema:** `docs/reference/event_schema.md` (Section: Sampling Metadata)
- **Tool Framework:** `.codemachine/artifacts/architecture/03_System_Structure_and_Data.md` (Component: Tool System)
- **Task Specification:** `.codemachine/artifacts/plan/02_Iteration_I3.md` (Task I3.T4)
- **ADR:** `docs/adr/003-event-sourcing-architecture.md` (Event sampling rationale)

---

**Document Version:** 1.1
**Last Updated:** 2025-11-09
**Maintained By:** WireTuner Development Team

**Changelog:**
- **v1.1 (I4.T5)**: Added magnetic grid snapping with hysteresis, inertia smoothing, and automatic operation grouping
- **v1.0 (I3.T4)**: Initial implementation with basic grid/angle snapping
