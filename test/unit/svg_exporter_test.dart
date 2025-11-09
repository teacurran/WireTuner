import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';

void main() {
  group('SvgExporter - pathToSvgPathData', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Converts empty path to empty string', () {
      final path = Path.empty();

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, '');
    });

    test('Converts single-point path to M command only', () {
      final path = Path(
        anchors: [AnchorPoint.corner(const Point(x: 10, y: 20))],
        segments: const [],
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, 'M 10.00 20.00');
    });

    test('Converts line path to M and L commands', () {
      final path = Path.line(
        start: const Point(x: 10, y: 20),
        end: const Point(x: 110, y: 70),
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, 'M 10.00 20.00 L 110.00 70.00');
    });

    test('Converts multi-segment line path', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
          AnchorPoint.corner(const Point(x: 0, y: 100)),
        ],
        closed: false,
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(
        svgData,
        'M 0.00 0.00 L 100.00 0.00 L 100.00 100.00 L 0.00 100.00',
      );
    });

    test('Converts Bezier path to M and C commands', () {
      final path = Path(
        anchors: [
          AnchorPoint(
            position: const Point(x: 0, y: 0),
            handleOut: const Point(x: 50, y: 0),
          ),
          AnchorPoint(
            position: const Point(x: 100, y: 100),
            handleIn: const Point(x: -50, y: 0),
          ),
        ],
        segments: [
          Segment.bezier(startIndex: 0, endIndex: 1),
        ],
      );

      final svgData = exporter.pathToSvgPathData(path);

      // Control point 1: (0, 0) + (50, 0) = (50, 0)
      // Control point 2: (100, 100) + (-50, 0) = (50, 100)
      expect(
        svgData,
        'M 0.00 0.00 C 50.00 0.00, 50.00 100.00, 100.00 100.00',
      );
    });

    test('Handles Bezier segment with null handles (degrades to line)', () {
      final path = Path(
        anchors: [
          AnchorPoint(
            position: const Point(x: 0, y: 0),
            handleOut: null, // No handle
          ),
          AnchorPoint(
            position: const Point(x: 100, y: 100),
            handleIn: null, // No handle
          ),
        ],
        segments: [
          Segment.bezier(startIndex: 0, endIndex: 1),
        ],
      );

      final svgData = exporter.pathToSvgPathData(path);

      // Control points default to anchor positions when handles are null
      expect(
        svgData,
        'M 0.00 0.00 C 0.00 0.00, 100.00 100.00, 100.00 100.00',
      );
    });

    test('Adds Z command for closed paths', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
          AnchorPoint.corner(const Point(x: 50, y: 86.6)),
        ],
        closed: true,
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, endsWith(' Z'));
      expect(svgData, 'M 0.00 0.00 L 100.00 0.00 L 50.00 86.60 Z');
    });

    test('Does not add Z command for open paths', () {
      final path = Path.fromAnchors(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
          AnchorPoint.corner(const Point(x: 50, y: 86.6)),
        ],
        closed: false,
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, isNot(contains('Z')));
    });

    test('Handles mixed line and Bezier segments', () {
      final path = Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint(
            position: const Point(x: 50, y: 50),
            handleIn: const Point(x: -20, y: 0),
            handleOut: const Point(x: 20, y: 0),
          ),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
        ],
        segments: [
          Segment.bezier(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
        ],
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, contains('M 0.00 0.00'));
      expect(svgData, contains('C')); // Bezier segment
      expect(svgData, contains('L 100.00 0.00')); // Line segment
    });

    test('Formats coordinates with 2 decimal precision', () {
      final path = Path.line(
        start: const Point(x: 1.23456, y: 2.98765),
        end: const Point(x: 100.999, y: 200.001),
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, 'M 1.23 2.99 L 101.00 200.00');
    });

    test('Handles negative coordinates', () {
      final path = Path.line(
        start: const Point(x: -50, y: -30),
        end: const Point(x: -10, y: -5),
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, 'M -50.00 -30.00 L -10.00 -5.00');
    });

    test('Handles large coordinate values', () {
      final path = Path.line(
        start: const Point(x: 10000, y: 20000),
        end: const Point(x: 15000, y: 25000),
      );

      final svgData = exporter.pathToSvgPathData(path);

      expect(svgData, 'M 10000.00 20000.00 L 15000.00 25000.00');
    });
  });

  group('SvgExporter - generateSvg', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Exports empty document with default viewBox', () {
      final document = Document(
        id: 'doc-empty',
        title: 'Empty Drawing',
        layers: const [],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('<?xml version="1.0"'));
      expect(svgContent, contains('<svg'));
      expect(svgContent, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(svgContent, contains('version="1.1"'));
      expect(svgContent, contains('viewBox="0.00 0.00 800.00 600.00"'));
      expect(svgContent, contains('<dc:title>Empty Drawing</dc:title>'));
      expect(svgContent, contains('</svg>'));
    });

    test('Exports document with single path', () {
      final document = Document(
        id: 'doc-1',
        title: 'Test Drawing',
        layers: [
          Layer(
            id: 'layer-1',
            name: 'Background',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('<g id="layer-1" opacity="1">'));
      expect(svgContent, contains('<path id="path-1"'));
      expect(svgContent, contains('d="M 0.00 0.00 L 100.00 100.00"'));
      expect(svgContent, contains('stroke="black"'));
      expect(svgContent, contains('stroke-width="1"'));
      expect(svgContent, contains('fill="none"'));
      expect(svgContent, contains('</g>'));
    });

    test('Exports document with multiple layers', () {
      final document = Document(
        id: 'doc-2',
        title: 'Multi-Layer',
        layers: [
          Layer(
            id: 'layer-bg',
            name: 'Background',
            objects: [
              VectorObject.path(
                id: 'path-bg',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 50, y: 50),
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-fg',
            name: 'Foreground',
            objects: [
              VectorObject.path(
                id: 'path-fg',
                path: Path.line(
                  start: const Point(x: 10, y: 10),
                  end: const Point(x: 60, y: 60),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('id="layer-bg"'));
      expect(svgContent, contains('id="path-bg"'));
      expect(svgContent, contains('id="layer-fg"'));
      expect(svgContent, contains('id="path-fg"'));
    });

    test('Skips invisible layers', () {
      final document = Document(
        id: 'doc-3',
        title: 'Hidden Layer Test',
        layers: [
          Layer(
            id: 'layer-visible',
            name: 'Visible',
            visible: true,
            objects: [
              VectorObject.path(
                id: 'path-visible',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 50, y: 50),
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-hidden',
            name: 'Hidden',
            visible: false,
            objects: [
              VectorObject.path(
                id: 'path-hidden',
                path: Path.line(
                  start: const Point(x: 10, y: 10),
                  end: const Point(x: 60, y: 60),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('id="layer-visible"'));
      expect(svgContent, contains('id="path-visible"'));
      expect(svgContent, isNot(contains('id="layer-hidden"')));
      expect(svgContent, isNot(contains('id="path-hidden"')));
    });

    test('Exports shapes by converting to paths', () {
      final document = Document(
        id: 'doc-4',
        title: 'Shape Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.shape(
                id: 'rect-1',
                shape: Shape.rectangle(
                  center: const Point(x: 50, y: 50),
                  width: 100,
                  height: 60,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('id="rect-1"'));
      expect(svgContent, contains('d="M')); // Shape converted to path
    });

    test('Calculates viewBox from object bounds', () {
      final document = Document(
        id: 'doc-5',
        title: 'Bounds Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 100, y: 200),
                  end: const Point(x: 500, y: 400),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // ViewBox should contain the path bounds (100, 200) to (500, 400)
      expect(svgContent, contains('viewBox="100.00 200.00 400.00 200.00"'));
    });

    test('Ignores selection state during export', () {
      final document = Document(
        id: 'doc-6',
        title: 'Selection Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(objectIds: {'path-1'}),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // SVG should not contain any selection-related attributes or elements
      expect(svgContent, contains('id="path-1"'));
      expect(svgContent, isNot(contains('class="selected"')));
      expect(svgContent, isNot(contains('<selection')));
      expect(svgContent, isNot(contains('data-selected')));
    });

    test('Escapes XML special characters in title', () {
      final document = Document(
        id: 'doc-7',
        title: 'Test <Title> & "Quotes"',
        layers: const [],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('<dc:title>Test &lt;Title&gt; &amp; &quot;Quotes&quot;</dc:title>'));
    });

    test('Escapes XML special characters in IDs', () {
      final document = Document(
        id: 'doc-8',
        title: 'ID Escape Test',
        layers: [
          Layer(
            id: 'layer-<special>',
            objects: [
              VectorObject.path(
                id: 'path-"quoted"',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      expect(svgContent, contains('id="layer-&lt;special&gt;"'));
      expect(svgContent, contains('id="path-&quot;quoted&quot;"'));
    });
  });

  group('SvgExporter - exportToFile', () {
    late SvgExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = SvgExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_svg_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Exports document to file', () async {
      final document = Document(
        id: 'doc-file',
        title: 'File Export Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/test_export.svg';
      await exporter.exportToFile(document, filePath);

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      // Verify file content
      final content = await file.readAsString();
      expect(content, contains('<?xml version="1.0"'));
      expect(content, contains('<svg'));
      expect(content, contains('<path id="path-1"'));
      expect(content, contains('</svg>'));
    });

    test('Overwrites existing file', () async {
      final filePath = '${tempDir.path}/overwrite_test.svg';

      // Create initial file
      final initialFile = File(filePath);
      await initialFile.writeAsString('old content');

      final document = Document(
        id: 'doc-overwrite',
        title: 'Overwrite Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-new',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 50, y: 50),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      await exporter.exportToFile(document, filePath);

      // Verify new content
      final content = await File(filePath).readAsString();
      expect(content, isNot(contains('old content')));
      expect(content, contains('id="path-new"'));
    });

    test('Throws exception for invalid file path', () async {
      final document = Document(
        id: 'doc-invalid',
        title: 'Invalid Path Test',
        layers: const [],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final invalidPath = '/nonexistent_directory_xyz/test.svg';

      await expectLater(
        exporter.exportToFile(document, invalidPath),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('Exports file with UTF-8 encoding', () async {
      final document = Document(
        id: 'doc-utf8',
        title: 'UTF-8 Test: 日本語 中文 한글',
        layers: const [],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/utf8_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();
      expect(content, contains('UTF-8 Test: 日本語 中文 한글'));
    });
  });

  group('SvgExporter - Tier-2 Features', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Exports document with defs section when needed', () {
      final document = Document(
        id: 'doc-defs',
        title: 'Defs Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // Currently defs is not included since we have no gradients
      // This test validates the structure is still correct
      expect(svgContent, contains('<svg'));
      expect(svgContent, contains('<metadata>'));
      expect(svgContent, contains('</svg>'));
    });

    test('Handles compound paths with multiple segments', () {
      // Create a path with multiple complex segments
      final compoundPath = Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint(
            position: const Point(x: 50, y: 50),
            handleIn: const Point(x: -20, y: 0),
            handleOut: const Point(x: 20, y: 0),
          ),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
          AnchorPoint(
            position: const Point(x: 150, y: 50),
            handleIn: const Point(x: -10, y: -10),
            handleOut: const Point(x: 10, y: 10),
          ),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.bezier(startIndex: 1, endIndex: 2),
          Segment.line(startIndex: 2, endIndex: 3),
        ],
        closed: true,
      );

      final document = Document(
        id: 'doc-compound',
        title: 'Compound Path Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(id: 'compound-path-1', path: compoundPath),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // Verify path contains both line and curve commands
      expect(svgContent, contains('L ')); // Line command
      expect(svgContent, contains('C ')); // Bezier curve command
      expect(svgContent, contains('Z')); // Close path command
    });

    test('Exports well-formed XML that can be parsed', () {
      final document = Document(
        id: 'doc-xml',
        title: 'XML Validation Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // Basic XML structure validation
      expect(svgContent, startsWith('<?xml version="1.0"'));
      expect(svgContent, contains('<svg'));
      expect(svgContent, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(svgContent, contains('</svg>'));

      // Verify proper nesting
      final openTags = '<svg'.allMatches(svgContent).length;
      final closeTags = '</svg>'.allMatches(svgContent).length;
      expect(openTags, equals(closeTags));
    });

    test('Handles paths with only anchors (no segments)', () {
      final singleAnchorPath = Path(
        anchors: [AnchorPoint.corner(const Point(x: 50, y: 50))],
        segments: const [],
        closed: false,
      );

      final document = Document(
        id: 'doc-single',
        title: 'Single Anchor Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(id: 'single-anchor', path: singleAnchorPath),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final svgContent = exporter.generateSvg(document);

      // Should contain move command only
      expect(svgContent, contains('M 50.00 50.00'));
      expect(svgContent, isNot(contains('L ')));
      expect(svgContent, isNot(contains('C ')));
    });

    test('Preserves coordinate precision for smooth curves', () {
      final smoothCurve = Path(
        anchors: [
          AnchorPoint(
            position: const Point(x: 0.123456, y: 0.987654),
            handleOut: const Point(x: 10.111111, y: 20.222222),
          ),
          AnchorPoint(
            position: const Point(x: 100.555555, y: 100.666666),
            handleIn: const Point(x: -10.333333, y: -20.444444),
          ),
        ],
        segments: [Segment.bezier(startIndex: 0, endIndex: 1)],
      );

      final svgData = exporter.pathToSvgPathData(smoothCurve);

      // Verify 2 decimal precision
      expect(svgData, contains('0.12')); // x coordinate of first anchor
      expect(svgData, contains('0.99')); // y coordinate of first anchor
      expect(svgData, contains('100.56')); // x coordinate of second anchor
      expect(svgData, contains('100.67')); // y coordinate of second anchor
    });
  });

  group('SvgExporter - Performance', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Exports 5000 objects within 5 seconds', () async {
      // Create document with 5000 simple line paths
      final objects = List.generate(
        5000,
        (i) => VectorObject.path(
          id: 'path-$i',
          path: Path.line(
            start: Point(x: i.toDouble(), y: i.toDouble()),
            end: Point(x: i.toDouble() + 10, y: i.toDouble() + 10),
          ),
        ),
      );

      final document = Document(
        id: 'doc-benchmark',
        title: 'Performance Benchmark',
        layers: [
          Layer(
            id: 'layer-bulk',
            objects: objects,
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final startTime = DateTime.now();
      final svgContent = exporter.generateSvg(document);
      final duration = DateTime.now().difference(startTime);

      expect(duration.inSeconds, lessThan(5));
      expect(svgContent, contains('id="path-0"'));
      expect(svgContent, contains('id="path-4999"'));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
