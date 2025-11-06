# Iteration 9: File Operations & Import/Export

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-9-overview -->
### Iteration 9: File Operations & Import/Export

<!-- anchor: iteration-9-metadata -->
*   **Iteration ID:** `I9`
*   **Goal:** Implement save/load for .wiretuner documents, SVG/PDF export, and Adobe Illustrator import
*   **Prerequisites:** I2 (event system), I3 (data models)

<!-- anchor: iteration-9-tasks -->
*   **Tasks:**

<!-- anchor: task-i9-t1 -->
*   **Task 9.1:**
    *   **Task ID:** `I9.T1`
    *   **Description:** Implement save document functionality in `lib/application/services/document_service.dart`. Create saveDocument(filePath) method that persists current event log and metadata to SQLite file at specified path. Trigger snapshot creation before save. Implement Save and Save As dialogs using file_picker package. Write integration tests for save workflow.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - File operations)
        *   Ticket T033 (Save Document)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/event_store.dart` (from I2.T4)
        *   `lib/infrastructure/persistence/metadata_store.dart` (create if not exists)
        *   `lib/infrastructure/event_sourcing/snapshot_manager.dart` (from I2.T7)
    *   **Target Files:**
        *   `lib/application/services/document_service.dart`
        *   `lib/infrastructure/persistence/metadata_store.dart`
        *   `integration_test/save_document_test.dart`
    *   **Deliverables:**
        *   saveDocument() method persisting to .wiretuner file
        *   File picker dialogs (Save, Save As)
        *   Metadata written (title, created_at, modified_at, format_version)
        *   Integration tests
    *   **Acceptance Criteria:**
        *   saveDocument() creates SQLite file with events, snapshots, metadata
        *   Save As prompts for file path
        *   Save uses current file path or prompts if new document
        *   format_version field set (e.g., "1.0")
        *   Integration test creates document, saves, verifies file exists
    *   **Dependencies:** `I2.T4` (EventStore), `I2.T7` (SnapshotManager), `I1.T5` (schema)
    *   **Parallelizable:** Yes

<!-- anchor: task-i9-t2 -->
*   **Task 9.2:**
    *   **Task ID:** `I9.T2`
    *   **Description:** Implement load document functionality in DocumentService. Create loadDocument(filePath) method that opens SQLite file, reads events and snapshots, uses EventReplayer to reconstruct Document state. Handle format version compatibility checks. Implement Open dialog. Write integration tests for load workflow (round-trip: save then load, verify document unchanged).
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Loading document)
        *   Ticket T034 (Load Document)
    *   **Input Files:**
        *   `lib/application/services/document_service.dart` (from I9.T1)
        *   `lib/infrastructure/event_sourcing/event_replayer.dart` (from I2.T9)
        *   `lib/infrastructure/persistence/metadata_store.dart` (from I9.T1)
    *   **Target Files:**
        *   `lib/application/services/document_service.dart` (enhance)
        *   `integration_test/load_document_test.dart`
        *   `integration_test/save_load_roundtrip_test.dart`
    *   **Deliverables:**
        *   loadDocument() method reconstructing Document from file
        *   Format version compatibility checks
        *   Open dialog integration
        *   Integration tests (including round-trip)
    *   **Acceptance Criteria:**
        *   loadDocument() opens .wiretuner file and replays events
        *   Format version checked before loading
        *   Error handling for corrupted files (show user-friendly message)
        *   Integration test: save document, load it, verify all objects identical
        *   Round-trip test achieves byte-for-byte equivalence (or acceptable differences documented)
    *   **Dependencies:** `I9.T1` (save), `I2.T9` (EventReplayer)
    *   **Parallelizable:** No (needs I9.T1)

<!-- anchor: task-i9-t3 -->
*   **Task 9.3:**
    *   **Task ID:** `I9.T3`
    *   **Description:** Implement file format versioning system. Define version migration logic in `lib/infrastructure/persistence/migrations/`. Support loading older format versions by applying migration transforms to event payloads or schema. Document migration strategy in `docs/adr/004-file-format-versioning.md`. Write unit tests for migration logic.
    *   **Agent Type Hint:** `DatabaseAgent`
    *   **Inputs:**
        *   Ticket T035 (File Format Versioning)
        *   Architecture blueprint Section 5.2 (Future - Format evolution)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/metadata_store.dart` (from I9.T1)
    *   **Target Files:**
        *   `lib/infrastructure/persistence/migrations/migration_manager.dart`
        *   `lib/infrastructure/persistence/migrations/version_1_to_2.dart` (example)
        *   `docs/adr/004-file-format-versioning.md`
        *   `test/infrastructure/persistence/migrations/migration_test.dart`
    *   **Deliverables:**
        *   MigrationManager with applyMigrations(fromVersion, toVersion)
        *   Example migration (even if no-op for v1)
        *   ADR documenting versioning strategy
        *   Unit tests
    *   **Acceptance Criteria:**
        *   MigrationManager detects format version from metadata
        *   Migrations applied sequentially (v1 → v2 → v3, etc.)
        *   ADR documents versioning approach (semantic versioning, backward compatibility policy)
        *   Unit tests verify migration logic
    *   **Dependencies:** `I9.T1` (metadata with version field)
    *   **Parallelizable:** Yes (can overlap with I9.T2)

