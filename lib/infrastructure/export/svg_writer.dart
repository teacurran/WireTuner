import 'package:wiretuner/domain/models/geometry/rectangle.dart';

/// SVG XML generation utility for building SVG documents.
///
/// This class provides a high-level API for constructing SVG XML documents
/// using a string buffer approach. It handles:
/// - XML declaration and SVG root element
/// - Metadata embedding (RDF/Dublin Core)
/// - Group elements for layer organization
/// - Path elements with styling
/// - Proper XML formatting and indentation
///
/// ## Usage
///
/// ```dart
/// final writer = SvgWriter();
/// writer.writeHeader(viewBox: Rectangle(x: 0, y: 0, width: 800, height: 600));
/// writer.writeMetadata(title: 'My Drawing');
/// writer.startGroup(id: 'layer-1');
/// writer.writePath(id: 'path-1', pathData: 'M 0 0 L 100 100');
/// writer.endGroup();
/// writer.writeFooter();
/// final svgContent = writer.build();
/// ```
class SvgWriter {
  /// Internal buffer for accumulating SVG content.
  final StringBuffer _buffer = StringBuffer();

  /// Current indentation level for pretty printing.
  int _indentLevel = 0;

  /// Indentation string (2 spaces per level).
  static const String _indent = '  ';

  /// Writes the XML declaration and SVG root element.
  ///
  /// The [viewBox] parameter defines the coordinate system and canvas size.
  /// The SVG element includes the XML namespace and version 1.1 declaration.
  ///
  /// Example:
  /// ```dart
  /// writer.writeHeader(
  ///   viewBox: Rectangle(x: 0, y: 0, width: 800, height: 600),
  /// );
  /// ```
  void writeHeader({required Rectangle viewBox}) {
    _buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    _buffer.write('<svg');
    _buffer.write(' xmlns="http://www.w3.org/2000/svg"');
    _buffer.write(' version="1.1"');

    // Format viewBox with 2 decimal precision
    _buffer.write(' viewBox="');
    _buffer.write('${_fmt(viewBox.x)} ${_fmt(viewBox.y)} ');
    _buffer.write('${_fmt(viewBox.width)} ${_fmt(viewBox.height)}"');

    // Add width and height attributes (same as viewBox dimensions)
    _buffer.write(' width="${_fmt(viewBox.width)}"');
    _buffer.write(' height="${_fmt(viewBox.height)}"');

    _buffer.writeln('>');
    _indentLevel++;
  }

  /// Writes RDF metadata section with document information.
  ///
  /// Embeds Dublin Core metadata including title and creator information.
  /// This metadata is recognized by SVG editors like Inkscape and Illustrator.
  ///
  /// Example:
  /// ```dart
  /// writer.writeMetadata(title: 'My Vector Drawing');
  /// ```
  void writeMetadata({required String title}) {
    _writeLine('<metadata>');
    _indentLevel++;

    _writeLine('<rdf:RDF');
    _indentLevel++;
    _writeLine('xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"');
    _writeLine('xmlns:dc="http://purl.org/dc/elements/1.1/">');
    _indentLevel--;

    _indentLevel++;
    _writeLine('<rdf:Description rdf:about="">');
    _indentLevel++;

    // Escape XML special characters in title
    final escapedTitle = _escapeXml(title);
    _writeLine('<dc:title>$escapedTitle</dc:title>');
    _writeLine('<dc:creator>WireTuner 0.1</dc:creator>');
    _writeLine('<dc:format>image/svg+xml</dc:format>');

    _indentLevel--;
    _writeLine('</rdf:Description>');
    _indentLevel--;

    _indentLevel--;
    _writeLine('</rdf:RDF>');

    _indentLevel--;
    _writeLine('</metadata>');
  }

