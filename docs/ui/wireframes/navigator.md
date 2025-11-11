# Navigator Window Wireframe

<!-- anchor: wireframe-navigator -->

## 1. Overview

The Navigator Window serves as the root window for WireTuner, providing document-level artboard management, multi-artboard selection, thumbnail previews, and quick navigation. It persists even when all artboard windows are closed, maintaining document context across the session.

**Route:** `app://navigator`

**Entry Methods:**
- Application launch (default)
- File → Open
- File → New
- Persists across document lifecycle

**Access Level:** Authenticated user

**Related Journeys:**
- Journey H: Manage Artboards in Navigator
- Flow C: Multi-Artboard Document Load & Navigator Activation

**Related Requirements:**
- FR-029 through FR-045 (Navigator feature set)
- NFR-PERF-001 (Load time < 100ms for 10K events)
- NFR-PERF-002 (Viewport restoration)

---

## 2. Layout Structure

<!-- anchor: wireframe-navigator-layout -->

```
┌────────────────────────────────────────────────────────────────────────────┐
│ WireTuner Navigator                                          ◯ □ ⨯          │
├────────────────────────────────────────────────────────────────────────────┤
│ [Document Tab 1] [Document Tab 2*] [+]                     [🔍] [⚙️] [👤] │
├────────────────────────────────────────────────────────────────────────────┤
│ Toolbar:                                                                    │
│ [+ New Artboard] [Filter ▾] [Sort: Modified ▾] [Grid Size: ●●○○]  [↻]    │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Grid View Area (Virtualized Scroll)                                       │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ [Thumbnail] │  │ [Thumbnail] │  │ [Thumbnail] │  │ [Thumbnail] │     │
│  │             │  │             │  │      ●      │  │             │     │
│  │             │  │             │  │   [DIRTY]   │  │             │     │
│  │ Home Screen │  │ Login Flow  │  │  Dashboard  │  │ Settings    │     │
│  │ 1920×1080   │  │ 375×812     │  │ 1440×900    │  │ 800×600     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ [Thumbnail] │  │ [Thumbnail] │  │ [Thumbnail] │  │ [+ Add New] │     │
│  │   SELECTED  │  │   SELECTED  │  │             │  │             │     │
│  │    (Blue    │  │    (Blue    │  │             │  │             │     │
│  │   Border)   │  │   Border)   │  │             │  │             │     │
│  │ Profile     │  │ Checkout    │  │ Confirm     │  │             │     │
│  │ 375×667     │  │ 375×667     │  │ 375×667     │  │             │     │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │
│                                                                             │
│  [Scroll continues... 50 more artboards]                                   │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ Status Bar:                                                                │
│ 54 artboards • 2 selected • Last refresh: 3s ago           Grid: 4 cols  │
└────────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- `*` indicates active document tab
- `●` indicates dirty state (unsaved changes)
- Blue border indicates selected artboard(s)
- Thumbnail refresh indicator shows time since last update
- Grid size control (4 dots = 4 columns, adjustable 2-6)

---

## 3. Component Inventory

<!-- anchor: wireframe-navigator-components -->

| Component | Location | Primary States | Key Interactions | Implementation Reference |
|-----------|----------|----------------|------------------|--------------------------|
| **WindowFrame** | Top chrome | focused, unfocused, fullscreen | Window controls, tab dragging | `navigator_window.dart` |
| **DocumentTabBar** | Below title bar | empty, single-tab, multi-tab | Tab switch, close (Cmd+W), new (+) | `navigator_window.dart:_buildTabBar()` |
| **NavigatorToolbar** | Below tabs | default, filtering, sorting | New artboard, filter, sort, grid size, refresh | `navigator_window.dart:_buildToolbar()` |
| **ArtboardGrid** | Main content | empty, loading, populated, scrolling | Virtualized scroll, card select, context menu | `navigator_window.dart:_buildGridView()` |
| **ArtboardCard** | Grid item | default, hover, selected, editing, dirty, error | Click, double-click, right-click, rename | `artboard_card.dart` |
| **StatusBar** | Bottom | default, selection-active, syncing | Info display, grid config toggle | `navigator_window.dart:_buildStatusBar()` |
| **ContextMenu** | Overlay | hidden, visible | Rename, Duplicate, Delete, Export, Refresh, Fit | `artboard_card.dart:_showContextMenu()` |
| **NewArtboardDialog** | Modal | hidden, visible, creating | Preset selection, custom dimensions, create/cancel | Route: `app://navigator/new-artboard` |

