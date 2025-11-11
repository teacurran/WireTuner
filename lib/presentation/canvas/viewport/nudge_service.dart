import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Direction for nudging operations.
enum NudgeDirection {
  /// Nudge up (negative Y).
  up,

  /// Nudge down (positive Y).
  down,

  /// Nudge left (negative X).
  left,

  /// Nudge right (positive X).
  right,
}

/// Configuration for nudge behavior.
class NudgeConfig {
  /// Creates a nudge configuration.
  const NudgeConfig({
    this.nudgeDistance = 1.0,
    this.largeNudgeDistance = 10.0,
    this.overshootThreshold = 50.0,
    this.undoGroupingWindow = const Duration(milliseconds: 200),
  });

  /// Default nudge distance in screen pixels.
  ///
  /// This is the distance moved by a single arrow key press.
  final double nudgeDistance;

  /// Large nudge distance in screen pixels.
  ///
  /// This is the distance moved when holding Shift + arrow key.
  final double largeNudgeDistance;

  /// Distance threshold for overshoot detection in world units.
  ///
  /// If a nudge would move an object this far beyond an artboard boundary,
  /// a toast notification is triggered.
  final double overshootThreshold;

  /// Time window for grouping consecutive nudges into a single undo operation.
  ///
  /// Nudges within this time window are batched together for undo/redo.
  /// Matches the InteractionEngine's 200ms grouping threshold.
  final Duration undoGroupingWindow;

  /// Creates a copy of this configuration with some fields replaced.
  NudgeConfig copyWith({
    double? nudgeDistance,
    double? largeNudgeDistance,
    double? overshootThreshold,
    Duration? undoGroupingWindow,
  }) =>
      NudgeConfig(
        nudgeDistance: nudgeDistance ?? this.nudgeDistance,
        largeNudgeDistance: largeNudgeDistance ?? this.largeNudgeDistance,
        overshootThreshold: overshootThreshold ?? this.overshootThreshold,
        undoGroupingWindow: undoGroupingWindow ?? this.undoGroupingWindow,
      );
}

/// Result of a nudge operation.
class NudgeResult {
  /// Creates a nudge result.
  const NudgeResult({
    required this.delta,
    required this.overshoot,
    this.overshootMessage,
  });

  /// The world-space delta applied by the nudge.
  final event_base.Point delta;

  /// Whether this nudge caused an overshoot beyond boundaries.
  final bool overshoot;

  /// Optional message describing the overshoot.
  final String? overshootMessage;

  @override
  String toString() => 'NudgeResult('
      'delta: $delta, '
      'overshoot: $overshoot'
      '${overshootMessage != null ? ', message: $overshootMessage' : ''})';
}

/// Callback for toast notifications.
///
/// This is invoked when a nudge operation triggers an overshoot condition.
/// The UI layer should display this message to the user.
typedef ToastCallback = void Function(String message);

/// Service that handles keyboard nudging operations with intelligent feedback.
///
/// The NudgeService implements FR-050's requirement for intelligent nudging
/// with toast hints when objects overshoot artboard boundaries. It coordinates
/// with the ViewportController for screen-space distance calculations and
/// emits nudge commands through callbacks for integration with InteractionEngine.
///
/// ## Features
///
/// 1. **Screen-Space Nudging**:
///    - Nudge distances are specified in screen pixels for consistency
///    - Converted to world-space deltas based on current zoom
///    - Small nudges (1px) and large nudges (10px with Shift)
///
/// 2. **Overshoot Detection**:
///    - Tracks cumulative nudge distance
///    - Detects when objects exceed artboard boundaries
///    - Triggers toast notifications with helpful hints
///
/// 3. **Undo Grouping**:
///    - Groups consecutive nudges within 200ms window
///    - Enables single undo operation for rapid nudging
///    - Integrates with InteractionEngine's batching logic
///
/// ## Usage
///
/// ```dart
/// final nudgeService = NudgeService(
///   controller: viewportController,
///   onToast: (message) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text(message)),
///     );
///   },
/// );
///
/// // Handle arrow key press
/// final result = nudgeService.nudge(
///   direction: NudgeDirection.right,
///   largeNudge: false,
///   contentBounds: Rectangle(x: 0, y: 0, width: 800, height: 600),
///   artboardBounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
/// );
///
/// // Apply the delta to selected objects
/// applyNudgeDelta(result.delta);
/// ```
///
/// ## Integration with InteractionEngine
///
/// The NudgeService calculates deltas but does not directly modify objects.
/// Instead, it returns [NudgeResult] containing the world-space delta that
/// should be applied. The caller is responsible for:
///
/// 1. Creating a command (e.g., `TransformCommand`)
/// 2. Dispatching through InteractionEngine
/// 3. Respecting the undo grouping window
///
/// This keeps the service focused on calculation logic while delegating
/// state mutations to the proper domain layer.
class NudgeService extends ChangeNotifier {
  /// Creates a nudge service.
  NudgeService({
    required ViewportController controller,
    NudgeConfig config = const NudgeConfig(),
    ToastCallback? onToast,
  })  : _controller = controller,
        _config = config,
        _onToast = onToast;

