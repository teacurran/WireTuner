/// Event replayer for rebuilding document state from event log.
///
/// This module provides the capability to replay events from the
/// event store to reconstruct document state at any point in time.
library;

import 'event_store_gateway.dart';
import 'event_dispatcher.dart';
import 'snapshot_manager.dart';
import 'metrics_sink.dart';

/// Interface for replaying events to reconstruct document state.
///
/// Supports time-travel debugging, undo/redo, and document reconstruction
/// from snapshots + subsequent events for efficient loading.
///
/// **Threading**: All methods must be called from the UI isolate.
abstract class EventReplayer {
  /// Reconstructs document state from events.
  ///
  /// Replays events from [fromSequence] to [toSequence] (inclusive),
  /// dispatching each event to registered handlers to rebuild state.
  ///
  /// [fromSequence]: Event sequence to start from (0 = beginning)
  /// [toSequence]: Event sequence to end at (null = latest)
  ///
  /// Returns a Future that completes when replay is finished.
  ///
  /// **Note**: The replayer pauses the [EventRecorder] during replay to
  /// prevent re-recording events, which would create an infinite loop.
  ///
  /// TODO(I1.T6): Implement full replay logic with event dispatcher.
  Future<void> replay({
    int fromSequence = 0,
    int? toSequence,
  });

  /// Loads document state from the most recent snapshot + subsequent events.
  ///
  /// Optimizes document loading by:
  /// 1. Loading the latest snapshot at or before [maxSequence]
  /// 2. Replaying only events after the snapshot up to [maxSequence]
  ///
  /// This avoids replaying the entire event history for large documents.
  ///
  /// [maxSequence]: Maximum sequence number to replay to (null = latest)
  ///
  /// Returns a Future that completes when replay is finished.
  ///
  /// TODO(I1.T6): Implement snapshot-based replay optimization.
  Future<void> replayFromSnapshot({
    int? maxSequence,
  });

  /// Returns whether replay is currently in progress.
  ///
  /// Used to coordinate with the event recorder to prevent re-recording
  /// during replay.
  bool get isReplaying;
}

/// Default stub implementation of [EventReplayer].
///
/// Logs method calls and enforces dependency injection of store gateway,
/// dispatcher, snapshot manager, and metrics sink.
///
/// TODO(I1.T6): Replace with full implementation that handles event
/// traversal, state reconstruction, and snapshot optimization.
class DefaultEventReplayer implements EventReplayer {
  /// Creates a default event replayer with injected dependencies.
  ///
  /// All dependencies are required to enforce proper dependency injection
  /// for future implementations.
  ///
  /// [storeGateway]: SQLite persistence gateway for reading events
  /// [dispatcher]: Event dispatcher for applying events to state
  /// [snapshotManager]: Snapshot manager for snapshot-based replay
  /// [metricsSink]: Metrics collection sink
  DefaultEventReplayer({
    required EventStoreGateway storeGateway,
    required EventDispatcher dispatcher,
    required SnapshotManager snapshotManager,
    required MetricsSink metricsSink,
  })  : _storeGateway = storeGateway,
        _dispatcher = dispatcher,
        _snapshotManager = snapshotManager,
        _metricsSink = metricsSink;

  final EventStoreGateway _storeGateway;
  final EventDispatcher _dispatcher;
  final SnapshotManager _snapshotManager;
  final MetricsSink _metricsSink;

  bool _isReplaying = false;

  @override
  Future<void> replay({
    int fromSequence = 0,
    int? toSequence,
  }) async {
    _isReplaying = true;
    try {
      // TODO(I1.T6): Implement replay logic
      // 1. Fetch events from store (_storeGateway.getEvents)
      // 2. Dispatch each event in sequence (_dispatcher.dispatch)
      // 3. Record replay metrics (_metricsSink.recordReplay)

      print('[EventReplayer] replay called: fromSequence=$fromSequence, toSequence=$toSequence');
    } finally {
      _isReplaying = false;
    }
  }

  @override
  Future<void> replayFromSnapshot({
    int? maxSequence,
  }) async {
    _isReplaying = true;
    try {
      // TODO(I1.T6): Implement snapshot-based replay
      // 1. Load most recent snapshot (_snapshotManager.loadSnapshot)
      // 2. Fetch events after snapshot (_storeGateway.getEvents)
      // 3. Dispatch events to reconstruct state (_dispatcher.dispatch)
      // 4. Record metrics (_metricsSink.recordSnapshotLoad, recordReplay)

      print('[EventReplayer] replayFromSnapshot called: maxSequence=$maxSequence');
    } finally {
      _isReplaying = false;
    }
  }

  @override
  bool get isReplaying => _isReplaying;
}
