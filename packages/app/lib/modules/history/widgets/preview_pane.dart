/// Preview pane widget for rendering artboard state at current sequence.
///
/// Displays the document/artboard visual state at the selected history point.
library;

import 'package:flutter/material.dart';
import 'package:core/replay/replay_service.dart';
import 'package:core/replay/checkpoint.dart';

/// Preview pane widget.
///
/// **Features:**
/// - Renders artboard state at current sequence
/// - Loading placeholder during seeks
/// - Empty state when no document loaded
/// - Zoom controls (future enhancement)
///
/// **Layout:**
/// ```
/// ┌─────────────────────────────────┐
/// │                                 │
/// │   [Rendered Artboard State]    │
/// │                                 │
/// │   ┌────────┐                    │
/// │   │ Object │  ← Added at seq    │
/// │   └────────┘                    │
/// │                                 │
/// │      •─────────•                │
/// │     /  Path    \  ← Current     │
/// │    •  (Active) •                │
/// │     \          /                │
/// │      •─────────•                │
/// │                                 │
/// └─────────────────────────────────┘
/// ```
///
/// Related: docs/ui/wireframes/history_replay.md
class PreviewPane extends StatelessWidget {
  /// Creates a preview pane.
  const PreviewPane({
    required this.replayService,
    super.key,
  });

  /// Replay service providing document state.
  final ReplayService replayService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReplayState>(
      stream: replayService.stateStream,
      initialData: replayService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data!;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Header with sequence info
              _buildHeader(state),

              // Preview content
              Expanded(
                child: _buildPreview(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds header with sequence info.
  Widget _buildHeader(ReplayState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.preview, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Preview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (state.isPlaying)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Playing...',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            )
          else
            Text(
              'Sequence ${state.currentSequence}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  /// Builds preview content.
  Widget _buildPreview(BuildContext context, ReplayState state) {
    if (state.documentState == null) {
      return _buildPlaceholder();
    }

    // TODO: Wire to actual rendering pipeline
    // For now, show placeholder with state info
    return _buildPlaceholderWithState(state);
  }

  /// Builds placeholder when no state loaded.
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No preview available',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Seek to a sequence to view document state',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Builds placeholder with state info (temporary until rendering wired).
  Widget _buildPlaceholderWithState(ReplayState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.blue[300]),
                const SizedBox(height: 16),
                Text(
                  'Document State at Sequence ${state.currentSequence}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progress: ${(state.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TODO: Wire to RenderingPipeline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Integrate with existing Canvas rendering\n'
                        '• Reuse ThumbnailGenerator for preview\n'
                        '• Display artboard at replayed state',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
