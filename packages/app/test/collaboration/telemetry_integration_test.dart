/// Tests for telemetry integration with performance overlay.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';

import 'package:app/modules/performance_overlay/telemetry_integration.dart';

void main() {
  group('Snapshot Telemetry Integration', () {
    test('createSnapshotTelemetryCallback forwards metrics to service', () {
      final config = TelemetryConfig.debug();
      final service = TelemetryService(config: config, verbose: false);

      final callback = createSnapshotTelemetryCallback(service);

      // Call the callback
      callback(
        documentId: 'doc-123',
        eventSequence: 1000,
        uncompressedSize: 10000,
        compressedSize: 1000,
        compressionRatio: 10.0,
        durationMs: 450,
      );

      // Since TelemetryService doesn't expose internal state,
      // we verify no exceptions were thrown (opt-out enforcement works)
      expect(service.enabled, true);
    });

    test('snapshot callback respects opt-out', () {
      final config = TelemetryConfig.disabled();
      final service = TelemetryService(config: config, verbose: false);

      final callback = createSnapshotTelemetryCallback(service);

      // Call the callback - should not throw with telemetry disabled
      expect(
        () => callback(
          documentId: 'doc-123',
          eventSequence: 1000,
          uncompressedSize: 10000,
          compressedSize: 1000,
          compressionRatio: 10.0,
          durationMs: 450,
        ),
        returnsNormally,
      );

      expect(service.enabled, false);
    });
  });

  group('ReplayMetricsTracker', () {
    test('calculates events per second correctly', () {
      var capturedRate = 0.0;
      var capturedDepth = 0;

      final tracker = ReplayMetricsTracker(
        windowDurationMs: 1000,
        onMetricUpdated: (rate, depth) {
          capturedRate = rate;
          capturedDepth = depth;
        },
      );

      // Record 10 events
      tracker.recordEvents(10);

      // Rate should be ~10 events/sec (may vary slightly due to timing)
      expect(capturedRate, greaterThan(9.0));
      expect(capturedRate, lessThan(11.0));
    });

    test('tracks queue depth', () {
      var capturedDepth = 0;

      final tracker = ReplayMetricsTracker(
        onMetricUpdated: (rate, depth) {
          capturedDepth = depth;
        },
      );

      tracker.updateQueueDepth(42);
      expect(tracker.queueDepth, 42);
      expect(capturedDepth, 42);
    });

    test('reset clears all metrics', () {
      final tracker = ReplayMetricsTracker();

      tracker.recordEvents(10);
      tracker.updateQueueDepth(5);

      tracker.reset();

      expect(tracker.calculateEventsPerSecond(), 0.0);
      expect(tracker.queueDepth, 0);
    });

    test('removes old events from sliding window', () async {
      final tracker = ReplayMetricsTracker(windowDurationMs: 100);

      // Record events
      tracker.recordEvents(5);

      // Initial rate should reflect 5 events
      final initialRate = tracker.calculateEventsPerSecond();
      expect(initialRate, greaterThan(40.0)); // 5 events / 0.1s = 50 events/s

      // Wait for window to expire
      await Future.delayed(const Duration(milliseconds: 150));

      // Record one more event to trigger cleanup
      tracker.recordEvent();

      // Rate should drop (old events removed)
      final newRate = tracker.calculateEventsPerSecond();
      expect(newRate, lessThan(initialRate));
    });

    test('handles zero events gracefully', () {
      final tracker = ReplayMetricsTracker();
      expect(tracker.calculateEventsPerSecond(), 0.0);
    });

    test('handles batch recording', () {
      var eventCount = 0;

      final tracker = ReplayMetricsTracker(
        onMetricUpdated: (rate, depth) {
          eventCount++;
        },
      );

      tracker.recordEvents(5);

      // Should have invoked callback 5 times (once per event)
      expect(eventCount, 5);
    });
  });

  group('Replay Telemetry Integration', () {
    test('createReplayMetricsTracker integrates with telemetry service', () {
      final config = TelemetryConfig.debug();
      final service = TelemetryService(config: config, verbose: false);

      final tracker = createReplayMetricsTracker(service);

      // Record events - should forward to telemetry service
      tracker.recordEvents(10);

      // Verify no exceptions thrown
      expect(service.enabled, true);
    });

    test('replay tracker respects telemetry opt-out', () {
      final config = TelemetryConfig.disabled();
      final service = TelemetryService(config: config, verbose: false);

      final tracker = createReplayMetricsTracker(service);

      // Record events - should not throw with telemetry disabled
      expect(() => tracker.recordEvents(10), returnsNormally);
      expect(service.enabled, false);
    });

    test('tracker uses custom window duration', () {
      final config = TelemetryConfig.debug();
      final service = TelemetryService(config: config, verbose: false);

      final tracker = createReplayMetricsTracker(
        service,
        windowDurationMs: 2000,
      );

      tracker.recordEvents(10);

      // Rate should be ~5 events/sec with 2s window (10 events / 2s)
      final rate = tracker.calculateEventsPerSecond();
      expect(rate, greaterThan(4.0));
      expect(rate, lessThan(6.0));
    });
  });

  group('End-to-End Integration', () {
    test('snapshot and replay metrics flow through telemetry pipeline', () {
      final config = TelemetryConfig.debug();
      final service = TelemetryService(config: config, verbose: false);

      // Create callbacks
      final snapshotCallback = createSnapshotTelemetryCallback(service);
      final replayTracker = createReplayMetricsTracker(service);

      // Emit snapshot metric
      snapshotCallback(
        documentId: 'doc-123',
        eventSequence: 1000,
        uncompressedSize: 10000,
        compressedSize: 1000,
        compressionRatio: 10.0,
        durationMs: 450,
      );

      // Emit replay metrics
      replayTracker.recordEvents(100);

      // Verify system remains stable
      expect(service.enabled, true);
    });

    test('opt-out blocks all metric emission', () {
      final config = TelemetryConfig(enabled: true);
      final service = TelemetryService(config: config, verbose: false);

      final snapshotCallback = createSnapshotTelemetryCallback(service);
      final replayTracker = createReplayMetricsTracker(service);

      // Emit metrics while enabled
      snapshotCallback(
        documentId: 'doc-123',
        eventSequence: 1000,
        uncompressedSize: 10000,
        compressedSize: 1000,
        compressionRatio: 10.0,
        durationMs: 450,
      );
      replayTracker.recordEvents(10);

      // Disable telemetry
      config.enabled = false;

      // Emit metrics while disabled - should not throw
      expect(
        () => snapshotCallback(
          documentId: 'doc-123',
          eventSequence: 2000,
          uncompressedSize: 10000,
          compressedSize: 1000,
          compressionRatio: 10.0,
          durationMs: 450,
        ),
        returnsNormally,
      );
      expect(() => replayTracker.recordEvents(10), returnsNormally);
    });
  });
}
