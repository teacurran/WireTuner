import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shell/app_shell.dart';
import 'package:wiretuner/application/services/keyboard_shortcut_service.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/models/path.dart' as domain;
import 'package:wiretuner/domain/models/shape.dart';
import 'package:wiretuner/domain/models/transform.dart' as domain_transform;
import 'package:wiretuner/presentation/canvas/viewport/viewport_binding.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/wiretuner_canvas.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/shell/tool_toolbar.dart';
import 'package:wiretuner/presentation/history/history_panel.dart';
import 'package:wiretuner/presentation/history/history_scrubber.dart';
import 'package:wiretuner/presentation/layers/layers_panel.dart';

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
    final toolManager = context.watch<ToolManager>();
    final undoProvider = context.watch<UndoProvider>();

    // Wrap the scaffold with keyboard shortcuts for undo/redo
    return Shortcuts(
      shortcuts: KeyboardShortcutService.getShortcuts(),
      child: Actions(
        actions: KeyboardShortcutService.getActions(
          onUndo: () => undoProvider.handleUndo(),
          onRedo: () => undoProvider.handleRedo(),
        ),
        child: Scaffold(
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
                          child: Listener(
                            // Route pointer events to active tool
                            onPointerDown: (event) {
                              toolManager.handlePointerDown(event);
                            },
                            onPointerMove: (event) {
                              toolManager.handlePointerMove(event);
                            },
                            onPointerUp: (event) {
                              toolManager.handlePointerUp(event);
                            },
                            child: _CanvasAdapter(
                              document: documentProvider.document,
                              viewportController: viewportController,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right sidebar: Tabbed panel with Layers and History
                    _RightSidebarTabs(),
                  ],
                ),
              ),

              // Bottom: History scrubber
              const HistoryScrubber(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adapter widget that extracts paths and shapes from the document
/// and passes them to WireTunerCanvas in the expected format.
class _CanvasAdapter extends StatelessWidget {
  const _CanvasAdapter({
    required this.document,
    required this.viewportController,
  });

  final Document document;
  final ViewportController viewportController;

  @override
  Widget build(BuildContext context) {
    // Get tool manager from context
    final toolManager = context.watch<ToolManager>();

    // Extract paths and shapes from all layers
    final paths = <domain.Path>[];
    final shapes = <String, Shape>{};
    final shapeTransforms = <String, domain_transform.Transform>{};

    // Get the first artboard (or use a default empty state if none exists)
    final artboard = document.artboards.isNotEmpty ? document.artboards.first : null;

    if (artboard != null) {
      debugPrint('[_CanvasAdapter] Extracting from ${artboard.layers.length} layers');
      for (final layer in artboard.layers) {
        debugPrint('[_CanvasAdapter] Layer ${layer.id} has ${layer.objects.length} objects');
        for (final obj in layer.objects) {
          obj.when(
            path: (id, path, transform) {
              debugPrint('[_CanvasAdapter] Adding path: $id');
              paths.add(path);
              // TODO: Handle path transforms
            },
            shape: (id, shape, transform) {
              debugPrint('[_CanvasAdapter] Adding shape: $id (${shape.kind}), transform: $transform');
              shapes[id] = shape;
              if (transform != null) {
                shapeTransforms[id] = transform as domain_transform.Transform;
              }
            },
          );
        }
      }
    }

    debugPrint('[_CanvasAdapter] Passing to canvas: ${paths.length} paths, ${shapes.length} shapes, ${shapeTransforms.length} transforms');

    return WireTunerCanvas(
      paths: paths,
      shapes: shapes,
      shapeTransforms: shapeTransforms,
      selection: artboard?.selection ?? const Selection(),
      viewportController: viewportController,
      toolManager: toolManager,
    );
  }
}

/// Tabbed widget for right sidebar showing Layers and History panels.
class _RightSidebarTabs extends StatefulWidget {
  @override
  State<_RightSidebarTabs> createState() => _RightSidebarTabsState();
}

class _RightSidebarTabsState extends State<_RightSidebarTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(
                icon: Icon(Icons.layers, size: 16),
                text: 'Layers',
              ),
              Tab(
                icon: Icon(Icons.history, size: 16),
                text: 'History',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                LayersPanel(),
                HistoryPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
