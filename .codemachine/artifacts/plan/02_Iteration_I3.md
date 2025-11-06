# Iteration 3: Vector Data Model

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-3-overview -->
### Iteration 3: Vector Data Model

<!-- anchor: iteration-3-metadata -->
*   **Iteration ID:** `I3`
*   **Goal:** Implement immutable domain models for vector objects (Document, Path, Shape, Segment, AnchorPoint, Style, Transform) with comprehensive unit tests
*   **Prerequisites:** I1 (project setup)

<!-- anchor: iteration-3-tasks -->
*   **Tasks:**

<!-- anchor: task-i3-t1 -->
*   **Task 3.1:**
    *   **Task ID:** `I3.T1`
    *   **Description:** Implement core geometry primitives in `lib/domain/models/`: Point (x, y), Rectangle (bounds), Matrix4 wrapper for transforms. Use vector_math package. Make all classes immutable with const constructors where possible. Write extensive unit tests for geometric operations (distance, intersection, transformation).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Geometry primitives)
        *   Ticket T009 (Core Geometry Primitives)
    *   **Input Files:** []
    *   **Target Files:**
        *   `lib/domain/models/geometry/point.dart`
        *   `lib/domain/models/geometry/rectangle.dart`
        *   `lib/domain/models/transform.dart`
        *   `test/domain/models/geometry/geometry_test.dart`
    *   **Deliverables:**
        *   Immutable Point, Rectangle classes
        *   Transform class wrapping Matrix4
        *   Unit tests achieving 90%+ coverage
    *   **Acceptance Criteria:**
        *   All classes are immutable (@immutable annotation)
        *   Point supports arithmetic operations (add, subtract, distance)
        *   Rectangle supports intersection, union, containsPoint
        *   Transform supports translate, rotate, scale, composition
        *   Unit tests verify all operations with edge cases
    *   **Dependencies:** `I1.T1` (project setup, vector_math dependency)
    *   **Parallelizable:** Yes

<!-- anchor: task-i3-t2 -->
*   **Task 3.2:**
    *   **Task ID:** `I3.T2`
    *   **Description:** Implement AnchorPoint and Segment models in `lib/domain/models/`. AnchorPoint has position, optional handleIn/handleOut (BCPs), and anchorType enum (corner/smooth/symmetric). Segment connects two anchors with type (line/bezier/arc). Both immutable with copyWith() methods. Write unit tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - AnchorPoint, Segment)
        *   Ticket T010 (Path Data Model)
    *   **Input Files:**
        *   `lib/domain/models/geometry/point.dart` (from I3.T1)
    *   **Target Files:**
        *   `lib/domain/models/anchor_point.dart`
        *   `lib/domain/models/segment.dart`
        *   `test/domain/models/anchor_point_test.dart`
        *   `test/domain/models/segment_test.dart`
    *   **Deliverables:**
        *   Immutable AnchorPoint class with BCP handles
        *   Segment class with line/bezier/arc types
        *   copyWith() methods for immutable updates
        *   Unit tests for anchor types and segment construction
    *   **Acceptance Criteria:**
        *   AnchorPoint correctly represents corner, smooth, symmetric types
        *   Segment stores correct anchor references and control points
        *   copyWith() creates new instances with modified fields
        *   Unit tests achieve 85%+ coverage
    *   **Dependencies:** `I3.T1` (Point)
    *   **Parallelizable:** Yes (can overlap with I3.T1)

