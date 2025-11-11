import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/import_export/svg_importer.dart';

void main() {
  group('SVG Importer - Gradient Support', () {
    late SvgImporter importer;

    setUp(() {
      importer = SvgImporter();
    });

    test('Parse linear gradient with percentage offsets', () async {
      final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="red"/>
      <stop offset="50%" stop-color="yellow"/>
      <stop offset="100%" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="80" height="50" fill="url(#grad1)"/>
</svg>
''';

      // Should not throw
      final events = await importer.importFromString(svgContent);

      expect(events, isNotEmpty,
          reason: 'Should import rect with gradient fallback');
      expect(events.first.eventType, 'CreatePathEvent');
    });

    test('Parse radial gradient', () async {
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

      // Should not throw
      final events = await importer.importFromString(svgContent);

      expect(events, isNotEmpty,
          reason: 'Should import circle with gradient fallback');
    });

    test('Handle clipPath reference with warning', () async {
      final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip1">
      <rect x="0" y="0" width="100" height="100"/>
    </clipPath>
  </defs>
  <rect x="10" y="10" width="200" height="200" clip-path="url(#clip1)"/>
</svg>
''';

      // Should not throw, but log warning
      final events = await importer.importFromString(svgContent);

      expect(events, isNotEmpty,
          reason: 'Should import rect with clipPath warning');
    });

    test('Convert text to placeholder path', () async {
      final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="20">Hello World</text>
</svg>
''';

      // Should not throw, convert to placeholder
      final events = await importer.importFromString(svgContent);

      expect(events, isNotEmpty,
          reason: 'Should create placeholder path for text');
      expect(events.first.eventType, 'CreatePathEvent');
    });

    test('Gradient with invalid ID reference logs warning', () async {
      final svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="80" height="50" fill="url(#nonexistent)"/>
</svg>
''';

      // Should not throw, just log warning
      final events = await importer.importFromString(svgContent);

      expect(events, isNotEmpty,
          reason: 'Should import rect despite invalid gradient ref');
    });
  });
}
