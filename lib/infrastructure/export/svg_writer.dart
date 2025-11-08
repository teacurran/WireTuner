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
  }) {
    _buffer.write(_getIndent());
    _buffer.write('<path');
    _buffer.write(' id="${_escapeXml(id)}"');
    _buffer.write(' d="$pathData"');
    _buffer.write(' stroke="$stroke"');
    _buffer.write(' stroke-width="$strokeWidth"');
    _buffer.write(' fill="$fill"');
    _buffer.writeln('/>');
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
