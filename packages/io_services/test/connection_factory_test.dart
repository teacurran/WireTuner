import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:io_services/io_services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI and Flutter bindings once for all tests
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  group('ConnectionFactory', () {
    late ConnectionFactory factory;

    setUp(() {
      factory = ConnectionFactory();
    });

    tearDown(() async {
      // Clean up all connections after each test
      try {
        await factory.closeAll();
      } catch (_) {
        // Ignore errors during cleanup
      }
    });

    group('initialize()', () {
      test('initializes SQLite FFI successfully', () async {
        await factory.initialize();
        expect(factory.isInitialized, isTrue);
      });

      test('is idempotent (safe to call multiple times)', () async {
        await factory.initialize();
        await factory.initialize(); // Should not throw
        expect(factory.isInitialized, isTrue);
      });
    });

    group('openConnection()', () {
      setUp(() async {
        await factory.initialize();
      });

      test('opens in-memory database successfully', () async {
        final db = await factory.openConnection(
          documentId: 'test-doc',
          config: DatabaseConfig.inMemory(),
        );

        expect(db, isNotNull);
        expect(factory.activeConnectionCount, equals(1));
      });

      test('opens file-based database successfully', () async {
        // Use absolute path for tests (path_provider not available in unit tests)
        final tempDir = Directory.systemTemp.createTempSync('wiretuner_test_');
        final dbPath = path.join(tempDir.path, 'test_document.wiretuner');

        final db = await factory.openConnection(
          documentId: 'file-doc',
          config: DatabaseConfig.file(filePath: dbPath),
        );

        expect(db, isNotNull);
        expect(factory.activeConnectionCount, equals(1));

        // Cleanup
        await factory.closeConnection('file-doc');
        await tempDir.delete(recursive: true);
      });

      test('reuses existing connection for same documentId', () async {
        final db1 = await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        final db2 = await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        expect(identical(db1, db2), isTrue);
        expect(factory.activeConnectionCount, equals(1));
      });

      test('creates separate connections for different documentIds', () async {
        final db1 = await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        final db2 = await factory.openConnection(
          documentId: 'doc-2',
          config: DatabaseConfig.inMemory(),
        );

        expect(identical(db1, db2), isFalse);
        expect(factory.activeConnectionCount, equals(2));
      });

      test('runs migrations by default', () async {
        final db = await factory.openConnection(
          documentId: 'migrated-doc',
          config: DatabaseConfig.inMemory(),
        );

        // Verify schema was created
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
        );

        expect(tables, hasLength(3));
      });

      test('skips migrations when runMigrations=false', () async {
        final db = await factory.openConnection(
          documentId: 'no-migration-doc',
          config: DatabaseConfig.inMemory(),
          runMigrations: false,
        );

        // Verify schema was NOT created
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('metadata', 'events', 'snapshots')",
        );

        expect(tables, isEmpty);
      });

      test('enables foreign keys for all connections', () async {
        final db = await factory.openConnection(
          documentId: 'fk-doc',
          config: DatabaseConfig.inMemory(),
        );

        final result = await db.rawQuery('PRAGMA foreign_keys');
        expect(result.first['foreign_keys'], equals(1));
      });

      test('throws StateError if not initialized', () async {
        final uninitializedFactory = ConnectionFactory();

        expect(
          () => uninitializedFactory.openConnection(
            documentId: 'doc',
            config: DatabaseConfig.inMemory(),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('closeConnection()', () {
      setUp(() async {
        await factory.initialize();
      });

      test('closes specific connection', () async {
        await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        await factory.openConnection(
          documentId: 'doc-2',
          config: DatabaseConfig.inMemory(),
        );

        expect(factory.activeConnectionCount, equals(2));

        await factory.closeConnection('doc-1');

        expect(factory.activeConnectionCount, equals(1));
        expect(factory.hasConnection('doc-1'), isFalse);
        expect(factory.hasConnection('doc-2'), isTrue);
      });

      test('is idempotent (safe to close non-existent connection)', () async {
        await factory.closeConnection('nonexistent-doc'); // Should not throw
        expect(factory.activeConnectionCount, equals(0));
      });
    });

    group('closeAll()', () {
      setUp(() async {
        await factory.initialize();
      });

      test('closes all active connections', () async {
        await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        await factory.openConnection(
          documentId: 'doc-2',
          config: DatabaseConfig.inMemory(),
        );

        await factory.openConnection(
          documentId: 'doc-3',
          config: DatabaseConfig.inMemory(),
        );

        expect(factory.activeConnectionCount, equals(3));

        await factory.closeAll();

        expect(factory.activeConnectionCount, equals(0));
      });

      test('is idempotent (safe to call when no connections)', () async {
        await factory.closeAll(); // Should not throw
        expect(factory.activeConnectionCount, equals(0));
      });
    });

    group('hasConnection()', () {
      setUp(() async {
        await factory.initialize();
      });

      test('returns true for existing connection', () async {
        await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        expect(factory.hasConnection('doc-1'), isTrue);
      });

      test('returns false for non-existent connection', () {
        expect(factory.hasConnection('nonexistent-doc'), isFalse);
      });
    });

    group('getConnection()', () {
      setUp(() async {
        await factory.initialize();
      });

      test('returns existing connection', () async {
        final db = await factory.openConnection(
          documentId: 'doc-1',
          config: DatabaseConfig.inMemory(),
        );

        final retrieved = factory.getConnection('doc-1');
        expect(identical(db, retrieved), isTrue);
      });

      test('throws StateError for non-existent connection', () {
        expect(
          () => factory.getConnection('nonexistent-doc'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('multi-window isolation', () {
      setUp(() async {
        await factory.initialize();
      });

      test('multiple windows can have independent connections', () async {
        // Simulate two windows opening different documents
        final db1 = await factory.openConnection(
          documentId: 'window1-doc',
          config: DatabaseConfig.inMemory(),
        );

        final db2 = await factory.openConnection(
          documentId: 'window2-doc',
          config: DatabaseConfig.inMemory(),
        );

        // Create metadata in first database
        await db1.insert('metadata', {
          'document_id': 'doc1',
          'title': 'Window 1 Document',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        // Create metadata in second database
        await db2.insert('metadata', {
          'document_id': 'doc2',
          'title': 'Window 2 Document',
          'format_version': 1,
          'created_at': 1234567890,
          'modified_at': 1234567890,
        });

        // Verify isolation
        final db1Metadata = await db1.query('metadata');
        final db2Metadata = await db2.query('metadata');

        expect(db1Metadata, hasLength(1));
        expect(db2Metadata, hasLength(1));
        expect(db1Metadata.first['title'], 'Window 1 Document');
        expect(db2Metadata.first['title'], 'Window 2 Document');
      });
    });

    group('WAL mode', () {
      setUp(() async {
        await factory.initialize();
      });

      test('file-based databases use WAL mode', () async {
        // Use absolute path for tests (path_provider not available in unit tests)
        final tempDir = Directory.systemTemp.createTempSync('wiretuner_test_');
        final dbPath = path.join(tempDir.path, 'wal_test.wiretuner');

        final db = await factory.openConnection(
          documentId: 'wal-doc',
          config: DatabaseConfig.file(filePath: dbPath),
        );

        final result = await db.rawQuery('PRAGMA journal_mode');
        final journalMode = result.first['journal_mode'] as String;
        expect(journalMode.toLowerCase(), equals('wal'));

        // Cleanup
        await factory.closeConnection('wal-doc');
        await tempDir.delete(recursive: true);
      });

      test('in-memory databases use memory journal mode', () async {
        final db = await factory.openConnection(
          documentId: 'memory-doc',
          config: DatabaseConfig.inMemory(),
        );

        final result = await db.rawQuery('PRAGMA journal_mode');
        final journalMode = result.first['journal_mode'] as String;
        expect(journalMode.toLowerCase(), equals('memory'));
      });
    });
  });

  group('DatabaseConfig', () {
    test('file config stores file path', () {
      final config = DatabaseConfig.file(filePath: 'test.wiretuner');
      expect(config.filePath, equals('test.wiretuner'));
      expect(config.isInMemory, isFalse);
    });

    test('in-memory config has null file path', () {
      final config = DatabaseConfig.inMemory();
      expect(config.filePath, isNull);
      expect(config.isInMemory, isTrue);
    });

    test('getPath() returns inMemoryDatabasePath for in-memory config', () {
      final config = DatabaseConfig.inMemory();
      expect(config.getPath(), equals(inMemoryDatabasePath));
    });

    test('getPath() returns file path for file config', () {
      final config = DatabaseConfig.file(filePath: 'test.wiretuner');
      expect(config.getPath(), equals('test.wiretuner'));
    });

    test('equality works correctly', () {
      final config1 = DatabaseConfig.file(filePath: 'test.wiretuner');
      final config2 = DatabaseConfig.file(filePath: 'test.wiretuner');
      final config3 = DatabaseConfig.file(filePath: 'other.wiretuner');
      final config4 = DatabaseConfig.inMemory();

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1, isNot(equals(config4)));
    });
  });
}
