# Iteration 1: Foundation & Setup

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: iteration-1-overview -->
### Iteration 1: Foundation & Setup

<!-- anchor: iteration-1-metadata -->
*   **Iteration ID:** `I1`
*   **Goal:** Establish project infrastructure, initialize Flutter project, integrate SQLite, and document event sourcing architecture
*   **Prerequisites:** None (starting point)

<!-- anchor: iteration-1-tasks -->
*   **Tasks:**

<!-- anchor: task-i1-t1 -->
*   **Task 1.1:**
    *   **Task ID:** `I1.T1`
    *   **Description:** Initialize Flutter desktop project with proper directory structure, configure analysis_options.yaml for strict linting, set up pubspec.yaml with initial dependencies (sqflite_common_ffi, provider, logger, freezed, vector_math), and create basic main.dart entry point. Configure macOS and Windows build targets. Create README.md with project overview.
    *   **Agent Type Hint:** `SetupAgent`
    *   **Inputs:**
        *   Project plan Section 3 (Directory Structure)
        *   Technology stack requirements (Flutter 3.16+, Dart 3.2+)
        *   Linting rules from architecture blueprint (analysis_options.yaml recommendations)
    *   **Input Files:** []
    *   **Target Files:**
        *   `pubspec.yaml`
        *   `lib/main.dart`
        *   `lib/app.dart`
        *   `analysis_options.yaml`
        *   `README.md`
        *   `.gitignore`
        *   `macos/` (Flutter-generated)
        *   `windows/` (Flutter-generated)
    *   **Deliverables:**
        *   Working Flutter project that compiles and runs on macOS/Windows
        *   Configured dependencies in pubspec.yaml
        *   Strict linting rules enforced
        *   Basic app widget with placeholder UI
        *   README documenting project setup
    *   **Acceptance Criteria:**
        *   `flutter pub get` succeeds without errors
        *   `flutter analyze` passes with zero issues
        *   `flutter run -d macos` launches application window
        *   `flutter run -d windows` launches application window (if on Windows)
        *   All required dependencies listed in pubspec.yaml
        *   Directory structure matches plan Section 3
    *   **Dependencies:** None
    *   **Parallelizable:** No (foundation for all other tasks)

<!-- anchor: task-i1-t2 -->
*   **Task 1.2:**
    *   **Task ID:** `I1.T2`
    *   **Description:** Generate PlantUML Component Diagram (C4 Level 3) showing the major subsystems: UI Layer, Canvas Renderer, Tool System, Event Sourcing Core, Vector Engine, Persistence Layer, and Import/Export Services. Diagram should visualize dependencies and data flow between components. Save as `docs/diagrams/component_overview.puml`.
    *   **Agent Type Hint:** `DocumentationAgent` or `DiagrammingAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.5 (Component Diagrams)
        *   Plan Section 2 (Core Architecture - Key Components)
    *   **Input Files:** []
    *   **Target Files:**
        *   `docs/diagrams/component_overview.puml`
    *   **Deliverables:**
        *   PlantUML Component Diagram file (C4 syntax)
        *   Diagram renders without syntax errors
        *   All major components from architecture blueprint included
    *   **Acceptance Criteria:**
        *   PlantUML file validates (can be rendered at plantuml.com or with local tool)
        *   Diagram accurately reflects component relationships described in architecture blueprint
        *   All components labeled with technology (e.g., "Flutter Widgets", "SQLite", "Dart Service")
        *   Dependencies between components shown with directional arrows
    *   **Dependencies:** `I1.T1` (needs docs/ directory created)
    *   **Parallelizable:** Yes (independent of code tasks)

<!-- anchor: task-i1-t3 -->
*   **Task 1.3:**
    *   **Task ID:** `I1.T3`
    *   **Description:** Generate PlantUML Sequence Diagrams for 5 critical event flows: (1) Creating a path with the Pen Tool, (2) Loading a document (event replay), (3) Undo operation (event navigation), (4) Dragging an anchor point (50ms sampling), (5) Exporting to SVG. Save as `docs/diagrams/event_sourcing_sequences.puml`. Each diagram should show interactions between User, UI components, Event Recorder, Event Store, Event Replayer, Document State, and Canvas Renderer.
    *   **Agent Type Hint:** `DocumentationAgent` or `DiagrammingAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.4 (Interaction Flows - Sequence Diagrams)
        *   Plan Section 2.1 (Communication Patterns)
    *   **Input Files:** []
    *   **Target Files:**
        *   `docs/diagrams/event_sourcing_sequences.puml`
    *   **Deliverables:**
        *   PlantUML file with 5 sequence diagrams
        *   Diagrams render without syntax errors
        *   Each diagram accurately represents the workflow described in architecture blueprint
    *   **Acceptance Criteria:**
        *   PlantUML file validates and renders correctly
        *   All 5 workflows covered: pen tool creation, document load, undo, drag, SVG export
        *   Sequence of method calls/events matches architecture specifications
        *   Actors, components, and messages clearly labeled
    *   **Dependencies:** `I1.T1` (needs docs/ directory)
    *   **Parallelizable:** Yes (independent, can run in parallel with I1.T2)

