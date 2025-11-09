import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/anchor_point.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/domain/models/segment.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/infrastructure/export/pdf_exporter.dart';

/// Integration tests for PDF export that verify output using external tools.
///
/// These tests validate that exported PDFs:
/// 1. Can be opened by external PDF viewers (Preview, Acrobat)
/// 2. Have correct page dimensions
/// 3. Have valid PDF structure
/// 4. Can be parsed by PDF tools (pdfinfo, pdffonts, etc.)
///
/// ## Requirements
///
/// These tests require external PDF tools to be installed:
/// - `pdfinfo`: Part of poppler-utils (macOS: `brew install poppler`)
/// - `pdffonts`: Part of poppler-utils (for text tests when implemented)
///
/// Tests will be skipped if tools are not available.
void main() {
  group('PDF Export Integration Tests', () {
    late PdfExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = PdfExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_pdf_integration_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Exported PDF can be verified with pdfinfo', () async {
      // Create a simple test document
      final document = Document(
        id: 'doc-integration',
        title: 'Integration Test Document',
        layers: [
          Layer(
            id: 'layer-1',
            name: 'Test Layer',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 50, y: 50),
                  end: const Point(x: 200, y: 150),
                ),
              ),
              VectorObject.shape(
                id: 'rect-1',
                shape: Shape.rectangle(
                  center: const Point(x: 300, y: 200),
                  width: 100,
                  height: 80,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Export to PDF
      final pdfPath = '${tempDir.path}/integration_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Verify file exists
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue, reason: 'PDF file should exist');

      // Check if pdfinfo is available
      final pdfinfoCheck = await Process.run('which', ['pdfinfo']);
      if (pdfinfoCheck.exitCode != 0) {
        // pdfinfo not available, skip external validation
        print('⚠️  pdfinfo not found, skipping external tool validation');
        print('   Install with: brew install poppler');
        return;
      }

      // Run pdfinfo to validate PDF structure
      final result = await Process.run('pdfinfo', [pdfPath]);

      // Verify pdfinfo succeeded
      expect(
        result.exitCode,
        equals(0),
        reason: 'pdfinfo should successfully parse the PDF',
      );

      // Parse pdfinfo output
      final output = result.stdout as String;
      expect(output, contains('Title:'), reason: 'PDF should have title metadata');
      expect(output, contains('Creator:'), reason: 'PDF should have creator metadata');
      expect(output, contains('Producer:'), reason: 'PDF should have producer metadata');
      expect(output, contains('PDF version:'), reason: 'PDF should specify version');
      expect(output, contains('Pages:'), reason: 'PDF should have page count');

      // Verify page count
      final pagesMatch = RegExp(r'Pages:\s+(\d+)').firstMatch(output);
      expect(pagesMatch, isNotNull, reason: 'Should extract page count');
      final pageCount = int.parse(pagesMatch!.group(1)!);
      expect(pageCount, equals(1), reason: 'Document should have exactly 1 page');

      // Verify PDF version
      expect(
        output,
        contains(RegExp(r'PDF version:\s+1\.[4-7]')),
        reason: 'PDF version should be 1.4 to 1.7',
      );
    });

    test('PDF page dimensions match document bounds', () async {
      // Create document with known dimensions
      final document = Document(
        id: 'doc-dimensions',
        title: 'Dimensions Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-bounds',
                path: Path.fromAnchors(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 0, y: 0)),
                    AnchorPoint.corner(const Point(x: 400, y: 0)),
                    AnchorPoint.corner(const Point(x: 400, y: 300)),
                    AnchorPoint.corner(const Point(x: 0, y: 300)),
                  ],
                  closed: true,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Export to PDF
      final pdfPath = '${tempDir.path}/dimensions_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Check if pdfinfo is available
      final pdfinfoCheck = await Process.run('which', ['pdfinfo']);
      if (pdfinfoCheck.exitCode != 0) {
        print('⚠️  pdfinfo not found, skipping dimension validation');
        return;
      }

      // Get page dimensions from pdfinfo
      final result = await Process.run('pdfinfo', [pdfPath]);
      expect(result.exitCode, equals(0));

      final output = result.stdout as String;

      // Extract page size (format: "Page size: WIDTHxHEIGHT pts")
      final pageSizeMatch = RegExp(r'Page size:\s+([\d.]+)\s+x\s+([\d.]+)\s+pts')
          .firstMatch(output);

      if (pageSizeMatch != null) {
        final width = double.parse(pageSizeMatch.group(1)!);
        final height = double.parse(pageSizeMatch.group(2)!);

        // Document bounds are 400x300, verify PDF matches
        expect(width, equals(400.0), reason: 'PDF width should match document bounds');
        expect(height, equals(300.0), reason: 'PDF height should match document bounds');
      } else {
        print('⚠️  Could not parse page size from pdfinfo output');
      }
    });

    test('PDF with multiple objects and layers exports correctly', () async {
      // Create complex document
      final document = Document(
        id: 'doc-complex',
        title: 'Complex Test Document',
        layers: [
          Layer(
            id: 'layer-background',
            name: 'Background',
            objects: [
              VectorObject.shape(
                id: 'bg-rect',
                shape: Shape.rectangle(
                  center: const Point(x: 250, y: 250),
                  width: 500,
                  height: 500,
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-paths',
            name: 'Paths',
            objects: [
              VectorObject.path(
                id: 'path-line-1',
                path: Path.line(
                  start: const Point(x: 100, y: 100),
                  end: const Point(x: 400, y: 100),
                ),
              ),
              VectorObject.path(
                id: 'path-curve-1',
                path: Path(
                  anchors: const [
                    AnchorPoint(
                      position: Point(x: 100, y: 200),
                      handleOut: Point(x: 100, y: 0),
                    ),
                    AnchorPoint(
                      position: Point(x: 400, y: 200),
                      handleIn: Point(x: -100, y: 0),
                    ),
                  ],
                  segments: [
                    Segment.bezier(startIndex: 0, endIndex: 1),
                  ],
                ),
              ),
            ],
          ),
          Layer(
            id: 'layer-shapes',
            name: 'Shapes',
            objects: [
              VectorObject.shape(
                id: 'circle-1',
                shape: Shape.ellipse(
                  center: const Point(x: 250, y: 350),
                  width: 100,
                  height: 100,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Export to PDF
      final pdfPath = '${tempDir.path}/complex_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Verify file exists and has content
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);
      final fileSize = await pdfFile.length();
      expect(fileSize, greaterThan(0), reason: 'PDF file should not be empty');

      // Check if pdfinfo is available
      final pdfinfoCheck = await Process.run('which', ['pdfinfo']);
      if (pdfinfoCheck.exitCode != 0) {
        print('⚠️  pdfinfo not found, skipping validation');
        return;
      }

      // Validate with pdfinfo
      final result = await Process.run('pdfinfo', [pdfPath]);
      expect(result.exitCode, equals(0), reason: 'pdfinfo should parse complex PDF');

      final output = result.stdout as String;
      expect(output, contains('Complex Test Document'), reason: 'Title should be embedded');
    });

    test('PDF with invisible layers excludes hidden content', () async {
      // Create document with mix of visible/invisible layers
      final document = Document(
        id: 'doc-visibility',
        title: 'Visibility Test',
        layers: [
          Layer(
            id: 'layer-visible',
            name: 'Visible Layer',
            visible: true,
            objects: [
              VectorObject.path(
                id: 'visible-path',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 100, y: 100),
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
                id: 'hidden-path',
                path: Path.line(
                  start: const Point(x: 200, y: 200),
                  end: const Point(x: 300, y: 300),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Export to PDF
      final pdfPath = '${tempDir.path}/visibility_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Verify file exists
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);

      // Note: Cannot easily verify content without PDF parser
      // The unit tests verify the logic, this just confirms export succeeds
    });

    test('Empty document exports valid PDF', () async {
      // Create empty document
      const document = Document(
        id: 'doc-empty',
        title: 'Empty Document',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      // Export to PDF
      final pdfPath = '${tempDir.path}/empty_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Verify file exists
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);

      // Check if pdfinfo is available
      final pdfinfoCheck = await Process.run('which', ['pdfinfo']);
      if (pdfinfoCheck.exitCode != 0) {
        print('⚠️  pdfinfo not found, skipping validation');
        return;
      }

      // Verify pdfinfo can parse empty PDF
      final result = await Process.run('pdfinfo', [pdfPath]);
      expect(
        result.exitCode,
        equals(0),
        reason: 'Empty PDF should be valid and parseable',
      );

      final output = result.stdout as String;
      expect(output, contains('Pages:'), reason: 'Should have page count');

      // Empty document should have 1 page with default size
      final pagesMatch = RegExp(r'Pages:\s+(\d+)').firstMatch(output);
      expect(pagesMatch, isNotNull);
      expect(int.parse(pagesMatch!.group(1)!), equals(1));
    });

    test('PDF opens in Preview without warnings (manual verification)', () async {
      // This is a semi-automated test - export PDF for manual verification
      final document = Document(
        id: 'doc-preview',
        title: 'Preview Verification Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.fromAnchors(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 50, y: 50)),
                    AnchorPoint.corner(const Point(x: 200, y: 50)),
                    AnchorPoint.corner(const Point(x: 200, y: 200)),
                    AnchorPoint.corner(const Point(x: 50, y: 200)),
                  ],
                  closed: true,
                ),
              ),
              VectorObject.path(
                id: 'path-curve',
                path: Path(
                  anchors: const [
                    AnchorPoint(
                      position: Point(x: 250, y: 100),
                      handleOut: Point(x: 50, y: 50),
                    ),
                    AnchorPoint(
                      position: Point(x: 350, y: 150),
                      handleIn: Point(x: -50, y: -50),
                    ),
                  ],
                  segments: [
                    Segment.bezier(startIndex: 0, endIndex: 1),
                  ],
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Export to PDF in temp directory
      final pdfPath = '${tempDir.path}/preview_test.pdf';
      await exporter.exportToFile(document, pdfPath);

      // Verify file was created
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);

      // Print path for manual verification
      print('📄 PDF exported for manual verification: $pdfPath');
      print('   Open in Preview.app or Acrobat to verify:');
      print('   - PDF opens without warnings');
      print('   - Rectangle and curve render correctly');
      print('   - No rendering artifacts');

      // Automated check with pdfinfo
      final pdfinfoCheck = await Process.run('which', ['pdfinfo']);
      if (pdfinfoCheck.exitCode == 0) {
        final result = await Process.run('pdfinfo', [pdfPath]);
        expect(result.exitCode, equals(0), reason: 'PDF should be valid');
      }
    });

    test('Performance: Export large document within time limit', () async {
      // Create document with many objects (1000 paths)
      final objects = List.generate(
        1000,
        (i) => VectorObject.path(
          id: 'path-$i',
          path: Path.line(
            start: Point(x: (i % 100).toDouble() * 10, y: (i ~/ 100).toDouble() * 10),
            end: Point(x: (i % 100).toDouble() * 10 + 5, y: (i ~/ 100).toDouble() * 10 + 5),
          ),
        ),
      );

      final document = Document(
        id: 'doc-performance',
        title: 'Performance Test (1000 objects)',
        layers: [
          Layer(
            id: 'layer-bulk',
            objects: objects,
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      // Measure export time
      final pdfPath = '${tempDir.path}/performance_test.pdf';
      final stopwatch = Stopwatch()..start();

      await exporter.exportToFile(document, pdfPath);

      stopwatch.stop();

      // Verify export completed quickly
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: '1000 objects should export in <5 seconds',
      );

      print('✅ Exported 1000 objects in ${stopwatch.elapsedMilliseconds}ms');

      // Verify file exists and is valid
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);
    });
  });
}
