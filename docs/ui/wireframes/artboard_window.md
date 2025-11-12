# Artboard Window Wireframe

<!-- anchor: wireframe-artboard-window -->

## 1. Overview

The Artboard Window is the primary editing canvas for WireTuner, providing tool-based vector drawing, direct manipulation of objects and anchors, screen-space snapping, viewport controls, and real-time collaboration overlays. Each artboard opens in its own MDI window with isolated viewport and selection state.

**Route:** `app://artboard/:docId/:artboardId`

**Entry Methods:**
- Double-click artboard thumbnail in Navigator
- Window menu → [Artboard Name]
- Cmd+Enter on selected artboard in Navigator
- Collaboration invite (auto-opens artboard)

**Access Level:** Authenticated user

**Related Journeys:**
- Journey 2: Direct Selection Drag (pen tool, anchor manipulation)
- Flow D: Direct Selection Drag with Collaboration Broadcast
- Journey A-G: Tool-based creation and editing

**Related Requirements:**
- FR-024 (Anchor visibility modes)
- FR-028 (Screen-space snapping with Shift)
- FR-031 (Open artboard from Navigator)
- NFR-PERF-002 (Viewport state restoration)
- FR-050 (Collaboration adoption)

---

## 2. Layout Structure

<!-- anchor: wireframe-artboard-window-layout -->

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ Artboard: Home Screen - Campaign.wire                    Zoom: 100%        ◯ □ ⨯        │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ Toolbar:                                                                                  │
│ [↖] [✋] [🖊] [✏️] [□] [○] [↩️] [↪️]    |  [🔍+] [🔍-] [100%▾] [⊞]    |  [👁] [🎨] [⚙️]│
│  V   H   Pen Shape Rect Oval Undo Redo    Zoom+  -    Fit   Grid       View Style Set │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                           │
│  Tool Shelf                      Canvas Area                       Inspector Panel       │
│  (Left Dock)                  (Infinite Artboard)                   (Right Dock)         │
│                                                                                           │
│  ┌────────┐    ┌─────────────────────────────────────────────┐    ┌──────────────────┐ │
│  │   ↖    │    │                                             │    │ Properties       │ │
│  │ Select │    │    ┌──────────────────────────┐   🔴       │    │ ─────────────── │ │
│  ├────────┤    │    │ [Artboard Boundary       │  Alice     │    │ Position         │ │
│  │   ✋   │    │    │  1920 × 1080]            │            │    │  X: 240.5 px     │ │
│  │  Hand  │    │    │                          │            │    │  Y: 120.0 px     │ │
│  ├────────┤    │    │   ┌────────┐             │            │    │ Size             │ │
│  │   🖊   │    │    │   │ SELECTED│             │  🟢       │    │  W: 180 px       │ │
│  │  Pen   │ ●  │    │   │ Rectangle            │  Bob       │    │  H: 60 px        │ │
│  ├────────┤    │    │   │  w/blue │             │            │    │ Rotation: 0°     │ │
│  │   □    │    │    │   │ handles │             │            │    │ ─────────────── │ │
│  │ Rect   │    │    │   └────────┘             │            │    │ Fill             │ │
│  ├────────┤    │    │                          │            │    │  [████] #FF5733  │ │
│  │   ○    │    │    │      •─────────•         │            │    │ Stroke           │ │
│  │ Oval   │    │    │     /  Bezier   \        │            │    │  [    ] None     │ │
│  ├────────┤    │    │    •  Path with •        │            │    │ ─────────────── │ │
│  │   ✏️   │    │    │     \ anchors  /         │            │    │                  │ │
│  │ Shape  │    │    │      •─────────•         │            │    │ [Apply]          │ │
│  └────────┘    │    │       ↑                  │            │    └──────────────────┘ │
│                │    │   [Snap Guide: Y=120]    │            │                         │ │
│                │    │                          │            │    ┌──────────────────┐ │
│                │    └──────────────────────────┘            │    │ Layers           │ │
│                │                                             │    │ ─────────────── │ │
│                │  [Grid Overlay: 10px × 10px]               │    │ 🔒 Background    │ │
│                │                                             │    │ 👁 Rectangle     │ │
│                │                                             │    │ 👁 Bezier Path ● │ │
│                │                                             │    │ 👁 Logo          │ │
│                └─────────────────────────────────────────────┘    │ + Add Layer      │ │
│                                                                    └──────────────────┘ │
│                                                                                         │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ Status Bar:                                                                              │
│ Cursor: (540, 320)  |  Selection: 2 objects  |  Artboard: 1920×1080  |  FPS: 60       │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- `●` indicates active tool (Pen tool in example)
- `🔴 Alice` = Collaborator presence indicator (red avatar)
- `🟢 Bob` = Collaborator presence indicator (green avatar)
- Blue handles = Selection transform controls
- Snap guide = Temporary alignment helper (Shift+drag)
- Grid overlay = Optional grid (toggleable)

---

## 3. Component Inventory