<!-- anchor: task-i3-t3 -->
*   **Task 3.3:**
    *   **Task ID:** `I3.T3`
    *   **Description:** Implement Path model in `lib/domain/models/path.dart`. Path contains list of Segments, closed boolean flag. Provide methods: bounds(), length(), pointAt(t), addSegment(). Make immutable with copyWith(). Write unit tests including Bezier curve paths.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Path)
        *   Ticket T010 (Path Data Model)
    *   **Input Files:**
        *   `lib/domain/models/segment.dart` (from I3.T2)
    *   **Target Files:**
        *   `lib/domain/models/path.dart`
        *   `test/domain/models/path_test.dart`
    *   **Deliverables:**
        *   Immutable Path class with segment list
        *   bounds() calculates bounding rectangle
        *   length() computes total path length
        *   pointAt(t) returns point along path at parameter t [0-1]
        *   Unit tests with straight and curved paths
    *   **Acceptance Criteria:**
        *   Path correctly stores segments and closed state
        *   bounds() accurate for Bezier curves (use control point bounds initially)
        *   length() approximates arc length for curves
        *   Unit tests cover open/closed paths, straight/curved segments
    *   **Dependencies:** `I3.T2` (Segment, AnchorPoint)
    *   **Parallelizable:** No (needs I3.T2)

<!-- anchor: task-i3-t4 -->
*   **Task 3.4:**
    *   **Task ID:** `I3.T4`
    *   **Description:** Implement Style model in `lib/domain/models/style.dart` for fill/stroke properties. Include fill color, stroke color, stroke width, opacity, blend mode. Make immutable. Implement Shape model in `lib/domain/models/shape.dart` with ShapeType enum (rect, ellipse, polygon, star) and parameters map. Shape has toPath() method to generate Path representation. Write unit tests for all shape types.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Style, Shape)
        *   Ticket T011 (Shape Data Model)
    *   **Input Files:**
        *   `lib/domain/models/path.dart` (from I3.T3)
    *   **Target Files:**
        *   `lib/domain/models/style.dart`
        *   `lib/domain/models/shape.dart`
        *   `test/domain/models/style_test.dart`
        *   `test/domain/models/shape_test.dart`
    *   **Deliverables:**
        *   Immutable Style class with paint properties
        *   Shape class with parametric definitions
        *   toPath() implementations for rect, ellipse, polygon, star
        *   Unit tests verifying shape-to-path conversion
    *   **Acceptance Criteria:**
        *   Style stores all paint properties
        *   Shape.toPath() generates correct Path for each ShapeType
        *   Rectangle shape produces 4-segment closed path
        *   Ellipse shape produces Bezier approximation
        *   Polygon shape produces n-sided regular polygon
        *   Star shape produces n-pointed star with inner/outer radii
        *   Unit tests cover all shape types and edge cases
    *   **Dependencies:** `I3.T3` (Path)
    *   **Parallelizable:** No (needs I3.T3)

<!-- anchor: task-i3-t5 -->
*   **Task ID:** `I3.T5`
*   **Description:** Implement VectorObject abstract base class and Layer model in `lib/domain/models/`. VectorObject has id, transform, style, and abstract methods bounds(), hitTest(). Layer has id, name, visible, locked, and list of VectorObjects. Make both immutable. Update Path and Shape to extend VectorObject. Write unit tests.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - VectorObject, Layer)
    *   **Input Files:**
        *   `lib/domain/models/path.dart` (from I3.T3)
        *   `lib/domain/models/shape.dart` (from I3.T4)
        *   `lib/domain/models/transform.dart` (from I3.T1)
        *   `lib/domain/models/style.dart` (from I3.T4)
    *   **Target Files:**
        *   `lib/domain/models/vector_object.dart`
        *   `lib/domain/models/layer.dart`
        *   `lib/domain/models/path.dart` (update to extend VectorObject)
        *   `lib/domain/models/shape.dart` (update to extend VectorObject)
        *   `test/domain/models/vector_object_test.dart`
        *   `test/domain/models/layer_test.dart`
    *   **Deliverables:**
        *   VectorObject abstract base class
        *   Path and Shape extending VectorObject
        *   Layer model with object list
        *   Unit tests for layer operations (add, remove, reorder objects)
    *   **Acceptance Criteria:**
        *   VectorObject defines common interface for all drawable objects
        *   Path.bounds() accounts for transform matrix
        *   Shape.bounds() computed from generated path
        *   Layer correctly manages object list
        *   Unit tests verify polymorphism (Layer can hold Path or Shape)
    *   **Dependencies:** `I3.T3` (Path), `I3.T4` (Shape, Style)
    *   **Parallelizable:** No (needs I3.T4)

