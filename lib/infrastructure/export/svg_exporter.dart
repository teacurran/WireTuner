import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/infrastructure/export/svg_writer.dart';

/// Service for exporting documents to SVG 1.1 format.
///
/// This service handles the complete workflow of converting a WireTuner document
/// to a standards-compliant SVG file. Key features:
/// - Converts paths and shapes to SVG path elements
/// - Exports layers as SVG groups
/// - Embeds document metadata (title, creator)
/// - Calculates optimal viewBox from document bounds
/// - Provides performance logging and error handling
///
/// ## Coordinate System
///
/// WireTuner uses screen coordinates (y increases downward), which matches
/// SVG's coordinate system. No transformation is needed during export.
///
/// ## Supported Features (Milestone 0.1)
///
/// - Paths (line and cubic Bezier segments)
/// - Shapes (converted to paths via toPath())
/// - Layers (exported as SVG groups)
/// - Document metadata (title, creator)
///
/// ## Tier-2 Export Capabilities
///
/// **Currently Exported:**
/// - ✅ Paths (line and cubic Bezier segments)
/// - ✅ Shapes (converted to paths via toPath())
/// - ✅ Compound paths (multiple segments with mixed line/Bezier)
/// - ✅ Layers (exported as SVG groups with proper hierarchy)
/// - ✅ Document metadata (title, creator, format in RDF)
/// - ✅ Coordinate precision (2 decimal places)
/// - ✅ XML well-formedness and SVG 1.1 compliance
///
/// **Infrastructure Ready (API exists, awaiting domain model support):**
/// - 🔧 Styles (stroke color, fill color, opacity) - VectorObject doesn't store style data yet
/// - 🔧 Gradients (linear and radial) - VectorObject doesn't store gradient definitions yet
/// - 🔧 Clipping masks - VectorObject doesn't store clipping relationships yet
/// - 🔧 Transform matrices - VectorObject doesn't store transforms yet
///
/// **Current Limitations:**
/// - All paths export with default black stroke, no fill (style system pending)
/// - No filter effects (drop shadows, blurs)
/// - No blend modes beyond normal
/// - No pattern fills
/// - No text rendering (text system not yet implemented)
/// - Selection state is ignored (not exported)
/// - Invisible layers are skipped
///
/// See `docs/reference/svg_export.md` for detailed limitations and roadmap.
///
/// ## Usage
///
/// ```dart
/// final exporter = SvgExporter();
/// await exporter.exportToFile(document, '/path/to/output.svg');
/// ```
class SvgExporter {
  /// Logger instance for export operations.
  final Logger _logger = Logger();

  /// Default canvas size when document has no objects.
  static const double _defaultWidth = 800.0;
  static const double _defaultHeight = 600.0;

