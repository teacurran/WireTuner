# Task Briefing Package

This package contains all necessary information and strategic guidance for the Coder Agent.

---

## 1. Current Task Details

This is the full specification of the task you must complete.

```json
{
  "task_id": "I1.T4",
  "iteration_id": "I1",
  "iteration_goal": "Establish project infrastructure, initialize Flutter project, integrate SQLite, and document event sourcing architecture",
  "description": "Integrate SQLite into the Flutter project using `sqflite_common_ffi` package. Create `lib/infrastructure/persistence/database_provider.dart` to manage SQLite connection lifecycle (open, close, transaction management). Implement initialization logic to create database file in application support directory. Write unit tests to verify database connection succeeds on both macOS and Windows.",
  "agent_type_hint": "BackendAgent",
  "inputs": "Architecture blueprint Section 3.2 (Technology Stack - SQLite), Plan Section 2 (Database: SQLite via sqflite_common_ffi), Ticket T002 (SQLite Integration)",
  "target_files": [
    "lib/infrastructure/persistence/database_provider.dart",
    "test/infrastructure/persistence/database_provider_test.dart"
  ],
  "input_files": [
    "pubspec.yaml"
  ],
  "deliverables": "DatabaseProvider class with open(), close(), getDatabase() methods, Database file created in correct application support directory, Unit tests confirming database opens successfully, Error handling for database initialization failures",
  "acceptance_criteria": "`flutter test test/infrastructure/persistence/database_provider_test.dart` passes, Database file created at correct path (~/Library/Application Support/WireTuner/ on macOS, %APPDATA%\\WireTuner\\ on Windows), No hardcoded paths; uses platform-specific path resolution, Connection can be opened and closed without errors",
  "dependencies": [
    "I1.T1"
  ],
  "parallelizable": false,
  "done": false
}
```

---

## 2. Architectural & Planning Context

The following are the relevant sections from the architecture and plan documents, which I found by analyzing the task description.

### Context: stack-persistence (from 02_Architecture_Overview.md)

```markdown
<!-- anchor: stack-persistence -->
#### Data & Persistence

| Component | Technology | Package/Library | Justification |
|-----------|-----------|-----------------|---------------|
| **Event Store** | SQLite | `sqflite_common_ffi` | Embedded database, ACID compliance, zero-config, portable files |
| **Schema** | SQL DDL | - | Direct SQL for event log, snapshot, document tables |
| **File Format** | .wiretuner (SQLite) | - | Self-contained file format, readable with standard SQLite tools |
```

### Context: decision-sqlite (from 06_Rationale_and_Future.md)

```markdown
<!-- anchor: decision-sqlite -->
#### Decision 3: SQLite for Event Storage & File Format

**Choice**: Use SQLite as the native .wiretuner file format

**Rationale:**
1. **Embedded**: No separate database server, zero configuration
2. **ACID Guarantees**: Ensures event log integrity even during crashes
3. **Portable**: .wiretuner files are standard SQLite databases, readable with any SQLite tool
4. **Performance**: More than adequate for 50ms sampling rate (20 events/second max)
5. **Battle-Tested**: SQLite is the most deployed database engine globally

**Trade-offs:**
- **Not Text-Based**: Unlike JSON/XML, binary format (but SQLite's ubiquity mitigates this)
- **Single-User**: SQLite not designed for concurrent access (acceptable for desktop app)
- **File Size**: Potentially larger than custom binary format (mitigated by snapshot compression)

**Alternatives Considered:**
- **JSON File + Append-Only Log**: Simpler but no ACID guarantees, harder to query
- **Custom Binary Format**: More compact but requires custom serialization, less tooling
- **PostgreSQL**: Overkill, requires server, not portable

**Verdict**: SQLite is the ideal choice for a local-first desktop application.

---
```

### Context: reliability-data-integrity (from 05_Operational_Architecture.md)

