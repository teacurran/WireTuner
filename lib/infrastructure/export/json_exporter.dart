import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:wiretuner/domain/document/document.dart';

/// Service for exporting documents to JSON archival format.
///
/// This service handles the complete workflow of converting a WireTuner document
/// to a JSON snapshot file suitable for archival, version control, and interop.
///
/// ## JSON Export Format (Section 7.10)
///
/// The JSON export follows the hybrid file format strategy:
/// - **Snapshot-only**: No event history, no undo/redo on import
/// - **Human-readable**: Pretty-printed JSON with consistent field ordering
/// - **Version-controlled**: Includes file format version for compatibility
/// - **Lossless for visual content**: Round-trip import/export preserves structure
///
/// ## Format Structure
///
/// ```json
/// {
///   "fileFormatVersion": "2.0.0",
///   "exportedAt": "2025-11-10T14:30:00.123Z",
///   "exportedBy": "WireTuner v0.1.0",
///   "document": {
///     "id": "uuid-v4",
///     "title": "Document Title",
///     "schemaVersion": 2,
///     "artboards": [...]
///   }
/// }
/// ```
///
/// ## Key Features
///
/// - ✅ Preserves artboards, layers, objects with transforms/styles
/// - ✅ Per-artboard viewport state (zoom, pan, preset)
/// - ✅ File format version validation (rejects incompatible versions)
/// - ✅ ISO 8601 timestamps for export metadata
/// - ✅ Optional pretty printing or minified output
/// - ✅ Artboard filtering (export specific artboards or all)
///
/// ## Limitations
///
/// - ❌ No event history (SQLite only)
/// - ❌ No undo stack preservation
/// - ❌ Import requires schema migration if versions differ
///
/// ## Usage
///
/// ```dart
/// final exporter = JsonExporter();
/// await exporter.exportToFile(document, '/path/to/output.json');
/// ```
class JsonExporter {
  /// Logger instance for export operations.
  final Logger _logger = Logger();

  /// Current file format version for JSON exports.
  ///
  /// This version should be incremented when the JSON structure changes
  /// in a backward-incompatible way. Follows semantic versioning.
  static const String kFileFormatVersion = '2.0.0';

  /// Application version used in export metadata.
  ///
  /// This is read from the package version at runtime.
  static const String kAppVersion = '0.1.0';

