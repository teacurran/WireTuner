import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_navigator.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

// Mock implementations for testing
class MockEventStore implements EventStore {
  final Map<int, EventBase> _eventsBySequence = {};
  int _maxSequence = -1;

  void addEventAtSequence(EventBase event, int sequence) {
    _eventsBySequence[sequence] = event;
    if (sequence > _maxSequence) {
      _maxSequence = sequence;
    }
  }

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
    throw UnimplementedError();
  }

  @override
  Future<List<int>> insertEventsBatch(
    String documentId,
    List<EventBase> events,
  ) async {
    throw UnimplementedError();
  }
}

class MockSnapshotStore implements SnapshotStore {
  Map<String, dynamic>? _snapshot;

  void setSnapshot(Map<String, dynamic> snapshot) {
    _snapshot = snapshot;
  }

  void clearSnapshot() {
    _snapshot = null;
  }

  @override
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int maxSequence,
  ) async {
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
    throw UnimplementedError();
  }

  @override
  Future<int> deleteOldSnapshots(
    String documentId, {
    int keepCount = 10,
  }) async {
    throw UnimplementedError();
  }
}

Uint8List _createSnapshotBytes(Map<String, dynamic> data) {
  final jsonString = jsonEncode(data);
  final bytes = utf8.encode(jsonString);
  final compressed = gzip.encode(bytes);
  return Uint8List.fromList(compressed);
}

