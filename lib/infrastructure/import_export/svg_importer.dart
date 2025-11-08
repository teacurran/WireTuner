import 'dart:io';
import 'dart:math' as math;

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/import_export/import_validator.dart';

/// Service for importing SVG 1.1 files into WireTuner's event-based format.
///
/// This service converts SVG vector graphics into a sequence of events
/// that can be replayed to reconstruct the document. It follows WireTuner's
/// event sourcing architecture.
///
/// ## Supported Features (Milestone 0.1)
///
/// **Path Elements:**
/// - M/m (moveTo) - absolute and relative
/// - L/l (lineTo) - absolute and relative
/// - H/h (horizontal lineTo) - absolute and relative
/// - V/v (vertical lineTo) - absolute and relative
/// - C/c (cubic Bezier) - absolute and relative
/// - S/s (smooth cubic Bezier) - absolute and relative
/// - Q/q (quadratic Bezier) - absolute and relative
/// - T/t (smooth quadratic Bezier) - absolute and relative
/// - Z/z (closePath)
///
/// **Shape Elements:**
/// - `<rect>` - rectangles with optional corner radius
/// - `<circle>` - circles
/// - `<ellipse>` - ellipses
/// - `<line>` - straight lines
/// - `<polyline>` - connected line segments
/// - `<polygon>` - closed polygons
///
/// **Grouping:**
/// - `<g>` - groups (flattened to single layer in 0.1)
///
/// ## Limitations (Milestone 0.1)
///
/// - Transform attributes ignored (future enhancement)
/// - Gradients/patterns not supported (logged as warning)
/// - Filters/effects not supported (logged as warning)
/// - Text elements not supported (logged as warning)
/// - Nested layers not supported (groups are flattened)
/// - Style inheritance simplified (stroke/fill from element only)
///
/// ## Security
///
/// - File size limited to 10 MB
/// - Path data limited to 100k characters per path
/// - XML external entities disabled (XXE prevention)
/// - Coordinate values validated for finite numbers
///
/// ## Usage
///
/// ```dart
/// final importer = SvgImporter();
/// final events = await importer.importFromFile('/path/to/drawing.svg');
///
/// // Replay events to reconstruct document
/// for (final event in events) {
///   eventDispatcher.dispatch(event);
/// }
/// ```
class SvgImporter {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Timestamp counter for event ordering.
  int _timestampCounter = 0;

  /// Current pen position for relative path commands.
  Point _currentPoint = const Point(x: 0, y: 0);

  /// Last control point for smooth Bezier commands.
  Point? _lastControlPoint;

  /// Imports an SVG file and returns a list of events.
  ///
  /// The returned events can be replayed via the event dispatcher
  /// to reconstruct the document.
  ///
  /// Parameters:
  /// - [filePath]: Absolute path to the SVG file
  ///
  /// Returns:
  /// - List of events representing the imported content
  ///
  /// Throws:
  /// - [ImportException] if file is invalid or parsing fails
  ///
  /// Example:
  /// ```dart
  /// final importer = SvgImporter();
  /// try {
  ///   final events = await importer.importFromFile('/path/to/file.svg');
  ///   print('Imported ${events.length} events');
  /// } catch (e) {
  ///   print('Import failed: $e');
  /// }
  /// ```
  Future<List<EventBase>> importFromFile(String filePath) async {
    final startTime = DateTime.now();

    _logger.i('Starting SVG import: $filePath');

    // Validate file
    await ImportValidator.validateFile(filePath);

    // Read file content
    final content = await File(filePath).readAsString();

    // Import from string
    final events = await importFromString(content);

    // Log performance
    final duration = DateTime.now().difference(startTime);
    _logger.i(
      'SVG import completed: ${events.length} events, '
      '${duration.inMilliseconds}ms',
    );

    return events;
  }

