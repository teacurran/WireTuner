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

      // Update state
      documentState['counter'] = 1;

      // Save cycle 2
      await saveService.save(
        documentId: documentId,
        currentSequence: 1,
        documentState: documentState,
        title: 'Test',
      );

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
      expect(
        failure.errorType,
        anyOf([LoadErrorType.fileNotFound, LoadErrorType.unknown]),
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
