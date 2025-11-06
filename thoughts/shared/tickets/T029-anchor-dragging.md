# T029: Anchor Point Dragging

## Status
- **Phase**: 7 - Direct Manipulation
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1.5 days
- **Dependencies**: T020

## Overview
Enable dragging anchor points to reshape paths.

## Objectives
- Drag selected anchor points
- Update path in real-time
- Record sampled drag interaction
- Update connected curves automatically

## Implementation
```dart
class DirectSelectionTool extends Tool {
  @override
  void onDragStart(DragStartDetails details, ViewportTransform viewport) {
    final docPos = viewport.screenToDocument(details.localPosition);
    final hitAnchor = _hitTestAnchor(docPos);

    if (hitAnchor != null) {
      _draggingAnchor = hitAnchor;
      _startDragInteraction();
    }
  }

  @override
  void onDragUpdate(DragUpdateDetails details, ViewportTransform viewport) {
    if (_draggingAnchor != null) {
      final docPos = viewport.screenToDocument(details.localPosition);
      _updateAnchorPosition(_draggingAnchor!, docPos);
      _recordSample(docPos);
    }
  }

  @override
  void onDragEnd(DragEndDetails details, ViewportTransform viewport) {
    _endDragInteraction();
    _recordEvent(EventType.pathAnchorMoved, /* ... */);
  }
}
```

## Success Criteria
- [ ] Can drag anchor points
- [ ] Path updates smoothly during drag
- [ ] Connected curves update correctly
- [ ] Drag interaction recorded with sampling

## References
- Dissipate dragging: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:89-145`
