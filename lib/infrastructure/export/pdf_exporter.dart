import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';

/// Service for exporting documents to PDF format.
///
/// This service handles the complete workflow of converting a WireTuner document
/// to a standards-compliant PDF file with vector fidelity. Key features:
/// - Converts paths and shapes to PDF vector path commands
/// - Exports layers as PDF content (respects visibility)
/// - Embeds document metadata (title, creator, dates)
/// - Calculates optimal page size from document bounds
/// - Provides performance logging and error handling
///
/// ## Coordinate System
///
/// **CRITICAL**: PDF uses bottom-left origin (y increases upward), while
/// WireTuner uses top-left origin (y increases downward). This exporter
/// transforms all Y coordinates during drawing:
///
/// ```dart
/// pdfY = pageHeight - wireTunerY
/// ```
///
/// This ensures correct orientation when opening PDFs in viewers.
///
/// ## Supported Features (Milestone 0.1)
///
/// - Paths (line and cubic Bezier segments)
/// - Shapes (converted to paths via toPath())
/// - Layers (visible layers only)
/// - Document metadata (title, creator, creation date)
/// - Vector preservation (no rasterization)
///
/// ## Limitations (Milestone 0.1)
///
/// - No style export (all paths use default black stroke, no fill)
/// - RGB color space only (CMYK support planned for future milestone)
/// - Single-page export (multi-page/artboard support planned)
/// - Selection state is ignored (not exported)
/// - Invisible layers are skipped
/// - No gradient, filter, or effect support
///
/// ## Color Profile Note
///
/// Milestone 0.1 exports all paths with RGB black stroke. CMYK color
/// conversion and ICC profile embedding will be added in a future milestone
/// when the style system is implemented.
///
/// ## Usage
///
/// ```dart
/// final exporter = PdfExporter();
/// await exporter.exportToFile(document, '/path/to/output.pdf');
/// ```
class PdfExporter {
  /// Logger instance for export operations.
  final Logger _logger = Logger();

  /// Default page size when document has no objects (US Letter).
  /// Standard US Letter size in PDF points (1/72 inch).
  static const double _defaultWidth = 612.0; // 8.5 inches
  static const double _defaultHeight = 792.0; // 11 inches

  /// Exports a document to a PDF file.
  ///
  /// Generates PDF binary content from the document and writes it to
  /// the specified file path.
  ///
  /// The export process:
  /// 1. Calculates document bounds for page size
  /// 2. Generates PDF structure with metadata
  /// 3. Draws all visible layers with vector paths
  /// 4. Writes binary PDF data to file
  /// 5. Logs performance metrics
  ///
  /// Parameters:
  /// - [document]: The document to export
  /// - [filePath]: Absolute path to the output PDF file
  ///
  /// Throws:
  /// - [FileSystemException] if file cannot be written
  /// - [Exception] for other export errors
  ///
  /// Example:
  /// ```dart
  /// final exporter = PdfExporter();
  /// try {
  ///   await exporter.exportToFile(document, '/Users/name/Desktop/drawing.pdf');
  ///   print('Export successful!');
  /// } catch (e) {
  ///   print('Export failed: $e');
  /// }
  /// ```
  Future<void> exportToFile(Document document, String filePath) async {
    final startTime = DateTime.now();

    try {
      _logger.d('Starting PDF export: document=${document.id}, path=$filePath');

      // Generate PDF binary content
      final pdfBytes = await generatePdf(document);

      // Write to file as binary data (NOT text)
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Log performance metrics
      final duration = DateTime.now().difference(startTime);
      final objectCount = _countObjects(document);

      _logger.i(
        'PDF export completed: $objectCount objects, '
        '${duration.inMilliseconds}ms, path=$filePath',
      );
    } catch (e, stackTrace) {
      _logger.e('PDF export failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generates PDF binary content from a document.
  ///
  /// This method is exposed for testing purposes. It generates the complete
  /// PDF document as binary data without writing to a file.
  ///
  /// Returns the PDF document as a Uint8List (binary format).
  Future<Uint8List> generatePdf(Document document) async {
    // Create PDF document with metadata
    final pdf = pw.Document(
      title: document.title,
      creator: 'WireTuner 0.1',
      producer: 'pdf package',
      subject: 'Vector illustration created with WireTuner',
    );

    // Calculate document bounds for page sizing
    final bounds = _calculateBounds(document);

    // Add single page with custom size (fit to content)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          bounds.width,
          bounds.height,
          marginAll: 0, // No margins for vector graphics
        ),
        build: (context) => pw.CustomPaint(
          painter: (canvas, size) {
            // Draw document content
            _drawDocument(canvas, document, bounds);
          },
        ),
      ),
    );

    // Save PDF to binary format
    return pdf.save();
  }

  /// Draws the entire document onto a PDF canvas.
  ///
  /// Iterates through all layers and objects, drawing visible content
  /// with proper coordinate system transformation.
  void _drawDocument(
    PdfGraphics graphics,
    Document document,
    Rectangle bounds,
  ) {
    // Iterate through layers
    for (final layer in document.layers) {
      // Skip invisible layers
      if (!layer.visible) {
        _logger.d('Skipping invisible layer: ${layer.id}');
        continue;
      }

      // Draw all objects in the layer
      for (final object in layer.objects) {
        _drawObject(graphics, object, bounds.height);
      }
    }
  }

