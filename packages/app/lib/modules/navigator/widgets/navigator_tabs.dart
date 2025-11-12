import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/navigator_provider.dart';

/// Document tab bar widget for the Navigator window.
///
/// Displays a horizontal scrollable list of open document tabs with:
/// - Active tab highlighting
/// - Dirty indicators (unsaved changes)
/// - Close buttons
/// - Path tooltips on hover
///
/// ## Behavior
/// - Click to switch documents
/// - Cmd+W or close button to close tabs
/// - Shows dirty indicator (dot) when document has unsaved changes
///
/// Related: Section 6.3 (Navigation & Window Chrome)
class NavigatorTabs extends StatelessWidget {
  const NavigatorTabs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigatorProvider>(
      builder: (context, navigator, _) {
        final tabs = navigator.openDocuments;

        if (tabs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final isActive = tab.documentId == navigator.activeDocumentId;

              return _TabItem(
                tab: tab,
                isActive: isActive,
                onTap: () {
                  navigator.switchToDocument(tab.documentId);
                },
                onClose: () {
                  _handleCloseTab(context, navigator, tab);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleCloseTab(
    BuildContext context,
    NavigatorProvider navigator,
    DocumentTab tab,
  ) async {
    // If dirty, ask for confirmation
    if (tab.isDirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'Do you want to save changes to "${tab.name}" before closing?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Don\'t Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Trigger save operation
                Navigator.of(context).pop(false);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        return; // User cancelled
      }
    }

    navigator.closeDocument(tab.documentId);
  }
}

class _TabItem extends StatefulWidget {
  final DocumentTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: widget.tab.path,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 120,
              maxWidth: 200,
            ),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? colorScheme.surface
                  : _isHovered
                      ? colorScheme.surfaceVariant.withOpacity(0.8)
                      : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.isActive
                      ? colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dirty indicator
                if (widget.tab.isDirty) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Tab name
                Flexible(
                  child: Text(
                    widget.tab.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                      color: widget.isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),

                // Close button (shown on hover or if active)
                if (_isHovered || widget.isActive) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
