import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/sqlite_repository.dart';

void main() {
  // Initialize FFI for tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteRepository', () {
    late DatabaseProvider provider;
    late SqliteRepository repository;
    late Directory tempDir;
    late String testDbPath;

    setUp(() async {
      provider = DatabaseProvider();

      // Create a temporary directory for test databases
      tempDir = await Directory.systemTemp.createTemp('wiretuner_test_');
      testDbPath = path.join(tempDir.path, 'test.wiretuner');

      // Initialize and open database
      await provider.initialize();
      await provider.open(testDbPath);

      // Create repository
      repository = SqliteRepository(provider);
    });

    tearDown(() async {
      // Close database connection
      if (provider.isOpen) {
        await provider.close();
      }

      // Clean up temporary files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // ========================================================================
    // Metadata CRUD Tests
    // ========================================================================

    group('Metadata CRUD', () {
      test('should create document metadata successfully', () async {
        final docId = await repository.createDocument(
          documentId: 'doc-1',
          title: 'Test Document',
          author: 'Test Author',
        );

        expect(docId, equals('doc-1'));

        // Verify the document was created
        final metadata = await repository.getDocumentMetadata('doc-1');
        expect(metadata, isNotNull);
        expect(metadata!['document_id'], equals('doc-1'));
        expect(metadata['title'], equals('Test Document'));
        expect(metadata['author'], equals('Test Author'));
        expect(
          metadata['format_version'],
          equals(DatabaseProvider.currentSchemaVersion),
        );
      });

      test('should create document with null author', () async {
        await repository.createDocument(
          documentId: 'doc-2',
          title: 'No Author Doc',
        );

        final metadata = await repository.getDocumentMetadata('doc-2');
        expect(metadata, isNotNull);
        expect(metadata!['author'], isNull);
      });

      test('should throw StateError when creating duplicate document',
          () async {
        await repository.createDocument(
          documentId: 'doc-dup',
          title: 'First',
        );

        expect(
          () => repository.createDocument(
            documentId: 'doc-dup',
            title: 'Second',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('should retrieve document metadata', () async {
        await repository.createDocument(
          documentId: 'doc-3',
          title: 'Retrieve Test',
          author: 'Author',
        );

        final metadata = await repository.getDocumentMetadata('doc-3');

        expect(metadata, isNotNull);
        expect(metadata!['title'], equals('Retrieve Test'));
        expect(metadata['created_at'], isA<int>());
        expect(metadata['modified_at'], isA<int>());
      });

      test('should return null when retrieving non-existent document',
          () async {
        final metadata =
            await repository.getDocumentMetadata('non-existent');

        expect(metadata, isNull);
      });

      test('should update document title', () async {
        await repository.createDocument(
          documentId: 'doc-4',
          title: 'Original Title',
        );

        final originalMetadata = await repository.getDocumentMetadata('doc-4');
        final originalModifiedAt = originalMetadata!['modified_at'] as int;

        // Wait a bit to ensure timestamp changes
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final updateCount = await repository.updateDocumentMetadata(
          'doc-4',
          title: 'Updated Title',
        );

        expect(updateCount, equals(1));

        final updatedMetadata = await repository.getDocumentMetadata('doc-4');
        expect(updatedMetadata!['title'], equals('Updated Title'));
        expect(
          updatedMetadata['modified_at'] as int,
          greaterThan(originalModifiedAt),
        );
      });

      test('should update document author', () async {
        await repository.createDocument(
          documentId: 'doc-5',
          title: 'Title',
          author: 'Original Author',
        );

        await repository.updateDocumentMetadata(
          'doc-5',
          author: 'New Author',
        );

        final metadata = await repository.getDocumentMetadata('doc-5');
        expect(metadata!['author'], equals('New Author'));
        expect(metadata['title'], equals('Title')); // Title unchanged
      });

      test('should return 0 when updating non-existent document', () async {
        final updateCount = await repository.updateDocumentMetadata(
          'non-existent',
          title: 'New Title',
        );

        expect(updateCount, equals(0));
      });

      test('should delete document successfully', () async {
        await repository.createDocument(
          documentId: 'doc-6',
          title: 'To Be Deleted',
        );

        final deleteCount = await repository.deleteDocument('doc-6');
        expect(deleteCount, equals(1));

        final metadata = await repository.getDocumentMetadata('doc-6');
        expect(metadata, isNull);
      });

      test('should return 0 when deleting non-existent document', () async {
        final deleteCount = await repository.deleteDocument('non-existent');
        expect(deleteCount, equals(0));
      });

      test('should list all documents', () async {
        await repository.createDocument(
          documentId: 'doc-7',
          title: 'Document 1',
        );
        await repository.createDocument(
          documentId: 'doc-8',
          title: 'Document 2',
        );
        await repository.createDocument(
          documentId: 'doc-9',
          title: 'Document 3',
        );

        final documents = await repository.listDocuments();

        expect(documents.length, equals(3));
        expect(
          documents.map((d) => d['document_id']),
          containsAll(['doc-7', 'doc-8', 'doc-9']),
        );
      });

      test('should list documents ordered by modified_at DESC', () async {
        await repository.createDocument(
          documentId: 'doc-old',
          title: 'Old',
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        await repository.createDocument(
          documentId: 'doc-new',
          title: 'New',
        );

        final documents = await repository.listDocuments();

        expect(documents.length, equals(2));
        expect(documents.first['document_id'], equals('doc-new'));
        expect(documents.last['document_id'], equals('doc-old'));
      });
    });

    // ========================================================================
    // Event Operations Tests
    // ========================================================================

    group('Event Operations', () {
      setUp(() async {
        // Create a document for event tests
        await repository.createDocument(
          documentId: 'event-doc',
          title: 'Event Test Document',
        );
      });

      test('should insert event successfully', () async {
        final event = CreatePathEvent(
          eventId: 'evt-1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100.0, y: 200.0),
        );

        final eventId = await repository.insertEvent('event-doc', event);

        expect(eventId, isPositive);
      });

      test('should retrieve events by sequence range', () async {
        // Insert multiple events
        for (int i = 0; i < 5; i++) {
          final event = CreatePathEvent(
            eventId: 'evt-$i',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-$i',
            startAnchor: Point(x: i * 10.0, y: i * 20.0),
          );
          await repository.insertEvent('event-doc', event);
        }

        // Retrieve events from sequence 1 to 3
        final events = await repository.getEvents(
          'event-doc',
          fromSeq: 1,
          toSeq: 3,
        );

        expect(events.length, equals(3));
        expect(events[0].eventType, equals('CreatePathEvent'));
      });

      test('should retrieve all events from a sequence onwards', () async {
        // Insert 10 events
        for (int i = 0; i < 10; i++) {
          final event = CreatePathEvent(
            eventId: 'evt-$i',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-$i',
            startAnchor: Point(x: i * 10.0, y: i * 20.0),
          );
          await repository.insertEvent('event-doc', event);
        }

        // Retrieve all events from sequence 5 onwards
        final events = await repository.getEvents(
          'event-doc',
          fromSeq: 5,
        );

        expect(events.length, equals(5)); // Sequences 5-9
      });

      test('should return max sequence correctly', () async {
        expect(await repository.getMaxSequence('event-doc'), equals(-1));

        await repository.insertEvent(
          'event-doc',
          CreatePathEvent(
            eventId: 'evt-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            startAnchor: const Point(x: 100.0, y: 200.0),
          ),
        );

        expect(await repository.getMaxSequence('event-doc'), equals(0));

        await repository.insertEvent(
          'event-doc',
          CreatePathEvent(
            eventId: 'evt-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-2',
            startAnchor: const Point(x: 300.0, y: 400.0),
          ),
        );

        expect(await repository.getMaxSequence('event-doc'), equals(1));
      });

      test('should throw StateError when inserting event for non-existent document',
          () async {
        final event = CreatePathEvent(
          eventId: 'evt-orphan',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-orphan',
          startAnchor: const Point(x: 100.0, y: 200.0),
        );

        await expectLater(
          repository.insertEvent('non-existent-doc', event),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ========================================================================
    // Snapshot Operations Tests
    // ========================================================================

    group('Snapshot Operations', () {
      setUp(() async {
        // Create a document for snapshot tests
        await repository.createDocument(
          documentId: 'snap-doc',
          title: 'Snapshot Test Document',
        );
      });

      test('should create snapshot successfully', () async {
        final snapshotData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final snapshotId = await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 100,
          snapshotData: snapshotData,
          compression: 'gzip',
        );

        expect(snapshotId, isPositive);
      });

      test('should retrieve latest snapshot', () async {
        final data1 = Uint8List.fromList([1, 2, 3]);
        final data2 = Uint8List.fromList([4, 5, 6]);
        final data3 = Uint8List.fromList([7, 8, 9]);

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 100,
          snapshotData: data1,
        );

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 200,
          snapshotData: data2,
        );

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 300,
          snapshotData: data3,
        );

        final latestSnapshot = await repository.getLatestSnapshot('snap-doc');

        expect(latestSnapshot, isNotNull);
        expect(latestSnapshot!['event_sequence'], equals(300));
        expect(latestSnapshot['snapshot_data'], equals(data3));
        expect(latestSnapshot['compression'], equals('gzip'));
      });

      test('should retrieve latest snapshot at or before max sequence',
          () async {
        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 100,
          snapshotData: Uint8List.fromList([1]),
        );

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 200,
          snapshotData: Uint8List.fromList([2]),
        );

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 300,
          snapshotData: Uint8List.fromList([3]),
        );

        // Get snapshot at or before sequence 250
        final snapshot = await repository.getLatestSnapshot(
          'snap-doc',
          maxSequence: 250,
        );

        expect(snapshot, isNotNull);
        expect(snapshot!['event_sequence'], equals(200));
      });

      test('should return null when no snapshots exist', () async {
        final snapshot = await repository.getLatestSnapshot('snap-doc');
        expect(snapshot, isNull);
      });

      test('should list all snapshots for a document', () async {
        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 100,
          snapshotData: Uint8List.fromList([1]),
        );

        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 200,
          snapshotData: Uint8List.fromList([2]),
        );

        final snapshots = await repository.listSnapshots('snap-doc');

        expect(snapshots.length, equals(2));
        expect(snapshots[0]['event_sequence'], equals(100));
        expect(snapshots[1]['event_sequence'], equals(200));
        expect(snapshots[0].containsKey('snapshot_data'), isFalse);
      });

      test('should prune old snapshots', () async {
        // Create 15 snapshots
        for (int i = 0; i < 15; i++) {
          await repository.createSnapshot(
            documentId: 'snap-doc',
            eventSequence: i * 100,
            snapshotData: Uint8List.fromList([i]),
          );
        }

        // Keep only 10 most recent
        final pruneCount = await repository.pruneSnapshots(
          'snap-doc',
          keepCount: 10,
        );

        expect(pruneCount, equals(5));

        final remaining = await repository.listSnapshots('snap-doc');
        expect(remaining.length, equals(10));
        expect(remaining.first['event_sequence'], equals(500)); // Oldest kept
        expect(remaining.last['event_sequence'], equals(1400)); // Newest
      });

      test('should not prune when fewer snapshots than keep count', () async {
        await repository.createSnapshot(
          documentId: 'snap-doc',
          eventSequence: 100,
          snapshotData: Uint8List.fromList([1]),
        );

        final pruneCount = await repository.pruneSnapshots(
          'snap-doc',
          keepCount: 10,
        );

        expect(pruneCount, equals(0));
      });

      test('should throw StateError when creating snapshot for non-existent document',
          () async {
        await expectLater(
          repository.createSnapshot(
            documentId: 'non-existent',
            eventSequence: 100,
            snapshotData: Uint8List.fromList([1]),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ========================================================================
    // Transaction Tests
    // ========================================================================

    group('Transactions', () {
      test('should commit transaction when all operations succeed', () async {
        await repository.transaction((txn) async {
          // Create document metadata
          await txn.insert('metadata', {
            'document_id': 'txn-doc',
            'title': 'Transaction Test',
            'format_version': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'modified_at': DateTime.now().millisecondsSinceEpoch,
          });

          // Insert event
          await txn.insert('events', {
            'document_id': 'txn-doc',
            'event_sequence': 0,
            'event_type': 'CreatePathEvent',
            'event_payload': '{"eventType":"CreatePathEvent","eventId":"evt-1","timestamp":${DateTime.now().millisecondsSinceEpoch},"pathId":"path-1","startAnchor":{"x":100.0,"y":200.0}}',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        });

        // Verify both operations succeeded
        final metadata = await repository.getDocumentMetadata('txn-doc');
        expect(metadata, isNotNull);

        final events = await repository.getEvents('txn-doc', fromSeq: 0);
        expect(events.length, equals(1));
      });

      test('should rollback transaction when operation fails', () async {
        try {
          await repository.transaction((txn) async {
            // Create document
            await txn.insert('metadata', {
              'document_id': 'rollback-doc',
              'title': 'Should Rollback',
              'format_version': 1,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'modified_at': DateTime.now().millisecondsSinceEpoch,
            });

            // This should fail - foreign key constraint violation
            await txn.insert('events', {
              'document_id': 'non-existent-doc',
              'event_sequence': 0,
              'event_type': 'CreatePathEvent',
              'event_payload': '{}',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          });
        } catch (e) {
          // Expected to fail
        }

        // Verify document was not created (transaction rolled back)
        final metadata = await repository.getDocumentMetadata('rollback-doc');
        expect(metadata, isNull);
      });
    });

    // ========================================================================
    // Note: Foreign key cascade tests are omitted as they test SQLite's
    // ON DELETE CASCADE behavior, which is verified by the SchemaManager tests
    // ========================================================================

    // ========================================================================
    // Utility & Statistics Tests
    // ========================================================================

    group('Utilities', () {
      test('should return database statistics', () async {
        await repository.createDocument(
          documentId: 'stats-doc-1',
          title: 'Stats 1',
        );

        await repository.createDocument(
          documentId: 'stats-doc-2',
          title: 'Stats 2',
        );

        await repository.insertEvent(
          'stats-doc-1',
          CreatePathEvent(
            eventId: 'evt-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            startAnchor: const Point(x: 100.0, y: 200.0),
          ),
        );

        await repository.createSnapshot(
          documentId: 'stats-doc-1',
          eventSequence: 0,
          snapshotData: Uint8List.fromList([1]),
        );

        final stats = await repository.getDatabaseStats();

        expect(stats['total_documents'], equals(2));
        expect(stats['total_events'], equals(1));
        expect(stats['total_snapshots'], equals(1));
      });

      test('should run VACUUM without errors', () async {
        // Create some data
        await repository.createDocument(
          documentId: 'vacuum-doc',
          title: 'Vacuum Test',
        );

        // Run VACUUM
        await repository.vacuum();

        // Verify database is still functional
        final metadata = await repository.getDocumentMetadata('vacuum-doc');
        expect(metadata, isNotNull);
      });
    });

    // ========================================================================
    // Integration Tests
    // ========================================================================

    group('Integration', () {
      test('should handle complete document lifecycle', () async {
        // 1. Create document
        await repository.createDocument(
          documentId: 'lifecycle-doc',
          title: 'Lifecycle Test',
          author: 'Test User',
        );

        // 2. Insert events
        for (int i = 0; i < 1500; i++) {
          await repository.insertEvent(
            'lifecycle-doc',
            CreatePathEvent(
              eventId: 'evt-$i',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              pathId: 'path-$i',
              startAnchor: Point(x: i * 10.0, y: i * 20.0),
            ),
          );
        }

        // 3. Create snapshots at 1000 events
        await repository.createSnapshot(
          documentId: 'lifecycle-doc',
          eventSequence: 999,
          snapshotData: Uint8List.fromList([1, 2, 3]),
        );

        // 4. Verify we can retrieve snapshot and subsequent events
        final snapshot = await repository.getLatestSnapshot('lifecycle-doc');
        expect(snapshot, isNotNull);
        expect(snapshot!['event_sequence'], equals(999));

        final subsequentEvents = await repository.getEvents(
          'lifecycle-doc',
          fromSeq: 1000,
        );
        expect(subsequentEvents.length, equals(500));

        // 5. Update metadata
        await repository.updateDocumentMetadata(
          'lifecycle-doc',
          title: 'Updated Title',
        );

        // 6. Verify everything is consistent
        final metadata = await repository.getDocumentMetadata('lifecycle-doc');
        expect(metadata!['title'], equals('Updated Title'));

        final stats = await repository.getDatabaseStats();
        expect(stats['total_documents'], equals(1));
        expect(stats['total_events'], equals(1500));
        expect(stats['total_snapshots'], equals(1));
      });
    });
  });
}
