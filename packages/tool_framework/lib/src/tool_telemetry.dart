/// Tool telemetry and undo boundary annotation system.
///
/// This module provides telemetry tracking and undo grouping support for tools
/// in the WireTuner application. It ensures that:
/// 1. Tool operations flush pending sampled events correctly
/// 2. Human-readable labels are emitted for undo/redo UI
/// 3. Tool usage metrics are tracked and aggregated
///
/// ## Architecture
///
/// The telemetry system integrates with:
/// - Event sourcing (via event recorder flush operations)
/// - Metrics infrastructure (MetricsSink pattern from I1.T8)
/// - Undo/redo system (StartGroupEvent/EndGroupEvent metadata)
/// - UI layer (Provider-based label propagation per Decision 7)
///
/// ## Usage
///
/// ```dart
/// final telemetry = ToolTelemetry(
///   logger: logger,
///   config: EventCoreDiagnosticsConfig.debug(),
/// );
///
/// // Start an undo group
/// final groupId = telemetry.startUndoGroup(
///   toolId: 'pen',
///   label: 'Create path',
/// );
///
/// // Record sampled events
/// telemetry.recordSample(
///   toolId: 'pen',
///   eventType: 'AddAnchorEvent',
/// );
///
/// // End the undo group
/// telemetry.endUndoGroup(
///   toolId: 'pen',
///   groupId: groupId,
///   label: 'Create path',
/// );
///
/// // Flush metrics periodically
/// await telemetry.flush();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';

/// Telemetry and undo boundary tracking for tools.
///
/// This class provides:
/// - Undo group lifecycle tracking (start/sample/end)
/// - Human-readable label registration for UI surfaces
/// - Tool usage metrics aggregation (activation counts, operation counts)
/// - Flush contract compatible with MetricsSink pattern
///
/// Thread-safe for Flutter's single-threaded execution model but NOT
/// safe for concurrent access across isolates.
class ToolTelemetry extends ChangeNotifier {
  /// Creates a tool telemetry tracker.
  ///
  /// [logger]: Logger instance for emitting metrics
  /// [config]: Diagnostics configuration controlling metric behavior
  ToolTelemetry({
    required Logger logger,
    required EventCoreDiagnosticsConfig config,
  })  : _logger = logger,
        _config = config;

  final Logger _logger;
  final EventCoreDiagnosticsConfig _config;

  // ========== Aggregated Metrics ==========

  /// Tool activation counts by tool ID.
  /// Maps toolId -> activation count.
  final Map<String, int> _activationCounts = {};

  /// Tool operation counts by tool ID and operation type.
  /// Maps toolId -> (operationType -> count).
  final Map<String, Map<String, int>> _operationCounts = {};

  /// Sample event counts by tool ID.
  /// Tracks sampled events emitted during pointer operations.
  final Map<String, int> _sampleCounts = {};

  /// Total undo group completions by tool ID.
  final Map<String, int> _undoGroupCompletions = {};

  // ========== Active Undo Group Tracking ==========

  /// Currently active undo groups by tool ID.
  /// Maps toolId -> groupId.
  /// Ensures only one undo group per tool is active at a time.
  final Map<String, String> _activeUndoGroups = {};

  /// Sample counts for active undo groups.
  /// Maps groupId -> sample count.
  /// Used to warn if groups have excessive sampled events.
  final Map<String, int> _activeGroupSampleCounts = {};

  // ========== Undo Label Tracking ==========

  /// Last completed operation label by tool ID.
  /// Exposed via Provider for UI binding (Decision 7).
  /// Maps toolId -> human-readable label (e.g., "Move Rectangle").
  final Map<String, String> _lastCompletedLabels = {};

  /// Returns the last completed operation label for a tool.
  ///
  /// This getter is intended for Provider consumption so menus and
  /// history panels can display undo/redo labels immediately.
  ///
  /// Returns null if no operations have completed for the tool.
  String? getLastCompletedLabel(String toolId) => _lastCompletedLabels[toolId];

  /// Returns all last completed labels (for history panels).
  Map<String, String> get allLastCompletedLabels =>
      Map.unmodifiable(_lastCompletedLabels);

  // ========== Public API ==========

