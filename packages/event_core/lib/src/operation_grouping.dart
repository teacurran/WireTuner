/// Operation grouping service for undo/redo boundary detection.
///
/// This module provides automatic operation boundary detection based on
/// idle thresholds, enabling the undo/redo system to group contiguous
/// events into logical operations per Decision 7.
///
/// **Design:**
/// - Listens to event recorder for incoming events
/// - Detects idle periods (default 200ms) to determine operation boundaries
/// - Emits boundary events with descriptions for UI consumption
/// - Supports manual boundary control via explicit API
///
/// **Integration:**
/// - Used by EventRecorder to group sampled events
/// - Consumed by UndoNavigator for operation-based history
/// - Extends Observable for listener notifications (compatible with Flutter's Provider)
///
/// **References:**
/// - Decision 7: Provider-based state management
/// - Task I1.T3: Event recorder interfaces
/// - Task I3.T9: Tool telemetry package
/// - Flow 3 (Behavior doc): Undo operation sequence
library;

import 'dart:async';
import 'package:meta/meta.dart';
import 'package:logger/logger.dart';

import 'metrics_sink.dart';
import 'diagnostics_config.dart';

/// Simple observable base class for non-Flutter packages.
///
/// Provides listener notification mechanism without depending on Flutter.
/// Named to avoid conflicts with Flutter's ChangeNotifier.
abstract class Observable {
  final List<void Function()> _listeners = [];

  /// Registers a listener callback.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a listener callback.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Notifies all registered listeners.
  @protected
  void notifyListeners() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Disposes this object and removes all listeners.
  @mustCallSuper
  void dispose() {
    _listeners.clear();
  }
}

/// Metadata about a recorded event for grouping decisions.
///
/// Lightweight representation that avoids storing full event payloads.
class EventMetadata {
  /// Creates event metadata.
  ///
  /// [eventType]: Type discriminator (e.g., 'MoveObjectEvent')
  /// [sequenceNumber]: Unique monotonic sequence number
  /// [timestamp]: Event timestamp in milliseconds since epoch
  /// [toolLabel]: Optional tool-specific label (e.g., 'pen', 'selection')
  const EventMetadata({
    required this.eventType,
    required this.sequenceNumber,
    required this.timestamp,
    this.toolLabel,
  });

  /// Event type discriminator.
  final String eventType;

  /// Unique sequence number from event store.
  final int sequenceNumber;

  /// Timestamp in milliseconds since epoch.
  final int timestamp;

  /// Optional tool-specific label for undo descriptions.
  final String? toolLabel;

  @override
  String toString() => 'EventMetadata('
      'type: $eventType, '
      'seq: $sequenceNumber, '
      'timestamp: $timestamp, '
      'toolLabel: $toolLabel'
      ')';
}

/// Represents a completed operation group with boundary information.
///
/// Immutable value object containing all metadata needed by UndoNavigator
/// and UI layers for operation-based history navigation.
@immutable
class OperationGroup {
  /// Creates an operation group.
  ///
  /// [groupId]: Unique identifier for this group
  /// [label]: Human-readable description (e.g., 'Create Path', 'Move Objects')
  /// [startSequence]: First event sequence in this group
  /// [endSequence]: Last event sequence in this group
  /// [startTimestamp]: Group start time (milliseconds since epoch)
  /// [endTimestamp]: Group end time (milliseconds since epoch)
  /// [eventCount]: Number of events in this group
  const OperationGroup({
    required this.groupId,
    required this.label,
    required this.startSequence,
    required this.endSequence,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.eventCount,
  });

  /// Unique group identifier.
  final String groupId;

  /// Human-readable operation label for UI display.
  final String label;

  /// First event sequence number in this group.
  final int startSequence;

  /// Last event sequence number in this group.
  final int endSequence;

  /// Start timestamp (milliseconds since epoch).
  final int startTimestamp;

  /// End timestamp (milliseconds since epoch).
  final int endTimestamp;

  /// Number of events in this group.
  final int eventCount;

  /// Duration of this operation in milliseconds.
  int get durationMs => endTimestamp - startTimestamp;

  @override
  String toString() => 'OperationGroup('
      'id: $groupId, '
      'label: "$label", '
      'seq: $startSequence-$endSequence, '
      'events: $eventCount, '
      'duration: ${durationMs}ms'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationGroup &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          label == other.label &&
          startSequence == other.startSequence &&
          endSequence == other.endSequence &&
          startTimestamp == other.startTimestamp &&
          endTimestamp == other.endTimestamp &&
          eventCount == other.eventCount;

  @override
  int get hashCode =>
      Object.hash(
        groupId,
        label,
        startSequence,
        endSequence,
        startTimestamp,
        endTimestamp,
        eventCount,
      );
}

/// Clock abstraction for testability.
///
/// Allows tests to inject deterministic time source.
abstract class Clock {
  /// Returns current timestamp in milliseconds since epoch.
  int now();
}

/// Default clock implementation using DateTime.
class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  int now() => DateTime.now().millisecondsSinceEpoch;
}

