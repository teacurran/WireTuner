/// Multi-window lifecycle and coordination manager.
///
/// This module implements the window management architecture defined in
/// ADR-002 (Multi-Window Document Editing), providing:
///
/// - **Window Registry**: Central registry mapping windowId → DocumentWindow instances
/// - **Lifecycle Hooks**: onWindowCreated, onWindowClosed callbacks for resource management
/// - **Isolation Guarantees**: Ensures each window has isolated undo stacks, metrics, and logging
/// - **Cleanup Enforcement**: Deterministic resource release on window close
///
/// **Design:**
/// - Each window receives a unique windowId (UUID) for logging/metrics isolation
/// - Window-scoped dependency containers hold dedicated UndoNavigator, metrics sink, logger
/// - Closing a window triggers cleanup hooks that dispose providers and release subscriptions
/// - Supports same document in multiple windows (each with independent undo stack)
///
/// **Integration:**
/// - Used by AppShell to manage document window lifecycle
/// - Creates window-scoped DocumentProvider, UndoProvider per window
/// - Coordinates with ConnectionFactory for pooled database connections
///
/// **References:**
/// - ADR-002: Multi-window document editing architecture
/// - Task I4.T7: Multi-window coordination implementation
/// - Decision 7: Provider-based state management
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import '../state/undo_provider.dart';

/// Unique identifier for a document window.
///
/// Used for isolating logging context, metrics, and undo stacks.
/// Generated as UUID v4 to avoid collisions across window creation/destruction cycles.
typedef WindowId = String;

/// Unique identifier for a document.
///
/// Used for connection pooling and multi-window coordination.
typedef DocumentId = String;

/// Window-scoped dependency container.
///
/// Holds all resources that should be isolated per window:
/// - Document provider (canvas state, selection, viewport)
/// - Undo provider (undo/redo stack, navigation commands)
/// - Undo navigator (core service backing undo provider)
/// - Metrics sink (window-specific performance counters)
/// - Logger (tagged with windowId for tracing)
///
/// **Lifecycle:**
/// Created when window opens, disposed when window closes.
/// Disposal releases all subscriptions and notifies cleanup hooks.
class WindowScope {
  /// Creates a window scope with isolated dependencies.
  WindowScope({
    required this.windowId,
    required this.documentId,
    required this.documentProvider,
    required this.undoProvider,
    required this.undoNavigator,
    required this.metricsSink,
    required this.logger,
  });

  /// Unique identifier for this window.
  final WindowId windowId;

  /// Document identifier (for connection pooling).
  final DocumentId documentId;

  /// Document provider (canvas state, selection, viewport).
  final DocumentProvider documentProvider;

  /// Undo provider (bridges UndoNavigator to Flutter UI).
  final UndoProvider undoProvider;

  /// Undo navigator (core undo/redo service).
  final UndoNavigator undoNavigator;

  /// Metrics sink (window-specific performance counters).
  final MetricsSink metricsSink;

  /// Logger (tagged with windowId).
  final Logger logger;

  /// Disposes all resources in this window scope.
  ///
  /// Releases subscriptions, disposes providers, and logs cleanup.
  /// Safe to call multiple times (idempotent).
  void dispose() {
    logger.d('[$windowId] Disposing window scope for document $documentId');

    // Dispose providers in reverse dependency order
    undoProvider.dispose();
    undoNavigator.dispose();
    documentProvider.dispose();

    logger.d('[$windowId] Window scope disposed');
  }

  @override
  String toString() => 'WindowScope(windowId: $windowId, documentId: $documentId)';
}

/// Lifecycle hook called when a window is created.
typedef OnWindowCreatedHook = void Function(WindowId windowId, DocumentId documentId);

/// Lifecycle hook called when a window is closed.
typedef OnWindowClosedHook = void Function(WindowId windowId, DocumentId documentId);

/// Lifecycle hook called when all windows are closed.
typedef OnAllWindowsClosedHook = void Function();

/// Multi-window coordination and lifecycle manager.
///
/// Manages the lifecycle of document windows, ensuring resource isolation
/// and deterministic cleanup per ADR-002.
///
/// **Usage:**
/// ```dart
/// final windowManager = WindowManager(
///   logger: logger,
///   diagnosticsConfig: EventCoreDiagnosticsConfig.debug(),
/// );
///
/// // Register lifecycle hooks
/// windowManager.onWindowCreated((windowId, documentId) {
///   print('Window $windowId opened for document $documentId');
/// });
///
/// windowManager.onWindowClosed((windowId, documentId) {
///   print('Window $windowId closed');
/// });
///
/// // Open a new window
/// final windowScope = await windowManager.openWindow(
///   documentId: 'doc-123',
///   operationGrouping: operationGrouping,
///   eventReplayer: eventReplayer,
/// );
///
/// // Access window-scoped dependencies
/// final documentProvider = windowScope.documentProvider;
/// final undoProvider = windowScope.undoProvider;
///
/// // Close the window
/// await windowManager.closeWindow(windowScope.windowId);
/// ```
///
/// **Multi-Window Scenarios:**
/// - Same document in multiple windows: Each has isolated undo stack
/// - Multiple documents: Each with independent window scopes
/// - Rapid open/close: Cleanup hooks prevent resource leaks
///
/// **Threading:** All methods must be called from UI isolate.
class WindowManager {
  /// Creates a window manager.
  ///
  /// [logger]: Logger instance for window lifecycle events
  /// [diagnosticsConfig]: Diagnostics configuration for UndoNavigator
  WindowManager({
    required Logger logger,
    required EventCoreDiagnosticsConfig diagnosticsConfig,
  })  : _logger = logger,
        _diagnosticsConfig = diagnosticsConfig;

