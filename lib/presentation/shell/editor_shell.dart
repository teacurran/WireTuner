import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/presentation/shell/tool_toolbar.dart';

/// Main editor shell widget that contains the toolbar and canvas area.
///
/// This widget establishes the main layout structure of the WireTuner editor:
/// - Left side: Vertical tool toolbar (fixed width)
/// - Right side: Canvas area (expandable)
///
/// ## Architecture
///
/// The EditorShell is the root UI widget for the editor interface. It:
/// - Consumes ToolManager from Provider for tool management
/// - Displays the ToolToolbar for tool selection
/// - Provides the canvas area for vector drawing (placeholder for now)
///
/// ## Usage
///
/// ```dart
/// MaterialApp(
///   home: EditorShell(),
/// )
/// ```
///
/// Note: Requires ToolManager to be provided higher in the widget tree.
class EditorShell extends StatelessWidget {
  /// Creates the editor shell widget.
  const EditorShell({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.grey[200],
        body: Row(
          children: [
            // Left sidebar: Tool toolbar
            const ToolToolbar(),

            // Main canvas area (placeholder)
            Expanded(
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: Text(
                    'Canvas Area\n(Vector drawing canvas will be implemented in future iterations)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
