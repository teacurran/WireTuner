import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/navigator_provider.dart';
import '../state/navigator_service.dart';
import 'context_menu.dart';

/// Individual artboard card widget.
///
/// Displays:
/// - Thumbnail image with loading placeholder
/// - Artboard title (editable on double-click)
/// - Dimensions label
/// - Modified indicator
/// - Selection highlighting
/// - Context menu on right-click
///
/// ## States
/// - Normal: Default appearance
/// - Selected: Blue border + background tint
/// - Hovered: Subtle elevation + border highlight
/// - Editing: Inline text field for rename
///
/// Related: FR-029–FR-044, NavigatorGrid organism
class ArtboardCard extends StatefulWidget {
  final ArtboardCardState artboard;
  final bool isSelected;

  const ArtboardCard({
    Key? key,
    required this.artboard,
    required this.isSelected,
  }) : super(key: key);

  @override
  State<ArtboardCard> createState() => _ArtboardCardState();
}

class _ArtboardCardState extends State<ArtboardCard> {
  bool _isHovered = false;
  bool _isEditing = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.artboard.title);
    _titleFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(ArtboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artboard.title != oldWidget.artboard.title && !_isEditing) {
      _titleController.text = widget.artboard.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_titleFocusNode.hasFocus && _isEditing) {
      _commitRename();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _titleController.text = widget.artboard.title;
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });

    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  Future<void> _commitRename() async {
    final newName = _titleController.text.trim();
    if (newName.isEmpty || newName == widget.artboard.title) {
      setState(() => _isEditing = false);
      return;
    }

    final service = context.read<NavigatorService>();
    final error = await service.renameArtboard(widget.artboard.artboardId, newName);

    if (error != null && mounted) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      _titleController.text = widget.artboard.title;
    } else if (mounted) {
      // Update provider state
      final navigator = context.read<NavigatorProvider>();
      navigator.updateArtboard(
        artboardId: widget.artboard.artboardId,
        title: newName,
      );
    }

    setState(() => _isEditing = false);
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: buildArtboardContextMenu(
        context: context,
        artboardId: widget.artboard.artboardId,
        onRename: _startEditing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer.withOpacity(0.3)
                : colorScheme.surface,
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _isHovered
                      ? colorScheme.outline
                      : colorScheme.outlineVariant,
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered && !widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail
              Expanded(
                child: _buildThumbnail(colorScheme),
              ),

              // Metadata
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _buildTitle(theme),
                    const SizedBox(height: 4),

                    // Dimensions + Dirty indicator
                    Row(
                      children: [
                        Text(
                          '${widget.artboard.dimensions.width.toInt()} × ${widget.artboard.dimensions.height.toInt()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (widget.artboard.isDirty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    final thumbnail = widget.artboard.thumbnail;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      child: Container(
        color: colorScheme.surfaceVariant,
        child: thumbnail != null
            ? _buildThumbnailImage(thumbnail)
            : _buildPlaceholder(colorScheme),
      ),
    );
  }

  Widget _buildThumbnailImage(Uint8List data) {
    return Image.memory(
      data,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(Theme.of(context).colorScheme);
      },
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    if (_isEditing) {
      return TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _commitRename(),
        onEditingComplete: _commitRename,
      );
    }

    return GestureDetector(
      onDoubleTap: _startEditing,
      child: Text(
        widget.artboard.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
