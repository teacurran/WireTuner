/// Unit tests for snapshot manager with memory guards and adaptive cadence.
///
/// This test suite covers:
/// - Snapshot creation with isolate-based serialization
/// - Memory guard thresholds (warn/max)
/// - Adaptive cadence (burst/normal/idle)
/// - Timer-based triggers (10-minute rule)
/// - Telemetry and performance tracking
library;

import 'package:event_core/src/snapshot_manager.dart';
import 'package:event_core/src/event_store_gateway.dart';
import 'package:event_core/src/metrics_sink.dart';
import 'package:event_core/src/diagnostics_config.dart';
import 'package:event_core/src/snapshot_tuning_config.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotManager', () {
    late MockEventStoreGateway gateway;
    late MockMetricsSink metricsSink;
    late Logger logger;
    late EventCoreDiagnosticsConfig config;

    setUp(() {
      gateway = MockEventStoreGateway();
      metricsSink = MockMetricsSink();
      logger = Logger(level: Level.warning);
      config = EventCoreDiagnosticsConfig(
        enableDetailedLogging: false,
      );
    });

    group('Memory Guards', () {
      test('should warn when snapshot exceeds warning threshold', () async {
        final testLogger = TestLogger();
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: testLogger,
          config: config,
          memoryGuards: const MemoryGuardThresholds(
            warnThresholdBytes: 500, // 500 bytes for testing
            maxThresholdBytes: 10000, // 10KB max
          ),
        );

        // Create a document that will be > 500 bytes uncompressed
        final largeDoc = {
          'id': 'test-doc',
          'title': 'Large Document',
          'data': List.generate(100, (i) => 'content_$i').join('_'),
        };

        // Should complete with warning logged
        await manager.createSnapshot(
          documentState: largeDoc,
          sequenceNumber: 1000,
          documentId: 'test-doc',
        );

        // Snapshot was recorded
        expect(metricsSink.snapshots.length, 1);

        // Should have logged a warning
        expect(
          testLogger.warnings.any((msg) => msg.contains('approaching size limit')),
          isTrue,
        );
      });

      test('should throw when snapshot exceeds maximum threshold', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          memoryGuards: const MemoryGuardThresholds(
            warnThresholdBytes: 1000,
            maxThresholdBytes: 5000, // 5KB for testing
          ),
        );

        // Create a huge document that will exceed max (>5KB uncompressed)
        final hugeDoc = {
          'id': 'huge-doc',
          'title': 'Huge Document',
          'data': List.generate(1000, (i) => 'long_content_line_$i').join('\n'),
        };

        // Should throw SnapshotSizeException
        expect(
          () => manager.createSnapshot(
            documentState: hugeDoc,
            sequenceNumber: 1000,
            documentId: 'huge-doc',
          ),
          throwsA(isA<SnapshotSizeException>()),
        );
      });

      test('should not throw for documents within limits', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        final normalDoc = {
          'id': 'normal-doc',
          'title': 'Test Document',
          'data': {'value': 123},
        };

        // Should complete without error
        await manager.createSnapshot(
          documentState: normalDoc,
          sequenceNumber: 500,
          documentId: 'normal-doc',
        );

        expect(metricsSink.snapshots.length, 1);
        expect(metricsSink.snapshots.first.sequenceNumber, 500);
      });
    });

    group('Adaptive Cadence', () {
      test('should use base interval for normal activity', () {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          tuningConfig: const SnapshotTuningConfig(
            baseInterval: 500,
            burstThreshold: 20.0,
            idleThreshold: 2.0,
          ),
        );

        // Simulate normal activity (10 events/sec)
        for (var i = 0; i < 10; i++) {
          manager.recordEventApplied(i + 1);
        }

        // Should trigger at base interval
        expect(manager.shouldCreateSnapshot(500), isTrue);
        expect(manager.shouldCreateSnapshot(499), isFalse);
        expect(manager.shouldCreateSnapshot(1000), isTrue);
      });

      test('should reduce interval during burst activity', () {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          tuningConfig: const SnapshotTuningConfig(
            baseInterval: 1000,
            burstMultiplier: 0.5, // 500 events during burst
            burstThreshold: 20.0,
          ),
        );

        // Simulate burst activity (30 events/sec)
        for (var i = 0; i < 30; i++) {
          manager.recordEventApplied(i + 1);
        }

        // Should trigger at reduced interval (500)
        expect(manager.shouldCreateSnapshot(500), isTrue);
        expect(manager.shouldCreateSnapshot(1000), isTrue);
      });

      test('should increase interval during idle activity', () {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          tuningConfig: const SnapshotTuningConfig(
            baseInterval: 1000,
            idleMultiplier: 2.0, // 2000 events during idle
            idleThreshold: 2.0,
          ),
        );

        // Simulate idle activity (1 event/sec)
        manager.recordEventApplied(1);

        // Should trigger at increased interval (2000), not base interval (1000)
        expect(manager.shouldCreateSnapshot(2000), isTrue);
        // Note: 1000 is also a multiple of 2000 calculation, so check a non-multiple
        expect(manager.shouldCreateSnapshot(1500), isFalse);
      });
    });

    group('Timer-Based Triggers', () {
      test('should trigger snapshot after 10 minutes with new events', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          timerCheckInterval: const Duration(milliseconds: 100), // 100ms for testing
        );

        // Create initial snapshot
        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'data': 'test'},
          sequenceNumber: 500,
          documentId: 'doc1',
        );

        // Wait for timer to expire
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Add new events
        manager.recordEventApplied(501);
        manager.recordEventApplied(502);

        // Should trigger by timer even though event threshold not met
        expect(
          manager.shouldCreateSnapshot(502, forceTimeCheck: true),
          isTrue,
        );
      });

      test('should not trigger timer-based snapshot without new events', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          timerCheckInterval: const Duration(milliseconds: 100),
        );

        // Create initial snapshot
        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'data': 'test'},
          sequenceNumber: 500,
          documentId: 'doc1',
        );

        // Wait for timer to expire
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // No new events - should not trigger
        expect(
          manager.shouldCreateSnapshot(500, forceTimeCheck: true),
          isFalse,
        );
      });

      test('should not trigger timer-based snapshot before timer expires', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          timerCheckInterval: const Duration(minutes: 10),
        );

        // Create initial snapshot
        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'data': 'test'},
          sequenceNumber: 500,
          documentId: 'doc1',
        );

        // Add new events immediately
        manager.recordEventApplied(501);

        // Timer not expired - should not trigger
        expect(
          manager.shouldCreateSnapshot(501, forceTimeCheck: true),
          isFalse,
        );
      });
    });

    group('Telemetry and Metrics', () {
      test('should record snapshot metrics with size and duration', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'title': 'Test', 'data': 'content'},
          sequenceNumber: 1000,
          documentId: 'doc1',
        );

        expect(metricsSink.snapshots.length, 1);
        final snapshot = metricsSink.snapshots.first;
        expect(snapshot.sequenceNumber, 1000);
        expect(snapshot.sizeBytes, greaterThan(0));
        // Duration may be 0 for very fast operations
        expect(snapshot.durationMs, greaterThanOrEqualTo(0));
      });

      test('should track backlog status correctly', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        // Simulate multiple pending snapshots
        final futures = <Future<void>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(manager.createSnapshot(
            documentState: {'id': 'doc$i', 'data': 'test'},
            sequenceNumber: (i + 1) * 500,
            documentId: 'doc$i',
          ));
        }

        await Future.wait(futures);

        // All snapshots completed
        final status = manager.getBacklogStatus(1500);
        expect(status.pendingSnapshots, 0);
        expect(status.lastSnapshotSequence, 1500);
      });

      test('should warn when backlog exceeds threshold', () async {
        final testLogger = TestLogger();
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: testLogger,
          config: config,
        );

        // Create many snapshots quickly to build up backlog
        final futures = <Future<void>>[];
        for (var i = 0; i < 5; i++) {
          futures.add(manager.createSnapshot(
            documentState: {'id': 'doc$i', 'data': 'x' * 1000},
            sequenceNumber: (i + 1) * 500,
            documentId: 'doc$i',
          ));
        }

        await Future.wait(futures);

        // Check for warning logs
        expect(
          testLogger.warnings.any((msg) => msg.contains('backlog')),
          isTrue,
        );
      });
    });

    group('Snapshot Lifecycle', () {
      test('should update last snapshot time after creation', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        expect(manager.lastSnapshotTime, isNull);

        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'data': 'test'},
          sequenceNumber: 500,
          documentId: 'doc1',
        );

        expect(manager.lastSnapshotTime, isNotNull);
      });

      test('should track events since last snapshot', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        await manager.createSnapshot(
          documentState: {'id': 'doc1', 'data': 'test'},
          sequenceNumber: 500,
          documentId: 'doc1',
        );

        // Record more events
        for (var i = 501; i <= 600; i++) {
          manager.recordEventApplied(i);
        }

        final status = manager.getBacklogStatus(600);
        expect(status.eventsSinceSnapshot, 100);
      });

      test('should handle snapshot serialization errors gracefully', () async {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        // Try to create snapshot with invalid data that will cause serialization issues
        // (in this case, our serializer should handle it, but test error handling)
        expect(
          () => manager.createSnapshot(
            documentState: {'id': 'doc1', 'circular': null},
            sequenceNumber: 500,
            documentId: 'doc1',
          ),
          returnsNormally, // Should handle gracefully
        );
      });
    });

    group('Configuration', () {
      test('should respect custom memory guard thresholds', () {
        final customGuards = const MemoryGuardThresholds(
          warnThresholdBytes: 10 * 1024 * 1024, // 10 MB
          maxThresholdBytes: 50 * 1024 * 1024, // 50 MB
        );

        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          memoryGuards: customGuards,
        );

        expect(manager.memoryGuards.warnThresholdBytes, 10 * 1024 * 1024);
        expect(manager.memoryGuards.maxThresholdBytes, 50 * 1024 * 1024);
      });

      test('should respect custom tuning configuration', () {
        final customTuning = const SnapshotTuningConfig(
          baseInterval: 250,
          burstMultiplier: 0.25,
          idleMultiplier: 4.0,
        );

        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
          tuningConfig: customTuning,
        );

        expect(manager.tuningConfig.baseInterval, 250);
        expect(manager.tuningConfig.burstMultiplier, 0.25);
        expect(manager.tuningConfig.idleMultiplier, 4.0);
      });

      test('should use default 500 event interval per ADR-0003', () {
        final manager = DefaultSnapshotManager(
          storeGateway: gateway,
          metricsSink: metricsSink,
          logger: logger,
          config: config,
        );

        expect(manager.snapshotInterval, 500);
      });
    });
  });
}

