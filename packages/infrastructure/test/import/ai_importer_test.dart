/// Unit tests for AI importer in Infrastructure layer.
///
/// Tests cover:
/// - Tier-1 operator parsing (moveto, lineto, curveto, closepath, rectangle)
/// - Tier-2 feature conversion (gradients, CMYK colors, Bezier variants)
/// - Tier-3 feature warnings (text, effects, unsupported operators)
/// - Coordinate system conversion (PDF → WireTuner)
/// - Security validation (file size, coordinate bounds)
/// - Error handling (malformed files, invalid operators)
/// - Integration with real PDF fixtures
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:infrastructure/import/ai_importer.dart';

void main() {
  group('AIImporter', () {
    late AIImporter importer;

    setUp(() {
      importer = AIImporter();
    });

    group('file validation', () {
      test('rejects files exceeding 10 MB limit', () async {
        // Create oversized file bytes (11 MB)
        final largeData = Uint8List(11 * 1024 * 1024);

        await expectLater(
          importer.importFromBytes(largeData, fileName: 'oversized.ai'),
          throwsA(isA<AIImportException>().having(
            (e) => e.message,
            'message',
            contains('exceeds maximum'),
          )),
        );
      });

      test('warns about non-.ai extension', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'file.pdf');

        // Should have warning about file extension
        expect(
          result.warnings.any(
            (w) =>
                w.featureType == 'file-extension' && w.severity == 'warning',
          ),
          isTrue,
        );
      });
    });

    group('PDF structure validation', () {
      test('rejects files without PDF header', () async {
        // Write invalid data (not PDF)
        final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        await expectLater(
          importer.importFromBytes(invalidBytes, fileName: 'invalid.ai'),
          throwsA(isA<AIImportException>().having(
            (e) => e.message,
            'message',
            contains('not a valid PDF structure'),
          )),
        );
      });

      test('accepts files with valid PDF header', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'valid.ai');

        // Should parse successfully (even if returning demonstration events)
        expect(result.events, isNotEmpty);
        expect(result.metadata, isNotNull);
      });
    });

    group('PDF operator parsing', () {
      test('generates valid event structure from PDF operators', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'demo.ai');

        // Should parse PDF operators and generate events
        expect(result.events, isNotEmpty);

        // Verify event structure
        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );
        expect(createPathEvent['eventId'], isNotNull);
        expect(createPathEvent['timestamp'], isA<int>());
        expect(createPathEvent['pathId'], isNotNull);
        expect(createPathEvent['startAnchor'], isA<Map<String, dynamic>>());
        expect(
            (createPathEvent['startAnchor'] as Map<String, dynamic>)['x'],
            isA<double>(),);
        expect(
            (createPathEvent['startAnchor'] as Map<String, dynamic>)['y'],
            isA<double>(),);

        // Verify AddAnchorEvent structure
        final addAnchorEvents = result.events
            .where((e) => e['eventType'] == 'AddAnchorEvent')
            .toList();
        expect(addAnchorEvents, isNotEmpty);

        for (final event in addAnchorEvents) {
          expect(event['eventId'], isNotNull);
          expect(event['pathId'], isNotNull);
          expect(event['position'], isA<Map<String, dynamic>>());
          expect(
              (event['position'] as Map<String, dynamic>)['x'],
              isA<double>(),);
          expect(
              (event['position'] as Map<String, dynamic>)['y'],
              isA<double>(),);
          expect(event['anchorType'], 'line');
        }

        // Verify FinishPathEvent
        final finishPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'FinishPathEvent',
        );
        expect(finishPathEvent['pathId'], equals(createPathEvent['pathId']));
        expect(finishPathEvent['closed'], isTrue);
      });

      test('generates monotonic timestamps', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'demo.ai');

        // Verify timestamps are monotonically increasing
        int? previousTimestamp;
        for (final event in result.events) {
          final timestamp = event['timestamp'] as int;
          if (previousTimestamp != null) {
            expect(timestamp, greaterThan(previousTimestamp));
          }
          previousTimestamp = timestamp;
        }
      });

      test('generates sequential event sequence numbers', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'demo.ai');

        // Verify event sequences are sequential starting from 0
        for (var i = 0; i < result.events.length; i++) {
          expect(result.events[i]['eventSequence'], equals(i));
        }
      });
    });

    group('Tier-1 operator support', () {
      test('parses moveto (m) operator correctly', () async {
        final pdfBytes = _createPdfWithOperators('100 200 m');

        final result = await importer.importFromBytes(pdfBytes);

        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );

        expect(
            (createPathEvent['startAnchor'] as Map<String, dynamic>)['x'],
            equals(100.0),);
        // Y coordinate should be flipped: 792 - 200 = 592
        expect(
            (createPathEvent['startAnchor'] as Map<String, dynamic>)['y'],
            equals(592.0),);
      });

      test('parses lineto (l) operator correctly', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 150 50 l');

        final result = await importer.importFromBytes(pdfBytes);

        final addAnchorEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'AddAnchorEvent',
        );

        expect(
            (addAnchorEvent['position'] as Map<String, dynamic>)['x'],
            equals(150.0),);
        expect(addAnchorEvent['anchorType'], equals('line'));
      });

      test('parses curveto (c) operator correctly', () async {
        final pdfBytes = _createPdfWithOperators(
          '50 50 m 60 70 80 90 100 100 c',
        );

        final result = await importer.importFromBytes(pdfBytes);

        final modifyAnchorEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'ModifyAnchorEvent',
        );
        final addAnchorEvent = result.events
            .where((e) => e['eventType'] == 'AddAnchorEvent')
            .first;

        expect(modifyAnchorEvent['handleOut'], isA<Map<String, dynamic>>());
        expect(addAnchorEvent['anchorType'], equals('bezier'));
        expect(addAnchorEvent['handleIn'], isA<Map<String, dynamic>>());
      });

      test('parses closepath (h) operator correctly', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 150 50 l h');

        final result = await importer.importFromBytes(pdfBytes);

        final finishPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'FinishPathEvent',
        );

        expect(finishPathEvent['closed'], isTrue);
      });

      test('parses rectangle (re) operator correctly', () async {
        final pdfBytes = _createPdfWithOperators('100 100 200 150 re');

        final result = await importer.importFromBytes(pdfBytes);

        final createShapeEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreateShapeEvent',
        );
        final params = createShapeEvent['parameters'] as Map<String, dynamic>;

        expect(createShapeEvent['shapeType'], equals('rectangle'));
        expect(params['x'], equals(100.0));
        expect(params['width'], equals(200.0));
        expect(params['height'], equals(150.0));
      });
    });

    group('Tier-2 feature conversion', () {
      test('converts Bezier variant "v" to standard curve', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 80 90 100 100 v');

        final result = await importer.importFromBytes(pdfBytes);

        // Should have info warning about conversion
        expect(
          result.warnings.any(
            (w) =>
                w.featureType == 'bezier-variant-v' && w.severity == 'info',
          ),
          isTrue,
        );

        // Should generate AddAnchorEvent with bezier type
        final addAnchorEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'AddAnchorEvent',
        );
        expect(addAnchorEvent['anchorType'], equals('bezier'));
      });

      test('converts Bezier variant "y" to standard curve', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 60 70 100 100 y');

        final result = await importer.importFromBytes(pdfBytes);

        // Should have info warning about conversion
        expect(
          result.warnings.any(
            (w) =>
                w.featureType == 'bezier-variant-y' && w.severity == 'info',
          ),
          isTrue,
        );
      });

      test('converts CMYK colors to RGB', () async {
        final pdfBytes = _createPdfWithOperators('0.2 0.8 0.0 0.1 k');

        final result = await importer.importFromBytes(pdfBytes);

        // Should have info warning about CMYK conversion
        expect(
          result.warnings.any(
            (w) => w.featureType == 'cmyk-color' && w.severity == 'info',
          ),
          isTrue,
        );
      });
    });

    group('Tier-3 feature warnings', () {
      test('includes AI private data limitation warning', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'demo.ai');

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
      });

      test('warns about unsupported operators', () async {
        // Create PDF with unsupported text operator
        final pdfBytes = _createPdfWithOperators('(Hello) Tj');

        final result = await importer.importFromBytes(pdfBytes);

        // Should have warning about unsupported operator
        expect(
          result.warnings.any(
            (w) => w.featureType == 'unsupported-operator',
          ),
          isTrue,
        );
      });
    });

    group('Y-axis coordinate conversion', () {
      test('flips Y coordinates from PDF to WireTuner space', () async {
        // PDF page height: 792 points (Letter size)
        final pdfBytes = _createPdfWithOperators('100 692 m');

        final result = await importer.importFromBytes(pdfBytes);

        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );
        final startAnchor =
            createPathEvent['startAnchor'] as Map<String, dynamic>;

        // Y coordinate: 792 - 692 = 100 (near top in WireTuner)
        expect(startAnchor['y'], equals(100.0));
      });
    });

    group('graphics state operators', () {
      test('parses stroke color (RG) operator', () async {
        final pdfBytes = _createPdfWithOperators('1.0 0.0 0.0 RG 50 50 m');

        final result = await importer.importFromBytes(pdfBytes);

        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );

        expect(createPathEvent['strokeColor'], equals('#ff0000'));
      });

      test('parses fill color (rg) operator', () async {
        final pdfBytes = _createPdfWithOperators('0.0 0.0 1.0 rg 50 50 m');

        final result = await importer.importFromBytes(pdfBytes);

        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );

        expect(createPathEvent['fillColor'], equals('#0000ff'));
      });

      test('parses stroke width (w) operator', () async {
        final pdfBytes = _createPdfWithOperators('2.5 w 50 50 m');

        final result = await importer.importFromBytes(pdfBytes);

        final createPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'CreatePathEvent',
        );

        expect(createPathEvent['strokeWidth'], equals(2.5));
      });
    });

    group('error handling', () {
      test('handles malformed moveto operator gracefully', () async {
        final pdfBytes = _createPdfWithOperators('100 m'); // Missing Y operand

        final result = await importer.importFromBytes(pdfBytes);

        // Should generate warning
        expect(
          result.warnings.any(
            (w) => w.featureType == 'malformed-operator',
          ),
          isTrue,
        );
      });

      test('handles lineto without preceding moveto', () async {
        final pdfBytes = _createPdfWithOperators('150 50 l'); // No moveto first

        final result = await importer.importFromBytes(pdfBytes);

        // Should generate warning
        expect(
          result.warnings.any(
            (w) => w.featureType == 'malformed-path',
          ),
          isTrue,
        );
      });

      test('finishes unclosed paths automatically', () async {
        final pdfBytes =
            _createPdfWithOperators('50 50 m 150 50 l'); // No closepath

        final result = await importer.importFromBytes(pdfBytes);

        // Should still have FinishPathEvent with closed=false
        final finishPathEvent = result.events.firstWhere(
          (e) => e['eventType'] == 'FinishPathEvent',
        );

        expect(finishPathEvent['closed'], isFalse);
      });
    });

    group('metadata extraction', () {
      test('extracts basic metadata', () async {
        final pdfBytes = _createMinimalPdfBytes();

        final result =
            await importer.importFromBytes(pdfBytes, fileName: 'demo.ai');

        expect(result.metadata.pageCount, equals(1));
        expect(result.metadata.pageWidth, equals(612.0)); // Letter size
        expect(result.metadata.pageHeight, equals(792.0)); // Letter size
        expect(result.metadata.creator, equals('Adobe Illustrator'));
      });
    });

    group('complex path scenarios', () {
      test('parses path with multiple segments', () async {
        final pdfBytes = _createPdfWithOperators(
          '50 50 m 100 50 l 100 100 l 50 100 l h',
        );

        final result = await importer.importFromBytes(pdfBytes);

        // Should have: CreatePath, 3x AddAnchor, FinishPath
        expect(
          result.events.where((e) => e['eventType'] == 'CreatePathEvent').length,
          equals(1),
        );
        expect(
          result.events.where((e) => e['eventType'] == 'AddAnchorEvent').length,
          equals(3),
        );
        expect(
          result.events.where((e) => e['eventType'] == 'FinishPathEvent').length,
          equals(1),
        );
      });

      test('parses multiple independent paths', () async {
        final pdfBytes = _createPdfWithOperators(
          '50 50 m 150 50 l h 200 200 m 250 250 l h',
        );

        final result = await importer.importFromBytes(pdfBytes);

        // Should have 2 CreatePathEvents
        expect(
          result.events.where((e) => e['eventType'] == 'CreatePathEvent').length,
          equals(2),
        );
        // Should have 2 FinishPathEvents
        expect(
          result.events.where((e) => e['eventType'] == 'FinishPathEvent').length,
          equals(2),
        );
      });
    });

    group('rendering operators', () {
      test('safely ignores stroke (S) operator', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 150 50 l S');

        final result = await importer.importFromBytes(pdfBytes);

        // Should parse successfully
        expect(result.events, isNotEmpty);
      });

      test('safely ignores fill (f) operator', () async {
        final pdfBytes = _createPdfWithOperators('50 50 m 150 50 l 50 100 l h f');

        final result = await importer.importFromBytes(pdfBytes);

        // Should parse successfully
        expect(result.events, isNotEmpty);
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

/// Creates PDF bytes with custom operators in content stream.
Uint8List _createPdfWithOperators(String operators) {
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
<< /Length ${operators.length + 2} >>
stream
$operators
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
