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
  final Map<int, Map<String, dynamic>> _snapshots = {};

  /// Set snapshot at specific sequence for testing
  void setSnapshotAtSequence(int sequence, Map<String, dynamic> data) {
    final snapshotBytes = _createSnapshotBytes(data);
    _snapshots[sequence] = {
      'event_sequence': sequence,
      'snapshot_data': snapshotBytes,
      'compression': 'gzip',
    };
  }

  /// Set corrupted snapshot at specific sequence
  void setCorruptedSnapshotAtSequence(int sequence) {
    _snapshots[sequence] = {
      'event_sequence': sequence,
      'snapshot_data': Uint8List.fromList([1, 2, 3, 4, 5]), // Invalid data
      'compression': 'gzip',
    };
  }

  @override
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int maxSequence,
  ) async {
    // Find latest snapshot <= maxSequence
    final validSequences = _snapshots.keys.where((seq) => seq <= maxSequence).toList()
      ..sort();

    if (validSequences.isEmpty) {
      return null;
    }

    return _snapshots[validSequences.last];
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

/// Helper function to create gzipped snapshot bytes for testing
Uint8List _createSnapshotBytes(Map<String, dynamic> data) {
  final jsonString = jsonEncode(data);
  final bytes = utf8.encode(jsonString);
  final compressed = gzip.encode(bytes);
  return Uint8List.fromList(compressed);
}

// Custom event type for corruption testing
// This is a simple concrete implementation for testing purposes
class _CorruptTestEvent extends EventBase {

  const _CorruptTestEvent({
    required String eventId,
    required int timestamp,
  })  : _eventId = eventId,
        _timestamp = timestamp;
  final String _eventId;
  final int _timestamp;

  @override
  String get eventId => _eventId;

  @override
  int get timestamp => _timestamp;

  @override
  String get eventType => 'CorruptEvent';

  @override
  Map<String, dynamic> toJson() => {
      'eventId': eventId,
      'timestamp': timestamp,
      'eventType': eventType,
    };
}

void main() {
  group('EventReplayer - replayToSequence() with corruption handling', () {
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

      // Handler that throws error for testing corruption
      registry.registerHandler('CorruptEvent', (state, event) {
        throw Exception('Corrupted event data');
      });

      final dispatcher = event_dispatcher.EventDispatcher(registry);
      replayer = EventReplayer(
        eventStore: eventStore,
        snapshotStore: snapshotStore,
        dispatcher: dispatcher,
      );
    });

    test('replays to specific sequence without issues', () async {
      // Arrange
      final events = [
        const CreatePathEvent(
          eventId: 'e0',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        const CreatePathEvent(
          eventId: 'e1',
          timestamp: 2000,
          pathId: 'path2',
          startAnchor: Point(x: 30, y: 40),
        ),
        const CreatePathEvent(
          eventId: 'e2',
          timestamp: 3000,
          pathId: 'path3',
          startAnchor: Point(x: 50, y: 60),
        ),
      ];
      eventStore.addEventsAtSequence(events, 0);

      // Act - replay to sequence 1
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 1,
      );

      // Assert
      expect(result.hasIssues, false);
      expect(result.skippedSequences, isEmpty);
      expect(result.warnings, isEmpty);

      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2); // Only events 0 and 1
    });

    test('skips corrupt event and continues with warning', () async {
      // Arrange - create event that will throw error
      // Use a custom event class that extends EventBase
      const corruptEvent = _CorruptTestEvent(
        eventId: 'corrupt',
        timestamp: 2000,
      );

      final events = [
        const CreatePathEvent(
          eventId: 'e0',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
        corruptEvent, // This will throw
        const CreatePathEvent(
          eventId: 'e2',
          timestamp: 3000,
          pathId: 'path2',
          startAnchor: Point(x: 30, y: 40),
        ),
      ];
      eventStore.addEventsAtSequence(events, 0);

      // Act
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 2,
      );

      // Assert
      expect(result.hasIssues, true);
      expect(result.skippedSequences, [1]); // Sequence 1 was skipped
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('sequence 1 failed'));

      // State should have path1 and path2, but not the corrupt event
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2); // Events 0 and 2 applied, 1 skipped
      expect(layers[0]['id'], 'path1');
      expect(layers[1]['id'], 'path2');
    });

    test('handles corrupted snapshot with fallback', () async {
      // Arrange
      snapshotStore.setCorruptedSnapshotAtSequence(50);

      final events = [
        const CreatePathEvent(
          eventId: 'e0',
          timestamp: 1000,
          pathId: 'path1',
          startAnchor: Point(x: 10, y: 20),
        ),
      ];
      eventStore.addEventsAtSequence(events, 51);

      // Act
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 51,
      );

      // Assert
      expect(result.hasIssues, true);
      expect(result.warnings.isNotEmpty, true);
      expect(
        result.warnings.any((w) => w.contains('Snapshot at sequence 50 corrupted')),
        true,
      );

      // Should still reconstruct state by falling back to full replay
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
      expect(layers[0]['id'], 'path1');
    });

    test('handles snapshot corruption with previous snapshot fallback', () async {
      // Arrange
      // Set valid snapshot at sequence 25
      snapshotStore.setSnapshotAtSequence(25, {
        'id': 'doc123',
        'title': 'Recovered Document',
        'layers': [
          {'type': 'path', 'id': 'path0'},
        ],
      });

      // Set corrupted snapshot at sequence 50
      snapshotStore.setCorruptedSnapshotAtSequence(50);

      // Add event at sequence 51
      const event = CreatePathEvent(
        eventId: 'e51',
        timestamp: 1000,
        pathId: 'path51',
        startAnchor: Point(x: 10, y: 20),
      );
      eventStore.addEventsAtSequence([event], 51);

      // Act - try to replay to sequence 51 (will hit corrupt snapshot at 50)
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 51,
      );

      // Assert
      expect(result.hasIssues, true);
      expect(
        result.warnings.any((w) => w.contains('Snapshot at sequence 50 corrupted')),
        true,
      );

      // Should recover using snapshot at sequence 25 and replay from there
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2); // path0 from snapshot + path51 from event
    });

    test('throws error when continueOnError is false', () async {
      // Arrange
      const corruptEvent = _CorruptTestEvent(
        eventId: 'corrupt',
        timestamp: 2000,
      );

      eventStore.addEventsAtSequence([corruptEvent], 0);

      // Act & Assert
      expect(
        () async => await replayer.replayToSequence(
          documentId: 'doc123',
          targetSequence: 0,
          continueOnError: false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('handles empty document (no events)', () async {
      // Arrange - no events added

      // Act
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 0,
      );

      // Assert
      expect(result.hasIssues, false);
      final doc = result.state as Map<String, dynamic>;
      expect(doc['id'], 'doc123');
      expect(doc['layers'], isEmpty);
    });

    test('uses snapshot when available (optimization)', () async {
      // Arrange
      snapshotStore.setSnapshotAtSequence(1000, {
        'id': 'doc123',
        'title': 'Snapshot Document',
        'layers': List.generate(
          1000,
          (i) => {'type': 'path', 'id': 'path$i'},
        ),
      });

      // Add delta event after snapshot
      const deltaEvent = CreatePathEvent(
        eventId: 'e1001',
        timestamp: 2000,
        pathId: 'path1001',
        startAnchor: Point(x: 10, y: 20),
      );
      eventStore.addEventsAtSequence([deltaEvent], 1001);

      // Act
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 1001,
      );

      // Assert
      expect(result.hasIssues, false);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1001); // 1000 from snapshot + 1 delta
    });

    test('handles snapshot at exact target sequence', () async {
      // Arrange
      snapshotStore.setSnapshotAtSequence(100, {
        'id': 'doc123',
        'title': 'Exact Snapshot',
        'layers': [
          {'type': 'path', 'id': 'path100'},
        ],
      });

      // Act
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 100,
      );

      // Assert
      expect(result.hasIssues, false);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1);
    });
  });

  group('EventReplayer - performance and edge cases', () {
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

    test('replays 1000 events in reasonable time', () async {
      // Arrange
      final events = List.generate(
        1000,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      // Act
      final stopwatch = Stopwatch()..start();
      final result = await replayer.replayToSequence(
        documentId: 'doc123',
        targetSequence: 999,
      );
      stopwatch.stop();

      // Assert
      expect(result.hasIssues, false);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1000);

      // Performance check - should be reasonable without snapshots on small datasets
      // CI runners vary significantly, but 1000 events should be < 1500ms
      // This is NOT the main performance requirement - see event_replay_performance_test.dart
      // for the critical 5k event with snapshot test (< 200ms requirement)
      print('1000 event replay took: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(1500));
    });
  });
}