```markdown
<!-- anchor: reliability-data-integrity -->
##### Data Integrity

**Event Log Integrity:**
- **Checksums**: SQLite's internal page checksums detect corruption
- **Validation**: On document load, verify event sequence numbers are contiguous
- **Error Handling**: If gap detected, warn user and skip to next valid event

**Snapshot Integrity:**
- **Versioning**: Each snapshot tagged with format version
- **Validation**: Deserialize snapshot, check for null fields, validate object IDs

**Export Integrity:**
- **SVG Validation**: Validate generated SVG against SVG 1.1 schema before writing
- **PDF Validation**: Check PDF structure integrity (valid xref table, trailer)
```

### Context: Ticket T002 - SQLite Integration

**Full ticket details from `.codemachine/inputs/tickets/T002-sqlite-integration.md`:**

This ticket provides a complete reference implementation including:

**Key Requirements:**
1. Use `sqflite_common_ffi` for desktop SQLite support
2. Database file extension: `.wiretuner`
3. Schema version tracking in database
4. Connection pooling/management
5. Thread-safe database operations

**Critical Implementation Notes:**
- Database files should be created in platform-specific application support directories
- Must use `sqfliteFfiInit()` and set `databaseFactory = databaseFactoryFfi` for desktop support
- Schema versioning is critical for forward compatibility
- Include `onCreate` and `onUpgrade` callbacks for schema management

