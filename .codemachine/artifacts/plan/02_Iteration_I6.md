# Iteration 6: Pen Tool

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-6-overview -->
### Iteration 6: Pen Tool

<!-- anchor: iteration-6-metadata -->
*   **Iteration ID:** `I6`
*   **Goal:** Implement fully functional Pen Tool for creating paths with straight segments and Bezier curves
*   **Prerequisites:** I5 (tool framework)

<!-- anchor: iteration-6-tasks -->
*   **Tasks:**

<!-- anchor: task-i6-t1 -->
*   **Task 6.1:**
    *   **Task ID:** `I6.T1`
    *   **Description:** Implement PenTool state machine in `lib/application/tools/pen_tool.dart`. Define states: IDLE, CREATING_PATH, ADJUSTING_HANDLES. Implement click-to-add-anchor behavior (generates CreatePathEvent on first click, AddAnchorEvent on subsequent clicks). Double-click or press Enter to finish path (FinishPathEvent). Write unit tests for state transitions.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Pen tool)
        *   Ticket T021 (Pen Tool - Create Anchor Points)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/infrastructure/event_sourcing/event_recorder.dart` (from I2.T3)
        *   `lib/domain/events/path_events.dart` (from I2.T1)
    *   **Target Files:**
        *   `lib/application/tools/pen_tool.dart`
        *   `test/application/tools/pen_tool_test.dart`
    *   **Deliverables:**
        *   PenTool with state machine (IDLE → CREATING_PATH → IDLE)
        *   Click handling to add anchors
        *   Double-click/Enter to finish path
        *   Unit tests for all state transitions
    *   **Acceptance Criteria:**
        *   First click creates new path (CreatePathEvent)
        *   Subsequent clicks add anchors (AddAnchorEvent)
        *   Double-click or Enter finishes path (FinishPathEvent)
        *   ESC key cancels path creation
        *   Unit tests achieve 85%+ coverage
    *   **Dependencies:** `I5.T1` (ITool), `I2.T1` (PathEvents), `I2.T3` (EventRecorder)
    *   **Parallelizable:** Yes

<!-- anchor: task-i6-t2 -->
*   **Task 6.2:**
    *   **Task ID:** `I6.T2`
    *   **Description:** Enhance PenTool to create straight line segments by default (no Bezier control points). Each click adds corner anchor without handles. Test creating multi-segment straight paths. Write integration tests for complete straight path workflow.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T022 (Pen Tool - Straight Segments)
    *   **Input Files:**
        *   `lib/application/tools/pen_tool.dart` (from I6.T1)
    *   **Target Files:**
        *   `lib/application/tools/pen_tool.dart` (update)
        *   `integration_test/pen_tool_straight_path_test.dart`
    *   **Deliverables:**
        *   Straight line segment creation
        *   Corner anchors (no BCP handles)
        *   Integration tests for straight paths
    *   **Acceptance Criteria:**
        *   Clicking creates straight segments between anchors
        *   Anchors have anchorType = corner, no handles
        *   Path renders as expected in canvas
        *   Integration test creates 5-point straight path successfully
    *   **Dependencies:** `I6.T1` (PenTool state machine)
    *   **Parallelizable:** No (needs I6.T1)

<!-- anchor: task-i6-t3 -->
*   **Task 6.3:**
    *   **Task ID:** `I6.T3`
    *   **Description:** Implement Bezier curve creation in PenTool. Click-and-drag to create anchor with Bezier handles. Dragging out from click position creates symmetric handles (smooth anchor type). Generate AddAnchorEvent with handleOut set. Implement Bezier segment between previous anchor's handleOut and new anchor's handleIn. Write integration tests creating curved paths.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Segment with Bezier)
        *   Ticket T023 (Pen Tool - Bezier Curves)
    *   **Input Files:**
        *   `lib/application/tools/pen_tool.dart` (from I6.T2)
        *   `lib/domain/models/anchor_point.dart` (from I3.T2)
    *   **Target Files:**
        *   `lib/application/tools/pen_tool.dart` (update)
        *   `integration_test/pen_tool_bezier_path_test.dart`
    *   **Deliverables:**
        *   Click-and-drag creates Bezier handles
        *   Smooth anchor type with symmetric handles
        *   Bezier segments rendered as curves
        *   Integration tests for curved paths
    *   **Acceptance Criteria:**
        *   Click-and-drag generates handleOut in direction of drag
        *   Anchor type = smooth, handleIn = -handleOut (symmetric)
        *   Bezier curve segment created using cubic Bezier
        *   Rendered curve matches expected shape
        *   Integration test creates S-curve path
    *   **Dependencies:** `I6.T2` (straight segments), `I3.T2` (AnchorPoint with handles)
    *   **Parallelizable:** No (needs I6.T2)

<!-- anchor: task-i6-t4 -->
*   **Task 6.4:**
    *   **Task ID:** `I6.T4`
    *   **Description:** Add BCP adjustment to PenTool. After creating anchor with Bezier handles, allow clicking anchor again to adjust handles independently (converts to corner anchor type). Alt+drag to break handle symmetry. Generate ModifyAnchorEvent when adjusting. Write integration tests for handle manipulation workflow.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T024 (Pen Tool - Adjust BCPs)
    *   **Input Files:**
        *   `lib/application/tools/pen_tool.dart` (from I6.T3)
    *   **Target Files:**
        *   `lib/application/tools/pen_tool.dart` (update)
        *   `lib/domain/events/path_events.dart` (add ModifyAnchorEvent if not exists)
        *   `integration_test/pen_tool_handle_adjustment_test.dart`
    *   **Deliverables:**
        *   Click existing anchor to adjust handles
        *   Alt+drag breaks handle symmetry (corner anchor)
        *   ModifyAnchorEvent recorded
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Clicking last anchor enters ADJUSTING_HANDLES state
        *   Dragging adjusts handleOut
        *   Alt+drag adjusts handleOut independently (corner type)
        *   ModifyAnchorEvent persisted to event log
        *   Integration test adjusts handle and verifies curve shape
    *   **Dependencies:** `I6.T3` (Bezier curves)
    *   **Parallelizable:** No (needs I6.T3)

<!-- anchor: task-i6-t5 -->
*   **Task 6.5:**
    *   **Task ID:** `I6.T5`
    *   **Description:** Create PlantUML State Diagram in `docs/diagrams/tool_state_machines.puml` documenting PenTool state machine (IDLE → CREATING_PATH → ADJUSTING_HANDLES → IDLE). Include transitions, trigger events (click, drag, double-click, ESC), and event generation (CreatePathEvent, AddAnchorEvent, etc.).
    *   **Agent Type Hint:** `DocumentationAgent` or `DiagrammingAgent`
    *   **Inputs:**
        *   Implemented PenTool from I6.T1-I6.T4
    *   **Input Files:**
        *   `lib/application/tools/pen_tool.dart` (from I6.T4)
    *   **Target Files:**
        *   `docs/diagrams/tool_state_machines.puml`
    *   **Deliverables:**
        *   PlantUML State Diagram for PenTool
        *   Diagram renders without syntax errors
    *   **Acceptance Criteria:**
        *   Diagram accurately reflects PenTool states
        *   All transitions labeled with triggers
        *   Events generated shown as actions
        *   Diagram validates and renders correctly
    *   **Dependencies:** `I6.T4` (complete PenTool implementation)
    *   **Parallelizable:** Yes (documentation task)

---

**Iteration 6 Summary:**
*   **Total Tasks:** 5
*   **Estimated Duration:** 4-5 days
*   **Critical Path:** I6.T1 → I6.T2 → I6.T3 → I6.T4 (sequential feature building), I6.T5 (parallel documentation)
*   **Deliverables:** Fully functional Pen Tool with straight and Bezier segments, handle adjustment, state diagram
