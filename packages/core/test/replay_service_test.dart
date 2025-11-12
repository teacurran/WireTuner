/// Tests for ReplayService checkpoint cache and seek latency.
///
/// Validates:
/// - Checkpoint generation at 1k intervals
/// - Seek performance (<50ms target)
/// - Checkpoint hit/miss behavior
/// - LRU eviction
/// - Playback control
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:logger/logger.dart';
import 'package:core/replay/replay_service.dart';
import 'package:core/replay/checkpoint.dart';
import 'package:core/replay/checkpoint_cache.dart';

void main() {
  group('CheckpointCache', () {
    late CheckpointCache cache;

    setUp(() {
      cache = CheckpointCache(
        checkpointInterval: 1000,
        maxMemoryBytes: 10 * 1024, // 10 KB for testing
        logger: Logger(level: Level.warning),
      );
    });

    test('generates checkpoints at correct intervals', () async {
      await cache.generateCheckpoints(
        maxSequence: 5000,
        snapshotProvider: (seq) async {
          return _createFakeSnapshot(seq);
        },
      );

      expect(cache.count, equals(5)); // 1000, 2000, 3000, 4000, 5000
      expect(cache.getCheckpointSequences(), equals([1000, 2000, 3000, 4000, 5000]));
    });

    test('finds nearest checkpoint correctly', () async {
      await cache.generateCheckpoints(
        maxSequence: 5000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
      );

      // Test exact match
      var checkpoint = cache.findNearest(3000);
      expect(checkpoint, isNotNull);
      expect(checkpoint!.sequence, equals(3000));

      // Test between checkpoints
      checkpoint = cache.findNearest(3500);
      expect(checkpoint, isNotNull);
      expect(checkpoint!.sequence, equals(3000)); // Should return nearest at or before

      // Test before first checkpoint
      checkpoint = cache.findNearest(500);
      expect(checkpoint, isNull);

      // Test after last checkpoint
      checkpoint = cache.findNearest(6000);
      expect(checkpoint, isNotNull);
      expect(checkpoint!.sequence, equals(5000));
    });

    test('evicts LRU checkpoints when over memory limit', () async {
      // Generate many checkpoints to exceed 10 KB limit
      // Use larger snapshots to force eviction
      await cache.generateCheckpoints(
        maxSequence: 50000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq, sizeBytes: 4096),
      );

      // Should have evicted some checkpoints to stay under 10 KB
      expect(cache.memoryUsage, lessThanOrEqualTo(10 * 1024));
      // With compression, some eviction should have occurred
      expect(cache.count, lessThan(50)); // Less than the total 50 checkpoints generated
    });

    test('updates LRU access time on read', () async {
      await cache.generateCheckpoints(
        maxSequence: 3000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
      );

      final checkpoint1 = cache.findNearest(1000)!;
      final firstAccessTime = checkpoint1.lastAccessTime;

      // Wait a bit
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Access again
      final checkpoint2 = cache.findNearest(1000)!;
      expect(checkpoint2.lastAccessTime.isAfter(firstAccessTime), isTrue);
    });

    test('clears all checkpoints', () async {
      await cache.generateCheckpoints(
        maxSequence: 5000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
      );

      expect(cache.count, greaterThan(0));

      cache.clear();

      expect(cache.count, equals(0));
      expect(cache.isEmpty, isTrue);
      expect(cache.memoryUsage, equals(0));
    });
  });

  group('ReplayService', () {
    late ReplayService service;
    late _FakeEventStore fakeStore;

    setUp(() {
      service = ReplayService(
        checkpointInterval: 1000,
        maxCacheMemory: 100 * 1024,
        logger: Logger(level: Level.warning),
      );

      fakeStore = _FakeEventStore();
    });

    tearDown(() {
      service.dispose();
    });

    test('initializes and generates checkpoints', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 5000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      expect(service.isInitialized, isTrue);
      expect(service.checkpointSequences.length, equals(5));
      expect(service.currentState.maxSequence, equals(5000));
    });

    test('seeks with checkpoint hit', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 10000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      final result = await service.seek(5500);

      expect(result.targetSequence, equals(5500));
      expect(result.checkpointSequence, equals(5000)); // Nearest checkpoint
      expect(result.eventsReplayed, equals(500)); // 5500 - 5000
      expect(result.checkpointHit, isTrue);
    });

    test('seek latency meets <50ms target for small deltas', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 50000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      // Seek with small delta from checkpoint (should be fast)
      final result = await service.seek(12100); // 100 events from checkpoint 12000

      expect(result.latencyMs, lessThan(50),
          reason: 'Seek latency should be <50ms for small deltas');
      expect(result.meetsTarget, isTrue);
    });

    test('multiple seeks produce performance metrics', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 10000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      // Perform multiple seeks
      for (int i = 0; i < 10; i++) {
        await service.seek(i * 1000);
      }

      final metrics = service.getSeekMetrics();
      expect(metrics['count'], equals(10));
      expect(metrics['avgLatencyMs'], isNotNull);
      expect(metrics['p95LatencyMs'], isNotNull);
      expect(metrics['checkpointHitRate'], isNotNull);
    });

    test('playback starts and advances sequence', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      expect(service.currentState.isPlaying, isFalse);

      service.play(speed: 10.0); // Fast playback for testing

      expect(service.currentState.isPlaying, isTrue);
      expect(service.currentState.playbackSpeed, equals(10.0));

      // Wait for some advancement
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(service.currentState.currentSequence, greaterThan(0));

      service.pause();
      expect(service.currentState.isPlaying, isFalse);
    });

    test('step forward advances one event', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      await service.seek(100);
      expect(service.currentState.currentSequence, equals(100));

      await service.stepForward();
      expect(service.currentState.currentSequence, equals(101));
    });

    test('step backward decrements one event', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      await service.seek(100);
      expect(service.currentState.currentSequence, equals(100));

      await service.stepBackward();
      expect(service.currentState.currentSequence, equals(99));
    });

    test('state stream emits updates', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      final stateUpdates = <ReplayState>[];
      service.stateStream.listen(stateUpdates.add);

      await service.seek(500);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(stateUpdates.length, greaterThan(0));
      expect(stateUpdates.last.currentSequence, equals(500));
    });

    test('clamping: seek beyond max clamps to max', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      final result = await service.seek(9999);
      expect(result.targetSequence, equals(1000)); // Clamped
    });

    test('clamping: seek below zero clamps to zero', () async {
      await service.initialize(
        documentId: 'doc123',
        maxSequence: 1000,
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      final result = await service.seek(-100);
      expect(result.targetSequence, equals(0)); // Clamped
    });
  });

  group('Performance Benchmarks', () {
    test('seek latency percentiles for large history', () async {
      final service = ReplayService(
        checkpointInterval: 1000,
        logger: Logger(level: Level.warning),
      );

      final fakeStore = _FakeEventStore();

      await service.initialize(
        documentId: 'perf-test',
        maxSequence: 100000, // 100k events
        snapshotProvider: (seq) async => _createFakeSnapshot(seq),
        eventReplayer: fakeStore.replayEvents,
        snapshotDeserializer: _deserializeSnapshot,
      );

      // Perform many seeks at random positions
      final random = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 50; i++) {
        final targetSeq = ((random + i * 1234) % 100000);
        await service.seek(targetSeq);
      }

      final metrics = service.getSeekMetrics();

      print('Performance Metrics:');
      print('  Count: ${metrics['count']}');
      print('  Avg Latency: ${metrics['avgLatencyMs']} ms');
      print('  Median Latency: ${metrics['medianLatencyMs']} ms');
      print('  P95 Latency: ${metrics['p95LatencyMs']} ms');
      print('  P99 Latency: ${metrics['p99LatencyMs']} ms');
      print('  Checkpoint Hit Rate: ${metrics['checkpointHitRate']}');
      print('  Target Met Rate: ${metrics['targetMetRate']}');

      // Verify P95 meets target
      expect(metrics['p95LatencyMs'], lessThan(50),
          reason: 'P95 seek latency should be <50ms');

      service.dispose();
    });
  });
}

