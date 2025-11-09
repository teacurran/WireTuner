<!-- anchor: adr-001-hybrid-state-history -->
# 001. Hybrid State + History Approach

**Status:** Accepted
**Date:** 2025-11-08
**Deciders:** WireTuner Architecture Team

## Context

WireTuner requires a persistence architecture that serves two distinct but complementary purposes:

1. **Instant Document Loading**: Users expect professional desktop applications to open documents in under 200ms, comparable to Adobe Illustrator or Figma. Loading times exceeding 1 second create friction in creative workflows.

2. **Complete History Preservation**: The event sourcing foundation (see ADR-003) captures every user action as immutable events, enabling infinite undo/redo, audit trails, and future collaboration. However, replaying 10,000+ events from document creation on every load creates unacceptable latency.

3. **Sampled Interaction Capture**: High-frequency user input (mouse drag operations) must be sampled at 50ms intervals to prevent storage bloat while maintaining perceptual smoothness during replay.

The challenge is balancing these requirements: event sourcing demands complete history preservation, but performance requires instant access to current document state without replaying the entire event log.

## Decision

We will implement a **hybrid persistence architecture** combining:

1. **Periodic Snapshots**: Compressed document state snapshots created every 1000 events, stored in the `snapshots` table
2. **Append-Only Event Log**: Complete event history preserved in the `events` table with 50ms sampling for continuous input
3. **Dual Loading Strategy**:
   - Fast path: Load nearest snapshot + replay recent events (< 200ms for typical documents)
   - Full reconstruction: Replay from document creation when needed (history browsing, debugging)
4. **SQLite Backend**: Single `.wiretuner` file containing metadata, events, and snapshots tables with WAL mode for crash resistance

This approach treats snapshots as **materialized views** of the event log—denormalized for read performance while the event log remains the source of truth.

## Rationale

### Why Hybrid Instead of Snapshots-Only?

**Snapshots-only architecture** (saving only current state, discarding history):
- ❌ Loses audit trail—cannot reconstruct past workflow decisions
- ❌ Breaks infinite undo/redo—undo limited to in-memory operations since last save
- ❌ Eliminates collaboration foundation—no event stream to distribute to peers
- ❌ Prevents time-travel debugging—cannot inspect document state at arbitrary points

**Hybrid architecture** (snapshots + events):
- ✅ Instant loading via snapshots (< 200ms)
- ✅ Infinite undo/redo via event replay to any sequence number
- ✅ Complete audit trail preserved in event log
- ✅ Future collaboration enabled by distributable event stream
- ✅ Time-travel debugging by replaying to arbitrary event sequence

### Why 1000-Event Snapshot Interval?

**Empirical Analysis**:
- **Typical Usage Pattern**: Active editing generates 20-30 events per minute
- **Interval in Time**: 1000 events ≈ 30-50 minutes of continuous work
- **Load Performance**: Snapshot + up to 1000 events replays in < 200ms on target hardware (8 GB RAM, SSD)
- **Storage Overhead**: Each gzip-compressed snapshot adds 10-50 KB (acceptable for documents < 100 MB)

**Alternatives Considered**:
- **Every 100 events**: Too frequent—snapshot overhead outweighs performance gain, file bloat
- **Every 10,000 events**: Too infrequent—document load times exceed 1 second, poor user experience
- **Time-based (every 5 minutes)**: Unpredictable event counts create inconsistent file sizes and load performance

**Verdict**: 1000 events empirically balances instant loading with minimal storage overhead. Interval is tunable via configuration if usage patterns differ from predictions.

### Why 50ms Sampling for Continuous Input?

**Problem**: Mouse drag operations generate 100-200 events/second at typical polling rates. Full-fidelity capture creates:
- Storage bloat: 2-second drag = 200+ events vs. 40 with 50ms sampling (5× reduction)
- Replay performance degradation: Excessive events slow undo/redo and history scrubbing

**Solution**: Sample continuous input (mouse drag, pen tablet) at 50ms intervals (20 samples/second maximum).

**Perceptual Validation**:
- Human motion smoothness threshold ≈ 60 FPS (16.7ms/frame)
- Vector path creation doesn't require per-frame capture
- 20 samples/second provides smooth replay without perceptible jitter
- Fidelity loss imperceptible to users in practice

**Trade-off**: Slight reduction in path precision compared to full-fidelity capture, but 5-10× storage savings and faster replay justify the compromise.

### Why SQLite with Snapshots + Events Tables?

**SQLite Advantages**:
- Single-file format (`.wiretuner`) simplifies distribution and backup
- ACID guarantees with WAL mode ensure crash resistance
- Standard tooling (SQLite browsers) allows users to inspect event logs for debugging
- Cross-platform support (macOS, Windows, Linux) via `sqflite_common_ffi`

**Three-Table Schema**:
- `metadata`: Document-level information (title, version, creation timestamp)
- `events`: Append-only log with event_type, event_payload (JSON), event_sequence, event_timestamp
- `snapshots`: Compressed document state at every 1000th event with snapshot_sequence, state_payload (gzipped JSON)

See `packages/io_services/lib/src/sqlite/schema.dart` for complete implementation.

## Consequences

### Positive Consequences

