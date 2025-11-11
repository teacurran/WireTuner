import 'dart:async';
import 'package:flutter/foundation.dart';
import 'window_descriptor.dart';

/// Manages window lifecycle for the entire application.
///
/// WindowManager acts as the central registry for all windows (Navigator,
/// artboard, inspector, etc.) and coordinates their lifecycle events:
/// - Opening and closing windows
/// - Tracking focus and blur
/// - Persisting and restoring viewport state
/// - Handling close confirmation for Navigator (root) windows
///
/// ## Architecture
///
/// The manager maintains:
/// - `_windows`: Map of all open windows by ID
/// - `_documentIndex`: Fast lookup of windows per document
/// - `_focusedWindowId`: Currently focused window
///
/// ## Usage
///
/// ```dart
/// final manager = WindowManager();
///
/// // Register Navigator window
/// await manager.registerWindow(
///   WindowDescriptor(
///     windowId: 'nav-doc123',
///     type: WindowType.navigator,
///     documentId: 'doc123',
///   ),
/// );
///
/// // Register artboard window
/// await manager.registerWindow(
///   WindowDescriptor(
///     windowId: 'art-doc123-art456',
///     type: WindowType.artboard,
///     documentId: 'doc123',
///     artboardId: 'art456',
///   ),
/// );
///
/// // Close document (prompts if Navigator)
/// final shouldClose = await manager.requestCloseDocument('doc123');
/// if (shouldClose) {
///   await manager.closeDocument('doc123');
/// }
/// ```
///
/// ## Window ID Conventions
///
/// - Navigator: `nav-{documentId}`
/// - Artboard: `art-{documentId}-{artboardId}`
/// - Inspector: `insp-{documentId}-{artboardId}`
/// - History: `hist-{documentId}`
///
/// Related: FR-040 (Window Lifecycle), Journey 18
class WindowManager extends ChangeNotifier {
  /// Creates a window manager.
  ///
  /// [onPersistViewportState]: Callback to persist viewport state to storage.
  /// [onConfirmClose]: Callback to show close confirmation dialog.
  WindowManager({
    this.onPersistViewportState,
    this.onConfirmClose,
  });

  /// All open windows by ID.
  final Map<String, WindowDescriptor> _windows = {};

  /// Index of window IDs per document for fast lookup.
  ///
  /// Map structure: documentId -> [windowId1, windowId2, ...]
  final Map<String, List<String>> _documentIndex = {};

  /// Currently focused window ID.
  String? _focusedWindowId;

  /// Callback to persist viewport state to storage.
  ///
  /// Called when a window is blurred or closed to save its viewport state.
  /// Implementation should delegate to SettingsService or similar.
  final Future<void> Function(String documentId, String? artboardId,
      ViewportSnapshot viewport)? onPersistViewportState;

  /// Callback to show close confirmation dialog.
  ///
  /// Called when attempting to close a Navigator window.
  /// Should return true if user confirms, false if cancelled.
  final Future<bool> Function(String documentId)? onConfirmClose;

  /// Stream controller for window lifecycle events.
  final _eventsController = StreamController<WindowLifecycleEvent>.broadcast();

  /// Stream of window lifecycle events.
  ///
  /// Emits events for:
  /// - `opened`: Window registered and opened
  /// - `focused`: Window received focus
  /// - `blurred`: Window lost focus
  /// - `closed`: Window unregistered and closed
  Stream<WindowLifecycleEvent> get events => _eventsController.stream;

  /// Gets all open windows.
  List<WindowDescriptor> get windows => _windows.values.toList();

  /// Gets the currently focused window, if any.
  WindowDescriptor? get focusedWindow =>
      _focusedWindowId != null ? _windows[_focusedWindowId] : null;

  /// Gets a window by ID.
  WindowDescriptor? getWindow(String windowId) => _windows[windowId];

  /// Gets all windows for a document.
  List<WindowDescriptor> getWindowsForDocument(String documentId) {
    final windowIds = _documentIndex[documentId] ?? [];
    return windowIds
        .map((id) => _windows[id])
        .whereType<WindowDescriptor>()
        .toList();
  }

  /// Gets the Navigator window for a document, if open.
  WindowDescriptor? getNavigatorForDocument(String documentId) {
    return getWindowsForDocument(documentId)
        .where((w) => w.type == WindowType.navigator)
        .firstOrNull;
  }

