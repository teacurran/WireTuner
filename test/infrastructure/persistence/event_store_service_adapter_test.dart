import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store_service_adapter.dart';
import 'package:wiretuner/infrastructure/persistence/migrations.dart';

void main() {
  // Initialize FFI for tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseProvider provider;
  late Directory tempDir;
  late String testDbPath;
  late Database db;
  late EventStoreServiceAdapter adapter;

  setUp(() async {
    provider = DatabaseProvider();
    await provider.initialize();

    // Create temporary directory and database
    tempDir = await Directory.systemTemp.createTemp('wiretuner_test_');
    testDbPath = path.join(tempDir.path, 'test_adapter.wiretuner');

    db = await provider.open(testDbPath);

    // Migrate to latest schema
    await SchemaMigrationManager.migrate(db, 1);

    adapter = EventStoreServiceAdapter(db);
  });

  tearDown(() async {
    // Clean up
    adapter.dispose();

    if (provider.isOpen) {
      await provider.close();
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EventStoreServiceAdapter - CRUD Operations', () {
    /// Helper to create a test document in documents table
    Future<void> createTestDocument(String documentId) async {
      await db.insert('documents', {
        'id': documentId,
        'owner_id': 'test-user',
        'name': 'Test Document',
        'file_format_version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'anchor_visibility_mode': 'auto',
        'event_count': 0,
        'snapshot_sequence': 0,
      });
    }

    /// Helper to create a test artboard
    Future<void> createTestArtboard(String artboardId, String documentId) async {
      await db.insert('artboards', {
        'id': artboardId,
        'document_id': documentId,
        'name': 'Test Artboard',
        'bounds_x': 0.0,
        'bounds_y': 0.0,
        'bounds_width': 1920.0,
        'bounds_height': 1080.0,
        'background_color': '#FFFFFF',
        'z_order': 0,
      });
    }

    /// Helper to create a test event
    CreatePathEvent createTestEvent({String? eventId}) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return CreatePathEvent(
        eventId: eventId ?? 'evt_$timestamp',
        timestamp: timestamp,
        pathId: 'path_$timestamp',
        startAnchor: const Point(x: 100, y: 200),
        fillColor: '#FF0000',
        strokeColor: '#000000',
        strokeWidth: 2.0,
        opacity: 1.0,
      );
    }

    test('createEvent adds event with sequence 0 for new document', () async {
      await createTestDocument('doc1');
      final event = createTestEvent(eventId: 'evt_test_001');

      final eventId = await adapter.createEvent('doc1', event);

      expect(eventId, equals('evt_test_001'));

      // Verify it was inserted with sequence 0
      final result = await db.query(
        'events',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      expect(result.length, equals(1));
      expect(result.first['sequence'], equals(0));
      expect(result.first['event_type'], equals('CreatePathEvent'));
      expect(result.first['document_id'], equals('doc1'));
    });

    test('createEvent with artboard_id associates event with artboard', () async {
      await createTestDocument('doc1');
      await createTestArtboard('artboard1', 'doc1');
      final event = createTestEvent(eventId: 'evt_artboard_001');

      final eventId = await adapter.createEvent(
        'doc1',
        event,
        artboardId: 'artboard1',
      );

      // Verify artboard association
      final result = await db.query(
        'events',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      expect(result.first['artboard_id'], equals('artboard1'));
    });

    test('createEvent with operation_id groups events for undo', () async {
      await createTestDocument('doc1');
      final event = createTestEvent(eventId: 'evt_op_001');

      await adapter.createEvent(
        'doc1',
        event,
        operationId: 'undo_group_123',
      );

      // Verify operation_id stored
      final result = await db.query(
        'events',
        where: 'event_id = ?',
        whereArgs: ['evt_op_001'],
      );
      expect(result.first['operation_id'], equals('undo_group_123'));
    });

    test('createEvent auto-increments sequence for multiple events', () async {
      await createTestDocument('doc1');
      final event1 = createTestEvent(eventId: 'evt1');
      final event2 = createTestEvent(eventId: 'evt2');
      final event3 = createTestEvent(eventId: 'evt3');

      await adapter.createEvent('doc1', event1);
      await adapter.createEvent('doc1', event2);
      await adapter.createEvent('doc1', event3);

      // Verify sequences are 0, 1, 2
      final result1 = await db.query('events', where: 'event_id = ?', whereArgs: ['evt1']);
      final result2 = await db.query('events', where: 'event_id = ?', whereArgs: ['evt2']);
      final result3 = await db.query('events', where: 'event_id = ?', whereArgs: ['evt3']);

      expect(result1.first['sequence'], equals(0));
      expect(result2.first['sequence'], equals(1));
      expect(result3.first['sequence'], equals(2));
    });

    test('createEvent updates document event_count', () async {
      await createTestDocument('doc1');
      final event1 = createTestEvent(eventId: 'evt_count_test_1');
      final event2 = createTestEvent(eventId: 'evt_count_test_2');

      await adapter.createEvent('doc1', event1);
      await adapter.createEvent('doc1', event2);

      // Verify event_count updated
      final result = await db.query('documents', where: 'id = ?', whereArgs: ['doc1']);
      expect(result.first['event_count'], equals(2));
    });

    test('getMaxSequence returns -1 for document with no events', () async {
      await createTestDocument('doc1');
      final maxSeq = await adapter.getMaxSequence('doc1');
      expect(maxSeq, equals(-1));
    });

    test('getMaxSequence returns correct value after inserts', () async {
      await createTestDocument('doc1');

      expect(await adapter.getMaxSequence('doc1'), equals(-1));

      await adapter.createEvent('doc1', createTestEvent());
      expect(await adapter.getMaxSequence('doc1'), equals(0));

      await adapter.createEvent('doc1', createTestEvent());
      expect(await adapter.getMaxSequence('doc1'), equals(1));

      await adapter.createEvent('doc1', createTestEvent());
      expect(await adapter.getMaxSequence('doc1'), equals(2));
    });

    test('getEvents returns events in sequence order', () async {
      await createTestDocument('doc1');

      final event1 = createTestEvent(eventId: 'evt1');
      final event2 = createTestEvent(eventId: 'evt2');
      final event3 = createTestEvent(eventId: 'evt3');

      await adapter.createEvent('doc1', event1);
      await adapter.createEvent('doc1', event2);
      await adapter.createEvent('doc1', event3);

      final events = await adapter.getEvents('doc1', fromSeq: 0);

      expect(events.length, equals(3));
      expect(events[0].eventId, equals(event1.eventId));
      expect(events[1].eventId, equals(event2.eventId));
      expect(events[2].eventId, equals(event3.eventId));
    });

    test('getEvents with range returns subset of events', () async {
      await createTestDocument('doc1');

      for (int i = 0; i < 5; i++) {
        await adapter.createEvent('doc1', createTestEvent());
      }

      // Get events 1-3
      final events = await adapter.getEvents('doc1', fromSeq: 1, toSeq: 3);

      expect(events.length, equals(3));
    });

    test('getEvents with artboard filter returns only matching events', () async {
      await createTestDocument('doc1');
      await createTestArtboard('artboard1', 'doc1');
      await createTestArtboard('artboard2', 'doc1');

      // Create events for different artboards
      await adapter.createEvent('doc1', createTestEvent(), artboardId: 'artboard1');
      await adapter.createEvent('doc1', createTestEvent(), artboardId: 'artboard2');
      await adapter.createEvent('doc1', createTestEvent(), artboardId: 'artboard1');
      await adapter.createEvent('doc1', createTestEvent()); // No artboard

      // Get only artboard1 events
      final artboard1Events = await adapter.getEvents(
        'doc1',
        fromSeq: 0,
        artboardId: 'artboard1',
      );

      expect(artboard1Events.length, equals(2));
    });

    test('updateEventMetadata updates operation_id', () async {
      await createTestDocument('doc1');
      final event = createTestEvent(eventId: 'evt_update_001');
      await adapter.createEvent('doc1', event);

      final updated = await adapter.updateEventMetadata(
        'evt_update_001',
        operationId: 'new_operation_123',
      );

      expect(updated, isTrue);

      final result = await db.query('events', where: 'event_id = ?', whereArgs: ['evt_update_001']);
      expect(result.first['operation_id'], equals('new_operation_123'));
    });

    test('updateEventMetadata returns false for non-existent event', () async {
      final updated = await adapter.updateEventMetadata(
        'non_existent',
        operationId: 'test',
      );

      expect(updated, isFalse);
    });

    test('deleteEventsBefore removes old events', () async {
      await createTestDocument('doc1');

      for (int i = 0; i < 10; i++) {
        await adapter.createEvent('doc1', createTestEvent());
      }

      // Delete events before sequence 5
      final deleted = await adapter.deleteEventsBefore('doc1', 5);

      expect(deleted, equals(5)); // Should delete sequences 0-4

      // Verify remaining events
      final remaining = await adapter.getEvents('doc1', fromSeq: 0);
      expect(remaining.length, equals(5)); // Sequences 5-9
    });
  });

  group('EventStoreServiceAdapter - Batch Operations', () {
    Future<void> createTestDocument(String documentId) async {
      await db.insert('documents', {
        'id': documentId,
        'owner_id': 'test-user',
        'name': 'Test Document',
        'file_format_version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'anchor_visibility_mode': 'auto',
        'event_count': 0,
        'snapshot_sequence': 0,
      });
    }

    CreatePathEvent createTestEvent({String? eventId}) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return CreatePathEvent(
        eventId: eventId ?? 'evt_${timestamp}_${DateTime.now().microsecond}',
        timestamp: timestamp,
        pathId: 'path_$timestamp',
        startAnchor: const Point(x: 100, y: 200),
        fillColor: '#FF0000',
        strokeColor: '#000000',
        strokeWidth: 2.0,
        opacity: 1.0,
      );
    }

    test('createEventsBatch inserts multiple events atomically', () async {
      await createTestDocument('doc1');
      final events = List.generate(5, (i) => createTestEvent(eventId: 'batch_evt_$i'));

      final eventIds = await adapter.createEventsBatch('doc1', events);

      expect(eventIds.length, equals(5));

      // Verify all events inserted with correct sequences
      final result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1'], orderBy: 'sequence ASC');
      expect(result.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(result[i]['sequence'], equals(i));
      }
    });

    test('createEventsBatch with auto-save batching delays commit', () async {
      await createTestDocument('doc1');
      final events = [createTestEvent(eventId: 'delayed_evt_1')];

      // Create with delayed commit
      await adapter.createEventsBatch('doc1', events, immediateCommit: false);

      // Event should not be in database yet
      final result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(result.length, equals(0));

      // Flush batch
      await adapter.flushBatch();

      // Now event should be in database
      final resultAfterFlush = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(resultAfterFlush.length, equals(1));
    });

    test('auto-batch flushes when size threshold reached', () async {
      await createTestDocument('doc1');

      // Create adapter with small batch size for testing
      final testAdapter = EventStoreServiceAdapter(db, autoBatchSize: 3, autoBatchTimeoutMs: 10000);

      // Add 2 events - should not flush yet
      await testAdapter.createEventsBatch('doc1', [createTestEvent()], immediateCommit: false);
      await testAdapter.createEventsBatch('doc1', [createTestEvent()], immediateCommit: false);

      var result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(result.length, equals(0));

      // Add 3rd event - should trigger auto-flush
      await testAdapter.createEventsBatch('doc1', [createTestEvent()], immediateCommit: false);

      // All 3 events should now be committed
      result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(result.length, equals(3));

      testAdapter.dispose();
    });

    test('auto-batch flushes when timeout expires', () async {
      await createTestDocument('doc1');

      // Create adapter with short timeout for testing
      final testAdapter = EventStoreServiceAdapter(db, autoBatchSize: 100, autoBatchTimeoutMs: 500);

      // Add event with delayed commit
      await testAdapter.createEventsBatch('doc1', [createTestEvent()], immediateCommit: false);

      // Should not be committed yet
      var result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(result.length, equals(0));

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 600));

      // Should be committed now
      result = await db.query('events', where: 'document_id = ?', whereArgs: ['doc1']);
      expect(result.length, equals(1));

      testAdapter.dispose();
    });

    test('flushBatch callback is invoked after commit', () async {
      await createTestDocument('doc1');

      bool callbackInvoked = false;
      adapter.onBatchCommitted = () {
        callbackInvoked = true;
      };

      await adapter.createEventsBatch('doc1', [createTestEvent()], immediateCommit: false);
      expect(callbackInvoked, isFalse);

      await adapter.flushBatch();
      expect(callbackInvoked, isTrue);
    });
  });

  group('EventStoreServiceAdapter - WAL Integrity', () {
    Future<void> createTestDocument(String documentId) async {
      await db.insert('documents', {
        'id': documentId,
        'owner_id': 'test-user',
        'name': 'Test Document',
        'file_format_version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'anchor_visibility_mode': 'auto',
        'event_count': 0,
        'snapshot_sequence': 0,
      });
    }

    test('performIntegrityCheck returns success for healthy database', () async {
      await createTestDocument('doc1');

      final result = await adapter.performIntegrityCheck();

      expect(result.passed, isTrue);
      expect(result.errors, isEmpty);
    });

    test('performIntegrityCheck performs WAL checkpoint', () async {
      await createTestDocument('doc1');

      final result = await adapter.performIntegrityCheck();

      // Should have checkpoint information
      expect(result.passed, isTrue);
      // WAL pages could be null or a number depending on state
      expect(result.walPages, isNotNull);
    });

    test('getWalStats returns WAL configuration', () async {
      final stats = await adapter.getWalStats();

      expect(stats.pageSize, greaterThan(0));
      expect(stats.autoCheckpointPages, greaterThan(0));
      expect(stats.journalMode, isNotEmpty);
      expect(stats.maxWalSizeBytes, greaterThan(0));
    });
  });

  group('EventStoreServiceAdapter - Error Handling', () {
    Future<void> createTestDocument(String documentId) async {
      await db.insert('documents', {
        'id': documentId,
        'owner_id': 'test-user',
        'name': 'Test Document',
        'file_format_version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
        'anchor_visibility_mode': 'auto',
        'event_count': 0,
        'snapshot_sequence': 0,
      });
    }

    CreatePathEvent createTestEvent({String? eventId}) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return CreatePathEvent(
        eventId: eventId ?? 'evt_$timestamp',
        timestamp: timestamp,
        pathId: 'path_$timestamp',
        startAnchor: const Point(x: 100, y: 200),
        fillColor: '#FF0000',
        strokeColor: '#000000',
        strokeWidth: 2.0,
        opacity: 1.0,
      );
    }

    test('createEvent throws StateError for non-existent document', () async {
      final event = createTestEvent();

      expect(
        () async => await adapter.createEvent('nonexistent_doc', event),
        throwsA(isA<StateError>()),
      );
    });

    test('createEvent throws StateError for duplicate event_id', () async {
      await createTestDocument('doc1');
      final event = createTestEvent(eventId: 'duplicate_evt');

      await adapter.createEvent('doc1', event);

      expect(
        () async => await adapter.createEvent('doc1', event),
        throwsA(isA<StateError>()),
      );
    });

    test('createEventsBatch validates artboardIds length', () async {
      await createTestDocument('doc1');
      final events = [createTestEvent(), createTestEvent()];
      final artboardIds = ['artboard1']; // Wrong length

      expect(
        () async => await adapter.createEventsBatch('doc1', events, artboardIds: artboardIds),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('createEventsBatch validates events not empty', () async {
      await createTestDocument('doc1');

      expect(
        () async => await adapter.createEventsBatch('doc1', []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
