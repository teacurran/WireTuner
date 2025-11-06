# T036: SVG Export

## Status
- **Phase**: 9 - Import/Export
- **Priority**: Critical (MVP)
- **Estimated Effort**: 2 days
- **Dependencies**: T034

## Overview
Export document to SVG format.

## Objectives
- Convert document state to SVG XML
- Export all paths as SVG path elements
- Export shapes as appropriate SVG elements
- Preserve colors, strokes, fills
- Support artboard bounds as viewBox

## Implementation
```dart
class SVGExporter {
  String exportToSVG(Document document) {
    final buffer = StringBuffer();

    // SVG header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.write('<svg xmlns="http://www.w3.org/2000/svg" ');
    buffer.write('viewBox="${document.artboard.bounds.left} ');
    buffer.write('${document.artboard.bounds.top} ');
    buffer.write('${document.artboard.bounds.width} ');
    buffer.writeln('${document.artboard.bounds.height}">');

    // Export each layer as group
    for (final layer in document.layers) {
      buffer.writeln('  <g id="${layer.id}">');
      for (final obj in layer.objects) {
        buffer.writeln(_objectToSVG(obj));
      }
      buffer.writeln('  </g>');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  String _pathToSVGPath(VectorPath path) {
    final d = StringBuffer();
    d.write('M ${path.anchors.first.position.dx},${path.anchors.first.position.dy}');

    for (final segment in path.segments) {
      if (segment.isCubic) {
        d.write(' C ${segment.control1!.dx},${segment.control1!.dy}');
        d.write(' ${segment.control2!.dx},${segment.control2!.dy}');
        d.write(' ${segment.end.dx},${segment.end.dy}');
      } else {
        d.write(' L ${segment.end.dx},${segment.end.dy}');
      }
    }

    if (path.closed) d.write(' Z');
    return d.toString();
  }
}
```

## Success Criteria
- [ ] SVG files open in Illustrator/Inkscape
- [ ] Paths render correctly
- [ ] Colors preserved
- [ ] Curves are accurate

## References
- SVG Path Spec: https://www.w3.org/TR/SVG/paths.html