  /// Starts a group element (SVG `<g>` tag).
  ///
  /// Groups are used to organize related elements, typically for layer
  /// representation. All elements written after this call will be nested
  /// inside this group until [endGroup] is called.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the group
  /// - [opacity]: Optional opacity value (0.0 to 1.0, default 1.0)
  ///
  /// Example:
  /// ```dart
  /// writer.startGroup(id: 'layer-background', opacity: 1.0);
  /// // ... write paths
  /// writer.endGroup();
  /// ```
  void startGroup({required String id, String? opacity}) {
    _buffer.write(_getIndent());
    _buffer.write('<g id="');
    _buffer.write(_escapeXml(id));
    _buffer.write('"');

    if (opacity != null) {
      _buffer.write(' opacity="$opacity"');
    }

    _buffer.writeln('>');
    _indentLevel++;
  }

  /// Ends the current group element.
  ///
  /// Must be called after [startGroup] to properly close the `<g>` tag.
  void endGroup() {
    _indentLevel--;
    _writeLine('</g>');
  }

  /// Writes a path element with styling.
  ///
  /// Creates an SVG `<path>` element with the specified attributes.
  /// The [pathData] should be a valid SVG path data string (d attribute).
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the path
  /// - [pathData]: SVG path data (e.g., "M 0 0 L 100 100")
  /// - [stroke]: Stroke color (default "black")
  /// - [strokeWidth]: Stroke width (default "1")
  /// - [fill]: Fill color (default "none")
  /// - [opacity]: Opacity value (0.0 to 1.0)
  /// - [strokeOpacity]: Stroke-specific opacity
  /// - [fillOpacity]: Fill-specific opacity
  /// - [strokeDasharray]: Dash pattern for strokes
  /// - [strokeLinecap]: Line cap style
  /// - [strokeLinejoin]: Line join style
  /// - [transform]: SVG transform attribute
  /// - [clipPath]: Reference to a clip path (e.g., "url(#clip-1)")
  ///
  /// Example:
  /// ```dart
  /// writer.writePath(
  ///   id: 'path-1',
  ///   pathData: 'M 10 20 L 110 70',
  ///   stroke: 'black',
  ///   strokeWidth: '2',
  ///   fill: 'none',
  /// );
  /// ```
  void writePath({
    required String id,
    required String pathData,
    String stroke = 'black',
    String strokeWidth = '1',
    String fill = 'none',
    double? opacity,
    double? strokeOpacity,
    double? fillOpacity,
    String? strokeDasharray,
    String? strokeLinecap,
    String? strokeLinejoin,
    String? transform,
    String? clipPath,
  }) {
    _buffer.write(_getIndent());
    _buffer.write('<path');
    _buffer.write(' id="${_escapeXml(id)}"');
    _buffer.write(' d="$pathData"');
    _buffer.write(' stroke="$stroke"');
    _buffer.write(' stroke-width="$strokeWidth"');
    _buffer.write(' fill="$fill"');

    if (opacity != null) {
      _buffer.write(' opacity="${_fmt(opacity)}"');
    }
    if (strokeOpacity != null) {
      _buffer.write(' stroke-opacity="${_fmt(strokeOpacity)}"');
    }
    if (fillOpacity != null) {
      _buffer.write(' fill-opacity="${_fmt(fillOpacity)}"');
    }
    if (strokeDasharray != null) {
      _buffer.write(' stroke-dasharray="$strokeDasharray"');
    }
    if (strokeLinecap != null) {
      _buffer.write(' stroke-linecap="$strokeLinecap"');
    }
    if (strokeLinejoin != null) {
      _buffer.write(' stroke-linejoin="$strokeLinejoin"');
    }
    if (transform != null) {
      _buffer.write(' transform="$transform"');
    }
    if (clipPath != null) {
      _buffer.write(' clip-path="$clipPath"');
    }

    _buffer.writeln('/>');
  }

  /// Starts a defs section for reusable resources.
  ///
  /// The defs element is used to store graphical objects that will be
  /// referenced later (gradients, clip paths, patterns, etc.).
  ///
  /// Must be followed by [endDefs] to close the section.
  ///
  /// Example:
  /// ```dart
  /// writer.startDefs();
  /// writer.writeLinearGradient(...);
  /// writer.writeClipPath(...);
  /// writer.endDefs();
  /// ```
  void startDefs() {
    _writeLine('<defs>');
    _indentLevel++;
  }

