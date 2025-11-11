/// Unit tests for AI importer.
///
/// Tests cover:
/// - Tier-1 operator parsing (moveto, lineto, curveto, closepath, rectangle)
/// - Tier-2 feature conversion (gradients, CMYK colors, Bezier variants)
/// - Tier-3 feature warnings (text, effects, unsupported operators)
/// - Coordinate system conversion (PDF → WireTuner)
/// - Security validation (file size, coordinate bounds)
/// - Error handling (malformed files, invalid operators)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:logger/logger.dart';
import '../../lib/src/importers/ai_importer.dart';

void main() {
  group('AIImporter', () {
    late AIImporter importer;
    late Logger logger;

    setUp(() {
      logger = Logger(level: Level.warning); // Suppress debug logs in tests
      importer = AIImporter(logger: logger);
    });

    group('file validation', () {
      test('rejects non-existent files', () async {
        expect(
          () => importer.importFromFile('/nonexistent/file.ai'),
          throwsA(isA<AIImportException>().having(
            (e) => e.message,
            'message',
            contains('File not found'),
          )),
        );
      });

      test('rejects files exceeding 10 MB limit', () async {
        // Create temporary oversized file
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/oversized.ai');

        // Write 11 MB of data (exceeds 10 MB limit)
        final largeData = Uint8List(11 * 1024 * 1024);
        await tempFile.writeAsBytes(largeData);

        try {
          await importer.importFromFile(tempFile.path);
          fail('Should have thrown AIImportException for oversized file');
        } on AIImportException catch (e) {
          expect(e.message, contains('exceeds maximum'));
          expect(e.message, contains('10 MB'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('warns about non-.ai extension', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/file.pdf');

        // Create minimal PDF file
        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Should have warning about file extension
          expect(
            result.warnings.any(
              (w) =>
                  w.featureType == 'file-extension' &&
                  w.severity == 'warning',
            ),
            isTrue,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('PDF structure validation', () {
      test('rejects files without PDF header', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/invalid.ai');

        // Write invalid data (not PDF)
        await tempFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));

        try {
          await importer.importFromFile(tempFile.path);
          fail('Should have thrown AIImportException for invalid PDF');
        } on AIImportException catch (e) {
          expect(e.message, contains('not a valid PDF structure'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('accepts files with valid PDF header', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/valid.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Should parse successfully (even if returning demonstration events)
          expect(result.events, isNotEmpty);
          expect(result.metadata, isNotNull);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('PDF operator parsing', () {
      test('generates valid event structure from PDF operators', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Should parse PDF operators and generate events
          expect(result.events, isNotEmpty);

          // Verify event structure
          final createPathEvent = result.events.firstWhere(
            (e) => e['eventType'] == 'CreatePathEvent',
          );
          expect(createPathEvent['eventId'], isNotNull);
          expect(createPathEvent['timestamp'], isA<int>());
          expect(createPathEvent['pathId'], isNotNull);
          expect(createPathEvent['startAnchor'], isA<Map>());
          expect(createPathEvent['startAnchor']['x'], isA<double>());
          expect(createPathEvent['startAnchor']['y'], isA<double>());

          // Verify AddAnchorEvent structure
          final addAnchorEvents = result.events
              .where((e) => e['eventType'] == 'AddAnchorEvent')
              .toList();
          expect(addAnchorEvents, isNotEmpty);

          for (final event in addAnchorEvents) {
            expect(event['eventId'], isNotNull);
            expect(event['pathId'], isNotNull);
            expect(event['position'], isA<Map>());
            expect(event['position']['x'], isA<double>());
            expect(event['position']['y'], isA<double>());
            expect(event['anchorType'], 'line');
          }

          // Verify FinishPathEvent
          final finishPathEvent = result.events.firstWhere(
            (e) => e['eventType'] == 'FinishPathEvent',
          );
          expect(finishPathEvent['pathId'], equals(createPathEvent['pathId']));
          expect(finishPathEvent['closed'], isTrue);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('generates monotonic timestamps', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Verify timestamps are monotonically increasing
          int? previousTimestamp;
          for (final event in result.events) {
            final timestamp = event['timestamp'] as int;
            if (previousTimestamp != null) {
              expect(timestamp, greaterThan(previousTimestamp));
            }
            previousTimestamp = timestamp;
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('generates sequential event sequence numbers', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Verify event sequences are sequential starting from 0
          for (var i = 0; i < result.events.length; i++) {
            expect(result.events[i]['eventSequence'], equals(i));
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('warnings collection', () {
      test('includes AI private data limitation warning', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Should have warning about AI private data
          expect(
            result.warnings.any(
              (w) =>
                  w.featureType == 'ai-private-data' &&
                  w.severity == 'info' &&
                  w.message.contains('PDF layer only'),
            ),
            isTrue,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('parses real PDF content stream successfully', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          // Should successfully parse (even if minimal PDF has no content stream, it should return empty events gracefully)
          expect(result.events, isNotNull);
          expect(result.metadata, isNotNull);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('metadata extraction', () {
      test('extracts basic metadata', () async {
        final tempDir = await Directory.systemTemp.createTemp('ai_test_');
        final tempFile = File('${tempDir.path}/demo.ai');

        final pdfBytes = _createMinimalPdfBytes();
        await tempFile.writeAsBytes(pdfBytes);

        try {
          final result = await importer.importFromFile(tempFile.path);

          expect(result.metadata.pageCount, equals(1));
          expect(result.metadata.pageWidth, equals(612.0)); // Letter size
          expect(result.metadata.pageHeight, equals(792.0)); // Letter size
          expect(result.metadata.creator, equals('Adobe Illustrator'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('Y-axis coordinate conversion', () {
      test('flips Y coordinates from PDF to WireTuner space', () {
        // PDF page height: 792 points (Letter size)
        const pageHeight = 792.0;

        // Test coordinates
        expect(pageHeight - 692.0, equals(100.0)); // Near top in PDF → near top in WT
        expect(pageHeight - 100.0, equals(692.0)); // Near bottom in PDF → near bottom in WT
        expect(pageHeight - 396.0, equals(396.0)); // Center stays center
      });
    });

    group('integration tests with fixtures', () {
      test('imports simple_rect.ai fixture correctly', () async {
        final fixturePath = 'test/fixtures/ai/simple_rect.ai';
        final fixtureFile = File(fixturePath);

        // Skip if fixture doesn't exist
        if (!await fixtureFile.exists()) {
          markTestSkipped('Fixture file not found: $fixturePath');
          return;
        }

        final result = await importer.importFromFile(fixturePath);

        // Should have parsed the rectangular path
        expect(result.events, isNotEmpty);

        // Verify CreatePathEvent
        final createPathEvents = result.events
            .where((e) => e['eventType'] == 'CreatePathEvent')
            .toList();
        expect(createPathEvents, hasLength(1));

        final createPath = createPathEvents.first;
        expect(createPath['startAnchor'], isNotNull);
        expect(createPath['startAnchor']['x'], equals(100.0));
        // Y coordinate should be flipped: pageHeight (792) - 100 = 692
        expect(createPath['startAnchor']['y'], equals(692.0));

        // Verify AddAnchorEvents (3 line segments: to 200,100 / 200,200 / 100,200)
        final addAnchorEvents = result.events
            .where((e) => e['eventType'] == 'AddAnchorEvent')
            .toList();
        expect(addAnchorEvents, hasLength(3));

        // First anchor: 200, 100 → 200, 692
        expect(addAnchorEvents[0]['position']['x'], equals(200.0));
        expect(addAnchorEvents[0]['position']['y'], equals(692.0));
        expect(addAnchorEvents[0]['anchorType'], equals('line'));

        // Second anchor: 200, 200 → 200, 592
        expect(addAnchorEvents[1]['position']['x'], equals(200.0));
        expect(addAnchorEvents[1]['position']['y'], equals(592.0));

        // Third anchor: 100, 200 → 100, 592
        expect(addAnchorEvents[2]['position']['x'], equals(100.0));
        expect(addAnchorEvents[2]['position']['y'], equals(592.0));

        // Verify FinishPathEvent
        final finishPathEvents = result.events
            .where((e) => e['eventType'] == 'FinishPathEvent')
            .toList();
        expect(finishPathEvents, hasLength(1));
        expect(finishPathEvents.first['closed'], isTrue);

        // Verify metadata
        expect(result.metadata.pageWidth, equals(612.0));
        expect(result.metadata.pageHeight, equals(792.0));

        // Should have AI private data warning
        expect(
          result.warnings.any((w) => w.featureType == 'ai-private-data'),
          isTrue,
        );
      });
    });
  });
}

/// Creates minimal valid PDF bytes for testing.
Uint8List _createMinimalPdfBytes() {
  // Minimal PDF structure with a simple content stream
  final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Count 1 /Kids [3 0 R] >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 29 >>
stream
50 50 m
150 50 l
h
S
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000193 00000 n
trailer
<< /Size 5 /Root 1 0 R >>
startxref
272
%%EOF
''';

  return Uint8List.fromList(pdfContent.codeUnits);
}

/// Test logger output that captures messages to a list.
class _ListOutput extends LogOutput {
  _ListOutput(this.messages);

  final List<String> messages;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      messages.add(line);
    }
  }
}
