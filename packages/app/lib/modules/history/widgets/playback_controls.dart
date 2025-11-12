/// Playback control widget for history replay.
///
/// Transport buttons, speed control, and checkpoint jumping.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core/replay/replay_service.dart';
import 'package:core/replay/checkpoint.dart';

/// Playback control widget.
///
/// **Layout:**
/// ```
/// [◀◀] [◀] [▶] [▶▶] [■]   Speed: [1x ▾]   Checkpoint: [Seq 12000 ▾]
/// ```
///
/// **Features:**
/// - Step backward/forward
/// - Play/pause
/// - Speed control (0.5×, 1×, 2×, 5×, 10×)
/// - Checkpoint jump dropdown
/// - Keyboard shortcuts (J/K/L)
///
/// Related: docs/ui/wireframes/history_replay.md
class PlaybackControls extends StatefulWidget {
  /// Creates playback controls.
  const PlaybackControls({
    required this.replayService,
    super.key,
  });

  /// Replay service to control.
  final ReplayService replayService;

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReplayState>(
      stream: widget.replayService.stateStream,
      initialData: widget.replayService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data!;

        return _buildControlsWithShortcuts(state);
      },
    );
  }

  /// Builds controls wrapped with keyboard shortcuts.
  Widget _buildControlsWithShortcuts(ReplayState state) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyJ): _PlayPauseIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK): _StopIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL): _StepForwardIntent(),
        const SingleActivator(LogicalKeyboardKey.keyH): _StepBackwardIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
            onInvoke: (_) => _handlePlayPause(state),
          ),
          _StopIntent: CallbackAction<_StopIntent>(
            onInvoke: (_) => _handleStop(),
          ),
          _StepForwardIntent: CallbackAction<_StepForwardIntent>(
            onInvoke: (_) => _handleStepForward(),
          ),
          _StepBackwardIntent: CallbackAction<_StepBackwardIntent>(
            onInvoke: (_) => _handleStepBackward(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: _buildControls(state),
        ),
      ),
    );
  }

  /// Builds the control bar.
  Widget _buildControls(ReplayState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Transport buttons
          _buildTransportButtons(state),

          const SizedBox(width: 24),

          // Speed control
          _buildSpeedControl(state),

          const SizedBox(width: 24),

          // Checkpoint jump
          _buildCheckpointJump(),

          const Spacer(),

          // Performance metrics
          _buildMetricsChip(),
        ],
      ),
    );
  }

  /// Builds transport buttons (step backward, play/pause, step forward).
  Widget _buildTransportButtons(ReplayState state) {
    return Row(
      children: [
        // Step backward
        IconButton(
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Step Backward (H)',
          onPressed: state.currentSequence > 0 ? _handleStepBackward : null,
        ),

        const SizedBox(width: 4),

        // Play/Pause
        IconButton(
          icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          tooltip: state.isPlaying ? 'Pause (J)' : 'Play (J)',
          onPressed: () => _handlePlayPause(state),
          iconSize: 32,
          color: Colors.blue[700],
        ),

        const SizedBox(width: 4),

        // Step forward
        IconButton(
          icon: const Icon(Icons.skip_next),
          tooltip: 'Step Forward (L)',
          onPressed: state.currentSequence < state.maxSequence
              ? _handleStepForward
              : null,
        ),

        const SizedBox(width: 8),

        // Stop
        IconButton(
          icon: const Icon(Icons.stop),
          tooltip: 'Stop (K)',
          onPressed: state.isPlaying ? _handleStop : null,
        ),
      ],
    );
  }

  /// Builds speed control dropdown.
  Widget _buildSpeedControl(ReplayState state) {
    const speeds = [0.5, 1.0, 2.0, 5.0, 10.0];

    return Row(
      children: [
        const Text('Speed:', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        DropdownButton<double>(
          value: state.playbackSpeed,
          items: speeds.map((speed) {
            return DropdownMenuItem(
              value: speed,
              child: Text('${speed}×'),
            );
          }).toList(),
          onChanged: (speed) {
            if (speed != null) {
              _handleSpeedChange(speed, state);
            }
          },
        ),
      ],
    );
  }

  /// Builds checkpoint jump dropdown.
  Widget _buildCheckpointJump() {
    final checkpoints = widget.replayService.checkpointSequences;

    if (checkpoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Text('Checkpoint:', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          hint: const Text('Jump to...'),
          items: checkpoints.map((seq) {
            return DropdownMenuItem(
              value: seq,
              child: Text('Seq $seq'),
            );
          }).toList(),
          onChanged: (sequence) {
            if (sequence != null) {
              widget.replayService.seek(sequence);
            }
          },
        ),
      ],
    );
  }

  /// Builds performance metrics chip.
  Widget _buildMetricsChip() {
    final metrics = widget.replayService.getSeekMetrics();
    final count = metrics['count'] ?? 0;

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Avg: ${metrics['avgLatencyMs']}ms\n'
          'P95: ${metrics['p95LatencyMs']}ms\n'
          'Hit Rate: ${metrics['checkpointHitRate']}',
      child: Chip(
        avatar: const Icon(Icons.speed, size: 16),
        label: Text(
          'P95: ${metrics['p95LatencyMs']}ms',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  /// Handles play/pause toggle.
  void _handlePlayPause(ReplayState state) {
    if (state.isPlaying) {
      widget.replayService.pause();
    } else {
      widget.replayService.play(speed: state.playbackSpeed);
    }
  }

  /// Handles stop (pause and reset to start).
  void _handleStop() {
    widget.replayService.pause();
    widget.replayService.seek(0);
  }

  /// Handles step forward.
  Future<void> _handleStepForward() async {
    await widget.replayService.stepForward();
  }

  /// Handles step backward.
  Future<void> _handleStepBackward() async {
    await widget.replayService.stepBackward();
  }

  /// Handles speed change.
  void _handleSpeedChange(double speed, ReplayState state) {
    if (state.isPlaying) {
      // Restart playback at new speed
      widget.replayService.pause();
      widget.replayService.play(speed: speed);
    }
    // Speed will be stored in state for next play
  }
}

// Keyboard shortcut intents
class _PlayPauseIntent extends Intent {}

class _StopIntent extends Intent {}

class _StepForwardIntent extends Intent {}

class _StepBackwardIntent extends Intent {}
