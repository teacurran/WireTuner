/// Undo/redo navigator service for operation-based history navigation.
///
/// This module provides time-travel navigation through the event history,
/// operating on completed operation groups rather than individual events
/// per Decision 7 and Iteration 4 requirements.
///
/// **Design:**
/// - Maintains dual-stack architecture (undo/redo stacks) for operation groups
/// - Integrates with EventReplayer for state reconstruction
/// - Subscribes to OperationGrouping for automatic boundary detection
/// - Invalidates redo branch when new operations occur after undo
/// - Supports arbitrary scrubbing to historical points
///
/// **Integration:**
/// - Listens to OperationGroupingService for completed operations
/// - Delegates state reconstruction to EventReplayer
/// - Consumed by UndoProvider for Flutter UI integration
/// - Extends Observable for listener notifications (compatible with Provider)
///
/// **References:**
/// - Decision 7: Provider-based state management
/// - Task I4.T3: Undo/redo navigator implementation
/// - Flow 3 (Behavior doc): Undo operation sequence
library;

import 'package:logger/logger.dart';

import 'operation_grouping.dart';
import 'event_replayer.dart';
import 'metrics_sink.dart';
import 'diagnostics_config.dart';

/// Undo/redo navigator service with operation-based history.
///
/// Provides time-travel navigation through the event history using
/// completed operation groups as boundaries. Maintains separate undo/redo
/// stacks and invalidates redo when new operations occur after undo.
///
/// **Usage:**
/// ```dart
/// final navigator = UndoNavigator(
///   operationGrouping: operationGrouping,
///   eventReplayer: eventReplayer,
///   metricsSink: metricsSink,
///   logger: logger,
///   config: EventCoreDiagnosticsConfig.debug(),
///   documentId: 'doc-123', // For multi-window isolation
/// );
///
/// // Listen for navigation events
/// navigator.addListener(() {
///   print('Navigation changed: ${navigator.currentOperationName}');
/// });
///
/// // Perform undo
/// await navigator.undo();
///
/// // Perform redo
/// await navigator.redo();
///
/// // Scrub to specific sequence
/// await navigator.scrubToSequence(5000);
/// ```
///
/// **Threading:** All methods must be called from UI isolate.
class UndoNavigator extends Observable {
  /// Creates an undo navigator.
  ///
  /// [operationGrouping]: Source of completed operation groups
  /// [eventReplayer]: Handles state reconstruction
  /// [metricsSink]: Metrics sink for telemetry
  /// [logger]: Logger instance
  /// [config]: Diagnostics configuration
  /// [documentId]: Document identifier for multi-window isolation
  UndoNavigator({
    required OperationGroupingService operationGrouping,
    required EventReplayer eventReplayer,
    required MetricsSink metricsSink,
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
    String? documentId,
  })  : _operationGrouping = operationGrouping,
        _eventReplayer = eventReplayer,
        _metricsSink = metricsSink,
        _logger = logger,
        _config = config,
        _documentId = documentId ?? 'default' {
    // Subscribe to operation grouping for new operations
    _operationGrouping.addListener(_onOperationCompleted);
  }

  final OperationGroupingService _operationGrouping;
  final EventReplayer _eventReplayer;
  final MetricsSink _metricsSink;
  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;
  final String _documentId;

  /// Stack of operation groups that can be undone.
  /// Most recent operation is at the end.
  final List<OperationGroup> _undoStack = [];

  /// Stack of operation groups that can be redone.
  /// Most recently undone operation is at the end.
  final List<OperationGroup> _redoStack = [];

  /// Current sequence number in the event timeline.
  /// Initially 0 (start of history).
  int _currentSequence = 0;

  /// Returns whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Returns whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Returns the current operation name (for UI display).
  ///
  /// Returns the label of the most recent operation in the undo stack,
  /// or null if no operations have been performed.
  String? get currentOperationName =>
      _undoStack.isEmpty ? null : _undoStack.last.label;

  /// Returns the operation name that would be undone.
  ///
  /// Used for "Undo [action]" menu labels.
  String? get undoOperationName =>
      _undoStack.isEmpty ? null : _undoStack.last.label;

  /// Returns the operation name that would be redone.
  ///
  /// Used for "Redo [action]" menu labels.
  String? get redoOperationName =>
      _redoStack.isEmpty ? null : _redoStack.last.label;

  /// Returns the current sequence number.
  int get currentSequence => _currentSequence;

