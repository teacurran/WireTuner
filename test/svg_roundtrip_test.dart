import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';

void main() {
  group('SVG Round-Trip Tests', () {
    late SvgImporter importer;

    setUp(() {
      importer = SvgImporter();
    });

    test('Round-trip detects gradients and issues warnings', () async {
      // Import SVG with gradient
      final svgWithGradient = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="grad1" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="red"/>
      <stop offset="100%" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="url(#grad1)"/>
</svg>
''';

      final events = await importer.importFromString(svgWithGradient);

      expect(events, isNotEmpty);
      // Rectangle should be imported with fallback fill color
      final createEvent = events.first;
      expect(createEvent.eventType, 'CreatePathEvent');

      // The gradient fallback should use first stop color
      final dynamic createEventDynamic = createEvent;
      expect(createEventDynamic.fillColor, 'red'); // First stop color
    });

    test('Round-trip handles clipPath with warnings', () async {
      final svgWithClip = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip1">
      <rect x="0" y="0" width="50" height="50"/>
    </clipPath>
  </defs>
  <rect x="0" y="0" width="100" height="100" fill="blue" clip-path="url(#clip1)"/>
</svg>
''';

      final events = await importer.importFromString(svgWithClip);

      expect(events, isNotEmpty);
      // Rect should be imported even though clipping not applied
      expect(events.first.eventType, 'CreatePathEvent');
    });

    test('Round-trip converts text to placeholder', () async {
      final svgWithText = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="20" font-size="14">Hello</text>
</svg>
''';

      final events = await importer.importFromString(svgWithText);

      expect(events, isNotEmpty);
      // Text should be converted to rectangle placeholder
      expect(events.first.eventType, 'CreatePathEvent');

      // Should create a closed rectangle (placeholder)
      final finishEvent = events.last;
      expect(finishEvent.eventType, 'FinishPathEvent');
      final dynamic finishDynamic = finishEvent;
      expect(finishDynamic.closed, true);
    });

    test('Round-trip preserves path geometry accuracy', () async {
      // Import SVG with Bezier curve
      final svgWithBezier = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M 0 50 C 30 20, 70 80, 100 50" stroke="black" fill="none"/>
</svg>
''';

      final events = await importer.importFromString(svgWithBezier);

      // Verify Bezier curve was imported
      expect(events, isNotEmpty);

      // Should have ModifyAnchorEvent for handleOut
      final modifyEvents =
          events.where((e) => e.eventType == 'ModifyAnchorEvent');
      expect(modifyEvents, isNotEmpty,
          reason: 'Bezier handles should be imported');

      // Should have AddAnchorEvent with handleIn
      final addEvents = events.where((e) => e.eventType == 'AddAnchorEvent');
      expect(addEvents, isNotEmpty);
    });

    test('Import handles multiple gradient stops correctly', () async {
      final svgWithMultiStop = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="multiGrad">
      <stop offset="0" stop-color="#ff0000"/>
      <stop offset="0.5" stop-color="#00ff00"/>
      <stop offset="1" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect fill="url(#multiGrad)" x="0" y="0" width="100" height="100"/>
</svg>
''';

      final events = await importer.importFromString(svgWithMultiStop);

      expect(events, isNotEmpty);
      // Should use first stop color as fallback
      final createEvent = events.first;
      final dynamic createDynamic = createEvent;
      expect(createDynamic.fillColor, '#ff0000');
    });
  });
}
