import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Configuration for SQLite database connections.
///
/// Supports both file-based and in-memory database modes for production
/// use and testing scenarios.
class DatabaseConfig {
  /// Creates a file-based database configuration.
  ///
  /// [filePath] can be either:
  /// - Relative path (e.g., "my_document.wiretuner") - stored in app support directory
  /// - Absolute path (e.g., "/path/to/my_document.wiretuner") - used as-is
  ///
  /// File extension .wiretuner is automatically added if missing.
  const DatabaseConfig.file({required this.filePath})
      : isInMemory = false;

  /// Creates an in-memory database configuration.
  ///
  /// In-memory databases are useful for:
  /// - Unit tests (fast, no file I/O)
  /// - Temporary scratch documents
  /// - CI environments
  ///
  /// Note: In-memory databases are destroyed when the connection is closed.
  const DatabaseConfig.inMemory()
      : filePath = null,
        isInMemory = true;

  /// Path to the database file (null for in-memory databases).
  final String? filePath;

  /// Whether this is an in-memory database.
  final bool isInMemory;

  /// Returns the path to use for opening the database.
  ///
  /// For in-memory databases, returns [inMemoryDatabasePath].
  /// For file-based databases, returns [filePath].
  String getPath() {
    if (isInMemory) {
      return inMemoryDatabasePath;
    }
    return filePath!;
  }

  @override
  String toString() {
    if (isInMemory) {
      return 'DatabaseConfig.inMemory()';
    }
    return 'DatabaseConfig.file(path: $filePath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DatabaseConfig &&
        other.filePath == filePath &&
        other.isInMemory == isInMemory;
  }

  @override
  int get hashCode => Object.hash(filePath, isInMemory);
}
