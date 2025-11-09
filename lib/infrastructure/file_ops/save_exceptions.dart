/// Base exception class for save operations.
///
/// All save-related exceptions extend this base class to enable
/// type-safe error handling and unified error recovery strategies.
class SaveException implements Exception {
  /// Creates a save exception with a descriptive message.
  const SaveException(this.message, {this.cause});

  /// The error message describing what went wrong.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'SaveException: $message\nCaused by: $cause';
    }
    return 'SaveException: $message';
  }
}

/// Exception thrown when there is insufficient disk space to save.
///
/// This corresponds to SQLite's SQLITE_FULL error code (13).
///
/// Recovery strategies:
/// - Display error message to user
/// - Suggest freeing up disk space
/// - Enter read-only mode if critical
/// - Keep pending events in memory for later save attempt
class DiskFullException extends SaveException {
  /// Creates a disk full exception.
  const DiskFullException(
    super.message, {
    super.cause,
  });
}

/// Exception thrown when the application lacks permission to write to the file.
///
/// This can occur due to:
/// - File system permissions (read-only file, protected directory)
/// - Operating system access controls
/// - File locked by another process
///
/// Recovery strategies:
/// - Display error message to user
/// - Suggest alternate save location (Save As...)
/// - Suggest checking file permissions
class PermissionDeniedException extends SaveException {
  /// Creates a permission denied exception.
  const PermissionDeniedException(
    super.message, {
    super.cause,
  });
}

/// Exception thrown when the target file already exists and overwrite is disabled.
///
/// This is used in "Save As..." flows to prevent accidental file overwrites.
///
/// Recovery strategies:
/// - Prompt user to confirm overwrite
/// - Suggest alternate filename
/// - Allow user to cancel operation
class FileExistsException extends SaveException {
  /// Creates a file exists exception.
  const FileExistsException(
    super.message, {
    this.existingFilePath,
    super.cause,
  });

  /// The path to the existing file that would be overwritten.
  final String? existingFilePath;

  @override
  String toString() {
    if (existingFilePath != null) {
      return 'FileExistsException: $message (path: $existingFilePath)';
    }
    return 'FileExistsException: $message';
  }
}

/// Exception thrown when the provided file path is invalid.
///
/// This can occur due to:
/// - Relative path when absolute path is required
/// - Invalid characters in filename
/// - Missing required file extension (.wiretuner)
/// - Path exceeds maximum length
///
/// Recovery strategies:
/// - Display error message to user
/// - Suggest valid file path format
/// - Auto-correct path if possible (e.g., add extension)
class InvalidFilePathException extends SaveException {
  /// Creates an invalid file path exception.
  const InvalidFilePathException(
    super.message, {
    this.providedPath,
    super.cause,
  });

  /// The invalid path that was provided.
  final String? providedPath;

  @override
  String toString() {
    if (providedPath != null) {
      return 'InvalidFilePathException: $message (provided: $providedPath)';
    }
    return 'InvalidFilePathException: $message';
  }
}

/// Exception thrown when save operation is cancelled by the user.
///
/// This is not an error condition, but rather a normal flow control
/// mechanism when the user cancels a file picker dialog.
///
/// Recovery strategies:
/// - Silently abort save operation
/// - Keep document in current state
/// - No error message needed (user intentionally cancelled)
class SaveCancelledException extends SaveException {
  /// Creates a save cancelled exception.
  const SaveCancelledException() : super('Save operation cancelled by user');
}
