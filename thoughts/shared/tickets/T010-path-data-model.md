# T010: Path Data Model

## Status
- **Phase**: 2 - Vector Data Model
- **Priority**: Critical
- **Estimated Effort**: 1 day
- **Dependencies**: T009

## Overview
Create the Path model representing sequences of anchor points and bezier segments, the core of vector drawing.

## Objectives
- Define Path class with anchor points
- Support open and closed paths
- Implement path operations (add/remove/move points)
- Convert path to Flutter Path for rendering

## Implementation

### Path Model (lib/models/vector/path.dart)
```dart
class VectorPath {
  final String id;
  final List<AnchorPoint> anchors;
  final bool closed;
  final PathStyle style;

  const VectorPath({
    required this.id,
    required this.anchors,
    this.closed = false,
    required this.style,
  });

  List<BezierSegment> get segments {
    final result = <BezierSegment>[];
    for (int i = 0; i < anchors.length - 1; i++) {
      result.add(BezierSegment(
        start: anchors[i].position,
        end: anchors[i + 1].position,
        control1: anchors[i].controlPoint2,
        control2: anchors[i + 1].controlPoint1,
      ));
    }
    if (closed && anchors.length > 2) {
      result.add(BezierSegment(
        start: anchors.last.position,
        end: anchors.first.position,
        control1: anchors.last.controlPoint2,
        control2: anchors.first.controlPoint1,
      ));
    }
    return result;
  }

  Path toFlutterPath() {
    final path = Path();
    if (anchors.isEmpty) return path;

    path.moveTo(anchors.first.position.dx, anchors.first.position.dy);

    for (final segment in segments) {
      if (segment.isStraight) {
        path.lineTo(segment.end.dx, segment.end.dy);
      } else if (segment.isCubic) {
        path.cubicTo(
          segment.control1!.dx, segment.control1!.dy,
          segment.control2!.dx, segment.control2!.dy,
          segment.end.dx, segment.end.dy,
        );
      }
    }

    if (closed) path.close();
    return path;
  }

  VectorPath withAnchorMoved(int index, Offset newPosition) {
    final newAnchors = List<AnchorPoint>.from(anchors);
    newAnchors[index] = anchors[index].copyWith(position: newPosition);
    return copyWith(anchors: newAnchors);
  }

  VectorPath withBCPAdjusted(int anchorIndex, int bcpIndex, Offset newPosition) {
    // Update controlPoint1 or controlPoint2
  }
}

class PathStyle {
  final Color strokeColor;
  final double strokeWidth;
  final Color? fillColor;

  const PathStyle({
    this.strokeColor = Colors.black,
    this.strokeWidth = 1.0,
    this.fillColor,
  });
}
```

## Success Criteria

### Automated Verification
- [ ] Can create path with multiple anchors
- [ ] Can get bezier segments from anchors
- [ ] Can convert to Flutter Path
- [ ] Can update anchor positions immutably
- [ ] Closed paths connect last to first

### Manual Verification
- [ ] Rendered path matches anchor positions
- [ ] BCPs affect curve shape correctly

## References
- Dissipate patterns: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:434-453`
