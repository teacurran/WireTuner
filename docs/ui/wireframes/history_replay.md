# History Replay Window Wireframe

<!-- anchor: wireframe-history-replay -->

## 1. Overview

The History Replay Window provides time-travel debugging and review capabilities, allowing users to scrub through document history, play back edits, jump to checkpoints, and inspect event metadata. It leverages checkpoint-based snapshots and event replay for fast seeking across large edit histories.

**Route:** `app://history/:docId`

**Entry Methods:**
- Window → History
- Cmd+Shift+H keyboard shortcut
- Navigator context menu → View History
- Collaboration panel → Session History

**Access Level:** Authenticated user

**Related Journeys:**
- Journey J: History Replay Scrubbing
- Flow C: Multi-Artboard Document Load (checkpoint restoration)

**Related Requirements:**
- FR-027 (History replay requirement)
- NFR-PERF-001 (<100ms load time, checkpoint-based seeking)

---

## 2. Layout Structure

<!-- anchor: wireframe-history-replay-layout -->

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ History: Campaign.wire - Home Screen Artboard                         ◯ □ ⨯             │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ Playback Controls:                                                                       │
│ [◀◀] [◀] [▶] [▶▶] [■]   Speed: [1x ▾]   Checkpoint: [Seq 12000 ▾]   [📍 Set Mark]    │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                           │
│  Preview Pane                                                    Metadata Inspector      │
│  (Artboard State at Selected Sequence)                          (Right Dock)             │
│                                                                                           │
│  ┌─────────────────────────────────────────────┐    ┌──────────────────────────────┐   │
│  │                                             │    │ Event Details                │   │
│  │                                             │    │ ─────────────────────────── │   │
│  │   [Rendered Artboard at Seq 12,345]        │    │ Sequence: 12,345             │   │
│  │                                             │    │ Type: path.anchor.moved      │   │
│  │   ┌────────┐                                │    │ Timestamp: 14:32:15.234      │   │
│  │   │ Object │  ← Added at seq 12,120        │    │ User: Alice                  │   │
│  │   └────────┘                                │    │ Session: collab-xyz-789      │   │
│  │                                             │    │ ─────────────────────────── │   │
│  │      •─────────•                            │    │ Payload:                     │   │
│  │     /  Path    \  ← Edited at seq 12,345   │    │ {                            │   │
│  │    •  (Active) •                            │    │   "anchorId": "a-42",        │   │
│  │     \          /                            │    │   "position": {              │   │
│  │      •─────────•                            │    │     "x": 540.5,              │   │
│  │                                             │    │     "y": 320.0               │   │
│  │                                             │    │   },                         │   │
│  │                                             │    │   "sampledPath": [...]       │   │
│  │                                             │    │ }                            │   │
│  │                                             │    │ ─────────────────────────── │   │
│  │                                             │    │ Related Events:              │   │
│  │                                             │    │ • 12,344 (anchor.selected)   │   │
│  │                                             │    │ • 12,346 (anchor.finalized)  │   │
│  └─────────────────────────────────────────────┘    │ [Jump to Event]              │   │
│                                                      └──────────────────────────────┘   │
│                                                                                           │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ Timeline Scrubber (Bottom):                                                              │
│ ┌─────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ 0K       ├───────┤     ├──────┤          ├──────────┤                     15K      │ │
│ │          │ CP    │     │ CP   │          │   CP     │                               │ │
│ │ ●────────┴───────┴─────┴──────┴──────────┴──────────┴──────────────────────●       │ │
│ │ Start    2K      4K    6K     8K         10K        12K    ▲          14K   Now     │ │
│ │                                                             │                        │ │
│ │                                                      Current: 12,345                 │ │
│ │ Legend: ● = Event   ├──┤ = Checkpoint   ▲ = Scrubber Position                      │ │
│ └─────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                           │
│ Sequence: 12,345 / 15,240  |  Time: 14:32:15  |  User: Alice  |  Rate: 245 events/sec │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- `CP` = Checkpoint (snapshot) position
- `●` = Individual events (densely packed)
- `▲` = Current scrubber position (seq 12,345)
- Preview pane shows artboard rendered at scrubber position
- Metadata inspector shows event details at current sequence