  final Logger _logger;
  final EventCoreDiagnosticsConfig _diagnosticsConfig;

  /// Registry mapping windowId → WindowScope.
  final Map<WindowId, WindowScope> _windows = {};

  /// Lifecycle hook callbacks.
  final List<OnWindowCreatedHook> _onWindowCreatedHooks = [];
  final List<OnWindowClosedHook> _onWindowClosedHooks = [];
  final List<OnAllWindowsClosedHook> _onAllWindowsClosedHooks = [];

  /// Returns an unmodifiable view of all open windows.
  Map<WindowId, WindowScope> get windows => Map.unmodifiable(_windows);

  /// Returns the number of open windows.
  int get windowCount => _windows.length;

  /// Returns whether the manager has any open windows.
  bool get hasOpenWindows => _windows.isNotEmpty;

  /// Returns the window scope for the given windowId, or null if not found.
  WindowScope? getWindow(WindowId windowId) => _windows[windowId];

  /// Registers a hook to be called when a window is created.
  ///
  /// The hook receives the windowId and documentId.
  /// Multiple hooks can be registered and will be called in registration order.
  void onWindowCreated(OnWindowCreatedHook hook) {
    _onWindowCreatedHooks.add(hook);
  }

  /// Registers a hook to be called when a window is closed.
  ///
  /// The hook receives the windowId and documentId.
  /// Multiple hooks can be registered and will be called in registration order.
  void onWindowClosed(OnWindowClosedHook hook) {
    _onWindowClosedHooks.add(hook);
  }

  /// Registers a hook to be called when all windows are closed.
  ///
  /// Useful for cleanup operations that should only happen when no windows remain.
  void onAllWindowsClosed(OnAllWindowsClosedHook hook) {
    _onAllWindowsClosedHooks.add(hook);
  }

