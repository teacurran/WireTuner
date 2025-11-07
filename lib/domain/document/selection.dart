import 'package:freezed_annotation/freezed_annotation.dart';

part 'selection.freezed.dart';
part 'selection.g.dart';

/// Represents an immutable selection state in the document.
///
/// A selection tracks:
/// - Which vector objects are selected (by object ID)
/// - Which anchor points are selected within those objects
///
/// ## Design Rationale
///
/// Selection is a value object that can be snapshotted along with the document
/// state. This enables:
/// - Undo/redo of selection changes
/// - Selection state persistence in snapshots
/// - Deterministic replay of selection events
///
/// ## Immutability
///
/// This class uses Freezed for:
/// - Automatic immutability enforcement
/// - copyWith method generation for creating modified selections
/// - Deep equality comparison
/// - JSON serialization support for snapshot persistence
///
/// ## Examples
///
/// Create an empty selection:
/// ```dart
/// final selection = Selection.empty();
/// assert(selection.isEmpty);
/// ```
///
/// Select a single object:
/// ```dart
/// final selection = Selection(
///   objectIds: {'object-123'},
/// );
/// assert(selection.contains('object-123'));
/// ```
///
/// Select specific anchor points within objects:
/// ```dart
/// final selection = Selection(
///   objectIds: {'path-1'},
///   anchorIndices: {
///     'path-1': {0, 2, 5},  // Anchors at indices 0, 2, and 5
///   },
/// );
/// ```
///
/// Add to selection:
/// ```dart
/// final updated = selection.addObject('object-456');
/// ```
@freezed
class Selection with _$Selection {
  const factory Selection({
    /// Set of selected object IDs.
    ///
    /// Each ID corresponds to a VectorObject (Path or Shape) in the document.
    /// Using a Set ensures uniqueness and O(1) lookup performance.
    @Default({}) Set<String> objectIds,

    /// Map of object ID to selected anchor point indices.
    ///
    /// This allows selecting individual anchor points within a path for
    /// direct manipulation. Keys are object IDs, values are sets of
    /// zero-based anchor indices.
    ///
    /// Example:
    /// ```dart
    /// {
    ///   'path-1': {0, 2, 5},  // Anchors 0, 2, 5 selected in path-1
    ///   'path-2': {1},         // Anchor 1 selected in path-2
    /// }
    /// ```
    @Default({}) Map<String, Set<int>> anchorIndices,
  }) = _Selection;

  /// Private constructor for accessing methods on Freezed class.
  const Selection._();

  /// Creates a Selection from JSON.
  ///
  /// Note: Freezed handles Set/Map serialization automatically using
  /// json_serializable's support for collections.
  factory Selection.fromJson(Map<String, dynamic> json) =>
      _$SelectionFromJson(json);

  /// Creates an empty selection with no objects or anchors selected.
  factory Selection.empty() => const Selection();

  /// Returns true if no objects are selected.
  bool get isEmpty => objectIds.isEmpty;

  /// Returns true if any objects are selected.
  bool get isNotEmpty => objectIds.isNotEmpty;

  /// Returns the number of selected objects.
  int get selectedCount => objectIds.length;

  /// Returns true if the given object ID is selected.
  bool contains(String objectId) => objectIds.contains(objectId);

  /// Returns true if the given object has any anchor points selected.
  bool hasSelectedAnchors(String objectId) =>
      anchorIndices.containsKey(objectId) &&
      anchorIndices[objectId]!.isNotEmpty;

  /// Returns the set of selected anchor indices for the given object.
  ///
  /// Returns an empty set if no anchors are selected for this object.
  Set<int> getSelectedAnchors(String objectId) =>
      anchorIndices[objectId] ?? {};

  /// Creates a new selection with the given object added.
  ///
  /// If the object is already selected, returns the current selection unchanged.
  Selection addObject(String objectId) {
    if (objectIds.contains(objectId)) {
      return this;
    }
    return copyWith(
      objectIds: {...objectIds, objectId},
    );
  }

