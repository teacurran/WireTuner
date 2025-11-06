# T023: Pen Tool - Create Bezier Curves

## Status
- **Phase**: 5 - Pen Tool
- **Priority**: Critical
- **Estimated Effort**: 1.5 days
- **Dependencies**: T022

## Overview
Enable creating curved segments by dragging BCPs when placing anchor points.

## Objectives
- Click and drag to create anchor with BCPs
- Show BCP handles while dragging
- Create smooth curves between anchors
- Support both symmetric and asymmetric handles

## Implementation
```dart
@override
void onDragStart(DragStartDetails details, ViewportTransform viewport) {
  final docPos = viewport.screenToDocument(details.localPosition);
  _currentAnchor = AnchorPoint(
    id: Uuid().v4(),
    position: docPos,
    type: PointType.smooth,
  );
}

@override
void onDragUpdate(DragUpdateDetails details, ViewportTransform viewport) {
  final docPos = viewport.screenToDocument(details.localPosition);
  final delta = docPos - _currentAnchor!.position;

  _currentAnchor = _currentAnchor!.copyWith(
    controlPoint1: _currentAnchor!.position - delta, // Incoming
    controlPoint2: docPos, // Outgoing
  );
}

@override
void onDragEnd(DragEndDetails details, ViewportTransform viewport) {
  _currentPath = _currentPath!.withAnchorAdded(_currentAnchor!);
  _currentAnchor = null;
}
```

## Success Criteria
- [ ] Click-drag creates anchor with BCPs
- [ ] Curves are smooth
- [ ] BCPs visible while dragging
- [ ] Resulting curve matches expected shape

## References
- Dissipate bezier: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:263-288`
