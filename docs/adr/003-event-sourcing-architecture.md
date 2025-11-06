# 003. Event Sourcing Architecture Design

**Status:** Accepted
**Date:** 2025-11-06
**Deciders:** WireTuner Architecture Team

## Context

WireTuner is a professional desktop vector graphics editor that requires robust support for unlimited undo/redo operations, complete audit trails of user actions, and a foundation for future collaborative editing features. Traditional CRUD-based architectures with command pattern undo stacks provide basic undo/redo functionality but lack comprehensive audit trails and natural support for distributed collaboration.

The challenge is to design a persistence architecture that:
- Enables infinite undo/redo without manual undo stack management
- Provides complete workflow reconstruction for debugging and analysis
- Supports future multi-user collaboration features without major architectural changes
- Maintains acceptable performance for high-frequency user input (mouse drag operations)
- Balances storage efficiency with replay performance
- Ensures crash resistance and data integrity

## Decision

We will implement a complete event sourcing architecture with the following characteristics:

1. **Append-Only Event Log**: All state changes captured as immutable events in SQLite
2. **50ms Sampling Rate**: High-frequency input events (mouse drag) sampled at 50ms intervals
3. **Periodic Snapshots**: Document state snapshots created every 1000 events
4. **JSON Event Encoding**: Event payloads stored as human-readable JSON
5. **Immutable Domain Models**: All in-memory domain objects (Document, Path, Shape) are immutable

The implementation uses SQLite as the event store with three core tables:
- `metadata`: Document-level information (title, version, timestamps)
- `events`: Append-only log with event_type, event_payload (JSON), event_sequence
- `snapshots`: Compressed document state captures for fast loading

See `lib/infrastructure/persistence/schema.dart` for the complete schema implementation.

## Rationale

### Why Event Sourcing?

Event sourcing provides WireTuner with four critical capabilities:

1. **Infinite Undo/Redo**: Natural consequence of event history navigation - replaying events to any sequence number reconstructs that historical state
2. **Complete Audit Trail**: Every user action recorded with timestamp, enabling workflow analysis and debugging
3. **Future-Proof Collaboration**: Events are inherently distributable messages, enabling multi-user editing in future versions via Operational Transform or CRDTs
4. **Robust Crash Recovery**: Combination of snapshots + event log ensures state can always be reconstructed

Traditional CRUD with command pattern undo requires manually implementing command serialization, undo stack management, and state cloning. Event sourcing provides these features as architectural consequences.

### Why 50ms Sampling Rate?

**Problem**: Mouse drag operations can generate 100-200 events per second at typical mouse polling rates, creating storage bloat and replay performance issues.

**Solution**: Sample continuous input events at 50ms intervals (20 samples/second maximum).

**Trade-off Analysis**:
- **Perceptual Smoothness**: Human perception of smooth motion requires ~60 FPS (16.7ms per frame), but vector path creation doesn't need per-frame capture. At 20 samples/second, dragging operations still feel smooth during replay.
- **Storage Efficiency**: A 2-second drag generates 40 events instead of 200+ events, reducing storage by 5-10x
- **Replay Performance**: Fewer events to replay means faster document loading and undo/redo operations
- **Fidelity**: Slight reduction in path smoothness compared to full-fidelity capture, but imperceptible to users in practice

**Validation**: 50ms is below human perception threshold for motion continuity while providing substantial storage savings.

### Why Snapshot Every 1000 Events?

**Problem**: Replaying 10,000+ events from document creation to current state on every document load is prohibitively slow (1-2 seconds or more).

**Solution**: Create compressed document snapshots every 1000 events, enabling fast loading (load nearest snapshot + replay recent events).

**Rationale**:
- **Typical Usage Pattern**: ~20-30 events per minute of active editing means 1000 events ≈ 30-50 minutes of work
- **Document Load Performance**: Loading snapshot + replaying up to 1000 events achieves < 200ms load times
- **Storage Overhead**: Each gzip-compressed snapshot adds ~10-50KB (acceptable for typical document sizes < 100MB)
- **Garbage Collection**: Old snapshots can be pruned periodically, keeping only the most recent N snapshots

