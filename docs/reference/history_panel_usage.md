# History Panel Usage Guide

<!-- anchor: history-panel-usage -->

**Version:** 1.0
**Date:** 2025-11-09
**Status:** Active
**Related Documents:** [Undo Label Reference](undo_labels.md) | [Undo Timeline Diagram](../diagrams/undo_timeline.mmd) | [History Debug Workflow](history_debug.md)

---

## Overview

The History Panel in WireTuner provides a visual, interactive interface for navigating your document's complete operation history. Unlike traditional undo/redo which only moves one step at a time, the History Panel lets you scrub through your entire editing timeline, preview past states, and jump directly to any point in your document's history.

**Key Features:**
- Visual timeline of all editing operations
- One-click navigation to any point in history
- Operation labels showing what each action did
- Current position indicator
- Platform-specific keyboard shortcuts (macOS/Windows)

---

## Table of Contents

- [Opening the History Panel](#opening-the-history-panel)
- [Understanding the Interface](#understanding-the-interface)
- [Basic Navigation](#basic-navigation)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Operation Labels](#operation-labels)
- [Redo Branch Behavior](#redo-branch-behavior)
- [Performance Characteristics](#performance-characteristics)
- [Multi-Window Behavior](#multi-window-behavior)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)
- [Technical Details](#technical-details)

---

## Opening the History Panel

### Via Menu

**macOS:**
```
Window → History Panel
```

**Windows/Linux:**
```
Window → History Panel
```

### Via Keyboard Shortcut

**macOS:**
```
Cmd+Shift+H
```

**Windows/Linux:**
```
Ctrl+Shift+H
```

**Note:** The History Panel is a non-modal panel that can remain open while you work. It updates automatically as you perform operations.

---

## Understanding the Interface

The History Panel displays a chronological list of operations from oldest (top) to newest (bottom):

```
┌─────────────────────────────────────┐
│ History                      [X]    │ ← Title bar with close button
├─────────────────────────────────────┤
│   Create Path                       │ ← Past operation
│   Move Objects                      │ ← Past operation
│ ► Adjust Handle                     │ ← Current position
│   Create Rectangle                  │ ← Future operation (grayed out)
│   Move Objects                      │ ← Future operation (grayed out)
└─────────────────────────────────────┘
```

### Visual Elements

| Element | Description | Appearance |
|---------|-------------|------------|
| **Current Position Indicator (►)** | Shows where you are in the history | Triangle marker or highlight |
| **Past Operations** | Operations before current position | Normal text color |
| **Future Operations (Redo Branch)** | Operations after current position | Grayed/dimmed text |
| **Operation Labels** | Human-readable action names | "Create Path", "Move Objects", etc. |
| **Scrollbar** | Navigate through long histories | Appears when >20 operations |

### Operation Types

The panel displays operations using consistent labels per the [Undo Label Reference](undo_labels.md):

- **Create Path** - Pen tool path creation
- **Move Objects** - Selection tool drag operation
- **Move Anchor** - Direct selection tool anchor manipulation
- **Adjust Handle** - Bezier control point modification
- **Create Rectangle** - Rectangle tool shape creation
- **Create Ellipse** - Ellipse tool shape creation
- And more...

---

## Basic Navigation

### Click to Navigate

**Action:** Click any operation in the list

**Result:** WireTuner navigates to that point in history by replaying events from the nearest snapshot

**Example:**
1. You have 10 operations
2. Currently at operation #10
3. Click operation #5
4. Document state jumps to show only operations 1-5
5. Operations 6-10 become "future" (redo branch)

**Performance:** Navigation completes in <80ms for typical documents (see [Performance Characteristics](#performance-characteristics))

### Undo/Redo Updates Panel

**When you use keyboard shortcuts:**
- `Cmd+Z` (macOS) or `Ctrl+Z` (Windows): Move current position up one operation
- `Cmd+Shift+Z` (macOS) or `Ctrl+Y` (Windows): Move current position down one operation

**The History Panel automatically updates** to reflect the new position.

### Real-Time Updates

**As you work:**
- New operations appear at the bottom of the list
- Current position indicator moves to the newest operation
- Panel scrolls automatically to keep current position visible
- No manual refresh needed

---

## Keyboard Shortcuts

### Undo/Redo (All Platforms)

| Action | macOS | Windows/Linux | Effect in History Panel |
|--------|-------|---------------|------------------------|
| **Undo** | `Cmd+Z` | `Ctrl+Z` | Move current position up one entry |
| **Redo** | `Cmd+Shift+Z` | `Ctrl+Y` or `Ctrl+Shift+Z` | Move current position down one entry |
| **Open History Panel** | `Cmd+Shift+H` | `Ctrl+Shift+H` | Show/hide the panel |

### Navigation Shortcuts (Proposed)

**Note:** These shortcuts may be implemented in future versions:

| Action | macOS | Windows/Linux | Effect |
|--------|-------|---------------|--------|
| **Step Back** | `Cmd+[` | `Ctrl+[` | Same as undo |
| **Step Forward** | `Cmd+]` | `Ctrl+]` | Same as redo |
| **Jump to Start** | `Cmd+Shift+[` | `Ctrl+Shift+[` | Navigate to operation #1 |
| **Jump to End** | `Cmd+Shift+]` | `Ctrl+Shift+]` | Navigate to latest operation |

---

## Operation Labels

### Label Format

All operations follow the format:

```
<Verb> <Object> [Detail]
```

Examples:
- **Create Path** - Creating a new vector path
- **Move Objects** - Dragging selected objects
- **Adjust Handle** - Modifying a Bezier control point

### Grouped Operations

Some operations consist of many events but appear as a single entry:

**Example: Moving a Rectangle**
- Internal: 40 `MoveObjectEvent` samples (50ms interval)
- History Panel: One entry labeled "Move Objects"
- Undo: Single `Cmd+Z` undoes entire move

This grouping uses a **200ms idle threshold** - events are grouped together until 200ms of inactivity.

### Missing Labels

If an operation shows no label or a generic label like "Unknown Operation":
- This may indicate a tool integration issue
- Report as a bug with reproduction steps
- See [Undo Label Reference](undo_labels.md) for expected labels

---

## Redo Branch Behavior

### What is a Redo Branch?

When you undo operations, they don't disappear - they become your "redo branch" (future operations).

**Example:**
1. You have operations A → B → C → D
2. You undo twice (now at B)
3. Operations C and D are your redo branch (shown grayed out)
4. You can redo to restore C and D

### Branch Invalidation

**Critical Behavior:** If you take a NEW action after undoing, the redo branch is **permanently deleted**.

**Example:**
1. You have operations A → B → C → D
2. You undo twice (now at B)
3. Operations C and D are redo branch
4. You create a new path (operation E)
5. **Operations C and D are deleted forever**
6. Your history is now: A → B → E

**Visual Indicator:**
- Grayed operations disappear from History Panel
- No warning dialog (this is intentional)
- Matches standard undo/redo behavior in professional tools

**Rationale:**
This behavior prevents timeline branching and maintains a linear history. See [Undo Timeline Diagram](../diagrams/undo_timeline.mmd) for technical details.

---

## Performance Characteristics

### Navigation Speed

**Target Performance (Iteration 4 KPIs):**
- Undo/redo latency: **< 80ms** (90th percentile)
- History scrubbing rate: **≥ 5,000 events/sec**
- Panel UI updates: Real-time (60 FPS)

### Snapshot Optimization

WireTuner creates snapshots every 1,000 events. When you navigate:

**With Snapshot:**
```
Current: Event 5500
Navigate to: Event 5000
Snapshot exists: Event 5000
Result: Load snapshot (~20ms) + replay 0 events = ~20ms total
```

**Without Snapshot:**
```
Current: Event 5500
Navigate to: Event 4500
Nearest snapshot: Event 4000
Result: Load snapshot (~20ms) + replay 500 events (~30ms) = ~50ms total
```

**User Impact:**
- Navigation is nearly instant for typical use
- Larger jumps may take slightly longer but stay <80ms
- No visible lag or frame drops

### Large Document Behavior

**For documents with 10,000+ objects:**
- Navigation may take 80-120ms (still fast)
- Snapshot cadence automatically adjusts (adaptive tuning)
- See [Performance Benchmarks](../qa/history_checklist.md#performance-benchmarks)

---

## Multi-Window Behavior

### Isolated Undo Stacks

**Each document window has its own history:**

**Window 1:** Document A
- History: Operations 1-50
- Current position: Operation 50
- Undo stack: Independent

**Window 2:** Document A (same file, different window)
- History: Operations 1-50 (shared event store)
- Current position: Operation 45 (undid 5 times)
- Undo stack: Independent

**Key Points:**
- Both windows share the same event database
- Each window maintains its own current position
- Undoing in Window 1 does not affect Window 2
- New operations from either window append to shared history

### Coordination

**When Window 1 adds a new operation:**
1. Event written to shared database
2. Window 2's History Panel updates automatically
3. Window 2's current position unchanged
4. Window 2 can undo/redo independently

**Use Case:** Compare two versions of the same document by opening it twice and navigating to different points in each window.

---

## Common Workflows

### Workflow 1: Compare Two States

**Goal:** Compare document at two different points in history

**Steps:**
1. Open History Panel (`Cmd+Shift+H`)
2. Note current state (e.g., operation #50)
3. Click operation #30 in panel
4. Canvas shows state at operation #30
5. Open second window (File → New Window)
6. In second window, navigate back to operation #50
7. Compare side-by-side

**Benefit:** Visual diff of changes without losing your place

---

### Workflow 2: Undo Multiple Operations at Once

**Goal:** Quickly jump back 10 operations

**Steps:**
1. Open History Panel
2. Scroll up to find operation 10 steps back
3. Click that operation
4. Document instantly jumps to that state

**Alternative (without panel):**
- Press `Cmd+Z` ten times (slower, harder to count)

---

### Workflow 3: Recover from Mistake

**Goal:** You made several bad edits and want to recover

**Steps:**
1. Open History Panel
2. Find last "good" operation (before mistakes started)
3. Click that operation
4. Document reverts to clean state
5. Continue working from that point
6. Bad edits are discarded (redo branch invalidated)

**Note:** This permanently removes the bad edits. To preserve them, export history first (see [History Debug Workflow](history_debug.md)).

---

### Workflow 4: Replay Work Session

**Goal:** Review all changes made during a work session

**Steps:**
1. Open History Panel
2. Click first operation from today
3. Use `Cmd+Shift+Z` repeatedly to step through operations
4. Watch document evolve step-by-step
5. Pause at any point to inspect

**Use Case:** Quality review, client presentation, training

---

## Troubleshooting

### Panel Not Updating

**Symptom:** History Panel shows old operations, doesn't update when you work

**Causes:**
1. Panel not watching provider correctly
2. Operation grouping not completing (200ms threshold)
3. UI rendering frozen

**Solutions:**
- Close and reopen panel (`Cmd+Shift+H` twice)
- Check console for errors
- Verify operations complete (stop dragging, release pointer)
- If persists, restart application

**Related:** See [History Checklist - History Panel Not Updating](../qa/history_checklist.md#issue-history-panel-not-updating)

---

### Slow Navigation

**Symptom:** Clicking operations in panel causes visible lag (>100ms)

**Causes:**
1. No snapshot available (replaying thousands of events)
2. Complex document with heavy geometry
3. Slow disk I/O

**Solutions:**
- Wait for snapshot to be created (every 1,000 events)
- Close other applications to free resources
- Run on SSD if possible
- Check performance metrics in console logs

**Related:** See [History Checklist - Undo Latency Exceeds 80ms](../qa/history_checklist.md#issue-undo-latency-exceeds-80ms)

---

### Operations Missing Labels

**Symptom:** History Panel shows blank or generic labels

**Causes:**
1. Tool not integrated with operation grouping
2. Bug in telemetry system
3. Old document format

**Solutions:**
- Check which tool created the operation (pen, selection, etc.)
- Report bug with tool name and reproduction steps
- For old documents, labels may not be available (pre-I4)

**Related:** See [Undo Label Reference](undo_labels.md#implementation-guidance)

---

### Redo Branch Disappeared

**Symptom:** Operations were grayed out, now they're gone

**Cause:** This is **expected behavior**. You took a new action after undoing, which invalidated the redo branch.

**Explanation:**
- Redo branch is only valid if you don't make new edits
- Taking new action creates alternate timeline
- Old timeline is permanently deleted to avoid branching

**Prevention:**
- If unsure, don't take new action - use redo to restore
- Export history before experimenting (see [History Debug Workflow](history_debug.md))

**Related:** See [Redo Branch Behavior](#redo-branch-behavior)

---

### Panel Crashes or Freezes

**Symptom:** History Panel becomes unresponsive or crashes application

**Causes:**
1. Very large history (10,000+ operations)
2. Memory leak in panel widget
3. Rendering bug with operation list

**Solutions:**
- Restart application
- Avoid keeping panel open with huge histories
- Report bug with document size and operation count
- Check memory usage in Activity Monitor / Task Manager

**Workaround:** Use keyboard shortcuts (`Cmd+Z`/`Cmd+Shift+Z`) instead of panel

---

## Technical Details

### Architecture

The History Panel integrates with several core systems:

**Data Flow:**
```
[OperationGroupingService] → [UndoNavigator] → [ToolTelemetry] → [HistoryPanel UI]
         ↓                           ↓
   [EventRecorder]            [EventReplayer]
         ↓                           ↓
     [EventStore] ←── [SnapshotStore]
```

**Key Components:**
- **OperationGroupingService**: Groups events with 200ms idle threshold
- **UndoNavigator**: Manages current position and time-travel logic
- **ToolTelemetry**: Stores operation labels and metrics
- **EventReplayer**: Reconstructs document state from events

**Provider Integration:**
The panel uses Flutter Provider for reactive updates:
```dart
context.watch<ToolTelemetry>() // Auto-rebuilds on new operations
```

### Performance Optimization

**Lazy Rendering:**
- Panel only renders visible operations (virtualized list)
- Scrolling loads additional entries on-demand
- Prevents memory issues with 10,000+ operations

**Snapshot Strategy:**
- Snapshots created every 1,000 events automatically
- Adaptive cadence adjusts for active editing
- See [Snapshot Strategy Reference](snapshot_strategy.md) (if exists)

**Event Replay:**
- Replays from nearest snapshot, not from beginning
- Typical replay: 500 events in ~30ms
- Batched updates reduce UI thrashing

### Data Persistence

**History Survives:**
- Application restart (persisted in SQLite)
- Crashes (WAL mode durability)
- Multi-window sessions (shared event store)

**History Does NOT Survive:**
- Redo branch invalidation (deleted from database)
- Explicit history clearing (if feature implemented)
- Document deletion

**Related:** See [Crash Recovery Playbook](../qa/recovery_playbook.md)

### Event Schema

All events include these fields:
- `eventId`: UUIDv4 identifier
- `timestamp`: Unix milliseconds
- `eventType`: Event class name
- `eventSequence`: Unique sequence number
- `documentId`: Document identifier

**Related:** See [Event Schema Reference](event_schema.md)

### Operation Grouping

**200ms Idle Threshold:**
```
Time:     0ms    50ms   100ms  150ms  200ms  350ms  400ms
Events:   [E1]   [E2]   [E3]   [E4]   [E5]         [complete]
                                       ^            ^
                                       Last event   Group complete
```

After 200ms of no new events, the active group is completed and assigned a label.

**Related:** See [Undo Timeline Diagram](../diagrams/undo_timeline.mmd)

---

## Advanced Features (Future)

### Timeline Scrubber

**Status:** Planned for future iteration

**Description:**
- Visual timeline bar with draggable handle
- Real-time preview as you scrub
- Playback controls (play/pause)

**Use Case:** Quickly review entire editing session

---

### Branching History

**Status:** Not planned (intentionally avoided)

**Reasoning:**
- Linear history is simpler to understand
- Professional tools (Photoshop, Illustrator) use linear history
- Branching adds UI complexity for rare use case

**Alternative:** Export history before experimenting (see [History Debug Workflow](history_debug.md))

---

### Collaborative History

**Status:** Future consideration

**Description:**
- Show which user performed each operation
- Filter by user or session
- Merge histories from multiple users

**Dependency:** Requires collaboration feature (not yet implemented)

---

## See Also

- [Undo Label Reference](undo_labels.md) - Operation naming conventions
- [Undo Timeline Diagram](../diagrams/undo_timeline.mmd) - Architecture details
- [History Debug Workflow](history_debug.md) - Export/import for debugging
- [History QA Checklist](../qa/history_checklist.md) - Testing procedures
- [Crash Recovery Playbook](../qa/recovery_playbook.md) - Data durability

---

**Document Maintainer:** WireTuner Architecture Team
**Last Updated:** 2025-11-09
**Next Review:** After I4 completion (Undo/Redo UI/UX Polish)