/// Operation grouping service with idle threshold detection.
///
/// Automatically groups contiguous events into logical operations for
/// undo/redo navigation. Detects operation boundaries when no events
/// arrive within the idle threshold (default 200ms).
///
/// **Usage:**
/// ```dart
/// final grouping = OperationGroupingService(
///   clock: SystemClock(),
///   metricsSink: metricsSink,
///   logger: logger,
///   config: EventCoreDiagnosticsConfig.debug(),
/// );
///
/// // Listen for completed operations
/// grouping.addListener(() {
///   final group = grouping.lastCompletedGroup;
///   print('Operation completed: ${group?.label}');
/// });
///
/// // Record events
/// grouping.onEventRecorded(EventMetadata(...));
///
/// // Force boundary (e.g., tool switch)
/// grouping.forceBoundary(label: 'Create Path', reason: 'tool_finished');
/// ```
///
/// **Threading:** All methods must be called from UI isolate.
class OperationGroupingService extends Observable {
  /// Creates an operation grouping service.
  ///
  /// [clock]: Time source (inject for testing)
  /// [metricsSink]: Metrics sink for telemetry
  /// [logger]: Logger instance
  /// [config]: Diagnostics configuration
  /// [idleThresholdMs]: Idle period to detect boundaries (default 200ms)
  OperationGroupingService({
    required Clock clock,
    required MetricsSink metricsSink,
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
    int idleThresholdMs = 200,
  })  : _clock = clock,
        _metricsSink = metricsSink,
        _logger = logger,
        _config = config,
        _idleThresholdMs = idleThresholdMs;

  final Clock _clock;
  final MetricsSink _metricsSink;
  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;
  final int _idleThresholdMs;

  /// Active group being accumulated.
  _ActiveGroup? _activeGroup;

  /// Last completed operation group.
  OperationGroup? _lastCompletedGroup;

  /// Pending boundary label (set by startUndoGroup).
  String? _pendingLabel;

  /// Timer for idle detection.
  Timer? _idleTimer;

  /// Counter for generating unique group IDs.
  int _groupCounter = 0;

  /// Total operations completed (for metrics).
  int _totalOperations = 0;

  /// Timestamp of first event in current metrics window.
  int? _metricsWindowStart;

  /// Returns the last completed operation group.
  ///
  /// Used by UI layers to display undo/redo labels.
  /// Returns null if no operations completed yet.
  OperationGroup? get lastCompletedGroup => _lastCompletedGroup;

  /// Returns current idle threshold in milliseconds.
  int get idleThresholdMs => _idleThresholdMs;

  /// Returns whether a group is currently active.
  bool get hasActiveGroup => _activeGroup != null;

  /// Records an event for grouping analysis.
  ///
  /// Called by EventRecorder after persisting each event.
  /// Automatically detects operation boundaries based on idle threshold.
  ///
  /// [metadata]: Lightweight event metadata
  void onEventRecorded(EventMetadata metadata) {
    final now = _clock.now();

    // Cancel previous idle timer
    _idleTimer?.cancel();

    // Initialize metrics window on first event
    _metricsWindowStart ??= now;

    // Create or extend active group
    if (_activeGroup == null) {
      // Start new group
      _activeGroup = _ActiveGroup(
        groupId: 'group_${_groupCounter++}',
        startSequence: metadata.sequenceNumber,
        startTimestamp: now,
        eventCount: 1,
        lastEventTimestamp: now,
        pendingLabel: _pendingLabel,
      );

      if (_config.enableDetailedLogging) {
        _logger.d(
          'Started operation group: ${_activeGroup!.groupId} '
          '(seq: ${metadata.sequenceNumber})',
        );
      }
    } else {
      // Extend existing group
      _activeGroup = _activeGroup!.copyWith(
        eventCount: _activeGroup!.eventCount + 1,
        lastEventTimestamp: now,
      );

      if (_config.enableDetailedLogging) {
        _logger.d(
          'Extended operation group: ${_activeGroup!.groupId} '
          '(events: ${_activeGroup!.eventCount})',
        );
      }
    }

    // Start idle timer to detect boundary
    _idleTimer = Timer(Duration(milliseconds: _idleThresholdMs), () {
      _completeActiveGroup(
        endSequence: metadata.sequenceNumber,
        reason: 'idle_threshold',
      );
    });
  }

  /// Manually starts an undo group with a label.
  ///
  /// Called by tool implementations per undo_labels.md guidelines.
  /// The label will be attached to the next completed operation.
  ///
  /// [label]: Human-readable operation label (e.g., 'Create Path')
  /// [toolId]: Optional tool identifier
  ///
  /// Returns a group ID for correlation with endUndoGroup.
  String startUndoGroup({required String label, String? toolId}) {
    _pendingLabel = label;

    if (_config.enableDetailedLogging) {
      _logger.d('Manual undo group start: label="$label", toolId=$toolId');
    }

    // Return next group ID (will be assigned on first event)
    return 'group_$_groupCounter';
  }

