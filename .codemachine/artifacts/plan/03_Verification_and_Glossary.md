# Project Plan: WireTuner - Verification & Glossary

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: verification-and-integration-strategy -->
## 5. Verification and Integration Strategy

<!-- anchor: testing-levels -->
### Testing Levels

<!-- anchor: unit-testing -->
#### Unit Testing
*   **Scope:** All domain models, services, and infrastructure components
*   **Coverage Target:** 80%+ for `lib/domain/` and `lib/infrastructure/`
*   **Framework:** `test` package (Dart standard)
*   **Guidelines:**
    *   Test each class in isolation with mocked dependencies
    *   Focus on business logic, geometry calculations, event handling
    *   Test edge cases (null values, boundary conditions, invalid input)
    *   Use descriptive test names (e.g., `test('Path.bounds() returns correct rectangle for Bezier curve')`)
*   **Examples:**
    *   `test/domain/models/path_test.dart` - Test Path.bounds(), length(), pointAt()
    *   `test/domain/services/geometry_service_test.dart` - Test Bezier math, intersections
    *   `test/infrastructure/event_sourcing/event_recorder_test.dart` - Test event sampling, persistence
    *   `test/infrastructure/persistence/event_store_test.dart` - Test SQL operations with in-memory database

<!-- anchor: widget-testing -->
#### Widget Testing
*   **Scope:** All major UI widgets (CanvasWidget, ToolToolbar, panels)
*   **Coverage Target:** 70%+ for `lib/presentation/`
*   **Framework:** `flutter_test` package
*   **Guidelines:**
    *   Test widget builds without errors
    *   Verify widget tree structure
    *   Simulate user interactions (tap, drag, keyboard input)
    *   Use `find.byType()`, `find.text()`, `find.byKey()` for locating widgets
    *   Test widget updates in response to Provider changes
*   **Examples:**
    *   `test/presentation/widgets/canvas/canvas_widget_test.dart` - Test build, gesture detection
    *   `test/presentation/widgets/toolbar/tool_toolbar_test.dart` - Test button clicks, active tool highlighting
    *   `test/presentation/widgets/canvas/canvas_painter_test.dart` - Test shouldRepaint() logic

<!-- anchor: integration-testing -->
#### Integration Testing
*   **Scope:** End-to-end workflows spanning multiple layers (UI → Application → Domain → Infrastructure)
*   **Coverage Target:** All critical user workflows
*   **Framework:** `integration_test` package
*   **Guidelines:**
    *   Test complete user scenarios (create path with pen tool, save document, load document)
    *   Run on actual Flutter desktop app (not mocked)
    *   Verify database persistence (check SQLite file contents)
    *   Use test fixtures (sample .wiretuner, .ai, .svg files)
    *   Measure performance (frame times, document load times)
*   **Examples:**
    *   `integration_test/pen_tool_workflow_test.dart` - Create multi-segment path, finish, verify events recorded
    *   `integration_test/save_load_roundtrip_test.dart` - Save document, load it, verify identical state
    *   `integration_test/undo_redo_test.dart` - Create object, modify it, undo, redo, verify state transitions
    *   `integration_test/anchor_dragging_test.dart` - Drag anchor 100px, verify MoveAnchorEvent recorded

<!-- anchor: performance-testing -->
#### Performance Testing
*   **Scope:** Rendering, event replay, file I/O
*   **Targets:**
    *   **Rendering:** 60 FPS (≤16.67ms frame time) with 1000 simple objects
    *   **Event Replay:** Load document with 10,000 events in < 2 seconds
    *   **Event Write:** Persist event to SQLite in < 10ms
    *   **Snapshot Creation:** < 50ms for typical document (1000 objects)
*   **Framework:** `test` package with Stopwatch for benchmarking
*   **Guidelines:**
    *   Create performance benchmarks in `test/performance/`
    *   Use standardized test documents (simple_1000_objects.wiretuner, complex_10000_events.wiretuner)
    *   Run benchmarks on CI/CD to detect regressions
    *   Profile with Flutter DevTools when targets not met
*   **Examples:**
    *   `test/performance/rendering_benchmark_test.dart` - Render 1000 paths, measure frame time
    *   `test/performance/event_replay_benchmark_test.dart` - Replay 10,000 events, measure duration

