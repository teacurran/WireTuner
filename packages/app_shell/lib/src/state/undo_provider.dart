import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wiretuner/application/services/undo_service.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:event_core/event_core.dart' show OperationGroup, UndoNavigator;

/// Provider that bridges UndoService to Flutter UI layer.
///
/// This provider:
/// - Wraps the UndoService (EventNavigator-based)
/// - Exposes undo/redo commands for keyboard shortcuts
/// - Provides UI state for undo/redo menu items (canUndo/canRedo)
///
/// **Usage:**
/// ```dart
/// // Setup in provider tree
/// MultiProvider(
///   providers: [
///     ChangeNotifierProvider<DocumentProvider>(
///       create: (_) => DocumentProvider(),
///     ),
///     ChangeNotifierProvider<UndoProvider>(
///       create: (context) => UndoProvider(
///         undoService: undoService,
///       ),
///     ),
///   ],
/// )
///
/// // Access in widgets
/// final undoProvider = context.watch<UndoProvider>();
/// final canUndo = undoProvider.canUndo;
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
/// Related: Task I8.T5 (Undo/Redo Implementation)
class UndoProvider extends ChangeNotifier {
  /// Creates an undo provider using UndoService (EventNavigator-based).
  ///
  /// [undoService]: Service that wraps EventNavigator
  UndoProvider({
    required UndoService undoService,
  })  : _undoService = undoService,
        _undoNavigator = null,
        _documentProvider = null;

  /// Creates an undo provider using UndoNavigator (event_core-based).
  ///
  /// This constructor is for backward compatibility with multi-window features.
  /// New code should use the default constructor with UndoService.
  ///
  /// [navigator]: Core undo navigator service from event_core
  /// [documentProvider]: Document provider (unused in this mode)
  UndoProvider.withNavigator({
    required UndoNavigator navigator,
    required DocumentProvider documentProvider,
  })  : _undoService = null,
        _undoNavigator = navigator,
        _documentProvider = documentProvider {
    // Subscribe to navigator changes
    _undoNavigator!.addListener(_onNavigationChanged);
  }

  final UndoService? _undoService;
  final UndoNavigator? _undoNavigator;
  final DocumentProvider? _documentProvider;

  /// Flag to prevent re-entrancy during navigation.
  bool _isNavigating = false;

  /// Cached canUndo state (updated asynchronously for UndoService mode).
  bool _canUndo = false;

  /// Cached canRedo state (updated asynchronously for UndoService mode).
  bool _canRedo = false;

  /// Returns whether undo is available.
  bool get canUndo {
    if (_undoNavigator != null) {
      return _undoNavigator!.canUndo;
    }
    return _canUndo;
  }

  /// Returns whether redo is available.
  bool get canRedo {
    if (_undoNavigator != null) {
      return _undoNavigator!.canRedo;
    }
    return _canRedo;
  }

  /// Returns the action label for undo menu item.
  String get undoActionLabel {
    if (_undoNavigator != null) {
      final operationName = _undoNavigator!.undoOperationName;
      return operationName != null ? 'Undo $operationName' : 'Undo';
    }
    return 'Undo';
  }

  /// Returns the action label for redo menu item.
  String get redoActionLabel {
    if (_undoNavigator != null) {
      final operationName = _undoNavigator!.redoOperationName;
      return operationName != null ? 'Redo $operationName' : 'Redo';
    }
    return 'Redo';
  }

  /// Refreshes the canUndo/canRedo state (UndoService mode only).
  Future<void> _refreshState() async {
    if (_undoService != null) {
      _canUndo = await _undoService!.canUndo();
      _canRedo = await _undoService!.canRedo();
      notifyListeners();
    }
  }

  /// Handles navigation changes from the navigator (UndoNavigator mode).
  void _onNavigationChanged() {
    notifyListeners();
  }

  /// Handles undo command from keyboard shortcut or menu.
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleUndo() async {
    if (_undoNavigator != null) {
      // UndoNavigator mode
      if (_isNavigating || !_undoNavigator!.canUndo) {
        return false;
      }
      _isNavigating = true;
      try {
        return await _undoNavigator!.undo();
      } finally {
        _isNavigating = false;
      }
    }

    // UndoService mode
    if (_isNavigating || !_canUndo) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _undoService!.undo();
      if (success) {
        await _refreshState();
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
    if (_undoNavigator != null) {
      // UndoNavigator mode
      if (_isNavigating || !_undoNavigator!.canRedo) {
        return false;
      }
      _isNavigating = true;
      try {
        return await _undoNavigator!.redo();
      } finally {
        _isNavigating = false;
      }
    }

    // UndoService mode
    if (_isNavigating || !_canRedo) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _undoService!.redo();
      if (success) {
        await _refreshState();
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
    if (_undoNavigator != null) {
      // UndoNavigator mode
      if (_isNavigating) {
        return false;
      }
      _isNavigating = true;
      try {
        return await _undoNavigator!.scrubToSequence(targetSequence);
      } finally {
        _isNavigating = false;
      }
    }

    // UndoService mode
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;
    try {
      final success = await _undoService!.navigateToSequence(targetSequence);
      if (success) {
        await _refreshState();
      }
      return success;
    } finally {
      _isNavigating = false;
    }
  }

  /// Handles scrubbing to a specific operation group (for history panel).
  ///
  /// [targetGroup]: Operation group to navigate to
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> handleScrubToGroup(dynamic targetGroup) async {
    if (_undoNavigator != null) {
      // UndoNavigator mode
      if (_isNavigating) {
        return false;
      }
      _isNavigating = true;
      try {
        return await _undoNavigator!.scrubToGroup(targetGroup as OperationGroup);
      } finally {
        _isNavigating = false;
      }
    }

    // UndoService mode - not supported
    return false;
  }

  /// Returns the undo stack for history panel display.
  List<OperationGroup> get undoStack {
    if (_undoNavigator != null) {
      return _undoNavigator!.undoStack;
    }
    return const [];
  }

  /// Returns the redo stack for history panel display.
  List<OperationGroup> get redoStack {
    if (_undoNavigator != null) {
      return _undoNavigator!.redoStack;
    }
    return const [];
  }

  @override
  void dispose() {
    if (_undoNavigator != null) {
      _undoNavigator!.removeListener(_onNavigationChanged);
    }
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