---

## 4. State Matrix

<!-- anchor: wireframe-navigator-states -->

### 4.1 ArtboardCard States

| State | Visual Indicators | Hover Behavior | Selection Behavior | Accessibility | Code Reference |
|-------|-------------------|----------------|--------------------|--------------|--------------------|
| **Default** | Gray border, white background, thumbnail visible, name + dimensions below | Elevate shadow, show hover overlay | Single-click selects, Cmd+click toggles, Shift+click range | `role="button"`, `aria-label="Artboard [name]"` | `artboard_card.dart:_buildDefault()` |
| **Hover** | Slight elevation, border lightens, cursor pointer | Show context menu icon top-right | Same as default | `aria-haspopup="true"` | `artboard_card.dart:_isHovered` |
| **Selected** | Blue border (2px), blue tint overlay (10% opacity) | Maintain selection, show context menu | Cmd+click deselects, arrow keys navigate | `aria-selected="true"` | `artboard_card.dart:_isSelected` |
| **Editing (Rename)** | Inline text field replaces name, focus ring, blue border | N/A (editing mode) | Maintains selection | `role="textbox"`, `aria-label="Rename artboard"` | `artboard_card.dart:_isEditing` |
| **Dirty** | Orange dot badge top-right, pulsing glow | Same as hover | Same as default | `aria-label="Artboard [name], unsaved changes"` | `artboard_card.dart:_isDirty` |
| **Error** | Red border, error icon overlay, tooltip on hover | Show error message | Same as default | `aria-invalid="true"`, error announcement | `artboard_card.dart:_hasError` |

### 4.2 Navigator Window States

| Condition | Visual Changes | Behavior Changes | Accessibility | Code Reference |
|-----------|----------------|------------------|---------------|----------------|
| **Empty (No Documents)** | Grid shows "Drag file here or File → New" placeholder | Disable toolbar except New | `aria-live="polite"` announcement | `navigator_window.dart:_buildEmptyState()` |
| **Loading Document** | Grid shows skeleton cards, loading spinner | Disable interactions | `aria-busy="true"` | Flow C implementation |
| **Multi-Select Active** | Status bar shows "N selected", Delete/Export enabled | Cmd/Shift click modifiers active | `aria-label="N artboards selected"` | `navigator_provider.dart:selectedArtboards` |
| **Thumbnail Refresh** | Refresh icon spins, status bar updates | Background update, no interaction block | `aria-live="polite"` for completion | `navigator_provider.dart:refreshThumbnails()` |
| **Filter Active** | Toolbar filter button highlighted, grid filtered | Only matching artboards visible | `aria-label="Showing N of M artboards"` | `navigator_provider.dart:filterMode` |
| **Last Document Closed** | Navigator remains open, shows empty state for active tab | Tab bar persists, can switch to other open docs | Focus returns to window | `navigator_window.dart` per spec |

---

## 5. Interaction Flows

<!-- anchor: wireframe-navigator-interactions -->

### 5.1 Core Interactions

