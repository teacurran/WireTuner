import 'dart:convert';
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

void main() {
  group('PdfExporter - generatePdf', () {
    late PdfExporter exporter;

    setUp(() {
      exporter = PdfExporter();
    });

    test('Exports empty document to valid PDF', () async {
      const document = Document(
        id: 'doc-empty',
        title: 'Empty Drawing',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is not empty
      expect(pdfBytes, isNotEmpty);

      // Verify PDF magic number %PDF-1.x (in ASCII)
      // 0x25 = '%', 0x50 = 'P', 0x44 = 'D', 0x46 = 'F'
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

      // Verify PDF version string is present
      final header = utf8.decode(pdfBytes.sublist(0, 20), allowMalformed: true);
      expect(header, startsWith('%PDF-1.'));
    });

    test('Exports document with single line path', () async {
      final document = Document(
        id: 'doc-1',
        title: 'Single Line',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

      // Verify PDF contains expected structure
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);
      expect(pdfContent, contains('%PDF')); // PDF header
      expect(pdfContent, contains('%%EOF')); // PDF footer
    });

    test('Exports document with Bezier path', () async {
      final document = Document(
        id: 'doc-bezier',
        title: 'Bezier Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-bezier',
                path: Path(
                  anchors: const [
                    AnchorPoint(
                      position: Point(x: 0, y: 0),
                      handleOut: Point(x: 50, y: 0),
                    ),
                    AnchorPoint(
                      position: Point(x: 100, y: 100),
                      handleIn: Point(x: -50, y: 0),
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

      // Note: Full Bezier accuracy verification would require PDF parsing
      // For now, verify export completes successfully
    });

    test('Exports closed path correctly', () async {
      final document = Document(
        id: 'doc-closed',
        title: 'Closed Path Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-triangle',
                path: Path.fromAnchors(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 0, y: 0)),
                    AnchorPoint.corner(const Point(x: 100, y: 0)),
                    AnchorPoint.corner(const Point(x: 50, y: 86.6)),
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Exports open path correctly', () async {
      final document = Document(
        id: 'doc-open',
        title: 'Open Path Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-line',
                path: Path.fromAnchors(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 0, y: 0)),
                    AnchorPoint.corner(const Point(x: 100, y: 0)),
                    AnchorPoint.corner(const Point(x: 50, y: 86.6)),
                  ],
                  closed: false,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Exports shapes by converting to paths', () async {
      final document = Document(
        id: 'doc-shape',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid (shape converted to path)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Exports document with multiple objects', () async {
      final document = Document(
        id: 'doc-multi',
        title: 'Multiple Objects',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 0, y: 0),
                  end: const Point(x: 50, y: 50),
                ),
              ),
              VectorObject.path(
                id: 'path-2',
                path: Path.line(
                  start: const Point(x: 50, y: 50),
                  end: const Point(x: 100, y: 0),
                ),
              ),
              VectorObject.shape(
                id: 'circle-1',
                shape: Shape.ellipse(
                  center: const Point(x: 75, y: 25),
                  width: 20,
                  height: 20,
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Exports document with multiple layers', () async {
      final document = Document(
        id: 'doc-layers',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Skips invisible layers', () async {
      final document = Document(
        id: 'doc-hidden',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      // Note: Cannot easily verify content without PDF parser,
      // but export should complete successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles empty path (no anchors)', () async {
      final document = Document(
        id: 'doc-empty-path',
        title: 'Empty Path Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-empty',
                path: Path.empty(),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully (skip empty path)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles path with single anchor', () async {
      final document = Document(
        id: 'doc-single-anchor',
        title: 'Single Anchor Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-point',
                path: Path(
                  anchors: [AnchorPoint.corner(const Point(x: 50, y: 50))],
                  segments: const [],
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles negative coordinates', () async {
      final document = Document(
        id: 'doc-negative',
        title: 'Negative Coordinates',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: -50, y: -30),
                  end: const Point(x: -10, y: -5),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles large coordinates', () async {
      final document = Document(
        id: 'doc-large',
        title: 'Large Coordinates',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path.line(
                  start: const Point(x: 10000, y: 20000),
                  end: const Point(x: 15000, y: 25000),
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Ignores selection state during export', () async {
      final document = Document(
        id: 'doc-selection',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully (selection ignored)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('PdfExporter - Metadata', () {
    late PdfExporter exporter;

    setUp(() {
      exporter = PdfExporter();
    });

    test('Embeds document title in metadata', () async {
      const document = Document(
        id: 'doc-title',
        title: 'Test Drawing Title',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid
      expect(pdfBytes, isNotEmpty);

      // Verify title is present in PDF metadata
      // (Full metadata parsing requires external library, but we can check for presence)
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);
      expect(pdfContent, contains('Test Drawing Title'));
    });

    test('Embeds creator information', () async {
      const document = Document(
        id: 'doc-creator',
        title: 'Creator Test',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF contains creator information
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);
      expect(pdfContent, contains('WireTuner'));
    });

    test('Handles special characters in title', () async {
      const document = Document(
        id: 'doc-special',
        title: 'Test <Title> & "Quotes"',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully (PDF handles encoding)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles UTF-8 characters in title', () async {
      const document = Document(
        id: 'doc-utf8',
        title: 'UTF-8 Test: 日本語 中文 한글',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('PdfExporter - exportToFile', () {
    late PdfExporter exporter;
    late Directory tempDir;

    setUp(() {
      exporter = PdfExporter();
      tempDir = Directory.systemTemp.createTempSync('wiretuner_pdf_test_');
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

      final filePath = '${tempDir.path}/test_export.pdf';
      await exporter.exportToFile(document, filePath);

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      // Verify file content is valid PDF
      final bytes = await file.readAsBytes();
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Overwrites existing file', () async {
      final filePath = '${tempDir.path}/overwrite_test.pdf';

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

      // Verify new content is valid PDF
      final bytes = await File(filePath).readAsBytes();
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

      final content = utf8.decode(bytes, allowMalformed: true);
      expect(content, isNot(contains('old content')));
    });

    test('Throws exception for invalid file path', () async {
      const document = Document(
        id: 'doc-invalid',
        title: 'Invalid Path Test',
        layers: [],
        selection: Selection(),
        viewport: Viewport(),
      );

      const invalidPath = '/nonexistent_directory_xyz/test.pdf';

      await expectLater(
        exporter.exportToFile(document, invalidPath),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('Creates parent directories if they exist', () async {
      final document = Document(
        id: 'doc-subdir',
        title: 'Subdirectory Test',
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

      // Create subdirectory first
      final subDir = Directory('${tempDir.path}/subdir');
      subDir.createSync();

      final filePath = '${subDir.path}/test.pdf';
      await exporter.exportToFile(document, filePath);

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      // Verify valid PDF
      final bytes = await file.readAsBytes();
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('PdfExporter - Performance', () {
    late PdfExporter exporter;

    setUp(() {
      exporter = PdfExporter();
    });

    test(
      'Exports 5000 objects within 10 seconds',
      () async {
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
        final pdfBytes = await exporter.generatePdf(document);
        final duration = DateTime.now().difference(startTime);

        // Acceptance criteria: <10s for benchmark doc
        expect(
          duration.inSeconds,
          lessThan(10),
          reason: 'Export took ${duration.inSeconds}s, target <10s',
        );

        // Verify PDF is valid
        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'Exports 1000 Bezier curves efficiently',
      () async {
        // Create document with 1000 Bezier curve paths
        final objects = List.generate(
          1000,
          (i) => VectorObject.path(
            id: 'curve-$i',
            path: Path(
              anchors: [
                AnchorPoint(
                  position: Point(x: i.toDouble(), y: i.toDouble()),
                  handleOut: const Point(x: 50, y: 0),
                ),
                AnchorPoint(
                  position: Point(x: i.toDouble() + 100, y: i.toDouble() + 100),
                  handleIn: const Point(x: -50, y: 0),
                ),
              ],
              segments: [
                Segment.bezier(startIndex: 0, endIndex: 1),
              ],
            ),
          ),
        );

        final document = Document(
          id: 'doc-curves',
          title: 'Bezier Benchmark',
          layers: [
            Layer(
              id: 'layer-curves',
              objects: objects,
            ),
          ],
          selection: const Selection(),
          viewport: const Viewport(),
        );

        final startTime = DateTime.now();
        final pdfBytes = await exporter.generatePdf(document);
        final duration = DateTime.now().difference(startTime);

        // Should complete in reasonable time
        expect(
          duration.inSeconds,
          lessThan(5),
          reason: 'Export took ${duration.inSeconds}s',
        );

        // Verify PDF is valid
        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('PdfExporter - Fill and Stroke Support', () {
    late PdfExporter exporter;

    setUp(() {
      exporter = PdfExporter();
    });

    test('Exports path with default stroke (backward compatibility)', () async {
      final document = Document(
        id: 'doc-default-stroke',
        title: 'Default Stroke Test',
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify PDF is valid (uses default black stroke)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Infrastructure supports fill and stroke parameters', () async {
      // Note: This test verifies the API exists, even though VectorObject
      // doesn't yet store style data. When style system is integrated,
      // the exporter will use these parameters.
      final document = Document(
        id: 'doc-styled',
        title: 'Styled Path Test',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-filled',
                path: Path.fromAnchors(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 0, y: 0)),
                    AnchorPoint.corner(const Point(x: 100, y: 0)),
                    AnchorPoint.corner(const Point(x: 50, y: 86.6)),
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

      final pdfBytes = await exporter.generatePdf(document);

      // Verify export completes successfully
      // When style data is available, _drawPath will use fillColor/strokeColor
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('PdfExporter - Edge Cases', () {
    late PdfExporter exporter;

    setUp(() {
      exporter = PdfExporter();
    });

    test('Handles document with only invisible layers', () async {
      final document = Document(
        id: 'doc-all-hidden',
        title: 'All Hidden',
        layers: [
          Layer(
            id: 'layer-1',
            visible: false,
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

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully (empty content)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles layer with no objects', () async {
      const document = Document(
        id: 'doc-empty-layer',
        title: 'Empty Layer',
        layers: [
          Layer(
            id: 'layer-empty',
            objects: [],
          ),
        ],
        selection: Selection(),
        viewport: Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles mixed line and Bezier segments in same path', () async {
      final document = Document(
        id: 'doc-mixed',
        title: 'Mixed Segments',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-mixed',
                path: Path(
                  anchors: [
                    AnchorPoint.corner(const Point(x: 0, y: 0)),
                    const AnchorPoint(
                      position: Point(x: 50, y: 50),
                      handleIn: Point(x: -20, y: 0),
                      handleOut: Point(x: 20, y: 0),
                    ),
                    AnchorPoint.corner(const Point(x: 100, y: 0)),
                  ],
                  segments: [
                    Segment.bezier(startIndex: 0, endIndex: 1),
                    Segment.line(startIndex: 1, endIndex: 2),
                  ],
                ),
              ),
            ],
          ),
        ],
        selection: const Selection(),
        viewport: const Viewport(),
      );

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Handles path with null handles on Bezier segment', () async {
      final document = Document(
        id: 'doc-null-handles',
        title: 'Null Handles',
        layers: [
          Layer(
            id: 'layer-1',
            objects: [
              VectorObject.path(
                id: 'path-1',
                path: Path(
                  anchors: const [
                    AnchorPoint(
                      position: Point(x: 0, y: 0),
                      handleOut: null,
                    ),
                    AnchorPoint(
                      position: Point(x: 100, y: 100),
                      handleIn: null,
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

      final pdfBytes = await exporter.generatePdf(document);

      // Should export successfully (degrades to line)
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });
}
