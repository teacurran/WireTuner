# Collaboration Panel Wireframe

<!-- anchor: wireframe-collaboration-panel -->

## 1. Overview

The Collaboration Panel provides real-time multi-user editing capabilities, including presence awareness, live cursor tracking, conflict resolution, session management, and comment/annotation threading. It integrates with the OT (Operational Transformation) engine and WebSocket gateway to enable seamless distributed editing.

**Routes:**
- `app://collaboration/presence` - Presence overlay
- `app://collaboration/conflict` - Conflict resolution banner
- `app://artboard/:docId/:artboardId` - Collaboration overlays embedded in artboard window

**Entry Methods:**
- View → Collaboration Panel
- Automatic when joining collaboration session
- WebSocket connection triggers overlay activation

**Access Level:** Authenticated user

**Related Journeys:**
- Journey I: Collaboration Session
- Flow D: Direct Selection Drag with Collaboration Broadcast

**Related Requirements:**
- FR-050 (Collaboration adoption)
- Flow D (OT conflict tracking, broadcast)

---

## 2. Layout Structure

<!-- anchor: wireframe-collaboration-panel-layout -->

### 2.1 Docked Panel (Right Side)

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Artboard: Home Screen - Campaign.wire                                 ◯ □ ⨯       │
├────────────────────────────────────────────────────────────────────────────────────┤
│ [Tools and Toolbar...]                                                             │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  Canvas Area                                     ┌──────────────────────────────┐  │
│  (Main Editing Surface)                          │ Collaboration                │  │
│                                                  │ ──────────────────────────── │  │
│  ┌──────────────────────────────────┐           │                              │  │
│  │                                  │           │ Session: Active              │  │
│  │  🔴 Alice                        │           │ Latency: 42 ms ●●●○○        │  │
│  │  [Moving Rectangle]              │           │ ──────────────────────────── │  │
│  │      ↓                           │           │                              │  │
│  │   [Object being edited]          │           │ Participants (3)             │  │
│  │                                  │           │ ────────────────             │  │
│  │                                  │           │ 🔴 Alice (You)               │  │
│  │  🟢 Bob                          │           │    Editing "Rectangle"       │  │
│  │  [Using Pen Tool]                │           │    Last action: 2s ago       │  │
│  │      ↓                           │           │ ────────────────             │  │
│  │   [Drawing path...]              │           │ 🟢 Bob                       │  │
│  │                                  │           │    Drawing "Path-42"         │  │
│  │                                  │           │    Last action: 1s ago       │  │
│  │    📌 Comment #3                 │           │    [Focus] [👁 Follow]       │  │
│  │    "Fix alignment here"          │           │ ────────────────             │  │
│  │                                  │           │ 🟡 Carol (Idle)              │  │
│  │                                  │           │    Viewing artboard          │  │
│  └──────────────────────────────────┘           │    Last action: 5m ago       │  │
│                                                  │    [Focus]                   │  │
│                                                  │ ────────────────             │  │
│                                                  │ + Invite Collaborator        │  │
│                                                  │ ──────────────────────────── │  │
│                                                  │                              │  │
│                                                  │ Comments (2)                 │  │
│                                                  │ ────────────────             │  │
│                                                  │ 📌 #3 Alice: "Fix align..."  │  │
│                                                  │    → Bob: "On it"            │  │
│                                                  │    [View] [Resolve]          │  │
│                                                  │ ────────────────             │  │
│                                                  │ 📌 #2 Carol: "Looks good"    │  │
│                                                  │    ✓ Resolved                │  │
│                                                  │    [View]                    │  │
│                                                  │ ────────────────             │  │
│                                                  │ [New Comment]                │  │
│                                                  │ ──────────────────────────── │  │
│                                                  │                              │  │
│                                                  │ Session Controls             │  │
│                                                  │ ────────────────             │  │
│                                                  │ [Share Link] [Leave]         │  │
│                                                  │                              │  │
│                                                  └──────────────────────────────┘  │
│                                                                                     │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- `🔴 Alice` = Active collaborator (red avatar, currently editing)
- `🟢 Bob` = Active collaborator (green avatar, using tool)
- `🟡 Carol` = Idle collaborator (yellow avatar, viewing only)
- `📌` = Comment marker pinned to artboard location
- Latency indicator: `●●●○○` = 3/5 bars (good connection)

---

## 3. Component Inventory

<!-- anchor: wireframe-collaboration-panel-components -->

