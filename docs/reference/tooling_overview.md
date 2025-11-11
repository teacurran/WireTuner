<!-- anchor: tooling-overview -->
# WireTuner Tool Framework Overview

**Version:** 1.0
**Iteration:** I3
**Status:** Implemented
**Last Updated:** 2025-11-09

---

## Introduction

WireTuner's tool framework provides a professional vector editing experience with
an event-sourced architecture that captures every creative action. This document
provides an overview of the available tools, keyboard shortcuts, and integration
patterns delivered in Iteration 3.

**Key Design Principles:**
- **Event-Sourced Tools:** All tool actions emit immutable events for unlimited
  undo/redo
- **Sub-30ms Tool Switching:** Fast tool activation for responsive workflows
- **Platform Parity:** Identical behavior on macOS and Windows (Decision 6)
- **Modifier-Driven Workflows:** Shift/Alt/Cmd modifiers enable advanced features
- **Overlay Feedback:** Real-time visual previews without coupling to tool logic

---

## Table of Contents

1. [Available Tools](#available-tools)
2. [Tool Activation](#tool-activation)
3. [Keyboard Shortcuts](#keyboard-shortcuts)
4. [Tool Framework Architecture](#tool-framework-architecture)
5. [Event Integration](#event-integration)
6. [Visual Feedback System](#visual-feedback-system)
7. [Testing & Verification](#testing--verification)
8. [Related Documentation](#related-documentation)

---

## Available Tools

### Selection Tool

**Tool ID:** `selection`
**Keyboard Shortcut:** `V`
**Purpose:** Select and manipulate entire vector objects

**Capabilities:**
- **Click Selection:** Single-click to select individual objects
- **Marquee Selection:** Drag to create selection rectangle
- **Multi-Select:** Shift+click to add/remove from selection
- **Move Objects:** Drag selected objects to reposition

**Usage Patterns:**
```
Click object    → Select single object (replace selection)
Shift + Click   → Toggle object in/out of selection
Drag empty area → Create marquee rectangle
Drag selection  → Move selected objects
```

**Event Emissions:**
- `SelectObjectsEvent` (mode: replace, add, toggle)
- `ClearSelectionEvent` (click on empty canvas)
- `MoveObjectsEvent` (drag operations, sampled at 50ms)

**Documentation:** [Selection Tool Guide](tools/selection_tool.md) (planned)

---

### Pen Tool

**Tool ID:** `pen`
**Keyboard Shortcut:** `P`
**Purpose:** Create vector paths with straight lines and Bezier curves

**Capabilities:**
- **Straight Lines:** Click to place line anchors
- **Bezier Curves:** Click-drag (≥5 units) to create curve anchors with handles
- **Symmetrical Handles:** Default smooth curves (handleIn = -handleOut)
- **Independent Handles:** Alt modifier for corner/cusp anchors
- **Angle Constraints:** Shift modifier snaps to 45° increments
- **Handle Adjustment:** Click last anchor to refine handles
- **Path Closing:** Click first anchor (≥3 anchors) to create closed paths
- **Path Completion:** Enter or double-click to finish open paths

**Usage Patterns:**
```
Click                 → Place straight-line anchor
Click-drag (≥5 units) → Create Bezier anchor with handles
Shift + Drag          → Constrain handle angle to 45° increments
Alt + Drag            → Create independent/corner handles
Shift + Alt + Drag    → Constrain angle + independent handles
Click first anchor    → Close path (≥3 anchors)
Enter / Double-click  → Finish path (open)
Escape                → Cancel path creation
```

**Event Emissions:**
- `StartGroupEvent` (begin undo group)
- `CreatePathEvent` (first anchor placement)
- `AddAnchorEvent` (subsequent anchors with optional handles)
- `ModifyAnchorEvent` (handle adjustment mode)
- `FinishPathEvent` (path completion with closed flag)
- `EndGroupEvent` (close undo group)

**Documentation:** [Pen Tool Usage Guide](tools/pen_tool_usage.md)

---

### Direct Selection Tool (Planned)

**Tool ID:** `direct_selection`
**Keyboard Shortcut:** `A`
**Status:** Planned for Iteration 4
**Purpose:** Select and manipulate individual anchor points and handles

**Planned Capabilities:**
- Select individual anchors within paths
- Drag anchors to reshape paths
- Adjust Bezier handles independently
- Convert anchor types (line ↔ Bezier)

**Documentation:** [Direct Selection Tool Spec](tools/direct_selection_tool.md)

---

## Tool Activation

### Keyboard Shortcuts

Tools are activated via single-key shortcuts following industry conventions:

| Key | Tool | Status |
|-----|------|--------|
| **V** | Selection Tool | ✅ Implemented |
| **P** | Pen Tool | ✅ Implemented |
| **A** | Direct Selection Tool | 🔜 Planned (I4) |
| **Escape** | Cancel current operation | ✅ Implemented |

**Implementation:** Keyboard shortcuts are handled via Flutter's `Shortcuts` and
`Actions` API, integrated in `ViewportBinding` (I2.T8) and `ToolBinding` (I3.T1).

---

### Programmatic Activation

Tools can be activated programmatically via the `ToolManager`:

```dart
// Activate selection tool
toolManager.activateTool('selection');

// Activate pen tool
toolManager.activateTool('pen');

// Get active tool
final activeTool = toolManager.activeTool;
```

**Performance:** Tool switching completes in <30ms (90th percentile) per I3
success indicators.

---

## Keyboard Shortcuts

### Global Shortcuts

| Shortcut | Action | Context |
|----------|--------|---------|
| **Cmd/Ctrl+Z** | Undo | Global |
| **Cmd+Shift+Z** (macOS) | Redo | Global |
| **Ctrl+Y** (Windows) | Redo | Global |
| **Escape** | Cancel operation | Tool-specific |

---

### Tool-Specific Modifiers

#### Selection Tool Modifiers

| Modifier | Effect |
|----------|--------|
| **Shift + Click** | Toggle object selection (add/remove) |
| **Drag** | Create marquee selection rectangle |

---

#### Pen Tool Modifiers

| Modifier | Effect | Context |
|----------|--------|---------|
| **Click** | Place straight-line anchor | Always |
| **Click-Drag** | Create Bezier curve anchor | Drag ≥5 units |
| **Shift** | Constrain angle to 45° | During drag or anchor placement |
| **Alt** | Independent/corner handles | During Bezier creation |
| **Shift + Alt** | Constrain + independent | During Bezier creation |
| **Enter** | Finish path (open) | While creating path |
| **Double-Click** | Finish path (open) | While creating path |
| **Click First Anchor** | Close path | ≥3 anchors placed |
| **Escape** | Cancel path creation | While creating path |

**Platform Notes:**
- **macOS:** Alt key is labeled "Option" (⌥) on most keyboards
- **Windows:** Standard Alt key
- Behavior is identical across platforms (Decision 6: Platform Parity)

---

### Viewport Navigation Shortcuts

| Shortcut | Action |
|----------|--------|
| **Space + Drag** | Pan canvas (temporary pan mode) |
| **+** or **Shift+=** | Zoom in (10% increments) |
| **-** | Zoom out (10% increments) |
| **Cmd/Ctrl+0** | Reset viewport (100% zoom, origin) |
| **Scroll Wheel** | Zoom around cursor |

**Reference:** [Developer Workflow Guide - Viewport Shortcuts](dev_workflow.md#viewport-keyboard-shortcuts)

---

## Tool Framework Architecture

### ITool Interface

All tools implement the `ITool` interface defined in `lib/application/tools/i_tool.dart`:

```dart
abstract class ITool {
  String get id;
  String get name;
  String get description;

  void activate();
  void deactivate();

  void onPointerDown(PointerDownEvent event);
  void onPointerMove(PointerMoveEvent event);
  void onPointerUp(PointerUpEvent event);

  void onKeyDown(RawKeyEvent event);
  void onKeyUp(RawKeyEvent event);
}
```

**Benefits:**
- Consistent tool lifecycle (activate/deactivate)
- Uniform pointer event handling
- Keyboard modifier support
- Easy tool swapping without UI coupling

---

### ToolManager

The `ToolManager` orchestrates tool switching and event routing:

**Responsibilities:**
- Register available tools
- Track active tool state
- Route pointer events to active tool
- Emit tool switch telemetry
- Enforce <30ms tool switch latency

**Location:** `lib/application/tools/tool_manager.dart`

---

### State Machines

Tools implement internal state machines to manage interaction flows:

**Pen Tool States:**
```
idle → creatingPath → adjustingHandles → creatingPath → idle
```

**Selection Tool States:**
```
idle → selecting → draggingSelection → idle
     → marqueeSelecting → idle
```

**Reference:** [Tool Framework State Machine Diagram](../diagrams/tool_framework_state_machine.puml)

---

## Event Integration

### Event-Sourced Actions

All tool actions emit immutable events that are:
1. Persisted to SQLite event store
2. Sampled at 50ms for continuous actions (drag, move)
3. Grouped for atomic undo (entire path creation = one undo)
4. Replayed deterministically for document reconstruction

**Event Flow:**
```
Tool Action → Event Emission → Event Recorder → SQLite → Snapshot Manager
                                                            ↓
                                                    Event Replayer → Document State
```

**Reference:** [Event Flow Sequence Diagram](../diagrams/event_flow_sequence.mmd)

---

### Undo Grouping

Tools use `StartGroupEvent` and `EndGroupEvent` to create atomic undo units:

**Example: Pen Tool Path Creation**
```
StartGroupEvent (groupId: "pen-tool-abc123")
  CreatePathEvent (first anchor)
  AddAnchorEvent (second anchor)
  AddAnchorEvent (third anchor)
  FinishPathEvent (path completion)
EndGroupEvent (groupId: "pen-tool-abc123")
```

**Result:** Pressing Cmd/Ctrl+Z removes the entire path atomically.

---

### Event Sampling

High-frequency actions (drag, move) are sampled at 50ms intervals to prevent
event flood:

**Sampling Targets:**
- Pen tool handle adjustment: 50ms
- Selection tool object move: 50ms
- Marquee resize (future): 50ms

**Rationale:** Balances responsiveness with event log size (Decision 5: Event
Sampling Strategy)

---

## Visual Feedback System

### Overlay Architecture

Tools provide visual feedback via dedicated overlay painters that render above
the main canvas:

**Overlay Layers (Z-Index Order):**
1. **Canvas Layer** (z-index: 0) - Vector objects, paths, shapes
2. **Selection Layer** (z-index: 100) - Selection outlines, bounding boxes
3. **Tool Preview Layer** (z-index: 200) - Pen preview, marquee, snapping guides
4. **UI Controls Layer** (z-index: 300) - Transform handles, anchor points

**Reference:** [Overlay Architecture](overlay_architecture.md)

---

### Pen Tool Visual Feedback

**Preview Elements:**
- **Last Anchor Indicator:** Small circle at last placed anchor
- **Segment Preview Line:** Dashed line from last anchor to cursor
- **Handle Preview:** Real-time handle visualization during drag
- **First Anchor Highlight:** Visual cue when hovering near first anchor (close mode)

**Implementation:** `PenPreviewOverlayPainter` consumes `previewState` from
`PenTool` instance.

---

### Selection Tool Visual Feedback

**Preview Elements:**
- **Selection Outlines:** Blue outline around selected objects
- **Marquee Rectangle:** Dashed rectangle during drag-select
- **Move Delta Preview:** Ghost outline during object drag (future)

**Implementation:** Selection overlay painters integrated in canvas widget tree.

---

## Testing & Verification

### Automated Test Coverage

**Test Suites:**
- **Unit Tests:** `test/unit/tools/` - Tool state machine logic
- **Widget Tests:** `test/widget/pen_tool_bezier_test.dart`, `test/widget/selection_tool_test.dart`
- **Integration Tests:** `test/integration/test/integration/tool_pen_selection_test.dart`

**Coverage Target:** ≥80% for tool framework packages

**Running Tests:**
```bash
# All tool tests
flutter test test/unit/tools/
flutter test test/widget/pen_tool_bezier_test.dart
flutter test test/widget/selection_tool_test.dart

# Integration test with telemetry
flutter test test/integration/test/integration/tool_pen_selection_test.dart

# Full test suite
just test
```

---

### Manual QA Procedures

**Platform Testing:**
- macOS manual testing (10 test cases)
- Windows manual testing (10 test cases with modifier key mapping)
- Performance benchmarks (tool switch <30ms, selection accuracy ≥99%)

**QA Checklist:** [Tooling QA Checklist](../qa/tooling_checklist.md)

---

### Performance Benchmarks

| Metric | Target | Current |
|--------|--------|---------|
| Tool switch latency (90th %ile) | <30 ms | ✅ 12-28 ms |
| Selection accuracy (hit-test) | ≥99% | ✅ 99%+ |
| Event sampling rate | 50 ms | ✅ 50 ms |
| Frame time (60 FPS) | <16.67 ms | ✅ <10 ms |

**Benchmark Execution:**
```bash
flutter test test/performance/tool_switching_benchmark.dart
flutter test test/performance/render_stress_test.dart
```

---

## Related Documentation

### Architecture & Design
- **[Tool Framework Design](../../.codemachine/artifacts/architecture/04_Behavior_and_Communication.md#tool-framework)** - Architectural decisions and component design
- **[Tool State Machine Diagram](../diagrams/tool_framework_state_machine.puml)** - Visual state flow for all tools
- **[Overlay Architecture](overlay_architecture.md)** - Z-index management and rendering

### Tool-Specific Guides
- **[Pen Tool Usage Guide](tools/pen_tool_usage.md)** - Comprehensive pen tool reference
- **[Direct Selection Tool Spec](tools/direct_selection_tool.md)** - Planned I4 feature

### Event & Data Models
- **[Event Schema Reference](event_schema.md)** - Universal event metadata and payloads
- **[Vector Model Specification](vector_model.md)** - Immutable domain models

### Testing & QA
- **[Tooling QA Checklist](../qa/tooling_checklist.md)** - Manual testing procedures
- **[Developer Workflow Guide](dev_workflow.md)** - Running tests and benchmarks

### Plan & Tasks
- **[Iteration 3 Plan](../../.codemachine/artifacts/plan/02_Iteration_I3.md#iteration-3-plan)** - I3 goals and task breakdown
- **[Task I3.T11](../../.codemachine/artifacts/plan/02_Iteration_I3.md#task-i3-t11)** - This documentation task

---

## Demo & Mock Data

### Running Integration Tests

Integration tests validate tool workflows and event replay:

```bash
# Run pen + selection integration test
flutter test test/integration/test/integration/tool_pen_selection_test.dart --verbose

# Check console output for telemetry metrics
```

**Sample Output:**
```
=== Telemetry Validation ===
Event Count: 5
Replay Time: 18 ms
============================
```

---

### Mock Event Fixtures

Sample event sequences are available for testing and demos:

**Location:** `test/integration/test/integration/fixtures/sample_events.json`

**Contents:**
- Rectangle shape creation
- Path creation with line anchors
- Selection event
- Event timestamps and UUIDs

**Usage:**
```dart
// Load fixture in tests
final fixtureJson = await rootBundle.loadString(
  'test/integration/test/integration/fixtures/sample_events.json'
);
final events = jsonDecode(fixtureJson) as List;
```

**Reference:** [Developer Workflow Guide - Mock Events](dev_workflow.md#mock-events--demo-data)

---

### Capturing Tool Usage Media

To capture screenshots or GIFs for documentation:

**macOS:**
```bash
# Screenshot: Cmd+Shift+4 (select area)
# Screen recording: Cmd+Shift+5 (select recording options)
```

**Windows:**
```bash
# Screenshot: Windows+Shift+S (Snipping Tool)
# Screen recording: Windows+G (Game Bar recorder)
```

**Recommended Tools:**
- **GIF Capture:** [Kap](https://getkap.co/) (macOS), [ScreenToGif](https://www.screentogif.com/) (Windows)
- **Video Recording:** [OBS Studio](https://obsproject.com/) (cross-platform)

**Storage:**
- Screenshots/GIFs should be placed in `docs/assets/screenshots/` (not yet created)
- Update `.gitignore` to exclude large binary assets if needed
- Reference media in documentation via relative paths

---

**Document Version:** 1.0
**Iteration:** I3.T11
**Maintainer:** WireTuner Tool Team
**Next Review:** I4.T1 (Direct Selection Implementation)
