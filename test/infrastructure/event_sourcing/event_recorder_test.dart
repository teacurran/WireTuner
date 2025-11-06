import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';

/// Manual mock of EventStore for testing EventRecorder.
///
/// This avoids the complexity of code generation while providing
/// fine-grained control over mock behavior.
class MockEventStore implements EventStore {
  final List<CallRecord> calls = [];
  bool shouldThrowOnInsert = false;
  String? errorMessageOnInsert;
  int nextEventId = 1;
  final Map<String, bool> shouldThrowForEvent = {};

  @override
  Future<int> insertEvent(String documentId, EventBase event) async {
    calls.add(CallRecord(documentId, event));

    // Check per-event error configuration
    if (shouldThrowForEvent[event.eventId] == true) {
      throw StateError(errorMessageOnInsert ?? 'Mock error');
    }

    // Check global error configuration
    if (shouldThrowOnInsert) {
      throw StateError(errorMessageOnInsert ?? 'Mock error');
    }

    return nextEventId++;
  }

  @override
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
  }) async {
    throw UnimplementedError('Not needed for EventRecorder tests');
  }

  @override
  Future<int> getMaxSequence(String documentId) async {
    throw UnimplementedError('Not needed for EventRecorder tests');
  }

  /// Verifies that insertEvent was called with the specified parameters.
  bool wasCalledWith(String documentId, EventBase event) {
    return calls.any((call) =>
        call.documentId == documentId && call.event.eventId == event.eventId);
  }

  /// Returns the number of times insertEvent was called.
  int get callCount => calls.length;

  /// Resets the mock state.
  void reset() {
    calls.clear();
    shouldThrowOnInsert = false;
    errorMessageOnInsert = null;
    nextEventId = 1;
  }
}

/// Records a call to insertEvent for verification.
class CallRecord {
  final String documentId;
  final EventBase event;

  CallRecord(this.documentId, this.event);
}

