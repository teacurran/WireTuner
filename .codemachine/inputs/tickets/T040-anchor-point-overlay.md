# T040: Anchor Point Overlay Rendering

## Status
- **Phase**: 10 - Anchor Point Visualization
- **Priority**: Critical (Milestone 0.1)
- **Estimated Effort**: 1 day
- **Dependencies**: T015, T017

## Overview
Render all anchor points on paths at all times with type-specific visual indicators: red circles for smooth/curve points, black squares for corner points, and orange triangles for tangent points.

## Objectives
- Always-visible anchor points (not just when selected)
- Type-specific visualization based on handle configuration
- Scale-independent rendering (same visual size at all zoom levels)
- Transparent but clickable for future selection/dragging

## Visual Specifications

### Smooth/Curve Anchors
- **When**: `AnchorType.smooth` OR both handleIn and handleOut present
- **Visual**: Filled red circle (5px radius) with black 1px stroke
- **Color**: `#FF0000` (red fill), `#000000` (stroke)

### Corner Anchors
- **When**: `AnchorType.corner` OR no handles present
- **Visual**: Filled black square (7x7px) with white 1px stroke
- **Color**: `#000000` (black fill), `#FFFFFF` (stroke)

### Tangent Anchors
- **When**: Exactly one handle present (either handleIn XOR handleOut)
- **Visual**: Filled orange equilateral triangle (7px sides) with black 1px stroke
- **Color**: `#FF8800` (orange fill), `#000000` (stroke)
- **Orientation**: Point upward for consistency
- **Rationale**: Inspired by FontForge's tangent point representation

## Technical Requirements

### Overlay Integration
- Render in overlay layer with z-index 115
  - Above selection overlay (110)
  - Below snapping guides (120)
- Register as `CanvasOverlayEntry.painter` with id `'anchor-points'`
- Use `HitTestBehavior.translucent` for clickable transparent areas

### Coordinate System
- Anchor positions stored in world coordinates
- Convert to screen coordinates for rendering via `ViewportController.worldToScreen()`
- Size specified in screen pixels (constant visual size regardless of zoom)
- Stroke width: 1px screen space (no scaling)

### Performance
- Only render anchors for visible paths (future: viewport culling)
- Use `CustomPainter` with `shouldRepaint` optimization
- Repaint only when paths change or viewport transforms

## Implementation

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Visual constants for anchor point rendering.
class AnchorPointConstants {
  static const Color smoothColor = Color(0xFFFF0000); // Red
  static const Color cornerColor = Color(0xFF000000); // Black
  static const Color tangentColor = Color(0xFFFF8800); // Orange

  static const double smoothRadius = 5.0; // Screen pixels
  static const double cornerSize = 7.0; // Screen pixels
  static const double tangentSize = 7.0; // Screen pixels
  static const double strokeWidth = 1.0; // Screen pixels
}

/// Determines the visual type of an anchor based on its handle configuration.
enum AnchorVisualType {
  smooth,  // Red circle
  corner,  // Black square
  tangent, // Orange triangle
}

/// Custom painter for rendering anchor points on all paths.
class AnchorPointOverlayPainter extends CustomPainter {
  AnchorPointOverlayPainter({
    required this.paths,
    required this.viewportController,
  }) : super(repaint: viewportController);

  final Map<String, domain.Path> paths;
  final ViewportController viewportController;

  @override
  void paint(Canvas canvas, ui.Size size) {
    // Iterate through all paths
    for (final entry in paths.entries) {
      final path = entry.value;

      // Render each anchor in the path
      for (var i = 0; i < path.anchors.length; i++) {
        final anchor = path.anchors[i];
        final visualType = _determineVisualType(anchor);

        // Convert world coordinates to screen coordinates
        final screenPos = viewportController.worldToScreen(anchor.position);

        // Render based on type
        _renderAnchor(canvas, screenPos, visualType);
      }
    }
  }

  /// Determines the visual type based on handle presence.
  AnchorVisualType _determineVisualType(AnchorPoint anchor) {
    final hasHandleIn = anchor.handleIn != null;
    final hasHandleOut = anchor.handleOut != null;

    if (hasHandleIn && hasHandleOut) {
      return AnchorVisualType.smooth; // Both handles = smooth
    } else if (!hasHandleIn && !hasHandleOut) {
      return AnchorVisualType.corner; // No handles = corner
    } else {
      return AnchorVisualType.tangent; // One handle = tangent
    }
  }

