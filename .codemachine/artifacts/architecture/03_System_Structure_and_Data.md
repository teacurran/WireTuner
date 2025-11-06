# System Architecture Blueprint: WireTuner

**Version:** 1.0
**Date:** 2025-11-05

---

<!-- anchor: system-structure -->
## 3. Proposed Architecture (Continued)

<!-- anchor: system-context-diagram -->
### 3.3. System Context Diagram (C4 Level 1)

<!-- anchor: context-description -->
#### Description

The System Context diagram illustrates WireTuner's position within its environment, showing the primary user (Vector Artist) and external systems the application interacts with. WireTuner is a self-contained desktop application with no runtime dependencies on external services. All interactions are file-based: importing vector files, exporting to standard formats, and persisting work to local storage.

**Key Insights:**
- Single-user desktop application with no cloud dependencies
- File-based integration with external tools (Adobe Illustrator, web browsers, PDF readers)
- Operating system provides file system access
- No authentication or networking required for core functionality

<!-- anchor: context-diagram -->
#### Diagram (PlantUML)

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

title System Context Diagram - WireTuner Vector Editor

' Define Persons
Person(artist, "Vector Artist", "Professional or amateur illustrator creating vector graphics")

' Define the System Boundary
System_Boundary(wiretuner_boundary, "WireTuner Desktop Application") {
  System(wiretuner, "WireTuner", "Event-sourced vector drawing application for macOS/Windows")
}

' Define External Systems
System_Ext(file_system, "File System", "Operating system file storage (macOS/Windows)")
System_Ext(illustrator, "Adobe Illustrator", "Industry-standard vector editor (.ai files)")
System_Ext(pdf_viewer, "PDF Viewer", "Acrobat, Preview, etc.")
System_Ext(web_browser, "Web Browser", "Chrome, Firefox, Safari (SVG display)")

' Define Relationships
Rel(artist, wiretuner, "Creates and edits vector graphics using", "Mouse/Keyboard/Trackpad")

Rel(wiretuner, file_system, "Saves/loads .wiretuner documents to", "File I/O")
Rel(wiretuner, file_system, "Exports SVG/PDF files to", "File I/O")
Rel(wiretuner, file_system, "Imports .ai/.svg files from", "File I/O")

Rel(file_system, illustrator, "Stores .ai files for import", "")
Rel(file_system, pdf_viewer, "Provides PDF files to open", "")
Rel(file_system, web_browser, "Provides SVG files to display", "")

SHOW_LEGEND()

@enduml
~~~

---

<!-- anchor: container-diagram -->
### 3.4. Container Diagram (C4 Level 2)

<!-- anchor: container-description -->
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

<!-- anchor: container-diagram-plantuml -->
#### Diagram (PlantUML)

~~~plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

title Container Diagram - WireTuner Internal Architecture

Person(artist, "Vector Artist", "User creating vector graphics")

System_Boundary(wiretuner_boundary, "WireTuner Desktop Application") {
  Container(ui_layer, "UI Layer", "Flutter Widgets", "Main window, toolbars, panels, dialogs")
  Container(canvas, "Canvas Renderer", "CustomPainter", "High-performance vector rendering at 60 FPS")
  Container(tools, "Tool System", "Dart Classes", "Pen, Selection, Shape tools with state machines")

  Container(event_recorder, "Event Recorder", "Dart Service", "Samples user input at 50ms, creates event objects")
  Container(event_replayer, "Event Replayer", "Dart Service", "Reconstructs document state from event log")
  Container(snapshot_manager, "Snapshot Manager", "Dart Service", "Creates/loads state snapshots every 1000 events")

  Container(vector_engine, "Vector Engine", "Domain Models", "Path, Shape, Document immutable data structures")
  Container(geometry, "Geometry Engine", "Dart Classes", "Bezier math, hit testing, transforms")

  ContainerDb(event_store, "Event Store", "SQLite Database", "Append-only event log with ACID guarantees")
  ContainerDb(snapshot_store, "Snapshot Store", "SQLite BLOB", "Serialized document snapshots for fast replay")

  Container(svg_exporter, "SVG Exporter", "XML Generator", "Converts Document to SVG 1.1")
  Container(pdf_exporter, "PDF Exporter", "PDF Library", "Generates PDF 1.7 documents")
  Container(ai_importer, "AI Importer", "PDF Parser", "Reads Adobe Illustrator files")
  Container(svg_importer, "SVG Importer", "XML Parser", "Parses SVG into Document events")
}

