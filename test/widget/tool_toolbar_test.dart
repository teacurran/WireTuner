import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wiretuner/application/tools/framework/cursor_service.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
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
import 'package:wiretuner/presentation/shell/tool_toolbar.dart';
import 'package:wiretuner/domain/events/event_base.dart';

void main() {
  group('ToolToolbar Widget Tests', () {
    late ToolManager toolManager;
    late Document document;
    late ViewportController viewportController;
    late EventRecorder eventRecorder;
    late PathRenderer pathRenderer;

    setUp(() {
      // Create mock services
      document = const Document(id: 'test-doc', title: 'Test Document');
      viewportController = ViewportController();
      pathRenderer = PathRenderer();
      final mockEventStore = _MockEventStore();
      eventRecorder = EventRecorder(
        eventStore: mockEventStore,
        documentId: document.id,
      );

      // Create tool manager
      final cursorService = CursorService();
      toolManager = ToolManager(
        cursorService: cursorService,
        eventRecorder: eventRecorder,
      );

      // Register all 7 tools
      toolManager.registerTool(
        SelectionTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );

      toolManager.registerTool(
        DirectSelectionTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
          pathRenderer: pathRenderer,
        ),
      );

      toolManager.registerTool(
        PenTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );

      toolManager.registerTool(
        RectangleTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );

      toolManager.registerTool(
        EllipseTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );

      toolManager.registerTool(
        PolygonTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );

      toolManager.registerTool(
        StarTool(
          document: document,
          viewportController: viewportController,
          eventRecorder: eventRecorder,
        ),
      );
    });

    tearDown(() {
      toolManager.dispose();
      viewportController.dispose();
      eventRecorder.dispose();
    });

    testWidgets('renders all 7 tool buttons', (WidgetTester tester) async {
      // Build the toolbar wrapped in MaterialApp and Provider
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Verify all 7 tool buttons are present by checking for their icons
      expect(find.byIcon(Icons.near_me), findsOneWidget); // Selection
      expect(
          find.byIcon(Icons.control_point), findsOneWidget); // Direct Selection
      expect(find.byIcon(Icons.edit), findsOneWidget); // Pen
      expect(find.byIcon(Icons.rectangle), findsOneWidget); // Rectangle
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget); // Ellipse
      expect(find.byIcon(Icons.hexagon_outlined), findsOneWidget); // Polygon
      expect(find.byIcon(Icons.star_outline), findsOneWidget); // Star
    });

    testWidgets('clicking button activates corresponding tool',
        (WidgetTester tester) async {
      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Initially no tool is active
      expect(toolManager.activeToolId, isNull);

      // Tap the Rectangle tool button
      await tester.tap(find.byIcon(Icons.rectangle));
      await tester.pumpAndSettle();

      // Verify Rectangle tool is now active
      expect(toolManager.activeToolId, equals('rectangle'));

      // Tap the Ellipse tool button
      await tester.tap(find.byIcon(Icons.circle_outlined));
      await tester.pumpAndSettle();

      // Verify Ellipse tool is now active
      expect(toolManager.activeToolId, equals('ellipse'));
    });

    testWidgets('active tool is visually highlighted',
        (WidgetTester tester) async {
      // Activate the Pen tool before building
      toolManager.activateTool('pen');

      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Find the IconButton for the Pen tool
      final penButton = find.ancestor(
        of: find.byIcon(Icons.edit),
        matching: find.byType(IconButton),
      );

      expect(penButton, findsOneWidget);

      // Get the IconButton widget
      final IconButton iconButton = tester.widget(penButton);

      // Verify the button has styling (non-null style indicates active state)
      expect(iconButton.style, isNotNull);
    });

    testWidgets('tool switching works correctly', (WidgetTester tester) async {
      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Test switching through all tools in sequence
      final toolSequence = [
        (Icons.near_me, 'selection'),
        (Icons.control_point, 'direct_selection'),
        (Icons.edit, 'pen'),
        (Icons.rectangle, 'rectangle'),
        (Icons.circle_outlined, 'ellipse'),
        (Icons.hexagon_outlined, 'polygon'),
        (Icons.star_outline, 'star'),
      ];

      for (final (icon, expectedToolId) in toolSequence) {
        // Find the IconButton containing this icon
        final iconFinder = find.byIcon(icon);
        final buttonFinder = find.ancestor(
          of: iconFinder,
          matching: find.byType(IconButton),
        );

        // Tap the tool button
        await tester.tap(buttonFinder.first);
        await tester.pumpAndSettle();

        // Verify the tool is activated
        expect(
          toolManager.activeToolId,
          equals(expectedToolId),
          reason:
              'Expected tool $expectedToolId to be active after tapping icon $icon',
        );
      }
    });

    testWidgets('toolbar displays tool tooltips', (WidgetTester tester) async {
      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Find the Selection tool tooltip
      final selectionTooltip = find.ancestor(
        of: find.byIcon(Icons.near_me),
        matching: find.byType(Tooltip),
      );

      expect(selectionTooltip, findsOneWidget);

      // Verify tooltip message (Selection Tool)
      final Tooltip tooltip = tester.widget(selectionTooltip);
      expect(tooltip.message, equals('Selection Tool'));
    });

    testWidgets('toolbar has correct layout dimensions',
        (WidgetTester tester) async {
      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Find the toolbar container
      final toolbarContainer = find.byType(Container).first;
      final Container container = tester.widget(toolbarContainer);

      // Verify toolbar has fixed width
      expect(container.constraints?.maxWidth, equals(ToolToolbar.toolbarWidth));
    });

    testWidgets('toolbar updates when tool manager changes',
        (WidgetTester tester) async {
      // Build the toolbar
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ToolManager>.value(
              value: toolManager,
              child: const ToolToolbar(),
            ),
          ),
        ),
      );

      // Activate a tool programmatically (not via UI)
      toolManager.activateTool('star');

      // Trigger rebuild
      await tester.pump();

      // Verify the active tool ID updated
      expect(toolManager.activeToolId, equals('star'));
    });
  });
}

/// Mock implementation of EventStore for testing.
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
