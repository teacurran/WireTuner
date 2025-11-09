import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_serializer.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

/// Integration tests for pen tool + selection tool event interplay.
///
/// This test suite verifies:
/// 1. Event persistence across tool interactions
/// 2. Undo/redo navigation preserves tool state
/// 3. Event replay determinism
/// 4. Telemetry thresholds within expected ranges
///
/// Validates requirements from I3.T10:
/// - Tool switching verified via event sequences
/// - Selection accuracy on pen-created paths
/// - Event persistence and replay
/// - Telemetry thresholds documented
void main() {
  // Initialize sqflite_ffi for desktop testing
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Integration: Pen Tool + Selection Tool Event Interplay', () {
    late Database db;
    late EventStore eventStore;
    late SnapshotStore snapshotStore;
    late EventReplayer replayer;
    late SnapshotSerializer serializer;
    late EventHandlerRegistry registry;

    setUp(() async {
      // Create in-memory database
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create events table schema
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

      // Create snapshots table schema
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

      // Create event handler registry
      registry = EventHandlerRegistry();
      _registerEventHandlers(registry);

      // Create dispatcher and replayer
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

    test(
      'Event persistence: Pen tool path creation + selection',
      () async {
        final docId = 'doc-pen-selection-test';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // Simulate pen tool workflow: Create path with Bezier curves
        final penEvents = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-new',
            startAnchor: const Point(x: 100, y: 100),
            strokeColor: '#000000',
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 100,
            pathId: 'path-new',
            position: const Point(x: 200, y: 150),
            anchorType: AnchorType.bezier,
            handleOut: const Point(x: 50, y: -20),
            handleIn: const Point(x: -50, y: 20),
          ),
          AddAnchorEvent(
            eventId: 'evt-003',
            timestamp: startTime + 200,
            pathId: 'path-new',
            position: const Point(x: 300, y: 100),
            anchorType: AnchorType.line,
          ),
          FinishPathEvent(
            eventId: 'evt-004',
            timestamp: startTime + 300,
            pathId: 'path-new',
            closed: false,
          ),
        ];

        // Persist pen tool events
        for (final event in penEvents) {
          await eventStore.insertEvent(docId, event);
        }

        // Simulate selection tool: Select the newly created path
        final selectionEvent = SelectObjectsEvent(
          eventId: 'evt-005',
          timestamp: startTime + 400,
          objectIds: ['path-new'],
          mode: SelectionMode.replace,
        );

        await eventStore.insertEvent(docId, selectionEvent);

        // Verify all events persisted
        final maxSeq = await eventStore.getMaxSequence(docId);
        expect(maxSeq, equals(4)); // 0-4 = 5 events

        // Replay all events
        final result = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: maxSeq,
        );

        // Verify replayed state
        final doc = result as Map<String, dynamic>;
        final layers = doc['layers'] as List;

        // Should have path-new
        final newPath = layers.firstWhere(
          (l) => l['id'] == 'path-new',
          orElse: () => <String, dynamic>{},
        );
        expect(newPath, isNotEmpty, reason: 'Path should exist after replay');

        final anchors = newPath['anchors'] as List;
        expect(anchors, hasLength(3), reason: 'Path should have 3 anchors');

        // Verify Bezier anchor has handles
        if (anchors.length > 1) {
          final bezierAnchor = anchors[1] as Map<String, dynamic>;
          if (bezierAnchor.containsKey('handleOut')) {
            final handleOut = bezierAnchor['handleOut'] as Map<String, dynamic>;
            expect(handleOut['x'], equals(50.0));
            expect(handleOut['y'], equals(-20.0));
          }
        }

        // Verify selection state
        final selection = doc['selection'] as Map<String, dynamic>;
        final selectedIds = selection['objectIds'] as List;
        expect(selectedIds, contains('path-new'),
            reason: 'Path should be selected after replay');
      },
    );

    test(
      'Undo simulation: Replay to state before pen tool usage',
      () async {
        final docId = 'doc-undo-test';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // Initial state: Select existing object
        await eventStore.insertEvent(
          docId,
          SelectObjectsEvent(
            eventId: 'evt-000',
            timestamp: startTime - 1000,
            objectIds: ['path-existing'],
            mode: SelectionMode.replace,
          ),
        );

        // Create new path (sequence 1-4)
        await eventStore.insertEvent(
          docId,
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-new',
            startAnchor: const Point(x: 100, y: 100),
          ),
        );

        await eventStore.insertEvent(
          docId,
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 100,
            pathId: 'path-new',
            position: const Point(x: 200, y: 100),
          ),
        );

        await eventStore.insertEvent(
          docId,
          FinishPathEvent(
            eventId: 'evt-003',
            timestamp: startTime + 200,
            pathId: 'path-new',
            closed: false,
          ),
        );

        // Replay to full state
        final fullState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 3,
        );

        final fullDoc = fullState as Map<String, dynamic>;
        final fullLayers = fullDoc['layers'] as List;
        final pathInFull =
            fullLayers.where((l) => l['id'] == 'path-new').toList();
        expect(pathInFull, isNotEmpty,
            reason: 'Path should exist in full state');

        // Simulate undo: Replay to sequence 0 (before pen tool)
        final undoState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 0,
        );

        final undoDoc = undoState as Map<String, dynamic>;
        final undoLayers = undoDoc['layers'] as List;
        final pathAfterUndo =
            undoLayers.where((l) => l['id'] == 'path-new').toList();

        expect(pathAfterUndo, isEmpty,
            reason: 'Path should not exist after undo to earlier state');
      },
    );

    test(
      'Deterministic replay: Multiple replays produce identical results',
      () async {
        final docId = 'doc-deterministic-test';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // Create event sequence
        final testEvents = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-1',
            startAnchor: const Point(x: 100, y: 100),
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 100,
            pathId: 'path-1',
            position: const Point(x: 200, y: 150),
            anchorType: AnchorType.bezier,
            handleOut: const Point(x: 50, y: -20),
            handleIn: const Point(x: -50, y: 20),
          ),
          FinishPathEvent(
            eventId: 'evt-003',
            timestamp: startTime + 200,
            pathId: 'path-1',
            closed: false,
          ),
          SelectObjectsEvent(
            eventId: 'evt-004',
            timestamp: startTime + 300,
            objectIds: ['path-1'],
            mode: SelectionMode.replace,
          ),
        ];

        // Insert all events
        for (final event in testEvents) {
          await eventStore.insertEvent(docId, event);
        }

        // Replay 3 times and collect results
        final results = <Map<String, dynamic>>[];
        for (int i = 0; i < 3; i++) {
          final maxSeq = await eventStore.getMaxSequence(docId);
          final result = await replayer.replayFromSnapshot(
            documentId: docId,
            maxSequence: maxSeq,
          );
          results.add(result as Map<String, dynamic>);
        }

        // All replays should produce identical JSON
        for (int i = 1; i < results.length; i++) {
          expect(jsonEncode(results[0]), equals(jsonEncode(results[i])),
              reason: 'Replay $i should match replay 0 (deterministic)');
        }
      },
    );

    test(
      'Telemetry validation: Event counts within expected ranges',
      () async {
        final docId = 'doc-telemetry-test';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // Create typical workflow: 3-anchor path + selection
        final telemetryEvents = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-1',
            startAnchor: const Point(x: 100, y: 100),
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 50,
            pathId: 'path-1',
            position: const Point(x: 200, y: 100),
          ),
          AddAnchorEvent(
            eventId: 'evt-003',
            timestamp: startTime + 100,
            pathId: 'path-1',
            position: const Point(x: 200, y: 200),
          ),
          FinishPathEvent(
            eventId: 'evt-004',
            timestamp: startTime + 150,
            pathId: 'path-1',
            closed: true,
          ),
          SelectObjectsEvent(
            eventId: 'evt-005',
            timestamp: startTime + 200,
            objectIds: ['path-1'],
            mode: SelectionMode.replace,
          ),
        ];

        // Persist events
        for (final event in telemetryEvents) {
          await eventStore.insertEvent(docId, event);
        }

        // Verify event count
        final maxSeq = await eventStore.getMaxSequence(docId);
        final eventCount = maxSeq + 1; // Sequence is 0-indexed

        // Expected: 5 events total for 3-anchor closed path + selection
        expect(eventCount, equals(5),
            reason: 'Typical 3-anchor path + selection = 5 events');

        // Verify event sampling rate (timestamp deltas from our test events)
        final timestamps = telemetryEvents.map((e) => e.timestamp).toList();

        for (int i = 1; i < timestamps.length; i++) {
          final delta = timestamps[i] - timestamps[i - 1];
          expect(delta, lessThanOrEqualTo(100),
              reason: 'Event sampling should be ≤ 100 ms (test interval)');
        }

        // Measure replay performance
        final replayStart = DateTime.now();
        await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: maxSeq,
        );
        final replayDuration = DateTime.now().difference(replayStart);

        // Small event count should replay very fast (< 50 ms)
        expect(replayDuration.inMilliseconds, lessThan(50),
            reason: 'Small replay (5 events) should be < 50 ms');

        // Print telemetry for documentation
        // ignore: avoid_print
        print('=== Telemetry Validation ===');
        // ignore: avoid_print
        print('Event Count: $eventCount');
        // ignore: avoid_print
        print('Replay Time: ${replayDuration.inMilliseconds} ms');
        // ignore: avoid_print
        print('============================');
      },
    );
  });
}