  /// Gets all artboard windows for a document.
  List<WindowDescriptor> getArtboardWindowsForDocument(String documentId) {
    return getWindowsForDocument(documentId)
        .where((w) => w.type == WindowType.artboard)
        .toList();
  }

  /// Checks if a document has any open windows.
  bool hasWindowsForDocument(String documentId) {
    final windows = _documentIndex[documentId];
    return windows != null && windows.isNotEmpty;
  }

  /// Checks if a specific artboard window is open.
  bool isArtboardWindowOpen(String documentId, String artboardId) {
    final windowId = _makeArtboardWindowId(documentId, artboardId);
    return _windows.containsKey(windowId);
  }

  /// Registers a new window and marks it as opened.
  ///
  /// This should be called when a window widget is initialized.
  /// Emits an `opened` lifecycle event.
  ///
  /// Returns the registered descriptor (with updated timestamps).
  Future<WindowDescriptor> registerWindow(WindowDescriptor descriptor) async {
    // Update timestamps
    final now = DateTime.now();
    final registered = descriptor.copyWith(
      createdAt: descriptor.createdAt is _DefaultDateTime ? now : null,
      lastFocusTime: now,
    );

    // Store window
    _windows[registered.windowId] = registered;

    // Update document index
    _documentIndex
        .putIfAbsent(registered.documentId, () => [])
        .add(registered.windowId);

    // Set as focused
    _focusedWindowId = registered.windowId;

    // Emit event
    _eventsController.add(WindowLifecycleEvent(
      type: WindowLifecycleEventType.opened,
      descriptor: registered,
    ));

    notifyListeners();

    debugPrint('[WindowManager] Registered window: ${registered.windowId}');
    return registered;
  }

  /// Unregisters a window and marks it as closed.
  ///
  /// This should be called when a window widget is disposed.
  /// Persists viewport state before closing if callback is provided.
  /// Emits a `closed` lifecycle event.
  Future<void> unregisterWindow(String windowId) async {
    final descriptor = _windows[windowId];
    if (descriptor == null) {
      debugPrint('[WindowManager] Attempted to unregister unknown window: $windowId');
      return;
    }

    // Persist viewport state if available
    if (descriptor.lastViewportState != null && onPersistViewportState != null) {
      await onPersistViewportState!(
        descriptor.documentId,
        descriptor.artboardId,
        descriptor.lastViewportState!,
      );
    }

    // Remove from index
    final docWindows = _documentIndex[descriptor.documentId];
    docWindows?.remove(windowId);
    if (docWindows?.isEmpty ?? false) {
      _documentIndex.remove(descriptor.documentId);
    }

    // Remove window
    _windows.remove(windowId);

    // Clear focus if this was focused
    if (_focusedWindowId == windowId) {
      _focusedWindowId = null;
    }

    // Emit event
    _eventsController.add(WindowLifecycleEvent(
      type: WindowLifecycleEventType.closed,
      descriptor: descriptor,
    ));

    notifyListeners();

    debugPrint('[WindowManager] Unregistered window: $windowId');
  }

  /// Updates a window's state (e.g., viewport, dirty flag).
  ///
  /// This should be called when the window's state changes, such as:
  /// - Viewport is panned or zoomed
  /// - Content is modified (isDirty = true)
  /// - Content is saved (isDirty = false)
  void updateWindow(String windowId, {
    ViewportSnapshot? viewportState,
    bool? isDirty,
  }) {
    final descriptor = _windows[windowId];
    if (descriptor == null) return;

    final updated = descriptor.copyWith(
      lastViewportState: viewportState,
      isDirty: isDirty,
    );

    _windows[windowId] = updated;
    notifyListeners();
  }

  /// Records that a window gained focus.
  ///
  /// Updates the lastFocusTime and emits a `focused` event.
  /// Should be called when the window's FocusNode receives focus.
  void focusWindow(String windowId) {
    final descriptor = _windows[windowId];
    if (descriptor == null) return;

    // Blur current focused window if different
    if (_focusedWindowId != null && _focusedWindowId != windowId) {
      blurWindow(_focusedWindowId!);
    }

    // Update focus time
    final updated = descriptor.copyWith(lastFocusTime: DateTime.now());
    _windows[windowId] = updated;
    _focusedWindowId = windowId;

    // Emit event
    _eventsController.add(WindowLifecycleEvent(
      type: WindowLifecycleEventType.focused,
      descriptor: updated,
    ));

    notifyListeners();
  }

