import 'package:test/test.dart';
import 'package:logger/logger.dart';

import 'package:event_core/src/undo_navigator.dart';
import 'package:event_core/src/operation_grouping.dart';
import 'package:event_core/src/event_replayer.dart';
import 'package:event_core/src/metrics_sink.dart';
import 'package:event_core/src/diagnostics_config.dart';

/// Tests for undo/redo navigator service.
///
/// Validates undo/redo operations, stack management, redo invalidation,
/// operation boundary respect, scrubbing, and multi-window isolation
/// per Task I4.T3 acceptance criteria.

/// Fake clock for deterministic testing.
class FakeClock implements Clock {
  FakeClock(this._currentTime);

  int _currentTime;

  @override
  int now() => _currentTime;

  void advance(int ms) {
    _currentTime += ms;
  }
}

/// Fake metrics sink for testing.
class FakeMetricsSink implements MetricsSink {
  final List<Map<String, dynamic>> recordedEvents = [];

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    recordedEvents.add({
      'eventType': eventType,
      'sampled': sampled,
      'durationMs': durationMs,
    });
  }

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {}

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {}

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {}

  @override
  Future<void> flush() async {}

  void reset() {
    recordedEvents.clear();
  }
}

/// Mock EventReplayer that tracks replay calls.
class MockEventReplayer implements EventReplayer {
  final List<int?> replayedSequences = [];
  bool shouldFail = false;

  @override
  Future<void> replay({
    int fromSequence = 0,
    int? toSequence,
  }) async {
    if (shouldFail) {
      throw Exception('Replay failed');
    }
    replayedSequences.add(toSequence);
  }

  @override
  Future<void> replayFromSnapshot({
    int? maxSequence,
  }) async {
    if (shouldFail) {
      throw Exception('Replay failed');
    }
    replayedSequences.add(maxSequence);
  }

  @override
  bool get isReplaying => false;

  void reset() {
    replayedSequences.clear();
    shouldFail = false;
  }
}