  /// Returns a copy of the undo stack for inspection.
  List<OperationGroup> get undoStack => List.unmodifiable(_undoStack);

  /// Returns a copy of the redo stack for inspection.
  List<OperationGroup> get redoStack => List.unmodifiable(_redoStack);

  /// Performs undo operation.
  ///
  /// Navigates to the previous operation group by:
  /// 1. Popping the current operation from undo stack
  /// 2. Pushing it onto redo stack
  /// 3. Calculating target sequence (end of previous operation or 0)
  /// 4. Calling EventReplayer to reconstruct state at target sequence
  ///
  /// Returns Future<bool> indicating success (false if nothing to undo).
  Future<bool> undo() async {
    if (!canUndo) {
      if (_config.enableDetailedLogging) {
        _logger.d('[$_documentId] Undo called with empty undo stack');
      }
      return false;
    }

    final operation = _undoStack.removeLast();
    _redoStack.add(operation);

    // Calculate target sequence (end of previous operation, or 0 if at start)
    final targetSequence =
        _undoStack.isEmpty ? 0 : _undoStack.last.endSequence;

    if (_config.enableDetailedLogging) {
      _logger.d(
        '[$_documentId] Undoing operation: "${operation.label}" '
        '(seq: ${operation.startSequence}-${operation.endSequence}) '
        '-> target: $targetSequence',
      );
    } else {
      _logger.i('[$_documentId] Undo: "${operation.label}"');
    }

    // Perform time-travel via replayer
    final success = await _navigateToSequence(
      targetSequence,
      operation: operation,
      isUndo: true,
    );

    if (success) {
      _currentSequence = targetSequence;
      notifyListeners();
    } else {
      // Rollback stack change on failure
      _undoStack.add(operation);
      _redoStack.removeLast();
      _logger.e('[$_documentId] Undo failed for operation: "${operation.label}"');
    }

    return success;
  }

  /// Performs redo operation.
  ///
  /// Navigates forward to the previously undone operation by:
  /// 1. Popping the operation from redo stack
  /// 2. Pushing it back onto undo stack
  /// 3. Calculating target sequence (end of operation)
  /// 4. Calling EventReplayer to reconstruct state
  ///
  /// Returns Future<bool> indicating success (false if nothing to redo).
  Future<bool> redo() async {
    if (!canRedo) {
      if (_config.enableDetailedLogging) {
        _logger.d('[$_documentId] Redo called with empty redo stack');
      }
      return false;
    }

    final operation = _redoStack.removeLast();
    _undoStack.add(operation);

    // Target is the end of the operation being redone
    final targetSequence = operation.endSequence;

    if (_config.enableDetailedLogging) {
      _logger.d(
        '[$_documentId] Redoing operation: "${operation.label}" '
        '(seq: ${operation.startSequence}-${operation.endSequence})',
      );
    } else {
      _logger.i('[$_documentId] Redo: "${operation.label}"');
    }

    // Perform time-travel via replayer
    final success = await _navigateToSequence(
      targetSequence,
      operation: operation,
      isUndo: false,
    );

    if (success) {
      _currentSequence = targetSequence;
      notifyListeners();
    } else {
      // Rollback stack change on failure
      _redoStack.add(operation);
      _undoStack.removeLast();
      _logger.e('[$_documentId] Redo failed for operation: "${operation.label}"');
    }

    return success;
  }

  /// Scrubs to a specific sequence number.
  ///
  /// Allows arbitrary navigation to any point in the event history.
  /// Reorganizes undo/redo stacks based on the target sequence.
  ///
  /// [targetSequence]: Event sequence number to navigate to
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> scrubToSequence(int targetSequence) async {
    if (targetSequence < 0) {
      _logger.w('[$_documentId] Invalid scrub target: $targetSequence');
      return false;
    }

    if (targetSequence == _currentSequence) {
      if (_config.enableDetailedLogging) {
        _logger.d('[$_documentId] Scrub to current sequence (no-op)');
      }
      return true;
    }

    if (_config.enableDetailedLogging) {
      _logger.d(
        '[$_documentId] Scrubbing from $currentSequence to $targetSequence',
      );
    }

    // Reorganize stacks based on target
    _reorganizeStacksForSequence(targetSequence);

    // Perform time-travel via replayer
    final success = await _navigateToSequence(targetSequence);

    if (success) {
      _currentSequence = targetSequence;
      notifyListeners();
    }

    return success;
  }

