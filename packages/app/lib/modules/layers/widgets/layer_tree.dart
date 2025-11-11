import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/layer_tree_provider.dart';

/// Virtualized layer tree widget.
///
/// Displays hierarchical layer structure with:
/// - Virtualization for 100+ layers (ListView.builder)
/// - Inline rename (double-click)
/// - Visibility/lock toggles
/// - Multi-select support
/// - Keyboard navigation
/// - Accessibility labels
///
/// Related: Section 6.2 LayerTree, FR-045
class LayerTree extends StatefulWidget {
  const LayerTree({Key? key}) : super(key: key);

  @override
  State<LayerTree> createState() => _LayerTreeState();
}

class _LayerTreeState extends State<LayerTree> {
  final ScrollController _scrollController = ScrollController();
  String? _lastSelectedId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, LayerTreeProvider provider) {
    if (event is! KeyDownEvent) return;

    final selected = provider.selectedLayerIds;
    if (selected.isEmpty) return;

    final lastId = _lastSelectedId ?? selected.first;

    // Cmd+] / Ctrl+] - Move layer forward
    if ((event.logicalKey == LogicalKeyboardKey.bracketRight) &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        provider.moveLayerToFront(lastId);
      } else {
        provider.moveLayerUp(lastId);
      }
    }
    // Cmd+[ / Ctrl+[ - Move layer backward
    else if ((event.logicalKey == LogicalKeyboardKey.bracketLeft) &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        provider.moveLayerToBack(lastId);
      } else {
        provider.moveLayerDown(lastId);
      }
    }
    // Delete/Backspace - Remove layer
    else if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      for (final layerId in selected) {
        provider.removeLayer(layerId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LayerTreeProvider>(
      builder: (context, provider, _) {
        final flatLayers = provider.flattenedLayers;

        if (flatLayers.isEmpty) {
          return _buildEmptyState(context);
        }

        return Semantics(
          label: 'Layer tree',
          container: true,
          child: KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKeyEvent: (event) => _handleKeyEvent(event, provider),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: flatLayers.length,
              itemExtent: 32, // Dense row height (tokens.spacing.6 * 4)
              itemBuilder: (context, index) {
                final flatNode = flatLayers[index];
                return _LayerTreeRow(
                  node: flatNode.node,
                  onTap: () {
                    _lastSelectedId = flatNode.node.layerId;
                    provider.selectLayer(flatNode.node.layerId);
                  },
                  onToggleTap: (isShift) {
                    if (isShift && _lastSelectedId != null) {
                      provider.selectRange(_lastSelectedId!, flatNode.node.layerId);
                    } else {
                      provider.toggleLayerSelection(flatNode.node.layerId);
                    }
                  },
                  onVisibilityToggle: () {
                    provider.toggleVisibility(flatNode.node.layerId);
                  },
                  onLockToggle: () {
                    provider.toggleLock(flatNode.node.layerId);
                  },
                  onExpansionToggle: flatNode.hasChildren
                      ? () {
                          provider.toggleExpansion(flatNode.node.layerId);
                        }
                      : null,
                  onRename: (newName) {
                    provider.renameLayer(flatNode.node.layerId, newName);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: 'No layers in this artboard',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No layers',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual layer tree row widget.
///
/// Displays layer name, icons, and toggles.
class _LayerTreeRow extends StatefulWidget {
  final LayerNode node;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleTap;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onLockToggle;
  final VoidCallback? onExpansionToggle;
  final ValueChanged<String> onRename;

  const _LayerTreeRow({
    required this.node,
    required this.onTap,
    required this.onToggleTap,
    required this.onVisibilityToggle,
    required this.onLockToggle,
    this.onExpansionToggle,
    required this.onRename,
  });

  @override
  State<_LayerTreeRow> createState() => _LayerTreeRowState();
}

class _LayerTreeRowState extends State<_LayerTreeRow> {
  bool _isRenaming = false;
  late TextEditingController _renameController;
  late FocusNode _renameFocusNode;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.node.name);
    _renameFocusNode = FocusNode();
    _renameFocusNode.addListener(_onRenameFocusChanged);
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  void _onRenameFocusChanged() {
    if (!_renameFocusNode.hasFocus && _isRenaming) {
      _commitRename();
    }
  }

  void _commitRename() {
    final newName = _renameController.text.trim();
    if (newName.isNotEmpty && newName != widget.node.name) {
      widget.onRename(newName);
    }
    setState(() {
      _isRenaming = false;
    });
  }

  void _startRename() {
    setState(() {
      _isRenaming = true;
      _renameController.text = widget.node.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocusNode.requestFocus();
      _renameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _renameController.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = widget.node.depth * 16.0;

    return Semantics(
      label: '${widget.node.name}, ${widget.node.type}${widget.node.isLocked ? ", locked" : ""}${!widget.node.isVisible ? ", hidden" : ""}',
      selected: widget.node.isSelected,
      container: true,
      child: GestureDetector(
        onTap: () {
          if (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed) {
            widget.onToggleTap(false);
          } else if (HardwareKeyboard.instance.isShiftPressed) {
            widget.onToggleTap(true);
          } else {
            widget.onTap();
          }
        },
        onDoubleTap: widget.node.isLocked ? null : _startRename,
        child: Container(
          height: 32,
          padding: EdgeInsets.only(left: indent),
          decoration: BoxDecoration(
            color: widget.node.isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Expansion toggle (for groups)
              if (widget.onExpansionToggle != null)
                Semantics(
                  label: widget.node.isExpanded ? 'Collapse group' : 'Expand group',
                  button: true,
                  child: GestureDetector(
                    onTap: widget.onExpansionToggle,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(
                        widget.node.isExpanded
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 20),

              const SizedBox(width: 4),

              // Layer type icon
              Icon(
                _getIconForType(widget.node.type),
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),

              const SizedBox(width: 6),

              // Layer name (editable)
              Expanded(
                child: _isRenaming
                    ? Semantics(
                        label: 'Rename layer',
                        textField: true,
                        child: TextField(
                          controller: _renameController,
                          focusNode: _renameFocusNode,
                          style: theme.textTheme.bodySmall,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _commitRename(),
                        ),
                      )
                    : Text(
                        widget.node.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.node.isLocked
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),

              const SizedBox(width: 4),

              // Lock toggle
              Semantics(
                label: widget.node.isLocked ? 'Unlock layer' : 'Lock layer',
                button: true,
                child: GestureDetector(
                  onTap: widget.onLockToggle,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      widget.node.isLocked ? Icons.lock : Icons.lock_open_outlined,
                      size: 14,
                      color: widget.node.isLocked
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),
              ),

              // Visibility toggle
              Semantics(
                label: widget.node.isVisible ? 'Hide layer' : 'Show layer',
                button: true,
                child: GestureDetector(
                  onTap: widget.onVisibilityToggle,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      widget.node.isVisible
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      size: 14,
                      color: widget.node.isVisible
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Group':
        return Icons.folder_outlined;
      case 'Rectangle':
        return Icons.crop_square;
      case 'Path':
        return Icons.timeline;
      case 'Mask':
        return Icons.masks;
      default:
        return Icons.layers_outlined;
    }
  }
}