  /// Starts a new undo group for a tool operation.
  ///
  /// This should be called when a pointer-driven operation begins
  /// (e.g., pointer down on a drag operation).
  ///
  /// Returns the groupId that should be used for subsequent samples
  /// and the final endUndoGroup call.
  ///
  /// Throws [StateError] if an undo group is already active for this tool.
  ///
  /// [toolId]: Tool identifier (e.g., 'pen', 'selection', 'direct_selection')
  /// [label]: Human-readable operation label (e.g., "Create path", "Move Rectangle")
  ///
  /// Example:
  /// ```dart
  /// final groupId = telemetry.startUndoGroup(
  ///   toolId: 'pen',
  ///   label: 'Create path',
  /// );
  /// ```
  String startUndoGroup({
    required String toolId,
    required String label,
  }) {
    if (!_config.enableMetrics) {
      return ''; // Metrics disabled, return empty groupId
    }

    // Validate no active group exists for this tool
    if (_activeUndoGroups.containsKey(toolId)) {
      final activeGroupId = _activeUndoGroups[toolId]!;
      _logger.e(
        'Tool "$toolId" attempted to start new undo group while group "$activeGroupId" is still active. '
        'This indicates missing endUndoGroup call.',
      );
      throw StateError(
        'Tool "$toolId" already has active undo group: $activeGroupId',
      );
    }

    // Generate new group ID
    final groupId = 'undo-$toolId-${DateTime.now().millisecondsSinceEpoch}';

    // Register active group
    _activeUndoGroups[toolId] = groupId;
    _activeGroupSampleCounts[groupId] = 0;

    if (_config.enableDetailedLogging) {
      _logger.d(
        'Undo group started: tool=$toolId, groupId=$groupId, label="$label"',
      );
    }

    return groupId;
  }

  /// Records a sampled event during an active undo group.
  ///
  /// This should be called for each sampled event emitted during
  /// a pointer operation (e.g., each 50ms sample during a drag).
  ///
  /// [toolId]: Tool identifier
  /// [eventType]: Event type name (e.g., 'AddAnchorEvent', 'MoveObjectEvent')
  ///
  /// Example:
  /// ```dart
  /// // During pointer move handler
  /// telemetry.recordSample(
  ///   toolId: 'direct_selection',
  ///   eventType: 'ModifyAnchorEvent',
  /// );
  /// ```
  void recordSample({
    required String toolId,
    required String eventType,
  }) {
    if (!_config.enableMetrics) return;

    // Track sample count for active group
    if (_activeUndoGroups.containsKey(toolId)) {
      final groupId = _activeUndoGroups[toolId]!;
      _activeGroupSampleCounts[groupId] =
          (_activeGroupSampleCounts[groupId] ?? 0) + 1;
    } else {
      _logger.w(
        'Sample recorded for tool "$toolId" but no active undo group. '
        'This may indicate missing startUndoGroup call.',
      );
    }

    // Increment sample count for tool
    _sampleCounts[toolId] = (_sampleCounts[toolId] ?? 0) + 1;

    // Increment operation count
    _operationCounts.putIfAbsent(toolId, () => {});
    _operationCounts[toolId]![eventType] =
        (_operationCounts[toolId]![eventType] ?? 0) + 1;

    if (_config.enableDetailedLogging) {
      _logger.d('Sample recorded: tool=$toolId, eventType=$eventType');
    }
  }

  /// Ends an active undo group.
  ///
  /// This should be called when a pointer-driven operation completes
  /// (e.g., pointer up after a drag).
  ///
  /// Validates that the groupId matches the active group and logs
  /// warnings if the group has excessive sampled events (> 100).
  ///
  /// [toolId]: Tool identifier
  /// [groupId]: Group ID returned from startUndoGroup
  /// [label]: Human-readable operation label (same as startUndoGroup)
  ///
  /// Throws [StateError] if no undo group is active or groupId mismatch.
  ///
  /// Example:
  /// ```dart
  /// telemetry.endUndoGroup(
  ///   toolId: 'pen',
  ///   groupId: groupId,
  ///   label: 'Create path',
  /// );
  /// ```
  void endUndoGroup({
    required String toolId,
    required String groupId,
    required String label,
  }) {
    if (!_config.enableMetrics) return;

    // Validate active group exists
    if (!_activeUndoGroups.containsKey(toolId)) {
      _logger.e(
        'Tool "$toolId" attempted to end undo group but no group is active. '
        'This indicates missing startUndoGroup call.',
      );
      throw StateError(
        'Tool "$toolId" has no active undo group to end',
      );
    }

    // Validate group ID matches
    final activeGroupId = _activeUndoGroups[toolId]!;
    if (activeGroupId != groupId) {
      _logger.e(
        'Tool "$toolId" attempted to end undo group "$groupId" but active group is "$activeGroupId". '
        'This indicates groupId mismatch or concurrent group operations.',
      );
      throw StateError(
        'Undo group ID mismatch for tool "$toolId": expected $activeGroupId, got $groupId',
      );
    }

    // Check for excessive sampled events
    final sampleCount = _activeGroupSampleCounts[groupId] ?? 0;
    if (sampleCount > 100) {
      _logger.w(
        'Undo group has excessive sampled events: '
        'tool=$toolId, groupId=$groupId, samples=$sampleCount (>100)',
      );
    }

    // Update completion metrics
    _undoGroupCompletions[toolId] = (_undoGroupCompletions[toolId] ?? 0) + 1;
    _lastCompletedLabels[toolId] = label;

    // Clean up active group tracking
    _activeUndoGroups.remove(toolId);
    _activeGroupSampleCounts.remove(groupId);

    // Log completion at INFO level (important lifecycle event)
    _logger.i(
      'Undo group completed: tool=$toolId, label="$label", samples=$sampleCount',
    );

    // Notify listeners (Provider propagation for UI)
    notifyListeners();
  }