  /// Creates a new selection with the given objects added.
  Selection addObjects(Iterable<String> ids) {
    return copyWith(
      objectIds: {...objectIds, ...ids},
    );
  }

  /// Creates a new selection with the given object removed.
  ///
  /// Also removes any anchor point selections for this object.
  Selection removeObject(String objectId) {
    if (!objectIds.contains(objectId)) {
      return this;
    }
    final newObjectIds = Set<String>.from(objectIds)..remove(objectId);
    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices)
      ..remove(objectId);
    return copyWith(
      objectIds: newObjectIds,
      anchorIndices: newAnchorIndices,
    );
  }

  /// Creates a new selection with the given objects removed.
  Selection removeObjects(Iterable<String> ids) {
    final idsSet = ids.toSet();
    final newObjectIds = objectIds.difference(idsSet);
    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices)
      ..removeWhere((key, _) => idsSet.contains(key));
    return copyWith(
      objectIds: newObjectIds,
      anchorIndices: newAnchorIndices,
    );
  }

  /// Creates a new selection with only the given object selected.
  ///
  /// Clears all other selections.
  Selection selectOnly(String objectId) {
    return Selection(objectIds: {objectId});
  }

  /// Creates a new selection with only the given objects selected.
  ///
  /// Clears all other selections.
  Selection selectOnlyMultiple(Iterable<String> ids) {
    return Selection(objectIds: ids.toSet());
  }

  /// Creates a new selection with all selections cleared.
  Selection clear() => Selection.empty();

  /// Creates a new selection with the given anchor added to the object's selection.
  ///
  /// Also ensures the object itself is selected.
  Selection addAnchor(String objectId, int anchorIndex) {
    final currentAnchors = getSelectedAnchors(objectId);
    if (currentAnchors.contains(anchorIndex)) {
      return this; // Already selected
    }

    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices);
    newAnchorIndices[objectId] = {...currentAnchors, anchorIndex};

    return copyWith(
      objectIds: {...objectIds, objectId}, // Ensure object is selected
      anchorIndices: newAnchorIndices,
    );
  }

  /// Creates a new selection with the given anchors added to the object's selection.
  Selection addAnchors(String objectId, Iterable<int> indices) {
    final currentAnchors = getSelectedAnchors(objectId);
    final newAnchors = {...currentAnchors, ...indices};

    if (currentAnchors.length == newAnchors.length) {
      return this; // No new anchors added
    }

    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices);
    newAnchorIndices[objectId] = newAnchors;

    return copyWith(
      objectIds: {...objectIds, objectId}, // Ensure object is selected
      anchorIndices: newAnchorIndices,
    );
  }

  /// Creates a new selection with the given anchor removed from the object's selection.
  Selection removeAnchor(String objectId, int anchorIndex) {
    final currentAnchors = getSelectedAnchors(objectId);
    if (!currentAnchors.contains(anchorIndex)) {
      return this; // Not selected
    }

    final newAnchors = Set<int>.from(currentAnchors)..remove(anchorIndex);
    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices);

    if (newAnchors.isEmpty) {
      newAnchorIndices.remove(objectId);
    } else {
      newAnchorIndices[objectId] = newAnchors;
    }

    return copyWith(anchorIndices: newAnchorIndices);
  }

  /// Creates a new selection with all anchor selections cleared for all objects.
  Selection clearAnchors() {
    return copyWith(anchorIndices: {});
  }

  /// Creates a new selection with anchor selections cleared for a specific object.
  Selection clearAnchorsForObject(String objectId) {
    if (!anchorIndices.containsKey(objectId)) {
      return this;
    }
    final newAnchorIndices = Map<String, Set<int>>.from(anchorIndices)
      ..remove(objectId);
    return copyWith(anchorIndices: newAnchorIndices);
  }
}
