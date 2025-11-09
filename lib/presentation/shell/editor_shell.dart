import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_binding.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/shell/tool_toolbar.dart';

/// Main editor shell widget that contains the toolbar and canvas area.
///
/// This widget establishes the main layout structure of the WireTuner editor:
/// - Left side: Vertical tool toolbar (fixed width)
/// - Right side: Canvas area with ViewportBinding for pan/zoom
///
/// ## Architecture
///
/// The EditorShell is the root UI widget for the editor interface. It:
/// - Consumes DocumentProvider, ViewportController, and ToolManager from Provider
/// - Displays the ToolToolbar for tool selection
/// - Provides the canvas area with ViewportBinding for viewport control
/// - Wires viewport state changes to persist in the document (Task I2.T8)
///
/// ## Viewport Integration
///
/// The canvas area uses ViewportBinding with:
/// - Keyboard shortcuts for zoom (+/-) and reset (Cmd/Ctrl+0)
/// - Space bar for pan mode with visual cursor feedback
/// - Viewport state persistence via DocumentProvider.updateViewport
/// - Bidirectional sync between controller and document
///
/// ## Usage
///
/// ```dart
/// MaterialApp(
///   home: EditorShell(),
/// )
/// ```
///
/// Note: Requires DocumentProvider, ViewportController, and ToolManager
/// to be provided higher in the widget tree.
class EditorShell extends StatelessWidget {
  /// Creates the editor shell widget.
  const EditorShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Access providers
    final documentProvider = context.watch<DocumentProvider>();
    final viewportController = context.watch<ViewportController>();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Row(
        children: [
          // Left sidebar: Tool toolbar
          const ToolToolbar(),

          // Main canvas area with viewport binding
          Expanded(
            child: Container(
              color: Colors.white,
              child: ViewportBinding(
                controller: viewportController,
                // Wire viewport changes to document provider
                onViewportChanged: (viewport) {
                  documentProvider.updateViewport(viewport);
                },
                // Enable debug mode to show shortcuts and FPS
                debugMode: true,
                child: const Center(
                  child: Text(
                    'Canvas Area\n'
                    'Try: Space bar to pan, +/- to zoom, Cmd/Ctrl+0 to reset\n'
                    '(Vector drawing canvas will be implemented in future iterations)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
