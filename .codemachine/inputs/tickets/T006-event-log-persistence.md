# T006: Event Log Table Schema and Persistence

## Status
- **Phase**: 1 - Core Event System
- **Priority**: Critical
- **Estimated Effort**: 0.5 days
- **Dependencies**: T002, T004

## Overview
Implement the database schema for storing events and create the persistence layer for reading/writing events to SQLite.

## Objectives
- Create events table schema
- Implement event persistence methods
- Add database indices for performance
- Support querying events by sequence, type, timestamp

## Implementation

### Database Schema Update (lib/services/database_service.dart)
```dart
Future<void> _onCreate(Database db, int version) async {
  // ... existing tables ...

  // Events table
  await db.execute('''
    CREATE TABLE events (
      id TEXT PRIMARY KEY,
      sequence INTEGER NOT NULL UNIQUE,
      timestamp TEXT NOT NULL,
      user_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      event_data TEXT NOT NULL
    )
  ''');

  await db.execute('CREATE INDEX idx_events_sequence ON events(sequence)');
  await db.execute('CREATE INDEX idx_events_timestamp ON events(timestamp)');
  await db.execute('CREATE INDEX idx_events_type ON events(event_type)');
  await db.execute('CREATE INDEX idx_events_user ON events(user_id)');
}
```

### Event Repository (lib/repositories/event_repository.dart)
```dart
class EventRepository {
  final Database _db;

  EventRepository(this._db);

  Future<void> insertEvent(Event event) async {
    await _db.insert('events', {
      'id': event.id,
      'sequence': event.sequence,
      'timestamp': event.timestamp.toIso8601String(),
      'user_id': event.userId,
      'event_type': event.type.value,
      'event_data': jsonEncode(event.data),
    });
  }

  Future<void> insertEvents(List<Event> events) async {
    final batch = _db.batch();
    for (final event in events) {
      batch.insert('events', {
        'id': event.id,
        'sequence': event.sequence,
        'timestamp': event.timestamp.toIso8601String(),
        'user_id': event.userId,
        'event_type': event.type.value,
        'event_data': jsonEncode(event.data),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Event>> getEvents({
    int? fromSequence,
    int? toSequence,
    EventType? type,
  }) async {
    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (fromSequence != null) {
      where.add('sequence >= ?');
      whereArgs.add(fromSequence);
    }
    if (toSequence != null) {
      where.add('sequence <= ?');
      whereArgs.add(toSequence);
    }
    if (type != null) {
      where.add('event_type = ?');
      whereArgs.add(type.value);
    }

    final results = await _db.query(
      'events',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sequence ASC',
    );

    return results.map((row) => Event.fromJson(row)).toList();
  }

  Future<int> getMaxSequence() async {
    final result = await _db.rawQuery('SELECT MAX(sequence) as max_seq FROM events');
    return (result.first['max_seq'] as int?) ?? 0;
  }
}
```

## Success Criteria

### Automated Verification
- [ ] Events table created with correct schema
- [ ] Indices created successfully
- [ ] Can insert single event
- [ ] Can batch insert multiple events
- [ ] Can query events by sequence range
- [ ] Can query events by type
- [ ] Events are returned in sequence order

### Manual Verification
- [ ] Database file contains events table
- [ ] Indices improve query performance
- [ ] Batch insert is faster than individual inserts

## References
- T003: Event Sourcing Architecture Design
