# Iteration 4: Rendering Engine

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-4-overview -->
### Iteration 4: Rendering Engine

<!-- anchor: iteration-4-metadata -->
*   **Iteration ID:** `I4`
*   **Goal:** Build high-performance canvas rendering system using Flutter CustomPainter with viewport transforms and 60 FPS target
*   **Prerequisites:** I3 (domain models), I2 (event system for state updates)

<!-- anchor: iteration-4-tasks -->
*   **Tasks:**

<!-- anchor: task-i4-t1 -->
*   **Task 4.1:**
    *   **Task ID:** `I4.T1`
    *   **Description:** Implement CanvasWidget in `lib/presentation/widgets/canvas/canvas_widget.dart` as main container for vector rendering. Use GestureDetector for input handling (pointer down/move/up, scroll for zoom). Integrate with DocumentProvider to reactively rebuild on state changes. Create basic layout with canvas centered in main window.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.4 (Container Diagram - Canvas Renderer)
        *   Ticket T013 (Canvas System with CustomPainter)
    *   **Input Files:**
        *   `lib/presentation/providers/document_provider.dart` (create if not exists)
    *   **Target Files:**
        *   `lib/presentation/widgets/canvas/canvas_widget.dart`
        *   `lib/presentation/providers/document_provider.dart`
        *   `test/presentation/widgets/canvas/canvas_widget_test.dart`
    *   **Deliverables:**
        *   CanvasWidget with GestureDetector for input
        *   Integration with DocumentProvider (Consumer widget)
        *   Widget tests verifying build
    *   **Acceptance Criteria:**
        *   CanvasWidget builds without errors
        *   GestureDetector captures pointer events
        *   Widget rebuilds when DocumentProvider notifies
        *   Widget tests pass
    *   **Dependencies:** `I1.T1` (project setup), `I3.T6` (Document model)
    *   **Parallelizable:** Yes

<!-- anchor: task-i4-t2 -->
*   **Task 4.2:**
    *   **Task ID:** `I4.T2`
    *   **Description:** Implement Viewport transformation logic in `lib/domain/models/viewport.dart` (if not already complete from I3.T6). Add methods: toScreen(Point), toWorld(Point), toScreenTransform() returning Matrix4. Implement pan and zoom logic. Write unit tests for coordinate transformations at various zoom levels.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 5.3 (Scalability - Viewport Culling)
        *   Ticket T014 (Viewport Transform Pan/Zoom)
    *   **Input Files:**
        *   `lib/domain/models/viewport.dart` (from I3.T6, enhance if needed)
    *   **Target Files:**
        *   `lib/domain/models/viewport.dart`
        *   `test/domain/models/viewport_test.dart`
    *   **Deliverables:**
        *   Viewport with toScreen/toWorld coordinate conversions
        *   Pan (translate) and zoom (scale) transformations
        *   Unit tests verifying transforms at zoom 0.1, 1.0, 10.0
    *   **Acceptance Criteria:**
        *   toScreen/toWorld correctly convert coordinates
        *   Pan updates viewport offset
        *   Zoom scales around cursor point
        *   Unit tests achieve 90%+ coverage
    *   **Dependencies:** `I3.T6` (Viewport model)
    *   **Parallelizable:** Yes (can overlap with I4.T1)

