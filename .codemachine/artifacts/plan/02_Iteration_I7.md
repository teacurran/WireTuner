# Iteration 7: Shape Tools

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-7-overview -->
### Iteration 7: Shape Tools

<!-- anchor: iteration-7-metadata -->
*   **Iteration ID:** `I7`
*   **Goal:** Implement shape creation tools (Rectangle, Ellipse, Polygon, Star) with drag-to-create interaction
*   **Prerequisites:** I5 (tool framework)

<!-- anchor: iteration-7-tasks -->
*   **Tasks:**

<!-- anchor: task-i7-t1 -->
*   **Task 7.1:**
    *   **Task ID:** `I7.T1`
    *   **Description:** Implement RectangleTool in `lib/application/tools/rectangle_tool.dart`. Click-and-drag to define bounding box, create Shape with ShapeType.RECTANGLE on pointer up. Generate CreateShapeEvent with parameters {width, height, position}. Support Shift+drag for square constraint. Write integration tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T025 (Rectangle Tool)
        *   Shape model from I3.T4
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/models/shape.dart` (from I3.T4)
        *   `lib/infrastructure/event_sourcing/event_recorder.dart` (from I2.T3)
    *   **Target Files:**
        *   `lib/application/tools/rectangle_tool.dart`
        *   `lib/domain/events/object_events.dart` (add CreateShapeEvent if not exists)
        *   `test/application/tools/rectangle_tool_test.dart`
        *   `integration_test/rectangle_tool_workflow_test.dart`
    *   **Deliverables:**
        *   RectangleTool with drag-to-create
        *   Shift modifier for square constraint
        *   CreateShapeEvent recording
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Drag creates rectangle with correct dimensions
        *   Shift+drag creates square (width = height)
        *   CreateShapeEvent persisted on pointer up
        *   Rectangle renders in canvas
        *   Integration test creates rectangle successfully
    *   **Dependencies:** `I5.T1` (ITool), `I3.T4` (Shape), `I2.T3` (EventRecorder)
    *   **Parallelizable:** Yes

<!-- anchor: task-i7-t2 -->
*   **Task 7.2:**
    *   **Task ID:** `I7.T2`
    *   **Description:** Implement EllipseTool in `lib/application/tools/ellipse_tool.dart`. Similar to RectangleTool but creates ShapeType.ELLIPSE. Drag defines bounding box, ellipse inscribed. Shift+drag for circle constraint. Generate CreateShapeEvent. Write integration tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T026 (Ellipse Tool)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/models/shape.dart` (from I3.T4)
    *   **Target Files:**
        *   `lib/application/tools/ellipse_tool.dart`
        *   `test/application/tools/ellipse_tool_test.dart`
        *   `integration_test/ellipse_tool_workflow_test.dart`
    *   **Deliverables:**
        *   EllipseTool with drag-to-create
        *   Shift modifier for circle
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Drag creates ellipse inscribed in bounding box
        *   Shift+drag creates circle
        *   CreateShapeEvent persisted
        *   Ellipse renders with Bezier approximation
        *   Integration test creates ellipse successfully
    *   **Dependencies:** `I7.T1` (RectangleTool pattern), `I3.T4` (Shape)
    *   **Parallelizable:** Yes (can run in parallel with I7.T1)

