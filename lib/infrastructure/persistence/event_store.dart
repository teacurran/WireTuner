import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';

/// Repository for managing event persistence in the SQLite events table.
///
/// Provides CRUD operations for the append-only event log, which is the
/// foundation of the event sourcing architecture. Events are never modified
/// after insertion, only appended.
class EventStore {
  final Database _db;
  static final Logger _logger = Logger();

  EventStore(this._db);

  /// Inserts an event into the event log and returns the auto-incremented event_id.
  ///
  /// The event_sequence is automatically calculated as (max_sequence + 1) for
  /// the given document. Event sequences are 0-based and independent per document.
  ///
  /// Throws [DatabaseException] if:
  /// - Document doesn't exist (foreign key constraint)
  /// - Duplicate sequence number (UNIQUE constraint)
  Future<int> insertEvent(String documentId, EventBase event) async {
    _logger.d('Inserting event: ${event.eventType} for document: $documentId');

    // 1. Get next sequence number
    final maxSeq = await getMaxSequence(documentId);
    final nextSeq = maxSeq + 1;

    // 2. Serialize event payload
    final payload = json.encode(event.toJson());

    // 3. Insert with parameterized query
    try {
      final eventId = await _db.rawInsert(
        '''
        INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [documentId, nextSeq, event.eventType, payload, event.timestamp, null],
      );

      _logger.i('Event inserted: id=$eventId, sequence=$nextSeq');
      return eventId;
    } on DatabaseException catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNIQUE constraint')) {
        throw StateError(
          'Event sequence $nextSeq already exists for document $documentId',
        );
      }
      if (errorMsg.contains('FOREIGN KEY constraint')) {
        throw StateError('Document $documentId does not exist');
      }
      rethrow;
    }
  }

  /// Returns events for a document in the specified sequence range.
  ///
  /// If [toSeq] is null, returns all events from [fromSeq] onwards.
  /// Events are always returned in ascending sequence order.
  ///
  /// Returns an empty list if no events match the criteria.
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
  }) async {
    _logger.d('Fetching events: doc=$documentId, from=$fromSeq, to=$toSeq');

    final String sql;
    final List<Object?> args;

    if (toSeq == null) {
      sql = '''
        SELECT event_type, event_payload FROM events
        WHERE document_id = ? AND event_sequence >= ?
        ORDER BY event_sequence ASC
      ''';
      args = [documentId, fromSeq];
    } else {
      sql = '''
        SELECT event_type, event_payload FROM events
        WHERE document_id = ? AND event_sequence >= ? AND event_sequence <= ?
        ORDER BY event_sequence ASC
      ''';
      args = [documentId, fromSeq, toSeq];
    }

    final result = await _db.rawQuery(sql, args);

    return result.map((row) {
      final payload = row['event_payload'] as String;
      final eventType = row['event_type'] as String;
      final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
      // Add eventType to JSON for polymorphic deserialization
      jsonMap['eventType'] = eventType;
      return eventFromJson(jsonMap);
    }).toList();
  }

  /// Returns the maximum event_sequence for a document, or -1 if none exist.
  ///
  /// This is used to calculate the next sequence number when inserting events.
  Future<int> getMaxSequence(String documentId) async {
    final result = await _db.rawQuery(
      'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
      [documentId],
    );

    final maxSeq = result.first['max_seq'] as int?;
    return maxSeq ?? -1; // -1 if no events
  }

  /// Inserts multiple events in a single atomic transaction.
  ///
  /// This method ensures ACID compliance by wrapping all insertions in a database
  /// transaction. Either all events are inserted successfully, or none are.
  ///
  /// This is more efficient than individual insertEvent calls when inserting
  /// multiple events, as it:
  /// - Reduces transaction overhead (single transaction vs N transactions)
  /// - Queries MAX sequence only once instead of N times
  /// - Ensures atomicity for batch operations
  ///
  /// Parameters:
  /// - [documentId]: The document to insert events for
  /// - [events]: List of events to insert (must not be empty)
  ///
  /// Returns a list of event IDs in the same order as the input events.
  ///
  /// Throws:
  /// - [ArgumentError] if events list is empty
  /// - [StateError] if document doesn't exist
  /// - [DatabaseException] for other database errors
  ///
  /// Example:
  /// ```dart
  /// final events = [event1, event2, event3];
  /// final eventIds = await eventStore.insertEventsBatch('doc-1', events);
  /// print('Inserted ${eventIds.length} events');
  /// ```
  Future<List<int>> insertEventsBatch(
    String documentId,
    List<EventBase> events,
  ) async {
    if (events.isEmpty) {
      throw ArgumentError('Events list cannot be empty');
    }

    _logger.d('Batch inserting ${events.length} events for document: $documentId');

    return await _db.transaction((txn) async {
      final eventIds = <int>[];

      // Get the starting sequence number once
      final maxSeqResult = await txn.rawQuery(
        'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
        [documentId],
      );
      int nextSeq = (maxSeqResult.first['max_seq'] as int? ?? -1) + 1;

      // Insert each event with incrementing sequence
      for (final event in events) {
        final payload = json.encode(event.toJson());

        try {
          final eventId = await txn.rawInsert(
            '''
            INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
            VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [documentId, nextSeq, event.eventType, payload, event.timestamp, null],
          );

          eventIds.add(eventId);
          nextSeq++;
        } on DatabaseException catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('UNIQUE constraint')) {
            throw StateError(
              'Event sequence $nextSeq already exists for document $documentId',
            );
          }
          if (errorMsg.contains('FOREIGN KEY constraint')) {
            throw StateError('Document $documentId does not exist');
          }
          rethrow;
        }
      }

      _logger.i('Batch inserted ${eventIds.length} events for document $documentId');
      return eventIds;
    });
  }
}
