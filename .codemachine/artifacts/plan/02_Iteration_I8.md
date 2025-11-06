# Iteration 8: Direct Manipulation

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-8-overview -->
### Iteration 8: Direct Manipulation

<!-- anchor: iteration-8-metadata -->
*   **Iteration ID:** `I8`
*   **Goal:** Implement dragging capabilities for anchor points, BCP handles, and objects; add multi-selection support
*   **Prerequisites:** I5 (tool framework), I6 (pen tool for anchor creation)

<!-- anchor: iteration-8-tasks -->
*   **Tasks:**

<!-- anchor: task-i8-t1 -->
*   **Task 8.1:**
    *   **Task ID:** `I8.T1`
    *   **Description:** Enhance DirectSelectionTool (from I5.T5) to support full anchor point dragging workflow. Implement drag state machine: IDLE → DRAGGING_ANCHOR → IDLE. Generate MoveAnchorEvent sampled at 50ms during drag. Update anchor position in real-time (via event application). Handle edge cases (anchor at path boundary, closed vs open paths). Write comprehensive integration tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Dragging anchor)
        *   Ticket T029 (Anchor Point Dragging)
    *   **Input Files:**
        *   `lib/application/tools/direct_selection_tool.dart` (from I5.T5)
        *   `lib/infrastructure/event_sourcing/event_sampler.dart` (from I2.T2)
    *   **Target Files:**
        *   `lib/application/tools/direct_selection_tool.dart` (enhance)
        *   `integration_test/anchor_dragging_test.dart`
    *   **Deliverables:**
        *   Anchor dragging with 50ms sampling
        *   Real-time visual feedback during drag
        *   MoveAnchorEvent recording
        *   Integration tests for drag workflow
    *   **Acceptance Criteria:**
        *   Drag anchor updates position smoothly at ~20 FPS (50ms sampling)
        *   MoveAnchorEvent generated every 50ms during drag
        *   Final position recorded on pointer up
        *   Anchor stays attached to path
        *   Integration test drags anchor 100px and verifies position
    *   **Dependencies:** `I5.T5` (DirectSelectionTool), `I2.T2` (EventSampler)
    *   **Parallelizable:** Yes

<!-- anchor: task-i8-t2 -->
*   **Task 8.2:**
    *   **Task ID:** `I8.T2`
    *   **Description:** Implement BCP handle dragging in DirectSelectionTool. When anchor selected, render BCP handles as draggable points. Dragging handle generates ModifyAnchorEvent (updates handleIn or handleOut). Support anchor type constraints: smooth anchors maintain symmetric handles, corner anchors allow independent handles. Write integration tests for handle manipulation.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T030 (BCP Handle Dragging)
        *   AnchorPoint model from I3.T2
    *   **Input Files:**
        *   `lib/application/tools/direct_selection_tool.dart` (from I8.T1)
        *   `lib/domain/models/anchor_point.dart` (from I3.T2)
    *   **Target Files:**
        *   `lib/application/tools/direct_selection_tool.dart` (enhance)
        *   `integration_test/bcp_handle_dragging_test.dart`
    *   **Deliverables:**
        *   BCP handle dragging with ModifyAnchorEvent
        *   Anchor type constraints enforced (smooth = symmetric, corner = independent)
        *   Real-time curve preview during drag
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Dragging handleOut updates curve shape
        *   Smooth anchor: handleIn updates symmetrically
        *   Corner anchor: handles move independently
        *   ModifyAnchorEvent recorded at 50ms intervals
        *   Integration test adjusts handle and verifies curve
    *   **Dependencies:** `I8.T1` (anchor dragging), `I3.T2` (AnchorPoint with handles)
    *   **Parallelizable:** No (needs I8.T1)

<!-- anchor: task-i8-t3 -->
*   **Task 8.3:**
    *   **Task ID:** `I8.T3`
    *   **Description:** Enhance SelectionTool (from I5.T4) to support full object dragging workflow. Implement DRAGGING_OBJECT state. Generate MoveObjectEvent sampled at 50ms during drag. Update object transform (translation) in real-time. Support dragging multiple selected objects simultaneously. Write integration tests for single and multi-object drag.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T031 (Object Dragging)
    *   **Input Files:**
        *   `lib/application/tools/selection_tool.dart` (from I5.T4)
        *   `lib/domain/models/transform.dart` (from I3.T1)
    *   **Target Files:**
        *   `lib/application/tools/selection_tool.dart` (enhance)
        *   `integration_test/object_dragging_test.dart`
    *   **Deliverables:**
        *   Object dragging with 50ms sampling
        *   Transform.translate() applied during drag
        *   Multi-object drag support
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Drag object updates position smoothly
        *   MoveObjectEvent generated every 50ms
        *   Multiple selected objects move together maintaining relative positions
        *   Integration test drags rectangle 50px right and verifies transform
    *   **Dependencies:** `I5.T4` (SelectionTool), `I3.T1` (Transform)
    *   **Parallelizable:** Yes (can overlap with I8.T1)

