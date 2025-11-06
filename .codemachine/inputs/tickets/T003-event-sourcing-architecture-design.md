# T003: Event Sourcing Architecture Design Document

## Status
- **Phase**: 0 - Foundation & Setup
- **Priority**: Critical
- **Estimated Effort**: 0.5 days
- **Dependencies**: T002

## Overview
Create comprehensive design document for the event sourcing architecture. This document will guide implementation of the core differentiating feature of WireTuner: full interaction recording and replay.

## Objectives
- Define event sourcing architecture patterns
- Document event types and schemas
- Design snapshot strategy
- Plan replay mechanism
- Address multi-user collaboration considerations

## Requirements

### Functional Requirements
1. Architecture supports recording all user interactions
2. Design enables perfect replay of document history
3. Snapshot strategy balances performance and storage
4. Schema supports future multi-user collaboration
5. Design accounts for forward compatibility

## Implementation Details

### Architecture Design Document

Create: `thoughts/shared/research/2025-11-05-event-sourcing-architecture.md`

**Contents:**

```markdown
# WireTuner Event Sourcing Architecture

## Overview
WireTuner uses event sourcing as its core architectural pattern. Every user interaction is recorded as an immutable event in the database, enabling complete history tracking, replay, undo/redo, and future collaboration features.

## Core Concepts

### Events
An **Event** represents a single user action or system state change:
- Immutable once written
- Sequential (ordered by timestamp and sequence number)
- Self-contained (includes all data needed to apply the event)
- Typed (explicit event_type field)

### Event Log
The **Event Log** is an append-only sequence of all events:
- Never delete or modify events
- New events are always appended
- Query by filtering and ordering

### Snapshots
A **Snapshot** captures the complete document state at a point in time:
- Created periodically (every N events or M minutes)
- Enables fast document loading without replaying all events
- Acts as performance optimization, not source of truth

### Materialized State
The **Materialized State** is the current document state:
- Computed by replaying events from last snapshot
- Held in memory during editing
- Rendered to canvas
- Exported to SVG/PDF/AI

## Database Schema

### events table
```sql
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sequence INTEGER NOT NULL,           -- Logical ordering
  timestamp TEXT NOT NULL,              -- ISO 8601 timestamp
  user_id TEXT NOT NULL,                -- For future collaboration
  event_type TEXT NOT NULL,             -- Event type identifier
  event_data TEXT NOT NULL,             -- JSON payload
  sampled_path TEXT,                    -- For mouse movements (JSON array)

  UNIQUE(sequence)
);

CREATE INDEX idx_events_sequence ON events(sequence);
CREATE INDEX idx_events_timestamp ON events(timestamp);
CREATE INDEX idx_events_type ON events(event_type);
```

### snapshots table
```sql
CREATE TABLE snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sequence INTEGER NOT NULL,            -- Last event included in snapshot
  timestamp TEXT NOT NULL,
  state_data TEXT NOT NULL,             -- JSON serialized state
  compressed INTEGER DEFAULT 0,         -- 1 if data is compressed

  UNIQUE(sequence)
);

CREATE INDEX idx_snapshots_sequence ON snapshots(sequence);
```

## Event Types

### Document Events
- `document.created` - New document initialized
- `document.metadata_changed` - Name, author, etc. updated

### Object Creation Events
- `object.path.created` - New path created with pen tool
- `object.shape.created` - New shape created (rect, ellipse, etc.)
- `object.imported` - Objects imported from external file

### Object Modification Events
- `object.transformed` - Object moved, scaled, rotated
- `object.styled` - Color, stroke, fill changed
- `object.deleted` - Object removed
- `object.duplicated` - Object copied

### Path Editing Events
- `path.anchor.added` - New anchor point added
- `path.anchor.moved` - Anchor point dragged
- `path.anchor.deleted` - Anchor point removed
- `path.bcp.adjusted` - Bezier control point moved
- `path.segment.type_changed` - Straight ↔ Curve conversion

### Selection Events
- `selection.changed` - Selection set updated
- `selection.cleared` - All objects deselected

### Viewport Events
- `viewport.panned` - Canvas panned
- `viewport.zoomed` - Canvas zoom changed

### Interaction Events (Sampled)
- `interaction.drag` - Mouse drag with sampled path
- `interaction.draw` - Freehand drawing with sampled path

## Event Sampling Strategy

### High-Fidelity Events (Every Event)
Record every occurrence:
- Anchor point creation
- Anchor point deletion
- BCP adjustments (record start + end position)
- Object creation
- Selection changes

### Sampled Events (50-100ms intervals)
Record at time intervals:
- Mouse movements during drag operations
- Freehand drawing paths
- Continuous pan/zoom operations

**Implementation:**
```dart
class EventSampler {
  static const Duration sampleInterval = Duration(milliseconds: 50);
  DateTime? _lastSampleTime;
  List<Offset> _currentSamples = [];

  bool shouldSample() {
    final now = DateTime.now();
    if (_lastSampleTime == null ||
        now.difference(_lastSampleTime!) >= sampleInterval) {
      _lastSampleTime = now;
      return true;
    }
    return false;
  }

  void addSample(Offset position) {
    if (shouldSample()) {
      _currentSamples.add(position);
    }
  }