<!-- anchor: task-i4-t3 -->
*   **Task 4.3:**
    *   **Task ID:** `I4.T3`
    *   **Description:** Implement CanvasPainter in `lib/presentation/widgets/canvas/canvas_painter.dart` extending CustomPainter. Override paint() method to render Document objects. Apply viewport transform, render each VectorObject's path with style (fill/stroke). Optimize with shouldRepaint() logic. Write widget tests and performance benchmarks (target 60 FPS with 1000 objects).
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.2 (Rendering - CustomPainter)
        *   Architecture blueprint Section 5.3 (Performance - Rendering Optimizations)
        *   Ticket T015 (Path Rendering with Bezier)
    *   **Input Files:**
        *   `lib/domain/models/document.dart` (from I3.T6)
        *   `lib/domain/models/viewport.dart` (from I4.T2)
    *   **Target Files:**
        *   `lib/presentation/widgets/canvas/canvas_painter.dart`
        *   `test/presentation/widgets/canvas/canvas_painter_test.dart`
        *   `test/performance/rendering_benchmark_test.dart`
    *   **Deliverables:**
        *   CustomPainter rendering all VectorObjects
        *   Bezier curve rendering via Canvas.drawPath()
        *   Viewport transform applied to all objects
        *   Performance benchmark achieving 60 FPS with 1000 simple paths
    *   **Acceptance Criteria:**
        *   paint() renders all objects from Document
        *   Bezier curves rendered smoothly (using Flutter's Path API)
        *   shouldRepaint() returns false when document unchanged
        *   Performance benchmark: 16ms frame time with 1000 objects
        *   Widget tests verify rendering output (golden tests optional)
    *   **Dependencies:** `I3.T6` (Document), `I4.T2` (Viewport)
    *   **Parallelizable:** No (needs I4.T2 for transforms)

<!-- anchor: task-i4-t4 -->
*   **Task 4.4:**
    *   **Task ID:** `I4.T4`
    *   **Description:** Enhance CanvasPainter to render Shape objects by calling shape.toPath() and rendering generated path. Test rendering for all shape types (rectangle, ellipse, polygon, star) with various styles (filled, stroked, both).
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Ticket T016 (Shape Rendering)
        *   Shape models from I3.T4
    *   **Input Files:**
        *   `lib/presentation/widgets/canvas/canvas_painter.dart` (from I4.T3)
        *   `lib/domain/models/shape.dart` (from I3.T4)
    *   **Target Files:**
        *   `lib/presentation/widgets/canvas/canvas_painter.dart` (update)
        *   `test/presentation/widgets/canvas/shape_rendering_test.dart`
    *   **Deliverables:**
        *   Shape rendering via toPath() conversion
        *   Visual tests for all shape types
    *   **Acceptance Criteria:**
        *   All ShapeType variants render correctly
        *   Shapes respect style (fill, stroke, opacity)
        *   Widget tests cover all shape types
    *   **Dependencies:** `I4.T3` (CanvasPainter), `I3.T4` (Shape)
    *   **Parallelizable:** No (needs I4.T3)

<!-- anchor: task-i4-t5 -->
*   **Task 4.5:**
    *   **Task ID:** `I4.T5`
    *   **Description:** Implement selection visualization in CanvasPainter. Render bounding boxes for selected objects, anchor points for direct selection, and BCP handles. Create OverlayPainter in `lib/presentation/widgets/canvas/overlay_painter.dart` for tool-specific overlays (guides, cursors). Write widget tests.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.4 (Container Diagram - Tool Overlay)
        *   Ticket T017 (Selection Visualization)
    *   **Input Files:**
        *   `lib/presentation/widgets/canvas/canvas_painter.dart` (from I4.T4)
        *   `lib/domain/models/selection.dart` (from I3.T6)
    *   **Target Files:**
        *   `lib/presentation/widgets/canvas/canvas_painter.dart` (update for selection rendering)
        *   `lib/presentation/widgets/canvas/overlay_painter.dart`
        *   `test/presentation/widgets/canvas/selection_visualization_test.dart`
    *   **Deliverables:**
        *   Bounding box rendering for selected objects
        *   Anchor point rendering (circles at anchor positions)
        *   BCP handle rendering (lines from anchor to control points)
        *   OverlayPainter for temporary tool feedback
    *   **Acceptance Criteria:**
        *   Selected objects show blue bounding box (configurable color)
        *   Anchor points render as small circles when path selected
        *   BCP handles render as lines with endpoint circles
        *   OverlayPainter renders independently from main canvas
        *   Widget tests verify selection rendering
    *   **Dependencies:** `I4.T4` (Shape rendering), `I3.T6` (Selection model)
    *   **Parallelizable:** No (needs I4.T4)

<!-- anchor: task-i4-t6 -->
*   **Task 4.6:**
    *   **Task ID:** `I4.T6`
    *   **Description:** Integrate pan/zoom gestures into CanvasWidget. Handle scroll events for zoom (pinch on trackpad, mouse wheel). Handle pan gesture (two-finger drag, or space+drag). Update Viewport model on gesture and trigger repaint. Write widget tests for gesture handling.
    *   **Agent Type Hint:** `FrontendAgent`
    *   **Inputs:**
        *   Ticket T014 (Viewport Transform Pan/Zoom)
    *   **Input Files:**
        *   `lib/presentation/widgets/canvas/canvas_widget.dart` (from I4.T1)
        *   `lib/domain/models/viewport.dart` (from I4.T2)
    *   **Target Files:**
        *   `lib/presentation/widgets/canvas/canvas_widget.dart` (update with gesture handlers)
        *   `test/presentation/widgets/canvas/pan_zoom_test.dart`
    *   **Deliverables:**
        *   Scroll event handling for zoom
        *   Pan gesture handling (update viewport offset)
        *   Viewport state updates trigger repaint
        *   Widget tests simulating gestures
    *   **Acceptance Criteria:**
        *   Scroll wheel zooms in/out around cursor position
        *   Pan gesture translates viewport
        *   Zoom constrained to reasonable range (0.1x - 100x)
        *   Widget tests verify viewport updates
    *   **Dependencies:** `I4.T1` (CanvasWidget), `I4.T2` (Viewport)
    *   **Parallelizable:** No (needs I4.T2)

---

**Iteration 4 Summary:**
*   **Total Tasks:** 6
*   **Estimated Duration:** 5-6 days
*   **Critical Path:** I4.T1/I4.T2 → I4.T3 → I4.T4 → I4.T5, I4.T6 (parallel with I4.T5)
*   **Deliverables:** Working canvas renderer with 60 FPS performance, pan/zoom, selection visualization