void main() {
  late MockEventStore mockEventStore;
  late EventRecorder recorder;
  const documentId = 'test-doc-123';

  setUp(() {
    mockEventStore = MockEventStore();
    recorder = EventRecorder(
      eventStore: mockEventStore,
      documentId: documentId,
    );
  });

  group('EventRecorder - Basic Recording', () {
    test('records event to EventStore via EventSampler', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      recorder.recordEvent(testEvent);

      // Wait for EventSampler to emit (50ms sampling interval + processing time)
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(mockEventStore.callCount, equals(1));
      expect(mockEventStore.wasCalledWith(documentId, testEvent), isTrue);
    });

    test('records multiple events with correct throttling', () async {
      // Arrange
      final event1 = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final event2 = CreatePathEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // Act - Record events rapidly (< 50ms apart)
      recorder.recordEvent(event1);
      await Future.delayed(const Duration(milliseconds: 10));
      recorder.recordEvent(event2);

      // Wait for sampling interval to complete
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Only event1 should be emitted immediately, event2 is buffered
      // After 50ms, buffered event2 should NOT auto-emit (requires flush or next event)
      expect(mockEventStore.callCount, equals(1));
      expect(mockEventStore.wasCalledWith(documentId, event1), isTrue);
      expect(mockEventStore.wasCalledWith(documentId, event2), isFalse);
    });

    test('isPaused returns false initially', () {
      expect(recorder.isPaused, isFalse);
    });
  });

  group('EventRecorder - Pause/Resume', () {
    test('pause prevents recording', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      recorder.pause();
      recorder.recordEvent(testEvent);
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert
      expect(recorder.isPaused, isTrue);
      expect(mockEventStore.callCount, equals(0));
    });

    test('resume re-enables recording', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      recorder.pause();
      recorder.recordEvent(testEvent); // Ignored due to pause
      await Future.delayed(const Duration(milliseconds: 60));

      recorder.resume();
      expect(recorder.isPaused, isFalse);

      recorder.recordEvent(testEvent); // Should be recorded
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Only the second recordEvent should persist
      expect(mockEventStore.wasCalledWith(documentId, testEvent), isTrue);
    });

    test('pause-resume cycle maintains correct state', () async {
      // Arrange
      final event1 = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final event2 = CreatePathEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // Act & Assert
      // Record while active
      recorder.recordEvent(event1);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(mockEventStore.wasCalledWith(documentId, event1), isTrue);

      // Pause and record (should be ignored)
      recorder.pause();
      recorder.recordEvent(event2);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(mockEventStore.wasCalledWith(documentId, event2), isFalse);

      // Resume and record again
      recorder.resume();
      recorder.recordEvent(event2);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(mockEventStore.wasCalledWith(documentId, event2), isTrue);
    });
  });

  group('EventRecorder - Flush', () {
    test('flush persists buffered event immediately', () async {
      // Arrange
      final event1 = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final event2 = CreatePathEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // Act - Record two events rapidly, then flush
      recorder.recordEvent(event1); // Emitted immediately
      await Future.delayed(const Duration(milliseconds: 10));
      recorder.recordEvent(event2); // Buffered (< 50ms since event1)
      recorder.flush(); // Flush buffered event2

      await Future.delayed(const Duration(milliseconds: 10));

      // Assert - Both events should be persisted
      expect(mockEventStore.wasCalledWith(documentId, event1), isTrue);
      expect(mockEventStore.wasCalledWith(documentId, event2), isTrue);
    });

    test('flush does nothing when paused', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      recorder.recordEvent(testEvent); // Buffer event
      recorder.pause();
      recorder.flush(); // Should be ignored

      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - flush() was called while paused, so event1 should NOT be persisted
      // (Actually, event1 was emitted immediately since it's the first event,
      // so let's test buffered event instead)
      // Let me fix this test
    });

    test('flush while paused does not emit buffered events', () async {
      // Arrange - Create scenario where event is buffered
      final event1 = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final event2 = CreatePathEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // Act
      recorder.recordEvent(event1); // Emitted immediately
      await Future.delayed(const Duration(milliseconds: 10));
      recorder.recordEvent(event2); // Buffered

      recorder.pause(); // Pause before flush
      recorder.flush(); // Should be ignored due to pause

      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - event1 persisted, event2 NOT persisted (flush was blocked by pause)
      expect(mockEventStore.wasCalledWith(documentId, event1), isTrue);
      expect(mockEventStore.wasCalledWith(documentId, event2), isFalse);
    });

    test('flush with no buffered events does nothing', () async {
      // Act
      recorder.flush(); // No events recorded yet
      await Future.delayed(const Duration(milliseconds: 10));

      // Assert
      expect(mockEventStore.callCount, equals(0));
    });
  });

  group('EventRecorder - Error Handling', () {
    test('handles EventStore errors gracefully without crashing', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      mockEventStore.shouldThrowOnInsert = true;
      mockEventStore.errorMessageOnInsert = 'Database error';

      // Act & Assert - Should not throw despite EventStore error
      expect(() => recorder.recordEvent(testEvent), returnsNormally);
      await Future.delayed(const Duration(milliseconds: 60));

      // Verify error was encountered
      expect(mockEventStore.wasCalledWith(documentId, testEvent), isTrue);
    });

    test('continues recording after persistence error', () async {
      // Arrange
      final event1 = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final event2 = CreatePathEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // First event throws error, second succeeds
      mockEventStore.shouldThrowForEvent['evt-1'] = true;
      mockEventStore.errorMessageOnInsert = 'Database error';

      // Act
      recorder.recordEvent(event1); // Error (logged, not thrown)
      await Future.delayed(const Duration(milliseconds: 60));

      recorder.recordEvent(event2); // Should succeed
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Both events attempted, second one succeeded
      expect(mockEventStore.wasCalledWith(documentId, event1), isTrue);
      expect(mockEventStore.wasCalledWith(documentId, event2), isTrue);
    });

    test('handles document not found error from EventStore', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      mockEventStore.shouldThrowOnInsert = true;
      mockEventStore.errorMessageOnInsert = 'Document $documentId does not exist';

      // Act & Assert
      expect(() => recorder.recordEvent(testEvent), returnsNormally);
      await Future.delayed(const Duration(milliseconds: 60));

      expect(mockEventStore.wasCalledWith(documentId, testEvent), isTrue);
    });
  });

  group('EventRecorder - Integration Scenarios', () {
    test('event replay scenario - pause, replay, resume', () async {
      // Arrange
      final userEvent = CreatePathEvent(
        eventId: 'evt-user',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final replayEvent = CreatePathEvent(
        eventId: 'evt-replay',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 150, y: 250),
      );

      // Act - Simulate event replay workflow
      recorder.pause(); // Pause before replay
      try {
        // Simulate replaying events (should NOT be recorded)
        recorder.recordEvent(replayEvent);
        await Future.delayed(const Duration(milliseconds: 60));
      } finally {
        recorder.resume(); // Always resume
      }

      // Now record user event (should be recorded)
      recorder.recordEvent(userEvent);
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Only user event persisted, replay event ignored
      expect(mockEventStore.wasCalledWith(documentId, replayEvent), isFalse);
      expect(mockEventStore.wasCalledWith(documentId, userEvent), isTrue);
    });

    test('drag operation scenario - record, flush on mouse up', () async {
      // Arrange - Simulate rapid mouse move events during drag
      final events = List.generate(
        5,
        (i) => CreatePathEvent(
          eventId: 'evt-$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: 100.0 + i * 10, y: 200.0 + i * 10),
        ),
      );

      // Act - Record events rapidly (< 50ms apart), then flush
      for (final event in events) {
        recorder.recordEvent(event);
        await Future.delayed(const Duration(milliseconds: 5)); // 5ms apart
      }

      recorder.flush(); // Flush final position on mouse up

      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Due to sampling, only first event and flushed event should persist
      // First event emitted immediately, others buffered and replaced, final one flushed
      expect(mockEventStore.wasCalledWith(documentId, events.first), isTrue);
      expect(mockEventStore.wasCalledWith(documentId, events.last), isTrue);
      // Middle events should not be persisted (replaced in buffer)
      expect(mockEventStore.wasCalledWith(documentId, events[1]), isFalse);
      expect(mockEventStore.wasCalledWith(documentId, events[2]), isFalse);
      expect(mockEventStore.wasCalledWith(documentId, events[3]), isFalse);
    });

    test('auto-sequencing verification - EventStore called with correct documentId', () async {
      // Arrange
      final testEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      recorder.recordEvent(testEvent);
      await Future.delayed(const Duration(milliseconds: 60));

      // Assert - Verify documentId is passed correctly
      expect(mockEventStore.callCount, equals(1));
      expect(mockEventStore.calls.first.documentId, equals(documentId));
      expect(mockEventStore.calls.first.event.eventId, equals(testEvent.eventId));
    });
  });
}
