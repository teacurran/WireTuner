import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

// Mock implementations for testing
class MockEventStore implements EventStore {
  final Map<int, EventBase> _eventsBySequence = {};
  int _maxSequence = -1;

  /// Add mock event at specific sequence
  void addEventAtSequence(EventBase event, int sequence) {
    _eventsBySequence[sequence] = event;
    if (sequence > _maxSequence) {
      _maxSequence = sequence;
    }
  }

  /// Add mock events starting at sequence 0
  void addEvents(List<EventBase> events) {
    for (var i = 0; i < events.length; i++) {
      addEventAtSequence(events[i], i);
    }
  }

  /// Add events at specific starting sequence
  void addEventsAtSequence(List<EventBase> events, int startSequence) {
    for (var i = 0; i < events.length; i++) {
      addEventAtSequence(events[i], startSequence + i);
    }
  }

  @override
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
  }) async {
    // Filter events by sequence range
    final sequences = _eventsBySequence.keys.toList()..sort();
    final filteredSequences = sequences.where((seq) {
      if (toSeq == null) {
        return seq >= fromSeq;
      }
      return seq >= fromSeq && seq <= toSeq;
    });

    return filteredSequences.map((seq) => _eventsBySequence[seq]!).toList();
  }

  @override
  Future<int> getMaxSequence(String documentId) async => _maxSequence;

  @override
  Future<int> insertEvent(String documentId, EventBase event) async {
    throw UnimplementedError('insertEvent not needed for replay tests');
  }

  @override
  Future<List<int>> insertEventsBatch(
    String documentId,
    List<EventBase> events,
  ) async {
    throw UnimplementedError('insertEventsBatch not needed for replay tests');
  }
}

class MockSnapshotStore implements SnapshotStore {
  Map<String, dynamic>? _snapshot;

  /// Set snapshot for testing
  void setSnapshot(Map<String, dynamic> snapshot) {
    _snapshot = snapshot;
  }

  /// Clear snapshot
  void clearSnapshot() {
    _snapshot = null;
  }

  @override
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int maxSequence,
  ) async {
    // Check if snapshot sequence is within maxSequence
    if (_snapshot != null) {
      final snapshotSeq = _snapshot!['event_sequence'] as int;
      if (snapshotSeq <= maxSequence) {
        return _snapshot;
      }
    }
    return null;
  }

  @override
  Future<int> insertSnapshot({
    required String documentId,
    required int eventSequence,
    required Uint8List snapshotData,
    required String compression,
  }) async {
    throw UnimplementedError('insertSnapshot not needed for replay tests');
  }

  @override
  Future<int> deleteOldSnapshots(
    String documentId, {
    int keepCount = 10,
  }) async {
    throw UnimplementedError('deleteOldSnapshots not needed for replay tests');
  }
}

