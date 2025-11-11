import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';

/// Provides database connection lifecycle management for the WireTuner application.
///
/// The [DatabaseProvider] class manages SQLite database connections using the
/// `sqflite_common_ffi` package for desktop platform support. It handles:
/// - Initialization of the SQLite FFI engine
/// - Opening and closing database connections
/// - Creating database files in platform-specific application support directories
/// - Transaction management
///
/// Database files use the `.wiretuner` extension and are stored in:
/// - macOS: `~/Library/Application Support/WireTuner/`
/// - Windows: `%APPDATA%\WireTuner\`
///
/// Example usage:
/// ```dart
/// final provider = DatabaseProvider();
/// await provider.initialize();
/// final db = await provider.open('my_document.wiretuner');
/// // Use database...
/// await provider.close();
/// ```
class DatabaseProvider {
  /// The current schema version for the WireTuner database.
  static const int currentSchemaVersion = 1;

  /// The file extension for WireTuner database files.
  static const String databaseExtension = '.wiretuner';

  /// The application directory name for storing database files.
  static const String appDirectoryName = 'WireTuner';

  Database? _database;
  final Logger _logger = Logger();
  bool _isInitialized = false;

  /// Returns the currently open database instance.
  ///
  /// Throws [StateError] if no database is currently open.
  Database getDatabase() {
    if (_database == null) {
      throw StateError(
        'No database is currently open. Call open() before accessing the database.',
      );
    }
    return _database!;
  }

  /// Initializes the SQLite FFI engine for desktop platforms.
  ///
  /// This method must be called before any database operations.
  /// It sets up the FFI-based database factory required for desktop platforms.
  ///
  /// Throws [Exception] if initialization fails.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('DatabaseProvider already initialized');
      return;
    }

    try {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _isInitialized = true;
      _logger.i('DatabaseProvider initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize DatabaseProvider', error: e);
      throw Exception('Failed to initialize database provider: $e');
    }
  }

  /// Opens a database connection to the specified file.
  ///
  /// If [filePath] is a relative path or just a filename, the database will be
  /// created in the platform-specific application support directory.
  /// If [filePath] is an absolute path, it will be used as-is.
  ///
  /// The database file will be created if it doesn't exist.
  ///
  /// Parameters:
  /// - [filePath]: The path to the database file. Can be relative or absolute.
  ///
  /// Returns the opened [Database] instance.
  ///
  /// Throws [StateError] if the provider hasn't been initialized.
  /// Throws [Exception] if the database cannot be opened.
  Future<Database> open(String filePath) async {
    if (!_isInitialized) {
      throw StateError(
        'DatabaseProvider not initialized. Call initialize() first.',
      );
    }

    // Close any existing connection
    if (_database != null) {
      _logger.w('Closing existing database connection before opening new one');
      await close();
    }

    try {
      // Resolve the full path to the database file
      final fullPath = await _resolveDatabasePath(filePath);
      _logger.i('Opening database at: $fullPath');

      // Ensure the directory exists
      final directory = Directory(path.dirname(fullPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        _logger.i('Created database directory: ${directory.path}');
      }

      // Open the database
      _database = await openDatabase(
        fullPath,
        version: currentSchemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );

      _logger.i('Database opened successfully: $fullPath');
      return _database!;
    } catch (e) {
      _logger.e('Failed to open database', error: e);
      throw Exception('Failed to open database at $filePath: $e');
    }
  }

  /// Closes the current database connection.
  ///
  /// This method is idempotent - calling it multiple times is safe.
  ///
  /// Throws [Exception] if an error occurs during closure.
  Future<void> close() async {
    if (_database == null) {
      _logger.d('No database connection to close');
      return;
    }

    try {
      await _database!.close();
      _database = null;
      _logger.i('Database connection closed successfully');
    } catch (e) {
      _logger.e('Error closing database connection', error: e);
      throw Exception('Failed to close database: $e');
    }
  }

  /// Resolves the full path to a database file.
  ///
  /// If the provided path is absolute, ensures it has the .wiretuner extension.
  /// If the provided path is relative, resolves it relative to the
  /// platform-specific application support directory and adds extension if needed.
  Future<String> _resolveDatabasePath(String filePath) async {
    // Ensure the path has the correct extension
    String resolvedPath = filePath;
    if (!resolvedPath.endsWith(databaseExtension)) {
      resolvedPath = '$resolvedPath$databaseExtension';
    }

    // If it's already an absolute path, return it with extension ensured
    if (path.isAbsolute(filePath)) {
      return resolvedPath;
    }

    // Get the application support directory
    final appSupportDir = await getApplicationSupportDirectory();
    final appDir = Directory(path.join(appSupportDir.path, appDirectoryName));

    // Extract just the filename from the path
    final fileName = path.basename(resolvedPath);

    return path.join(appDir.path, fileName);
  }

  /// Callback invoked when the database is created for the first time.
  ///
  /// This method delegates to [SchemaManager] to create the complete
  /// event sourcing schema including metadata, events, and snapshots tables.
  Future<void> _onCreate(Database db, int version) async {
    _logger.i('Database created with version $version');
    await SchemaManager.createSchema(db);
    _logger.i('Schema creation completed successfully');
  }

  /// Callback invoked when the database needs to be upgraded.
  ///
  /// This handles schema migrations between versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i('Upgrading database from version $oldVersion to $newVersion');
    // Schema migrations will be implemented in future tasks
  }

  /// Callback invoked when the database is opened (every time).
  ///
  /// This enables foreign key constraints for the connection.
  /// In SQLite, foreign keys must be enabled for each connection.
  Future<void> _onOpen(Database db) async {
    _logger.d('Enabling foreign keys for connection');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Returns whether the provider has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns whether a database is currently open.
  bool get isOpen => _database != null;
}
