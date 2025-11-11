/// Event store persistence gateway abstraction.
///
/// This module defines the interface for persisting and retrieving events
/// from SQLite storage, abstracting the underlying persistence mechanism.
library;

/// Interface for event persistence operations.
///
/// Abstracts SQLite storage to enable dependency injection and testing.
/// Concrete implementations will integrate with drift or sqflite in Task I1.T4.
abstract class EventStoreGateway {
  /// Persists a single event to the event store.
  ///
  /// [eventData] must contain:
  /// - `eventId`: Unique identifier
  /// - `timestamp`: Unix milliseconds
  /// - `eventType`: Discriminator string
  /// - `sequenceNumber`: Monotonic sequence for replay ordering
  /// - Additional event-specific fields
  ///
  /// Returns a Future that completes when the event is durably stored.
  ///
  /// TODO(I1.T4): Implement SQLite persistence with transaction support.
  Future<void> persistEvent(Map<String, dynamic> eventData);

  /// Persists a batch of events atomically.
  ///
  /// Either all events are persisted or none (transaction semantics).
  /// Useful for flushing sampled event buffers.
  ///
  /// TODO(I1.T4): Implement batch insert with SQLite transaction.
  Future<void> persistEventBatch(List<Map<String, dynamic>> events);

  /// Retrieves events in sequence-number order.
  ///
  /// [fromSequence]: Starting sequence number (inclusive)
  /// [toSequence]: Ending sequence number (inclusive, null = latest)
  ///
  /// Returns events as JSON maps for polymorphic deserialization.
  ///
  /// TODO(I1.T4): Implement SQLite query with ORDER BY sequenceNumber.
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  });

  /// Retrieves the latest event sequence number.
  ///
  /// Returns 0 if no events exist.
  ///
  /// TODO(I1.T4): Implement MAX(sequenceNumber) query.
  Future<int> getLatestSequenceNumber();

  /// Deletes events older than the specified sequence number.
  ///
  /// Used for pruning old events after snapshot creation.
  ///
  /// TODO(I1.T4): Implement DELETE WHERE sequenceNumber < threshold.
  Future<void> pruneEventsBeforeSequence(int sequenceNumber);
}