<!-- anchor: task-i1-t4 -->
*   **Task 1.4:**
    *   **Task ID:** `I1.T4`
    *   **Description:** Integrate SQLite into the Flutter project using `sqflite_common_ffi` package. Create `lib/infrastructure/persistence/database_provider.dart` to manage SQLite connection lifecycle (open, close, transaction management). Implement initialization logic to create database file in application support directory. Write unit tests to verify database connection succeeds on both macOS and Windows.
    *   **Agent Type Hint:** `BackendAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.2 (Technology Stack - SQLite)
        *   Plan Section 2 (Database: SQLite via sqflite_common_ffi)
        *   Ticket T002 (SQLite Integration)
    *   **Input Files:**
        *   `pubspec.yaml` (from I1.T1)
    *   **Target Files:**
        *   `lib/infrastructure/persistence/database_provider.dart`
        *   `test/infrastructure/persistence/database_provider_test.dart`
    *   **Deliverables:**
        *   DatabaseProvider class with open(), close(), getDatabase() methods
        *   Database file created in correct application support directory
        *   Unit tests confirming database opens successfully
        *   Error handling for database initialization failures
    *   **Acceptance Criteria:**
        *   `flutter test test/infrastructure/persistence/database_provider_test.dart` passes
        *   Database file created at correct path (~/Library/Application Support/WireTuner/ on macOS, %APPDATA%\WireTuner\ on Windows)
        *   No hardcoded paths; uses platform-specific path resolution
        *   Connection can be opened and closed without errors
    *   **Dependencies:** `I1.T1` (needs pubspec.yaml with sqflite_common_ffi dependency)
    *   **Parallelizable:** No (needed by I1.T5)

<!-- anchor: task-i1-t5 -->
*   **Task 1.5:**
    *   **Task ID:** `I1.T5`
    *   **Description:** Create SQLite schema for event sourcing: define `metadata`, `events`, and `snapshots` tables as specified in architecture blueprint Section 3.6 (Data Model ERD). Implement SQL DDL in `lib/infrastructure/persistence/schema.dart`. Add migration logic to DatabaseProvider to create tables on first run. Write unit tests to verify schema creation.
    *   **Agent Type Hint:** `DatabaseAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 3.6 (Data Model ERD - SQLite Tables)
        *   Ticket T002 (SQLite Integration)
    *   **Input Files:**
        *   `lib/infrastructure/persistence/database_provider.dart` (from I1.T4)
    *   **Target Files:**
        *   `lib/infrastructure/persistence/schema.dart`
        *   `lib/infrastructure/persistence/database_provider.dart` (update with migration logic)
        *   `test/infrastructure/persistence/schema_test.dart`
    *   **Deliverables:**
        *   SQL DDL for metadata, events, snapshots tables
        *   Migration logic executed on database initialization
        *   Indexes on (document_id, event_sequence) for events table
        *   Unit tests confirming tables created with correct schema
    *   **Acceptance Criteria:**
        *   `flutter test test/infrastructure/persistence/schema_test.dart` passes
        *   Database schema matches ERD in architecture blueprint
        *   Indexes created for efficient event replay queries
        *   PRAGMA journal_mode=WAL enabled for crash resistance
        *   Schema version tracking for future migrations
    *   **Dependencies:** `I1.T4` (needs DatabaseProvider)
    *   **Parallelizable:** No (sequential with I1.T4)

<!-- anchor: task-i1-t6 -->
*   **Task 1.6:**
    *   **Task ID:** `I1.T6`
    *   **Description:** Document event sourcing architecture design in `docs/adr/003-event-sourcing-architecture.md` (Architectural Decision Record format). Cover rationale for 50ms sampling rate, snapshot frequency (1000 events), event payload format (JSON), and immutability patterns. Reference relevant sections from architecture blueprint. This fulfills Ticket T003.
    *   **Agent Type Hint:** `DocumentationAgent`
    *   **Inputs:**
        *   Architecture blueprint Section 4.1 (Design Rationale - Event Sourcing decisions)
        *   Ticket T003 (Event Sourcing Architecture Design)
        *   Plan Section 2 (Core Architecture - Event Sourcing Foundation)
    *   **Input Files:** []
    *   **Target Files:**
        *   `docs/adr/003-event-sourcing-architecture.md`
    *   **Deliverables:**
        *   ADR document in markdown format
        *   Covers: context, decision, rationale, consequences, alternatives considered
        *   References architecture blueprint sections
    *   **Acceptance Criteria:**
        *   ADR follows standard format (title, status, context, decision, consequences)
        *   Explains 50ms sampling decision with rationale
        *   Documents snapshot strategy (frequency, compression, garbage collection)
        *   Describes event payload format (JSON) and schema evolution approach
        *   Lists alternatives considered (no sampling, time-based snapshots, binary encoding)
    *   **Dependencies:** `I1.T1` (needs docs/ directory)
    *   **Parallelizable:** Yes (can run in parallel with code tasks)

---

**Iteration 1 Summary:**
*   **Total Tasks:** 6
*   **Estimated Duration:** 4-5 days
*   **Critical Path:** I1.T1 → I1.T4 → I1.T5 (sequential database setup)
*   **Parallelizable Work:** I1.T2, I1.T3, I1.T6 (documentation tasks can run alongside code tasks)
*   **Deliverables:** Working Flutter project, SQLite integration, database schema, architecture diagrams, ADR documentation
