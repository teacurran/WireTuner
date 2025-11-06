# T009: Core Geometry Primitives

## Status
- **Phase**: 2 - Vector Data Model
- **Priority**: Critical
- **Estimated Effort**: 0.5 days
- **Dependencies**: None

## Overview
Create fundamental geometry classes for vector graphics: Point, BezierSegment, Transform Matrix.

## Objectives
- Define Point class (anchor point with BCPs)
- Define BezierSegment class (cubic bezier curve)
- Define Transform2D class (affine transformations)
- Ensure all classes are immutable and serializable

## Implementation

### Point Model (lib/models/geometry/point.dart)
```dart
class AnchorPoint {
  final String id;
  final Offset position;
  final Offset? controlPoint1; // BCP for incoming curve
  final Offset? controlPoint2; // BCP for outgoing curve
  final PointType type; // corner, smooth, symmetrical

  const AnchorPoint({
    required this.id,
    required this.position,
    this.controlPoint1,
    this.controlPoint2,
    this.type = PointType.corner,
  });

  AnchorPoint copyWith({
    Offset? position,
    Offset? controlPoint1,
    Offset? controlPoint2,
    PointType? type,
  }) => AnchorPoint(
    id: id,
    position: position ?? this.position,
    controlPoint1: controlPoint1 ?? this.controlPoint1,
    controlPoint2: controlPoint2 ?? this.controlPoint2,
    type: type ?? this.type,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    if (controlPoint1 != null)
      'controlPoint1': {'x': controlPoint1!.dx, 'y': controlPoint1!.dy},
    if (controlPoint2 != null)
      'controlPoint2': {'x': controlPoint2!.dx, 'y': controlPoint2!.dy},
    'type': type.name,
  };
}

enum PointType { corner, smooth, symmetrical }
```

### Bezier Segment (lib/models/geometry/bezier_segment.dart)
```dart
class BezierSegment {
  final Offset start;
  final Offset end;
  final Offset? control1;
  final Offset? control2;

  const BezierSegment({
    required this.start,
    required this.end,
    this.control1,
    this.control2,
  });

  bool get isStraight => control1 == null && control2 == null;
  bool get isQuadratic => control1 != null && control2 == null;
  bool get isCubic => control1 != null && control2 != null;
}
```

### Transform2D (lib/models/geometry/transform2d.dart)
```dart
class Transform2D {
  final double tx, ty; // Translation
  final double sx, sy; // Scale
  final double rotation; // Radians

  const Transform2D({
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rotation = 0,
  });

  Matrix4 toMatrix4() {
    // Convert to Flutter Matrix4
  }

  Transform2D compose(Transform2D other) {
    // Compose transformations
  }
}
```

## Success Criteria

### Automated Verification
- [ ] All geometry classes compile
- [ ] Point can be created with BCPs
- [ ] BezierSegment identifies type correctly
- [ ] Transform2D converts to Matrix4
- [ ] JSON serialization works

### Manual Verification
- [ ] Can represent corner vs smooth points
- [ ] Can represent straight, quadratic, cubic curves

## References
- Dissipate Point/BezierCurve: `/Users/tea/dev/github/dissipate/lib/screens/whiteboard.dart:434-453`