  /// Imports SVG content from a string.
  ///
  /// This method is useful for testing and for importing from
  /// in-memory SVG content.
  ///
  /// Parameters:
  /// - [svgContent]: The SVG XML content as a string
  ///
  /// Returns:
  /// - List of events representing the imported content
  ///
  /// Throws:
  /// - [ImportException] if SVG is malformed or parsing fails
  Future<List<EventBase>> importFromString(String svgContent) async {
    try {
      // Reset state
      _timestampCounter = 0;
      _currentPoint = const Point(x: 0, y: 0);
      _lastControlPoint = null;

      // Parse XML (xml package doesn't support DTD/entities by default - safe)
      final document = XmlDocument.parse(svgContent);

      // Find SVG root element
      final svgElement = document.findElements('svg').firstOrNull;
      if (svgElement == null) {
        throw ImportException('No <svg> root element found');
      }

      // Parse all child elements
      final events = <EventBase>[];
      for (final element in svgElement.children.whereType<XmlElement>()) {
        events.addAll(_parseElement(element));
      }

      return events;
    } on XmlException catch (e) {
      throw ImportException('Malformed SVG XML: ${e.message}');
    } catch (e) {
      if (e is ImportException) rethrow;
      throw ImportException('SVG parsing failed: $e');
    }
  }

  /// Parses an XML element and returns corresponding events.
  List<EventBase> _parseElement(XmlElement element) {
    final tagName = element.name.local.toLowerCase();

    switch (tagName) {
      case 'path':
        return _parsePathElement(element);
      case 'rect':
        return _parseRectElement(element);
      case 'circle':
        return _parseCircleElement(element);
      case 'ellipse':
        return _parseEllipseElement(element);
      case 'line':
        return _parseLineElement(element);
      case 'polyline':
        return _parsePolylineElement(element);
      case 'polygon':
        return _parsePolygonElement(element);
      case 'g':
        return _parseGroupElement(element);

      // Unsupported but safe to ignore
      case 'defs':
      case 'metadata':
      case 'title':
      case 'desc':
        return [];

      // Unsupported features - log warning
      case 'text':
      case 'tspan':
        _logger.w('Unsupported SVG element: <$tagName> (text not supported in Milestone 0.1), skipping');
        return [];

      case 'lineargradient':
      case 'radialgradient':
      case 'pattern':
        _logger.w('Unsupported SVG element: <$tagName> (gradients/patterns not supported), skipping');
        return [];

      case 'filter':
      case 'fegaussianblur':
      case 'fecolormatrix':
        _logger.w('Unsupported SVG element: <$tagName> (filters not supported), skipping');
        return [];

      case 'image':
        _logger.w('Unsupported SVG element: <$tagName> (embedded images not supported), skipping');
        return [];

      default:
        _logger.w('Unknown SVG element: <$tagName>, skipping');
        return [];
    }
  }

  /// Parses a <path> element.
  List<EventBase> _parsePathElement(XmlElement element) {
    final pathData = element.getAttribute('d');
    if (pathData == null || pathData.isEmpty) {
      _logger.w('Path element has no "d" attribute, skipping');
      return [];
    }

    // Validate path data length
    ImportValidator.validatePathData(pathData);

    // Generate unique path ID
    final pathId = 'import_path_${_uuid.v4()}';

    // Parse style attributes
    final style = _parseStyle(element);

    // Parse path data into events
    try {
      return _parsePathData(pathData, pathId, style);
    } catch (e) {
      _logger.e('Failed to parse path data: $e');
      return [];
    }
  }