| User Action | System Response | Requirements | Journey Reference | Code Path |
|-------------|-----------------|--------------|-------------------|-----------|
| **Launch App** | Navigator opens with last document or empty state | FR-029 | Flow C | `DesktopShell` → `NavigatorService.initialize()` |
| **File → Open** | Navigator tab opens for document, grid populates with artboards | FR-029, NFR-PERF-001 | Flow C | `SecurityGateway.requestFileAccess()` → `EventStoreService.openSQLite()` |
| **Click Artboard Card** | Select artboard (blue border), deselect others | FR-030 | Journey H | `ArtboardCard.onTap()` → `NavigatorProvider.selectArtboard()` |
| **Double-Click Card** | Open artboard window, restore viewport state | FR-031 | Flow C | `ArtboardCard.onDoubleTap()` → `NavigatorService.openArtboardWindow()` |
| **Cmd+Click Card** | Toggle artboard in/out of selection set | FR-032 | Journey H | `ArtboardCard.onTap(cmd=true)` → `NavigatorProvider.toggleSelection()` |
| **Shift+Click Card** | Range-select from last anchor to clicked card | FR-033 | Journey H | `ArtboardCard.onTap(shift=true)` → `NavigatorProvider.rangeSelect()` |
| **Right-Click Card** | Show context menu (Rename, Duplicate, Delete, Export, Refresh, Fit) | FR-034 | Journey H | `ArtboardCard.onSecondaryTap()` → `_showContextMenu()` |
| **Context Menu → Rename** | Enter inline edit mode, focus text field | FR-035 | Journey H | `ContextMenu.rename()` → `ArtboardCard.startEditing()` |
| **Context Menu → Delete** | Confirm dialog, then delete artboard(s) | FR-036 | Journey H | `ContextMenu.delete()` → `NavigatorService.deleteArtboards()` |
| **Context Menu → Duplicate** | Create copy with "(Copy)" suffix, animate insertion | FR-037 | Journey H | `ContextMenu.duplicate()` → `NavigatorService.duplicateArtboards()` |
| **Context Menu → Refresh** | Invalidate thumbnail cache, request re-render | FR-038 | — | `ContextMenu.refresh()` → `NavigatorProvider.refreshThumbnails()` |
| **Toolbar → + New Artboard** | Open new artboard dialog with presets | FR-039 | Journey H | `Toolbar.newArtboard()` → Route `app://navigator/new-artboard` |
| **Toolbar → Filter** | Dropdown filters (By name, dimension, modified, tags) | FR-040 | — | `Toolbar.filter()` → `NavigatorProvider.setFilter()` |
| **Toolbar → Sort** | Dropdown sorts (Name, Modified, Created, Size, Custom) | FR-041 | — | `Toolbar.sort()` → `NavigatorProvider.setSortMode()` |
| **Toolbar → Grid Size** | Adjust columns 2-6, persist preference | FR-042 | — | `Toolbar.gridSize()` → `SettingsService.setGridColumns()` |
| **Toolbar → Refresh** | Refresh all thumbnails (10s cooldown) | FR-043 | — | `Toolbar.refresh()` → `NavigatorProvider.refreshThumbnails()` |
| **Arrow Keys (Selection)** | Navigate grid, select adjacent card | FR-044 | — | `navigator_window.dart:_handleKeyEvent()` → `NavigatorProvider.navigateSelection()` |
| **Delete Key** | Delete selected artboard(s) after confirmation | FR-045 | Journey H | `navigator_window.dart:_handleKeyEvent()` → `NavigatorService.deleteArtboards()` |
| **Cmd+W** | Close active document tab, prompt if dirty | FR-029 | — | `navigator_window.dart:_handleKeyEvent()` → `NavigatorService.closeDocument()` |
| **Auto Thumbnail Refresh** | Every 10s, refresh visible dirty artboards | FR-043 | — | `NavigatorProvider` timer → `refreshThumbnails()` |

### 5.2 Multi-Select Scenarios

| Scenario | Selection Outcome | Visual Feedback | Notes |
|----------|-------------------|-----------------|-------|
| **Click A, Shift+Click E** | Select A, B, C, D, E (range) | All 5 cards show blue border | Range wraps grid rows |
| **Click A, Cmd+Click C, Cmd+Click E** | Select A, C, E (non-contiguous) | 3 cards blue border | Standard multi-select |
| **Select A, Arrow Right** | Deselect A, select B | Focus moves, selection updates | Single-select navigation |
| **Select A+B, Shift+Arrow Right** | Extend to A+B+C | Selection grows | Range-extend mode |
| **Select All (Cmd+A)** | Select all visible artboards | All cards blue border | Filtered artboards only |

---

## 6. Responsive Variants

<!-- anchor: wireframe-navigator-responsive -->

### 6.1 Compact Mode (Window Width < 800px)

```
┌──────────────────────────────────────┐
│ Navigator           ◯ □ ⨯            │
├──────────────────────────────────────┤
│ [Doc1*] [+] [🔍] [⚙️]               │
├──────────────────────────────────────┤
│ [+ New] [⋮] [↻]      Grid: ●●○○     │
├──────────────────────────────────────┤
│                                      │
│  ┌────────┐  ┌────────┐             │
│  │ [Thm]  │  │ [Thm]  │             │
│  │        │  │    ●   │             │
│  │        │  │ [DIRTY]│             │
│  │ Home   │  │ Login  │             │
│  │ 1920×  │  │ 375×   │             │
│  └────────┘  └────────┘             │
│                                      │
│  ┌────────┐  ┌────────┐             │
│  │SELECTED│  │ [Thm]  │             │
│  │ (Blue) │  │        │             │
│  │        │  │        │             │
│  │Profile │  │Settings│             │
│  │ 375×   │  │ 800×   │             │
│  └────────┘  └────────┘             │
│                                      │
├──────────────────────────────────────┤
│ 20 artboards • 1 sel                │
└──────────────────────────────────────┘
```