| Component | Location | Primary States | Key Interactions | Implementation Reference |
|-----------|----------|----------------|------------------|--------------------------|
| **CollaborationPanel** | Right dock or floating | hidden, docked, floating, collapsed | Toggle visibility, drag to float | Section 6: Collaboration components |
| **PresenceAvatarRow** | Canvas overlay (top-right) or panel header | empty, 1+ collaborators | Click avatar to focus on cursor | `PresenceAvatarRow` |
| **LiveCursorBadge** | Canvas overlay (follows pointer) | hidden, visible, moving | Tracks remote collaborator cursor | `LiveCursorBadge` |
| **ParticipantCard** | Panel list item | active, editing, idle, offline | Focus on cursor, follow mode, kick user | Section 6 |
| **LatencyIndicator** | Panel header or canvas overlay | green (<100ms), yellow (<300ms), red (>300ms) | Displays network latency | `LatencyIndicator` |
| **CommentMarker** | Canvas overlay (pinned to location) | unread, active, resolved | Click to open thread, reply, resolve | `CommentMarker` |
| **CommentThread** | Panel comments section or modal | open, collapsed, resolved | View replies, add reply, resolve | Section 6 |
| **ConflictBanner** | Canvas overlay (top) | hidden, visible, resolving | View diff, accept, retry, merge | `ConflictResolutionBanner` |
| **SessionControls** | Panel footer | active, leaving | Share link, copy invite, leave session | Section 6 |
| **InviteDialog** | Modal | hidden, visible | Enter email, set permissions, send invite | Route: `app://collaboration/invite` |

---

## 4. State Matrix

<!-- anchor: wireframe-collaboration-panel-states -->

### 4.1 Collaboration Session States

| State | Visual Indicators | Behavior | Accessibility | Code Reference |
|-------|-------------------|----------|---------------|----------------|
| **Offline** | Panel hidden or grayed, "Offline" badge | No collaboration features available | `aria-label="Collaboration offline"` | — |
| **Connecting** | Spinner, "Connecting..." message | WebSocket handshake in progress | `aria-busy="true"` | Journey I: WS authenticate |
| **Active** | Presence avatars visible, latency indicator green/yellow | Real-time editing, OT broadcast active | `aria-label="Session active, N users"` | Journey I, Flow D |
| **Idle** | User avatar grayed or marked idle | No activity for 5+ minutes, cursor hidden | `aria-label="User [name] idle"` | Presence timeout |
| **Disconnected** | Banner "Connection lost", red indicator | Local changes continue, no broadcast | `aria-live="assertive"` announcement | WS disconnect handler |
| **Conflict** | Conflict banner visible, red indicator | OT transformation failed, requires resolution | `aria-invalid="true"` | `CollaborationGateway.ot.conflict` |

### 4.2 Participant States

| State | Visual Changes | Behavior | Accessibility |
|-------|----------------|----------|---------------|
| **Active (Editing)** | Avatar solid color, tool/object label, "Editing [object]" | Live cursor visible, events broadcasted | `aria-label="[Name] editing [object]"` |
| **Active (Viewing)** | Avatar solid color, "Viewing artboard" | Cursor visible but no edits | `aria-label="[Name] viewing artboard"` |
| **Idle** | Avatar grayed, "Idle" badge | Cursor hidden, no events for 5+ min | `aria-label="[Name] idle"` |
| **Offline** | Avatar strikethrough, "Offline" badge | Removed from presence list after disconnect | `aria-label="[Name] offline"` |

### 4.3 Comment States

| State | Visual Changes | Behavior | Accessibility |
|-------|----------------|----------|---------------|
| **Unread** | Orange dot badge, bold text | Auto-scroll to unread on panel open | `aria-label="Unread comment from [user]"` |
| **Active** | Standard styling, marker visible on canvas | Click marker to focus thread | `aria-label="Comment from [user]"` |
| **Resolved** | Green checkmark, strikethrough text, marker grayed | Archived, can be reopened | `aria-label="Resolved comment"` |

---

## 5. Interaction Flows

<!-- anchor: wireframe-collaboration-panel-interactions -->

### 5.1 Core Interactions

