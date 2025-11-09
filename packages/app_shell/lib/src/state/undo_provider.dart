import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:event_core/event_core.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

/// Provider that bridges UndoNavigator to Flutter UI layer.
///
/// This provider:
/// - Wraps the event_core UndoNavigator service
/// - Listens for navigation events and updates DocumentProvider
/// - Exposes undo/redo commands for keyboard shortcuts
/// - Provides UI state for undo/redo menu items (canUndo/canRedo, labels)
///
/// **Usage:**
/// ```dart
/// // Setup in provider tree
/// MultiProvider(
///   providers: [
///     ChangeNotifierProvider<DocumentProvider>(
///       create: (_) => DocumentProvider(),
///     ),
///     ChangeNotifierProxyProvider<DocumentProvider, UndoProvider>(
///       create: (context) => UndoProvider(
///         navigator: undoNavigator,
///         documentProvider: context.read<DocumentProvider>(),
///       ),
///       update: (context, docProvider, previous) {
///         return previous ?? UndoProvider(
///           navigator: undoNavigator,
///           documentProvider: docProvider,
///         );
///       },
///     ),
///   ],
/// )
///
/// // Access in widgets
/// final undoProvider = context.watch<UndoProvider>();
/// final canUndo = undoProvider.canUndo;
/// final undoLabel = undoProvider.undoActionLabel;
/// ```
///
/// **Keyboard Shortcuts:**
/// ```dart
/// Shortcuts(
///   shortcuts: {
///     LogicalKeySet(
///       Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
///       LogicalKeyboardKey.keyZ,
///     ): UndoIntent(),
///     LogicalKeySet(
///       Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
///       LogicalKeyboardKey.shift,
///       LogicalKeyboardKey.keyZ,
///     ): RedoIntent(),
///   },
///   child: Actions(
///     actions: {
///       UndoIntent: CallbackAction<UndoIntent>(
///         onInvoke: (_) => context.read<UndoProvider>().handleUndo(),
///       ),
///       RedoIntent: CallbackAction<RedoIntent>(
///         onInvoke: (_) => context.read<UndoProvider>().handleRedo(),
///       ),
///     },
///     child: child,
///   ),
/// )
/// ```
///
/// Related: Task I4.T3 (Undo/Redo Navigator), Decision 7 (Provider pattern)
class UndoProvider extends ChangeNotifier {
  /// Creates an undo provider.
  ///
  /// [navigator]: Core undo navigator service from event_core
  /// [documentProvider]: Document provider to update on navigation (currently unused)
  UndoProvider({
    required UndoNavigator navigator,
    required DocumentProvider documentProvider,
  })  : _navigator = navigator {
    // Subscribe to navigator changes
    _navigator.addListener(_onNavigationChanged);
  }

  final UndoNavigator _navigator;

  /// Flag to prevent re-entrancy during navigation.
  bool _isNavigating = false;

  /// Returns whether undo is available.
  bool get canUndo => _navigator.canUndo;

  /// Returns whether redo is available.
  bool get canRedo => _navigator.canRedo;

  /// Returns the action label for undo menu item.
  ///
  /// Examples: "Undo", "Undo Create Path", "Undo Move Objects"
  String get undoActionLabel {
    final operationName = _navigator.undoOperationName;
    return operationName != null ? 'Undo $operationName' : 'Undo';
  }

  /// Returns the action label for redo menu item.
  ///
  /// Examples: "Redo", "Redo Create Path", "Redo Move Objects"
  String get redoActionLabel {
    final operationName = _navigator.redoOperationName;
    return operationName != null ? 'Redo $operationName' : 'Redo';
  }

  /// Returns the current operation name (for status display).
  String? get currentOperationName => _navigator.currentOperationName;

  /// Handles undo command from keyboard shortcut or menu.
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleUndo() async {
    if (_isNavigating || !canUndo) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _navigator.undo();
      if (success) {
        // Navigator triggers notification, which will update document
      }
      return success;
    } finally {
      _isNavigating = false;
    }
  }

  /// Handles redo command from keyboard shortcut or menu.
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleRedo() async {
    if (_isNavigating || !canRedo) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _navigator.redo();
      if (success) {
        // Navigator triggers notification, which will update document
      }
      return success;
    } finally {
      _isNavigating = false;
    }
  }

  /// Handles scrubbing to a specific sequence (for history panel UI).
  ///
  /// [targetSequence]: Event sequence number to navigate to
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleScrub(int targetSequence) async {
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _navigator.scrubToSequence(targetSequence);
      if (success) {
        // Navigator triggers notification, which will update document
      }
      return success;
    } finally {
      _isNavigating = false;
    }
  }

  /// Handles scrubbing to a specific operation group.
  ///
  /// [targetGroup]: Operation group to navigate to
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleScrubToGroup(OperationGroup targetGroup) async {
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _navigator.scrubToGroup(targetGroup);
      if (success) {
        // Navigator triggers notification, which will update document
      }
      return success;
    } finally {
      _isNavigating = false;
    }
  }

  /// Resets the undo/redo state.
  ///
  /// Called when loading a new document or resetting application state.
  void reset() {
    _navigator.reset();
  }

  /// Returns the undo stack for history panel display.
  List<OperationGroup> get undoStack => _navigator.undoStack;

  /// Returns the redo stack for history panel display.
  List<OperationGroup> get redoStack => _navigator.redoStack;

  /// Handles navigation changes from the navigator.
  ///
  /// This is called when navigator state changes (undo/redo/scrub).
  /// We don't need to update DocumentProvider here because the
  /// EventReplayer already reconstructs the document state and
  /// the event system will trigger document updates through the
  /// normal event dispatch flow.
  void _onNavigationChanged() {
    // Notify Flutter widgets that undo/redo state changed
    // (enables/disables undo/redo buttons, updates menu labels)
    notifyListeners();

    // Note: We don't call documentProvider.updateDocument() here because:
    // 1. EventReplayer handles state reconstruction
    // 2. Event dispatching updates the document through normal flow
    // 3. Calling updateDocument here would create duplicate updates
    //
    // This design maintains separation between navigation (UndoNavigator)
    // and document state management (DocumentProvider).
  }

  @override
  void dispose() {
    _navigator.removeListener(_onNavigationChanged);
    super.dispose();
  }
}

/// Intent for undo action (Flutter Actions/Shortcuts framework).
class UndoIntent extends Intent {
  /// Creates an undo intent.
  const UndoIntent();
}

/// Intent for redo action (Flutter Actions/Shortcuts framework).
class RedoIntent extends Intent {
  /// Creates a redo intent.
  const RedoIntent();
}
