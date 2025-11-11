import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/canvas/wiretuner_canvas.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'window_manager.dart';
import 'window_descriptor.dart';

/// Window for editing a single artboard.
///
/// ArtboardWindow wraps the WireTunerCanvas and handles:
/// - Window registration and lifecycle with WindowManager
/// - Per-artboard viewport state persistence (Journey 15)
/// - Per-artboard selection isolation (Journey 16)
/// - Silent close without confirmation (FR-040)
/// - Focus/blur events for viewport persistence
///
/// ## Usage
///
/// ```dart
/// MaterialPageRoute(
///   builder: (_) => ArtboardWindow(
///     documentId: 'doc123',
///     artboardId: 'art456',
///     artboard: document.artboards['art456'],
///   ),
/// )
/// ```
///
/// Related: FR-040, Journey 15-16, Journey 18
class ArtboardWindow extends StatefulWidget {
  /// Creates an artboard editing window.
  const ArtboardWindow({
    Key? key,
    required this.documentId,
    required this.artboardId,
    required this.documentName,
    required this.artboardName,
    this.initialViewportState,
  }) : super(key: key);

  /// Document this artboard belongs to.
  final String documentId;

  /// Artboard being edited.
  final String artboardId;

  /// Document name for window title.
  final String documentName;

  /// Artboard name for window title.
  final String artboardName;

  /// Initial viewport state (restored from persistence).
  ///
  /// Per Journey 15: each artboard remembers its last viewport independently.
  final ViewportSnapshot? initialViewportState;

  @override
  State<ArtboardWindow> createState() => _ArtboardWindowState();
}

class _ArtboardWindowState extends State<ArtboardWindow> {
  late String _windowId;
  late ViewportController _viewportController;
  late FocusNode _focusNode;
  WindowManager? _windowManager;

  @override
  void initState() {
    super.initState();

    _windowId = 'art-${widget.documentId}-${widget.artboardId}';
    _focusNode = FocusNode();

    // Initialize viewport controller with restored state or defaults
    final initialState = widget.initialViewportState;
    _viewportController = ViewportController(
      initialPan: initialState?.panOffset ?? Offset.zero,
      initialZoom: initialState?.zoom ?? 1.0,
    );

    // Listen to focus changes
    _focusNode.addListener(_handleFocusChanged);

    // Listen to viewport changes to persist state
    _viewportController.addListener(_handleViewportChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get WindowManager from context
    _windowManager = context.read<WindowManager?>();

    // Register this window
    if (_windowManager != null) {
      _registerWindow();
    }
  }

  Future<void> _registerWindow() async {
    await _windowManager?.registerWindow(
      WindowDescriptor(
        windowId: _windowId,
        type: WindowType.artboard,
        documentId: widget.documentId,
        artboardId: widget.artboardId,
        lastViewportState: widget.initialViewportState,
      ),
    );
  }

  void _handleFocusChanged() {
    if (_windowManager == null) return;

    if (_focusNode.hasFocus) {
      _windowManager!.focusWindow(_windowId);
    } else {
      _windowManager!.blurWindow(_windowId);
    }
  }

  void _handleViewportChanged() {
    if (_windowManager == null) return;

    // Update window descriptor with latest viewport state
    final snapshot = ViewportSnapshot(
      panOffset: _viewportController.panOffset,
      zoom: _viewportController.zoomLevel,
    );

    _windowManager!.updateWindow(
      _windowId,
      viewportState: snapshot,
    );
  }

  Future<void> _handleCloseRequested() async {
    if (_windowManager == null) {
      // No manager, close directly
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Artboard windows close silently (FR-040)
    await _windowManager!.requestCloseArtboard(
      widget.documentId,
      widget.artboardId,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Unregister window
    _windowManager?.unregisterWindow(_windowId);

    // Cleanup
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _viewportController.removeListener(_handleViewportChanged);
    _viewportController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleCloseRequested();
        return false; // Prevent default pop, we handle it manually
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text('${widget.artboardName} - ${widget.documentName}'),
            actions: [
              // Future: Add artboard-specific toolbar actions
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleCloseRequested,
                tooltip: 'Close artboard',
              ),
            ],
          ),
          body: _buildCanvas(),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    // TODO: In a real implementation, this would fetch the artboard data
    // from a document provider/service and render it with WireTunerCanvas.
    //
    // For now, we show a placeholder that demonstrates the viewport state
    // is being tracked and persisted.

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
            'Artboard: ${widget.artboardName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Document: ${widget.documentName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Viewport State:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            'Zoom: ${_viewportController.zoomLevel.toStringAsFixed(2)}x',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Pan: (${_viewportController.panOffset.dx.toStringAsFixed(1)}, '
            '${_viewportController.panOffset.dy.toStringAsFixed(1)})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _viewportController.setZoom(
                  (_viewportController.zoomLevel + 0.5) % 3.0 + 0.5,
                );
              });
            },
            child: const Text('Test Zoom Change'),
          ),
          const SizedBox(height: 8),
          Text(
            'Close and reopen this window to test viewport persistence',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    // Real implementation would use:
    // return WireTunerCanvas(
    //   paths: artboard.paths,
    //   shapes: artboard.shapes,
    //   selection: artboard.selection,
    //   viewportController: _viewportController,
    // );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCmd = event.logicalKey == LogicalKeyboardKey.meta ||
        event.logicalKey == LogicalKeyboardKey.control;

    // Cmd+W: Close window
    if (isCmd && event.logicalKey == LogicalKeyboardKey.keyW) {
      _handleCloseRequested();
      return;
    }

    // Future: Add more keyboard shortcuts
    // - Cmd+S: Save
    // - Cmd+Z: Undo
    // - Tool shortcuts
  }
}