| User Action | System Response | Requirements | Journey Reference | Code Path |
|-------------|-----------------|--------------|-------------------|-----------|
| **Start Collaboration** | Panel opens, WebSocket connects, presence syncs | FR-050 | Journey I | `CollabPanel.start()` → `WS.authenticate()` |
| **Join Session (Invite Link)** | Auto-open artboard, connect to session, show presence | FR-050 | Journey I | `WS.join(document)` → `OTResolver.broadcast` |
| **Click Participant Avatar** | Canvas pans to collaborator's cursor, highlights their selection | FR-050 | — | `PresenceAvatarRow.onClick()` → `CollaborationGateway.focusUser()` |
| **Enable "Follow Mode"** | Canvas continuously pans to track collaborator's viewport | FR-050 | — | `ParticipantCard.followMode()` → `ViewportService.followUser()` |
| **Edit Object (Local)** | Event broadcast, remote cursors update, OT applied | FR-050 | Flow D | `Canvas.edit()` → `CollaborationGateway.submitEvent()` |
| **Receive Remote Edit** | OT transform, canvas updates, presence label updates | FR-050 | Flow D | `WS.onEvent()` → `OTResolver.transform()` → `Canvas.apply()` |
| **OT Conflict Detected** | Conflict banner appears, diff shown, resolution options | Flow D | Journey I | `OTResolver.conflict()` → `ConflictBanner.show()` |
| **Resolve Conflict (Accept Theirs)** | Apply remote change, discard local, banner dismisses | Flow D | — | `ConflictBanner.acceptTheirs()` → `OTResolver.applyRemote()` |
| **Resolve Conflict (Keep Mine)** | Force local change, notify collaborator, banner dismisses | Flow D | — | `ConflictBanner.keepMine()` → `OTResolver.forceLocal()` |
| **Pin Comment** | Click canvas location, comment marker appears, thread opens | — | — | `Canvas.contextMenu.addComment()` → `CommentMarker.create()` |
| **Reply to Comment** | Type reply, submit, thread updates, notify original author | — | — | `CommentThread.reply()` → `WS.broadcast(comment.added)` |
| **Resolve Comment** | Mark resolved, marker grays, thread archived | — | — | `CommentThread.resolve()` → `CommentMarker.setResolved()` |
| **Invite Collaborator** | Open invite dialog, enter email, send link via email/copy | FR-050 | — | `SessionControls.invite()` → Route `app://collaboration/invite` |
| **Leave Session** | Disconnect WebSocket, remove presence, return to offline mode | — | — | `SessionControls.leave()` → `WS.disconnect()` |

### 5.2 Journey I: Collaboration Session

