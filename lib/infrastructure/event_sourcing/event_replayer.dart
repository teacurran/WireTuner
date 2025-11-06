import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../../domain/events/event_base.dart';
import '../persistence/event_store.dart';
import '../persistence/snapshot_store.dart';
import 'event_dispatcher.dart';
import 'snapshot_serializer.dart';

/// Reconstructs document state from event sequences using snapshots for optimization.
///
/// The [EventReplayer] is the final piece of the event sourcing infrastructure,
/// responsible for loading documents by replaying their event history. It provides
/// two strategies:
///
/// 1. **Full Replay** ([replay]): Replays events from scratch (sequence 0 onwards)
/// 2. **Snapshot-Optimized Replay** ([replayFromSnapshot]): Loads nearest snapshot
///    then replays only delta events (~100x faster for large documents)
///
/// **Usage Example:**
/// ```dart
/// // Create replayer with dependencies
/// final replayer = EventReplayer(
///   eventStore: eventStore,
///   snapshotStore: snapshotStore,
///   dispatcher: dispatcher,
///   enableCompression: true,
/// );
///
/// // Load document at latest state
/// final maxSeq = await eventStore.getMaxSequence('doc123');
/// final document = await replayer.replayFromSnapshot(
///   documentId: 'doc123',
///   maxSequence: maxSeq,
/// );
/// ```
///
/// **Performance Characteristics:**
/// - Full replay: O(n) where n = total events (use for debugging/testing)
/// - Snapshot replay: O(1) + O(d) where d = delta events since snapshot
/// - Target: < 200ms to load document with 5000 events using snapshots
///
/// **Design Rationale:**
/// - **Deterministic**: Same events always produce same state
/// - **Observable**: Logs all operations for debugging
/// - **Graceful Fallback**: If no snapshot exists, falls back to full replay
/// - **Immutable State**: Replaying never mutates original state
/// - **Dependency Injection**: All dependencies passed via constructor for testability
///
/// **Integration Points:**
/// - Uses [EventStore] to query event sequences
/// - Uses [SnapshotStore] to load most recent snapshots
/// - Uses [EventDispatcher] to apply events deterministically
/// - Uses [SnapshotSerializer] to deserialize snapshot BLOBs
///
/// **Thread Safety**: Designed for single-threaded use on main isolate.
/// All replay operations are async to avoid blocking the UI.
class EventReplayer {
  final EventStore _eventStore;
  final SnapshotStore _snapshotStore;
  final EventDispatcher _dispatcher;
  final SnapshotSerializer _serializer;
  final Logger _logger = Logger();

  /// Creates an [EventReplayer] with the specified dependencies.
  ///
  /// **Parameters:**
  /// - [eventStore]: Store for querying event sequences
  /// - [snapshotStore]: Store for loading document snapshots
  /// - [dispatcher]: Dispatcher for applying events to state
  /// - [enableCompression]: Enable gzip compression for snapshot deserialization (default: true)
  ///
  /// **Usage Example:**
  /// ```dart
  /// final replayer = EventReplayer(
  ///   eventStore: EventStore(db),
  ///   snapshotStore: SnapshotStore(db),
  ///   dispatcher: EventDispatcher(registry),
  ///   enableCompression: true,
  /// );
  /// ```
  EventReplayer({
    required EventStore eventStore,
    required SnapshotStore snapshotStore,
    required EventDispatcher dispatcher,
    bool enableCompression = true,
  })  : _eventStore = eventStore,
        _snapshotStore = snapshotStore,
        _dispatcher = dispatcher,
        _serializer = SnapshotSerializer(enableCompression: enableCompression);

