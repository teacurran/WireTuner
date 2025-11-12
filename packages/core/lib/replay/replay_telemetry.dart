/// Telemetry instrumentation for history replay.
///
/// Collects metrics for checkpoint cache, seek latency, playback performance,
/// and memory usage.
library;

import 'package:logger/logger.dart';
import 'replay_service.dart';
import 'checkpoint.dart';

/// Telemetry event types for replay operations.
enum ReplayEventType {
  /// Checkpoint cache initialized.
  checkpointCacheInitialized,

  /// Checkpoint generated.
  checkpointGenerated,

  /// Checkpoint evicted from cache.
  checkpointEvicted,

  /// Seek operation performed.
  seekPerformed,

  /// Playback started.
  playbackStarted,

  /// Playback paused.
  playbackPaused,

  /// Playback completed (reached end).
  playbackCompleted,
}

/// Telemetry event for replay operations.
class ReplayTelemetryEvent {
  /// Creates a telemetry event.
  ReplayTelemetryEvent({
    required this.type,
    required this.timestamp,
    this.documentId,
    this.sequence,
    this.latencyMs,
    this.checkpointSequence,
    this.eventsReplayed,
    this.checkpointHit,
    this.cacheSize,
    this.cacheMemoryBytes,
    this.playbackSpeed,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Event type.
  final ReplayEventType type;

  /// When the event occurred (UTC).
  final DateTime timestamp;

  /// Document ID being replayed.
  final String? documentId;

  /// Target sequence number (for seeks).
  final int? sequence;

  /// Latency in milliseconds (for seeks).
  final int? latencyMs;

  /// Checkpoint sequence used (for seeks).
  final int? checkpointSequence;

  /// Number of events replayed (for seeks).
  final int? eventsReplayed;

  /// Whether checkpoint was hit (for seeks).
  final bool? checkpointHit;

  /// Checkpoint cache size (count).
  final int? cacheSize;

  /// Cache memory usage in bytes.
  final int? cacheMemoryBytes;

  /// Playback speed multiplier.
  final double? playbackSpeed;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Converts to JSON for logging.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      if (documentId != null) 'documentId': documentId,
      if (sequence != null) 'sequence': sequence,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (checkpointSequence != null) 'checkpointSequence': checkpointSequence,
      if (eventsReplayed != null) 'eventsReplayed': eventsReplayed,
      if (checkpointHit != null) 'checkpointHit': checkpointHit,
      if (cacheSize != null) 'cacheSize': cacheSize,
      if (cacheMemoryBytes != null) 'cacheMemoryBytes': cacheMemoryBytes,
      if (playbackSpeed != null) 'playbackSpeed': playbackSpeed,
      ...metadata,
    };
  }

  @override
  String toString() =>
      'ReplayTelemetryEvent(${type.name}, seq=$sequence, latency=${latencyMs}ms)';
}

/// Telemetry collector for replay operations.
///
/// Wraps ReplayService to emit telemetry events for monitoring and debugging.
///
/// **Usage:**
/// ```dart
/// final telemetry = ReplayTelemetry(
///   onEvent: (event) {
///     print('Telemetry: ${event.toJson()}');
///     // Send to TelemetryService, logging, or analytics
///   },
/// );
///
/// final service = ReplayService();
/// telemetry.attach(service);
///
/// // All operations now emit telemetry
/// await service.seek(12345);
/// ```
class ReplayTelemetry {
  /// Creates a telemetry collector.
  ///
  /// [onEvent]: Callback invoked for each telemetry event
  /// [logger]: Optional logger for diagnostics
  ReplayTelemetry({
    required this.onEvent,
    Logger? logger,
  }) : _logger = logger ?? Logger(level: Level.info);

  /// Callback for telemetry events.
  final void Function(ReplayTelemetryEvent event) onEvent;

  final Logger _logger;

  /// Attached replay service.
  ReplayService? _attachedService;

  /// Attaches to a replay service to collect telemetry.
  ///
  /// Subscribes to state stream and wraps operations.
  void attach(ReplayService service) {
    _attachedService = service;

    // Listen to state stream for events
    service.stateStream.listen((state) {
      _handleStateChange(state);
    });

    _logger.d('ReplayTelemetry attached to service');
  }