  /// Parses a <rect> element.
  List<EventBase> _parseRectElement(XmlElement element) {
    try {
      final x = _parseDouble(element.getAttribute('x') ?? '0');
      final y = _parseDouble(element.getAttribute('y') ?? '0');
      final width = _parseDouble(element.getAttribute('width') ?? '0');
      final height = _parseDouble(element.getAttribute('height') ?? '0');
      final rx = _parseDouble(element.getAttribute('rx') ?? '0');

      // Validate coordinates
      ImportValidator.validateCoordinate(x, 'rect x');
      ImportValidator.validateCoordinate(y, 'rect y');
      ImportValidator.validateCoordinate(width, 'rect width');
      ImportValidator.validateCoordinate(height, 'rect height');

      if (width <= 0 || height <= 0) {
        _logger.w('Rectangle has zero or negative dimensions, skipping');
        return [];
      }

      final pathId = 'import_rect_${_uuid.v4()}';
      final style = _parseStyle(element);

      // Convert rectangle to path
      return _rectangleToPath(x, y, width, height, rx, pathId, style);
    } catch (e) {
      _logger.e('Failed to parse rect element: $e');
      return [];
    }
  }

  /// Parses a <circle> element.
  List<EventBase> _parseCircleElement(XmlElement element) {
    try {
      final cx = _parseDouble(element.getAttribute('cx') ?? '0');
      final cy = _parseDouble(element.getAttribute('cy') ?? '0');
      final r = _parseDouble(element.getAttribute('r') ?? '0');

      // Validate coordinates
      ImportValidator.validateCoordinate(cx, 'circle cx');
      ImportValidator.validateCoordinate(cy, 'circle cy');
      ImportValidator.validateCoordinate(r, 'circle r');

      if (r <= 0) {
        _logger.w('Circle has zero or negative radius, skipping');
        return [];
      }

      final pathId = 'import_circle_${_uuid.v4()}';
      final style = _parseStyle(element);

      // Convert circle to path (ellipse with equal radii)
      return _ellipseToPath(cx, cy, r, r, pathId, style);
    } catch (e) {
      _logger.e('Failed to parse circle element: $e');
      return [];
    }
  }

  /// Parses an <ellipse> element.
  List<EventBase> _parseEllipseElement(XmlElement element) {
    try {
      final cx = _parseDouble(element.getAttribute('cx') ?? '0');
      final cy = _parseDouble(element.getAttribute('cy') ?? '0');
      final rx = _parseDouble(element.getAttribute('rx') ?? '0');
      final ry = _parseDouble(element.getAttribute('ry') ?? '0');

      // Validate coordinates
      ImportValidator.validateCoordinate(cx, 'ellipse cx');
      ImportValidator.validateCoordinate(cy, 'ellipse cy');
      ImportValidator.validateCoordinate(rx, 'ellipse rx');
      ImportValidator.validateCoordinate(ry, 'ellipse ry');

      if (rx <= 0 || ry <= 0) {
        _logger.w('Ellipse has zero or negative radii, skipping');
        return [];
      }

      final pathId = 'import_ellipse_${_uuid.v4()}';
      final style = _parseStyle(element);

      return _ellipseToPath(cx, cy, rx, ry, pathId, style);
    } catch (e) {
      _logger.e('Failed to parse ellipse element: $e');
      return [];
    }
  }

  /// Parses a <line> element.
  List<EventBase> _parseLineElement(XmlElement element) {
    try {
      final x1 = _parseDouble(element.getAttribute('x1') ?? '0');
      final y1 = _parseDouble(element.getAttribute('y1') ?? '0');
      final x2 = _parseDouble(element.getAttribute('x2') ?? '0');
      final y2 = _parseDouble(element.getAttribute('y2') ?? '0');

      // Validate coordinates
      ImportValidator.validateCoordinate(x1, 'line x1');
      ImportValidator.validateCoordinate(y1, 'line y1');
      ImportValidator.validateCoordinate(x2, 'line x2');
      ImportValidator.validateCoordinate(y2, 'line y2');

      final pathId = 'import_line_${_uuid.v4()}';
      final style = _parseStyle(element);

      // Create simple two-point path
      return [
        CreatePathEvent(
          eventId: _generateEventId(),
          timestamp: _nextTimestamp(),
          pathId: pathId,
          startAnchor: Point(x: x1, y: y1),
          strokeColor: style.strokeColor,
          strokeWidth: style.strokeWidth,
          opacity: style.opacity,
        ),
        AddAnchorEvent(
          eventId: _generateEventId(),
          timestamp: _nextTimestamp(),
          pathId: pathId,
          position: Point(x: x2, y: y2),
          anchorType: AnchorType.line,
        ),
        FinishPathEvent(
          eventId: _generateEventId(),
          timestamp: _nextTimestamp(),
          pathId: pathId,
          closed: false,
        ),
      ];
    } catch (e) {
      _logger.e('Failed to parse line element: $e');
      return [];
    }
  }