  /// The viewport controller for coordinate transformations.
  final ViewportController _controller;

  /// Current nudge configuration.
  NudgeConfig _config;

  /// Callback for toast notifications.
  final ToastCallback? _onToast;

  /// Timestamp of the last nudge operation.
  DateTime? _lastNudgeTime;

  /// Cumulative nudge distance in the current grouping window.
  ///
  /// Reset when the grouping window expires.
  event_base.Point _cumulativeDelta = const event_base.Point(x: 0, y: 0);

  /// Timer for resetting cumulative tracking.
  Timer? _resetTimer;

  /// Gets the current nudge configuration.
  NudgeConfig get config => _config;

  /// Updates the nudge configuration.
  set config(NudgeConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// Gets the cumulative delta for the current grouping window.
  ///
  /// This is useful for UI indicators showing total nudge distance.
  event_base.Point get cumulativeDelta => _cumulativeDelta;

  /// Gets whether a nudge grouping window is currently active.
  ///
  /// Returns true if the last nudge was within the grouping window.
  bool get isGroupingActive {
    if (_lastNudgeTime == null) return false;
    final elapsed = DateTime.now().difference(_lastNudgeTime!);
    return elapsed < _config.undoGroupingWindow;
  }

  /// Performs a nudge operation in the specified direction.
  ///
  /// This calculates the world-space delta for the nudge, checks for
  /// overshoot conditions, and triggers toast notifications as needed.
  ///
  /// The [direction] specifies which way to nudge.
  /// The [largeNudge] flag enables large nudge distance (Shift+arrow).
  /// The [contentBounds] specifies the bounds of the content being nudged.
  /// The [artboardBounds] specifies the artboard boundary for overshoot detection.
  ///
  /// Returns a [NudgeResult] containing the delta to apply and overshoot info.
  ///
  /// Example:
  /// ```dart
  /// final result = nudgeService.nudge(
  ///   direction: NudgeDirection.down,
  ///   largeNudge: true, // Shift+Down = 10px
  ///   contentBounds: selectionBounds,
  ///   artboardBounds: currentArtboard.bounds,
  /// );
  ///
  /// if (result.overshoot) {
  ///   // Toast already shown by service
  /// }
  ///
  /// // Apply delta through InteractionEngine
  /// dispatchTransformCommand(result.delta);
  /// ```
  NudgeResult nudge({
    required NudgeDirection direction,
    required bool largeNudge,
    Rectangle? contentBounds,
    Rectangle? artboardBounds,
  }) {
    // Calculate screen-space nudge distance
    final screenDistance =
        largeNudge ? _config.largeNudgeDistance : _config.nudgeDistance;

    // Convert to world-space distance
    final worldDistance = _controller.screenDistanceToWorld(screenDistance);

    // Calculate delta based on direction
    final delta = _calculateDelta(direction, worldDistance);

    // Update cumulative tracking
    _updateCumulativeTracking(delta);

    // Check for overshoot if bounds provided
    bool overshoot = false;
    String? overshootMessage;

    if (contentBounds != null && artboardBounds != null) {
      final result = _checkOvershoot(
        contentBounds,
        artboardBounds,
        delta,
      );
      overshoot = result.overshoot;
      overshootMessage = result.message;

      // Trigger toast if overshoot detected
      if (overshoot && overshootMessage != null) {
        _onToast?.call(overshootMessage);
      }
    }

    notifyListeners();

    return NudgeResult(
      delta: delta,
      overshoot: overshoot,
      overshootMessage: overshootMessage,
    );
  }

  /// Calculates the delta vector for a nudge in the given direction.
  event_base.Point _calculateDelta(NudgeDirection direction, double distance) {
    switch (direction) {
      case NudgeDirection.up:
        return event_base.Point(x: 0, y: -distance);
      case NudgeDirection.down:
        return event_base.Point(x: 0, y: distance);
      case NudgeDirection.left:
        return event_base.Point(x: -distance, y: 0);
      case NudgeDirection.right:
        return event_base.Point(x: distance, y: 0);
    }
  }

  /// Updates the cumulative delta tracking for undo grouping.
  void _updateCumulativeTracking(event_base.Point delta) {
    final now = DateTime.now();

    // Check if within grouping window
    if (_lastNudgeTime != null) {
      final elapsed = now.difference(_lastNudgeTime!);
      if (elapsed >= _config.undoGroupingWindow) {
        // Window expired, reset cumulative tracking
        _cumulativeDelta = delta;
      } else {
        // Within window, accumulate delta
        _cumulativeDelta = event_base.Point(
          x: _cumulativeDelta.x + delta.x,
          y: _cumulativeDelta.y + delta.y,
        );
      }
    } else {
      // First nudge
      _cumulativeDelta = delta;
    }

    _lastNudgeTime = now;

    // Schedule reset timer
    _resetTimer?.cancel();
    _resetTimer = Timer(_config.undoGroupingWindow, _resetCumulativeTracking);
  }

  /// Resets cumulative tracking when grouping window expires.
  void _resetCumulativeTracking() {
    _cumulativeDelta = const event_base.Point(x: 0, y: 0);
    _lastNudgeTime = null;
    notifyListeners();
  }

  /// Checks if a nudge would cause an overshoot beyond artboard boundaries.
  ///
  /// Returns a record with:
  /// - overshoot: Whether overshoot was detected
  /// - message: Optional toast message describing the overshoot
  ({bool overshoot, String? message}) _checkOvershoot(
    Rectangle contentBounds,
    Rectangle artboardBounds,
    event_base.Point delta,
  ) {
    // Calculate new bounds after nudge
    final newBounds = Rectangle(
      x: contentBounds.x + delta.x,
      y: contentBounds.y + delta.y,
      width: contentBounds.width,
      height: contentBounds.height,
    );

    // Check each edge for overshoot
    final leftOvershoot = artboardBounds.x - newBounds.x;
    final rightOvershoot =
        (newBounds.x + newBounds.width) - (artboardBounds.x + artboardBounds.width);
    final topOvershoot = artboardBounds.y - newBounds.y;
    final bottomOvershoot =
        (newBounds.y + newBounds.height) - (artboardBounds.y + artboardBounds.height);

    // Check if any overshoot exceeds threshold
    final threshold = _config.overshootThreshold;
    String? message;

    if (leftOvershoot > threshold) {
      message = 'Selection exceeded left artboard boundary by '
          '${leftOvershoot.toStringAsFixed(1)} units';
    } else if (rightOvershoot > threshold) {
      message = 'Selection exceeded right artboard boundary by '
          '${rightOvershoot.toStringAsFixed(1)} units';
    } else if (topOvershoot > threshold) {
      message = 'Selection exceeded top artboard boundary by '
          '${topOvershoot.toStringAsFixed(1)} units';
    } else if (bottomOvershoot > threshold) {
      message = 'Selection exceeded bottom artboard boundary by '
          '${bottomOvershoot.toStringAsFixed(1)} units';
    }

    return (
      overshoot: message != null,
      message: message,
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }
}
