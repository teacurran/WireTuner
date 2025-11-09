import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database_config.dart';
import '../migrations/migration_runner.dart';

/// Factory for creating and managing SQLite database connections.
///
/// This class provides:
/// - Connection pooling for multi-document/multi-window scenarios
/// - Automatic FFI initialization for desktop platforms
/// - Path resolution for file-based databases
/// - Migration management
/// - Proper error handling with actionable messages
///
/// Example usage:
/// ```dart
/// final factory = ConnectionFactory();
/// await factory.initialize();
///
/// // Open a file-based database
/// final db1 = await factory.openConnection(
///   documentId: 'doc-1',
///   config: DatabaseConfig.file(filePath: 'document1.wiretuner'),
/// );
///
/// // Open an in-memory database for testing
/// final db2 = await factory.openConnection(
///   documentId: 'test-doc',
///   config: DatabaseConfig.inMemory(),
/// );
///
/// // Close specific connection
/// await factory.closeConnection('doc-1');
///
/// // Close all connections
/// await factory.closeAll();
/// ```
class ConnectionFactory {
  /// The file extension for WireTuner database files.
  static const String databaseExtension = '.wiretuner';

  /// The application directory name for storing database files.
  static const String appDirectoryName = 'WireTuner';

  static final Logger _logger = Logger();
  bool _isInitialized = false;

  /// Pool of active database connections, keyed by document ID.
  final Map<String, Database> _connectionPool = {};

  /// Returns whether the factory has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns the number of active connections.
  int get activeConnectionCount => _connectionPool.length;

