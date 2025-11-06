# System Architecture Blueprint: WireTuner

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: api-communication -->
### 3.7. API Design & Communication

<!-- anchor: api-style -->
#### API Style

WireTuner is a **desktop application with no network APIs**. Communication occurs entirely within process boundaries through:

1. **Event-Driven Internal APIs**: Tools and services communicate by emitting/handling events
2. **Immutable Method Calls**: Stateless functions and methods on immutable objects
3. **Reactive UI**: Provider-based state management with `notifyListeners()` pattern

**No REST/GraphQL/gRPC**: Not applicable for single-user desktop application. Future collaborative features would introduce WebSocket-based event synchronization.

<!-- anchor: communication-patterns -->
#### Communication Patterns

<!-- anchor: pattern-event-driven -->
##### 1. Event-Driven Pattern (Core Architecture)

**Usage**: User interactions → Event Recording → State Changes

**Flow:**
```
User Input → Tool Controller → Event Recorder → Event Store (SQLite)
                                     ↓
                              Event Dispatcher → Event Handlers → New Document State
                                                                          ↓
                                                                    UI Rebuild (Provider)
```

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

<!-- anchor: pattern-request-response -->
##### 2. Synchronous Request/Response Pattern

**Usage**: Querying document state, geometry calculations

**Flow:**
```
Tool → Document.getObjectById(id) → VectorObject
Tool → GeometryService.hitTest(path, point) → bool
Canvas Renderer → Document.getAllObjects() → List<VectorObject>
```

**Characteristics:**
- **Synchronous**: Direct function calls, return values immediately
- **Stateless**: Services (GeometryService, HitTestService) have no mutable state
- **Read-Only**: Query methods never mutate state

<!-- anchor: pattern-pub-sub -->
##### 3. Publish/Subscribe Pattern (UI Reactivity)

**Usage**: UI updates in response to document changes

**Flow:**
```
Event Handler applies event → Document state changes → DocumentProvider.notifyListeners()
                                                              ↓
                                                    Widgets rebuild (Consumer/Selector)
```

**Implementation**: Flutter Provider package
- `ChangeNotifier` for document state
- `Consumer<DocumentProvider>` in widgets
- Selective rebuilds with `Selector` for performance

<!-- anchor: interaction-flows -->
#### Key Interaction Flows (Sequence Diagrams)

<!-- anchor: flow-pen-tool-create -->
##### Flow 1: Creating a Path with the Pen Tool

**Description**: User clicks multiple times with the pen tool to create a path with straight segments, then double-clicks to finish the path.

~~~plantuml
@startuml
actor User
participant "Canvas Widget" as Canvas
participant "Tool Manager" as ToolMgr
participant "Pen Tool" as PenTool
participant "Event Recorder" as Recorder
participant "Event Store" as Store
participant "Event Dispatcher" as Dispatcher
participant "Document State" as Doc
participant "Canvas Renderer" as Renderer

User -> Canvas : Click at point A
Canvas -> ToolMgr : onPointerDown(A)
ToolMgr -> PenTool : onPointerDown(A)

alt First Click (Start Path)
  PenTool -> PenTool : State: IDLE → CREATING_PATH
  PenTool -> Recorder : recordEvent(CreatePathEvent(pathId, startAnchor: A))
  Recorder -> Store : INSERT INTO events (...)
  Store --> Recorder : Success
  Recorder -> Dispatcher : dispatch(CreatePathEvent)
  Dispatcher -> Doc : applyEvent(CreatePathEvent)
  Doc -> Doc : Create new Path with anchor at A
  Doc --> Dispatcher : Updated Document
  Dispatcher --> Recorder : State updated
  Recorder -> Canvas : notifyListeners()
  Canvas -> Renderer : paint(Document)
  Renderer --> User : Shows anchor point at A
end

User -> Canvas : Click at point B
Canvas -> ToolMgr : onPointerDown(B)
ToolMgr -> PenTool : onPointerDown(B)

PenTool -> Recorder : recordEvent(AddAnchorEvent(pathId, position: B, type: LINE))
Recorder -> Store : INSERT INTO events (...)
Recorder -> Dispatcher : dispatch(AddAnchorEvent)
Dispatcher -> Doc : applyEvent(AddAnchorEvent)
Doc -> Doc : Add anchor B, create line segment A→B
Doc --> Dispatcher : Updated Document
Dispatcher --> Recorder : State updated
Recorder -> Canvas : notifyListeners()
Canvas -> Renderer : paint(Document)
Renderer --> User : Shows line segment A→B

