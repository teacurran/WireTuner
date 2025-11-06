# Task Briefing Package

This package contains all necessary information and strategic guidance for the Coder Agent.

---

## 1. Current Task Details

This is the full specification of the task you must complete.

```json
{
  "task_id": "I1.T2",
  "iteration_id": "I1",
  "iteration_goal": "Establish project infrastructure, initialize Flutter project, integrate SQLite, and document event sourcing architecture",
  "description": "Generate PlantUML Component Diagram (C4 Level 3) showing the major subsystems: UI Layer, Canvas Renderer, Tool System, Event Sourcing Core, Vector Engine, Persistence Layer, and Import/Export Services. Diagram should visualize dependencies and data flow between components. Save as `docs/diagrams/component_overview.puml`.",
  "agent_type_hint": "DocumentationAgent",
  "inputs": "Architecture blueprint Section 3.5 (Component Diagrams), Plan Section 2 (Core Architecture - Key Components)",
  "target_files": [
    "docs/diagrams/component_overview.puml"
  ],
  "input_files": [],
  "deliverables": "PlantUML Component Diagram file (C4 syntax), Diagram renders without syntax errors, All major components from architecture blueprint included",
  "acceptance_criteria": "PlantUML file validates (can be rendered at plantuml.com or with local tool), Diagram accurately reflects component relationships described in architecture blueprint, All components labeled with technology (e.g., \"Flutter Widgets\", \"SQLite\", \"Dart Service\"), Dependencies between components shown with directional arrows",
  "dependencies": ["I1.T1"],
  "parallelizable": true,
  "done": false
}
```

---

## 2. Architectural & Planning Context

The following are the relevant sections from the architecture and plan documents, which I found by analyzing the task description.

### Context: component-vector-engine (from 03_System_Structure_and_Data.md)

```markdown
#### Vector Engine Components

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title Component Diagram - Vector Engine

Container_Boundary(vector_engine, "Vector Engine") {
  Component(document, "Document", "Immutable Class", "Root container: layers, artboards, objects")
  Component(path, "Path", "Immutable Class", "Sequence of segments, open or closed")
  Component(segment, "Segment", "Immutable Class", "Line, Bezier curve, or arc")
  Component(shape, "Shape", "Immutable Class", "Rectangle, Ellipse, Polygon, Star")
  Component(anchor, "Anchor Point", "Immutable Struct", "Position + handles (BCP)")
  Component(style, "Style", "Immutable Class", "Fill, stroke, opacity properties")
  Component(transform, "Transform", "Immutable Class", "Translation, rotation, scale matrix")

  Component(geometry, "Geometry Service", "Stateless Functions", "Bezier math, intersections, bounds")
  Component(hit_test, "Hit Test Service", "Stateless Functions", "Point-in-path, distance to curve")
  Component(path_ops, "Path Operations", "Stateless Functions", "Boolean ops, offset, simplify")
}

ContainerDb(event_store, "Event Store", "SQLite")
Container(event_replayer, "Event Replayer", "Service")
Container(canvas, "Canvas Renderer", "CustomPainter")

' Internal relationships
Rel(document, path, "Contains 0..n", "")
Rel(document, shape, "Contains 0..n", "")
Rel(path, segment, "Composed of 2..n", "")
Rel(segment, anchor, "Defined by 2..4", "Control points")
Rel(path, style, "Styled with", "")
Rel(shape, style, "Styled with", "")
Rel(path, transform, "Transformed by", "Matrix")
Rel(shape, transform, "Transformed by", "Matrix")

Rel(hit_test, geometry, "Uses", "Distance/intersection functions")
Rel(path_ops, geometry, "Uses", "Curve manipulation")

' External relationships
Rel(event_replayer, document, "Reconstructs", "Event application")
Rel(document, canvas, "Provides data to", "Rendering")
Rel(geometry, canvas, "Supports", "Curve tessellation")

@enduml
~~~
```

### Context: component-event-sourcing (from 03_System_Structure_and_Data.md)

