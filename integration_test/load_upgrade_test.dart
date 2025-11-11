import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/api/event_schema.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as wire_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart';
import 'package:wiretuner/infrastructure/event_sourcing/snapshot_manager.dart';
import 'package:wiretuner/infrastructure/file_ops/file_picker_adapter.dart';
import 'package:wiretuner/infrastructure/file_ops/load_exceptions.dart';
import 'package:wiretuner/infrastructure/file_ops/load_service.dart';
import 'package:wiretuner/infrastructure/file_ops/save_service.dart';
import 'package:wiretuner/infrastructure/file_ops/version_migrator.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Load Document Integration Tests', () {
    late String testFilePath;
    late DatabaseProvider dbProvider;
    late LoadService loadService;
    late SaveService saveService;
    late MockFilePickerAdapter mockFilePicker;
    late EventStore eventStore;
    late SnapshotStore snapshotStore;
    late EventReplayer eventReplayer;
    late wire_dispatcher.EventDispatcher eventDispatcher;

    setUp(() async {
      // Initialize SQLite FFI for desktop testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Generate unique test file path in system temp directory
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory.systemTemp;
      testFilePath = '${tempDir.path}/wiretuner_load_test_$timestamp.wiretuner';

      // Initialize database provider
      dbProvider = DatabaseProvider();
      await dbProvider.initialize();

      // Create mock file picker
      mockFilePicker = MockFilePickerAdapter();
      mockFilePicker.nextOpenPath = testFilePath;
      mockFilePicker.nextSavePath = testFilePath;

      // Open database and create dependencies
      final db = await dbProvider.open(testFilePath);
      eventStore = EventStore(db);
      snapshotStore = SnapshotStore(db);

      // Create event registry and dispatcher
      final registry = EventHandlerRegistry();
      eventDispatcher = wire_dispatcher.EventDispatcher(registry);

      // Create event replayer
      eventReplayer = EventReplayer(
        eventStore: eventStore,
        snapshotStore: snapshotStore,
        dispatcher: eventDispatcher,
      );

      // Create snapshot manager
      final snapshotManager = SnapshotManager(snapshotStore: snapshotStore);

      // Create save service (for test setup)
      saveService = SaveService(
        eventStore: eventStore,
        snapshotManager: snapshotManager,
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
      );

      // Create load service
      loadService = LoadService(
        eventStore: eventStore,
        snapshotStore: snapshotStore,
        eventReplayer: eventReplayer,
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
        versionMigrator: VersionMigrator(),
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

    testWidgets('Load document with snapshot and delta events', (tester) async {
      // Arrange - Create document with 1500 events (triggers snapshot at 1000)
      final documentId = 'doc-load-1';
      final title = 'Load Test Document';
      final document = Document(id: documentId, title: title);

      final events = List.generate(
        1500,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );

      // Save document
      await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Act - Load document
      final result = await loadService.load(filePath: testFilePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.documentId, equals(documentId));
      expect(result.eventCount, equals(1500));
      expect(result.snapshotUsed, isTrue);
      expect(result.eventsReplayed, lessThan(1500)); // Should use snapshot
      expect(result.hadIssues, isFalse);
      expect(result.document.id, equals(documentId));
      expect(result.document.title, equals(title));
    });

    testWidgets('Load document without snapshot (full replay)', (tester) async {
      // Arrange - Create document with < 1000 events (no snapshot)
      final documentId = 'doc-load-2';
      final title = 'No Snapshot Document';
      final document = Document(id: documentId, title: title);

      final events = List.generate(
        500,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );

      // Save document
      await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Act - Load document
      final result = await loadService.load(filePath: testFilePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.documentId, equals(documentId));
      expect(result.eventCount, equals(500));
      expect(result.eventsReplayed, equals(500)); // Full replay (no snapshot)
      expect(result.hadIssues, isFalse);
    });

    testWidgets('Load document with corrupt events shows warning', (tester) async {
      // Arrange - Create document with valid events
      final documentId = 'doc-corrupt';
      final title = 'Corrupt Events Document';
      final document = Document(id: documentId, title: title);

      final events = List.generate(
        100,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );

      // Save document
      await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Corrupt an event by manually modifying the database
      final db = dbProvider.getDatabase();
      await db.rawUpdate(
        'UPDATE events SET event_payload = ? WHERE event_sequence = ?',
        ['{"invalid": "json', 50], // Invalid JSON
      );

      // Setup warning callback
      bool warningCalled = false;
      int capturedSkippedCount = 0;
      List<String> capturedWarnings = [];

      final loadServiceWithCallback = LoadService(
        eventStore: EventStore(await dbProvider.open(testFilePath)),
        snapshotStore: SnapshotStore(dbProvider.getDatabase()),
        eventReplayer: EventReplayer(
          eventStore: EventStore(dbProvider.getDatabase()),
          snapshotStore: SnapshotStore(dbProvider.getDatabase()),
          dispatcher: eventDispatcher,
        ),
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
        onLoadWarning: ({
          required message,
          required skippedCount,
          required warnings,
        }) {
          warningCalled = true;
          capturedSkippedCount = skippedCount;
          capturedWarnings = warnings;
        },
      );

      // Act - Load document with corrupt events
      final result = await loadServiceWithCallback.load(filePath: testFilePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.hadIssues, isTrue);
      expect(result.skippedEventCount, greaterThan(0));
      expect(warningCalled, isTrue);
      expect(capturedSkippedCount, greaterThan(0));
      expect(capturedWarnings.isNotEmpty, isTrue);
    });

    testWidgets('Load throws FileNotFoundException if file does not exist',
        (tester) async {
      // Arrange
      final nonExistentPath = '/tmp/nonexistent_${DateTime.now().millisecondsSinceEpoch}.wiretuner';

      // Act & Assert
      expect(
        () async => await loadService.load(filePath: nonExistentPath),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    testWidgets('Load throws InvalidFilePathException for non-.wiretuner file',
        (tester) async {
      // Arrange - Create a file without .wiretuner extension
      final tempDir = Directory.systemTemp;
      final invalidPath = '${tempDir.path}/test_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(invalidPath).writeAsString('test');

      // Act & Assert
      expect(
        () async => await loadService.load(filePath: invalidPath),
        throwsA(isA<InvalidFilePathException>()),
      );

      // Cleanup
      await File(invalidPath).delete();
    });

    testWidgets('Load throws LoadCancelledException when user cancels',
        (tester) async {
      // Arrange
      mockFilePicker.simulateCancellation = true;

      // Act & Assert
      expect(
        () async => await loadService.load(), // No filePath triggers dialog
        throwsA(isA<LoadCancelledException>()),
      );
    });

    testWidgets('Load throws CorruptDatabaseException if metadata missing',
        (tester) async {
      // Arrange - Create database without metadata
      final corruptPath = '${Directory.systemTemp.path}/corrupt_${DateTime.now().millisecondsSinceEpoch}.wiretuner';
      final corruptDb = await databaseFactory.openDatabase(
        corruptPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            // Create events table but NOT metadata table
            await db.execute('''
              CREATE TABLE events (
                event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id TEXT NOT NULL,
                event_sequence INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                event_payload TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                user_id TEXT
              )
            ''');
          },
        ),
      );
      await corruptDb.close();

      // Act & Assert
      expect(
        () async => await loadService.load(filePath: corruptPath),
        throwsA(isA<CorruptDatabaseException>()),
      );

      // Cleanup
      await File(corruptPath).delete();
    });

    testWidgets('Load throws VersionMismatchException if format version too new',
        (tester) async {
      // Arrange - Create document and manually update format version to future version
      final documentId = 'doc-version';
      final document = Document(id: documentId, title: 'Version Test');

      await saveService.save(
        documentId: documentId,
        title: 'Version Test',
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Update format_version to 99 (future version)
      final db = dbProvider.getDatabase();
      await db.rawUpdate(
        'UPDATE metadata SET format_version = ?',
        [99],
      );

      // Act & Assert
      expect(
        () async => await loadService.load(filePath: testFilePath),
        throwsA(isA<VersionMismatchException>()),
      );
    });

    testWidgets('Round-trip: Save and load produces identical document',
        (tester) async {
      // Arrange - Create document with various elements
      final documentId = 'doc-roundtrip';
      final title = 'Round-Trip Test';
      final document = Document(
        id: documentId,
        title: title,
        schemaVersion: kDocumentSchemaVersion,
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
          timestamp: DateTime.now().millisecondsSinceEpoch + 1,
          pathId: 'path-1',
          position: const Point(x: 200, y: 300),
        ),
      ];

      // Act - Save document
      final saveResult = await saveService.save(
        documentId: documentId,
        title: title,
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      expect(saveResult.success, isTrue);

      // Load document
      final loadResult = await loadService.load(filePath: testFilePath);

      // Assert - Verify document properties match
      expect(loadResult.success, isTrue);
      expect(loadResult.documentId, equals(documentId));
      expect(loadResult.document.id, equals(document.id));
      expect(loadResult.document.title, equals(document.title));
      expect(loadResult.document.schemaVersion, equals(document.schemaVersion));
      expect(loadResult.eventCount, equals(events.length));
    });

    testWidgets('Load telemetry callback is invoked', (tester) async {
      // Arrange - Create document
      final documentId = 'doc-telemetry';
      final document = Document(id: documentId, title: 'Telemetry Test');

      await saveService.save(
        documentId: documentId,
        title: 'Telemetry Test',
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Setup telemetry callback
      bool callbackInvoked = false;
      String? capturedDocId;
      int? capturedEventCount;

      final loadServiceWithCallback = LoadService(
        eventStore: EventStore(await dbProvider.open(testFilePath)),
        snapshotStore: SnapshotStore(dbProvider.getDatabase()),
        eventReplayer: EventReplayer(
          eventStore: EventStore(dbProvider.getDatabase()),
          snapshotStore: SnapshotStore(dbProvider.getDatabase()),
          dispatcher: eventDispatcher,
        ),
        dbProvider: dbProvider,
        filePickerAdapter: mockFilePicker,
        onLoadCompleted: ({
          required documentId,
          required eventCount,
          required fileSize,
          required durationMs,
          required snapshotUsed,
          required eventsReplayed,
        }) {
          callbackInvoked = true;
          capturedDocId = documentId;
          capturedEventCount = eventCount;
        },
      );

      // Act - Load document
      await loadServiceWithCallback.load(filePath: testFilePath);

      // Assert
      expect(callbackInvoked, isTrue);
      expect(capturedDocId, equals(documentId));
      expect(capturedEventCount, greaterThanOrEqualTo(0));
    });

    testWidgets('Load result includes telemetry metrics', (tester) async {
      // Arrange - Create document
      final documentId = 'doc-metrics';
      final document = Document(id: documentId, title: 'Metrics Test');

      final events = List.generate(
        100,
        (i) => CreatePathEvent(
          eventId: 'e$i',
          timestamp: DateTime.now().millisecondsSinceEpoch + i,
          pathId: 'path-$i',
          startAnchor: Point(x: i.toDouble(), y: i.toDouble()),
        ),
      );

      await saveService.save(
        documentId: documentId,
        title: 'Metrics Test',
        pendingEvents: events,
        document: document,
        filePath: testFilePath,
      );

      // Act - Load document
      final result = await loadService.load(filePath: testFilePath);

      // Assert - Verify telemetry metrics
      expect(result.fileSize, greaterThan(0));
      expect(result.durationMs, greaterThanOrEqualTo(0));
      expect(result.eventCount, equals(100));
      expect(result.eventsReplayed, greaterThanOrEqualTo(0));

      // Verify file size matches actual file
      final fileInfo = await File(testFilePath).stat();
      expect(result.fileSize, equals(fileInfo.size));
    });

    testWidgets('Load opens file picker when no path provided', (tester) async {
      // Arrange - Create document
      final documentId = 'doc-picker';
      final document = Document(id: documentId, title: 'Picker Test');

      await saveService.save(
        documentId: documentId,
        title: 'Picker Test',
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Mock file picker returns test file path
      mockFilePicker.nextOpenPath = testFilePath;

      // Act - Load without file path (triggers picker)
      final result = await loadService.load(); // No filePath argument

      // Assert
      expect(result.success, isTrue);
      expect(result.filePath, equals(testFilePath));
    });

    testWidgets('Load handles empty document (no events)', (tester) async {
      // Arrange - Create document with no events
      final documentId = 'doc-empty';
      final document = Document(id: documentId, title: 'Empty Document');

      await saveService.save(
        documentId: documentId,
        title: 'Empty Document',
        pendingEvents: [],
        document: document,
        filePath: testFilePath,
      );

      // Act - Load document
      final result = await loadService.load(filePath: testFilePath);

      // Assert
      expect(result.success, isTrue);
      expect(result.eventCount, equals(0));
      expect(result.eventsReplayed, equals(0));
      expect(result.hadIssues, isFalse);
    });
  });

  group('Version Migration Integration Tests', () {
    late String migrationTestFilePath;
    late DatabaseProvider migrationDbProvider;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory.systemTemp;
      migrationTestFilePath = '${tempDir.path}/wiretuner_migration_test_$timestamp.wiretuner';

      migrationDbProvider = DatabaseProvider();
      await migrationDbProvider.initialize();
    });

    tearDown(() async {
      if (migrationDbProvider.isOpen) {
        await migrationDbProvider.close();
      }

      if (await File(migrationTestFilePath).exists()) {
        await File(migrationTestFilePath).delete();
      }
    });

    testWidgets('Version migrator handles v1 database (no migration needed)',
        (tester) async {
      // Arrange - Create v1 database
      final db = await migrationDbProvider.open(migrationTestFilePath);

      // Insert metadata with format_version = 1
      await db.insert('metadata', {
        'document_id': 'doc-v1',
        'title': 'Version 1 Document',
        'format_version': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
        'author': null,
      });

      await migrationDbProvider.close();

      // Create load service with migrator
      final mockFilePicker = MockFilePickerAdapter();
      mockFilePicker.nextOpenPath = migrationTestFilePath;

      // Create dependencies (database will be reopened by LoadService)
      final migrationDb = await migrationDbProvider.open(migrationTestFilePath);
      final registry = EventHandlerRegistry();
      final migrationLoadService = LoadService(
        eventStore: EventStore(migrationDb),
        snapshotStore: SnapshotStore(migrationDb),
        eventReplayer: EventReplayer(
          eventStore: EventStore(migrationDb),
          snapshotStore: SnapshotStore(migrationDb),
          dispatcher: wire_dispatcher.EventDispatcher(registry),
        ),
        dbProvider: migrationDbProvider,
        filePickerAdapter: mockFilePicker,
        versionMigrator: VersionMigrator(),
      );

      // Act - Load v1 document
      final result = await migrationLoadService.load(filePath: migrationTestFilePath);

      // Assert - Should load successfully without migration
      expect(result.success, isTrue);
      expect(result.documentId, equals('doc-v1'));

      // Verify format_version is still 1 (no migration needed)
      final metadata = await migrationDbProvider.getDatabase().query('metadata');
      expect(metadata.first['format_version'], equals(1));
    });
  });
}
