import 'package:flutter/material.dart';
import 'package:wiretuner/presentation/canvas/overlay_registry.dart';

/// Widget that renders overlay layers in deterministic z-index order.
///
/// OverlayLayer consumes an [OverlayRegistry] and renders all registered
/// overlays in sorted order, handling both CustomPainter-based and
/// widget-based overlays.
///
/// ## Architecture
///
/// The layer uses a Stack to compose:
/// 1. Painter-based overlays (rendered via CustomPaint with IgnorePointer)
/// 2. Widget-based overlays (rendered as positioned widgets)
///
/// Each overlay type is rendered in z-index order within its category,
/// ensuring deterministic stacking regardless of registration order.
///
/// ## Hit-Test Management
///
/// By default, painter overlays use `IgnorePointer` to allow pointer events
/// to pass through to underlying canvas gesture handlers. This ensures:
/// - Pan/zoom gestures continue to work
/// - Tool click events reach the canvas
/// - Widget overlays can selectively capture events
///
/// Individual overlays can override this behavior via `hitTestBehavior`.
///
/// ## Performance
///
/// - Listens to registry changes for automatic re-rendering
/// - Rebuilds only when overlays are added/removed/reordered
/// - Painters repaint independently via their shouldRepaint logic
/// - Widget overlays handle their own rebuild logic
///
/// ## Usage
///
/// ```dart
/// final registry = OverlayRegistry();
///
/// // In canvas widget:
/// Stack(
///   children: [
///     CustomPaint(painter: DocumentPainter(...)),
///     OverlayLayer(registry: registry),
///   ],
/// )
/// ```
///
/// Related: I3.T8, OverlayRegistry, WireTunerCanvas
class OverlayLayer extends StatelessWidget {
  /// Creates an overlay layer.
  const OverlayLayer({
    required this.registry,
    super.key,
  });

  /// The overlay registry to render.
  final OverlayRegistry registry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final painters = registry.getSortedPainters();
        final widgets = registry.getSortedWidgets();

        // Early return if no overlays
        if (painters.isEmpty && widgets.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Render painter-based overlays first
            ...painters.map((entry) => _buildPainterOverlay(entry)),

            // Render widget-based overlays on top
            ...widgets.map((entry) => _buildWidgetOverlay(entry)),
          ],
        );
      },
    );
  }

  /// Builds a CustomPaint widget for a painter-based overlay.
  Widget _buildPainterOverlay(CanvasOverlayEntry entry) {
    final painter = entry.getPainter();
    if (painter == null) {
      return const SizedBox.shrink();
    }

    // Wrap in IgnorePointer based on hit-test behavior
    final paintWidget = CustomPaint(
      key: ValueKey('overlay-painter-${entry.id}'),
      painter: painter,
      size: Size.infinite,
    );

    // Use IgnorePointer for translucent behavior to pass events through
    if (entry.hitTestBehavior == HitTestBehavior.translucent) {
      return IgnorePointer(
        key: ValueKey('overlay-ignore-${entry.id}'),
        child: paintWidget,
      );
    }

    // For opaque or deferToChild, wrap in container with hit-test behavior
    return Container(
      key: ValueKey('overlay-container-${entry.id}'),
      child: paintWidget,
    );
  }

  /// Builds a widget-based overlay.
  ///
  /// Widget overlays handle their own positioning and hit-test behavior.
  Widget _buildWidgetOverlay(CanvasOverlayEntry entry) {
    if (entry.widget == null) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: ValueKey('overlay-widget-${entry.id}'),
      child: entry.widget!,
    );
  }
}

/// Composite painter that renders multiple CustomPainters in z-index order.
///
/// This painter is useful when you need to batch multiple painter overlays
/// into a single CustomPaint widget for performance optimization.
///
/// ## Usage
///
/// ```dart
/// final compositePainter = CompositeOverlayPainter(
///   painters: [
///     selectionPainter,
///     penPreviewPainter,
///     snappingGuidePainter,
///   ],
/// );
///
/// CustomPaint(painter: compositePainter)
/// ```
///
/// ## Performance Note
///
/// Using CompositeOverlayPainter can reduce the number of CustomPaint widgets
/// in the tree, but it also means all painters repaint together. Use separate
/// CustomPaint widgets (via OverlayLayer) if you want independent repaint
/// boundaries for each overlay.
class CompositeOverlayPainter extends CustomPainter {
  /// Creates a composite painter.
  CompositeOverlayPainter({
    required this.painters,
    Listenable? repaint,
  }) : super(repaint: repaint);

  /// The list of painters to render, in order.
  final List<CustomPainter> painters;

  @override
  void paint(Canvas canvas, Size size) {
    for (final painter in painters) {
      painter.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(CompositeOverlayPainter oldDelegate) {
    // Repaint if the painter list changed
    if (painters.length != oldDelegate.painters.length) {
      return true;
    }

    // Check if any individual painter should repaint
    for (int i = 0; i < painters.length; i++) {
      if (painters[i].shouldRepaint(oldDelegate.painters[i])) {
        return true;
      }
    }

    return false;
  }
}
