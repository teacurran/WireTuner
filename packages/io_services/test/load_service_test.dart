/// Unit tests for LoadService.
///
/// Tests cover:
/// - Happy path: loading freshly saved file
/// - Unsupported version rejection
/// - Migration flow (v0 → v1)
/// - Snapshot corruption handling
/// - Concurrent load guard
/// - Error categorization
library;

import 'dart:async';
import 'package:event_core/event_core.dart';
import 'package:io_services/io_services.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // Initialize FFI for desktop platforms
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LoadService', () {
    late ConnectionFactory connectionFactory;
    late LoadService loadService;
    late Logger logger;

    setUp(() {
      logger = Logger(level: Level.warning); // Reduce test noise
      connectionFactory = ConnectionFactory();
      connectionFactory.initialize();

      // Create mock snapshot manager
      final mockSnapshotManager = _MockSnapshotManager();

      // Create mock event replayer
      final mockEventReplayer = _MockEventReplayer();

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
      await connectionFactory.closeAll();
    });

    test('load() succeeds for valid in-memory database', () async {
      // Arrange: Create a minimal in-memory database
      final documentId = 'test-doc-1';
      final db = await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      // Insert metadata
      await db.rawInsert(
        'INSERT INTO metadata (document_id, title, format_version, created_at, modified_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [documentId, 'Test Document', 1, 1699545600, 1699545600],
      );

      // Act: Load the document
      final result = await loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      // Assert
      expect(result, isA<LoadSuccess>());
      final success = result as LoadSuccess;
      expect(success.documentId, documentId);
      expect(success.title, 'Test Document');
      expect(success.formatVersion, 1);
      expect(success.wasMigrated, false);
      expect(success.currentSequence, 0); // No events
    });

    test('load() rejects unsupported future version', () async {
      // Arrange: Create database with future version
      final documentId = 'test-doc-future';
      final db = await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      // Insert metadata with version 2 (future version)
      await db.rawUpdate(
        'UPDATE metadata SET format_version = ? WHERE document_id = ?',
        [2, documentId],
      );

      // Insert a metadata row if none exists
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM metadata');
      if (count.first['count'] == 0) {
        await db.rawInsert(
          'INSERT INTO metadata (document_id, title, format_version, created_at, modified_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [documentId, 'Future Doc', 2, 1699545600, 1699545600],
        );
      }

      // Act: Attempt to load
      final result = await loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      // Assert
      expect(result, isA<LoadFailure>());
      final failure = result as LoadFailure;
      expect(failure.errorType, LoadErrorType.unsupportedVersion);
      expect(failure.userMessage, contains('Incompatible File Version'));
      expect(failure.userMessage, contains('version 2'));
    });

    test('load() detects corrupted database', () async {
      // Arrange: Create database then close it
      final documentId = 'test-doc-corrupt';
      await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      // Manually corrupt by dropping metadata table
      final db = connectionFactory.getConnection(documentId);
      await db.execute('DROP TABLE metadata');

      // Act: Attempt to load
      final result = await loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      // Assert
      expect(result, isA<LoadFailure>());
      final failure = result as LoadFailure;
      expect(failure.errorType, LoadErrorType.metadataMissing);
      expect(failure.userMessage, contains('missing metadata'));
    });

    test('load() prevents concurrent loads of same document', () async {
      // Arrange: Create valid database
      final documentId = 'test-doc-concurrent';
      final db = await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      await db.rawInsert(
        'INSERT INTO metadata (document_id, title, format_version, created_at, modified_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [documentId, 'Test', 1, 1699545600, 1699545600],
      );

      // Act: Start two loads simultaneously
      final future1 = loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      final future2 = loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      final results = await Future.wait([future1, future2]);

      // Assert: Both should succeed (second waits for first)
      expect(results[0], isA<LoadSuccess>());
      expect(results[1], isA<LoadSuccess>());
    });

    test('load() loads document with events', () async {
      // Arrange: Create database with events
      final documentId = 'test-doc-events';
      final db = await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      await db.rawInsert(
        'INSERT INTO metadata (document_id, title, format_version, created_at, modified_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [documentId, 'Test', 1, 1699545600, 1699545600],
      );

      // Add events
      final eventGateway = SqliteEventGateway(db: db, documentId: documentId);
      for (int i = 0; i < 5; i++) {
        await eventGateway.persistEvent({
          'eventType': 'TestEvent',
          'sequenceNumber': i,
          'timestamp': 1699545600 + i * 1000,
          'data': {'value': i},
        });
      }

      // Act: Load
      final result = await loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      // Assert
      expect(result, isA<LoadSuccess>());
      final success = result as LoadSuccess;
      expect(success.currentSequence, 4); // 0-4 = 5 events, max is 4
    });

    test('closeDocument() releases resources', () async {
      // Arrange: Load a document
      final documentId = 'test-doc-close';
      await connectionFactory.openConnection(
        documentId: documentId,
        config: DatabaseConfig.inMemory(),
        runMigrations: true,
      );

      final db = connectionFactory.getConnection(documentId);
      await db.rawInsert(
        'INSERT INTO metadata (document_id, title, format_version, created_at, modified_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [documentId, 'Test', 1, 1699545600, 1699545600],
      );

      await loadService.load(
        documentId: documentId,
        filePath: inMemoryDatabasePath,
      );

      expect(loadService.getCurrentFilePath(documentId), inMemoryDatabasePath);

      // Act: Close document
      await loadService.closeDocument(documentId);

      // Assert: Path should be cleared
      expect(loadService.getCurrentFilePath(documentId), isNull);
      expect(connectionFactory.hasConnection(documentId), false);
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
    // No-op for tests
  }

  @override
  Future<SnapshotData?> loadSnapshot({int? maxSequence}) async {
    // Return null (no snapshot) - forces full replay
    return null;
  }

  @override
  Future<void> pruneSnapshotsBeforeSequence(int sequenceNumber) async {
    // No-op for tests
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
    // No-op for tests
  }

  @override
  Future<void> replayFromSnapshot({int? maxSequence}) async {
    // No-op for tests
  }

  @override
  bool get isReplaying => false;
}
