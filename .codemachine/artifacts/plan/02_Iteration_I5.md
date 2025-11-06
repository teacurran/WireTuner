# Iteration 5: Tool System Architecture

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-5-overview -->
### Iteration 5: Tool System Architecture

<!-- anchor: iteration-5-metadata -->
*   **Iteration ID:** `I5`
*   **Goal:** Establish tool framework and implement Selection and Direct Selection tools for object and anchor manipulation
*   **Prerequisites:** I4 (canvas rendering), I2 (event recording)

<!-- anchor: iteration-5-tasks -->
*   **Tasks:**

<!-- anchor: task-i5-t1 -->
*   **Task 5.1:**
    *   **Task ID:** `I5.T1`
    *   **Description:** Define ITool abstract interface in `lib/application/tools/tool_interface.dart`. Specify methods: onActivate(), onDeactivate(), onPointerDown/Move/Up(), onKeyPress(), renderOverlay(Canvas). Define Cursor get cursor property. All tools will implement this interface.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.6 (Internal API - Tool Interface)
        *   Ticket T018 (Tool Framework)
    *   **Input Files:** []
    *   **Target Files:**
        *   `lib/application/tools/tool_interface.dart`
    *   **Deliverables:**
        *   ITool abstract interface
        *   Method signatures for all tool lifecycle and event handling
    *   **Acceptance Criteria:**
        *   Interface compiles without errors
        *   All required methods defined with clear documentation
        *   Cursor property defined (returns SystemMouseCursor or custom)
    *   **Dependencies:** `I1.T1` (project setup)
    *   **Parallelizable:** Yes

<!-- anchor: task-i5-t2 -->
*   **Task 5.2:**
    *   **Task ID:** `I5.T2`
    *   **Description:** Implement ToolManager in `lib/application/tools/tool_manager.dart` as singleton service. Manage active tool state, provide setActiveTool(ITool), route pointer/keyboard events to active tool. Integrate with CanvasWidget to receive input events. Create ToolManagerProvider for state management.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.5 (Component Diagram - Tool Manager)
        *   Ticket T018 (Tool Framework)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
    *   **Target Files:**
        *   `lib/application/tools/tool_manager.dart`
        *   `lib/presentation/providers/tool_manager_provider.dart`
        *   `test/application/tools/tool_manager_test.dart`
    *   **Deliverables:**
        *   ToolManager service with tool switching logic
        *   Event routing to active tool
        *   Provider for UI integration
        *   Unit tests with mock tools
    *   **Acceptance Criteria:**
        *   setActiveTool() calls onDeactivate() on previous tool, onActivate() on new tool
        *   Pointer events routed to active tool's handlers
        *   Keyboard events routed to active tool
        *   Unit tests verify routing and lifecycle
    *   **Dependencies:** `I5.T1` (ITool interface)
    *   **Parallelizable:** No (needs I5.T1)

<!-- anchor: task-i5-t3 -->
*   **Task 5.3:**
    *   **Task ID:** `I5.T3`
    *   **Description:** Implement HitTestService in `lib/domain/services/hit_test_service.dart` for detecting which object/anchor is under a point. Provide methods: hitTestObjects(Document, Point) returning nearest object, hitTestAnchors(Path, Point) returning anchor index. Use distance calculations and path containment logic. Write comprehensive unit tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.5 (Component Diagram - Hit Test Service)
    *   **Input Files:**
        *   `lib/domain/models/document.dart` (from I3.T6)
        *   `lib/domain/models/path.dart` (from I3.T3)
    *   **Target Files:**
        *   `lib/domain/services/hit_test_service.dart`
        *   `test/domain/services/hit_test_service_test.dart`
    *   **Deliverables:**
        *   HitTestService with hitTestObjects(), hitTestAnchors()
        *   Distance-based hit detection for paths
        *   Bounds-based hit detection for shapes
        *   Unit tests covering edge cases (overlapping objects, small objects)
    *   **Acceptance Criteria:**
        *   hitTestObjects() returns nearest object within tolerance (5px)
        *   hitTestAnchors() returns anchor index within tolerance (8px)
        *   Returns null if no object/anchor within tolerance
        *   Unit tests achieve 90%+ coverage
    *   **Dependencies:** `I3.T6` (Document), `I3.T3` (Path)
    *   **Parallelizable:** Yes (independent of tool implementations)

