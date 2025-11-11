import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart' as geom;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Controller for marquee selection rectangle.
///
/// The MarqueeController manages the visual feedback and bounds calculation
/// for marquee (rubber-band) selection. It tracks the start and end points
/// in both screen and world coordinates, and renders a dashed selection
/// rectangle overlay.
///
/// ## Coordinate Systems
///
/// The controller maintains both screen and world coordinates:
/// - Screen coordinates: Used for rendering the visual feedback
/// - World coordinates: Used for hit-testing against document objects
///
/// ## Visual Style
///
/// The marquee rectangle is rendered with:
/// - Blue stroke color (matching selection overlay)
/// - Dashed border pattern
/// - Semi-transparent fill
/// - 1px stroke width (in screen space)
///
/// ## Usage
///
/// ```dart
/// // Start marquee on pointer down
/// final marquee = MarqueeController(
///   startScreenPos: event.localPosition,
///   startWorldPos: viewportController.screenToWorld(event.localPosition),
/// );
///
/// // Update on pointer move
/// marquee.updateEnd(
///   event.localPosition,
///   viewportController.screenToWorld(event.localPosition),
/// );
///
/// // Render overlay
/// marquee.render(canvas, viewportController);
///
/// // Get world bounds for hit-testing
/// final bounds = marquee.worldBounds;
/// final selectedObjects = document.objectsInBounds(bounds);
/// ```
class MarqueeController {
  MarqueeController({
    required this.startScreenPos,
    required this.startWorldPos,
  });

  /// Start position in screen coordinates.
  final Offset startScreenPos;

  /// Start position in world coordinates.
  final Point startWorldPos;

  /// Current end position in screen coordinates.
  Offset? _endScreenPos;

  /// Current end position in world coordinates.
  Point? _endWorldPos;

  /// Color for marquee stroke.
  static const Color strokeColor = Color(0xFF2196F3); // Blue

  /// Color for marquee fill.
  static const Color fillColor = Color(0x1A2196F3); // Blue with 10% opacity

  /// Stroke width in screen pixels.
  static const double strokeWidth = 1.0;

  /// Dash pattern for marquee border (line, gap).
  static const List<double> dashPattern = [4.0, 4.0];

  /// Updates the end position of the marquee rectangle.
  void updateEnd(Offset screenPos, Point worldPos) {
    _endScreenPos = screenPos;
    _endWorldPos = worldPos;
  }

  /// Returns the marquee bounds in world coordinates, or null if not yet dragged.
  geom.Rectangle? get worldBounds {
    if (_endWorldPos == null) return null;

    final minX =
        _endWorldPos!.x < startWorldPos.x ? _endWorldPos!.x : startWorldPos.x;
    final minY =
        _endWorldPos!.y < startWorldPos.y ? _endWorldPos!.y : startWorldPos.y;
    final maxX =
        _endWorldPos!.x > startWorldPos.x ? _endWorldPos!.x : startWorldPos.x;
    final maxY =
        _endWorldPos!.y > startWorldPos.y ? _endWorldPos!.y : startWorldPos.y;

    return geom.Rectangle(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Returns the marquee bounds in screen coordinates, or null if not yet dragged.
  Rect? get screenBounds {
    if (_endScreenPos == null) return null;

    final minX = _endScreenPos!.dx < startScreenPos.dx
        ? _endScreenPos!.dx
        : startScreenPos.dx;
    final minY = _endScreenPos!.dy < startScreenPos.dy
        ? _endScreenPos!.dy
        : startScreenPos.dy;
    final maxX = _endScreenPos!.dx > startScreenPos.dx
        ? _endScreenPos!.dx
        : startScreenPos.dx;
    final maxY = _endScreenPos!.dy > startScreenPos.dy
        ? _endScreenPos!.dy
        : startScreenPos.dy;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Renders the marquee rectangle overlay.
  void render(ui.Canvas canvas, ViewportController viewportController) {
    final bounds = screenBounds;
    if (bounds == null || bounds.width < 1 || bounds.height < 1) {
      return; // Don't render if marquee is too small
    }

    // Draw fill
    final fillPaint = ui.Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(bounds, fillPaint);

    // Draw dashed stroke
    final strokePaint = ui.Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    _drawDashedRect(canvas, bounds, strokePaint);
  }

  /// Draws a dashed rectangle.
  void _drawDashedRect(ui.Canvas canvas, Rect rect, ui.Paint paint) {
    final path = ui.Path();

    // Top edge
    _addDashedLine(
      path,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
    );

    // Right edge
    _addDashedLine(
      path,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
    );

    // Bottom edge
    _addDashedLine(
      path,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    );

    // Left edge
    _addDashedLine(
      path,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
    );

    canvas.drawPath(path, paint);
  }

  /// Adds a dashed line to a path.
  void _addDashedLine(ui.Path path, Offset start, Offset end) {
    final dashLength = dashPattern[0];
    final gapLength = dashPattern[1];
    final totalLength = (end - start).distance;

    double currentDistance = 0;
    bool isDash = true;

    path.moveTo(start.dx, start.dy);

    while (currentDistance < totalLength) {
      final segmentLength = isDash ? dashLength : gapLength;
      final nextDistance =
          (currentDistance + segmentLength).clamp(0.0, totalLength);

      final t = nextDistance / totalLength;
      final nextPoint = Offset.lerp(start, end, t)!;

      if (isDash) {
        path.lineTo(nextPoint.dx, nextPoint.dy);
      } else {
        path.moveTo(nextPoint.dx, nextPoint.dy);
      }

      currentDistance = nextDistance;
      isDash = !isDash;
    }
  }
}