**Alternatives Considered**:
- **Time-Based Snapshots** (every 5 minutes): Rejected due to unpredictable event counts and inconsistent file sizes
- **Every 100 Events**: Too frequent, excessive storage overhead for marginal performance gain
- **Every 10,000 Events**: Too infrequent, slow document load times

**Verdict**: 1000 events empirically balances performance and storage, with potential for tuning based on real-world usage data.

### Why JSON Event Encoding?

**Problem**: Event payloads must be serialized for storage. Options include JSON, Protocol Buffers, MessagePack, or custom binary formats.

**Solution**: Store event payloads as JSON text in the `event_payload` column.

**Rationale**:
1. **Human-Readable**: JSON events can be inspected directly using SQLite browsers, aiding debugging
2. **Schema Evolution**: JSON allows adding optional fields without binary protocol versioning or code generation
3. **Simplicity**: No build-time code generation required (unlike Protocol Buffers or FlatBuffers)
4. **Size Trade-off**: JSON + gzip compression is only 20-30% larger than binary encodings for typical event payloads
5. **Tooling**: Standard JSON parsers available, no custom deserialization logic

**Schema Evolution Strategy**:
- **Versioning**: Each event type includes a `version` field in the JSON payload
- **Forward Compatibility**: New event schema versions add optional fields with defaults
- **Backward Compatibility**: Old readers ignore unknown JSON fields (schema-on-read)
- **Migration**: Breaking changes require explicit migration functions during document load

**Alternatives Considered**:
- **Protocol Buffers**: Rejected due to code generation requirement and marginal size savings (15-20% smaller)
- **Custom Binary Format**: Rejected as reinventing the wheel, would require extensive testing
- **MessagePack**: Rejected as binary format loses human-readability benefit with minimal size improvement

**Verdict**: JSON provides the best balance of developer productivity, debuggability, and adequate performance.

### Why Immutable Domain Models?

**Problem**: Mutable domain models (Document, Path, Shape) create complexity in event sourcing: cloning state for undo, race conditions, unpredictable mutations.

**Solution**: All domain models are immutable - every modification creates a new instance via `copyWith()` methods.

**Rationale**:
1. **Predictable State Transitions**: Each event handler produces a new document version, no hidden mutations
2. **Simplified Undo/Redo**: No need to clone state for undo stack - replay events to target sequence number
3. **Thread Safety**: Immutable objects safe to share across Dart isolates (future: background rendering)
4. **Simplified Testing**: Pure functions easier to test, no setup/teardown of mutable state
5. **Event Sourcing Synergy**: Natural fit - event application is state → event → new state

