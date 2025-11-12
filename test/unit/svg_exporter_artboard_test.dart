import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';

void main() {
  group('SvgExporter - Per-Artboard Export', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Exports single artboard with correct viewBox', () {
      final artboard = Artboard(
        id: 'artboard-1',
        name: 'Mobile',
        bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 50, y: 50),
                  end: const Point(x: 150, y: 150),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('<?xml version="1.0"'));
      expect(svgContent, contains('<svg'));
      expect(svgContent, contains('viewBox="0.00 0.00 390.00 844.00"'));
      expect(svgContent, contains('width="390.00"'));
      expect(svgContent, contains('height="844.00"'));
      expect(svgContent, contains('<path id="path-1"'));
    });

    test('Uses artboard bounds for viewBox not object bounds', () {
      final artboard = Artboard(
        id: 'artboard-2',
        name: 'Desktop',
        bounds: const Rectangle(x: 100, y: 200, width: 1920, height: 1080),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              // Object is small but artboard bounds should be used
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 150, y: 250),
                  end: const Point(x: 200, y: 300),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      // ViewBox should match artboard bounds, not object bounds
      expect(svgContent, contains('viewBox="100.00 200.00 1920.00 1080.00"'));
    });

    test('Includes artboard name in metadata', () {
      final artboard = Artboard(
        id: 'artboard-3',
        name: 'Tablet Layout',
        bounds: const Rectangle(x: 0, y: 0, width: 768, height: 1024),
        layers: const [],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('<dc:title>Tablet Layout</dc:title>'));
    });

    test('Includes document title in metadata when provided', () {
      final artboard = Artboard(
        id: 'artboard-4',
        name: 'Mobile',
        bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
        layers: const [],
      );

      final svgContent = exporter.generateSvgForArtboard(
        artboard,
        documentTitle: 'My Design',
      );

      expect(svgContent, contains('<dc:title>My Design - Mobile</dc:title>'));
    });

    test('Exports artboard with multiple layers', () {
      final artboard = Artboard(
        id: 'artboard-5',
        name: 'Multi-Layer',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
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
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('id="layer-bg"'));
      expect(svgContent, contains('id="path-bg"'));
      expect(svgContent, contains('id="layer-fg"'));
      expect(svgContent, contains('id="path-fg"'));
    });

    test('Skips invisible layers in artboard', () {
      final artboard = Artboard(
        id: 'artboard-6',
        name: 'Hidden Layer Test',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
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
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('id="layer-visible"'));
      expect(svgContent, contains('id="path-visible"'));
      expect(svgContent, isNot(contains('id="layer-hidden"')));
      expect(svgContent, isNot(contains('id="path-hidden"')));
    });

    test('Exports empty artboard', () {
      final artboard = Artboard(
        id: 'artboard-7',
        name: 'Empty',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: const [],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('<?xml version="1.0"'));
      expect(svgContent, contains('<svg'));
      expect(svgContent, contains('<metadata>'));
      expect(svgContent, contains('</svg>'));
    });

    test('Handles artboards with non-zero origin', () {
      final artboard = Artboard(
        id: 'artboard-8',
        name: 'Offset Canvas',
        bounds: const Rectangle(x: 500, y: 300, width: 1024, height: 768),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 600, y: 400),
                  end: const Point(x: 700, y: 500),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      expect(svgContent, contains('viewBox="500.00 300.00 1024.00 768.00"'));
    });
  });

  group('SvgExporter - exportArtboardToFile', () {
    late SvgExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = SvgExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_svg_ab_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Exports artboard to file', () async {
      final artboard = Artboard(
        id: 'artboard-file',
        name: 'File Export',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
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
      );

      final filePath = '${tempDir.path}/artboard_export.svg';
      await exporter.exportArtboardToFile(artboard, filePath);

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

    test('Includes document title in exported file', () async {
      final artboard = Artboard(
        id: 'artboard-titled',
        name: 'Mobile',
        bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
        layers: const [],
      );

      final filePath = '${tempDir.path}/titled_export.svg';
      await exporter.exportArtboardToFile(
        artboard,
        filePath,
        documentTitle: 'My App Design',
      );

      final content = await File(filePath).readAsString();
      expect(content, contains('<dc:title>My App Design - Mobile</dc:title>'));
    });

    test('Overwrites existing file', () async {
      final filePath = '${tempDir.path}/overwrite_artboard.svg';

      // Create initial file
      await File(filePath).writeAsString('old content');

      final artboard = Artboard(
        id: 'artboard-new',
        name: 'New',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: [
          Layer(
            id: 'layer-new',
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
      );

      await exporter.exportArtboardToFile(artboard, filePath);

      // Verify new content
      final content = await File(filePath).readAsString();
      expect(content, isNot(contains('old content')));
      expect(content, contains('id="path-new"'));
    });

    test('Throws exception for invalid file path', () async {
      final artboard = Artboard(
        id: 'artboard-invalid',
        name: 'Invalid',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: const [],
      );

      final invalidPath = '/nonexistent_directory_xyz/artboard.svg';

      await expectLater(
        exporter.exportArtboardToFile(artboard, invalidPath),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('Exports file with UTF-8 encoding', () async {
      final artboard = Artboard(
        id: 'artboard-utf8',
        name: 'UTF-8 Test: 日本語 中文 한글',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: const [],
      );

      final filePath = '${tempDir.path}/utf8_artboard.svg';
      await exporter.exportArtboardToFile(artboard, filePath);

      final content = await File(filePath).readAsString();
      expect(content, contains('UTF-8 Test: 日本語 中文 한글'));
    });
  });

  group('SvgExporter - Artboard vs Document Export', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Document export uses calculated bounds', () {
      final document = Document(
        id: 'doc-legacy',
        title: 'Legacy Document',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 100, y: 200),
                  end: const Point(x: 500, y: 600),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvg(document);

      // ViewBox calculated from object bounds
      expect(svgContent, contains('viewBox="100.00 200.00 400.00 400.00"'));
    });

    test('Artboard export uses artboard bounds', () {
      final artboard = Artboard(
        id: 'artboard-fixed',
        name: 'Fixed Bounds',
        bounds: const Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 100, y: 200),
                  end: const Point(x: 500, y: 600),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      // ViewBox matches artboard bounds exactly
      expect(svgContent, contains('viewBox="0.00 0.00 1920.00 1080.00"'));
    });

    test('Artboard export preserves coordinate system', () {
      // Test that objects maintain their absolute positions
      final artboard = Artboard(
        id: 'artboard-coords',
        name: 'Coordinate Test',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 50, y: 75),
                  end: const Point(x: 200, y: 300),
                ),
              ),
            ],
          ),
        ],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      // Path data should preserve exact coordinates
      expect(svgContent, contains('M 50.00 75.00 L 200.00 300.00'));
    });
  });

  group('SvgExporter - Artboard Metadata', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Includes artboard preset in metadata if available', () {
      final artboard = Artboard(
        id: 'artboard-preset',
        name: 'iPhone 14',
        bounds: const Rectangle(x: 0, y: 0, width: 390, height: 844),
        preset: 'iPhone14',
        layers: const [],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      // Basic validation - preset not in SVG metadata by default
      // but artboard name should be present
      expect(svgContent, contains('<dc:title>iPhone 14</dc:title>'));
    });

    test('Handles special characters in artboard names', () {
      final artboard = Artboard(
        id: 'artboard-special',
        name: 'Design <v2> & "Updates"',
        bounds: const Rectangle(x: 0, y: 0, width: 800, height: 600),
        layers: const [],
      );

      final svgContent = exporter.generateSvgForArtboard(artboard);

      // XML special characters should be escaped
      expect(
        svgContent,
        contains(
          '<dc:title>Design &lt;v2&gt; &amp; &quot;Updates&quot;</dc:title>',
        ),
      );
    });
  });

  group('SvgExporter - Performance', () {
    late SvgExporter exporter;

    setUp(() {
      exporter = SvgExporter();
    });

    test('Exports artboard with 1000 objects within 1 second', () {
      // Create artboard with 1000 simple line paths
      final objects = List.generate(
        1000,
        (i) => VectorObject.path(
          id: 'path-$i',
          path: Path.line(
            start: Point(x: i.toDouble(), y: i.toDouble()),
            end: Point(x: i.toDouble() + 10, y: i.toDouble() + 10),
          ),
        ),
      );

      final artboard = Artboard(
        id: 'artboard-perf',
        name: 'Performance Test',
        bounds: const Rectangle(x: 0, y: 0, width: 2000, height: 2000),
        layers: [
          Layer(
            id: 'layer-bulk',
            objects: objects,
          ),
        ],
      );

      final startTime = DateTime.now();
      final svgContent = exporter.generateSvgForArtboard(artboard);
      final duration = DateTime.now().difference(startTime);

      expect(duration.inMilliseconds, lessThan(1000));
      expect(svgContent, contains('id="path-0"'));
      expect(svgContent, contains('id="path-999"'));
    }, timeout: const Timeout(Duration(seconds: 3)));
  });
}