<!-- anchor: wireframe-artboard-window-components -->

| Component | Location | Primary States | Key Interactions | Route/Code Reference |
|-----------|----------|----------------|------------------|----------------------|
| **WindowFrame** | Top chrome | focused, unfocused, fullscreen | Window controls, zoom display | `ArtboardWindowTemplate` |
| **Toolbar** | Below title bar | default, tool-active, disabled | Tool select, viewport controls, view options | Section 6 component list |
| **ToolShelf** | Left dock | collapsed, expanded, floating | Tool selection, shortcuts | Section 6: Tool shelf |
| **Canvas** | Center | idle, tool-active, panning, selecting | Pointer events, zoom, pan | `RenderingPipeline` |
| **InspectorPanel** | Right dock | collapsed, expanded, floating | Property editing, layer management | `app://inspector/:docId/:artboardId` |
| **SelectionHandles** | Canvas overlay | hidden, visible, dragging | Transform resize, rotate, anchor edit | `InteractionEngine` |
| **SnapGuides** | Canvas overlay | hidden, visible | Alignment feedback during drag | FR-028 |
| **GridOverlay** | Canvas underlay | hidden, visible, adjustable | Visual alignment aid | Toolbar grid toggle |
| **PresenceAvatars** | Canvas overlay (top-right) | empty, 1+ collaborators | Live cursor tracking, name display | `PresenceAvatarRow` |
| **LiveCursorBadge** | Canvas overlay (follows pointer) | hidden, visible | Remote collaborator cursor tracking | `LiveCursorBadge` |
| **StatusBar** | Bottom | default, performance-overlay | Info display, cursor position, FPS | Section 6 |
| **FloatingPalette** | Detachable overlay | hidden, docked, floating | Quick color, tool, selection access | `FloatingPalette` |

---

## 4. State Matrix

<!-- anchor: wireframe-artboard-window-states -->

### 4.1 Tool States

| Tool | Visual Indicators | Cursor | Canvas Behavior | Keyboard Shortcut | Code Reference |
|------|-------------------|--------|-----------------|-------------------|----------------|
| **Select (Arrow)** | Tool shelf highlighted, selection handles visible | Arrow pointer | Click selects, drag moves, handles transform | V | `ToolingFramework.selectTool` |
| **Hand (Pan)** | Tool shelf highlighted, hand cursor | Open hand | Drag pans viewport, scroll wheel zooms | H / Space | `ToolingFramework.panTool` |
| **Pen** | Tool shelf highlighted, anchor points visible | Crosshair + pen | Click adds anchor, drag creates bezier | P | Journey 2, FR-024 |
| **Shape (Rectangle)** | Tool shelf highlighted, preview outline | Crosshair | Click-drag creates rectangle | R | `ToolingFramework.rectTool` |
| **Shape (Oval)** | Tool shelf highlighted, preview outline | Crosshair | Click-drag creates oval | O | `ToolingFramework.ovalTool` |
| **Direct Selection** | Anchors visible per FR-024, anchor handles | Arrow + box | Click anchor to edit, drag to move | A | Flow D |
| **Zoom** | Magnifier cursor | Magnifier | Click to zoom in, Alt+click to zoom out | Z | `ToolingFramework.zoomTool` |

### 4.2 Canvas Interaction States

| State | Visual Changes | Behavior | Accessibility | Code Reference |
|-------|----------------|----------|---------------|----------------|
| **Idle** | Default cursor, no overlays | Awaiting pointer input | `aria-label="Artboard canvas"` | `InteractionEngine.idle` |
| **Hovering Object** | Highlight outline, cursor changes to pointer | Shows hover state, click to select | `aria-label="[Object type]"` announced | `InteractionEngine.hover` |
| **Dragging Object** | Object follows cursor, snap guides appear (Shift) | Live transform, constrained by modifiers | `aria-live="polite"` position updates | Flow D |
| **Dragging Anchor** | Anchor follows cursor, bezier handles update, snap guides | Live path edit, sampled positions recorded | Position updates announced | Flow D, FR-028 |
| **Multi-Select** | Multiple selection outlines, transform handles on bounds | Group transform operations | `aria-label="N objects selected"` | `InteractionEngine.multiSelect` |
| **Panning** | Hand cursor, canvas moves with drag | Viewport translation, no object interaction | Silent (viewport change) | `ToolingFramework.pan` |
| **Zooming (Scroll)** | Canvas scales at cursor anchor | Pinch-to-zoom or scroll wheel | Zoom level announced | `ToolingFramework.zoom` |
| **Snapping Active (Shift)** | Yellow snap guide lines overlay canvas | Objects/anchors snap to 10px grid in screen space | "Snapped to grid" announcement | FR-028 |
| **Collaboration Active** | Presence avatars visible, live cursors | Remote edits merge via OT, cursors tracked | "User [name] joined" announcement | Flow D, Journey I |

### 4.3 Inspector Panel States

