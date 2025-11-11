import 'package:event_core/event_core.dart';

/// View model for history panel displaying operation groups.
///
/// This view model combines undo/redo stacks into a unified timeline view
/// with the current position marked. It supports filtering and search
/// operations on operation labels.
///
/// **Timeline Structure:**
/// ```
/// [Oldest]                    [Current]                    [Newest]
/// undo[0]...undo[n-2], undo[n-1] ► current, redo[0], redo[1]...redo[m]
/// ```
///
/// Related: Task I4.T4 (History Panel UI), Decision 7 (Provider pattern)
class HistoryViewModel {
  /// Creates a history view model from undo/redo stacks.
  ///
  /// [undoStack]: Past operations (oldest first)
  /// [redoStack]: Future operations (most recent first)
  /// [searchQuery]: Optional filter text
  HistoryViewModel({
    required List<OperationGroup> undoStack,
    required List<OperationGroup> redoStack,
    String? searchQuery,
  })  : _undoStack = undoStack,
        _redoStack = redoStack,
        _searchQuery = searchQuery?.toLowerCase();

  final List<OperationGroup> _undoStack;
  final List<OperationGroup> _redoStack;
  final String? _searchQuery;

  /// Returns all operation groups in chronological order.
  ///
  /// Combines undo stack (past) and redo stack (future) into a single
  /// timeline with filtering applied if search query is active.
  List<HistoryEntry> get timeline {
    final entries = <HistoryEntry>[];

    // Add undo stack (past operations, oldest first)
    for (var i = 0; i < _undoStack.length; i++) {
      final group = _undoStack[i];
      if (_matchesSearch(group)) {
        entries.add(HistoryEntry(
          group: group,
          isCurrent: i == _undoStack.length - 1 && _redoStack.isEmpty,
          isPast: true,
          index: i,
        ));
      }
    }

    // Add redo stack (future operations)
    for (var i = 0; i < _redoStack.length; i++) {
      final group = _redoStack[i];
      if (_matchesSearch(group)) {
        entries.add(HistoryEntry(
          group: group,
          isCurrent: i == 0 && _undoStack.isEmpty,
          isPast: false,
          index: _undoStack.length + i,
        ));
      }
    }

    return entries;
  }

  /// Returns the index of the current position in the timeline.
  ///
  /// This is the last operation in the undo stack, or -1 if empty.
  int get currentIndex {
    if (_undoStack.isEmpty) return -1;
    return _undoStack.length - 1;
  }

  /// Returns whether the timeline is empty.
  bool get isEmpty => _undoStack.isEmpty && _redoStack.isEmpty;

  /// Returns the total number of operations (before filtering).
  int get totalOperations => _undoStack.length + _redoStack.length;

  /// Checks if an operation group matches the search query.
  bool _matchesSearch(OperationGroup group) {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return true;
    }
    return group.label.toLowerCase().contains(_searchQuery!);
  }
}

/// Represents a single entry in the history timeline.
///
/// Combines operation metadata with timeline position information.
class HistoryEntry {
  /// Creates a history entry.
  const HistoryEntry({
    required this.group,
    required this.isCurrent,
    required this.isPast,
    required this.index,
  });

  /// Operation group metadata.
  final OperationGroup group;

  /// Whether this is the current position (marked with ►).
  final bool isCurrent;

  /// Whether this operation is in the past (undo stack).
  final bool isPast;

  /// Index in the combined timeline.
  final int index;

  /// Whether this operation can be undone.
  bool get canUndo => isPast && isCurrent;

  /// Whether this operation can be redone.
  bool get canRedo => !isPast;
}
