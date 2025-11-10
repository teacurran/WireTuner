import 'package:flutter/foundation.dart';
import 'package:wiretuner/application/services/undo_service.dart';

/// Flutter ChangeNotifier wrapper around UndoService for reactive UI updates.
///
/// This provider exposes undo/redo state and operations to the Flutter widget tree.
/// It wraps the UndoService (which uses EventNavigator internally) and provides
/// a ChangeNotifier interface for UI components to react to undo/redo state changes.
///
/// **Usage:**
/// ```dart
/// // Setup in provider tree
/// ChangeNotifierProvider<UndoStateProvider>(
///   create: (_) => UndoStateProvider(undoService: undoService),
/// )
///
/// // Access in widgets
/// final undoState = context.watch<UndoStateProvider>();
/// final canUndo = undoState.canUndo;
/// ```
///
/// **Integration with Keyboard Shortcuts:**
/// ```dart
/// Actions(
///   actions: {
///     UndoIntent: CallbackAction<UndoIntent>(
///       onInvoke: (_) => context.read<UndoStateProvider>().handleUndo(),
///     ),
///   },
/// )
/// ```
class UndoStateProvider extends ChangeNotifier {
  /// Creates an undo state provider.
  ///
  /// **Parameters:**
  /// - [undoService]: The UndoService that manages event navigation
  UndoStateProvider({required UndoService undoService})
      : _undoService = undoService;

  final UndoService _undoService;

  /// Flag to track whether a navigation operation is in progress.
  /// Prevents re-entrancy issues.
  bool _isNavigating = false;

  /// Cached canUndo state (updated by _refreshState).
  bool _canUndo = false;

  /// Cached canRedo state (updated by _refreshState).
  bool _canRedo = false;

  /// Returns whether undo is available.
  bool get canUndo => _canUndo;

  /// Returns whether redo is available.
  bool get canRedo => _canRedo;

  /// Returns the current event sequence number.
  int get currentSequence => _undoService.currentSequence;

  /// Returns the maximum event sequence number.
  int get maxSequence => _undoService.maxSequence;

  /// Returns whether a navigation operation is in progress.
  bool get isNavigating => _isNavigating;

  /// Initializes the provider by loading initial undo/redo state.
  ///
  /// This should be called once after creating the provider.
  ///
  /// **Returns:** true if initialization succeeded, false otherwise
  Future<bool> initialize() async {
    final success = await _undoService.initialize();
    if (success) {
      await _refreshState();
    }
    return success;
  }

  /// Handles undo command from keyboard shortcut or menu.
  ///
  /// **Returns:** Future<bool> indicating success
  Future<bool> handleUndo() async {
    if (_isNavigating || !_canUndo) {
      return false;
    }

    _isNavigating = true;
    notifyListeners();

    try {
      final success = await _undoService.undo();
      if (success) {
        await _refreshState();
      }
      return success;
    } finally {
      _isNavigating = false;
      notifyListeners();
    }
  }

  /// Handles redo command from keyboard shortcut or menu.
  ///
  /// **Returns:** Future<bool> indicating success
  Future<bool> handleRedo() async {
    if (_isNavigating || !_canRedo) {
      return false;
    }

    _isNavigating = true;
    notifyListeners();

    try {
      final success = await _undoService.redo();
      if (success) {
        await _refreshState();
      }
      return success;
    } finally {
      _isNavigating = false;
      notifyListeners();
    }
  }

  /// Handles scrubbing to a specific sequence number.
  ///
  /// This is used for timeline/history panel navigation.
  ///
  /// **Parameters:**
  /// - [targetSequence]: Event sequence number to navigate to
  ///
  /// **Returns:** Future<bool> indicating success
  Future<bool> handleScrub(int targetSequence) async {
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;
    notifyListeners();

    try {
      final success = await _undoService.navigateToSequence(targetSequence);
      if (success) {
        await _refreshState();
      }
      return success;
    } finally {
      _isNavigating = false;
      notifyListeners();
    }
  }

  /// Refreshes the cached undo/redo state.
  ///
  /// This queries the UndoService for the current canUndo/canRedo state
  /// and triggers a notification if the state has changed.
  Future<void> _refreshState() async {
    final newCanUndo = await _undoService.canUndo();
    final newCanRedo = await _undoService.canRedo();

    if (newCanUndo != _canUndo || newCanRedo != _canRedo) {
      _canUndo = newCanUndo;
      _canRedo = newCanRedo;
      notifyListeners();
    }
  }

  /// Clears the navigator cache.
  void clearCache() {
    _undoService.clearCache();
  }

  /// Returns cache statistics for debugging.
  Map<String, dynamic> getCacheStats() => _undoService.getCacheStats();
}
