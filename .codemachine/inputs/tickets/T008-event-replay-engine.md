# T008: Event Replay Engine

## Status
- **Phase**: 1 - Core Event System
- **Priority**: Critical
- **Estimated Effort**: 1.5 days
- **Dependencies**: T007

## Overview
Implement the event replay engine that reconstructs document state by replaying events from snapshots.

## Objectives
- Load latest snapshot
- Replay events since snapshot
- Apply events to rebuild document state
- Support replay at specific sequence (for undo/redo)

## Implementation

### Replay Engine (lib/services/replay_engine.dart)
```dart
class ReplayEngine {
  Future<DocumentState> replayToSequence(int targetSequence) async {
    // 1. Find latest snapshot before target
    final snapshot = await _snapshotService.getLatestSnapshot(
      beforeSequence: targetSequence,
    );

    // 2. Load state from snapshot or create empty
    final state = snapshot != null
        ? DocumentState.fromJson(jsonDecode(snapshot.stateData))
        : DocumentState.empty();

    // 3. Get events since snapshot
    final fromSequence = snapshot?.sequence ?? 0;
    final events = await _eventRepo.getEvents(
      fromSequence: fromSequence + 1,
      toSequence: targetSequence,
    );

    // 4. Replay events
    for (final event in events) {
      _applyEvent(state, event);
    }

    return state;
  }

  void _applyEvent(DocumentState state, Event event) {
    switch (event.type) {
      case EventType.objectShapeCreated:
        final data = ObjectShapeCreatedEvent.fromEvent(event);
        state.addObject(/* ... */);
        break;
      case EventType.pathAnchorMoved:
        final data = PathAnchorMovedEvent.fromEvent(event);
        state.moveAnchor(/* ... */);
        break;
      // ... other event types ...
    }
  }
}
```

## Success Criteria

### Automated Verification
- [ ] Can replay from snapshot to current
- [ ] Can replay from beginning (no snapshot)
- [ ] Can replay to specific sequence
- [ ] State matches expected after replay
- [ ] All event types are handled

### Manual Verification
- [ ] Replaying document shows all objects correctly
- [ ] Replay performance is acceptable (<1s for 1000 events)
- [ ] Undo/redo works by replaying to previous sequence

## References
- T007: Snapshot System