System_Ext(file_system, "File System", "OS-provided storage")

' User interactions
Rel(artist, ui_layer, "Interacts with", "Mouse/Keyboard")
Rel(artist, canvas, "Views rendered graphics on", "Display")

' UI to Tools
Rel(ui_layer, tools, "Routes input events to", "Method calls")
Rel(tools, event_recorder, "Generates interaction events", "Event objects")

' Event flow
Rel(event_recorder, event_store, "Appends events to", "SQL INSERT")
Rel(event_recorder, snapshot_manager, "Triggers snapshot every 1000 events", "Callback")
Rel(snapshot_manager, snapshot_store, "Saves document state to", "SQL BLOB")

' Replay flow
Rel(event_store, event_replayer, "Provides event history", "SQL SELECT")
Rel(snapshot_store, event_replayer, "Loads base snapshot from", "SQL SELECT")
Rel(event_replayer, vector_engine, "Reconstructs document state in", "Object construction")

' Rendering flow
Rel(vector_engine, geometry, "Uses for calculations", "Method calls")
Rel(vector_engine, canvas, "Provides render data to", "Paint calls")

' File operations
Rel(ui_layer, svg_exporter, "Triggers export", "Save dialog")
Rel(ui_layer, pdf_exporter, "Triggers export", "Save dialog")
Rel(ui_layer, ai_importer, "Triggers import", "Open dialog")
Rel(ui_layer, svg_importer, "Triggers import", "Open dialog")

Rel(vector_engine, svg_exporter, "Provides document data to", "")
Rel(vector_engine, pdf_exporter, "Provides document data to", "")
Rel(ai_importer, event_recorder, "Generates events from file", "Event stream")
Rel(svg_importer, event_recorder, "Generates events from file", "Event stream")

Rel(svg_exporter, file_system, "Writes file to", "File I/O")
Rel(pdf_exporter, file_system, "Writes file to", "File I/O")
Rel(ai_importer, file_system, "Reads file from", "File I/O")
Rel(svg_importer, file_system, "Reads file from", "File I/O")

Rel(event_store, file_system, "Persisted as .wiretuner file in", "SQLite file")
Rel(snapshot_store, file_system, "Stored within .wiretuner file", "SQLite BLOB")

SHOW_LEGEND()

@enduml
~~~

---

<!-- anchor: component-diagram -->
### 3.5. Component Diagram(s) (C4 Level 3)

<!-- anchor: component-description -->
#### Description

This section provides detailed component views of the most critical containers. We focus on three key areas:

1. **Vector Engine Components**: Core domain models and geometry logic
2. **Event Sourcing Core Components**: Event recording, replay, and snapshot mechanisms
3. **Tool System Components**: Tool framework and primary tool implementations

<!-- anchor: component-vector-engine -->
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

<!-- anchor: component-event-sourcing -->
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

<!-- anchor: component-tool-system -->
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

---

<!-- anchor: data-model -->
### 3.6. Data Model Overview & ERD

<!-- anchor: data-model-description -->
#### Description

WireTuner's data model is split into two domains:

1. **Event Sourcing Schema (SQLite)**: Persistent event log and snapshot storage
2. **Vector Domain Model (In-Memory)**: Immutable Dart objects representing the document

The SQLite database provides durability and serves as the source of truth. The in-memory domain model is reconstructed on-demand through event replay.