<!-- anchor: task-i8-t4 -->
*   **Task 8.4:**
    *   **Task ID:** `I8.T4`
    *   **Description:** Implement multi-selection support in SelectionTool. Shift+Click adds object to selection without clearing existing selection. Cmd+Click (macOS) or Ctrl+Click (Windows) toggles object in selection. Update Selection model to support multiple object IDs. Render bounding box encompassing all selected objects. Write integration tests for multi-selection scenarios.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T032 (Multi-Selection Support)
    *   **Input Files:**
        *   `lib/application/tools/selection_tool.dart` (from I8.T3)
        *   `lib/domain/models/selection.dart` (from I3.T6)
    *   **Target Files:**
        *   `lib/application/tools/selection_tool.dart` (enhance)
        *   `lib/domain/models/selection.dart` (update if needed)
        *   `integration_test/multi_selection_test.dart`
    *   **Deliverables:**
        *   Shift+Click adds to selection
        *   Cmd/Ctrl+Click toggles selection
        *   Bounding box for multiple selected objects
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Shift+Click adds object without clearing selection
        *   Cmd/Ctrl+Click toggles object selection state
        *   Selection model stores multiple object IDs
        *   Bounding box encompasses all selected objects
        *   Integration test selects 3 objects and drags them together
    *   **Dependencies:** `I8.T3` (object dragging), `I3.T6` (Selection model)
    *   **Parallelizable:** No (needs I8.T3)

<!-- anchor: task-i8-t5 -->
*   **Task 8.5:**
    *   **Task ID:** `I8.T5`
    *   **Description:** Implement undo/redo functionality accessible via Cmd+Z (undo) and Cmd+Shift+Z (redo) on macOS, Ctrl+Z and Ctrl+Shift+Z on Windows. Create EventNavigator service in `lib/infrastructure/event_sourcing/event_navigator.dart` that uses EventReplayer to reconstruct state at target event sequence. Integrate with keyboard shortcuts. Write integration tests for undo/redo workflow (create object, move it, undo move, redo move).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Undo operation)
        *   Architecture blueprint Section 5.2 (Future - Undo/Redo UI design)
    *   **Input Files:**
        *   `lib/infrastructure/event_sourcing/event_replayer.dart` (from I2.T9)
        *   `lib/presentation/providers/document_provider.dart`
    *   **Target Files:**
        *   `lib/infrastructure/event_sourcing/event_navigator.dart`
        *   `lib/application/services/keyboard_shortcut_service.dart`
        *   `integration_test/undo_redo_test.dart`
    *   **Deliverables:**
        *   EventNavigator service with undo(), redo(), canUndo(), canRedo()
        *   Keyboard shortcut handling (Cmd/Ctrl+Z, Cmd/Ctrl+Shift+Z)
        *   Integration with DocumentProvider
        *   Integration tests for undo/redo
    *   **Acceptance Criteria:**
        *   Cmd/Ctrl+Z undoes last action (navigates to previous event sequence)
        *   Cmd/Ctrl+Shift+Z redoes undone action (navigates forward)
        *   canUndo() returns false when at beginning of history
        *   canRedo() returns false when at latest event
        *   Integration test: create rectangle, move it, undo, redo, verify positions
    *   **Dependencies:** `I2.T9` (EventReplayer)
    *   **Parallelizable:** Yes (independent of drag tasks)

---

**Iteration 8 Summary:**
*   **Total Tasks:** 5
*   **Estimated Duration:** 5-6 days
*   **Critical Path:** I8.T1 → I8.T2 (anchor/BCP dragging), I8.T3 → I8.T4 (object dragging, multi-selection), I8.T5 (undo/redo parallel)
*   **Deliverables:** Full editing capability with anchor, handle, and object dragging; multi-selection; undo/redo