<!-- anchor: manual-testing -->
#### Manual Testing
*   **Scope:** Usability, visual correctness, platform-specific behavior
*   **Guidelines:**
    *   Test on both macOS and Windows before release
    *   Verify tool cursors, keyboard shortcuts (Cmd vs Ctrl)
    *   Visual inspection of rendered paths (smooth curves, accurate colors)
    *   Test file dialogs (Save, Save As, Open) on both platforms
    *   Stress test with complex documents (10,000+ objects)
*   **Checklists:**
    *   [ ] All tools functional (Pen, Selection, Direct Selection, Shapes)
    *   [ ] Pan/zoom smooth at 60 FPS
    *   [ ] Undo/redo works for all operations
    *   [ ] Save/load preserves all document data
    *   [ ] SVG export opens correctly in browser
    *   [ ] PDF export opens in Acrobat/Preview
    *   [ ] AI import loads basic Illustrator files

---

<!-- anchor: ci-cd -->
### CI/CD Integration

<!-- anchor: ci-cd-pipeline -->
#### CI/CD Pipeline (GitHub Actions)

**Workflow File:** `.github/workflows/build.yml`

**Triggers:**
*   Push to `main` or `develop` branches
*   Pull requests to `main` branch

**Jobs:**

1. **Test Job** (runs on `ubuntu-latest`)
   *   Checkout code
   *   Install Flutter 3.16+
   *   Run `flutter pub get`
   *   Run `flutter analyze` (must pass with zero issues)
   *   Run `flutter test --coverage` (unit + widget tests)
   *   Upload coverage to Codecov or similar service
   *   **Pass Criteria:** All tests pass, analyzer has zero issues

2. **Build macOS Job** (runs on `macos-latest`)
   *   Depends on: Test job success
   *   Checkout code
   *   Install Flutter
   *   Run `flutter build macos --release`
   *   Create .dmg installer (use `create-dmg` tool)
   *   Upload .dmg as artifact
   *   **Pass Criteria:** Build completes without errors

3. **Build Windows Job** (runs on `windows-latest`)
   *   Depends on: Test job success
   *   Checkout code
   *   Install Flutter
   *   Run `flutter build windows --release`
   *   Create .exe installer (use Inno Setup or MSIX)
   *   Upload installer as artifact
   *   **Pass Criteria:** Build completes without errors

4. **Integration Test Job** (runs on `macos-latest` and `windows-latest` in parallel)
   *   Depends on: Build jobs success
   *   Download built application artifact
   *   Run integration tests (`flutter test integration_test/`)
   *   **Pass Criteria:** All integration tests pass

**Artifact Validation:**
*   Validate PlantUML diagrams on PR (run `plantuml -syntax` on all .puml files)
*   Validate JSON event schemas (if schema files exist)
*   Check API documentation for broken links (markdown linting)

---

<!-- anchor: code-quality-gates -->
### Code Quality Gates

<!-- anchor: quality-linting -->
#### Linting
*   **Tool:** Dart analyzer with strict rules (`analysis_options.yaml`)
*   **Rules Enforced:**
    *   `avoid_dynamic_calls` - Prevent untyped method calls
    *   `prefer_const_constructors` - Use const where possible for performance
    *   `cancel_subscriptions` - Prevent memory leaks
    *   `close_sinks` - Ensure streams closed properly
    *   `unnecessary_null_checks` - Leverage null safety
*   **Gate:** CI/CD fails if `flutter analyze` returns any issues

<!-- anchor: quality-test-coverage -->
#### Test Coverage Minimums
*   **Domain Layer:** 85%+ line coverage
*   **Infrastructure Layer:** 80%+ line coverage
*   **Presentation Layer:** 70%+ line coverage
*   **Application Layer:** 75%+ line coverage
*   **Overall Project:** 80%+ line coverage
*   **Gate:** CI/CD warns if coverage drops below target (does not fail build initially, but blocks merge for critical files)

<!-- anchor: quality-code-review -->
#### Code Review (Single Developer Adaptation)
*   **Self-Review Checklist:**
    *   [ ] All unit tests pass locally
    *   [ ] Code follows project style (consistent naming, formatting)
    *   [ ] No commented-out code (use git history instead)
    *   [ ] Complex logic has explanatory comments
    *   [ ] Public APIs have dartdoc comments
    *   [ ] No hardcoded paths or magic numbers
    *   [ ] Null safety enforced (no `!` operators without justification)
*   **Automated Checks:**
    *   Dart formatter (`flutter format --set-exit-if-changed`)
    *   Import sorting (via `flutter format`)
    *   No TODOs in production code (grep check on CI)