  /// Exports a document to a JSON file with full metadata.
  ///
  /// Generates a JSON snapshot from the document and writes it to
  /// the specified file path with UTF-8 encoding.
  ///
  /// The export process:
  /// 1. Validates document schema version compatibility
  /// 2. Builds JSON structure with metadata headers
  /// 3. Serializes document using Document.toJson()
  /// 4. Writes to file with pretty printing
  /// 5. Logs performance metrics
  ///
  /// Parameters:
  /// - [document]: The document to export
  /// - [filePath]: Absolute path to the output JSON file
  /// - [prettyPrint]: Enable pretty printing (default: true)
  /// - [artboardIds]: Optional list of artboard IDs to export (null = all)
  ///
  /// Throws:
  /// - [FileSystemException] if file cannot be written
  /// - [ArgumentError] if document schema version is invalid
  /// - [Exception] for other export errors
  ///
  /// Example:
  /// ```dart
  /// final exporter = JsonExporter();
  /// try {
  ///   await exporter.exportToFile(document, '/path/to/archive.json');
  ///   print('Export successful!');
  /// } catch (e) {
  ///   print('Export failed: $e');
  /// }
  /// ```
  Future<void> exportToFile(
    Document document,
    String filePath, {
    bool prettyPrint = true,
    List<String>? artboardIds,
  }) async {
    final startTime = DateTime.now();

    try {
      _logger.d('Starting JSON export: document=${document.id}, path=$filePath');

      // Validate schema version
      _validateSchemaVersion(document);

      // Generate JSON content
      final jsonContent = generateJson(
        document,
        prettyPrint: prettyPrint,
        artboardIds: artboardIds,
      );

      // Write to file with UTF-8 encoding
      final file = File(filePath);
      await file.writeAsString(jsonContent, encoding: utf8);

      // Log performance metrics
      final duration = DateTime.now().difference(startTime);
      final artboardCount = artboardIds?.length ?? document.artboards.length;

      _logger.i(
        'JSON export completed: $artboardCount artboards, '
        '${duration.inMilliseconds}ms, path=$filePath',
      );
    } catch (e, stackTrace) {
      _logger.e('JSON export failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generates JSON string from a document with metadata wrapper.
  ///
  /// This method is exposed for testing purposes. It generates the complete
  /// JSON content without writing to a file.
  ///
  /// Parameters:
  /// - [document]: The document to export
  /// - [prettyPrint]: Enable pretty printing (default: true)
  /// - [artboardIds]: Optional list of artboard IDs to export (null = all)
  ///
  /// Returns the JSON document as a string.
  ///
  /// Example:
  /// ```dart
  /// final json = exporter.generateJson(document);
  /// final parsed = jsonDecode(json);
  /// print(parsed['fileFormatVersion']); // "2.0.0"
  /// ```
  String generateJson(
    Document document, {
    bool prettyPrint = true,
    List<String>? artboardIds,
  }) {
    // Filter artboards if requested
    final filteredDocument = artboardIds != null
        ? document.copyWith(
            artboards: document.artboards
                .where((ab) => artboardIds.contains(ab.id))
                .toList(),
          )
        : document;

    // Build export structure
    final exportData = {
      'fileFormatVersion': kFileFormatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportedBy': 'WireTuner v$kAppVersion',
      'document': filteredDocument.toJson(),
    };

    // Encode with optional pretty printing
    if (prettyPrint) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(exportData);
    } else {
      return jsonEncode(exportData);
    }
  }

  /// Validates that the document schema version is compatible with export.
  ///
  /// Throws [ArgumentError] if the document schema version exceeds the
  /// supported file format version.
  void _validateSchemaVersion(Document document) {
    if (document.schemaVersion > kDocumentSchemaVersion) {
      throw ArgumentError(
        'Document schema version ${document.schemaVersion} exceeds '
        'supported version $kDocumentSchemaVersion. Cannot export.',
      );
    }
  }

  /// Validates a JSON export file before import.
  ///
  /// This static method checks if a JSON export is compatible with the
  /// current application version before attempting to import.
  ///
  /// Parameters:
  /// - [jsonContent]: The JSON string to validate
  ///
  /// Returns:
  /// - [ValidationResult] with compatibility status and warnings
  ///
  /// Example:
  /// ```dart
  /// final content = await File(path).readAsString();
  /// final result = JsonExporter.validateImport(content);
  /// if (!result.isCompatible) {
  ///   print('Incompatible: ${result.error}');
  /// }
  /// ```
  static ValidationResult validateImport(String jsonContent) {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Check file format version
      final fileVersion = data['fileFormatVersion'] as String?;
      if (fileVersion == null) {
        return ValidationResult(
          isCompatible: false,
          error: 'Missing fileFormatVersion field',
        );
      }

      // Parse version components
      final parts = fileVersion.split('.');
      if (parts.length != 3) {
        return ValidationResult(
          isCompatible: false,
          error: 'Invalid version format: $fileVersion',
        );
      }

      final majorVersion = int.tryParse(parts[0]);
      final currentMajor = int.parse(kFileFormatVersion.split('.')[0]);

      if (majorVersion == null) {
        return ValidationResult(
          isCompatible: false,
          error: 'Invalid major version: ${parts[0]}',
        );
      }

      // Reject if major version exceeds current
      if (majorVersion > currentMajor) {
        return ValidationResult(
          isCompatible: false,
          error: 'File format version $fileVersion is too new. '
              'Current version: $kFileFormatVersion',
        );
      }

      // Warn if minor version differs
      final warnings = <String>[];
      if (majorVersion < currentMajor) {
        warnings.add(
          'File format version $fileVersion is older than current '
          'version $kFileFormatVersion. Migration may be required.',
        );
      }

      // Check for document payload
      final document = data['document'] as Map<String, dynamic>?;
      if (document == null) {
        return ValidationResult(
          isCompatible: false,
          error: 'Missing document payload',
        );
      }

      return ValidationResult(
        isCompatible: true,
        warnings: warnings,
      );
    } catch (e) {
      return ValidationResult(
        isCompatible: false,
        error: 'Failed to parse JSON: $e',
      );
    }
  }

  /// Imports a document from a JSON export file.
  ///
  /// This method reads a JSON export file, validates it, and reconstructs
  /// the document snapshot. Event history is NOT restored.
  ///
  /// Parameters:
  /// - [filePath]: Path to the JSON export file
  ///
  /// Returns:
  /// - [ImportResult] with the document and any warnings
  ///
  /// Throws:
  /// - [FileSystemException] if file cannot be read
  /// - [FormatException] if JSON is invalid
  /// - [ArgumentError] if file format is incompatible
  ///
  /// Example:
  /// ```dart
  /// final exporter = JsonExporter();
  /// final result = await exporter.importFromFile('/path/to/archive.json');
  /// if (result.warnings.isNotEmpty) {
  ///   print('Warnings: ${result.warnings}');
  /// }
  /// print('Loaded: ${result.document.title}');
  /// ```
  Future<ImportResult> importFromFile(String filePath) async {
    final startTime = DateTime.now();

    try {
      _logger.d('Starting JSON import: path=$filePath');

      // Read file content
      final file = File(filePath);
      final jsonContent = await file.readAsString(encoding: utf8);

      // Validate format
      final validation = validateImport(jsonContent);
      if (!validation.isCompatible) {
        throw ArgumentError(
          'Incompatible JSON export: ${validation.error}',
        );
      }

      // Parse JSON
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documentData = data['document'] as Map<String, dynamic>;

      // Reconstruct document
      final document = Document.fromJson(documentData);

      // Log performance metrics
      final duration = DateTime.now().difference(startTime);
      _logger.i(
        'JSON import completed: ${document.artboards.length} artboards, '
        '${duration.inMilliseconds}ms',
      );

      return ImportResult(
        document: document,
        warnings: validation.warnings,
      );
    } catch (e, stackTrace) {
      _logger.e('JSON import failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// Result of JSON import validation.
class ValidationResult {
  const ValidationResult({
    required this.isCompatible,
    this.error,
    this.warnings = const [],
  });

  /// Whether the file is compatible with the current version.
  final bool isCompatible;

  /// Error message if validation failed.
  final String? error;

  /// Warning messages for non-blocking issues.
  final List<String> warnings;
}

/// Result of a JSON import operation.
class ImportResult {
  const ImportResult({
    required this.document,
    this.warnings = const [],
  });

  /// The imported document.
  final Document document;

  /// Warning messages from the import process.
  final List<String> warnings;
}