  /// Ends the defs section.
  void endDefs() {
    _indentLevel--;
    _writeLine('</defs>');
  }

  /// Writes a linear gradient definition.
  ///
  /// Creates a `<linearGradient>` element in the defs section.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the gradient (referenced via url(#id))
  /// - [x1], [y1]: Start point coordinates (0.0 to 1.0 or absolute)
  /// - [x2], [y2]: End point coordinates (0.0 to 1.0 or absolute)
  /// - [stops]: List of color stops with offsets and colors
  /// - [gradientUnits]: Coordinate system ("userSpaceOnUse" or "objectBoundingBox")
  ///
  /// Example:
  /// ```dart
  /// writer.writeLinearGradient(
  ///   id: 'grad-1',
  ///   x1: '0%', y1: '0%',
  ///   x2: '100%', y2: '100%',
  ///   stops: [
  ///     GradientStop(offset: '0%', color: '#ff0000'),
  ///     GradientStop(offset: '100%', color: '#0000ff'),
  ///   ],
  /// );
  /// ```
  void writeLinearGradient({
    required String id,
    required String x1,
    required String y1,
    required String x2,
    required String y2,
    required List<GradientStop> stops,
    String gradientUnits = 'objectBoundingBox',
  }) {
    _buffer.write(_getIndent());
    _buffer.write('<linearGradient');
    _buffer.write(' id="${_escapeXml(id)}"');
    _buffer.write(' x1="$x1" y1="$y1"');
    _buffer.write(' x2="$x2" y2="$y2"');
    _buffer.write(' gradientUnits="$gradientUnits"');
    _buffer.writeln('>');
    _indentLevel++;

    for (final stop in stops) {
      _buffer.write(_getIndent());
      _buffer.write('<stop offset="${stop.offset}"');
      _buffer.write(' stop-color="${stop.color}"');
      if (stop.opacity != null) {
        _buffer.write(' stop-opacity="${_fmt(stop.opacity!)}"');
      }
      _buffer.writeln('/>');
    }

    _indentLevel--;
    _writeLine('</linearGradient>');
  }

  /// Writes a radial gradient definition.
  ///
  /// Creates a `<radialGradient>` element in the defs section.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the gradient
  /// - [cx], [cy]: Center point coordinates
  /// - [r]: Radius
  /// - [fx], [fy]: Focal point coordinates (optional)
  /// - [stops]: List of color stops
  /// - [gradientUnits]: Coordinate system
  ///
  /// Example:
  /// ```dart
  /// writer.writeRadialGradient(
  ///   id: 'grad-radial-1',
  ///   cx: '50%', cy: '50%',
  ///   r: '50%',
  ///   stops: [
  ///     GradientStop(offset: '0%', color: '#ffffff'),
  ///     GradientStop(offset: '100%', color: '#000000'),
  ///   ],
  /// );
  /// ```
  void writeRadialGradient({
    required String id,
    required String cx,
    required String cy,
    required String r,
    String? fx,
    String? fy,
    required List<GradientStop> stops,
    String gradientUnits = 'objectBoundingBox',
  }) {
    _buffer.write(_getIndent());
    _buffer.write('<radialGradient');
    _buffer.write(' id="${_escapeXml(id)}"');
    _buffer.write(' cx="$cx" cy="$cy"');
    _buffer.write(' r="$r"');
    if (fx != null) _buffer.write(' fx="$fx"');
    if (fy != null) _buffer.write(' fy="$fy"');
    _buffer.write(' gradientUnits="$gradientUnits"');
    _buffer.writeln('>');
    _indentLevel++;

    for (final stop in stops) {
      _buffer.write(_getIndent());
      _buffer.write('<stop offset="${stop.offset}"');
      _buffer.write(' stop-color="${stop.color}"');
      if (stop.opacity != null) {
        _buffer.write(' stop-opacity="${_fmt(stop.opacity!)}"');
      }
      _buffer.writeln('/>');
    }

    _indentLevel--;
    _writeLine('</radialGradient>');
  }

