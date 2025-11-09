import 'package:flutter/widgets.dart';

/// Intent for play/pause toggle action (J key - video editing style).
///
/// Toggles between playing and paused states for timeline replay.
/// When playing, automatically steps through operation history.
class HistoryPlayPauseIntent extends Intent {
  /// Creates a play/pause intent.
  const HistoryPlayPauseIntent();
}

/// Intent for stop action (K key - video editing style).
///
/// Stops playback and resets to paused state.
class HistoryStopIntent extends Intent {
  /// Creates a stop intent.
  const HistoryStopIntent();
}

/// Intent for step forward action (L key - video editing style).
///
/// Steps forward one operation in the timeline (equivalent to redo).
class HistoryStepForwardIntent extends Intent {
  /// Creates a step forward intent.
  const HistoryStepForwardIntent();
}

/// Intent for step backward action (H key - video editing style).
///
/// Steps backward one operation in the timeline (equivalent to undo).
class HistoryStepBackwardIntent extends Intent {
  /// Creates a step backward intent.
  const HistoryStepBackwardIntent();
}

/// Intent for increasing playback speed (Shift+L).
///
/// Cycles through playback speeds: 0.5x -> 1.0x -> 2.0x -> 5.0x -> 0.5x
class HistorySpeedUpIntent extends Intent {
  /// Creates a speed up intent.
  const HistorySpeedUpIntent();
}

/// Intent for decreasing playback speed (Shift+H).
///
/// Cycles through playback speeds: 5.0x -> 2.0x -> 1.0x -> 0.5x -> 5.0x
class HistorySpeedDownIntent extends Intent {
  /// Creates a speed down intent.
  const HistorySpeedDownIntent();
}