  /// Renders an anchor point based on its visual type.
  void _renderAnchor(Canvas canvas, Offset position, AnchorVisualType type) {
    switch (type) {
      case AnchorVisualType.smooth:
        _renderSmoothAnchor(canvas, position);
        break;
      case AnchorVisualType.corner:
        _renderCornerAnchor(canvas, position);
        break;
      case AnchorVisualType.tangent:
        _renderTangentAnchor(canvas, position);
        break;
    }
  }

  /// Renders a smooth anchor (red circle).
  void _renderSmoothAnchor(Canvas canvas, Offset position) {
    final fillPaint = ui.Paint()
      ..color = AnchorPointConstants.smoothColor
      ..style = ui.PaintingStyle.fill;

    final strokePaint = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = AnchorPointConstants.strokeWidth;

    canvas.drawCircle(position, AnchorPointConstants.smoothRadius, fillPaint);
    canvas.drawCircle(position, AnchorPointConstants.smoothRadius, strokePaint);
  }

  /// Renders a corner anchor (black square).
  void _renderCornerAnchor(Canvas canvas, Offset position) {
    final halfSize = AnchorPointConstants.cornerSize / 2;
    final rect = Rect.fromCenter(
      center: position,
      width: AnchorPointConstants.cornerSize,
      height: AnchorPointConstants.cornerSize,
    );

    final fillPaint = ui.Paint()
      ..color = AnchorPointConstants.cornerColor
      ..style = ui.PaintingStyle.fill;

    final strokePaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = AnchorPointConstants.strokeWidth;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }

  /// Renders a tangent anchor (orange triangle).
  void _renderTangentAnchor(Canvas canvas, Offset position) {
    final path = ui.Path();
    final height = AnchorPointConstants.tangentSize * 0.866; // √3/2 for equilateral
    final halfBase = AnchorPointConstants.tangentSize / 2;

    // Equilateral triangle pointing upward
    path.moveTo(position.dx, position.dy - height * 2 / 3); // Top point
    path.lineTo(position.dx - halfBase, position.dy + height / 3); // Bottom left
    path.lineTo(position.dx + halfBase, position.dy + height / 3); // Bottom right
    path.close();

    final fillPaint = ui.Paint()
      ..color = AnchorPointConstants.tangentColor
      ..style = ui.PaintingStyle.fill;

    final strokePaint = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = AnchorPointConstants.strokeWidth;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(AnchorPointOverlayPainter oldDelegate) {
    // Repaint if paths changed
    return paths != oldDelegate.paths;
  }
}
```

### Integration with WireTunerCanvas

Update `wiretuner_canvas.dart` to register the anchor point overlay:

```dart
void _registerOverlays(Map<String, domain.Path> pathsMap) {
  // ... existing overlays ...

  // Register anchor point overlay (z-index 115)
  if (pathsMap.isNotEmpty) {
    _overlayRegistry.register(
      CanvasOverlayEntry.painter(
        id: 'anchor-points',
        zIndex: 115,
        painter: AnchorPointOverlayPainter(
          paths: pathsMap,
          viewportController: widget.viewportController,
        ),
        hitTestBehavior: HitTestBehavior.translucent,
      ),
    );
  } else {
    _overlayRegistry.unregister('anchor-points');
  }
}
```

## Success Criteria
- [ ] All anchor points visible on all paths at all times
- [ ] Smooth anchors render as red circles (5px)
- [ ] Corner anchors render as black squares (7x7px)
- [ ] Tangent anchors render as orange triangles (7px)
- [ ] Anchors maintain constant screen size regardless of zoom level
- [ ] No performance degradation with 100+ anchors on screen
- [ ] Anchors are clickable (hit test passes through transparent areas)

## Testing
- [ ] Unit test: `_determineVisualType()` returns correct type for each handle configuration
- [ ] Widget test: Verify anchor rendering at different zoom levels
- [ ] Integration test: Create path with mixed anchor types, verify correct visualization
- [ ] Manual test: Pan/zoom canvas, verify anchors maintain size and position

## References
- FontForge tangent point visualization
- Selection overlay: `lib/presentation/canvas/overlays/selection_overlay.dart`
- Pen tool preview: `lib/presentation/canvas/overlays/pen_preview_overlay.dart`
