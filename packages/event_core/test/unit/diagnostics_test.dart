/// Unit tests for event core diagnostics (logging + metrics).
///
/// Validates that metrics are correctly recorded, logged, and aggregated.
library;

import 'package:test/test.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';

void main() {
  group('EventCoreDiagnosticsConfig', () {
    test('creates debug configuration', () {
      final config = EventCoreDiagnosticsConfig.debug();
      expect(config.logLevel, Level.debug);
      expect(config.enableMetrics, true);
      expect(config.enableDetailedLogging, true);
    });

    test('creates release configuration', () {
      final config = EventCoreDiagnosticsConfig.release();
      expect(config.logLevel, Level.info);
      expect(config.enableMetrics, true);
      expect(config.enableDetailedLogging, false);
    });

    test('creates silent configuration', () {
      final config = EventCoreDiagnosticsConfig.silent();
      expect(config.logLevel, Level.off);
      expect(config.enableMetrics, false);
      expect(config.enableDetailedLogging, false);
    });

    test('shouldLog respects configured level', () {
      const config = EventCoreDiagnosticsConfig(logLevel: Level.info);
      expect(config.shouldLog(Level.debug), false);
      expect(config.shouldLog(Level.info), true);
      expect(config.shouldLog(Level.warning), true);
      expect(config.shouldLog(Level.error), true);
    });
  });

  group('PerformanceCounters', () {
    late PerformanceCounters counters;

    setUp(() {
      counters = PerformanceCounters();
    });

    test('measureSync returns duration', () {
      final durationMs = counters.measureSync('test', () {
        // Simulate work (loop to consume some time)
        for (var i = 0; i < 1000; i++) {
          // ignore: unused_local_variable
          final _ = i * i;
        }
      });
      expect(durationMs, greaterThanOrEqualTo(0));
    });

    test('measure returns result and duration', () async {
      final (result, durationMs) = await counters.measure('test', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'test-result';
      });
      expect(result, 'test-result');
      expect(durationMs, greaterThanOrEqualTo(10));
    });

    test('time returns only duration', () async {
      final durationMs = await counters.time('test', () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      expect(durationMs, greaterThanOrEqualTo(5));
    });

    test('startTimer creates manual timer', () {
      final timer = counters.startTimer('manual');
      expect(timer.name, 'manual');
      expect(timer.isStopped, false);

      final elapsed = timer.stop();
      expect(elapsed, greaterThanOrEqualTo(0));
      expect(timer.isStopped, true);

      // Subsequent stops return same value
      final elapsed2 = timer.stop();
      expect(elapsed2, elapsed);
    });

    test('timer elapsedMs works before stop', () async {
      final timer = counters.startTimer('test');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(timer.elapsedMs, greaterThanOrEqualTo(10));
      expect(timer.isStopped, false);

      timer.stop();
      expect(timer.isStopped, true);
    });
  });

  group('StructuredMetricsSink', () {
    late FakeLogger fakeLogger;
    late EventCoreDiagnosticsConfig config;
    late StructuredMetricsSink sink;

    setUp(() {
      fakeLogger = FakeLogger();
      config = EventCoreDiagnosticsConfig.debug();
      sink = StructuredMetricsSink(logger: fakeLogger, config: config);
    });

    test('recordEvent logs detailed info when enabled', () {
      sink.recordEvent(
        eventType: 'MoveObjectEvent',
        sampled: true,
        durationMs: 8,
      );

      expect(fakeLogger.debugMessages, hasLength(1));
      expect(fakeLogger.debugMessages.first, contains('MoveObjectEvent'));
      expect(fakeLogger.debugMessages.first, contains('sampled: true'));
      expect(fakeLogger.debugMessages.first, contains('duration: 8ms'));
    });

    test('recordEvent warns on slow writes', () {
      sink.recordEvent(
        eventType: 'PathCreatedEvent',
        sampled: false,
        durationMs: 75, // > 50ms threshold
      );

      expect(fakeLogger.warningMessages, hasLength(1));
      expect(fakeLogger.warningMessages.first, contains('Slow event write'));
      expect(fakeLogger.warningMessages.first, contains('75ms'));
    });

    test('recordReplay always logs at INFO level', () {
      sink.recordReplay(
        eventCount: 100,
        fromSequence: 0,
        toSequence: 99,
        durationMs: 250,
      );

      expect(fakeLogger.infoMessages, hasLength(1));
      expect(fakeLogger.infoMessages.first, contains('Replay completed'));
      expect(fakeLogger.infoMessages.first, contains('100 events'));
      expect(fakeLogger.infoMessages.first, contains('250ms'));
    });

    test('recordReplay warns on slow replays', () {
      sink.recordReplay(
        eventCount: 200,
        fromSequence: 0,
        toSequence: 199,
        durationMs: 750, // > 500ms target
      );

      expect(fakeLogger.warningMessages, hasLength(1));
      expect(fakeLogger.warningMessages.first, contains('Slow replay'));
      expect(fakeLogger.warningMessages.first, contains('750ms'));
    });

    test('recordSnapshot logs detailed info when enabled', () {
      sink.recordSnapshot(
        sequenceNumber: 1000,
        snapshotSizeBytes: 5 * 1024 * 1024, // 5MB
        durationMs: 120,
      );

      expect(fakeLogger.debugMessages, hasLength(1));
      expect(fakeLogger.debugMessages.first, contains('seq=1000'));
      expect(fakeLogger.debugMessages.first, contains('5.00MB'));
    });

    test('recordSnapshot warns on large snapshots', () {
      sink.recordSnapshot(
        sequenceNumber: 2000,
        snapshotSizeBytes: 150 * 1024 * 1024, // 150MB > 100MB threshold
        durationMs: 500,
      );

      expect(fakeLogger.warningMessages, hasLength(1));
      expect(fakeLogger.warningMessages.first, contains('Large snapshot'));
      expect(fakeLogger.warningMessages.first, contains('150.00MB'));
    });

    test('recordSnapshotLoad logs at INFO level', () {
      sink.recordSnapshotLoad(
        sequenceNumber: 1500,
        durationMs: 80,
      );

      expect(fakeLogger.infoMessages, hasLength(1));
      expect(fakeLogger.infoMessages.first, contains('Snapshot loaded'));
      expect(fakeLogger.infoMessages.first, contains('seq=1500'));
      expect(fakeLogger.infoMessages.first, contains('80ms'));
    });

    test('flush emits aggregated metrics', () async {
      // Record multiple events
      sink.recordEvent(eventType: 'Event1', sampled: true, durationMs: 5);
      sink.recordEvent(eventType: 'Event2', sampled: false, durationMs: 10);
      sink.recordReplay(
        eventCount: 50,
        fromSequence: 0,
        toSequence: 49,
        durationMs: 200,
      );
      sink.recordSnapshot(
        sequenceNumber: 1000,
        snapshotSizeBytes: 1024,
        durationMs: 50,
      );

      fakeLogger.clear();
      await sink.flush();

      // Should emit aggregated statistics
      expect(fakeLogger.infoMessages, isNotEmpty);
      final allInfo = fakeLogger.infoMessages.join(' ');
      expect(allInfo, contains('Event metrics'));
      expect(allInfo, contains('total=2'));
      expect(allInfo, contains('sampled=1'));
      expect(allInfo, contains('Replay metrics'));
      expect(allInfo, contains('count=1'));
      expect(allInfo, contains('Snapshot metrics'));
    });

    test('getMetrics returns current aggregated data', () {
      sink.recordEvent(eventType: 'Event1', sampled: true, durationMs: 5);
      sink.recordEvent(eventType: 'Event2', sampled: false, durationMs: 15);
      sink.recordReplay(
        eventCount: 100,
        fromSequence: 0,
        toSequence: 99,
        durationMs: 300,
      );

      final metrics = sink.getMetrics();
      expect(metrics['eventCount'], 2);
      expect(metrics['sampledEventCount'], 1);
      expect(metrics['totalEventWriteTimeMs'], 20);
      expect(metrics['avgEventWriteTimeMs'], 10.0);
      expect(metrics['replayCount'], 1);
      expect(metrics['totalReplayTimeMs'], 300);
      expect(metrics['avgReplayTimeMs'], 300.0);
    });

    test('metrics are disabled when config.enableMetrics is false', () {
      final silentConfig = EventCoreDiagnosticsConfig.silent();
      final silentSink = StructuredMetricsSink(
        logger: fakeLogger,
        config: silentConfig,
      );

      silentSink.recordEvent(
        eventType: 'Event1',
        sampled: true,
        durationMs: 5,
      );

      expect(fakeLogger.debugMessages, isEmpty);
      expect(fakeLogger.infoMessages, isEmpty);
    });
  });

  group('Integration: Recorder with metrics', () {
    late FakeLogger fakeLogger;
    late StructuredMetricsSink metricsSink;
    late DefaultEventRecorder recorder;

    setUp(() {
      fakeLogger = FakeLogger();
      final config = EventCoreDiagnosticsConfig.debug();
      metricsSink = StructuredMetricsSink(logger: fakeLogger, config: config);

      recorder = DefaultEventRecorder(
        sampler: StubEventSampler(),
        dispatcher: StubEventDispatcher(),
        storeGateway: StubEventStoreGateway(),
        metricsSink: metricsSink,
        logger: fakeLogger,
        config: config,
      );
    });

    test('recorder emits metrics on recordEvent', () async {
      await recorder.recordEvent({'eventType': 'TestEvent'});

      final metrics = metricsSink.getMetrics();
      expect(metrics['eventCount'], 1);
      expect(fakeLogger.debugMessages, isNotEmpty);
    });

    test('recorder logs pause/resume', () {
      recorder.pause();
      expect(
        fakeLogger.infoMessages,
        contains(
          predicate<String>((msg) => msg.contains('paused')),
        ),
      );

      fakeLogger.clear();
      recorder.resume();
      expect(
        fakeLogger.infoMessages,
        contains(
          predicate<String>((msg) => msg.contains('resumed')),
        ),
      );
    });
  });

  group('Integration: Replayer with metrics', () {
    late FakeLogger fakeLogger;
    late StructuredMetricsSink metricsSink;
    late DefaultEventReplayer replayer;

    setUp(() {
      fakeLogger = FakeLogger();
      final config = EventCoreDiagnosticsConfig.debug();
      metricsSink = StructuredMetricsSink(logger: fakeLogger, config: config);

      replayer = DefaultEventReplayer(
        storeGateway: StubEventStoreGateway(),
        dispatcher: StubEventDispatcher(),
        snapshotManager: DefaultSnapshotManager(
          storeGateway: StubEventStoreGateway(),
          metricsSink: metricsSink,
          logger: fakeLogger,
          config: config,
        ),
        metricsSink: metricsSink,
        logger: fakeLogger,
        config: config,
      );
    });

    test('replayer emits metrics on replay', () async {
      await replayer.replay(fromSequence: 0, toSequence: 50);

      final metrics = metricsSink.getMetrics();
      expect(metrics['replayCount'], 1);
      expect(
        fakeLogger.infoMessages,
        contains(
          predicate<String>((msg) => msg.contains('Starting replay')),
        ),
      );
    });

    test('replayer logs snapshot-based replay', () async {
      await replayer.replayFromSnapshot(maxSequence: 100);

      expect(
        fakeLogger.infoMessages,
        contains(
          predicate<String>((msg) => msg.contains('snapshot-based replay')),
        ),
      );
    });
  });
}

/// Fake logger for testing that captures log messages.
class FakeLogger extends Logger {
  FakeLogger() : super(level: Level.all);

  final List<String> debugMessages = [];
  final List<String> infoMessages = [];
  final List<String> warningMessages = [];
  final List<String> errorMessages = [];

  void clear() {
    debugMessages.clear();
    infoMessages.clear();
    warningMessages.clear();
    errorMessages.clear();
  }

  @override
  void d(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugMessages.add(message.toString());
  }

  @override
  void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    infoMessages.add(message.toString());
  }

  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    warningMessages.add(message.toString());
  }

  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    errorMessages.add(message.toString());
  }
}