  /// Draws a vector object on the PDF canvas.
  ///
  /// Handles both path and shape objects by converting them to PDF path
  /// commands. Shapes are first converted to paths using their toPath() method.
  void _drawObject(
    PdfGraphics graphics,
    VectorObject object,
    double pageHeight,
  ) {
    object.when(
      path: (id, path) {
        _drawPath(graphics, path, pageHeight);
      },
      shape: (id, shape) {
        // Convert shape to path first
        final path = shape.toPath();
        _drawPath(graphics, path, pageHeight);
      },
    );
  }

  /// Draws a path on the PDF canvas with coordinate transformation.
  ///
  /// Converts WireTuner path segments to PDF path commands:
  /// - Line segments → lineTo()
  /// - Bezier segments → curveTo()
  /// - Closed paths → closePath()
  ///
  /// **Coordinate System Transformation**:
  /// PDF uses bottom-left origin (y up), WireTuner uses top-left (y down).
  /// All Y coordinates are transformed: pdfY = pageHeight - wireTunerY
  ///
  /// **Handle Conversion**:
  /// Anchor handles are stored as relative offsets. This method converts
  /// them to absolute positions: `absoluteHandle = anchorPosition + handle`
  ///
  /// **Style Rendering** (Milestone 0.2+):
  /// When VectorObject gains style data, this method will apply stroke/fill
  /// colors and gradients. Current implementation uses default black stroke.
  void _drawPath(
    PdfGraphics graphics,
    Path path,
    double pageHeight, {
    PdfColor? strokeColor,
    PdfColor? fillColor,
    double strokeWidth = 1.0,
  }) {
    if (path.anchors.isEmpty) {
      return; // Nothing to draw
    }

    // Start path at first anchor
    final firstAnchor = path.anchors[0];
    graphics.moveTo(
      firstAnchor.position.x,
      _pdfY(firstAnchor.position.y, pageHeight),
    );

    // Process each segment
    for (final segment in path.segments) {
      // Validate segment indices (defensive programming)
      if (segment.startAnchorIndex >= path.anchors.length ||
          segment.endAnchorIndex >= path.anchors.length) {
        _logger.w(
          'Invalid segment indices: start=${segment.startAnchorIndex}, '
          'end=${segment.endAnchorIndex}, anchors=${path.anchors.length}',
        );
        continue;
      }

      final startAnchor = path.anchors[segment.startAnchorIndex];
      final endAnchor = path.anchors[segment.endAnchorIndex];

      if (segment.isLine) {
        // Draw straight line
        graphics.lineTo(
          endAnchor.position.x,
          _pdfY(endAnchor.position.y, pageHeight),
        );
      } else if (segment.isBezier) {
        // Draw cubic Bezier curve
        // Convert relative handles to absolute positions
        final cp1 = startAnchor.handleOut != null
            ? startAnchor.position + startAnchor.handleOut!
            : startAnchor.position;

        final cp2 = endAnchor.handleIn != null
            ? endAnchor.position + endAnchor.handleIn!
            : endAnchor.position;

        // Transform all points to PDF coordinate system
        graphics.curveTo(
          cp1.x,
          _pdfY(cp1.y, pageHeight),
          cp2.x,
          _pdfY(cp2.y, pageHeight),
          endAnchor.position.x,
          _pdfY(endAnchor.position.y, pageHeight),
        );
      }
    }

    // Close path if needed
    if (path.closed) {
      graphics.closePath();
    }

    // Apply stroke and/or fill based on provided colors
    // Default: black stroke with no fill (Milestone 0.1 behavior)
    final hasStroke = strokeColor != null;
    final hasFill = fillColor != null;

    if (hasStroke && hasFill) {
      // Both stroke and fill
      graphics
        ..setStrokeColor(strokeColor)
        ..setLineWidth(strokeWidth)
        ..setFillColor(fillColor)
        ..fillAndStrokePath();
    } else if (hasFill) {
      // Fill only
      graphics
        ..setFillColor(fillColor)
        ..fillPath();
    } else {
      // Stroke only (default)
      graphics
        ..setStrokeColor(strokeColor ?? PdfColors.black)
        ..setLineWidth(strokeWidth)
        ..strokePath();
    }
  }

  /// Transforms WireTuner Y coordinate to PDF Y coordinate.
  ///
  /// PDF uses bottom-left origin (y increases upward), while WireTuner
  /// uses top-left origin (y increases downward). This method performs
  /// the necessary transformation.
  ///
  /// Formula: pdfY = pageHeight - wireTunerY
  ///
  /// Example:
  /// ```dart
  /// // WireTuner point at (100, 50) in 800px tall canvas
  /// // becomes (100, 750) in PDF coordinates
  /// final pdfY = _pdfY(50, 800); // Returns 750
  /// ```
  double _pdfY(double wireTunerY, double pageHeight) => pageHeight - wireTunerY;

  /// Calculates the bounding rectangle for the document.
  ///
  /// Computes the union of all object bounds across all visible layers.
  /// This determines the PDF page size.
  ///
  /// Returns:
  /// - Union bounds if document has objects
  /// - Default US Letter size (612x792 points) if document is empty
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
      // This ensures consistent page size even if layers are toggled
      for (final object in layer.objects) {
        final objBounds = object.getBounds();

        if (bounds == null) {
          bounds = objBounds;
        } else {
          bounds = bounds.union(objBounds);
        }
      }
    }

    // Return default page size (US Letter) if no objects or zero-size bounds
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
      return const Rectangle(
        x: 0,
        y: 0,
        width: _defaultWidth,
        height: _defaultHeight,
      );
    }

    return bounds;
  }

  /// Counts total number of objects in document.
  ///
  /// Used for performance logging.
  int _countObjects(Document document) => document.layers.fold(
        0,
        (sum, layer) => sum + layer.objects.length,
      );
}
