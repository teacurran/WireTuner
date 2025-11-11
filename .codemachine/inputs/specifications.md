# WireTuner - Vector Drawing Application
## Comprehensive Project Specification

---

### **Part 1: The Essentials (Core Requirements)**

#### **1.0 Project Overview**

**1.1 Project Name:** WireTuner

**1.2 Project Goal:**
WireTuner is a professional desktop vector drawing application with complete event-sourced interaction history, enabling users to create precise vector artwork while capturing their entire creative process for replay, analysis, and collaboration.

**1.3 Target Audience:**
- Professional graphic designers and illustrators requiring precise vector drawing tools
- Design teams needing to understand and replay creative workflows
- Digital artists working across multiple platforms (macOS and Windows)
- Users migrating from or collaborating with Adobe Illustrator users

**1.4 Primary Differentiator:**
Unlike traditional vector editors (Illustrator, Inkscape), WireTuner records every user interaction with **complete event sourcing**, capturing all critical actions (clicks, drags, edits) plus optional mouse movement sampling (configurable, default 200ms) for rich history replay visualization — not just undo/redo, but scrubbing through the entire creative process like video playback of the design session.

---

#### **2.0 Core Functionality & User Journeys**

##### **2.1 Core Features List**

**Drawing & Creation:**
- Pen Tool (Bézier path creation with anchor points and control handles)
- Shape Tools (Rectangle, Ellipse, Polygon, Star)
- Selection Tool (object-level selection)
- Direct Selection Tool (anchor point and control handle editing)

**Document Management:**
- Create new documents with multiple artboards (unlimited per document)
- Save documents in native .wiretuner format (SQLite-based)
- Load documents with automatic version migration
- Multi-document interface with shared application instance
- Artboard Navigator for managing and opening artboards across all open documents

**Multi-Artboard System:**
- Each document contains multiple artboards (like Figma frames or Sketch artboards)
- Each artboard opens in its own dedicated window
- Artboard Navigator provides thumbnail view of all artboards across all open files
- Per-artboard layers, viewport state, and selection state
- Artboard presets (iPhone 14, Desktop 1920x1080, A4 Paper, Custom)

**Viewport & Navigation:**
- Pan (spacebar + drag)
- Zoom (pinch/scroll with viewport transform)
- Viewport state preserved per-artboard (independent zoom/pan for each artboard)
- Artboard Navigator with live thumbnail previews (updates every 10 seconds or on save)

**History & Undo:**
- Operation-based undo/redo (200ms idle boundary detection)
- History panel showing all operations with thumbnails (future)
- Event replay visualization (scrub through history)

**Import/Export:**
- Import: SVG (Tier 1 & 2), Adobe Illustrator AI files (Tier 2)
- Export: SVG (high-fidelity, standards-compliant), PDF (via SVG-to-PDF conversion)

**Visual Feedback:**
- Always-visible anchor points with type-specific visualization
- Selection overlay with bounding boxes
- Tool cursors with 0.2ms update latency
- Performance metrics overlay (FPS monitor, event count)

---

##### **2.2 User Journeys**

**Journey 1: Create a Vector Path with Pen Tool**

1. User clicks Pen Tool icon in toolbar → app **MUST** activate Pen Tool and change cursor to crosshair
2. User clicks on canvas → app **MUST** create first anchor point and record `CreatePathEvent`
3. User clicks second location → app **MUST** add second anchor with straight segment, record `path.anchor.added` event
4. User clicks and drags → app **MUST** create Bézier anchor with control handles, show live preview
5. User releases mouse → app **MUST** commit anchor point, record `path.anchor.added` event with handle positions
6. User clicks starting anchor (within 8px hit radius) → app **MUST** close path and record `FinishPathEvent`
7. User presses Escape → app **MUST** cancel current path, discard uncommitted anchors

**Journey 2: Edit Existing Path with Direct Selection**

1. User clicks Direct Selection Tool → app **MUST** activate tool and show all anchor points as colored overlays
2. User hovers over anchor point → app **MUST** increase anchor size by 30% and show outer glow
3. User clicks anchor → app **MUST** select anchor, show blue 2px outline, display control handles
4. User drags anchor → app **MUST**:
   - Show live position update in real-time
   - Record drag start event with initial position (critical)
   - Optionally sample intermediate positions at configurable rate (default: 200ms, for replay visualization only)
   - User can configure sampling from 0ms (every frame) to 500ms+ (sparse) via settings
5. User holds Shift while dragging → app **MUST** enable grid snapping to 10px grid
6. User releases mouse → app **MUST**:
   - Record drag end event with final position (critical)
   - Commit final position to document state
   - Flush any queued sampled events
   - **Note:** Even with no intermediate samples, replay can infer smooth motion from start→end positions
7. User drags control handle (BCP) → app **MUST** adjust Bézier curve in real-time, respect anchor type:
   - Smooth anchor → **MUST** mirror opposite handle automatically
   - Corner anchor → **MUST** adjust handle independently
   - Tangent anchor → **MUST** adjust single handle only

**Journey 3: Save Document**

1. User presses Cmd/Ctrl+S → app **MUST** show file picker dialog
2. User selects location and filename → app **MUST** validate writable directory
3. User confirms save → app **MUST**:
   - Create snapshot of current document state
   - Write all events to SQLite database
   - Embed file format version header (current: v1.0.0)
   - Record metadata (document name, author, created/modified timestamps)
   - Show "Saved successfully" status message
4. If save fails → app **MUST** show error dialog with retry option, preserve unsaved work in memory

**Journey 4: Load Document**

1. User presses Cmd/Ctrl+O → app **MUST** show file picker
2. User selects .wiretuner file → app **MUST** validate file format and version
3. If file version is current or backward-compatible → app **MUST**:
   - Load most recent snapshot from database
   - Replay events since snapshot to reconstruct current state
   - Display document in new window (MDI)
   - Target load time: <100ms for documents up to 10K events
4. If file version is newer (unsupported) → app **MUST** show "Cannot open - created with newer version" error with upgrade prompt
5. If file version is older (requires migration) → app **MUST**:
   - Show "Migrating file format..." progress dialog
   - Run migration scripts (e.g., v1→v2)
   - Create backup of original file
   - Load migrated document

**Journey 5: Import SVG File**

1. User selects File → Import → SVG → app **MUST** show file picker
2. User selects SVG file → app **MUST** parse SVG XML with validator
3. During parsing → app **MUST**:
   - Extract paths, shapes, fills, strokes (Tier 1 features)
   - Extract gradients, clipPaths, text-as-paths (Tier 2 features)
   - Log warnings for unsupported features (blend modes, live effects)
   - Show import preview dialog with feature compatibility report
4. User confirms import → app **MUST** create `ObjectImportedEvent` with all imported objects, add to current layer
5. If parsing fails → app **MUST** show "Import failed" error with detailed message, no partial import

**Journey 6: Export to SVG and PDF**

**SVG Export:**
1. User selects File → Export → SVG → app **MUST** show file save dialog
2. User confirms filename → app **MUST**:
   - Convert all paths to SVG `<path>` elements with `d` attribute
   - Convert shapes to native SVG elements (`<rect>`, `<circle>`, `<ellipse>`, `<polygon>`)
   - Embed fills, strokes, transforms as SVG attributes
   - Set viewBox to artboard bounds
   - Write UTF-8 XML with proper namespaces (xmlns="http://www.w3.org/2000/svg")
   - Include metadata: generator="WireTuner", version, creation date
3. On success → app **MUST** show "Exported successfully" message
4. User opens exported SVG in Illustrator → file **MUST** render identically (no precision loss)

**PDF Export (via SVG-to-PDF Conversion):**
1. User selects File → Export → PDF → app **MUST** show file save dialog
2. User confirms filename → app **MUST**:
   - **Step 1:** Generate high-fidelity SVG (same process as SVG export above)
   - **Step 2:** Pass SVG to open-source SVG-to-PDF library (e.g., `librsvg` + Cairo, `resvg`, or similar)
   - **Step 3:** Library converts SVG to PDF vector graphics
   - **Step 4:** Write PDF file to disk
3. On success → app **MUST** show "Exported successfully" message
4. If conversion fails → app **MUST** show error: "PDF export failed: [library error]. Try exporting as SVG first to verify rendering."
5. User opens exported PDF in Adobe Acrobat → file **MUST** show vector paths (not rasterized), preserve colors and strokes

**Rationale for SVG-to-PDF approach:**
- **Maintainability:** Single source of truth for vector export (SVG exporter)
- **Standards compliance:** SVG is W3C standard, PDF generation delegated to battle-tested libraries
- **Reduced complexity:** No need to maintain separate PDF operator parsing/generation code
- **Quality:** Open-source libraries (librsvg, resvg) handle edge cases better than custom implementations

**Journey 7: Undo/Redo Operations**

1. User creates rectangle → app **MUST** record as single operation
2. User drags rectangle for 2 seconds → app **MUST** sample at 50ms intervals but group as single operation
3. User presses Cmd/Ctrl+Z → app **MUST**:
   - Replay events up to previous operation boundary (200ms idle threshold)
   - Show "Undo: Move Rectangle" in status bar
   - Update canvas to show previous state
4. User presses Cmd/Ctrl+Shift+Z → app **MUST** redo operation, advance event sequence
5. User undoes 5 operations then creates new shape → app **MUST** clear redo stack, branch history from undo point

**Journey 8: Multi-Selection with Keyboard Modifiers**

1. User clicks object with Selection Tool → app **MUST** select object, show bounding box
2. User holds Shift and clicks second object → app **MUST** add to selection, show unified bounding box
3. User holds Shift and clicks selected object → app **MUST** deselect that object only
4. User drags marquee around multiple objects → app **MUST** select all fully-enclosed objects
5. User holds Alt/Option and drags marquee → app **MUST** select all objects touched by marquee (not just enclosed)

**Journey 9: Anchor Point Visibility Toggle**

**Default State: Always Visible**
1. User creates path with Pen Tool → app **MUST** show anchor points by default on all paths:
   - Smooth anchors: Red filled circles (5px radius) with black 1px stroke
   - Corner anchors: Black filled squares (7x7px) with white 1px stroke
   - Tangent anchors: Orange filled triangles (7px equilateral) with black 1px stroke
2. User zooms to 800% → anchor point visual size **MUST** remain constant in screen pixels (scale-independent)

**Visibility Toggle (3 Modes):**
3. User clicks anchor visibility icon in window frame → app **MUST** cycle through 3 modes:
   - **Mode 1 (Default): "All Visible"** - Show anchors on all paths
     - Icon visual: Multiple dots (●●●) with blue highlight
   - **Mode 2: "Selected Only"** - Show anchors only on currently selected paths
     - Icon visual: Single dot with selection box (⬚●)
     - Non-selected paths show no anchors
     - When selection changes, anchor overlay updates immediately
   - **Mode 3: "Hidden"** - No anchors visible on any paths
     - Icon visual: Dots with strikethrough (●̶●̶●̶) or crossed-out eye
     - Overlay renderer unregistered (zero performance cost)

**Icon Location:**
4. Icon **MUST** be positioned in window frame (toolbar or status bar):
   - **Option A:** Top toolbar, near viewport controls (zoom/pan buttons)
   - **Option B:** Bottom-right status bar corner
   - **Option C:** Floating tool palette (if implemented)
   - Icon includes tooltip on hover: "Anchor Points: All Visible / Selected Only / Hidden"

**Keyboard Shortcut:**
5. User presses **Cmd/Ctrl+Shift+A** → app **MUST** cycle through modes in same order (All → Selected → Hidden → All)

**Persistence:**
6. Anchor visibility mode **MUST** be saved:
   - **Per-document preference** (saved in document metadata)
   - **Global default** (application settings for new documents)
   - When document reopened → restore last used mode for that document

**Visual Feedback:**
7. When switching modes → app **MUST** show brief toast notification:
   - "Anchor Points: All Visible"
   - "Anchor Points: Selected Paths Only"
   - "Anchor Points: Hidden"

**Performance:**
8. Mode 2 (Selected Only) and Mode 3 (Hidden) **MUST** unregister unused overlay painters for performance

**Journey 10: Open Document with Multiple Artboards**

1. User presses Cmd/Ctrl+O → app **MUST** show file picker dialog
2. User selects `website-design.wiretuner` → app **MUST**:
   - Load document metadata and detect artboard count (e.g., 5 artboards)
   - Open Artboard Navigator window automatically
   - Show thumbnail grid of all 5 artboards with names and dimensions
   - Display artboard names: "Homepage 1920x1080", "Mobile 375x812", "Tablet 768x1024", "Login Modal 400x600", "Icons 1000x1000"
3. User clicks "Homepage 1920x1080" thumbnail → app **MUST**:
   - Open new window titled "Homepage 1920x1080 - website-design.wiretuner"
   - Restore saved viewport state for that artboard (zoom 100%, centered)
   - Load per-artboard layers and objects
   - Show artboard bounds with background color
4. User clicks "Mobile 375x812" thumbnail → app **MUST**:
   - Open second window titled "Mobile 375x812 - website-design.wiretuner"
   - Both windows now visible independently
   - Each window has isolated selection and viewport state

**Journey 11: Create New Artboard in Existing Document**

1. User has `website-design.wiretuner` open with Navigator visible
2. User clicks "+" button in Navigator → app **MUST** show "New Artboard" dialog with:
   - Name field (default: "Artboard 6")
   - Size presets dropdown: "iPhone 14 Pro (393x852)", "Desktop HD (1920x1080)", "A4 Portrait (595x842)", "Instagram Square (1080x1080)", "Custom"
   - Width/Height fields (editable if "Custom" selected)
   - Background color picker (default: white)
3. User selects "iPhone 14 Pro (393x852)" and clicks "Create" → app **MUST**:
   - Create new artboard with ID, name, bounds
   - Add to document's artboard list
   - Record `artboard.created` event
   - Show new thumbnail in Navigator
   - Automatically open artboard window
4. New window shows empty artboard with one default layer

**Journey 12: Manage Multiple Open Documents**

1. User has `project-a.wiretuner` open (3 artboards)
2. User presses Cmd/Ctrl+O and opens `project-b.wiretuner` (4 artboards)
3. Artboard Navigator **MUST**:
   - Show tabs at top: "project-a.wiretuner" | "project-b.wiretuner"
   - Display thumbnails for currently selected tab
   - Clicking tab switches thumbnail view
   - Active document tab highlighted
4. User opens artboard from each document → app **MUST**:
   - Create windows with document name in title: "Homepage - project-a.wiretuner"
   - Allow simultaneous editing across documents
   - Keep event logs isolated per document
5. User closes `project-a.wiretuner` tab in Navigator → app **MUST**:
   - Prompt: "Close all artboards for project-a.wiretuner?"
   - If confirmed: Close all artboard windows for that document, remove from Navigator tabs

**Journey 13: Rename and Reorder Artboards**

1. User right-clicks artboard thumbnail in Navigator → app **MUST** show context menu:
   - Rename Artboard
   - Duplicate Artboard
   - Delete Artboard
   - Export Artboard...
2. User selects "Rename Artboard" → app **MUST**:
   - Show inline text field over thumbnail with current name selected
   - User types "Hero Section" and presses Enter
   - Record `artboard.renamed` event
   - Update window title if artboard is open: "Hero Section - website-design.wiretuner"
3. User drags artboard thumbnail to new position in Navigator → app **MUST**:
   - Show drop indicator between thumbnails
   - On drop: reorder artboards in document
   - Record `artboard.reordered` event
   - Update zIndex values

**Journey 14: Delete Artboard with Safety Checks**

1. User right-clicks artboard thumbnail → selects "Delete Artboard"
2. App **MUST** show confirmation dialog:
   - "Delete artboard 'Mobile 375x812'? This will permanently delete 47 objects and 3 layers."
   - Buttons: "Cancel" | "Delete"
3. User clicks "Delete" → app **MUST**:
   - Close artboard window if open
   - Remove artboard from document
   - Delete all layers and objects belonging to that artboard
   - Record `artboard.deleted` event with cascade metadata
   - Remove thumbnail from Navigator
4. If deleting last artboard → app **MUST**:
   - Show error: "Cannot delete last artboard. Documents must have at least one artboard."
   - Prevent deletion

**Journey 15: Per-Artboard Viewport State Persistence**

1. User opens "Homepage" artboard → zooms to 200%, pans to center
2. User opens "Mobile" artboard → zooms to 150%, pans to top
3. User closes both artboard windows
4. User saves document with Cmd/Ctrl+S
5. User quits application
6. Later: User reopens `website-design.wiretuner`
7. User clicks "Homepage" thumbnail in Navigator → app **MUST**:
   - Restore viewport to 200% zoom, centered position (saved state)
   - Not default 100% zoom
8. User clicks "Mobile" thumbnail → app **MUST**:
   - Restore viewport to 150% zoom, top position
   - Each artboard remembers its last viewport independently

**Journey 16: Per-Artboard Selection Isolation**

1. User has two artboard windows open: "Homepage" and "Mobile"
2. In "Homepage" window: User selects 3 rectangles with Selection Tool
3. User switches focus to "Mobile" window → app **MUST**:
   - "Mobile" window shows no selection (starts empty)
   - "Homepage" window keeps its 3 rectangles selected
4. In "Mobile" window: User selects 2 circles
5. User switches back to "Homepage" → app **MUST**:
   - "Homepage" still shows 3 rectangles selected (preserved)
   - "Mobile" still has 2 circles selected (isolated)
6. Selection state is per-artboard, not global

**Journey 17: Navigator Thumbnail Auto-Update**

1. User has Navigator open, showing 5 artboard thumbnails
2. User opens "Homepage" artboard window
3. User draws complex path with pen tool
4. Navigator thumbnail **MUST**:
   - Continue showing old thumbnail (performance optimization)
   - After 10 seconds of idle time → automatically regenerate thumbnail with new path visible
   - OR: User presses Cmd/Ctrl+S to save → thumbnail updates immediately
5. User closes "Homepage" window → Navigator thumbnail remains current
6. User can right-click thumbnail → "Refresh Thumbnail" to force immediate update

**Journey 18: Artboard Window Lifecycle**

1. User closes "Homepage" artboard window by clicking X button
2. App **MUST**:
   - Close window (no prompt if saved)
   - Keep artboard in document (not deleted)
   - Keep Navigator window open
   - Artboard thumbnail remains in Navigator
   - User can reopen artboard by clicking thumbnail again
3. User closes Navigator window → app **MUST**:
   - Show prompt: "Close website-design.wiretuner and all artboard windows?"
   - If confirmed: Close all artboard windows + Navigator, document closed
   - If cancelled: Navigator stays open
4. Navigator is "root" window for each document - closing it closes the document

**Journey 19: History Replay (Future Feature - Foundation Present)**

1. User selects Window → History Panel → app **MUST** show timeline with event markers
2. User drags playhead to event #500 → app **MUST**:
   - Load snapshot preceding event #500
   - Replay events 1–500 from snapshot
   - Render document state at that point in time
   - Target: 5K events/second replay rate
3. User presses Play button → app **MUST** animate through events at 1x speed (50ms per sample)
4. User adjusts speed to 10x → app **MUST** skip intermediate samples while maintaining key operations

---

#### **3.0 Data Models**

##### **3.1 Core Domain Models**

