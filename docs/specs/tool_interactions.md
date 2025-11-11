# Tool Interaction Specification

**Document Version:** 1.0
**Last Updated:** 2025-11-08
**Status:** Active
**Related Diagrams:** [tool_interaction_sequence.puml](../diagrams/tool_interaction_sequence.puml)
**Related Specs:** [event_lifecycle.md](event_lifecycle.md)

---

## Overview

This document specifies the interaction patterns between tools, the tool framework, and the event sourcing system in WireTuner. It focuses on how pointer events flow through the `ToolManager`, how tools interact with the `EventRecorder` and `EventSampler`, and how undo grouping provides atomic operations for multi-step interactions.

**Key Architectural Principles:**
- All pointer events route through `ToolManager` to the active tool
- High-frequency input (drag operations) is sampled at 50ms intervals by `EventSampler`
- Multi-step operations are grouped using `StartGroupEvent` / `EndGroupEvent` markers for atomic undo
- Tool lifecycle (activate/deactivate) coordinates with event recorder flush operations
- Tools remain stateless with respect to document data—all state changes flow through events

---

## Tool Framework Architecture

### Component Hierarchy

```
Canvas Widget (Pointer/Keyboard Input)
       ↓
Tool Manager (Event Router + Lifecycle Manager)
       ↓
Active Tool (ITool implementation: PenTool, SelectionTool, etc.)
       ↓
Event Sampler (50ms throttling for continuous input)
       ↓
Event Recorder (Sequence assignment, undo grouping)
       ↓
Event Dispatcher → Document State Update
       ↓
Event Store (SQLite persistence)
```

### State Management Flow

```
User Action → Tool State Machine → Event Generation → Event Application → UI Update
```

**Critical Design Constraint:** Tools do not directly mutate document state. All state changes occur through events applied by `EventDispatcher`.

---

## Pointer Event Flow

### Phase 1: Event Routing

**Sequence:**
1. User interacts with canvas (click, drag, scroll)
2. Canvas Widget receives Flutter pointer event
3. Canvas Widget calls `ToolManager.handlePointerDown/Move/Up(event)`
4. ToolManager routes event to active tool's `onPointerDown/Move/Up(event)`
5. Tool returns `true` if handled, `false` if not (allows fallback behavior)

**Code Reference:** [tool_manager.dart:285-326](../../lib/application/tools/framework/tool_manager.dart)

**Example:**
```dart
// Canvas Widget
Listener(
  onPointerDown: (event) {
    final handled = toolManager.handlePointerDown(event);
    if (!handled) {
      // Fallback: start canvas pan
    }
  },
  child: CustomPaint(...),
)
```

### Phase 2: Tool Processing

**Tool State Machine Example (Pen Tool):**

```
States:
  IDLE → CREATING_PATH → IDLE

Transitions:
  IDLE + pointer_down → CREATING_PATH (emit StartGroupEvent, CreatePathEvent)
  CREATING_PATH + pointer_down → CREATING_PATH (emit AddAnchorEvent)
  CREATING_PATH + double_click/Enter → IDLE (emit FinishPathEvent, EndGroupEvent)
  CREATING_PATH + Escape → IDLE (emit CancelPathEvent, EndGroupEvent)
```

**Code Reference:** [tool_interface.dart:183-234](../../lib/application/tools/framework/tool_interface.dart)

### Phase 3: Event Sampling (Continuous Input Only)

For discrete events (single clicks), events bypass the sampler and go directly to `EventRecorder`.

For continuous input (drag operations), the `EventSampler` throttles to 50ms intervals:

**Sampler Behavior:**
- **First Move:** Emitted immediately (t=0ms)
- **Subsequent Moves (< 50ms):** Buffered, latest position retained
- **50ms Threshold Reached:** Emit buffered position as single event
- **Pointer Up:** Flush any remaining buffered position