**Platform-Specific Paths:**
- macOS: `~/Library/Application Support/WireTuner/`
- Windows: `%APPDATA%\WireTuner\`

**Reference Code Pattern (from ticket):**
```dart
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
}
```

---

## 3. Codebase Analysis & Strategic Guidance

The following analysis is based on my direct review of the current codebase. Use these notes and tips to guide your implementation.

### Relevant Existing Code

*   **File:** `pubspec.yaml`
    *   **Summary:** This file already contains the `sqflite_common_ffi: ^2.3.0` dependency. The dependency is ready to use.
    *   **Recommendation:** You DO NOT need to add the sqflite dependency - it's already present. Focus on implementing the DatabaseProvider class.

*   **File:** `lib/main.dart`
    *   **Summary:** This is the application entry point. Currently initializes logging and runs the App widget.
    *   **Recommendation:** You will need to modify this file to initialize the DatabaseProvider before running the app. Follow the pattern shown in Ticket T002 - call `WidgetsFlutterBinding.ensureInitialized()` and initialize the database service.
    *   **Important:** The main.dart currently uses a Logger instance. You SHOULD also use the logger package for any database initialization logging.

*   **File:** `lib/app.dart`
    *   **Summary:** Root application widget that sets up MaterialApp with Material Design 3 theme. Currently shows a placeholder home page.
    *   **Recommendation:** You do NOT need to modify this file for task I1.T4. The DatabaseProvider should be initialized in main.dart before the App widget is created.

*   **Directory:** `lib/infrastructure/persistence/`
    *   **Summary:** This directory exists but is currently empty. This is where you will create `database_provider.dart`.
    *   **Recommendation:** Create the DatabaseProvider class in this directory following the layered architecture pattern.

*   **File:** `analysis_options.yaml`
    *   **Summary:** Strict linting configuration is enabled with comprehensive rules.
    *   **Recommendation:** Your code MUST comply with these rules. Pay special attention to:
        - `public_member_api_docs` - All public members need documentation comments
        - `prefer_const_constructors` - Use const constructors where possible
        - `prefer_single_quotes` - Use single quotes for strings
        - `require_trailing_commas` - Add trailing commas to parameter lists
        - `avoid_print` - Use the logger package instead of print statements

### Implementation Tips & Notes

*   **Tip #1 - Platform-Specific Paths:** You MUST use platform-specific path resolution. Do NOT hardcode paths like `~/Library/Application Support/`. The ticket mentions `path_provider` package but it's NOT yet in pubspec.yaml. You have two options:
    1. Add `path_provider: ^2.1.0` to pubspec.yaml dependencies (RECOMMENDED)
    2. Use `Platform.environment` and manual path construction (NOT recommended, less robust)

*   **Tip #2 - Naming Convention:** The task specifies creating `database_provider.dart`, but Ticket T002 uses the name `database_service.dart`. Based on the task specification and directory structure, you SHOULD use `database_provider.dart` as specified in the target_files. The class name should be `DatabaseProvider` (not DatabaseService).

*   **Tip #3 - Error Handling:** The architecture blueprint emphasizes ACID guarantees and data integrity. Your DatabaseProvider MUST:
    - Handle file I/O errors gracefully (permissions, disk full, etc.)
    - Validate that database files are actually SQLite databases
    - Provide clear error messages for debugging
    - Use try-catch blocks with proper exception handling

*   **Tip #4 - Testing Strategy:** Your unit tests MUST:
    - Create test databases in a temporary directory (NOT the real app directory)
    - Clean up test files in `tearDown()` method
    - Test both success and failure cases (e.g., opening non-existent file, corrupted database)
    - Use the pattern shown in Ticket T002's test code as a reference
    - Ensure tests can run on both macOS and Windows (use platform-agnostic paths)

*   **Tip #5 - Initialization Pattern:** Follow the exact initialization pattern from Ticket T002:
    ```dart
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    ```
    This MUST be called before any database operations. It should be in an `initialize()` method that's called from main.dart.

*   **Note #1 - Schema Not Required Yet:** Task I1.T4 is about creating the DatabaseProvider (connection management). The actual schema creation is in task I1.T5. For this task, you only need to:
    - Open/close database connections
    - Create empty database files
    - You do NOT need to create tables yet (that comes in I1.T5)

*   **Note #2 - File Extension:** Database files MUST use the `.wiretuner` extension as specified in the architecture. When creating new documents, ensure the file path ends with `.wiretuner`.

*   **Warning #1 - Thread Safety:** The architecture mentions "thread-safe database operations". However, since SQLite itself handles locking and Flutter is single-threaded by default, you don't need complex synchronization. The main concern is ensuring you don't access a closed database. Include proper null checks and state management.

*   **Warning #2 - Desktop-Only Package:** `sqflite_common_ffi` is desktop-only. The code will NOT work on mobile platforms. This is acceptable per the project requirements (macOS/Windows desktop only), but be aware if you test on mobile emulators.

### Acceptance Criteria Checklist

To verify your implementation is complete, ensure:

- [ ] `DatabaseProvider` class created in `lib/infrastructure/persistence/database_provider.dart`
- [ ] Class includes `initialize()` method that calls `sqfliteFfiInit()` and sets `databaseFactory`
- [ ] Class includes `open(String filePath)` method that opens a database connection
- [ ] Class includes `close()` method that closes the database connection
- [ ] Class includes `getDatabase()` method that returns the current Database instance
- [ ] Database files are created in platform-specific app support directory (use `path_provider`)
- [ ] Error handling for common failure cases (permissions, corrupted files, etc.)
- [ ] All public methods have documentation comments (required by linter)
- [ ] Unit tests created in `test/infrastructure/persistence/database_provider_test.dart`
- [ ] Tests verify database can be opened and closed
- [ ] Tests verify database file is created at correct path
- [ ] Tests clean up temporary files in tearDown()
- [ ] `flutter test test/infrastructure/persistence/database_provider_test.dart` passes
- [ ] `flutter analyze` shows no errors or warnings
- [ ] Updated `lib/main.dart` to initialize DatabaseProvider before running app

### Code Quality Requirements

Your implementation must:
1. Follow the Dart style guide and project linting rules
2. Include comprehensive documentation comments for all public APIs
3. Use single quotes for strings
4. Add trailing commas to all parameter lists
5. Use `const` constructors where possible
6. Use the `logger` package for any logging (NOT print statements)
7. Handle all exceptions with try-catch blocks
8. Provide user-friendly error messages
