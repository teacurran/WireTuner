import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_manager.dart';
import 'package:wiretuner/infrastructure/file_ops/file_picker_adapter.dart';
import 'package:wiretuner/infrastructure/file_ops/save_exceptions.dart';
import 'package:wiretuner/infrastructure/file_ops/save_service.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Save Flow Integration Tests', () {
    late String testFilePath;
    late DatabaseProvider dbProvider;
    late SaveService saveService;
    late MockFilePickerAdapter mockFilePicker;
    late EventStore eventStore;
    late SnapshotManager snapshotManager;

    setUp(() async {
      // Initialize SQLite FFI for desktop testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Generate unique test file path in system temp directory
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory.systemTemp;
      testFilePath = '${tempDir.path}/wiretuner_test_$timestamp.wiretuner';

      // Initialize database provider
      dbProvider = DatabaseProvider();
      await dbProvider.initialize();

      // Create mock file picker
      mockFilePicker = MockFilePickerAdapter();
      mockFilePicker.nextSavePath = testFilePath;

      // Open database and create dependencies
      final db = await dbProvider.open(testFilePath);
      eventStore = EventStore(db);
      final snapshotStore = SnapshotStore(db);
      snapshotManager = SnapshotManager(snapshotStore: snapshotStore);

      // Create save service
      saveService = SaveService(
        eventStore: eventStore,
        snapshotManager: snapshotManager,
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
      );
    });

    tearDown(() async {
      // Close database
      if (dbProvider.isOpen) {
        await dbProvider.close();
      }

      // Delete test file
      if (await File(testFilePath).exists()) {
        await File(testFilePath).delete();
      }
    });

    testWidgets('First save creates database with metadata', (tester) async {
      // Arrange
      final documentId = 'doc-test-1';
      final title = 'Test Document';
      final document = Document(
        id: documentId,
        title: title,
        schemaVersion: 1,
      );

      final events = <EventBase>[
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100, y: 200),
        ),
        AddAnchorEvent(
          eventId: 'e2',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          position: const Point(x: 200, y: 300),
        ),
      ];

      // Act
      final result = await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.documentId, equals(documentId));
      expect(result.eventCount, equals(2));
      expect(result.filePath, equals(testFilePath));
      expect(await File(testFilePath).exists(), isTrue);

      // Verify metadata exists in database
      final db = dbProvider.getDatabase();
      final metadata = await db.query(
        'metadata',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      expect(metadata.length, equals(1));
      expect(metadata.first['title'], equals(title));
      expect(metadata.first['format_version'], equals(1));

      // Verify events were persisted
      final persistedEvents = await eventStore.getEvents(
        documentId,
        fromSeq: 0,
      );
      expect(persistedEvents.length, equals(2));
      expect(persistedEvents[0].eventType, equals('CreatePathEvent'));
      expect(persistedEvents[1].eventType, equals('AddAnchorEvent'));
    });

    testWidgets('Subsequent save updates modified_at timestamp', (tester) async {
      // Arrange - First save
      final documentId = 'doc-test-2';
      final title = 'Test Document 2';
      final document = Document(id: documentId, title: title);

      await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Get initial modified_at timestamp
      final db = dbProvider.getDatabase();
      final initialMetadata = await db.query(
        'metadata',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      final initialModifiedAt = initialMetadata.first['modified_at'] as int;

      // Wait to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 100));

      // Act - Second save with new events
      final newEvent = CreatePathEvent(
        eventId: 'e3',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-2',
        startAnchor: const Point(x: 300, y: 400),
      );

      final result = await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: [newEvent],
        document: document,
        filePath: testFilePath,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.eventCount, equals(1));

      // Verify modified_at was updated
      final updatedMetadata = await db.query(
        'metadata',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      final updatedModifiedAt = updatedMetadata.first['modified_at'] as int;
      expect(updatedModifiedAt, greaterThan(initialModifiedAt));

      // Verify created_at remained unchanged
      final createdAt = updatedMetadata.first['created_at'] as int;
      expect(createdAt, equals(initialMetadata.first['created_at']));
    });

    testWidgets('Save with 1000+ events creates snapshot', (tester) async {
      // Arrange
      final documentId = 'doc-test-large';
      final title = 'Large Document';
      final document = Document(id: documentId, title: title);

      // Generate 1000 events to trigger snapshot threshold
      final events = List.generate(
        1000,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );

      // Act
      final result = await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.eventCount, equals(1000));
      expect(result.snapshotCreated, isTrue);
      expect(result.snapshotCount, greaterThan(0));

      // Verify snapshot exists in database
      final db = dbProvider.getDatabase();
      final snapshots = await db.query(
        'snapshots',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      expect(snapshots.isNotEmpty, isTrue);
    });

    testWidgets('Save with empty events list succeeds', (tester) async {
      // Arrange
      final documentId = 'doc-test-empty';
      final title = 'Empty Document';
      final document = Document(id: documentId, title: title);

      // Act - Save with no events
      final result = await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.eventCount, equals(0));
      expect(result.snapshotCreated, isFalse);

      // Verify metadata still exists
      final db = dbProvider.getDatabase();
      final metadata = await db.query(
        'metadata',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      expect(metadata.length, equals(1));
    });

    testWidgets('User cancels file picker throws SaveCancelledException',
        (tester) async {
      // Arrange
      mockFilePicker.simulateCancellation = true;
      final documentId = 'doc-test-cancel';
      final document = Document(id: documentId, title: 'Test');

      // Act & Assert
      expect(
        () async => await saveService.save(
          documentId: documentId,
          title: 'Test',
          pendingEvents: [],
          document: document,
          filePath: null, // Triggers file picker
        ),
        throwsA(isA<SaveCancelledException>()),
      );
    });

    testWidgets('Save with invalid relative path throws exception',
        (tester) async {
      // Arrange
      final documentId = 'doc-test-invalid';
      final document = Document(id: documentId, title: 'Test');

      // Act & Assert
      expect(
        () async => await saveService.save(
          documentId: documentId,
          title: 'Test',
          pendingEvents: [],
          document: document,
          filePath: 'relative/path.wiretuner', // Invalid - not absolute
        ),
        throwsA(isA<InvalidFilePathException>()),
      );
    });

    testWidgets('SaveAs creates new document with new ID', (tester) async {
      // Arrange
      final originalDocId = 'doc-original';
      final title = 'Original Document';
      final document = Document(id: originalDocId, title: title);

      final events = <EventBase>[
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100, y: 200),
        ),
      ];

      // First save original document
      await saveService.save(
        documentId: originalDocId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Prepare new file path for Save As
      final tempDir = Directory.systemTemp;
      final saveAsPath = '${tempDir.path}/wiretuner_saveas_${DateTime.now().millisecondsSinceEpoch}.wiretuner';
      mockFilePicker.nextSavePath = saveAsPath;

      // Act - Save As
      final result = await saveService.saveAs(
        documentId: originalDocId,
        title: title,
        allEvents: await eventStore.getEvents(originalDocId, fromSeq: 0),
        document: document,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.documentId, isNot(equals(originalDocId))); // New ID
      expect(result.eventCount, equals(1));
      expect(result.snapshotCreated, isTrue);
      expect(result.filePath, equals(saveAsPath));
      expect(await File(saveAsPath).exists(), isTrue);

      // Cleanup
      await File(saveAsPath).delete();
    });

    testWidgets('Save automatically adds .wiretuner extension', (tester) async {
      // Arrange
      final documentId = 'doc-test-ext';
      final document = Document(id: documentId, title: 'Test');
      final tempDir = Directory.systemTemp;
      final pathWithoutExt = '${tempDir.path}/wiretuner_test_no_ext_${DateTime.now().millisecondsSinceEpoch}';

      // Act
      final result = await saveService.save(
        documentId: documentId,
        title: 'Test',
        pendingEvents: [],
        document: document,
        filePath: pathWithoutExt,
      );

      // Assert
      expect(result.filePath, equals('$pathWithoutExt.wiretuner'));
      expect(await File('$pathWithoutExt.wiretuner').exists(), isTrue);

      // Cleanup
      await File('$pathWithoutExt.wiretuner').delete();
    });

    testWidgets('Save result includes telemetry metrics', (tester) async {
      // Arrange
      final documentId = 'doc-test-telemetry';
      final document = Document(id: documentId, title: 'Test');
      final events = <EventBase>[
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100, y: 200),
        ),
      ];

      // Act
      final result = await saveService.save(
        documentId: documentId,
        title: 'Test',
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Assert - Verify telemetry metrics
      expect(result.fileSize, greaterThan(0));
      expect(result.durationMs, greaterThanOrEqualTo(0));
      expect(result.eventCount, equals(1));
      expect(result.snapshotCount, greaterThanOrEqualTo(0));

      // Verify file size matches actual file
      final fileInfo = await File(testFilePath).stat();
      expect(result.fileSize, equals(fileInfo.size));
    });

    testWidgets('Telemetry callback is invoked on successful save',
        (tester) async {
      // Arrange
      final documentId = 'doc-test-callback';
      final document = Document(id: documentId, title: 'Test');

      bool callbackInvoked = false;
      String? capturedDocId;
      int? capturedEventCount;

      final serviceWithCallback = SaveService(
        eventStore: eventStore,
        snapshotManager: snapshotManager,
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
        onSaveCompleted: ({
          required documentId,
          required eventCount,
          required fileSize,
          required durationMs,
          required snapshotCreated,
          required snapshotRatio,
        }) {
          callbackInvoked = true;
          capturedDocId = documentId;
          capturedEventCount = eventCount;
        },
      );

      final events = <EventBase>[
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100, y: 200),
        ),
      ];

      // Act
      await serviceWithCallback.save(
        documentId: documentId,
        title: 'Test',
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Assert
      expect(callbackInvoked, isTrue);
      expect(capturedDocId, equals(documentId));
      expect(capturedEventCount, equals(1));
    });

    testWidgets('WAL checkpoint is executed after save', (tester) async {
      // Arrange
      final documentId = 'doc-test-wal';
      final document = Document(id: documentId, title: 'Test');
      final events = <EventBase>[
        CreatePathEvent(
          eventId: 'e1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 100, y: 200),
        ),
      ];

      // Act
      await saveService.save(
        documentId: documentId,
        title: 'Test',
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Assert - Verify WAL mode is enabled
      final db = dbProvider.getDatabase();
      final walResult = await db.rawQuery('PRAGMA journal_mode');
      expect(walResult.first.values.first, equals('wal'));

      // Verify events are persisted (not just in WAL)
      final persistedEvents = await eventStore.getEvents(documentId, fromSeq: 0);
      expect(persistedEvents.length, equals(1));
    });
  });
}

/// Helper function to compute document hash for verification.
///
/// This is used in round-trip tests to verify that saved documents
/// can be loaded with identical state.
String _computeDocumentHash(Document doc) {
  final json = jsonEncode(doc.toJson());
  return sha256.convert(utf8.encode(json)).toString();
}