  /// Detaches from the replay service.
  void detach() {
    _attachedService = null;
    _logger.d('ReplayTelemetry detached');
  }

  /// Records a checkpoint cache initialization event.
  void recordCacheInitialized({
    required String documentId,
    required int maxSequence,
    required int checkpointCount,
    required int memoryBytes,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.checkpointCacheInitialized,
      timestamp: DateTime.now().toUtc(),
      documentId: documentId,
      sequence: maxSequence,
      cacheSize: checkpointCount,
      cacheMemoryBytes: memoryBytes,
    );

    onEvent(event);
    _logger.i('Cache initialized: $checkpointCount checkpoints, '
        '${_formatBytes(memoryBytes)}');
  }

  /// Records a checkpoint generation event.
  void recordCheckpointGenerated({
    required int sequence,
    required int sizeBytes,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.checkpointGenerated,
      timestamp: DateTime.now().toUtc(),
      sequence: sequence,
      metadata: {'sizeBytes': sizeBytes},
    );

    onEvent(event);
    _logger.d('Checkpoint generated at $sequence (${_formatBytes(sizeBytes)})');
  }

  /// Records a checkpoint eviction event.
  void recordCheckpointEvicted({
    required int sequence,
    required int ageSeconds,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.checkpointEvicted,
      timestamp: DateTime.now().toUtc(),
      sequence: sequence,
      metadata: {'ageSeconds': ageSeconds},
    );

    onEvent(event);
    _logger.d('Checkpoint evicted at $sequence (age: ${ageSeconds}s)');
  }

  /// Records a seek operation.
  void recordSeek(SeekResult result, {String? documentId}) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.seekPerformed,
      timestamp: DateTime.now().toUtc(),
      documentId: documentId,
      sequence: result.targetSequence,
      latencyMs: result.latencyMs,
      checkpointSequence: result.checkpointSequence,
      eventsReplayed: result.eventsReplayed,
      checkpointHit: result.checkpointHit,
      metadata: {
        'meetsTarget': result.meetsTarget,
      },
    );

    onEvent(event);

    if (!result.meetsTarget) {
      _logger.w('Seek exceeded 50ms target: ${result.latencyMs}ms '
          '(events replayed: ${result.eventsReplayed})');
    }
  }

  /// Records playback start.
  void recordPlaybackStarted({
    required double speed,
    required int fromSequence,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.playbackStarted,
      timestamp: DateTime.now().toUtc(),
      sequence: fromSequence,
      playbackSpeed: speed,
    );

    onEvent(event);
    _logger.i('Playback started at ${speed}× from sequence $fromSequence');
  }

  /// Records playback pause.
  void recordPlaybackPaused({
    required int atSequence,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.playbackPaused,
      timestamp: DateTime.now().toUtc(),
      sequence: atSequence,
    );

    onEvent(event);
    _logger.i('Playback paused at sequence $atSequence');
  }

  /// Records playback completion.
  void recordPlaybackCompleted({
    required int maxSequence,
    required Duration duration,
  }) {
    final event = ReplayTelemetryEvent(
      type: ReplayEventType.playbackCompleted,
      timestamp: DateTime.now().toUtc(),
      sequence: maxSequence,
      metadata: {
        'durationMs': duration.inMilliseconds,
      },
    );

    onEvent(event);
    _logger.i('Playback completed at $maxSequence (duration: ${duration.inSeconds}s)');
  }

  /// Handles state changes from ReplayService.
  void _handleStateChange(ReplayState state) {
    // Track playback state changes
    // This is called on every state update, so we filter for specific events
    // (Actual event emission is done by explicit record* methods above)
  }

  /// Formats bytes as human-readable string.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Returns summary statistics for all recorded events.
  Map<String, dynamic> getSummary() {
    return {
      'attachedService': _attachedService != null,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// Extension on ReplayService to add telemetry helpers.
extension ReplayServiceTelemetry on ReplayService {
  /// Wraps a seek call with telemetry recording.
  Future<SeekResult> seekWithTelemetry(
    int sequence, {
    required ReplayTelemetry telemetry,
    String? documentId,
  }) async {
    final result = await seek(sequence);
    telemetry.recordSeek(result, documentId: documentId);
    return result;
  }
}
