import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
import 'package:wiretuner/application/tools/framework/cursor_service.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/application/tools/pen/pen_tool.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/application/tools/shapes/ellipse_tool.dart';
import 'package:wiretuner/application/tools/shapes/polygon_tool.dart';
import 'package:wiretuner/application/tools/shapes/rectangle_tool.dart';
import 'package:wiretuner/application/tools/shapes/star_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/shell/editor_shell.dart';
import 'package:wiretuner/domain/events/event_base.dart';

/// Root application widget for WireTuner.
/// Configures Material Design 3 theme and application routing.
class App extends StatelessWidget {
  /// Creates the application root widget.
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WireTuner',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _AppInitializer(),
      );
}

/// Internal widget that initializes all services and provides them via Provider.
///
/// This widget creates and manages the lifecycle of core application services:
/// - Document: The vector document model
/// - EventRecorder: Event sourcing system (with mock EventStore for now)
/// - ViewportController: Canvas viewport transformations
/// - PathRenderer: Path-to-UI conversion service
/// - CursorService: Cursor state management
/// - ToolManager: Tool lifecycle and event routing
///
/// All 7 tools are registered and the Selection tool is activated by default.
class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  // Core services
  late final Document _document;
  late final EventRecorder _eventRecorder;
  late final ViewportController _viewportController;
  late final PathRenderer _pathRenderer;
  late final CursorService _cursorService;
  late final ToolManager _toolManager;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initializes all application services and registers tools.
  void _initializeServices() {
    // Create core document model
    _document = const Document(id: 'default-doc', title: 'Untitled');

    // Create viewport controller with default zoom and pan
    _viewportController = ViewportController(
      initialPan: Offset.zero,
      initialZoom: 1.0,
    );

    // Create path renderer for geometric conversions
    _pathRenderer = PathRenderer();

    // Create cursor service for cursor management
    _cursorService = CursorService();

    // Create mock event store and recorder
    // Note: In production, this would be a real SQLite-backed EventStore
    final mockEventStore = _MockEventStore();
    _eventRecorder = EventRecorder(
      eventStore: mockEventStore,
      documentId: _document.id,
    );

    // Create tool manager with services
    _toolManager = ToolManager(
      cursorService: _cursorService,
      eventRecorder: _eventRecorder,
    );

    // Register all 7 tools
    _registerTools();

    // Activate default tool (Selection)
    _toolManager.activateTool('selection');
  }

  /// Registers all tools with the ToolManager.
  ///
  /// Tools registered:
  /// 1. Selection Tool (ID: 'selection')
  /// 2. Direct Selection Tool (ID: 'direct_selection')
  /// 3. Pen Tool (ID: 'pen')
  /// 4. Rectangle Tool (ID: 'rectangle')
  /// 5. Ellipse Tool (ID: 'ellipse')
  /// 6. Polygon Tool (ID: 'polygon')
  /// 7. Star Tool (ID: 'star')
  void _registerTools() {
    // Register Selection Tool
    _toolManager.registerTool(
      SelectionTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Direct Selection Tool
    _toolManager.registerTool(
      DirectSelectionTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
        pathRenderer: _pathRenderer,
        // telemetryService is optional, omitting for now
      ),
    );

    // Register Pen Tool
    _toolManager.registerTool(
      PenTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Rectangle Tool
    _toolManager.registerTool(
      RectangleTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Ellipse Tool
    _toolManager.registerTool(
      EllipseTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Polygon Tool
    _toolManager.registerTool(
      PolygonTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Star Tool
    _toolManager.registerTool(
      StarTool(
        document: _document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose services in reverse order of creation
    _toolManager.dispose();
    _cursorService.dispose();
    _viewportController.dispose();
    _eventRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          // Provide ToolManager for toolbar and canvas
          ChangeNotifierProvider<ToolManager>.value(
            value: _toolManager,
          ),
          // Provide ViewportController for canvas transformations
          ChangeNotifierProvider<ViewportController>.value(
            value: _viewportController,
          ),
          // Provide Document for future use
          Provider<Document>.value(
            value: _document,
          ),
        ],
        child: const EditorShell(),
      );
}

/// Mock implementation of EventStore for development.
///
/// This is a temporary implementation that satisfies the EventRecorder's
/// dependency on EventStore without requiring a full SQLite setup.
///
/// In production, this will be replaced with the real EventStore implementation
/// that persists events to SQLite.
class _MockEventStore implements EventStore {
  @override
  Future<int> insertEvent(String documentId, EventBase event) async => 0;

  @override
  Future<List<EventBase>> getEvents(
    String documentId, {
    required int fromSeq,
    int? toSeq,
  }) async =>
      [];

  @override
  Future<int> getMaxSequence(String documentId) async => -1;

  @override
  Future<List<int>> insertEventsBatch(
    String documentId,
    List<EventBase> events,
  ) async =>
      List.filled(events.length, 0);
}