```markdown
#### Event Sourcing Core Components

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title Component Diagram - Event Sourcing Core

Container_Boundary(event_core, "Event Sourcing Core") {
  Component(event_recorder, "Event Recorder", "Service", "Samples input at 50ms, creates events")
  Component(event_dispatcher, "Event Dispatcher", "Service", "Routes events to handlers")
  Component(event_handler, "Event Handler Registry", "Map<EventType, Handler>", "Applies events to document state")

  Component(snapshot_manager, "Snapshot Manager", "Service", "Triggers/stores snapshots every 1000 events")
  Component(snapshot_serializer, "Snapshot Serializer", "Codec", "Document <-> binary serialization")

  Component(event_replayer, "Event Replayer", "Service", "Reconstructs state from snapshot + events")
  Component(event_navigator, "Event Navigator", "Service", "Undo/redo by event index navigation")

  Component(event_model, "Event Model", "Sealed Class Hierarchy", "CreatePath, AddAnchor, MoveObject, etc.")
  Component(event_sampler, "Event Sampler", "Throttler", "Debounces high-frequency input")
}

ContainerDb(event_store, "Event Store", "SQLite")
ContainerDb(snapshot_store, "Snapshot Store", "SQLite BLOB")
Container(tools, "Tool System", "Controllers")
Container(vector_engine, "Vector Engine", "Domain Models")

' Internal relationships
Rel(event_recorder, event_sampler, "Uses", "Throttle to 50ms")
Rel(event_sampler, event_model, "Creates instances of", "")
Rel(event_recorder, event_dispatcher, "Sends events to", "")
Rel(event_dispatcher, event_handler, "Looks up handler in", "EventType key")
Rel(event_handler, vector_engine, "Mutates (creates new)", "Immutable copy")

Rel(event_recorder, snapshot_manager, "Notifies on event count", "Every 1000 events")
Rel(snapshot_manager, snapshot_serializer, "Uses to encode", "")
Rel(snapshot_serializer, vector_engine, "Serializes Document from", "")

Rel(event_replayer, event_store, "Reads events from", "SQL SELECT")
Rel(event_replayer, snapshot_store, "Loads base snapshot from", "SQL SELECT")
Rel(event_replayer, event_handler, "Applies events via", "")

Rel(event_navigator, event_replayer, "Uses for state at index", "")

' External relationships
Rel(tools, event_recorder, "Generates events", "Method calls")
Rel(event_recorder, event_store, "Persists to", "SQL INSERT")
Rel(snapshot_manager, snapshot_store, "Persists to", "SQL INSERT")

@enduml
~~~
```

### Context: component-tool-system (from 03_System_Structure_and_Data.md)

```markdown
#### Tool System Components

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title Component Diagram - Tool System

Container_Boundary(tool_system, "Tool System") {
  Component(tool_manager, "Tool Manager", "Service", "Active tool tracking, tool switching")
  Component(tool_interface, "ITool Interface", "Abstract Interface", "onPointerDown/Move/Up, onKeyPress, render")

  Component(pen_tool, "Pen Tool", "StateMachine", "Creates paths with straight/bezier segments")
  Component(selection_tool, "Selection Tool", "Controller", "Selects/moves entire objects")
  Component(direct_selection, "Direct Selection Tool", "Controller", "Selects/moves anchors and BCPs")

  Component(rect_tool, "Rectangle Tool", "Controller", "Creates rectangle shapes by drag")
  Component(ellipse_tool, "Ellipse Tool", "Controller", "Creates ellipse shapes by drag")
  Component(polygon_tool, "Polygon Tool", "Controller", "Creates n-sided polygons")
  Component(star_tool, "Star Tool", "Controller", "Creates n-pointed stars")

  Component(tool_cursor, "Cursor Manager", "Service", "Updates cursor based on tool/context")
  Component(tool_overlay, "Overlay Renderer", "CustomPainter", "Draws tool-specific UI (handles, guides)")
}

Container(event_recorder, "Event Recorder", "Service")
Container(vector_engine, "Vector Engine", "Domain Models")
Container(canvas, "Canvas Renderer", "CustomPainter")
Container(ui_layer, "UI Layer", "Widgets")

' Internal relationships
Rel(tool_manager, tool_interface, "Manages instances of", "")
Rel(pen_tool, tool_interface, "Implements", "")
Rel(selection_tool, tool_interface, "Implements", "")
Rel(direct_selection, tool_interface, "Implements", "")
Rel(rect_tool, tool_interface, "Implements", "")
Rel(ellipse_tool, tool_interface, "Implements", "")
Rel(polygon_tool, tool_interface, "Implements", "")
Rel(star_tool, tool_interface, "Implements", "")

Rel(tool_manager, tool_cursor, "Updates via", "")
Rel(tool_interface, tool_overlay, "Renders feedback via", "")

' External relationships
Rel(ui_layer, tool_manager, "Routes input to", "Pointer/Keyboard events")
Rel(tool_manager, event_recorder, "Generates events via", "")
Rel(tool_interface, vector_engine, "Queries document state from", "")
Rel(tool_overlay, canvas, "Renders on top of", "Custom paint layer")

@enduml
~~~
```

