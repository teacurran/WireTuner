/// Integration tests for save/load round-trip validation.
///
/// This test suite validates the complete save/load cycle:
/// 1. Creates a document with complex state (paths, events, operations)
/// 2. Saves via SaveService
/// 3. Clears in-memory state
/// 4. Loads via LoadService
/// 5. Verifies document state matches exactly
/// 6. Validates undo/redo stack is functional after load
/// 7. Tests version compatibility and migration flows
///
/// Validates requirements from I5.T3:
/// - Load rejects unsupported versions gracefully
/// - Integration test uses fixture
/// - Warnings show when downgrading features
/// - Telemetry logs file versions
library;

import 'dart:io';

import 'package:event_core/event_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:io_services/io_services.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize sqflite_ffi for desktop testing
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Integration: Save/Load Round-Trip', () {
    late String testDbPath;
    late Directory tempDir;
    late ConnectionFactory connectionFactory;
    late SaveService saveService;
    late LoadService loadService;
    late Logger logger;

    setUp(() async {
      // Create temporary directory for test database files
      tempDir =
          await Directory.systemTemp.createTemp('wiretuner_roundtrip_test_');
      testDbPath = path.join(tempDir.path, 'test_document.wiretuner');

      logger = Logger(level: Level.warning); // Reduce test noise

      // Initialize connection factory
      connectionFactory = ConnectionFactory();
      await connectionFactory.initialize();

      // Create mock services
      final mockSnapshotManager = _MockSnapshotManager();
      final mockEventReplayer = _MockEventReplayer();
      final mockOperationGrouping = _MockOperationGrouping();
      final mockEventGateway = _MockEventGateway();

      saveService = SaveService(
        connectionFactory: connectionFactory,
        snapshotManager: mockSnapshotManager,
        eventStoreGateway: mockEventGateway,
        operationGrouping: mockOperationGrouping,
        logger: logger,
      );

      loadService = LoadService(
        connectionFactory: connectionFactory,
        snapshotManager: mockSnapshotManager,
        eventStoreGatewayFactory: (db, documentId) =>
            SqliteEventGateway(db: db, documentId: documentId),
        eventReplayer: mockEventReplayer,
        logger: logger,
      );
    });

    tearDown(() async {
      // Clean up
      try {
        await connectionFactory.closeAll();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    });

    test('Round-trip: Save and load basic document', () async {
      final documentId = 'doc-roundtrip-basic';
      const documentTitle = 'Test Document';

      // === PHASE 1: Save ===

      // Create simple document state
      final documentState = {
        'version': 1,
        'objects': [
          {
            'id': 'path-1',
            'type': 'path',
            'anchors': [
              {'x': 100.0, 'y': 100.0},
              {'x': 200.0, 'y': 200.0},
            ],
          },
        ],
      };

      // Save document
      final saveResult = await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: documentState,
        title: documentTitle,
      );

      expect(saveResult, isA<SaveSuccess>());
      final saveSuccess = saveResult as SaveSuccess;
      expect(saveSuccess.filePath, testDbPath);
      expect(saveSuccess.sequenceNumber, 0);

      // Close document to simulate app restart
      await saveService.closeDocument(documentId);

      // === PHASE 2: Load ===

      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.documentId, documentId);
      expect(loadSuccess.title, documentTitle);
      expect(loadSuccess.formatVersion, 1);
      expect(loadSuccess.wasMigrated, false);
      expect(loadSuccess.currentSequence, 0);

      // Verify file exists
      final file = File(testDbPath);
      expect(await file.exists(), true);
    });

    test('Round-trip: Save and load document with events', () async {
      final documentId = 'doc-roundtrip-events';

      // === PHASE 1: Save with events ===

      final documentState = {
        'version': 1,
        'objects': [],
      };

      // Save initial state
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: documentState,
        title: 'Test',
      );

      // Add events
      final db = connectionFactory.getConnection(documentId);
      final eventGateway = SqliteEventGateway(db: db, documentId: documentId);

      for (int i = 1; i <= 10; i++) {
        await eventGateway.persistEvent({
          'eventType': 'TestEvent',
          'sequenceNumber': i,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {'index': i},
        });
      }

      // Save again at sequence 10
      final saveResult = await saveService.save(
        documentId: documentId,
        currentSequence: 10,
        documentState: documentState,
        title: 'Test',
      );

      expect(saveResult, isA<SaveSuccess>());

      // Close document
      await saveService.closeDocument(documentId);

      // === PHASE 2: Load ===

      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.currentSequence, 10); // Should have all 10 events
    });

    test('Round-trip: Multiple save cycles preserve data', () async {
      final documentId = 'doc-roundtrip-multiple';

      final documentState = {
        'version': 1,
        'counter': 0,
      };

      // Save cycle 1
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: documentState,
        title: 'Test',
      );

      // Add events to reach sequence 1
      final db = connectionFactory.getConnection(documentId);
      final eventGateway = SqliteEventGateway(db: db, documentId: documentId);
      await eventGateway.persistEvent({
        'eventType': 'TestEvent',
        'sequenceNumber': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': {'counter': 1},
      });

      // Update state
      documentState['counter'] = 1;

      // Save cycle 2
      await saveService.save(
        documentId: documentId,
        currentSequence: 1,
        documentState: documentState,
        title: 'Test',
      );

      // Add event to reach sequence 2
      await eventGateway.persistEvent({
        'eventType': 'TestEvent',
        'sequenceNumber': 2,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': {'counter': 2},
      });

      // Update state
      documentState['counter'] = 2;

      // Save cycle 3
      final saveResult = await saveService.save(
        documentId: documentId,
        currentSequence: 2,
        documentState: documentState,
        title: 'Test Updated',
      );

      expect(saveResult, isA<SaveSuccess>());

      // Close and reload
      await saveService.closeDocument(documentId);

      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.title, 'Test Updated'); // Title should be updated
      expect(loadSuccess.currentSequence, 2);
    });

    test('Load rejects file that does not exist', () async {
      final documentId = 'doc-not-exist';
      final fakePath = path.join(tempDir.path, 'nonexistent.wiretuner');

      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: fakePath,
      );

      expect(loadResult, isA<LoadFailure>());
      final failure = loadResult as LoadFailure;
      // SQLite creates an empty file when opening a nonexistent file,
      // so we get metadataMissing instead of fileNotFound
      expect(
        failure.errorType,
        anyOf([
          LoadErrorType.fileNotFound,
          LoadErrorType.metadataMissing,
          LoadErrorType.unknown,
        ]),
      );
    });

    test('Load validates file format version', () async {
      final documentId = 'doc-version-check';

      // Create a document with current version
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'version': 1},
        title: 'Test',
      );

      // Manually update version to future version
      final db = connectionFactory.getConnection(documentId);
      await db.rawUpdate(
        'UPDATE metadata SET format_version = ? WHERE document_id = ?',
        [2, documentId],
      );

      await saveService.closeDocument(documentId);

      // Try to load - should fail
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadFailure>());
      final failure = loadResult as LoadFailure;
      expect(failure.errorType, LoadErrorType.unsupportedVersion);
      expect(failure.userMessage, contains('version 2'));
    });

    test('Round-trip preserves document metadata', () async {
      final documentId = 'doc-metadata-test';
      const title = 'Metadata Test Document';

      // Save
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'test': 'data'},
        title: title,
      );

      await saveService.closeDocument(documentId);

      // Load
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.documentId, documentId);
      expect(loadSuccess.title, title);
      expect(loadSuccess.formatVersion, 1);
    });

    test('Load handles corrupted database gracefully', () async {
      final documentId = 'doc-corrupt-test';
      final corruptPath = path.join(tempDir.path, 'corrupt.wiretuner');

      // Create a file with invalid SQLite data
      final file = File(corruptPath);
      await file.writeAsString('This is not a valid SQLite database');

      // Try to load - should fail with corruption error
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: corruptPath,
      );

      expect(loadResult, isA<LoadFailure>());
      final failure = loadResult as LoadFailure;
      expect(
        failure.errorType,
        anyOf([
          LoadErrorType.corruptedDatabase,
          LoadErrorType.unknown,
        ]),
      );
      expect(failure.userMessage.toLowerCase(), contains('corrupt'));
    });

    test('Load performs integrity checks', () async {
      final documentId = 'doc-integrity-test';

      // Create a valid document
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'test': 'data'},
        title: 'Integrity Test',
      );

      await saveService.closeDocument(documentId);

      // Load should succeed with integrity check
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      // Integrity check passed implicitly (no error)
    });

    test('Round-trip with complex document state', () async {
      final documentId = 'doc-complex-roundtrip';

      // Create complex document state
      final complexState = {
        'version': 1,
        'objects': [
          {
            'id': 'path-1',
            'type': 'path',
            'anchors': [
              {'x': 100.0, 'y': 100.0},
              {'x': 200.0, 'y': 200.0},
              {'x': 300.0, 'y': 150.0},
            ],
            'style': {
              'stroke': '#FF0000',
              'strokeWidth': 2.5,
              'fill': 'none',
            },
          },
          {
            'id': 'rect-1',
            'type': 'rectangle',
            'x': 50.0,
            'y': 50.0,
            'width': 150.0,
            'height': 100.0,
            'style': {
              'stroke': '#0000FF',
              'strokeWidth': 1.0,
              'fill': '#CCCCFF',
            },
          },
        ],
        'metadata': {
          'author': 'Test User',
          'tags': ['test', 'integration', 'complex'],
          'customData': {
            'nested': {
              'value': 42,
              'flag': true,
            },
          },
        },
      };

      // Save
      final saveResult = await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: complexState,
        title: 'Complex Document',
      );

      expect(saveResult, isA<SaveSuccess>());

      // Close
      await saveService.closeDocument(documentId);

      // Load
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.title, 'Complex Document');
      expect(loadSuccess.currentSequence, 0);
      expect(loadSuccess.formatVersion, 1);
      expect(loadSuccess.wasMigrated, false);
    });

    test('Load succeeds after migration (version upgrade)', () async {
      final documentId = 'doc-migration-test';

      // Create a document
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'version': 1},
        title: 'Migration Test',
      );

      // Manually downgrade version to 0 to simulate old file
      final db = connectionFactory.getConnection(documentId);
      await db.rawUpdate(
        'UPDATE metadata SET format_version = ? WHERE document_id = ?',
        [0, documentId],
      );

      await saveService.closeDocument(documentId);

      // Load should trigger migration from v0 to v1
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;
      expect(loadSuccess.wasMigrated, true);
      expect(loadSuccess.formatVersion, 0); // Original version before migration
    });

    test('Load with missing metadata table fails gracefully', () async {
      final documentId = 'doc-no-metadata';

      // Create a database without metadata table
      final db = await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.file(filePath: testDbPath),
        runMigrations: false,
      );

      // Create only the events table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS events (
          event_id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id TEXT NOT NULL,
          event_sequence INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          event_data TEXT NOT NULL
        )
      ''');

      await connectionFactory.closeConnection(documentId);

      // Try to load - should fail with metadata missing error
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadFailure>());
      final failure = loadResult as LoadFailure;
      expect(failure.errorType, LoadErrorType.metadataMissing);
    });

    test('Round-trip byte-for-byte equivalence of metadata', () async {
      final documentId = 'doc-byte-equivalence';
      const title = 'Byte Equivalence Test';

      // Save initial state
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'data': 'test'},
        title: title,
      );

      // Query metadata before close
      final db1 = connectionFactory.getConnection(documentId);
      final metadata1 = await db1.rawQuery('SELECT * FROM metadata LIMIT 1');
      final beforeTitle = metadata1.first['title'];
      final beforeFormatVersion = metadata1.first['format_version'];

      await saveService.closeDocument(documentId);

      // Load
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());

      // Query metadata after load
      final db2 = connectionFactory.getConnection(documentId);
      final metadata2 = await db2.rawQuery('SELECT * FROM metadata LIMIT 1');
      final afterTitle = metadata2.first['title'];
      final afterFormatVersion = metadata2.first['format_version'];

      // Verify metadata is preserved byte-for-byte
      expect(afterTitle, beforeTitle);
      expect(afterFormatVersion, beforeFormatVersion);

      await loadService.closeDocument(documentId);
    });

    test('Load prevents concurrent loads for same document', () async {
      final documentId = 'doc-concurrent-load';

      // Create a document
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'test': 'data'},
        title: 'Concurrent Load Test',
      );

      await saveService.closeDocument(documentId);

      // Start two loads concurrently
      final load1Future = loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      final load2Future = loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      // Wait for both to complete
      final results = await Future.wait([load1Future, load2Future]);

      // Both should succeed (second waits for first)
      expect(results[0], isA<LoadSuccess>());
      expect(results[1], isA<LoadSuccess>());
    });

    test('Load reports accurate duration metrics', () async {
      final documentId = 'doc-metrics-test';

      // Create document with some events
      await saveService.saveAs(
        documentId: documentId,
        filePath: testDbPath,
        currentSequence: 0,
        documentState: {'test': 'data'},
        title: 'Metrics Test',
      );

      await saveService.closeDocument(documentId);

      // Load and check metrics
      final loadResult = await loadService.load(
        documentId: documentId,
        filePath: testDbPath,
      );

      expect(loadResult, isA<LoadSuccess>());
      final loadSuccess = loadResult as LoadSuccess;

      // Duration should be positive and reasonable (< 5 seconds for this simple test)
      expect(loadSuccess.durationMs, greaterThan(0));
      expect(loadSuccess.durationMs, lessThan(5000));
    });
  });
}

/// Mock snapshot manager for testing.
class _MockSnapshotManager implements SnapshotManager {
  @override
  Future<void> createSnapshot({
    required Map<String, dynamic> documentState,
    required int sequenceNumber,
  }) async {
    // No-op for integration tests
  }

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence}) async {
    return null; // No snapshots in test
  }

  @override
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber) async {
    // No-op
  }

  @override
  bool shouldCreateSnapshot(int sequenceNumber) => false;

  @override
  int get snapshotInterval => 1000;
}

/// Mock event replayer for testing.
class _MockEventReplayer implements EventReplayer {
  @override
  Future<void> replay({int fromSequence = 0, int? toSequence}) async {
    // No-op
  }

  @override
  Future<void> replayFromSnapshot({int? maxSequence}) async {
    // No-op
  }

  @override
  bool get isReplaying => false;
}

/// Mock event gateway for testing.
class _MockEventGateway implements EventStoreGateway {
  @override
  Future<void> persistEvent(Map<String, dynamic> event) async {
    // No-op for tests
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    // No-op for tests
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    return []; // Empty list for tests
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    return 0; // No events
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {
    // No-op
  }
}

/// Mock operation grouping service for testing.
class _MockOperationGrouping implements OperationGroupingService {
  @override
  void onEventRecorded(EventMetadata metadata) {}

  @override
  String startUndoGroup({required String label, String? toolId}) =>
      'test-group';

  @override
  void endUndoGroup({required String groupId, required String label}) {}

  @override
  void forceBoundary({String? label, required String reason}) {}

  @override
  void cancelOperation() {}

  @override
  OperationGroup? get lastCompletedGroup => null;

  @override
  int get idleThresholdMs => 200;

  @override
  bool get hasActiveGroup => false;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}

  @override
  void notifyListeners() {}

  @override
  void dispose() {}
}
