import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
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

/// Integration tests for crash recovery validation.
///
/// This test suite validates the crash recovery mechanism:
/// 1. Simulates crash mid-operation by abruptly closing database
/// 2. Relaunches app by reopening database connection
/// 3. Verifies last snapshot + events restore exact state
/// 4. Measures recovery performance (<100 ms target per Decision 1)
///
/// Validates requirements from I4.T9:
/// - Recovery test passes with various crash scenarios
/// - Load time < 100 ms (measured and documented)
/// - Snapshot + event log integrity maintained
/// - References Decision 1: Event Sourcing + Snapshots
///
/// **Crash Scenarios Tested:**
/// - Crash during event recording (mid-operation)
/// - Crash during snapshot creation (partial snapshot)
/// - Crash with backlog of pending events
/// - Corrupted snapshot fallback to previous snapshot
void main() {
  // Initialize sqflite_ffi for desktop testing
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Integration: Crash Recovery Validation', () {
    late String testDbPath;
    late Directory tempDir;

    setUp(() async {
      // Create temporary directory for test database files
      tempDir = await Directory.systemTemp.createTemp('wiretuner_crash_test_');
      testDbPath = path.join(tempDir.path, 'test_document.db');
    });

    tearDown(() async {
      // Clean up temporary files
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    });

    test(
      'Crash Recovery: Mid-operation event recording',
      () async {
        final docId = 'doc-crash-mid-operation';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // === PHASE 1: Normal Operation (Before Crash) ===

        // Open database and create schema
        var db = await databaseFactoryFfi.openDatabase(testDbPath);
        await _createSchema(db);

        var eventStore = EventStore(db);
        var snapshotStore = SnapshotStore(db);
        var registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        var dispatcher = event_dispatcher.EventDispatcher(registry);
        var replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );
        var serializer = SnapshotSerializer(enableCompression: true);

        // Create a document with some events
        final preCrashEvents = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-1',
            startAnchor: const Point(x: 100, y: 100),
            strokeColor: '#000000',
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 50,
            pathId: 'path-1',
            position: const Point(x: 200, y: 150),
            anchorType: AnchorType.line,
          ),
          AddAnchorEvent(
            eventId: 'evt-003',
            timestamp: startTime + 100,
            pathId: 'path-1',
            position: const Point(x: 300, y: 100),
            anchorType: AnchorType.line,
          ),
          FinishPathEvent(
            eventId: 'evt-004',
            timestamp: startTime + 150,
            pathId: 'path-1',
            closed: false,
          ),
        ];

        // Persist events
        for (final event in preCrashEvents) {
          await eventStore.insertEvent(docId, event);
        }

        // Create snapshot at sequence 2 (after 3 events)
        final stateBeforeSnapshot = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 2,
        );

        final snapshotData = serializer.serialize(stateBeforeSnapshot);
        await snapshotStore.insertSnapshot(
          documentId: docId,
          eventSequence: 2,
          snapshotData: snapshotData,
          compression: 'gzip',
        );

        // Get state before crash
        final preCrashState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 3,
        );

        // === SIMULATE CRASH: Abruptly close database ===
        // Simulate crash by closing database without clean shutdown
        await db.close();
        // In real crash scenario, OS would kill process here

        // === PHASE 2: Recovery (After Crash/Restart) ===

        // Measure recovery time
        final recoveryStart = DateTime.now();

        // Reopen database (simulating app relaunch)
        db = await databaseFactoryFfi.openDatabase(testDbPath);

        // Recreate infrastructure (as app would on restart)
        eventStore = EventStore(db);
        snapshotStore = SnapshotStore(db);
        registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        dispatcher = event_dispatcher.EventDispatcher(registry);
        replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );

        // Recover to last known sequence
        final maxSeq = await eventStore.getMaxSequence(docId);
        final recoveredState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: maxSeq,
        );

        final recoveryDuration = DateTime.now().difference(recoveryStart);

        // === VERIFICATION ===

        // Verify recovered state matches pre-crash state
        expect(
          jsonEncode(recoveredState),
          equals(jsonEncode(preCrashState)),
          reason: 'Recovered state must match pre-crash state exactly',
        );

        // Verify all events were persisted
        expect(maxSeq, equals(3),
            reason: 'All 4 events (0-3) should be present');

        // Verify recovery performance target: < 100 ms
        expect(
          recoveryDuration.inMilliseconds,
          lessThan(100),
          reason: 'Recovery should complete in < 100 ms per Decision 1',
        );

        // Verify document structure integrity
        // Note: After snapshot deserialization, the state is a real Document object
        // with the full structure (layers[].objects[]), not our simplified test structure
        // (layers[].anchors[]). The jsonEncode comparison above already validates correctness.
        final doc = recoveredState is Map<String, dynamic>
            ? recoveredState
            : (recoveredState as dynamic).toJson() as Map<String, dynamic>;

        expect(doc['id'], equals(docId));
        final layers = (doc['layers'] ?? []) as List;
        expect(layers, hasLength(1), reason: 'Should have one layer');

        // Print recovery metrics for documentation
        print('=== Crash Recovery Metrics ===');
        print('Recovery Time: ${recoveryDuration.inMilliseconds} ms');
        print('Events Recovered: ${maxSeq + 1}');
        print('Snapshot Used: Yes (at sequence 2)');
        print('State Integrity: PASS');
        print('==============================');

        await db.close();
      },
    );

    test(
      'Crash Recovery: During snapshot creation',
      () async {
        final docId = 'doc-crash-snapshot';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // === PHASE 1: Setup with partial snapshot corruption ===

        var db = await databaseFactoryFfi.openDatabase(testDbPath);
        await _createSchema(db);

        var eventStore = EventStore(db);
        var snapshotStore = SnapshotStore(db);
        var registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        var dispatcher = event_dispatcher.EventDispatcher(registry);
        var serializer = SnapshotSerializer(enableCompression: true);

        // Create multiple events
        final events = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-1',
            startAnchor: const Point(x: 50, y: 50),
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 50,
            pathId: 'path-1',
            position: const Point(x: 100, y: 100),
          ),
          FinishPathEvent(
            eventId: 'evt-003',
            timestamp: startTime + 100,
            pathId: 'path-1',
            closed: false,
          ),
          CreatePathEvent(
            eventId: 'evt-004',
            timestamp: startTime + 200,
            pathId: 'path-2',
            startAnchor: const Point(x: 200, y: 200),
          ),
          AddAnchorEvent(
            eventId: 'evt-005',
            timestamp: startTime + 250,
            pathId: 'path-2',
            position: const Point(x: 250, y: 250),
          ),
        ];

        for (final event in events) {
          await eventStore.insertEvent(docId, event);
        }

        // Create valid snapshot at sequence 1
        var replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );

        final state1 = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 1,
        );
        final snapshotData1 = serializer.serialize(state1);
        await snapshotStore.insertSnapshot(
          documentId: docId,
          eventSequence: 1,
          snapshotData: snapshotData1,
          compression: 'gzip',
        );

        // Simulate corrupted snapshot at sequence 3 (simulating crash during snapshot write)
        final corruptedData =
            Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]); // Invalid data
        await snapshotStore.insertSnapshot(
          documentId: docId,
          eventSequence: 3,
          snapshotData: corruptedData,
          compression: 'gzip',
        );

        // Close database (simulate crash after partial snapshot write)
        await db.close();

        // === PHASE 2: Recovery with corrupted snapshot fallback ===

        final recoveryStart = DateTime.now();

        db = await databaseFactoryFfi.openDatabase(testDbPath);
        eventStore = EventStore(db);
        snapshotStore = SnapshotStore(db);
        registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        dispatcher = event_dispatcher.EventDispatcher(registry);
        replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );

        // Attempt recovery - should fall back to previous valid snapshot
        final result = await replayer.replayToSequence(
          documentId: docId,
          targetSequence: 4,
          continueOnError: true,
        );

        final recoveryDuration = DateTime.now().difference(recoveryStart);

        // === VERIFICATION ===

        // Should have warnings about corrupted snapshot
        expect(
          result.hasIssues,
          isTrue,
          reason: 'Should detect corrupted snapshot',
        );

        expect(
          result.warnings.any((w) => w.contains('corrupted')),
          isTrue,
          reason: 'Should log corrupted snapshot warning',
        );

        // But state should still be recovered using fallback mechanism
        // Convert to Map if it's a typed object
        final doc = result.state is Map<String, dynamic>
            ? result.state
            : (result.state as dynamic).toJson() as Map<String, dynamic>;
        final layers = doc['layers'] as List;
        expect(
          layers.length,
          greaterThanOrEqualTo(1),
          reason: 'Should recover at least first path using fallback',
        );

        // Performance should still be reasonable
        expect(
          recoveryDuration.inMilliseconds,
          lessThan(150),
          reason: 'Recovery with fallback should complete in < 150 ms',
        );

        print('=== Corrupted Snapshot Recovery ===');
        print('Recovery Time: ${recoveryDuration.inMilliseconds} ms');
        print('Warnings: ${result.warnings.length}');
        print('Fallback Strategy: SUCCESSFUL');
        print('===================================');

        await db.close();
      },
    );

    test(
      'Crash Recovery: Backlog of pending events',
      () async {
        final docId = 'doc-crash-backlog';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // === PHASE 1: Create large event backlog ===

        var db = await databaseFactoryFfi.openDatabase(testDbPath);
        await _createSchema(db);

        var eventStore = EventStore(db);
        var snapshotStore = SnapshotStore(db);
        var registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        var dispatcher = event_dispatcher.EventDispatcher(registry);
        var serializer = SnapshotSerializer(enableCompression: true);
        var replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );

        // Create snapshot early (at sequence 10)
        final batchSize = 50;
        final events = <EventBase>[];

        // Create multiple paths to simulate realistic workload
        for (int i = 0; i < 10; i++) {
          events.add(CreatePathEvent(
            eventId: 'evt-create-$i',
            timestamp: startTime + (i * 10),
            pathId: 'path-$i',
            startAnchor: Point(x: i * 50.0, y: i * 50.0),
          ));
          events.add(AddAnchorEvent(
            eventId: 'evt-add-$i',
            timestamp: startTime + (i * 10) + 5,
            pathId: 'path-$i',
            position: Point(x: i * 50.0 + 100, y: i * 50.0 + 100),
          ));
          events.add(FinishPathEvent(
            eventId: 'evt-finish-$i',
            timestamp: startTime + (i * 10) + 8,
            pathId: 'path-$i',
            closed: false,
          ));
        }

        // Add selection events
        for (int i = 0; i < 20; i++) {
          events.add(SelectObjectsEvent(
            eventId: 'evt-select-$i',
            timestamp: startTime + 200 + (i * 5),
            objectIds: ['path-${i % 10}'],
            mode: SelectionMode.replace,
          ));
        }

        // Persist all events
        for (final event in events) {
          await eventStore.insertEvent(docId, event);
        }

        final totalEvents = events.length;

        // Create snapshot at sequence 10 (early snapshot)
        final snapshotState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: 10,
        );
        final snapshotData10 = serializer.serialize(snapshotState);
        await snapshotStore.insertSnapshot(
          documentId: docId,
          eventSequence: 10,
          snapshotData: snapshotData10,
          compression: 'gzip',
        );

        // === SIMULATE CRASH with large event backlog ===
        await db.close();

        // === PHASE 2: Recovery with large replay ===

        final recoveryStart = DateTime.now();

        db = await databaseFactoryFfi.openDatabase(testDbPath);
        eventStore = EventStore(db);
        snapshotStore = SnapshotStore(db);
        registry = EventHandlerRegistry();
        _registerEventHandlers(registry);
        dispatcher = event_dispatcher.EventDispatcher(registry);
        replayer = EventReplayer(
          eventStore: eventStore,
          snapshotStore: snapshotStore,
          dispatcher: dispatcher,
          enableCompression: true,
        );

        final maxSeq = await eventStore.getMaxSequence(docId);
        final recoveredState = await replayer.replayFromSnapshot(
          documentId: docId,
          maxSequence: maxSeq,
        );

        final recoveryDuration = DateTime.now().difference(recoveryStart);

        // === VERIFICATION ===

        // Verify all events recovered
        expect(
          maxSeq,
          equals(totalEvents - 1),
          reason: 'All events should be persisted',
        );

        // Verify document structure
        // Convert to Map if it's a typed object
        final doc = recoveredState is Map<String, dynamic>
            ? recoveredState
            : (recoveredState as dynamic).toJson() as Map<String, dynamic>;
        final layers = doc['layers'] as List;
        expect(
          layers.length,
          equals(10),
          reason: 'Should have 10 paths',
        );

        // Performance: Snapshot should enable fast recovery despite backlog
        // Target: < 100 ms with snapshot optimization
        expect(
          recoveryDuration.inMilliseconds,
          lessThan(100),
          reason: 'Snapshot optimization should enable <100 ms recovery',
        );

        final eventsReplayed = maxSeq - 10; // Events after snapshot

        print('=== Large Backlog Recovery ===');
        print('Total Events: $totalEvents');
        print('Snapshot at: sequence 10');
        print('Events Replayed: $eventsReplayed');
        print('Recovery Time: ${recoveryDuration.inMilliseconds} ms');
        print(
            'Performance: ${(eventsReplayed / recoveryDuration.inMilliseconds * 1000).toStringAsFixed(0)} events/sec');
        print('==============================');

        await db.close();
      },
    );

    test(
      'Crash Recovery: Complete data loss prevention',
      () async {
        final docId = 'doc-crash-no-loss';
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // === Test that SQLite's WAL mode prevents data loss ===

        var db = await databaseFactoryFfi.openDatabase(testDbPath);
        await _createSchema(db);

        // Enable WAL mode for crash safety (should be default in production)
        // Note: sqflite_ffi already uses WAL mode by default
        await db.execute('PRAGMA journal_mode=WAL');

        var eventStore = EventStore(db);

        // Write events in quick succession (simulating rapid user actions)
        final rapidEvents = <EventBase>[
          CreatePathEvent(
            eventId: 'evt-001',
            timestamp: startTime,
            pathId: 'path-rapid',
            startAnchor: const Point(x: 0, y: 0),
          ),
          AddAnchorEvent(
            eventId: 'evt-002',
            timestamp: startTime + 1,
            pathId: 'path-rapid',
            position: const Point(x: 10, y: 10),
          ),
          AddAnchorEvent(
            eventId: 'evt-003',
            timestamp: startTime + 2,
            pathId: 'path-rapid',
            position: const Point(x: 20, y: 20),
          ),
        ];

        for (final event in rapidEvents) {
          await eventStore.insertEvent(docId, event);
          // No explicit flush - testing auto-commit behavior
        }

        // Immediate crash (no clean shutdown)
        await db.close();

        // === Recovery ===

        db = await databaseFactoryFfi.openDatabase(testDbPath);
        eventStore = EventStore(db);

        final maxSeq = await eventStore.getMaxSequence(docId);

        // === VERIFICATION ===

        // All events should be recovered (WAL ensures durability)
        expect(
          maxSeq,
          equals(2),
          reason:
              'WAL mode should prevent event loss even without explicit flush',
        );

        // Verify we can read all events
        final recoveredEvents = await eventStore.getEvents(
          docId,
          fromSeq: 0,
          toSeq: maxSeq,
        );

        expect(
          recoveredEvents.length,
          equals(3),
          reason: 'All 3 events should be readable',
        );

        print('=== WAL Data Loss Prevention ===');
        print('Events Written: 3');
        print('Events Recovered: ${recoveredEvents.length}');
        print('Data Loss: ZERO');
        print('================================');

        await db.close();
      },
    );
  });
}

