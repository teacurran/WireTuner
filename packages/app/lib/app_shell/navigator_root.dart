import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/navigator/navigator_window.dart';
import 'window_manager.dart';
import 'window_descriptor.dart';

/// Root widget for a Navigator window that integrates with WindowManager.
///
/// NavigatorRoot wraps the existing NavigatorWindow and handles:
/// - Window registration on mount
/// - Close confirmation prompts per FR-040
/// - Viewport state persistence on blur/close
/// - Document cleanup on window close
///
/// ## Usage
///
/// ```dart
/// MaterialPageRoute(
///   builder: (_) => NavigatorRoot(
///     documentId: 'doc123',
///     documentName: 'website-design.wiretuner',
///   ),
/// )
/// ```
///
/// Related: FR-040 (Window Lifecycle), Journey 18
class NavigatorRoot extends StatefulWidget {
  /// Creates a Navigator root window.
  const NavigatorRoot({
    Key? key,
    required this.documentId,
    required this.documentName,
  }) : super(key: key);

  /// Document this Navigator is displaying.
  final String documentId;

  /// Display name of the document (filename).
  final String documentName;

  @override
  State<NavigatorRoot> createState() => _NavigatorRootState();
}

class _NavigatorRootState extends State<NavigatorRoot> {
  late String _windowId;
  WindowManager? _windowManager;

  @override
  void initState() {
    super.initState();
    _windowId = 'nav-${widget.documentId}';
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
        type: WindowType.navigator,
        documentId: widget.documentId,
      ),
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

    // Request close via manager (will show confirmation)
    final shouldClose = await _windowManager!.requestCloseNavigator(widget.documentId);

    if (shouldClose && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Unregister window on dispose
    _windowManager?.unregisterWindow(_windowId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleCloseRequested();
        return false; // Prevent default pop, we handle it manually
      },
      child: NavigatorWindow(
        onClose: _handleCloseRequested,
      ),
    );
  }
}

/// Shows a confirmation dialog for closing a Navigator window.
///
/// Per Journey 18: "Close [documentName] and all artboard windows?"
///
/// Returns true if user confirms, false if cancelled.
Future<bool> showNavigatorCloseConfirmation(
  BuildContext context,
  String documentName,
  int artboardWindowCount,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Close Document'),
      content: Text(
        artboardWindowCount > 0
            ? 'Close "$documentName" and all $artboardWindowCount artboard window${artboardWindowCount == 1 ? '' : 's'}?'
            : 'Close "$documentName"?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  return result ?? false;
}
