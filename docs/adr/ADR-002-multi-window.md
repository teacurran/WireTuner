<!-- anchor: adr-002-multi-window -->
# 002. Multi-Window Document Editing

**Status:** Accepted
**Date:** 2025-11-08
**Deciders:** WireTuner Architecture Team

## Context

WireTuner is a professional desktop vector editor targeting macOS and Windows platforms. Industry-standard creative tools (Adobe Illustrator, Figma Desktop, Affinity Designer) support **multi-window workflows** where users can:

1. Open multiple documents simultaneously, each in its own window
2. View the same document in multiple windows (split-view editing)
3. Arrange windows side-by-side for reference comparison or copy-paste workflows
4. Expect each window to maintain independent UI state (zoom level, selected tool, pan position)

The architectural challenge is designing a system where:
- **Resource Isolation**: Each document window has isolated undo stacks, metrics, logging context, and canvas state
- **Storage Coordination**: Multiple windows accessing the same `.wiretuner` file must not corrupt the event log or snapshot data
- **Lifecycle Management**: Closing a window cleanly releases resources (database connections, event subscriptions, memory) without affecting other open windows
- **Performance**: Opening 3+ windows simultaneously must not degrade event persistence or UI responsiveness

Without explicit multi-window support, WireTuner would be limited to single-document workflows, creating friction for professional users accustomed to multi-window multitasking.

## Decision

We will implement **multi-window document editing** with the following design:

### 1. Independent Window State

Each document window maintains:
- **Isolated Undo/Redo Stack**: Per-window `UndoNavigator` instances tracking local undo/redo positions (no shared undo state between windows)
- **Separate Canvas State**: Independent zoom level, pan position, selected objects, and active tool
- **Dedicated Logging Context**: Per-window logger tags for tracing events to specific windows (e.g., `[window-abc123]`)
- **Isolated Metrics**: Per-window performance counters (frame times, event latency) for diagnostics

**Rationale**: Independent state prevents unintended interactions (zooming in Window A shouldn't affect Window B) and simplifies crash isolation (Window B crash doesn't corrupt Window A state).

### 2. Shared Event Store with Connection Pooling

Multiple windows opening the same `.wiretuner` file share:
- **Pooled SQLite Connections**: `ConnectionFactory` maintains a connection pool keyed by `documentId`, reusing connections across windows
- **WAL Mode Concurrency**: SQLite's Write-Ahead Logging mode allows multiple readers + single writer without blocking
- **Event Coordination**: Windows observe the event log for changes, triggering UI updates when other windows append events (foundation for future collaborative editing)

**Rationale**: Connection pooling prevents file descriptor exhaustion and ensures consistent event ordering. WAL mode provides ACID guarantees without serializing all database access.

### 3. Window Manager Coordination

The `app_shell` package's `WindowManager` provides:
- **Window Registry**: Central registry mapping `windowId → DocumentWindow` instances
- **Lifecycle Hooks**: `onWindowCreated()`, `onWindowClosed()`, `onAllWindowsClosed()` callbacks for resource management
- **Cleanup Guarantees**: Closing a window releases its database connection, event subscriptions, and canvas resources via deterministic cleanup hooks

**Implementation Location**: `packages/app_shell/lib/src/window/window_manager.dart`

### 4. Document Lifecycle Contract

**Opening a document in a new window:**
1. Window Manager generates unique `windowId` (UUID)
2. `ConnectionFactory` opens or reuses pooled connection for `documentId`
3. Window loads nearest snapshot + replays recent events (hybrid loading strategy per ADR-001)
4. Window initializes isolated `UndoNavigator`, canvas state, and logger context

**Closing a window:**
1. Window releases event subscriptions and canvas resources
2. `ConnectionFactory.closeConnection(documentId)` decrements pool reference count
3. If reference count reaches zero, connection is closed and removed from pool
4. Window Manager removes window from registry and invokes cleanup hooks

**Opening the same document in multiple windows:**
- Each window has independent `UndoNavigator` (isolated undo stacks)
- Both windows share the same pooled SQLite connection
- Event coordination logic observes event log changes and triggers repaints (foundation for future real-time sync)

