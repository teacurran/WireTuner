# T005: Event Recorder with Sampling

## Status
- **Phase**: 1 - Core Event System
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T004

## Overview
Implement the EventRecorder service that captures user interactions and records them as events with appropriate sampling for continuous interactions like dragging.

## Objectives
- Create EventRecorder service
- Implement 50-100ms sampling for continuous interactions
- Manage event sequence numbers
- Buffer events before database write
- Handle interaction sessions (drag start → drag end)

## Requirements

### Functional Requirements
1. Record discrete events immediately (clicks, creations)
2. Sample continuous events at 50-100ms intervals
3. Maintain sequential ordering of events
4. Support interaction sessions with unique IDs
5. Batch events for efficient database writes

### Technical Requirements
- Thread-safe sequence number generation
- Configurable sampling interval (default 50ms)
- Event buffer with automatic flush
- Memory-efficient path sampling

## Implementation Details

### Event Recorder Service (lib/services/event_recorder.dart)
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wiretuner/models/events/event.dart';
import 'package:wiretuner/services/database_service.dart';

class EventRecorder {
  static const Duration samplingInterval = Duration(milliseconds: 50);
  static const int bufferFlushSize = 10;

  final DatabaseService _db;
  final String _userId;

  int _currentSequence = 0;
  final List<Event> _eventBuffer = [];
  Timer? _flushTimer;

  // Sampling state
  DateTime? _lastSampleTime;
  String? _currentInteractionId;
  List<Offset> _currentSampledPath = [];
  DateTime? _interactionStartTime;

  EventRecorder(this._db, this._userId) {
    _initializeSequence();
    _startFlushTimer();
  }

  Future<void> _initializeSequence() async {
    // Get last sequence number from database
    final result = await _db.database?.query(
      'events',
      columns: ['MAX(sequence) as max_seq'],
    );
    if (result != null && result.isNotEmpty) {
      _currentSequence = (result.first['max_seq'] as int?) ?? 0;
    }
  }

  int _nextSequence() => ++_currentSequence;

  /// Record a discrete event (happens once, no sampling)
  Future<void> recordEvent(Event event) async {
    _eventBuffer.add(event);

    if (_eventBuffer.length >= bufferFlushSize) {
      await _flush();
    }
  }

  /// Start recording a continuous interaction (drag, draw, etc.)
  void startInteraction(String interactionId) {
    _currentInteractionId = interactionId;
    _interactionStartTime = DateTime.now();
    _currentSampledPath.clear();
    _lastSampleTime = null;
  }

  /// Add a sample point to current interaction
  void addSample(Offset position) {
    if (_currentInteractionId == null) return;

    final now = DateTime.now();
    if (_lastSampleTime == null ||
        now.difference(_lastSampleTime!) >= samplingInterval) {
      _currentSampledPath.add(position);
      _lastSampleTime = now;
    }
  }

  /// End current interaction and record the event
  Future<void> endInteraction(EventType eventType) async {
    if (_currentInteractionId == null) return;

    final event = Event(
      sequence: _nextSequence(),
      userId: _userId,
      type: eventType,
      data: {
        'interactionId': _currentInteractionId!,
        'sampledPath': _currentSampledPath
            .map((offset) => {'x': offset.dx, 'y': offset.dy})
            .toList(),
        'startTime': _interactionStartTime!.toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
      },
    );

    await recordEvent(event);

    // Reset state
    _currentInteractionId = null;
    _currentSampledPath.clear();
    _lastSampleTime = null;
    _interactionStartTime = null;
  }

  /// Manually flush event buffer to database
  Future<void> _flush() async {
    if (_eventBuffer.isEmpty) return;

    final batch = _db.database?.batch();
    if (batch == null) return;

    for (final event in _eventBuffer) {
      batch.insert('events', {
        'sequence': event.sequence,
        'timestamp': event.timestamp.toIso8601String(),
        'user_id': event.userId,
        'event_type': event.type.value,
        'event_data': jsonEncode(event.data),
      });
    }

    await batch.commit(noResult: true);
    _eventBuffer.clear();
  }