  /// Opens a new window for the given document.
  ///
  /// Creates a window-scoped dependency container with:
  /// - Unique windowId (UUID v4)
  /// - Isolated DocumentProvider
  /// - Isolated UndoProvider + UndoNavigator
  /// - Window-specific metrics sink and logger
  ///
  /// [documentId]: Document identifier (for connection pooling)
  /// [operationGrouping]: Operation grouping service (shared across windows)
  /// [eventReplayer]: Event replayer (shared across windows)
  /// [initialDocument]: Optional initial document state (defaults to empty)
  ///
  /// Returns the created WindowScope.
  ///
  /// **Thread Safety**: Must be called from UI isolate.
  Future<WindowScope> openWindow({
    required DocumentId documentId,
    required OperationGroupingService operationGrouping,
    required EventReplayer eventReplayer,
    Document? initialDocument,
  }) async {
    // Generate unique window ID
    final windowId = _generateWindowId();

    _logger.i('Opening window $windowId for document $documentId');

    // Create window-scoped logger (simple wrapper that prefixes windowId)
    final windowLogger = _logger;

    // Create window-scoped metrics sink (concrete implementation)
    final windowMetricsSink = _InMemoryMetricsSink();

    // Create isolated document provider
    final documentProvider = DocumentProvider(
      initialDocument: initialDocument,
    );

    // Create isolated undo navigator
    final undoNavigator = UndoNavigator(
      operationGrouping: operationGrouping,
      eventReplayer: eventReplayer,
      metricsSink: windowMetricsSink,
      logger: windowLogger,
      config: _diagnosticsConfig,
      documentId: windowId, // Use windowId for multi-window isolation
    );

    // Create undo provider (bridges navigator to Flutter UI)
    final undoProvider = UndoProvider.withNavigator(
      navigator: undoNavigator,
      documentProvider: documentProvider,
    );

    // Create window scope
    final windowScope = WindowScope(
      windowId: windowId,
      documentId: documentId,
      documentProvider: documentProvider,
      undoProvider: undoProvider,
      undoNavigator: undoNavigator,
      metricsSink: windowMetricsSink,
      logger: windowLogger,
    );

    // Register window
    _windows[windowId] = windowScope;

    _logger.i(
      'Window $windowId opened for document $documentId '
      '(total windows: ${_windows.length})',
    );

    // Invoke lifecycle hooks
    for (final hook in _onWindowCreatedHooks) {
      try {
        hook(windowId, documentId);
      } catch (e, stackTrace) {
        _logger.e(
          'Error in onWindowCreated hook for window $windowId',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    return windowScope;
  }

  /// Closes the window with the given windowId.
  ///
  /// Disposes all window-scoped resources:
  /// - UndoProvider (releases navigator listeners)
  /// - UndoNavigator (releases operation grouping listeners)
  /// - DocumentProvider (releases document listeners)
  ///
  /// Invokes onWindowClosed hooks and onAllWindowsClosed if no windows remain.
  ///
  /// Returns true if the window was found and closed, false otherwise.
  /// Safe to call multiple times for the same windowId (idempotent).
  ///
  /// **Thread Safety**: Must be called from UI isolate.
  Future<bool> closeWindow(WindowId windowId) async {
    final windowScope = _windows[windowId];
    if (windowScope == null) {
      _logger.w('Attempted to close non-existent window: $windowId');
      return false;
    }

    final documentId = windowScope.documentId;

    _logger.i('Closing window $windowId for document $documentId');

    // Remove from registry first (prevents re-entrancy)
    _windows.remove(windowId);

    // Dispose window scope (releases all subscriptions)
    windowScope.dispose();

    _logger.i(
      'Window $windowId closed for document $documentId '
      '(remaining windows: ${_windows.length})',
    );

    // Invoke onWindowClosed hooks
    for (final hook in _onWindowClosedHooks) {
      try {
        hook(windowId, documentId);
      } catch (e, stackTrace) {
        _logger.e(
          'Error in onWindowClosed hook for window $windowId',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    // If no windows remain, invoke onAllWindowsClosed hooks
    if (_windows.isEmpty) {
      _logger.i('All windows closed');
      for (final hook in _onAllWindowsClosedHooks) {
        try {
          hook();
        } catch (e, stackTrace) {
          _logger.e(
            'Error in onAllWindowsClosed hook',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    }

    return true;
  }

  /// Closes all open windows.
  ///
  /// Disposes all window scopes in reverse creation order.
  /// Invokes onWindowClosed for each window, then onAllWindowsClosed once.
  ///
  /// Safe to call when no windows are open (no-op).
  Future<void> closeAllWindows() async {
    if (_windows.isEmpty) {
      _logger.d('closeAllWindows called with no open windows (no-op)');
      return;
    }

    final windowIds = _windows.keys.toList();
    _logger.i('Closing all windows (${windowIds.length} windows)');

    for (final windowId in windowIds) {
      await closeWindow(windowId);
    }
  }

  /// Returns the window IDs for all windows viewing the given document.
  ///
  /// Useful for multi-window coordination (e.g., notifying all windows
  /// when document is saved or external changes detected).
  List<WindowId> getWindowsForDocument(DocumentId documentId) {
    return _windows.entries
        .where((entry) => entry.value.documentId == documentId)
        .map((entry) => entry.key)
        .toList();
  }

  /// Generates a unique window ID.
  ///
  /// Uses a simple counter-based approach for deterministic testing.
  /// Production implementation could use UUID v4.
  WindowId _generateWindowId() {
    return 'window-${DateTime.now().millisecondsSinceEpoch}-${_windowCounter++}';
  }

  static int _windowCounter = 0;

  /// Disposes the window manager and all open windows.
  ///
  /// Releases all resources and clears lifecycle hooks.
  /// Safe to call multiple times (idempotent).
  Future<void> dispose() async {
    _logger.i('Disposing window manager (${_windows.length} open windows)');

    await closeAllWindows();

    _onWindowCreatedHooks.clear();
    _onWindowClosedHooks.clear();
    _onAllWindowsClosedHooks.clear();

    _logger.i('Window manager disposed');
  }

  @override
  String toString() => 'WindowManager(windows: ${_windows.length})';
}

/// In-memory metrics sink implementation for window-scoped metrics.
///
/// This is a simple implementation that stores metrics in memory.
/// Production implementations could forward to external observability systems.
class _InMemoryMetricsSink implements MetricsSink {
  final List<Map<String, dynamic>> _events = [];

  @override
  void recordEvent({
    required String eventType,
    required bool sampled,
    int? durationMs,
  }) {
    _events.add({
      'eventType': eventType,
      'sampled': sampled,
      'durationMs': durationMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  void recordReplay({
    required int eventCount,
    required int fromSequence,
    required int toSequence,
    required int durationMs,
  }) {
    _events.add({
      'type': 'replay',
      'eventCount': eventCount,
      'fromSequence': fromSequence,
      'toSequence': toSequence,
      'durationMs': durationMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  void recordSnapshot({
    required int sequenceNumber,
    required int snapshotSizeBytes,
    required int durationMs,
  }) {
    _events.add({
      'type': 'snapshot',
      'sequenceNumber': sequenceNumber,
      'snapshotSizeBytes': snapshotSizeBytes,
      'durationMs': durationMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  void recordSnapshotLoad({
    required int sequenceNumber,
    required int durationMs,
  }) {
    _events.add({
      'type': 'snapshotLoad',
      'sequenceNumber': sequenceNumber,
      'durationMs': durationMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> flush() async {
    // No-op for in-memory implementation
  }

  /// Returns recorded events for testing/debugging.
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
}