1. **Sub-200ms Document Loading**: Hybrid approach achieves instant-load UX without sacrificing event history
2. **Infinite Undo/Redo**: Event log enables replay to any sequence number without manual undo stack management
3. **Complete Audit Trail**: Every user action recorded with timestamp for debugging and workflow analysis
4. **Future-Proof Collaboration**: Event log provides distributable message stream for multi-user editing (Iteration 5+ roadmap)
5. **Robust Crash Recovery**: WAL mode + snapshots ensure recovery even if recent events corrupted
6. **Predictable Performance**: Event-based snapshots (vs. time-based) provide consistent load times regardless of editing intensity
7. **Storage Efficiency**: 50ms sampling reduces event volume by 5-10× for continuous input without perceptible quality loss

### Negative Consequences

1. **Storage Overhead**: Snapshots add 10-50 KB per 1000 events (mitigated by gzip compression achieving 10:1 ratios)
2. **Snapshot Maintenance Complexity**: Requires background snapshot generation logic and garbage collection of old snapshots
3. **Dual Truth Sources**: Snapshots must stay consistent with event log replay (mitigated by deterministic event handlers and snapshot validation tests)
4. **Initial Implementation Cost**: Hybrid system requires upfront investment in snapshot management, replay engine, and testing infrastructure
5. **Storage Growth**: Event log grows unbounded without compaction (mitigated by optional "compress history" feature in future iterations)

### Mitigation Strategies

- **Storage Overhead**: Implement aggressive gzip compression (typical 10:1 ratio for JSON snapshots), potential future migration to binary encoding if needed
- **Dual Truth Sources**: Comprehensive unit tests validate snapshot generation produces identical state to full event replay from document creation
- **Complexity**: Strict architectural boundaries (see Architecture Blueprint Section 3.1), comprehensive ADRs and code documentation
- **Performance Monitoring**: Continuous profiling during development, load time benchmarks in CI, snapshot size regression tests

## Alternatives Considered

### 1. Snapshots-Only (No Event History)

**Description**: Save only current document state, discard edit history on file save.

**Why Rejected**:
- Breaks infinite undo/redo (undo limited to in-memory operations since last save)
- No audit trail for debugging or workflow reconstruction
- Eliminates future collaboration foundation
- Unacceptable for professional creative tools requiring robust undo

**Verdict**: Insufficient for WireTuner's architectural vision.

### 2. Event Log Only (No Snapshots)

**Description**: Store only events, reconstruct document state by replaying from document creation every time.

**Why Rejected**:
- Document load times exceed 1-2 seconds for complex documents with 10,000+ events
- Poor user experience compared to industry standards (Adobe Illustrator, Figma load in < 500ms)
- Replay CPU cost scales linearly with document age

**Verdict**: Unacceptable performance for production application.

### 3. Time-Based Snapshots (Every N Minutes)

**Description**: Create snapshots based on elapsed time (e.g., every 5 minutes) instead of event count.

**Why Rejected**:
- Unpredictable file sizes: power users generate many events quickly, casual users few
- Inconsistent document load performance (variable event counts between snapshots)
- Harder to predict storage requirements and test load performance

**Verdict**: Event-based snapshots provide more predictable, testable behavior.

### 4. Snapshot Every Event (Immediate Consistency)

**Description**: Save complete document state after every event for instant loading with zero replay.

**Why Rejected**:
- Prohibitive storage overhead: 10-50 KB per event × 10,000 events = 100-500 MB files
- Write amplification degrades performance: each event requires full document serialization
- Unnecessary for 50ms-sampled events where many states are nearly identical

**Verdict**: Storage and performance costs far exceed benefits.

### 5. Custom Binary File Format (Not SQLite)

**Description**: Design a custom binary format with event log and snapshot sections, implemented with Dart file I/O.

**Why Rejected**:
- Reinventing the wheel: SQLite provides ACID guarantees, crash recovery, and query capabilities
- No standard tooling: users cannot inspect files for debugging
- High development and testing cost for marginal benefits
- SQLite is battle-tested across billions of deployments

**Verdict**: SQLite is the pragmatic choice for local-first desktop applications (see ADR-003 for detailed SQLite rationale).

## References

- **Architecture Blueprint Section 3.1** (Event Sourcing Foundation): `.codemachine/artifacts/architecture/06_Rationale_and_Future.md#decision-event-sourcing`
- **Plan Overview**: `.codemachine/artifacts/plan/01_Plan_Overview_and_Setup.md#project-overview`
- **Task I1.T3**: Event core implementation with snapshot logic (`.codemachine/artifacts/plan/02_Iteration_I1.md#task-i1-t3`)
- **Task I1.T4**: I/O services package with SQLite schema (`.codemachine/artifacts/plan/02_Iteration_I1.md#task-i1-t4`)
- **Task I1.T5**: Diagnostics package for load time metrics (`.codemachine/artifacts/plan/02_Iteration_I1.md#task-i1-t5`)
- **ADR-003**: Event Sourcing Architecture Design (`docs/adr/003-event-sourcing-architecture.md`)
- **Iteration 4 Plan**: Undo/redo implementation leveraging hybrid architecture (`.codemachine/artifacts/plan/02_Iteration_I4.md#iteration-4-plan`)
- **Martin Fowler - Event Sourcing**: https://martinfowler.com/eaaDev/EventSourcing.html
- **Greg Young - CQRS & Event Sourcing**: Snapshots as materialized views concept

---

**This ADR documents the hybrid persistence strategy that combines event sourcing's benefits (infinite undo, audit trails, collaboration foundation) with snapshot-based performance (< 200ms document loading). All persistence operations in `packages/io_services` and event replay logic in `packages/event_core` must maintain this dual contract.**
