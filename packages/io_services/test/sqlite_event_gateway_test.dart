import 'package:flutter_test/flutter_test.dart';
import 'package:io_services/io_services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI once for all tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteEventGateway', () {
    late ConnectionFactory factory;
    late Database db;
    late SqliteEventGateway gateway;
    const documentId = 'test-doc';

    setUp(() async {
      factory = ConnectionFactory();
      await factory.initialize();

      db = await factory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
      );

      // Create metadata for the test document
      await db.insert('metadata', {
        'document_id': documentId,
        'title': 'Test Document',
        'format_version': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      });

      gateway = SqliteEventGateway(
        db: db,
        documentId: documentId,
      );
    });

    tearDown(() async {
      await factory.closeAll();
    });

    group('persistEvent()', () {
      test('persists event successfully', () async {
        final eventData = {
          'eventId': 'event-1',
          'eventType': 'CreatePath',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sequenceNumber': 0,
          'pathId': 'path-1',
        };

        await gateway.persistEvent(eventData);

        // Verify event was stored
        final events = await db.query(
          'events',
          where: 'document_id = ?',
          whereArgs: [documentId],
        );

        expect(events, hasLength(1));
        expect(events.first['event_type'], equals('CreatePath'));
        expect(events.first['event_sequence'], equals(0));
      });

      test('throws ArgumentError when missing eventType', () async {
        final eventData = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sequenceNumber': 0,
        };

        expect(
          () => gateway.persistEvent(eventData),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when missing timestamp', () async {
        final eventData = {
          'eventType': 'CreatePath',
          'sequenceNumber': 0,
        };

        expect(
          () => gateway.persistEvent(eventData),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when missing sequenceNumber', () async {
        final eventData = {
          'eventType': 'CreatePath',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        expect(
          () => gateway.persistEvent(eventData),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws StateError on duplicate sequence number', () async {
        final eventData1 = {
          'eventType': 'CreatePath',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sequenceNumber': 0,
        };

        final eventData2 = {
          'eventType': 'DeletePath',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sequenceNumber': 0, // Duplicate
        };

        await gateway.persistEvent(eventData1);

        expect(
          () => gateway.persistEvent(eventData2),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when document does not exist', () async {
        final invalidGateway = SqliteEventGateway(
          db: db,
          documentId: 'nonexistent-doc',
        );

        final eventData = {
          'eventType': 'CreatePath',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sequenceNumber': 0,
        };

        expect(
          () => invalidGateway.persistEvent(eventData),
          throwsA(isA<StateError>()),
        );
      });

      test('preserves all event data in JSON payload', () async {
        final eventData = {
          'eventId': 'event-1',
          'eventType': 'MoveAnchor',
          'timestamp': 1234567890,
          'sequenceNumber': 0,
          'pathId': 'path-1',
          'anchorIndex': 2,
          'newX': 100.5,
          'newY': 200.7,
        };

        await gateway.persistEvent(eventData);

        final events = await gateway.getEvents(fromSequence: 0);
        expect(events, hasLength(1));

        final retrieved = events.first;
        expect(retrieved['eventId'], equals('event-1'));
        expect(retrieved['eventType'], equals('MoveAnchor'));
        expect(retrieved['pathId'], equals('path-1'));
        expect(retrieved['anchorIndex'], equals(2));
        expect(retrieved['newX'], equals(100.5));
        expect(retrieved['newY'], equals(200.7));
      });
    });

    group('persistEventBatch()', () {
      test('persists multiple events atomically', () async {
        final events = [
          {
            'eventType': 'Event1',
            'timestamp': 1000,
            'sequenceNumber': 0,
          },
          {
            'eventType': 'Event2',
            'timestamp': 2000,
            'sequenceNumber': 1,
          },
          {
            'eventType': 'Event3',
            'timestamp': 3000,
            'sequenceNumber': 2,
          },
        ];

        await gateway.persistEventBatch(events);

        final stored = await db.query(
          'events',
          where: 'document_id = ?',
          whereArgs: [documentId],
          orderBy: 'event_sequence ASC',
        );

        expect(stored, hasLength(3));
        expect(stored[0]['event_type'], equals('Event1'));
        expect(stored[1]['event_type'], equals('Event2'));
        expect(stored[2]['event_type'], equals('Event3'));
      });

      test('handles empty batch gracefully', () async {
        await gateway.persistEventBatch([]); // Should not throw

        final stored = await db.query('events');
        expect(stored, isEmpty);
      });

      test('rolls back entire batch on error (atomicity)', () async {
        final events = [
          {
            'eventType': 'Event1',
            'timestamp': 1000,
            'sequenceNumber': 0,
          },
          {
            'eventType': 'Event2',
            'timestamp': 2000,
            'sequenceNumber': 0, // Duplicate - will cause error
          },
        ];

        expect(
          () => gateway.persistEventBatch(events),
          throwsA(isA<StateError>()),
        );

        // Verify no events were persisted
        final stored = await db.query('events');
        expect(stored, isEmpty);
      });

      test('throws ArgumentError for invalid event data', () async {
        final events = [
          {
            'eventType': 'Event1',
            'timestamp': 1000,
            // Missing sequenceNumber
          },
        ];

        expect(
          () => gateway.persistEventBatch(events),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('getEvents()', () {
      setUp(() async {
        // Insert test events
        await gateway.persistEventBatch([
          {'eventType': 'Event0', 'timestamp': 1000, 'sequenceNumber': 0},
          {'eventType': 'Event1', 'timestamp': 2000, 'sequenceNumber': 1},
          {'eventType': 'Event2', 'timestamp': 3000, 'sequenceNumber': 2},
          {'eventType': 'Event3', 'timestamp': 4000, 'sequenceNumber': 3},
          {'eventType': 'Event4', 'timestamp': 5000, 'sequenceNumber': 4},
        ]);
      });

      test('returns all events from specified sequence', () async {
        final events = await gateway.getEvents(fromSequence: 0);

        expect(events, hasLength(5));
        expect(events[0]['eventType'], equals('Event0'));
        expect(events[4]['eventType'], equals('Event4'));
      });

      test('returns events in sequence order', () async {
        final events = await gateway.getEvents(fromSequence: 0);

        for (int i = 0; i < events.length; i++) {
          expect(events[i]['sequenceNumber'], equals(i));
        }
      });

      test('returns events in specified range', () async {
        final events = await gateway.getEvents(
          fromSequence: 1,
          toSequence: 3,
        );

        expect(events, hasLength(3));
        expect(events[0]['eventType'], equals('Event1'));
        expect(events[1]['eventType'], equals('Event2'));
        expect(events[2]['eventType'], equals('Event3'));
      });

      test('returns empty list when no events match', () async {
        final events = await gateway.getEvents(fromSequence: 100);

        expect(events, isEmpty);
      });

      test('returns subset when toSequence exceeds available events', () async {
        final events = await gateway.getEvents(
          fromSequence: 3,
          toSequence: 100,
        );

        expect(events, hasLength(2));
        expect(events[0]['eventType'], equals('Event3'));
        expect(events[1]['eventType'], equals('Event4'));
      });
    });

    group('getLatestSequenceNumber()', () {
      test('returns 0 when no events exist', () async {
        final latest = await gateway.getLatestSequenceNumber();
        expect(latest, equals(0));
      });

      test('returns latest sequence number', () async {
        await gateway.persistEventBatch([
          {'eventType': 'Event0', 'timestamp': 1000, 'sequenceNumber': 0},
          {'eventType': 'Event1', 'timestamp': 2000, 'sequenceNumber': 1},
          {'eventType': 'Event2', 'timestamp': 3000, 'sequenceNumber': 2},
        ]);

        final latest = await gateway.getLatestSequenceNumber();
        expect(latest, equals(2));
      });

      test('updates correctly after adding events', () async {
        await gateway.persistEvent({
          'eventType': 'Event0',
          'timestamp': 1000,
          'sequenceNumber': 0,
        });

        expect(await gateway.getLatestSequenceNumber(), equals(0));

        await gateway.persistEvent({
          'eventType': 'Event1',
          'timestamp': 2000,
          'sequenceNumber': 1,
        });

        expect(await gateway.getLatestSequenceNumber(), equals(1));
      });
    });

    group('pruneEventsBeforeSequence()', () {
      setUp(() async {
        await gateway.persistEventBatch([
          {'eventType': 'Event0', 'timestamp': 1000, 'sequenceNumber': 0},
          {'eventType': 'Event1', 'timestamp': 2000, 'sequenceNumber': 1},
          {'eventType': 'Event2', 'timestamp': 3000, 'sequenceNumber': 2},
          {'eventType': 'Event3', 'timestamp': 4000, 'sequenceNumber': 3},
          {'eventType': 'Event4', 'timestamp': 5000, 'sequenceNumber': 4},
        ]);
      });

      test('deletes events before specified sequence', () async {
        await gateway.pruneEventsBeforeSequence(3);

        final remaining = await gateway.getEvents(fromSequence: 0);

        expect(remaining, hasLength(2));
        expect(remaining[0]['eventType'], equals('Event3'));
        expect(remaining[1]['eventType'], equals('Event4'));
      });

      test('does not delete events at or after specified sequence', () async {
        await gateway.pruneEventsBeforeSequence(2);

        final remaining = await gateway.getEvents(fromSequence: 0);

        expect(remaining, hasLength(3));
        expect(remaining[0]['sequenceNumber'], equals(2));
        expect(remaining[1]['sequenceNumber'], equals(3));
        expect(remaining[2]['sequenceNumber'], equals(4));
      });

      test('handles pruning when no events exist', () async {
        final emptyGateway = SqliteEventGateway(
          db: db,
          documentId: 'empty-doc',
        );

        // Create metadata for empty document
        await db.insert('metadata', {
          'document_id': 'empty-doc',
          'title': 'Empty',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        await emptyGateway.pruneEventsBeforeSequence(100); // Should not throw

        final events = await emptyGateway.getEvents(fromSequence: 0);
        expect(events, isEmpty);
      });
    });

    group('multi-document isolation', () {
      test('events are isolated by document ID', () async {
        // Create second document
        const doc2Id = 'doc-2';
        await db.insert('metadata', {
          'document_id': doc2Id,
          'title': 'Document 2',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        final gateway2 = SqliteEventGateway(
          db: db,
          documentId: doc2Id,
        );

        // Add events to both documents with same sequence numbers
        await gateway.persistEvent({
          'eventType': 'Doc1Event',
          'timestamp': 1000,
          'sequenceNumber': 0,
        });

        await gateway2.persistEvent({
          'eventType': 'Doc2Event',
          'timestamp': 2000,
          'sequenceNumber': 0,
        });

        // Verify isolation
        final doc1Events = await gateway.getEvents(fromSequence: 0);
        final doc2Events = await gateway2.getEvents(fromSequence: 0);

        expect(doc1Events, hasLength(1));
        expect(doc2Events, hasLength(1));
        expect(doc1Events.first['eventType'], equals('Doc1Event'));
        expect(doc2Events.first['eventType'], equals('Doc2Event'));
      });

      test('pruning only affects target document', () async {
        // Create second document
        const doc2Id = 'doc-2';
        await db.insert('metadata', {
          'document_id': doc2Id,
          'title': 'Document 2',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        final gateway2 = SqliteEventGateway(
          db: db,
          documentId: doc2Id,
        );

        // Add events to both documents
        await gateway.persistEventBatch([
          {'eventType': 'Event0', 'timestamp': 1000, 'sequenceNumber': 0},
          {'eventType': 'Event1', 'timestamp': 2000, 'sequenceNumber': 1},
        ]);

        await gateway2.persistEventBatch([
          {'eventType': 'Event0', 'timestamp': 1000, 'sequenceNumber': 0},
          {'eventType': 'Event1', 'timestamp': 2000, 'sequenceNumber': 1},
        ]);

        // Prune doc1 events
        await gateway.pruneEventsBeforeSequence(1);

        // Verify doc1 was pruned but doc2 was not
        final doc1Events = await gateway.getEvents(fromSequence: 0);
        final doc2Events = await gateway2.getEvents(fromSequence: 0);

        expect(doc1Events, hasLength(1));
        expect(doc2Events, hasLength(2));
      });
    });
  });
}
