# T039: SVG Import

## Status
- **Phase**: 9 - Import/Export
- **Priority**: High
- **Estimated Effort**: 2 days
- **Dependencies**: T038

## Overview
Import SVG files into WireTuner documents.

## Objectives
- Parse SVG XML
- Convert SVG paths to VectorPath objects
- Convert SVG shapes (rect, circle, etc.) to Shape objects
- Handle transforms, styles, groups
- Create ImportEvent

## Implementation
```dart
import 'package:xml/xml.dart';

class SVGImporter {
  Future<Document> importSVG(String filePath) async {
    final svgString = await File(filePath).readAsString();
    final xmlDoc = XmlDocument.parse(svgString);

    final objects = <VectorObject>[];

    // Find all path elements
    for (final pathElement in xmlDoc.findAllElements('path')) {
      final d = pathElement.getAttribute('d');
      if (d != null) {
        final path = _parseSVGPath(d);
        objects.add(PathObject(path));
      }
    }

    // Find all rect elements
    for (final rectElement in xmlDoc.findAllElements('rect')) {
      final shape = _parseSVGRect(rectElement);
      objects.add(ShapeObject(shape));
    }

    // Find all circle/ellipse elements
    for (final circleElement in xmlDoc.findAllElements('circle')) {
      final shape = _parseSVGCircle(circleElement);
      objects.add(ShapeObject(shape));
    }

    // Create document with imported objects
    final document = Document.empty();
    return document.withLayerObjects(0, objects);
  }

  VectorPath _parseSVGPath(String pathData) {
    // Parse SVG path commands (M, L, C, Z, etc.)
    // Convert to AnchorPoint list
  }
}
```

## Success Criteria
- [ ] Can import SVG files
- [ ] Paths converted correctly
- [ ] Basic shapes (rect, circle, ellipse) work
- [ ] Colors/styles preserved
- [ ] Complex SVGs handled gracefully

## References
- SVG Path Spec: https://www.w3.org/TR/SVG/paths.html
- xml package: https://pub.dev/packages/xml