<!-- anchor: task-i5-t4 -->
*   **Task 5.4:**
    *   **Task ID:** `I5.T4`
    *   **Description:** Implement SelectionTool in `lib/application/tools/selection_tool.dart`. Click to select objects, Cmd+Click to toggle selection, drag to move selected objects. Generate MoveObjectEvent during drag (sampled at 50ms via EventRecorder). Use HitTestService for object detection. Write widget and integration tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Tool interactions)
        *   Ticket T019 (Selection Tool)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/services/hit_test_service.dart` (from I5.T3)
        *   `lib/infrastructure/event_sourcing/event_recorder.dart` (from I2.T3)
    *   **Target Files:**
        *   `lib/application/tools/selection_tool.dart`
        *   `test/application/tools/selection_tool_test.dart`
        *   `integration_test/selection_tool_workflow_test.dart`
    *   **Deliverables:**
        *   SelectionTool implementing ITool
        *   Click-to-select logic with modifier key support
        *   Drag-to-move with event recording
        *   Integration tests for full selection workflow
    *   **Acceptance Criteria:**
        *   Click on object selects it (updates Selection in Document)
        *   Cmd+Click toggles selection state
        *   Drag generates MoveObjectEvent at 50ms intervals
        *   Cursor changes based on hover state (arrow / move cursor)
        *   Integration tests pass
    *   **Dependencies:** `I5.T1` (ITool), `I5.T2` (ToolManager), `I5.T3` (HitTestService), `I2.T3` (EventRecorder)
    *   **Parallelizable:** No (needs I5.T3)

<!-- anchor: task-i5-t5 -->
*   **Task 5.5:**
    *   **Task ID:** `I5.T5`
    *   **Description:** Implement DirectSelectionTool in `lib/application/tools/direct_selection_tool.dart`. Click to select individual anchor points on paths. Display anchor points and BCP handles when path selected. Drag anchors to move them (generates MoveAnchorEvent). Use HitTestService.hitTestAnchors(). Write widget and integration tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T020 (Direct Selection Tool)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/services/hit_test_service.dart` (from I5.T3)
        *   `lib/infrastructure/event_sourcing/event_recorder.dart` (from I2.T3)
    *   **Target Files:**
        *   `lib/application/tools/direct_selection_tool.dart`
        *   `test/application/tools/direct_selection_tool_test.dart`
        *   `integration_test/direct_selection_workflow_test.dart`
    *   **Deliverables:**
        *   DirectSelectionTool implementing ITool
        *   Anchor selection logic
        *   Anchor dragging with MoveAnchorEvent recording
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Click on anchor selects it
        *   Drag anchor generates MoveAnchorEvent at 50ms intervals
        *   Anchor points and BCP handles rendered via renderOverlay()
        *   Cursor changes to crosshair when hovering anchor
        *   Integration tests verify anchor manipulation workflow
    *   **Dependencies:** `I5.T1` (ITool), `I5.T3` (HitTestService), `I2.T3` (EventRecorder)
    *   **Parallelizable:** Yes (can run in parallel with I5.T4)

<!-- anchor: task-i5-t6 -->
*   **Task 5.6:**
    *   **Task ID:** `I5.T6`
    *   **Description:** Create tool toolbar UI in `lib/presentation/widgets/toolbar/tool_toolbar.dart`. Display buttons for each tool (Selection, Direct Selection, Pen, Rectangle, Ellipse, Polygon, Star). Clicking button calls ToolManager.setActiveTool(). Highlight active tool. Write widget tests.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Ticket T018 (Tool Framework)
    *   **Input Files:**
        *   `lib/presentation/providers/tool_manager_provider.dart` (from I5.T2)
    *   **Target Files:**
        *   `lib/presentation/widgets/toolbar/tool_toolbar.dart`
        *   `lib/presentation/widgets/toolbar/tool_button.dart`
        *   `test/presentation/widgets/toolbar/tool_toolbar_test.dart`
    *   **Deliverables:**
        *   Tool toolbar widget with icon buttons
        *   Active tool highlighting
        *   Integration with ToolManagerProvider
        *   Widget tests
    *   **Acceptance Criteria:**
        *   Toolbar displays all tool buttons
        *   Clicking button activates corresponding tool
        *   Active tool button highlighted (different color/border)
        *   Widget tests verify button interactions
    *   **Dependencies:** `I5.T2` (ToolManager)
    *   **Parallelizable:** Yes (UI task, can overlap with tool implementations)

---

**Iteration 5 Summary:**
*   **Total Tasks:** 6
*   **Estimated Duration:** 4-5 days
*   **Critical Path:** I5.T1 → I5.T2, I5.T3 → I5.T4/I5.T5 (tool implementations), I5.T6 (parallel UI)
*   **Deliverables:** Tool framework with Selection and Direct Selection tools, tool toolbar UI