### Context: container-diagram (from 03_System_Structure_and_Data.md)

```markdown
### 3.4. Container Diagram (C4 Level 2)

#### Description

The Container diagram zooms into the WireTuner system boundary to reveal its major structural components (containers in C4 terminology). WireTuner is composed of:

1. **Desktop Application (Flutter)**: Main UI layer containing all widgets, tools, and canvas rendering
2. **Event Sourcing Core**: Custom-built subsystem handling event recording, replay, and snapshots
3. **Vector Engine**: Domain models and rendering logic for paths, shapes, and documents
4. **Persistence Layer**: SQLite database handling event log and snapshot storage
5. **Import/Export Services**: Converters for external file formats (SVG, PDF, AI)

**Data Flow:**
- User interactions → Event Recorder (50ms sampling) → SQLite Event Log
- Event Log + Snapshots → Event Replay → Current Document State
- Document State → Vector Engine → Canvas Renderer → Screen
- Import: External File → Parser → Events → Event Log
- Export: Document State → Exporter → External File Format
```

### Context: key-components (from 01_Plan_Overview_and_Setup.md)

```markdown
*   **Key Components/Services:**
    *   **UI Layer:** Main window, toolbars, tool panels, canvas widget, dialogs
    *   **Canvas Renderer:** CustomPainter implementation for 60 FPS vector rendering with viewport transforms
    *   **Tool System:** Abstract ITool interface with implementations (Pen, Selection, Direct Selection, Rectangle, Ellipse, Polygon, Star)
    *   **Event Sourcing Core:**
        *   EventRecorder: Samples user input at 50ms, creates event objects
        *   EventReplayer: Reconstructs document state from event log
        *   SnapshotManager: Creates/loads state snapshots every 1000 events
    *   **Vector Engine:** Domain models (Document, Path, Shape, Segment, AnchorPoint, Style, Transform)
    *   **Geometry Engine:** Bezier math, hit testing, bounds calculation, path operations
    *   **Persistence Layer:**
        *   Event Store: SQLite table with append-only event log
        *   Snapshot Store: SQLite BLOB storage for serialized document snapshots
    *   **Import/Export Services:**
        *   SVG Exporter: Converts Document to SVG 1.1 XML
        *   PDF Exporter: Generates PDF 1.7 documents
        *   AI Importer: Parses Adobe Illustrator files (PDF-based)
        *   SVG Importer: Parses SVG into Document events
    *   *Refer to Component Diagram (see Iteration 1, Task 2) for detailed visualization*
```

### Context: architectural-style (from 02_Architecture_Overview.md)

```markdown
### 3.1. Architectural Style

**Primary Style: Event-Sourced Layered Architecture**

WireTuner employs a hybrid architectural approach combining **Event Sourcing** with a **Layered Architecture** pattern, tailored for desktop application requirements.

#### Event Sourcing Foundation

**Definition**: All state changes are captured as immutable events stored in an append-only log. The current application state is derived by replaying events from the log.

**Rationale for WireTuner:**
1. **Infinite Undo/Redo**: Natural consequence of event history - navigate forward/backward through events
2. **Audit Trail**: Complete record of user actions enables debugging and workflow analysis
3. **Future Collaboration**: Events are inherently distributable, enabling multi-user editing in future versions
4. **State Recovery**: Snapshots + events provide robust crash recovery
5. **Temporal Queries**: Ability to inspect document state at any point in history

**Key Design Decision**: Sample user interactions at 50ms intervals rather than capturing every mouse movement event. This balances fidelity with storage/replay performance.

#### Layered Architecture Structure

WireTuner organizes code into distinct layers with clear dependencies:

```
┌─────────────────────────────────────────┐
│     Presentation Layer (UI/Widgets)     │  ← Flutter widgets, tools, canvas
├─────────────────────────────────────────┤
│    Application Layer (Use Cases)        │  ← Event handlers, tool controllers
├─────────────────────────────────────────┤
│    Domain Layer (Models & Logic)        │  ← Path, Shape, Document models
├─────────────────────────────────────────┤
│  Infrastructure Layer (Persistence)      │  ← SQLite, file I/O, event store
└─────────────────────────────────────────┘
```

**Rationale:**
- **Separation of Concerns**: Each layer has distinct responsibility
- **Testability**: Domain logic independent of UI framework
- **Maintainability**: Changes to UI don't affect business logic
- **Flutter Compatibility**: Maps well to Flutter's widget-based architecture
```

---

