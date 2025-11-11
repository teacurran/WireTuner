import 'package:flutter/material.dart';

/// Z-index tiers for deterministic overlay stacking order.
///
/// These constants define the rendering order of different overlay types.
/// Lower values render first (bottom), higher values render last (top).
///
/// ## Stacking Architecture
///
/// The overlay system uses three distinct tiers:
///
/// 1. **Document-derived overlays (100-199)**: Visual feedback tied to document
///    state, like selection boxes and bounding rectangles. These render above
///    the document layer but below tool-specific UI.
///
/// 2. **Tool-state painters (200-299)**: Dynamic previews from active tools,
///    such as pen path previews, shape creation guides, and snapping indicators.
///    These render above selection UI to provide immediate visual feedback.
///
/// 3. **Widget overlays (300-399)**: Positioned widgets for hints, HUD elements,
///    and performance monitoring. These render on top of all painted layers.
///
/// ## Usage
///
/// ```dart
/// registry.register(
///   id: 'selection',
///   zIndex: OverlayZIndex.selection,
///   painter: selectionPainter,
/// );
/// ```
class OverlayZIndex {
  /// Base z-index for document-derived overlays (100-199).
  static const int documentBase = 100;

  /// Selection boxes and handles (document-derived).
  static const int selection = 110;

  /// Object bounds and alignment guides (document-derived).
  static const int bounds = 120;

  /// Base z-index for tool-state painters (200-299).
  static const int toolBase = 200;

  /// Pen tool preview (rubber-band line and handle guides).
  static const int penPreview = 210;

  /// Shape creation preview (rectangle, ellipse guides).
  static const int shapePreview = 220;

  /// Snapping guides (grid, object, guide alignment).
  static const int snapping = 230;

  /// Active tool overlay from ToolManager.renderOverlay.
  static const int activeTool = 240;

  /// Base z-index for widget overlays (300-399).
  static const int widgetBase = 300;

  /// Tool hints and modifier key feedback.
  static const int toolHints = 310;

  /// Performance HUD and debugging overlays.
  static const int performance = 320;
}

/// Represents a registered canvas overlay entry.
///
/// Each overlay can be one of three types:
/// - **CustomPainter**: Renders via Canvas API (e.g., selection boxes, pen preview)
/// - **Widget**: Positioned widget (e.g., tool hints, performance HUD)
/// - **PainterBuilder**: Dynamic painter constructed on each frame (e.g., tool overlay)
///
/// Note: Named CanvasOverlayEntry to avoid conflict with Flutter's OverlayEntry.
class CanvasOverlayEntry {
  /// Creates an overlay entry with a CustomPainter.
  CanvasOverlayEntry.painter({
    required this.id,
    required this.zIndex,
    required CustomPainter painter,
    this.hitTestBehavior = HitTestBehavior.translucent,
  })  : painter = painter,
        widget = null,
        painterBuilder = null;

  /// Creates an overlay entry with a positioned widget.
  CanvasOverlayEntry.widget({
    required this.id,
    required this.zIndex,
    required Widget widget,
    this.hitTestBehavior = HitTestBehavior.translucent,
  })  : widget = widget,
        painter = null,
        painterBuilder = null;

  /// Creates an overlay entry with a painter builder function.
  ///
  /// The builder is invoked on each frame to construct a fresh painter.
  /// This is useful for tool overlays that need to reflect current state.
  CanvasOverlayEntry.painterBuilder({
    required this.id,
    required this.zIndex,
    required CustomPainter Function() builder,
    this.hitTestBehavior = HitTestBehavior.translucent,
  })  : painterBuilder = builder,
        painter = null,
        widget = null;

  /// Unique identifier for this overlay.
  final String id;

  /// Z-index determining render order (lower = bottom, higher = top).
  final int zIndex;

  /// CustomPainter instance (if painter-based).
  final CustomPainter? painter;

  /// Widget instance (if widget-based).
  final Widget? widget;

  /// Painter builder function (if builder-based).
  final CustomPainter Function()? painterBuilder;

  /// Hit-test behavior for pointer event routing.
  ///
  /// - `translucent`: Overlay receives events but also passes them through
  /// - `opaque`: Overlay blocks events from layers below
  /// - `deferToChild`: Only overlay's child widgets receive events
  final HitTestBehavior hitTestBehavior;

  /// Returns true if this is a painter-based overlay.
  bool get isPainter => painter != null || painterBuilder != null;

  /// Returns true if this is a widget-based overlay.
  bool get isWidget => widget != null;

