/// Legacy test file - replaced by test/unit/event_core_interfaces_test.dart
///
/// This file has been superseded by comprehensive interface tests.
/// See test/unit/event_core_interfaces_test.dart for current tests.
library;

import 'package:event_core/event_core.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultEventRecorder', () {
    late DefaultEventRecorder recorder;
    late StubEventSampler sampler;
    late StubEventDispatcher dispatcher;
    late StubEventStoreGateway storeGateway;
    late StubMetricsSink metricsSink;

    setUp(() {
      sampler = StubEventSampler();
      dispatcher = StubEventDispatcher();
      storeGateway = StubEventStoreGateway();
      metricsSink = StubMetricsSink();

      recorder = DefaultEventRecorder(
        sampler: sampler,
        dispatcher: dispatcher,
        storeGateway: storeGateway,
        metricsSink: metricsSink,
      );
    });

    test('can be instantiated', () {
      expect(recorder, isNotNull);
    });

    test('has correct sampling interval', () {
      expect(recorder.samplingIntervalMs, equals(50));
    });
  });

  group('DefaultEventReplayer', () {
    late DefaultEventReplayer replayer;
    late StubEventStoreGateway storeGateway;
    late StubEventDispatcher dispatcher;
    late DefaultSnapshotManager snapshotManager;
    late StubMetricsSink metricsSink;

    setUp(() {
      storeGateway = StubEventStoreGateway();
      dispatcher = StubEventDispatcher();
      metricsSink = StubMetricsSink();
      snapshotManager = DefaultSnapshotManager(
        storeGateway: storeGateway,
        metricsSink: metricsSink,
      );

      replayer = DefaultEventReplayer(
        storeGateway: storeGateway,
        dispatcher: dispatcher,
        snapshotManager: snapshotManager,
        metricsSink: metricsSink,
      );
    });

    test('can be instantiated', () {
      expect(replayer, isNotNull);
    });

    test('initial state is not replaying', () {
      expect(replayer.isReplaying, isFalse);
    });
  });

  group('DefaultSnapshotManager', () {
    late DefaultSnapshotManager snapshotManager;
    late StubEventStoreGateway storeGateway;
    late StubMetricsSink metricsSink;

    setUp(() {
      storeGateway = StubEventStoreGateway();
      metricsSink = StubMetricsSink();
      snapshotManager = DefaultSnapshotManager(
        storeGateway: storeGateway,
        metricsSink: metricsSink,
      );
    });

    test('can be instantiated', () {
      expect(snapshotManager, isNotNull);
    });

    test('has correct snapshot interval', () {
      expect(snapshotManager.snapshotInterval, equals(1000));
    });
  });
}
