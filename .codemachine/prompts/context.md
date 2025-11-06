# Task Briefing Package

This package contains all necessary information and strategic guidance for the Coder Agent.

---

## 1. Current Task Details

This is the full specification of the task you must complete.

```json
{
  "task_id": "I1.T3",
  "iteration_id": "I1",
  "iteration_goal": "Establish project infrastructure, initialize Flutter project, integrate SQLite, and document event sourcing architecture",
  "description": "Generate PlantUML Sequence Diagrams for 5 critical event flows: (1) Creating a path with the Pen Tool, (2) Loading a document (event replay), (3) Undo operation (event navigation), (4) Dragging an anchor point (50ms sampling), (5) Exporting to SVG. Save as `docs/diagrams/event_sourcing_sequences.puml`. Each diagram should show interactions between User, UI components, Event Recorder, Event Store, Event Replayer, Document State, and Canvas Renderer.",
  "agent_type_hint": "DocumentationAgent",
  "inputs": "Architecture blueprint Section 4.4 (Interaction Flows - Sequence Diagrams), Plan Section 2.1 (Communication Patterns)",
  "target_files": [
    "docs/diagrams/event_sourcing_sequences.puml"
  ],
  "input_files": [],
  "deliverables": "PlantUML file with 5 sequence diagrams, Diagrams render without syntax errors, Each diagram accurately represents the workflow described in architecture blueprint",
  "acceptance_criteria": "PlantUML file validates and renders correctly, All 5 workflows covered: pen tool creation, document load, undo, drag, SVG export, Sequence of method calls/events matches architecture specifications, Actors, components, and messages clearly labeled",
  "dependencies": ["I1.T1"],
  "parallelizable": true,
  "done": false
}
```

---

## 2. Architectural & Planning Context

The following are the relevant sections from the architecture and plan documents, which I found by analyzing the task description.

### Context: Communication Patterns (from 04_Behavior_and_Communication.md)

The task requires understanding the communication patterns used throughout the system.

**Event-Driven Pattern (Core Architecture):**
- User Input → Tool Controller → Event Recorder → Event Store (SQLite)
- Event Recorder → Event Dispatcher → Event Handlers → New Document State → UI Rebuild (Provider)

**Example Events:**
- `CreatePathEvent(pathId, style)`
- `AddAnchorEvent(pathId, position, handles)`
- `MoveObjectEvent(objectId, delta)`
- `ModifyStyleEvent(objectId, fillColor, strokeWidth)`

**Characteristics:**
- **Asynchronous**: Events processed in next frame to avoid blocking UI
- **Ordered**: Event sequence numbers ensure deterministic replay
- **Sampled**: High-frequency inputs (e.g., drag) throttled to 50ms
- **Durable**: All events persisted to SQLite immediately

**Synchronous Request/Response Pattern:**
- Tool → Document.getObjectById(id) → VectorObject
- Tool → GeometryService.hitTest(path, point) → bool
- Canvas Renderer → Document.getAllObjects() → List<VectorObject>

**Publish/Subscribe Pattern (UI Reactivity):**
- Event Handler applies event → Document state changes → DocumentProvider.notifyListeners()
- Widgets rebuild (Consumer/Selector)

### Context: Flow 1 - Creating a Path with the Pen Tool (from 04_Behavior_and_Communication.md)

**Complete PlantUML sequence diagram exists in the architecture document at lines 93-167**

Key participants:
- User (actor)
- Canvas Widget
- Tool Manager
- Pen Tool
- Event Recorder
- Event Store
- Event Dispatcher
- Document State
- Canvas Renderer

Flow includes:
1. **First Click (Start Path)**: Creates CreatePathEvent, state changes IDLE → CREATING_PATH
2. **Subsequent Clicks**: AddAnchorEvent for each anchor point, creates line segments
3. **Finish Path**: Double-click or Enter triggers FinishPathEvent, state returns to IDLE

### Context: Flow 2 - Loading a Document (Event Replay) (from 04_Behavior_and_Communication.md)

**Complete PlantUML sequence diagram exists in the architecture document at lines 174-227**

Key participants:
- User
- File Dialog
- Document Service
- Event Store
- Snapshot Store
- Event Replayer
- Event Dispatcher
- Document State
- UI Layer
- Canvas Renderer

Flow includes:
1. User selects .wiretuner file
2. Query max event sequence from database
3. Load most recent snapshot (e.g., at sequence 5000)
4. Replay subsequent events (e.g., 5001-5432)
5. Loop through events, dispatching and applying each
6. Render final reconstructed document

**Important Note**: Replay of 432 events typically takes 20-50ms

### Context: Flow 3 - Undo Operation (Event Navigation) (from 04_Behavior_and_Communication.md)

**Complete PlantUML sequence diagram exists in the architecture document at lines 234-285**

Key participants:
- User
- UI Layer
- Event Navigator
- Event Store
- Snapshot Store
- Event Replayer
- Document State
- Canvas Renderer

Flow includes:
1. User presses Cmd+Z (macOS) or Ctrl+Z (Windows)
2. Event Navigator determines current and target sequence (e.g., 5432 → 5431)
3. Load appropriate snapshot (e.g., at sequence 5000)
4. Replay events up to target sequence (5001-5431)
5. Display document with last action undone

**Important Note**: Undo/Redo is time travel to a specific event sequence number. Redo would navigate forward (e.g., to 5432).

### Context: Flow 4 - Dragging an Anchor Point (50ms Sampling) (from 04_Behavior_and_Communication.md)

**Complete PlantUML sequence diagram exists in the architecture document at lines 292-373**

