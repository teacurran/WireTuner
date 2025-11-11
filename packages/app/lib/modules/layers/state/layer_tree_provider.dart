import 'package:flutter/foundation.dart';

/// Represents a single layer node in the layer tree.
///
/// Layers form a hierarchical structure supporting groups, masks, and clipping.
@immutable
class LayerNode {
  /// Unique identifier for the layer.
  final String layerId;

  /// Display name of the layer.
  final String name;

  /// Layer type (e.g., "Rectangle", "Path", "Group", "Mask").
  final String type;

  /// Whether this layer is visible.
  final bool isVisible;

  /// Whether this layer is locked (prevents editing).
  final bool isLocked;

  /// Whether this layer is currently selected.
  final bool isSelected;

  /// Whether this is a mask layer.
  final bool isMask;

  /// Whether this layer has clipping enabled.
  final bool isClipping;

  /// Child layers (for groups).
  final List<LayerNode> children;

  /// Depth level in tree (0 = root).
  final int depth;

  /// Whether this group is expanded (only relevant for groups).
  final bool isExpanded;

  const LayerNode({
    required this.layerId,
    required this.name,
    required this.type,
    this.isVisible = true,
    this.isLocked = false,
    this.isSelected = false,
    this.isMask = false,
    this.isClipping = false,
    this.children = const [],
    this.depth = 0,
    this.isExpanded = true,
  });