<!-- anchor: quality-documentation -->
#### Documentation Quality
*   **Required Documentation:**
    *   Public classes and methods have dartdoc comments
    *   README.md up-to-date with setup instructions
    *   Architectural diagrams kept in sync with code (update .puml files when structure changes)
    *   ADRs written for major decisions
*   **Gate:** CI/CD warns if dartdoc coverage drops below 80% (using `dartdoc --validate-links`)

---

<!-- anchor: artifact-validation -->
### Artifact Validation

<!-- anchor: artifact-validation-diagrams -->
#### Diagram Validation
*   **PlantUML Files:** Run syntax validation on all `.puml` files
    ```bash
    plantuml -syntax docs/diagrams/*.puml
    ```
*   **Gate:** CI/CD fails if any diagram has syntax errors

<!-- anchor: artifact-validation-api-specs -->
#### API Specification Validation
*   **Event Schema:** Validate `api/event_schema.dart` compiles without errors
*   **Internal API Docs:** Check `docs/api/internal_api_contracts.md` for broken links (using markdown link checker)

<!-- anchor: artifact-validation-file-formats -->
#### File Format Validation
*   **SQLite Schema:** Run test migrations on sample databases, verify schema integrity
*   **.wiretuner Files:** Integration tests load and validate test fixture files
*   **SVG/PDF Exports:** Integration tests validate exported files (SVG with xmllint, PDF with pdfinfo)

---

<!-- anchor: glossary -->
## 6. Glossary

<!-- anchor: glossary-terms -->
### Terms

| Term | Definition |
|------|------------|
| **Anchor Point** | A point on a path defining segment endpoints. May have Bezier Control Point (BCP) handles. |
| **BCP** | Bezier Control Point - handles extending from anchor points that define curve shape. |
| **Canvas** | The drawing surface where vector objects are rendered. Managed by CanvasWidget and CanvasPainter. |
| **Component Diagram** | C4 Level 3 diagram showing internal structure of a container (e.g., Event Sourcing Core components). |
| **Container Diagram** | C4 Level 2 diagram showing major subsystems and data flow (e.g., UI Layer, Vector Engine, Persistence). |
| **Context Diagram** | C4 Level 1 diagram showing system boundary and external actors (e.g., User, File System). |
| **CustomPainter** | Flutter API for low-level canvas rendering. Extend this class and override paint() method. |
| **Direct Selection Tool** | Tool for selecting and manipulating individual anchor points and BCP handles on paths. |
| **Document** | Root aggregate containing all layers, objects, selection state, and viewport. Immutable data structure. |
| **ERD** | Entity-Relationship Diagram - shows database schema tables and relationships. |
| **Event** | Immutable record of a user interaction (CreatePath, MoveAnchor, etc.). Stored in event log. |
| **Event Dispatcher** | Routes events to registered handlers for application to document state. |
| **Event Handler** | Function that applies an event to document state, producing new immutable document. |
| **Event Log** | Append-only sequence of events stored in SQLite `events` table. |
| **Event Navigator** | Service that implements undo/redo by navigating to specific event sequences. |
| **Event Recorder** | Service that samples user input at 50ms intervals and persists events to SQLite. |
| **Event Replayer** | Service that reconstructs document state by replaying events from log. |
| **Event Sourcing** | Architectural pattern where state changes are captured as immutable events in an append-only log. |
| **Freezed** | Dart code generation package for creating immutable classes with copyWith() methods. |
| **Immutable** | Object that cannot be modified after creation. Changes produce new copies. |
| **ITool** | Abstract interface defining tool lifecycle (onActivate, onPointerDown, etc.). All tools implement this. |
| **Layer** | Named container for vector objects with visibility and lock state. |
| **LOD** | Level of Detail - rendering optimization that simplifies objects when zoomed out. |
| **Manifest** | JSON index file mapping anchors to file locations for surgical content retrieval. |
| **Path** | Sequence of connected segments forming an open or closed curve. |
| **Pen Tool** | Tool for creating paths by clicking to add anchor points (straight or Bezier curves). |
| **PlantUML** | Text-based diagramming tool using markup syntax. Generates UML diagrams. |
| **Provider** | Flutter state management package based on InheritedWidget. Used for DocumentProvider, ToolManagerProvider. |
| **Sampling** | Recording events at fixed 50ms intervals rather than capturing every input change. Reduces event volume. |
| **Sealed Class** | Dart pattern restricting class hierarchy to known subtypes (e.g., sealed Event base class). |
| **Segment** | Part of a path between two anchor points. Can be line, Bezier curve, or arc. |
| **Selection** | Set of selected object IDs and anchor indices. Part of Document model. |
| **Selection Tool** | Tool for selecting and moving entire objects. Click to select, drag to move. |
| **Shape** | Parametric geometric primitive (Rectangle, Ellipse, Polygon, Star) with toPath() method. |
| **Snapshot** | Serialized document state at a specific event sequence. Stored in SQLite BLOB column. |
| **SQLite** | Embedded relational database engine. Used for .wiretuner file format. |
| **State Machine** | Pattern for managing tool behavior with explicit states and transitions (e.g., PenTool: IDLE → CREATING_PATH). |
| **Style** | Fill and stroke properties (colors, widths, opacity, blend modes) applied to vector objects. |
| **Tessellation** | Converting Bezier curves to line segments for rendering. Handled by Flutter's Path API. |
| **Tool Manager** | Service managing active tool state and routing input events to the active tool. |
| **Transform** | Affine transformation matrix (translate, rotate, scale) applied to vector objects. |
| **VectorObject** | Abstract base class for all drawable objects (Path, Shape). Has id, transform, style. |
| **Viewport** | Defines visible portion of canvas with pan offset and zoom level. Provides coordinate conversion (world ↔ screen). |
| **.wiretuner** | Native file format - SQLite database containing events, snapshots, and metadata. |

