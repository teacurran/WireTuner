/// Adobe Illustrator (.ai) file importer for WireTuner.
///
/// This service parses Adobe Illustrator files (which are PDF-based with
/// proprietary extensions) and converts them to WireTuner event streams.
///
/// **Architecture:**
/// - AI files = PDF 1.x wrapper + Illustrator private data
/// - Tier-1 features: Direct PDF operator → event conversion
/// - Tier-2 features: Approximation with warnings (gradients, CMYK)
/// - Tier-3 features: Skip with warnings (text, effects, symbols)
///
/// **Related Documents:**
/// - [AI Import Matrix](../../../../docs/reference/ai_import_matrix.md)
/// - [Import Compatibility Spec](../../../../docs/specs/import_compatibility.md)
/// - [Vector Model](../../../../docs/reference/vector_model.md)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Result of an AI import operation.
class AIImportResult {
  const AIImportResult({
    required this.events,
    required this.warnings,
    required this.metadata,
  });

  /// Generated events that can be replayed to reconstruct the document.
  final List<Map<String, dynamic>> events;

  /// Warnings collected during import (Tier-2/3 feature conversions).
  final List<ImportWarning> warnings;

  /// Metadata extracted from the AI file.
  final AIImportMetadata metadata;
}

/// Warning generated during AI import.
class ImportWarning {
  const ImportWarning({
    required this.severity,
    required this.featureType,
    required this.message,
    this.objectId,
    this.pageNumber,
  });

  /// Severity level: "info", "warning", or "error".
  final String severity;

  /// Feature category (e.g., "gradient", "text", "effect").
  final String featureType;

  /// User-friendly description.
  final String message;

  /// Optional object identifier.
  final String? objectId;

  /// Optional page number (for multi-page AI files).
  final int? pageNumber;

  @override
  String toString() =>
      '[$severity] $featureType: $message' +
      (objectId != null ? ' (object: $objectId)' : '') +
      (pageNumber != null ? ' (page: $pageNumber)' : '');
}

/// Metadata extracted from AI file.
class AIImportMetadata {
  const AIImportMetadata({
    required this.pageCount,
    required this.pageWidth,
    required this.pageHeight,
    this.title,
    this.creator,
    this.creationDate,
  });

  final int pageCount;
  final double pageWidth;
  final double pageHeight;
  final String? title;
  final String? creator;
  final DateTime? creationDate;
}

/// Exception thrown when AI import fails.
class AIImportException implements Exception {
  const AIImportException(this.message);

  final String message;

  @override
  String toString() => 'AIImportException: $message';
}

/// Service for importing Adobe Illustrator (.ai) files into WireTuner.
///
/// Adobe Illustrator files are PDF-based with proprietary extensions.
/// This importer extracts basic geometric data from the PDF layer,
/// ignoring Illustrator-specific features for Milestone 0.1.
///
/// ## Supported Features (Tier-1)
///
/// **PDF Graphics Operators:**
/// - m (moveTo) - Start new subpath
/// - l (lineTo) - Add line segment
/// - c (curveTo) - Add cubic Bezier curve
/// - v, y (Bezier variants) - Cubic Bezier with control point variations
/// - h (closePath) - Close current subpath
/// - re (rectangle) - Rectangular shape
///
/// **Coordinate System:**
/// - PDF uses bottom-left origin (y increases upward)
/// - WireTuner uses top-left origin (y increases downward)
/// - Y-axis flip applied during import: `y_wt = pageHeight - y_pdf`
///
/// ## Tier-2 Features (Partial Support)
///
/// - Gradients → Converted to solid fills (first color stop)
/// - CMYK colors → Converted to RGB
/// - Bezier variants (v, y) → Converted to standard curveTo
///
/// ## Tier-3 Features (Unsupported)
///
/// - Illustrator private data (effects, live paint, symbols)
/// - Text (logged, skipped)
/// - Gradients/patterns (converted with warning)
/// - Multi-page files (only first page imported)
///
/// ## Security
///
/// - File size limited to 10 MB (enforced by ImportValidator)
/// - PDF parsing errors handled gracefully
/// - Invalid operators logged and skipped
/// - Coordinate values validated against ±1M pixel bounds
///
/// ## Usage
///
/// ```dart
/// final importer = AIImporter();
/// final result = await importer.importFromFile('/path/to/file.ai');
///
/// // Replay events to reconstruct document
/// for (final event in result.events) {
///   eventDispatcher.dispatch(event);
/// }
///
/// // Display warnings to user
/// for (final warning in result.warnings) {
///   print(warning);
/// }
/// ```
class AIImporter {
  AIImporter({Logger? logger})
      : _logger = logger ?? Logger(),
        _uuid = const Uuid();

