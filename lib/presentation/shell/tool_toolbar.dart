import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/object_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

/// Vertical toolbar widget displaying all available tools.
///
/// The ToolToolbar provides:
/// - Visual representation of all 7 tools (Selection, Direct Selection, Pen, Rectangle, Ellipse, Polygon, Star)
/// - Active tool highlighting
/// - Tool switching on button click
/// - Material Design 3 styling
///
/// ## Layout
///
/// The toolbar is a fixed-width (60px) vertical column on the left side of the editor.
/// Each tool is represented by an IconButton with:
/// - Material Design icon
/// - Tooltip showing tool name
/// - Visual highlight when active (filled style)
/// - Standard gray appearance when inactive
///
/// ## Tool Icons
///
/// The following Material Design icons are used:
/// - Selection: Icons.near_me (selection cursor)
/// - Direct Selection: Icons.control_point (precision selection)
/// - Pen: Icons.edit (drawing/creation)
/// - Rectangle: Icons.rectangle (rectangle shape)
/// - Ellipse: Icons.circle_outlined (ellipse/circle shape)
/// - Polygon: Icons.hexagon_outlined (polygon shape)
/// - Star: Icons.star_outline (star shape)
///
/// ## Usage
///
/// ```dart
/// Row(
///   children: [
///     ToolToolbar(),  // Fixed-width toolbar
///     Expanded(child: CanvasWidget()),  // Expandable canvas
///   ],
/// )
/// ```
///
/// Note: Requires ToolManager to be provided via Provider.
class ToolToolbar extends StatelessWidget {
  /// Creates the tool toolbar widget.
  const ToolToolbar({super.key});

  /// Fixed width of the toolbar in pixels.
  static const double toolbarWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    final toolManager = context.watch<ToolManager>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: toolbarWidth,
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // Toolbar title/header
          Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Tools',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          // Tool buttons
          _buildToolButton(
            context: context,
            toolId: 'selection',
            icon: Icons.near_me,
            tooltip: 'Selection Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'direct_selection',
            icon: Icons.control_point,
            tooltip: 'Direct Selection Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'pen',
            icon: Icons.edit,
            tooltip: 'Pen Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'rectangle',
            icon: Icons.rectangle,
            tooltip: 'Rectangle Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'ellipse',
            icon: Icons.circle_outlined,
            tooltip: 'Ellipse Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'polygon',
            icon: Icons.hexagon_outlined,
            tooltip: 'Polygon Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),
          _buildToolButton(
            context: context,
            toolId: 'star',
            icon: Icons.star_outline,
            tooltip: 'Star Tool',
            toolManager: toolManager,
            colorScheme: colorScheme,
          ),

          // Spacer to push tools to top
          const Spacer(),

          // Divider before action buttons
          Divider(
            color: colorScheme.outlineVariant,
            thickness: 1,
            height: 1,
          ),

          // Clear canvas button
          _buildActionButton(
            context: context,
            icon: Icons.delete_outline,
            tooltip: 'Clear Canvas',
            onPressed: () => _showClearCanvasDialog(context),
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Builds a tool button with appropriate styling based on active state.
  Widget _buildToolButton({
    required BuildContext context,
    required String toolId,
    required IconData icon,
    required String tooltip,
    required ToolManager toolManager,
    required ColorScheme colorScheme,
  }) {
    final isActive = toolManager.activeToolId == toolId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: IconButton(
          icon: Icon(icon),
          iconSize: 24,
          onPressed: () {
            toolManager.activateTool(toolId);
          },
          // Use filled style for active tool, standard for inactive
          style: isActive
              ? IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                )
              : IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }

  /// Builds an action button (not a tool selection button).
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: IconButton(
          icon: Icon(icon),
          iconSize: 24,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog for clearing the canvas.
  Future<void> _showClearCanvasDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear Canvas'),
          content: const Text(
            'Are you sure you want to clear the entire canvas?\n\n'
            'This will remove all shapes and paths. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      // Clear the canvas by emitting a clear event
      _clearCanvas(context);
    }
  }

  /// Clears the canvas by recording a delete event for all objects.
  void _clearCanvas(BuildContext context) {
    final documentProvider = context.read<DocumentProvider>();
    final eventRecorder = context.read<EventRecorder>();
    final uuid = const Uuid();

    // Get all object IDs from all layers
    final objectIds = <String>[];

    // Get the first artboard (or active artboard if there are multiple)
    final artboard = documentProvider.document.artboards.firstOrNull;
    if (artboard != null) {
      // Collect all object IDs from all layers
      for (final layer in artboard.layers) {
        for (final obj in layer.objects) {
          // Each object has an ID - the when method passes (id, object, transform)
          objectIds.add(
            obj.when(
              path: (id, _, __) => id,
              shape: (id, _, __) => id,
            ),
          );
        }
      }
    }

    // If there are objects to delete, emit a delete event
    if (objectIds.isNotEmpty) {
      final deleteEvent = DeleteObjectEvent(
        eventId: uuid.v4(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        objectIds: objectIds,
      );

      eventRecorder.recordEvent(deleteEvent);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${objectIds.length} object${objectIds.length == 1 ? '' : 's'} removed'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canvas is already empty'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
