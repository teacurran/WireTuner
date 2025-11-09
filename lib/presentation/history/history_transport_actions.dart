import 'package:flutter/widgets.dart';
import 'package:wiretuner/presentation/history/history_transport_intents.dart';

/// Action for play/pause toggle.
///
/// This action calls the provided callback to toggle playback state.
/// The callback is typically bound to HistoryScrubber._togglePlayback.
class HistoryPlayPauseAction extends Action<HistoryPlayPauseIntent> {
  /// Creates a play/pause action.
  HistoryPlayPauseAction({
    required this.onPlayPause,
    required this.enabledCallback,
  });

  /// Callback to toggle playback.
  final VoidCallback onPlayPause;

  /// Whether the action is currently enabled.
  final bool Function() enabledCallback;

  @override
  bool isEnabled(HistoryPlayPauseIntent intent) => enabledCallback();

  @override
  void invoke(HistoryPlayPauseIntent intent) {
    if (enabledCallback()) {
      onPlayPause();
    }
  }
}

/// Action for stop.
///
/// This action calls the provided callback to stop playback.
class HistoryStopAction extends Action<HistoryStopIntent> {
  /// Creates a stop action.
  HistoryStopAction({
    required this.onStop,
    required this.enabledCallback,
  });

  /// Callback to stop playback.
  final VoidCallback onStop;

  /// Whether the action is currently enabled.
  final bool Function() enabledCallback;

  @override
  bool isEnabled(HistoryStopIntent intent) => enabledCallback();

  @override
  void invoke(HistoryStopIntent intent) {
    if (enabledCallback()) {
      onStop();
    }
  }
}

/// Action for step forward.
///
/// This action calls the provided callback to step forward one operation.
class HistoryStepForwardAction extends Action<HistoryStepForwardIntent> {
  /// Creates a step forward action.
  HistoryStepForwardAction({
    required this.onStepForward,
    required this.enabledCallback,
  });

  /// Callback to step forward.
  final VoidCallback onStepForward;

  /// Whether the action is currently enabled.
  final bool Function() enabledCallback;

  @override
  bool isEnabled(HistoryStepForwardIntent intent) => enabledCallback();

  @override
  void invoke(HistoryStepForwardIntent intent) {
    if (enabledCallback()) {
      onStepForward();
    }
  }
}

/// Action for step backward.
///
/// This action calls the provided callback to step backward one operation.
class HistoryStepBackwardAction extends Action<HistoryStepBackwardIntent> {
  /// Creates a step backward action.
  HistoryStepBackwardAction({
    required this.onStepBackward,
    required this.enabledCallback,
  });

  /// Callback to step backward.
  final VoidCallback onStepBackward;

  /// Whether the action is currently enabled.
  final bool Function() enabledCallback;

  @override
  bool isEnabled(HistoryStepBackwardIntent intent) => enabledCallback();

  @override
  void invoke(HistoryStepBackwardIntent intent) {
    if (enabledCallback()) {
      onStepBackward();
    }
  }
}

/// Action for increasing playback speed.
///
/// Cycles through available speeds: 0.5x -> 1.0x -> 2.0x -> 5.0x -> 0.5x
class HistorySpeedUpAction extends Action<HistorySpeedUpIntent> {
  /// Creates a speed up action.
  HistorySpeedUpAction({
    required this.onSpeedUp,
  });

  /// Callback to increase speed.
  final VoidCallback onSpeedUp;

  @override
  void invoke(HistorySpeedUpIntent intent) {
    onSpeedUp();
  }
}

/// Action for decreasing playback speed.
///
/// Cycles through available speeds: 5.0x -> 2.0x -> 1.0x -> 0.5x -> 5.0x
class HistorySpeedDownAction extends Action<HistorySpeedDownIntent> {
  /// Creates a speed down action.
  HistorySpeedDownAction({
    required this.onSpeedDown,
  });

  /// Callback to decrease speed.
  final VoidCallback onSpeedDown;

  @override
  void invoke(HistorySpeedDownIntent intent) {
    onSpeedDown();
  }
}
