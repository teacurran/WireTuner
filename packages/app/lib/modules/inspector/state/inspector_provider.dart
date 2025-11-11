import 'package:flutter/material.dart';

/// Represents the properties of a selected object in the Inspector.
///
/// This model contains all editable properties displayed in the Inspector panel,
/// organized into logical groups (transform, fill, stroke, effects).
@immutable
class ObjectProperties {
  /// Unique identifier for the selected object.
  final String objectId;

  /// Object type (e.g., "Rectangle", "Path", "Group").
  final String objectType;

  /// X position in pixels.
  final double x;

  /// Y position in pixels.
  final double y;

  /// Width in pixels.
  final double width;

  /// Height in pixels.
  final double height;

  /// Rotation in degrees.
  final double rotation;

  /// Whether aspect ratio is locked.
  final bool aspectRatioLocked;

  /// Fill color (null if no fill).
  final Color? fillColor;

  /// Fill opacity (0.0 to 1.0).
  final double fillOpacity;

  /// Stroke color (null if no stroke).
  final Color? strokeColor;

  /// Stroke width in pixels.
  final double strokeWidth;

  /// Stroke cap style.
  final StrokeCap strokeCap;

  /// Stroke join style.
  final StrokeJoin strokeJoin;

  /// Blend mode for compositing.
  final BlendMode blendMode;

  /// Overall opacity (0.0 to 1.0).
  final double opacity;

  const ObjectProperties({
    required this.objectId,
    required this.objectType,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 100.0,
    this.height = 100.0,
    this.rotation = 0.0,
    this.aspectRatioLocked = false,
    this.fillColor,
    this.fillOpacity = 1.0,
    this.strokeColor,
    this.strokeWidth = 1.0,
    this.strokeCap = StrokeCap.butt,
    this.strokeJoin = StrokeJoin.miter,
    this.blendMode = BlendMode.srcOver,
    this.opacity = 1.0,
  });

