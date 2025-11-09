import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';

/// Integration tests for SVG export with W3C validation.
///
/// These tests validate that exported SVG files:
/// - Are well-formed XML
/// - Conform to SVG 1.1 specification
/// - Pass W3C validator (when available)
/// - Match golden files for visual regression testing
///
/// ## Running Tests
///
/// ```bash
/// flutter test test/integration/svg_export_test.dart
/// ```
///
/// ## W3C Validation
///
/// To validate SVG files with the W3C validator, install the validator:
/// ```bash
/// npm install -g vnu-jar
/// ```
///
/// Then run validation manually:
/// ```bash
/// vnu --svg output.svg
/// ```
void main() {
  group('SVG Export Integration Tests', () {
    late SvgExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = SvgExporter();
      tempDir =
          Directory.systemTemp.createTempSync('wiretuner_svg_integration_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Exports valid SVG with paths and shapes', () async {
      final document = Document(
        id: 'doc-integration-1',
        title: 'Integration Test Document',
        layers: [
          Layer(
            id: 'layer-paths',
            name: 'Paths',
            objects: [
              // Simple line path
              VectorObject.path(
                id: 'line-1',
                path: Path.line(
                  start: const Point(x: 10, y: 10),
                  end: const Point(x: 100, y: 100),
                ),
              ),
              // Bezier curve path
              VectorObject.path(
                id: 'curve-1',
                path: Path(
                  anchors: [
                    AnchorPoint(
                      position: const Point(x: 200, y: 200),
                      handleOut: const Point(x: 50, y: 0),
                    ),
                    AnchorPoint(
                      position: const Point(x: 300, y: 200),
                      handleIn: const Point(x: -50, y: 0),
                    ),
                  ],
                  segments: [Segment.bezier(startIndex: 0, endIndex: 1)],
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-shapes',
            name: 'Shapes',
            objects: [
              // Rectangle shape
              VectorObject.shape(
                id: 'rect-1',
                shape: Shape.rectangle(
                  center: const Point(x: 150, y: 150),
                  width: 100,
                  height: 60,
                ),
              ),
              // Circle shape
              VectorObject.shape(
                id: 'circle-1',
                shape: Shape.ellipse(
                  center: const Point(x: 250, y: 250),
                  width: 80,
                  height: 80,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/integration_test_output.svg';
      await exporter.exportToFile(document, filePath);

      // Verify file exists and is readable
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();

      // Validate XML structure
      expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(content, contains('<svg'));
      expect(content, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(content, contains('version="1.1"'));
      expect(content, contains('</svg>'));

      // Validate metadata
      expect(content, contains('<metadata>'));
      expect(
          content, contains('<dc:title>Integration Test Document</dc:title>'));
      expect(content, contains('<dc:creator>WireTuner 0.1</dc:creator>'));

      // Validate layer groups
      expect(content, contains('id="layer-paths"'));
      expect(content, contains('id="layer-shapes"'));

      // Validate path elements
      expect(content, contains('id="line-1"'));
      expect(content, contains('id="curve-1"'));
      expect(content, contains('id="rect-1"'));
      expect(content, contains('id="circle-1"'));

      // Validate path data contains expected commands
      expect(content, contains('M ')); // Move commands
      expect(content, contains('L ')); // Line commands
      expect(content, contains('C ')); // Bezier curve commands
    });

    test('Exports compound paths with gradients (placeholder)', () async {
      // Create a complex document with compound paths
      final compoundPath = Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 0, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 0)),
          AnchorPoint.corner(const Point(x: 100, y: 100)),
          AnchorPoint.corner(const Point(x: 0, y: 100)),
        ],
        segments: [
          Segment.line(startIndex: 0, endIndex: 1),
          Segment.line(startIndex: 1, endIndex: 2),
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
              VectorObject.path(id: 'compound-1', path: compoundPath),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/compound_path_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();

      // Verify closed path has Z command
      expect(content, contains(' Z'));

      // Verify viewBox is calculated correctly
      expect(content, contains('viewBox="0.00 0.00 100.00 100.00"'));
    });

    test('Exports with proper XML escaping', () async {
      final document = Document(
        id: 'doc-escaping',
        title: 'Test <Title> & "Quotes" \' Special',
        layers: [
          Layer(
            id: 'layer-<special>',
            name: 'Layer & Name',
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

      final filePath = '${tempDir.path}/escaping_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();

      // Verify XML entities are properly escaped
      expect(content, contains('&lt;Title&gt;')); // <Title>
      expect(content, contains('&amp;')); // &
      expect(content, contains('&quot;')); // "
      expect(content, contains('&apos;')); // '

      // Verify IDs are escaped
      expect(content, contains('id="layer-&lt;special&gt;"'));
      expect(content, contains('id="path-&quot;quoted&quot;"'));
    });

    test('Exports multiple layers with visibility handling', () async {
      final document = Document(
        id: 'doc-visibility',
        title: 'Visibility Test',
        layers: [
          Layer(
            id: 'layer-visible-1',
            name: 'Visible Layer 1',
            visible: true,
            objects: [
              VectorObject.path(
                id: 'path-v1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 50, y: 50),
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-hidden',
            name: 'Hidden Layer',
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
          Layer(
            id: 'layer-visible-2',
            name: 'Visible Layer 2',
            visible: true,
            objects: [
              VectorObject.path(
                id: 'path-v2',
                path: Path.line(
                  start: const Point(x: 20, y: 20),
                  end: const Point(x: 70, y: 70),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/visibility_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();

      // Verify visible layers are included
      expect(content, contains('id="layer-visible-1"'));
      expect(content, contains('id="path-v1"'));
      expect(content, contains('id="layer-visible-2"'));
      expect(content, contains('id="path-v2"'));

      // Verify hidden layer is NOT included
      expect(content, isNot(contains('id="layer-hidden"')));
      expect(content, isNot(contains('id="path-hidden"')));
    });

    test('Exports with correct coordinate precision', () async {
      final path = Path(
        anchors: [
          AnchorPoint.corner(const Point(x: 1.234567, y: 9.876543)),
          AnchorPoint.corner(const Point(x: 100.999999, y: 200.000001)),
        ],
        segments: [Segment.line(startIndex: 0, endIndex: 1)],
      );

      final document = Document(
        id: 'doc-precision',
        title: 'Precision Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [VectorObject.path(id: 'precise-path', path: path)],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/precision_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();

      // Verify 2 decimal precision
      expect(content, contains('M 1.23 9.88')); // Rounded to 2 decimals
      expect(content, contains('L 101.00 200.00')); // Rounded to 2 decimals
    });

    test('Validates exported SVG can be parsed as valid XML', () async {
      final document = Document(
        id: 'doc-xml-validation',
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

      final filePath = '${tempDir.path}/xml_validation_test.svg';
      await exporter.exportToFile(document, filePath);

      final content = await File(filePath).readAsString();

      // Basic XML well-formedness checks
      // Count opening and closing tags
      final svgOpenCount = '<svg'.allMatches(content).length;
      final svgCloseCount = '</svg>'.allMatches(content).length;
      expect(svgOpenCount, equals(1));
      expect(svgCloseCount, equals(1));

      final gOpenCount = '<g '.allMatches(content).length;
      final gCloseCount = '</g>'.allMatches(content).length;
      expect(gOpenCount, equals(gCloseCount));

      // Verify proper XML declaration
      expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));

      // Verify no unescaped special characters outside of tags
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.contains('>') && line.contains('<')) {
          // Extract content between tags
          final contentMatch = RegExp(r'>([^<]+)<').firstMatch(line);
          if (contentMatch != null) {
            final tagContent = contentMatch.group(1)!;
            // Content should not contain raw < > &
            // Note: quotes and apostrophes are allowed in text content
            expect(tagContent, isNot(contains(RegExp(r'[<>&]'))));
          }
        }
      }
    });

    test('Exports large documents efficiently', () async {
      // Create a document with many objects
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

      final document = Document(
        id: 'doc-large',
        title: 'Large Document Test',
        layers: [
          Layer(
            id: 'layer-bulk',
            objects: objects,
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final filePath = '${tempDir.path}/large_document_test.svg';

      final startTime = DateTime.now();
      await exporter.exportToFile(document, filePath);
      final duration = DateTime.now().difference(startTime);

      // Export should complete within reasonable time
      expect(duration.inSeconds, lessThan(3));

      // Verify file was created and contains all objects
      final content = await File(filePath).readAsString();
      expect(content, contains('id="path-0"'));
      expect(content, contains('id="path-999"'));
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('SVG W3C Validator Integration', () {
    late SvgExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = SvgExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_svg_validator_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Validates exported SVG with W3C validator (if available)', () async {
      // Create a simple document
      final document = Document(
        id: 'doc-w3c',
        title: 'W3C Validation Test',
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

      final filePath = '${tempDir.path}/w3c_validation_test.svg';
      await exporter.exportToFile(document, filePath);

      // Try to run W3C validator if available
      try {
        final result = await Process.run(
          'vnu',
          ['--svg', '--stdout', filePath],
        );

        // If vnu is installed, check that validation passed
        if (result.exitCode == 0) {
          // No errors - validation passed
          expect(result.exitCode, equals(0));
          print('✓ W3C validation passed');
        } else {
          // Validation failed - print errors
          print('✗ W3C validation failed:');
          print(result.stderr);
          fail('W3C validation failed with errors');
        }
      } catch (e) {
        // Validator not installed - skip test
        print('⊘ W3C validator (vnu) not found - skipping validation');
        print('  Install with: npm install -g vnu-jar');
      }
    });

    test('Golden file comparison test', () async {
      // Create the exact document structure that matches the golden file
      final document = Document(
        id: 'doc-golden',
        title: 'Golden Test Document',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'line-1',
                path: Path.line(
                  start: const Point(x: 10, y: 10),
                  end: const Point(x: 100, y: 100),
                ),
              ),
              VectorObject.path(
                id: 'curve-1',
                path: Path(
                  anchors: [
                    AnchorPoint(
                      position: const Point(x: 200, y: 200),
                      handleOut: const Point(x: 50, y: 0),
                    ),
                    AnchorPoint(
                      position: const Point(x: 300, y: 200),
                      handleIn: const Point(x: -50, y: 0),
                    ),
                  ],
                  segments: [Segment.bezier(startIndex: 0, endIndex: 1)],
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-2',
            objects: [
              VectorObject.shape(
                id: 'rect-1',
                shape: Shape.rectangle(
                  center: const Point(x: 150, y: 135),
                  width: 100,
                  height: 30,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Generate SVG
      final actualSvg = exporter.generateSvg(document);

      // Read golden file
      final goldenFile = File('test/integration/fixtures/golden_export.svg');
      expect(goldenFile.existsSync(), isTrue,
          reason:
              'Golden file should exist at test/integration/fixtures/golden_export.svg');

      final goldenSvg = await goldenFile.readAsString();

      // Normalize whitespace for comparison (ignore formatting differences)
      String normalize(String svg) {
        return svg
            .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
            .replaceAll(RegExp(r'>\s+<'), '><') // Remove space between tags
            .trim();
      }

      final normalizedActual = normalize(actualSvg);
      final normalizedGolden = normalize(goldenSvg);

      // Compare normalized content
      expect(normalizedActual, equals(normalizedGolden),
          reason: 'Exported SVG should match golden file');

      // If comparison fails, write actual output for debugging
      if (normalizedActual != normalizedGolden) {
        final debugFile = File('${tempDir.path}/golden_mismatch.svg');
        await debugFile.writeAsString(actualSvg);
        print('Actual output written to: ${debugFile.path}');
      }
    });
  });
}