  /// Manually ends an undo group.
  ///
  /// Forces a boundary even if idle threshold hasn't elapsed.
  ///
  /// [groupId]: Group ID from startUndoGroup (for validation)
  /// [label]: Human-readable label (should match startUndoGroup)
  void endUndoGroup({required String groupId, required String label}) {
    if (_activeGroup == null) {
      _logger.w('endUndoGroup called with no active group: $groupId');
      return;
    }

    // Use the most recent event's sequence as end boundary
    final lastSeq = _activeGroup!.startSequence + _activeGroup!.eventCount - 1;

    _completeActiveGroup(
      endSequence: lastSeq,
      reason: 'manual_end',
      label: label,
    );
  }

  /// Forces an operation boundary with an optional label.
  ///
  /// Used when operation should end immediately (e.g., tool switch,
  /// explicit finish action like Enter key in pen tool).
  ///
  /// [label]: Optional human-readable label for the completed operation
  /// [reason]: Telemetry reason for forced boundary
  void forceBoundary({String? label, required String reason}) {
    if (_activeGroup == null) {
      if (_config.enableDetailedLogging) {
        _logger.d('forceBoundary called with no active group: $reason');
      }
      return;
    }

    // Use the most recent event's sequence
    final lastSeq = _activeGroup!.startSequence + _activeGroup!.eventCount - 1;

    _completeActiveGroup(
      endSequence: lastSeq,
      reason: reason,
      label: label,
    );
  }

  /// Cancels the current operation without completing it.
  ///
  /// Used when user cancels an action (e.g., Escape during path creation).
  /// No operation group is emitted, and no undo entry is created.
  void cancelOperation() {
    if (_activeGroup == null) {
      if (_config.enableDetailedLogging) {
        _logger.d('cancelOperation called with no active group');
      }
      return;
    }

    if (_config.enableDetailedLogging) {
      _logger.d('Canceled operation group: ${_activeGroup!.groupId}');
    }

    _activeGroup = null;
    _pendingLabel = null;
    _idleTimer?.cancel();
    _idleTimer = null;

    // Notify listeners (UI may need to update)
    notifyListeners();
  }

  /// Completes the active group and emits boundary event.
  void _completeActiveGroup({
    required int endSequence,
    required String reason,
    String? label,
  }) {
    final group = _activeGroup;
    if (group == null) return;

    _idleTimer?.cancel();
    _idleTimer = null;

    final now = _clock.now();

    // Determine final label (explicit > pending > fallback)
    final finalLabel = label ?? group.pendingLabel ?? 'Operation';

    // Create immutable operation group
    final operationGroup = OperationGroup(
      groupId: group.groupId,
      label: finalLabel,
      startSequence: group.startSequence,
      endSequence: endSequence,
      startTimestamp: group.startTimestamp,
      endTimestamp: now,
      eventCount: group.eventCount,
    );

    _lastCompletedGroup = operationGroup;
    _activeGroup = null;
    _pendingLabel = null;
    _totalOperations++;

    // Log completion
    if (_config.enableDetailedLogging) {
      _logger.d(
        'Completed operation: $operationGroup (reason: $reason)',
      );
    } else {
      _logger.i('Operation completed: "$finalLabel" ($reason)');
    }

    // Record metrics
    if (_config.enableMetrics) {
      _recordOperationMetrics(operationGroup);
    }

    // Notify listeners (triggers UI updates via Provider)
    notifyListeners();
  }

  /// Records operation metrics.
  void _recordOperationMetrics(OperationGroup group) {
    // Use recordEvent as a generic metrics channel
    // (MetricsSink doesn't have operation-specific method yet)
    _metricsSink.recordEvent(
      eventType: 'OperationGroupCompleted',
      sampled: false,
      durationMs: group.durationMs,
    );

    // Calculate operations/sec for this metrics window
    final windowStart = _metricsWindowStart;
    if (windowStart != null) {
      final windowDurationSec = (_clock.now() - windowStart) / 1000.0;
      if (windowDurationSec >= 1.0) {
        final operationsPerSec = _totalOperations / windowDurationSec;

        if (_config.enableDetailedLogging) {
          _logger.d(
            'Operations/sec: ${operationsPerSec.toStringAsFixed(2)} '
            '(${_totalOperations} ops in ${windowDurationSec.toStringAsFixed(1)}s)',
          );
        }

        // Reset metrics window
        _totalOperations = 0;
        _metricsWindowStart = null;
      }
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}

/// Internal mutable state for active group accumulation.
class _ActiveGroup {
  const _ActiveGroup({
    required this.groupId,
    required this.startSequence,
    required this.startTimestamp,
    required this.eventCount,
    required this.lastEventTimestamp,
    this.pendingLabel,
  });

  final String groupId;
  final int startSequence;
  final int startTimestamp;
  final int eventCount;
  final int lastEventTimestamp;
  final String? pendingLabel;

  _ActiveGroup copyWith({
    int? eventCount,
    int? lastEventTimestamp,
  }) =>
      _ActiveGroup(
        groupId: groupId,
        startSequence: startSequence,
        startTimestamp: startTimestamp,
        eventCount: eventCount ?? this.eventCount,
        lastEventTimestamp: lastEventTimestamp ?? this.lastEventTimestamp,
        pendingLabel: pendingLabel,
      );
}
