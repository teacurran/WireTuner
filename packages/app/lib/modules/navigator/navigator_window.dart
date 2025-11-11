import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'state/navigator_provider.dart';
import 'state/navigator_service.dart';
import 'widgets/navigator_tabs.dart';
import 'widgets/artboard_grid.dart';

/// Main Navigator window widget.
///
/// Provides the top-level UI shell for multi-artboard document management,
/// including:
/// - Document tabs (top bar)
/// - Artboard grid (main area)
/// - Status bar (bottom)
/// - Keyboard shortcuts
///
/// ## Architecture
///
/// This widget acts as the composition root for the Navigator module:
/// - Provides NavigatorProvider and NavigatorService via Provider
/// - Coordinates keyboard shortcuts (Cmd+W for close, arrow keys for selection)
/// - Integrates with existing app shell (will be windowed via WindowManager in future)
///
/// ## Usage
///
/// ```dart
/// Navigator(
///   MaterialPageRoute(
///     builder: (_) => NavigatorWindow(
///       onClose: () => Navigator.of(context).pop(),
///     ),
///   ),
/// );
/// ```
///
/// Related: Flow C (Multi-Artboard Document Load), FR-029–FR-044
class NavigatorWindow extends StatefulWidget {
  /// Callback when window close is requested.
  final VoidCallback? onClose;

  const NavigatorWindow({
    Key? key,
    this.onClose,
  }) : super(key: key);

  @override
  State<NavigatorWindow> createState() => _NavigatorWindowState();
}

class _NavigatorWindowState extends State<NavigatorWindow> {
  late NavigatorProvider _navigatorProvider;
  late NavigatorService _navigatorService;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _navigatorService = NavigatorService(
      telemetryCallback: (metric, data) {
        // TODO: Wire to TelemetryService in future iteration
        debugPrint('Telemetry: $metric $data');
      },
    );

    _navigatorProvider = NavigatorProvider();

    // Listen to action events and handle them
    _navigatorService.actionStream.listen(_handleArtboardAction);

    // Request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _navigatorService.dispose();
    _navigatorProvider.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleArtboardAction(ArtboardActionEvent event) {
    // TODO: Dispatch to EventStore/InteractionEngine
    // For now, just log the action
    debugPrint('Artboard action: $event');

    // Handle UI-specific actions immediately
    switch (event.action) {
      case ArtboardAction.rename:
        // Rename is handled inline in ArtboardCard
        break;
      case ArtboardAction.duplicate:
        // Would trigger document model update + grid refresh
        break;
      case ArtboardAction.delete:
        // Would remove artboards from provider
        break;
      case ArtboardAction.refresh:
        // Trigger thumbnail regeneration
        final artboardId = event.artboardIds.first;
        _navigatorProvider.refreshThumbnailNow(
          artboardId,
          () => MockThumbnailGenerator.generate(artboardId, 200, 200),
        );
        break;
      case ArtboardAction.fitToView:
        // Would restore viewport via ViewportController
        break;
      case ArtboardAction.copyToDocument:
      case ArtboardAction.exportAs:
        // Future features
        break;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCmd = event.logicalKey == LogicalKeyboardKey.meta ||
        event.logicalKey == LogicalKeyboardKey.control;

    // Cmd+W: Close window
    if (isCmd && event.logicalKey == LogicalKeyboardKey.keyW) {
      widget.onClose?.call();
      return;
    }

    // Arrow keys: Navigate grid
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // TODO: Implement grid keyboard navigation
      // This would select adjacent artboards based on grid layout
    }

    // Delete/Backspace: Delete selected artboards
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final selected = _navigatorProvider.selectedArtboards.toList();
      if (selected.isNotEmpty) {
        _navigatorService.deleteArtboards(
          selected,
          confirmCallback: (count) => _showDeleteConfirmation(count),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(int count) async {
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _navigatorProvider),
        Provider.value(value: _navigatorService),
      ],
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              // Document tabs
              const NavigatorTabs(),

              // Main artboard grid
              Expanded(
                child: _buildMainArea(),
              ),

              // Status bar
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea() {
    return Consumer<NavigatorProvider>(
      builder: (context, navigator, _) {
        final activeDocId = navigator.activeDocumentId;

        if (activeDocId == null) {
          return _buildEmptyState();
        }

        final artboards = navigator.getArtboards(activeDocId);

        if (artboards.isEmpty) {
          return _buildEmptyState(message: 'No artboards in this document');
        }

        return ArtboardGrid(
          documentId: activeDocId,
          artboards: artboards,
        );
      },
    );
  }

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No documents open',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Consumer<NavigatorProvider>(
      builder: (context, navigator, _) {
        final selectionCount = navigator.selectedArtboards.length;
        final activeDoc = navigator.activeDocument;
        final artboardCount = activeDoc?.artboardIds.length ?? 0;

        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              // Selection count
              Text(
                selectionCount > 0
                    ? '$selectionCount of $artboardCount selected'
                    : '$artboardCount artboards',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              // Grid zoom controls (future feature)
              // For now, just show grid config
              Text(
                '${navigator.gridConfig.columns} columns',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
