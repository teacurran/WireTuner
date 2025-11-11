/// History replay service with checkpoint-based seeking.
///
/// Provides time-travel debugging and history scrubbing for documents,
/// using checkpoint snapshots to achieve <50ms seek latency.
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:logger/logger.dart';

import 'checkpoint.dart';
import 'checkpoint_cache.dart';

/// Callback for replaying events from one sequence to another.
///
/// Returns the reconstructed document state after replay.
typedef EventReplayCallback = Future<dynamic> Function(
  int fromSequence,
  int toSequence,
);

/// Callback for loading a snapshot at a specific sequence.
///
/// Returns compressed snapshot data (gzip JSON).
typedef SnapshotLoadCallback = Future<Uint8List> Function(int sequence);

/// Callback for decompressing and deserializing a snapshot.
///
/// Returns the document state from compressed snapshot data.
typedef SnapshotDeserializeCallback = Future<dynamic> Function(
  Uint8List compressedData,
);

/// Service for history replay with checkpoint optimization.
///
/// **Features:**
/// - Checkpoint cache for fast seeking (target: <50ms)
/// - Playback control (0.5× to 10× speed)
/// - Telemetry for seek latency and checkpoint metrics
/// - LRU eviction for memory management
///
/// **Usage Example:**
/// ```dart
/// final service = ReplayService(
///   checkpointInterval: 1000,
///   maxCacheMemory: 100 * 1024 * 1024, // 100 MB
/// );
///
/// // Initialize for document
/// await service.initialize(
///   documentId: 'doc123',
///   maxSequence: 50000,
///   snapshotProvider: (seq) => loadSnapshot(seq),
///   eventReplayer: (from, to) => replayEvents(from, to),
/// );
///
/// // Seek to sequence
/// final result = await service.seek(12345);
/// print('Seek latency: ${result.latencyMs}ms');
///
/// // Start playback
/// service.play(speed: 2.0);
///
/// // Listen to state changes
/// service.stateStream.listen((state) {
///   print('Current sequence: ${state.currentSequence}');
/// });
/// ```
class ReplayService {
  /// Creates a replay service.
  ///
  /// [checkpointInterval]: Events between checkpoints (default: 1000)
  /// [maxCacheMemory]: Maximum cache memory in bytes (default: 100 MB)
  /// [logger]: Logger for diagnostics
  ReplayService({
    int checkpointInterval = 1000,
    int maxCacheMemory = 100 * 1024 * 1024,
    Logger? logger,
  })  : _cache = CheckpointCache(
          checkpointInterval: checkpointInterval,
          maxMemoryBytes: maxCacheMemory,
          logger: logger,
        ),
        _logger = logger ?? Logger();

  final CheckpointCache _cache;
  final Logger _logger;

  /// Current replay state.
  ReplayState _currentState = const ReplayState(
    currentSequence: 0,
    maxSequence: 0,
    isPlaying: false,
    playbackSpeed: 1.0,
  );

  /// Stream controller for state updates.
  final StreamController<ReplayState> _stateController =
      StreamController<ReplayState>.broadcast();

  /// Playback timer.
  Timer? _playbackTimer;

  /// Callbacks set during initialization.
  EventReplayCallback? _eventReplayer;
  SnapshotDeserializeCallback? _snapshotDeserializer;

  /// Document ID being replayed.
  String? _documentId;

  /// Telemetry metrics.
  final List<SeekResult> _seekHistory = [];

  /// Stream of replay state updates.
  Stream<ReplayState> get stateStream => _stateController.stream;

  /// Current replay state.
  ReplayState get currentState => _currentState;

  /// Whether checkpoints have been initialized.
  bool get isInitialized => _documentId != null;

  /// Checkpoint sequences for UI markers.
  List<int> get checkpointSequences => _cache.getCheckpointSequences();