  List<Offset> collectSamples() {
    final samples = List<Offset>.from(_currentSamples);
    _currentSamples.clear();
    _lastSampleTime = null;
    return samples;
  }
}
```

## Snapshot Strategy

### When to Create Snapshots
1. **Event count threshold**: Every 1000 events
2. **Time threshold**: Every 10 minutes of active editing
3. **Manual trigger**: On explicit "Save" action
4. **Document close**: When document is closed

### Snapshot Format
```json
{
  "version": 1,
  "sequence": 5432,
  "timestamp": "2025-11-05T10:30:00Z",
  "document": {
    "metadata": { "name": "My Design", "author": "user" },
    "artboards": [...],
    "objects": [...],
    "layers": [...]
  }
}
```

### Loading Strategy
1. Find most recent snapshot before current sequence
2. Load snapshot into memory
3. Replay events since snapshot
4. Materialize final state

## Replay Mechanism

### Full Replay
Replay all events from beginning (for debugging, analysis):
```dart
Future<DocumentState> replayAll() async {
  final events = await _db.query('events', orderBy: 'sequence ASC');
  final state = DocumentState.empty();
  for (final event in events) {
    state.apply(event);
  }
  return state;
}
```

### Incremental Replay
Replay from last snapshot (for normal loading):
```dart
Future<DocumentState> replayFromSnapshot() async {
  final snapshot = await _getLatestSnapshot();
  final state = DocumentState.fromSnapshot(snapshot);
  final events = await _db.query(
    'events',
    where: 'sequence > ?',
    whereArgs: [snapshot.sequence],
    orderBy: 'sequence ASC',
  );
  for (final event in events) {
    state.apply(event);
  }
  return state;
}
```

## Multi-User Collaboration (Future)

### User Identification
Each event includes `user_id` field:
- Single user: always same ID
- Multi-user: unique ID per user

### Conflict Resolution Strategies

**Option 1: Operational Transform (OT)**
- Transform concurrent operations to be commutative
- Complex but well-studied (Google Docs uses this)

**Option 2: CRDT (Conflict-free Replicated Data Types)**
- Use data structures that merge automatically
- Simpler than OT but constrains operations

**Option 3: Last-Write-Wins (LWW)**
- Use timestamps to resolve conflicts
- Simple but can lose data

**Recommendation**: Start with LWW for MVP, evaluate OT/CRDT later.

### Event Synchronization
```sql
-- Add sync fields to events table
ALTER TABLE events ADD COLUMN synced INTEGER DEFAULT 0;
ALTER TABLE events ADD COLUMN origin TEXT; -- 'local' or remote server ID
```

## Forward Compatibility

### Schema Versioning
- Always include schema version in database
- Old app versions refuse to open newer schemas
- New app versions migrate older schemas

### Event Versioning
Include version in event_data:
```json
{
  "version": 1,
  "type": "path.anchor.moved",
  "data": {
    "object_id": "path_123",
    "anchor_index": 2,
    "old_position": {"x": 10, "y": 20},
    "new_position": {"x": 15, "y": 25}
  }
}
```

### Handling Unknown Events
```dart
void applyEvent(Event event) {
  switch (event.type) {
    case 'path.anchor.moved':
      _handleAnchorMoved(event);
      break;
    // ... other known events ...
    default:
      // Unknown event type - log warning but don't crash
      print('Warning: Unknown event type: ${event.type}');
      // Store in "unknown_events" for potential future processing
  }
}
```

## Performance Considerations

### Memory Usage
- Load snapshots incrementally for large documents
- Consider LRU cache for event replay results
- Stream events instead of loading all into memory

### Storage Size
- 50ms sampling reduces data vs 60fps by ~92%
- Snapshots add overhead but enable fast loading
- Consider compressing snapshot data (gzip)

### Query Optimization
- Index on sequence, timestamp, event_type
- Use prepared statements for repeated queries
- Batch inserts for multiple events

## Undo/Redo

Undo/redo becomes trivial with event sourcing:

```dart
class UndoManager {
  int _currentSequence;

  Future<void> undo() async {
    // Find last non-viewport event before current
    final event = await _db.query(
      'events',
      where: 'sequence < ? AND event_type NOT LIKE "viewport.%"',
      whereArgs: [_currentSequence],
      orderBy: 'sequence DESC',
      limit: 1,
    );

    if (event.isNotEmpty) {
      _currentSequence = event.first['sequence'];
      await _replayToSequence(_currentSequence);
    }
  }

  Future<void> redo() async {
    // Find next non-viewport event after current
    final event = await _db.query(
      'events',
      where: 'sequence > ? AND event_type NOT LIKE "viewport.%"',
      whereArgs: [_currentSequence],
      orderBy: 'sequence ASC',
      limit: 1,
    );

    if (event.isNotEmpty) {
      _currentSequence = event.first['sequence'];
      await _replayToSequence(_currentSequence);
    }
  }
}
```

## References
- Event Sourcing Pattern: https://martinfowler.com/eaaDev/EventSourcing.html
- CQRS: https://martinfowler.com/bliki/CQRS.html
- Operational Transform: https://en.wikipedia.org/wiki/Operational_transformation
- CRDTs: https://crdt.tech/
```

## Success Criteria

### Automated Verification
- [ ] Design document created in thoughts/shared/research/
- [ ] No unresolved architectural questions

### Manual Verification
- [ ] Document reviewed and approved
- [ ] Event types cover all Milestone 0.1 interactions
- [ ] Snapshot strategy is clearly defined
- [ ] Database schema supports all event types
- [ ] Multi-user groundwork is present but not blocking MVP
- [ ] Performance considerations addressed

## Notes
- This is a design document, not implementation
- Will be referenced by T004-T008 for implementation
- May need updates as implementation reveals issues
- Critical to get right before implementation starts

## References
- Product Vision: `/Users/tea/dev/github/wiretuner/thoughts/shared/research/2025-11-05-product-vision.md`
- Event Sourcing Pattern: https://martinfowler.com/eaaDev/EventSourcing.html