**Document**
- `id` (REQUIRED, UUID v4, unique identifier)
- `metadata` (REQUIRED, DocumentMetadata object)
  - `name` (REQUIRED, String, max 200 chars, default: "Untitled")
  - `author` (REQUIRED, String, default: system username)
  - `createdAt` (REQUIRED, RFC3339 timestamp)
  - `modifiedAt` (REQUIRED, RFC3339 timestamp, auto-update on any change)
  - `anchorVisibilityMode` (REQUIRED, AnchorVisibilityMode enum, default: allVisible)
    - `allVisible` - Show anchor points on all paths
    - `selectedOnly` - Show anchor points only on selected paths
    - `hidden` - No anchor points visible
- `artboards` (REQUIRED, List<Artboard>, min 1 artboard, max 1000 artboards, unlimited practical)
- `fileFormatVersion` (REQUIRED, Semantic Version, current: 2.0.0)

**ARCHITECTURAL CHANGE:** Documents now contain multiple artboards instead of a single artboard. Each artboard has its own layers, objects, viewport state, and selection state. This enables multi-page workflows like Figma or responsive design systems.

**Artboard**
- `id` (REQUIRED, UUID v4, unique artboard identifier)
- `name` (REQUIRED, String, max 100 chars, default: "Artboard 1")
- `bounds` (REQUIRED, Rectangle, artboard dimensions in world coordinates)
  - `x` (REQUIRED, Double, left edge, default: 0)
  - `y` (REQUIRED, Double, top edge, default: 0)
  - `width` (REQUIRED, Double, min 100px, max 100000px, default: 1920px)
  - `height` (REQUIRED, Double, min 100px, max 100000px, default: 1080px)