  /// Initializes the replay service for a document.
  ///
  /// Lazily generates checkpoints on first access.
  ///
  /// [documentId]: Document to replay
  /// [maxSequence]: Maximum event sequence available
  /// [snapshotProvider]: Function to load snapshot at sequence
  /// [eventReplayer]: Function to replay events from/to sequences
  /// [snapshotDeserializer]: Function to deserialize compressed snapshots
  ///
  /// **Example:**
  /// ```dart
  /// await service.initialize(
  ///   documentId: 'doc123',
  ///   maxSequence: 50000,
  ///   snapshotProvider: (seq) async {
  ///     final state = await loadSnapshot(seq);
  ///     return gzip.encode(utf8.encode(jsonEncode(state)));
  ///   },
  ///   eventReplayer: (from, to) async {
  ///     return await replayEvents(from, to);
  ///   },
  ///   snapshotDeserializer: (data) async {
  ///     final json = utf8.decode(gzip.decode(data));
  ///     return Document.fromJson(jsonDecode(json));
  ///   },
  /// );
  /// ```
  Future<void> initialize({
    required String documentId,
    required int maxSequence,
    required SnapshotLoadCallback snapshotProvider,
    required EventReplayCallback eventReplayer,
    required SnapshotDeserializeCallback snapshotDeserializer,
  }) async {
    _logger.i('Initializing ReplayService for document $documentId '
        '(maxSequence: $maxSequence)');

    _documentId = documentId;
    _eventReplayer = eventReplayer;
    _snapshotDeserializer = snapshotDeserializer;

    // Update state with max sequence
    _updateState(_currentState.copyWith(maxSequence: maxSequence));

    // Generate checkpoints lazily
    await _cache.generateCheckpoints(
      maxSequence: maxSequence,
      snapshotProvider: snapshotProvider,
    );

    _logger.i('ReplayService initialized (checkpoints: ${_cache.count})');
  }

  /// Seeks to a specific sequence number.
  ///
  /// Finds nearest checkpoint, loads it, and replays delta events.
  /// Emits updated state with reconstructed document.
  ///
  /// Returns seek performance metrics.
  ///
  /// **Example:**
  /// ```dart
  /// final result = await service.seek(12345);
  /// if (!result.meetsTarget) {
  ///   print('Warning: Seek took ${result.latencyMs}ms (target: <50ms)');
  /// }
  /// ```
  Future<SeekResult> seek(int targetSequence) async {
    if (!isInitialized) {
      throw StateError('ReplayService not initialized');
    }

    final stopwatch = Stopwatch()..start();

    // Clamp to valid range
    final clampedSequence = targetSequence.clamp(0, _currentState.maxSequence);

    _logger.d('Seeking to sequence $clampedSequence');

    // Find nearest checkpoint
    final checkpoint = _cache.findNearest(clampedSequence);

    int fromSequence;
    dynamic state;

    if (checkpoint != null) {
      // Load checkpoint state
      _logger.d('Loading checkpoint at ${checkpoint.sequence}');
      state = await _snapshotDeserializer!(checkpoint.compressedData);
      fromSequence = checkpoint.sequence;
    } else {
      // No checkpoint found, start from beginning
      _logger.d('No checkpoint found, starting from sequence 0');
      fromSequence = 0;
      state = null; // Will be initialized by replay
    }

    // Replay delta events if needed
    final eventsToReplay = clampedSequence - fromSequence;
    if (eventsToReplay > 0) {
      _logger.d('Replaying $eventsToReplay events from $fromSequence to $clampedSequence');
      state = await _eventReplayer!(fromSequence, clampedSequence);
    }

    stopwatch.stop();
    final latencyMs = stopwatch.elapsedMilliseconds;

    // Create result
    final result = SeekResult(
      targetSequence: clampedSequence,
      checkpointSequence: checkpoint?.sequence ?? 0,
      eventsReplayed: eventsToReplay,
      latencyMs: latencyMs,
      checkpointHit: checkpoint != null,
    );

    // Record for telemetry
    _seekHistory.add(result);

    // Log performance
    if (result.meetsTarget) {
      _logger.d('Seek completed in ${latencyMs}ms (target met)');
    } else {
      _logger.w('Seek took ${latencyMs}ms (exceeds 50ms target!)');
    }

    // Update state
    _updateState(_currentState.copyWith(
      currentSequence: clampedSequence,
      documentState: state,
    ));

    return result;
  }

