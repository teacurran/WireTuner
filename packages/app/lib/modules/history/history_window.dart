/// History replay window for time-travel debugging and review.
///
/// Provides scrubbing, playback, checkpoint jumping, and event inspection.
/// Route: app://history/:docId
library;

import 'package:flutter/material.dart';
import 'package:core/replay/replay_service.dart';

import 'widgets/timeline_widget.dart';
import 'widgets/playback_controls.dart';
import 'widgets/preview_pane.dart';
import 'widgets/metadata_inspector.dart';

/// History replay window widget.
///
/// **Layout:**
/// ```
/// ┌────────────────────────────────────────────────┐
/// │ History: Document - Artboard         ◯ □ ⨯    │
/// ├────────────────────────────────────────────────┤
/// │ Playback Controls                              │
/// ├────────────────────────────────────────────────┤
/// │ Preview Pane            │ Metadata Inspector   │
/// │                         │                      │
/// │ [Artboard Rendering]    │ Event Details        │
/// │                         │ Type: path.moved     │
/// │                         │ Sequence: 12345      │
/// │                         │ Timestamp: ...       │
/// │                         │                      │
/// ├─────────────────────────┴──────────────────────┤
/// │ Timeline Scrubber                              │
/// └────────────────────────────────────────────────┘
/// ```
///
/// **Features:**
/// - Checkpoint-based seeking (<50ms target)
/// - Playback speeds: 0.5×, 1×, 2×, 5×, 10×
/// - Event metadata inspection
/// - Checkpoint markers on timeline
/// - Keyboard shortcuts (J/K/L for play/pause/step)
///
/// **Related:**
/// - ADR-006 (History Replay Architecture)
/// - Flow J (History Replay Scrubbing)
/// - FR-027 (History Replay Requirement)
class HistoryWindow extends StatefulWidget {
  /// Creates a history window.
  ///
  /// [documentId]: Document to display history for
  /// [artboardName]: Optional artboard name for title
  const HistoryWindow({
    required this.documentId,
    this.artboardName,
    super.key,
  });

  /// Document ID to display history for.
  final String documentId;

  /// Optional artboard name for window title.
  final String? artboardName;

  @override
  State<HistoryWindow> createState() => _HistoryWindowState();
}

class _HistoryWindowState extends State<HistoryWindow> {
  late ReplayService _replayService;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeReplayService();
  }

  /// Initializes the replay service with document data.
  Future<void> _initializeReplayService() async {
    try {
      _replayService = ReplayService(
        checkpointInterval: 1000,
        maxCacheMemory: 100 * 1024 * 1024, // 100 MB
      );

      // TODO: Wire to actual event store and snapshot provider
      // For now, this is a placeholder showing the integration pattern
      await _replayService.initialize(
        documentId: widget.documentId,
        maxSequence: 10000, // TODO: Get from EventStore
        snapshotProvider: (sequence) async {
          // TODO: Implement actual snapshot loading
          throw UnimplementedError('Snapshot provider not yet wired');
        },
        eventReplayer: (from, to) async {
          // TODO: Implement actual event replay
          throw UnimplementedError('Event replayer not yet wired');
        },
        snapshotDeserializer: (data) async {
          // TODO: Implement actual deserialization
          throw UnimplementedError('Snapshot deserializer not yet wired');
        },
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _replayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Builds the app bar with window title and controls.
  PreferredSizeWidget _buildAppBar() {
    final title = widget.artboardName != null
        ? 'History: ${widget.documentId} - ${widget.artboardName}'
        : 'History: ${widget.documentId}';

    return AppBar(
      title: Text(title),
      actions: [
        // Checkpoint count badge
        if (_isInitialized)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Chip(
                label: Text(
                  '${_replayService.checkpointSequences.length} checkpoints',
                  style: const TextStyle(fontSize: 12),
                ),
                avatar: const Icon(Icons.bookmark, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the main body layout.
  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return Column(
      children: [
        // Playback controls (top bar)
        PlaybackControls(replayService: _replayService),

        // Main content (preview + inspector)
        Expanded(
          child: Row(
            children: [
              // Preview pane (left, 70% width)
              Expanded(
                flex: 7,
                child: PreviewPane(replayService: _replayService),
              ),

              // Vertical divider
              VerticalDivider(width: 1, color: Colors.grey[300]),

              // Metadata inspector (right, 30% width)
              Expanded(
                flex: 3,
                child: MetadataInspector(replayService: _replayService),
              ),
            ],
          ),
        ),

        // Timeline scrubber (bottom)
        TimelineWidget(replayService: _replayService),
      ],
    );
  }

  /// Builds loading state.
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading history...'),
        ],
      ),
    );
  }

  /// Builds error state.
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to load history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
              _initializeReplayService();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