  /// Starts a clipPath definition.
  ///
  /// ClipPaths define regions where content is visible. Content outside
  /// the clip path is masked.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the clip path
  /// - [clipPathUnits]: Coordinate system ("userSpaceOnUse" or "objectBoundingBox")
  ///
  /// Must be followed by path/shape elements and then [endClipPath].
  ///
  /// Example:
  /// ```dart
  /// writer.startClipPath(id: 'clip-1');
  /// writer.writePath(id: 'clip-path-1', pathData: 'M 0 0 L 100 0 L 100 100 Z');
  /// writer.endClipPath();
  /// ```
  void startClipPath({
    required String id,
    String clipPathUnits = 'userSpaceOnUse',
  }) {
    _buffer.write(_getIndent());
    _buffer.write('<clipPath');
    _buffer.write(' id="${_escapeXml(id)}"');
    _buffer.write(' clipPathUnits="$clipPathUnits"');
    _buffer.writeln('>');
    _indentLevel++;
  }

  /// Ends a clipPath definition.
  void endClipPath() {
    _indentLevel--;
    _writeLine('</clipPath>');
  }

  /// Writes the closing SVG root element tag.
  ///
  /// Must be called after all content has been written to properly
  /// close the SVG document.
  void writeFooter() {
    _indentLevel--;
    _buffer.writeln('</svg>');
  }

  /// Builds and returns the complete SVG document as a string.
  ///
  /// This should be called after [writeFooter] to retrieve the final
  /// SVG XML content.
  ///
  /// Returns the complete SVG document as a UTF-8 string.
  String build() => _buffer.toString();

  /// Writes a line with proper indentation.
  void _writeLine(String content) {
    _buffer.write(_getIndent());
    _buffer.writeln(content);
  }

  /// Returns the current indentation string.
  String _getIndent() => _indent * _indentLevel;

  /// Formats a double value with 2 decimal places.
  ///
  /// This reduces file size while maintaining sufficient precision
  /// for vector graphics (0.01 pixel precision).
  String _fmt(double value) => value.toStringAsFixed(2);

  /// Escapes XML special characters.
  ///
  /// Converts:
  /// - `&` to `&amp;`
  /// - `<` to `&lt;`
  /// - `>` to `&gt;`
  /// - `"` to `&quot;`
  /// - `'` to `&apos;`
  String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Represents a gradient color stop for SVG gradients.
///
/// Used in linear and radial gradient definitions to specify color
/// transitions at specific offsets along the gradient.
///
/// Example:
/// ```dart
/// final stop = GradientStop(
///   offset: '50%',
///   color: '#ff0000',
///   opacity: 0.8,
/// );
/// ```
class GradientStop {
  /// Creates a gradient stop.
  ///
  /// Parameters:
  /// - [offset]: Position along gradient (0% to 100% or 0.0 to 1.0)
  /// - [color]: Color value (hex string like "#ff0000" or color name)
  /// - [opacity]: Optional opacity for this stop (0.0 to 1.0)
  const GradientStop({
    required this.offset,
    required this.color,
    this.opacity,
  });

  /// The position of this color stop along the gradient.
  ///
  /// Can be specified as:
  /// - Percentage: "0%", "50%", "100%"
  /// - Decimal: "0.0", "0.5", "1.0"
  final String offset;

  /// The color at this stop.
  ///
  /// Can be specified as:
  /// - Hex color: "#ff0000", "#rgb", "#rrggbb"
  /// - Named color: "red", "blue", "transparent"
  /// - RGB: "rgb(255, 0, 0)"
  final String color;

  /// Optional opacity for this color stop (0.0 = transparent, 1.0 = opaque).
  ///
  /// If null, the color's inherent opacity is used.
  final double? opacity;
}