// Helper functions

/// Creates a fake compressed snapshot.
Uint8List _createFakeSnapshot(int sequence, {int sizeBytes = 1024}) {
  // Generate less-compressible data using random-like patterns
  final randomData = List.generate(
    sizeBytes ~/ 100,
    (i) => {
      'id': 'obj-${sequence}-${i}',
      'x': (sequence * i * 7) % 1000,
      'y': (sequence * i * 13) % 1000,
      'data': '${sequence}-${i}-${DateTime.now().millisecondsSinceEpoch}',
    },
  );

  final data = {
    'sequence': sequence,
    'timestamp': DateTime.now().toIso8601String(),
    'objects': randomData,
  };

  final json = jsonEncode(data);
  return Uint8List.fromList(gzip.encode(utf8.encode(json)));
}

/// Deserializes a fake snapshot.
Future<dynamic> _deserializeSnapshot(Uint8List compressedData) async {
  final json = utf8.decode(gzip.decode(compressedData));
  return jsonDecode(json);
}

/// Fake event store for testing.
class _FakeEventStore {
  /// Simulates event replay by returning a fake state.
  Future<dynamic> replayEvents(int fromSequence, int toSequence) async {
    // Simulate some processing time (proportional to events)
    final eventCount = toSequence - fromSequence;
    await Future<void>.delayed(Duration(microseconds: eventCount * 10));

    return {
      'fromSequence': fromSequence,
      'toSequence': toSequence,
      'eventCount': eventCount,
      'objects': ['obj-1', 'obj-2'],
    };
  }
}
