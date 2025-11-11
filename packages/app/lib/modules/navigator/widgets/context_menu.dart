import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/navigator_provider.dart';
import '../state/navigator_service.dart';

/// Builds the context menu for artboard cards.
///
/// Provides actions like:
/// - Rename
/// - Duplicate
/// - Delete
/// - Refresh Thumbnail
/// - Fit to View
/// - Copy to Document (future)
/// - Export As (future)
///
/// Menu items are dynamically enabled/disabled based on selection state.
///
/// ## Usage
///
/// ```dart
/// showMenu(
///   context: context,
///   position: RelativeRect.fromLTRB(...),
///   items: buildArtboardContextMenu(
///     context: context,
///     artboardId: artboardId,
///     onRename: () { /* start inline edit */ },
///   ),
/// );
/// ```
///
/// Related: Journey H, NavigatorGrid organism
List<PopupMenuEntry<ArtboardMenuAction>> buildArtboardContextMenu({
  required BuildContext context,
  required String artboardId,
  VoidCallback? onRename,
}) {
  final navigator = context.read<NavigatorProvider>();
  final service = context.read<NavigatorService>();
  final selectedCount = navigator.selectedArtboards.length;

  // Determine if multi-select is active
  final isMultiSelect = selectedCount > 1;
  final targetIds = isMultiSelect
      ? navigator.selectedArtboards.toList()
      : [artboardId];

  return [
    // Rename (only for single selection)
    if (!isMultiSelect)
      PopupMenuItem(
        value: ArtboardMenuAction.rename,
        child: const Row(
          children: [
            Icon(Icons.edit, size: 18),
            SizedBox(width: 12),
            Text('Rename'),
          ],
        ),
        onTap: () {
          // Delay to allow menu to close first
          Future.delayed(const Duration(milliseconds: 100), () {
            onRename?.call();
          });
        },
      ),

    // Duplicate
    PopupMenuItem(
      value: ArtboardMenuAction.duplicate,
      child: Row(
        children: [
          const Icon(Icons.content_copy, size: 18),
          const SizedBox(width: 12),
          Text(isMultiSelect
              ? 'Duplicate $selectedCount Artboards'
              : 'Duplicate'),
        ],
      ),
      onTap: () {
        Future.delayed(const Duration(milliseconds: 100), () {
          service.duplicateArtboards(targetIds);
        });
      },
    ),

    // Divider
    const PopupMenuDivider(),

    // Refresh Thumbnail (only for single selection)
    if (!isMultiSelect)
      PopupMenuItem(
        value: ArtboardMenuAction.refresh,
        child: const Row(
          children: [
            Icon(Icons.refresh, size: 18),
            SizedBox(width: 12),
            Text('Refresh Thumbnail'),
          ],
        ),
        onTap: () {
          Future.delayed(const Duration(milliseconds: 100), () {
            service.requestThumbnailRefresh(artboardId);
          });
        },
      ),

    // Fit to View (only for single selection)
    if (!isMultiSelect)
      PopupMenuItem(
        value: ArtboardMenuAction.fitToView,
        child: const Row(
          children: [
            Icon(Icons.fit_screen, size: 18),
            SizedBox(width: 12),
            Text('Fit to View'),
          ],
        ),
        onTap: () {
          Future.delayed(const Duration(milliseconds: 100), () {
            service.fitToView(artboardId);
          });
        },
      ),

    // Divider
    const PopupMenuDivider(),

    // Delete
    PopupMenuItem(
      value: ArtboardMenuAction.delete,
      child: Row(
        children: [
          const Icon(Icons.delete, size: 18, color: Colors.red),
          const SizedBox(width: 12),
          Text(
            isMultiSelect
                ? 'Delete $selectedCount Artboards'
                : 'Delete',
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
      onTap: () {
        Future.delayed(const Duration(milliseconds: 100), () {
          service.deleteArtboards(
            targetIds,
            confirmCallback: (count) => _showDeleteConfirmation(context, count),
          );
        });
      },
    ),

    // Future features (disabled for now)
    const PopupMenuDivider(),
    PopupMenuItem(
      value: ArtboardMenuAction.copyToDocument,
      enabled: false,
      child: Row(
        children: [
          Icon(Icons.copy_all, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('Copy to Document...', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    ),
    PopupMenuItem(
      value: ArtboardMenuAction.exportAs,
      enabled: false,
      child: Row(
        children: [
          Icon(Icons.download, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('Export As...', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    ),
  ];
}

/// Context menu actions enum.
enum ArtboardMenuAction {
  rename,
  duplicate,
  delete,
  refresh,
  fitToView,
  copyToDocument,
  exportAs,
}

/// Show delete confirmation dialog.
Future<bool> _showDeleteConfirmation(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Artboards'),
      content: Text(
        count == 1
            ? 'Are you sure you want to delete this artboard?'
            : 'Are you sure you want to delete $count artboards?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return result ?? false;
}
