/// Tests for operation grouping service.
///
/// Validates automatic idle threshold detection, manual boundary control,
/// and edge cases per Task I4.T1 acceptance criteria.
import 'package:test/test.dart';
import 'package:logger/logger.dart';

import 'package:event_core/src/operation_grouping.dart';
import 'package:event_core/src/metrics_sink.dart';
import 'package:event_core/src/diagnostics_config.dart';

/// Fake clock for deterministic testing.
class FakeClock implements Clock {
  FakeClock(this._currentTime);

  int _currentTime;

  @override
  int now() => _currentTime;

  /// Advances time by [ms] milliseconds.
  void advance(int ms) {
    _currentTime += ms;
  }

  /// Sets absolute time.
  void setTime(int ms) {
    _currentTime = ms;
  }
}

/// Fake metrics sink for testing.
class FakeMetricsSink implements MetricsSink {
  final List<Map<String, dynamic>> recordedEvents = [];
  final List<Map<String, dynamic>> recordedReplays = [];
  final List<Map<String, dynamic>> recordedSnapshots = [];
  final List<Map<String, dynamic>> recordedSnapshotLoads = [];

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
  }) {
    recordedReplays.add({
      'eventCount': eventCount,
      'fromSequence': fromSequence,
      'toSequence': toSequence,
      'durationMs': durationMs,
    });
  }

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    recordedSnapshots.add({
      'sequenceNumber': sequenceNumber,
      'snapshotSizeBytes': snapshotSizeBytes,
      'durationMs': durationMs,
    });
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    recordedSnapshotLoads.add({
      'sequenceNumber': sequenceNumber,
      'durationMs': durationMs,
    });
  }

  @override
  Future<void> flush() async {
    // No-op for testing
  }

  void reset() {
    recordedEvents.clear();
    recordedReplays.clear();
    recordedSnapshots.clear();
    recordedSnapshotLoads.clear();
  }
}