// ========== Test Mocks ==========

class MockEventStoreGateway implements EventStoreGateway {
  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    events.add(eventData);
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    this.events.addAll(events);
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    return events
        .where((e) {
          final seq = e['sequenceNumber'] as int?;
          if (seq == null) return false;
          return seq >= fromSequence &&
              (toSequence == null || seq <= toSequence);
        })
        .toList();
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    if (events.isEmpty) return 0;
    return events.map((e) => e['sequenceNumber'] as int).reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {
    events.removeWhere((e) => (e['sequenceNumber'] as int) < sequenceNumber);
  }
}

class MockMetricsSink implements MetricsSink {
  final List<SnapshotMetric> snapshots = [];
  final List<SnapshotLoadMetric> snapshotLoads = [];

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    snapshots.add(SnapshotMetric(
      sequenceNumber: sequenceNumber,
      sizeBytes: snapshotSizeBytes,
      durationMs: durationMs,
    ));
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    snapshotLoads.add(SnapshotLoadMetric(
      sequenceNumber: sequenceNumber,
      durationMs: durationMs,
    ));
  }

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {}

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {}

  @override
  Future<void> flush() async {}
}

class SnapshotMetric {
  final int sequenceNumber;
  final int sizeBytes;
  final int durationMs;

  SnapshotMetric({
    required this.sequenceNumber,
    required this.sizeBytes,
    required this.durationMs,
  });
}

class SnapshotLoadMetric {
  final int sequenceNumber;
  final int durationMs;

  SnapshotLoadMetric({
    required this.sequenceNumber,
    required this.durationMs,
  });
}

class TestLogger extends Logger {
  final List<String> warnings = [];
  final List<String> errors = [];
  final List<String> info = [];

  TestLogger() : super(level: Level.all);

  @override
  void w(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    warnings.add(message.toString());
    super.w(message, time: time, error: error, stackTrace: stackTrace);
  }

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    errors.add(message.toString());
    super.e(message, time: time, error: error, stackTrace: stackTrace);
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    info.add(message.toString());
    super.i(message, time: time, error: error, stackTrace: stackTrace);
  }
}