  /// Exports a document to an SVG file.
  ///
  /// Generates SVG 1.1 XML content from the document and writes it to
  /// the specified file path with UTF-8 encoding.
  ///
  /// The export process:
  /// 1. Calculates document bounds for viewBox
  /// 2. Generates SVG XML structure
  /// 3. Writes to file with UTF-8 encoding
  /// 4. Logs performance metrics
  ///
  /// Parameters:
  /// - [document]: The document to export
  /// - [filePath]: Absolute path to the output SVG file
  ///
  /// Throws:
  /// - [FileSystemException] if file cannot be written
  /// - [Exception] for other export errors
  ///
  /// Example:
  /// ```dart
  /// final exporter = SvgExporter();
  /// try {
  ///   await exporter.exportToFile(document, '/Users/name/Desktop/drawing.svg');
  ///   print('Export successful!');
  /// } catch (e) {
  ///   print('Export failed: $e');
  /// }
  /// ```
  Future<void> exportToFile(Document document, String filePath) async {
    final startTime = DateTime.now();

    try {
      _logger.d('Starting SVG export: document=${document.id}, path=$filePath');

      // Generate SVG content
      final svgContent = generateSvg(document);

      // Write to file with UTF-8 encoding
      final file = File(filePath);
      await file.writeAsString(svgContent, encoding: utf8);

      // Log performance metrics
      final duration = DateTime.now().difference(startTime);
      final objectCount = _countObjects(document);

      _logger.i(
        'SVG export completed: $objectCount objects, '
        '${duration.inMilliseconds}ms, path=$filePath',
      );
    } catch (e, stackTrace) {
      _logger.e('SVG export failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generates SVG XML content from a document.
  ///
  /// This method is exposed for testing purposes. It generates the complete
  /// SVG document string without writing to a file.
  ///
  /// Returns the SVG document as an XML string.
  String generateSvg(Document document) {
    final writer = SvgWriter();

    // Calculate document bounds for viewBox
    final bounds = _calculateBounds(document);

    // Write SVG header
    writer.writeHeader(viewBox: bounds);

    // Collect all gradients and clip paths needed (for future enhancement)
    // This would scan all objects and extract gradient/clipping definitions
    final hasDefsContent = false; // Placeholder for future gradient detection

    // Write defs section if needed
    if (hasDefsContent) {
      writer.startDefs();
      // Future: Write gradients and clip paths here
      writer.endDefs();
    }

    // Write metadata
    writer.writeMetadata(title: document.title);

    // Write layers (skip invisible layers)
    for (final layer in document.layers) {
      if (!layer.visible) {
        _logger.d('Skipping invisible layer: ${layer.id}');
        continue;
      }

      // Start layer group
      writer.startGroup(id: layer.id, opacity: '1');

      // Write objects in layer
      for (final object in layer.objects) {
        _writeObject(writer, object);
      }

      // End layer group
      writer.endGroup();
    }

    // Write footer
    writer.writeFooter();

    return writer.build();
  }

  /// Writes a vector object to the SVG writer.
  ///
  /// Handles both path and shape objects by converting them to SVG path
  /// elements. Shapes are first converted to paths using their toPath() method.
  void _writeObject(SvgWriter writer, VectorObject object) {
    object.when(
      path: (id, path, _) {
        final pathData = pathToSvgPathData(path);
        writer.writePath(id: id, pathData: pathData);
      },
      shape: (id, shape, _) {
        // Convert shape to path first
        final path = shape.toPath();
        final pathData = pathToSvgPathData(path);
        writer.writePath(id: id, pathData: pathData);
      },
    );
  }

  /// Converts a Path to SVG path data string.
  ///
  /// Generates the SVG path data (d attribute) by:
  /// 1. Starting with 'M' (move) command at first anchor
  /// 2. Processing each segment:
  ///    - Line segments: 'L' command
  ///    - Bezier segments: 'C' command with control points
  /// 3. Adding 'Z' command if path is closed
  ///
  /// ## Coordinate Precision
  ///
  /// All coordinates are formatted with 2 decimal places to balance
  /// file size and visual precision.
  ///
  /// ## Handle Conversion
  ///
  /// Anchor handles are stored as relative offsets but SVG requires
  /// absolute positions. This method converts handles to absolute
  /// coordinates: `absoluteHandle = anchorPosition + relativeHandle`
  ///
  /// Parameters:
  /// - [path]: The path to convert
  ///
  /// Returns SVG path data string (e.g., "M 0.00 0.00 L 100.00 100.00")
  ///
  /// Example:
  /// ```dart
  /// final path = Path.line(
  ///   start: Point(x: 10, y: 20),
  ///   end: Point(x: 110, y: 70),
  /// );
  /// final svgData = pathToSvgPathData(path);
  /// // Result: "M 10.00 20.00 L 110.00 70.00"
  /// ```
  String pathToSvgPathData(Path path) {
    if (path.anchors.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    // Start with 'M' (move to first anchor)
    final firstAnchor = path.anchors[0];
    buffer.write(
        'M ${_fmt(firstAnchor.position.x)} ${_fmt(firstAnchor.position.y)}');

    // Process each segment
    for (final segment in path.segments) {
      final startAnchor = path.anchors[segment.startAnchorIndex];
      final endAnchor = path.anchors[segment.endAnchorIndex];

      if (segment.isLine) {
        // Line command: L x y
        buffer.write(
          ' L ${_fmt(endAnchor.position.x)} ${_fmt(endAnchor.position.y)}',
        );
      } else if (segment.isBezier) {
        // Cubic Bezier command: C x1 y1, x2 y2, x y
        // Convert relative handles to absolute positions
        final cp1 = startAnchor.handleOut != null
            ? startAnchor.position + startAnchor.handleOut!
            : startAnchor.position;

        final cp2 = endAnchor.handleIn != null
            ? endAnchor.position + endAnchor.handleIn!
            : endAnchor.position;

        buffer.write(' C ${_fmt(cp1.x)} ${_fmt(cp1.y)},');
        buffer.write(' ${_fmt(cp2.x)} ${_fmt(cp2.y)},');
        buffer.write(
            ' ${_fmt(endAnchor.position.x)} ${_fmt(endAnchor.position.y)}');
      }
    }

    // Close path if needed
    if (path.closed) {
      buffer.write(' Z');
    }

    return buffer.toString();
  }

  /// Calculates the bounding rectangle for the document.
  ///
  /// Computes the union of all object bounds across all visible layers.
  /// This determines the SVG viewBox size.
  ///
  /// Returns:
  /// - Union bounds if document has objects
  /// - Default 800x600 canvas if document is empty
  ///
  /// Example:
  /// ```dart
  /// final bounds = _calculateBounds(document);
  /// // bounds might be Rectangle(x: 0, y: 0, width: 1024, height: 768)
  /// ```
  Rectangle _calculateBounds(Document document) {
    Rectangle? bounds;

    for (final layer in document.layers) {
      // Consider all layers (visible and invisible) for bounds calculation
      // This ensures consistent viewBox even if layers are toggled
      for (final object in layer.objects) {
        final objBounds = object.getBounds();

        if (bounds == null) {
          bounds = objBounds;
        } else {
          bounds = bounds.union(objBounds);
        }
      }
    }

    // Return default canvas size if no objects
    return bounds ??
        const Rectangle(
          x: 0,
          y: 0,
          width: _defaultWidth,
          height: _defaultHeight,
        );
  }

  /// Counts total number of objects in document.
  ///
  /// Used for performance logging.
  int _countObjects(Document document) => document.layers.fold(
        0,
        (sum, layer) => sum + layer.objects.length,
      );

  /// Formats a coordinate value with 2 decimal places.
  String _fmt(double value) => value.toStringAsFixed(2);
}
