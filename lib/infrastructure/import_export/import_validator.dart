import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// Shared validation logic for import operations.
///
/// This class provides security and validation checks for file imports,
/// ensuring that imported files meet safety constraints before parsing.
///
/// ## Security Constraints
///
/// - **Max File Size**: 10 MB limit to prevent DoS attacks
/// - **File Type Validation**: Only .svg and .ai extensions allowed
/// - **Path Data Length**: Maximum 100k characters per path
/// - **Existence Check**: Verifies file exists before processing
///
/// ## Usage
///
/// ```dart
/// await ImportValidator.validateFile('/path/to/file.svg');
/// // Throws ImportException if validation fails
///
/// ImportValidator.validatePathData(pathDataString);
/// // Throws ImportException if path data too long
/// ```
class ImportValidator {
  static final Logger _logger = Logger();

  /// Maximum file size in bytes (10 MB).
  ///
  /// Files larger than this are rejected to prevent:
  /// - Out-of-memory errors
  /// - DoS attacks via huge files
  /// - Excessive parsing time
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum path data string length (100k characters).
  ///
  /// SVG path data strings longer than this are rejected to prevent:
  /// - DoS attacks via billion laughs pattern
  /// - Excessive memory allocation
  /// - Pathologically long parse times
  static const int maxPathDataLength = 100000;

  /// Supported file extensions.
  static const List<String> supportedExtensions = ['.svg', '.ai'];

  /// Validates a file for import operations.
  ///
  /// Performs the following checks:
  /// 1. File exists
  /// 2. File size is within limits
  /// 3. File extension is supported
  ///
  /// Parameters:
  /// - [filePath]: Absolute path to the file to validate
  ///
  /// Throws:
  /// - [ImportException] if any validation check fails
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await ImportValidator.validateFile('/path/to/drawing.svg');
  ///   // File is valid, proceed with import
  /// } catch (e) {
  ///   print('Validation failed: $e');
  /// }
  /// ```
  static Future<void> validateFile(String filePath) async {
    _logger.d('Validating file: $filePath');

    final file = File(filePath);

    // Check file exists
    if (!await file.exists()) {
      throw ImportException('File not found: $filePath');
    }

    // Check file size
    final size = await file.length();
    _logger.d('File size: $size bytes');

    if (size > maxFileSizeBytes) {
      throw ImportException(
        'File size ($size bytes) exceeds maximum ($maxFileSizeBytes bytes). '
        'Maximum supported file size is ${maxFileSizeBytes ~/ (1024 * 1024)} MB.',
      );
    }

    // Check file extension
    final ext = p.extension(filePath).toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw ImportException(
        'Unsupported file type: $ext. '
        'Supported formats: ${supportedExtensions.join(", ")}',
      );
    }

    _logger.d('File validation passed: $filePath');
  }

  /// Validates SVG path data string length.
  ///
  /// Checks that the path data string does not exceed the maximum
  /// allowed length. Empty strings are considered valid.
  ///
  /// Parameters:
  /// - [pathData]: The SVG path data string to validate
  ///
  /// Throws:
  /// - [ImportException] if path data exceeds maximum length
  ///
  /// Example:
  /// ```dart
  /// final pathData = element.getAttribute('d');
  /// if (pathData != null) {
  ///   ImportValidator.validatePathData(pathData);
  ///   // Safe to parse
  /// }
  /// ```
  static void validatePathData(String pathData) {
    if (pathData.isEmpty) return;

    if (pathData.length > maxPathDataLength) {
      throw ImportException(
        'Path data exceeds maximum length '
        '(${pathData.length} > $maxPathDataLength characters). '
        'This may indicate malicious input.',
      );
    }
  }

  /// Validates a numeric value for safety.
  ///
  /// Checks that a parsed coordinate value is finite and within
  /// reasonable bounds for vector graphics.
  ///
  /// Parameters:
  /// - [value]: The numeric value to validate
  /// - [name]: Description of the value (for error messages)
  ///
  /// Throws:
  /// - [ImportException] if value is NaN, infinite, or out of bounds
  ///
  /// Example:
  /// ```dart
  /// final x = double.parse(xStr);
  /// ImportValidator.validateCoordinate(x, 'x coordinate');
  /// ```
  static void validateCoordinate(double value, String name) {
    if (!value.isFinite) {
      throw ImportException(
        'Invalid $name: $value. '
        'Coordinate values must be finite numbers.',
      );
    }

    // Reasonable bounds for vector graphics (±1 million pixels)
    const maxCoordinate = 1000000.0;
    if (value.abs() > maxCoordinate) {
      throw ImportException(
        'Invalid $name: $value. '
        'Coordinate values must be within ±$maxCoordinate range.',
      );
    }
  }
}

/// Exception thrown when import validation fails.
///
/// This exception is used for all import-related errors including:
/// - File validation failures
/// - Malformed SVG/AI content
/// - Unsupported features that cannot be safely ignored
/// - Security constraint violations
///
/// Example:
/// ```dart
/// try {
///   await importer.importFromFile(path);
/// } on ImportException catch (e) {
///   print('Import failed: ${e.message}');
/// }
/// ```
class ImportException implements Exception {
  /// The error message describing why import failed.
  final String message;

  /// Creates a new import exception.
  ImportException(this.message);

  @override
  String toString() => 'ImportException: $message';
}
