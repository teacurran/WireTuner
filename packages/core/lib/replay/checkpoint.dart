/// Checkpoint data models for history replay.
///
/// Checkpoints are serialized snapshots at regular intervals (every 1k events)
/// that enable fast seeking through document history without replaying from
/// the beginning.
library;

import 'dart:typed_data';

/// A checkpoint representing document state at a specific sequence number.
///
/// Checkpoints are stored compressed (gzip) to minimize memory usage.
/// They enable <50ms seek operations by avoiding full event replay.
class Checkpoint {
  /// Creates a checkpoint.
  ///
  /// [sequence]: Event sequence number this checkpoint represents
  /// [compressedData]: Gzip-compressed serialized document state
  /// [timestamp]: When this checkpoint was created (UTC)
  /// [memorySizeBytes]: Uncompressed memory size for eviction decisions
  Checkpoint({
    required this.sequence,
    required this.compressedData,
    required this.timestamp,
    required this.memorySizeBytes,
  });

  /// Event sequence number this checkpoint represents.
  final int sequence;

  /// Gzip-compressed serialized document state (JSON).
  final Uint8List compressedData;

  /// When this checkpoint was created (UTC).
  final DateTime timestamp;

  /// Uncompressed memory size in bytes for eviction decisions.
  final int memorySizeBytes;

  /// Last access time for LRU eviction (updated on read).
  DateTime lastAccessTime = DateTime.now().toUtc();

  /// Compressed size in bytes (actual memory footprint).
  int get compressedSizeBytes => compressedData.length;

  /// Marks this checkpoint as accessed (for LRU tracking).
  void markAccessed() {
    lastAccessTime = DateTime.now().toUtc();
  }

  @override
  String toString() => 'Checkpoint(seq=$sequence, size=${compressedSizeBytes}B, '
      'created=${timestamp.toIso8601String()})';
}

/// Result of a seek operation.
///
/// Contains performance metrics and metadata for telemetry.
class SeekResult {
  /// Creates a seek result.
  SeekResult({
    required this.targetSequence,
    required this.checkpointSequence,
    required this.eventsReplayed,
    required this.latencyMs,
    required this.checkpointHit,
  });

  /// Target sequence number requested.
  final int targetSequence;

  /// Checkpoint sequence used as base (may be < targetSequence).
  final int checkpointSequence;

  /// Number of events replayed from checkpoint to target.
  final int eventsReplayed;

  /// Total seek latency in milliseconds.
  final int latencyMs;

  /// Whether a checkpoint was found (true) or full replay needed (false).
  final bool checkpointHit;

  /// Whether this seek meets the <50ms performance target.
  bool get meetsTarget => latencyMs < 50;

  @override
  String toString() =>
      'SeekResult(target=$targetSequence, checkpoint=$checkpointSequence, '
      'events=$eventsReplayed, latency=${latencyMs}ms, hit=$checkpointHit)';
}

/// Current replay state for UI binding.
class ReplayState {
  /// Creates a replay state.
  const ReplayState({
    required this.currentSequence,
    required this.maxSequence,
    required this.isPlaying,
    required this.playbackSpeed,
    this.documentState,
  });

  /// Current sequence number being displayed.
  final int currentSequence;

  /// Maximum available sequence number.
  final int maxSequence;

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Playback speed multiplier (0.5× to 10×).
  final double playbackSpeed;

  /// Reconstructed document state at currentSequence (nullable).
  final dynamic documentState;

  /// Progress as fraction (0.0 to 1.0).
  double get progress =>
      maxSequence == 0 ? 0.0 : currentSequence / maxSequence;

  /// Creates a copy with updated fields.
  ReplayState copyWith({
    int? currentSequence,
    int? maxSequence,
    bool? isPlaying,
    double? playbackSpeed,
    dynamic documentState,
  }) {
    return ReplayState(
      currentSequence: currentSequence ?? this.currentSequence,
      maxSequence: maxSequence ?? this.maxSequence,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      documentState: documentState ?? this.documentState,
    );
  }

  @override
  String toString() => 'ReplayState(seq=$currentSequence/$maxSequence, '
      'playing=$isPlaying, speed=${playbackSpeed}x)';
}