## 3. Codebase Analysis & Strategic Guidance

The following analysis is based on my direct review of the current codebase. Use these notes and tips to guide your implementation.

### Relevant Existing Code

*   **File:** `docs/diagrams/` (directory exists but empty)
    *   **Summary:** The target directory for PlantUML diagrams already exists in the project structure.
    *   **Recommendation:** You SHOULD create the `component_overview.puml` file directly in this directory at path `docs/diagrams/component_overview.puml`.

*   **File:** `pubspec.yaml`
    *   **Summary:** This file defines the project dependencies and configuration. Currently includes packages like `sqflite_common_ffi` (database), `provider` (state management), `vector_math` (geometry), and `logger`.
    *   **Recommendation:** Your diagram should reflect the technologies mentioned here (SQLite, Provider, Flutter framework).

*   **File:** `lib/main.dart` and `lib/app.dart`
    *   **Summary:** These are the current entry points for the Flutter application. Task I1.T1 has been completed successfully - the basic Flutter project structure is in place with proper initialization.
    *   **Recommendation:** The UI Layer component in your diagram should reference "Flutter Widgets" as the technology, which is already set up in the existing code.

*   **File:** `analysis_options.yaml`
    *   **Summary:** Contains strict linting rules including `public_member_api_docs` requirement. This enforces documentation standards across the codebase.
    *   **Note:** While this doesn't directly affect your PlantUML diagram, it indicates the project follows high code quality standards.

### Implementation Tips & Notes

*   **Tip:** The architecture blueprint provides THREE separate component diagrams (Vector Engine, Event Sourcing Core, Tool System). Your task is to create a SINGLE unified Component Diagram that shows ALL major subsystems and their interactions. You should synthesize these into one comprehensive C4 Level 3 diagram.

*   **Tip:** Use the C4-PlantUML library by including `!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml` at the top of your file. This provides the Component, Container, ContainerDb, and Rel macros you'll need.

*   **Note:** The diagram should show the following major subsystems as Container_Boundary sections:
    1. **UI Layer** (Flutter Widgets)
    2. **Canvas Renderer** (CustomPainter)
    3. **Tool System** (with ITool interface and tool implementations)
    4. **Event Sourcing Core** (EventRecorder, EventReplayer, SnapshotManager, etc.)
    5. **Vector Engine** (Document, Path, Shape, domain models)
    6. **Persistence Layer** (SQLite databases for events and snapshots)
    7. **Import/Export Services** (SVG, PDF, AI converters)

*   **Note:** The data flow is critical to show:
    - User → UI Layer → Tool System → Event Recorder → Event Store → EventDispatcher → Vector Engine → Canvas Renderer → User
    - This forms the complete interaction loop that must be visible in your diagram.

*   **Warning:** The C4 syntax requires proper quotation marks and parameter ordering. Each Component/Container call follows the pattern: `Component(id, "Name", "Technology", "Description")`. Ensure you maintain this exact format to avoid syntax errors.

*   **Tip:** Based on the existing component diagrams in the architecture blueprint, you should use:
    - `Container_Boundary(id, "Name")` for major subsystems
    - `Component(id, "Name", "Type", "Description")` for individual components
    - `ContainerDb(id, "Name", "Technology")` for database components
    - `Rel(source, target, "Label", "Optional detail")` for relationships

*   **Note:** All components must be labeled with their technology stack as specified in the acceptance criteria. Examples:
    - UI components: "Flutter Widgets"
    - Services: "Dart Service"
    - Database: "SQLite"
    - Renderers: "CustomPainter"
    - Models: "Immutable Class"

*   **Critical:** The file MUST be saved at the exact path `docs/diagrams/component_overview.puml` (not `component_diagram.puml` or any other variation). The path is specified in the task target_files.

*   **Validation:** After creating the file, you can validate it by:
    1. Checking the PlantUML syntax is correct
    2. Ensuring all relationships point to defined component IDs
    3. Verifying the diagram title is clear and descriptive
    4. Testing that it renders at plantuml.com (optional but recommended)

*   **Best Practice:** Start with a title using `title Component Diagram - WireTuner Architecture Overview` or similar to clearly identify what the diagram represents.

### Directory Structure Context

The project follows a layered architecture pattern with this structure:
```
lib/
├── presentation/      # UI Layer
├── application/       # Application Layer (Tools, Services)
├── domain/           # Domain Layer (Models, Events, Services)
└── infrastructure/   # Infrastructure Layer (Persistence, Event Sourcing)
```

Your component diagram should reflect this organizational structure with clear boundaries between layers.