**Changes:**
- Grid collapses to 2 columns
- Toolbar actions collapse to hamburger menu (⋮)
- Status bar text abbreviated
- Dimensions truncated
- Tabs scrollable horizontally

### 6.2 Wide Mode (Window Width > 1600px)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ [Doc1] [Doc2*] [Doc3] [+]                                          [🔍] [⚙️] [👤]          │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│ [+ New Artboard] [Filter ▾] [Sort: Modified ▾] [Grid Size: ●●●●●○] [↻] [View: Grid ▾]    │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ [Large   │ │ [Large   │ │ [Large   │ │ [Large   │ │ [Large   │ │ [Large   │           │
│  │ Thumb]   │ │ Thumb]   │ │ Thumb]   │ │ Thumb]   │ │ Thumb]   │ │ Thumb]   │           │
│  │ Home     │ │ Login    │ │ Dash     │ │ Settings │ │ Profile  │ │ Checkout │           │
│  │ 1920×1080│ │ 375×812  │ │ 1440×900 │ │ 800×600  │ │ 375×667  │ │ 375×667  │           │
│  │ Modified │ │ Modified │ │ Modified │ │ Modified │ │ Modified │ │ Modified │           │
│  │ 2m ago   │ │ 5m ago   │ │ 8m ago   │ │ 12m ago  │ │ 15m ago  │ │ 20m ago  │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
│                                                                                              │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│ 54 artboards in "Marketing Campaign Q4" • 2 selected • Last refresh: 3s ago  Grid: 6 cols │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Changes:**
- Grid expands to 6 columns
- Larger thumbnails with additional metadata (modified timestamp)
- Document name shown in status bar
- Additional toolbar actions visible (View mode toggle)
- More horizontal space for tab bar

---

## 7. Keyboard Shortcuts

<!-- anchor: wireframe-navigator-shortcuts -->

| Key Combination | Action | Context | Requirement | Implementation |
|-----------------|--------|---------|-------------|----------------|
| **Cmd/Ctrl+N** | New artboard dialog | Navigator focused | FR-039 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+W** | Close active document tab | Navigator focused | FR-029 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+A** | Select all visible artboards | Navigator focused | FR-032 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+D** | Duplicate selected artboard(s) | Selection active | FR-037 | `navigator_window.dart:_handleKeyEvent()` |
| **Delete/Backspace** | Delete selected artboard(s) | Selection active | FR-045 | `navigator_window.dart:_handleKeyEvent()` |
| **Arrow Keys** | Navigate grid selection | Navigator focused | FR-044 | `navigator_window.dart:_handleKeyEvent()` |
| **Shift+Arrows** | Extend range selection | Selection active | FR-033 | `navigator_window.dart:_handleKeyEvent()` |
| **Enter/Return** | Open selected artboard window | Selection active | FR-031 | `navigator_window.dart:_handleKeyEvent()` |
| **F2** | Rename selected artboard | Single selection | FR-035 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+F** | Focus search/filter field | Navigator focused | FR-040 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+R** | Refresh thumbnails | Navigator focused | FR-043 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+Plus** | Increase grid size | Navigator focused | FR-042 | `navigator_window.dart:_handleKeyEvent()` |
| **Cmd/Ctrl+Minus** | Decrease grid size | Navigator focused | FR-042 | `navigator_window.dart:_handleKeyEvent()` |
| **Escape** | Clear selection or cancel edit | Context-dependent | — | `navigator_window.dart:_handleKeyEvent()` |
| **Tab** | Cycle focus through toolbar/grid | Navigator focused | — | Flutter focus traversal |
| **Space** | Toggle selection on focused card | Card focused | FR-032 | `artboard_card.dart` |

**Focus Management:**
- Tab order: Document tabs → Toolbar actions → Grid (first card) → Status bar controls
- Arrow keys navigate within grid only when grid has focus
- Escape returns focus to grid from toolbar/dialogs

---

## 8. Accessibility Notes

<!-- anchor: wireframe-navigator-a11y -->

### 8.1 ARIA Roles & Semantic Structure

