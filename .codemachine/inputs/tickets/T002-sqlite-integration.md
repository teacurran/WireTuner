# T002: SQLite Integration and Database Connection

## Status
- **Phase**: 0 - Foundation & Setup
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T001

## Overview
Integrate SQLite database support into the Flutter application. This establishes the foundation for the event-sourced file format (.wiretuner files).

## Objectives
- Add SQLite dependencies to the project
- Create database service layer
- Implement database connection management
- Create initial database schema
- Verify database operations work on both platforms

## Requirements

### Functional Requirements
1. SQLite database can be created and opened
2. Database operations (create, read, update, query) work correctly
3. Database connections are properly managed (opened/closed)
4. Database files can be created at user-specified locations
5. Database schema versioning is tracked

### Technical Requirements
- Use `sqflite_common_ffi` for desktop SQLite support
- Database file extension: `.wiretuner`
- Schema version tracking in database
- Connection pooling/management
- Thread-safe database operations

## Implementation Details

### Dependencies (pubspec.yaml)
```yaml
dependencies:
  sqflite_common_ffi: ^2.3.0
  path_provider: ^2.1.0
  path: ^1.8.3
```

### Database Service (lib/services/database_service.dart)
```dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

class DatabaseService {
  static const int currentSchemaVersion = 1;
  Database? _database;

  Future<void> initialize() async {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> openDocument(String filePath) async {
    _database = await openDatabase(
      filePath,
      version: currentSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> createNewDocument(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      throw Exception('File already exists: $filePath');
    }
    await openDocument(filePath);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create schema_version table
    await db.execute('''
      CREATE TABLE schema_version (
        version INTEGER PRIMARY KEY,
        created_at TEXT NOT NULL,
        app_version TEXT NOT NULL
      )
    ''');

    // Insert initial version record
    await db.insert('schema_version', {
      'version': version,
      'created_at': DateTime.now().toIso8601String(),
      'app_version': '0.1.0', // TODO: Get from package version
    });

    // Create metadata table
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insert initial metadata
    await db.insert('metadata', {
      'key': 'document_name',
      'value': 'Untitled',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations in future versions
    // This is critical for forward compatibility requirement
  }

  // Helper methods for common operations
  Future<int> getSchemaVersion() async {
    if (_database == null) throw Exception('Database not opened');
    final result = await _database!.query(
      'schema_version',
      orderBy: 'version DESC',
      limit: 1,
    );
    return result.first['version'] as int;
  }

  Future<String?> getMetadata(String key) async {
    if (_database == null) throw Exception('Database not opened');
    final result = await _database!.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> setMetadata(String key, String value) async {
    if (_database == null) throw Exception('Database not opened');
    await _database!.insert(
      'metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

### Initialize in Main (lib/main.dart)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = DatabaseService();
  await dbService.initialize();

  runApp(const WireTunerApp());
}
```

### Initial Schema
```sql
-- Schema version tracking
CREATE TABLE schema_version (
  version INTEGER PRIMARY KEY,
  created_at TEXT NOT NULL,
  app_version TEXT NOT NULL
);

-- Document metadata
CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

## Success Criteria

### Automated Verification
- [ ] Project builds successfully with SQLite dependencies
- [ ] No compilation errors or warnings
- [ ] Unit tests for DatabaseService pass:
  - [ ] Can create new database file
  - [ ] Can open existing database file
  - [ ] Can read/write metadata
  - [ ] Schema version is tracked correctly
  - [ ] Database closes properly

### Manual Verification
- [ ] Application launches without database errors
- [ ] Can create a new .wiretuner file at a specified path
- [ ] Can open an existing .wiretuner file
- [ ] File is readable as SQLite database (use DB Browser for SQLite)
- [ ] Schema_version table exists with version 1
- [ ] Metadata table exists with initial data
- [ ] No file corruption or locks after app closes

## Testing Strategy

### Unit Tests (test/services/database_service_test.dart)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/services/database_service.dart';
import 'dart:io';

void main() {
  late DatabaseService dbService;
  late String testDbPath;

  setUp(() async {
    dbService = DatabaseService();
    await dbService.initialize();
    testDbPath = 'test_document.wiretuner';
  });

  tearDown(() async {
    await dbService.close();
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Can create new database', () async {
    await dbService.createNewDocument(testDbPath);
    final file = File(testDbPath);
    expect(await file.exists(), true);
  });

  test('Schema version is correct', () async {
    await dbService.createNewDocument(testDbPath);
    final version = await dbService.getSchemaVersion();
    expect(version, 1);
  });

  test('Can read and write metadata', () async {
    await dbService.createNewDocument(testDbPath);
    await dbService.setMetadata('test_key', 'test_value');
    final value = await dbService.getMetadata('test_key');
    expect(value, 'test_value');
  });
}
```

## Notes
- `sqflite_common_ffi` is required for desktop; standard `sqflite` is mobile-only
- Consider adding database encryption in future (sqlcipher)
- File association (.wiretuner files open in WireTuner) comes later
- Database schema migrations are critical for forward compatibility

## References
- sqflite_common_ffi: https://pub.dev/packages/sqflite_common_ffi
- SQLite Data Types: https://www.sqlite.org/datatype3.html
- Schema Versioning Best Practices: https://www.sqlite.org/pragma.html#pragma_user_version
