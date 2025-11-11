import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';

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
}