  /// Start periodic flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _flush();
    });
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush(); // Final flush
  }
}
```

### Helper Methods for Common Events

```dart
// Extension methods for convenient event recording
extension EventRecorderExtensions on EventRecorder {
  Future<void> recordPathAnchorMoved({
    required String objectId,
    required int anchorIndex,
    required Offset oldPosition,
    required Offset newPosition,
  }) async {
    final event = Event(
      sequence: _nextSequence(),
      userId: _userId,
      type: EventType.pathAnchorMoved,
      data: {
        'objectId': objectId,
        'anchorIndex': anchorIndex,
        'oldPosition': {'x': oldPosition.dx, 'y': oldPosition.dy},
        'newPosition': {'x': newPosition.dx, 'y': newPosition.dy},
      },
    );
    await recordEvent(event);
  }

  Future<void> recordShapeCreated({
    required String objectId,
    required String shapeType,
    required Rect bounds,
    Map<String, dynamic>? properties,
  }) async {
    final event = Event(
      sequence: _nextSequence(),
      userId: _userId,
      type: EventType.objectShapeCreated,
      data: {
        'objectId': objectId,
        'shapeType': shapeType,
        'bounds': {
          'left': bounds.left,
          'top': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        },
        if (properties != null) 'properties': properties,
      },
    );
    await recordEvent(event);
  }

  Future<void> recordSelectionChanged({
    required List<String> selectedObjectIds,
    required List<String> previouslySelectedObjectIds,
  }) async {
    final event = Event(
      sequence: _nextSequence(),
      userId: _userId,
      type: EventType.selectionChanged,
      data: {
        'selectedObjectIds': selectedObjectIds,
        'previouslySelectedObjectIds': previouslySelectedObjectIds,
      },
    );
    await recordEvent(event);
  }
}
```

## Success Criteria

### Automated Verification
- [ ] Unit tests pass:
  - [ ] Sequence numbers increment correctly
  - [ ] Discrete events are recorded immediately
  - [ ] Sampling respects 50ms interval
  - [ ] Buffer flushes at threshold
  - [ ] Interaction sessions track start/end
  - [ ] Events are written to database correctly

### Manual Verification
- [ ] Multiple events have sequential sequence numbers
- [ ] Sampled paths have ~20 samples per second (50ms interval)
- [ ] No dropped events during rapid interactions
- [ ] Database writes are batched (not one-by-one)
- [ ] Memory usage remains stable during long editing sessions

## Testing Strategy

### Unit Tests (test/services/event_recorder_test.dart)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/services/event_recorder.dart';

void main() {
  group('EventRecorder', () {
    late EventRecorder recorder;

    setUp(() {
      // Setup test database and recorder
    });

    test('generates sequential sequence numbers', () async {
      final event1 = Event(/* ... */);
      final event2 = Event(/* ... */);

      await recorder.recordEvent(event1);
      await recorder.recordEvent(event2);

      expect(event2.sequence, event1.sequence + 1);
    });

    test('samples at correct interval', () async {
      recorder.startInteraction('drag_1');

      // Simulate 200ms of samples at 50ms intervals
      for (int i = 0; i < 5; i++) {
        recorder.addSample(Offset(i * 10.0, i * 10.0));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await recorder.endInteraction(EventType.interactionDrag);

      // Should have ~4 samples (one every 50ms)
      expect(recorder._currentSampledPath.length, greaterThanOrEqualTo(3));
    });

    test('flushes buffer at threshold', () async {
      for (int i = 0; i < 15; i++) {
        await recorder.recordEvent(Event(/* ... */));
      }

      // Buffer should have flushed after 10 events
      expect(recorder._eventBuffer.length, lessThan(10));
    });
  });
}
```

## Notes
- Buffer size and flush interval can be tuned for performance
- Consider adding event compression for large sampled paths
- Monitor memory usage in profiler during implementation
- May need to handle buffer overflow in extreme cases

## References
- T004: Event Model
- Design Document: `/Users/tea/dev/github/wiretuner/thoughts/shared/tickets/T003-event-sourcing-architecture-design.md`
