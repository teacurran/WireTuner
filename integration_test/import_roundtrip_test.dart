import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/domain/models/path.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';
import 'package:wiretuner/infrastructure/import_export/ai_importer.dart';
import 'package:wiretuner/infrastructure/import_export/import_validator.dart';
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Import Round-Trip Integration Tests', () {
    late SvgImporter svgImporter;
    late AiImporter aiImporter;
    late SvgExporter svgExporter;

    setUp(() {
      svgImporter = SvgImporter();
      aiImporter = AiImporter();
      svgExporter = SvgExporter();
    });

    group('SVG Import - Basic Path', () {
      testWidgets('Import simple path with line segments', (tester) async {
        // Arrange
        final svgContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 200 200" width="200" height="200">
  <path d="M 10 10 L 100 10 L 100 100 L 10 100 Z" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty, reason: 'Should generate events from path');

        // Verify event sequence
        expect(events[0].eventType, 'CreatePathEvent',
            reason: 'First event should be CreatePathEvent');
        expect(
            events.where((e) => e.eventType == 'AddAnchorEvent').length, 3,
            reason: 'Should have 3 AddAnchorEvent (L commands)');
        expect(events.last.eventType, 'FinishPathEvent',
            reason: 'Last event should be FinishPathEvent');
      });

      testWidgets('Import path with cubic Bezier curves', (tester) async {
        // Arrange
        final svgContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 200 200" width="200" height="200">
  <path d="M 10 100 C 40 10, 160 10, 190 100" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Should have CreatePath, ModifyAnchor (for handleOut), AddAnchor (with handleIn), Finish
        expect(events[0].eventType, 'CreatePathEvent');

        // Check for Bezier-related events
        final modifyEvents =
            events.where((e) => e.eventType == 'ModifyAnchorEvent');
        final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');

        expect(modifyEvents, isNotEmpty,
            reason: 'Should have ModifyAnchorEvent for handleOut');
        expect(addEvents, isNotEmpty,
            reason: 'Should have AddAnchorEvent for Bezier end anchor');
      });

      testWidgets('Import relative path commands', (tester) async {
        // Arrange - lowercase commands are relative
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 l 50 0 l 0 50 l -50 0 z" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);
        expect(events[0].eventType, 'CreatePathEvent');

        // Should have 3 AddAnchorEvent for the 3 relative 'l' commands
        final addEvents =
            events.where((e) => e.eventType == 'AddAnchorEvent');
        expect(addEvents.length, 3);
      });
    });

    group('SVG Import - Shape Elements', () {
      testWidgets('Import rectangle element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="80" height="50" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Rectangle converted to path with 4 corners
        expect(events[0].eventType, 'CreatePathEvent');
        expect(
            events.where((e) => e.eventType == 'AddAnchorEvent').length, 3,
            reason: 'Rectangle should have 3 additional corners (4 total)');

        final finishEvent = events.last;
        expect(finishEvent.eventType, 'FinishPathEvent');
        // Rectangle should be closed
        expect((finishEvent as dynamic).closed, true);
      });

      testWidgets('Import circle element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <circle cx="100" cy="100" r="50" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Circle converted to ellipse path with 4 Bezier curves
        expect(events[0].eventType, 'CreatePathEvent');

        // Should have ModifyAnchor and AddAnchor events for Bezier curves
        final modifyEvents =
            events.where((e) => e.eventType == 'ModifyAnchorEvent');
        final addEvents =
            events.where((e) => e.eventType == 'AddAnchorEvent');

        expect(modifyEvents.length, greaterThan(0),
            reason: 'Circle uses Bezier curves, needs ModifyAnchorEvent');
        expect(addEvents.length, greaterThan(0),
            reason: 'Circle has multiple anchor points');
      });

      testWidgets('Import ellipse element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="100" cy="100" rx="60" ry="40" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);
        expect(events[0].eventType, 'CreatePathEvent');

        // Ellipse should be closed
        final finishEvent = events.last;
        expect(finishEvent.eventType, 'FinishPathEvent');
        expect((finishEvent as dynamic).closed, true);
      });

      testWidgets('Import line element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <line x1="10" y1="20" x2="100" y2="80" stroke="black"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Line is simple two-point path
        expect(events[0].eventType, 'CreatePathEvent');
        expect(events[1].eventType, 'AddAnchorEvent');
        expect(events[2].eventType, 'FinishPathEvent');

        // Line should not be closed
        expect((events[2] as dynamic).closed, false);
      });

      testWidgets('Import polygon element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <polygon points="10,10 50,10 50,50 10,50" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Polygon should be closed
        final finishEvent = events.last;
        expect(finishEvent.eventType, 'FinishPathEvent');
        expect((finishEvent as dynamic).closed, true);
      });

      testWidgets('Import polyline element', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <polyline points="10,10 50,10 50,50" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Polyline should NOT be closed
        final finishEvent = events.last;
        expect(finishEvent.eventType, 'FinishPathEvent');
        expect((finishEvent as dynamic).closed, false);
      });
    });

    group('SVG Import - Groups and Multiple Elements', () {
      testWidgets('Import multiple paths', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 10 L 50 10" stroke="black" fill="none"/>
  <path d="M 100 100 L 150 150" stroke="black" fill="none"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Should have 2 CreatePathEvent (one for each path)
        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent');
        expect(createEvents.length, 2);
      });

      testWidgets('Import group element with nested paths', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g id="layer-1">
    <path d="M 10 10 L 50 10" stroke="black" fill="none"/>
    <circle cx="100" cy="100" r="20" stroke="black" fill="none"/>
  </g>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty);

        // Group is flattened, but both elements should be imported
        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent');
        expect(createEvents.length, 2,
            reason: 'Group should be flattened, all paths imported');
      });
    });

    group('SVG Import - Security Constraints', () {
      testWidgets('Reject file exceeding max size', (tester) async {
        // Arrange - Create large SVG file
        final tempDir = Directory.systemTemp;
        final largeSvgPath =
            '${tempDir.path}/large_test_${DateTime.now().millisecondsSinceEpoch}.svg';

        // Create 15 MB file (exceeds 10 MB limit)
        final largeContent = '<svg>${'x' * 15 * 1024 * 1024}</svg>';
        await File(largeSvgPath).writeAsString(largeContent);

        try {
          // Act & Assert
          expect(
            () => svgImporter.importFromFile(largeSvgPath),
            throwsA(isA<ImportException>()),
          );
        } finally {
          // Cleanup
          if (await File(largeSvgPath).exists()) {
            await File(largeSvgPath).delete();
          }
        }
      });

      testWidgets('Handle malformed XML gracefully', (tester) async {
        // Arrange - Invalid XML
        final badSvg = '<svg><path d="M 0 0 L 100 100</svg>'; // Missing closing tag

        // Act & Assert
        expect(
          () => svgImporter.importFromString(badSvg),
          throwsA(isA<ImportException>()),
        );
      });

      testWidgets('Validate path data length', (tester) async {
        // Arrange - Path data exceeding limit
        final hugePath = '<svg><path d="${'M 0 0 L 1 1 ' * 20000}"/></svg>';

        // Act & Assert
        expect(
          () => svgImporter.importFromString(hugePath),
          throwsA(isA<ImportException>()),
        );
      });

      testWidgets('Skip zero-dimension shapes gracefully', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="0" height="50" stroke="black"/>
  <circle cx="100" cy="100" r="0" stroke="black"/>
</svg>
''';

        // Act
        final events = await svgImporter.importFromString(svgContent);

        // Assert - Should skip invalid shapes, not crash
        // May have no events or only events from valid shapes
        // Just ensure it doesn't throw
        expect(events, isA<List<EventBase>>());
      });
    });

    group('SVG Import - Unsupported Features', () {
      testWidgets('Log warning for gradient but do not crash', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1">
      <stop offset="0%" stop-color="red"/>
      <stop offset="100%" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="80" height="50" fill="url(#grad1)"/>
</svg>
''';

        // Act - Should not throw
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        // Gradient definition is skipped, but rect should be imported
        expect(events, isNotEmpty,
            reason: 'Should import rect even though gradient not supported');
      });

      testWidgets('Log warning for text but do not crash', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="20">Hello World</text>
  <path d="M 10 10 L 50 50" stroke="black"/>
</svg>
''';

        // Act - Should not throw
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        // Text is converted to placeholder rectangle, and path is imported
        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent');
        expect(createEvents.length, 2,
            reason: 'Both text placeholder and path should be imported');
      });

      testWidgets('Log warning for filter but do not crash', (tester) async {
        // Arrange
        final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="blur1">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <circle cx="50" cy="50" r="30" filter="url(#blur1)"/>
</svg>
''';

        // Act - Should not throw
        final events = await svgImporter.importFromString(svgContent);

        // Assert
        expect(events, isNotEmpty,
            reason: 'Should import circle even though filter not supported');
      });
    });

    group('AI Import - Basic Functionality', () {
      testWidgets('Import AI file returns events (placeholder)', (tester) async {
        // Note: AI import is placeholder in Milestone 0.1
        // This test verifies the service doesn't crash

        // Arrange - Create minimal .ai file
        final tempDir = Directory.systemTemp;
        final aiPath =
            '${tempDir.path}/test_${DateTime.now().millisecondsSinceEpoch}.ai';

        // Create a minimal file (actual PDF structure not required for placeholder)
        await File(aiPath).writeAsString('%PDF-1.4\n%%EOF');

        try {
          // Act
          final events = await aiImporter.importFromFile(aiPath);

          // Assert
          // Placeholder returns demonstration events
          expect(events, isA<List<EventBase>>());

          // Verify it's generating valid event structure
          if (events.isNotEmpty) {
            expect(events[0], isA<EventBase>());
            expect(events[0].eventId, isNotEmpty);
            expect(events[0].timestamp, greaterThan(0));
          }
        } finally {
          // Cleanup
          if (await File(aiPath).exists()) {
            await File(aiPath).delete();
          }
        }
      });

      testWidgets('Reject oversized AI file', (tester) async {
        // Arrange - Create large .ai file
        final tempDir = Directory.systemTemp;
        final largeAiPath =
            '${tempDir.path}/large_${DateTime.now().millisecondsSinceEpoch}.ai';

        // Create 15 MB file (exceeds 10 MB limit)
        final largeContent = '%PDF-1.4\n${'x' * 15 * 1024 * 1024}\n%%EOF';
        await File(largeAiPath).writeAsString(largeContent);

        try {
          // Act & Assert
          expect(
            () => aiImporter.importFromFile(largeAiPath),
            throwsA(isA<ImportException>()),
          );
        } finally {
          // Cleanup
          if (await File(largeAiPath).exists()) {
            await File(largeAiPath).delete();
          }
        }
      });
    });

    group('Golden File Round-Trip Tests', () {
      // Note: These tests require event replay infrastructure
      // For Milestone 0.1, we test event generation correctness
      // Future milestone will add full round-trip with document reconstruction

      testWidgets('Simple path golden fixture generates correct events',
          (tester) async {
        // Arrange
        final fixtureDir = '${Directory.current.path}/test/fixtures/golden';
        final simplePath = '$fixtureDir/simple_path.svg';

        // Skip if fixture doesn't exist (CI environment)
        if (!await File(simplePath).exists()) {
          print('Skipping golden test - fixture not found: $simplePath');
          return;
        }

        // Act
        final events = await svgImporter.importFromFile(simplePath);

        // Assert
        expect(events, isNotEmpty);

        // Verify event structure
        expect(events[0].eventType, 'CreatePathEvent');
        expect(events.last.eventType, 'FinishPathEvent');

        // Verify closed path
        expect((events.last as dynamic).closed, true);
      });

      testWidgets('Bezier path golden fixture generates correct events',
          (tester) async {
        // Arrange
        final fixtureDir = '${Directory.current.path}/test/fixtures/golden';
        final bezierPath = '$fixtureDir/bezier_path.svg';

        // Skip if fixture doesn't exist
        if (!await File(bezierPath).exists()) {
          print('Skipping golden test - fixture not found: $bezierPath');
          return;
        }

        // Act
        final events = await svgImporter.importFromFile(bezierPath);

        // Assert
        expect(events, isNotEmpty);

        // Should have ModifyAnchorEvent for Bezier handles
        final modifyEvents =
            events.where((e) => e.eventType == 'ModifyAnchorEvent');
        expect(modifyEvents, isNotEmpty,
            reason: 'Bezier curve should have handle modifications');
      });

      testWidgets('Shapes golden fixture generates correct events',
          (tester) async {
        // Arrange
        final fixtureDir = '${Directory.current.path}/test/fixtures/golden';
        final shapesFile = '$fixtureDir/shapes.svg';

        // Skip if fixture doesn't exist
        if (!await File(shapesFile).exists()) {
          print('Skipping golden test - fixture not found: $shapesFile');
          return;
        }

        // Act
        final events = await svgImporter.importFromFile(shapesFile);

        // Assert
        expect(events, isNotEmpty);

        // Should have 3 CreatePathEvent (rect, circle, ellipse)
        final createEvents =
            events.where((e) => e.eventType == 'CreatePathEvent');
        expect(createEvents.length, 3,
            reason: 'shapes.svg has 3 elements: rect, circle, ellipse');
      });
    });
  });
}