---

## 3. Component Inventory

<!-- anchor: wireframe-history-replay-components -->

| Component | Location | Primary States | Key Interactions | Implementation Reference |
|-----------|----------|----------------|------------------|--------------------------|
| **WindowFrame** | Top chrome | focused, unfocused, fullscreen | Window controls | `HistoryReplayTemplate` |
| **PlaybackControls** | Top toolbar | playing, paused, stopped | Play, pause, skip, speed adjust | Section 6 |
| **PreviewPane** | Center (main) | loading, rendering, error | Read-only view of artboard state | `ReplayEngine` → `RenderingPipeline` |
| **TimelineScrubber** | Bottom | idle, scrubbing, seeking | Drag scrubber, click to jump | `HistoryWindow` |
| **CheckpointMarkers** | Timeline overlay | default, hover, active | Click to jump to checkpoint | `CheckpointCache` |
| **EventDots** | Timeline underlay | default, hovered, current | Hover to preview, click to jump | `EventStoreService` |
| **MetadataInspector** | Right dock | collapsed, expanded, floating | View event details, jump to related | `HistoryWindow` |
| **StatusBar** | Bottom | default, playback-active | Display sequence, time, rate | — |
| **BookmarkBar** | Timeline overlay | hidden, visible | User-set markers for quick navigation | `SettingsService` |

---

## 4. State Matrix

<!-- anchor: wireframe-history-replay-states -->

### 4.1 Playback States

| State | Visual Indicators | Behavior | Accessibility | Code Reference |
|-------|-------------------|----------|---------------|----------------|
| **Stopped** | Play button enabled, scrubber at sequence | Awaiting user action | `aria-label="Playback stopped"` | `ReplayEngine.stop()` |
| **Playing** | Play button → Pause, scrubber animates | Auto-advances sequence at speed (1x, 2x, 5x, 10x) | `aria-live="polite"` sequence updates | `ReplayEngine.play()` |
| **Paused** | Pause button → Play, scrubber static | Sequence frozen, can scrub manually | `aria-label="Playback paused at [seq]"` | `ReplayEngine.pause()` |
| **Seeking** | Loading spinner, scrubber jumps | Loads nearest checkpoint, replays events to target | `aria-busy="true"` | Journey J, `ReplayEngine.seek()` |
| **Buffering** | Progress bar on timeline | Loading checkpoint or event batch | `aria-live="polite"` "Loading checkpoint" | `CheckpointCache.ensureCheckpoints()` |

### 4.2 Timeline Interaction States