| State | Visual Changes | Behavior | Accessibility |
|-------|----------------|----------|---------------|
| **No Selection** | Properties section grayed out, "No selection" placeholder | Read-only | `aria-disabled="true"` |
| **Single Object Selected** | Properties editable, layer highlighted | Edit position, size, fill, stroke | `aria-label="Properties for [object]"` |
| **Multi-Object Selected** | Shared properties editable, differing properties show "—" | Bulk edit, mixed values indicated | `aria-label="Properties for N objects"` |
| **Layer Reordering** | Drag handle visible, drop zone indicator | Drag layer to reorder z-index | `aria-grabbed="true"` during drag |

---

## 5. Interaction Flows

<!-- anchor: wireframe-artboard-window-interactions -->

### 5.1 Core Interactions

| User Action | System Response | Requirements | Journey Reference | Code Path |
|-------------|-----------------|--------------|-------------------|-----------|
| **Open Artboard from Navigator** | Window opens, viewport restored, selection cleared | FR-031, NFR-PERF-002 | Flow C | `NavigatorService.openArtboardWindow()` → `RenderingPipeline.render()` |
| **Select Tool from Shelf** | Tool activates, cursor changes, toolbar updates | — | — | `ToolShelf.onToolSelect()` → `ToolingFramework.activateTool()` |
| **Click Object (Select Tool)** | Object selected, handles appear, inspector updates | — | Journey A | `InteractionEngine.onPointerDown()` → `SelectionService.select()` |
| **Drag Object** | Object moves with cursor, snap guides if Shift held | FR-028 | Journey A | `InteractionEngine.onPointerMove()` → `EventStoreService.record(object.moved)` |
| **Drag Anchor (Pen/Direct)** | Anchor moves, bezier handles update, path redraws | FR-024 | Flow D | `InteractionEngine.beginAnchorDrag()` → `EventStoreService.record(path.anchor.moved)` |
| **Shift+Drag Anchor** | Anchor snaps to 10px screen-space grid, guide shows | FR-028 | Flow D | `InteractionEngine.enforceScreenSpaceSnap()` → `RenderingPipeline.drawSnapGuide()` |
| **Cmd+Z (Undo)** | Last event reversed, canvas redraws, inspector updates | — | — | `ToolingFramework.undo()` → `ReplayService.rewind()` |
| **Cmd+Shift+Z (Redo)** | Next event replayed, canvas redraws | — | — | `ToolingFramework.redo()` → `ReplayService.forward()` |
| **Scroll Wheel** | Canvas zooms at cursor position | — | — | `InteractionEngine.onScroll()` → `ViewportService.zoom()` |
| **Space+Drag** | Canvas pans (hand tool temporary) | — | — | `InteractionEngine.onKeyDown(space)` → `ToolingFramework.tempPan()` |
| **Cmd+0** | Zoom to 100% | — | — | `ToolingFramework.zoomReset()` |
| **Cmd+1** | Zoom to fit artboard in window | — | — | `ToolingFramework.zoomFit()` |
| **Tab Key** | Toggle Inspector panel | — | Route `app://inspector` | `WindowFrame.toggleInspector()` |
| **Grid Toggle (Toolbar)** | Grid overlay shows/hides 10px grid | — | — | `ToolingFramework.toggleGrid()` |
| **Color Picker (Inspector)** | Floating color picker, apply to selection fill | — | — | `InspectorPanel.colorPicker()` → `StyleService.applyFill()` |
| **Layer Drag (Inspector)** | Reorder z-index, canvas updates | — | — | `InspectorPanel.reorderLayer()` → `EventStoreService.record(layer.reordered)` |
| **Presence Avatar Click** | Focus on collaborator cursor, follow mode | FR-050 | Journey I | `PresenceAvatarRow.onClick()` → `CollaborationGateway.focusUser()` |

### 5.2 Tool-Specific Workflows

#### Pen Tool (Journey 2)

| Step | User Action | System Response | Code Reference |
|------|-------------|-----------------|----------------|
| 1 | Select Pen tool (P) | Cursor changes to crosshair, anchors visible per FR-024 | `ToolingFramework.activateTool("pen")` |
| 2 | Click canvas | Create first anchor, path starts | `InteractionEngine.onPointerDown()` → `EventStoreService.record(path.started)` |
| 3 | Click second point | Create second anchor, line segment drawn | `EventStoreService.record(path.anchor.added)` |
| 4 | Drag third point | Create bezier anchor, handles appear | `InteractionEngine.onPointerMove()` → bezier calculation |
| 5 | Release drag | Anchor finalizes, sampled path recorded | `EventStoreService.record(path.anchor.moved end)` |
| 6 | Shift+drag anchor | Snap to 10px grid, guide shows | FR-028, Flow D |
| 7 | Close path (click first anchor) | Path completes, fill applied | `EventStoreService.record(path.closed)` |

#### Direct Selection (Flow D)