<!-- anchor: data-model-event-schema -->
#### Event Sourcing Schema (SQLite Tables)

**Rationale for SQLite Schema Design:**
- **Append-only `events` table**: Ensures event immutability, supports efficient replay via indexed `event_sequence`
- **Periodic `snapshots` table**: Avoids replaying entire event history (10,000 events = ~1 minute replay time; snapshot every 1000 events reduces to ~50ms)
- **`metadata` table**: Stores document-level info (title, created date, version) separate from event stream
- **ACID guarantees**: SQLite transactions ensure no partial writes during crashes

<!-- anchor: data-model-key-entities -->
#### Key Entities

**Persistent Entities (SQLite):**
- **Event**: Immutable record of user interaction (type, payload, timestamp, sequence number)
- **Snapshot**: Serialized document state at a specific event sequence
- **Metadata**: Document-level properties (title, version, created/modified timestamps)

**Domain Entities (In-Memory Dart Objects):**
- **Document**: Root aggregate containing all layers, artboards, and objects
- **Path**: Sequence of connected segments (open or closed curve)
- **Shape**: Geometric primitives (Rectangle, Ellipse, Polygon, Star) with computed paths
- **Segment**: Line, cubic Bezier curve, or arc connecting two anchor points
- **Anchor Point**: Position + optional Bezier control point handles (BCPs)
- **Style**: Fill/stroke colors, widths, opacity, blend modes
- **Transform**: Affine transformation matrix (translate, rotate, scale, skew)
- **Selection**: Set of selected object IDs and anchor indices

<!-- anchor: data-model-erd -->
#### Diagram (PlantUML - ERD)

~~~plantuml
@startuml

title Entity-Relationship Diagram - WireTuner Persistent Data

' SQLite Tables
entity metadata {
  *document_id : TEXT <<PK>>
  --
  title : TEXT
  format_version : INTEGER
  created_at : INTEGER (Unix timestamp)
  modified_at : INTEGER (Unix timestamp)
  author : TEXT (optional)
}

entity events {
  *event_id : INTEGER <<PK, AUTOINCREMENT>>
  --
  document_id : TEXT <<FK>>
  event_sequence : INTEGER (0-based, unique per document)
  event_type : TEXT (e.g., "CreatePath", "MoveAnchor")
  event_payload : TEXT (JSON serialized)
  timestamp : INTEGER (Unix timestamp milliseconds)
  user_id : TEXT (future: for collaboration)
}

entity snapshots {
  *snapshot_id : INTEGER <<PK, AUTOINCREMENT>>
  --
  document_id : TEXT <<FK>>
  event_sequence : INTEGER (snapshot taken after this event)
  snapshot_data : BLOB (serialized Document)
  created_at : INTEGER (Unix timestamp)
  compression : TEXT (e.g., "gzip", "none")
}

