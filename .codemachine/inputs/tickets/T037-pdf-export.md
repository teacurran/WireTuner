# T037: PDF Export

## Status
- **Phase**: 9 - Import/Export
- **Priority**: Critical (MVP)
- **Estimated Effort**: 2 days
- **Dependencies**: T036

## Overview
Export document to PDF format.

## Objectives
- Generate PDF with vector graphics
- Use pdf package for Flutter
- Preserve vector quality
- Support multiple artboards as pages

## Dependencies
```yaml
dependencies:
  pdf: ^3.10.0
```

## Implementation
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFExporter {
  Future<Uint8List> exportToPDF(Document document) async {
    final pdf = pw.Document();

    // Add page for artboard
    pdf.addPage(
      pw.Page(
        pageFormat: _getPageFormat(document.artboard.bounds),
        build: (context) {
          return pw.CustomPaint(
            painter: (canvas, size) {
              _renderDocumentToPDF(canvas, document);
            },
          );
        },
      ),
    );

    return pdf.save();
  }

  void _renderPathToPDF(PdfCanvas canvas, VectorPath path) {
    // Convert path to PDF drawing commands
    canvas.moveTo(path.anchors.first.position.dx, path.anchors.first.position.dy);

    for (final segment in path.segments) {
      if (segment.isCubic) {
        canvas.curveTo(
          segment.control1!.dx, segment.control1!.dy,
          segment.control2!.dx, segment.control2!.dy,
          segment.end.dx, segment.end.dy,
        );
      } else {
        canvas.lineTo(segment.end.dx, segment.end.dy);
      }
    }

    if (path.closed) canvas.closePath();

    // Apply stroke/fill
    canvas.setStrokeColor(PdfColor.fromInt(path.style.strokeColor.value));
    canvas.stroke();
  }
}
```

## Success Criteria
- [ ] PDF exports successfully
- [ ] Vector quality preserved
- [ ] Opens correctly in PDF readers
- [ ] File size reasonable

## References
- pdf package: https://pub.dev/packages/pdf