void main() {
  group('EventReplayer - replay() method', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;

    setUp(() {
      eventStore = MockEventStore();
      snapshotStore = MockSnapshotStore();

      // Create dispatcher with simple test handlers
      final registry = EventHandlerRegistry();
      registry.registerHandler('CreatePathEvent', (state, event) {
        final map = state as Map<String, dynamic>;
        final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
        final pathEvent = event as CreatePathEvent;
        layers.add({
          'type': 'path',
          'id': pathEvent.pathId,
          'anchors': [pathEvent.startAnchor.toJson()],
        });
        return {...map, 'layers': layers};
      });

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
      );
    });

    test('returns empty document when no events exist', () async {
      // Arrange: no events added to store

      // Act
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null,
      );

      // Assert
      expect(result, isA<Map<String, dynamic>>());
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      expect(doc['title'], 'Empty Document');
      expect(doc['layers'], isEmpty);
    });

    test('replays events from sequence 0 to latest', () async {
      // Arrange
      const event1 = CreatePathEvent(
        eventId: 'e1',
        timestamp: 1000,
        pathId: 'path1',
        startAnchor: Point(x: 10, y: 20),
      );
      const event2 = AddAnchorEvent(
        eventId: 'e2',
        timestamp: 2000,
        pathId: 'path1',
        position: Point(x: 30, y: 40),
      );
      eventStore.addEvents([event1, event2]);

      // Act
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null,
      );

      // Assert
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
      final path = layers[0] as Map<String, dynamic>;
      expect(path['id'], 'path1');
      expect(path['anchors'], hasLength(2));
    });

    test('replays events in specified range (fromSeq to toSeq)', () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const AddAnchorEvent(
          eventId: 'e2',
          timestamp: 2000,
          pathId: 'path1',
          position: Point(x: 30, y: 40),
        ),
        const AddAnchorEvent(
          eventId: 'e3',
          timestamp: 3000,
          pathId: 'path1',
          position: Point(x: 50, y: 60),
        ),
      ];
      eventStore.addEvents(events);

      // Act - replay only first 2 events (sequence 0 to 1)
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: 1,
      );

      // Assert
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      final path = layers[0] as Map<String, dynamic>;
      // Should have 2 anchors (from events 0 and 1), not 3
      expect(path['anchors'], hasLength(2));
    });

    test('handles null toSeq (replays to end)', () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const AddAnchorEvent(
          eventId: 'e2',
          timestamp: 2000,
          pathId: 'path1',
          position: Point(x: 30, y: 40),
        ),
      ];
      eventStore.addEvents(events);

      // Act
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null, // null = replay all
      );

      // Assert
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      final path = layers[0] as Map<String, dynamic>;
      expect(path['anchors'], hasLength(2));
    });

    test('applies events in correct order', () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const CreatePathEvent(
          eventId: 'e2',
          timestamp: 2000,
          pathId: 'path2',
          startAnchor: Point(x: 100, y: 200),
        ),
      ];
      eventStore.addEvents(events);

      // Act
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null,
      );

      // Assert - verify both paths were created in order
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2);
      expect(layers[0]['id'], 'path1');
      expect(layers[1]['id'], 'path2');
    });

    test('replays from intermediate sequence', () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const CreatePathEvent(
          eventId: 'e2',
          timestamp: 2000,
          pathId: 'path2',
          startAnchor: Point(x: 100, y: 200),
        ),
        const CreatePathEvent(
          eventId: 'e3',
          timestamp: 3000,
          pathId: 'path3',
          startAnchor: Point(x: 200, y: 300),
        ),
      ];
      eventStore.addEvents(events);

      // Act - replay from sequence 1 onwards (skip first event)
      final result = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 1,
        toSequence: null,
      );

      // Assert - should only have path2 and path3, not path1
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2);
      expect(layers[0]['id'], 'path2');
      expect(layers[1]['id'], 'path3');
    });
  });

  group('EventReplayer - replayFromSnapshot() method', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;

    setUp(() {
      eventStore = MockEventStore();
      snapshotStore = MockSnapshotStore();

      // Create dispatcher with test handlers
      final registry = EventHandlerRegistry();
      registry.registerHandler('CreatePathEvent', (state, event) {
        final map = state as Map<String, dynamic>;
        final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
        final pathEvent = event as CreatePathEvent;
        layers.add({
          'type': 'path',
          'id': pathEvent.pathId,
          'anchors': [pathEvent.startAnchor.toJson()],
        });
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

    test('falls back to full replay when no snapshot exists', () async {
      // Arrange
      const event = CreatePathEvent(
        eventId: 'e1',
        timestamp: 1000,
        pathId: 'path1',
        startAnchor: Point(x: 10, y: 20),
      );
      eventStore.addEvents([event]);
      snapshotStore.clearSnapshot();

      // Act
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 0,
      );

      // Assert - should have replayed from scratch
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
      expect(layers[0]['id'], 'path1');
    });

    test('loads snapshot and replays delta events', () async {
      // Arrange
      // Snapshot at sequence 1000 with 5 paths
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': [
          {'type': 'path', 'id': 'path1'},
          {'type': 'path', 'id': 'path2'},
          {'type': 'path', 'id': 'path3'},
          {'type': 'path', 'id': 'path4'},
          {'type': 'path', 'id': 'path5'},
        ],
      };

      // Create snapshot bytes (JSON encoded, gzipped)
      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 1000,
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // Add delta events (sequence 1001-1002)
      const deltaEvent1 = CreatePathEvent(
        eventId: 'e1001',
        timestamp: 2000,
        pathId: 'path6',
        startAnchor: Point(x: 10, y: 20),
      );
      const deltaEvent2 = CreatePathEvent(
        eventId: 'e1002',
        timestamp: 3000,
        pathId: 'path7',
        startAnchor: Point(x: 30, y: 40),
      );
      eventStore.addEventsAtSequence([deltaEvent1, deltaEvent2], 1001);

      // Act
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 1002,
      );

      // Assert - should have 5 paths from snapshot + 2 from delta
      final doc = result as Map<String, dynamic>;
      expect(doc['title'], 'Test Document');
      final layers = doc['layers'] as List;
      expect(layers.length, 7); // 5 from snapshot + 2 delta
      expect(layers[5]['id'], 'path6');
      expect(layers[6]['id'], 'path7');
    });

    test('handles snapshot at target sequence (no delta)', () async {
      // Arrange
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': [
          {'type': 'path', 'id': 'path1'},
        ],
      };

      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 100,
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // Act - replay to same sequence as snapshot
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 100,
      );

      // Assert - should return snapshot state without replaying any events
      final doc = result as Map<String, dynamic>;
      expect(doc['title'], 'Test Document');
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
    });

    test('handles snapshot beyond target (no delta)', () async {
      // Arrange
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': [
          {'type': 'path', 'id': 'path1'},
        ],
      };

      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 200,
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // Act - replay to sequence before snapshot (should return null from getLatestSnapshot)
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 100,
      );

      // Assert - should fall back to full replay with empty document
      final doc = result as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      expect(doc['title'], 'Empty Document');
    });

    test('queries correct event range (snapshot+1 to maxSeq)', () async {
      // Arrange
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': [
          {'type': 'path', 'id': 'path1'},
        ],
      };

      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 50,
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // Add events at sequences 51 and 52
      const event51 = CreatePathEvent(
        eventId: 'e51',
        timestamp: 2000,
        pathId: 'path2',
        startAnchor: Point(x: 10, y: 20),
      );
      const event52 = CreatePathEvent(
        eventId: 'e52',
        timestamp: 3000,
        pathId: 'path3',
        startAnchor: Point(x: 30, y: 40),
      );
      eventStore.addEventsAtSequence([event51, event52], 51);

      // Act - replay from snapshot (seq 50) to seq 51 (should only get 1 delta event)
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 51,
      );

      // Assert - should have 1 path from snapshot + 1 from delta (not 2)
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2); // 1 from snapshot + 1 delta (only event51)
      expect(layers[1]['id'], 'path2');
    });

    test('handles empty delta events', () async {
      // Arrange
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': [
          {'type': 'path', 'id': 'path1'},
        ],
      };

      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 50,
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // No events added (empty delta)

      // Act
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 100,
      );

      // Assert - should return snapshot state
      final doc = result as Map<String, dynamic>;
      expect(doc['title'], 'Test Document');
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
    });
  });

  group('EventReplayer - Integration scenarios', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;

    setUp(() {
      eventStore = MockEventStore();
      snapshotStore = MockSnapshotStore();

      final registry = EventHandlerRegistry();
      registry.registerHandler('CreatePathEvent', (state, event) {
        final map = state as Map<String, dynamic>;
        final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
        final pathEvent = event as CreatePathEvent;
        layers.add({
          'type': 'path',
          'id': pathEvent.pathId,
          'anchors': [pathEvent.startAnchor.toJson()],
        });
        return {...map, 'layers': layers};
      });

      final dispatcher = event_dispatcher.EventDispatcher(registry);
      replayer = EventReplayer(
        eventStore: eventStore,
        snapshotStore: snapshotStore,
        dispatcher: dispatcher,
      );
    });

    test('deterministic replay - multiple replays produce identical results',
        () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const CreatePathEvent(
          eventId: 'e2',
          timestamp: 2000,
          pathId: 'path2',
          startAnchor: Point(x: 30, y: 40),
        ),
      ];
      eventStore.addEvents(events);

      // Act - replay twice
      final result1 = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null,
      );
      final result2 = await replayer.replay(
        documentId: 'doc123',
        fromSequence: 0,
        toSequence: null,
      );

      // Assert - results should be identical
      final doc1 = result1 as Map<String, dynamic>;
      final doc2 = result2 as Map<String, dynamic>;

      expect(doc1['id'], doc2['id']);
      expect(doc1['title'], doc2['title']);

      final layers1 = doc1['layers'] as List;
      final layers2 = doc2['layers'] as List;
      expect(layers1.length, layers2.length);

      for (var i = 0; i < layers1.length; i++) {
        expect(layers1[i]['id'], layers2[i]['id']);
      }
    });

    test('full document lifecycle - create events, snapshot, replay', () async {
      // Arrange - simulate creating 100 events (sequences 0-99)
      final events = List.generate(
        100,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEvents(events); // Adds at sequences 0-99

      // Create snapshot at event 50
      final snapshotData = {
        'id': 'doc123',
        'title': 'Test Document',
        'layers': List.generate(
          50,
          (i) => {
            'type': 'path',
            'id': 'path$i',
            'anchors': [
              {'x': i.toDouble(), 'y': i.toDouble()},
            ],
          },
        ),
      };

      final snapshotBytes = _createSnapshotBytes(snapshotData);
      snapshotStore.setSnapshot({
        'event_sequence': 49, // After 50 events (0-49)
        'snapshot_data': snapshotBytes,
        'compression': 'gzip',
      });

      // Act - replay from snapshot to sequence 99
      final result = await replayer.replayFromSnapshot(
        documentId: 'doc123',
        maxSequence: 99,
      );

      // Assert - should have all 100 paths (50 from snapshot + 50 delta)
      final doc = result as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 100);

      // Verify first path from snapshot
      expect(layers[0]['id'], 'path0');

      // Verify last path from delta replay
      expect(layers[99]['id'], 'path99');
    });
  });
}

/// Helper function to create gzipped snapshot bytes for testing
Uint8List _createSnapshotBytes(Map<String, dynamic> data) {
  // Serialize to JSON
  final jsonString = jsonEncode(data);

  // Convert to UTF-8 bytes
  final bytes = utf8.encode(jsonString);

  // Compress with gzip
  final compressed = gzip.encode(bytes);

  return Uint8List.fromList(compressed);
}