' Relationships
metadata ||--o{ events : "contains"
metadata ||--o{ snapshots : "has"

' Notes
note right of events
  Append-only log.
  Indexed on (document_id, event_sequence)
  for efficient replay.
  Typical size: ~100-500 bytes per event.
end note

note right of snapshots
  Created every 1000 events.
  BLOB size: ~10KB-1MB depending on complexity.
  Enables fast document loading without
  replaying entire event history.
end note

@enduml
~~~

<!-- anchor: data-model-domain-erd -->
#### Domain Model (In-Memory Structures)

~~~plantuml
@startuml

title Domain Model - WireTuner Vector Objects (In-Memory)

' Core domain entities
class Document {
  +id : String
  +title : String
  +layers : List<Layer>
  +selection : Selection
  +viewport : Viewport
  --
  +getAllObjects() : List<VectorObject>
  +getObjectById(id) : VectorObject?
}

class Layer {
  +id : String
  +name : String
  +visible : bool
  +locked : bool
  +objects : List<VectorObject>
}

abstract class VectorObject {
  +id : String
  +transform : Transform
  +style : Style
  --
  +bounds() : Rectangle
  +hitTest(point) : bool
}

class Path {
  +segments : List<Segment>
  +closed : bool
  --
  +length() : double
  +pointAt(t) : Point
}

class Shape {
  +shapeType : ShapeType (rect/ellipse/polygon/star)
  +parameters : Map<String, double>
  --
  +toPath() : Path
}

enum ShapeType {
  RECTANGLE
  ELLIPSE
  POLYGON
  STAR
}

class Segment {
  +startAnchor : AnchorPoint
  +endAnchor : AnchorPoint
  +type : SegmentType (line/bezier/arc)
  +controlPoint1 : Point? (for bezier)
  +controlPoint2 : Point? (for bezier)
}

class AnchorPoint {
  +position : Point
  +handleIn : Point? (BCP)
  +handleOut : Point? (BCP)
  +anchorType : AnchorType (corner/smooth/symmetric)
}

class Style {
  +fill : Paint?
  +stroke : Paint?
  +strokeWidth : double
  +opacity : double
  +blendMode : BlendMode
}

class Transform {
  +matrix : Matrix4
  --
  +translate(dx, dy)
  +rotate(angle)
  +scale(sx, sy)
}

class Selection {
  +objectIds : Set<String>
  +anchorIndices : Map<String, Set<int>>
  --
  +isEmpty() : bool
  +contains(objectId) : bool
}

class Viewport {
  +pan : Point
  +zoom : double
  +canvasSize : Size
  --
  +toScreen(worldPoint) : Point
  +toWorld(screenPoint) : Point
}

' Relationships
Document "1" *-- "0..*" Layer : contains
Layer "1" *-- "0..*" VectorObject : contains
VectorObject <|-- Path
VectorObject <|-- Shape
Path "1" *-- "2..*" Segment : composed of
Segment "1" *-- "2" AnchorPoint : defined by
VectorObject "1" *-- "1" Style : styled with
VectorObject "1" *-- "1" Transform : transformed by
Shape "1" -- "1" ShapeType : is a
Document "1" *-- "1" Selection : tracks
Document "1" *-- "1" Viewport : views through

note right of VectorObject
  All domain objects are immutable.
  Modifications create new copies
  with changed properties.
end note

note bottom of AnchorPoint
  BCPs (Bezier Control Points) are
  optional. Present only for smooth
  curve segments.
end note

@enduml
~~~

<!-- anchor: data-model-rationale -->
#### Data Model Design Rationale

**Immutability Pattern:**
- **Why**: Simplifies event sourcing (each event produces new state), enables time-travel debugging, thread-safe
- **How**: Dart `@immutable` classes, `copyWith()` methods (via Freezed code generation)
- **Trade-off**: Memory overhead from copying, mitigated by structural sharing (reuse unchanged sub-trees)

**Separation of Path vs. Shape:**
- **Why**: Shapes have parametric definitions (e.g., "rectangle with width=100, height=50") that can be edited post-creation
- **How**: Shape stores parameters, generates Path on-demand for rendering
- **Benefit**: Non-destructive editing (change rectangle corner radius without losing parametric nature)

**Anchor Point Design:**
- **Why**: Matches industry standard (Adobe Illustrator model)
- **Components**: Position + optional in/out handles (BCPs) + anchor type (corner/smooth/symmetric)
- **Benefit**: Supports straight lines (no BCPs), smooth curves (symmetric BCPs), and corner curves (independent BCPs)

**Selection as First-Class Entity:**
- **Why**: Selection state is modified frequently during editing
- **Inclusion**: Part of Document model for simplicity (alternative: separate SelectionService)
- **Content**: Object IDs + anchor indices for direct selection tool

**Event Payload as JSON:**
- **Why**: Schema flexibility (add fields without migration), human-readable for debugging
- **Trade-off**: Larger storage vs. binary (acceptable at 50ms sampling rate)
- **Alternative**: Consider binary encoding (Protocol Buffers) if file sizes become problematic