  ObjectProperties copyWith({
    String? objectId,
    String? objectType,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? aspectRatioLocked,
    Color? fillColor,
    double? fillOpacity,
    Color? strokeColor,
    double? strokeWidth,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    BlendMode? blendMode,
    double? opacity,
  }) {
    return ObjectProperties(
      objectId: objectId ?? this.objectId,
      objectType: objectType ?? this.objectType,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      aspectRatioLocked: aspectRatioLocked ?? this.aspectRatioLocked,
      fillColor: fillColor ?? this.fillColor,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeCap: strokeCap ?? this.strokeCap,
      strokeJoin: strokeJoin ?? this.strokeJoin,
      blendMode: blendMode ?? this.blendMode,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectProperties &&
          runtimeType == other.runtimeType &&
          objectId == other.objectId &&
          objectType == other.objectType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height &&
          rotation == other.rotation &&
          aspectRatioLocked == other.aspectRatioLocked &&
          fillColor == other.fillColor &&
          fillOpacity == other.fillOpacity &&
          strokeColor == other.strokeColor &&
          strokeWidth == other.strokeWidth &&
          strokeCap == other.strokeCap &&
          strokeJoin == other.strokeJoin &&
          blendMode == other.blendMode &&
          opacity == other.opacity;

  @override
  int get hashCode =>
      objectId.hashCode ^
      objectType.hashCode ^
      x.hashCode ^
      y.hashCode ^
      width.hashCode ^
      height.hashCode ^
      rotation.hashCode ^
      aspectRatioLocked.hashCode ^
      fillColor.hashCode ^
      fillOpacity.hashCode ^
      strokeColor.hashCode ^
      strokeWidth.hashCode ^
      strokeCap.hashCode ^
      strokeJoin.hashCode ^
      blendMode.hashCode ^
      opacity.hashCode;
}

/// Represents properties for multiple selected objects with mixed values.
///
/// When multiple objects are selected with different property values,
/// those properties are marked as null to indicate "mixed" state.
@immutable
class MultiSelectionProperties {
  /// List of selected object IDs.
  final List<String> objectIds;

  /// Number of selected objects.
  final int selectionCount;

  /// X position (null if mixed values).
  final double? x;

  /// Y position (null if mixed values).
  final double? y;

  /// Width (null if mixed values).
  final double? width;

  /// Height (null if mixed values).
  final double? height;

  /// Rotation (null if mixed values).
  final double? rotation;

  /// Aspect ratio locked state (null if mixed values).
  final bool? aspectRatioLocked;

  /// Fill color (null if mixed values or no fill).
  final Color? fillColor;

  /// Fill opacity (null if mixed values).
  final double? fillOpacity;

  /// Stroke color (null if mixed values or no stroke).
  final Color? strokeColor;

  /// Stroke width (null if mixed values).
  final double? strokeWidth;

  /// Stroke cap style (null if mixed values).
  final StrokeCap? strokeCap;

  /// Stroke join style (null if mixed values).
  final StrokeJoin? strokeJoin;

  /// Blend mode (null if mixed values).
  final BlendMode? blendMode;

  /// Opacity (null if mixed values).
  final double? opacity;

  const MultiSelectionProperties({
    required this.objectIds,
    required this.selectionCount,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.aspectRatioLocked,
    this.fillColor,
    this.fillOpacity,
    this.strokeColor,
    this.strokeWidth,
    this.strokeCap,
    this.strokeJoin,
    this.blendMode,
    this.opacity,
  });
}

/// Main state provider for the Inspector panel.
///
/// Manages property editing state, selection tracking, and command dispatch
/// for the Inspector UI. Integrates with the InteractionEngine for undo/redo
/// and EventStore for persistence.
///
/// ## Architecture
///
/// Follows the NavigatorProvider pattern:
/// - Extends ChangeNotifier for reactive UI updates
/// - Provides clear state accessors for widgets
/// - Emits domain commands through abstraction layer
/// - Supports single and multi-object selection
///
/// ## Usage
///
/// ```dart
/// final inspector = context.watch<InspectorProvider>();
///
/// // Access state
/// final props = inspector.currentProperties;
/// final hasSelection = inspector.hasSelection;
///
/// // Mutations
/// inspector.updateTransform(x: 100, y: 200);
/// inspector.updateFill(color: Colors.blue);
/// ```
///
/// Related: FR-045, Section 6.2 component specs, Inspector wireframe
class InspectorProvider extends ChangeNotifier {
  /// Currently selected object IDs.
  final Set<String> _selectedObjectIds = {};

  /// Properties for single selected object.
  ObjectProperties? _currentProperties;

  /// Properties for multiple selected objects.
  MultiSelectionProperties? _multiSelectionProperties;

  /// Uncommitted changes (for Reset functionality).
  final Map<String, ObjectProperties> _stagedChanges = {};

  /// Callback for dispatching property change commands.
  /// Will be wired to InteractionEngine/EventStore in future iterations.
  final void Function(String command, Map<String, dynamic> data)? _commandDispatcher;

  InspectorProvider({
    void Function(String command, Map<String, dynamic> data)? commandDispatcher,
  }) : _commandDispatcher = commandDispatcher;

  // Getters

  /// Whether any objects are selected.
  bool get hasSelection => _selectedObjectIds.isNotEmpty;

  /// Number of selected objects.
  int get selectionCount => _selectedObjectIds.length;

  /// Whether multiple objects are selected.
  bool get isMultiSelection => _selectedObjectIds.length > 1;

  /// Current properties for single selection (null if no selection or multi-selection).
  ObjectProperties? get currentProperties => _currentProperties;

  /// Multi-selection properties (null if single or no selection).
  MultiSelectionProperties? get multiSelectionProperties => _multiSelectionProperties;

  /// Selected object IDs.
  Set<String> get selectedObjectIds => Set.unmodifiable(_selectedObjectIds);

  /// Whether there are uncommitted changes.
  bool get hasStagedChanges => _stagedChanges.isNotEmpty;

  // Selection Management

  /// Update selection from InteractionEngine.
  ///
  /// This is called when the user selects objects on the canvas.
  /// It loads properties for the selected objects.
  void updateSelection(List<String> objectIds, [List<ObjectProperties>? properties]) {
    _selectedObjectIds.clear();
    _selectedObjectIds.addAll(objectIds);
    _stagedChanges.clear();

    if (objectIds.isEmpty) {
      _currentProperties = null;
      _multiSelectionProperties = null;
    } else if (objectIds.length == 1) {
      // Single selection
      _currentProperties = properties?.first ??
          ObjectProperties(
            objectId: objectIds.first,
            objectType: 'Unknown',
          );
      _multiSelectionProperties = null;
    } else {
      // Multi-selection: compute merged properties
      _currentProperties = null;
      _multiSelectionProperties = _computeMultiSelectionProperties(
        objectIds,
        properties ?? [],
      );
    }

    notifyListeners();
  }

  /// Compute multi-selection properties, marking mixed values as null.
  MultiSelectionProperties _computeMultiSelectionProperties(
    List<String> objectIds,
    List<ObjectProperties> properties,
  ) {
    if (properties.isEmpty) {
      return MultiSelectionProperties(
        objectIds: objectIds,
        selectionCount: objectIds.length,
      );
    }

    final first = properties.first;
    double? x = first.x;
    double? y = first.y;
    double? width = first.width;
    double? height = first.height;
    double? rotation = first.rotation;
    bool? aspectRatioLocked = first.aspectRatioLocked;
    Color? fillColor = first.fillColor;
    double? fillOpacity = first.fillOpacity;
    Color? strokeColor = first.strokeColor;
    double? strokeWidth = first.strokeWidth;
    StrokeCap? strokeCap = first.strokeCap;
    StrokeJoin? strokeJoin = first.strokeJoin;
    BlendMode? blendMode = first.blendMode;
    double? opacity = first.opacity;

    for (var i = 1; i < properties.length; i++) {
      final prop = properties[i];
      if (x != prop.x) x = null;
      if (y != prop.y) y = null;
      if (width != prop.width) width = null;
      if (height != prop.height) height = null;
      if (rotation != prop.rotation) rotation = null;
      if (aspectRatioLocked != prop.aspectRatioLocked) aspectRatioLocked = null;
      if (fillColor != prop.fillColor) fillColor = null;
      if (fillOpacity != prop.fillOpacity) fillOpacity = null;
      if (strokeColor != prop.strokeColor) strokeColor = null;
      if (strokeWidth != prop.strokeWidth) strokeWidth = null;
      if (strokeCap != prop.strokeCap) strokeCap = null;
      if (strokeJoin != prop.strokeJoin) strokeJoin = null;
      if (blendMode != prop.blendMode) blendMode = null;
      if (opacity != prop.opacity) opacity = null;
    }

    return MultiSelectionProperties(
      objectIds: objectIds,
      selectionCount: objectIds.length,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      aspectRatioLocked: aspectRatioLocked,
      fillColor: fillColor,
      fillOpacity: fillOpacity,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      blendMode: blendMode,
      opacity: opacity,
    );
  }

  // Property Updates (Staging)

  /// Update transform properties (staged, not committed).
  void updateTransform({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? aspectRatioLocked,
  }) {
    if (!hasSelection) return;

    if (isMultiSelection) {
      // For multi-selection, apply relative changes
      // TODO: Implement multi-object transform
      debugPrint('Multi-selection transform not yet implemented');
    } else {
      final current = _currentProperties!;
      final updated = current.copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
        rotation: rotation,
        aspectRatioLocked: aspectRatioLocked,
      );
      _currentProperties = updated;
      _stagedChanges[current.objectId] = updated;
      notifyListeners();
    }
  }

  /// Update fill properties (staged, not committed).
  void updateFill({
    Color? color,
    double? opacity,
  }) {
    if (!hasSelection) return;

    if (isMultiSelection) {
      // For multi-selection, update all objects
      debugPrint('Multi-selection fill not yet implemented');
    } else {
      final current = _currentProperties!;
      final updated = current.copyWith(
        fillColor: color,
        fillOpacity: opacity,
      );
      _currentProperties = updated;
      _stagedChanges[current.objectId] = updated;
      notifyListeners();
    }
  }

  /// Update stroke properties (staged, not committed).
  void updateStroke({
    Color? color,
    double? width,
    StrokeCap? cap,
    StrokeJoin? join,
  }) {
    if (!hasSelection) return;

    if (isMultiSelection) {
      debugPrint('Multi-selection stroke not yet implemented');
    } else {
      final current = _currentProperties!;
      final updated = current.copyWith(
        strokeColor: color,
        strokeWidth: width,
        strokeCap: cap,
        strokeJoin: join,
      );
      _currentProperties = updated;
      _stagedChanges[current.objectId] = updated;
      notifyListeners();
    }
  }

  /// Update blend/opacity properties (staged, not committed).
  void updateBlend({
    BlendMode? mode,
    double? opacity,
  }) {
    if (!hasSelection) return;

    if (isMultiSelection) {
      debugPrint('Multi-selection blend not yet implemented');
    } else {
      final current = _currentProperties!;
      final updated = current.copyWith(
        blendMode: mode,
        opacity: opacity,
      );
      _currentProperties = updated;
      _stagedChanges[current.objectId] = updated;
      notifyListeners();
    }
  }

  // Command Dispatch

  /// Commit staged changes to EventStore.
  ///
  /// This creates an undoable command and dispatches it to the domain layer.
  void applyChanges() {
    if (!hasStagedChanges) return;

    for (final entry in _stagedChanges.entries) {
      _commandDispatcher?.call('updateObjectProperties', {
        'objectId': entry.key,
        'properties': entry.value,
      });
    }

    _stagedChanges.clear();
    notifyListeners();
  }

  /// Reset staged changes to last committed state.
  void resetChanges() {
    if (!hasStagedChanges) return;

    _stagedChanges.clear();

    // Reload properties from domain model
    // TODO: Fetch from actual domain model
    // For now, just clear staged changes
    notifyListeners();
  }

  @override
  void dispose() {
    _selectedObjectIds.clear();
    _stagedChanges.clear();
    super.dispose();
  }
}
