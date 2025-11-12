/// Timeline scrubber widget with checkpoint markers.
///
/// Displays horizontal timeline with event dots, checkpoint markers,
/// and drag-to-seek functionality.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core/replay/replay_service.dart';
import 'package:core/replay/checkpoint.dart';

/// Timeline scrubber widget.
///
/// **Features:**
/// - Horizontal scrubber bar
/// - Checkpoint markers (vertical ticks every 1k events)
/// - Drag gesture for seeking
/// - Click-to-seek
/// - Current position indicator
/// - Hover tooltips for event metadata
/// - Throttled updates (16ms) for performance
///
/// **Visual:**
/// ```
/// ┌──────────────────────────────────────────────┐
/// │ ▼    ┊         ┊         ┊         ┊        │
/// │ ●════●═════●═══●═════●═══●═════●═══●════    │
/// │ 0   1k       2k       3k       4k       5k   │
/// └──────────────────────────────────────────────┘
/// ```
///
/// Related: FR-027, docs/ui/wireframes/history_replay.md
class TimelineWidget extends StatefulWidget {
  /// Creates a timeline widget.
  const TimelineWidget({
    required this.replayService,
    this.height = 80.0,
    super.key,
  });

  /// Replay service to control.
  final ReplayService replayService;

  /// Height of timeline widget.
  final double height;

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  Timer? _dragThrottle;
  int? _pendingSeekSequence;
  bool _isDragging = false;
  Offset? _hoverPosition;

  @override
  void dispose() {
    _dragThrottle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReplayState>(
      stream: widget.replayService.stateStream,
      initialData: widget.replayService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data!;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Sequence label and progress
              _buildHeader(state),

              // Timeline track
              Expanded(
                child: _buildTimeline(state),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds header with sequence label and progress.
  Widget _buildHeader(ReplayState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Text(
            'Sequence: ${state.currentSequence} / ${state.maxSequence}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(state.progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Builds the timeline track with scrubber.
  Widget _buildTimeline(ReplayState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final checkpoints = widget.replayService.checkpointSequences;

        return MouseRegion(
          onHover: (event) {
            setState(() {
              _hoverPosition = event.localPosition;
            });
          },
          onExit: (_) {
            setState(() {
              _hoverPosition = null;
            });
          },
          child: GestureDetector(
            onTapDown: (details) {
              _handleSeek(details.localPosition.dx, width, state.maxSequence);
            },
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              _handleSeek(details.localPosition.dx, width, state.maxSequence);
            },
            onPanEnd: (_) {
              setState(() {
                _isDragging = false;
              });
            },
            child: CustomPaint(
              size: Size(width, constraints.maxHeight),
              painter: _TimelinePainter(
                currentSequence: state.currentSequence,
                maxSequence: state.maxSequence,
                checkpoints: checkpoints,
                hoverPosition: _hoverPosition,
                isDragging: _isDragging,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Handles seek gesture with throttling.
  void _handleSeek(double offsetX, double width, int maxSequence) {
    // Calculate target sequence from position
    final progress = (offsetX / width).clamp(0.0, 1.0);
    final targetSequence = (progress * maxSequence).round();

    // Store pending seek
    _pendingSeekSequence = targetSequence;

    // Cancel existing throttle timer
    _dragThrottle?.cancel();

    // Throttle seeks to 16ms (60 FPS)
    _dragThrottle = Timer(const Duration(milliseconds: 16), () {
      if (_pendingSeekSequence != null) {
        widget.replayService.seek(_pendingSeekSequence!);
        _pendingSeekSequence = null;
      }
    });
  }
}

/// Custom painter for timeline track.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.currentSequence,
    required this.maxSequence,
    required this.checkpoints,
    this.hoverPosition,
    this.isDragging = false,
  });

  final int currentSequence;
  final int maxSequence;
  final List<int> checkpoints;
  final Offset? hoverPosition;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw track background
    paint.color = Colors.grey[300]!;
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4),
      paint,
    );

    // Draw checkpoint markers
    paint.color = Colors.blue[300]!;
    paint.strokeWidth = 2;
    for (final checkpoint in checkpoints) {
      final x = (checkpoint / maxSequence) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );

      // Draw checkpoint label every 5 checkpoints
      if (checkpoint % 5000 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${checkpoint ~/ 1000}k',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, size.height - 16),
        );
      }
    }

    // Draw progress (filled portion)
    final progress = maxSequence == 0 ? 0.0 : currentSequence / maxSequence;
    paint.color = Colors.blue[600]!;
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2 - 2, size.width * progress, 4),
      paint,
    );

    // Draw current position handle
    final handleX = size.width * progress;
    paint.color = Colors.blue[800]!;
    canvas.drawCircle(
      Offset(handleX, size.height / 2),
      isDragging ? 10 : 8,
      paint,
    );

    // Draw handle outline
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(
      Offset(handleX, size.height / 2),
      isDragging ? 10 : 8,
      paint,
    );

    // Draw hover indicator
    if (hoverPosition != null) {
      final hoverSequence = ((hoverPosition!.dx / size.width) * maxSequence).round();
      final hoverX = (hoverSequence / maxSequence) * size.width;

      // Draw vertical line at hover position
      paint.color = Colors.grey[600]!.withValues(alpha: 0.5);
      paint.strokeWidth = 1;
      canvas.drawLine(
        Offset(hoverX, 0),
        Offset(hoverX, size.height),
        paint,
      );

      // Draw tooltip with sequence number
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Seq: $hoverSequence',
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Tooltip background
      final tooltipRect = Rect.fromLTWH(
        hoverX - textPainter.width / 2 - 4,
        4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      paint.color = Colors.black87;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(tooltipRect, const Radius.circular(4)),
        paint,
      );

      // Tooltip text
      textPainter.paint(
        canvas,
        Offset(hoverX - textPainter.width / 2, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.currentSequence != currentSequence ||
        oldDelegate.maxSequence != maxSequence ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.isDragging != isDragging;
  }
}