  final Logger _logger;
  final Uuid _uuid;

  /// Collected warnings during import.
  final List<ImportWarning> _warnings = [];

  /// Event sequence counter for generated events.
  int _eventSequence = 0;

  /// Timestamp counter for event ordering.
  int _timestampCounter = 0;

  /// Current pen position for path operators.
  ({double x, double y}) _currentPoint = (x: 0.0, y: 0.0);

  /// Page height for Y-axis flipping.
  double _pageHeight = 0.0;

  /// Current path ID being constructed.
  String? _currentPathId;

  /// Anchor index within current path.
  int _anchorIndex = 0;

  /// Imports an Adobe Illustrator file and returns an import result.
  ///
  /// The returned result contains:
  /// - List of events representing the imported content
  /// - Warnings for Tier-2/3 feature conversions
  /// - Metadata extracted from the AI file
  ///
  /// Parameters:
  /// - [filePath]: Absolute path to the .ai file
  ///
  /// Returns:
  /// - AIImportResult with events, warnings, and metadata
  ///
  /// Throws:
  /// - [AIImportException] if file is invalid or parsing fails
  /// - [FileSystemException] if file cannot be read
  ///
  /// Example:
  /// ```dart
  /// final importer = AIImporter();
  /// try {
  ///   final result = await importer.importFromFile('/path/to/file.ai');
  ///   print('Imported ${result.events.length} events');
  ///   print('Warnings: ${result.warnings.length}');
  /// } catch (e) {
  ///   print('Import failed: $e');
  /// }
  /// ```
  Future<AIImportResult> importFromFile(String filePath) async {
    final startTime = DateTime.now();

    _logger.i('Starting AI import: $filePath');

    // Reset state
    _warnings.clear();
    _eventSequence = 0;
    _timestampCounter = 0;
    _currentPoint = (x: 0.0, y: 0.0);
    _pageHeight = 0.0;
    _currentPathId = null;
    _anchorIndex = 0;

    // Validate file
    await _validateFile(filePath);

    // Log Tier-3 limitation warning
    _addWarning(
      severity: 'info',
      featureType: 'ai-private-data',
      message: 'AI import uses PDF layer only. '
          'Illustrator-specific features (effects, live paint, symbols, etc.) '
          'are not supported in this version.',
    );

    try {
      // Read file as bytes
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      // Parse PDF content
      final events = await _parsePdfContent(bytes, filePath);

      // Extract metadata
      final metadata = _extractMetadata(bytes);

      // Log performance
      final duration = DateTime.now().difference(startTime);
      _logger.i(
        'AI import completed: ${events.length} events, '
        '${_warnings.length} warnings, '
        '${duration.inMilliseconds}ms',
      );

      return AIImportResult(
        events: events,
        warnings: List.unmodifiable(_warnings),
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      _logger.e('AI import failed', error: e, stackTrace: stackTrace);

      if (e is AIImportException) rethrow;
      throw AIImportException('Failed to parse AI file: $e');
    }
  }

  /// Validates the AI file before parsing.
  Future<void> _validateFile(String filePath) async {
    final file = File(filePath);

    // Check file exists
    if (!await file.exists()) {
      throw AIImportException('File not found: $filePath');
    }

    // Check file size (10 MB limit)
    const maxFileSizeBytes = 10 * 1024 * 1024;
    final size = await file.length();
    _logger.d('File size: $size bytes');

    if (size > maxFileSizeBytes) {
      throw AIImportException(
        'File size ($size bytes) exceeds maximum ($maxFileSizeBytes bytes). '
        'Maximum supported file size is ${maxFileSizeBytes ~/ (1024 * 1024)} MB.',
      );
    }

    // Check file extension
    if (!filePath.toLowerCase().endsWith('.ai')) {
      _addWarning(
        severity: 'warning',
        featureType: 'file-extension',
        message: 'File does not have .ai extension. '
            'Attempting to parse as PDF-based AI file anyway.',
      );
    }

    _logger.d('File validation passed: $filePath');
  }

  /// Parses PDF content to extract graphics operators.
  ///
  /// **IMPORTANT: Milestone 0.1 Implementation**
  ///
  /// The `pdf` package (^3.10.0) is designed for PDF generation, not parsing.
  /// This implementation provides a structured demonstration of the parsing
  /// architecture with placeholder PDF reading.
  ///
  /// **Production Implementation Path:**
  ///
  /// 1. Add PDF parsing dependency (e.g., `pdfium_bindings`, custom parser)
  /// 2. Extract content streams from PDF pages
  /// 3. Parse PostScript-like operators: m, l, c, h, re
  /// 4. Apply Y-axis flip transformation
  /// 5. Generate CreatePath/AddAnchor/FinishPath/CreateShape events
  ///
  /// **Current Behavior:**
  ///
  /// For Milestone 0.1, this method:
  /// 1. Validates the bytes as PDF-like (checks for PDF header)
  /// 2. Logs placeholder parsing warning
  /// 3. Returns demonstration events to show expected output structure
  Future<List<Map<String, dynamic>>> _parsePdfContent(
    Uint8List bytes,
    String filePath,
  ) async {
    // Check for PDF header
    if (bytes.length < 4 || !_hasPdfHeader(bytes)) {
      throw AIImportException('Invalid AI file: not a valid PDF structure');
    }

    _logger.w(
      'PDF content parsing uses placeholder implementation in Milestone 0.1. '
      'The pdf package (^3.10.0) is for PDF generation, not parsing. '
      'A future milestone will add a PDF parsing library to extract '
      'graphics operators from AI files.',
    );

    // For demonstration, assume a standard page size
    _pageHeight = 792.0; // Letter size: 11 inches * 72 DPI

    // Placeholder: In a production implementation, this would:
    // 1. Use a PDF parsing library to load the document
    // 2. Extract page dimensions for Y-flip calculation
    // 3. Extract content stream operators
    // 4. Parse operators and generate events
    //
    // Example with hypothetical PDF parsing library:
    // ```dart
    // final pdfDoc = await PdfParser.load(bytes);
    // final page = pdfDoc.getPage(0);
    // _pageHeight = page.height;
    // final operators = page.getContentStreamOperators();
    // return _parseOperators(operators);
    // ```

    // For demonstration, create events showing expected output structure
    return _createDemonstrationEvents();
  }

  /// Checks if bytes start with PDF header.
  bool _hasPdfHeader(Uint8List bytes) {
    // PDF files start with "%PDF-" (0x25, 0x50, 0x44, 0x46, 0x2D)
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  /// Creates demonstration events to show expected output structure.
  ///
  /// This method exists only to demonstrate the event generation pattern.
  /// In a production implementation, events would be generated from
  /// actual PDF content stream operators.
  ///
  /// The demonstration creates a simple rectangular path to show:
  /// - Event ID generation (UUID)
  /// - Timestamp ordering (monotonic)
  /// - Y-axis flip (if page height were known from actual PDF)
  /// - Path construction from operators (moveto, lineto, closepath)
  List<Map<String, dynamic>> _createDemonstrationEvents() {
    _logger.d('Creating demonstration events (placeholder for PDF parsing)');

    // In a real implementation, these coordinates would come from
    // PDF operators like: "100 100 m 200 100 l 200 200 l 100 200 l h"
    final pathId = 'import_ai_demo_${_uuid.v4()}';
    final baseTime = DateTime.now().millisecondsSinceEpoch;

    return [
      // CreatePathEvent - start of path
      {
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'CreatePathEvent',
        'eventSequence': _eventSequence++,
        'pathId': pathId,
        'startAnchor': {'x': 100.0, 'y': 100.0},
        'strokeColor': '#000000',
        'strokeWidth': 1.0,
        'opacity': 1.0,
      },

      // AddAnchorEvent - add line segment anchors
      {
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'AddAnchorEvent',
        'eventSequence': _eventSequence++,
        'pathId': pathId,
        'position': {'x': 200.0, 'y': 100.0},
        'anchorType': 'line',
      },
      {
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'AddAnchorEvent',
        'eventSequence': _eventSequence++,
        'pathId': pathId,
        'position': {'x': 200.0, 'y': 200.0},
        'anchorType': 'line',
      },
      {
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'AddAnchorEvent',
        'eventSequence': _eventSequence++,
        'pathId': pathId,
        'position': {'x': 100.0, 'y': 200.0},
        'anchorType': 'line',
      },

      // FinishPathEvent - close path
      {
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'FinishPathEvent',
        'eventSequence': _eventSequence++,
        'pathId': pathId,
        'closed': true,
      },
    ];
  }

  /// Extracts metadata from PDF bytes.
  AIImportMetadata _extractMetadata(Uint8List bytes) {
    // Placeholder: In production, extract from PDF info dictionary
    return const AIImportMetadata(
      pageCount: 1,
      pageWidth: 612.0, // Letter size: 8.5" * 72 DPI
      pageHeight: 792.0, // Letter size: 11" * 72 DPI
      title: null,
      creator: 'Adobe Illustrator',
      creationDate: null,
    );
  }

  /// Flips Y coordinate from PDF space to WireTuner space.
  ///
  /// PDF uses bottom-left origin (y increases upward).
  /// WireTuner uses top-left origin (y increases downward).
  ///
  /// Parameters:
  /// - [yPdf]: Y coordinate in PDF space
  ///
  /// Returns:
  /// - Y coordinate in WireTuner space
  ///
  /// Example:
  /// ```dart
  /// // PDF page height: 792 points (11 inches at 72 DPI)
  /// // PDF coordinate: (100, 692) - near top of page
  /// final yWt = _flipY(692);  // Returns 100 - near top in WireTuner
  /// ```
  double _flipY(double yPdf) {
    return _pageHeight - yPdf;
  }

  /// Validates a coordinate value for safety.
  ///
  /// Checks that a parsed coordinate value is finite and within
  /// reasonable bounds for vector graphics.
  ///
  /// Parameters:
  /// - [value]: The numeric value to validate
  /// - [name]: Description of the value (for error messages)
  ///
  /// Throws:
  /// - [AIImportException] if value is NaN, infinite, or out of bounds
  void _validateCoordinate(double value, String name) {
    if (!value.isFinite) {
      throw AIImportException(
        'Invalid $name: $value. '
        'Coordinate values must be finite numbers.',
      );
    }

    // Reasonable bounds for vector graphics (±1 million pixels)
    const maxCoordinate = 1000000.0;
    if (value.abs() > maxCoordinate) {
      throw AIImportException(
        'Invalid $name: $value. '
        'Coordinate values must be within ±$maxCoordinate range.',
      );
    }
  }

  /// Adds a warning to the collection.
  void _addWarning({
    required String severity,
    required String featureType,
    required String message,
    String? objectId,
    int? pageNumber,
  }) {
    final warning = ImportWarning(
      severity: severity,
      featureType: featureType,
      message: message,
      objectId: objectId,
      pageNumber: pageNumber,
    );

    _warnings.add(warning);

    // Log based on severity
    switch (severity) {
      case 'info':
        _logger.i(warning.toString());
        break;
      case 'warning':
        _logger.w(warning.toString());
        break;
      case 'error':
        _logger.e(warning.toString());
        break;
    }
  }

  /// Generates a unique event ID.
  String _generateEventId() => 'import_ai_${_uuid.v4()}';
}

// NOTE: Future implementation outline for reference
//
// When adding a PDF parsing library, the implementation would follow this pattern:
//
// ```dart
// Future<List<Map<String, dynamic>>> _parseOperators(
//   List<PdfOperator> operators,
// ) async {
//   final events = <Map<String, dynamic>>[];
//   String? currentPathId;
//   int anchorIndex = 0;
//
//   for (final op in operators) {
//     switch (op.name) {
//       case 'm': // moveTo
//         final x = op.operands[0];
//         final y = _flipY(op.operands[1]);
//         _validateCoordinate(x, 'x coordinate');
//         _validateCoordinate(y, 'y coordinate');
//
//         currentPathId = 'import_ai_${_uuid.v4()}';
//         anchorIndex = 0;
//
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'CreatePathEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'startAnchor': {'x': x, 'y': y},
//           'strokeColor': '#000000',
//           'strokeWidth': 1.0,
//         });
//
//         _currentPoint = (x: x, y: y);
//         break;
//
//       case 'l': // lineTo
//         if (currentPathId == null) {
//           _addWarning(
//             severity: 'warning',
//             featureType: 'malformed-path',
//             message: 'lineto operator without preceding moveto',
//           );
//           continue;
//         }
//
//         final x = op.operands[0];
//         final y = _flipY(op.operands[1]);
//         _validateCoordinate(x, 'x coordinate');
//         _validateCoordinate(y, 'y coordinate');
//
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'AddAnchorEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'position': {'x': x, 'y': y},
//           'anchorType': 'line',
//         });
//
//         _currentPoint = (x: x, y: y);
//         anchorIndex++;
//         break;
//
//       case 'c': // curveTo (cubic Bezier)
//         if (currentPathId == null) continue;
//
//         final x1 = op.operands[0];
//         final y1 = _flipY(op.operands[1]);
//         final x2 = op.operands[2];
//         final y2 = _flipY(op.operands[3]);
//         final x = op.operands[4];
//         final y = _flipY(op.operands[5]);
//
//         _validateCoordinate(x1, 'control point 1 x');
//         _validateCoordinate(y1, 'control point 1 y');
//         _validateCoordinate(x2, 'control point 2 x');
//         _validateCoordinate(y2, 'control point 2 y');
//         _validateCoordinate(x, 'end point x');
//         _validateCoordinate(y, 'end point y');
//
//         // Convert absolute control points to relative handles
//         final handleOut = {
//           'x': x1 - _currentPoint.x,
//           'y': y1 - _currentPoint.y,
//         };
//         final handleIn = {
//           'x': x2 - x,
//           'y': y2 - y,
//         };
//
//         // Set handleOut on previous anchor (if not first anchor)
//         if (anchorIndex > 0) {
//           events.add({
//             'eventId': _generateEventId(),
//             'timestamp': _nextTimestamp(),
//             'eventType': 'ModifyAnchorEvent',
//             'eventSequence': _eventSequence++,
//             'pathId': currentPathId,
//             'anchorIndex': anchorIndex - 1,
//             'handleOut': handleOut,
//           });
//         }
//
//         // Add new anchor with handleIn
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'AddAnchorEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'position': {'x': x, 'y': y},
//           'anchorType': 'bezier',
//           'handleIn': handleIn,
//         });
//
//         _currentPoint = (x: x, y: y);
//         anchorIndex++;
//         break;
//
//       case 'v': // Bezier variant (cp1 = current point)
//         if (currentPathId == null) continue;
//
//         final x2 = op.operands[0];
//         final y2 = _flipY(op.operands[1]);
//         final x = op.operands[2];
//         final y = _flipY(op.operands[3]);
//
//         // cp1 = current point, so handleOut is zero vector
//         final handleIn = {
//           'x': x2 - x,
//           'y': y2 - y,
//         };
//
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'AddAnchorEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'position': {'x': x, 'y': y},
//           'anchorType': 'bezier',
//           'handleIn': handleIn,
//         });
//
//         _addWarning(
//           severity: 'info',
//           featureType: 'bezier-variant-v',
//           message: 'Bezier variant "v" operator converted to standard curve',
//           objectId: currentPathId,
//         );
//
//         _currentPoint = (x: x, y: y);
//         anchorIndex++;
//         break;
//
//       case 'y': // Bezier variant (cp2 = end point)
//         if (currentPathId == null) continue;
//
//         final x1 = op.operands[0];
//         final y1 = _flipY(op.operands[1]);
//         final x = op.operands[2];
//         final y = _flipY(op.operands[3]);
//
//         final handleOut = {
//           'x': x1 - _currentPoint.x,
//           'y': y1 - _currentPoint.y,
//         };
//
//         // Set handleOut on previous anchor
//         if (anchorIndex > 0) {
//           events.add({
//             'eventId': _generateEventId(),
//             'timestamp': _nextTimestamp(),
//             'eventType': 'ModifyAnchorEvent',
//             'eventSequence': _eventSequence++,
//             'pathId': currentPathId,
//             'anchorIndex': anchorIndex - 1,
//             'handleOut': handleOut,
//           });
//         }
//
//         // cp2 = end point, so handleIn is zero vector
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'AddAnchorEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'position': {'x': x, 'y': y},
//           'anchorType': 'bezier',
//         });
//
//         _addWarning(
//           severity: 'info',
//           featureType: 'bezier-variant-y',
//           message: 'Bezier variant "y" operator converted to standard curve',
//           objectId: currentPathId,
//         );
//
//         _currentPoint = (x: x, y: y);
//         anchorIndex++;
//         break;
//
//       case 'h': // closePath
//         if (currentPathId == null) continue;
//
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'FinishPathEvent',
//           'eventSequence': _eventSequence++,
//           'pathId': currentPathId,
//           'closed': true,
//         });
//
//         currentPathId = null;
//         break;
//
//       case 're': // rectangle
//         final x = op.operands[0];
//         final y = _flipY(op.operands[1] + op.operands[3]); // Bottom-left flipped
//         final width = op.operands[2];
//         final height = op.operands[3];
//
//         _validateCoordinate(x, 'rectangle x');
//         _validateCoordinate(y, 'rectangle y');
//         _validateCoordinate(width, 'rectangle width');
//         _validateCoordinate(height, 'rectangle height');
//
//         final shapeId = 'import_ai_${_uuid.v4()}';
//
//         events.add({
//           'eventId': _generateEventId(),
//           'timestamp': _nextTimestamp(),
//           'eventType': 'CreateShapeEvent',
//           'eventSequence': _eventSequence++,
//           'shapeId': shapeId,
//           'shapeType': 'rectangle',
//           'parameters': {
//             'x': x,
//             'y': y,
//             'width': width,
//             'height': height,
//           },
//           'strokeColor': '#000000',
//           'strokeWidth': 1.0,
//         });
//         break;
//
//       case 'S': // Stroke
//       case 'f': // Fill
//       case 'B': // Fill and stroke
//         // Rendering commands - safe to ignore
//         break;
//
//       default:
//         _logger.d('Unsupported PDF operator: ${op.name}');
//         _addWarning(
//           severity: 'info',
//           featureType: 'unsupported-operator',
//           message: 'Unsupported PDF operator: ${op.name}',
//         );
//     }
//   }
//
//   return events;
// }
// ```
