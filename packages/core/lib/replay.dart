/// History replay module with checkpoint-based seeking.
///
/// Provides time-travel debugging and history scrubbing for documents.
///
/// **Features:**
/// - Checkpoint cache for <50ms seeks
/// - Playback control (0.5×–10× speeds)
/// - Telemetry instrumentation
/// - LRU memory management
///
/// **Usage:**
/// ```dart
/// import 'package:core/replay.dart';
///
/// final service = ReplayService(
///   checkpointInterval: 1000,
///   maxCacheMemory: 100 * 1024 * 1024,
/// );
///
/// await service.initialize(
///   documentId: 'doc123',
///   maxSequence: 50000,
///   snapshotProvider: loadSnapshot,
///   eventReplayer: replayEvents,
///   snapshotDeserializer: deserialize,
/// );
///
/// final result = await service.seek(12345);
/// print('Seek latency: ${result.latencyMs}ms');
/// ```
library;

export 'replay/checkpoint.dart';
export 'replay/checkpoint_cache.dart';
export 'replay/replay_service.dart';
export 'replay/replay_telemetry.dart';