| Component | ARIA Role | Key Attributes | Screen Reader Behavior |
|-----------|-----------|----------------|------------------------|
| **NavigatorWindow** | `window` | `aria-label="Navigator - [DocumentName]"` | Announces window context on focus |
| **DocumentTabBar** | `tablist` | `aria-multiselectable="false"` | Tab navigation with arrows |
| **DocumentTab** | `tab` | `aria-selected="true/false"`, `aria-controls="grid-{docId}"` | Selected state announced |
| **ArtboardGrid** | `grid` | `aria-rowcount`, `aria-colcount` | Announces grid dimensions |
| **ArtboardCard** | `button` | `aria-label="Artboard [name], [width]×[height]"`, `aria-selected` | Announces name, dimensions, selected state |
| **ArtboardCard (Dirty)** | `button` | `aria-label="..., unsaved changes"` | Announces dirty state |
| **ArtboardCard (Editing)** | `textbox` | `aria-label="Rename artboard"`, `aria-required="true"` | Edit mode announced |
| **ContextMenu** | `menu` | `aria-haspopup="true"`, `aria-expanded="true/false"` | Menu state announced |
| **ContextMenuItem** | `menuitem` | `aria-label="[Action] artboard"` | Action announced on hover |
| **StatusBar** | `status` | `aria-live="polite"` | Selection changes announced |
| **RefreshIndicator** | `progressbar` | `aria-valuemin="0"`, `aria-valuemax="100"`, `aria-valuenow` | Refresh progress announced |

### 8.2 Keyboard Navigation

**Grid Navigation:**
- Arrow keys move focus between cards (left/right/up/down)
- Home/End jump to first/last card in row
- Ctrl+Home/End jump to first/last card in grid
- Page Up/Down scroll by viewport height

**Selection Announcements:**
- Single select: "Artboard [name] selected"
- Multi-select: "Artboard [name] added to selection, N artboards selected"
- Range select: "Range selected, N artboards selected"
- Deselect: "Artboard [name] deselected, N artboards selected"

**Context Menu:**
- Triggered by right-click or Shift+F10 or Ctrl+Enter
- Arrow keys navigate menu items
- Enter activates item
- Escape closes menu

### 8.3 Focus Management

**Focus Order:**
1. Document tab bar (left to right)
2. Toolbar controls (left to right)
3. Grid (row-major order, top-left to bottom-right)
4. Status bar controls (left to right)

**Focus Indicators:**
- Blue 2px outline on focused elements
- High-contrast mode: 4px dashed outline
- Persistent focus visible even during keyboard navigation

**Focus Restoration:**
- Closing context menu returns focus to triggering card
- Closing dialog returns focus to last focused grid card
- Opening artboard window maintains Navigator focus (multi-window)

### 8.4 Screen Reader Support

**Live Region Announcements:**
- Document load: "Document [name] loaded, N artboards"
- Thumbnail refresh: "Thumbnails refreshed"
- Save completion: "Document saved"
- Artboard deleted: "Artboard [name] deleted, N artboards remaining"
- Filter applied: "Showing N of M artboards"

**Descriptive Labels:**
- All interactive elements have descriptive `aria-label` or visible text
- Icons paired with text or `aria-label`
- Status indicators announced via `aria-live`

### 8.5 Contrast & Visual Accessibility

- All text meets WCAG 2.1 AA contrast ratio (4.5:1 for normal text, 3:1 for large text)
- Selected state visible in high-contrast mode
- Dirty badge uses both color and icon (orange dot + pulsing outline)
- Error state uses both color and icon (red border + X icon)
- Focus indicators remain visible in all color schemes

### 8.6 Responsive Accessibility

- Touch targets minimum 44×44 px (iOS) / 48×48 dp (Android/desktop)
- Compact mode maintains touch target sizes by adjusting spacing
- Context menu items remain tappable in touch mode
- Drag-to-reorder includes keyboard alternative (Ctrl+Shift+Arrow)

---

## 9. Context Menu Specification

<!-- anchor: wireframe-navigator-context-menu -->

```
┌────────────────────────────┐
│ Rename              F2     │
│ Duplicate          Cmd+D   │
├────────────────────────────┤
│ Delete             Del     │
├────────────────────────────┤
│ Export...                  │
│ Refresh Thumbnail          │
├────────────────────────────┤
│ Fit to Window              │
│ Copy as PNG                │
└────────────────────────────┘
```

