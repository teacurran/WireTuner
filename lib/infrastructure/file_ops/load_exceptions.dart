/// Base exception for load operations.
///
/// All load-specific exceptions extend this class to enable
/// consistent error handling in the UI layer.
class LoadException implements Exception {
  /// Creates a LoadException with a message and optional cause.
  const LoadException(this.message, {this.cause});

  /// Human-readable error message suitable for display to users.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() => 'LoadException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when the user cancels a file picker dialog during load.
///
/// This is not a true error condition - it indicates the user chose
/// not to proceed with the load operation.
///
/// Example:
/// ```dart
/// try {
///   await loadService.load();
/// } on LoadCancelledException {
///   print('Load cancelled by user');
/// }
/// ```
class LoadCancelledException extends LoadException {
  /// Creates a LoadCancelledException.
  const LoadCancelledException() : super('User cancelled load operation');
}

/// Thrown when the specified file path does not exist.
///
/// This can occur when:
/// - Loading a recent file that has been moved or deleted
/// - User provides an invalid file path
///
/// Example:
/// ```dart
/// try {
///   await loadService.load(filePath: '/path/to/missing.wiretuner');
/// } on FileNotFoundException catch (e) {
///   showError('File not found: ${e.message}');
/// }
/// ```
class FileNotFoundException extends LoadException {
  /// Creates a FileNotFoundException.
  FileNotFoundException(super.message, {super.cause});
}

/// Thrown when the file format version is newer than the app supports.
///
/// This occurs when a file created with a newer version of WireTuner
/// is opened in an older version. The user must upgrade the app to
/// open the file.
///
/// Example:
/// ```dart
/// try {
///   await loadService.load(filePath: filePath);
/// } on VersionMismatchException catch (e) {
///   showError('Please upgrade WireTuner to open this file');
/// }
/// ```
class VersionMismatchException extends LoadException {
  /// Creates a VersionMismatchException.
  VersionMismatchException(super.message, {super.cause});
}

/// Thrown when the database file is corrupt or invalid.
///
/// This can occur when:
/// - File is not a valid SQLite database
/// - Required tables (metadata, events, snapshots) are missing
/// - Database schema is invalid
///
/// Example:
/// ```dart
/// try {
///   await loadService.load(filePath: filePath);
/// } on CorruptDatabaseException catch (e) {
///   showError('Database file is corrupt: ${e.message}');
/// }
/// ```
class CorruptDatabaseException extends LoadException {
  /// Creates a CorruptDatabaseException.
  CorruptDatabaseException(super.message, {super.cause});
}

/// Thrown when the file path is invalid.
///
/// This can occur when:
/// - Path is not absolute
/// - Path contains invalid characters
/// - Path does not have .wiretuner extension
///
/// Example:
/// ```dart
/// try {
///   await loadService.load(filePath: 'relative/path.wiretuner');
/// } on InvalidFilePathException catch (e) {
///   showError('Invalid file path: ${e.message}');
/// }
/// ```
class InvalidFilePathException extends LoadException {
  /// Creates an InvalidFilePathException.
  InvalidFilePathException(
    super.message, {
    super.cause,
    this.providedPath,
  });

  /// The file path that caused the validation error.
  final String? providedPath;

  @override
  String toString() => 'InvalidFilePathException: $message'
      '${providedPath != null ? ' (path: $providedPath)' : ''}'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