| Step | User Action | System Response | Code Reference |
|------|-------------|-----------------|----------------|
| 1 | Select object with pen path | Object selected, anchors visible per anchor visibility mode | `SelectionService.select()` |
| 2 | Click anchor | Anchor selected, bezier handles appear | `InteractionEngine.selectAnchor()` |
| 3 | Drag anchor | Anchor moves, path updates live, samples recorded | Flow D, `EventStoreService.record(path.anchor.moved sample)` |
| 4 | Hold Shift | Snap to 10px screen-space grid, yellow guide shows | FR-028, `InteractionEngine.enforceScreenSpaceSnap()` |
| 5 | Release drag | Anchor finalizes, event persisted, OT broadcast | `CollaborationGateway.submitEvent()` |

---

## 6. Responsive Variants

<!-- anchor: wireframe-artboard-window-responsive -->

### 6.1 Compact Mode (Window Width < 1200px)

```
┌────────────────────────────────────────────────┐
│ Home Screen - Campaign              ◯ □ ⨯     │
├────────────────────────────────────────────────┤
│ [↖][✋][🖊][□][○][↩️][↪️] [⋮] 100% [⊞]       │
├────────────────────────────────────────────────┤
│                                                │
│  🔧         Canvas Area             📋        │
│  (Icon)   (Full Width)            (Float)     │
│                                                │
│  [Tools    ┌──────────────────┐               │
│   Float]   │ [Artboard]       │  [Inspector   │
│            │                  │   Hidden,     │
│            │                  │   Tab to      │
│            │  [Objects]       │   Toggle]     │
│            │                  │               │
│            │                  │               │
│            └──────────────────┘               │
│                                                │
├────────────────────────────────────────────────┤
│ 540, 320  |  2 objects  |  60 FPS             │
└────────────────────────────────────────────────┘
```

**Changes:**
- Tool shelf collapses to floating palette (🔧 icon to open)
- Inspector auto-hides, Tab key toggles overlay
- Toolbar actions collapse to hamburger (⋮)
- Status bar abbreviated
- Canvas maximized to full width

### 6.2 Floating Palette Mode

```
┌────────────────────────────────────────────────┐
│ Artboard Window                                │
│                                                │
│  ┌─────────┐         Canvas                   │
│  │ Tools   │                                   │
│  │ ────    │       ┌──────────────┐           │
│  │ [↖][✋]│       │              │           │
│  │ [🖊][□]│       │  [Artboard]  │           │
│  │ [○][✏️]│       │              │           │
│  └─────────┘       └──────────────┘           │
│                                                │
│                    ┌─────────────┐            │
│                    │ Inspector   │            │
│                    │ ────────    │            │
│                    │ Properties  │            │
│                    │ ...         │            │
│                    └─────────────┘            │
└────────────────────────────────────────────────┘
```

**Behavior:**
- Tool shelf and Inspector can be dragged off dock
- Floating palettes stay on top, semi-transparent
- Double-click title bar to re-dock
- User preference persisted per document

---

## 7. Keyboard Shortcuts

<!-- anchor: wireframe-artboard-window-shortcuts -->

### 7.1 Tool Selection

| Key | Tool | Context | Code Reference |
|-----|------|---------|----------------|
| **V** | Select (Arrow) | Artboard focused | `ToolingFramework.activateTool("select")` |
| **H** | Hand (Pan) | Artboard focused | `ToolingFramework.activateTool("hand")` |
| **P** | Pen | Artboard focused | `ToolingFramework.activateTool("pen")` |
| **A** | Direct Selection | Artboard focused | `ToolingFramework.activateTool("directSelect")` |
| **R** | Rectangle | Artboard focused | `ToolingFramework.activateTool("rectangle")` |
| **O** | Oval | Artboard focused | `ToolingFramework.activateTool("oval")` |
| **Z** | Zoom | Artboard focused | `ToolingFramework.activateTool("zoom")` |
| **Space (Hold)** | Temporary Hand | Any tool active | `ToolingFramework.tempPan()` |

### 7.2 Viewport Controls

| Key Combination | Action | Context | Code Reference |
|-----------------|--------|---------|----------------|
| **Cmd/Ctrl+Plus** | Zoom in | Artboard focused | `ViewportService.zoomIn()` |
| **Cmd/Ctrl+Minus** | Zoom out | Artboard focused | `ViewportService.zoomOut()` |
| **Cmd/Ctrl+0** | Zoom to 100% | Artboard focused | `ViewportService.zoomReset()` |
| **Cmd/Ctrl+1** | Zoom to fit artboard | Artboard focused | `ViewportService.zoomFit()` |
| **Cmd/Ctrl+2** | Zoom to selection | Selection active | `ViewportService.zoomToSelection()` |
| **Scroll Wheel** | Zoom at cursor | Artboard focused | `ViewportService.zoom()` |
| **Space+Drag** | Pan canvas | Artboard focused | `ViewportService.pan()` |

### 7.3 Editing & Selection