  /// Parses a <polyline> element.
  List<EventBase> _parsePolylineElement(XmlElement element) {
    final points = element.getAttribute('points');
    if (points == null || points.isEmpty) {
      _logger.w('Polyline element has no "points" attribute, skipping');
      return [];
    }

    try {
      final coords = _parsePointsList(points);
      if (coords.isEmpty) {
        return [];
      }

      final pathId = 'import_polyline_${_uuid.v4()}';
      final style = _parseStyle(element);

      return _pointsToPath(coords, pathId, style, closed: false);
    } catch (e) {
      _logger.e('Failed to parse polyline element: $e');
      return [];
    }
  }

  /// Parses a <polygon> element.
  List<EventBase> _parsePolygonElement(XmlElement element) {
    final points = element.getAttribute('points');
    if (points == null || points.isEmpty) {
      _logger.w('Polygon element has no "points" attribute, skipping');
      return [];
    }

    try {
      final coords = _parsePointsList(points);
      if (coords.isEmpty) {
        return [];
      }

      final pathId = 'import_polygon_${_uuid.v4()}';
      final style = _parseStyle(element);

      return _pointsToPath(coords, pathId, style, closed: true);
    } catch (e) {
      _logger.e('Failed to parse polygon element: $e');
      return [];
    }
  }

  /// Parses a <g> (group) element by recursively parsing children.
  List<EventBase> _parseGroupElement(XmlElement element) {
    final events = <EventBase>[];

    // Recursively parse all child elements
    // (Flattening groups - no nested layers in Milestone 0.1)
    for (final child in element.children.whereType<XmlElement>()) {
      events.addAll(_parseElement(child));
    }

    return events;
  }