## Rationale

### Why Isolated Undo Stacks Per Window?

**Alternatives Considered:**
- **Shared Undo Stack**: All windows viewing the same document share one undo/redo stack

**Why Rejected:**
- Confusing UX: Undoing in Window A unexpectedly changes Window B's view
- Race conditions: If Window A and Window B both undo simultaneously, which takes precedence?
- Collaboration complexity: When implementing multi-user editing (future), per-user undo stacks are required anyway

**Accepted Approach:** Isolated undo stacks per window mirror industry-standard behavior (Adobe Illustrator, Figma) and simplify future collaboration features (each user has their own undo stack).

### Why SQLite Connection Pooling?

**Problem**: Opening 10 windows on 5 documents creates 50 SQLite connections if connections are 1:1 with windows.

**Solution**: Pool connections by `documentId`, allowing multiple windows to share the same connection.

**Benefits:**
- Reduces file descriptor usage (critical on macOS with default limit of 256 FDs)
- Ensures consistent event ordering (all events for a document flow through the same connection)
- Simplifies transaction management (single writer per document)

**Trade-off**: Requires reference counting to safely close pooled connections when all windows close.

### Why WAL Mode?

**Problem**: Traditional SQLite locking (DELETE journal mode) blocks readers during writes, creating UI freezes when one window saves while another scrolls the canvas.

**Solution**: Enable Write-Ahead Logging (WAL) mode, allowing concurrent readers and a single writer.

**Performance Impact:**
- Readers never block on writer
- Writer commits ~30% faster (no journal rollback overhead)
- Minimal storage overhead (WAL file auto-checkpoints at 1000 pages)

**Reference**: See `packages/io_services/lib/src/migrations/base_schema.sql:51` for WAL mode initialization.

### Why Per-Window Metrics and Logging?

**Problem**: Debugging performance issues when 3 windows are open—which window is causing frame drops?

**Solution**: Each window tags logs with `[window-{windowId}]` prefix and tracks independent performance metrics.

**Benefits:**
- Isolated diagnostics: Can identify specific window causing performance degradation
- Crash attribution: If Window B crashes, logs clearly indicate which window's event handlers failed
- Multi-user foundation: When implementing collaboration, per-user logging follows naturally

## Consequences

### Positive Consequences

1. **Professional Multi-Window UX**: Users can work with multiple documents or split-view same document, matching industry-standard workflows
2. **Crash Isolation**: Window B crash doesn't corrupt Window A's in-memory state or undo stack
3. **Resource Efficiency**: Connection pooling prevents file descriptor exhaustion and reduces memory overhead
4. **Collaboration-Ready**: Isolated undo stacks and event coordination logic provide foundation for multi-user editing (Iteration 5+ roadmap)
5. **Debuggability**: Per-window logging and metrics simplify performance profiling and crash triage
6. **Concurrency Without Blocking**: WAL mode eliminates reader/writer contention, maintaining 60 FPS canvas even during saves

### Negative Consequences

1. **Coordination Complexity**: Window Manager must track window lifecycle, manage cleanup hooks, and enforce isolation guarantees
2. **Memory Overhead**: Each window duplicates canvas state, undo navigator, and event subscriptions (mitigated by sharing document model via immutable data structures)
3. **Connection Pool Management**: Reference counting adds complexity to connection lifecycle (must avoid premature closure or leaks)
4. **Testing Burden**: Must simulate multi-window scenarios (3+ windows, same document in 2+ windows, rapid open/close) to validate isolation
5. **Potential Race Conditions**: Event coordination logic must handle scenarios where Window A and Window B append events simultaneously (mitigated by SQLite ACID guarantees)

### Mitigation Strategies