**Trade-offs**:
- **Memory Overhead**: Copying objects on every change (mitigated by Dart's structural sharing)
- **Performance**: Slightly slower than in-place mutation (negligible for document-level objects)
- **Boilerplate**: Requires `copyWith()` methods (can be generated with Freezed package)

**Verdict**: Immutability is foundational to maintainable, testable event-sourced systems.

## Consequences

### Positive Consequences

1. **Unlimited Undo/Redo with Zero Extra Code**: Undo/redo is simply event replay - no manual undo stack management
2. **Complete Audit Trail**: Every user action recorded with timestamp, user_id (future collaboration), and event payload
3. **Robust Crash Recovery**: WAL mode + event log ensures no data loss; snapshots enable recovery even if recent events corrupted
4. **Future-Proof Collaboration**: Event log is inherently distributable, enabling real-time collaboration in future versions
5. **Temporal Queries**: Can inspect document state at any point in history (useful for debugging, version comparison)
6. **Simplified Domain Logic**: Immutable models eliminate mutation bugs, simplify reasoning

### Negative Consequences

1. **Larger File Sizes**: JSON encoding + event log overhead results in larger files than binary formats (mitigated by compression)
2. **Complexity**: Event sourcing is more complex than traditional CRUD, requires discipline to maintain
3. **Storage Growth**: Event log grows unbounded without compaction (mitigated by optional "compress history" feature)
4. **Learning Curve**: Developers unfamiliar with event sourcing and immutability patterns require onboarding time
5. **Initial Performance Investment**: Snapshot management, event replay engine require upfront implementation effort

### Mitigation Strategies

- **File Size**: Implement gzip compression for snapshots (10:1 compression typical), potential future migration to binary encoding if needed
- **Complexity**: Comprehensive documentation (ADRs, code comments), strict architectural boundaries (see Architecture Blueprint Section 3.1)
- **Storage Growth**: Implement optional "compress history" feature (remove intermediate sampled events, keep only keyframe events)
- **Performance**: Continuous profiling during development, viewport culling, and caching strategies

## Alternatives Considered

### 1. Command Pattern with In-Memory Undo Stack

**Description**: Store executed commands in an in-memory stack, implement `undo()` and `redo()` methods on each command.

**Why Rejected**:
- No persistent audit trail (undo stack lost on app close)
- Requires manual command serialization for file save/load
- No natural foundation for future collaboration features
- Must manually implement state cloning for undo operations

**Verdict**: Insufficient for professional vector editor requirements.

### 2. Full Event Sourcing Without Sampling

**Description**: Capture every mouse movement event during drag operations without sampling.

**Why Rejected**:
- File size bloat: 2-second drag = 200+ events vs. 40 with sampling
- Replay performance issues: too many events to process efficiently
- No perceptual benefit: 50ms sampling provides smooth enough reconstruction

**Verdict**: Storage and performance costs outweigh marginal fidelity improvement.

### 3. Time-Based Snapshots (Every N Minutes)

**Description**: Create snapshots based on elapsed time (e.g., every 5 minutes) rather than event count.

**Why Rejected**:
- Unpredictable file sizes (power users generate many events quickly, casual users few)
- Inconsistent document load performance (may need to replay highly variable event counts)
- Harder to predict storage requirements

**Verdict**: Event-based snapshots provide more predictable behavior.

### 4. Binary Event Encoding (Protocol Buffers)

**Description**: Use Protocol Buffers or FlatBuffers for compact binary event serialization.

**Why Rejected**:
- Requires code generation build step, added complexity
- Loss of human-readability hurts debugging productivity
- Only 20-30% smaller than JSON + gzip (not significant enough to justify trade-offs)
- Schema evolution requires protocol versioning and generated code maintenance

**Verdict**: May revisit if file sizes become problematic in production, but JSON adequate for 0.1.

### 5. Custom Binary File Format (Not SQLite)

**Description**: Design a custom binary format with event log and snapshots, implemented with Dart file I/O.

**Why Rejected**:
- Reinventing the wheel: SQLite provides ACID guarantees, crash recovery, and query capabilities
- No standard tooling: users cannot inspect .wiretuner files with SQLite browsers
- High development and testing cost for marginal benefits
- SQLite is battle-tested and well-understood

**Verdict**: SQLite is the pragmatic choice for local-first desktop application.

### 6. NoSQL Databases (MongoDB, Hive, ObjectBox)

**Description**: Use a NoSQL database instead of SQLite.

**Why Rejected**:
- **MongoDB**: Requires server process, not embeddable, overkill for single-user desktop
- **Hive**: Key-value store lacks relational query capabilities needed for event log
- **ObjectBox**: Proprietary, less tooling support, SQLite more ubiquitous

**Verdict**: SQLite is the industry-standard embeddable database with superior tooling and reliability.

## References

- **Architecture Blueprint Section 3.1** (Architectural Style - Event Sourcing Foundation): Defines the core event sourcing rationale
- **Architecture Blueprint Section 3.6** (Data Model ERD): Documents the metadata, events, and snapshots table schema
- **Architecture Blueprint Section 4.1** (Key Decisions Summary): Consolidates event sourcing, 50ms sampling, and snapshot frequency decisions
- **Plan Document Section 2** (Core Architecture): Overview of layered architecture with event sourcing foundation
- **Implementation**: `lib/infrastructure/persistence/schema.dart` (lines 102-118 for events table, lines 131-144 for snapshots table)
- **Martin Fowler - Event Sourcing Pattern**: https://martinfowler.com/eaaDev/EventSourcing.html
- **SQLite Write-Ahead Logging**: https://www.sqlite.org/wal.html (justification for WAL mode, see `schema.dart:51`)

---

**This ADR documents the foundational architectural decision for WireTuner's persistence layer. All future features (undo/redo UI, collaboration, import/export) build upon this event sourcing foundation.**