void main() {
  group('OperationGroupingService', () {
    late FakeClock clock;
    late FakeMetricsSink metricsSink;
    late Logger logger;
    late EventCoreDiagnosticsConfig config;
    late OperationGroupingService service;

    setUp(() {
      clock = FakeClock(1000000); // Start at arbitrary timestamp
      metricsSink = FakeMetricsSink();
      logger = Logger(level: Level.off); // Silent for tests
      config = EventCoreDiagnosticsConfig.silent();
      service = OperationGroupingService(
        clock: clock,
        metricsSink: metricsSink,
        logger: logger,
        config: config,
        idleThresholdMs: 200, // Default threshold
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Automatic Idle Detection', () {
      test('groups contiguous events within threshold', () async {
        // Record events with 50ms gaps (continuous typing simulation)
        service.onEventRecorded(EventMetadata(
          eventType: 'KeyPress',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'KeyPress',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'KeyPress',
          sequenceNumber: 3,
          timestamp: clock.now(),
        ));

        // Should still have active group (no idle timeout yet)
        expect(service.hasActiveGroup, isTrue);
        expect(service.lastCompletedGroup, isNull);

        // Wait for idle threshold to elapse
        await Future.delayed(const Duration(milliseconds: 250));

        // Group should now be completed
        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.eventCount, equals(3));
        expect(service.lastCompletedGroup!.startSequence, equals(1));
        expect(service.lastCompletedGroup!.endSequence, equals(3));
      });

      test('creates separate groups for paused operations', () async {
        // First operation: continuous events
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNotNull);
        final firstGroup = service.lastCompletedGroup!;
        expect(firstGroup.eventCount, equals(2));

        // Second operation: after pause
        clock.advance(500); // Long pause
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 3,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 4,
          timestamp: clock.now(),
        ));

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNotNull);
        final secondGroup = service.lastCompletedGroup!;
        expect(secondGroup.eventCount, equals(2));
        expect(secondGroup.groupId, isNot(equals(firstGroup.groupId)));
      });

      test('handles rapid event streams (sampling simulation)', () async {
        // Simulate 20 events at 50ms intervals (1 second of continuous drag)
        for (int i = 1; i <= 20; i++) {
          service.onEventRecorded(EventMetadata(
            eventType: 'DragEvent',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          clock.advance(50);
        }

        // Should still be in active group
        expect(service.hasActiveGroup, isTrue);

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        // Should complete as single group
        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.eventCount, equals(20));
      });
    });

    group('Manual Boundary Control', () {
      test('startUndoGroup attaches label to next operation', () async {
        final groupId = service.startUndoGroup(label: 'Create Path');
        expect(groupId, isNotEmpty);

        service.onEventRecorded(EventMetadata(
          eventType: 'AddAnchor',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'AddAnchor',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // Manually end group
        service.endUndoGroup(groupId: groupId, label: 'Create Path');

        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.label, equals('Create Path'));
        expect(service.lastCompletedGroup!.eventCount, equals(2));
      });

      test('forceBoundary completes group immediately', () async {
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'MoveEvent',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // Force boundary before idle threshold
        service.forceBoundary(
          label: 'Move Objects',
          reason: 'tool_switch',
        );

        // Should complete immediately (no async wait needed)
        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.label, equals('Move Objects'));
      });

      test('cancelOperation discards active group', () async {
        service.onEventRecorded(EventMetadata(
          eventType: 'AddAnchor',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(50);
        service.onEventRecorded(EventMetadata(
          eventType: 'AddAnchor',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        expect(service.hasActiveGroup, isTrue);

        // Cancel operation (e.g., user pressed Escape)
        service.cancelOperation();

        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNull);

        // Wait to ensure no group is completed
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles single event operation', () async {
        service.onEventRecorded(EventMetadata(
          eventType: 'DeleteEvent',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.eventCount, equals(1));
        expect(service.lastCompletedGroup!.startSequence, equals(1));
        expect(service.lastCompletedGroup!.endSequence, equals(1));
      });

      test('handles empty service (no events)', () async {
        expect(service.hasActiveGroup, isFalse);
        expect(service.lastCompletedGroup, isNull);

        // Try to force boundary with no active group
        service.forceBoundary(label: 'None', reason: 'test');

        expect(service.lastCompletedGroup, isNull);
      });

      test('handles multiple forceBoundary calls', () async {
        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        service.forceBoundary(label: 'Op1', reason: 'test');
        expect(service.lastCompletedGroup!.label, equals('Op1'));

        service.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        service.forceBoundary(label: 'Op2', reason: 'test');
        expect(service.lastCompletedGroup!.label, equals('Op2'));

        // Second forceBoundary should have no effect
        service.forceBoundary(label: 'Op3', reason: 'test');
        expect(service.lastCompletedGroup!.label, equals('Op2'));
      });

      test('handles events at exact threshold boundary', () async {
        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        // Wait for idle timer to almost fire
        await Future.delayed(const Duration(milliseconds: 150));

        // Advance clock to exactly threshold (200ms)
        clock.advance(200);

        service.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // Second event extends the group, so wait for new idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNotNull);
        // Both events should be in same group since second arrived before timer fired
        expect(service.lastCompletedGroup!.eventCount, equals(2));
      });
    });

    group('Metrics', () {
      test('records operation completion metrics', () async {
        final metricsConfig = EventCoreDiagnosticsConfig(
          enableMetrics: true,
          enableDetailedLogging: false,
        );
        final metricsService = OperationGroupingService(
          clock: clock,
          metricsSink: metricsSink,
          logger: logger,
          config: metricsConfig,
          idleThresholdMs: 200,
        );

        metricsService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(100);

        metricsService.forceBoundary(label: 'Test Op', reason: 'test');

        // Should have recorded completion metric
        expect(metricsSink.recordedEvents, isNotEmpty);
        expect(
          metricsSink.recordedEvents.last['eventType'],
          equals('OperationGroupCompleted'),
        );
        expect(metricsSink.recordedEvents.last['durationMs'], greaterThan(0));

        metricsService.dispose();
      });

      test('respects enableMetrics config flag', () async {
        // Config with metrics disabled
        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        service.forceBoundary(label: 'Test', reason: 'test');

        // Should not record metrics
        expect(metricsSink.recordedEvents, isEmpty);
      });
    });

    group('ChangeNotifier Integration', () {
      test('notifies listeners on operation completion', () async {
        int notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });

        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        service.forceBoundary(label: 'Test', reason: 'test');

        expect(notificationCount, equals(1));
      });

      test('notifies listeners on cancelOperation', () async {
        int notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });

        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        service.cancelOperation();

        expect(notificationCount, equals(1));
      });

      test('does not notify on events (only on boundaries)', () async {
        int notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });

        service.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        service.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // Should not notify until boundary
        expect(notificationCount, equals(0));

        service.forceBoundary(label: 'Test', reason: 'test');

        expect(notificationCount, equals(1));
      });
    });

    group('OperationGroup Value Object', () {
      test('equality and hashCode', () {
        final group1 = OperationGroup(
          groupId: 'g1',
          label: 'Test',
          startSequence: 1,
          endSequence: 5,
          startTimestamp: 1000,
          endTimestamp: 1500,
          eventCount: 5,
        );

        final group2 = OperationGroup(
          groupId: 'g1',
          label: 'Test',
          startSequence: 1,
          endSequence: 5,
          startTimestamp: 1000,
          endTimestamp: 1500,
          eventCount: 5,
        );

        final group3 = OperationGroup(
          groupId: 'g2',
          label: 'Different',
          startSequence: 1,
          endSequence: 5,
          startTimestamp: 1000,
          endTimestamp: 1500,
          eventCount: 5,
        );

        expect(group1, equals(group2));
        expect(group1.hashCode, equals(group2.hashCode));
        expect(group1, isNot(equals(group3)));
      });

      test('durationMs calculation', () {
        final group = OperationGroup(
          groupId: 'g1',
          label: 'Test',
          startSequence: 1,
          endSequence: 5,
          startTimestamp: 1000,
          endTimestamp: 1750,
          eventCount: 5,
        );

        expect(group.durationMs, equals(750));
      });

      test('toString includes key information', () {
        final group = OperationGroup(
          groupId: 'g1',
          label: 'Move Objects',
          startSequence: 10,
          endSequence: 20,
          startTimestamp: 1000,
          endTimestamp: 1500,
          eventCount: 11,
        );

        final str = group.toString();
        expect(str, contains('g1'));
        expect(str, contains('Move Objects'));
        expect(str, contains('10-20'));
        expect(str, contains('11'));
        expect(str, contains('500ms'));
      });
    });

    group('Continuous Typing Scenario', () {
      test('groups rapid keystrokes into single operation', () async {
        // Simulate typing "hello" with 80ms intervals (continuous typing)
        final keystrokes = ['h', 'e', 'l', 'l', 'o'];

        for (int i = 0; i < keystrokes.length; i++) {
          service.onEventRecorded(EventMetadata(
            eventType: 'KeyPress',
            sequenceNumber: i + 1,
            timestamp: clock.now(),
            toolLabel: 'text_tool',
          ));

          if (i < keystrokes.length - 1) {
            clock.advance(80); // Continuous typing
          }
        }

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        expect(service.lastCompletedGroup, isNotNull);
        expect(service.lastCompletedGroup!.eventCount, equals(5));
        expect(service.lastCompletedGroup!.startSequence, equals(1));
        expect(service.lastCompletedGroup!.endSequence, equals(5));
      });

      test('splits typing into separate operations on pause', () async {
        // Type "hello" continuously
        for (int i = 1; i <= 5; i++) {
          service.onEventRecorded(EventMetadata(
            eventType: 'KeyPress',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          clock.advance(80);
        }

        // Wait for idle (completes first group)
        await Future.delayed(const Duration(milliseconds: 250));

        final firstGroup = service.lastCompletedGroup!;
        expect(firstGroup.eventCount, equals(5));

        // Long pause (user thinks)
        clock.advance(2000);

        // Type "world" continuously
        for (int i = 6; i <= 10; i++) {
          service.onEventRecorded(EventMetadata(
            eventType: 'KeyPress',
            sequenceNumber: i,
            timestamp: clock.now(),
          ));
          clock.advance(80);
        }

        // Wait for idle (completes second group)
        await Future.delayed(const Duration(milliseconds: 250));

        final secondGroup = service.lastCompletedGroup!;
        expect(secondGroup.eventCount, equals(5));
        expect(secondGroup.groupId, isNot(equals(firstGroup.groupId)));
      });
    });

    group('Custom Idle Threshold', () {
      test('respects custom threshold value', () async {
        final customService = OperationGroupingService(
          clock: clock,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          idleThresholdMs: 500, // Custom 500ms threshold
        );

        customService.onEventRecorded(EventMetadata(
          eventType: 'Event1',
          sequenceNumber: 1,
          timestamp: clock.now(),
        ));

        clock.advance(250);

        customService.onEventRecorded(EventMetadata(
          eventType: 'Event2',
          sequenceNumber: 2,
          timestamp: clock.now(),
        ));

        // With 200ms threshold, this would be two groups
        // With 500ms threshold, should still be one group
        await Future.delayed(const Duration(milliseconds: 300));

        expect(customService.hasActiveGroup, isTrue);

        // Wait for custom threshold
        await Future.delayed(const Duration(milliseconds: 300));

        expect(customService.hasActiveGroup, isFalse);
        expect(customService.lastCompletedGroup!.eventCount, equals(2));

        customService.dispose();
      });
    });
  });
}
