/// Metadata inspector widget for event details.
///
/// Displays event type, timestamp, user, session, and payload.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:core/replay/replay_service.dart';
import 'package:core/replay/checkpoint.dart';

/// Metadata inspector widget.
///
/// **Layout:**
/// ```
/// ┌──────────────────────────────┐
/// │ Event Details                │
/// │ ──────────────────────────── │
/// │ Sequence: 12,345             │
/// │ Type: path.anchor.moved      │
/// │ Timestamp: 14:32:15.234      │
/// │ User: Alice                  │
/// │ Session: collab-xyz-789      │
/// │ ──────────────────────────── │
/// │ Payload:                     │
/// │ {                            │
/// │   "anchorId": "a-42",        │
/// │   "position": {              │
/// │     "x": 540.5,              │
/// │     "y": 320.0               │
/// │   }                          │
/// │ }                            │
/// │ ──────────────────────────── │
/// │ Related Events:              │
/// │ • 12,344 (anchor.selected)   │
/// │ • 12,346 (path.updated)      │
/// └──────────────────────────────┘
/// ```
///
/// Related: docs/ui/wireframes/history_replay.md
class MetadataInspector extends StatelessWidget {
  /// Creates a metadata inspector.
  const MetadataInspector({
    required this.replayService,
    super.key,
  });

  /// Replay service to inspect.
  final ReplayService replayService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReplayState>(
      stream: replayService.stateStream,
      initialData: replayService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data!;

        return Container(
          color: Colors.grey[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildContent(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds header.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20),
          SizedBox(width: 8),
          Text(
            'Event Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds content.
  Widget _buildContent(BuildContext context, ReplayState state) {
    if (state.currentSequence == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sequence info
        _buildSection(
          title: 'Sequence Information',
          children: [
            _buildField('Sequence', state.currentSequence.toString()),
            _buildField('Progress',
                '${(state.progress * 100).toStringAsFixed(1)}%'),
            _buildField('Max Sequence', state.maxSequence.toString()),
          ],
        ),

        const SizedBox(height: 16),

        // Event metadata (placeholder - needs actual event data)
        _buildSection(
          title: 'Event Metadata',
          children: [
            _buildField('Type', 'TODO: Load from event store'),
            _buildField('Timestamp', DateTime.now().toIso8601String()),
            _buildField('User', 'Unknown'),
            _buildField('Session', 'N/A'),
          ],
        ),

        const SizedBox(height: 16),

        // Payload (placeholder)
        _buildSection(
          title: 'Payload',
          children: [
            _buildCodeBlock(context, _getPlaceholderPayload()),
          ],
        ),

        const SizedBox(height: 16),

        // Checkpoint info
        if (_isNearCheckpoint(state.currentSequence))
          _buildSection(
            title: 'Checkpoint Info',
            children: [
              _buildField('Is Checkpoint', 'Yes'),
              _buildField(
                  'Cache Size', '${replayService.checkpointSequences.length}'),
            ],
          ),

        const SizedBox(height: 16),

        // Performance metrics
        _buildSection(
          title: 'Performance Metrics',
          children: [
            ..._buildPerformanceMetrics(),
          ],
        ),
      ],
    );
  }

  /// Builds empty state.
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No event selected',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Scrub timeline to view event details',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a section with title and children.
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  /// Builds a key-value field.
  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a code block for JSON payload.
  Widget _buildCodeBlock(BuildContext context, String json) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        json,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Colors.green,
        ),
      ),
    );
  }

  /// Builds performance metrics from replay service.
  List<Widget> _buildPerformanceMetrics() {
    final metrics = replayService.getSeekMetrics();

    if (metrics['count'] == 0) {
      return [
        const Text(
          'No seeks performed yet',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ];
    }

    return [
      _buildField('Seek Count', metrics['count'].toString()),
      _buildField('Avg Latency', '${metrics['avgLatencyMs']} ms'),
      _buildField('P95 Latency', '${metrics['p95LatencyMs']} ms'),
      _buildField('P99 Latency', '${metrics['p99LatencyMs']} ms'),
      _buildField('Checkpoint Hit Rate', metrics['checkpointHitRate'].toString()),
      _buildField('Target Met Rate', metrics['targetMetRate'].toString()),
    ];
  }

  /// Checks if sequence is near a checkpoint.
  bool _isNearCheckpoint(int sequence) {
    return replayService.checkpointSequences.contains(sequence);
  }

  /// Returns placeholder payload JSON.
  String _getPlaceholderPayload() {
    const payload = {
      'anchorId': 'a-42',
      'position': {'x': 540.5, 'y': 320.0},
      'sampledPath': ['...'],
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }
}
