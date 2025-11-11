import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/import_export/import_validator.dart';
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';

/// Integration tests for SVG importer using sample SVG files.
///
/// These tests verify that the SVG importer correctly parses real SVG files
/// and generates appropriate event sequences for path reconstruction.
///
/// Related: I9.T7 (SVG Import), T039 (SVG Import Ticket)
void main() {
  group('SVG Importer Integration Tests', () {
    late SvgImporter importer;
    late String fixturesPath;

    setUp(() {
      importer = SvgImporter();
      // Get path to fixtures directory
      final testDir = Directory.current.path;
      fixturesPath = p.join(testDir, 'test', 'fixtures');
    });

    group('Complex Path Parsing', () {
      test('Imports SVG with complex Bezier paths', () async {
        final filePath = p.join(fixturesPath, 'sample_complex_paths.svg');

        // Verify file exists
        expect(File(filePath).existsSync(), true,
            reason: 'Sample file should exist');

        // Import the file
        final events = await importer.importFromFile(filePath);

        // Verify events were generated
        expect(events, isNotEmpty,
            reason: 'Should generate events for complex paths');

        // Verify we have CreatePath events
        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent').toList();
        expect(createEvents.length, greaterThanOrEqualTo(4),
            reason: 'Should have one CreatePath per path element');

        // Verify Bezier curves were parsed (should have ModifyAnchor events)
        final modifyEvents =
            events.where((e) => e.eventType == 'ModifyAnchorEvent').toList();
        expect(modifyEvents, isNotEmpty,
            reason: 'Bezier paths should generate ModifyAnchor events');

        // Verify paths are finished
        final finishEvents =
            events.where((e) => e.eventType == 'FinishPathEvent').toList();
        expect(finishEvents.length, equals(createEvents.length),
            reason: 'Each path should have a FinishPath event');
      });

      test('Converts cubic Bezier (C command) to Path segments', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 80 C 40 10, 65 10, 95 80" stroke="black" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Should have CreatePath, ModifyAnchor (for handleOut), AddAnchor (with handleIn), FinishPath
        expect(events.length, greaterThanOrEqualTo(4),
            reason: 'Bezier curve should generate multiple events');

        // Verify ModifyAnchor event sets handleOut
        final modifyEvent = events.firstWhere(
          (e) => e.eventType == 'ModifyAnchorEvent',
        ) as ModifyAnchorEvent;
        expect(modifyEvent.handleOut, isNotNull,
            reason: 'Cubic Bezier should set handleOut');

        // Verify AddAnchor event has handleIn
        final addEvent = events.firstWhere(
          (e) => e.eventType == 'AddAnchorEvent',
        ) as AddAnchorEvent;
        expect(addEvent.handleIn, isNotNull,
            reason: 'Cubic Bezier should set handleIn');
        expect(addEvent.anchorType, equals(AnchorType.bezier),
            reason: 'Anchor type should be bezier');
      });

      test('Handles smooth cubic Bezier (S command)', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 80 C 40 10, 65 10, 95 80 S 150 150, 180 80" stroke="black" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Should have multiple Bezier segments
        final modifyEvents =
            events.where((e) => e.eventType == 'ModifyAnchorEvent');
        expect(modifyEvents.length, greaterThanOrEqualTo(2),
            reason: 'S command should generate additional Bezier segment');
      });

      test('Converts quadratic Bezier (Q command) to cubic', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 80 Q 52.5 10, 95 80" stroke="black" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Quadratic should be converted to cubic Bezier
        final addEvent = events.firstWhere(
          (e) => e.eventType == 'AddAnchorEvent',
        ) as AddAnchorEvent;
        expect(addEvent.anchorType, equals(AnchorType.bezier),
            reason: 'Quadratic should be converted to cubic Bezier');
        expect(addEvent.handleIn, isNotNull);
      });

      test('Handles smooth quadratic Bezier (T command)', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 80 Q 52.5 10, 95 80 T 180 80" stroke="black" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Should handle reflected control point
        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, greaterThanOrEqualTo(2),
            reason: 'T command should add additional anchor');
      });

      test('Handles Z (close path) command', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 L 50 10 L 30 40 Z" stroke="black" fill="red"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, true,
            reason: 'Z command should close the path');
      });
    });

    group('Shape Element Conversion', () {
      test('Imports SVG with basic shapes', () async {
        final filePath = p.join(fixturesPath, 'sample_shapes.svg');

        final events = await importer.importFromFile(filePath);

        // Should have events for: rect, circle, ellipse, line, polyline, polygon
        expect(events, isNotEmpty);

        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent').toList();
        expect(createEvents.length, equals(6),
            reason: 'Should convert all 6 shapes to paths');

        // Verify all paths are finished
        final finishEvents =
            events.where((e) => e.eventType == 'FinishPathEvent').toList();
        expect(finishEvents.length, equals(6),
            reason: 'All shapes should be finished');
      });

      test('Converts rectangle to closed path', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="20" width="100" height="50" fill="blue"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Should create path with 4 corners
        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, equals(3),
            reason: 'Rectangle should have 3 additional corners (4 total with start)');

        // Should be closed
        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, true,
            reason: 'Rectangle should be closed path');
      });

      test('Converts ellipse to Bezier approximation', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="100" cy="100" rx="50" ry="30" fill="yellow"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Ellipse should be approximated with 4 Bezier curves
        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, equals(3),
            reason: 'Ellipse should have 3 additional anchors (4 total)');

        // All anchors should be Bezier type
        for (final event in addEvents) {
          final addEvent = event as AddAnchorEvent;
          expect(addEvent.anchorType, equals(AnchorType.bezier),
              reason: 'Ellipse anchors should be Bezier type');
        }

        // Should be closed
        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, true,
            reason: 'Ellipse should be closed path');
      });

      test('Converts circle to Bezier approximation', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="25" fill="red"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Circle is ellipse with equal radii
        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, equals(3),
            reason: 'Circle should have 3 additional anchors (4 total)');

        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, true);
      });

      test('Converts line to simple path', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <line x1="0" y1="0" x2="100" y2="100" stroke="black"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        expect(events.length, equals(3),
            reason: 'Line should generate CreatePath, AddAnchor, FinishPath');

        final addEvent = events[1] as AddAnchorEvent;
        expect(addEvent.anchorType, equals(AnchorType.line));

        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, false,
            reason: 'Line should not be closed');
      });

      test('Converts polyline to line segments', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <polyline points="10,10 20,20 30,15 40,25" stroke="green" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, equals(3),
            reason: 'Polyline with 4 points should have 3 AddAnchor events');

        for (final event in addEvents) {
          final addEvent = event as AddAnchorEvent;
          expect(addEvent.anchorType, equals(AnchorType.line));
        }

        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, false,
            reason: 'Polyline should not be closed');
      });

      test('Converts polygon to closed line segments', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <polygon points="50,10 90,90 10,90" fill="blue"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, equals(2),
            reason: 'Polygon with 3 points should have 2 AddAnchor events');

        final finishEvent = events.last as FinishPathEvent;
        expect(finishEvent.closed, true,
            reason: 'Polygon should be closed');
      });
    });

    group('Advanced Features (Tier-2)', () {
      test('Imports SVG with gradients and applies fallback', () async {
        final filePath = p.join(fixturesPath, 'sample_with_gradients.svg');

        final events = await importer.importFromFile(filePath);

        expect(events, isNotEmpty,
            reason: 'Should import shapes with gradient references');

        // Find CreatePath event with fill from gradient fallback
        final createEvents = events
            .where((e) => e.eventType == 'CreatePathEvent')
            .cast<CreatePathEvent>();

        bool foundGradientFallback = false;
        for (final event in createEvents) {
          if (event.fillColor != null && event.fillColor != 'none') {
            foundGradientFallback = true;
            break;
          }
        }

        expect(foundGradientFallback, true,
            reason: 'Should apply gradient fallback color');
      });

      test('Handles clipPath with warning', () async {
        final filePath = p.join(fixturesPath, 'sample_with_gradients.svg');

        // Should not throw despite clipPath reference
        final events = await importer.importFromFile(filePath);

        expect(events, isNotEmpty,
            reason: 'Should import shapes with clipPath references');
      });

      test('Parses linear gradient definition', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="red"/>
      <stop offset="100%" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="100" height="100" fill="url(#grad1)"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final createEvent = events.first as CreatePathEvent;
        expect(createEvent.fillColor, equals('red'),
            reason: 'Should use first stop color as fallback');
      });

      test('Parses radial gradient definition', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="grad2" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="white"/>
      <stop offset="1" stop-color="black"/>
    </radialGradient>
  </defs>
  <circle cx="50" cy="50" r="40" fill="url(#grad2)"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final createEvent = events.first as CreatePathEvent;
        expect(createEvent.fillColor, equals('white'),
            reason: 'Should use first stop color as fallback');
      });
    });

    group('Style Attribute Parsing', () {
      test('Parses stroke and fill colors', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 L 50 50" stroke="red" fill="blue"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final createEvent = events.first as CreatePathEvent;
        expect(createEvent.strokeColor, equals('red'));
        expect(createEvent.fillColor, equals('blue'));
      });

      test('Parses stroke width', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 L 50 50" stroke="black" stroke-width="3.5"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final createEvent = events.first as CreatePathEvent;
        expect(createEvent.strokeWidth, equals(3.5));
      });

      test('Parses opacity', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="50" height="50" fill="red" opacity="0.7"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        final createEvent = events.first as CreatePathEvent;
        expect(createEvent.opacity, equals(0.7));
      });
    });

    group('Error Handling and Validation', () {
      test('Throws ImportException for non-existent file', () async {
        final invalidPath = p.join(fixturesPath, 'nonexistent.svg');

        expect(
          () => importer.importFromFile(invalidPath),
          throwsA(isA<ImportException>()),
          reason: 'Should throw for non-existent file',
        );
      });

      test('Throws ImportException for malformed XML', () async {
        final malformedSvg = '<svg><path d="M 10 10 L 50';

        expect(
          () => importer.importFromString(malformedSvg),
          throwsA(isA<ImportException>()),
          reason: 'Should throw for malformed XML',
        );
      });

      test('Throws ImportException for missing SVG root element', () async {
        final noSvgRoot = '<xml><path d="M 10 10 L 50 50"/></xml>';

        expect(
          () => importer.importFromString(noSvgRoot),
          throwsA(isA<ImportException>()),
          reason: 'Should throw when no <svg> root element',
        );
      });

      test('Handles empty path data gracefully', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d=""/>
</svg>
''';

        // Should not throw, just return empty events
        final events = await importer.importFromString(svgContent);
        expect(events, isEmpty,
            reason: 'Empty path data should be skipped');
      });

      test('Validates coordinate values', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="blue"/>
</svg>
''';

        // Should not throw for valid coordinates
        final events = await importer.importFromString(svgContent);
        expect(events, isNotEmpty);
      });
    });

    group('Imported Object Rendering Verification', () {
      test('Verifies imported structure has correct event sequence', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 L 50 10 L 30 40 Z" stroke="black" fill="red"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Verify event sequence
        expect(events[0].eventType, equals('CreatePathEvent'));
        expect(events[1].eventType, equals('AddAnchorEvent'));
        expect(events[2].eventType, equals('AddAnchorEvent'));
        expect(events[3].eventType, equals('FinishPathEvent'));

        // Verify path ID consistency
        final createEvent = events[0] as CreatePathEvent;
        final addEvent1 = events[1] as AddAnchorEvent;
        final addEvent2 = events[2] as AddAnchorEvent;
        final finishEvent = events[3] as FinishPathEvent;

        expect(addEvent1.pathId, equals(createEvent.pathId),
            reason: 'All events should share same pathId');
        expect(addEvent2.pathId, equals(createEvent.pathId),
            reason: 'All events should share same pathId');
        expect(finishEvent.pathId, equals(createEvent.pathId),
            reason: 'All events should share same pathId');

        // Verify timestamps are monotonically increasing
        expect(events[1].timestamp, greaterThan(events[0].timestamp));
        expect(events[2].timestamp, greaterThan(events[1].timestamp));
        expect(events[3].timestamp, greaterThan(events[2].timestamp));
      });

      test('Verifies complex path maintains geometry', () async {
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 50 150 C 50 80, 150 80, 150 150" stroke="black" fill="none"/>
</svg>
''';

        final events = await importer.importFromString(svgContent);

        // Should have CreatePath, ModifyAnchor, AddAnchor, FinishPath
        expect(events.length, equals(4),
            reason: 'Cubic Bezier path should have 4 events');

        final createEvent = events[0] as CreatePathEvent;
        expect(createEvent.startAnchor.x, equals(50));
        expect(createEvent.startAnchor.y, equals(150));

        final addEvent = events[2] as AddAnchorEvent;
        expect(addEvent.position.x, equals(150));
        expect(addEvent.position.y, equals(150));
      });
    });
  });
}