  /// Parses SVG path data string into events.
  List<EventBase> _parsePathData(
    String pathData,
    String pathId,
    _StyleAttributes style,
  ) {
    final events = <EventBase>[];
    final commands = _tokenizePathData(pathData);

    bool isFirstCommand = true;
    int anchorIndex = 0;

    for (final cmd in commands) {
      switch (cmd.type.toUpperCase()) {
        case 'M': // MoveTo
          final point = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          if (isFirstCommand) {
            events.add(CreatePathEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              startAnchor: point,
              strokeColor: style.strokeColor,
              strokeWidth: style.strokeWidth,
              fillColor: style.fillColor,
              opacity: style.opacity,
            ));
            isFirstCommand = false;
            anchorIndex = 0;
          } else {
            // Subsequent MoveTo is treated as LineTo
            events.add(AddAnchorEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              position: point,
              anchorType: AnchorType.line,
            ));
            anchorIndex++;
          }

          _currentPoint = point;
          _lastControlPoint = null;
          break;

        case 'L': // LineTo
          final point = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: point,
            anchorType: AnchorType.line,
          ));

          _currentPoint = point;
          _lastControlPoint = null;
          anchorIndex++;
          break;

        case 'H': // Horizontal LineTo
          final x = cmd.isRelative ? _currentPoint.x + cmd.coords[0] : cmd.coords[0];
          final point = Point(x: x, y: _currentPoint.y);

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: point,
            anchorType: AnchorType.line,
          ));

          _currentPoint = point;
          _lastControlPoint = null;
          anchorIndex++;
          break;

        case 'V': // Vertical LineTo
          final y = cmd.isRelative ? _currentPoint.y + cmd.coords[0] : cmd.coords[0];
          final point = Point(x: _currentPoint.x, y: y);

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: point,
            anchorType: AnchorType.line,
          ));

          _currentPoint = point;
          _lastControlPoint = null;
          anchorIndex++;
          break;

        case 'C': // Cubic Bezier
          final cp1Abs = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          final cp2Abs = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[2], y: _currentPoint.y + cmd.coords[3])
              : Point(x: cmd.coords[2], y: cmd.coords[3]);

          final endPoint = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[4], y: _currentPoint.y + cmd.coords[5])
              : Point(x: cmd.coords[4], y: cmd.coords[5]);

          // Convert absolute control points to relative handles
          final handleOut = Point(x: cp1Abs.x - _currentPoint.x, y: cp1Abs.y - _currentPoint.y);
          final handleIn = Point(x: cp2Abs.x - endPoint.x, y: cp2Abs.y - endPoint.y);

          // Set handleOut on current anchor (before adding the next one)
          // For the first bezier after CreatePath, anchorIndex is 0
          // We need to modify the anchor at index 0 (the start anchor)
          if (anchorIndex >= 0 && !isFirstCommand) {
            events.add(ModifyAnchorEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              anchorIndex: anchorIndex,
              handleOut: handleOut,
            ));
          }

          // Add new anchor with handleIn
          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: endPoint,
            anchorType: AnchorType.bezier,
            handleIn: handleIn,
          ));

          _currentPoint = endPoint;
          _lastControlPoint = cp2Abs;
          anchorIndex++;
          break;

        case 'S': // Smooth Cubic Bezier
          // First control point is reflection of last control point
          final cp1Abs = _lastControlPoint != null
              ? Point(
                  x: 2 * _currentPoint.x - _lastControlPoint!.x,
                  y: 2 * _currentPoint.y - _lastControlPoint!.y,
                )
              : _currentPoint;

          final cp2Abs = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          final endPoint = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[2], y: _currentPoint.y + cmd.coords[3])
              : Point(x: cmd.coords[2], y: cmd.coords[3]);

          final handleOut = Point(x: cp1Abs.x - _currentPoint.x, y: cp1Abs.y - _currentPoint.y);
          final handleIn = Point(x: cp2Abs.x - endPoint.x, y: cp2Abs.y - endPoint.y);

          if (anchorIndex >= 0 && !isFirstCommand) {
            events.add(ModifyAnchorEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              anchorIndex: anchorIndex,
              handleOut: handleOut,
            ));
          }

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: endPoint,
            anchorType: AnchorType.bezier,
            handleIn: handleIn,
          ));

          _currentPoint = endPoint;
          _lastControlPoint = cp2Abs;
          anchorIndex++;
          break;

        case 'Q': // Quadratic Bezier (convert to cubic)
          final cpAbs = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          final endPoint = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[2], y: _currentPoint.y + cmd.coords[3])
              : Point(x: cmd.coords[2], y: cmd.coords[3]);

          // Convert quadratic to cubic Bezier
          // CP1 = current + 2/3 * (QCP - current)
          // CP2 = end + 2/3 * (QCP - end)
          final cp1Abs = Point(
            x: _currentPoint.x + 2.0 / 3.0 * (cpAbs.x - _currentPoint.x),
            y: _currentPoint.y + 2.0 / 3.0 * (cpAbs.y - _currentPoint.y),
          );

          final cp2Abs = Point(
            x: endPoint.x + 2.0 / 3.0 * (cpAbs.x - endPoint.x),
            y: endPoint.y + 2.0 / 3.0 * (cpAbs.y - endPoint.y),
          );

          final handleOut = Point(x: cp1Abs.x - _currentPoint.x, y: cp1Abs.y - _currentPoint.y);
          final handleIn = Point(x: cp2Abs.x - endPoint.x, y: cp2Abs.y - endPoint.y);

          if (anchorIndex >= 0 && !isFirstCommand) {
            events.add(ModifyAnchorEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              anchorIndex: anchorIndex,
              handleOut: handleOut,
            ));
          }

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: endPoint,
            anchorType: AnchorType.bezier,
            handleIn: handleIn,
          ));

          _currentPoint = endPoint;
          _lastControlPoint = cpAbs;
          anchorIndex++;
          break;

        case 'T': // Smooth Quadratic Bezier
          final cpAbs = _lastControlPoint != null
              ? Point(
                  x: 2 * _currentPoint.x - _lastControlPoint!.x,
                  y: 2 * _currentPoint.y - _lastControlPoint!.y,
                )
              : _currentPoint;

          final endPoint = cmd.isRelative
              ? Point(x: _currentPoint.x + cmd.coords[0], y: _currentPoint.y + cmd.coords[1])
              : Point(x: cmd.coords[0], y: cmd.coords[1]);

          // Convert to cubic
          final cp1Abs = Point(
            x: _currentPoint.x + 2.0 / 3.0 * (cpAbs.x - _currentPoint.x),
            y: _currentPoint.y + 2.0 / 3.0 * (cpAbs.y - _currentPoint.y),
          );

          final cp2Abs = Point(
            x: endPoint.x + 2.0 / 3.0 * (cpAbs.x - endPoint.x),
            y: endPoint.y + 2.0 / 3.0 * (cpAbs.y - endPoint.y),
          );

          final handleOut = Point(x: cp1Abs.x - _currentPoint.x, y: cp1Abs.y - _currentPoint.y);
          final handleIn = Point(x: cp2Abs.x - endPoint.x, y: cp2Abs.y - endPoint.y);

          if (anchorIndex >= 0 && !isFirstCommand) {
            events.add(ModifyAnchorEvent(
              eventId: _generateEventId(),
              timestamp: _nextTimestamp(),
              pathId: pathId,
              anchorIndex: anchorIndex,
              handleOut: handleOut,
            ));
          }

          events.add(AddAnchorEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            position: endPoint,
            anchorType: AnchorType.bezier,
            handleIn: handleIn,
          ));

          _currentPoint = endPoint;
          _lastControlPoint = cpAbs;
          anchorIndex++;
          break;

        case 'Z': // ClosePath
          events.add(FinishPathEvent(
            eventId: _generateEventId(),
            timestamp: _nextTimestamp(),
            pathId: pathId,
            closed: true,
          ));
          break;
      }
    }

    // If path wasn't explicitly closed, add finish event
    if (events.isNotEmpty && events.last is! FinishPathEvent) {
      events.add(FinishPathEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        closed: false,
      ));
    }

    return events;
  }

  /// Tokenizes SVG path data string into commands.
  List<_PathCommand> _tokenizePathData(String pathData) {
    final commands = <_PathCommand>[];

    // Remove all commas and extra whitespace
    final normalized = pathData
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split into tokens
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];

      if (_isCommand(char)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
      } else if (char == ' ') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else if (char == '-' && buffer.isNotEmpty && !buffer.toString().endsWith('e')) {
        // Negative sign starts new number (unless it's scientific notation)
        tokens.add(buffer.toString());
        buffer.clear();
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    // Parse tokens into commands
    int i = 0;
    while (i < tokens.length) {
      final cmdChar = tokens[i];
      if (!_isCommand(cmdChar)) {
        i++;
        continue;
      }

      final cmdType = cmdChar.toUpperCase();
      final isRelative = cmdChar != cmdType; // Lowercase = relative

      // Get expected coordinate count for this command
      final coordCount = _getCoordCount(cmdType);

      i++; // Move past command character

      // Collect coordinates
      final coords = <double>[];
      while (i < tokens.length && !_isCommand(tokens[i]) && coords.length < coordCount) {
        try {
          coords.add(_parseDouble(tokens[i]));
          i++;
        } catch (e) {
          _logger.w('Failed to parse coordinate "${tokens[i]}": $e');
          i++;
        }
      }

      if (coords.length == coordCount || cmdType == 'Z') {
        commands.add(_PathCommand(
          type: cmdChar,
          coords: coords,
          isRelative: isRelative,
        ));
      } else {
        _logger.w('Incomplete coordinates for command $cmdChar (expected $coordCount, got ${coords.length})');
      }
    }

    return commands;
  }

  /// Checks if a character is a path command.
  bool _isCommand(String char) {
    return 'MmLlHhVvCcSsQqTtAaZz'.contains(char);
  }

  /// Gets the expected coordinate count for a command type.
  int _getCoordCount(String cmdType) {
    switch (cmdType) {
      case 'M':
      case 'L':
      case 'T':
        return 2;
      case 'H':
      case 'V':
        return 1;
      case 'S':
      case 'Q':
        return 4;
      case 'C':
        return 6;
      case 'A':
        return 7; // Not supported in 0.1, but defined for completeness
      case 'Z':
        return 0;
      default:
        return 0;
    }
  }

  /// Converts a rectangle to path events.
  List<EventBase> _rectangleToPath(
    double x,
    double y,
    double width,
    double height,
    double rx,
    String pathId,
    _StyleAttributes style,
  ) {
    final events = <EventBase>[];

    if (rx <= 0) {
      // Sharp corners - simple rectangle
      events.add(CreatePathEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        startAnchor: Point(x: x, y: y),
        strokeColor: style.strokeColor,
        strokeWidth: style.strokeWidth,
        fillColor: style.fillColor,
        opacity: style.opacity,
      ));

      events.add(AddAnchorEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        position: Point(x: x + width, y: y),
        anchorType: AnchorType.line,
      ));

      events.add(AddAnchorEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        position: Point(x: x + width, y: y + height),
        anchorType: AnchorType.line,
      ));

      events.add(AddAnchorEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        position: Point(x: x, y: y + height),
        anchorType: AnchorType.line,
      ));

      events.add(FinishPathEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        closed: true,
      ));
    } else {
      // Rounded corners - more complex path
      // For simplicity in Milestone 0.1, convert to sharp rectangle
      // Future enhancement: implement rounded corners with Bezier curves
      _logger.d('Rounded rectangle corners not yet supported, using sharp corners');
      return _rectangleToPath(x, y, width, height, 0, pathId, style);
    }

    return events;
  }

  /// Converts an ellipse to path events.
  List<EventBase> _ellipseToPath(
    double cx,
    double cy,
    double rx,
    double ry,
    String pathId,
    _StyleAttributes style,
  ) {
    // Ellipse approximation with 4 Bezier curves
    // Magic constant for circle approximation: k = 4/3 * (sqrt(2) - 1)
    const k = 0.5522847498;

    final kx = k * rx;
    final ky = k * ry;

    final events = <EventBase>[];

    // Start at rightmost point
    events.add(CreatePathEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      startAnchor: Point(x: cx + rx, y: cy),
      strokeColor: style.strokeColor,
      strokeWidth: style.strokeWidth,
      fillColor: style.fillColor,
      opacity: style.opacity,
    ));

    // Top curve (right to top)
    events.add(ModifyAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      anchorIndex: 0,
      handleOut: Point(x: 0, y: -ky),
    ));

    events.add(AddAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      position: Point(x: cx, y: cy - ry),
      anchorType: AnchorType.bezier,
      handleIn: Point(x: kx, y: 0),
    ));

    // Left curve (top to left)
    events.add(ModifyAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      anchorIndex: 1,
      handleOut: Point(x: -kx, y: 0),
    ));

    events.add(AddAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      position: Point(x: cx - rx, y: cy),
      anchorType: AnchorType.bezier,
      handleIn: Point(x: 0, y: -ky),
    ));

    // Bottom curve (left to bottom)
    events.add(ModifyAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      anchorIndex: 2,
      handleOut: Point(x: 0, y: ky),
    ));

    events.add(AddAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      position: Point(x: cx, y: cy + ry),
      anchorType: AnchorType.bezier,
      handleIn: Point(x: -kx, y: 0),
    ));

    // Right curve (bottom to right)
    events.add(ModifyAnchorEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      anchorIndex: 3,
      handleOut: Point(x: kx, y: 0),
    ));

    events.add(FinishPathEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      closed: true,
    ));

    return events;
  }

  /// Converts a list of points to path events.
  List<EventBase> _pointsToPath(
    List<Point> points,
    String pathId,
    _StyleAttributes style, {
    required bool closed,
  }) {
    if (points.isEmpty) return [];

    final events = <EventBase>[];

    // Create path with first point
    events.add(CreatePathEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      startAnchor: points[0],
      strokeColor: style.strokeColor,
      strokeWidth: style.strokeWidth,
      fillColor: style.fillColor,
      opacity: style.opacity,
    ));

    // Add remaining points as line anchors
    for (int i = 1; i < points.length; i++) {
      events.add(AddAnchorEvent(
        eventId: _generateEventId(),
        timestamp: _nextTimestamp(),
        pathId: pathId,
        position: points[i],
        anchorType: AnchorType.line,
      ));
    }

    // Finish path
    events.add(FinishPathEvent(
      eventId: _generateEventId(),
      timestamp: _nextTimestamp(),
      pathId: pathId,
      closed: closed,
    ));

    return events;
  }

  /// Parses a space/comma-separated list of coordinate pairs.
  List<Point> _parsePointsList(String pointsStr) {
    final coords = pointsStr
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => _parseDouble(s))
        .toList();

    if (coords.length % 2 != 0) {
      _logger.w('Points list has odd number of coordinates, ignoring last value');
    }

    final points = <Point>[];
    for (int i = 0; i + 1 < coords.length; i += 2) {
      points.add(Point(x: coords[i], y: coords[i + 1]));
    }

    return points;
  }

  /// Parses style attributes from an element.
  _StyleAttributes _parseStyle(XmlElement element) {
    // Extract stroke and fill attributes
    // In Milestone 0.1, we only support basic attributes
    final stroke = element.getAttribute('stroke');
    final strokeWidth = element.getAttribute('stroke-width');
    final fill = element.getAttribute('fill');
    final opacity = element.getAttribute('opacity');

    return _StyleAttributes(
      strokeColor: stroke != null && stroke != 'none' ? stroke : null,
      strokeWidth: strokeWidth != null ? _parseDouble(strokeWidth) : null,
      fillColor: fill != null && fill != 'none' ? fill : null,
      opacity: opacity != null ? _parseDouble(opacity) : null,
    );
  }

  /// Parses a string to double, handling edge cases.
  double _parseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      throw ImportException('Invalid numeric value: "$value"');
    }
  }

  /// Generates a unique event ID.
  String _generateEventId() => 'import_${_uuid.v4()}';

  /// Gets the next timestamp for event ordering.
  int _nextTimestamp() {
    final base = DateTime.now().millisecondsSinceEpoch;
    return base + _timestampCounter++;
  }
}

/// Internal representation of a parsed path command.
class _PathCommand {
  final String type; // Command character (M, L, C, etc.)
  final List<double> coords; // Coordinate values
  final bool isRelative; // True if lowercase command

  _PathCommand({
    required this.type,
    required this.coords,
    required this.isRelative,
  });
}

/// Style attributes extracted from SVG elements.
class _StyleAttributes {
  final String? strokeColor;
  final double? strokeWidth;
  final String? fillColor;
  final double? opacity;

  _StyleAttributes({
    this.strokeColor,
    this.strokeWidth,
    this.fillColor,
    this.opacity,
  });
}