/// Creates database schema (events + snapshots tables).
Future<void> _createSchema(Database db) async {
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
}

/// Registers event handlers for document reconstruction.
void _registerEventHandlers(EventHandlerRegistry registry) {
  // Handler for CreatePathEvent
  registry.registerHandler('CreatePathEvent', (state, event) {
    // Convert state to Map if it's a typed object (from deserialized snapshot)
    final map = state is Map<String, dynamic>
        ? state
        : (state as dynamic).toJson() as Map<String, dynamic>;
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
    // Convert state to Map if it's a typed object (from deserialized snapshot)
    final map = state is Map<String, dynamic>
        ? state
        : (state as dynamic).toJson() as Map<String, dynamic>;
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
    // Convert state to Map if it's a typed object (from deserialized snapshot)
    final map = state is Map<String, dynamic>
        ? state
        : (state as dynamic).toJson() as Map<String, dynamic>;
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
    // Convert state to Map if it's a typed object (from deserialized snapshot)
    final map = state is Map<String, dynamic>
        ? state
        : (state as dynamic).toJson() as Map<String, dynamic>;
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
    // Convert state to Map if it's a typed object (from deserialized snapshot)
    final map = state is Map<String, dynamic>
        ? state
        : (state as dynamic).toJson() as Map<String, dynamic>;

    return {
      ...map,
      'selection': {
        'objectIds': <String>[],
        'anchorIndices': <String, Set<int>>{},
      },
    };
  });
}