**Context-Dependent Behavior:**
- If single artboard selected: All actions enabled
- If multiple artboards selected: Rename disabled, others bulk-apply
- If dirty state: "Save" action prepends menu
- If error state: "View Error Details" prepends menu

**Implementation:** `artboard_card.dart:_showContextMenu()`
**Route:** `app://navigator/thumbnail-context`

---

## 10. New Artboard Dialog

<!-- anchor: wireframe-navigator-new-artboard-dialog -->

```
┌──────────────────────────────────────────┐
│ New Artboard                        ⨯   │
├──────────────────────────────────────────┤
│                                          │
│  Presets:                                │
│  ┌────────┐ ┌────────┐ ┌────────┐       │
│  │Desktop │ │ Phone  │ │Tablet  │       │
│  │1920×   │ │ 375×   │ │1024×   │       │
│  │1080    │ │ 812    │ │ 768    │       │
│  └────────┘ └────────┘ └────────┘       │
│                                          │
│  Custom Dimensions:                      │
│  Width:  [1920    ] px                   │
│  Height: [1080    ] px                   │
│                                          │
│  Name:   [Artboard 5          ]          │
│                                          │
│  □ Open in new window after creation     │
│                                          │
│              [Cancel]  [Create]          │
└──────────────────────────────────────────┘
```

**Behavior:**
- Preset click auto-fills dimensions and name
- Custom dimensions validated (min 100×100, max 8192×8192)
- Name defaults to "Artboard N" (auto-incremented)
- Create button submits, animates card insertion into grid
- Triggered by Toolbar "+ New Artboard" or Shift+N

**Route:** `app://navigator/new-artboard`
**Entry:** Toolbar action, keyboard shortcut

---

## 11. Thumbnail Refresh Mechanism

<!-- anchor: wireframe-navigator-thumbnail-refresh -->

**Automatic Refresh:**
- Every 10 seconds, `NavigatorProvider` checks for dirty artboards
- Dirty artboards marked with orange dot badge
- Background worker requests thumbnail re-render from `RenderingPipeline`
- Thumbnail updates in-place with fade transition
- Status bar updates "Last refresh: [time] ago"

**Manual Refresh:**
- Toolbar refresh button (↻) or Cmd+R
- Cooldown: 10 seconds between manual refreshes
- During refresh: Button shows spinner, status bar shows "Refreshing..."
- Context menu "Refresh Thumbnail" forces single-artboard refresh

**Performance:**
- Thumbnails rendered at 256×256 px (retina: 512×512)
- Only visible thumbnails refreshed (virtualized grid)
- Refresh queue processes 5 thumbnails concurrently
- Snapshots used as fallback if artboard window closed

**Code:** `navigator_provider.dart:refreshThumbnails()`
**Requirement:** FR-043

---

## 12. Empty State

<!-- anchor: wireframe-navigator-empty-state -->

```
┌────────────────────────────────────────────────┐
│ Navigator                     ◯ □ ⨯            │
├────────────────────────────────────────────────┤
│ [+]                        [🔍] [⚙️] [👤]      │
├────────────────────────────────────────────────┤
│                                                │
│                                                │
│           📄                                   │
│                                                │
│       No Document Open                         │
│                                                │
│   Drag a .wire file here to open              │
│          or                                    │
│   [File → New Document]                        │
│   [File → Open Document]                       │
│                                                │
│                                                │
│   Recent Documents:                            │
│   • Marketing Campaign Q4.wire                 │
│   • Mobile App Redesign.wire                   │
│   • Client Presentation.wire                   │
│                                                │
│                                                │
├────────────────────────────────────────────────┤
│ No documents                                   │
└────────────────────────────────────────────────┘
```

**Interactions:**
- Drag-drop .wire file onto empty state opens document
- Recent documents clickable (opens in new tab)
- File menu actions remain accessible
- New document button opens new artboard dialog

**Code:** `navigator_window.dart:_buildEmptyState()`

---

## 13. Error States

<!-- anchor: wireframe-navigator-error-states -->

### 13.1 Failed Document Load

```
┌────────────────────────────────────────────────┐
│ Navigator - Failed Document   ◯ □ ⨯            │
├────────────────────────────────────────────────┤
│ [Campaign.wire*] [+]        [🔍] [⚙️] [👤]    │
├────────────────────────────────────────────────┤
│                                                │
│           ⚠️                                   │
│                                                │
│    Failed to load document                     │
│                                                │
│    Error: Corrupted event log at sequence      │
│    12,450. Last valid snapshot: seq 12,000.    │
│                                                │
│    [Recover from Snapshot]  [Close]            │
│                                                │
├────────────────────────────────────────────────┤
│ Error loading document                         │
└────────────────────────────────────────────────┘
```

