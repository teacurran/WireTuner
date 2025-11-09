import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_binding.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/shell/tool_toolbar.dart';
import 'package:wiretuner/presentation/history/history_panel.dart';
import 'package:wiretuner/presentation/history/history_scrubber.dart';

/// Main editor shell widget that contains the toolbar, canvas, and history panel.
///
/// This widget establishes the main layout structure of the WireTuner editor:
/// - Left side: Vertical tool toolbar (fixed width)
/// - Center: Canvas area with ViewportBinding for pan/zoom
/// - Right side: History panel with operation timeline (Task I4.T4)
/// - Bottom: History scrubber for playback controls
///
/// ## Architecture
///
/// The EditorShell is the root UI widget for the editor interface. It:
/// - Consumes DocumentProvider, ViewportController, ToolManager, and UndoProvider
/// - Displays the ToolToolbar for tool selection
/// - Provides the canvas area with ViewportBinding for viewport control
/// - Shows history panel with operation timeline and thumbnails
/// - Includes scrubber for timeline navigation and playback
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
/// ## History Panel Integration (Task I4.T4)
///
/// The history panel displays:
/// - Chronological operation list with thumbnails
/// - Current position indicator (►)
/// - Search/filter by operation label
/// - Click-to-navigate scrubbing
/// - Lazy thumbnail loading with caching
///
/// ## Usage
///
/// ```dart
/// MaterialApp(
///   home: EditorShell(),
/// )
/// ```
///
/// Note: Requires DocumentProvider, ViewportController, ToolManager, and
/// UndoProvider to be provided higher in the widget tree.
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
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Row(
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

                // Right sidebar: History panel (Task I4.T4)
                const HistoryPanel(),
              ],
            ),
          ),

          // Bottom: History scrubber
          const HistoryScrubber(),
        ],
      ),
    );
  }
}