  LayerNode copyWith({
    String? layerId,
    String? name,
    String? type,
    bool? isVisible,
    bool? isLocked,
    bool? isSelected,
    bool? isMask,
    bool? isClipping,
    List<LayerNode>? children,
    int? depth,
    bool? isExpanded,
  }) {
    return LayerNode(
      layerId: layerId ?? this.layerId,
      name: name ?? this.name,
      type: type ?? this.type,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      isSelected: isSelected ?? this.isSelected,
      isMask: isMask ?? this.isMask,
      isClipping: isClipping ?? this.isClipping,
      children: children ?? this.children,
      depth: depth ?? this.depth,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerNode &&
          runtimeType == other.runtimeType &&
          layerId == other.layerId &&
          name == other.name &&
          type == other.type &&
          isVisible == other.isVisible &&
          isLocked == other.isLocked &&
          isSelected == other.isSelected &&
          isMask == other.isMask &&
          isClipping == other.isClipping &&
          depth == other.depth &&
          isExpanded == other.isExpanded;

  @override
  int get hashCode =>
      layerId.hashCode ^
      name.hashCode ^
      type.hashCode ^
      isVisible.hashCode ^
      isLocked.hashCode ^
      isSelected.hashCode ^
      isMask.hashCode ^
      isClipping.hashCode ^
      depth.hashCode ^
      isExpanded.hashCode;
}

/// Flattened layer node for efficient virtualized rendering.
///
/// The tree structure is flattened into a list based on expansion state,
/// allowing ListView.builder to efficiently handle large layer counts.
@immutable
class FlattenedLayerNode {
  final LayerNode node;
  final int flatIndex;
  final bool hasChildren;
  final bool isLastChild;

  const FlattenedLayerNode({
    required this.node,
    required this.flatIndex,
    this.hasChildren = false,
    this.isLastChild = false,
  });
}

/// Main state provider for the Layer Tree panel.
///
/// Manages layer hierarchy, selection, visibility, lock state, and tree
/// expansion. Provides flattened layer list for virtualized rendering.
///
/// ## Architecture
///
/// Follows the NavigatorProvider pattern:
/// - Extends ChangeNotifier for reactive UI updates
/// - Flattens tree structure for virtualization
/// - Provides clear mutation methods
/// - Dispatches layer commands through abstraction layer
///
/// ## Usage
///
/// ```dart
/// final layers = context.watch<LayerTreeProvider>();
///
/// // Access state
/// final flatLayers = layers.flattenedLayers;
/// final selected = layers.selectedLayerIds;
///
/// // Mutations
/// layers.toggleVisibility(layerId);
/// layers.renameLayer(layerId, newName);
/// layers.reorderLayer(layerId, newIndex);
/// ```
///
/// Related: FR-045, Section 6.2 LayerTree spec, Inspector wireframe
class LayerTreeProvider extends ChangeNotifier {
  /// Root layer nodes (top-level layers in artboard).
  final List<LayerNode> _rootLayers = [];

  /// Currently selected layer IDs.
  final Set<String> _selectedLayerIds = {};

  /// Layer ID to node lookup map (for fast access).
  final Map<String, LayerNode> _layerMap = {};

  /// Cached flattened layer list (for virtualization).
  List<FlattenedLayerNode> _flattenedCache = [];

  /// Whether the flattened cache needs rebuilding.
  bool _cacheInvalid = true;

  /// Search filter text.
  String _filterText = '';

  /// Callback for dispatching layer commands.
  final void Function(String command, Map<String, dynamic> data)? _commandDispatcher;

  LayerTreeProvider({
    void Function(String command, Map<String, dynamic> data)? commandDispatcher,
  }) : _commandDispatcher = commandDispatcher;

  // Getters

  /// Root layer nodes.
  List<LayerNode> get rootLayers => List.unmodifiable(_rootLayers);

  /// Flattened layer list for virtualized rendering.
  ///
  /// This list respects expansion state and filter text.
  /// Only expanded groups show their children.
  List<FlattenedLayerNode> get flattenedLayers {
    if (_cacheInvalid) {
      _rebuildFlattenedCache();
    }
    return List.unmodifiable(_flattenedCache);
  }

  /// Selected layer IDs.
  Set<String> get selectedLayerIds => Set.unmodifiable(_selectedLayerIds);

  /// Whether any layers are selected.
  bool get hasSelection => _selectedLayerIds.isNotEmpty;

  /// Total layer count (including collapsed children).
  int get totalLayerCount => _layerMap.length;

  /// Visible layer count (excluding collapsed children).
  int get visibleLayerCount => _flattenedCache.length;

  /// Current filter text.
  String get filterText => _filterText;

  // Layer Management

  /// Load layer tree from domain model.
  ///
  /// This is called when switching artboards or after document load.
  void loadLayers(List<LayerNode> layers) {
    _rootLayers.clear();
    _rootLayers.addAll(layers);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();
  }

  /// Add a new layer to the tree.
  void addLayer(LayerNode layer, {String? parentId}) {
    if (parentId == null) {
      _rootLayers.add(layer);
    } else {
      // Add to parent's children
      final parent = _layerMap[parentId];
      if (parent != null) {
        final updatedParent = parent.copyWith(
          children: [...parent.children, layer],
        );
        _replaceLayerInTree(parent.layerId, updatedParent);
      }
    }

    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('addLayer', {
      'layer': layer,
      'parentId': parentId,
    });
  }

  /// Remove a layer from the tree.
  void removeLayer(String layerId) {
    final layer = _layerMap[layerId];
    if (layer == null) return;

    _removeLayerFromTree(layerId);
    _selectedLayerIds.remove(layerId);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('removeLayer', {
      'layerId': layerId,
    });
  }

  /// Rename a layer.
  void renameLayer(String layerId, String newName) {
    final layer = _layerMap[layerId];
    if (layer == null) return;

    final updated = layer.copyWith(name: newName);
    _replaceLayerInTree(layerId, updated);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('renameLayer', {
      'layerId': layerId,
      'name': newName,
    });
  }

  /// Toggle layer visibility.
  void toggleVisibility(String layerId) {
    final layer = _layerMap[layerId];
    if (layer == null) return;

    final updated = layer.copyWith(isVisible: !layer.isVisible);
    _replaceLayerInTree(layerId, updated);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('toggleLayerVisibility', {
      'layerId': layerId,
      'isVisible': updated.isVisible,
    });
  }

  /// Toggle layer lock state.
  void toggleLock(String layerId) {
    final layer = _layerMap[layerId];
    if (layer == null) return;

    final updated = layer.copyWith(isLocked: !layer.isLocked);
    _replaceLayerInTree(layerId, updated);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('toggleLayerLock', {
      'layerId': layerId,
      'isLocked': updated.isLocked,
    });
  }

  /// Toggle group expansion state.
  void toggleExpansion(String layerId) {
    final layer = _layerMap[layerId];
    if (layer == null || layer.children.isEmpty) return;

    final updated = layer.copyWith(isExpanded: !layer.isExpanded);
    _replaceLayerInTree(layerId, updated);
    _rebuildLayerMap();
    _cacheInvalid = true;
    notifyListeners();
  }

  /// Select a layer (clears previous selection).
  void selectLayer(String layerId) {
    _selectedLayerIds.clear();
    _selectedLayerIds.add(layerId);
    _updateSelectionState();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('selectLayer', {
      'layerIds': [layerId],
    });
  }

  /// Toggle layer selection (for Cmd+Click multi-select).
  void toggleLayerSelection(String layerId) {
    if (_selectedLayerIds.contains(layerId)) {
      _selectedLayerIds.remove(layerId);
    } else {
      _selectedLayerIds.add(layerId);
    }
    _updateSelectionState();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('selectLayer', {
      'layerIds': _selectedLayerIds.toList(),
    });
  }

  /// Select a range of layers (for Shift+Click).
  void selectRange(String fromId, String toId) {
    final flatList = flattenedLayers;
    final fromIndex = flatList.indexWhere((n) => n.node.layerId == fromId);
    final toIndex = flatList.indexWhere((n) => n.node.layerId == toId);

    if (fromIndex == -1 || toIndex == -1) return;

    final start = fromIndex < toIndex ? fromIndex : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex;

    _selectedLayerIds.clear();
    for (var i = start; i <= end; i++) {
      _selectedLayerIds.add(flatList[i].node.layerId);
    }

    _updateSelectionState();
    _cacheInvalid = true;
    notifyListeners();

    _commandDispatcher?.call('selectLayer', {
      'layerIds': _selectedLayerIds.toList(),
    });
  }

  /// Clear selection.
  void clearSelection() {
    _selectedLayerIds.clear();
    _updateSelectionState();
    _cacheInvalid = true;
    notifyListeners();
  }

  /// Move layer up (forward in z-order).
  void moveLayerUp(String layerId) {
    // TODO: Implement reordering
    _commandDispatcher?.call('moveLayerUp', {'layerId': layerId});
  }

  /// Move layer down (backward in z-order).
  void moveLayerDown(String layerId) {
    // TODO: Implement reordering
    _commandDispatcher?.call('moveLayerDown', {'layerId': layerId});
  }

  /// Move layer to front.
  void moveLayerToFront(String layerId) {
    // TODO: Implement reordering
    _commandDispatcher?.call('moveLayerToFront', {'layerId': layerId});
  }

  /// Move layer to back.
  void moveLayerToBack(String layerId) {
    // TODO: Implement reordering
    _commandDispatcher?.call('moveLayerToBack', {'layerId': layerId});
  }

  /// Update filter text for layer search.
  void setFilterText(String text) {
    _filterText = text.toLowerCase();
    _cacheInvalid = true;
    notifyListeners();
  }

  // Private Helpers

  /// Rebuild layer lookup map.
  void _rebuildLayerMap() {
    _layerMap.clear();
    _buildLayerMapRecursive(_rootLayers);
  }

  void _buildLayerMapRecursive(List<LayerNode> layers) {
    for (final layer in layers) {
      _layerMap[layer.layerId] = layer;
      if (layer.children.isNotEmpty) {
        _buildLayerMapRecursive(layer.children);
      }
    }
  }

  /// Replace a layer in the tree.
  void _replaceLayerInTree(String layerId, LayerNode newNode) {
    final updatedLayers = _replaceLayerRecursive(_rootLayers, layerId, newNode);
    _rootLayers.clear();
    _rootLayers.addAll(updatedLayers);
  }

  List<LayerNode> _replaceLayerRecursive(
    List<LayerNode> layers,
    String targetId,
    LayerNode newNode,
  ) {
    return layers.map((layer) {
      if (layer.layerId == targetId) {
        return newNode;
      } else if (layer.children.isNotEmpty) {
        return layer.copyWith(
          children: _replaceLayerRecursive(layer.children, targetId, newNode),
        );
      }
      return layer;
    }).toList();
  }

  /// Remove a layer from the tree.
  void _removeLayerFromTree(String layerId) {
    final updatedLayers = _removeLayerRecursive(_rootLayers, layerId);
    _rootLayers.clear();
    _rootLayers.addAll(updatedLayers);
  }

  List<LayerNode> _removeLayerRecursive(List<LayerNode> layers, String targetId) {
    return layers
        .where((layer) => layer.layerId != targetId)
        .map((layer) {
          if (layer.children.isNotEmpty) {
            return layer.copyWith(
              children: _removeLayerRecursive(layer.children, targetId),
            );
          }
          return layer;
        })
        .toList();
  }

  /// Update selection state in layer nodes.
  void _updateSelectionState() {
    _rootLayers.clear();
    _rootLayers.addAll(_updateSelectionRecursive(_rootLayers));
    _rebuildLayerMap();
  }

  List<LayerNode> _updateSelectionRecursive(List<LayerNode> layers) {
    return layers.map((layer) {
      final isSelected = _selectedLayerIds.contains(layer.layerId);
      final updated = layer.copyWith(isSelected: isSelected);
      if (layer.children.isNotEmpty) {
        return updated.copyWith(
          children: _updateSelectionRecursive(layer.children),
        );
      }
      return updated;
    }).toList();
  }

  /// Rebuild flattened cache for virtualization.
  void _rebuildFlattenedCache() {
    _flattenedCache.clear();
    _flattenLayersRecursive(_rootLayers, 0);
    _cacheInvalid = false;
  }

  void _flattenLayersRecursive(List<LayerNode> layers, int depth) {
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final isLastChild = i == layers.length - 1;

      // Apply filter
      if (_filterText.isNotEmpty && !layer.name.toLowerCase().contains(_filterText)) {
        continue;
      }

      _flattenedCache.add(FlattenedLayerNode(
        node: layer,
        flatIndex: _flattenedCache.length,
        hasChildren: layer.children.isNotEmpty,
        isLastChild: isLastChild,
      ));

      // Recursively flatten children if expanded
      if (layer.isExpanded && layer.children.isNotEmpty) {
        _flattenLayersRecursive(layer.children, depth + 1);
      }
    }
  }

  @override
  void dispose() {
    _rootLayers.clear();
    _selectedLayerIds.clear();
    _layerMap.clear();
    _flattenedCache.clear();
    super.dispose();
  }
}