Key participants:
- User
- Canvas Widget
- Tool Manager
- Direct Selection Tool
- Event Sampler
- Event Recorder
- Event Store
- Document State
- Canvas Renderer

Flow includes:
1. **Drag Start**: Mouse down on anchor, hit test to identify anchor, state changes to DRAGGING_ANCHOR
2. **Drag Movement**: Mouse move events sampled at 50ms intervals
   - Within 50ms: Buffer movement (don't emit event)
   - 50ms elapsed: Emit MoveAnchorEvent, persist to store, update UI
3. **Continuous Dragging**: Loop of sampled events (~20 events/second)
4. **Drag End**: Mouse up, flush any buffered final position, return to IDLE state

**Important Note**: 50ms sampling creates smooth playback while limiting event volume. A 2-second drag generates ~40 events instead of 200+.

### Context: Flow 5 - Exporting to SVG (from 04_Behavior_and_Communication.md)

**Complete PlantUML sequence diagram exists in the architecture document at lines 380-434**

Key participants:
- User
- UI Menu
- Export Service
- SVG Exporter
- Document State
- Geometry Service
- File System

Flow includes:
1. User selects File → Export → SVG
2. File save dialog shown, user chooses path
3. Export Service gets all objects from Document State
4. Loop through each VectorObject:
   - If Path: Generate `<path d="M x y C ...">` element with style attributes
   - If Shape: Convert to Path using Geometry Service, then generate SVG path
   - Apply transform matrix as "transform" attribute
5. Write XML to file system
6. Show success notification

**Important Note**: SVG exporter handles Bezier curve conversion, transform matrices, color format conversion (RGBA → hex), and coordinate system mapping (Y-axis flip).

---

## 3. Codebase Analysis & Strategic Guidance

The following analysis is based on my direct review of the current codebase. Use these notes and tips to guide your implementation.

### Relevant Existing Code

*   **File:** `docs/diagrams/component_overview.puml`
    *   **Summary:** This file contains the existing C4 Level 3 Component Diagram for the WireTuner architecture. It demonstrates the PlantUML style and formatting conventions being used in this project.
    *   **Recommendation:** You MUST follow the exact same PlantUML formatting style as this file. Key conventions:
        - Uses `@startuml` / `@enduml` tags
        - Includes C4 imports when using C4 syntax (but sequence diagrams don't use C4 imports)
        - Uses clear title comments
        - Has well-organized sections with comments
        - Uses consistent indentation and spacing
        - Professional, clean formatting throughout

*   **File:** `.codemachine/artifacts/architecture/04_Behavior_and_Communication.md`
    *   **Summary:** This file contains the COMPLETE PlantUML source code for all 5 required sequence diagrams, embedded within markdown code fences (~~~plantuml).
    *   **Recommendation:** You MUST extract the PlantUML code from this file. The diagrams are located at:
        - Flow 1 (Pen Tool): Lines 93-167
        - Flow 2 (Load Document): Lines 174-227
        - Flow 3 (Undo): Lines 234-285
        - Flow 4 (Drag Anchor): Lines 292-373
        - Flow 5 (Export SVG): Lines 380-434
    *   **Important:** The code is enclosed in `~~~plantuml` and `~~~` markers. You need to extract just the PlantUML content (from `@startuml` to `@enduml`) for each diagram.

*   **Directory:** `docs/diagrams/`
    *   **Summary:** This directory already exists and contains the component_overview.puml file.
    *   **Recommendation:** You SHOULD create the new file `event_sourcing_sequences.puml` in this same directory. The directory is already set up with proper permissions.

### Implementation Tips & Notes

*   **Tip:** The architecture document already contains complete, production-ready PlantUML code for all 5 sequence diagrams. Your task is NOT to write new diagrams from scratch, but to extract and consolidate the existing diagrams into a single file.

*   **Tip:** Each diagram in the architecture document is self-contained with its own `@startuml` and `@enduml` tags. You need to combine all 5 diagrams into one file, ensuring each diagram remains complete and separate.

*   **Tip:** Add clear section headers/comments between each diagram to make the file easy to navigate. For example:
    ```
    ' ============================================
    ' Flow 1: Creating a Path with the Pen Tool
    ' ============================================
    ```

*   **Tip:** The PlantUML syntax in the architecture document uses proper participant definitions, alt/loop blocks, and notes. This is the correct approach - do not simplify or modify the logic.

*   **Note:** The existing component_overview.puml uses C4-PlantUML includes (`!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml`), but sequence diagrams use standard PlantUML syntax and do NOT need these includes.

*   **Note:** Each sequence diagram includes important notes (using `note right`, `note left` syntax) that explain critical implementation details. These notes MUST be preserved as they provide valuable context.

*   **Warning:** Do not modify the participant names, message sequences, or flow logic. The diagrams in the architecture document have been carefully designed to match the actual implementation architecture. Your job is to consolidate them, not redesign them.

*   **Quality Check:** After creating the file, verify that:
    1. All 5 diagrams are present
    2. Each diagram has proper `@startuml` / `@enduml` markers
    3. Section comments clearly separate the diagrams
    4. No PlantUML syntax errors (check for matching quotes, proper alt/end blocks, etc.)
    5. All notes and annotations are preserved

*   **File Organization Best Practice:** Structure the file as:
    ```
    ' Header comment with file purpose and date

    ' Flow 1 section comment
    @startuml
    [diagram 1 content]
    @enduml

    ' Flow 2 section comment
    @startuml
    [diagram 2 content]
    @enduml

    [... continue for all 5 diagrams]
    ```

*   **Validation:** The acceptance criteria requires that diagrams "render without syntax errors". You can validate PlantUML syntax at plantuml.com or using a local PlantUML processor. Make sure to test the file after creation.