| Step | User Action | System Response | Code Reference |
|------|-------------|-----------------|----------------|
| 1 | User clicks "Start Collaboration" in panel or View menu | Panel opens, shows "Connecting..." | `CollabPanel.start()` |
| 2 | CollaborationGateway authenticates with WebSocket | `WS.authenticate()` handshake | Journey I |
| 3 | WebSocket sends join event: `join(document)` | `OTResolver.broadcast(join)` | Journey I |
| 4 | OTResolver updates presence list, broadcasts to peers | `Presence.update()` | Journey I |
| 5 | PresenceOverlay shows all collaborators (Alice, Bob) | Avatars appear top-right canvas | Journey I |
| 6 | User (Alice) edits object on canvas | `Canvas.edit()` → `WS.sendEvent(object.moved)` | Journey I |
| 7 | WebSocket sends event to CollaborationGateway | `WS.send(event)` | Journey I |
| 8 | OTResolver sequences and transforms event | `OT.sequence(event)` → `OT.transform()` | Journey I |
| 9 | Remote Canvas (Bob's view) applies transformed event | `Canvas.applyRemoteEvent()` | Journey I |
| 10 | PresenceOverlay updates Bob's view with Alice's live cursor | `LiveCursorBadge` follows Alice's pointer | Journey I |

---

## 6. Responsive Variants

<!-- anchor: wireframe-collaboration-panel-responsive -->

### 6.1 Compact Mode (Collapsed Panel)

```
┌────────────────────────────────────────┐
│ Artboard Window                        │
│                                        │
│  Canvas                  ┌─────┐      │
│                          │👥(3)│      │ ← Collapsed panel
│  ┌──────────────────┐   │ ▼   │      │   (avatar count only)
│  │  [Artboard]      │   └─────┘      │
│  │                  │                 │
│  │  🔴 Alice        │                 │ ← Live cursors still visible
│  │     ↓            │                 │
│  │  [Editing...]    │                 │
│  │                  │                 │
│  └──────────────────┘                 │
│                                        │
└────────────────────────────────────────┘
```

**Behavior:**
- Panel collapses to avatar count indicator
- Click to expand full panel
- Live cursors and conflict banners remain visible on canvas
- Latency indicator moves to toolbar

### 6.2 Floating Palette Mode

```
┌────────────────────────────────────────┐
│ Artboard Window                        │
│                                        │
│  Canvas (Full Width)                   │
│  ┌──────────────────────────────────┐ │
│  │  [Artboard]                      │ │
│  │                                  │ │
│  │              ┌───────────────┐  │ │
│  │              │ Collaboration │  │ │ ← Floating
│  │              │ ───────────── │  │ │   panel
│  │              │ 🔴🟢🟡 (3)    │  │ │
│  │              │ Latency: 42ms │  │ │
│  │              │ [Comments]    │  │ │
│  │              └───────────────┘  │ │
│  │                                  │ │
│  └──────────────────────────────────┘ │
└────────────────────────────────────────┘
```

**Behavior:**
- Panel can be dragged off dock to floating overlay
- Semi-transparent when not hovered
- Always on top of canvas
- Double-click title to re-dock

---

## 7. Keyboard Shortcuts

<!-- anchor: wireframe-collaboration-panel-shortcuts -->

| Key Combination | Action | Context | Code Reference |
|-----------------|--------|---------|----------------|
| **Cmd/Ctrl+Shift+C** | Toggle Collaboration panel | Any window | `CollabPanel.toggle()` |
| **Cmd/Ctrl+Shift+I** | Invite collaborator | Collaboration active | `SessionControls.invite()` |
| **Cmd/Ctrl+Shift+L** | Leave collaboration session | Collaboration active | `SessionControls.leave()` |
| **Cmd/Ctrl+Alt+C** | Add comment at selection/cursor | Artboard focused | `CommentMarker.create()` |
| **Cmd/Ctrl+/** | Focus comment search field | Panel visible | `CommentThread.focusSearch()` |
| **F** (when avatar selected) | Toggle follow mode for collaborator | Participant focused | `ParticipantCard.followMode()` |
| **Escape** | Exit follow mode or close conflict banner | Follow mode or conflict active | `FollowMode.exit()` |
| **Tab** | Cycle through unread comments | Panel visible | `CommentThread.nextUnread()` |

---

## 8. Accessibility Notes

<!-- anchor: wireframe-collaboration-panel-a11y -->

### 8.1 ARIA Roles & Semantic Structure

| Component | ARIA Role | Key Attributes | Screen Reader Behavior |
|-----------|-----------|----------------|------------------------|
| **CollaborationPanel** | `complementary` | `aria-label="Collaboration panel"` | Announces panel context |
| **PresenceAvatarRow** | `list` | `aria-label="Collaborators"` | Announces participant count |
| **ParticipantCard** | `listitem` | `aria-label="[Name], [status]"` | Announces name, status, last action |
| **LatencyIndicator** | `status` | `aria-live="polite"`, `aria-label="Latency: [ms]"` | Announces latency changes |
| **LiveCursorBadge** | `img` | `aria-label="[Name] cursor at [x, y]"` | Announces cursor position changes |
| **CommentMarker** | `button` | `aria-label="Comment from [user]: [preview]"` | Announces comment preview |
| **CommentThread** | `article` | `aria-label="Comment thread"` | Announces thread with replies |
| **ConflictBanner** | `alert` | `aria-live="assertive"`, `aria-label="Conflict detected"` | Immediately announces conflict |
| **SessionControls** | `toolbar` | `aria-label="Session controls"` | Announces control group |

### 8.2 Keyboard Navigation

**Panel Navigation:**
- Tab cycles through participant cards, comment threads, session controls
- Enter/Space activates buttons (focus, follow, resolve)
- Arrows navigate within participant list

**Canvas Overlay Navigation:**
- Tab enters canvas, cycles through comment markers
- Enter opens comment thread
- Escape closes thread or exits follow mode

**Comment Threading:**
- Tab cycles through reply field, resolve button, replies
- Enter submits reply
- Ctrl+Enter resolves thread

### 8.3 Focus Management

**Focus Order:**
1. Panel header (latency indicator, collapse button)
2. Participant list (top to bottom)
3. Comment threads (top to bottom)
4. Session controls (left to right)

**Focus Indicators:**
- Blue 2px outline on focused elements
- Participant cards highlight on focus
- Comment markers pulse on focus

**Focus Restoration:**
- Closing conflict banner returns focus to canvas
- Resolving comment returns focus to comment list
- Leaving follow mode returns focus to participant card

### 8.4 Screen Reader Support

**Live Region Announcements:**
- User joins: "Bob joined the session"
- User leaves: "Carol left the session"
- User editing: "Alice is editing Rectangle"
- Comment added: "New comment from Bob: [preview]"
- Conflict detected: "Conflict detected, resolution required"
- Conflict resolved: "Conflict resolved, changes applied"
- Latency change: "Latency increased to 250 milliseconds"

**Descriptive Labels:**
- All avatars include name and status in `aria-label`
- Live cursors announce position changes (throttled)
- Comment markers include user and preview text
- Session controls describe action (e.g., "Share session link")

### 8.5 Contrast & Visual Accessibility

- All text meets WCAG 2.1 AA contrast (4.5:1)
- Presence avatars use distinct, high-contrast colors (red, green, blue, yellow, purple)
- Latency indicator uses both color and text (●●●○○ + "42 ms")
- Conflict banner uses red background with white text (7:1 contrast)
- Comment markers use both icon and color (📌 + orange/green)

---

## 9. Presence Overlay Specification

<!-- anchor: wireframe-collaboration-panel-presence -->

### 9.1 Presence Avatar Row (Canvas Overlay)

```
Canvas with presence avatars (top-right):

┌────────────────────────────────────────────┐
│                      🔴 Alice  🟢 Bob  🟡 Carol│ ← Avatars
│                      (You)    (Editing)(Idle) │
│                                            │
│  [Artboard content...]                     │
│                                            │
└────────────────────────────────────────────┘
```

**Avatar States:**
- Solid color: Active (editing or viewing)
- Grayed: Idle (5+ minutes no activity)
- Strikethrough: Offline (disconnected)

**Hover Behavior:**
- Tooltip shows full name, email, current action
- Click to focus on their cursor (pan viewport)
- Right-click for context menu (Follow, Mute, Kick)

### 9.2 Live Cursor Badge

```
Canvas with live cursor badge:

┌────────────────────────────────────────────┐
│                                            │
│   🔴 Alice                                 │
│   [Moving Rectangle]  ← Badge follows pointer
│      ↓                                     │
│   [Object being dragged]                   │
│                                            │
│   🟢 Bob                                   │
│   [Using Pen Tool]                         │
│      ↓                                     │
│   [Drawing path...]                        │
│                                            │
└────────────────────────────────────────────┘
```

**Badge Contents:**
- Collaborator name
- Current tool or action
- Optional: Last edit time

**Update Throttling:**
- Position updates: 10/sec (100ms interval)
- Action updates: Immediate on tool switch or object interaction
- Bandwidth: ~1 KB/sec per active user

**Implementation:**
- `LiveCursorBadge` component per Section 6
- Position tracked via WebSocket broadcast
- Local cursor not shown (only remote collaborators)

---

## 10. Conflict Resolution Specification

<!-- anchor: wireframe-collaboration-panel-conflict -->

### 10.1 Conflict Banner

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠️ Conflict Detected: You and Alice edited the same object   │
│ [View Diff]  [Accept Theirs]  [Keep Mine]  [Merge]  [×]     │
└──────────────────────────────────────────────────────────────┘
```

**Trigger Conditions:**
- OT transformation fails to reconcile concurrent edits
- Both users edited same object within conflict window (< 1s)
- Sequence numbers overlap without causal relationship

**Actions:**

1. **View Diff**
   - Opens side-by-side comparison modal
   - Shows local changes vs remote changes
   - Highlights conflicting properties

2. **Accept Theirs**
   - Apply remote change completely
   - Discard local change
   - Notify remote user of acceptance

3. **Keep Mine**
   - Force local change to be authoritative
   - Notify remote user of override
   - May cause remote user's change to be discarded

4. **Merge**
   - Manual resolution dialog
   - Select properties from each version
   - Create merged state

**Implementation:**
- `ConflictResolutionBanner` component per Section 6
- Route: `app://collaboration/conflict`
- Triggered by `CollaborationGateway.ot.conflict` event

### 10.2 Diff View Modal

```
┌────────────────────────────────────────────────────────────────┐
│ Resolve Conflict                                          [×]  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Your Changes (Alice)        Remote Changes (Bob)              │
│  ┌─────────────────────┐    ┌─────────────────────┐          │
│  │ Rectangle           │    │ Rectangle           │          │
│  │ X: 100 ←            │    │ X: 105 ←            │          │
│  │ Y: 200              │    │ Y: 200              │          │
│  │ Width: 150 ←        │    │ Width: 180 ←        │          │
│  │ Height: 100         │    │ Height: 100         │          │
│  │ Fill: #FF0000 ←     │    │ Fill: #FF5733 ←     │          │
│  └─────────────────────┘    └─────────────────────┘          │
│                                                                │
│  Conflicting Properties:                                       │
│  • X position: 100 (yours) vs 105 (Bob's)                     │
│  • Width: 150 (yours) vs 180 (Bob's)                          │
│  • Fill: #FF0000 (yours) vs #FF5733 (Bob's)                   │
│                                                                │
│  Resolution Strategy:                                          │
│  ○ Accept all yours                                            │
│  ○ Accept all theirs                                           │
│  ● Custom merge:                                               │
│    X: ○ 100  ● 105                                             │
│    Width: ● 150  ○ 180                                         │
│    Fill: ○ #FF0000  ● #FF5733                                  │
│                                                                │
│  [Apply Resolution]  [Cancel]                                  │
└────────────────────────────────────────────────────────────────┘
```

---

## 11. Comment System Specification

<!-- anchor: wireframe-collaboration-panel-comments -->

### 11.1 Comment Marker (Canvas Overlay)

```
Canvas with comment marker:

┌────────────────────────────────────────────┐
│                                            │
│    📌 Comment #3                           │
│    "Fix alignment here"                    │ ← Marker with preview
│    ↓ (pinned to this location)            │
│   [Object]                                 │
│                                            │
└────────────────────────────────────────────┘
```

**Marker States:**
- **Unread**: Orange dot badge, pulsing animation
- **Active**: Standard pin icon, solid
- **Resolved**: Green checkmark, grayed out

**Interactions:**
- Click to open full thread in panel or modal
- Hover shows comment preview (first 50 chars)
- Drag to reposition marker

### 11.2 Comment Thread (Panel)

```
┌────────────────────────────────────────┐
│ Comment #3                        [×]  │
├────────────────────────────────────────┤
│ 📌 Pinned to (540, 320)                │
│ Created: 2 minutes ago                 │
│                                        │
│ 🔴 Alice: "Fix alignment here"         │
│            2 minutes ago               │
│                                        │
│ 🟢 Bob:   "On it, adjusting now"       │
│            1 minute ago                │
│                                        │
│ ────────────────────────────────────── │
│                                        │
│ Reply: [Type your reply...          ]  │
│                                        │
│ [Post Reply]  [Resolve Thread]  [📍]   │
└────────────────────────────────────────┘
```

**Features:**
- **Threaded Replies**: Nested conversation structure
- **Timestamps**: Relative time ("2 minutes ago")
- **Pin Icon (📍)**: Jump to marker location on canvas
- **Resolve**: Archives thread, grays marker
- **Mentions**: @username to notify collaborator

**Notifications:**
- Desktop notification when mentioned or thread replied
- Unread badge on panel icon
- Audio ping (optional, user preference)

### 11.3 New Comment Dialog

```
┌────────────────────────────────────────┐
│ New Comment                       [×]  │
├────────────────────────────────────────┤
│ Pin to:                                │
│ ● Current cursor position (540, 320)   │
│ ○ Selected object (Rectangle)          │
│ ○ Custom position (click canvas)       │
│                                        │
│ Comment:                               │
│ [Fix the alignment of this element ]   │
│ [to match the grid guidelines.      ]  │
│                                        │
│ Notify:                                │
│ ☑ @Bob                                 │
│ ☐ @Carol                               │
│                                        │
│ [Pin Comment]  [Cancel]                │
└────────────────────────────────────────┘
```

---

## 12. Latency Indicator Specification

<!-- anchor: wireframe-collaboration-panel-latency -->

### 12.1 Latency Display

```
Panel header with latency indicator:

┌────────────────────────────────────────┐
│ Collaboration                          │
│ Session: Active                        │
│ Latency: 42 ms ●●●○○                  │ ← Latency indicator
│ ────────────────────────────────────── │
```

**Color Coding:**
- **Green (●●●●●)**: < 100ms (Excellent)
- **Yellow (●●●○○)**: 100-300ms (Good)
- **Red (●●○○○)**: > 300ms (Poor)

**Update Frequency:**
- Measured every 5 seconds via ping/pong
- Displayed as rolling average of last 10 samples
- Bars animate on update

**Accessibility:**
- `aria-label="Latency: 42 milliseconds, good connection"`
- Color + text + bars (triple encoding)

### 12.2 Connection Quality Warnings

```
┌────────────────────────────────────────┐
│ ⚠️ Poor Connection Quality             │
│ Latency: 450 ms ●●○○○                 │
│ Some changes may be delayed.           │
│ [Reconnect]  [Work Offline]            │
└────────────────────────────────────────┘
```

**Trigger:** Latency > 500ms or packet loss > 5%

---

## 13. Session Management

<!-- anchor: wireframe-collaboration-panel-session -->

### 13.1 Invite Collaborator Dialog

```
┌────────────────────────────────────────┐
│ Invite Collaborator              [×]   │
├────────────────────────────────────────┤
│ Email:                                 │
│ [bob@example.com                    ]  │
│                                        │
│ Permissions:                           │
│ ○ Viewer (read-only)                   │
│ ● Editor (can edit)                    │
│ ○ Admin (can invite/remove users)      │
│                                        │
│ Message (optional):                    │
│ [Check out this design draft!       ]  │
│                                        │
│ Share Link:                            │
│ [https://wire.app/collab/xyz-789    ]  │
│ [Copy Link]                            │
│                                        │
│ [Send Invite]  [Cancel]                │
└────────────────────────────────────────┘
```

**Route:** `app://collaboration/invite`

**Features:**
- Email invite with magic link
- Shareable link (expires in 7 days)
- Permission levels: Viewer, Editor, Admin
- Optional welcome message

### 13.2 Session Controls (Panel Footer)

```
┌────────────────────────────────────────┐
│ Session Controls                       │
│ ────────────────────────────────────── │
│ [Share Link]  [Invite]  [Leave]        │
│                                        │
│ Session ID: collab-xyz-789             │
│ Started: 14:30:00 (2 hours ago)        │
└────────────────────────────────────────┘
```

**Actions:**
- **Share Link**: Copy invite link to clipboard
- **Invite**: Open invite dialog
- **Leave**: Disconnect from session, remove presence

---

## 14. Error States

<!-- anchor: wireframe-collaboration-panel-errors -->

### 14.1 Connection Lost

```
┌────────────────────────────────────────┐
│ ⚠️ Connection Lost                [×] │
│ Collaboration session disconnected.    │
│ Your changes are saved locally.        │
│ [Reconnect]  [Work Offline]            │
└────────────────────────────────────────┘
```

**Behavior:**
- Banner appears when WebSocket disconnects
- Local changes continue, no broadcast
- Auto-reconnect attempts every 10 seconds
- After 3 failed attempts, prompt user

### 14.2 Session Expired

```
┌────────────────────────────────────────┐
│ Session Expired                        │
├────────────────────────────────────────┤
│ This collaboration session has ended.  │
│ Changes made offline:                  │
│ • 12 events recorded                   │
│ • Last save: 2 minutes ago             │
│                                        │
│ [Save & Close]  [Start New Session]    │
└────────────────────────────────────────┘
```

### 14.3 User Removed

```
┌────────────────────────────────────────┐
│ Removed from Session                   │
├────────────────────────────────────────┤
│ You have been removed by Carol (Admin).│
│ Your changes up to this point are      │
│ saved locally.                         │
│                                        │
│ [Save Document]  [Close]               │
└────────────────────────────────────────┘
```

---

## 15. Advanced Features

<!-- anchor: wireframe-collaboration-panel-advanced -->

### 15.1 Follow Mode

**Activation:**
- Click "Follow" button on participant card
- Keyboard shortcut: F (when participant focused)

**Behavior:**
- Viewport continuously pans to track collaborator's viewport
- Zoom level syncs with collaborator
- Selection highlights show both local and remote
- Exit via Escape or click "Unfollow"

**Visual Indicator:**
```
┌────────────────────────────────────────┐
│ Following Bob                     [×]  │
│ (Your viewport is synced with Bob's)   │
└────────────────────────────────────────┘
```

### 15.2 Activity Timeline

```
┌────────────────────────────────────────┐
│ Activity Timeline                      │
│ ────────────────────────────────────── │
│ 🔴 Alice moved Rectangle      2s ago   │
│ 🟢 Bob created Path-42        5s ago   │
│ 🟡 Carol commented #3         8s ago   │
│ 🔴 Alice deleted Layer-1      12s ago  │
│ 🟢 Bob renamed Artboard       20s ago  │
│ [View All Activity]                    │
└────────────────────────────────────────┘
```

**Features:**
- Real-time activity log
- Filterable by user, type, time
- Click event to jump to sequence in History window

### 15.3 Presence Indicators on Objects

```
Canvas with object-level presence:

┌────────────────────────────────────────┐
│                                        │
│   ┌────────────┐                       │
│   │ Rectangle  │ 🔴 Alice editing      │ ← Object-level indicator
│   └────────────┘                       │
│                                        │
│      •─────────•                       │
│     /  Path-42  \ 🟢 Bob drawing       │ ← Path being edited
│    •            •                      │
│     \          /                       │
│      •─────────•                       │
│                                        │
└────────────────────────────────────────┘
```

**Behavior:**
- Objects being edited show avatar badge
- Locks object from other users (optional setting)
- Release lock after 5 seconds of inactivity

---

## 16. Cross-References

<!-- anchor: wireframe-collaboration-panel-cross-refs -->

**Related Wireframes:**
- [Navigator Window](./navigator.md) - Shared document state visible in tabs
- [Artboard Window](./artboard_window.md) - Collaboration overlays integrated here
- [History Replay](./history_replay.md) - Multi-user history tracking

**Related Architecture:**
- [Section 6.3.1 Route Definitions](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md#section-3-1) - `app://collaboration/*` routes
- [Journey I: Collaboration Session](../../.codemachine/artifacts/architecture/06_UI_UX_Architecture.md) - Session workflow
- [Flow D: Direct Selection Drag with Collaboration Broadcast](../../.codemachine/artifacts/architecture/03_Behavior_and_Communication.md) - OT broadcast sequence

**Related Code:**
- `packages/core/lib/services/collaboration_gateway.dart` - WebSocket, OT engine (if implemented)
- `packages/app/lib/modules/collaboration/` - Collaboration UI components (to be created)

**Related Requirements:**
- FR-050: Collaboration adoption
- Flow D: OT conflict tracking, broadcast latency

---

## 17. Design Tokens Reference

<!-- anchor: wireframe-collaboration-panel-tokens -->

**Colors:**
- Presence avatars: `--color-collab-[user]` (Red #FF4444, Green #44FF44, Blue #4444FF, Yellow #FFAA00, Purple #AA44FF)
- Latency good: `--color-success` (Green #00CC66)
- Latency poor: `--color-error` (Red #CC0000)
- Conflict banner: `--color-error-bg` (Red #FFEBEE)
- Comment marker: `--color-info` (Blue #0066CC)
- Comment resolved: `--color-success` (Green #00CC66)

**Spacing:**
- Panel width: `320px` (docked)
- Participant card height: `72px`
- Comment card height: `auto` (min 60px)
- Avatar size: `32×32 px`

**Typography:**
- Participant name: `--font-body` 14px, weight 500
- Last action: `--font-caption` 12px, weight 400
- Comment text: `--font-body` 13px

**Shadows:**
- Floating panel: `0 4px 16px rgba(0,0,0,0.2)`
- Conflict banner: `0 2px 8px rgba(0,0,0,0.15)`

**Reference:** `docs/ui/tokens.md`

---

## 18. Implementation Checklist

<!-- anchor: wireframe-collaboration-panel-checklist -->

- [ ] Collaboration panel shell (docked, floating, collapsed)
- [ ] Presence avatar row (canvas overlay)
- [ ] Live cursor badges (follow remote pointers)
- [ ] Participant cards (active, idle, offline states)
- [ ] Latency indicator (color-coded, bar graph)
- [ ] Comment markers (canvas overlay, pinned locations)
- [ ] Comment threads (replies, resolve, mentions)
- [ ] Conflict resolution banner (diff, accept, merge)
- [ ] Session controls (invite, share link, leave)
- [ ] Invite dialog (email, permissions, link copy)
- [ ] WebSocket integration (authenticate, join, broadcast)
- [ ] OT engine integration (transform, conflict detection)
- [ ] Follow mode (viewport sync)
- [ ] Activity timeline (real-time log)
- [ ] Keyboard shortcuts (Cmd+Shift+C, F for follow)
- [ ] Accessibility (ARIA, keyboard nav, screen reader)
- [ ] Error handling (disconnect, session expired, removed)

---

## 19. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-11 | 1.0 | Initial wireframe creation for I3.T4 | DocumentationAgent |

---

**End of Collaboration Panel Wireframe Specification**