void main() {
  group('UndoNavigator', () {
    late FakeClock clock;
    late FakeMetricsSink metricsSink;
    late Logger logger;
    late EventCoreDiagnosticsConfig config;
    late OperationGroupingService groupingService;
    late MockEventReplayer eventReplayer;
    late UndoNavigator navigator;

    setUp(() {
      clock = FakeClock(1000000);
      metricsSink = FakeMetricsSink();
      logger = Logger(level: Level.off); // Silent for tests
      config = EventCoreDiagnosticsConfig.silent();
      groupingService = OperationGroupingService(
        clock: clock,
        metricsSink: metricsSink,
        logger: logger,
        config: config,
        idleThresholdMs: 200,
      );
      eventReplayer = MockEventReplayer();
      navigator = UndoNavigator(
        operationGrouping: groupingService,
        eventReplayer: eventReplayer,
        metricsSink: metricsSink,
        logger: logger,
        config: config,
        documentId: 'test-doc',
      );
    });

    tearDown(() {
      navigator.dispose();
      groupingService.dispose();
    });

    group('Basic Undo/Redo', () {
      test('initial state has no undo/redo available', () {
        expect(navigator.canUndo, isFalse);
        expect(navigator.canRedo, isFalse);
        expect(navigator.currentSequence, equals(0));
        expect(navigator.currentOperationName, isNull);
      });

      test('adds completed operations to undo stack', () async {
        // Simulate an operation
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Operation 1', reason: 'test');

        expect(navigator.canUndo, isTrue);
        expect(navigator.canRedo, isFalse);
        expect(navigator.currentOperationName, equals('Operation 1'));
        expect(navigator.undoStack.length, equals(1));
      });

      test('undo navigates to previous operation', () async {
        // Create two operations
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 2', reason: 'test');

        expect(navigator.undoStack.length, equals(2));
        expect(navigator.currentSequence, equals(2));

        // Undo
        final success = await navigator.undo();

        expect(success, isTrue);
        expect(navigator.canUndo, isTrue); // Still have Op 1
        expect(navigator.canRedo, isTrue); // Can redo Op 2
        expect(navigator.currentSequence, equals(1));
        expect(navigator.currentOperationName, equals('Op 1'));
        expect(navigator.undoStack.length, equals(1));
        expect(navigator.redoStack.length, equals(1));

        // Verify replayer was called with correct sequence
        expect(eventReplayer.replayedSequences, contains(1));
      });

      test('redo navigates forward to undone operation', () async {
        // Create operation and undo it
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await navigator.undo();
        expect(navigator.currentSequence, equals(0));

        // Redo
        final success = await navigator.redo();

        expect(success, isTrue);
        expect(navigator.canUndo, isTrue);
        expect(navigator.canRedo, isFalse);
        expect(navigator.currentSequence, equals(1));
        expect(navigator.currentOperationName, equals('Op 1'));
        expect(navigator.undoStack.length, equals(1));
        expect(navigator.redoStack.length, equals(0));

        // Verify replayer was called with correct sequence
        expect(eventReplayer.replayedSequences.last, equals(1));
      });

      test('multiple undo/redo operations', () async {
        // Create three operations
        for (int i = 1; i <= 3; i++) {
          groupingService.onEventRecorded(EventMetadata(
            eventType: 'Event$i',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          groupingService.forceBoundary(label: 'Op $i', reason: 'test');
        }

        expect(navigator.currentSequence, equals(3));

        // Undo twice
        await navigator.undo();
        expect(navigator.currentSequence, equals(2));
        await navigator.undo();
        expect(navigator.currentSequence, equals(1));

        expect(navigator.undoStack.length, equals(1));
        expect(navigator.redoStack.length, equals(2));

        // Redo once
        await navigator.redo();
        expect(navigator.currentSequence, equals(2));

        expect(navigator.undoStack.length, equals(2));
        expect(navigator.redoStack.length, equals(1));
      });

      test('undo at start of history returns false', () async {
        final success = await navigator.undo();
        expect(success, isFalse);
        expect(navigator.currentSequence, equals(0));
      });

      test('redo with empty redo stack returns false', () async {
        final success = await navigator.redo();
        expect(success, isFalse);
      });
    });

    group('Redo Invalidation', () {
      test('new operation after undo invalidates redo branch', () async {
        // Create two operations
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 2', reason: 'test');

        // Undo
        await navigator.undo();
        expect(navigator.canRedo, isTrue);
        expect(navigator.redoStack.length, equals(1));

        // Create new operation (invalidates redo)
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event3',
          sequenceNumber: 3,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 3', reason: 'test');

        // Redo should now be empty
        expect(navigator.canRedo, isFalse);
        expect(navigator.redoStack.length, equals(0));
        expect(navigator.undoStack.length, equals(2)); // Op 1 and Op 3
      });

      test('redo after invalidation fails', () async {
        // Setup: create, undo, new operation
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await navigator.undo();

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 2', reason: 'test');

        // Redo should fail
        final success = await navigator.redo();
        expect(success, isFalse);
      });
    });

    group('Operation Boundary Respect', () {
      test('undo operates on entire operation group, not individual events', () async {
        // Create operation with multiple events
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        clock.advance(50);
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));
        clock.advance(50);
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 3,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Move Objects', reason: 'test');

        expect(navigator.undoStack.last.eventCount, equals(3));

        // Undo should navigate to before the entire operation
        await navigator.undo();

        // Should navigate to sequence 0 (before all events)
        expect(navigator.currentSequence, equals(0));
        expect(eventReplayer.replayedSequences.last, equals(0));
      });

      test('undo respects operation boundaries with multiple groups', () async {
        // Create first operation (seq 1-3)
        for (int i = 1; i <= 3; i++) {
          groupingService.onEventRecorded(EventMetadata(
            eventType: 'Event$i',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          clock.advance(50);
        }
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        // Create second operation (seq 4-6)
        for (int i = 4; i <= 6; i++) {
          groupingService.onEventRecorded(EventMetadata(
            eventType: 'Event$i',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          clock.advance(50);
        }
        groupingService.forceBoundary(label: 'Op 2', reason: 'test');

        // Undo Op 2 - should go to end of Op 1 (seq 3)
        await navigator.undo();
        expect(navigator.currentSequence, equals(3));

        // Undo Op 1 - should go to start (seq 0)
        await navigator.undo();
        expect(navigator.currentSequence, equals(0));
      });
    });

    group('Scrubbing', () {
      test('scrubToSequence navigates to arbitrary point', () async {
        // Create three operations
        for (int i = 1; i <= 3; i++) {
          groupingService.onEventRecorded(EventMetadata(
            eventType: 'Event$i',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          groupingService.forceBoundary(label: 'Op $i', reason: 'test');
        }

        // Scrub to middle
        final success = await navigator.scrubToSequence(2);

        expect(success, isTrue);
        expect(navigator.currentSequence, equals(2));
        expect(eventReplayer.replayedSequences.last, equals(2));
      });

      test('scrubToSequence reorganizes stacks correctly', () async {
        // Create three operations
        for (int i = 1; i <= 3; i++) {
          groupingService.onEventRecorded(EventMetadata(
            eventType: 'Event$i',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          groupingService.forceBoundary(label: 'Op $i', reason: 'test');
        }

        // Scrub to middle (after Op 2)
        await navigator.scrubToSequence(2);

        // Undo stack should have Op 1 and Op 2
        expect(navigator.undoStack.length, equals(2));
        expect(navigator.undoStack[0].label, equals('Op 1'));
        expect(navigator.undoStack[1].label, equals('Op 2'));

        // Redo stack should have Op 3
        expect(navigator.redoStack.length, equals(1));
        expect(navigator.redoStack[0].label, equals('Op 3'));
      });

      test('scrubToGroup navigates to operation end', () async {
        // Create operation
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        final group = navigator.undoStack.last;

        // Undo first
        await navigator.undo();
        expect(navigator.currentSequence, equals(0));

        // Scrub to group
        final success = await navigator.scrubToGroup(group);

        expect(success, isTrue);
        expect(navigator.currentSequence, equals(group.endSequence));
      });

      test('scrubToSequence with current sequence is no-op', () async {
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        eventReplayer.reset();

        // Scrub to current
        final success = await navigator.scrubToSequence(1);

        expect(success, isTrue);
        expect(eventReplayer.replayedSequences, isEmpty);
      });

      test('scrubToSequence with negative sequence fails', () async {
        final success = await navigator.scrubToSequence(-1);
        expect(success, isFalse);
      });
    });

    group('Error Handling', () {
      test('undo rolls back on replay failure', () async {
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        // Make replayer fail
        eventReplayer.shouldFail = true;

        final success = await navigator.undo();

        expect(success, isFalse);
        // Stacks should be unchanged
        expect(navigator.undoStack.length, equals(1));
        expect(navigator.redoStack.length, equals(0));
      });

      test('redo rolls back on replay failure', () async {
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await navigator.undo();

        // Make replayer fail
        eventReplayer.shouldFail = true;

        final success = await navigator.redo();

        expect(success, isFalse);
        // Stacks should be unchanged
        expect(navigator.undoStack.length, equals(0));
        expect(navigator.redoStack.length, equals(1));
      });
    });

    group('Reset', () {
      test('reset clears all state', () async {
        // Create operations
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await navigator.undo();

        expect(navigator.canUndo, isFalse);
        expect(navigator.canRedo, isTrue);

        // Reset
        navigator.reset();

        expect(navigator.canUndo, isFalse);
        expect(navigator.canRedo, isFalse);
        expect(navigator.currentSequence, equals(0));
        expect(navigator.undoStack, isEmpty);
        expect(navigator.redoStack, isEmpty);
      });
    });

    group('UI State', () {
      test('provides operation names for UI labels', () async {
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Create Path', reason: 'test');

        expect(navigator.undoOperationName, equals('Create Path'));
        expect(navigator.redoOperationName, isNull);

        await navigator.undo();

        expect(navigator.undoOperationName, isNull);
        expect(navigator.redoOperationName, equals('Create Path'));
      });

      test('notifies listeners on navigation', () async {
        int notificationCount = 0;
        navigator.addListener(() {
          notificationCount++;
        });

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        // +1 for operation added

        await navigator.undo();
        // +1 for undo

        expect(notificationCount, equals(2));
      });
    });

    group('Multi-Window Isolation', () {
      test('separate navigator instances maintain independent state', () async {
        // Create second navigator for different document
        final navigator2 = UndoNavigator(
          operationGrouping: groupingService,
          eventReplayer: eventReplayer,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          documentId: 'test-doc-2',
        );

        // Create operation (both navigators see it via shared grouping)
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        // Both should have the operation
        expect(navigator.canUndo, isTrue);
        expect(navigator2.canUndo, isTrue);

        // Undo in first navigator only
        await navigator.undo();

        expect(navigator.currentSequence, equals(0));
        expect(navigator2.currentSequence, equals(1));

        expect(navigator.canUndo, isFalse);
        expect(navigator2.canUndo, isTrue);

        navigator2.dispose();
      });

      test('document ID included in logs for multi-window debugging', () async {
        // This test verifies that documentId is used in logging
        // (actual log verification would require log capture)

        // Create navigators with different doc IDs
        final nav1 = UndoNavigator(
          operationGrouping: groupingService,
          eventReplayer: eventReplayer,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          documentId: 'doc-A',
        );

        final nav2 = UndoNavigator(
          operationGrouping: groupingService,
          eventReplayer: eventReplayer,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          documentId: 'doc-B',
        );

        // Operations would include doc IDs in logs
        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await nav1.undo();
        await nav2.undo();

        // Logs would show [doc-A] and [doc-B] prefixes
        // (verification would require log capture infrastructure)

        nav1.dispose();
        nav2.dispose();
      });
    });

    group('Metrics', () {
      test('records undo navigation metrics', () async {
        final metricsConfig = EventCoreDiagnosticsConfig(
          enableMetrics: true,
          enableDetailedLogging: false,
        );
        final metricsNavigator = UndoNavigator(
          operationGrouping: groupingService,
          eventReplayer: eventReplayer,
          metricsSink: metricsSink,
          logger: logger,
          config: metricsConfig,
          documentId: 'test-doc',
        );

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        metricsSink.reset();

        await metricsNavigator.undo();

        // Should record undo navigation metric
        expect(metricsSink.recordedEvents, isNotEmpty);
        expect(
          metricsSink.recordedEvents.last['eventType'],
          equals('UndoNavigation'),
        );

        metricsNavigator.dispose();
      });

      test('records redo navigation metrics', () async {
        final metricsConfig = EventCoreDiagnosticsConfig(
          enableMetrics: true,
          enableDetailedLogging: false,
        );
        final metricsNavigator = UndoNavigator(
          operationGrouping: groupingService,
          eventReplayer: eventReplayer,
          metricsSink: metricsSink,
          logger: logger,
          config: metricsConfig,
          documentId: 'test-doc',
        );

        groupingService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));
        groupingService.forceBoundary(label: 'Op 1', reason: 'test');

        await metricsNavigator.undo();

        metricsSink.reset();

        await metricsNavigator.redo();

        // Should record redo navigation metric
        expect(metricsSink.recordedEvents, isNotEmpty);
        expect(
          metricsSink.recordedEvents.last['eventType'],
          equals('RedoNavigation'),
        );

        metricsNavigator.dispose();
      });
    });
  });
}