User -> Canvas : Click at point C
note right: Same flow as point B
Canvas -> ToolMgr : onPointerDown(C)
ToolMgr -> PenTool : onPointerDown(C)
PenTool -> Recorder : recordEvent(AddAnchorEvent(pathId, position: C, type: LINE))
Recorder -> Store : INSERT INTO events (...)
Recorder -> Dispatcher : dispatch(AddAnchorEvent)
Dispatcher -> Doc : applyEvent(AddAnchorEvent)
Doc -> Doc : Add anchor C, create line segment B→C
Recorder -> Canvas : notifyListeners()
Canvas -> Renderer : paint(Document)
Renderer --> User : Shows path A→B→C

User -> Canvas : Double-click (or press Enter)
Canvas -> ToolMgr : onDoubleClick() / onKeyPress(ENTER)
ToolMgr -> PenTool : finishPath()

PenTool -> Recorder : recordEvent(FinishPathEvent(pathId, closed: false))
Recorder -> Store : INSERT INTO events (...)
Recorder -> Dispatcher : dispatch(FinishPathEvent)
Dispatcher -> Doc : applyEvent(FinishPathEvent)
Doc -> Doc : Mark path as complete
PenTool -> PenTool : State: CREATING_PATH → IDLE
Recorder -> Canvas : notifyListeners()
Canvas -> Renderer : paint(Document)
Renderer --> User : Shows completed open path

@enduml
~~~

<!-- anchor: flow-load-document -->
##### Flow 2: Loading a Document (Event Replay)

**Description**: User opens an existing .wiretuner file. The system loads the most recent snapshot, replays subsequent events, and renders the reconstructed document.

~~~plantuml
@startuml
actor User
participant "File Dialog" as FileDialog
participant "Document Service" as DocService
participant "Event Store" as Store
participant "Snapshot Store" as SnapStore
participant "Event Replayer" as Replayer
participant "Event Dispatcher" as Dispatcher
participant "Document State" as Doc
participant "UI Layer" as UI
participant "Canvas Renderer" as Renderer

User -> FileDialog : Select .wiretuner file
FileDialog -> DocService : loadDocument(filePath)

DocService -> Store : ATTACH DATABASE 'filePath'
Store --> DocService : Connection established

DocService -> Store : SELECT MAX(event_sequence) FROM events
Store --> DocService : maxSequence = 5432

DocService -> SnapStore : SELECT snapshot_data, event_sequence\nFROM snapshots\nWHERE event_sequence <= 5432\nORDER BY event_sequence DESC LIMIT 1
SnapStore --> DocService : snapshot at sequence 5000, BLOB data

DocService -> Replayer : replayFromSnapshot(snapshotData, fromSequence: 5000)

Replayer -> Replayer : Deserialize snapshot BLOB → Document
Replayer -> Store : SELECT * FROM events\nWHERE event_sequence > 5000\nORDER BY event_sequence ASC
Store --> Replayer : Events 5001-5432 (432 events)

loop For each event (5001 to 5432)
  Replayer -> Dispatcher : dispatch(event)
  Dispatcher -> Doc : applyEvent(event)
  Doc -> Doc : Create new immutable state
  Doc --> Dispatcher : Updated Document
  Dispatcher --> Replayer : Continue
end

Replayer --> DocService : Final Document state
DocService -> UI : setDocument(document)
UI -> UI : notifyListeners()

UI -> Renderer : build() → Paint Document
Renderer --> User : Display loaded document

note right of Replayer
  Replay of 432 events typically
  takes 20-50ms (depends on
  event complexity and device).
end note

@enduml
~~~

<!-- anchor: flow-undo -->
##### Flow 3: Undo Operation (Event Navigation)

**Description**: User presses Cmd+Z (macOS) or Ctrl+Z (Windows) to undo the last action. The system navigates to the previous event in the history and reconstructs state.

~~~plantuml
@startuml
actor User
participant "UI Layer" as UI
participant "Event Navigator" as Navigator
participant "Event Store" as Store
participant "Snapshot Store" as SnapStore
participant "Event Replayer" as Replayer
participant "Document State" as Doc
participant "Canvas Renderer" as Renderer

User -> UI : Press Cmd+Z (Undo)
UI -> Navigator : undo()

Navigator -> Navigator : currentSequence = 5432
Navigator -> Navigator : targetSequence = 5431

Navigator -> Store : SELECT MAX(event_sequence) FROM snapshots\nWHERE event_sequence <= 5431
Store --> Navigator : snapshotSequence = 5000

Navigator -> SnapStore : SELECT snapshot_data FROM snapshots\nWHERE event_sequence = 5000
SnapStore --> Navigator : Snapshot BLOB

Navigator -> Replayer : replayFromSnapshot(snapshotData, fromSeq: 5000, toSeq: 5431)

Replayer -> Replayer : Deserialize snapshot → Base Document
Replayer -> Store : SELECT * FROM events\nWHERE event_sequence > 5000 AND event_sequence <= 5431\nORDER BY event_sequence ASC
Store --> Replayer : Events 5001-5431 (431 events)