  /// Records that a window lost focus.
  ///
  /// Persists viewport state and emits a `blurred` event.
  /// Should be called when the window's FocusNode loses focus.
  Future<void> blurWindow(String windowId) async {
    final descriptor = _windows[windowId];
    if (descriptor == null) return;

    // Persist viewport state on blur (Journey 15 requirement)
    if (descriptor.lastViewportState != null && onPersistViewportState != null) {
      await onPersistViewportState!(
        descriptor.documentId,
        descriptor.artboardId,
        descriptor.lastViewportState!,
      );
    }

    // Clear focused if this was focused
    if (_focusedWindowId == windowId) {
      _focusedWindowId = null;
    }

    // Emit event
    _eventsController.add(WindowLifecycleEvent(
      type: WindowLifecycleEventType.blurred,
      descriptor: descriptor,
    ));

    notifyListeners();
  }

  /// Requests to close an artboard window.
  ///
  /// Artboard windows close silently per FR-040 (no confirmation needed).
  /// Returns true (always succeeds).
  Future<bool> requestCloseArtboard(String documentId, String artboardId) async {
    final windowId = _makeArtboardWindowId(documentId, artboardId);
    await unregisterWindow(windowId);
    return true;
  }

  /// Requests to close a Navigator window (root window for document).
  ///
  /// Per FR-040 and Journey 18:
  /// - Shows confirmation prompt: "Close all artboards for [document]?"
  /// - If confirmed: closes all windows for the document
  /// - If cancelled: returns false, no windows closed
  ///
  /// Returns true if close proceeded, false if cancelled.
  Future<bool> requestCloseNavigator(String documentId) async {
    // Show confirmation if callback provided
    if (onConfirmClose != null) {
      final confirmed = await onConfirmClose!(documentId);
      if (!confirmed) {
        debugPrint('[WindowManager] Navigator close cancelled by user');
        return false;
      }
    }

    // Close all windows for this document
    await closeDocument(documentId);
    return true;
  }

  /// Closes all windows for a document.
  ///
  /// This is called after user confirms Navigator close, or programmatically
  /// when closing a document from the File menu.
  Future<void> closeDocument(String documentId) async {
    final windowIds = List<String>.from(_documentIndex[documentId] ?? []);

    debugPrint('[WindowManager] Closing document $documentId (${windowIds.length} windows)');

    // Close all windows
    for (final windowId in windowIds) {
      await unregisterWindow(windowId);
    }
  }

  /// Opens an artboard window for editing.
  ///
  /// If the window is already open, focuses it instead of creating a new one.
  /// Restores last viewport state if available.
  ///
  /// Returns the window descriptor.
  Future<WindowDescriptor> openArtboardWindow({
    required String documentId,
    required String artboardId,
    ViewportSnapshot? initialViewportState,
  }) async {
    final windowId = _makeArtboardWindowId(documentId, artboardId);

    // If already open, just focus
    if (_windows.containsKey(windowId)) {
      focusWindow(windowId);
      return _windows[windowId]!;
    }

    // Create new window descriptor
    final descriptor = WindowDescriptor(
      windowId: windowId,
      type: WindowType.artboard,
      documentId: documentId,
      artboardId: artboardId,
      lastViewportState: initialViewportState,
    );

    return registerWindow(descriptor);
  }

  /// Generates a window ID for an artboard.
  String _makeArtboardWindowId(String documentId, String artboardId) {
    return 'art-$documentId-$artboardId';
  }

  @override
  void dispose() {
    _eventsController.close();
    super.dispose();
  }
}

/// Lifecycle event types.
enum WindowLifecycleEventType {
  /// Window was opened (registered).
  opened,

  /// Window gained focus.
  focused,

  /// Window lost focus.
  blurred,

  /// Window was closed (unregistered).
  closed,
}

/// Represents a window lifecycle event.
@immutable
class WindowLifecycleEvent {
  /// Creates a lifecycle event.
  const WindowLifecycleEvent({
    required this.type,
    required this.descriptor,
  });

  /// Type of event.
  final WindowLifecycleEventType type;

  /// Window descriptor at the time of the event.
  final WindowDescriptor descriptor;

  @override
  String toString() => 'WindowLifecycleEvent($type: ${descriptor.windowId})';
}
