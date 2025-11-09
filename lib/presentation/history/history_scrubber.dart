import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shell/app_shell.dart';
import 'package:wiretuner/presentation/history/history_view_model.dart';

/// Scrubber widget for timeline playback and navigation.
///
/// **Features:**
/// - Slider for scrubbing through operation timeline
/// - Play/pause controls for automated playback
/// - Step forward/backward buttons
/// - Current position display with label
/// - Playback speed control
/// - Throttled navigation to meet 5k events/sec target
///
/// **Layout:**
/// ```
/// ┌────────────────────────────────────────────┐
/// │ ◄ ► ▶ ║  ════●════════  [Current Op] 12/45│
/// └────────────────────────────────────────────┘
/// ```
///
/// **Performance:**
/// - Throttles scrub requests to prevent overwhelming navigator
/// - Uses AnimationController for smooth playback
/// - Target: 5k events/sec replay speed
/// - Respects UndoProvider._isNavigating guard
///
/// Related: Task I4.T4 (History Panel UI), Performance target 5k events/sec
class HistoryScrubber extends StatefulWidget {
  /// Creates a history scrubber widget.
  const HistoryScrubber({super.key});

  @override
  State<HistoryScrubber> createState() => _HistoryScrubberState();
}

class _HistoryScrubberState extends State<HistoryScrubber>
    with SingleTickerProviderStateMixin {
  late AnimationController _playbackController;
  Timer? _scrubThrottle;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0; // 1.0 = normal speed
  int? _pendingIndex;

  @override
  void initState() {
    super.initState();
    _playbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(_onPlaybackTick);
  }

  @override
  void dispose() {
    _playbackController.dispose();
    _scrubThrottle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final undoProvider = context.watch<UndoProvider>();

    final viewModel = HistoryViewModel(
      undoStack: undoProvider.undoStack,
      redoStack: undoProvider.redoStack,
    );

    if (viewModel.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentIndex = viewModel.currentIndex;
    final maxIndex = viewModel.timeline.length - 1;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Playback controls
          _buildPlaybackControls(
            undoProvider: undoProvider,
            viewModel: viewModel,
            currentIndex: currentIndex,
            maxIndex: maxIndex,
          ),

          const SizedBox(width: 16),

          // Scrubber slider
          Expanded(
            child: _buildScrubber(
              undoProvider: undoProvider,
              viewModel: viewModel,
              currentIndex: currentIndex,
              maxIndex: maxIndex,
            ),
          ),

          const SizedBox(width: 16),

          // Position indicator
          _buildPositionIndicator(
            viewModel: viewModel,
            currentIndex: currentIndex,
            maxIndex: maxIndex,
          ),
        ],
      ),
    );
  }

  /// Builds playback control buttons.
  Widget _buildPlaybackControls({
    required UndoProvider undoProvider,
    required HistoryViewModel viewModel,
    required int currentIndex,
    required int maxIndex,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step backward
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 20),
          tooltip: 'Step Backward',
          onPressed: currentIndex > 0
              ? () => _stepBackward(undoProvider)
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),

        // Play/Pause
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            size: 20,
          ),
          tooltip: _isPlaying ? 'Pause' : 'Play',
          onPressed: currentIndex < maxIndex
              ? _togglePlayback
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),

        // Step forward
        IconButton(
          icon: const Icon(Icons.skip_next, size: 20),
          tooltip: 'Step Forward',
          onPressed: currentIndex < maxIndex
              ? () => _stepForward(undoProvider)
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),

        const SizedBox(width: 8),

        // Speed control
        PopupMenuButton<double>(
          icon: const Icon(Icons.speed, size: 18),
          tooltip: 'Playback Speed',
          itemBuilder: (context) => [
            _buildSpeedMenuItem(0.5, '0.5×'),
            _buildSpeedMenuItem(1.0, '1.0×'),
            _buildSpeedMenuItem(2.0, '2.0×'),
            _buildSpeedMenuItem(5.0, '5.0×'),
          ],
          onSelected: (speed) {
            setState(() {
              _playbackSpeed = speed;
            });
          },
        ),
      ],
    );
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double speed, String label) {
    return PopupMenuItem(
      value: speed,
      child: Row(
        children: [
          if (_playbackSpeed == speed)
            const Icon(Icons.check, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  /// Builds scrubber slider.
  Widget _buildScrubber({
    required UndoProvider undoProvider,
    required HistoryViewModel viewModel,
    required int currentIndex,
    required int maxIndex,
  }) {
    return Slider(
      value: currentIndex.toDouble(),
      min: 0,
      max: maxIndex.toDouble(),
      divisions: maxIndex,
      label: viewModel.timeline[currentIndex.clamp(0, maxIndex)].group.label,
      onChanged: (value) {
        _handleScrub(
          value.round(),
          undoProvider,
          viewModel,
        );
      },
      onChangeEnd: (_) {
        // Ensure final scrub is processed
        _flushPendingScrub(undoProvider, viewModel);
      },
    );
  }

  /// Builds position indicator.
  Widget _buildPositionIndicator({
    required HistoryViewModel viewModel,
    required int currentIndex,
    required int maxIndex,
  }) {
    final entry = viewModel.timeline[currentIndex.clamp(0, maxIndex)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.group.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${currentIndex + 1} / ${maxIndex + 1}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Handles scrubber drag with throttling.
  void _handleScrub(
    int targetIndex,
    UndoProvider undoProvider,
    HistoryViewModel viewModel,
  ) {
    // Store pending index for throttled execution
    _pendingIndex = targetIndex;

    // Cancel existing throttle timer
    _scrubThrottle?.cancel();

    // Throttle scrub requests to 60 FPS (16.7ms)
    _scrubThrottle = Timer(const Duration(milliseconds: 16), () {
      _flushPendingScrub(undoProvider, viewModel);
    });
  }

  /// Flushes pending scrub request to navigator.
  void _flushPendingScrub(
    UndoProvider undoProvider,
    HistoryViewModel viewModel,
  ) {
    final index = _pendingIndex;
    if (index == null) return;

    _pendingIndex = null;

    // Get target operation group
    if (index >= 0 && index < viewModel.timeline.length) {
      final targetGroup = viewModel.timeline[index].group;
      undoProvider.handleScrubToGroup(targetGroup);
    }
  }

  /// Steps backward one operation.
  void _stepBackward(UndoProvider undoProvider) {
    undoProvider.handleUndo();
  }

  /// Steps forward one operation.
  void _stepForward(UndoProvider undoProvider) {
    undoProvider.handleRedo();
  }

  /// Toggles playback on/off.
  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackController.repeat();
      } else {
        _playbackController.stop();
      }
    });
  }

  /// Called on each playback animation tick.
  void _onPlaybackTick() {
    if (!_isPlaying) return;

    final undoProvider = context.read<UndoProvider>();
    final viewModel = HistoryViewModel(
      undoStack: undoProvider.undoStack,
      redoStack: undoProvider.redoStack,
    );

    final currentIndex = viewModel.currentIndex;
    final maxIndex = viewModel.timeline.length - 1;

    if (currentIndex < maxIndex) {
      // Step forward at playback speed
      if (_playbackController.value > 0.9) {
        _stepForward(undoProvider);
      }
    } else {
      // Reached end, stop playback
      setState(() {
        _isPlaying = false;
        _playbackController.stop();
      });
    }
  }
}
