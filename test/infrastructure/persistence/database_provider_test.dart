import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/infrastructure/persistence/database_provider.dart';

void main() {
  // Initialize FFI for tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseProvider', () {
    late DatabaseProvider provider;
    late Directory tempDir;
    late String testDbPath;

    setUp(() async {
      provider = DatabaseProvider();

      // Create a temporary directory for test databases
      tempDir = await Directory.systemTemp.createTemp('wiretuner_test_');
      testDbPath = path.join(tempDir.path, 'test.wiretuner');
    });

    tearDown(() async {
      // Close any open database connections
      if (provider.isOpen) {
        await provider.close();
      }

      // Clean up temporary files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should initialize successfully', () async {
      await provider.initialize();
      expect(provider.isInitialized, isTrue);
    });

    test('should be idempotent when initialized multiple times', () async {
      await provider.initialize();
      await provider.initialize();
      expect(provider.isInitialized, isTrue);
    });

    test('should throw StateError when opening database before initialization',
        () async {
      expect(
        () => provider.open(testDbPath),
        throwsA(isA<StateError>()),
      );
    });

    test('should open database successfully', () async {
      await provider.initialize();
      final db = await provider.open(testDbPath);

      expect(db, isNotNull);
      expect(provider.isOpen, isTrue);
      expect(await File(testDbPath).exists(), isTrue);
    });

    test('should create database file at specified absolute path', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      expect(await File(testDbPath).exists(), isTrue);
      expect(path.extension(testDbPath), equals('.wiretuner'));
    });

    test('should create database directory if it does not exist', () async {
      final nestedPath = path.join(
        tempDir.path,
        'nested',
        'directory',
        'test.wiretuner',
      );

      await provider.initialize();
      await provider.open(nestedPath);

      expect(await File(nestedPath).exists(), isTrue);
      expect(await Directory(path.dirname(nestedPath)).exists(), isTrue);
    });

    test('should add .wiretuner extension if not present (relative path)',
        () async {
      // For relative paths, the extension should be added automatically
      // We'll use an absolute path for testing but without the extension
      final pathWithoutExtension = path.join(tempDir.path, 'test_db');

      await provider.initialize();
      await provider.open(pathWithoutExtension);

      // The file should be created with the extension added
      final expectedPath = '$pathWithoutExtension.wiretuner';
      expect(await File(expectedPath).exists(), isTrue);
    });

    test('should close database successfully', () async {
      await provider.initialize();
      await provider.open(testDbPath);
      await provider.close();

      expect(provider.isOpen, isFalse);
    });

    test('should be idempotent when closing multiple times', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      await provider.close();
      await provider.close();

      expect(provider.isOpen, isFalse);
    });

    test('should return database instance via getDatabase()', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      final db = provider.getDatabase();
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('should throw StateError when calling getDatabase() with no open database',
        () async {
      await provider.initialize();

      expect(
        () => provider.getDatabase(),
        throwsA(isA<StateError>()),
      );
    });

    test('should close existing connection when opening a new database',
        () async {
      final firstDbPath = path.join(tempDir.path, 'first.wiretuner');
      final secondDbPath = path.join(tempDir.path, 'second.wiretuner');

      await provider.initialize();
      await provider.open(firstDbPath);

      expect(provider.isOpen, isTrue);
      expect(await File(firstDbPath).exists(), isTrue);

      // Open second database - should close first one
      await provider.open(secondDbPath);

      expect(provider.isOpen, isTrue);
      expect(await File(secondDbPath).exists(), isTrue);
    });

    test('should handle database operations (basic query)', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      final db = provider.getDatabase();

      // Create a simple test table
      await db.execute('''
        CREATE TABLE test_table (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');

      // Insert test data
      await db.insert('test_table', {'id': 1, 'name': 'Test'});

      // Query test data
      final results = await db.query('test_table');
      expect(results.length, equals(1));
      expect(results.first['name'], equals('Test'));
    });

    test('should verify database is created with correct schema version',
        () async {
      await provider.initialize();
      final db = await provider.open(testDbPath);

      final version = await db.getVersion();
      expect(version, equals(DatabaseProvider.currentSchemaVersion));
    });

    test('should handle transaction operations', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      final db = provider.getDatabase();

      // Create a test table
      await db.execute('''
        CREATE TABLE test_table (
          id INTEGER PRIMARY KEY,
          value TEXT
        )
      ''');

      // Perform operations in a transaction
      await db.transaction((txn) async {
        await txn.insert('test_table', {'id': 1, 'value': 'First'});
        await txn.insert('test_table', {'id': 2, 'value': 'Second'});
      });

      final results = await db.query('test_table');
      expect(results.length, equals(2));
    });

    test('should handle opening non-existent database', () async {
      // Opening a non-existent database should create it
      await provider.initialize();
      final newDbPath = path.join(tempDir.path, 'new_database.wiretuner');

      expect(await File(newDbPath).exists(), isFalse);

      await provider.open(newDbPath);

      expect(await File(newDbPath).exists(), isTrue);
      expect(provider.isOpen, isTrue);
    });

    test('should properly clean up resources on close', () async {
      await provider.initialize();
      await provider.open(testDbPath);

      final db = provider.getDatabase();
      expect(db.isOpen, isTrue);

      await provider.close();

      // After close, isOpen should be false
      expect(provider.isOpen, isFalse);

      // Trying to get database should throw
      expect(
        () => provider.getDatabase(),
        throwsA(isA<StateError>()),
      );
    });

    test('should handle multiple databases in sequence', () async {
      await provider.initialize();

      // Open first database
      final db1Path = path.join(tempDir.path, 'db1.wiretuner');
      await provider.open(db1Path);
      await provider.close();

      // Open second database
      final db2Path = path.join(tempDir.path, 'db2.wiretuner');
      await provider.open(db2Path);
      await provider.close();

      // Verify both files exist
      expect(await File(db1Path).exists(), isTrue);
      expect(await File(db2Path).exists(), isTrue);
    });
  });
}