  /// Scrubs to a specific operation group.
  ///
  /// Convenience method that scrubs to the end sequence of the given operation.
  ///
  /// [targetGroup]: Operation group to navigate to
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> scrubToGroup(OperationGroup targetGroup) async =>
      scrubToSequence(targetGroup.endSequence);

  /// Resets the navigator to initial state.
  ///
  /// Clears all undo/redo stacks and resets current sequence to 0.
  /// Used when loading a new document or resetting state.
  void reset() {
    _undoStack.clear();
    _redoStack.clear();
    _currentSequence = 0;

    _logger.i('[$_documentId] Navigator reset');
    notifyListeners();
  }

  /// Handles completed operations from OperationGroupingService.
  void _onOperationCompleted() {
    final completedGroup = _operationGrouping.lastCompletedGroup;
    if (completedGroup == null) return;

    // Only add if this operation is after our current sequence
    // (prevents adding operations during replay)
    if (completedGroup.endSequence > _currentSequence) {
      _undoStack.add(completedGroup);
      _currentSequence = completedGroup.endSequence;

      // Invalidate redo branch if we're not at the end of history
      if (_redoStack.isNotEmpty) {
        if (_config.enableDetailedLogging) {
          _logger.d(
            '[$_documentId] New operation after undo: invalidating redo branch '
            '(${_redoStack.length} operations dropped)',
          );
        } else {
          _logger.i('[$_documentId] Redo branch invalidated (new operation)');
        }
        _redoStack.clear();
      }

      if (_config.enableDetailedLogging) {
        _logger.d(
          '[$_documentId] Operation added to history: "${completedGroup.label}" '
          '(undo stack: ${_undoStack.length})',
        );
      }

      notifyListeners();
    }
  }

  /// Navigates to the target sequence using EventReplayer.
  ///
  /// Chooses optimal replay strategy (from snapshot or from beginning)
  /// and records navigation metrics.
  ///
  /// [targetSequence]: Target event sequence
  /// [operation]: Optional operation being navigated (for logging)
  /// [isUndo]: Whether this is an undo operation (for metrics)
  ///
  /// Returns Future<bool> indicating success.
  Future<bool> _navigateToSequence(
    int targetSequence, {
    OperationGroup? operation,
    bool? isUndo,
  }) async {
    try {
      final startTime = DateTime.now();

      // Use snapshot-based replay for efficiency
      // EventReplayer will find nearest snapshot and replay forward
      await _eventReplayer.replayFromSnapshot(maxSequence: targetSequence);

      final durationMs = DateTime.now().difference(startTime).inMilliseconds;

      // Record navigation metrics
      if (_config.enableMetrics) {
        _metricsSink.recordEvent(
          eventType: isUndo == true
              ? 'UndoNavigation'
              : isUndo == false
                  ? 'RedoNavigation'
                  : 'ScrubNavigation',
          sampled: false,
          durationMs: durationMs,
        );
      }

      // Warn if navigation exceeds target latency
      if (durationMs > 80) {
        _logger.w(
          '[$_documentId] Navigation latency ${durationMs}ms exceeds target (80ms) '
          'for operation: ${operation?.label ?? "scrub"}',
        );
      }

      return true;
    } catch (e, stackTrace) {
      _logger.e(
        '[$_documentId] Navigation failed to sequence $targetSequence',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Reorganizes undo/redo stacks for a target sequence.
  ///
  /// Moves operations between stacks to reflect the target position
  /// in the timeline.
  void _reorganizeStacksForSequence(int targetSequence) {
    // Combine all operations from both stacks, sorted by sequence
    final allOperations = [..._undoStack, ..._redoStack]
      ..sort((a, b) => a.endSequence.compareTo(b.endSequence));

    _undoStack.clear();
    _redoStack.clear();

    // Split operations based on target sequence
    for (final op in allOperations) {
      if (op.endSequence <= targetSequence) {
        _undoStack.add(op);
      } else {
        _redoStack.add(op);
      }
    }

    if (_config.enableDetailedLogging) {
      _logger.d(
        '[$_documentId] Stacks reorganized for sequence $targetSequence: '
        'undo=${_undoStack.length}, redo=${_redoStack.length}',
      );
    }
  }

  @override
  void dispose() {
    _operationGrouping.removeListener(_onOperationCompleted);
    super.dispose();
  }
}