  /// Starts playback at specified speed.
  ///
  /// Automatically advances sequence at intervals based on speed multiplier.
  /// Supported speeds: 0.5×, 1×, 2×, 5×, 10×
  ///
  /// **Example:**
  /// ```dart
  /// service.play(speed: 2.0); // 2× speed
  /// ```
  void play({double speed = 1.0}) {
    if (!isInitialized) {
      throw StateError('ReplayService not initialized');
    }

    if (_currentState.isPlaying) {
      _logger.w('Playback already active');
      return;
    }

    _logger.i('Starting playback at ${speed}× speed');

    // Cancel existing timer
    _playbackTimer?.cancel();

    // Update state
    _updateState(_currentState.copyWith(
      isPlaying: true,
      playbackSpeed: speed,
    ));

    // Calculate tick interval based on speed
    // Base interval: 100ms per event at 1× speed
    final baseIntervalMs = 100;
    final intervalMs = (baseIntervalMs / speed).round().clamp(10, 1000);

    // Start playback timer
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _advancePlayback();
    });
  }

  /// Pauses playback.
  void pause() {
    if (!_currentState.isPlaying) {
      return;
    }

    _logger.i('Pausing playback');

    _playbackTimer?.cancel();
    _playbackTimer = null;

    _updateState(_currentState.copyWith(isPlaying: false));
  }

  /// Steps forward one event.
  Future<void> stepForward() async {
    if (!isInitialized) {
      throw StateError('ReplayService not initialized');
    }

    final nextSequence = (_currentState.currentSequence + 1)
        .clamp(0, _currentState.maxSequence);

    if (nextSequence != _currentState.currentSequence) {
      await seek(nextSequence);
    }
  }

  /// Steps backward one event.
  Future<void> stepBackward() async {
    if (!isInitialized) {
      throw StateError('ReplayService not initialized');
    }

    final prevSequence = (_currentState.currentSequence - 1).clamp(0, _currentState.maxSequence);

    if (prevSequence != _currentState.currentSequence) {
      await seek(prevSequence);
    }
  }

  /// Advances playback by one step.
  Future<void> _advancePlayback() async {
    if (_currentState.currentSequence >= _currentState.maxSequence) {
      // Reached end, stop playback
      pause();
      _logger.i('Playback reached end');
      return;
    }

    await stepForward();
  }

  /// Returns seek performance statistics.
  ///
  /// Includes average, median, p95, p99 latencies.
  Map<String, dynamic> getSeekMetrics() {
    if (_seekHistory.isEmpty) {
      return {'count': 0};
    }

    final latencies = _seekHistory.map((r) => r.latencyMs).toList()..sort();
    final count = latencies.length;
    final sum = latencies.reduce((a, b) => a + b);
    final avg = sum / count;

    final median = latencies[count ~/ 2];
    final p95 = latencies[(count * 0.95).floor()];
    final p99 = latencies[(count * 0.99).floor()];

    final hitRate = _seekHistory.where((r) => r.checkpointHit).length / count;
    final targetMetRate = _seekHistory.where((r) => r.meetsTarget).length / count;

    return {
      'count': count,
      'avgLatencyMs': avg.toStringAsFixed(1),
      'medianLatencyMs': median,
      'p95LatencyMs': p95,
      'p99LatencyMs': p99,
      'checkpointHitRate': (hitRate * 100).toStringAsFixed(1) + '%',
      'targetMetRate': (targetMetRate * 100).toStringAsFixed(1) + '%',
      'cacheSize': _cache.count,
      'cacheMemory': _cache.memoryUsage,
    };
  }

  /// Updates current state and notifies listeners.
  void _updateState(ReplayState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Disposes resources.
  void dispose() {
    _playbackTimer?.cancel();
    _stateController.close();
    _cache.clear();
    _logger.d('ReplayService disposed');
  }

  @override
  String toString() => 'ReplayService(doc=$_documentId, ${_cache.toString()})';
}
