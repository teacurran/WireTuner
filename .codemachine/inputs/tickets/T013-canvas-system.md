# T013: Canvas System with CustomPainter

## Status
- **Phase**: 3 - Rendering Engine
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T012

## Overview
Create the canvas rendering system using Flutter CustomPainter to draw the document.

## Objectives
- Implement CanvasWidget with CustomPainter
- Render document to screen
- Apply viewport transform (pan/zoom)
- Handle high DPI displays

## Implementation (lib/widgets/canvas/canvas_widget.dart)
```dart
class CanvasWidget extends StatelessWidget {
  final Document document;
  final ViewportTransform viewport;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DocumentPainter(document, viewport),
      child: Container(),
    );
  }
}

class DocumentPainter extends CustomPainter {
  final Document document;
  final ViewportTransform viewport;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.scale);

    // Render artboard background
    _renderArtboard(canvas);

    // Render all objects
    for (final layer in document.layers) {
      if (layer.visible) {
        for (final obj in layer.objects) {
          _renderObject(canvas, obj);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(DocumentPainter old) =>
      document != old.document || viewport != old.viewport;
}
```

## Success Criteria
- [ ] Canvas renders document
- [ ] Objects appear on screen
- [ ] Viewport transform applies correctly

## References
- Dissipate CustomPaint: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:52-75`