### 13.2 Thumbnail Render Failure

```
┌─────────────┐
│     ⚠️      │
│ Render      │
│ Failed      │
│             │
│  [Retry]    │
│ Home Screen │
│ 1920×1080   │
└─────────────┘
```

**Behavior:**
- Red border indicates error state
- Hover shows tooltip with error details
- Retry button attempts re-render
- Context menu includes "View Error Details"

---

## 14. Cross-References

<!-- anchor: wireframe-navigator-cross-refs -->

**Related Wireframes:**
- [Artboard Window](./artboard_window.md) - Opened by double-clicking artboard card
- [History Replay](./history_replay.md) - Accessible via Window menu when Navigator focused
- [Collaboration Panel](./collaboration_panel.md) - Shared document state visible in Navigator tabs

**Related Architecture:**
- [Section 6.3.1 Route Definitions](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md#section-3-1) - `app://navigator` route
- [Flow C: Multi-Artboard Document Load](../../.codemachine/artifacts/architecture/03_Behavior_and_Communication.md) - Navigator initialization sequence
- [Journey H: Manage Artboards](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md) - Navigator interaction flows

**Related Code:**
- `packages/app/lib/modules/navigator/navigator_window.dart` - Window shell implementation
- `packages/app/lib/modules/navigator/widgets/artboard_card.dart` - Card component
- `packages/app/lib/modules/navigator/state/navigator_provider.dart` - State management

**Related Requirements:**
- FR-029 through FR-045: Navigator features
- NFR-PERF-001: Document load < 100ms for 10K events
- NFR-PERF-002: Viewport restoration fidelity

---

## 15. Design Tokens Reference

<!-- anchor: wireframe-navigator-tokens -->

**Colors:**
- Selection border: `--color-primary` (Blue #0066CC)
- Dirty badge: `--color-warning` (Orange #FF8800)
- Error border: `--color-error` (Red #CC0000)
- Hover overlay: `--color-overlay-light` (Black 5%)
- Card background: `--color-surface` (White #FFFFFF)
- Border default: `--color-border` (Gray #DDDDDD)

**Spacing:**
- Card gap: `16px`
- Card padding: `12px`
- Thumbnail aspect ratio: `16:10` (artboard dimensions)
- Grid margin: `24px`

**Typography:**
- Artboard name: `--font-body` 14px, weight 500
- Dimensions: `--font-caption` 12px, weight 400
- Status bar: `--font-caption` 12px, weight 400

**Shadows:**
- Card default: `0 1px 3px rgba(0,0,0,0.1)`
- Card hover: `0 4px 12px rgba(0,0,0,0.15)`
- Card selected: `0 2px 8px rgba(0,102,204,0.2)`

**Animations:**
- Thumbnail fade-in: `200ms ease-out`
- Selection transition: `150ms ease-in-out`
- Dirty badge pulse: `1500ms ease-in-out infinite`

**Reference:** `docs/ui/tokens.md`

---

## 16. Implementation Checklist

<!-- anchor: wireframe-navigator-checklist -->

- [x] Navigator window shell with tab bar (`navigator_window.dart`)
- [x] Virtualized artboard grid (`_buildGridView()`)
- [x] Artboard card with states (`artboard_card.dart`)
- [x] Context menu integration
- [x] Keyboard shortcuts (Cmd+W, Delete, arrows)
- [x] Multi-select (Cmd+Click, Shift+Click ranges)
- [x] Thumbnail refresh mechanism (10s timer)
- [x] Status bar with selection count
- [ ] New artboard dialog (route: `app://navigator/new-artboard`)
- [ ] Filter/sort toolbar controls
- [ ] Grid size persistence via `SettingsService`
- [ ] Empty state with drag-drop
- [ ] Error state handling
- [ ] Accessibility testing (screen reader, keyboard-only)
- [ ] Responsive layout testing (compact, wide modes)
- [ ] Telemetry hooks (load time, refresh rate)

---

## 17. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-11 | 1.0 | Initial wireframe creation for I3.T4 | DocumentationAgent |

---

**End of Navigator Wireframe Specification**