| Key Combination | Action | Context | Code Reference |
|-----------------|--------|---------|----------------|
| **Cmd/Ctrl+Z** | Undo | Artboard focused | `ToolingFramework.undo()` |
| **Cmd/Ctrl+Shift+Z** | Redo | Artboard focused | `ToolingFramework.redo()` |
| **Cmd/Ctrl+C** | Copy selection | Selection active | `ClipboardService.copy()` |
| **Cmd/Ctrl+V** | Paste | Artboard focused | `ClipboardService.paste()` |
| **Cmd/Ctrl+X** | Cut selection | Selection active | `ClipboardService.cut()` |
| **Cmd/Ctrl+D** | Duplicate selection | Selection active | `SelectionService.duplicate()` |
| **Delete/Backspace** | Delete selection | Selection active | `SelectionService.delete()` |
| **Cmd/Ctrl+A** | Select all objects | Artboard focused | `SelectionService.selectAll()` |
| **Cmd/Ctrl+Shift+A** | Deselect all | Artboard focused | `SelectionService.deselectAll()` |
| **Tab** | Toggle Inspector panel | Artboard focused | `WindowFrame.toggleInspector()` |
| **Shift+Tab** | Toggle Tool shelf | Artboard focused | `WindowFrame.toggleToolShelf()` |

### 7.4 Modifier Keys

| Key | Modifier Effect | Context | Requirement |
|-----|----------------|---------|-------------|
| **Shift** | Screen-space snap to 10px grid | Dragging object/anchor | FR-028 |
| **Cmd/Ctrl** | Toggle selection (multi-select) | Clicking object | — |
| **Alt/Option** | Duplicate while dragging | Dragging object | — |
| **Shift+Drag** | Constrain aspect ratio | Resizing object | — |
| **Cmd+Drag** | Ignore snapping | Dragging with snap enabled | — |

### 7.5 Inspector & Layers