- **Complexity**: Comprehensive unit tests for `WindowManager` lifecycle hooks, connection pool reference counting, and cleanup guarantees (see Task I4.T7 acceptance criteria)
- **Memory Overhead**: Use Flutter's `ChangeNotifier` pattern to share document model across windows via immutable data structures (structural sharing reduces copies)
- **Race Conditions**: SQLite's transaction isolation prevents event log corruption; event coordination logic uses optimistic concurrency (reload on conflict)
- **Testing**: Automated tests simulate 3-window scenarios with same document, verify cleanup hooks release resources, validate isolated undo stacks

## Alternatives Considered

### 1. Single-Window Application (No Multi-Window Support)

**Description**: Limit WireTuner to a single document window at a time, like some web-based editors (Canva, Vectr).

**Why Rejected**:
- Unacceptable for professional desktop workflows requiring side-by-side reference documents
- Forces users to Alt-Tab between documents instead of arranging windows
- Misses competitive parity with Adobe Illustrator, Affinity Designer
- No technical benefit—Flutter supports multi-window on desktop natively

**Verdict**: Insufficient for professional creative tool positioning.

### 2. Shared Undo Stack Across Windows

**Description**: All windows viewing the same document share a single undo/redo stack, so undoing in Window A affects Window B.

**Why Rejected**:
- Confusing UX: User expects undo to affect only the active window
- Doesn't match industry behavior (Adobe apps use per-window undo)
- Complicates future collaboration (multi-user editing requires per-user undo anyway)

**Verdict**: Poor UX and architecturally incompatible with collaboration roadmap.

### 3. Single SQLite Connection Per Window (No Pooling)

**Description**: Each window opens its own dedicated SQLite connection to the same `.wiretuner` file.

**Why Rejected**:
- File descriptor exhaustion: 10 windows = 10 FDs per document
- Increases memory overhead (each connection caches pages independently)
- Harder to coordinate event ordering across connections

**Verdict**: Connection pooling provides better resource efficiency without sacrificing isolation.

### 4. Document Locking (Prevent Multiple Windows on Same Document)

**Description**: Allow only one window per document, showing error dialog if user tries to open the same file twice.

**Why Rejected**:
- Prevents split-view workflows (viewing different canvas regions simultaneously)
- Doesn't match user expectations from other creative tools
- No technical benefit—WAL mode handles concurrent access safely

**Verdict**: Artificial limitation that degrades UX without architectural benefit.

### 5. In-Memory Event Log (No Persistent Multi-Window Coordination)

**Description**: Keep event log in memory, persist only on explicit save, eliminating SQLite coordination complexity.

**Why Rejected**:
- Loses crash resistance (unsaved work lost on app crash)
- Breaks hybrid loading strategy (see ADR-001)
- Doesn't eliminate multi-window coordination—still need in-memory event queue synchronization

**Verdict**: Sacrifices core event sourcing benefits (crash recovery, audit trail) for marginal simplification.

## References

- **Architecture Blueprint Section 3.1** (Multi-Window Requirements): `.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-event-sourcing`
- **Plan Overview** (Multi-Window Assumptions): `.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#project-overview`
- **Iteration 4 Plan** (Multi-Window Coordination): `.codemachine/artifacts/plan/02_Iteration_I4.md#iteration-4-plan`
- **Task I4.T7** (Window Manager Implementation): `.codemachine/artifacts/plan/02_Iteration_I4.md#task-i4-t7`
- **Package app_shell README**: `packages/app_shell/README.md` (Document tab management, window state management)
- **Package io_services README**: `packages/io_services/README.md` (Connection pooling, WAL mode, multi-document support)
- **ADR-001**: Hybrid State + History Approach (`docs/adr/ADR-001-hybrid-state-history.md`)
- **ADR-003**: Event Sourcing Architecture Design (`docs/adr/003-event-sourcing-architecture.md`)
- **SQLite WAL Mode Documentation**: https://www.sqlite.org/wal.html (Concurrency guarantees)

---

**This ADR documents the multi-window architecture that enables professional desktop workflows while maintaining resource isolation, crash resistance, and a foundation for future collaborative editing. The `WindowManager` in `packages/app_shell` and `ConnectionFactory` in `packages/io_services` must maintain these contracts throughout implementation.**
