import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiretuner/infrastructure/persistence/schema.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SchemaManager', () {
    late Database db;

    setUp(() async {
      // Create a fresh in-memory database for each test
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('createSchema creates all required tables', () async {
      // Act
      await SchemaManager.createSchema(db);

      // Assert - Query sqlite_master to verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('metadata'));
      expect(tableNames, contains('events'));
      expect(tableNames, contains('snapshots'));
    });

    test('metadata table has correct schema', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Check column definitions
      final columns = await db.rawQuery('PRAGMA table_info(metadata)');

      // Convert to a map for easier assertion
      final columnMap = {
        for (var col in columns) col['name'] as String: col,
      };

      // Verify all required columns exist
      expect(
        columnMap.keys,
        containsAll(
          [
            'document_id',
            'title',
            'format_version',
            'created_at',
            'modified_at',
            'author',
          ],
        ),
      );

      // Verify primary key
      expect(columnMap['document_id']!['pk'], 1);

      // Verify data types
      expect(columnMap['document_id']!['type'], 'TEXT');
      expect(columnMap['title']!['type'], 'TEXT');
      expect(columnMap['format_version']!['type'], 'INTEGER');
      expect(columnMap['created_at']!['type'], 'INTEGER');
      expect(columnMap['modified_at']!['type'], 'INTEGER');
      expect(columnMap['author']!['type'], 'TEXT');

      // Verify NOT NULL constraints
      // Note: PRIMARY KEY columns are implicitly NOT NULL in SQLite,
      // but the notnull flag may show as 0. We verify the PK instead.
      expect(columnMap['title']!['notnull'], 1);
      expect(columnMap['format_version']!['notnull'], 1);
      expect(columnMap['created_at']!['notnull'], 1);
      expect(columnMap['modified_at']!['notnull'], 1);
      expect(columnMap['author']!['notnull'], 0); // Optional
    });

    test('events table has correct schema', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Check column definitions
      final columns = await db.rawQuery('PRAGMA table_info(events)');

      final columnMap = {
        for (var col in columns) col['name'] as String: col,
      };

      // Verify all required columns exist
      expect(
        columnMap.keys,
        containsAll(
          [
            'event_id',
            'document_id',
            'event_sequence',
            'event_type',
            'event_payload',
            'timestamp',
            'user_id',
          ],
        ),
      );

      // Verify primary key (AUTOINCREMENT)
      expect(columnMap['event_id']!['pk'], 1);

      // Verify data types
      expect(columnMap['event_id']!['type'], 'INTEGER');
      expect(columnMap['document_id']!['type'], 'TEXT');
      expect(columnMap['event_sequence']!['type'], 'INTEGER');
      expect(columnMap['event_type']!['type'], 'TEXT');
      expect(columnMap['event_payload']!['type'], 'TEXT');
      expect(columnMap['timestamp']!['type'], 'INTEGER');
      expect(columnMap['user_id']!['type'], 'TEXT');

      // Verify NOT NULL constraints
      expect(columnMap['document_id']!['notnull'], 1);
      expect(columnMap['event_sequence']!['notnull'], 1);
      expect(columnMap['event_type']!['notnull'], 1);
      expect(columnMap['event_payload']!['notnull'], 1);
      expect(columnMap['timestamp']!['notnull'], 1);
      expect(columnMap['user_id']!['notnull'], 0); // Optional
    });

    test('events table has UNIQUE constraint on (document_id, event_sequence)',
        () async {
      // Arrange
      await SchemaManager.createSchema(db);

      // Insert test metadata
      await db.insert('metadata', {
        'document_id': 'doc1',
        'title': 'Test Document',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      // Insert first event
      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 0,
        'event_type': 'CreatePath',
        'event_payload': '{}',
        'timestamp': 1234567890,
      });

      // Act & Assert - Try to insert duplicate sequence number
      expect(
        () async => await db.insert('events', {
          'document_id': 'doc1',
          'event_sequence': 0, // Duplicate
          'event_type': 'MovePath',
          'event_payload': '{}',
          'timestamp': 1234567891,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('snapshots table has correct schema', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Check column definitions
      final columns = await db.rawQuery('PRAGMA table_info(snapshots)');

      final columnMap = {
        for (var col in columns) col['name'] as String: col,
      };

      // Verify all required columns exist
      expect(
        columnMap.keys,
        containsAll(
          [
            'snapshot_id',
            'document_id',
            'event_sequence',
            'snapshot_data',
            'created_at',
            'compression',
          ],
        ),
      );

      // Verify primary key
      expect(columnMap['snapshot_id']!['pk'], 1);

      // Verify data types
      expect(columnMap['snapshot_id']!['type'], 'INTEGER');
      expect(columnMap['document_id']!['type'], 'TEXT');
      expect(columnMap['event_sequence']!['type'], 'INTEGER');
      expect(columnMap['snapshot_data']!['type'], 'BLOB');
      expect(columnMap['created_at']!['type'], 'INTEGER');
      expect(columnMap['compression']!['type'], 'TEXT');

      // Verify NOT NULL constraints
      expect(columnMap['document_id']!['notnull'], 1);
      expect(columnMap['event_sequence']!['notnull'], 1);
      expect(columnMap['snapshot_data']!['notnull'], 1);
      expect(columnMap['created_at']!['notnull'], 1);
      expect(columnMap['compression']!['notnull'], 1);
    });

    test('foreign key constraints are enforced', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      // Act & Assert - Try to insert event without corresponding metadata
      expect(
        () async => await db.insert('events', {
          'document_id': 'nonexistent_doc',
          'event_sequence': 0,
          'event_type': 'CreatePath',
          'event_payload': '{}',
          'timestamp': 1234567890,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('CASCADE delete removes related events and snapshots', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      // Insert metadata
      await db.insert('metadata', {
        'document_id': 'doc1',
        'title': 'Test Document',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      // Insert events
      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 0,
        'event_type': 'CreatePath',
        'event_payload': '{}',
        'timestamp': 1234567890,
      });

      // Insert snapshot
      await db.insert('snapshots', {
        'document_id': 'doc1',
        'event_sequence': 0,
        'snapshot_data': Uint8List.fromList([1, 2, 3]),
        'created_at': 1234567890,
        'compression': 'none',
      });

      // Act - Delete metadata
      await db
          .delete('metadata', where: 'document_id = ?', whereArgs: ['doc1']);

      // Assert - Events and snapshots should be deleted
      final remainingEvents = await db.query('events');
      final remainingSnapshots = await db.query('snapshots');

      expect(remainingEvents, isEmpty);
      expect(remainingSnapshots, isEmpty);
    });

    test('idx_events_document_sequence index is created', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Query sqlite_master for the index
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_events_document_sequence'",
      );

      expect(indexes, hasLength(1));
      expect(indexes[0]['name'], 'idx_events_document_sequence');
    });

    test('idx_snapshots_document index is created', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Query sqlite_master for the index
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_snapshots_document'",
      );

      expect(indexes, hasLength(1));
      expect(indexes[0]['name'], 'idx_snapshots_document');
    });

    test('WAL mode is enabled (or memory mode for in-memory db)', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Check journal mode
      // Note: In-memory databases use 'memory' journal mode, not WAL
      final result = await db.rawQuery('PRAGMA journal_mode');
      final journalMode = result[0]['journal_mode'] as String;
      expect(journalMode.toLowerCase(), anyOf('wal', 'memory'));
    });

    test('foreign keys are enabled', () async {
      // Arrange & Act
      await SchemaManager.createSchema(db);

      // Assert - Check foreign key setting
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result[0]['foreign_keys'], 1);
    });

    test('verifySchema returns true for valid schema', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      // Act
      final isValid = await SchemaManager.verifySchema(db);

      // Assert
      expect(isValid, isTrue);
    });

    test('verifySchema returns false for incomplete schema', () async {
      // Arrange - Create only one table
      await db.execute('''
        CREATE TABLE metadata (
          document_id TEXT PRIMARY KEY
        )
      ''');

      // Act
      final isValid = await SchemaManager.verifySchema(db);

      // Assert
      expect(isValid, isFalse);
    });

    test('events can be inserted and queried in sequence order', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      await db.insert('metadata', {
        'document_id': 'doc1',
        'title': 'Test Document',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      // Insert events in random order
      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 2,
        'event_type': 'Event2',
        'event_payload': '{}',
        'timestamp': 1234567892,
      });

      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 0,
        'event_type': 'Event0',
        'event_payload': '{}',
        'timestamp': 1234567890,
      });

      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 1,
        'event_type': 'Event1',
        'event_payload': '{}',
        'timestamp': 1234567891,
      });

      // Act - Query events using the index (document_id, event_sequence)
      final events = await db.query(
        'events',
        where: 'document_id = ?',
        whereArgs: ['doc1'],
        orderBy: 'event_sequence ASC',
      );

      // Assert - Events should be in sequence order
      expect(events, hasLength(3));
      expect(events[0]['event_type'], 'Event0');
      expect(events[0]['event_sequence'], 0);
      expect(events[1]['event_type'], 'Event1');
      expect(events[1]['event_sequence'], 1);
      expect(events[2]['event_type'], 'Event2');
      expect(events[2]['event_sequence'], 2);
    });

    test('snapshots can store and retrieve BLOB data', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      await db.insert('metadata', {
        'document_id': 'doc1',
        'title': 'Test Document',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      // Create some binary data
      final snapshotData = Uint8List.fromList(
        List<int>.generate(1000, (i) => i % 256),
      );

      // Act - Insert snapshot
      await db.insert('snapshots', {
        'document_id': 'doc1',
        'event_sequence': 999,
        'snapshot_data': snapshotData,
        'created_at': 1234567890,
        'compression': 'gzip',
      });

      // Retrieve snapshot
      final snapshots = await db.query(
        'snapshots',
        where: 'document_id = ?',
        whereArgs: ['doc1'],
      );

      // Assert
      expect(snapshots, hasLength(1));
      expect(snapshots[0]['compression'], 'gzip');

      final retrievedData = snapshots[0]['snapshot_data'] as Uint8List;
      expect(retrievedData, equals(snapshotData));
    });

    test('multiple documents can have independent event sequences', () async {
      // Arrange
      await SchemaManager.createSchema(db);

      // Insert metadata for two documents
      await db.insert('metadata', {
        'document_id': 'doc1',
        'title': 'Document 1',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      await db.insert('metadata', {
        'document_id': 'doc2',
        'title': 'Document 2',
        'format_version': 1,
        'created_at': 1234567890,
        'modified_at': 1234567890,
      });

      // Act - Insert events with same sequence numbers for different documents
      await db.insert('events', {
        'document_id': 'doc1',
        'event_sequence': 0,
        'event_type': 'Doc1Event0',
        'event_payload': '{}',
        'timestamp': 1234567890,
      });

      await db.insert('events', {
        'document_id': 'doc2',
        'event_sequence': 0,
        'event_type': 'Doc2Event0',
        'event_payload': '{}',
        'timestamp': 1234567890,
      });

      // Assert - Both inserts should succeed
      final doc1Events = await db.query(
        'events',
        where: 'document_id = ?',
        whereArgs: ['doc1'],
      );

      final doc2Events = await db.query(
        'events',
        where: 'document_id = ?',
        whereArgs: ['doc2'],
      );

      expect(doc1Events, hasLength(1));
      expect(doc1Events[0]['event_type'], 'Doc1Event0');
      expect(doc2Events, hasLength(1));
      expect(doc2Events[0]['event_type'], 'Doc2Event0');
    });
  });
}