loop For each event (5001 to 5431)
  Replayer -> Doc : applyEvent(event)
  Doc -> Doc : Create new immutable state
end

Replayer --> Navigator : Document at sequence 5431
Navigator -> UI : setDocument(document, currentSequence: 5431)
UI -> UI : notifyListeners()
UI -> Renderer : paint(Document)
Renderer --> User : Display document with last action undone

note right of Navigator
  Undo/Redo is essentially
  time travel to a specific
  event sequence number.

  Redo would navigate to
  sequence 5432 (reapply
  the undone event).
end note

@enduml
~~~

<!-- anchor: flow-drag-anchor -->
##### Flow 4: Dragging an Anchor Point

**Description**: User drags an anchor point with the Direct Selection tool. The system samples the drag at 50ms intervals, records MoveAnchorEvents, and updates the canvas in real-time.

~~~plantuml
@startuml
actor User
participant "Canvas Widget" as Canvas
participant "Tool Manager" as ToolMgr
participant "Direct Selection\nTool" as DirectSel
participant "Event Sampler" as Sampler
participant "Event Recorder" as Recorder
participant "Event Store" as Store
participant "Document State" as Doc
participant "Canvas Renderer" as Renderer

User -> Canvas : Mouse down on anchor point
Canvas -> ToolMgr : onPointerDown(point)
ToolMgr -> DirectSel : onPointerDown(point)

DirectSel -> Doc : hitTestAnchors(point)
Doc --> DirectSel : Found: pathId=P1, anchorIndex=3

DirectSel -> DirectSel : State: IDLE → DRAGGING_ANCHOR\ndragContext = {pathId: P1, anchorIndex: 3, startPos: point}

User -> Canvas : Mouse move (drag)
Canvas -> ToolMgr : onPointerMove(newPoint)
ToolMgr -> DirectSel : onPointerMove(newPoint)

DirectSel -> Sampler : recordMove(pathId, anchorIndex, newPoint, timestamp)

