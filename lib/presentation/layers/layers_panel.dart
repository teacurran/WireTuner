import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/events/selection_events.dart';
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:uuid/uuid.dart';

/// Panel displaying the layer hierarchy with objects nested under each layer.
///
/// Allows users to:
/// - See all layers in the artboard
/// - Expand/collapse layers to see objects
/// - Select layers (to make them the active layer for new objects)
/// - Select objects by clicking on them
/// - See which objects are currently selected
class LayersPanel extends StatefulWidget {
  const LayersPanel({super.key});

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  // Track which layers are expanded
  final Set<String> _expandedLayers = {};

  // Track the active layer ID (where new objects will be created)
  String? _activeLayerId;

  @override
  Widget build(BuildContext context) {
    final documentProvider = context.watch<DocumentProvider>();
    final document = documentProvider.document;

    // Get the first artboard
    final artboard = document.artboards.isNotEmpty
        ? document.artboards.first
        : null;

    if (artboard == null) {
      return Container(
        width: 200,
        color: Colors.grey[300],
        child: const Center(
          child: Text('No artboard'),
        ),
      );
    }

    // Set default active layer if not set
    if (_activeLayerId == null && artboard.layers.isNotEmpty) {
      _activeLayerId = artboard.layers.first.id;
    }

    // Count total objects across all layers
    int totalObjects = 0;
    for (final layer in artboard.layers) {
      totalObjects += layer.objects.length;
    }

    return Container(
      width: 200,
      color: Colors.grey[300],
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[400],
            child: Row(
              children: [
                const Icon(Icons.layers, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Layers',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalObjects',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Layer list
          Expanded(
            child: artboard.layers.isEmpty
                ? const Center(
                    child: Text(
                      'No layers',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: artboard.layers.length,
                    itemBuilder: (context, index) {
                      final layer = artboard.layers[index];
                      final isExpanded = _expandedLayers.contains(layer.id);
                      final isActive = layer.id == _activeLayerId;

                      return _LayerItem(
                        layer: layer,
                        isExpanded: isExpanded,
                        isActive: isActive,
                        selection: artboard.selection,
                        onToggleExpand: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedLayers.remove(layer.id);
                            } else {
                              _expandedLayers.add(layer.id);
                            }
                          });
                        },
                        onSelectLayer: () {
                          setState(() {
                            _activeLayerId = layer.id;
                          });
                        },
                        onSelectObject: (objectId) =>
                            _selectObject(context, objectId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _selectObject(BuildContext context, String objectId) {
    final documentProvider = context.read<DocumentProvider>();

    // Update the selection to this object only
    documentProvider.updateSelection(
      Selection(objectIds: {objectId}),
    );
  }
}

/// Widget that displays a single layer with its nested objects.
class _LayerItem extends StatelessWidget {
  final Layer layer;
  final bool isExpanded;
  final bool isActive;
  final Selection selection;
  final VoidCallback onToggleExpand;
  final VoidCallback onSelectLayer;
  final void Function(String objectId) onSelectObject;

  const _LayerItem({
    required this.layer,
    required this.isExpanded,
    required this.isActive,
    required this.selection,
    required this.onToggleExpand,
    required this.onSelectLayer,
    required this.onSelectObject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Layer header
        InkWell(
          onTap: onSelectLayer,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue[100] : Colors.grey[350],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[400]!,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse button
                InkWell(
                  onTap: onToggleExpand,
                  child: Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                // Layer icon
                Icon(
                  Icons.layers,
                  size: 14,
                  color: isActive ? Colors.blue[900] : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                // Layer name
                Expanded(
                  child: Text(
                    layer.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.blue[900] : Colors.black87,
                    ),
                  ),
                ),
                // Object count
                Text(
                  '${layer.objects.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                // Visibility toggle
                Icon(
                  layer.visible ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),

        // Objects list (shown when expanded)
        if (isExpanded)
          ...layer.objects.map((obj) {
            final isSelected = selection.contains(obj.id);
            return _ObjectListItem(
              object: obj,
              isSelected: isSelected,
              onTap: () => onSelectObject(obj.id),
            );
          }).toList(),
      ],
    );
  }
}

/// List item for displaying a single object nested under a layer.
class _ObjectListItem extends StatelessWidget {
  final VectorObject object;
  final bool isSelected;
  final VoidCallback onTap;

  const _ObjectListItem({
    required this.object,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getIcon() {
    return object.when(
      path: (id, path, transform) => Icons.timeline,
      shape: (id, shape, transform) {
        switch (shape.kind) {
          case ShapeKind.rectangle:
            return Icons.crop_square;
          case ShapeKind.ellipse:
            return Icons.circle_outlined;
          case ShapeKind.polygon:
            return Icons.hexagon_outlined;
          case ShapeKind.star:
            return Icons.star_border;
        }
      },
    );
  }

  String _getTypeLabel() {
    return object.when(
      path: (id, path, transform) => 'Path',
      shape: (id, shape, transform) => shape.kind.name.toUpperCase(),
    );
  }

  int _getAnchorCount() {
    return object.when(
      path: (id, path, transform) => path.anchors.length,
      shape: (id, shape, transform) => 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 28, right: 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : null,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[350]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getIcon(),
              size: 14,
              color: isSelected ? Colors.blue[900] : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTypeLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                    ),
                  ),
                  Text(
                    object.id.substring(0, 8),
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (_getAnchorCount() > 0)
              Text(
                '${_getAnchorCount()}',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
