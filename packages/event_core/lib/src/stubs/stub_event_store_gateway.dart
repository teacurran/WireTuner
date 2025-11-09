/// Stub implementation of EventStoreGateway for testing and development.
library;

import '../event_store_gateway.dart';

/// Stub implementation of [EventStoreGateway] that uses in-memory storage.
///
/// Events are stored in a simple list for development and testing.
/// This implementation does NOT provide durability or transaction semantics.
///
/// TODO(I1.T4): Replace with production SQLite implementation using drift.
class StubEventStoreGateway implements EventStoreGateway {
  /// Creates a stub event store gateway.
  StubEventStoreGateway();

  final List<Map<String, dynamic>> _events = [];
  int _nextSequenceNumber = 1;

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    // Assign sequence number if not present
    if (!eventData.containsKey('sequenceNumber')) {
      eventData['sequenceNumber'] = _nextSequenceNumber++;
    }

    _events.add(Map<String, dynamic>.from(eventData));
    print('[StubEventStoreGateway] persisted event: ${eventData['eventType']} (seq: ${eventData['sequenceNumber']})');
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    for (final event in events) {
      await persistEvent(event);
    }
    print('[StubEventStoreGateway] persisted batch of ${events.length} events');
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    final filtered = _events.where((event) {
      final seq = event['sequenceNumber'] as int;
      if (seq < fromSequence) return false;
      if (toSequence != null && seq > toSequence) return false;
      return true;
    }).toList();

    print('[StubEventStoreGateway] retrieved ${filtered.length} events from $fromSequence to $toSequence');
    return filtered;
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    if (_events.isEmpty) return 0;
    return _events.last['sequenceNumber'] as int;
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {
    _events.removeWhere((event) {
      final seq = event['sequenceNumber'] as int;
      return seq < sequenceNumber;
    });
    print('[StubEventStoreGateway] pruned events before sequence $sequenceNumber');
  }
}
