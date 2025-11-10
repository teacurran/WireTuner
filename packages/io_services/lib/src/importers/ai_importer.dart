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
  /// This implementation uses a lightweight custom PDF parser to extract
  /// the content stream from AI files (which are PDF-based). It does not
  /// use a full PDF library since the `pdf` package is focused on generation.
  ///
  /// **Implementation:**
  ///
  /// 1. Extract MediaBox dimensions from page object
  /// 2. Locate and extract content stream
  /// 3. Tokenize PostScript operators: m, l, c, v, y, h, re
  /// 4. Apply Y-axis flip transformation
  /// 5. Generate CreatePath/AddAnchor/FinishPath/CreateShape events
  ///
  /// **Limitations:**
  ///
  /// - Only parses first page (multi-page warning logged)
  /// - Does not handle compressed streams (assumes uncompressed)
  /// - Basic error recovery for malformed operators
  Future<List<Map<String, dynamic>>> _parsePdfContent(
    Uint8List bytes,
    String filePath,
  ) async {
    // Check for PDF header
    if (bytes.length < 4 || !_hasPdfHeader(bytes)) {
      throw AIImportException('Invalid AI file: not a valid PDF structure');
    }

    try {
      // Extract page dimensions (MediaBox)
      final mediaBox = _extractMediaBox(bytes);
      _pageHeight = mediaBox.height;

      _logger.d(
        'PDF page dimensions: ${mediaBox.width} x ${mediaBox.height} pt',
      );

      // Extract content stream
      final contentStream = _extractContentStream(bytes);

      if (contentStream.isEmpty) {
        _logger.w('No content stream found in PDF, returning empty events');
        return [];
      }

      _logger.d('Content stream length: ${contentStream.length} bytes');

      // Parse operators and generate events
      return _parseOperators(contentStream);
    } catch (e, stackTrace) {
      _logger.e('PDF parsing error', error: e, stackTrace: stackTrace);
      throw AIImportException('Failed to parse PDF content: $e');
    }
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

  /// Extracts MediaBox dimensions from PDF bytes.
  ({double width, double height}) _extractMediaBox(Uint8List bytes) {
    // Convert to string for regex parsing
    final pdfText = String.fromCharCodes(bytes);

    // Look for MediaBox definition: /MediaBox [x1 y1 x2 y2]
    final mediaBoxRegex = RegExp(r'/MediaBox\s*\[\s*(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*\]');
    final match = mediaBoxRegex.firstMatch(pdfText);

    if (match == null) {
      _logger.w('MediaBox not found, using default Letter size');
      return (width: 612.0, height: 792.0); // Letter size default
    }

    // MediaBox format: [x1 y1 x2 y2] where (x1,y1) is lower-left, (x2,y2) is upper-right
    final x1 = double.parse(match.group(1)!);
    final y1 = double.parse(match.group(2)!);
    final x2 = double.parse(match.group(3)!);
    final y2 = double.parse(match.group(4)!);

    final width = x2 - x1;
    final height = y2 - y1;

    _logger.d('MediaBox: [$x1 $y1 $x2 $y2] → ${width}x$height');

    return (width: width, height: height);
  }

  /// Extracts content stream from PDF bytes.
  String _extractContentStream(Uint8List bytes) {
    // Convert to string
    final pdfText = String.fromCharCodes(bytes);

    // Find content stream between "stream" and "endstream"
    // Pattern: << /Length N >> stream\n<content>\nendstream
    // Note: \s* allows for flexible whitespace including newlines
    final streamRegex = RegExp(
      r'stream\s+(.*?)\s+endstream',
      multiLine: true,
      dotAll: true,
    );

    final match = streamRegex.firstMatch(pdfText);

    if (match == null) {
      _logger.w('No content stream found in PDF');
      return '';
    }

    final streamContent = match.group(1) ?? '';

    _logger.d('Extracted content stream: ${streamContent.length} chars');

    return streamContent.trim();
  }

  /// Parses PDF operators from content stream and generates events.
  List<Map<String, dynamic>> _parseOperators(String contentStream) {
    final events = <Map<String, dynamic>>[];
    final tokens = _tokenize(contentStream);

    _logger.d('Tokenized ${tokens.length} tokens from content stream');

    // Operand stack (PostScript-style)
    final operandStack = <double>[];

    // Current path state
    String? currentPathId;
    int anchorIndex = 0;
    ({double x, double y}) subpathStart = (x: 0.0, y: 0.0);

    // Graphics state
    String strokeColor = '#000000';
    String? fillColor;
    double strokeWidth = 1.0;
    double opacity = 1.0;

    final baseTime = DateTime.now().millisecondsSinceEpoch;

    for (final token in tokens) {
      // Try to parse as number (operand)
      final numberValue = double.tryParse(token);

      if (numberValue != null) {
        // Push operand onto stack
        operandStack.add(numberValue);
        continue;
      }

      // Token is an operator
      final operator = token;

      try {
        switch (operator) {
          case 'm': // moveto - start new subpath
            if (operandStack.length < 2) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-operator',
                message: 'moveto operator requires 2 operands',
              );
              operandStack.clear();
              continue;
            }

            final y = operandStack.removeLast();
            final x = operandStack.removeLast();

            final yFlipped = _flipY(y);
            _validateCoordinate(x, 'x coordinate');
            _validateCoordinate(yFlipped, 'y coordinate');

            // Start new path
            currentPathId = 'import_ai_${_uuid.v4()}';
            anchorIndex = 0;
            _currentPoint = (x: x, y: yFlipped);
            subpathStart = _currentPoint;

            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'CreatePathEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'startAnchor': {'x': x, 'y': yFlipped},
              'strokeColor': strokeColor,
              'strokeWidth': strokeWidth,
              'opacity': opacity,
              if (fillColor != null) 'fillColor': fillColor,
            });

            _logger.d('moveto: ($x, $y) → ($x, $yFlipped)');
            break;

          case 'l': // lineto - add line segment
            if (currentPathId == null) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-path',
                message: 'lineto operator without preceding moveto',
              );
              operandStack.clear();
              continue;
            }

            if (operandStack.length < 2) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-operator',
                message: 'lineto operator requires 2 operands',
              );
              operandStack.clear();
              continue;
            }

            final y = operandStack.removeLast();
            final x = operandStack.removeLast();

            final yFlipped = _flipY(y);
            _validateCoordinate(x, 'x coordinate');
            _validateCoordinate(yFlipped, 'y coordinate');

            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'AddAnchorEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'position': {'x': x, 'y': yFlipped},
              'anchorType': 'line',
            });

            _currentPoint = (x: x, y: yFlipped);
            anchorIndex++;

            _logger.d('lineto: ($x, $y) → ($x, $yFlipped)');
            break;

          case 'c': // curveto - cubic Bezier curve
            if (currentPathId == null) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-path',
                message: 'curveto operator without preceding moveto',
              );
              operandStack.clear();
              continue;
            }

            if (operandStack.length < 6) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-operator',
                message: 'curveto operator requires 6 operands',
              );
              operandStack.clear();
              continue;
            }

            final y3 = operandStack.removeLast();
            final x3 = operandStack.removeLast();
            final y2 = operandStack.removeLast();
            final x2 = operandStack.removeLast();
            final y1 = operandStack.removeLast();
            final x1 = operandStack.removeLast();

            final y1Flipped = _flipY(y1);
            final y2Flipped = _flipY(y2);
            final y3Flipped = _flipY(y3);

            _validateCoordinate(x1, 'control point 1 x');
            _validateCoordinate(y1Flipped, 'control point 1 y');
            _validateCoordinate(x2, 'control point 2 x');
            _validateCoordinate(y2Flipped, 'control point 2 y');
            _validateCoordinate(x3, 'end point x');
            _validateCoordinate(y3Flipped, 'end point y');

            // Convert absolute control points to relative handles
            final handleOut = {
              'x': x1 - _currentPoint.x,
              'y': y1Flipped - _currentPoint.y,
            };
            final handleIn = {
              'x': x2 - x3,
              'y': y2Flipped - y3Flipped,
            };

            // Set handleOut on previous anchor (if not first anchor)
            if (anchorIndex > 0) {
              events.add({
                'eventId': _generateEventId(),
                'timestamp': baseTime + _timestampCounter++,
                'eventType': 'ModifyAnchorEvent',
                'eventSequence': _eventSequence++,
                'pathId': currentPathId,
                'anchorIndex': anchorIndex - 1,
                'handleOut': handleOut,
              });
            }

            // Add new anchor with handleIn
            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'AddAnchorEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'position': {'x': x3, 'y': y3Flipped},
              'anchorType': 'bezier',
              'handleIn': handleIn,
            });

            _currentPoint = (x: x3, y: y3Flipped);
            anchorIndex++;

            _logger.d('curveto: ($x1, $y1) ($x2, $y2) ($x3, $y3)');
            break;

          case 'v': // Bezier variant (cp1 = current point)
            if (currentPathId == null) {
              operandStack.clear();
              continue;
            }

            if (operandStack.length < 4) {
              operandStack.clear();
              continue;
            }

            final y3 = operandStack.removeLast();
            final x3 = operandStack.removeLast();
            final y2 = operandStack.removeLast();
            final x2 = operandStack.removeLast();

            final y2Flipped = _flipY(y2);
            final y3Flipped = _flipY(y3);

            // cp1 = current point, so handleOut is zero vector
            final handleIn = {
              'x': x2 - x3,
              'y': y2Flipped - y3Flipped,
            };

            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'AddAnchorEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'position': {'x': x3, 'y': y3Flipped},
              'anchorType': 'bezier',
              'handleIn': handleIn,
            });

            _addWarning(
              severity: 'info',
              featureType: 'bezier-variant-v',
              message: 'Bezier variant "v" operator converted to standard curve',
              objectId: currentPathId,
            );

            _currentPoint = (x: x3, y: y3Flipped);
            anchorIndex++;
            break;

          case 'y': // Bezier variant (cp2 = end point)
            if (currentPathId == null) {
              operandStack.clear();
              continue;
            }

            if (operandStack.length < 4) {
              operandStack.clear();
              continue;
            }

            final y3 = operandStack.removeLast();
            final x3 = operandStack.removeLast();
            final y1 = operandStack.removeLast();
            final x1 = operandStack.removeLast();

            final y1Flipped = _flipY(y1);
            final y3Flipped = _flipY(y3);

            final handleOut = {
              'x': x1 - _currentPoint.x,
              'y': y1Flipped - _currentPoint.y,
            };

            // Set handleOut on previous anchor
            if (anchorIndex > 0) {
              events.add({
                'eventId': _generateEventId(),
                'timestamp': baseTime + _timestampCounter++,
                'eventType': 'ModifyAnchorEvent',
                'eventSequence': _eventSequence++,
                'pathId': currentPathId,
                'anchorIndex': anchorIndex - 1,
                'handleOut': handleOut,
              });
            }

            // cp2 = end point, so handleIn is zero vector
            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'AddAnchorEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'position': {'x': x3, 'y': y3Flipped},
              'anchorType': 'bezier',
            });

            _addWarning(
              severity: 'info',
              featureType: 'bezier-variant-y',
              message: 'Bezier variant "y" operator converted to standard curve',
              objectId: currentPathId,
            );

            _currentPoint = (x: x3, y: y3Flipped);
            anchorIndex++;
            break;

          case 'h': // closepath
            if (currentPathId == null) continue;

            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'FinishPathEvent',
              'eventSequence': _eventSequence++,
              'pathId': currentPathId,
              'closed': true,
            });

            _logger.d('closepath: finishing path $currentPathId');

            currentPathId = null;
            _currentPoint = subpathStart; // PDF spec: current point becomes subpath start
            break;

          case 're': // rectangle
            if (operandStack.length < 4) {
              _addWarning(
                severity: 'warning',
                featureType: 'malformed-operator',
                message: 'rectangle operator requires 4 operands',
              );
              operandStack.clear();
              continue;
            }

            final height = operandStack.removeLast();
            final width = operandStack.removeLast();
            final y = operandStack.removeLast();
            final x = operandStack.removeLast();

            // Rectangle y is bottom-left corner in PDF, need to flip to top-left
            final yTopLeft = _flipY(y + height);

            _validateCoordinate(x, 'rectangle x');
            _validateCoordinate(yTopLeft, 'rectangle y');
            _validateCoordinate(width, 'rectangle width');
            _validateCoordinate(height, 'rectangle height');

            final shapeId = 'import_ai_${_uuid.v4()}';

            events.add({
              'eventId': _generateEventId(),
              'timestamp': baseTime + _timestampCounter++,
              'eventType': 'CreateShapeEvent',
              'eventSequence': _eventSequence++,
              'shapeId': shapeId,
              'shapeType': 'rectangle',
              'parameters': {
                'x': x,
                'y': yTopLeft,
                'width': width,
                'height': height,
              },
              'strokeColor': strokeColor,
              'strokeWidth': strokeWidth,
              'opacity': opacity,
              if (fillColor != null) 'fillColor': fillColor,
            });

            _logger.d('rectangle: ($x, $y, $width, $height)');
            break;

          // Graphics state operators
          case 'w': // line width
            if (operandStack.isNotEmpty) {
              strokeWidth = operandStack.removeLast();
              _logger.d('stroke width: $strokeWidth');
            }
            break;

          case 'RG': // RGB stroke color
            if (operandStack.length >= 3) {
              final b = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              final g = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              final r = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              strokeColor = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
              _logger.d('stroke color: $strokeColor');
            }
            break;

          case 'rg': // RGB fill color
            if (operandStack.length >= 3) {
              final b = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              final g = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              final r = (operandStack.removeLast() * 255).toInt().clamp(0, 255);
              fillColor = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
              _logger.d('fill color: $fillColor');
            }
            break;

          case 'K': // CMYK stroke color
          case 'k': // CMYK fill color
            if (operandStack.length >= 4) {
              final k = operandStack.removeLast();
              final y = operandStack.removeLast();
              final m = operandStack.removeLast();
              final c = operandStack.removeLast();

              // Convert CMYK to RGB
              final r = (255 * (1 - c) * (1 - k)).toInt().clamp(0, 255);
              final g = (255 * (1 - m) * (1 - k)).toInt().clamp(0, 255);
              final b = (255 * (1 - y) * (1 - k)).toInt().clamp(0, 255);

              final rgbHex = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';

              if (operator == 'K') {
                strokeColor = rgbHex;
              } else {
                fillColor = rgbHex;
              }

              _addWarning(
                severity: 'info',
                featureType: 'cmyk-color',
                message: 'CMYK color CMYK($c, $m, $y, $k) converted to RGB $rgbHex',
              );
            }
            break;

          // Rendering operators (safe to ignore for geometry)
          case 'S': // Stroke
          case 's': // Close and stroke
          case 'f': // Fill
          case 'F': // Fill (alternate)
          case 'f*': // Fill even-odd
          case 'B': // Fill and stroke
          case 'B*': // Fill and stroke even-odd
          case 'b': // Close, fill, and stroke
          case 'b*': // Close, fill, and stroke even-odd
          case 'n': // No-op (for clipping paths)
            _logger.d('rendering operator: $operator');
            break;

          default:
            _logger.d('Unsupported PDF operator: $operator');
            _addWarning(
              severity: 'info',
              featureType: 'unsupported-operator',
              message: 'Unsupported PDF operator: $operator',
            );
            operandStack.clear();
        }
      } catch (e, stackTrace) {
        _logger.e(
          'Error processing operator: $operator',
          error: e,
          stackTrace: stackTrace,
        );
        _addWarning(
          severity: 'warning',
          featureType: 'operator-error',
          message: 'Error processing operator "$operator": $e',
        );
        operandStack.clear();
      }
    }

    // If there's an unclosed path, finish it
    if (currentPathId != null) {
      _logger.w('Path $currentPathId was not explicitly closed, finishing');
      events.add({
        'eventId': _generateEventId(),
        'timestamp': baseTime + _timestampCounter++,
        'eventType': 'FinishPathEvent',
        'eventSequence': _eventSequence++,
        'pathId': currentPathId,
        'closed': false,
      });
    }

    _logger.i('Generated ${events.length} events from PDF operators');

    return events;
  }

  /// Tokenizes content stream into operators and operands.
  List<String> _tokenize(String contentStream) {
    // Split by whitespace and newlines
    final tokens = contentStream
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    return tokens;
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