  /// Gets the painter instance (either direct or from builder).
  CustomPainter? getPainter() {
    if (painter != null) return painter;
    if (painterBuilder != null) return painterBuilder!();
    return null;
  }
}

/// Registry for managing overlay rendering order and lifecycle.
///
/// OverlayRegistry provides a centralized system for:
/// - Registering overlays with deterministic z-index ordering
/// - Retrieving overlays sorted by render order
/// - Adding/removing overlays dynamically
/// - Managing hit-test behavior for pointer events
///
/// ## Architecture
///
/// The registry uses a three-tier z-index system (see [OverlayZIndex]):
/// 1. Document-derived overlays (100-199): Selection, bounds
/// 2. Tool-state painters (200-299): Pen preview, snapping guides
/// 3. Widget overlays (300-399): Tool hints, performance HUD
///
/// ## Usage
///
/// ```dart
/// final registry = OverlayRegistry();
///
/// // Register selection overlay
/// registry.register(CanvasOverlayEntry.painter(
///   id: 'selection',
///   zIndex: OverlayZIndex.selection,
///   painter: SelectionOverlayPainter(...),
/// ));
///
/// // Register pen preview
/// registry.register(CanvasOverlayEntry.painter(
///   id: 'pen-preview',
///   zIndex: OverlayZIndex.penPreview,
///   painter: PenPreviewOverlayPainter(...),
/// ));
///
/// // Register tool hints widget
/// registry.register(CanvasOverlayEntry.widget(
///   id: 'tool-hints',
///   zIndex: OverlayZIndex.toolHints,
///   widget: ToolHintsOverlay(...),
/// ));
///
/// // Get sorted overlays for rendering
/// final overlays = registry.getSortedOverlays();
/// ```
///
/// ## Painter vs Widget Overlays
///
/// - **Painters**: Use for high-performance drawing (selection boxes, guides)
///   - Rendered via CustomPaint
///   - Apply viewport transformations
///   - Efficient for frequently updating graphics
///
/// - **Widgets**: Use for positioned UI elements (hints, HUD)
///   - Rendered as positioned Flutter widgets
///   - Handle their own layout and text rendering
///   - Better for text-heavy or interactive overlays
///
/// Related: I3.T8, Section 2 (Rendering & Graphics)
class OverlayRegistry extends ChangeNotifier {
  /// Map of overlays by ID.
  final Map<String, CanvasOverlayEntry> _overlays = {};

  /// Registers an overlay entry.
  ///
  /// If an overlay with the same ID exists, it will be replaced.
  /// Notifies listeners after registration to trigger re-render.
  void register(CanvasOverlayEntry entry) {
    _overlays[entry.id] = entry;
    notifyListeners();
  }

  /// Unregisters an overlay by ID.
  ///
  /// Returns true if the overlay was found and removed, false otherwise.
  /// Notifies listeners after removal to trigger re-render.
  bool unregister(String id) {
    final removed = _overlays.remove(id) != null;
    if (removed) {
      notifyListeners();
    }
    return removed;
  }

  /// Gets an overlay entry by ID.
  ///
  /// Returns null if no overlay with the given ID exists.
  CanvasOverlayEntry? get(String id) => _overlays[id];

  /// Checks if an overlay is registered.
  bool contains(String id) => _overlays.containsKey(id);

  /// Gets all overlays sorted by z-index (ascending).
  ///
  /// Lower z-index values render first (bottom), higher values render last (top).
  /// Overlays with the same z-index maintain stable ordering based on registration.
  List<CanvasOverlayEntry> getSortedOverlays() {
    final overlays = _overlays.values.toList();
    overlays.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return overlays;
  }

  /// Gets all painter-based overlays sorted by z-index.
  List<CanvasOverlayEntry> getSortedPainters() {
    return getSortedOverlays().where((e) => e.isPainter).toList();
  }

  /// Gets all widget-based overlays sorted by z-index.
  List<CanvasOverlayEntry> getSortedWidgets() {
    return getSortedOverlays().where((e) => e.isWidget).toList();
  }

  /// Clears all registered overlays.
  ///
  /// Notifies listeners after clearing to trigger re-render.
  void clear() {
    _overlays.clear();
    notifyListeners();
  }

  /// Returns the number of registered overlays.
  int get count => _overlays.length;

  /// Returns true if no overlays are registered.
  bool get isEmpty => _overlays.isEmpty;

  /// Returns true if any overlays are registered.
  bool get isNotEmpty => _overlays.isNotEmpty;
}