void main() {
  group('EventNavigator - Basic operations', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;
    late EventNavigator navigator;

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

    test('initializes with document at latest state', () async {
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
      ];
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );

      // Act
      final result = await navigator.initialize();

      // Assert
      expect(result.hasIssues, false);
      expect(navigator.currentSequence, 1);
      expect(navigator.maxSequence, 1);

      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 2);
    });

    test('handles empty document initialization', () async {
      // Arrange - no events
      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );

      // Act
      final result = await navigator.initialize();

      // Assert
      expect(result.hasIssues, false);
      expect(navigator.currentSequence, -1);
      expect(navigator.maxSequence, -1);

      final doc = result.state as Map<String, dynamic>;
      expect(doc['layers'], isEmpty);
    });

    test('canUndo returns correct values', () async {
      // Arrange
      final events = List.generate(
        5,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );
      await navigator.initialize();

      // Assert - at sequence 4, can undo
      expect(await navigator.canUndo(), true);

      // Undo to sequence 0
      await navigator.undo();
      await navigator.undo();
      await navigator.undo();
      await navigator.undo();

      // Now at sequence 0, cannot undo further
      expect(await navigator.canUndo(), false);
    });

    test('canRedo returns correct values', () async {
      // Arrange
      final events = List.generate(
        5,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );
      await navigator.initialize();

      // Assert - at latest, cannot redo
      expect(await navigator.canRedo(), false);

      // Undo once
      await navigator.undo();

      // Now can redo
      expect(await navigator.canRedo(), true);
    });
  });

  group('EventNavigator - Undo/Redo operations', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;
    late EventNavigator navigator;

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

      // Create events
      final events = List.generate(
        10,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );
    });

    test('undo navigates to previous sequence', () async {
      // Arrange
      await navigator.initialize();
      expect(navigator.currentSequence, 9);

      // Act
      final result = await navigator.undo();

      // Assert
      expect(navigator.currentSequence, 8);
      expect(result.hasIssues, false);

      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 9); // Sequences 0-8
    });

    test('redo navigates to next sequence', () async {
      // Arrange
      await navigator.initialize();
      await navigator.undo();
      expect(navigator.currentSequence, 8);

      // Act
      final result = await navigator.redo();

      // Assert
      expect(navigator.currentSequence, 9);
      expect(result.hasIssues, false);

      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 10);
    });

    test('multiple undo operations work correctly', () async {
      // Arrange
      await navigator.initialize();

      // Act - undo 5 times
      for (var i = 0; i < 5; i++) {
        await navigator.undo();
      }

      // Assert
      expect(navigator.currentSequence, 4);

      final result =
          await navigator.navigateToSequence(navigator.currentSequence);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 5);
    });

    test('undo then redo sequence works correctly', () async {
      // Arrange
      await navigator.initialize();
      final originalSequence = navigator.currentSequence;

      // Act - undo 3 times, then redo 3 times
      await navigator.undo();
      await navigator.undo();
      await navigator.undo();

      await navigator.redo();
      await navigator.redo();
      await navigator.redo();

      // Assert - back at original sequence
      expect(navigator.currentSequence, originalSequence);
    });

    test('throws error when undoing at sequence 0', () async {
      // Arrange
      await navigator.initialize();

      // Undo to sequence 0 (we start at 9, so 9 undos gets us to 0)
      for (var i = 0; i < 9; i++) {
        await navigator.undo();
      }

      // Verify we're at sequence 0
      expect(navigator.currentSequence, 0);

      // Act & Assert - expectLater for async matchers
      await expectLater(navigator.undo(), throwsStateError);
    });

    test('throws error when redoing at latest sequence', () async {
      // Arrange
      await navigator.initialize();

      // Act & Assert - already at latest, use expectLater for async matchers
      await expectLater(navigator.redo(), throwsStateError);
    });
  });

  group('EventNavigator - Cache behavior', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;
    late EventNavigator navigator;

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

      // Create 20 events
      final events = List.generate(
        20,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );
    });

    test('caches states during navigation', () async {
      // Arrange
      await navigator.initialize();

      // Act - navigate to sequence 10
      await navigator.navigateToSequence(10);

      // Assert - cache should contain sequence 10
      final stats = navigator.getCacheStats();
      expect(stats['sequences'], contains(10));
    });

    test('cache hit returns same state', () async {
      // Arrange
      await navigator.initialize();
      await navigator.navigateToSequence(10);

      // Act - navigate to 10 again (cache hit)
      final result = await navigator.navigateToSequence(10);

      // Assert
      expect(result.hasIssues, false);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 11); // Sequences 0-10
    });

    test('LRU eviction works correctly', () async {
      // Arrange
      await navigator.initialize();

      // Act - navigate to 15 different sequences (more than cache capacity of 10)
      for (var i = 0; i < 15; i++) {
        await navigator.navigateToSequence(i);
      }

      // Assert - cache should have at most 10 entries
      final stats = navigator.getCacheStats();
      expect(stats['size'], lessThanOrEqualTo(10));

      // Recent sequences should be cached
      expect(stats['sequences'], contains(14));
      expect(stats['sequences'], contains(13));

      // Oldest sequences should be evicted
      expect(stats['sequences'], isNot(contains(0)));
      expect(stats['sequences'], isNot(contains(1)));
    });

    test('repeated undo/redo uses cache', () async {
      // Arrange
      await navigator.initialize();

      // Act - undo 3 times
      await navigator.undo();
      await navigator.undo();
      await navigator.undo();

      // Cache should have sequences 16, 17, 18
      var stats = navigator.getCacheStats();
      expect(stats['sequences'], contains(16));

      // Redo 3 times - should hit cache
      await navigator.redo();
      await navigator.redo();
      await navigator.redo();

      // Should still have cached entries
      stats = navigator.getCacheStats();
      expect(stats['size'], greaterThan(0));
    });

    test('clearCache removes all cached states', () async {
      // Arrange
      await navigator.initialize();
      await navigator.navigateToSequence(10);
      await navigator.navigateToSequence(5);

      // Act
      navigator.clearCache();

      // Assert
      final stats = navigator.getCacheStats();
      expect(stats['size'], 0);
      expect(stats['sequences'], isEmpty);
    });

    test('cache stats returns correct information', () async {
      // Arrange
      await navigator.initialize();
      await navigator.navigateToSequence(10);
      await navigator.navigateToSequence(5);

      // Act
      final stats = navigator.getCacheStats();

      // Assert
      expect(stats['size'], greaterThan(0));
      expect(stats['capacity'], 10);
      expect(stats['sequences'], isList);
      expect(stats['currentSequence'], 5);
      expect(stats['maxSequence'], 19);
    });
  });

  group('EventNavigator - Arbitrary sequence navigation', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;
    late EventNavigator navigator;

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

      final events = List.generate(
        100,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );
    });

    test('navigates to arbitrary sequence correctly', () async {
      // Arrange
      await navigator.initialize();

      // Act
      final result = await navigator.navigateToSequence(42);

      // Assert
      expect(navigator.currentSequence, 42);
      expect(result.hasIssues, false);

      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 43); // Sequences 0-42
    });

    test('throws error for negative sequence', () async {
      // Arrange
      await navigator.initialize();

      // Act & Assert - use expectLater for async matchers
      await expectLater(
        navigator.navigateToSequence(-1),
        throwsArgumentError,
      );
    });

    test('throws error for sequence beyond max', () async {
      // Arrange
      await navigator.initialize();

      // Act & Assert - use expectLater for async matchers
      await expectLater(
        navigator.navigateToSequence(1000),
        throwsArgumentError,
      );
    });

    test('navigates to sequence 0', () async {
      // Arrange
      await navigator.initialize();

      // Act
      final result = await navigator.navigateToSequence(0);

      // Assert
      expect(navigator.currentSequence, 0);
      final doc = result.state as Map<String, dynamic>;
      final layers = doc['layers'] as List;
      expect(layers.length, 1); // Only event 0
    });

    test('navigates between non-adjacent sequences', () async {
      // Arrange
      await navigator.initialize();

      // Act - jump around
      await navigator.navigateToSequence(10);
      await navigator.navigateToSequence(50);
      await navigator.navigateToSequence(25);

      // Assert
      expect(navigator.currentSequence, 25);
    });
  });

  group('EventNavigator - Edge cases and error handling', () {
    late MockEventStore eventStore;
    late MockSnapshotStore snapshotStore;
    late EventReplayer replayer;
    late EventNavigator navigator;

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

    test('handles document with single event', () async {
      // Arrange
      const event = CreatePathEvent(
        eventId: 'e0',
        timestamp: 1000,
        pathId: 'path0',
        startAnchor: Point(x: 0, y: 0),
      );
      eventStore.addEventsAtSequence([event], 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );

      // Act
      await navigator.initialize();

      // Assert
      expect(navigator.currentSequence, 0);
      expect(await navigator.canUndo(), false);
      expect(await navigator.canRedo(), false);
    });

    test('cache immutability - modifying returned state does not affect cache',
        () async {
      // Arrange
      final events = List.generate(
        5,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: 1000 + i,
          pathId: 'path$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );
      eventStore.addEventsAtSequence(events, 0);

      navigator = EventNavigator(
        documentId: 'doc123',
        replayer: replayer,
        eventStore: eventStore,
      );

      // Act
      final result1 = await navigator.navigateToSequence(2);
      final doc1 = result1.state as Map<String, dynamic>;
      final layers1 = doc1['layers'] as List;

      // Modify returned state
      layers1.add({'type': 'path', 'id': 'hacked'});

      // Navigate to same sequence again
      final result2 = await navigator.navigateToSequence(2);
      final doc2 = result2.state as Map<String, dynamic>;
      final layers2 = doc2['layers'] as List;

      // Assert - should not have the modification
      expect(layers2.length, 3); // Not 4
      expect(layers2.any((l) => l['id'] == 'hacked'), false);
    });
  });
}