<!-- anchor: task-i9-t4 -->
*   **Task 9.4:**
    *   **Task ID:** `I9.T4`
    *   **Description:** Implement SVG exporter in `lib/infrastructure/import_export/svg_exporter.dart`. Convert Document to SVG 1.1 XML. Use xml package for generation. Map VectorObjects to SVG <path> elements with d attribute (Bezier curve syntax). Apply styles (fill, stroke) as attributes. Support coordinate system transformation (WireTuner coordinates → SVG coordinates). Write integration tests exporting sample document and validating SVG structure.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Sequence Diagram - Exporting SVG)
        *   Architecture blueprint Section 3.2 (Technology Stack - xml package)
        *   Ticket T036 (SVG Export)
    *   **Input Files:**
        *   `lib/domain/models/document.dart` (from I3.T6)
        *   `pubspec.yaml` (add xml package if not present)
    *   **Target Files:**
        *   `lib/infrastructure/import_export/svg_exporter.dart`
        *   `integration_test/svg_export_test.dart`
    *   **Deliverables:**
        *   SVGExporter class with exportToFile(Document, filePath)
        *   Path-to-SVG conversion (Bezier curves → d="M...C..." syntax)
        *   Style-to-attribute mapping (fill, stroke, opacity)
        *   Integration tests with SVG validation
    *   **Acceptance Criteria:**
        *   Exported SVG is valid XML (validates against SVG 1.1 DTD)
        *   Paths render correctly when opened in browser or Illustrator
        *   Bezier curves converted to cubic Bezier commands (C command)
        *   Transforms applied correctly (transform="matrix(...)" attribute)
        *   Integration test exports document and verifies SVG structure
    *   **Dependencies:** `I3.T6` (Document model)
    *   **Parallelizable:** Yes (independent of save/load)

<!-- anchor: task-i9-t5 -->
*   **Task 9.5:**
    *   **Task ID:** `I9.T5`
    *   **Description:** Implement PDF exporter in `lib/infrastructure/import_export/pdf_exporter.dart`. Use pdf package to generate PDF 1.7 documents. Convert VectorObjects to PDF path drawing commands. Support embedded fonts (if text implemented). Map coordinate systems. Write integration tests exporting sample document and verifying PDF opens correctly.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.2 (Technology Stack - pdf package)
        *   Ticket T037 (PDF Export)
    *   **Input Files:**
        *   `lib/domain/models/document.dart` (from I3.T6)
        *   `pubspec.yaml` (add pdf package if not present)
    *   **Target Files:**
        *   `lib/infrastructure/import_export/pdf_exporter.dart`
        *   `integration_test/pdf_export_test.dart`
    *   **Deliverables:**
        *   PDFExporter class with exportToFile(Document, filePath)
        *   Path-to-PDF conversion (moveTo, curveTo, closePath commands)
        *   Style application (fill, stroke colors, widths)
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Exported PDF is valid (opens in Acrobat, Preview)
        *   Paths render accurately
        *   Colors and stroke widths correct
        *   Coordinate system matches (origin, scaling)
        *   Integration test exports and opens PDF without errors
    *   **Dependencies:** `I3.T6` (Document model)
    *   **Parallelizable:** Yes (can overlap with I9.T4)

