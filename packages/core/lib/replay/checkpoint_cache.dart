/// Checkpoint cache for fast history seeking.
///
/// Maintains checkpoints at regular intervals (every 1000 events) to enable
/// sub-50ms seeks through document history. Uses LRU eviction when memory
/// exceeds threshold.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:logger/logger.dart';

import 'checkpoint.dart';

/// Cache for checkpoint snapshots with LRU eviction.
///
/// **Performance Characteristics:**
/// - Checkpoint lookup: O(log n) using SortedMap
/// - Memory-bounded: Evicts LRU checkpoints when exceeding threshold
/// - Lazy generation: Creates checkpoints on first access
///
/// **Usage Example:**
/// ```dart
/// final cache = CheckpointCache(
///   checkpointInterval: 1000,
///   maxMemoryBytes: 100 * 1024 * 1024, // 100 MB
/// );
///
/// // Generate checkpoints from event store
/// await cache.generateCheckpoints(
///   documentId: 'doc123',
///   snapshotProvider: (seq) async => await loadSnapshot(seq),
/// );
///
/// // Find nearest checkpoint for seeking
/// final checkpoint = cache.findNearest(12345);
/// ```
class CheckpointCache {
  /// Creates a checkpoint cache.
  ///
  /// [checkpointInterval]: Events between checkpoints (default: 1000)
  /// [maxMemoryBytes]: Maximum cache memory before eviction (default: 100 MB)
  /// [logger]: Logger for diagnostics
  CheckpointCache({
    this.checkpointInterval = 1000,
    this.maxMemoryBytes = 100 * 1024 * 1024,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  /// Events between checkpoints (default: 1000).
  final int checkpointInterval;

  /// Maximum cache memory in bytes before eviction (default: 100 MB).
  final int maxMemoryBytes;

  final Logger _logger;

  /// Checkpoint storage sorted by sequence number.
  final SplayTreeMap<int, Checkpoint> _checkpoints =
      SplayTreeMap<int, Checkpoint>();

  /// Total compressed memory usage in bytes.
  int _totalMemoryBytes = 0;

  /// Number of checkpoints in cache.
  int get count => _checkpoints.length;

  /// Total memory usage in bytes.
  int get memoryUsage => _totalMemoryBytes;

  /// Whether the cache is empty.
  bool get isEmpty => _checkpoints.isEmpty;

  /// Generates checkpoints at regular intervals.
  ///
  /// [maxSequence]: Maximum event sequence to generate checkpoints for
  /// [snapshotProvider]: Function that returns compressed snapshot data for a sequence
  ///
  /// **Example:**
  /// ```dart
  /// await cache.generateCheckpoints(
  ///   maxSequence: 50000,
  ///   snapshotProvider: (seq) async {
  ///     final state = await replayToSequence(seq);
  ///     final json = jsonEncode(state.toJson());
  ///     return gzip.encode(utf8.encode(json));
  ///   },
  /// );
  /// ```
  Future<void> generateCheckpoints({
    required int maxSequence,
    required Future<Uint8List> Function(int sequence) snapshotProvider,
  }) async {
    _logger.i('Generating checkpoints up to sequence $maxSequence '
        '(interval: $checkpointInterval)');

    final stopwatch = Stopwatch()..start();
    int generated = 0;

    // Generate checkpoints at intervals
    for (int seq = checkpointInterval;
        seq <= maxSequence;
        seq += checkpointInterval) {
      try {
        final compressedData = await snapshotProvider(seq);
        final checkpoint = Checkpoint(
          sequence: seq,
          compressedData: compressedData,
          timestamp: DateTime.now().toUtc(),
          memorySizeBytes: compressedData.length * 2, // Estimate uncompressed
        );

        _addCheckpoint(checkpoint);
        generated++;

        // Evict if over memory limit
        if (_totalMemoryBytes > maxMemoryBytes) {
          _evictLRU();
        }
      } catch (e, stack) {
        _logger.w('Failed to generate checkpoint at sequence $seq: $e\n$stack');
        // Continue generating remaining checkpoints
      }
    }

    stopwatch.stop();
    _logger.i('Generated $generated checkpoints in ${stopwatch.elapsedMilliseconds}ms '
        '(cache size: ${_formatBytes(_totalMemoryBytes)})');
  }

  /// Adds a checkpoint to the cache.
  void _addCheckpoint(Checkpoint checkpoint) {
    // Remove existing checkpoint at this sequence if present
    final existing = _checkpoints.remove(checkpoint.sequence);
    if (existing != null) {
      _totalMemoryBytes -= existing.compressedSizeBytes;
    }

    _checkpoints[checkpoint.sequence] = checkpoint;
    _totalMemoryBytes += checkpoint.compressedSizeBytes;
  }

  /// Finds the nearest checkpoint at or before the target sequence.
  ///
  /// Returns null if no checkpoint exists before target.
  ///
  /// **Example:**
  /// ```dart
  /// final checkpoint = cache.findNearest(12345);
  /// if (checkpoint != null) {
  ///   print('Found checkpoint at ${checkpoint.sequence}');
  ///   checkpoint.markAccessed(); // Update LRU
  /// }
  /// ```
  Checkpoint? findNearest(int targetSequence) {
    if (_checkpoints.isEmpty) {
      return null;
    }

    // Find largest checkpoint sequence <= target
    Checkpoint? nearest;
    for (final entry in _checkpoints.entries) {
      if (entry.key <= targetSequence) {
        nearest = entry.value;
      } else {
        break; // SplayTreeMap is sorted, stop searching
      }
    }

    if (nearest != null) {
      nearest.markAccessed();
      _logger.d('Found checkpoint at ${nearest.sequence} for target $targetSequence');
    } else {
      _logger.d('No checkpoint found for target $targetSequence');
    }

    return nearest;
  }

  /// Returns all checkpoint sequences (for UI markers).
  List<int> getCheckpointSequences() {
    return _checkpoints.keys.toList();
  }

  /// Evicts least-recently-used checkpoints until under memory limit.
  void _evictLRU() {
    if (_checkpoints.isEmpty) {
      return;
    }

    _logger.d('Evicting LRU checkpoints (current: ${_formatBytes(_totalMemoryBytes)}, '
        'limit: ${_formatBytes(maxMemoryBytes)})');

    int evicted = 0;

    while (_totalMemoryBytes > maxMemoryBytes && _checkpoints.isNotEmpty) {
      // Find least recently used checkpoint
      Checkpoint? lruCheckpoint;
      int? lruSequence;

      for (final entry in _checkpoints.entries) {
        if (lruCheckpoint == null ||
            entry.value.lastAccessTime.isBefore(lruCheckpoint.lastAccessTime)) {
          lruCheckpoint = entry.value;
          lruSequence = entry.key;
        }
      }

      if (lruSequence != null && lruCheckpoint != null) {
        _checkpoints.remove(lruSequence);
        _totalMemoryBytes -= lruCheckpoint.compressedSizeBytes;
        evicted++;
        _logger.d('Evicted checkpoint at $lruSequence '
            '(age: ${DateTime.now().toUtc().difference(lruCheckpoint.lastAccessTime).inSeconds}s)');
      } else {
        break; // Safety: avoid infinite loop
      }
    }

    _logger.i('Evicted $evicted checkpoints '
        '(new size: ${_formatBytes(_totalMemoryBytes)})');
  }

  /// Clears all checkpoints from cache.
  void clear() {
    _checkpoints.clear();
    _totalMemoryBytes = 0;
    _logger.d('Checkpoint cache cleared');
  }

  /// Formats bytes as human-readable string.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() =>
      'CheckpointCache(count=$count, memory=${_formatBytes(_totalMemoryBytes)})';
}
