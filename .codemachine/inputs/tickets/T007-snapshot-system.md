# T007: Snapshot System

## Status
- **Phase**: 1 - Core Event System
- **Priority**: High
- **Estimated Effort**: 1 day
- **Dependencies**: T006

## Overview
Implement periodic snapshot creation to enable fast document loading without replaying all events.

## Objectives
- Create snapshots table schema
- Implement snapshot creation (every 1000 events or 10 minutes)
- Serialize document state to JSON
- Store and retrieve snapshots

## Implementation

### Snapshots Table Schema
```sql
CREATE TABLE snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sequence INTEGER NOT NULL UNIQUE,
  timestamp TEXT NOT NULL,
  state_data TEXT NOT NULL
);
CREATE INDEX idx_snapshots_sequence ON snapshots(sequence);
```

### Snapshot Service (lib/services/snapshot_service.dart)
```dart
class SnapshotService {
  static const int snapshotInterval = 1000; // Every 1000 events

  Future<void> createSnapshot(int sequence, DocumentState state) async {
    await _db.insert('snapshots', {
      'sequence': sequence,
      'timestamp': DateTime.now().toIso8601String(),
      'state_data': jsonEncode(state.toJson()),
    });
  }

  Future<Snapshot?> getLatestSnapshot({int? beforeSequence}) async {
    // Query most recent snapshot
  }

  bool shouldCreateSnapshot(int currentSequence, int lastSnapshotSequence) {
    return currentSequence - lastSnapshotSequence >= snapshotInterval;
  }
}
```

## Success Criteria

### Automated Verification
- [ ] Snapshots table created
- [ ] Can create snapshot at sequence N
- [ ] Can retrieve latest snapshot
- [ ] Can retrieve snapshot before sequence N

### Manual Verification
- [ ] Snapshots created every 1000 events
- [ ] Snapshot contains complete document state
- [ ] Loading from snapshot is faster than full replay

## References
- T003: Architecture Design