| State | Visual Changes | Behavior | Accessibility |
|-------|----------------|----------|---------------|
| **Idle** | Scrubber at current sequence | Awaiting interaction | `aria-label="Timeline"` |
| **Hovering Event** | Tooltip shows event type, user, timestamp | Preview event metadata | `aria-label="Event [type] at [seq]"` |
| **Hovering Checkpoint** | Checkpoint marker highlights, tooltip shows sequence | Click to jump | `aria-label="Checkpoint at [seq]"` |
| **Dragging Scrubber** | Scrubber follows cursor, preview updates live | Seek to sequence, render artboard | `aria-valuenow="[seq]"` |
| **Jump to Sequence** | Scrubber animates to target, preview loads | Checkpoint seek + event replay | `aria-live="polite"` "Jumped to [seq]"` |

### 4.3 Preview Pane States

| State | Visual Changes | Behavior | Accessibility |
|-------|----------------|----------|---------------|
| **Loading** | Skeleton screen, spinner | Loading checkpoint + replaying events | `aria-busy="true"` |
| **Rendering** | Artboard rendered at sequence | Interactive preview (pan/zoom only, no editing) | `aria-label="Artboard at sequence [seq]"` |
| **Error** | Error icon, message | Checkpoint or replay failure | `aria-invalid="true"` error announced |
| **Empty (Start)** | "No events yet" placeholder | Document start, no objects | `aria-label="Empty artboard"` |

---

## 5. Interaction Flows

<!-- anchor: wireframe-history-replay-interactions -->

### 5.1 Core Interactions

| User Action | System Response | Requirements | Journey Reference | Code Path |
|-------------|-----------------|--------------|-------------------|-----------|
| **Open History Window** | Window opens, loads document timeline, shows latest state | FR-027 | Journey J | `HistoryWindow.open()` → `CheckpointCache.load()` |
| **Drag Scrubber** | Preview updates live, metadata inspector shows event at position | FR-027 | Journey J | `TimelineScrubber.onDrag()` → `ReplayEngine.seek()` |
| **Click Timeline Position** | Scrubber jumps, preview seeks to nearest checkpoint + replays | NFR-PERF-001 | Journey J | `Timeline.onClick()` → `CheckpointCache.findNearest()` → `ReplayEngine.replay()` |
| **Click Checkpoint Marker** | Jump directly to checkpoint, instant preview update | NFR-PERF-001 | Journey J | `CheckpointMarker.onClick()` → `ReplayEngine.loadCheckpoint()` |
| **Hover Event Dot** | Tooltip shows event type, user, timestamp | — | — | `EventDot.onHover()` → `MetadataInspector.preview()` |
| **Play Button** | Start playback at current speed, auto-advance sequence | FR-027 | — | `PlaybackControls.play()` → `ReplayEngine.play(speed)` |
| **Pause Button** | Stop playback, freeze at current sequence | — | — | `PlaybackControls.pause()` → `ReplayEngine.pause()` |
| **Skip Forward (▶▶)** | Jump forward 100 events or to next checkpoint | — | — | `PlaybackControls.skipForward()` → `ReplayEngine.seek(+100)` |
| **Skip Backward (◀◀)** | Jump backward 100 events or to previous checkpoint | — | — | `PlaybackControls.skipBackward()` → `ReplayEngine.seek(-100)` |
| **Speed Dropdown** | Change playback speed (1x, 2x, 5x, 10x) | — | — | `PlaybackControls.setSpeed()` → `ReplayEngine.setPlaybackRate()` |
| **Checkpoint Dropdown** | List checkpoints, jump to selected | — | — | `PlaybackControls.selectCheckpoint()` → `ReplayEngine.loadCheckpoint()` |
| **Set Bookmark** | Add user marker at current sequence, persist | — | — | `PlaybackControls.setBookmark()` → `SettingsService.saveBookmark()` |
| **Jump to Event (Inspector)** | Scrubber jumps to event sequence, preview updates | — | — | `MetadataInspector.jumpToEvent()` → `ReplayEngine.seek()` |
| **Filter Timeline** | Show only events matching filter (user, type, artboard) | — | — | `Timeline.filter()` → `EventStoreService.queryEvents()` |

### 5.2 Journey J: History Replay Scrubbing

| Step | User Action | System Response | Code Reference |
|------|-------------|-----------------|----------------|
| 1 | Cmd+Shift+H or Window → History | History window opens, loads timeline | `HistoryWindow.open()` |
| 2 | Timeline displays 0 → 15,240 events, checkpoints at 2K, 4K, 6K, 10K, 12K | `CheckpointCache.ensureCheckpoints()` | Journey J |
| 3 | Scrubber defaults to latest sequence (15,240) | Preview shows current artboard state | `ReplayEngine.loadLatest()` |
| 4 | User drags scrubber to sequence 12,345 | `Timeline.onDrag()` → `ReplayEngine.seek(12345)` | Journey J |
| 5 | ReplayEngine finds nearest checkpoint (seq 12,000) | `CheckpointCache.loadNearestCheckpoint(12345)` returns seq 12,000 | Journey J |
| 6 | ReplayEngine loads checkpoint 12,000 | `EventStoreService.fetchSnapshotBlob(12000)` → deserialize | Journey J |
| 7 | ReplayEngine replays events 12,001 → 12,345 | `EventStoreService.fetchEvents(12001..12345)` → apply | Journey J |
| 8 | Preview pane renders artboard at seq 12,345 | `RenderingPipeline.render(state)` | Journey J |
| 9 | Metadata inspector shows event 12,345 details | User: Alice, Type: path.anchor.moved, payload | Journey J |
| 10 | User clicks "Jump to Event" for related event 12,344 | Scrubber jumps to 12,344, preview updates instantly | `ReplayEngine.seek(12344)` |

---

## 6. Responsive Variants

<!-- anchor: wireframe-history-replay-responsive -->

### 6.1 Compact Mode (Window Width < 1000px)

```
┌──────────────────────────────────────────┐
│ History - Campaign               ◯ □ ⨯  │
├──────────────────────────────────────────┤
│ [◀◀][◀][▶][▶▶][■] 1x [⋮]              │
├──────────────────────────────────────────┤
│                                          │
│  Preview Pane (Full Width)               │
│  ┌──────────────────────────────────┐   │
│  │                                  │   │
│  │  [Artboard at Seq 12,345]        │   │
│  │                                  │   │
│  └──────────────────────────────────┘   │
│                                          │
│  Metadata (Collapsible)                  │
│  [Seq 12,345 ▾] [Event Details...]      │
│                                          │
├──────────────────────────────────────────┤
│ Timeline:                                │
│ ┌────────────────────────────────────┐  │
│ │●─────┬────┬────┬─────┬───▲───────●│  │
│ │      CP   CP   CP    CP   12K     │  │
│ └────────────────────────────────────┘  │
│ 12,345 / 15,240  |  14:32:15  |  Alice │
└──────────────────────────────────────────┘
```

**Changes:**
- Metadata inspector collapses to accordion below preview
- Playback controls abbreviated, advanced options in hamburger menu (⋮)
- Timeline height reduced, checkpoint labels abbreviated
- Status bar text abbreviated

### 6.2 Floating Inspector Mode

```
┌────────────────────────────────────────────┐
│ History Window                             │
│                                            │
│  Preview Pane (Full Width)                 │
│  ┌────────────────────────────────────┐   │
│  │                                    │   │
│  │  [Artboard]                        │   │
│  │                        ┌────────┐  │   │
│  │                        │Metadata│  │   │ ← Floating
│  │                        │────────│  │   │   Inspector
│  │                        │Seq:    │  │   │
│  │                        │12,345  │  │   │
│  │                        └────────┘  │   │
│  └────────────────────────────────────┘   │
│                                            │
│ [Timeline...]                              │
└────────────────────────────────────────────┘
```

**Behavior:**
- Inspector can be dragged to floating overlay
- Semi-transparent when not hovered
- Double-click title to re-dock

---

## 7. Keyboard Shortcuts

<!-- anchor: wireframe-history-replay-shortcuts -->

| Key Combination | Action | Context | Code Reference |
|-----------------|--------|---------|----------------|
| **Cmd/Ctrl+Shift+H** | Open History window | Any window | `HistoryWindow.open()` |
| **Space** | Play/Pause playback | History focused | `PlaybackControls.togglePlay()` |
| **Left Arrow** | Step backward 1 event | History focused | `ReplayEngine.seek(-1)` |
| **Right Arrow** | Step forward 1 event | History focused | `ReplayEngine.seek(+1)` |
| **Shift+Left Arrow** | Jump to previous checkpoint | History focused | `ReplayEngine.seekPreviousCheckpoint()` |
| **Shift+Right Arrow** | Jump to next checkpoint | History focused | `ReplayEngine.seekNextCheckpoint()` |
| **Home** | Jump to document start (seq 0) | History focused | `ReplayEngine.seek(0)` |
| **End** | Jump to latest sequence | History focused | `ReplayEngine.seekEnd()` |
| **Cmd/Ctrl+B** | Set bookmark at current sequence | History focused | `PlaybackControls.setBookmark()` |
| **Cmd/Ctrl+F** | Focus timeline filter field | History focused | `Timeline.focusFilter()` |
| **Cmd/Ctrl+Plus** | Increase playback speed | Playback active | `ReplayEngine.increaseSpeed()` |
| **Cmd/Ctrl+Minus** | Decrease playback speed | Playback active | `ReplayEngine.decreaseSpeed()` |
| **Escape** | Stop playback, return to latest | Playback active | `PlaybackControls.stop()` |
| **Tab** | Toggle metadata inspector | History focused | `WindowFrame.toggleInspector()` |
| **1-9** | Jump to checkpoint N | History focused | `ReplayEngine.jumpToCheckpoint(N)` |

---

## 8. Accessibility Notes

<!-- anchor: wireframe-history-replay-a11y -->

### 8.1 ARIA Roles & Semantic Structure

| Component | ARIA Role | Key Attributes | Screen Reader Behavior |
|-----------|-----------|----------------|------------------------|
| **HistoryWindow** | `window` | `aria-label="History replay - [DocumentName]"` | Announces history context on focus |
| **PlaybackControls** | `toolbar` | `aria-label="Playback controls"` | Announces control group |
| **PlayButton** | `button` | `aria-label="Play"`, `aria-pressed="true/false"` | Play/pause state announced |
| **TimelineScrubber** | `slider` | `aria-valuemin="0"`, `aria-valuemax="[maxSeq]"`, `aria-valuenow="[currentSeq]"`, `aria-label="Timeline scrubber"` | Current sequence announced on change |
| **CheckpointMarker** | `button` | `aria-label="Checkpoint at sequence [seq]"` | Checkpoint position announced |
| **EventDot** | `button` | `aria-label="Event [type] at sequence [seq]"` | Event type + sequence announced |
| **PreviewPane** | `img` | `aria-label="Artboard preview at sequence [seq]"` | Sequence announced on update |
| **MetadataInspector** | `complementary` | `aria-label="Event details"` | Announces event metadata |
| **StatusBar** | `status` | `aria-live="polite"` | Sequence/time updates announced |

### 8.2 Keyboard Navigation

**Playback Controls:**
- Tab cycles through controls (Play, Speed, Checkpoint, Bookmark)
- Enter/Space activates button
- Dropdowns navigate with arrows, Enter selects

**Timeline Navigation:**
- Tab enters timeline scrubber
- Left/Right arrows step 1 event (with announcement)
- Shift+Left/Right jump to checkpoints
- Home/End jump to document start/end
- Scrubber position announced on every change

**Inspector Navigation:**
- Tab cycles through metadata fields
- "Jump to Event" links keyboard activatable

### 8.3 Focus Management

**Focus Order:**
1. Playback controls (left to right)
2. Preview pane (read-only, skippable)
3. Timeline scrubber
4. Metadata inspector fields
5. Status bar (skippable)

**Focus Indicators:**
- Blue 2px outline on focused elements
- Scrubber handle enlarged when focused

**Focus Restoration:**
- Opening History window focuses playback controls
- Closing dialog returns focus to timeline

### 8.4 Screen Reader Support

**Live Region Announcements:**
- Playback start: "Playback started at sequence [seq]"
- Playback pause: "Playback paused at sequence [seq]"
- Seek complete: "Jumped to sequence [seq], [time], [user]"
- Checkpoint load: "Loaded checkpoint [seq]"
- Event hover: "Event [type] by [user] at [time]"
- Speed change: "Playback speed set to [speed]"

**Descriptive Labels:**
- All controls have descriptive `aria-label`
- Event types translated to human-readable labels (e.g., "path.anchor.moved" → "Moved anchor")
- Timestamps formatted as relative time ("2 minutes ago")

### 8.5 Contrast & Visual Accessibility

- All text meets WCAG 2.1 AA contrast (4.5:1)
- Timeline scrubber handle high contrast (blue #0066CC)
- Checkpoint markers distinct from event dots (larger, different shape)
- Playback state visible in high-contrast mode
- Loading states use both spinner and text announcement

---

## 9. Timeline Specification

<!-- anchor: wireframe-history-replay-timeline -->

### 9.1 Timeline Rendering

**Scale:**
- Horizontal axis: Sequence number (0 → maxSeq)
- Auto-zoom based on window width and event count
- Dense event regions compressed, sparse regions expanded

**Visual Elements:**
- **Event dots**: Small circles every 10-100 sequences (density-dependent)
- **Checkpoint markers**: Vertical bars with label (e.g., "CP 12K")
- **Scrubber handle**: Triangle or circle indicating current position
- **Bookmark flags**: User-set markers with custom labels

**Interaction:**
- Click timeline to jump to sequence
- Drag scrubber to seek
- Hover event dot for tooltip
- Click checkpoint to jump directly

### 9.2 Checkpoint Strategy

**Checkpoint Intervals:**
- Automatic checkpoints every 2,000 events
- Additional checkpoints at major milestones (document save, artboard create)
- User-triggered checkpoints (manual snapshot)

**Checkpoint Loading:**
- `CheckpointCache.ensureCheckpoints()` called on History window open (Journey J)
- Nearest checkpoint identified for seek target
- Checkpoint blob loaded from `EventStoreService.fetchSnapshotBlob()`
- Events between checkpoint and target replayed

**Performance:**
- Seek time < 100ms for 10K event documents (NFR-PERF-001)
- Checkpoints compressed (GZIP) and cached in memory
- Preview rendering throttled to 60 FPS during scrub

### 9.3 Timeline Filters

```
┌─────────────────────────────────────────┐
│ Filter Timeline                    [×]  │
├─────────────────────────────────────────┤
│ User:       [All ▾] [Alice] [Bob]       │
│ Event Type: [All ▾] [path.*] [object.*] │
│ Artboard:   [All ▾] [Home Screen]       │
│ Date Range: [Last 7 days ▾]             │
│                                         │
│ [Apply]  [Reset]                        │
└─────────────────────────────────────────┘
```

**Behavior:**
- Filter panel opened via Cmd+F or toolbar button
- Filtered timeline shows only matching events
- Checkpoint markers adjusted to filtered range
- Status bar shows "Showing N of M events"

---

## 10. Metadata Inspector Specification

<!-- anchor: wireframe-history-replay-metadata -->

### 10.1 Event Details View

```
┌────────────────────────────────────┐
│ Event Details                      │
│ ────────────────────────────────── │
│                                    │
│ Sequence: 12,345                   │
│ Type: path.anchor.moved            │
│ Category: Editing                  │
│ Timestamp: 2025-11-11 14:32:15.234 │
│ Relative: 2 minutes ago            │
│ User: Alice (alice@example.com)    │
│ Session: collab-xyz-789            │
│ Artboard: Home Screen              │
│                                    │
│ ────────────────────────────────── │
│                                    │
│ Payload (JSON):                    │
│ {                                  │
│   "anchorId": "a-42",              │
│   "objectId": "path-123",          │
│   "position": {                    │
│     "x": 540.5,                    │
│     "y": 320.0                     │
│   },                               │
│   "sampledPath": [                 │
│     {"x": 540, "y": 319},          │
│     {"x": 540.5, "y": 320}         │
│   ]                                │
│ }                                  │
│                                    │
│ ────────────────────────────────── │
│                                    │
│ Related Events:                    │
│ • 12,344 - anchor.selected         │
│ • 12,346 - anchor.finalized        │
│                                    │
│ [Jump to 12,344]  [Jump to 12,346] │
│                                    │
│ ────────────────────────────────── │
│                                    │
│ Impact:                            │
│ Modified object "path-123"         │
│ Anchor "a-42" moved 1.5px          │
│ 2 sampled positions recorded       │
│                                    │
└────────────────────────────────────┘
```

**Sections:**
1. **Event Overview**: Sequence, type, timestamp, user
2. **Payload**: Full JSON event data (syntax highlighted)
3. **Related Events**: Causal links (e.g., selection before drag, finalization after)
4. **Impact Analysis**: Human-readable summary of changes

### 10.2 Checkpoint Details View

```
┌────────────────────────────────────┐
│ Checkpoint Details                 │
│ ────────────────────────────────── │
│                                    │
│ Sequence: 12,000                   │
│ Type: Automatic                    │
│ Created: 2025-11-11 14:30:00       │
│ Trigger: Every 2,000 events        │
│                                    │
│ ────────────────────────────────── │
│                                    │
│ Snapshot Statistics:               │
│ Objects: 142                       │
│ Artboards: 5                       │
│ Compressed Size: 245 KB            │
│ Uncompressed: 1.2 MB               │
│ Compression: 5:1 ratio             │
│                                    │
│ ────────────────────────────────── │
│                                    │
│ Events Since Checkpoint:           │
│ Total: 345 events                  │
│ By User:                           │
│   Alice: 220                       │
│   Bob: 125                         │
│ By Type:                           │
│   path.*: 180                      │
│   object.*: 100                    │
│   artboard.*: 65                   │
│                                    │
│ [Load Checkpoint]                  │
│                                    │
└────────────────────────────────────┘
```

---

## 11. Error States

<!-- anchor: wireframe-history-replay-errors -->

### 11.1 Checkpoint Load Failure

```
┌────────────────────────────────────────────┐
│ History - Campaign                     ⨯  │
├────────────────────────────────────────────┤
│                                            │
│          ⚠️                                │
│                                            │
│     Failed to load checkpoint              │
│                                            │
│     Error: Checkpoint blob corrupted       │
│     Sequence: 12,000                       │
│                                            │
│     Try loading previous checkpoint?       │
│                                            │
│     [Load CP 10,000]  [Cancel]             │
│                                            │
└────────────────────────────────────────────┘
```

### 11.2 Event Replay Failure

```
┌────────────────────────────────────────────┐
│ ⚠️ Replay Error                       [×] │
│ Failed to replay events 12,001-12,345      │
│ Error: Invalid event sequence at 12,234    │
│ [Skip Event]  [Stop Replay]  [Report]     │
└────────────────────────────────────────────┘
```

**Banner appears as overlay when ReplayEngine encounters invalid event**

---

## 12. Playback Speed Control

<!-- anchor: wireframe-history-replay-speed -->

```
┌──────────────────┐
│ Playback Speed   │
├──────────────────┤
│ ○ 0.5x (Slow)    │
│ ● 1x (Normal)    │
│ ○ 2x             │
│ ○ 5x             │
│ ○ 10x (Fast)     │
│ ○ Custom...      │
└──────────────────┘
```

**Behavior:**
- Dropdown from toolbar
- 1x = 1 event per 100ms (10 events/sec)
- 10x = 1 event per 10ms (100 events/sec)
- Custom allows 0.1x - 50x range
- Playback rate shown in status bar

**Implementation:**
- `ReplayEngine.setPlaybackRate(multiplier)`
- Timer interval adjusted: `100ms / multiplier`

---

## 13. Bookmark System

<!-- anchor: wireframe-history-replay-bookmarks -->

### 13.1 Bookmark Creation

```
┌──────────────────────────────────┐
│ Create Bookmark             [×]  │
├──────────────────────────────────┤
│ Sequence: 12,345                 │
│ Timestamp: 14:32:15              │
│                                  │
│ Label: [Bug Fix Commit       ]   │
│                                  │
│ Color: [🔵] [🔴] [🟢] [🟡]      │
│                                  │
│ Notes (optional):                │
│ [Fixed path anchor snap issue]   │
│                                  │
│ [Create]  [Cancel]               │
└──────────────────────────────────┘
```

### 13.2 Bookmark Display

```
Timeline with bookmarks:

┌─────────────────────────────────────────────┐
│●─────┬────┬──🔵──┬─────┬─🟢─▲───────●     │
│      CP   CP  [BM] CP    [BM] 12K           │
└─────────────────────────────────────────────┘

🔵 = "Bug Fix Commit" at seq 6,500
🟢 = "Feature Complete" at seq 11,000
```

**Features:**
- Click bookmark flag to jump to sequence
- Hover shows bookmark label and notes
- Managed via Bookmark panel (Cmd+Shift+B)
- Persisted per document via `SettingsService`

---

## 14. Advanced Features

<!-- anchor: wireframe-history-replay-advanced -->

### 14.1 Diff View (Compare Two Sequences)

```
┌────────────────────────────────────────────┐
│ Compare Sequences                          │
├────────────────────────────────────────────┤
│ Seq A: [12,000]   Seq B: [12,345]         │
│                                            │
│ ┌──────────────┐     ┌──────────────┐    │
│ │ State at A   │     │ State at B   │    │
│ │ (12,000)     │     │ (12,345)     │    │
│ └──────────────┘     └──────────────┘    │
│                                            │
│ Changes (A → B):                           │
│ • Added: 3 objects                         │
│ • Modified: 8 objects                      │
│ • Deleted: 1 object                        │
│ • Events: 345                              │
│                                            │
│ [View Event Log]  [Export Diff]            │
└────────────────────────────────────────────┘
```

### 14.2 Export Timeline

```
┌────────────────────────────────────┐
│ Export Timeline               [×]  │
├────────────────────────────────────┤
│ Range:                             │
│ ○ All events                       │
│ ● Custom range                     │
│   From: [12,000] To: [12,345]      │
│                                    │
│ Format:                            │
│ ○ JSON (event log)                 │
│ ○ CSV (summary)                    │
│ ○ Video (replay recording)         │
│                                    │
│ Include:                           │
│ ☑ Event metadata                   │
│ ☑ Checkpoint markers               │
│ ☑ Bookmarks                        │
│ ☐ User annotations                 │
│                                    │
│ [Export]  [Cancel]                 │
└────────────────────────────────────┘
```

---

## 15. Cross-References

<!-- anchor: wireframe-history-replay-cross-refs -->

**Related Wireframes:**
- [Navigator Window](./navigator.md) - Entry point for History window
- [Artboard Window](./artboard_window.md) - Shares event timeline
- [Collaboration Panel](./collaboration_panel.md) - Multi-user history tracking

**Related Architecture:**
- [Section 6.3.1 Route Definitions](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md#section-3-1) - `app://history/:docId`
- [Journey J: History Replay Scrubbing](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md) - Scrubbing workflow
- [Flow C: Multi-Artboard Document Load](../../.codemachine/artifacts/architecture/03_Behavior_and_Communication.md) - Checkpoint restoration

