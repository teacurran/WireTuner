import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

/// Integration tests for EventReplayer with real database and stores.
///
/// These tests verify that EventReplayer works correctly with actual SQLite
/// databases, EventStore, SnapshotStore, and EventDispatcher instances.
void main() {
  // Initialize sqflite_ffi for desktop testing
  sqfliteFfiInit();

  group('EventReplayer - Integration with real stores', () {
    late Database db;
    late EventStore eventStore;
    late SnapshotStore snapshotStore;
    late EventReplayer replayer;
    late SnapshotSerializer serializer;

    setUp(() async {
      // Create in-memory database
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create schema - events table
      await db.execute('''
        CREATE TABLE events (
          event_id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id TEXT NOT NULL,
          event_sequence INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          event_payload TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          user_id TEXT,
          UNIQUE(document_id, event_sequence)
        )
      ''');

      // Create schema - snapshots table
      await db.execute('''
        CREATE TABLE snapshots (
          snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id TEXT NOT NULL,
          event_sequence INTEGER NOT NULL,
          snapshot_data BLOB NOT NULL,
          created_at INTEGER NOT NULL,
          compression TEXT NOT NULL
        )
      ''');

      // Create stores
      eventStore = EventStore(db);
      snapshotStore = SnapshotStore(db);
      serializer = SnapshotSerializer(enableCompression: true);

      // Create dispatcher with test handlers
      final registry = EventHandlerRegistry();

      // Register CreatePathEvent handler
      registry.registerHandler('CreatePathEvent', (state, event) {
        final map = state as Map<String, dynamic>;
        final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
        final pathEvent = event as CreatePathEvent;
        layers.add({
          'type': 'path',
          'id': pathEvent.pathId,
          'anchors': [pathEvent.startAnchor.toJson()],
          'fillColor': pathEvent.fillColor,
          'strokeColor': pathEvent.strokeColor,
        });
        return {...map, 'layers': layers};
      });

      // Register AddAnchorEvent handler
      registry.registerHandler('AddAnchorEvent', (state, event) {
        final map = state as Map<String, dynamic>;
        final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
        final anchorEvent = event as AddAnchorEvent;

        // Find path and add anchor
        final pathIndex =
            layers.indexWhere((layer) => layer['id'] == anchorEvent.pathId);
        if (pathIndex != -1) {
          final path = Map<String, dynamic>.from(layers[pathIndex]);
          final anchors =
              List<Map<String, dynamic>>.from(path['anchors'] as List);
          anchors.add(anchorEvent.position.toJson());
          path['anchors'] = anchors;
          layers[pathIndex] = path;
        }

        return {...map, 'layers': layers};
      });

      final dispatcher = event_dispatcher.EventDispatcher(registry);
      replayer = EventReplayer(
        eventStore: eventStore,
        snapshotStore: snapshotStore,
        dispatcher: dispatcher,
        enableCompression: true,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Integration: Replay document with 100 events (no snapshot)',
        () async {
      // Arrange - Insert 100 events into database
      for (var i = 0; i < 100; i++) {
        final event = CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble() * 2),
        );
        await eventStore.insertEvent('doc123', event);
      }

      // Act - Replay all events
      final maxSeq = await eventStore.getMaxSequence('doc123');
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: maxSeq,
      );

      // Assert - Verify all 100 paths were created
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      final layers = doc['layers'] as List;
      expect(layers.length, 100);

      // Verify first and last paths
      expect(layers[0]['id'], 'path0');
      expect(layers[99]['id'], 'path99');

      // Verify anchor positions
      final firstPath = layers[0] as Map<String, dynamic>;
      final firstAnchors = firstPath['anchors'] as List;
      expect(firstAnchors[0]['x'], 0.0);
      expect(firstAnchors[0]['y'], 0.0);
    });

    test('Integration: Replay document with 2000 events + snapshot at 1000',
        () async {
      // Arrange - Insert 2000 events
      for (var i = 0; i < 2000; i++) {
        final event = CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble() * 2),
        );
        await eventStore.insertEvent('doc123', event);
      }

      // Create snapshot at sequence 999 (after 1000 events)
      final snapshotDoc = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': List.generate(
          1000,
          (i) => {
            'type': 'path',
            'id': 'path$i',
            'anchors': [
              {'x': i.toDouble(), 'y': i.toDouble() * 2}
            ],
          },
        ),
      };

      final snapshotBytes = serializer.serialize(snapshotDoc);
      await snapshotStore.insertSnapshot(
        documentId: 'doc123',
        eventSequence: 999,
        snapshotData: snapshotBytes,
        compression: 'gzip',
      );

      // Act - Replay from snapshot
      final maxSeq = await eventStore.getMaxSequence('doc123');
      expect(maxSeq, 1999); // 0-1999 = 2000 events

      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: maxSeq,
      );

      // Assert - Should have all 2000 paths
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2000);

      // Verify paths from snapshot
      expect(layers[0]['id'], 'path0');
      expect(layers[999]['id'], 'path999');

      // Verify paths from delta replay
      expect(layers[1000]['id'], 'path1000');
      expect(layers[1999]['id'], 'path1999');
    });

    test('Integration: Replay to intermediate sequence (undo scenario)',
        () async {
      // Arrange - Insert 1000 events
      for (var i = 0; i < 1000; i++) {
        final event = CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble() * 2),
        );
        await eventStore.insertEvent('doc123', event);
      }

      // Create snapshot at sequence 499 (after 500 events)
      final snapshotDoc = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': List.generate(
          500,
          (i) => {
            'type': 'path',
            'id': 'path$i',
            'anchors': [
              {'x': i.toDouble(), 'y': i.toDouble() * 2}
            ],
          },
        ),
      };

      final snapshotBytes = serializer.serialize(snapshotDoc);
      await snapshotStore.insertSnapshot(
        documentId: 'doc123',
        eventSequence: 499,
        snapshotData: snapshotBytes,
        compression: 'gzip',
      );

      // Act - Replay to sequence 749 (simulate undo to this point)
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 749,
      );

      // Assert - Should have 750 paths (sequences 0-749)
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 750);

      // Verify we got paths 0-749, not 0-999
      expect(layers[0]['id'], 'path0');
      expect(layers[749]['id'], 'path749');
    });

    test('Integration: Replay empty document (no events, no snapshots)',
        () async {
      // Arrange - no events or snapshots

      // Act - Try to replay non-existent document
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 100,
      );

      // Assert - Should return empty placeholder document
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      expect(doc['title'], 'Empty Document');
      final layers = doc['layers'] as List;
      expect(layers, isEmpty);
    });

    test('Integration: Multiple replay calls produce identical results',
        () async {
      // Arrange - Insert 50 events
      for (var i = 0; i < 50; i++) {
        final event = CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble() * 2),
        );
        await eventStore.insertEvent('doc123', event);
      }

      // Act - Replay twice
      final maxSeq = await eventStore.getMaxSequence('doc123');

      final result1 = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: maxSeq,
      );

      final result2 = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: maxSeq,
      );

      // Assert - Results should be identical
      final doc1 = result1 as Map<String, dynamic>;
      final doc2 = result2 as Map<String, dynamic>;

      expect(doc1['id'], doc2['id']);
      expect(doc1['title'], doc2['title']);

      final layers1 = doc1['layers'] as List;
      final layers2 = doc2['layers'] as List;

      expect(layers1.length, layers2.length);
      expect(layers1.length, 50);

      for (var i = 0; i < layers1.length; i++) {
        expect(layers1[i]['id'], layers2[i]['id']);
        expect(layers1[i]['type'], layers2[i]['type']);
      }
    });

    test('Integration: Replay with mixed event types (CreatePath + AddAnchor)',
        () async {
      // Arrange - Create path with anchors
      await eventStore.insertEvent(
        'doc123',
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path1',
          startAnchor: const Point(x: 10, y: 20),
          strokeColor: '#000000',
        ),
      );

      await eventStore.insertEvent(
        'doc123',
        AddAnchorEvent(
          eventId: 'e2',
          timestamp: DateTime.now().millisecondsSinceEpoch + 1,
          pathId: 'path1',
          position: const Point(x: 30, y: 40),
        ),
      );

      await eventStore.insertEvent(
        'doc123',
        AddAnchorEvent(
          eventId: 'e3',
          timestamp: DateTime.now().millisecondsSinceEpoch + 2,
          pathId: 'path1',
          position: const Point(x: 50, y: 60),
        ),
      );

      // Act - Replay
      final maxSeq = await eventStore.getMaxSequence('doc123');
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: maxSeq,
      );

      // Assert - Verify path with 3 anchors
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1);

      final path = layers[0] as Map<String, dynamic>;
      expect(path['id'], 'path1');
      expect(path['strokeColor'], '#000000');

      final anchors = path['anchors'] as List;
      expect(anchors.length, 3);
      expect(anchors[0]['x'], 10.0);
      expect(anchors[0]['y'], 20.0);
      expect(anchors[1]['x'], 30.0);
      expect(anchors[1]['y'], 40.0);
      expect(anchors[2]['x'], 50.0);
      expect(anchors[2]['y'], 60.0);
    });

    test('Integration: Snapshot compression reduces storage size', () async {
      // Arrange - Create large document state
      final largeDoc = {
        'id': 'doc123',
        'title': 'Large Document',
        'layers': List.generate(
          1000,
          (i) => {
            'type': 'path',
            'id': 'path$i',
            'anchors': List.generate(
              10,
              (j) => {'x': (i * 10 + j).toDouble(), 'y': (i * 10 + j).toDouble()},
            ),
          },
        ),
      };

      // Act - Serialize with and without compression
      final compressedSerializer = SnapshotSerializer(enableCompression: true);
      final uncompressedSerializer = SnapshotSerializer(enableCompression: false);

      final compressedBytes = compressedSerializer.serialize(largeDoc);
      final uncompressedBytes = uncompressedSerializer.serialize(largeDoc);

      // Assert - Compressed should be significantly smaller
      expect(compressedBytes.length, lessThan(uncompressedBytes.length));

      // Typically expect at least 50% compression for JSON data
      final compressionRatio = compressedBytes.length / uncompressedBytes.length;
      expect(compressionRatio, lessThan(0.5));

      // Verify both can be deserialized correctly
      final decompressedDoc = compressedSerializer.deserialize(compressedBytes);
      final doc = decompressedDoc as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      expect(doc['title'], 'Large Document');
      final layers = doc['layers'] as List;
      expect(layers.length, 1000);
    });
  });
}