  /// Records a tool activation.
  ///
  /// This should be called when a tool is activated via ToolManager.
  ///
  /// [toolId]: Tool identifier
  ///
  /// Example:
  /// ```dart
  /// // Inside ToolManager.activateTool
  /// telemetry.recordActivation('pen');
  /// ```
  void recordActivation(String toolId) {
    if (!_config.enableMetrics) return;

    _activationCounts[toolId] = (_activationCounts[toolId] ?? 0) + 1;

    if (_config.enableDetailedLogging) {
      _logger.d('Tool activated: $toolId');
    }
  }

  /// Flushes buffered metrics to the logger.
  ///
  /// Called periodically or on application shutdown to ensure metrics
  /// are not lost. Emits aggregated statistics at INFO level.
  ///
  /// Resets counters after flush (matching MetricsSink contract).
  ///
  /// Example:
  /// ```dart
  /// // Inside ToolManager.handlePointerUp or deactivation
  /// await telemetry.flush();
  /// ```
  Future<void> flush() async {
    if (!_config.enableMetrics) return;

    // Emit aggregated tool activation metrics
    if (_activationCounts.isNotEmpty) {
      final totalActivations =
          _activationCounts.values.reduce((a, b) => a + b);
      _logger.i(
        'Tool activation metrics: total=$totalActivations, '
        'byTool=${_activationCounts}',
      );
    }

    // Emit aggregated operation metrics
    if (_operationCounts.isNotEmpty) {
      for (final entry in _operationCounts.entries) {
        final toolId = entry.key;
        final operations = entry.value;
        final totalOps = operations.values.reduce((a, b) => a + b);
        _logger.i(
          'Tool operation metrics: tool=$toolId, totalOps=$totalOps, '
          'byType=$operations',
        );
      }
    }

    // Emit sample event metrics
    if (_sampleCounts.isNotEmpty) {
      final totalSamples = _sampleCounts.values.reduce((a, b) => a + b);
      _logger.i(
        'Tool sample metrics: total=$totalSamples, '
        'byTool=${_sampleCounts}',
      );
    }

    // Emit undo group completion metrics
    if (_undoGroupCompletions.isNotEmpty) {
      final totalCompletions =
          _undoGroupCompletions.values.reduce((a, b) => a + b);
      _logger.i(
        'Undo group completion metrics: total=$totalCompletions, '
        'byTool=${_undoGroupCompletions}',
      );
    }

    // Warn if active groups remain (indicates missing endUndoGroup)
    if (_activeUndoGroups.isNotEmpty) {
      _logger.w(
        'Active undo groups remain at flush: ${_activeUndoGroups.keys.toList()}. '
        'This indicates missing endUndoGroup calls.',
      );
    }

    // Reset counters after flush (MetricsSink contract)
    _activationCounts.clear();
    _operationCounts.clear();
    _sampleCounts.clear();
    _undoGroupCompletions.clear();

    // Note: _lastCompletedLabels is NOT cleared (needed for UI persistence)
    // Note: _activeUndoGroups is NOT cleared (in-progress operations)
  }

  /// Returns current aggregated metrics as a map.
  ///
  /// Useful for debugging or exporting metrics to external systems.
  Map<String, dynamic> getMetrics() => {
        'activationCounts': Map.unmodifiable(_activationCounts),
        'operationCounts': Map.unmodifiable(_operationCounts),
        'sampleCounts': Map.unmodifiable(_sampleCounts),
        'undoGroupCompletions': Map.unmodifiable(_undoGroupCompletions),
        'activeUndoGroups': Map.unmodifiable(_activeUndoGroups),
        'lastCompletedLabels': Map.unmodifiable(_lastCompletedLabels),
      };

  @override
  void dispose() {
    // Warn if active groups remain at disposal
    if (_activeUndoGroups.isNotEmpty) {
      _logger.w(
        'ToolTelemetry disposed with active undo groups: ${_activeUndoGroups.keys.toList()}. '
        'This indicates missing endUndoGroup calls.',
      );
    }

    super.dispose();
  }
}