alt Within 50ms of last sample
  Sampler -> Sampler : Buffer movement (don't emit event yet)
  note right: Prevents event flood during fast drag
else 50ms elapsed since last sample
  Sampler -> Recorder : recordEvent(MoveAnchorEvent(P1, 3, delta))
  Recorder -> Store : INSERT INTO events (...)
  Recorder -> Doc : Apply event → New anchor position
  Doc -> Doc : Create new immutable Path with moved anchor
  Recorder -> Canvas : notifyListeners()
  Canvas -> Renderer : paint(Document)
  Renderer --> User : Smooth visual update (anchor moved)
end

User -> Canvas : Continue dragging (multiple moves)
note right: Sampler emits event every 50ms\nResulting in ~20 events/second during drag

loop While dragging
  Canvas -> ToolMgr : onPointerMove(point_i)
  ToolMgr -> DirectSel : onPointerMove(point_i)
  DirectSel -> Sampler : recordMove(...)

  alt 50ms threshold reached
    Sampler -> Recorder : recordEvent(MoveAnchorEvent)
    Recorder -> Store : INSERT
    Recorder -> Doc : Apply event
    Recorder -> Canvas : notifyListeners()
  end
end

User -> Canvas : Mouse up (release)
Canvas -> ToolMgr : onPointerUp(finalPoint)
ToolMgr -> DirectSel : onPointerUp(finalPoint)

DirectSel -> Sampler : flush() (emit final position if buffered)

alt Buffered movement exists
  Sampler -> Recorder : recordEvent(MoveAnchorEvent(final position))
  Recorder -> Store : INSERT INTO events (...)
  Recorder -> Doc : Apply final event
end

DirectSel -> DirectSel : State: DRAGGING_ANCHOR → IDLE
Recorder -> Canvas : notifyListeners()
Canvas -> Renderer : paint(Document)
Renderer --> User : Final anchor position rendered

note right of Sampler
  50ms sampling creates smooth
  playback while limiting event
  volume. A 2-second drag generates
  ~40 events instead of 200+.
end note

@enduml
~~~

<!-- anchor: flow-export-svg -->
##### Flow 5: Exporting to SVG

**Description**: User selects File → Export → SVG. The system converts the current document state to SVG XML and writes it to disk.

~~~plantuml
@startuml
actor User
participant "UI Menu" as Menu
participant "Export Service" as ExportSvc
participant "SVG Exporter" as SVGExp
participant "Document State" as Doc
participant "Geometry Service" as Geo
participant "File System" as FS

User -> Menu : Click "File → Export → SVG"
Menu -> Menu : Show file save dialog
User -> Menu : Choose path "/Users/.../output.svg"
Menu -> ExportSvc : exportSVG(document, filePath)

ExportSvc -> Doc : getAllObjects()
Doc --> ExportSvc : List<VectorObject> (Paths, Shapes)

ExportSvc -> SVGExp : generateSVG(objects, bounds)

SVGExp -> SVGExp : Create XML root <svg> with viewBox

loop For each VectorObject
  alt Object is Path
    SVGExp -> SVGExp : Generate <path d="M x y C ..."> element
    SVGExp -> SVGExp : Apply style attributes (fill, stroke, opacity)
  else Object is Shape
    SVGExp -> Geo : shape.toPath()
    Geo --> SVGExp : Computed Path
    SVGExp -> SVGExp : Generate <path> from computed segments
  end

  SVGExp -> SVGExp : Apply transform matrix as "transform" attribute
  SVGExp -> SVGExp : Append to <svg> tree
end

SVGExp --> ExportSvc : XML Document (string)

ExportSvc -> FS : Write file to "/Users/.../output.svg"
FS --> ExportSvc : Success / Error

ExportSvc --> Menu : Export complete
Menu -> Menu : Show "Export successful" notification
Menu --> User : Notification displayed

note right of SVGExp
  SVG exporter handles:
  - Bezier curve conversion to SVG path syntax
  - Transform matrix to SVG transform attribute
  - Color format conversion (RGBA → hex)
  - Coordinate system mapping (Y-axis flip)
end note

@enduml
~~~

---

<!-- anchor: internal-apis -->
#### Internal API Contracts

While WireTuner has no external HTTP APIs, it maintains clear internal contracts between layers:

<!-- anchor: api-event-recorder -->
##### Event Recorder API

```dart
class EventRecorder {
  /// Records a user interaction event with automatic sampling
  Future<void> recordEvent(DocumentEvent event);

  /// Flushes any buffered sampled events immediately
  void flush();

  /// Pauses event recording (e.g., during event replay)
  void pause();

  /// Resumes event recording
  void resume();
}
```

<!-- anchor: api-event-replayer -->
##### Event Replayer API

```dart
class EventReplayer {
  /// Reconstructs document state from events
  /// [fromSequence]: Event sequence to start from (0 = beginning)
  /// [toSequence]: Event sequence to end at (null = latest)
  Future<Document> replay({
    int fromSequence = 0,
    int? toSequence,
  });

  /// Loads document from most recent snapshot + subsequent events
  Future<Document> replayFromSnapshot({
    required int maxSequence,
  });
}
```

<!-- anchor: api-tool-interface -->
##### Tool Interface API

```dart
abstract class ITool {
  String get toolId;
  Cursor get cursor;

  /// Called when tool becomes active
  void onActivate();

  /// Called when tool becomes inactive
  void onDeactivate();

  /// Pointer event handlers (return true if event handled)
  bool onPointerDown(PointerDownEvent event);
  bool onPointerMove(PointerMoveEvent event);
  bool onPointerUp(PointerUpEvent event);

  /// Keyboard event handler
  bool onKeyPress(KeyEvent event);

  /// Render tool-specific overlay (guides, handles, cursors)
  void renderOverlay(Canvas canvas, Size size);
}
```

<!-- anchor: api-document-state -->
##### Document State API

```dart
class Document {
  /// Immutable getters
  String get id;
  String get title;
  List<Layer> get layers;
  Selection get selection;
  Viewport get viewport;

  /// Query methods
  VectorObject? getObjectById(String id);
  List<VectorObject> getAllObjects();
  List<VectorObject> getObjectsInBounds(Rectangle bounds);

  /// Create modified copy (immutable pattern)
  Document copyWith({
    String? title,
    List<Layer>? layers,
    Selection? selection,
    Viewport? viewport,
  });
}
```

---

<!-- anchor: error-handling -->
#### Error Handling & Communication Failures

**Event Persistence Failures:**
- **Scenario**: SQLite INSERT fails (disk full, permissions)
- **Handling**: Show error dialog, disable save until resolved, keep in-memory state
- **Recovery**: Prompt user to save to alternate location

**Event Replay Failures:**
- **Scenario**: Corrupted event payload, missing event handler
- **Handling**: Log error, skip event, continue replay
- **UI**: Show warning banner "Document may be incomplete (N events skipped)"

**File I/O Failures:**
- **Scenario**: Cannot read .wiretuner file, .ai import fails
- **Handling**: Show error dialog with details, offer to open recent files
- **Logging**: Write detailed error to application log for debugging

**Render Failures:**
- **Scenario**: Invalid geometry (degenerate Bezier curves, NaN coordinates)
- **Handling**: Skip rendering problematic object, log warning
- **Visual**: Show error icon in layer panel for problematic objects