---

<!-- anchor: glossary-acronyms -->
### Acronyms

| Acronym | Full Form |
|---------|-----------|
| **ACID** | Atomicity, Consistency, Isolation, Durability (database transaction properties) |
| **ADR** | Architectural Decision Record |
| **AI** | Adobe Illustrator (file format) |
| **API** | Application Programming Interface |
| **BCP** | Bezier Control Point |
| **BLOB** | Binary Large Object (database data type for snapshots) |
| **C4** | Context, Containers, Components, Code (architecture diagram model) |
| **CI/CD** | Continuous Integration / Continuous Deployment |
| **CRDT** | Conflict-free Replicated Data Type (future collaboration consideration) |
| **CRUD** | Create, Read, Update, Delete |
| **DDL** | Data Definition Language (SQL schema definitions) |
| **DMG** | Disk Image (macOS installer format) |
| **ERD** | Entity-Relationship Diagram |
| **FFI** | Foreign Function Interface |
| **FPS** | Frames Per Second |
| **I/O** | Input/Output |
| **JSON** | JavaScript Object Notation |
| **LOD** | Level of Detail |
| **NFR** | Non-Functional Requirement |
| **OT** | Operational Transform (future collaboration algorithm) |
| **PDF** | Portable Document Format |
| **SQL** | Structured Query Language |
| **SQLite** | SQL Lite (embedded database) |
| **SVG** | Scalable Vector Graphics |
| **UI** | User Interface |
| **UML** | Unified Modeling Language |
| **UUID** | Universally Unique Identifier |
| **WAL** | Write-Ahead Logging (SQLite journaling mode) |
| **XML** | Extensible Markup Language |

---

<!-- anchor: glossary-project-specific -->
### Project-Specific Terms

| Term | Definition |
|------|------------|
| **Milestone 0.1** | First release target: working vector editor with pen tool, shapes, direct manipulation, save/load (~21 days). |
| **Event Sequence** | Zero-based index of events in the log. Used for undo/redo navigation. |
| **Snapshot Frequency** | Number of events between snapshots (default: 1000). |
| **Sampling Rate** | Interval for recording high-frequency events (default: 50ms). |
| **Immutable Data Pattern** | Design pattern where all domain models are immutable, changes create new copies. |
| **Event Payload** | JSON-serialized data stored in `events.event_payload` field containing event-specific information. |
| **Format Version** | Version number in `metadata.format_version` field enabling schema migration. |
| **Document Provider** | Flutter Provider (ChangeNotifier) holding current document state and notifying UI of changes. |
| **Tool Manager Provider** | Flutter Provider managing active tool state. |
| **Canvas Painter** | CustomPainter implementation rendering all vector objects with viewport transforms. |
| **Overlay Painter** | CustomPainter rendering tool-specific UI (handles, guides) on top of main canvas. |
| **Hit Test Service** | Service detecting which object/anchor is under a point. Used by selection tools. |
| **Geometry Service** | Service providing Bezier math, intersection calculations, bounds computations. |
| **Event Sampler** | Component throttling high-frequency input to 50ms intervals. |
| **Migration Manager** | Service applying schema migrations when loading older .wiretuner files. |

---

**End of Verification & Glossary Document**