<!-- anchor: task-i7-t3 -->
*   **Task 7.3:**
    *   **Task ID:** `I7.T3`
    *   **Description:** Implement PolygonTool in `lib/application/tools/polygon_tool.dart`. Click defines center, drag defines radius. Number of sides configurable (default 6). Generate CreateShapeEvent with parameters {sides, radius, center}. Show live preview during drag. Write integration tests for 3-sided (triangle) and 8-sided polygons.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T027 (Polygon Tool)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/models/shape.dart` (from I3.T4)
    *   **Target Files:**
        *   `lib/application/tools/polygon_tool.dart`
        *   `test/application/tools/polygon_tool_test.dart`
        *   `integration_test/polygon_tool_workflow_test.dart`
    *   **Deliverables:**
        *   PolygonTool with click-center-drag-radius interaction
        *   Configurable side count (3-20)
        *   Live preview during drag
        *   Integration tests for triangle and octagon
    *   **Acceptance Criteria:**
        *   Click defines center point
        *   Drag distance defines radius
        *   Polygon has correct number of sides
        *   Regular polygon (all sides equal length)
        *   Integration tests create 3-sided and 8-sided polygons
    *   **Dependencies:** `I5.T1` (ITool), `I3.T4` (Shape.toPath() for polygon)
    *   **Parallelizable:** Yes (can overlap with I7.T1/I7.T2)

<!-- anchor: task-i7-t4 -->
*   **Task 7.4:**
    *   **Task ID:** `I7.T4`
    *   **Description:** Implement StarTool in `lib/application/tools/star_tool.dart`. Similar to PolygonTool but creates star with inner and outer radius. Click defines center, drag defines outer radius, inner radius = outer * 0.5 (default ratio). Number of points configurable (default 5). Generate CreateShapeEvent with parameters {points, outerRadius, innerRadius, center}. Write integration tests for 5-point and 8-point stars.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T028 (Star Tool)
    *   **Input Files:**
        *   `lib/application/tools/tool_interface.dart` (from I5.T1)
        *   `lib/domain/models/shape.dart` (from I3.T4)
    *   **Target Files:**
        *   `lib/application/tools/star_tool.dart`
        *   `test/application/tools/star_tool_test.dart`
        *   `integration_test/star_tool_workflow_test.dart`
    *   **Deliverables:**
        *   StarTool with click-center-drag-radius interaction
        *   Configurable point count and inner/outer ratio
        *   Live preview
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Click defines center
        *   Drag distance defines outer radius
        *   Inner radius = outer * 0.5 by default
        *   Star has alternating outer/inner points
        *   Integration tests create 5-point and 8-point stars
    *   **Dependencies:** `I7.T3` (PolygonTool pattern), `I3.T4` (Shape)
    *   **Parallelizable:** No (reuses pattern from I7.T3)

<!-- anchor: task-i7-t5 -->
*   **Task 7.5:**
    *   **Task ID:** `I7.T5`
    *   **Description:** Update tool toolbar UI to include buttons for Rectangle, Ellipse, Polygon, and Star tools. Add icons for each tool (use Material Design icons or custom SVG). Test tool switching between all tools. Write widget tests.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Tool implementations from I7.T1-I7.T4
    *   **Input Files:**
        *   `lib/presentation/widgets/toolbar/tool_toolbar.dart` (from I5.T6)
    *   **Target Files:**
        *   `lib/presentation/widgets/toolbar/tool_toolbar.dart` (update)
        *   `test/presentation/widgets/toolbar/tool_toolbar_updated_test.dart`
    *   **Deliverables:**
        *   Toolbar with all shape tool buttons
        *   Tool switching functional
        *   Widget tests
    *   **Acceptance Criteria:**
        *   All 7 tools visible in toolbar (Selection, Direct Selection, Pen, Rectangle, Ellipse, Polygon, Star)
        *   Clicking each button activates corresponding tool
        *   Active tool highlighted
        *   Widget tests verify all buttons functional
    *   **Dependencies:** `I7.T1`, `I7.T2`, `I7.T3`, `I7.T4` (tool implementations)
    *   **Parallelizable:** No (needs all tools implemented)

---

**Iteration 7 Summary:**
*   **Total Tasks:** 5
*   **Estimated Duration:** 4-5 days
*   **Critical Path:** I7.T1/I7.T2/I7.T3 (parallel shape tools) → I7.T4 (star tool) → I7.T5 (toolbar update)
*   **Deliverables:** All basic shape creation tools functional, updated toolbar UI