| Key Combination | Action | Context | Code Reference |
|-----------------|--------|---------|----------------|
| **Cmd/Ctrl+]** | Move layer up (forward) | Layer selected | `InspectorPanel.moveLayerUp()` |
| **Cmd/Ctrl+[** | Move layer down (backward) | Layer selected | `InspectorPanel.moveLayerDown()` |
| **Cmd/Ctrl+Shift+]** | Move layer to front | Layer selected | `InspectorPanel.moveLayerToFront()` |
| **Cmd/Ctrl+Shift+[** | Move layer to back | Layer selected | `InspectorPanel.moveLayerToBack()` |
| **Cmd/Ctrl+G** | Group selected objects | Multi-select | `SelectionService.group()` |
| **Cmd/Ctrl+Shift+G** | Ungroup | Group selected | `SelectionService.ungroup()` |

---

## 8. Accessibility Notes

<!-- anchor: wireframe-artboard-window-a11y -->

### 8.1 ARIA Roles & Semantic Structure

| Component | ARIA Role | Key Attributes | Screen Reader Behavior |
|-----------|-----------|----------------|------------------------|
| **ArtboardWindow** | `window` | `aria-label="Artboard: [name]"` | Announces artboard context on focus |
| **Canvas** | `img` or `application` | `aria-label="Vector canvas"`, `role="application"` for tool interactions | Announces tool mode, selection changes |
| **ToolShelf** | `toolbar` | `aria-label="Drawing tools"` | Announces tool selection |
| **ToolButton** | `button` | `aria-label="[Tool name] tool"`, `aria-pressed="true/false"` | Active tool announced |
| **SelectionHandles** | `button` | `aria-label="Resize handle [direction]"` | Handle direction announced |
| **InspectorPanel** | `complementary` | `aria-label="Object properties"` | Property changes announced |
| **PropertyField** | `textbox` or `spinbutton` | `aria-label="[Property] value"` | Current value announced |
| **LayerList** | `tree` | `aria-label="Layer hierarchy"` | Layer name, visibility, lock state |
| **LayerItem** | `treeitem` | `aria-selected`, `aria-expanded` | Selection and hierarchy state |
| **StatusBar** | `status` | `aria-live="polite"` | Cursor position, selection updates |
| **SnapGuide** | `img` | `aria-live="assertive"`, `aria-label="Snapped to grid"` | Snap event announced |

### 8.2 Keyboard Navigation

**Canvas Focus:**
- Tab enters canvas from toolbar
- Tool shortcuts (V, H, P, etc.) available when canvas focused
- Arrow keys move selected object(s) by 1px (Shift+arrow = 10px)
- Selection navigable via Tab within canvas (cycles through objects)

**Inspector Navigation:**
- Tab cycles through property fields
- Enter/Space activates color picker, dropdowns
- Arrow keys adjust numeric spinners

**Layer Panel Navigation:**
- Arrow keys navigate tree (up/down)
- Left/Right collapse/expand groups
- Space toggles visibility
- Enter renames layer (inline edit)

### 8.3 Focus Management

**Focus Order:**
1. Toolbar (left to right)
2. Tool shelf (top to bottom)
3. Canvas (application region)
4. Inspector panel fields (top to bottom)
5. Layer list (tree order)
6. Status bar controls

**Focus Indicators:**
- Blue 2px outline on focused elements
- High-contrast mode: 4px dashed outline
- Canvas tool cursor changes indicate focus state

**Focus Restoration:**
- Opening Inspector returns focus to last focused field
- Closing dialog returns focus to canvas
- Tool switch maintains canvas focus

### 8.4 Screen Reader Support

**Live Region Announcements:**
- Tool selection: "Pen tool activated"
- Object selection: "Rectangle selected, X: 240, Y: 120, Width: 180, Height: 60"
- Multi-select: "2 objects selected"
- Drag start: "Dragging Rectangle"
- Snap event: "Snapped to grid at Y: 120"
- Property change: "Width changed to 200 pixels"
- Collaboration: "Alice joined artboard", "Bob is editing [object name]"
- Undo/redo: "Undo path anchor moved", "Redo object created"

**Descriptive Labels:**
- All tools have descriptive `aria-label`
- Selection handles labeled by direction ("Top-left resize handle")
- Color swatches include hex value in label
- Layer visibility toggles announce state

### 8.5 Contrast & Visual Accessibility

- All text meets WCAG 2.1 AA contrast (4.5:1)
- Selection handles use blue (#0066CC) with 3:1 contrast against canvas
- Snap guides use yellow (#FFCC00) with high contrast
- Focus indicators remain visible in all themes
- Presence avatars use distinct, high-contrast colors

### 8.6 Alternative Interaction Modes

**Touch Mode:**
- Touch targets minimum 44×44 px
- Long-press triggers context menu
- Two-finger pinch for zoom
- Two-finger drag for pan
- Direct selection requires tap-and-hold

**Voice Control:**
- Tool selection: "Click Pen tool", "Click Select tool"
- Object selection: "Select [layer name]"
- Property editing: "Set width to 200"
- Viewport: "Zoom to fit", "Reset zoom"

---

## 9. Screen-Space Snapping (FR-028)

<!-- anchor: wireframe-artboard-window-snapping -->

### 9.1 Snapping Behavior

**Activation:**
- Hold Shift key while dragging object or anchor
- Snaps to 10px grid in screen space (not artboard space)
- Visual feedback: Yellow guide lines overlay canvas

**Snap Targets:**
- Horizontal guides: Y coordinate snaps to nearest 10px
- Vertical guides: X coordinate snaps to nearest 10px
- Corner snaps: Both X and Y snap simultaneously
- Guide lines extend across visible canvas

**Visual Indicators:**
```
Canvas with snap guide:

    ┌────────────────────────────────┐
    │                                │
    │   ┌────────┐                   │
    │   │ Object │ ← dragging        │
    │   └────────┘                   │
    │━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ ← Yellow snap guide (Y=120px)
    │                                │
    │                                │
    └────────────────────────────────┘
```

**Implementation:**
- `InteractionEngine.enforceScreenSpaceSnap(step=10px)` per Flow D
- `RenderingPipeline.drawSnapGuide()` renders guide overlay
- Guides persist until drag completes or Shift released

**Accessibility:**
- `aria-live="assertive"` announces "Snapped to grid at Y: 120"
- Haptic feedback on snap (desktop trackpad)

---

## 10. Anchor Visibility Modes (FR-024)

<!-- anchor: wireframe-artboard-window-anchors -->

### 10.1 Visibility Modes

| Mode | When Anchors Visible | Use Case | Setting Location |
|------|---------------------|----------|------------------|
| **Always** | All path anchors always visible | Precision editing, teaching mode | Settings → Canvas → Anchors |
| **On Selection** | Only selected object's anchors | Default, reduces clutter | Settings → Canvas → Anchors |
| **On Hover** | Hovered object's anchors | Quick preview without selection | Settings → Canvas → Anchors |
| **Never (Tool Only)** | Only when Pen/Direct Selection tool active | Minimal UI, large artboards | Settings → Canvas → Anchors |

**Current Mode Indicator:**
- Status bar shows "Anchors: [Mode]"
- Toolbar eye icon (👁) with dropdown to change mode

**Visual Representation:**
```
Anchor display (On Selection mode):

  Unselected Path:        Selected Path:
  ───────────────         •─────────•
       (no anchors)       │ Anchors │
                          │ visible │
                          •─────────•
```

**Implementation:**
- `RenderingPipeline.applyAnchorVisibility(documentPref)` per Flow C
- Persisted via `SettingsService` per document
- Referenced in Flow D anchor drag sequence

---

## 11. Collaboration Overlay

<!-- anchor: wireframe-artboard-window-collaboration -->

### 11.1 Presence Indicators

```
Canvas with collaboration overlay:

┌────────────────────────────────────────────┐
│                            🔴 Alice   🟢 Bob│ ← Presence avatars
│                            (Online)   (Typing)
│   ┌──────────────────────────┐             │
│   │ [Artboard]               │             │
│   │                          │             │
│   │   🔴 Alice               │             │ ← Live cursor badge
│   │   [Using Pen Tool]       │             │    follows pointer
│   │      ↓                   │             │
│   │   [Editing path...]      │             │
│   │                          │             │
│   │               🟢 Bob     │             │
│   │               [Moving Rectangle]       │
│   │                  ↓       │             │
│   │              [Object]    │             │
│   │                          │             │
│   └──────────────────────────┘             │
│                                            │
│ [Latency: 45ms ●●●○○]                     │ ← Latency indicator
└────────────────────────────────────────────┘
```

**Components:**
1. **PresenceAvatarRow** (top-right): List of collaborators, click to focus on their cursor
2. **LiveCursorBadge** (follows pointer): Name + tool/action label
3. **LatencyIndicator** (bottom-left): Network latency, color-coded (green < 100ms, yellow < 300ms, red > 300ms)

**Behavior:**
- Avatars appear when user joins (Journey I)
- Live cursors throttled to 10 updates/sec to reduce bandwidth
- Remote selections highlighted with collaborator color (blue, red, green, etc.)
- Local user's cursor/selection uses primary blue

**Implementation:**
- `CollaborationGateway.broadcast(selection.sync)` per Flow D
- `PresenceOverlay` component from Section 6
- OT conflict resolution in `CollaborationGateway.applyOTTransform()`

### 11.2 Conflict Resolution Banner

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠️ Conflict Detected                                 [×]     │
│ Alice and you edited the same object simultaneously.         │
│ [View Diff]  [Accept Theirs]  [Keep Mine]  [Merge]          │
└──────────────────────────────────────────────────────────────┘
```

**Triggers:**
- OT transformation fails to reconcile concurrent edits
- Banner appears as overlay at top of canvas

**Actions:**
- **View Diff:** Shows side-by-side comparison
- **Accept Theirs:** Apply remote change, discard local
- **Keep Mine:** Force local change, notify collaborator
- **Merge:** Attempt manual resolution (opens dialog)

**Implementation:**
- `ConflictResolutionBanner` component per Section 6
- Triggered by `CollaborationGateway` when `ot.conflict` detected
- Route: `app://collaboration/conflict`

---

## 12. Inspector Panel Specification

<!-- anchor: wireframe-artboard-window-inspector -->

### 12.1 Properties Section

```
┌──────────────────────────────────┐
│ Properties                       │
│ ──────────────────────────────── │
│                                  │
│ Transform                        │
│  X:  [240.5  ] px                │
│  Y:  [120.0  ] px                │
│  W:  [180    ] px  🔗 (locked)  │
│  H:  [60     ] px                │
│  R:  [0      ] °                 │
│                                  │
│ ──────────────────────────────── │
│                                  │
│ Fill                             │
│  [████] #FF5733  [Eyedropper]    │
│  Opacity: [100] %                │
│                                  │
│ Stroke                           │
│  [    ] None     [Add Stroke]    │
│                                  │
│ ──────────────────────────────── │
│                                  │
│ Effects                          │
│  + Add Shadow                    │
│  + Add Blur                      │
│                                  │
│ ──────────────────────────────── │
│                                  │
│ [Apply]  [Reset]                 │
└──────────────────────────────────┘
```

**Field Behaviors:**
- Numeric fields: Click to edit, arrow keys ±1, Shift+arrow ±10
- Color swatch: Click opens color picker
- Lock icon (🔗): Maintains aspect ratio for W/H
- Apply button: Commits changes to EventStore
- Reset: Reverts to last committed state

### 12.2 Layers Section

```
┌──────────────────────────────────┐
│ Layers                           │
│ ──────────────────────────────── │
│                                  │
│ 🔒 Background           👁       │
│ ▼ Group 1               👁       │
│   ├─ Rectangle          👁  ●    │
│   └─ Bezier Path        👁       │
│ Logo                    👁       │
│                                  │
│ [+ Add Layer]                    │
└──────────────────────────────────┘
```

**Icons:**
- **🔒** = Locked layer (no editing)
- **👁** = Visibility toggle
- **●** = Currently selected
- **▼** = Expanded group
- **▶** = Collapsed group

**Interactions:**
- Click layer to select
- Drag layer to reorder z-index
- Right-click for context menu (Rename, Duplicate, Delete, Lock, Hide)
- Double-click to rename (inline edit)

**Implementation:**
- `InspectorPanel` component per Section 6
- Route: `app://inspector/:docId/:artboardId`
- Triggered by Tab key or toolbar icon

---

## 13. Error States

<!-- anchor: wireframe-artboard-window-errors -->

### 13.1 Render Failure

```
┌────────────────────────────────────────────┐
│ Artboard: Dashboard - Campaign        ⨯   │
├────────────────────────────────────────────┤
│                                            │
│          ⚠️                                │
│                                            │
│     Failed to render artboard              │
│                                            │
│     Error: GPU memory exceeded             │
│     Objects: 12,453 / Limit: 10,000        │
│                                            │
│     [Simplify Objects]  [View Details]     │
│                                            │
└────────────────────────────────────────────┘
```

### 13.2 Collaboration Disconnect

```
┌────────────────────────────────────────────┐
│ ⚠️ Connection Lost                    [×] │
│ Collaboration session disconnected.        │
│ Your changes are saved locally.            │
│ [Reconnect]  [Work Offline]                │
└────────────────────────────────────────────┘
```

**Banner appears as overlay when WebSocket disconnects**

---

## 14. Performance Overlay (Dev Mode)

<!-- anchor: wireframe-artboard-window-performance -->

```
┌─────────────────────┐
│ Performance         │
│ ─────────────────── │
│ FPS: 60.0           │
│ Frame Time: 16.3 ms │
│ Objects: 142        │
│ Draw Calls: 8       │
│ Memory: 45 MB       │
│ Event Queue: 3      │
│ OT Latency: 42 ms   │
└─────────────────────┘
```

**Activation:**
- Ctrl+Alt+P or View → Performance Overlay
- Docked panel (right) or floating palette
- Real-time metrics updated every frame

**Route:** `app://performance`

---

## 15. Cross-References

<!-- anchor: wireframe-artboard-window-cross-refs -->

**Related Wireframes:**
- [Navigator Window](./navigator.md) - Opens artboard windows
- [History Replay](./history_replay.md) - Shares event timeline with artboard
- [Collaboration Panel](./collaboration_panel.md) - Overlay components detailed here

**Related Architecture:**
- [Section 6.3.1 Route Definitions](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md#section-3-1) - `app://artboard/:docId/:artboardId`
- [Flow D: Direct Selection Drag](../../.codemachine/artifacts/architecture/03_Behavior_and_Communication.md) - Anchor editing sequence
- [Journey 2: Direct Selection](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md) - Pen tool workflow
- [Section 6.2 Component Catalog](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md) - Tool shelf, Inspector, Canvas components

**Related Code:**
- `packages/app/lib/modules/tooling/tooling_framework.dart` - Tool activation and switching
- `packages/app/lib/modules/interaction/interaction_engine.dart` - Pointer events, drag handling
- `packages/app/lib/modules/viewport/viewport_service.dart` - Zoom, pan, state persistence
- `packages/core/lib/services/rendering_pipeline.dart` - Canvas rendering, snap guides

**Related Requirements:**
- FR-024: Anchor visibility modes
- FR-028: Screen-space snapping with Shift
- FR-031: Open artboard from Navigator
- FR-050: Collaboration adoption
- NFR-PERF-002: Viewport restoration

---

## 16. Design Tokens Reference

<!-- anchor: wireframe-artboard-window-tokens -->

**Colors:**
- Selection handles: `--color-primary` (Blue #0066CC)
- Snap guides: `--color-warning` (Yellow #FFCC00)
- Grid overlay: `--color-border-light` (Gray #E0E0E0)
- Presence avatars: `--color-collab-[user]` (Red #FF4444, Green #44FF44, Blue #4444FF)
- Canvas background: `--color-canvas` (Light gray #F5F5F5)

**Spacing:**
- Tool shelf button: `48×48 px`
- Inspector field height: `32px`
- Status bar height: `28px`
- Toolbar height: `48px`

**Typography:**
- Status bar: `--font-caption` 11px
- Inspector labels: `--font-body` 13px
- Inspector values: `--font-mono` 13px

**Shadows:**
- Floating palette: `0 4px 16px rgba(0,0,0,0.2)`
- Context menu: `0 2px 8px rgba(0,0,0,0.15)`

**Reference:** `docs/ui/tokens.md`

---

## 17. Implementation Checklist

<!-- anchor: wireframe-artboard-window-checklist -->

- [ ] Artboard window shell with toolbar, canvas, docks
- [ ] Tool shelf with V/H/P/A/R/O/Z tools
- [ ] Canvas pointer event handling (InteractionEngine)
- [ ] Selection transform handles
- [ ] Snap guide rendering (Shift+drag, FR-028)
- [ ] Anchor visibility modes (FR-024)
- [ ] Inspector panel (properties, layers)
- [ ] Viewport zoom/pan/fit controls
- [ ] Undo/redo integration with ReplayService
- [ ] Collaboration overlay (presence, live cursors)
- [ ] Conflict resolution banner
- [ ] Keyboard shortcuts (V/H/P/A/R/O/Z, Cmd+Z, etc.)
- [ ] Accessibility (ARIA, keyboard nav, screen reader)
- [ ] Responsive variants (compact, floating palettes)
- [ ] Performance overlay (dev mode)
- [ ] Error state handling (render failure, disconnect)

---

## 18. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-11 | 1.0 | Initial wireframe creation for I3.T4 | DocumentationAgent |

---

**End of Artboard Window Wireframe Specification**