**Code Reference:** [event_lifecycle.md:59-87](event_lifecycle.md#phase-2-event-sampling-high-frequency-input-throttling)

**Sampling Accuracy Acceptance Criteria:**

| Metric | Target | Rationale |
|--------|--------|-----------|
| Sampling Rate | 50ms (20 samples/sec) | Matches human perception of smooth motion (~60 FPS) |
| Storage Reduction | 5-10x | 2-second drag: ~200 raw events → ~40 sampled events |
| Replay Smoothness | Perceptually smooth | 20 fps is sufficient for path replay |
| Latency Overhead | < 2ms | Lightweight timestamp check, negligible impact |
| Flush Guarantee | 100% | Final position always persisted on pointer up |

**Diagram Reference:** [tool_interaction_sequence.puml:167-222](../diagrams/tool_interaction_sequence.puml) (Dragging an Anchor Point)

---

## Undo Grouping Rules

### Start/End Markers

Undo grouping uses special marker events to define atomic operation boundaries:

- **`StartGroupEvent`**: Marks the beginning of a multi-step operation
- **`EndGroupEvent`**: Marks the completion of a multi-step operation

All events between these markers are treated as a single undoable unit.

**Event Schema:**
```json
// StartGroupEvent
{
  "eventType": "StartGroupEvent",
  "eventId": "uuid-1234",
  "timestamp": 1699564800000,
  "groupId": "drag-operation-5678",
  "description": "Drag anchor point"
}

// EndGroupEvent
{
  "eventType": "EndGroupEvent",
  "eventId": "uuid-1235",
  "timestamp": 1699564802000,
  "groupId": "drag-operation-5678"
}
```

### Grouping Scenarios

| Operation | Group Boundaries | Event Count (Typical) |
|-----------|-----------------|----------------------|
| **Pen Tool: Create Path** | Start: First click (CreatePathEvent)<br>End: Double-click/Enter (FinishPathEvent) | 5-20 (depends on anchor count) |
| **Direct Selection: Drag Anchor** | Start: Pointer down<br>End: Pointer up | 30-50 (sampled drag events) |
| **Selection Tool: Marquee Select** | Start: Pointer down<br>End: Pointer up | 2-3 (StartMarqueeEvent, SelectObjectsEvent, EndGroupEvent) |
| **Batch Style Modification** | Start: First style change<br>End: Apply button click | 10-100 (depends on selection size) |

### Undo Navigation Algorithm

**Finding Previous Group:**
```sql
-- Step 1: Find the most recent EndGroupEvent before current sequence
SELECT event_sequence
FROM events
WHERE event_type = 'EndGroupEvent'
  AND event_sequence < :currentSequence
ORDER BY event_sequence DESC
LIMIT 1;

-- Step 2: Find the corresponding StartGroupEvent
SELECT event_sequence
FROM events
WHERE event_type = 'StartGroupEvent'
  AND group_id = (
    SELECT group_id FROM events WHERE event_sequence = :endGroupSequence
  )
LIMIT 1;

-- Step 3: Navigate to sequence before StartGroupEvent
targetSequence = startGroupSequence - 1;
```

**Replay Process:**
1. Pause event recording (prevent circular event creation)
2. Find nearest snapshot ≤ targetSequence
3. Deserialize snapshot → base document state
4. Replay events from snapshot to targetSequence
5. Update current sequence pointer
6. Resume event recording
7. Notify UI listeners → canvas repaint

**Latency Budget:** < 100ms for typical undo (replays < 100 events from cached snapshot)

**Code Reference:** [event_lifecycle.md:224-268](event_lifecycle.md#phase-6-event-replay-and-navigation)

**Diagram Reference:** [tool_interaction_sequence.puml:267-338](../diagrams/tool_interaction_sequence.puml) (Undo Operation)

### Redo Behavior

Redo navigates forward to the next `EndGroupEvent`:

```sql
-- Find next EndGroupEvent after current sequence
SELECT event_sequence
FROM events
WHERE event_type = 'EndGroupEvent'
  AND event_sequence > :currentSequence
ORDER BY event_sequence ASC
LIMIT 1;
```

The redo operation then replays events from `currentSequence + 1` to `redoTargetSequence`.

---

## Tool Lifecycle and Event Coordination

### Tool Activation Flow

**Sequence:**
1. User selects new tool from toolbar (e.g., switches from Pen to Selection)
2. `ToolManager.activateTool(toolId)` is called
3. ToolManager flushes `EventRecorder` to persist any buffered events
4. ToolManager calls `currentTool.onDeactivate()`
5. ToolManager calls `newTool.onActivate()`
6. ToolManager updates cursor via `CursorService`
7. ToolManager notifies listeners (UI updates toolbar state)

**Code Reference:** [tool_manager.dart:198-227](../../lib/application/tools/framework/tool_manager.dart)

**Diagram Reference:** [tool_interaction_sequence.puml:152-170](../diagrams/tool_interaction_sequence.puml) (Tool switch protocol)

### Tool Deactivation Responsibilities

When a tool is deactivated, it must:

1. **Flush buffered state** to `EventRecorder` (e.g., pending sampled events)
2. **Emit `EndGroupEvent`** if an operation is in progress (to prevent incomplete groups)
3. **Reset internal state** to IDLE (or equivalent)
4. **Cancel ongoing operations** gracefully (e.g., cancel in-progress path creation)

**Example (Pen Tool deactivation mid-path creation):**
```dart
@override
void onDeactivate() {
  if (_state == PathState.CREATING_PATH) {
    // Cancel path creation, emit EndGroupEvent to close undo group
    _eventRecorder.recordEvent(CancelPathEvent(pathId: _currentPathId));
    _eventRecorder.recordEvent(EndGroupEvent(groupId: _currentGroupId));
    _currentPathId = null;
    _currentGroupId = null;
  }
  _state = PathState.IDLE;
}
```

---

## Pointer Event Types and Tool Responses

### onPointerDown

**Purpose:** Initiate interactions (start drag, add anchor, select object)

**Tool Responsibilities:**
- Perform hit testing (check if user clicked on handle, anchor, object)
- Initialize drag context if starting a drag operation
- Emit `StartGroupEvent` for multi-step operations
- Emit initial event (e.g., `CreatePathEvent`, `SelectObjectEvent`)
- Transition state machine

**Return Value:**
- `true`: Event handled, prevent fallback behavior
- `false`: Event not handled, allow canvas pan or other fallback

**Coordinate Conversion:**
```dart
// Pointer events provide screen coordinates
// Tools must convert to world coordinates via ViewportController
final worldPos = _viewportController.screenToWorld(event.localPosition);
```

**Code Reference:** [tool_interface.dart:156-183](../../lib/application/tools/framework/tool_interface.dart)

### onPointerMove

**Purpose:** Handle continuous input (drag, hover, preview updates)

**Tool Responsibilities:**
- Check if in dragging state (otherwise ignore or handle hover)
- Convert screen coordinates to world coordinates
- Emit move events via `EventSampler` (not directly to `EventRecorder`)
- Update internal preview state for overlay rendering

**Performance Critical:** Called 60-120 times per second during drag operations. Must be efficient.

**Return Value:**
- `true`: Event handled (tool is actively dragging)
- `false`: Event not handled (allow hover effects or cursor updates)

**Code Reference:** [tool_interface.dart:185-209](../../lib/application/tools/framework/tool_interface.dart)

### onPointerUp

**Purpose:** Finalize interactions (complete drag, commit object, finish path)

**Tool Responsibilities:**
- Call `EventSampler.flush()` to ensure final position persisted
- Emit completion event (e.g., `FinishPathEvent`)
- Emit `EndGroupEvent` to close undo group
- Transition state machine to IDLE or next state
- Clear drag context

**Critical:** Always flush sampler on pointer up to guarantee final state is recorded.

**Code Reference:** [tool_interface.dart:211-234](../../lib/application/tools/framework/tool_interface.dart)

**Diagram Reference:** [tool_interaction_sequence.puml:223-251](../diagrams/tool_interaction_sequence.puml) (Pointer up and flush)

---

## Tool State Machines

### Pen Tool States

```
┌──────┐  pointer_down (first click)   ┌──────────────┐
│ IDLE │──────────────────────────────>│ CREATING_PATH│
└──────┘                                └──────────────┘
   ↑                                            │
   │  double_click / Enter / Escape             │
   └────────────────────────────────────────────┘
```

**Events Emitted:**
- `IDLE → CREATING_PATH`: `StartGroupEvent`, `CreatePathEvent`
- `CREATING_PATH → CREATING_PATH`: `AddAnchorEvent` (each click)
- `CREATING_PATH → IDLE`: `FinishPathEvent` (or `CancelPathEvent`), `EndGroupEvent`

**Undo Grouping:** Entire path creation (multiple clicks) is one undo group.

### Direct Selection Tool States

```
┌──────┐  pointer_down (on anchor)   ┌──────────────────┐
│ IDLE │────────────────────────────>│ DRAGGING_ANCHOR  │
└──────┘                              └──────────────────┘
   ↑                                          │
   │  pointer_up                              │
   └──────────────────────────────────────────┘
```

**Events Emitted:**
- `IDLE → DRAGGING_ANCHOR`: `StartGroupEvent`
- `DRAGGING_ANCHOR → DRAGGING_ANCHOR`: `MoveAnchorEvent` (sampled at 50ms)
- `DRAGGING_ANCHOR → IDLE`: `MoveAnchorEvent` (final flush), `EndGroupEvent`

**Undo Grouping:** Entire drag operation (~40 events) is one undo group.

### Selection Tool States

```
┌──────┐  pointer_down (on canvas)   ┌─────────────────┐
│ IDLE │────────────────────────────>│ MARQUEE_SELECT  │
└──────┘                              └─────────────────┘
   ↑    pointer_down (on object)             │
   │                                          │
   │  ┌──────────────────┐  pointer_up       │
   ├──│ DRAGGING_OBJECTS │<──────────────────┘
   │  └──────────────────┘
   │         │
   └─────────┘ pointer_up
```

**Events Emitted:**
- `IDLE → MARQUEE_SELECT`: `StartGroupEvent`, `StartMarqueeEvent`
- `MARQUEE_SELECT → IDLE`: `SelectObjectsEvent`, `EndGroupEvent`
- `IDLE → DRAGGING_OBJECTS`: `StartGroupEvent`
- `DRAGGING_OBJECTS → DRAGGING_OBJECTS`: `MoveObjectEvent` (sampled)
- `DRAGGING_OBJECTS → IDLE`: `MoveObjectEvent` (final), `EndGroupEvent`

---

## Event Recorder Interactions

### Recording Discrete Events

**Pattern (Single-click, keyboard shortcut):**
```dart
_eventRecorder.recordEvent(AddAnchorEvent(
  eventId: _uuid.v4(),
  timestamp: DateTime.now().millisecondsSinceEpoch,
  pathId: _currentPathId,
  anchorPosition: worldPos,
  anchorType: AnchorType.line,
));
```

**Behavior:**
- Event assigned monotonic sequence number
- Event dispatched immediately to `EventDispatcher`
- Event persisted to SQLite asynchronously
- UI notified via `notifyListeners()`

### Recording Continuous Events (via Sampler)

**Pattern (Drag operation):**
```dart
// In onPointerMove:
_eventSampler.recordMove(
  pathId: _dragContext.pathId,
  anchorIndex: _dragContext.anchorIndex,
  newPosition: worldPos,
  timestamp: DateTime.now().millisecondsSinceEpoch,
);

// In onPointerUp:
_eventSampler.flush(); // Emit final buffered position
```

**Behavior:**
- Sampler buffers intermediate positions
- Emits events at 50ms intervals via `EventRecorder`
- Flush on pointer up ensures final position persisted

**Code Reference:** [event_lifecycle.md:59-87](event_lifecycle.md#phase-2-event-sampling-high-frequency-input-throttling)

### Pause/Resume During Undo

**Pattern (Preventing circular event creation):**
```dart
// Before undo navigation
_eventRecorder.pause();

try {
  await _eventReplayer.replayToSequence(targetSequence);
  _currentSequence = targetSequence;
} finally {
  _eventRecorder.resume();
}
```

**Rationale:** During undo, the system replays events to reconstruct state. If recording were active, replaying a `MoveAnchorEvent` would generate a new `MoveAnchorEvent`, creating infinite loops.

**Code Reference:** [tool_manager.dart:391-417](../../lib/application/tools/framework/tool_manager.dart)

---

## Cursor Management

### Cursor Service Integration

The `CursorService` manages cursor state globally. Tools define their cursor via the `ITool.cursor` getter.

**ToolManager Responsibilities:**
- On tool activation: `_cursorService.setCursor(newTool.cursor)`
- On tool deactivation: `_cursorService.reset()` (returns to default)

**Dynamic Cursor Updates:**
Tools can request cursor changes mid-operation (e.g., hovering over a handle):

```dart
// In tool's onPointerMove:
if (hoveringOverHandle) {
  _toolManager.updateCursor(SystemMouseCursors.move);
} else {
  _toolManager.updateCursor(_defaultCursor);
}
```

**Code Reference:** [tool_manager.dart:419-435](../../lib/application/tools/framework/tool_manager.dart)

---

## Overlay Rendering

### Rendering Pipeline

**Flow:**
1. Flutter framework calls `CustomPainter.paint(canvas, size)`
2. Canvas widget calls `ToolManager.renderOverlay(canvas, size)`
3. ToolManager calls `activeTool.renderOverlay(canvas, size)`
4. Tool draws guides, handles, previews on canvas

**Performance Consideration:** Called every frame (60 FPS). Keep rendering efficient.

**Coordinate System:**
- Canvas is pre-transformed by viewport (pan/zoom applied)
- Tools draw in world coordinates
- For screen-space UI (e.g., fixed-size handles), use `ViewportController.worldToScreen()`

**Example (Pen Tool drawing anchor preview):**
```dart
@override
void renderOverlay(Canvas canvas, Size size) {
  if (_state == PathState.CREATING_PATH && _hoverPosition != null) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw preview line from last anchor to hover position
    final lastAnchor = _currentPath.anchors.last;
    canvas.drawLine(lastAnchor.position, _hoverPosition!, paint);

    // Draw anchor preview circle
    canvas.drawCircle(_hoverPosition!, 4.0, paint);
  }
}
```

**Code Reference:** [tool_interface.dart:265-300](../../lib/application/tools/framework/tool_interface.dart)

---

## Latency Budgets and Performance Requirements

| Operation | Target Latency | Measurement Point | Acceptance Criteria |
|-----------|---------------|-------------------|---------------------|
| **Pointer Event Routing** | < 5ms | Canvas widget → Tool handler | Non-blocking, no jank |
| **Event Sampler Processing** | < 2ms | Sampler timestamp check + buffering | Negligible overhead |
| **Event Recording** | < 5ms | Tool → EventRecorder | Event creation + sequence assignment |
| **Event Dispatch** | < 10ms | EventRecorder → Document state update | Depends on document complexity |
| **UI Update (notifyListeners)** | < 16.7ms | Document update → canvas repaint | Maintain 60 FPS |
| **Tool Activation** | < 50ms | Deactivate old tool → Activate new tool | Includes flush operation |
| **Undo/Redo (Grouped Operation)** | < 100ms | Cmd+Z → UI repaint | Replay < 100 events from snapshot |

**Profiling Instrumentation:**
- Development builds include `Timeline.startSync/finishSync` markers
- Performance tests in CI/CD measure P95 latencies
- Dart DevTools used for frame-by-frame analysis

---

## Error Handling and Edge Cases

### Incomplete Undo Groups

**Scenario:** User deactivates tool mid-operation (e.g., switches tools while dragging)

**Handling:**
- Tool's `onDeactivate()` emits `EndGroupEvent` to close group
- Partial operation (e.g., half-completed drag) is still undoable as a unit
- Prevents orphaned `StartGroupEvent` without matching `EndGroupEvent`

**Code Reference:** [tool_interactions.md:188-203](#tool-deactivation-responsibilities)

### Event Recorder Pause/Resume Imbalance

**Scenario:** `pause()` called but `resume()` never called (e.g., exception during undo)

**Detection:** Event recorder tracks pause depth counter

**Handling:**
```dart
// EventRecorder
int _pauseDepth = 0;

void pause() {
  _pauseDepth++;
}

void resume() {
  if (_pauseDepth > 0) {
    _pauseDepth--;
  } else {
    _logger.w('resume() called without matching pause()');
  }
}

bool get isPaused => _pauseDepth > 0;
```

**Recovery:** Application restart resets pause state. Development builds log warnings.

### Sampler Flush Failures

**Scenario:** `EventSampler.flush()` called but buffer is empty (no buffered position)

**Handling:** No-op, silently ignored. Not an error condition.

**Scenario:** Pointer up event never received (user drags off-screen and releases)

**Handling:**
- Canvas widget uses `Listener` with `behavior: HitTestBehavior.translucent`
- Ensures pointer up events are captured even off-canvas
- Tool sets up fallback timer: if no pointer up within 5 seconds, auto-flush and reset state

---

## Testing Strategy

### Unit Tests (Tool State Machines)

**Coverage:**
- State transitions for each tool (IDLE → ACTIVE → IDLE)
- Event emission for each transition
- Edge cases (e.g., double-click during drag, Escape mid-operation)

**Example:**
```dart
test('PenTool emits StartGroupEvent on first click', () {
  final tool = PenTool();
  final recorder = MockEventRecorder();
  tool.eventRecorder = recorder;

  tool.onActivate();
  tool.onPointerDown(PointerDownEvent(position: Offset(100, 100)));

  expect(recorder.events, contains(isA<StartGroupEvent>()));
  expect(recorder.events, contains(isA<CreatePathEvent>()));
});
```

### Integration Tests (Tool + EventRecorder + Sampler)

**Coverage:**
- Sampling behavior (verify 50ms throttling)
- Flush on pointer up
- Undo grouping (verify Start/End markers)

**Example:**
```dart
testWidgets('DirectSelectionTool samples drag events at 50ms', (tester) async {
  final recorder = EventRecorder();
  final sampler = EventSampler(recorder);
  final tool = DirectSelectionTool(sampler);

  // Simulate 200ms drag with 10ms polling
  for (int i = 0; i < 20; i++) {
    tool.onPointerMove(PointerMoveEvent(
      position: Offset(100.0 + i * 10, 100.0),
      timeStamp: Duration(milliseconds: i * 10),
    ));
    await tester.pump(Duration(milliseconds: 10));
  }

  tool.onPointerUp(PointerUpEvent());

  // Expect ~4 events (200ms / 50ms = 4) + 1 flush event
  expect(recorder.events.whereType<MoveAnchorEvent>().length, inRange(4, 5));
});
```

### Acceptance Tests (End-to-End Workflows)

**Scenarios:**
1. Create 3-segment path with Pen Tool → Undo → Verify path removed
2. Drag anchor with Direct Selection Tool → Undo → Verify original position restored
3. Switch tools mid-drag → Verify `EndGroupEvent` emitted, state reset
4. Perform 50-event drag → Verify storage reduction (< 10 events persisted)

---

## Cross-References

### Architecture Documents
- [ADR 003: Event Sourcing Architecture](../adr/003-event-sourcing-architecture.md)
- [Behavior and Communication - Tool Interaction Flows](../architecture/04_Behavior_and_Communication.md#flow-1-creating-a-path-with-the-pen-tool)
- [System Structure - Tool Framework Components](../architecture/03_System_Structure_and_Data.md)

### Diagrams
- [Tool Interaction Sequence Diagram](../diagrams/tool_interaction_sequence.puml) *(this specification's visual companion)*
- [Event Flow Sequence Diagram](../diagrams/event_flow_sequence.puml)
- [Component Overview Diagram](../diagrams/component_overview.puml)

### Related Specifications
- [Event Lifecycle Specification](event_lifecycle.md) - Foundation for event sourcing
- [Viewport Specification](viewport.md) - Coordinate transformations for tools

### Backlog Tickets
- [T018: Tool Framework](../../.codemachine/inputs/tickets/T018-tool-framework.md)
- [T019: Pen Tool](../../.codemachine/inputs/tickets/T019-pen-tool.md)
- [T020: Selection Tool](../../.codemachine/inputs/tickets/T020-selection-tool.md)
- [T021: Direct Selection Tool](../../.codemachine/inputs/tickets/T021-direct-selection-tool.md)
- [T022: Anchor Manipulation](../../.codemachine/inputs/tickets/T022-anchor-manipulation.md)
- [T023: Bezier Handle Editing](../../.codemachine/inputs/tickets/T023-bezier-handle-editing.md)
- [T024: Path Editing Modes](../../.codemachine/inputs/tickets/T024-path-editing-modes.md)

### Implementation
- [ToolManager](../../lib/application/tools/framework/tool_manager.dart) - Central orchestrator
- [ITool Interface](../../lib/application/tools/framework/tool_interface.dart) - Tool contract
- [EventRecorder](../../lib/infrastructure/event_sourcing/event_recorder.dart) - Event recording + undo grouping
- [EventSampler](../../lib/infrastructure/event_sourcing/event_sampler.dart) - 50ms sampling logic

---

## Acceptance Criteria Summary

This specification is considered complete when:

### Diagram Completeness
- ✅ PlantUML diagram renders without errors
- ✅ Diagram includes participants: `ToolManager`, `PenTool`, `DirectSelectionTool`, `EventRecorder`, `EventSampler`, `SnapshotManager`
- ✅ Diagram illustrates three scenarios:
  1. Pen Tool: Creating a path with straight segments
  2. Direct Selection Tool: Dragging an anchor with sampling
  3. Undo operation: Reverting a grouped operation
- ✅ Diagram includes inline notes explaining sampling, undo grouping, and flush triggers

### Specification Completeness
- ✅ Describes pointer event flow (down/move/up) through ToolManager to tools
- ✅ Explains event batching via `EventSampler` (50ms threshold)
- ✅ Defines undo grouping rules (`StartGroupEvent` / `EndGroupEvent` markers)
- ✅ Specifies sampling accuracy acceptance criteria (latency, storage reduction, replay smoothness)
- ✅ Documents tool lifecycle (activate/deactivate) and flush coordination
- ✅ Provides code references to existing implementations (`tool_manager.dart`, `tool_interface.dart`, `event_lifecycle.md`)

### Cross-Reference Integrity
- ✅ Links to `event_lifecycle.md` for event sourcing foundation
- ✅ Links to relevant tickets (T018-T024)
- ✅ Links to architecture documents (ADR 003, Behavior and Communication flows)
- ✅ Includes code line references for traceability

---

**Document Status:** Complete
**Next Review:** After T019 (Pen Tool Implementation)
**Maintainer:** WireTuner Architecture Team
