import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:app_shell/app_shell.dart';
import 'package:app/app.dart';
import 'package:wiretuner/application/services/document_event_applier.dart';
import 'package:wiretuner/application/services/undo_service.dart';
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
import 'package:wiretuner/domain/document/selection.dart';
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart'
    as app_event_recorder;
import 'package:wiretuner/infrastructure/event_sourcing/event_navigator.dart'
    as app_event_navigator;
import 'package:wiretuner/infrastructure/event_sourcing/event_replayer.dart'
    as app_event_replayer;
import 'package:wiretuner/infrastructure/persistence/event_store.dart';
import 'package:wiretuner/infrastructure/persistence/snapshot_store.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as app_event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';
import 'package:wiretuner/presentation/shell/editor_shell.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'dart:async';

/// Root application widget for WireTuner.
/// Configures Material Design 3 theme and application routing.
class App extends StatelessWidget {
  /// Creates the application root widget.
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WireTuner',
        theme: buildWireTunerTheme(brightness: Brightness.dark),
        home: const _AppInitializer(),
      );
}

/// Internal widget that initializes all services and provides them via Provider.
///
/// This widget creates and manages the lifecycle of core application services:
/// - DocumentProvider: Mutable document state with ChangeNotifier (Decision 7)
/// - EventRecorder: Event sourcing system (with mock EventStore for now)
/// - ViewportController: Canvas viewport transformations
/// - PathRenderer: Path-to-UI conversion service
/// - CursorService: Cursor state management
/// - ToolManager: Tool lifecycle and event routing
///
/// All 7 tools are registered and the Selection tool is activated by default.
/// Viewport state is persisted within the document and synced bidirectionally.
class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  // Core services
  late final DocumentProvider _documentProvider;
  late final app_event_recorder.EventRecorder _eventRecorder;
  late final ViewportController _viewportController;
  late final PathRenderer _pathRenderer;
  late final CursorService _cursorService;
  late final ToolManager _toolManager;

  // Undo/redo services
  late final Logger _logger;
  late final app_event_navigator.EventNavigator _eventNavigator;
  late final UndoService _undoService;
  late final UndoProvider _undoProvider;

  // Event application
  late final DocumentEventApplier _eventApplier;
  late final StreamSubscription<EventBase> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initializes all application services and registers tools.
  void _initializeServices() {
    // Create logger
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true,
        printTime: false,
      ),
    );

    // Create document provider with default document and default artboard
    _documentProvider = DocumentProvider(
      initialDocument: Document(
        id: 'default-doc',
        title: 'Untitled',
        artboards: const [
          Artboard(
            id: 'artboard-1',
            name: 'Artboard 1',
            bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
          ),
        ],
      ),
    );

    // Create viewport controller with default zoom and pan
    // Initial state will be synced from document viewport
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
    _eventRecorder = app_event_recorder.EventRecorder(
      eventStore: mockEventStore,
      documentId: _documentProvider.document.id,
    );

    // Initialize undo/redo infrastructure
    _initializeUndoSystem(mockEventStore);

    // Create tool manager with services
    _toolManager = ToolManager(
      cursorService: _cursorService,
      eventRecorder: _eventRecorder,
    );

    // Create event applier and wire it to event recorder
    _eventApplier = DocumentEventApplier(_documentProvider);
    _eventSubscription = _eventRecorder.eventStream.listen(
      _eventApplier.apply,
    );

    // Register all 7 tools
    _registerTools();

    // Activate default tool (Selection)
    _toolManager.activateTool('selection');
  }

  /// Initializes undo/redo system with EventNavigator and UndoService.
  void _initializeUndoSystem(EventStore eventStore) {
    // Create snapshot store (mock for now)
    final snapshotStore = _MockSnapshotStore();

    // Create event dispatcher with empty registry for now
    final dispatcher = app_event_dispatcher.EventDispatcher(
      EventHandlerRegistry(),
    );

    // Create event replayer
    final replayer = app_event_replayer.EventReplayer(
      eventStore: eventStore,
      snapshotStore: snapshotStore,
      dispatcher: dispatcher,
      enableCompression: false,
    );

    // Create event navigator
    _eventNavigator = app_event_navigator.EventNavigator(
      documentId: _documentProvider.document.id,
      replayer: replayer,
      eventStore: eventStore,
    );

    // Create undo service
    _undoService = UndoService(
      navigator: _eventNavigator,
      documentProvider: _documentProvider,
    );

    // Create undo provider (Flutter bridge) - need to adapt it
    _undoProvider = UndoProvider(
      undoService: _undoService,
    );
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
  ///
  /// Note: Tools receive the current document snapshot. In future iterations,
  /// they should observe DocumentProvider for changes.
  void _registerTools() {
    // Register Selection Tool
    _toolManager.registerTool(
      SelectionTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Direct Selection Tool
    _toolManager.registerTool(
      DirectSelectionTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
        pathRenderer: _pathRenderer,
        // telemetryService is optional, omitting for now
      ),
    );

    // Register Pen Tool
    _toolManager.registerTool(
      PenTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Rectangle Tool
    _toolManager.registerTool(
      RectangleTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Ellipse Tool
    _toolManager.registerTool(
      EllipseTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Polygon Tool
    _toolManager.registerTool(
      PolygonTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );

    // Register Star Tool
    _toolManager.registerTool(
      StarTool(
        document: _documentProvider.document,
        viewportController: _viewportController,
        eventRecorder: _eventRecorder,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose services in reverse order of creation
    _eventSubscription.cancel();
    _undoProvider.dispose();
    // Event navigator doesn't have dispose method
    _toolManager.dispose();
    _cursorService.dispose();
    _viewportController.dispose();
    _eventRecorder.dispose();
    _documentProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          // Provide DocumentProvider for mutable document state (Decision 7)
          ChangeNotifierProvider<DocumentProvider>.value(
            value: _documentProvider,
          ),
          // Provide ToolManager for toolbar and canvas
          ChangeNotifierProvider<ToolManager>.value(
            value: _toolManager,
          ),
          // Provide ViewportController for canvas transformations
          ChangeNotifierProvider<ViewportController>.value(
            value: _viewportController,
          ),
          // Provide UndoProvider for history panel and undo/redo
          ChangeNotifierProvider<UndoProvider>.value(
            value: _undoProvider,
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

/// Mock SnapshotStore for development.
///
/// This is a temporary implementation for the snapshot store dependency.
class _MockSnapshotStore implements SnapshotStore {
  @override
  Future<Map<String, dynamic>?> getLatestSnapshot(
    String documentId,
    int beforeSequence,
  ) async {
    // No snapshots in development mode
    return null;
  }

  @override
  Future<void> saveSnapshot(
    String documentId,
    int eventSequence,
    List<int> snapshotData,
  ) async {
    // No-op
  }

  @override
  Future<int> insertSnapshot({
    required String documentId,
    required int eventSequence,
    required Uint8List snapshotData,
    required String compression,
  }) async {
    // No-op - return 0 as placeholder ID
    return 0;
  }

  @override
  Future<int?> getLatestSnapshotSequence(String documentId) async {
    return null;
  }

  @override
  Future<int> deleteOldSnapshots(String documentId,
      {int keepCount = 10}) async {
    // No-op - return 0 deleted count
    return 0;
  }
}
