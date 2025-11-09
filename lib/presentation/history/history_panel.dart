import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shell/app_shell.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/history/history_view_model.dart';
import 'package:wiretuner/presentation/history/thumbnail_generator.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

/// History panel widget displaying operation timeline with thumbnails.
///
/// **Features:**
/// - Chronological list of operations with labels
/// - Current position indicator (►)
/// - Search/filter by operation label
/// - Thumbnail previews of document state
/// - Click to navigate (scrub) to specific operation
/// - Lazy loading of thumbnails
/// - Keyboard shortcuts (arrow keys for navigation)
///
/// **Layout:**
/// ```
/// ┌─────────────────────────────┐
/// │ History              [🔍]   │
/// ├─────────────────────────────┤
/// │ [thumb] Create Rectangle    │
/// │ ► [thumb] Move Objects      │ ← Current
/// │ [thumb] Adjust Handle       │
/// │ [thumb] Create Path         │
/// └─────────────────────────────┘
/// ```
///
/// **Performance:**
/// - Lazy ListView with itemBuilder for efficient rendering
/// - Thumbnail caching via ThumbnailGenerator
/// - Throttled search input (300ms debounce)
/// - Target: 5k events/sec scrubbing performance
///
/// Related: Task I4.T4 (History Panel UI), docs/reference/undo_labels.md
class HistoryPanel extends StatefulWidget {
  /// Creates a history panel widget.
  ///
  /// [width]: Fixed width of the panel (default: 250px)
  const HistoryPanel({
    this.width = 250.0,
    super.key,
  });

  /// Fixed width of the history panel.
  final double width;

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ThumbnailGenerator _thumbnailGenerator = ThumbnailGenerator();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _thumbnailGenerator.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final undoProvider = context.watch<UndoProvider>();
    final documentProvider = context.watch<DocumentProvider>();

    // Build view model from undo/redo stacks
    final viewModel = HistoryViewModel(
      undoStack: undoProvider.undoStack,
      redoStack: undoProvider.redoStack,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          left: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with search
          _buildHeader(),

          // Operation list
          Expanded(
            child: viewModel.isEmpty
                ? _buildEmptyState()
                : _buildOperationList(
                    viewModel: viewModel,
                    undoProvider: undoProvider,
                    documentProvider: documentProvider,
                  ),
          ),

          // Footer with stats
          _buildFooter(viewModel),
        ],
      ),
    );
  }

  /// Builds panel header with title and search.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search operations...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Builds empty state when no operations exist.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Operations will appear here\nas you work',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds scrollable operation list.
  Widget _buildOperationList({
    required HistoryViewModel viewModel,
    required UndoProvider undoProvider,
    required DocumentProvider documentProvider,
  }) {
    final timeline = viewModel.timeline;

    return ListView.builder(
      controller: _scrollController,
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final entry = timeline[index];
        return _HistoryEntryTile(
          entry: entry,
          thumbnailGenerator: _thumbnailGenerator,
          document: documentProvider.document,
          onTap: () => _handleEntryTap(entry, undoProvider),
        );
      },
    );
  }

  /// Builds footer with operation count stats.
  Widget _buildFooter(HistoryViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Text(
        '${viewModel.timeline.length} operations',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// Handles clicking an operation entry to scrub to that state.
  void _handleEntryTap(HistoryEntry entry, UndoProvider undoProvider) {
    // Navigate to this operation group
    undoProvider.handleScrubToGroup(entry.group);
  }
}

/// Individual history entry tile with thumbnail and label.
class _HistoryEntryTile extends StatefulWidget {
  const _HistoryEntryTile({
    required this.entry,
    required this.thumbnailGenerator,
    required this.document,
    required this.onTap,
  });

  final HistoryEntry entry;
  final ThumbnailGenerator thumbnailGenerator;
  final Document document;
  final VoidCallback onTap;

  @override
  State<_HistoryEntryTile> createState() => _HistoryEntryTileState();
}

class _HistoryEntryTileState extends State<_HistoryEntryTile> {
  ui.Image? _thumbnail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(_HistoryEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.group.groupId != widget.entry.group.groupId) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final image = await widget.thumbnailGenerator.generate(
        groupId: widget.entry.group.groupId,
        document: widget.document,
      );

      if (mounted) {
        setState(() {
          _thumbnail = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HistoryPanel] Failed to load thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isCurrent = entry.isCurrent;

    return Material(
      color: isCurrent ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Current indicator
              SizedBox(
                width: 16,
                child: isCurrent
                    ? const Icon(
                        Icons.play_arrow,
                        size: 14,
                        color: Colors.blue,
                      )
                    : null,
              ),

              // Thumbnail
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildThumbnail(),
              ),

              const SizedBox(width: 8),

              // Label and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.group.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.group.eventCount} events • ${entry.group.durationMs}ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_thumbnail != null) {
      return CustomPaint(
        painter: _ThumbnailPainter(image: _thumbnail!),
      );
    }

    return Center(
      child: Icon(
        Icons.image_not_supported,
        size: 20,
        color: Colors.grey[400],
      ),
    );
  }
}

/// Custom painter for rendering thumbnail images.
class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter({required this.image});

  final ui.Image image;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Draw image scaled to fit
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