**Related Code:**
- `packages/core/lib/services/replay_service.dart` - Replay engine, checkpoint loading
- `packages/core/lib/services/event_store_service.dart` - Event fetching, snapshot blobs
- `packages/app/lib/modules/history/history_window.dart` - History window UI (if implemented)

**Related Requirements:**
- FR-027: History replay requirement
- NFR-PERF-001: < 100ms load time, checkpoint-based seeking

---

## 16. Design Tokens Reference

<!-- anchor: wireframe-history-replay-tokens -->

**Colors:**
- Scrubber handle: `--color-primary` (Blue #0066CC)
- Checkpoint marker: `--color-success` (Green #00CC66)
- Event dot: `--color-border` (Gray #CCCCCC)
- Bookmark flags: `--color-info` (Blue), `--color-warning` (Yellow), `--color-success` (Green), `--color-error` (Red)
- Timeline background: `--color-surface` (White #FFFFFF)

**Spacing:**
- Timeline height: `80px`
- Scrubber handle size: `20×20 px`
- Checkpoint marker width: `4px`
- Event dot size: `4px`

**Typography:**
- Timeline labels: `--font-caption` 10px
- Status bar: `--font-caption` 11px
- Metadata inspector: `--font-mono` 12px

**Reference:** `docs/ui/tokens.md`

---

## 17. Implementation Checklist

<!-- anchor: wireframe-history-replay-checklist -->

- [ ] History window shell with playback controls, preview, timeline
- [ ] Timeline scrubber with drag interaction
- [ ] Checkpoint marker rendering and click-to-jump
- [ ] Event dot rendering and hover tooltips
- [ ] Playback controls (play, pause, skip, speed)
- [ ] ReplayEngine integration (seek, play, checkpoint loading)
- [ ] Preview pane rendering (read-only artboard state)
- [ ] Metadata inspector (event details, payload, related events)
- [ ] Keyboard shortcuts (Space, arrows, Home/End)
- [ ] Bookmark system (create, display, jump, persist)
- [ ] Timeline filters (user, type, artboard, date)
- [ ] Diff view (compare two sequences)
- [ ] Export timeline (JSON, CSV, video)
- [ ] Accessibility (ARIA, keyboard nav, screen reader)
- [ ] Error handling (checkpoint load failure, replay errors)
- [ ] Responsive variants (compact, floating inspector)

---

## 18. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-11 | 1.0 | Initial wireframe creation for I3.T4 | DocumentationAgent |

---

**End of History Replay Wireframe Specification**
