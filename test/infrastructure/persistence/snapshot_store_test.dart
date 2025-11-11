import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseProvider provider;
  late Directory tempDir;
  late String testDbPath;
  late Database db;
  late SnapshotStore snapshotStore;

  setUp(() async {
    provider = DatabaseProvider();
    await provider.initialize();

    tempDir = await Directory.systemTemp.createTemp('wiretuner_test_');
    testDbPath = path.join(tempDir.path, 'test_snapshot_store.wiretuner');

    db = await provider.open(testDbPath);

    // Explicitly enable foreign keys for this connection
    // (Required for CASCADE DELETE to work properly)
    await db.execute('PRAGMA foreign_keys=ON;');

    snapshotStore = SnapshotStore(db);
  });

  tearDown(() async {
    if (provider.isOpen) {
      await provider.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SnapshotStore', () {
    /// Helper to create test document in metadata table
    Future<void> createTestDocument(String documentId) async {
      await db.insert('metadata', {
        'document_id': documentId,
        'title': 'Test Document',
        'format_version': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    /// Helper to create test snapshot data
    Uint8List createTestSnapshotData(String content) =>
        Uint8List.fromList(content.codeUnits);

    group('insertSnapshot', () {
      test('stores BLOB with metadata correctly', () async {
        await createTestDocument('doc1');

        final snapshotData = createTestSnapshotData('test snapshot content');
        final snapshotId = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: snapshotData,
          compression: 'gzip',
        );

        expect(snapshotId, greaterThan(0));

        // Verify data stored correctly
        final result = await db.rawQuery(
          'SELECT * FROM snapshots WHERE snapshot_id = ?',
          [snapshotId],
        );

        expect(result.length, equals(1));
        final snapshot = result.first;
        expect(snapshot['document_id'], equals('doc1'));
        expect(snapshot['event_sequence'], equals(1000));
        expect(snapshot['compression'], equals('gzip'));
        expect(snapshot['created_at'], isA<int>());

        final retrievedData = snapshot['snapshot_data'] as Uint8List;
        expect(retrievedData, equals(snapshotData));
      });

      test('handles foreign key constraint violation', () async {
        final snapshotData = createTestSnapshotData('test');

        expect(
          () => snapshotStore.insertSnapshot(
            documentId: 'nonexistent',
            eventSequence: 0,
            snapshotData: snapshotData,
            compression: 'none',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('stores multiple snapshots for same document', () async {
        await createTestDocument('doc1');

        final snapshot1 = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot 1'),
          compression: 'gzip',
        );

        final snapshot2 = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot 2'),
          compression: 'gzip',
        );

        expect(snapshot1, isNot(equals(snapshot2)));

        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(result.first['count'], equals(2));
      });

      test('works with real SnapshotSerializer', () async {
        await createTestDocument('doc1');

        // Create realistic snapshot using SnapshotSerializer
        final serializer = SnapshotSerializer(enableCompression: true);
        const document = Document(
          id: 'doc1',
          title: 'Test Document',
          layers: [
            Layer(id: 'layer1', name: 'Layer 1'),
            Layer(id: 'layer2', name: 'Layer 2'),
          ],
        );
        final snapshotData = serializer.serialize(document);

        final snapshotId = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: snapshotData,
          compression: 'gzip',
        );

        expect(snapshotId, greaterThan(0));

        // Verify retrieval and deserialization
        final result = await db.rawQuery(
          'SELECT snapshot_data FROM snapshots WHERE snapshot_id = ?',
          [snapshotId],
        );

        final retrievedData = result.first['snapshot_data'] as Uint8List;
        final deserialized = serializer.deserialize(retrievedData);
        expect(deserialized.id, equals('doc1'));
        expect(deserialized.title, equals('Test Document'));
        expect(deserialized.layers.length, equals(2));
        expect(deserialized.layers[0].id, equals('layer1'));
        expect(deserialized.layers[1].id, equals('layer2'));
      });

      test('stores empty BLOB', () async {
        await createTestDocument('doc1');

        final emptyData = Uint8List(0);
        final snapshotId = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 0,
          snapshotData: emptyData,
          compression: 'none',
        );

        expect(snapshotId, greaterThan(0));

        final result = await db.rawQuery(
          'SELECT snapshot_data FROM snapshots WHERE snapshot_id = ?',
          [snapshotId],
        );
        final retrieved = result.first['snapshot_data'] as Uint8List;
        expect(retrieved.length, equals(0));
      });

      test('stores large BLOB', () async {
        await createTestDocument('doc1');

        // Create 1MB BLOB
        final largeData = Uint8List(1024 * 1024);
        for (var i = 0; i < largeData.length; i++) {
          largeData[i] = i % 256;
        }

        final snapshotId = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 5000,
          snapshotData: largeData,
          compression: 'gzip',
        );

        expect(snapshotId, greaterThan(0));

        final result = await db.rawQuery(
          'SELECT snapshot_data FROM snapshots WHERE snapshot_id = ?',
          [snapshotId],
        );
        final retrieved = result.first['snapshot_data'] as Uint8List;
        expect(retrieved, equals(largeData));
      });
    });

    group('getLatestSnapshot', () {
      test('returns most recent snapshot', () async {
        await createTestDocument('doc1');

        // Insert multiple snapshots
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot at 1000'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot at 2000'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 3000,
          snapshotData: createTestSnapshotData('snapshot at 3000'),
          compression: 'none',
        );

        // Get latest snapshot at sequence 3000
        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 3000);

        expect(snapshot, isNotNull);
        expect(snapshot!['event_sequence'], equals(3000));

        final data = snapshot['snapshot_data'] as Uint8List;
        final content = String.fromCharCodes(data);
        expect(content, equals('snapshot at 3000'));
      });

      test('respects maxSequence constraint', () async {
        await createTestDocument('doc1');

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot at 1000'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot at 2000'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 3000,
          snapshotData: createTestSnapshotData('snapshot at 3000'),
          compression: 'none',
        );

        // Request snapshot at max sequence 2500 - should return snapshot at 2000
        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 2500);

        expect(snapshot, isNotNull);
        expect(snapshot!['event_sequence'], equals(2000));

        final data = snapshot['snapshot_data'] as Uint8List;
        final content = String.fromCharCodes(data);
        expect(content, equals('snapshot at 2000'));
      });

      test('returns exact match when maxSequence equals event_sequence',
          () async {
        await createTestDocument('doc1');

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot at 1000'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot at 2000'),
          compression: 'none',
        );

        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 2000);

        expect(snapshot, isNotNull);
        expect(snapshot!['event_sequence'], equals(2000));
      });

      test('returns null when no snapshot exists', () async {
        await createTestDocument('doc1');

        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 1000);

        expect(snapshot, isNull);
      });

      test('returns null when maxSequence is before all snapshots', () async {
        await createTestDocument('doc1');

        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot at 1000'),
          compression: 'none',
        );

        // Request snapshot before any exist
        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 500);

        expect(snapshot, isNull);
      });

      test('returns null for non-existent document', () async {
        final snapshot =
            await snapshotStore.getLatestSnapshot('nonexistent', 1000);

        expect(snapshot, isNull);
      });

      test('includes all metadata fields', () async {
        await createTestDocument('doc1');

        final snapshotId = await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('test'),
          compression: 'gzip',
        );

        final snapshot = await snapshotStore.getLatestSnapshot('doc1', 1000);

        expect(snapshot, isNotNull);
        expect(snapshot!['snapshot_id'], equals(snapshotId));
        expect(snapshot['event_sequence'], equals(1000));
        expect(snapshot['compression'], equals('gzip'));
        expect(snapshot['created_at'], isA<int>());
        expect(snapshot['snapshot_data'], isA<Uint8List>());
      });
    });

    group('deleteOldSnapshots', () {
      test('removes old snapshots and keeps most recent N', () async {
        await createTestDocument('doc1');

        // Insert 15 snapshots
        for (var i = 0; i < 15; i++) {
          await snapshotStore.insertSnapshot(
            documentId: 'doc1',
            eventSequence: i * 1000,
            snapshotData: createTestSnapshotData('snapshot $i'),
            compression: 'none',
          );
        }

        // Keep only 10 most recent
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 10,
        );

        expect(deleted, equals(5));

        // Verify only 10 remain
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(result.first['count'], equals(10));

        // Verify the kept snapshots are the most recent ones (5000-14000)
        final snapshots = await db.rawQuery(
          'SELECT event_sequence FROM snapshots WHERE document_id = ? ORDER BY event_sequence ASC',
          ['doc1'],
        );

        expect(snapshots.length, equals(10));
        expect(snapshots.first['event_sequence'], equals(5000));
        expect(snapshots.last['event_sequence'], equals(14000));
      });

      test('handles fewer snapshots than keepCount', () async {
        await createTestDocument('doc1');

        // Insert only 3 snapshots
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 0,
          snapshotData: createTestSnapshotData('snapshot 1'),
          compression: 'none',
        );
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot 2'),
          compression: 'none',
        );
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot 3'),
          compression: 'none',
        );

        // Try to keep 10 (more than we have)
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 10,
        );

        expect(deleted, equals(0));

        // Verify all 3 still exist
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(result.first['count'], equals(3));
      });

      test('handles exactly keepCount snapshots', () async {
        await createTestDocument('doc1');

        // Insert exactly 5 snapshots
        for (var i = 0; i < 5; i++) {
          await snapshotStore.insertSnapshot(
            documentId: 'doc1',
            eventSequence: i * 1000,
            snapshotData: createTestSnapshotData('snapshot $i'),
            compression: 'none',
          );
        }

        // Try to keep 5 (exact match)
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 5,
        );

        expect(deleted, equals(0));

        // Verify all 5 still exist
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(result.first['count'], equals(5));
      });

      test('returns 0 when no snapshots exist', () async {
        await createTestDocument('doc1');

        final deleted = await snapshotStore.deleteOldSnapshots('doc1');

        expect(deleted, equals(0));
      });

      test('keeps most recent snapshots based on event_sequence not timestamp',
          () async {
        await createTestDocument('doc1');

        // Insert snapshots in non-sequential order (simulating out-of-order insertion)
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 3000,
          snapshotData: createTestSnapshotData('snapshot 3'),
          compression: 'none',
        );
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot 1'),
          compression: 'none',
        );
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot 2'),
          compression: 'none',
        );

        // Keep only 2 most recent by event_sequence
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 2,
        );

        expect(deleted, equals(1));

        // Verify kept snapshots are 2000 and 3000 (not based on insertion order)
        final snapshots = await db.rawQuery(
          'SELECT event_sequence FROM snapshots WHERE document_id = ? ORDER BY event_sequence ASC',
          ['doc1'],
        );

        expect(snapshots.length, equals(2));
        expect(snapshots[0]['event_sequence'], equals(2000));
        expect(snapshots[1]['event_sequence'], equals(3000));
      });

      test('deletes only one snapshot when keeping N-1', () async {
        await createTestDocument('doc1');

        // Insert 5 snapshots
        for (var i = 0; i < 5; i++) {
          await snapshotStore.insertSnapshot(
            documentId: 'doc1',
            eventSequence: i * 1000,
            snapshotData: createTestSnapshotData('snapshot $i'),
            compression: 'none',
          );
        }

        // Keep 4 out of 5
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 4,
        );

        expect(deleted, equals(1));

        // Verify 4 remain (1000-4000, not 0)
        final snapshots = await db.rawQuery(
          'SELECT event_sequence FROM snapshots WHERE document_id = ? ORDER BY event_sequence ASC',
          ['doc1'],
        );

        expect(snapshots.length, equals(4));
        expect(snapshots.first['event_sequence'], equals(1000));
        expect(snapshots.last['event_sequence'], equals(4000));
      });
    });

    group('multiple documents', () {
      test('snapshots are independent per document', () async {
        await createTestDocument('doc1');
        await createTestDocument('doc2');

        // Insert snapshots for both documents
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('doc1 snapshot'),
          compression: 'none',
        );

        await snapshotStore.insertSnapshot(
          documentId: 'doc2',
          eventSequence: 500,
          snapshotData: createTestSnapshotData('doc2 snapshot'),
          compression: 'none',
        );

        // Verify doc1 snapshot
        final snapshot1 = await snapshotStore.getLatestSnapshot('doc1', 1000);
        expect(snapshot1, isNotNull);
        final data1 = snapshot1!['snapshot_data'] as Uint8List;
        expect(String.fromCharCodes(data1), equals('doc1 snapshot'));

        // Verify doc2 snapshot
        final snapshot2 = await snapshotStore.getLatestSnapshot('doc2', 500);
        expect(snapshot2, isNotNull);
        final data2 = snapshot2!['snapshot_data'] as Uint8List;
        expect(String.fromCharCodes(data2), equals('doc2 snapshot'));
      });

      test('deleteOldSnapshots affects only specified document', () async {
        await createTestDocument('doc1');
        await createTestDocument('doc2');

        // Insert 5 snapshots for each document
        for (var i = 0; i < 5; i++) {
          await snapshotStore.insertSnapshot(
            documentId: 'doc1',
            eventSequence: i * 1000,
            snapshotData: createTestSnapshotData('doc1 snapshot $i'),
            compression: 'none',
          );
          await snapshotStore.insertSnapshot(
            documentId: 'doc2',
            eventSequence: i * 1000,
            snapshotData: createTestSnapshotData('doc2 snapshot $i'),
            compression: 'none',
          );
        }

        // Delete old snapshots for doc1 only
        final deleted = await snapshotStore.deleteOldSnapshots(
          'doc1',
          keepCount: 2,
        );

        expect(deleted, equals(3));

        // Verify doc1 has 2 snapshots
        final result1 = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(result1.first['count'], equals(2));

        // Verify doc2 still has all 5 snapshots
        final result2 = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc2'],
        );
        expect(result2.first['count'], equals(5));
      });
    });

    group('cascading deletion', () {
      test('snapshots are deleted when document is deleted', () async {
        await createTestDocument('doc1');

        // Insert snapshots
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 1000,
          snapshotData: createTestSnapshotData('snapshot 1'),
          compression: 'none',
        );
        await snapshotStore.insertSnapshot(
          documentId: 'doc1',
          eventSequence: 2000,
          snapshotData: createTestSnapshotData('snapshot 2'),
          compression: 'none',
        );

        // Verify snapshots exist
        final beforeDelete = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(beforeDelete.first['count'], equals(2));

        // Delete document (should cascade to snapshots)
        await db
            .delete('metadata', where: 'document_id = ?', whereArgs: ['doc1']);

        // Verify snapshots were deleted due to CASCADE
        final afterDelete = await db.rawQuery(
          'SELECT COUNT(*) as count FROM snapshots WHERE document_id = ?',
          ['doc1'],
        );
        expect(afterDelete.first['count'], equals(0));
      });
    });
  });
}