<!-- anchor: task-i9-t6 -->
*   **Task 9.6:**
    *   **Task ID:** `I9.T6`
    *   **Description:** Implement Adobe Illustrator (.ai) importer in `lib/infrastructure/import_export/ai_importer.dart`. Parse .ai file (PDF-based format) using pdf package. Extract vector paths from PDF content streams. Generate CreatePathEvent and CreateShapeEvent from imported objects. Handle basic path and shape types; defer advanced features (gradients, effects). Write integration tests with sample .ai files.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.2 (Import/Export - AI Import)
        *   Ticket T038 (AI Import)
    *   **Input Files:**
        *   `pubspec.yaml` (pdf package)
    *   **Target Files:**
        *   `lib/infrastructure/import_export/ai_importer.dart`
        *   `integration_test/ai_import_test.dart`
        *   `test/fixtures/sample.ai` (test fixture)
    *   **Deliverables:**
        *   AIImporter class with importFromFile(filePath) returning List<Event>
        *   PDF content stream parsing
        *   Path extraction from PDF operators (moveto, curveto, etc.)
        *   Event generation for imported objects
        *   Integration tests with sample .ai file
    *   **Acceptance Criteria:**
        *   Importer parses basic .ai file (simple paths, shapes)
        *   Generates CreatePathEvent for imported paths
        *   Imported objects render in WireTuner canvas
        *   Unsupported features logged as warnings (not errors)
        *   Integration test imports sample.ai and verifies object count
    *   **Dependencies:** `I2.T1` (event models), `I3.T3` (Path model)
    *   **Parallelizable:** Yes (can overlap with I9.T4/I9.T5)

<!-- anchor: task-i9-t7 -->
*   **Task 9.7:**
    *   **Task ID:** `I9.T7`
    *   **Description:** Implement SVG importer in `lib/infrastructure/import_export/svg_importer.dart`. Parse SVG XML using xml package. Extract <path> elements and convert d attribute to WireTuner Path model. Handle basic shapes (<rect>, <ellipse>, <polygon>) by converting to paths. Generate events for imported objects. Write integration tests with sample SVG files.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Ticket T039 (SVG Import)
    *   **Input Files:**
        *   `lib/infrastructure/import_export/svg_exporter.dart` (reference for SVG structure)
        *   `pubspec.yaml` (xml package)
    *   **Target Files:**
        *   `lib/infrastructure/import_export/svg_importer.dart`
        *   `integration_test/svg_import_test.dart`
        *   `test/fixtures/sample.svg` (test fixture)
    *   **Deliverables:**
        *   SVGImporter class with importFromFile(filePath) returning List<Event>
        *   SVG path d attribute parsing (M, L, C, Z commands)
        *   Basic shape conversion (<rect> → Path)
        *   Event generation
        *   Integration tests
    *   **Acceptance Criteria:**
        *   Importer parses SVG <path> elements
        *   Converts Bezier commands (C) to Path segments
        *   Basic shapes (<rect>, <ellipse>) converted to paths
        *   Imported objects render correctly
        *   Integration test imports sample.svg and verifies structure
    *   **Dependencies:** `I2.T1` (events), `I3.T3` (Path)
    *   **Parallelizable:** Yes (can overlap with I9.T6)

<!-- anchor: task-i9-t8 -->
*   **Task 9.8:**
    *   **Task ID:** `I9.T8`
    *   **Description:** Create comprehensive testing strategy document in `docs/testing/testing_strategy.md`. Document unit test expectations (80%+ coverage for domain/infrastructure), widget test guidelines (all major widgets tested), integration test scenarios (critical workflows end-to-end). Include guidelines for performance testing, visual regression testing (golden files), and manual testing. Reference CI/CD integration (tests run on every PR).
    *   **Agent Type Hint:** `DocumentationAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 5.1 (Verification Strategy)
        *   All test files created throughout iterations
    *   **Input Files:** []
    *   **Target Files:**
        *   `docs/testing/testing_strategy.md`
    *   **Deliverables:**
        *   Testing strategy markdown document
        *   Coverage targets documented
        *   Test types explained (unit, widget, integration, performance)
        *   Examples of each test type
    *   **Acceptance Criteria:**
        *   Document covers unit, widget, integration, performance testing
        *   Coverage target: 80%+ for lib/domain and lib/infrastructure
        *   Widget test guidelines with examples
        *   Integration test scenarios listed (save/load, pen tool workflow, undo/redo)
        *   Performance benchmarks documented (60 FPS target, document load < 2s)
    *   **Dependencies:** None (documentation task)
    *   **Parallelizable:** Yes (can run throughout iteration)

---

**Iteration 9 Summary:**
*   **Total Tasks:** 8
*   **Estimated Duration:** 7-9 days
*   **Critical Path:** I9.T1 → I9.T2 (save/load sequential), I9.T3 (versioning parallel), I9.T4/I9.T5/I9.T6/I9.T7 (import/export parallel), I9.T8 (documentation parallel)
*   **Deliverables:** Save/load functionality, file format versioning, SVG/PDF export, AI/SVG import, testing strategy documentation
*   **Milestone 0.1 Complete:** All critical features delivered