<!-- anchor: task-i3-t6 -->
*   **Task 3.6:**
    *   **Task ID:** `I3.T6`
    *   **Description:** Implement Document model in `lib/domain/models/document.dart` as root aggregate. Contains list of Layers, Selection, Viewport. Provide query methods: getObjectById(), getAllObjects(), getObjectsInBounds(). Make immutable with copyWith(). Write comprehensive unit tests including complex documents with nested objects.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model - Document)
        *   Architecture blueprint Section 4.6 (Internal API - Document State)
        *   Ticket T012 (Document Model)
    *   **Input Files:**
        *   `lib/domain/models/layer.dart` (from I3.T5)
        *   `lib/domain/models/geometry/rectangle.dart` (from I3.T1)
    *   **Target Files:**
        *   `lib/domain/models/document.dart`
        *   `lib/domain/models/selection.dart`
        *   `lib/domain/models/viewport.dart`
        *   `test/domain/models/document_test.dart`
    *   **Deliverables:**
        *   Immutable Document class with layer hierarchy
        *   Selection model (set of object IDs, anchor indices)
        *   Viewport model (pan, zoom, canvas size)
        *   Query methods (getObjectById, getAllObjects, getObjectsInBounds)
        *   Unit tests with multi-layer documents
    *   **Acceptance Criteria:**
        *   Document correctly manages layer list
        *   getObjectById() searches across all layers
        *   getAllObjects() flattens layer hierarchy
        *   getObjectsInBounds() uses bounds() for filtering
        *   Selection tracks object IDs and anchor indices
        *   Viewport supports pan/zoom transformations
        *   Unit tests achieve 90%+ coverage for Document class
    *   **Dependencies:** `I3.T5` (Layer, VectorObject)
    *   **Parallelizable:** No (final task, needs all previous I3 tasks)

<!-- anchor: task-i3-t7 -->
*   **Task 3.7:**
    *   **Task ID:** `I3.T7`
    *   **Description:** Generate PlantUML ERD diagram in `docs/diagrams/database_erd.puml` showing SQLite schema (metadata, events, snapshots tables) with relationships and field types. Also generate PlantUML Class Diagram in `docs/diagrams/domain_model_class.puml` showing in-memory domain model (Document, Layer, VectorObject hierarchy, Path, Shape, Segment, AnchorPoint, Style, Transform). Both diagrams should match implemented models.
    *   **Agent Type Hint:** `DocumentationAgent` or `DiagrammingAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model ERD)
        *   Implemented domain models from I3.T1-I3.T6
        *   Database schema from I1.T5
    *   **Input Files:**
        *   `lib/domain/models/*.dart` (all domain models)
        *   `lib/infrastructure/persistence/schema.dart`
    *   **Target Files:**
        *   `docs/diagrams/database_erd.puml`
        *   `docs/diagrams/domain_model_class.puml`
    *   **Deliverables:**
        *   PlantUML ERD diagram for SQLite schema
        *   PlantUML Class Diagram for domain model
        *   Both diagrams render without syntax errors
    *   **Acceptance Criteria:**
        *   ERD accurately reflects metadata, events, snapshots tables with primary/foreign keys
        *   Class diagram shows inheritance (VectorObject → Path, Shape)
        *   Class diagram shows composition (Document contains Layers, Layer contains VectorObjects)
        *   Diagrams validate and render correctly
    *   **Dependencies:** `I3.T6` (all domain models completed)
    *   **Parallelizable:** Yes (documentation task)

---

**Iteration 3 Summary:**
*   **Total Tasks:** 7
*   **Estimated Duration:** 5-6 days
*   **Critical Path:** I3.T1 → I3.T2 → I3.T3 → I3.T4 → I3.T5 → I3.T6 (sequential model building)
*   **Parallelizable Work:** I3.T1 and I3.T2 can partially overlap, I3.T7 runs in parallel with later tasks
*   **Deliverables:** Complete immutable domain model with unit tests, architecture diagrams