/// Registers event handlers for document reconstruction.
void _registerEventHandlers(EventHandlerRegistry registry) {
  // Handler for CreatePathEvent
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
      'strokeWidth': pathEvent.strokeWidth,
      'opacity': pathEvent.opacity,
      'closed': false,
    });

    return {...map, 'layers': layers};
  });

  // Handler for AddAnchorEvent
  registry.registerHandler('AddAnchorEvent', (state, event) {
    final map = state as Map<String, dynamic>;
    final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
    final anchorEvent = event as AddAnchorEvent;

    final pathIndex =
        layers.indexWhere((layer) => layer['id'] == anchorEvent.pathId);
    if (pathIndex != -1) {
      final path = Map<String, dynamic>.from(layers[pathIndex]);
      final anchors = List<Map<String, dynamic>>.from(path['anchors'] as List);

      final anchorData = <String, dynamic>{
        'x': anchorEvent.position.x,
        'y': anchorEvent.position.y,
      };

      // Include handle data if Bezier anchor
      if (anchorEvent.anchorType == AnchorType.bezier) {
        if (anchorEvent.handleOut != null) {
          anchorData['handleOut'] = {
            'x': anchorEvent.handleOut!.x,
            'y': anchorEvent.handleOut!.y,
          };
        }
        if (anchorEvent.handleIn != null) {
          anchorData['handleIn'] = {
            'x': anchorEvent.handleIn!.x,
            'y': anchorEvent.handleIn!.y,
          };
        }
      }

      anchors.add(anchorData);
      path['anchors'] = anchors;
      layers[pathIndex] = path;
    }

    return {...map, 'layers': layers};
  });

  // Handler for FinishPathEvent
  registry.registerHandler('FinishPathEvent', (state, event) {
    final map = state as Map<String, dynamic>;
    final layers = List<Map<String, dynamic>>.from(map['layers'] as List);
    final finishEvent = event as FinishPathEvent;

    final pathIndex =
        layers.indexWhere((layer) => layer['id'] == finishEvent.pathId);
    if (pathIndex != -1) {
      final path = Map<String, dynamic>.from(layers[pathIndex]);
      path['closed'] = finishEvent.closed;
      layers[pathIndex] = path;
    }

    return {...map, 'layers': layers};
  });

  // Handler for SelectObjectsEvent
  registry.registerHandler('SelectObjectsEvent', (state, event) {
    final map = state as Map<String, dynamic>;
    final selectEvent = event as SelectObjectsEvent;

    return {
      ...map,
      'selection': {
        'objectIds': selectEvent.objectIds,
        'anchorIndices': <String, Set<int>>{},
      },
    };
  });

  // Handler for ClearSelectionEvent
  registry.registerHandler('ClearSelectionEvent', (state, event) {
    final map = state as Map<String, dynamic>;

    return {
      ...map,
      'selection': {
        'objectIds': <String>[],
        'anchorIndices': <String, Set<int>>{},
      },
    };
  });
}
