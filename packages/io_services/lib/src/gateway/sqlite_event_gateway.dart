import 'dart:convert';

import 'package:event_core/event_core.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite implementation of [EventStoreGateway].
///
/// This class provides concrete persistence operations for the event sourcing
/// architecture, implementing the gateway interface defined in event_core.
///
/// It handles:
/// - Single event persistence
/// - Batch event persistence with transaction semantics
/// - Event retrieval with sequence ordering
/// - Sequence number management
/// - Event pruning for snapshot cleanup
///
/// All operations assume a valid database connection has been established
/// via [ConnectionFactory] and that the schema has been migrated.
class SqliteEventGateway implements EventStoreGateway {
  SqliteEventGateway({
    required Database db,
    required String documentId,
  })  : _db = db,
        _documentId = documentId;

  final Database _db;
  final String _documentId;
  static final Logger _logger = Logger();

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    _logger.d('Persisting event: ${eventData['eventType']} for document: $_documentId');

    try {
      // Extract event fields
      final eventType = eventData['eventType'] as String?;
      final timestamp = eventData['timestamp'] as int?;
      final sequenceNumber = eventData['sequenceNumber'] as int?;

      // Validate required fields
      if (eventType == null) {
        throw ArgumentError('Event data missing required field: eventType');
      }
      if (timestamp == null) {
        throw ArgumentError('Event data missing required field: timestamp');
      }
      if (sequenceNumber == null) {
        throw ArgumentError('Event data missing required field: sequenceNumber');
      }

      // Serialize event payload
      final payload = json.encode(eventData);

      // Insert event
      final eventId = await _db.rawInsert(
        '''
        INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [_documentId, sequenceNumber, eventType, payload, timestamp, null],
      );

      _logger.i('Event persisted: id=$eventId, sequence=$sequenceNumber, type=$eventType');
    } on DatabaseException catch (e) {
      _logger.e('Database error persisting event', error: e);
      _handleDatabaseException(e, eventData);
    } on ArgumentError {
      // Re-throw ArgumentErrors without wrapping
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error persisting event', error: e);
      throw Exception('Failed to persist event for document "$_documentId": $e');
    }
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) {
      _logger.w('Attempted to persist empty event batch');
      return;
    }

    _logger.d('Persisting batch of ${events.length} events for document: $_documentId');

    try {
      await _db.transaction((txn) async {
        for (final eventData in events) {
          // Extract event fields
          final eventType = eventData['eventType'] as String?;
          final timestamp = eventData['timestamp'] as int?;
          final sequenceNumber = eventData['sequenceNumber'] as int?;

          // Validate required fields
          if (eventType == null || timestamp == null || sequenceNumber == null) {
            throw ArgumentError(
              'Event data missing required fields. Required: eventType, timestamp, sequenceNumber',
            );
          }

          // Serialize event payload
          final payload = json.encode(eventData);

          // Insert event
          await txn.rawInsert(
            '''
            INSERT INTO events (document_id, event_sequence, event_type, event_payload, timestamp, user_id)
            VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [_documentId, sequenceNumber, eventType, payload, timestamp, null],
          );
        }
      });

      _logger.i('Batch persisted: ${events.length} events for document $_documentId');
    } on DatabaseException catch (e) {
      _logger.e('Database error persisting event batch', error: e);
      _handleDatabaseException(e, events.first);
    } on ArgumentError {
      // Re-throw ArgumentErrors without wrapping
      rethrow;
    } catch (e) {
      _logger.e('Unexpected error persisting event batch', error: e);
      throw Exception('Failed to persist event batch for document "$_documentId": $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    _logger.d('Fetching events: doc=$_documentId, from=$fromSequence, to=$toSequence');

    try {
      final String sql;
      final List<Object?> args;

      if (toSequence == null) {
        sql = '''
          SELECT event_type, event_payload FROM events
          WHERE document_id = ? AND event_sequence >= ?
          ORDER BY event_sequence ASC
        ''';
        args = [_documentId, fromSequence];
      } else {
        sql = '''
          SELECT event_type, event_payload FROM events
          WHERE document_id = ? AND event_sequence >= ? AND event_sequence <= ?
          ORDER BY event_sequence ASC
        ''';
        args = [_documentId, fromSequence, toSequence];
      }

      final result = await _db.rawQuery(sql, args);

      final events = result.map((row) {
        final payload = row['event_payload'] as String;
        final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
        return jsonMap;
      }).toList();

      _logger.d('Fetched ${events.length} events for document $_documentId');
      return events;
    } catch (e) {
      _logger.e('Error fetching events', error: e);
      throw Exception(
        'Failed to fetch events for document "$_documentId" '
        '(from: $fromSequence, to: $toSequence): $e',
      );
    }
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    _logger.d('Fetching latest sequence number for document: $_documentId');

    try {
      final result = await _db.rawQuery(
        'SELECT MAX(event_sequence) as max_seq FROM events WHERE document_id = ?',
        [_documentId],
      );

      final maxSeq = result.first['max_seq'] as int?;
      final latestSeq = maxSeq ?? 0;

      _logger.d('Latest sequence number for document $_documentId: $latestSeq');
      return latestSeq;
    } catch (e) {
      _logger.e('Error fetching latest sequence number', error: e);
      throw Exception(
        'Failed to fetch latest sequence number for document "$_documentId": $e',
      );
    }
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {
    _logger.i('Pruning events before sequence $sequenceNumber for document: $_documentId');

    try {
      final deletedCount = await _db.rawDelete(
        'DELETE FROM events WHERE document_id = ? AND event_sequence < ?',
        [_documentId, sequenceNumber],
      );

      _logger.i('Pruned $deletedCount events before sequence $sequenceNumber');
    } catch (e) {
      _logger.e('Error pruning events', error: e);
      throw Exception(
        'Failed to prune events before sequence $sequenceNumber for document "$_documentId": $e',
      );
    }
  }

  /// Handles database exceptions with actionable error messages.
  Never _handleDatabaseException(
    DatabaseException e,
    Map<String, dynamic> eventData,
  ) {
    final errorMsg = e.toString();

    if (errorMsg.contains('UNIQUE constraint')) {
      throw StateError(
        'Event sequence ${eventData['sequenceNumber']} already exists for document "$_documentId". '
        'This indicates a concurrency issue or duplicate event submission.',
      );
    }

    if (errorMsg.contains('FOREIGN KEY constraint')) {
      throw StateError(
        'Document "$_documentId" does not exist in the metadata table. '
        'Ensure the document is created before persisting events.',
      );
    }

    throw Exception(
      'Database error persisting event for document "$_documentId": $e',
    );
  }
}