  /// Reconstructs document state from events in the specified range.
  ///
  /// This method replays events from scratch without using snapshots. It's
  /// primarily used for testing, debugging, or when no snapshots exist.
  ///
  /// **Process:**
  /// 1. Query events from EventStore (fromSequence to toSequence)
  /// 2. Create empty initial state (placeholder Map for now)
  /// 3. Use EventDispatcher.dispatchAll() to apply events
  /// 4. Return final state
  ///
  /// **Performance:** O(n) where n = number of events. For documents with 10,000+
  /// events, use [replayFromSnapshot] instead for ~100x speedup.
  ///
  /// **Usage Example:**
  /// ```dart
  /// // Replay all events for a document
  /// final document = await replayer.replay(
  ///   documentId: 'doc123',
  ///   fromSequence: 0,
  ///   toSequence: null, // null = replay to latest
  /// );
  ///
  /// // Replay specific range (for undo/redo)
  /// final documentAtSeq500 = await replayer.replay(
  ///   documentId: 'doc123',
  ///   fromSequence: 0,
  ///   toSequence: 500,
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// - [documentId]: The document to replay events for
  /// - [fromSequence]: Event sequence to start from (0 = beginning)
  /// - [toSequence]: Event sequence to end at (null = latest)
  ///
  /// **Returns:** The reconstructed document state (Map for now, Document in I3.T6)
  ///
  /// **Edge Cases:**
  /// - Empty event list: Returns placeholder empty document
  /// - toSequence beyond max: Replays to latest event
  /// - fromSequence > toSequence: Returns empty event list (handled by EventStore)
  Future<dynamic> replay({
    required String documentId,
    int fromSequence = 0,
    int? toSequence,
  }) async {
    try {
      _logger.d(
        'Replaying events: doc=$documentId, from=$fromSequence, to=$toSequence',
      );

      // Step 1: Query events
      final events = await _eventStore.getEvents(
        documentId,
        fromSeq: fromSequence,
        toSeq: toSequence,
      );

      _logger.d('Fetched ${events.length} events for replay');

      if (events.isEmpty) {
        _logger.w('No events found for doc=$documentId');
        // Return empty placeholder document
        return {
          'id': documentId,
          'title': 'Empty Document',
          'layers': [],
        };
      }

      // Step 2: Create initial state (placeholder until Document model exists)
      final initialState = {
        'id': documentId,
        'title': 'New Document',
        'layers': [],
      };

      // Step 3: Replay events via dispatcher
      final finalState = _dispatcher.dispatchAll(initialState, events);

      _logger.i(
        'Replayed ${events.length} events successfully '
        '(seq $fromSequence to ${toSequence ?? "latest"})',
      );
      return finalState;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to replay events for doc=$documentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reconstructs document state from nearest snapshot + subsequent events.
  ///
  /// This is the primary method for fast document loading. It loads the most
  /// recent snapshot before maxSequence, then replays only the delta events.
  ///
  /// **Performance Optimization:** With snapshots every 1000 events, this method
  /// typically only needs to replay < 1000 events, achieving ~100x speedup vs
  /// full replay for large documents.
  ///
  /// **Process:**
  /// 1. Query latest snapshot from SnapshotStore (≤ maxSequence)
  /// 2. If snapshot exists:
  ///    a. Deserialize snapshot BLOB → Document state
  ///    b. Query events from (snapshot sequence + 1) to maxSequence
  ///    c. Replay delta events via dispatcher
  /// 3. If no snapshot:
  ///    a. Fall back to full replay from sequence 0
  ///
  /// **Usage Example:**
  /// ```dart
  /// // Load document at latest state
  /// final maxSeq = await eventStore.getMaxSequence('doc123');
  /// final document = await replayer.replayFromSnapshot(
  ///   documentId: 'doc123',
  ///   maxSequence: maxSeq,
  /// );
  ///
  /// // Load document at specific sequence (undo to sequence 5000)
  /// final documentAt5000 = await replayer.replayFromSnapshot(
  ///   documentId: 'doc123',
  ///   maxSequence: 5000,
  /// );
  /// ```
  ///
  /// **Parameters:**
  /// - [documentId]: The document to replay
  /// - [maxSequence]: Target sequence to reconstruct state at
  ///
  /// **Returns:** The reconstructed document state at maxSequence
  ///
  /// **Edge Cases:**
  /// - No snapshot exists: Falls back to [replay] from sequence 0
  /// - Snapshot at target sequence: Returns snapshot (no delta replay)
  /// - Snapshot beyond target: Returns snapshot (no delta replay)
  /// - Empty delta events: Returns snapshot state
  ///
  /// **Performance Target:** < 200ms for documents with 5000 events
  Future<dynamic> replayFromSnapshot({
    required String documentId,
    required int maxSequence,
  }) async {
    try {
      _logger.d(
        'Replaying from snapshot: doc=$documentId, maxSeq=$maxSequence',
      );

      // Step 1: Query latest snapshot
      final snapshotData = await _snapshotStore.getLatestSnapshot(
        documentId,
        maxSequence,
      );

      if (snapshotData == null) {
        // No snapshot exists - fall back to full replay
        _logger.w(
          'No snapshot found for doc=$documentId, falling back to full replay',
        );
        return replay(
          documentId: documentId,
          fromSequence: 0,
          toSequence: maxSequence,
        );
      }

      // Step 2: Deserialize snapshot
      final snapshotBytes = snapshotData['snapshot_data'] as Uint8List;
      final snapshotSequence = snapshotData['event_sequence'] as int;

      _logger.d(
        'Found snapshot at sequence $snapshotSequence '
        '(${snapshotBytes.length} bytes)',
      );

      final baseState = _serializer.deserialize(snapshotBytes);

      // Step 3: Query delta events (after snapshot to maxSequence)
      if (snapshotSequence >= maxSequence) {
        // Snapshot is at or beyond target - no events to replay
        _logger.d(
          'Snapshot at $snapshotSequence >= target $maxSequence, '
          'no delta replay needed',
        );
        return baseState;
      }

      final deltaEvents = await _eventStore.getEvents(
        documentId,
        fromSeq: snapshotSequence + 1, // +1 is critical - events AFTER snapshot
        toSeq: maxSequence,
      );

      _logger.d('Replaying ${deltaEvents.length} delta events');

      // Step 4: Replay delta events
      if (deltaEvents.isEmpty) {
        _logger.d('No delta events to replay');
        return baseState;
      }

      final finalState = _dispatcher.dispatchAll(baseState, deltaEvents);

      _logger.i(
        'Replay complete: snapshot at $snapshotSequence + '
        '${deltaEvents.length} delta events → sequence $maxSequence',
      );

      return finalState;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to replay from snapshot for doc=$documentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