  /// Initializes the SQLite FFI engine for desktop platforms.
  ///
  /// This method must be called before any database operations.
  /// It sets up the FFI-based database factory required for desktop platforms.
  ///
  /// Safe to call multiple times (idempotent).
  ///
  /// Throws [Exception] if initialization fails.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d('ConnectionFactory already initialized');
      return;
    }

    try {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _isInitialized = true;
      _logger.i('ConnectionFactory initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize ConnectionFactory', error: e);
      throw Exception(
        'Failed to initialize SQLite connection factory: $e\n'
        'Ensure sqflite_common_ffi is properly configured for desktop platforms.',
      );
    }
  }

  /// Opens a database connection for the specified document.
  ///
  /// If a connection already exists for [documentId], returns the existing connection.
  /// Otherwise, creates a new connection and adds it to the pool.
  ///
  /// Parameters:
  /// - [documentId]: Unique identifier for the document (used for connection pooling)
  /// - [config]: Database configuration (file-based or in-memory)
  /// - [runMigrations]: Whether to run schema migrations (default: true)
  ///
  /// Returns the opened [Database] instance.
  ///
  /// Throws:
  /// - [StateError] if the factory hasn't been initialized
  /// - [Exception] if the database cannot be opened or migrated
  Future<Database> openConnection({
    required String documentId,
    required DatabaseConfig config,
    bool runMigrations = true,
  }) async {
    if (!_isInitialized) {
      throw StateError(
        'ConnectionFactory not initialized. Call initialize() first.',
      );
    }

    // Return existing connection if available
    if (_connectionPool.containsKey(documentId)) {
      _logger.d('Reusing existing connection for document: $documentId');
      return _connectionPool[documentId]!;
    }

    try {
      // Resolve the database path
      final dbPath = await _resolvePath(config);
      _logger.i('Opening database connection: $documentId at $dbPath');

      // Ensure directory exists for file-based databases
      if (!config.isInMemory) {
        await _ensureDirectoryExists(dbPath);
      }

      // Open the database with singleInstance: false to allow multiple handles
      // Version management is handled by MigrationRunner
      final db = await openDatabase(
        dbPath,
        singleInstance: false,
        onOpen: (db) async {
          _logger.d('Enabling foreign keys and WAL mode for document $documentId');
          await db.execute('PRAGMA foreign_keys = ON');
          // Only enable WAL for file-based databases (in-memory uses 'memory' journal mode)
          if (!config.isInMemory) {
            await db.execute('PRAGMA journal_mode=WAL');
          }
        },
      );

      // Run migrations if requested
      if (runMigrations) {
        _logger.d('Running schema migrations for document $documentId');
        final migrationRunner = MigrationRunner(db);
        await migrationRunner.runMigrations();
      }

      // Add to connection pool
      _connectionPool[documentId] = db;
      _logger.i('Connection opened and pooled for document: $documentId');

      return db;
    } catch (e) {
      _logger.e('Failed to open database connection for document $documentId', error: e);

      // Provide actionable error messages
      if (e.toString().contains('permission') || e.toString().contains('access')) {
        throw Exception(
          'Failed to open database for document "$documentId": Permission denied.\n'
          'Ensure the application has write permissions to the database directory.\n'
          'Path: ${config.filePath ?? "in-memory"}\n'
          'Original error: $e',
        );
      } else if (e.toString().contains('corrupt')) {
        throw Exception(
          'Failed to open database for document "$documentId": Database file is corrupted.\n'
          'Consider restoring from a backup or creating a new document.\n'
          'Path: ${config.filePath ?? "in-memory"}\n'
          'Original error: $e',
        );
      } else {
        throw Exception(
          'Failed to open database for document "$documentId": $e\n'
          'Configuration: $config',
        );
      }
    }
  }

  /// Closes the database connection for the specified document.
  ///
  /// Removes the connection from the pool and closes it.
  /// This method is idempotent - calling it for a non-existent connection is safe.
  ///
  /// Throws [Exception] if an error occurs during closure.
  Future<void> closeConnection(String documentId) async {
    if (!_connectionPool.containsKey(documentId)) {
      _logger.d('No connection to close for document: $documentId');
      return;
    }

    try {
      final db = _connectionPool.remove(documentId)!;
      await db.close();
      _logger.i('Connection closed for document: $documentId');
    } catch (e) {
      _logger.e('Error closing connection for document $documentId', error: e);
      throw Exception('Failed to close database connection for document "$documentId": $e');
    }
  }

  /// Closes all active database connections.
  ///
  /// Useful for application shutdown or cleanup in tests.
  ///
  /// Throws [Exception] if any connection fails to close.
  Future<void> closeAll() async {
    _logger.i('Closing all ${_connectionPool.length} active connections...');

    final errors = <String, Exception>{};

    for (final documentId in _connectionPool.keys.toList()) {
      try {
        await closeConnection(documentId);
      } catch (e) {
        errors[documentId] = e as Exception;
      }
    }

    if (errors.isNotEmpty) {
      _logger.e('Failed to close ${errors.length} connections: ${errors.keys.join(", ")}');
      throw Exception(
        'Failed to close ${errors.length} database connections:\n'
        '${errors.entries.map((e) => '  - ${e.key}: ${e.value}').join('\n')}',
      );
    }

    _logger.i('All connections closed successfully');
  }

  /// Resolves the database path based on configuration.
  ///
  /// For in-memory databases, returns [inMemoryDatabasePath].
  /// For file-based databases:
  /// - Absolute paths are used as-is (with extension ensured)
  /// - Relative paths are resolved to the application support directory
  Future<String> _resolvePath(DatabaseConfig config) async {
    if (config.isInMemory) {
      return inMemoryDatabasePath;
    }

    String filePath = config.filePath!;

    // Ensure .wiretuner extension
    if (!filePath.endsWith(databaseExtension)) {
      filePath = '$filePath$databaseExtension';
    }

    // If already absolute, return as-is
    if (path.isAbsolute(filePath)) {
      return filePath;
    }

    // Resolve relative path to app support directory
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final appDir = Directory(path.join(appSupportDir.path, appDirectoryName));
      final fileName = path.basename(filePath);
      return path.join(appDir.path, fileName);
    } catch (e) {
      throw Exception(
        'Failed to resolve database path for "$filePath": $e\n'
        'Ensure path_provider can access the application support directory.',
      );
    }
  }

  /// Ensures the parent directory exists for a database file.
  Future<void> _ensureDirectoryExists(String dbPath) async {
    try {
      final directory = Directory(path.dirname(dbPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        _logger.i('Created database directory: ${directory.path}');
      }
    } catch (e) {
      throw Exception(
        'Failed to create database directory for "$dbPath": $e\n'
        'Check filesystem permissions.',
      );
    }
  }

  /// Returns whether a connection exists for the specified document.
  bool hasConnection(String documentId) {
    return _connectionPool.containsKey(documentId);
  }

  /// Gets an existing connection for the specified document.
  ///
  /// Throws [StateError] if no connection exists for the document.
  Database getConnection(String documentId) {
    if (!_connectionPool.containsKey(documentId)) {
      throw StateError(
        'No database connection exists for document "$documentId". '
        'Call openConnection() first.',
      );
    }
    return _connectionPool[documentId]!;
  }
}