- `backgroundColor` (REQUIRED, RGBA, default: white #FFFFFF)
- `layers` (REQUIRED, List<Layer>, min 1 layer, max 100 layers per artboard)
- `viewportState` (OPTIONAL, ViewportState, saved zoom/pan position)
  - `zoom` (REQUIRED, Double, 0.01x to 100x, default: 1.0)
  - `panOffset` (REQUIRED, Point, world coordinates offset, default: (0, 0))
- `selectionState` (OPTIONAL, Selection, per-artboard selection)
- `zOrder` (REQUIRED, Integer, determines order in Navigator, 0-based)
- `preset` (OPTIONAL, ArtboardPreset enum: custom | iphone14pro | desktophd | a4portrait | instagramsquare | etc.)
- `thumbnail` (OPTIONAL, ImageData, cached Navigator thumbnail, regenerated on save or every 10s)
- `thumbnailTimestamp` (OPTIONAL, RFC3339 timestamp, when thumbnail was last generated)

**Layer** (Per-Artboard)
- `id` (REQUIRED, UUID v4)
- `artboardId` (REQUIRED, UUID v4, reference to parent artboard)
- `name` (REQUIRED, String, max 100 chars, default: "Layer 1")
- `visible` (REQUIRED, Boolean, default: true)
- `locked` (REQUIRED, Boolean, default: false, prevents editing when true)
- `objects` (REQUIRED, List<VectorObject>, can be empty)
- `zIndex` (REQUIRED, Integer, determines stacking order within artboard, 0-based)

**VectorObject** (Discriminated Union)
- Variant 1: **PathObject**
  - `type: "path"` (discriminator)
  - `path` (REQUIRED, VectorPath)
- Variant 2: **ShapeObject**
  - `type: "shape"` (discriminator)
  - `shape` (REQUIRED, Shape)

**VectorPath**
- `id` (REQUIRED, UUID v4)
- `anchors` (REQUIRED, List<AnchorPoint>, min 2 anchors, max 10,000 anchors)
- `segments` (REQUIRED, List<Segment>, computed from anchors, count = anchors.length - 1 if open, anchors.length if closed)
- `closed` (REQUIRED, Boolean, true if path forms closed loop)
- `transform` (REQUIRED, Transform2D, affine transformation matrix)
- `style` (REQUIRED, PathStyle)

**AnchorPoint**
- `position` (REQUIRED, Point, world coordinates as double precision)
- `handleIn` (OPTIONAL, Point, relative offset for incoming Bézier control point)
- `handleOut` (OPTIONAL, Point, relative offset for outgoing Bézier control point)
- `type` (REQUIRED, AnchorType enum):
  - `smooth`: Both handles present, mirrored and equal length (C1 continuity)
  - `corner`: No handles or independent handles (C0 continuity)
  - `tangent`: Exactly one handle present (transition between straight and curved)

**Segment**
- `start` (REQUIRED, Point, position of starting anchor)
- `end` (REQUIRED, Point, position of ending anchor)
- `control1` (OPTIONAL, Point, first Bézier control point for cubic curve)
- `control2` (OPTIONAL, Point, second Bézier control point for cubic curve)
- `isCubic` (REQUIRED, Boolean, true if cubic Bézier, false if straight line)

**Shape** (Parametric Primitives)
- `id` (REQUIRED, UUID v4)
- `type` (REQUIRED, ShapeType enum: rectangle | ellipse | polygon | star)
- `bounds` (REQUIRED, Rectangle, bounding box)
- `cornerRadius` (OPTIONAL, Double, for rounded rectangles, 0-50% of min dimension)
- `sides` (OPTIONAL, Integer, for polygon/star, min 3, max 100, default: 5)
- `innerRadius` (OPTIONAL, Double, for star, 0.0-1.0 ratio to outer radius, default: 0.5)
- `transform` (REQUIRED, Transform2D)
- `style` (REQUIRED, PathStyle)

**PathStyle**
- `fill` (OPTIONAL, Paint)
  - `color` (REQUIRED, RGBA with 8-bit channels)
  - OR `gradient` (OPTIONAL, Gradient: linear | radial with stops)
- `stroke` (OPTIONAL, Stroke)
  - `color` (REQUIRED, RGBA)
  - `width` (REQUIRED, Double, min 0.1px, max 100px, default: 1.0px)
  - `cap` (REQUIRED, LineCap: butt | round | square, default: round)
  - `join` (REQUIRED, LineJoin: miter | round | bevel, default: round)
  - `dashPattern` (OPTIONAL, List<Double>, dash/gap lengths in px)
- `opacity` (REQUIRED, Double, 0.0-1.0, default: 1.0)

**Transform2D** (Affine Transformation)
- `translation` (REQUIRED, Point, default: (0, 0))
- `rotation` (REQUIRED, Double radians, default: 0)
- `scale` (REQUIRED, Point, default: (1, 1), uniform scaling if x == y)
- Represented as 3x3 matrix for composition

**Selection** (Per-Artboard)
- `objectIds` (REQUIRED, Set<UUID>, selected object IDs)
- `anchorIndices` (OPTIONAL, Map<UUID, Set<Integer>>, object ID → anchor indices)
- `bounds` (OPTIONAL, Rectangle, unified bounding box, computed on-demand)

---

##### **3.2 Event Models (Event Sourcing)**

**EventBase** (Abstract)
- `eventId` (REQUIRED, UUID v4, unique per event)
- `sequence` (REQUIRED, Integer autoincrement, logical ordering within document)
- `timestamp` (REQUIRED, RFC3339 with microsecond precision)
- `userId` (REQUIRED, UUID, for collaboration support, single-user: always same ID)
- `eventType` (REQUIRED, String, discriminator for polymorphic deserialization)
- `eventData` (REQUIRED, JSON payload, varies by event type)

**Event Categories:**

1. **Document Events**
   - `document.created` → Document initialized with default artboard and layer
     - Payload: `documentId`, `defaultArtboardId`, `metadata`
   - `document.metadata_changed` → Name, author, or metadata updated
     - Payload: `oldMetadata`, `newMetadata`

2. **Artboard Events** (NEW)
   - `artboard.created` → New artboard added to document
     - Payload: `artboardId`, `name`, `bounds`, `backgroundColor`, `preset?`, `zOrder`
   - `artboard.deleted` → Artboard removed from document
     - Payload: `artboardId`, `cascadeDeletedObjectCount`, `cascadeDeletedLayerCount`
   - `artboard.renamed` → Artboard name changed
     - Payload: `artboardId`, `oldName`, `newName`
   - `artboard.resized` → Artboard bounds changed
     - Payload: `artboardId`, `oldBounds`, `newBounds`
   - `artboard.reordered` → Artboard position in Navigator changed
     - Payload: `artboardId`, `oldZOrder`, `newZOrder`
   - `artboard.duplicated` → Artboard copied with all layers/objects
     - Payload: `sourceArtboardId`, `newArtboardId`, `newName`, `objectIdMapping` (old→new)
   - `artboard.background_changed` → Background color updated
     - Payload: `artboardId`, `oldColor`, `newColor`
   - `artboard.viewport_changed` → Zoom/pan state saved for artboard
     - Payload: `artboardId`, `oldViewportState`, `newViewportState`
   - `artboard.thumbnail_regenerated` → Navigator thumbnail updated
     - Payload: `artboardId`, `thumbnailData`, `timestamp`

3. **Object Creation Events**
   - `object.path.created` → New path created (pen tool)
     - Payload: `artboardId`, `pathId`, `initialAnchors[]`, `style`
   - `object.shape.created` → New shape created (shape tools)
     - Payload: `artboardId`, `shapeId`, `shapeType`, `bounds`, `parameters`, `style`
   - `object.imported` → Objects imported from external file
     - Payload: `artboardId`, `sourceFile`, `format` (svg|ai|pdf), `objectIds[]`

4. **Path Editing Events**
   - `path.anchor.added` → New anchor point added to path
     - Payload: `pathId`, `anchorIndex`, `position`, `handleIn?`, `handleOut?`, `type`
   - `path.anchor.moved` → Anchor position changed (high-frequency, sampled)
     - Payload: `pathId`, `anchorIndex`, `oldPosition`, `newPosition`, `sampledPath[]` (50ms samples)
   - `path.anchor.deleted` → Anchor removed
     - Payload: `pathId`, `anchorIndex`
   - `path.bcp.adjusted` → Bezier control handle moved (high-frequency, sampled)
     - Payload: `pathId`, `anchorIndex`, `handleType` (in|out), `oldOffset`, `newOffset`, `sampledPath[]`
   - `path.segment.type_changed` → Straight ↔ Curve conversion
     - Payload: `pathId`, `segmentIndex`, `oldType`, `newType`
   - `path.closed` → Path closed into loop
     - Payload: `pathId`

5. **Object Manipulation Events**
   - `object.moved` → Object dragged (high-frequency, sampled)
     - Payload: `artboardId`, `objectIds[]`, `deltaX`, `deltaY`, `sampledPath[]`
   - `object.transformed` → Rotation, scale, or matrix transform
     - Payload: `artboardId`, `objectIds[]`, `oldTransform`, `newTransform`
   - `object.styled` → Fill, stroke, or style changed
     - Payload: `artboardId`, `objectIds[]`, `styleProperty` (fill|stroke|opacity), `oldValue`, `newValue`
   - `object.deleted` → Object removed
     - Payload: `artboardId`, `objectIds[]`
   - `object.duplicated` → Object copied
     - Payload: `artboardId`, `sourceIds[]`, `newIds[]`, `offset` (for paste-in-place)
   - `object.moved_between_artboards` → Object moved from one artboard to another
     - Payload: `sourceArtboardId`, `targetArtboardId`, `objectIds[]`

6. **Selection Events** (Per-Artboard)
   - `selection.changed` → Selection set updated within artboard
     - Payload: `artboardId`, `oldSelection` (objectIds[]), `newSelection` (objectIds[])
   - `selection.cleared` → All deselected in artboard
     - Payload: `artboardId`
   - `anchor.selected` → Anchor points selected (direct selection tool)
     - Payload: `artboardId`, `pathId`, `anchorIndices[]`

7. **Viewport Events** (Per-Artboard)
   - `viewport.panned` → Canvas panned (sampled at 50ms)
     - Payload: `artboardId`, `oldOffset`, `newOffset`, `sampledPath[]`
   - `viewport.zoomed` → Zoom level changed
     - Payload: `artboardId`, `oldZoom`, `newZoom`, `pivotPoint`
   - `viewport.reset` → Zoom to fit artboard
     - Payload: `artboardId`

8. **Operation Boundary Events** (Undo/Redo Grouping)
   - `operation.started` → Begin logical operation group
     - Payload: `operationName` (e.g., "Create Rectangle"), `artboardId?` (optional, if operation is artboard-specific)
   - `operation.ended` → End operation group (triggered by 200ms idle threshold)
     - Payload: `duration`, `eventCount`

9. **File Events**
   - `document.saved` → Document persisted to disk
     - Payload: `filePath`, `snapshotSequence`, `eventCount`
   - `document.loaded` → Document loaded from disk
     - Payload: `filePath`, `fileVersion`, `eventsReplayed`

---

##### **3.3 Snapshot Model**

**Snapshot** (Performance Optimization)
- `id` (REQUIRED, Integer autoincrement)
- `sequence` (REQUIRED, Integer, last event sequence included in snapshot)
- `timestamp` (REQUIRED, RFC3339 timestamp)
- `stateData` (REQUIRED, JSON-serialized Document)
- `compressed` (REQUIRED, Boolean, true if gzip-compressed)
- **Purpose:** Enable fast document loading by replaying events from snapshot instead of beginning
- **Strategy (Easily Configurable):**
  - **Event threshold:** Configurable constant (default: 500 events) - single line of code change
  - **Time threshold:** Configurable constant (default: 10 minutes) - independent of event count
  - **Manual trigger:** On explicit save (Cmd/Ctrl+S)
  - **Background execution:** Snapshots MUST run in background isolate/thread (non-blocking)
  - **UI responsiveness:** User can continue editing during snapshot creation
- **Load Strategy:**
  1. Find most recent snapshot ≤ current sequence
  2. Deserialize snapshot into Document
  3. Replay events (snapshot.sequence + 1) to (current sequence)
  4. Materialize final state

---

#### **4.0 Essential Error Handling**

##### **4.1 File Operations**

**Scenario: Cannot Save Document (Disk Full)**
- User presses Cmd/Ctrl+S → app **MUST** attempt save
- If disk full → app **MUST**:
  - Show error dialog: "Cannot save: Disk full. Free up space and try again."
  - Provide "Retry" and "Save As..." buttons
  - Preserve unsaved document in memory
  - Show unsaved indicator (dot in window title)
- User clicks Retry → app **MUST** re-attempt save
- If still fails → app **MUST** suggest alternative location

**Scenario: Cannot Load Document (Corrupted File)**
- User selects file → app **MUST** validate SQLite database integrity
- If corrupted → app **MUST**:
  - Show error: "Cannot open document: File is corrupted or invalid."
  - Offer "Try Recovery" option (attempt to read partial events)
  - If recovery succeeds → show warning: "Recovered partial document. Some data may be missing."
  - If recovery fails → show "Cannot recover" message, do not open document

**Scenario: Incompatible File Version (Too New)**
- User opens file with version 2.0.0, app supports 1.x → app **MUST**:
  - Show error: "This document was created with a newer version of WireTuner (v2.0.0). Please upgrade to open this file."
  - Provide "Check for Updates" button
  - Do not attempt to open or modify file

**Scenario: Old File Version (Migration Required)**
- User opens v1.0.0 file with v2.0.0 app → app **MUST**:
  - Show dialog: "This document uses an older format and will be migrated."
  - Show progress bar during migration
  - Create backup copy at `original_filename.v1.0.0.backup.wiretuner`
  - Migrate to current version
  - Show success: "Migration complete. Document upgraded to v2.0.0."

##### **4.2 Import/Export Errors**

**Scenario: Invalid SVG File**
- User imports malformed SVG → app **MUST**:
  - Parse XML with validation
  - If parse error → show "Cannot import: Invalid SVG file. Line 42: Unexpected token."
  - Do not create partial import

**Scenario: SVG with Unsupported Features**
- User imports SVG with blend modes → app **MUST**:
  - Parse successfully but ignore unsupported features
  - Show warning dialog: "Import complete with warnings. The following features are not supported: Blend modes (3 instances). These will be ignored."
  - Provide "View Details" button showing list of ignored features with line numbers

**Scenario: PDF Export Fails**
- User exports to PDF, PDF library throws error → app **MUST**:
  - Show error: "Cannot export PDF: [technical error message]"
  - Provide "Retry" and "Report Bug" buttons
  - Do not leave partial/corrupted PDF file

##### **4.3 Drawing Tool Errors**

**Scenario: Too Many Anchor Points (Performance Limit)**
- User creates path with 10,000 anchors and attempts to add more → app **MUST**:
  - Show warning: "Path has reached maximum anchor count (10,000). No more points can be added."
  - Ignore additional clicks
  - Allow user to close path or cancel

**Scenario: Invalid Shape Parameters**
- User creates polygon with 0 sides via API → app **MUST**:
  - Validate parameters: sides ≥ 3
  - Throw error: "Invalid shape parameters: sides must be ≥ 3"
  - Do not create shape

##### **4.4 Event Sourcing Errors**

**Scenario: Event Store Database Locked**
- Multiple windows attempt to write events simultaneously → app **MUST**:
  - Use SQLite transactions with exclusive locks
  - Retry up to 3 times with exponential backoff (10ms, 50ms, 200ms)
  - If all retries fail → show error: "Cannot save changes: Database is locked. Close other documents and try again."

**Scenario: Event Replay Inconsistency**
- Event replay produces different state than snapshot → app **MUST**:
  - Log error with event IDs and state diff
  - Show warning: "History replay detected inconsistency. Document may not match original state."
  - Use snapshot state as source of truth
  - Report bug to telemetry service (if enabled)

##### **4.5 System Resource Errors**

**Scenario: Out of Memory (Very Large Document)**
- Document with 100K objects causes memory pressure → app **SHOULD**:
  - Implement object streaming (load only visible objects)
  - Show warning: "Document is very large and may run slowly."
  - Suggest: "Consider splitting into multiple documents."

**Scenario: GPU Rendering Failure**
- CustomPainter throws exception → app **MUST**:
  - Catch exception, log to console
  - Fall back to CPU rendering
  - Show warning: "GPU rendering failed. Performance may be reduced."

---

### **Part 2: Advanced Specifications (For Complex Projects)**

---

#### **5.0 Formal Project Controls & Scope**

**5.1 Document Control**

- **Version:** 2.0 (Post-Implementation Refinement)
- **Status:** Approved & Active
- **Date:** 2025-11-10
- **Previous Version:** 1.0 (2025-11-06) - Original architectural decisions
- **Change Summary:** Added clarifications from actual implementation, identified ambiguities, specified error handling

**5.2 Detailed Scope**

**In Scope (v0.1 Milestone):**

✅ **Drawing Tools:**
- Pen tool with anchor point creation, straight segments, Bézier curves, control handle dragging
- Selection tool with click selection, marquee selection, multi-selection (Shift modifier)
- Direct selection tool with anchor dragging, BCP handle dragging, snapping (Shift toggle)
- Rectangle tool, Ellipse tool, Polygon tool, Star tool

✅ **Event Sourcing System:**
- **Critical events:** Always recorded (clicks, drags start/end, anchor creation, object manipulation)
- **Mouse movement sampling:** Configurable rate (default: 200ms) for replay visualization only
- **Philosophy:** Start/end positions are essential, intermediate samples are optional "nice-to-have"
- Event persistence to SQLite database (events table)
- Snapshot creation every 500 events for performance optimization
- Event replay engine for document reconstruction (infers motion from start/end if no intermediate samples)

✅ **Rendering Pipeline:**
- CustomPainter-based canvas rendering
- Path rendering with Bézier tessellation
- Viewport transforms (pan/zoom) with screen-to-world coordinate conversion
- Anchor point visualization overlay with type-specific colors
- Selection overlay with bounding boxes
- Performance metrics overlay (FPS monitor)

✅ **File Operations:**
- Save document to .wiretuner format (SQLite)
- Load document with version detection
- File format versioning infrastructure (v1.0.0)
- Migration framework for forward compatibility

✅ **Import/Export:**
- SVG import (Tier 1 & Tier 2 features: paths, shapes, gradients, clipPath)
- SVG export with standard compliance
- PDF export (operator parsing implemented)

✅ **Undo/Redo:**
- Operation-based undo/redo with 200ms idle threshold
- Configurable undo stack depth (default: 100 operations, max: unlimited)
- Easily adjustable in code (single constant)
- Redo stack cleared on new operation after undo

✅ **Multi-Selection:**
- Shift+click to add/remove from selection
- Marquee selection (drag bounding box)
- Unified bounding box for multiple selected objects

**Additional Features IN SCOPE for MVP (Unlimited Resources):**

✅ **Collaboration Infrastructure & Networking:**
- UUID-based event IDs (not sequential integers)
- RFC3339 timestamps with microsecond precision
- userId field in all events
- **Real-time multiplayer editing via API** (see Section 7.9 for architecture)
- Conflict resolution (Operational Transform or CRDT)
- User cursors with name labels
- WebSocket/GraphQL/gRPC API (recommendation in Section 7.9)

✅ **Multi-Document Architecture:**
- MDI (Multiple Document Interface) support with separate windows
- Isolated event stores per document
- Complete window lifecycle management
- Multi-artboard support with Navigator (fully implemented in v3.0)

✅ **History Replay UI:**
- Timeline scrubber widget
- Play/pause/rewind controls
- Event thumbnails with preview
- Speed control (1x, 2x, 5x, 10x, custom)
- Event replay engine foundation already exists
- Replay visualization with smooth interpolation

✅ **Advanced Typography:**
- Editable text tool with system font rendering
- Text on path support
- Font family, size, weight, style controls
- Text-to-path conversion for export compatibility
- Rich text editing (bold, italic, underline, alignment)

✅ **Layer Management UI:**
- Layer panel with list view
- Drag-to-reorder layers
- Layer visibility toggles
- Layer rename, duplicate, delete, merge
- Per-artboard layer management
- Layer locking and opacity controls

✅ **Advanced Vector Operations:**
- Boolean operations (union, intersect, subtract, exclude)
- Path simplification and optimization
- Envelope distortion
- Compound paths and clipping masks

**Out of Scope (Not Planned for v1.0):**

❌ **Plugins/Extensions:**
- Plugin API
- Third-party tool integration
- Scripting language
- *Deferred to v2.0+ based on user demand*

**5.3 Glossary of Terms & Acronyms**

| Term | Definition |
|------|------------|
| **Anchor Point** | Control point defining a path vertex with optional Bézier handles |
| **BCP** | Bezier Control Point - handle extending from anchor for curve control |
| **MDI** | Multiple Document Interface - separate windows per document |
| **Event Sourcing** | Architectural pattern storing state changes as immutable event log |
| **Snapshot** | Point-in-time serialized document state for fast loading |
| **Tier 1/2 Import** | Feature support levels: Tier 1 (basic), Tier 2 (extended) |
| **Sampling** | Recording high-frequency events at fixed intervals (50ms) |
| **Operation Boundary** | 200ms idle threshold grouping events into single undo action |
| **Viewport Transform** | Affine transformation mapping world coordinates to screen pixels |
| **Overlay** | Rendering layer above document content (selection, tools, UI) |
| **Hit Testing** | Determining which object/anchor is clicked based on cursor position |
| **Immutability** | Data structure cannot be modified after creation (copy-on-write) |
| **Freezed** | Dart code generation library for immutable data classes |
| **Provider** | Flutter state management pattern (dependency injection) |
| **RGBA** | Red-Green-Blue-Alpha color representation (8-bit channels) |
| **RFC3339** | Timestamp format: `2025-11-10T14:30:00.123456Z` |
| **UUID v4** | Universally Unique Identifier (random, 128-bit) |
| **SQLite** | Embedded relational database (file-based) |
| **Semantic Versioning** | Version format `MAJOR.MINOR.PATCH` (e.g., 1.0.0) |

---

#### **6.0 Granular & Traceable Requirements**

##### **6.1 Functional Requirements**

| ID | Requirement Name / User Story | Description | Priority | Acceptance Criteria |
|:---|:---|:---|:---|:---|
| **FR-001** | Pen Tool - Create Anchor Points | The system **MUST** allow users to create anchor points by clicking on the canvas with the Pen Tool. | Critical | ✅ Click creates anchor at cursor position<br>✅ Subsequent clicks add anchors to current path<br>✅ First click starts new path<br>✅ `CreatePathEvent` and `path.anchor.added` events recorded |
| **FR-002** | Pen Tool - Bézier Curves | The system **MUST** allow users to create Bézier curves by clicking and dragging with the Pen Tool. | Critical | ✅ Click+drag creates anchor with control handles<br>✅ Handles extend in drag direction<br>✅ Live preview during drag<br>✅ Smooth anchor type assigned by default |
| **FR-003** | Pen Tool - Close Path | The system **MUST** close the path when the user clicks the starting anchor point. | Critical | ✅ Clicking within 8px of first anchor closes path<br>✅ `path.closed` event recorded<br>✅ Path marked as closed=true |
| **FR-004** | Direct Selection - Anchor Dragging | The system **MUST** allow users to drag anchor points with the Direct Selection Tool. | Critical | ✅ Click anchor to select<br>✅ Drag moves anchor in real-time<br>✅ Position sampled every 50ms<br>✅ `ModifyAnchorEvent` recorded with sampled path<br>✅ Connected segments update automatically |
| **FR-005** | Direct Selection - BCP Handle Dragging | The system **MUST** allow users to drag Bézier control handles to adjust curves. | Critical | ✅ Handles visible when anchor selected<br>✅ Drag handle updates curve in real-time<br>✅ Smooth anchors mirror opposite handle<br>✅ Corner anchors adjust handles independently<br>✅ `path.bcp.adjusted` event recorded |
| **FR-006** | Selection Tool - Marquee Selection | The system **MUST** allow users to select multiple objects by dragging a marquee box with full-enclosed or touch-selection modes. | Critical | ✅ Click+drag creates selection box (dashed outline)<br>✅ **Default mode:** All fully-enclosed objects selected on release<br>✅ **Alt/Option modifier:** All objects touched by marquee selected (not just enclosed)<br>✅ Visual feedback during drag shows which objects will be selected<br>✅ `selection.changed` event recorded with artboardId |
| **FR-007** | Selection Tool - Multi-Selection with Shift | The system **MUST** allow users to add/remove objects from selection by Shift+clicking. | High | ✅ Shift+click unselected object adds to selection<br>✅ Shift+click selected object removes from selection<br>✅ Unified bounding box shown for multi-selection |
| **FR-008** | Shape Tools - Rectangle Creation | The system **MUST** allow users to create rectangles by clicking and dragging. | Critical | ✅ Click+drag defines opposite corners<br>✅ Live preview during drag<br>✅ `object.shape.created` event recorded<br>✅ Shape has default style (black stroke, no fill) |
| **FR-009** | Shape Tools - Ellipse Creation | The system **MUST** allow users to create ellipses by clicking and dragging. | Critical | ✅ Click+drag defines bounding box<br>✅ Live preview during drag<br>✅ Perfect circles if Shift held |
| **FR-010** | Shape Tools - Polygon Creation | The system **MUST** allow users to create regular polygons with configurable side count. | High | ✅ Side count adjustable (3-100, default: 5)<br>✅ Click+drag defines size<br>✅ Rotation adjustable during drag |
| **FR-011** | Shape Tools - Star Creation | The system **MUST** allow users to create star shapes with configurable points and inner radius. | High | ✅ Point count adjustable (3-100, default: 5)<br>✅ Inner radius ratio adjustable (0.0-1.0, default: 0.5)<br>✅ Click+drag defines outer radius |
| **FR-012** | Viewport - Pan | The system **MUST** allow users to pan the canvas by dragging with spacebar held. | Critical | ✅ Spacebar+drag pans viewport<br>✅ Cursor changes to hand icon<br>✅ `viewport.panned` event recorded (start + end critical, intermediate samples optional) |
| **FR-013** | Viewport - Zoom | The system **MUST** allow users to zoom with pinch gesture or scroll. | Critical | ✅ Scroll wheel zooms at cursor position<br>✅ Pinch gesture on trackpad zooms<br>✅ Zoom range: 0.01x to 100x<br>✅ `viewport.zoomed` event recorded |
| **FR-014** | Save Document & Auto-Save | The system **MUST** auto-save after every operation and stamp save events when user explicitly saves. | Critical | ✅ **Auto-save:** Persist to SQLite after every operation (200ms idle threshold)<br>✅ **Manual save (Cmd/Ctrl+S):** Records `document.saved` event with timestamp<br>✅ **Save deduplication:** Multiple saves without changes record only ONE save event<br>✅ **Save indicator:** Visual feedback shows "Saved" status<br>✅ Snapshot created at manual save time<br>✅ All events and snapshots persisted to .wiretuner file<br>✅ Load time target: <100ms for 10K events<br>⚠️ Auto-save is continuous, manual save is for user checkpoints/versioning |
| **FR-015** | Load Document | The system **MUST** load documents by replaying events from the most recent snapshot. | Critical | ✅ Cmd/Ctrl+O triggers open dialog<br>✅ File version validated<br>✅ Snapshot loaded first<br>✅ Events replayed from snapshot.sequence+1<br>✅ Document reconstructed accurately<br>✅ `document.loaded` event recorded |
| **FR-016** | File Version Migration | The system **MUST** migrate older file format versions to the current version. | High | ✅ Version detection on load<br>✅ Migration scripts executed automatically<br>✅ Backup of original file created<br>✅ Success message shown<br>✅ Newer versions rejected with upgrade prompt |
| **FR-017** | SVG Import - Tier 1 Features | The system **MUST** import SVG paths, shapes, fills, and strokes. | Critical | ✅ Parses SVG `<path>` elements<br>✅ Converts to VectorPath with anchors<br>✅ Imports `<rect>`, `<circle>`, `<ellipse>`, `<polygon>`<br>✅ Preserves fill and stroke colors<br>✅ Imports stroke widths |
| **FR-018** | SVG Import - Tier 2 Features | The system **SHOULD** import SVG gradients, clipPaths, and text-as-paths. | High | ✅ Linear and radial gradients imported<br>✅ ClipPath support<br>✅ Text converted to placeholder geometry<br>⚠️ Transforms may be ignored (logged as warning) |
| **FR-019** | SVG Export | The system **MUST** export documents to standards-compliant SVG files. | Critical | ✅ Paths exported as `<path>` with `d` attribute<br>✅ Shapes exported as native SVG elements<br>✅ ViewBox set to artboard bounds<br>✅ File opens identically in Illustrator |
| **FR-020** | PDF Export via SVG | The system **MUST** export documents to PDF format by converting SVG to PDF using an open-source library. | High | ✅ SVG generated with high fidelity<br>✅ SVG passed to conversion library (librsvg/resvg/similar)<br>✅ PDF contains vector graphics (not rasterized)<br>✅ File opens in Adobe Acrobat with correct rendering<br>✅ Error handling if conversion fails |
| **FR-021** | Adobe AI Import (PDF-Compatible Only) | The system **MUST** import PDF-compatible Adobe Illustrator (.ai) files (AI 9.0+, created ~2000+) with Tier 1 feature support. Legacy PostScript AI is out of scope. | High | ✅ PDF-compatible AI files (AI 9.0+) parsed<br>✅ Vector paths extracted from PDF structure<br>✅ Basic shapes, fills, strokes imported<br>⚠️ AI-specific metadata may be ignored<br>❌ Legacy PostScript AI explicitly unsupported (show error) |
| **FR-022** | Undo Operation | The system **MUST** support undo via Cmd/Ctrl+Z with configurable stack depth. | Critical | ✅ Keyboard shortcut triggers undo<br>✅ Canvas reverts to state before last operation<br>✅ Operation boundary = 200ms idle threshold<br>✅ Status bar shows "Undo: [operation name]"<br>✅ Undo stack depth configurable (default: 100, max: unlimited)<br>✅ Single constant adjustment in UndoManager<br>✅ SQLite provides durable storage (indexing supports performance) |
| **FR-023** | Redo Operation | The system **MUST** support redo via Cmd/Ctrl+Shift+Z. | Critical | ✅ Keyboard shortcut triggers redo<br>✅ Canvas advances to next operation state<br>✅ Redo stack cleared on new operation after undo |
| **FR-024** | Anchor Point Visibility Modes | The system **MUST** provide 3 anchor point visibility modes with toggle icon in window frame. | Critical | ✅ **Mode 1 (Default): All Visible** - anchors on all paths<br>✅ **Mode 2: Selected Only** - anchors on selected paths only<br>✅ **Mode 3: Hidden** - no anchors visible<br>✅ Icon in window frame (toolbar/status bar) cycles through modes<br>✅ Keyboard shortcut: Cmd/Ctrl+Shift+A cycles modes<br>✅ Smooth anchors: red circles (5px), Corner: black squares (7x7px), Tangent: orange triangles (7px)<br>✅ Size scale-independent<br>✅ Mode persisted per-document and globally<br>✅ Toast notification on mode change<br>✅ Unused overlay painters unregistered for performance |
| **FR-025** | Event Sampling Strategy | The system **MUST** record critical events always, with configurable mouse movement sampling for replay visualization. | Critical | ✅ **Critical events always recorded:** Click down, click up, drag start, drag end with positions<br>✅ **Mouse movement sampling:** Configurable rate (default: 200ms), easily adjustable in code<br>✅ **Sampling range:** 0ms (every frame) to 500ms+ (sparse), user-configurable in settings<br>✅ **Philosophy:** Start/end positions essential for reconstruction, intermediate samples are "nice-to-have" for smooth replay<br>✅ **Replay inference:** If no intermediate samples, replay infers linear/curved motion from start→end<br>✅ Sampled positions stored in `sampledPath[]` array<br>✅ Events flushed on pointer up |
| **FR-026** | Snapshot Creation | The system **MUST** create snapshots at configurable intervals (default: 500 events, 10 minutes) using background execution. | Critical | ✅ Snapshot created at configurable event threshold (single constant, default: 500)<br>✅ Snapshot created at configurable time threshold (single constant, default: 10 min)<br>✅ Manual snapshot on save (Cmd/Ctrl+S)<br>✅ Background execution via isolate/thread (non-blocking)<br>✅ UI remains responsive during snapshot creation<br>✅ Snapshot contains full document state<br>✅ Snapshot sequence number stored<br>✅ Compressed with gzip if >1MB |
| **FR-027** | Event Replay | The system **MUST** reconstruct document state by replaying events from a snapshot. | Critical | ✅ Finds most recent snapshot ≤ target sequence<br>✅ Deserializes snapshot<br>✅ Replays events sequentially<br>✅ Produces identical document state<br>✅ Target: 5K events/second replay rate |
| **FR-028** | Grid Snapping | The system **SHOULD** enable grid snapping when Shift is held during dragging. | Medium | ✅ Shift key toggles snapping<br>✅ **Grid size: 10px in screen space** (not world space - maintains consistent visual snap regardless of zoom)<br>✅ Anchor positions rounded to nearest grid point in screen coordinates<br>✅ Converted back to world coordinates for storage |
| **FR-029** | Artboard Navigator - Open on Load | The system **MUST** automatically open the Artboard Navigator when a document with multiple artboards is loaded. | Critical | ✅ Navigator opens automatically<br>✅ Shows thumbnail grid of all artboards<br>✅ Displays artboard names and dimensions |
| **FR-030** | Artboard Navigator - Multi-Document Tabs | The system **MUST** support multiple open documents in the Navigator with tab switching. | Critical | ✅ Shows tabs for each open document<br>✅ Tab click switches thumbnail view<br>✅ Active document tab highlighted<br>✅ Tab close prompts to close all artboards |
| **FR-031** | Create New Artboard | The system **MUST** allow users to create new artboards with preset sizes or custom dimensions. | Critical | ✅ "+" button in Navigator opens dialog<br>✅ Preset dropdown (iPhone 14 Pro, Desktop HD, A4, Instagram, Custom)<br>✅ Width/Height fields editable<br>✅ `artboard.created` event recorded<br>✅ New artboard window opens automatically |
| **FR-032** | Artboard Window Titles | The system **MUST** display artboard name and document name in window titles. | High | ✅ Format: "Artboard Name - document.wiretuner"<br>✅ Updates when artboard renamed |
| **FR-033** | Per-Artboard Viewport Persistence | The system **MUST** save and restore viewport state (zoom/pan) independently for each artboard. | Critical | ✅ Viewport state saved in artboard model<br>✅ Restored when artboard window reopened<br>✅ Persisted to disk on save<br>✅ `artboard.viewport_changed` event recorded |
| **FR-034** | Per-Artboard Selection Isolation | The system **MUST** maintain independent selection state for each artboard. | Critical | ✅ Selection isolated per artboard<br>✅ Switching windows preserves each artboard's selection<br>✅ `selection.changed` events include artboardId |
| **FR-035** | Rename Artboard | The system **MUST** allow users to rename artboards via context menu or inline editing. | High | ✅ Right-click → "Rename Artboard"<br>✅ Inline text field over thumbnail<br>✅ Enter commits, Escape cancels<br>✅ `artboard.renamed` event recorded<br>✅ Window title updates if artboard open |
| **FR-036** | Reorder Artboards | The system **MUST** allow users to drag artboards to reorder them in the Navigator. | Medium | ✅ Drag thumbnail to new position<br>✅ Drop indicator shown between thumbnails<br>✅ `artboard.reordered` event recorded<br>✅ zOrder values updated |
| **FR-037** | Duplicate Artboard | The system **MUST** allow users to duplicate artboards with all layers and objects. | High | ✅ Right-click → "Duplicate Artboard"<br>✅ Creates copy with all layers/objects<br>✅ Name appended with " Copy"<br>✅ `artboard.duplicated` event with object ID mapping |
| **FR-038** | Delete Artboard with Safety | The system **MUST** prevent deletion of the last artboard and show confirmation for others. | Critical | ✅ Confirmation dialog shows object/layer count<br>✅ "Cancel" and "Delete" buttons<br>✅ Last artboard deletion blocked with error<br>✅ `artboard.deleted` event with cascade metadata<br>✅ Closes artboard window if open |
| **FR-039** | Artboard Navigator Thumbnails | The system **MUST** generate and update thumbnails for artboards in the Navigator. | Critical | ✅ Thumbnail generated on artboard creation<br>✅ Auto-updates every 10 seconds of idle time<br>✅ Immediate update on save (Cmd/Ctrl+S)<br>✅ Right-click → "Refresh Thumbnail" for manual update<br>✅ `artboard.thumbnail_regenerated` event recorded |
| **FR-040** | Artboard Window Lifecycle | The system **MUST** manage artboard window opening/closing without deleting artboards. | Critical | ✅ Closing artboard window keeps artboard in document<br>✅ Closing Navigator prompts "Close all artboards?"<br>✅ Navigator is root window (closing it closes document)<br>✅ Artboards can be reopened by clicking thumbnails |
| **FR-041** | Export Single Artboard | The system **SHOULD** allow exporting individual artboards to SVG/PDF via context menu. | Medium | ✅ Right-click → "Export Artboard..."<br>✅ Shows file save dialog with artboard name as default<br>✅ Exports only selected artboard content |
| **FR-042** | Artboard Background Color | The system **MUST** allow users to set custom background colors for each artboard. | Medium | ✅ Artboard properties panel or right-click → "Background Color..."<br>✅ Color picker dialog<br>✅ `artboard.background_changed` event recorded |
| **FR-043** | Artboard Preset Templates | The system **MUST** provide standard artboard size presets matching common design targets. | High | ✅ iPhone 14 Pro: 393x852px<br>✅ Desktop HD: 1920x1080px<br>✅ A4 Portrait: 595x842pt (PDF points)<br>✅ Instagram Square: 1080x1080px<br>✅ Custom: user-defined dimensions |
| **FR-044** | Move Objects Between Artboards | The system **SHOULD** allow cut/paste or drag-and-drop to move objects between artboards. | Medium | ✅ Cut (Cmd/Ctrl+X) from one artboard, paste (Cmd/Ctrl+V) in another<br>✅ `object.moved_between_artboards` event recorded<br>✅ Object removed from source artboard layers<br>✅ Object added to target artboard layers |
| **FR-045** | Per-Artboard Layers | The system **MUST** maintain independent layer stacks for each artboard. | Critical | ✅ Each artboard has min 1 layer, max 100 layers<br>✅ Layer model includes artboardId reference<br>✅ Layers not shared across artboards<br>✅ Layer panel shows layers for currently active artboard |
| **FR-046** | Sampling Rate Configuration | The system **MUST** provide easy configuration of mouse movement sampling rate in code and user settings. | High | ✅ **Code configuration:** Single constant (e.g., `SAMPLING_INTERVAL_MS = 200`) in event sampler class<br>✅ **User settings:** Advanced preferences panel with slider (0-500ms)<br>✅ **Default: 200ms** (balances file size and replay smoothness)<br>✅ **Presets:** "High fidelity (100ms)", "Balanced (200ms)", "Minimal (500ms)", "Sparse (1000ms)"<br>✅ **Live preview:** Settings panel shows estimated events/hour and storage impact<br>✅ **Note:** Critical events (click down/up, drag start/end) always recorded regardless of sampling rate |
| **FR-047** | macOS Platform Integration | The system **SHOULD** integrate with macOS-specific features (excluding Touch Bar). | Medium | ✅ **QuickLook support** - .wiretuner files show artboard thumbnail preview in Finder<br>✅ **Native file dialogs** - use macOS open/save panels<br>✅ **Menu bar integration** - standard macOS menu structure<br>✅ **Spotlight indexing** - document metadata searchable via Spotlight<br>❌ **Touch Bar** - explicitly NOT supported<br>⚠️ **Handoff/Continuity** - out of scope for v1.0 |
| **FR-048** | Windows Platform Integration | The system **SHOULD** integrate with Windows-specific features. | Medium | ✅ **File Explorer thumbnails** - .wiretuner files show preview in Explorer<br>✅ **File associations** - double-click .wiretuner opens WireTuner<br>✅ **Jump Lists** - recent documents in taskbar right-click menu<br>✅ **Windows Search** - document metadata searchable<br>✅ **Native file dialogs** - use Windows open/save dialogs<br>⚠️ **Windows Ink** - out of scope for v1.0 (mouse/trackpad only) |
| **FR-049** | Hybrid File Format Strategy | The system **MUST** use SQLite for active editing (.wiretuner) and support JSON export for archival and interoperability. | Critical | ✅ **Active editing:** .wiretuner files use SQLite database (snapshots + events)<br>✅ **Export:** File → Export → JSON exports full document as human-readable JSON<br>✅ **Archive:** JSON format includes full state (artboards, layers, objects, metadata)<br>✅ **Import:** File → Import → JSON can load exported JSON back into SQLite<br>✅ **Version control friendly:** JSON export enables git diff/merge workflows<br>✅ **Interoperability:** JSON format documented for third-party tools<br>⚠️ **Note:** JSON export does NOT include event history (snapshot only) |
| **FR-050** | Arrow Key Nudging with Intelligent Zoom | The system **MUST** support arrow key nudging with automatic zoom-in when precision is needed. | High | ✅ **Arrow keys nudge selected objects/anchors** in 1px increments (screen space)<br>✅ **Shift + Arrow:** 10px increments (screen space)<br>✅ **Intelligent zoom behavior:** If user continues nudging past target (overshooting), system suggests zoom-in via toast notification: "Press Cmd/Ctrl + = to zoom in for finer control"<br>✅ **Alternative:** Hold Z key to temporarily zoom to cursor for precision positioning<br>✅ **Nudge distance in world space:** Varies by zoom level (1px screen = smaller world distance when zoomed in)<br>✅ **Visual feedback:** Object/anchor moves in real-time with each key press<br>✅ Events recorded: `object.moved` or `path.anchor.moved` |

##### **6.2 Non-Functional Requirements (NFRs)**

| ID | Category | Requirement | Metric / Acceptance Criteria |
|:---|:---|:---|:---|
| **NFR-PERF-001** | Performance | Document Load Time | 95% of documents with ≤10K events **MUST** load in <100ms.<br>*Measured: Snapshot load + event replay + UI render* |
| **NFR-PERF-002** | Performance | Event Replay Rate | Event replay engine **MUST** process ≥5,000 events/second.<br>*Measured: Time to replay 5K events from snapshot* |
| **NFR-PERF-003** | Performance | Canvas Frame Rate | Canvas rendering **MUST** maintain ≥60 FPS during pan/zoom operations on documents with ≤1,000 objects.<br>*Measured: Performance overlay FPS counter* |
| **NFR-PERF-004** | Performance | Cursor Update Latency | Tool cursor updates **MUST** complete in <0.2ms.<br>*Measured: CursorService.setCursor() duration* |
| **NFR-PERF-005** | Performance | Event Sampling Overhead | Mouse movement sampling **MUST** add <2% overhead to interaction time at default 200ms rate.<br>*Measured: Sampling timer overhead / total interaction time. Note: Critical events (click/drag start/end) are instantaneous with no sampling delay.* |
| **NFR-PERF-006** | Performance | Snapshot Background Execution | Snapshot creation **MUST** run in background isolate/thread with zero UI blocking.<br>*Measured: Main thread remains responsive during snapshot creation. Frame time <16ms (60fps) maintained during background snapshot. Total snapshot creation <500ms for documents with ≤10K objects.* |
| **NFR-PERF-007** | Performance | Tool Activation Time | Switching tools **MUST** complete in <50ms.<br>*Measured: ToolManager.setActiveTool() duration* |
| **NFR-PERF-008** | Performance | Artboard Navigator Rendering | Navigator thumbnail grid with 100 artboards **MUST** render in <200ms.<br>*Measured: Time to paint all thumbnails* |
| **NFR-PERF-009** | Performance | Artboard Window Switch Time | Switching focus between artboard windows **MUST** complete in <16ms (1 frame at 60fps).<br>*Measured: Time from window activation to canvas render* |
| **NFR-PERF-010** | Performance | Thumbnail Generation | Artboard thumbnail generation **MUST** complete in <100ms for artboards with ≤1,000 objects.<br>*Measured: Time to render artboard to thumbnail image* |
| **NFR-ACC-001** | Accuracy | Path Rendering Precision | Rendered paths **MUST** match anchor positions within 0.1px at 100% zoom.<br>*Measured: Pixel diff between expected and actual render* |
| **NFR-ACC-002** | Accuracy | Bezier Curve Accuracy | Bezier curves **MUST** be tessellated with ≤0.5px deviation from true cubic curve.<br>*Measured: Hausdorff distance between tessellated and analytical curve* |
| **NFR-ACC-003** | Accuracy | SVG Import/Export Fidelity | SVG export → import round-trip **MUST** preserve path coordinates within 0.01px.<br>*Measured: Max coordinate difference before/after round-trip* |
| **NFR-ACC-004** | Accuracy | Event Replay Determinism | Event replay **MUST** produce bit-identical document state for same event sequence.<br>*Measured: SHA256 hash of serialized document before/after replay* |
| **NFR-REL-001** | Reliability | Event Store Durability | Event writes **MUST** be durable (fsync) before confirming success.<br>*Measured: No data loss in hard shutdown simulation* |
| **NFR-REL-002** | Reliability | Crash Recovery | Application **MUST** recover unsaved work from event log after unexpected shutdown.<br>*Measured: Events written before crash are loadable after restart* |
| **NFR-REL-003** | Reliability | File Corruption Detection | Application **MUST** detect corrupted SQLite databases and refuse to open.<br>*Measured: SQLite PRAGMA integrity_check passes* |
| **NFR-REL-004** | Reliability | Migration Safety | File format migration **MUST** create backup before modifying original file.<br>*Measured: Backup file exists with correct content* |
| **NFR-SEC-001** | Security | File Path Validation | Application **MUST** validate all file paths to prevent directory traversal attacks.<br>*Measured: Reject paths containing `..` or absolute paths outside allowed directories* |
| **NFR-USAB-001** | Usability | Undo/Redo Discoverability | Undo/redo commands **MUST** display operation name in status bar.<br>*Measured: "Undo: Move Rectangle" message visible after undo* |
| **NFR-USAB-002** | Usability | Error Message Clarity | Error dialogs **MUST** include actionable instructions (e.g., "Free up disk space and retry").<br>*Measured: User study shows 80% understand corrective action* |
| **NFR-USAB-003** | Usability | Tool Cursor Feedback | Active tool cursor **MUST** visually indicate tool type (crosshair for pen, arrow for selection).<br>*Measured: Cursor changes within 1 frame of tool activation* |
| **NFR-SCALE-001** | Scalability | Max Objects per Document | Documents with ≤10,000 objects **MUST** remain responsive (<100ms interaction latency).<br>*Measured: Time from click to visual feedback* |
| **NFR-SCALE-002** | Scalability | Max Anchors per Path | Paths with ≤10,000 anchors **MUST** render without frame drops.<br>*Measured: FPS ≥60 when path is visible* |
| **NFR-SCALE-003** | Scalability | Max Events per Document | Documents with ≤100,000 events **MUST** load in <1 second.<br>*Measured: Time from file open to canvas render* |
| **NFR-SCALE-004** | Scalability | Max Artboards per Document | Documents with ≤1,000 artboards **MUST** remain responsive in Navigator.<br>*Measured: Thumbnail grid scrolling at ≥30 FPS* |
| **NFR-SCALE-005** | Scalability | Concurrent Open Artboards | Application **MUST** support ≥20 simultaneously open artboard windows without performance degradation.<br>*Measured: All artboards maintain ≥60 FPS rendering* |
| **NFR-MAINT-001** | Maintainability | Code Test Coverage | Core domain models and event sourcing logic **MUST** have ≥80% test coverage.<br>*Measured: `flutter test --coverage` report* |
| **NFR-MAINT-002** | Maintainability | Immutable Data Models | All domain models **MUST** be immutable (Freezed-generated).<br>*Measured: No mutable fields in domain/ directory* |
| **NFR-MAINT-003** | Maintainability | Clean Architecture Layers | Dependencies **MUST** flow inward (presentation → application → infrastructure → domain).<br>*Measured: No imports from inner layers to outer layers* |
| **NFR-PORT-001** | Portability | Platform Parity | All drawing tools **MUST** behave identically on macOS and Windows.<br>*Measured: Cross-platform test suite passes on both platforms* |
| **NFR-PORT-002** | Portability | File Interoperability | .wiretuner files **MUST** be byte-identical across platforms (no endianness issues).<br>*Measured: File created on macOS loads correctly on Windows* |
| **NFR-EXT-001** | Extensibility | Tool Plugin Architecture | Tool interface **MUST** allow third-party tools to be registered via ToolRegistry.<br>*Measured: External tool package can be integrated without modifying core code* |
| **NFR-EXT-002** | Extensibility | Event Type Extensibility | New event types **MUST** be addable without modifying EventBase class.<br>*Measured: Event schema registry supports dynamic registration* |
| **NFR-INTER-001** | Interoperability | SVG Standards Compliance | Exported SVG **MUST** validate against W3C SVG 1.1 schema.<br>*Measured: Pass W3C SVG validator* |
| **NFR-INTER-002** | Interoperability | Illustrator Compatibility | Exported SVG **MUST** open in Adobe Illustrator without errors or warnings.<br>*Measured: Manual verification in Illustrator CS6+ versions* |

---

#### **7.0 Technical & Architectural Constraints**

**7.1 Technology Stack**

- **Frontend Framework:** Flutter 3.x (desktop support)
- **Programming Language:** Dart 3.x
- **Database:** SQLite 3.x (via `sqflite` package)
- **State Management:** Provider pattern with ChangeNotifier
- **Immutability:** Freezed code generation for data classes
- **JSON Serialization:** json_serializable with Freezed integration
- **Testing:** flutter_test (unit), integration_test (E2E)
- **Target Platforms:** macOS 10.15+ (Catalina), Windows 10+
- **SVG Parsing/Generation:** `xml` package for SVG import/export
- **PDF Generation:** SVG-to-PDF conversion via one of:
  - **Option A (Recommended):** `flutter_svg` + `pdf` package (pure Dart, cross-platform)
  - **Option B:** Native bridge to `librsvg` + Cairo (higher fidelity, platform-specific)
  - **Option C:** `resvg` via FFI (Rust library, excellent quality, moderate complexity)

**7.2 Architectural Principles**

**Clean Architecture (Layered Onion Model):**
```
Domain (Core) - Pure business logic, no dependencies
    ↑ interfaces
Application - Services, tools, use cases
    ↑ implements
Infrastructure - I/O, persistence, external APIs
    ↑ depends on
Presentation - UI, widgets, rendering
```

**Key Constraints:**
1. **Immutability:** All domain models **MUST** be immutable (use Freezed `@freezed` annotation)
2. **Event Sourcing:** All state changes **MUST** be recorded as events (no direct state mutation)
3. **Statelessness:** Tools **MUST NOT** store document state (read from DocumentProvider)
4. **Single Responsibility:** Each tool handles one interaction mode only
5. **Testability:** Business logic **MUST** be testable without Flutter framework

**7.3 Deployment Environment**

- **Distribution:** Standalone desktop application (not web-based)
- **Packaging:** macOS DMG installer, Windows MSI installer
- **Auto-Updates:** Not implemented in v0.1 (planned for v1.0)
- **Licensing:** Open-source (license TBD)

**7.4 Development Constraints**

- **Single Developer:** All estimates assume one full-time developer
- **No Native Code:** Pure Flutter implementation (no platform channels except file dialogs)
- **Offline-First:** No network requirements for core functionality
- **Local Files Only:** No cloud storage integration in v0.1

**7.5 Performance Constraints**

- **Memory Limit:** Application **MUST** run on systems with 4GB RAM
- **Startup Time:** Application **MUST** launch in <2 seconds on macOS/Windows
- **File Size:** Event database files **SHOULD** compress to <10MB for typical documents (1000 objects, 10K events)

**7.6 Event Sampling Configuration (Easy Adjustability)**

**Code-level configuration** - Single constant in `EventSampler` class:

```dart
// lib/infrastructure/event_sourcing/event_sampler.dart
class EventSampler {
  // EASILY CONFIGURABLE: Adjust sampling rate here
  static const SAMPLING_INTERVAL_MS = 200; // Default: 200ms

  // Alternative configurations:
  // static const SAMPLING_INTERVAL_MS = 100;  // High fidelity
  // static const SAMPLING_INTERVAL_MS = 500;  // Sparse sampling
  // static const SAMPLING_INTERVAL_MS = 1000; // Minimal sampling

  DateTime? _lastSampleTime;

  bool shouldSample() {
    final now = DateTime.now();
    if (_lastSampleTime == null ||
        now.difference(_lastSampleTime!) >=
        Duration(milliseconds: SAMPLING_INTERVAL_MS)) {
      _lastSampleTime = now;
      return true;
    }
    return false;
  }
}
```

**User-configurable settings** - Advanced preferences panel:

```dart
// User Settings UI
Slider(
  value: samplingIntervalMs.toDouble(),
  min: 0,      // Every frame (60fps)
  max: 1000,   // Very sparse
  divisions: 20,
  label: '${samplingIntervalMs}ms',
  onChanged: (value) {
    setState(() => samplingIntervalMs = value.toInt());
    // Show estimate: "~X events/hour, ~Y MB/hour"
  },
)

// Preset buttons
["High (100ms)", "Balanced (200ms)", "Sparse (500ms)", "Minimal (1000ms)"]
```

**Philosophy:**
- **Critical events (click down/up, drag start/end):** ALWAYS recorded immediately, no sampling
- **Mouse movements during drag:** Sampled at configured rate for replay smoothness
- **Replay strategy:** If no intermediate samples exist, infer linear motion from start→end

**Storage Impact Examples (1 hour of active editing):**
- 100ms sampling: ~36,000 samples/hour → ~1.8 MB
- 200ms sampling: ~18,000 samples/hour → ~900 KB (default)
- 500ms sampling: ~7,200 samples/hour → ~360 KB
- 1000ms sampling: ~3,600 samples/hour → ~180 KB

**7.7 Snapshot Strategy Configuration (Easy Adjustability & Background Execution)**

**Code-level configuration** - Single constants in `SnapshotManager` class:

```dart
// lib/infrastructure/event_sourcing/snapshot_manager.dart
class SnapshotManager {
  // EASILY CONFIGURABLE: Adjust snapshot triggers here
  static const SNAPSHOT_EVENT_THRESHOLD = 500;        // Default: 500 events
  static const SNAPSHOT_TIME_THRESHOLD_MINUTES = 10;  // Default: 10 minutes

  // Alternative configurations:
  // static const SNAPSHOT_EVENT_THRESHOLD = 100;   // Frequent snapshots
  // static const SNAPSHOT_EVENT_THRESHOLD = 1000;  // Sparse snapshots
  // static const SNAPSHOT_EVENT_THRESHOLD = null;  // Disable event-based (time-only)

  int _eventsSinceLastSnapshot = 0;
  DateTime _lastSnapshotTime = DateTime.now();

  Future<void> checkAndCreateSnapshot(Document document) async {
    _eventsSinceLastSnapshot++;
    final timeSinceSnapshot = DateTime.now().difference(_lastSnapshotTime);

    final eventThresholdMet = SNAPSHOT_EVENT_THRESHOLD != null &&
                               _eventsSinceLastSnapshot >= SNAPSHOT_EVENT_THRESHOLD;
    final timeThresholdMet = timeSinceSnapshot >=
                             Duration(minutes: SNAPSHOT_TIME_THRESHOLD_MINUTES);

    if (eventThresholdMet || timeThresholdMet) {
      await createSnapshotInBackground(document);
    }
  }

  // BACKGROUND EXECUTION: Non-blocking snapshot creation
  Future<void> createSnapshotInBackground(Document document) async {
    // Run snapshot creation in background isolate to prevent UI blocking
    final snapshot = await compute(_createSnapshotWorker, document);

    // Store snapshot to database (this is fast, just a DB write)
    await _repository.saveSnapshot(snapshot);

    _eventsSinceLastSnapshot = 0;
    _lastSnapshotTime = DateTime.now();
  }

  // Worker function runs in separate isolate
  static Snapshot _createSnapshotWorker(Document document) {
    // Serialize document state
    final json = document.toJson();
    final compressed = gzip.encode(utf8.encode(jsonEncode(json)));

    return Snapshot(
      sequence: document.currentSequence,
      data: compressed,
      timestamp: DateTime.now(),
    );
  }

  // Manual snapshot trigger (on save)
  Future<void> createSnapshotOnSave(Document document) async {
    await createSnapshotInBackground(document);
    // Reset counters after manual save
    _eventsSinceLastSnapshot = 0;
    _lastSnapshotTime = DateTime.now();
  }
}
```

**Philosophy:**
- **Event threshold:** Snapshots every N events (default: 500, configurable)
- **Time threshold:** Snapshots every M minutes (default: 10, configurable)
- **Manual trigger:** On save (Cmd/Ctrl+S) always creates snapshot
- **Background execution:** Uses Flutter's `compute()` to run in isolate (non-blocking)
- **UI responsiveness:** User can continue editing during snapshot creation
- **Independent triggers:** Either threshold can trigger snapshot (OR logic)

**Background Execution Benefits:**
- Document serialization runs in separate isolate (no UI freeze)
- GZIP compression runs in background (CPU-intensive)
- Main thread remains responsive for user interactions
- Database write is fast (typically <10ms), done on main thread after compression

**Storage Impact Examples:**
- 500 events/snapshot, 100KB/snapshot: 10 snapshots in 5,000 events → ~1 MB
- Time-based: 10-minute snapshots in 1-hour session → 6 snapshots → ~600 KB
- Manual saves: Additional snapshots on user save (Cmd/Ctrl+S)

**7.8 Undo Stack Depth Configuration (Easily Adjustable)**

**Code-level configuration** - Single constant in `UndoManager` class:

```dart
// lib/application/undo/undo_manager.dart
class UndoManager {
  // EASILY CONFIGURABLE: Adjust undo stack depth here
  static const MAX_UNDO_DEPTH = 100;  // Default: 100 operations

  // Alternative configurations:
  // static const MAX_UNDO_DEPTH = 50;    // Conservative (lower memory)
  // static const MAX_UNDO_DEPTH = 500;   // Deep history
  // static const MAX_UNDO_DEPTH = null;  // Unlimited (user manages file size)

  final List<DocumentOperation> _undoStack = [];
  final List<DocumentOperation> _redoStack = [];

  void recordOperation(DocumentOperation operation) {
    _undoStack.add(operation);

    // Enforce depth limit if configured
    if (MAX_UNDO_DEPTH != null && _undoStack.length > MAX_UNDO_DEPTH) {
      _undoStack.removeAt(0);  // Remove oldest operation
    }

    // Clear redo stack when new operation is recorded
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    final operation = _undoStack.removeLast();
    operation.invert();  // Apply inverse
    _redoStack.add(operation);
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final operation = _redoStack.removeLast();
    operation.apply();  // Reapply operation
    _undoStack.add(operation);
  }
}
```

**Philosophy:**
- **Default: 100 operations** - Balances usability with reasonable memory usage
- **Maximum: Unlimited** - Set `MAX_UNDO_DEPTH = null` for unlimited history
- **Storage: SQLite-backed** - Event log provides durable storage with proper indexing
- **Performance: Excellent** - SQLite handles large event counts efficiently with indexing
- **User control: File size** - Users manage file size growth, not artificially limited

**Why Unlimited is Safe:**
- SQLite storage is durable and indexed (fast lookups even with millions of events)
- Users can see file size and manage it themselves
- Event sourcing already stores full history for replay
- Undo/redo just replays events forward/backward (no additional storage overhead)

**Memory Impact Examples:**
- 100 operations: ~50-100 KB in memory (cached operations)
- 500 operations: ~250-500 KB in memory
- Unlimited: Lazy loading from SQLite (only recent operations in memory)

**7.9 Multiplayer API Architecture Recommendation**

**Recommendation: WebSockets + GraphQL Hybrid**

For real-time collaborative editing with event sourcing architecture, we recommend a **hybrid approach**:

**Primary: WebSockets for Event Streaming**
- **Use case:** Real-time event broadcasting (user edits, cursor movements, selections)
- **Why:** Bidirectional, persistent connection with minimal latency (<50ms)
- **Protocol:** WebSocket over WSS (TLS encrypted)
- **Event format:** JSON-serialized Event objects (already defined in event sourcing model)

**Secondary: GraphQL for Queries & Mutations**
- **Use case:** Document loading, snapshots, user management, authentication
- **Why:** Flexible schema, efficient queries, strong typing with code generation
- **Protocol:** HTTPS (RESTful fallback)
- **Operations:**
  - `query { document(id: ID!) { ... } }` - Load document with snapshot + recent events
  - `mutation { createDocument(...) }` - Create new document
  - `subscription { documentEvents(id: ID!) }` - GraphQL subscriptions (alternative to WebSockets)

**Why NOT gRPC (for this use case):**
- ❌ HTTP/2 overhead for small, frequent messages (event streaming)
- ❌ Protobuf adds serialization complexity vs. existing JSON event model
- ❌ Limited browser support (requires grpc-web proxy)
- ❌ Overkill for text-based event payloads
- ✅ **Alternative:** Consider gRPC for server-to-server sync if multiple backend services emerge

**Architecture Diagram:**

```
┌─────────────────┐         WebSocket (WSS)        ┌─────────────────┐
│  Flutter Client │◄──────────────────────────────►│  API Server     │
│  (Desktop App)  │                                 │  (Node.js/Dart) │
│                 │         GraphQL (HTTPS)         │                 │
│                 │◄──────────────────────────────►│                 │
└─────────────────┘                                 └─────────────────┘
                                                            │
                                                            ▼
                                                    ┌─────────────────┐
                                                    │  PostgreSQL DB  │
                                                    │  (Event Store)  │
                                                    └─────────────────┘
```

**Event Flow (Real-Time Collaboration):**

1. **User A edits path:**
   - Flutter app creates Event object (already in event sourcing model)
   - Event sent via WebSocket to API server
   - Server validates event, assigns server-side timestamp
   - Server broadcasts event to all connected clients on that document
   - Server persists event to PostgreSQL

2. **User B receives event:**
   - WebSocket message received
   - Event deserialized from JSON
   - Event applied to local document state (event replay engine)
   - UI updated with User A's change
   - User B sees User A's cursor/selection (if presence tracking enabled)

3. **Conflict Resolution:**
   - **Strategy: Operational Transform (OT)** or **CRDT**
   - **Recommendation: OT** for path editing (deterministic, well-understood)
   - Server maintains authoritative event sequence
   - Clients apply transformations to concurrent events
   - Event sourcing model already assigns UUIDs (not sequence numbers) for distributed IDs

**WebSocket Message Format:**

```json
{
  "type": "event.broadcast",
  "documentId": "uuid-v4",
  "event": {
    "id": "uuid-v4",
    "sequence": 12345,
    "userId": "user-uuid",
    "timestamp": "2025-11-10T14:30:00.123Z",
    "type": "path.anchor.moved",
    "data": {
      "pathId": "path-uuid",
      "anchorIndex": 2,
      "newPosition": {"x": 150.5, "y": 200.3}
    }
  }
}
```

**GraphQL Schema Example:**

```graphql
type Document {
  id: ID!
  name: String!
  artboards: [Artboard!]!
  currentSnapshot: Snapshot
  recentEvents(limit: Int = 100): [Event!]!
  collaborators: [User!]!
}

type Event {
  id: ID!
  sequence: Int!
  userId: ID!
  timestamp: DateTime!
  type: EventType!
  data: JSON!
}

type Mutation {
  createDocument(name: String!): Document!
  inviteCollaborator(documentId: ID!, userId: ID!): Boolean!
}

type Subscription {
  # Alternative to WebSockets (uses WebSockets under the hood)
  documentEvents(documentId: ID!): Event!
}
```

**Technology Stack Recommendation:**

**Backend:**
- **Runtime:** Node.js (TypeScript) or Dart (Dart Frog framework)
  - **Recommendation: Dart Frog** - Share event models between client & server
- **WebSocket Library:** `ws` (Node.js) or `shelf_web_socket` (Dart)
- **GraphQL Server:** `graphql_flutter` server bindings or `apollo-server` (Node.js)
- **Database:** PostgreSQL with TimescaleDB extension (optimized for event sourcing time-series)
- **ORM:** Prisma (Node.js) or Drift (Dart)

**Why Dart Frog for Backend:**
- ✅ Share Freezed data models between Flutter app and server
- ✅ Type-safe event serialization (no schema drift)
- ✅ Single language across stack (Dart expertise)
- ✅ Built-in WebSocket support
- ✅ Fast development iteration

**Scalability Considerations:**

- **WebSocket Scaling:** Use Redis Pub/Sub for horizontal scaling
  - Multiple API servers subscribe to document channels
  - Events published to Redis, distributed to all connected clients
- **GraphQL Caching:** Use DataLoader pattern to batch queries
- **Event Store Sharding:** Partition by `documentId` for large deployments

**Security:**

- **Authentication:** JWT tokens passed in WebSocket handshake + GraphQL headers
- **Authorization:** Per-document access control (owner, editor, viewer roles)
- **Rate Limiting:** Limit events per second per user (prevent spam/DoS)
- **Validation:** Server validates all events before broadcast (prevent malicious edits)

**Migration Path:**

1. **Phase 1:** Add WebSocket event broadcasting (read-only collaboration - see others edit)
2. **Phase 2:** Add Operational Transform for conflict resolution (full multiplayer editing)
3. **Phase 3:** Add presence tracking (cursors, selections, user names)
4. **Phase 4:** Add GraphQL subscriptions as fallback for restrictive firewalls

**Estimated Effort (with unlimited resources):**
- WebSocket event streaming: ~1-2 weeks
- GraphQL API: ~1 week
- Operational Transform: ~2-3 weeks
- Presence tracking: ~1 week
- Security & auth: ~1 week
- **Total: ~6-8 weeks** for full multiplayer feature

**7.10 Hybrid File Format Strategy**

**Philosophy: Right Tool for the Right Job**

The system uses **two complementary file formats** optimized for different use cases:

**1. SQLite for Active Editing (.wiretuner files)**

**Why SQLite:**
- ✅ **Event sourcing optimized** - Efficient storage and retrieval of event streams
- ✅ **Performance** - Indexed queries for fast snapshot + event replay
- ✅ **Durability** - ACID transactions prevent data loss on crashes
- ✅ **Scalability** - Handles millions of events without performance degradation
- ✅ **Single file** - No multi-file coordination issues
- ✅ **Cross-platform** - Binary format works identically on macOS/Windows

**Schema (Simplified):**
```sql
CREATE TABLE snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sequence INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  state_data BLOB NOT NULL,  -- JSON or compressed JSON
  compressed BOOLEAN NOT NULL
);

CREATE TABLE events (
  event_id TEXT PRIMARY KEY,      -- UUID
  sequence INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_data TEXT NOT NULL        -- JSON payload
);

CREATE INDEX idx_events_sequence ON events(sequence);
CREATE INDEX idx_snapshots_sequence ON snapshots(sequence DESC);
```

**2. JSON for Export and Archive (.json files)**

**Why JSON:**
- ✅ **Human-readable** - Can inspect/edit in text editor
- ✅ **Version control friendly** - Git diff/merge workflows
- ✅ **Interoperability** - Easy integration with third-party tools/scripts
- ✅ **Language-agnostic** - Parse in any language (Python, JavaScript, Rust, etc.)
- ✅ **Documentation-friendly** - Self-describing format
- ✅ **Archival** - Long-term storage without proprietary binary dependencies

**Export Format (Document Snapshot Only):**
```json
{
  "fileFormatVersion": "2.0.0",
  "exportedAt": "2025-11-10T14:30:00.123Z",
  "exportedBy": "WireTuner v1.0.0",
  "document": {
    "id": "uuid-v4",
    "metadata": {
      "name": "Website Design",
      "author": "User Name",
      "createdAt": "2025-11-09T10:00:00.000Z",
      "modifiedAt": "2025-11-10T14:30:00.000Z",
      "anchorVisibilityMode": "allVisible"
    },
    "artboards": [
      {
        "id": "artboard-uuid-1",
        "name": "Homepage Desktop",
        "bounds": {"x": 0, "y": 0, "width": 1920, "height": 1080},
        "backgroundColor": "#FFFFFF",
        "layers": [
          {
            "id": "layer-uuid-1",
            "artboardId": "artboard-uuid-1",
            "name": "Layer 1",
            "visible": true,
            "locked": false,
            "zIndex": 0,
            "objects": [
              {
                "type": "path",
                "path": {
                  "id": "path-uuid-1",
                  "anchors": [
                    {
                      "position": {"x": 100.5, "y": 200.3},
                      "handleIn": null,
                      "handleOut": {"x": 50, "y": 0},
                      "type": "smooth"
                    }
                    // ... more anchors
                  ],
                  "closed": true,
                  "transform": {
                    "translation": {"x": 0, "y": 0},
                    "rotation": 0,
                    "scale": {"x": 1, "y": 1}
                  },
                  "style": {
                    "fill": {"color": "#FF5733FF"},
                    "stroke": {
                      "color": "#000000FF",
                      "width": 2.0,
                      "cap": "round",
                      "join": "round"
                    },
                    "opacity": 1.0
                  }
                }
              }
              // ... more objects
            ]
          }
          // ... more layers
        ],
        "viewportState": {
          "zoom": 1.0,
          "panOffset": {"x": 0, "y": 0}
        },
        "zOrder": 0,
        "preset": "custom"
      }
      // ... more artboards
    ]
  }
}
```

**Important Notes:**
- ⚠️ **JSON export does NOT include event history** - Only current document snapshot
- ⚠️ **No undo/redo across JSON export/import** - New document starts fresh event log
- ✅ **Lossless for visual content** - All objects, layers, artboards preserved exactly
- ✅ **Round-trip compatible** - Import JSON → Edit → Export JSON produces identical structure

**Use Cases:**

| Use Case | Format | Reason |
|----------|--------|--------|
| **Daily editing** | .wiretuner (SQLite) | Full undo/redo, event history, snapshots |
| **Version control** | .json (JSON) | Git diff shows meaningful changes |
| **Team sharing** | .wiretuner OR .json | SQLite for active collab, JSON for review |
| **Long-term archival** | .json (JSON) | No binary dependencies, human-readable |
| **Scripting/automation** | .json (JSON) | Easy to parse/generate programmatically |
| **Data recovery** | .wiretuner (SQLite) | Event log enables time-travel debugging |

**File Menu Structure:**

```
File
  ├── New                        (Cmd/Ctrl+N)
  ├── Open...                    (Cmd/Ctrl+O) - Opens .wiretuner OR .json
  ├── Save                       (Cmd/Ctrl+S) - Saves to .wiretuner
  ├── Save As...                 (Cmd/Ctrl+Shift+S) - Save .wiretuner with new name
  ├── Export ▶
  │   ├── JSON (.json)           - Export current snapshot to JSON
  │   ├── SVG (.svg)             - Export artboard(s) to SVG
  │   └── PDF (.pdf)             - Export artboard(s) to PDF (via SVG)
  └── Import ▶
      ├── JSON (.json)           - Load JSON as new document (creates .wiretuner)
      ├── SVG (.svg)             - Import vector graphics
      └── AI (.ai)               - Import Adobe Illustrator file
```

**Implementation:**

```dart
// Export JSON
Future<void> exportJSON(Document document, String filePath) async {
  final json = {
    'fileFormatVersion': document.fileFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'exportedBy': 'WireTuner v${AppVersion.current}',
    'document': document.toJson(),
  };

  final prettyJson = JsonEncoder.withIndent('  ').convert(json);
  await File(filePath).writeAsString(prettyJson);
}

// Import JSON
Future<Document> importJSON(String filePath) async {
  final jsonString = await File(filePath).readAsString();
  final parsed = jsonDecode(jsonString);

  // Validate version compatibility
  final version = Version.parse(parsed['fileFormatVersion']);
  if (version.major > 2) {
    throw UnsupportedFileVersionException();
  }

  // Deserialize document (without events)
  final document = Document.fromJson(parsed['document']);

  // Create new .wiretuner file with initial snapshot
  // (no event history from JSON import)
  return document;
}
```

**File Size Comparison (Example):**

For a document with 1,000 objects and 10,000 events:
- **SQLite (.wiretuner):** ~2-5 MB (snapshot + full event history)
- **JSON (.json):** ~500 KB - 1 MB (snapshot only, pretty-printed)
- **JSON (minified):** ~300-600 KB (no whitespace)

**Benefits of Hybrid Approach:**
1. ✅ **Best performance** - SQLite optimized for event sourcing workloads
2. ✅ **Version control** - JSON enables meaningful git diffs
3. ✅ **Interoperability** - JSON for scripts, SQLite for editing
4. ✅ **Durability** - SQLite transactions prevent data loss
5. ✅ **Future-proof** - JSON archival outlives any application

**7.11 Grid Snapping & Arrow Key Nudging (Screen Space Consistency)**

**Philosophy: Consistent Visual Behavior Across Zoom Levels**

Both grid snapping and arrow key nudging operate in **screen space** (pixels on the user's display), not world space (document coordinates). This ensures predictable, consistent behavior regardless of zoom level.

**Grid Snapping (Screen Space)**

```dart
// lib/application/tools/grid_snapping.dart
class GridSnapper {
  static const GRID_SIZE_SCREEN_PX = 10; // 10px in screen space

  Point snapToGrid(Point worldPosition, ViewportTransform viewport, bool shiftHeld) {
    if (!shiftHeld) return worldPosition; // No snapping

    // 1. Convert world coordinates to screen coordinates
    final screenPos = viewport.worldToScreen(worldPosition);

    // 2. Snap to nearest 10px grid in screen space
    final snappedScreen = Point(
      (screenPos.x / GRID_SIZE_SCREEN_PX).round() * GRID_SIZE_SCREEN_PX,
      (screenPos.y / GRID_SIZE_SCREEN_PX).round() * GRID_SIZE_SCREEN_PX,
    );

    // 3. Convert back to world coordinates for storage
    return viewport.screenToWorld(snappedScreen);
  }
}
```

**Why Screen Space for Grid Snapping:**
- ✅ **Visual consistency** - Grid always appears 10px apart on screen, regardless of zoom
- ✅ **Predictable behavior** - User sees exactly what they get
- ✅ **Zoom independence** - At 100% zoom, 10px screen = 10px world. At 200% zoom, 10px screen = 5px world.

**Arrow Key Nudging (Screen Space)**

```dart
// lib/application/tools/keyboard_nudge.dart
class KeyboardNudge {
  static const NUDGE_DISTANCE_PX = 1;       // Normal: 1px in screen space
  static const NUDGE_DISTANCE_LARGE_PX = 10; // Shift: 10px in screen space

  int _consecutiveOvershoots = 0;
  Point? _lastNudgePosition;

  void handleArrowKey(ArrowKey key, bool shiftHeld, Selection selection, ViewportTransform viewport) {
    // Determine nudge distance in screen space
    final nudgeDistanceScreen = shiftHeld ? NUDGE_DISTANCE_LARGE_PX : NUDGE_DISTANCE_PX;

    // Calculate delta in screen space
    final deltaScreen = switch (key) {
      ArrowKey.left  => Point(-nudgeDistanceScreen, 0),
      ArrowKey.right => Point(nudgeDistanceScreen, 0),
      ArrowKey.up    => Point(0, -nudgeDistanceScreen),
      ArrowKey.down  => Point(0, nudgeDistanceScreen),
    };

    // Convert screen space delta to world space delta
    final deltaWorld = viewport.screenDeltaToWorldDelta(deltaScreen);

    // Move selected objects/anchors
    for (final objectId in selection.objectIds) {
      final object = document.getObject(objectId);
      object.position += deltaWorld;
    }

    // Intelligent zoom suggestion
    _detectOvershoot(selection.bounds.center, deltaWorld);
  }

  void _detectOvershoot(Point currentPosition, Point delta) {
    // Check if user is oscillating (moving back and forth)
    if (_lastNudgePosition != null) {
      final movement = currentPosition - _lastNudgePosition!;
      final isReversing = (movement.x * delta.x < 0) || (movement.y * delta.y < 0);

      if (isReversing) {
        _consecutiveOvershoots++;

        if (_consecutiveOvershoots >= 3) {
          // User is overshooting - suggest zoom
          ToastService.show(
            "Press Cmd/Ctrl + = to zoom in for finer control",
            duration: Duration(seconds: 3),
            icon: Icons.zoom_in,
          );
          _consecutiveOvershoots = 0; // Reset after showing suggestion
        }
      } else {
        _consecutiveOvershoots = 0; // Reset on consistent direction
      }
    }

    _lastNudgePosition = currentPosition;
  }
}
```

**Screen Space Delta Conversion:**

```dart
// In ViewportTransform class
Point screenDeltaToWorldDelta(Point screenDelta) {
  // At 100% zoom: 1px screen = 1px world
  // At 200% zoom: 1px screen = 0.5px world
  // At 50% zoom: 1px screen = 2px world
  return Point(
    screenDelta.x / zoom,
    screenDelta.y / zoom,
  );
}
```

**User Experience Examples:**

| Zoom Level | Arrow Key Press | Screen Movement | World Movement | Grid Snap (Screen) | Grid Snap (World) |
|------------|-----------------|-----------------|----------------|-------------------|-------------------|
| 100% (1:1) | → (normal) | 1px right | 1px right | 10px screen | 10px world |
| 200% (2x) | → (normal) | 1px right | 0.5px right | 10px screen | 5px world |
| 50% (0.5x) | → (normal) | 1px right | 2px right | 10px screen | 20px world |
| 100% | Shift + → | 10px right | 10px right | 10px screen | 10px world |
| 400% (4x) | → (normal) | 1px right | 0.25px right | 10px screen | 2.5px world |

**Intelligent Zoom Workflow:**

1. **Initial positioning:** User drags object roughly into position
2. **Arrow key refinement:** User presses → → → to nudge right
3. **Overshoot detection:** User presses ← (reversing direction)
4. **Repeated overshoot:** User presses → ← → ← (oscillating)
5. **System suggestion:** Toast appears: "Press Cmd/Ctrl + = to zoom in for finer control"
6. **User zooms in:** Presses Cmd/Ctrl + =, zoom increases to 200%
7. **Finer control:** Now each → key press moves 0.5px in world space instead of 1px
8. **Precise positioning:** User can position exactly where desired

**Alternative: Temporary Zoom (Z key hold):**

```dart
// Hold Z to temporarily zoom to cursor for precision
bool _zKeyHeld = false;
double _zoomBeforeTemporary;
Point _cursorPositionWhenZPressed;

void onKeyDown(KeyEvent event) {
  if (event.key == LogicalKeyboardKey.keyZ && !_zKeyHeld) {
    _zKeyHeld = true;
    _zoomBeforeTemporary = viewport.zoom;
    _cursorPositionWhenZPressed = viewport.cursorPosition;

    // Zoom in 2x, centered on cursor
    viewport.zoomTo(
      _zoomBeforeTemporary * 2,
      pivotPoint: _cursorPositionWhenZPressed,
    );
  }
}

void onKeyUp(KeyEvent event) {
  if (event.key == LogicalKeyboardKey.keyZ && _zKeyHeld) {
    _zKeyHeld = false;

    // Restore original zoom
    viewport.zoomTo(
      _zoomBeforeTemporary,
      pivotPoint: _cursorPositionWhenZPressed,
    );
  }
}
```

**Benefits:**
1. ✅ **Consistent visual behavior** - Grid and nudge distances always look the same on screen
2. ✅ **Precision at any zoom** - Zoom in for finer world-space adjustments
3. ✅ **No mental math** - User doesn't calculate "1px at 200% zoom = 0.5px world"
4. ✅ **Intelligent assistance** - System detects struggle and offers helpful zoom suggestion
5. ✅ **Professional workflow** - Matches Illustrator/Figma behavior

**7.12 Auto-Save & Manual Save Strategy**

**Philosophy: Continuous Auto-Save + User Checkpoint Markers**

The system uses **continuous auto-save** for data safety while allowing users to **mark explicit save points** for versioning and workflow milestones.

**Auto-Save (Continuous)**

```dart
// lib/infrastructure/persistence/auto_save_manager.dart
class AutoSaveManager {
  static const AUTO_SAVE_IDLE_THRESHOLD_MS = 200; // 200ms after last operation

  Timer? _autoSaveTimer;
  int _lastSavedSequence = 0;
  bool _hasUnsavedChanges = false;

  void onEventRecorded(Event event) {
    _hasUnsavedChanges = true;

    // Cancel previous auto-save timer
    _autoSaveTimer?.cancel();

    // Start new auto-save timer (debounced)
    _autoSaveTimer = Timer(
      Duration(milliseconds: AUTO_SAVE_IDLE_THRESHOLD_MS),
      () => _performAutoSave(),
    );
  }

  Future<void> _performAutoSave() async {
    if (!_hasUnsavedChanges) return;

    // Persist all events to SQLite (incremental)
    final newEvents = _eventStore.getEventsSince(_lastSavedSequence);
    await _database.insertEvents(newEvents);

    _lastSavedSequence = _eventStore.currentSequence;
    _hasUnsavedChanges = false;

    // Update UI indicator
    _statusBar.showStatus("Auto-saved", duration: Duration(seconds: 1));

    // NOTE: Do NOT record document.saved event for auto-save
    // Only manual saves (Cmd/Ctrl+S) create save events
  }
}
```

**Manual Save (User Checkpoint)**

```dart
// lib/application/document/save_document_use_case.dart
class SaveDocumentUseCase {
  int? _lastManualSaveSequence;

  Future<void> saveDocument() async {
    final currentSequence = _eventStore.currentSequence;

    // Check if anything changed since last manual save
    if (_lastManualSaveSequence == currentSequence) {
      // No changes - don't record duplicate save event
      _statusBar.showStatus("No changes to save");
      return;
    }

    // 1. Force auto-save to ensure all events persisted
    await _autoSaveManager.performAutoSave();

    // 2. Create snapshot (background execution)
    await _snapshotManager.createSnapshotOnSave(document);

    // 3. Record document.saved event (user checkpoint marker)
    final saveEvent = Event(
      eventId: uuid.v4(),
      sequence: currentSequence + 1,
      timestamp: DateTime.now(),
      userId: _currentUser.id,
      eventType: 'document.saved',
      eventData: {
        'filePath': document.filePath,
        'snapshotSequence': currentSequence,
        'eventCount': currentSequence,
        'savedAt': DateTime.now().toIso8601String(),
      },
    );

    await _eventStore.recordEvent(saveEvent);
    await _database.insertEvent(saveEvent);

    _lastManualSaveSequence = saveEvent.sequence;

    // 4. Update UI
    _statusBar.showStatus("Saved", duration: Duration(seconds: 2));
    _windowTitle.removeDirtyIndicator(); // Remove "*" from title
  }
}
```

**Save Deduplication Logic:**

```dart
// Scenario 1: User presses Cmd/Ctrl+S multiple times without editing
//
// State: currentSequence = 1000, lastManualSaveSequence = 1000
// User: Presses Cmd/Ctrl+S
// Result: "No changes to save" message, NO new event recorded
//
// User: Presses Cmd/Ctrl+S again
// Result: "No changes to save" message, NO new event recorded

// Scenario 2: User edits, then saves multiple times
//
// State: currentSequence = 1000, lastManualSaveSequence = 1000
// User: Edits path (creates events 1001-1005)
// State: currentSequence = 1005, lastManualSaveSequence = 1000
//
// User: Presses Cmd/Ctrl+S
// Result: Creates event 1006 (document.saved), lastManualSaveSequence = 1006
//
// User: Presses Cmd/Ctrl+S again (no edits)
// Result: "No changes to save", NO new event (deduplication)
//
// User: Edits again (creates event 1007)
// State: currentSequence = 1007, lastManualSaveSequence = 1006
//
// User: Presses Cmd/Ctrl+S
// Result: Creates event 1008 (document.saved), lastManualSaveSequence = 1008
```

**UI Indicators:**

```dart
// Window title dirty indicator
// Unsaved changes: "* Homepage - website.wiretuner"
// Saved state: "Homepage - website.wiretuner"

// Status bar messages
// Auto-save: "Auto-saved" (1 second, subtle)
// Manual save: "Saved" (2 seconds, prominent)
// No changes: "No changes to save" (2 seconds)
```

**Benefits of Auto-Save:**
1. ✅ **Data safety** - Never lose work due to crashes
2. ✅ **No "lost work" anxiety** - Events continuously persisted
3. ✅ **Crash recovery** - Load document and resume from last auto-saved event
4. ✅ **Seamless collaboration** - Auto-saved events immediately available for sync
5. ✅ **Low overhead** - Only writes new events incrementally (not full document)

**Benefits of Manual Save Events:**
1. ✅ **Version markers** - User can identify "checkpoints" in event history
2. ✅ **Replay milestones** - Replay to specific save points for debugging
3. ✅ **Collaboration signals** - "John saved at 2:30 PM" visible in event log
4. ✅ **Workflow integration** - Export workflow can trigger on manual save
5. ✅ **User intent tracking** - Know when user considered work "done"

**Event Log Example:**

```
Sequence | Timestamp            | Event Type           | User ID  | Notes
---------|----------------------|---------------------|----------|------------------
1000     | 2025-11-10 14:00:00 | path.created         | alice    |
1001     | 2025-11-10 14:00:05 | path.anchor.added    | alice    |
1002     | 2025-11-10 14:00:10 | path.anchor.moved    | alice    |
1003     | 2025-11-10 14:00:15 | document.saved       | alice    | Manual save (Cmd/Ctrl+S)
1004     | 2025-11-10 14:01:00 | object.moved         | alice    |
1005     | 2025-11-10 14:01:05 | object.styled        | alice    |
1006     | 2025-11-10 14:01:20 | document.saved       | alice    | Manual save (Cmd/Ctrl+S)
[User presses Cmd/Ctrl+S again - NO event created (deduplication)]
1007     | 2025-11-10 14:02:00 | path.closed          | alice    |
1008     | 2025-11-10 14:02:30 | document.saved       | alice    | Manual save (Cmd/Ctrl+S)
```

**Error Recovery Workflow:**

1. **App crashes at sequence 1005**
   - Auto-save has already persisted events 1000-1005 to SQLite
   - User reopens app
   - Document loads from snapshot + events 1000-1005
   - **Zero data loss** - user continues from exactly where they left off

2. **User wants to "rollback" to last manual save**
   - Finds last `document.saved` event in history (e.g., sequence 1003)
   - Replays events from last snapshot to sequence 1003
   - Document state restored to that save point
   - Can use this for "Save As..." historical version export

**Auto-Save vs. Manual Save Summary:**

| Feature | Auto-Save | Manual Save (Cmd/Ctrl+S) |
|---------|-----------|--------------------------|
| **Trigger** | 200ms after last operation | User presses Cmd/Ctrl+S |
| **Frequency** | Continuous (every edit) | On-demand |
| **Event recorded?** | NO | YES (`document.saved`) |
| **Snapshot created?** | NO (only at manual save) | YES (background) |
| **UI feedback** | "Auto-saved" (subtle, 1s) | "Saved" (prominent, 2s) |
| **Deduplication?** | N/A | YES (same sequence = skip) |
| **Purpose** | Data safety | User checkpoint marker |

---

#### **8.0 Assumptions, Dependencies & Risks**

**8.1 Assumptions**

1. **User Hardware:** Users have desktop computers with:
   - 4GB RAM minimum
   - Dual-core CPU 2GHz+
   - 1920×1080 display or higher
   - Mouse or trackpad (touch input not supported)

2. **File System Access:** Users have read/write permissions to local file system for document storage.

3. **Operating System:** Users run maintained OS versions (macOS 10.15+, Windows 10+).

4. **Flutter Stability:** Flutter desktop support remains stable and maintained by Google.

5. **SQLite Reliability:** SQLite database engine is reliable and performant for local file storage.

6. **Single User:** Each document is edited by one user at a time (no concurrent editing in v0.1).

7. **Document Size:** Typical documents contain <10,000 objects and <100,000 events.

8. **Network Optional:** Application does not require internet connectivity for core features.

**8.2 Dependencies**

**External Libraries:**
- `flutter`: SDK 3.x (Google)
- `sqflite`: SQLite plugin (maintained)
- `provider`: State management (maintained)
- `freezed`: Code generation for immutable classes (maintained)
- `file_picker`: Cross-platform file dialogs (maintained)
- `xml`: XML parsing for SVG import (maintained)
- `pdf`: PDF generation for export (maintained)

**Platform APIs:**
- macOS: File system access, window management
- Windows: File system access, window management

**Development Tools:**
- Dart SDK 3.x
- Flutter DevTools for debugging
- VS Code or Android Studio for IDE

**8.3 Risks**

| Risk ID | Risk Description | Probability | Impact | Mitigation Strategy | Residual Risk |
|:--------|:-----------------|:------------|:-------|:--------------------|:--------------|
| **R-001** | Flutter desktop support deprecated by Google | Low | Critical | Monitor Flutter roadmap, have contingency plan for Electron/Qt migration | Medium |
| **R-002** | SQLite performance degradation with 100K+ events | Medium | High | Implemented snapshot system (500 events), aggressive indexing, compression | Low |
| **R-003** | Event replay non-determinism due to floating-point rounding | Medium | High | Use double precision for all coordinates, validate replay in integration tests | Low |
| **R-004** | File corruption from application crash during save | Low | High | Use SQLite transactions with fsync, implement crash recovery | Very Low |
| **R-005** | Adobe AI file format changes break import | Medium | Medium | Focus on PDF-compatible AI format (stable), document limitations clearly | Low |
| **R-006** | Memory exhaustion on very large documents (50K+ objects) | Medium | Medium | Implement object streaming, viewport culling, recommend document splitting | Medium |
| **R-007** | Cross-platform file path issues (macOS/Windows) | Low | Low | Use Flutter path package for cross-platform paths, test on both platforms | Very Low |
| **R-008** | Bezier tessellation accuracy issues at extreme zoom levels | Low | Low | Adaptive tessellation based on zoom level, LOD simplification | Very Low |
| **R-009** | Undo/redo stack memory bloat with deep history | Low | Very Low | Configurable depth (default: 100, max: unlimited). SQLite storage with proper indexing handles large history efficiently. User controls file size growth. | Very Low |
| **R-010** | SVG import compatibility with non-standard SVG variants | High | Medium | Focus on W3C-compliant SVG, document unsupported features clearly, provide import report | Medium |
| **R-011** | Multi-document window lifecycle complexity on Windows | Medium | Medium | MDI infrastructure present. Complete window lifecycle management will be implemented in MVP with unlimited resources. Requires thorough cross-platform testing (macOS & Windows). | Medium |
| **R-012** | Event sampling causing data loss if app crashes mid-drag | Low | Low | Flush events on pointer up, implement periodic auto-flush (1 second) | Very Low |

---

#### **9.0 Key Insights from Implementation Review**

**9.1 What Went Right**

✅ **Event Sourcing Foundation:** The hybrid state management model (final state + history log) was correctly interpreted and implemented. This avoids the performance trap of pure event sourcing while maintaining replay capability.

✅ **Tool Framework:** The tool architecture with ITool interface, ToolManager orchestration, and CursorService is clean and well-tested (70+ unit tests).

✅ **Immutability:** Consistent use of Freezed for all domain models ensures predictable state management and easy debugging.

✅ **SVG Import:** Exceeded specification by implementing comprehensive Tier 1 & 2 support with integration test coverage.

✅ **Undo/Redo:** Operation-based grouping with 200ms threshold was implemented exactly as specified, demonstrating clear understanding of requirements.

✅ **Testing Discipline:** 70 unit tests + 14 integration tests show strong commitment to quality.

---

**9.2 Ambiguities Identified in Original Specification**

🔶 **Ambiguity 1: Event Sourcing Purpose**

**Issue:** Original specification suggested "event sourcing for document reconstruction" but architectural decision clarified primary purpose is "history replay visualization."

**Impact:** Could lead to misunderstanding that all document loads require event replay (performance issue).

**Resolution:** Specification now clarifies:
- Primary storage: Final state snapshot
- Event log: Optional, for history replay only
- Load strategy: Always load final state first, replay only for history visualization

---

🔶 **Ambiguity 2: Anchor Point Visibility Default**

**Issue:** T040 ticket says "anchor points visible by default" but doesn't specify if this persists across sessions or per-document.

**Impact:** Unclear whether preference should be global (application settings) or per-document.

**Resolution:** Specification now clarifies:
- Default: Always visible on all paths
- Persistence: Both per-document AND global application preference
- Toggle: Cmd/Ctrl+Shift+A for temporary hide
- Performance: When hidden, overlay unregistered (zero cost)

---

🔶 **Ambiguity 3: Multi-Document Architecture Scope**

**Issue:** Decision 2 specifies MDI (separate windows) but current implementation has single-document UI shell.

**Impact:** Infrastructure exists but UI not fully wired, unclear if blocking v0.1 release.

**Resolution (Updated for Unlimited Resources):** Specification now clarifies:
- **v1.0 MVP scope:** Complete multi-document UI with window lifecycle management
- **Infrastructure:** Multi-document backend complete
- **Window Management:** Full implementation included in MVP (unlimited development resources)
- **Deliverable:** Complete MDI with multi-artboard Navigator, window lifecycle, cross-platform support

---

🔶 **Ambiguity 4: AI Import Scope & Format Support**

**Issue:** Original specification said "Tier 2 support" but didn't clarify which AI file formats to support (PDF-compatible vs. Legacy PostScript).

**Impact:** Unclear what specific features and file versions must be implemented.

**Resolution:** Specification now focuses on **easiest and most common** AI files:
- **Supported:** PDF-compatible AI files (AI 9.0+, created ~2000 onwards)
  - These are essentially PDFs with AI metadata
  - Can be parsed using existing PDF libraries
  - Covers ~95% of modern AI files
- **Feature Level: Tier 1 (Basic Vector Features)**
  - Paths with Bézier curves
  - Basic shapes (rectangles, ellipses)
  - Fill and stroke colors
  - Stroke widths
  - Layer hierarchy (basic)
- **Tier 2 Features INCLUDED in MVP:**
  - ✅ Gradients (linear and radial)
  - ✅ Compound paths
  - ✅ Clipping masks
- **Explicitly NOT Supported:**
  - ❌ Legacy PostScript AI files (AI 8 and earlier, pre-2000)
  - ❌ AI-specific features (brushes, symbols, live effects, appearances)
- **Implementation Strategy:**
  - Parse AI file as PDF (since AI 9+ embeds PDF)
  - Extract vector content from PDF structure
  - Convert to WireTuner objects
  - Show import report: "Imported X paths, Y shapes. Unsupported features ignored: [list]"
- **Error Handling:**
  - If file is Legacy PostScript AI → show error: "Unsupported AI format. Please save as AI 9.0+ (PDF-compatible) in Illustrator."
  - Recommend: Use "File → Save As → Illustrator (AI) → Compatibility: AI 9.0 or later"

**Rationale:**
- PDF-compatible AI is the de facto standard since Illustrator 9 (2000)
- Uses existing PDF parsing infrastructure (no custom PostScript parser needed)
- Tier 1 features cover 90% of simple vector import use cases
- Users can convert complex AI files to SVG in Illustrator for full fidelity

---

🔶 **Ambiguity 5: Snapshot Frequency Discrepancy**

**Issue:**
- Specification says: "Every 1000 events"
- Implementation uses: 500 events

**Impact:** More snapshots than specified = larger file size, but better performance.

**Resolution:** Specification now clarifies:
- **Acceptable range:** 500-1000 events
- **Rationale:** 500 events provides better replay performance (<100ms sections) with acceptable storage overhead
- **Implementation decision:** 500 events is within acceptable parameters

---

🔶 **Ambiguity 6: Error Handling Missing from Original Spec**

**Issue:** Original specification lacked detailed error scenarios (disk full, corrupted files, invalid SVG).

**Impact:** Implementation may handle errors inconsistently or not at all.

**Resolution:** Section 4.0 added with comprehensive error scenarios:
- File operation errors (disk full, corrupted files, version mismatch)
- Import/export errors (invalid formats, unsupported features)
- Drawing tool errors (limits, validation)
- Event store errors (database locks, replay inconsistencies)
- System resource errors (memory pressure, GPU failures)

---

🔶 **Ambiguity 7: File Format Version Compatibility**

**Issue:** Decision 4 says "N-2 backward compatibility" but doesn't specify:
- What happens when opening v2.0 file with v1.0 app?
- What happens when saving v1.0 file from v2.0 app?

**Impact:** Migration logic may be incomplete or incorrect.

**Resolution:** Specification now includes version compatibility matrix:
```
| App Version | Can Read | Can Write | Notes |
|-------------|----------|-----------|-------|
| 1.x | 1.x | 1.x | Initial format |
| 2.x | 1.x, 2.x | 2.x, 1.x (degraded) | Warns on feature loss |
| 3.x | 1.x, 2.x, 3.x | 3.x, 2.x (degraded) | Drops 1.x write |
```

And clarifies behavior:
- **Newer version:** Reject with "Upgrade required" message
- **Older version:** Auto-migrate with backup creation
- **Degraded save:** "Save As..." option with feature loss warnings

---

**9.3 Contradictions Resolved**

❌→✅ **Contradiction 1: Event Sourcing Model**

**Original Statement:** "Event sourcing for document reconstruction"
**Architectural Decision:** "Hybrid state management - final state for loading, events for replay"

**Resolution:** The specification now consistently describes the hybrid model throughout all sections (3.0, 4.0, 6.0). The term "event sourcing" is qualified as "event-logged history" to avoid confusion with pure event sourcing patterns.

---

❌→✅ **Contradiction 2: Snapshot Strategy**

**Specification:** "Every 1000 events"
**Implementation:** Every 500 events

**Resolution:** Specification updated to specify "500 events (conservative strategy)" with rationale that this provides better replay performance while staying within acceptable storage overhead. Original 1000-event target documented as "relaxed strategy" that may be used in future optimizations.

---

**9.4 Missing Specifications Identified**

📋 **Missing Spec 1: Performance Metrics Overlay**

**Issue:** Implementation has comprehensive performance monitoring (FPS overlay, event count) but not specified in original requirements.

**Added:** NFR-PERF-003 specifies 60 FPS target, User Journey now mentions Cmd/Ctrl+Shift+P toggle for performance overlay.

---

📋 **Missing Spec 2: Tool Cursor Behavior**

**Issue:** Specification didn't describe cursor changes for tools.

**Added:** FR-003 now specifies cursor requirements (crosshair for pen, arrow for selection, etc.) and NFR-PERF-004 specifies <0.2ms cursor update latency.

---

📋 **Missing Spec 3: Hit Testing Radius**

**Issue:** Specification didn't define how close user must click to select anchor points.

**Added:** User Journey 2 now specifies 8px hit test radius for anchor selection.

---

📋 **Missing Spec 4: Grid Snapping Parameters** ✅ RESOLVED

**Issue:** FR-028 mentions grid snapping but doesn't specify grid size or coordinate space.

**Resolution (v3.7):** Grid snapping and arrow key nudging comprehensively specified:
- Grid size: **10px in screen space** (not world space)
- Arrow key nudging: **1px screen space** (normal), **10px screen space** (Shift modifier)
- Intelligent zoom suggestion when user overshoots (3+ direction reversals)
- Alternative: Z key hold for temporary 2x zoom
- See FR-050 and Section 7.11 for complete implementation details

---

📋 **Missing Spec 5: Undo Stack Depth** ✅ RESOLVED

**Issue:** Undo/redo mentioned but no limit specified.

**Resolution (v3.5):** FR-022 now specifies configurable undo stack depth:
- Default: 100 operations
- Maximum: Unlimited (user manages file size)
- Configuration: Single constant in UndoManager class
- Storage: SQLite-backed with proper indexing for performance
- See Section 7.8 for code example

---

**9.5 Implementation Completeness Assessment**

**Features COMPLETE and meeting specification:**
- ✅ Event sourcing (hybrid model)
- ✅ All drawing tools (pen, selection, direct selection, shapes)
- ✅ Rendering pipeline with overlays
- ✅ Save/load with version migration infrastructure
- ✅ SVG import (Tier 1 & 2)
- ✅ SVG export
- ✅ Undo/redo with operation grouping
- ✅ Anchor point visualization
- ✅ Event sampling (50ms)
- ✅ Snapshot system (500 events)

**Features PARTIAL implementation:**
- ⚠️ Multi-document UI (infrastructure ready, UI incomplete)
- ⚠️ PDF export (operator parsing done, full export status unclear)
- ⚠️ AI import (framework exists, tier level needs verification)

**All Core Features IN SCOPE for v1.0 MVP (Unlimited Resources):**
- ✅ History replay UI (timeline scrubber, play/pause, speed control)
- ✅ Layer management panel (full UI with drag-drop, visibility, locking)
- ✅ Collaboration sync (real-time multiplayer via API - see Section 7.9)
- ✅ Advanced typography (text tool, text on path, rich formatting)
- ✅ Advanced vector operations (boolean ops, path simplification, envelope distortion)

**Overall Completeness Target: ~100% for v1.0 MVP** (comprehensive feature set with unlimited development resources)

---

#### **9.6 Architectural Decision Records (ADRs)**

**Purpose:** This section explicitly documents critical architectural decisions that resolve ambiguities in the specification and provide clear implementation guidance.

**Source:** Automated specification review (2025-11-10) identifying 7 critical assertions requiring explicit resolution.

---

**ADR-001: Event Sourcing Storage Strategy**

**Decision:** **Unbounded Event Log with User-Managed File Sizes**

**Context:** The system must balance complete history retention with performance and storage constraints.

**Chosen Path:** Store all events indefinitely without automatic pruning. Users manage file sizes through manual archival or file splitting.

**Rationale:**
- Aligns with "unlimited resources" MVP scope and professional user base
- Event sourcing value proposition depends on complete history access
- SQLite with proper indexing handles 500K+ events without catastrophic degradation
- Users in professional workflows understand file size management (similar to video editing)

**Implementation Requirements:**
- **File Size Growth Estimation:** Typical 1-hour editing session = ~5,000 events = ~2MB file size
- **Performance Thresholds:**
  - ≤100K events: Excellent performance (<100ms load time)
  - 100K-500K events: Good performance (<500ms load time)
  - >500K events: Acceptable performance (<2s load time) with user warning
- **User Warnings:** When document exceeds 500K events, show toast: "Large document detected. Consider archiving to JSON for long-term storage."
- **Snapshot Strategy:** Maintain configurable snapshot frequency (default: 500 events) to optimize load times
- **Monitoring:** Expose event count in file info dialog and status bar

**Alternatives Rejected:**
- Windowed retention: Loses deep history, contradicts core value proposition
- Tiered retention: Complex implementation, user confusion about which events are kept

---

**ADR-002: Multiplayer Collaboration Conflict Resolution**

**Decision:** **Operational Transform (OT) Algorithm**

**Context:** Real-time multiplayer editing requires deterministic conflict resolution for concurrent vector path edits.

**Chosen Path:** Implement Operational Transform with centralized server-side operation sequencing.

**Rationale:**
- Vector editing requires deterministic, precision-critical conflict resolution
- Target use case is small design teams (2-10 concurrent users) where OT excels
- Aligns with WebSockets + GraphQL hybrid architecture (server can sequence operations)
- Well-understood algorithms for path editing transformations (move, transform, style changes)

**Implementation Requirements:**
- **Maximum Concurrent Editors:** 5-10 users per document (enforced server-side)
- **Conflict Resolution Latency:** <200ms for transform + broadcast cycle
- **Operation Types with Transform Functions:**
  - `path.anchor.moved`: Transform concurrent anchor moves on same path
  - `object.moved`: Transform concurrent object moves with collision detection
  - `path.anchor.added/deleted`: Sequence-dependent indexing adjustments
  - `object.styled`: Last-write-wins for style properties (low conflict)
- **Server Requirements:**
  - Maintain authoritative event sequence number
  - Broadcast transformed operations to all connected clients
  - Persist all operations to event store
- **Client Requirements:**
  - Buffer local operations during server round-trip
  - Apply server-transformed operations to local state
  - Display conflict resolution in real-time (no "lock" icons, seamless)

**Alternatives Rejected:**
- CRDT: Eventually consistent, may produce unexpected intermediate states for precise vector work
- Last-Write-Wins: Unacceptable data loss risk during simultaneous edits

**References:** Section 7.9 (Multiplayer API Architecture)

---

**ADR-003: Cross-Platform File Format Serialization**

**Decision:** **SQLite Native Types Only (INTEGER, REAL, TEXT)**

**Context:** Ensure byte-identical cross-platform compatibility between macOS (Intel/ARM) and Windows (x86/x64).

**Chosen Path:** Restrict all stored data to SQLite's native types, avoiding custom binary serialization.

**Rationale:**
- **Eliminates endianness issues:** SQLite handles platform differences internally
- **Guaranteed portability:** Files created on macOS open identically on Windows
- **Simpler debugging:** Direct SQL queries reveal human-readable data
- **Lower risk:** No custom binary format maintenance burden

**Implementation Requirements:**

**Schema Design:**
```sql
-- Document metadata
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,  -- RFC3339 timestamp
  modified_at TEXT NOT NULL,
  file_version TEXT NOT NULL -- Semantic version "2.0.0"
);

-- Artboards
CREATE TABLE artboards (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  name TEXT NOT NULL,
  bounds_x REAL NOT NULL,
  bounds_y REAL NOT NULL,
  bounds_width REAL NOT NULL,
  bounds_height REAL NOT NULL,
  background_color TEXT NOT NULL, -- Hex "#RRGGBBAA"
  z_order INTEGER NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents(id)
);

-- Layers (denormalized - per artboard)
CREATE TABLE layers (
  id TEXT PRIMARY KEY,
  artboard_id TEXT NOT NULL,
  name TEXT NOT NULL,
  visible INTEGER NOT NULL,  -- Boolean as 0/1
  locked INTEGER NOT NULL,
  z_index INTEGER NOT NULL,
  FOREIGN KEY (artboard_id) REFERENCES artboards(id)
);

-- Vector objects (paths and shapes)
CREATE TABLE vector_objects (
  id TEXT PRIMARY KEY,
  layer_id TEXT NOT NULL,
  object_type TEXT NOT NULL,  -- "path" or "shape"
  transform_tx REAL NOT NULL, -- Translation X
  transform_ty REAL NOT NULL,
  transform_rotation REAL NOT NULL,
  transform_scale_x REAL NOT NULL,
  transform_scale_y REAL NOT NULL,
  style_fill_color TEXT,      -- Hex or NULL
  style_stroke_color TEXT,
  style_stroke_width REAL,
  style_opacity REAL NOT NULL,
  FOREIGN KEY (layer_id) REFERENCES layers(id)
);

-- Anchor points (denormalized - separate table for paths)
CREATE TABLE anchor_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  path_id TEXT NOT NULL,
  anchor_index INTEGER NOT NULL,
  position_x REAL NOT NULL,
  position_y REAL NOT NULL,
  handle_in_x REAL,  -- NULL if no handle
  handle_in_y REAL,
  handle_out_x REAL,
  handle_out_y REAL,
  anchor_type TEXT NOT NULL,  -- "smooth", "corner", "tangent"
  FOREIGN KEY (path_id) REFERENCES vector_objects(id)
);

-- Events (event sourcing log)
CREATE TABLE events (
  event_id TEXT PRIMARY KEY,
  sequence INTEGER NOT NULL UNIQUE,
  timestamp TEXT NOT NULL,
  user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_data TEXT NOT NULL,  -- JSON payload as TEXT
  FOREIGN KEY (sequence) -- Indexed for replay
);

-- Snapshots
CREATE TABLE snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sequence INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  compressed INTEGER NOT NULL,  -- Boolean: is gzipped?
  state_data TEXT NOT NULL      -- JSON or compressed JSON as TEXT
);

CREATE INDEX idx_events_sequence ON events(sequence);
CREATE INDEX idx_snapshots_sequence ON snapshots(sequence DESC);
```

**Coordinate Storage:** All coordinates stored as REAL (SQLite's 8-byte IEEE 754 float, equivalent to double precision)

**Color Storage:** Hex strings "#RRGGBBAA" (8 characters) for consistency and human-readability

**Boolean Storage:** INTEGER 0 (false) or 1 (true)

**JSON Payloads:** Event data and snapshot state stored as TEXT (JSON), optionally gzipped and stored as TEXT (base64-encoded if needed, or as BLOB for compressed data)

**Performance Considerations:**
- Denormalized schema (anchor points in separate table) slightly increases query complexity
- Offset by eliminating JSON parsing overhead for common queries
- Proper indexing maintains <100ms load times for documents with 10K+ objects

**Alternatives Rejected:**
- Pure JSON in BLOBs: Larger files, slower parsing, harder to debug
- Custom binary format: Platform compatibility risk, maintenance burden

---

**ADR-004: Snapshot Background Execution Thread Safety**

**Decision:** **Copy-on-Write Snapshot with Memory Monitoring**

**Context:** Background snapshot creation must not block UI or corrupt state during concurrent user edits.

**Chosen Path:** Deep clone document state before passing to background isolate, with memory pressure monitoring.

**Rationale:**
- **Guarantees consistency:** Snapshot captures exact state at specific sequence number
- **Non-blocking:** Aligns with v3.4 requirement for background execution
- **Predictable behavior:** No retry logic complexity or user-visible failures

**Implementation Requirements:**

```dart
// lib/infrastructure/persistence/snapshot_manager.dart
class SnapshotManager {
  Future<void> createSnapshotInBackground(Document document) async {
    // 1. Check available memory before cloning
    final systemInfo = await DeviceInfoPlugin().deviceInfo;
    final availableMemoryMB = systemInfo.availableMemoryMB;

    // Estimate: document size ≈ object count * 2KB + event count * 0.5KB
    final estimatedDocSizeMB = (document.objectCount * 2 +
                                 document.eventCount * 0.5) / 1024;

    final requiredMemoryMB = estimatedDocSizeMB * 2 + 200; // 2x doc + 200MB headroom

    if (availableMemoryMB < requiredMemoryMB) {
      // Defer snapshot to next opportunity
      _logger.warn('Insufficient memory for snapshot: need ${requiredMemoryMB}MB, have ${availableMemoryMB}MB');
      _statusBar.showWarning('Low memory - snapshot deferred');
      return;
    }

    // 2. Deep clone document state (copy-on-write)
    final documentClone = document.deepCopy();
    final targetSequence = document.currentSequence;

    // 3. Pass clone to background isolate
    final snapshot = await compute(
      _createSnapshotWorker,
      _SnapshotWorkerParams(
        document: documentClone,
        sequence: targetSequence,
      ),
    );

    // 4. Persist snapshot to database (fast, <10ms)
    await _database.insertSnapshot(snapshot);

    _logger.info('Snapshot created: sequence=$targetSequence, size=${snapshot.compressedSize}KB');
  }

  // Worker runs in separate isolate
  static Snapshot _createSnapshotWorker(_SnapshotWorkerParams params) {
    final json = params.document.toJson();
    final jsonString = jsonEncode(json);
    final compressed = gzip.encode(utf8.encode(jsonString));

    return Snapshot(
      sequence: params.sequence,
      timestamp: DateTime.now(),
      compressed: true,
      stateData: base64.encode(compressed),
    );
  }
}
```

**Memory Thresholds:**
- **Safe zone:** >2GB available RAM - always proceed with snapshot
- **Warning zone:** 500MB-2GB available RAM - proceed with monitoring
- **Defer zone:** <500MB available RAM - defer snapshot, show warning
- **User action:** If snapshots consistently deferred, suggest closing other documents or archiving to JSON

**Performance Impact:**
- Deep copy overhead: ~50-100ms for typical 1,000-object document
- Total snapshot time: ~200-500ms including serialization and compression
- UI remains 60fps responsive (runs in background isolate)

**Alternatives Rejected:**
- Read lock: Introduces UI freeze (contradicts v3.4 non-blocking requirement)
- Sequence validation retry: Complex, may fail under heavy editing load

**References:** Section 7.7 (Snapshot Strategy Configuration)

---

**ADR-005: AI File Import Feature Completeness**

**Decision:** **Tier 1 + Tier 2 Comprehensive Import**

**Context:** Balance import coverage with implementation complexity for Adobe Illustrator (.ai) files.

**Chosen Path:** Implement Tier 1 (basic vectors) + Tier 2 (gradients, masks, compound paths) for 85-90% coverage.

**Rationale:**
- Aligns with "unlimited resources" MVP scope (v3.5)
- Tier 2 explicitly marked "INCLUDED in MVP" in specification
- Covers vast majority of professional design use cases
- Clear boundary: exclude proprietary features (blend modes, live effects)

**Implementation Requirements:**

**Tier 1 Features (MUST support):**
- Basic vector paths (straight and curved segments)
- Primitive shapes (rectangles, ellipses, polygons)
- Fill colors (solid RGB/RGBA)
- Stroke properties (color, width, cap, join)
- Layer hierarchy (basic groups)

**Tier 2 Features (MUST support):**
- Linear gradients (2+ color stops)
- Radial gradients (2+ color stops)
- Clipping masks (single-level)
- Compound paths (union of multiple path outlines)

**Tier 3+ Features (Graceful degradation with warnings):**
- Blend modes → Import as normal objects, log warning
- Live effects (drop shadow, blur) → Ignore, log warning
- Symbols/brushes → Convert to expanded paths or skip
- Text → Import as path outlines if embedded, otherwise placeholder
- Patterns → Import as flat fills with warning

**Acceptance Criteria:**
- **Test Corpus:** 20 representative AI files (Illustrator CS6, CC 2018, CC 2024)
- **Success Rate:** ≥85% of objects import with correct visual appearance
- **Import Report:** Display modal after import listing:
  - ✅ Successfully imported: X paths, Y shapes, Z gradients
  - ⚠️ Partial support: List of degraded features (e.g., "3 blend modes converted to normal")
  - ❌ Unsupported: List of skipped features (e.g., "1 live effect ignored")

**Implementation Estimate:** 10-15 days including edge case testing

**Alternatives Rejected:**
- Tier 1 only: Insufficient coverage (60-70%), users would be disappointed
- Full AI spec: Unrealistic (30-60 days), high failure risk on proprietary features

**References:** Section 9.2 Ambiguity 4 (AI Import Scope)

---

**ADR-006: History Replay Timeline Scrubber Performance**

**Decision:** **Snapshot Checkpoints with Lazy Generation**

**Context:** Enable smooth timeline scrubbing through 100K+ event documents without performance degradation.

**Chosen Path:** Pre-generate snapshots every 1,000 events (lazy, on first scrub) for rapid seeking.

**Rationale:**
- Balances performance with memory efficiency
- Lazy generation avoids impact on document load time
- 30fps scrubbing UX is achievable with <50ms seek latency

**Implementation Requirements:**

**Checkpoint Strategy:**
```dart
// lib/application/history/history_replay_manager.dart
class HistoryReplayManager {
  static const CHECKPOINT_INTERVAL = 1000; // Events between checkpoints

  final Map<int, DocumentSnapshot> _replayCheckpoints = {};
  bool _checkpointsGenerated = false;

  // Called when user first opens History Replay panel
  Future<void> initializeReplay(Document document) async {
    if (_checkpointsGenerated) return;

    _statusBar.showStatus('Generating timeline checkpoints...');

    final checkpointCount = (document.currentSequence / CHECKPOINT_INTERVAL).ceil();

    // Generate checkpoints in background
    for (int i = 0; i < checkpointCount; i++) {
      final targetSequence = i * CHECKPOINT_INTERVAL;

      // Replay from last checkpoint (or beginning) to target
      final checkpoint = await _generateCheckpoint(document, targetSequence);
      _replayCheckpoints[targetSequence] = checkpoint;

      // Update progress
      _statusBar.showStatus('Checkpoint ${i+1}/$checkpointCount');
    }

    _checkpointsGenerated = true;
    _statusBar.showStatus('Timeline ready');
  }

  // Seek to arbitrary position in timeline
  Future<Document> seekToSequence(int targetSequence) async {
    // Find nearest checkpoint ≤ target
    final checkpointSequence = (targetSequence ~/ CHECKPOINT_INTERVAL) * CHECKPOINT_INTERVAL;
    final checkpoint = _replayCheckpoints[checkpointSequence];

    // Replay from checkpoint to target (typically <1000 events)
    final document = checkpoint.toDocument();
    await _replayEngine.replayRange(
      document,
      fromSequence: checkpointSequence + 1,
      toSequence: targetSequence,
    );

    return document;
  }
}
```

**Performance Targets:**
- **Checkpoint Generation:** <1s per 1,000-event checkpoint
- **Initial Generation Time:** ~10-15s for 100,000-event document (100 checkpoints)
- **Scrubbing Latency:** <50ms to seek to arbitrary position
- **UI Responsiveness:** 30fps during timeline scrubbing
- **Memory Overhead:** ~50-100MB for 100K-event document (100 checkpoints × 0.5-1MB each)

**User Experience:**
1. User opens History Replay panel
2. Progress indicator: "Generating timeline checkpoints... 25/100"
3. Once complete: Smooth scrubbing enabled
4. Checkpoints cached for document session (regenerate on reload)

**Alternatives Rejected:**
- Keyframe interpolation: Complex, harder to ensure visual accuracy
- Lazy evaluation: Degraded UX during fast scrubbing, inconsistent performance

**References:** NFR-PERF-002 (Event Replay Rate), v3.5 changelog (History Replay UI in MVP)

---

**ADR-007: Arrow Key Nudging Behavior at Extreme Zoom Levels**

**Decision:** **Fixed Screen-Space Nudging Across All Zoom Levels**

**Context:** Define arrow key nudging behavior consistency from 0.01x zoom (full artboard view) to 100x zoom (extreme close-up).

**Chosen Path:** Always nudge 1px screen space (normal) or 10px screen space (Shift modifier), regardless of zoom level. Intelligent zoom suggestions remain advisory.

**Rationale:**
- **Predictable behavior:** User always knows "arrow key = 1px movement on screen"
- **Zoom as precision tool:** Users zoom in for finer world-space control
- **Matches industry standards:** Illustrator, Figma use fixed screen-space nudging
- **Advisory assistance:** Toast suggestions help users discover zoom for precision, without blocking workflow

**Implementation Requirements:**

**Nudging Behavior Across Zoom Levels:**

| Zoom Level | Arrow Key (Normal) | Shift + Arrow | World Space Movement |
|------------|-------------------|---------------|---------------------|
| 0.01x (0.01:1) | 1px screen | 10px screen | 100px world |
| 0.1x (0.1:1) | 1px screen | 10px screen | 10px world |
| 50% (0.5:1) | 1px screen | 10px screen | 2px world |
| 100% (1:1) | 1px screen | 10px screen | 1px world |
| 200% (2:1) | 1px screen | 10px screen | 0.5px world |
| 400% (4:1) | 1px screen | 10px screen | 0.25px world |
| 800% (8:1) | 1px screen | 10px screen | 0.125px world |
| 10,000% (100:1) | 1px screen | 10px screen | 0.01px world |

**Intelligent Zoom Suggestions:**
- Activated when user overshoots target (3+ direction reversals: → ← → ←)
- Toast notification: "Press Cmd/Ctrl + = to zoom in for finer control"
- Non-blocking (user can ignore and continue nudging)
- Alternative: Hold Z key for temporary 2x zoom at cursor

**Extreme Zoom Recommendations** (non-blocking guidance):
- **Below 10% zoom:** Status bar hint: "Tip: Use marquee selection for large movements at this zoom level"
- **Above 800% zoom:** No special behavior (sub-pixel nudging is valid for precision work)
- **Viewport panning:** Never replace arrow key nudging with panning (spacebar+drag is for panning)

**Edge Case Handling:**
- **No selection:** Arrow keys do nothing (no viewport panning)
- **Multiple objects selected:** Nudge all selected objects together
- **Anchors selected (Direct Selection Tool):** Nudge individual anchors

**Alternatives Rejected:**
- Adaptive nudging: Unpredictable, user confusion about movement distance
- Mandatory zoom gates: Blocks workflow, removes user agency

**References:** FR-050 (Arrow Key Nudging), Section 7.11 (Grid Snapping & Arrow Key Nudging)

---

#### **10.0 Specification Changelog**

| Version | Date | Changes | Author |
|:--------|:-----|:--------|:-------|
| 1.0 | 2025-11-06 | Original architectural decisions document | System/User |
| 2.0 | 2025-11-10 | Comprehensive specification using template format, added error handling, resolved ambiguities, integrated implementation findings | Claude/User |
| 3.0 | 2025-11-10 | **MAJOR UPDATE:** Multi-artboard architecture - documents now support unlimited artboards with Artboard Navigator, per-artboard layers/viewport/selection, window lifecycle management. Added 17 new FRs (FR-029 to FR-045), 9 new artboard events, comprehensive user journeys (Journey 10-18). File format version bumped to 2.0.0. | Claude/User |
| 3.1 | 2025-11-10 | **Clarifications on Export/Import:** (1) PDF export simplified to SVG-to-PDF conversion approach using open-source libraries (flutter_svg+pdf, librsvg, or resvg). Removes need for custom PDF operator generation. (2) AI import scoped to PDF-compatible AI files only (AI 9.0+, ~2000 onwards) with Tier 1 features. Legacy PostScript AI explicitly out of scope. Implementation strategy and library recommendations added. | Claude/User |
| 3.2 | 2025-11-10 | **Anchor Point Visibility Enhancement:** Upgraded from simple toggle to 3-mode system: (1) All Visible (default), (2) Selected Only, (3) Hidden. Added toggle icon in window frame, keyboard shortcut cycles modes, toast notifications, per-document + global persistence. Updated FR-024 to Critical priority. Journey 9 significantly expanded with detailed interaction flows. | Claude/User |
| 3.3 | 2025-11-10 | **Event Sampling Strategy Refined:** Changed philosophy from "sample everything at 50ms" to "critical events always + optional mouse movement sampling (default 200ms, configurable 0-500ms+)". Added FR-046 for sampling configuration with code example and user settings UI. Storage impact calculations added (200ms = ~900KB/hour). Clarified that start/end positions are essential, intermediate samples are "nice-to-have" for replay visualization. Replay engine can infer motion from start→end if no intermediate samples. Updated all references from 50ms to 200ms default with configurability emphasis. | Claude/User |
| 3.4 | 2025-11-10 | **Snapshot Strategy Configuration:** Made snapshot triggers easily configurable (default: 500 events OR 10 minutes) with single-constant code changes. Added Section 7.7 with SnapshotManager code example showing configurable thresholds. **Critical: Background execution requirement** - snapshots MUST run in background isolate/thread using Flutter's `compute()` to prevent UI blocking. Updated FR-026 to Critical priority with background execution acceptance criteria. Updated NFR-PERF-006 to require zero UI blocking during snapshot creation (maintain 60fps). Philosophy: Event threshold OR time threshold OR manual save (Cmd/Ctrl+S) triggers snapshot. | Claude/User |
| 3.5 | 2025-11-10 | **MAJOR SCOPE EXPANSION - Unlimited Resources Strategy:** (1) **Undo Stack Depth**: Made configurable (default: 100, max: unlimited). Added Section 7.8 with UndoManager code example. Updated FR-022, R-009, Missing Spec 5. (2) **Everything Ships with MVP**: Removed all v0.2 deferrals. History Replay UI, Layer Management Panel, Collaboration Features, Advanced Typography, Advanced Vector Operations ALL included in v1.0 MVP. Updated scope sections, risks, ambiguity resolutions. (3) **Multiplayer API Architecture**: Added comprehensive Section 7.9 recommending **WebSockets + GraphQL hybrid** (NOT gRPC). Includes Dart Frog backend recommendation, event flow diagrams, OT/CRDT conflict resolution strategy, security model, scalability with Redis Pub/Sub, and 6-8 week implementation estimate. Target: ~100% feature completeness for v1.0 MVP. | Claude/User |
| 3.6 | 2025-11-10 | **Platform Integration & Hybrid File Format:** (1) **Platform-Specific Features**: Added FR-047 (macOS integration) and FR-048 (Windows integration). macOS: QuickLook preview, Spotlight indexing, native dialogs (NO Touch Bar explicitly). Windows: Explorer thumbnails, Jump Lists, Search integration, file associations. Both medium priority. (2) **Hybrid File Format Strategy**: Added FR-049 and Section 7.10. **SQLite for active editing** (.wiretuner files - event sourcing, snapshots, undo/redo). **JSON for export/archive** (.json files - version control friendly, human-readable, interoperability). Includes file menu structure, implementation examples, use case matrix, file size comparisons. JSON export = snapshot only (no event history). Round-trip compatible. | Claude/User |
| 3.7 | 2025-11-10 | **Grid Snapping & Arrow Key Nudging (Screen Space):** Updated FR-028 and added FR-050 with comprehensive screen-space behavior. **Grid snapping: 10px in screen space** (maintains visual consistency regardless of zoom). **Arrow key nudging: 1px screen space** (normal), 10px (Shift modifier). Added **intelligent zoom suggestion** - system detects overshooting (3+ direction reversals) and suggests zoom-in via toast. Alternative: Z key hold for temporary 2x zoom. Added Section 7.11 with complete implementation examples, screen-to-world coordinate conversion, user experience table showing zoom level effects. Resolved Missing Spec 4. Philosophy: Consistent visual behavior across all zoom levels. | Claude/User |
| 3.8 | 2025-11-10 | **Auto-Save & Manual Save Strategy:** Updated FR-014 with comprehensive auto-save + manual save behavior. **Auto-save:** Continuous (200ms idle threshold), persists events to SQLite incrementally, NO event recorded, subtle "Auto-saved" indicator. **Manual save (Cmd/Ctrl+S):** Records `document.saved` event, creates snapshot (background), prominent "Saved" indicator, **save deduplication** (multiple saves without changes = ONE event only). Added Section 7.12 with complete implementation, deduplication logic, UI indicators, error recovery workflows, benefits comparison table. Philosophy: Auto-save for data safety (zero data loss on crash), manual save for user checkpoint markers (versioning, collaboration signals, replay milestones). | Claude/User |
| 3.9 | 2025-11-10 | **CRITICAL: Architectural Decision Records (ADRs) - Automated Review Response:** Added Section 9.6 resolving 7 critical assertions from automated specification review. **ADR-001:** Unbounded event log (user-managed file sizes, 500K event thresholds). **ADR-002:** Operational Transform for multiplayer (5-10 concurrent users, <200ms conflict resolution). **ADR-003:** SQLite native types serialization (eliminates endianness issues, complete schema design with denormalized anchor_points table). **ADR-004:** Copy-on-write snapshot with memory monitoring (2x memory requirement, defer if <500MB RAM). **ADR-005:** Tier 1+2 AI import (85-90% coverage, 20-file test corpus, import report modal). **ADR-006:** Snapshot checkpoints for history replay (1,000-event intervals, lazy generation, 30fps scrubbing). **ADR-007:** Fixed screen-space nudging across all zoom levels (1px/10px screen space, advisory intelligent zoom). All ambiguities explicitly resolved with implementation requirements, code examples, and rationale. **Status: Ready for architectural design phase.** | Claude/User |

---

#### **11.0 Approval & Next Steps**

**Status:** Approved for implementation (v3.0 with multi-artboard architecture)

**Recommended Next Steps:**

1. **Implement Multi-Artboard Architecture** (CRITICAL - New Scope):
   - **Phase 1: Data Model Refactoring** (~2-3 days)
     - Update Document model: single `artboard` → `List<Artboard>`
     - Add Artboard model with layers, viewportState, selectionState, thumbnail fields
     - Update Layer model to include `artboardId` reference
     - Bump file format version to 2.0.0
     - Create migration script: v1.0 (single artboard) → v2.0 (multi-artboard)

   - **Phase 2: Event Model Updates** (~1-2 days)
     - Add 9 new artboard event types (created, deleted, renamed, resized, reordered, duplicated, etc.)
     - Add `artboardId` field to all object creation/manipulation events
     - Update event replay logic to handle artboard-scoped events
     - Update snapshot serialization for multi-artboard documents

   - **Phase 3: Artboard Navigator UI** (~4-5 days)
     - Floating palette window with thumbnail grid
     - Multi-document tabs at top
     - Context menu (Rename, Duplicate, Delete, Export, Refresh Thumbnail)
     - Drag-and-drop reordering with drop indicators
     - Thumbnail auto-regeneration (every 10s or on save)
     - "+" button for creating new artboards with preset dialog

   - **Phase 4: Window Lifecycle Management** (~3-4 days)
     - Multiple artboard windows per document
     - Shared application instance managing all windows
     - Window titles: "Artboard Name - document.wiretuner"
     - Close artboard window → keep artboard in document
     - Close Navigator → prompt "Close all artboards?"
     - Navigator as "root" window for document

   - **Phase 5: Per-Artboard State Management** (~2-3 days)
     - Independent viewport state per artboard (zoom/pan)
     - Independent selection state per artboard
     - Artboard window focus switches preserve states
     - State persistence to disk (in artboard model)

   - **Phase 6: Artboard Presets & Templates** (~1 day)
     - Preset dropdown in "New Artboard" dialog
     - iPhone 14 Pro (393x852), Desktop HD (1920x1080), A4 Portrait (595x842), Instagram Square (1080x1080), Custom
     - Custom width/height validation (min 100px, max 100,000px)

   - **Phase 7: Advanced Features** (~2-3 days)
     - Move objects between artboards (cut/paste workflow)
     - Export single artboard to SVG/PDF
     - Artboard background color picker
     - Duplicate artboard with all layers/objects

   - **Phase 8: Testing & Polish** (~3-4 days)
     - Unit tests for artboard model and events
     - Integration tests for Navigator workflow
     - Cross-platform testing (macOS & Windows)
     - Performance testing (100+ artboards, 20 open windows)
     - Thumbnail generation performance optimization

   **Total Estimated Effort: 18-25 days** (with unlimited resources, can parallelize UI and backend work)

2. **Import/Export Refinements** (In Parallel with Multi-Artboard Work):
   - **SVG Export** - Verify high-fidelity export (critical, likely complete)
   - **PDF Export** - Implement SVG-to-PDF conversion pipeline (~2 days):
     - Choose library: `flutter_svg` + `pdf` package (recommended, pure Dart)
     - OR: Native bridge to librsvg/resvg (higher quality, more complex)
     - Test vector output in Adobe Acrobat
     - Error handling for conversion failures
   - **AI Import (PDF-Compatible)** - Focus on easiest files (~3 days):
     - Parse AI 9.0+ (PDF-compatible) files only
     - Extract paths, shapes, fills, strokes (Tier 1 features)
     - Show error for Legacy PostScript AI files
     - Display import report with unsupported feature warnings
   - **Anchor Point Visibility Modes** - Implement 3-mode toggle system (~1-2 days):
     - Create toggle icon in window frame (toolbar or status bar)
     - Implement Mode 1: All Visible (default)
     - Implement Mode 2: Selected Only (filter by selection)
     - Implement Mode 3: Hidden (unregister overlay)
     - Add keyboard shortcut (Cmd/Ctrl+Shift+A cycles modes)
     - Toast notifications for mode changes
     - Per-document persistence in metadata
     - Global default in application settings

3. **Create Implementation Tickets:**
   - Break down 8 phases above into granular tickets
   - Assign dependencies and sequencing
   - Create test plans for each ticket

5. **Migration Strategy:**
   - All v1.0 files (single artboard) auto-migrate to v2.0 (single artboard in list)
   - Backward compatibility: v2.0 app can read v1.0 files
   - No forward compatibility: v1.0 app cannot read v2.0 files (show upgrade prompt)

---

**END OF SPECIFICATION**
