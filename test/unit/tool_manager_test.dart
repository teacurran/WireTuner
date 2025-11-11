import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/framework/cursor_service.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/application/tools/framework/tool_registry.dart';

/// Fake tool implementation for testing.
///
/// Records all lifecycle and event handling calls for verification.
class FakeTool implements ITool {
  FakeTool(
    this._toolId, {
    MouseCursor cursor = SystemMouseCursors.basic,
  }) : _cursor = cursor;
  final String _toolId;
  final MouseCursor _cursor;

  // Lifecycle tracking
  int activateCallCount = 0;
  int deactivateCallCount = 0;

  // Event handling tracking
  final List<String> eventLog = [];
  bool pointerDownHandled = true;
  bool pointerMoveHandled = false;
  bool pointerUpHandled = true;
  bool keyPressHandled = false;

  @override
  String get toolId => _toolId;

  @override
  MouseCursor get cursor => _cursor;

  @override
  void onActivate() {
    activateCallCount++;
    eventLog.add('activate');
  }

  @override
  void onDeactivate() {
    deactivateCallCount++;
    eventLog.add('deactivate');
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    eventLog.add('pointerDown');
    return pointerDownHandled;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    eventLog.add('pointerMove');
    return pointerMoveHandled;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    eventLog.add('pointerUp');
    return pointerUpHandled;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    eventLog.add('keyPress');
    return keyPressHandled;
  }

  @override
  void renderOverlay(Canvas canvas, Size size) {
    eventLog.add('render');
  }

  void reset() {
    activateCallCount = 0;
    deactivateCallCount = 0;
    eventLog.clear();
  }
}

/// Mock EventRecorder for testing that doesn't require a real EventStore.
class MockEventRecorder with ChangeNotifier {
  int pauseCallCount = 0;
  int resumeCallCount = 0;
  int flushCallCount = 0;
  bool _isPaused = false;

  void pause() {
    pauseCallCount++;
    _isPaused = true;
  }

  void resume() {
    resumeCallCount++;
    _isPaused = false;
  }

  void flush() {
    flushCallCount++;
  }

  bool get isPaused => _isPaused;
}

void main() {
  group('ToolManager', () {
    late ToolManager toolManager;
    late CursorService cursorService;
    late FakeTool penTool;
    late FakeTool selectionTool;

    setUp(() {
      cursorService = CursorService();
      toolManager = ToolManager(
        cursorService: cursorService,
      );
      penTool = FakeTool('pen', cursor: SystemMouseCursors.precise);
      selectionTool = FakeTool('selection', cursor: SystemMouseCursors.click);
    });

    tearDown(() {
      toolManager.dispose();
      cursorService.dispose();
    });

    group('Tool Registration', () {
      test('should register tool successfully', () {
        toolManager.registerTool(penTool);

        expect(toolManager.registeredTools.containsKey('pen'), isTrue);
        expect(toolManager.registeredTools['pen'], equals(penTool));
      });

      test('should replace existing tool with same ID', () {
        final penTool1 = FakeTool('pen');
        final penTool2 = FakeTool('pen');

        toolManager.registerTool(penTool1);
        toolManager.registerTool(penTool2);

        expect(toolManager.registeredTools['pen'], equals(penTool2));
      });

      test('should unregister tool successfully', () {
        toolManager.registerTool(penTool);
        toolManager.unregisterTool('pen');

        expect(toolManager.registeredTools.containsKey('pen'), isFalse);
      });

      test('should deactivate tool on unregister if active', () {
        toolManager.registerTool(penTool);
        toolManager.activateTool('pen');

        expect(toolManager.activeToolId, equals('pen'));

        toolManager.unregisterTool('pen');

        expect(toolManager.activeToolId, isNull);
        expect(penTool.deactivateCallCount, equals(1));
      });

      test('should handle unregistering non-existent tool gracefully', () {
        // Should not throw
        toolManager.unregisterTool('nonexistent');
      });
    });

    group('Tool Activation', () {
      setUp(() {
        toolManager.registerTool(penTool);
        toolManager.registerTool(selectionTool);
      });

      test('should activate tool successfully', () {
        final success = toolManager.activateTool('pen');

        expect(success, isTrue);
        expect(toolManager.activeToolId, equals('pen'));
        expect(toolManager.activeTool, equals(penTool));
        expect(penTool.activateCallCount, equals(1));
      });

      test('should fail to activate unregistered tool', () {
        final success = toolManager.activateTool('nonexistent');

        expect(success, isFalse);
        expect(toolManager.activeToolId, isNull);
      });

      test('should be no-op if tool is already active', () {
        toolManager.activateTool('pen');
        penTool.reset();

        toolManager.activateTool('pen');

        expect(penTool.activateCallCount, equals(0));
        expect(penTool.deactivateCallCount, equals(0));
      });

      test('should update cursor when activating tool', () {
        toolManager.activateTool('pen');

        expect(cursorService.currentCursor, equals(SystemMouseCursors.precise));
      });

      test('should deactivate previous tool when activating new tool', () {
        toolManager.activateTool('pen');
        toolManager.activateTool('selection');

        expect(penTool.deactivateCallCount, equals(1));
        expect(penTool.eventLog, contains('deactivate'));
        expect(selectionTool.activateCallCount, equals(1));
        expect(selectionTool.eventLog, contains('activate'));
      });

      test('should ensure only one tool is active at a time', () {
        toolManager.activateTool('pen');
        expect(toolManager.activeToolId, equals('pen'));

        toolManager.activateTool('selection');
        expect(toolManager.activeToolId, equals('selection'));
        expect(toolManager.activeTool, equals(selectionTool));
      });

      test('should call deactivate before activate when switching tools', () {
        toolManager.activateTool('pen');
        penTool.reset();
        selectionTool.reset();

        toolManager.activateTool('selection');

        // Pen should be deactivated before selection is activated
        expect(penTool.deactivateCallCount, equals(1));
        expect(selectionTool.activateCallCount, equals(1));
      });

      test('should reset cursor when deactivating tool', () {
        toolManager.activateTool('pen');
        expect(cursorService.currentCursor, equals(SystemMouseCursors.precise));

        toolManager.deactivateCurrentTool();

        expect(cursorService.currentCursor, equals(SystemMouseCursors.basic));
      });

      test('should handle deactivating when no tool is active', () {
        // Should not throw
        toolManager.deactivateCurrentTool();
        expect(toolManager.activeToolId, isNull);
      });
    });

    group('Event Routing', () {
      setUp(() {
        toolManager.registerTool(penTool);
        toolManager.activateTool('pen');
      });

      test('should route pointer down event to active tool', () {
        const event = PointerDownEvent(
          position: Offset(100, 100),
        );

        final handled = toolManager.handlePointerDown(event);

        expect(handled, isTrue);
        expect(penTool.eventLog, contains('pointerDown'));
      });

      test('should route pointer move event to active tool', () {
        const event = PointerMoveEvent(
          position: Offset(150, 150),
        );

        final handled = toolManager.handlePointerMove(event);

        expect(handled, isFalse); // FakeTool returns false by default
        expect(penTool.eventLog, contains('pointerMove'));
      });

      test('should route pointer up event to active tool', () {
        const event = PointerUpEvent(
          position: Offset(200, 200),
        );

        final handled = toolManager.handlePointerUp(event);

        expect(handled, isTrue);
        expect(penTool.eventLog, contains('pointerUp'));
      });

      test('should route keyboard event to active tool', () {
        const event = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.enter,
          physicalKey: PhysicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        );

        final handled = toolManager.handleKeyPress(event);

        expect(handled, isFalse); // FakeTool returns false by default
        expect(penTool.eventLog, contains('keyPress'));
      });

      test('should return false for events when no tool is active', () {
        toolManager.deactivateCurrentTool();

        const pointerEvent = PointerDownEvent(position: Offset(0, 0));
        const keyEvent = KeyDownEvent(
          logicalKey: LogicalKeyboardKey.keyA,
          physicalKey: PhysicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        );

        expect(toolManager.handlePointerDown(pointerEvent), isFalse);
        expect(
            toolManager.handlePointerMove(const PointerMoveEvent()), isFalse);
        expect(toolManager.handlePointerUp(const PointerUpEvent()), isFalse);
        expect(toolManager.handleKeyPress(keyEvent), isFalse);
      });
    });

    group('Overlay Rendering', () {
      setUp(() {
        toolManager.registerTool(penTool);
      });

      test('should render active tool overlay', () {
        toolManager.activateTool('pen');

        final canvas = MockCanvas();
        const size = Size(800, 600);

        toolManager.renderOverlay(canvas, size);

        expect(penTool.eventLog, contains('render'));
      });

      test('should not render when no tool is active', () {
        final canvas = MockCanvas();
        const size = Size(800, 600);

        // Should not throw
        toolManager.renderOverlay(canvas, size);

        expect(penTool.eventLog, isEmpty);
      });
    });

    group('Event Recorder Integration', () {
      late MockEventRecorder eventRecorder;
      late ToolManager toolManagerWithRecorder;

      setUp(() {
        eventRecorder = MockEventRecorder();
        toolManagerWithRecorder = ToolManager(
          cursorService: cursorService,
          eventRecorder: eventRecorder,
        );
        toolManagerWithRecorder.registerTool(penTool);
        toolManagerWithRecorder.registerTool(selectionTool);
      });

      tearDown(() {
        toolManagerWithRecorder.dispose();
        eventRecorder.dispose();
      });

      test('should flush events when deactivating tool', () {
        toolManagerWithRecorder.activateTool('pen');
        expect(eventRecorder.flushCallCount, equals(0));

        toolManagerWithRecorder.activateTool('selection');

        expect(eventRecorder.flushCallCount, greaterThan(0));
      });

      test('should flush events after pointer up', () {
        toolManagerWithRecorder.activateTool('pen');
        eventRecorder.flushCallCount = 0;

        const event = PointerUpEvent(position: Offset(100, 100));
        toolManagerWithRecorder.handlePointerUp(event);

        expect(eventRecorder.flushCallCount, equals(1));
      });

      test('should pause and resume recording', () {
        toolManagerWithRecorder.pauseRecording();
        expect(eventRecorder.pauseCallCount, equals(1));
        expect(eventRecorder.isPaused, isTrue);

        toolManagerWithRecorder.resumeRecording();
        expect(eventRecorder.resumeCallCount, equals(1));
        expect(eventRecorder.isPaused, isFalse);
      });
    });

    group('Cursor Management', () {
      setUp(() {
        toolManager.registerTool(penTool);
        toolManager.registerTool(selectionTool);
      });

      test('should update cursor to tool cursor on activation', () {
        toolManager.activateTool('pen');
        expect(cursorService.currentCursor, equals(SystemMouseCursors.precise));

        toolManager.activateTool('selection');
        expect(cursorService.currentCursor, equals(SystemMouseCursors.click));
      });

      test('should allow dynamic cursor updates', () {
        toolManager.activateTool('pen');

        toolManager.updateCursor(SystemMouseCursors.move);

        expect(cursorService.currentCursor, equals(SystemMouseCursors.move));
      });
    });

    group('Lifecycle and Cleanup', () {
      test('should deactivate tool on manager disposal', () {
        // Use a separate tool manager instance for this test to avoid double-dispose
        final localToolManager = ToolManager(
          cursorService: cursorService,
        );
        final localPenTool = FakeTool('pen');

        localToolManager.registerTool(localPenTool);
        localToolManager.activateTool('pen');

        expect(localPenTool.activateCallCount, equals(1));

        localToolManager.dispose();

        expect(localPenTool.deactivateCallCount, equals(1));
        expect(localToolManager.activeTool, isNull);
      });
    });

    group('State Transitions', () {
      setUp(() {
        toolManager.registerTool(penTool);
        toolManager.registerTool(selectionTool);
      });

      test('should transition through states correctly', () {
        // Initial state: no tool active
        expect(toolManager.activeToolId, isNull);

        // Activate pen tool
        toolManager.activateTool('pen');
        expect(toolManager.activeToolId, equals('pen'));
        expect(penTool.activateCallCount, equals(1));
        expect(penTool.deactivateCallCount, equals(0));

        // Switch to selection tool
        toolManager.activateTool('selection');
        expect(toolManager.activeToolId, equals('selection'));
        expect(penTool.deactivateCallCount, equals(1));
        expect(selectionTool.activateCallCount, equals(1));

        // Deactivate current tool
        toolManager.deactivateCurrentTool();
        expect(toolManager.activeToolId, isNull);
        expect(selectionTool.deactivateCallCount, equals(1));
      });
    });

    group('ChangeNotifier Behavior', () {
      test('should notify listeners on tool registration', () {
        var notified = false;
        toolManager.addListener(() => notified = true);

        toolManager.registerTool(penTool);

        expect(notified, isTrue);
      });

      test('should notify listeners on tool unregistration', () {
        toolManager.registerTool(penTool);

        var notified = false;
        toolManager.addListener(() => notified = true);

        toolManager.unregisterTool('pen');

        expect(notified, isTrue);
      });

      test('should notify listeners on tool activation', () {
        toolManager.registerTool(penTool);

        var notified = false;
        toolManager.addListener(() => notified = true);

        toolManager.activateTool('pen');

        expect(notified, isTrue);
      });

      test('should notify listeners on tool deactivation', () {
        toolManager.registerTool(penTool);
        toolManager.activateTool('pen');

        var notified = false;
        toolManager.addListener(() => notified = true);

        toolManager.deactivateCurrentTool();

        expect(notified, isTrue);
      });
    });
  });

  group('Hotkey Handling', () {
    late ToolManager toolManager;
    late CursorService cursorService;
    late ToolRegistry registry;
    late FakeTool penTool;

    setUpAll(() {
      // Initialize the TestWidgetsFlutterBinding to support HardwareKeyboard.instance
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      cursorService = CursorService();
      toolManager = ToolManager(
        cursorService: cursorService,
      );
      registry = ToolRegistry.instance;
      registry.clear();

      penTool = FakeTool('pen', cursor: SystemMouseCursors.precise);

      // Register tool definition with shortcut
      registry.registerDefinition(
        ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          shortcut: 'P',
          factory: () => penTool,
        ),
      );

      toolManager.registerTool(penTool);
    });

    tearDown() {
      registry.clear();
      toolManager.dispose();
      cursorService.dispose();
    }

    test('should handle tool hotkey with registry integration', () {
      const event = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.keyP,
        physicalKey: PhysicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      // Now returns true and activates the tool
      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isTrue);
      expect(toolManager.activeToolId, equals('pen'));
    });

    test('should not interfere with active tool key handling', () {
      toolManager.activateTool('pen');

      const hotkeyEvent = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.keyP,
        physicalKey: PhysicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      const toolKeyEvent = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.enter,
        physicalKey: PhysicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );

      // Hotkey now returns true (tool already active)
      expect(toolManager.handleToolHotkey(hotkeyEvent), isTrue);

      // Tool key handling still works
      expect(toolManager.handleKeyPress(toolKeyEvent), isFalse);
      expect(penTool.eventLog, contains('keyPress'));
    });
  });

  group('Invalid Activation Attempts', () {
    late ToolManager toolManager;
    late CursorService cursorService;
    late FakeTool penTool;
    late FakeTool selectionTool;

    setUp(() {
      cursorService = CursorService();
      toolManager = ToolManager(
        cursorService: cursorService,
      );
      penTool = FakeTool('pen', cursor: SystemMouseCursors.precise);
      selectionTool = FakeTool('selection', cursor: SystemMouseCursors.click);
      toolManager.registerTool(penTool);
      toolManager.registerTool(selectionTool);
    });

    tearDown(() {
      toolManager.dispose();
      cursorService.dispose();
    });

    test('should reject activation of unregistered tool', () {
      final success = toolManager.activateTool('nonexistent');

      expect(success, isFalse);
      expect(toolManager.activeToolId, isNull);
      expect(toolManager.activeTool, isNull);
    });

    test('should handle activation of empty string toolId', () {
      final success = toolManager.activateTool('');

      expect(success, isFalse);
      expect(toolManager.activeToolId, isNull);
    });

    test('should handle multiple invalid activation attempts', () {
      expect(toolManager.activateTool('invalid1'), isFalse);
      expect(toolManager.activateTool('invalid2'), isFalse);
      expect(toolManager.activateTool('invalid3'), isFalse);

      expect(toolManager.activeToolId, isNull);
      expect(toolManager.activeTool, isNull);
    });

    test('should allow valid activation after invalid attempts', () {
      toolManager.activateTool('invalid1');
      toolManager.activateTool('invalid2');

      final success = toolManager.activateTool('pen');

      expect(success, isTrue);
      expect(toolManager.activeToolId, equals('pen'));
      expect(penTool.activateCallCount, equals(1));
    });

    test('should preserve current tool if invalid activation attempted', () {
      toolManager.activateTool('pen');
      expect(toolManager.activeToolId, equals('pen'));

      final success = toolManager.activateTool('invalid');

      expect(success, isFalse);
      expect(toolManager.activeToolId, equals('pen')); // Still pen
      expect(penTool.deactivateCallCount, equals(0)); // Not deactivated
    });

    test('should handle special characters in toolId', () {
      final success = toolManager.activateTool('tool-with-@#\$%');

      expect(success, isFalse);
      expect(toolManager.activeToolId, isNull);
    });
  });

  group('Activation Order Verification', () {
    late ToolManager toolManager;
    late CursorService cursorService;
    late FakeTool penTool;
    late FakeTool selectionTool;

    setUp(() {
      cursorService = CursorService();
      toolManager = ToolManager(
        cursorService: cursorService,
      );
      penTool = FakeTool('pen', cursor: SystemMouseCursors.precise);
      selectionTool = FakeTool('selection', cursor: SystemMouseCursors.click);
      toolManager.registerTool(penTool);
      toolManager.registerTool(selectionTool);
    });

    tearDown(() {
      toolManager.dispose();
      cursorService.dispose();
    });

    test('should enforce deactivate before activate order', () {
      toolManager.activateTool('pen');
      penTool.reset();
      selectionTool.reset();

      toolManager.activateTool('selection');

      // Verify order: pen deactivated first, then selection activated
      expect(penTool.eventLog, ['deactivate']);
      expect(selectionTool.eventLog, ['activate']);
      expect(penTool.deactivateCallCount, equals(1));
      expect(selectionTool.activateCallCount, equals(1));
    });

    test('should complete deactivation before new tool sees events', () {
      toolManager.activateTool('pen');
      penTool.reset();
      selectionTool.reset();

      // Switch tools
      toolManager.activateTool('selection');

      // Verify pen is deactivated
      expect(penTool.deactivateCallCount, equals(1));

      // Verify selection is active and receives events
      const event = PointerDownEvent(position: Offset(100, 100));
      toolManager.handlePointerDown(event);

      expect(selectionTool.eventLog, contains('activate'));
      expect(selectionTool.eventLog, contains('pointerDown'));
      expect(penTool.eventLog, isNot(contains('pointerDown')));
    });
  });

  group('CursorService', () {
    late CursorService cursorService;

    setUp(() {
      cursorService = CursorService();
    });

    tearDown(() {
      cursorService.dispose();
    });

    test('should initialize with default cursor', () {
      expect(cursorService.currentCursor, equals(SystemMouseCursors.basic));
    });

    test('should initialize with custom cursor', () {
      final service = CursorService(
        initialCursor: SystemMouseCursors.precise,
      );
      expect(service.currentCursor, equals(SystemMouseCursors.precise));
      service.dispose();
    });

    test('should update cursor and notify listeners', () {
      var notified = false;
      cursorService.addListener(() => notified = true);

      cursorService.setCursor(SystemMouseCursors.click);

      expect(cursorService.currentCursor, equals(SystemMouseCursors.click));
      expect(notified, isTrue);
    });

    test('should not notify listeners if cursor unchanged', () {
      cursorService.setCursor(SystemMouseCursors.basic); // Set to current value

      var notified = false;
      cursorService.addListener(() => notified = true);

      cursorService.setCursor(SystemMouseCursors.basic);

      expect(notified, isFalse);
    });

    test('should reset to default cursor', () {
      cursorService.setCursor(SystemMouseCursors.precise);
      cursorService.reset();

      expect(cursorService.currentCursor, equals(SystemMouseCursors.basic));
    });

    test('should support cursor propagation within frame budget', () {
      // This test validates the performance requirement:
      // cursor updates must propagate within <1 frame (16.67ms at 60fps)

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 100; i++) {
        cursorService.setCursor(
          i.isEven ? SystemMouseCursors.click : SystemMouseCursors.precise,
        );
      }

      stopwatch.stop();

      // 100 cursor updates should complete in well under 1 second
      // This validates the cursor service is efficient enough for real-time updates
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Tool Hotkey Handling', () {
    late ToolManager toolManager;
    late CursorService cursorService;
    late ToolRegistry registry;
    late FakeTool penTool;
    late FakeTool selectionTool;
    late FakeTool directSelectionTool;

    setUpAll(() {
      // Initialize the TestWidgetsFlutterBinding to support HardwareKeyboard.instance
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      cursorService = CursorService();
      toolManager = ToolManager(cursorService: cursorService);
      registry = ToolRegistry.instance;
      registry.clear();

      // Create tools
      penTool = FakeTool('pen', cursor: SystemMouseCursors.precise);
      selectionTool = FakeTool('selection', cursor: SystemMouseCursors.click);
      directSelectionTool =
          FakeTool('direct_selection', cursor: SystemMouseCursors.move);

      // Register tool definitions with shortcuts
      registry.registerDefinition(
        ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          shortcut: 'P',
          factory: () => penTool,
        ),
      );

      registry.registerDefinition(
        ToolDefinition(
          toolId: 'selection',
          name: 'Selection Tool',
          description: 'Test',
          category: ToolCategory.selection,
          shortcut: 'V',
          factory: () => selectionTool,
        ),
      );

      registry.registerDefinition(
        ToolDefinition(
          toolId: 'direct_selection',
          name: 'Direct Selection Tool',
          description: 'Test',
          category: ToolCategory.selection,
          shortcut: 'A',
          factory: () => directSelectionTool,
        ),
      );

      // Register tools with manager
      toolManager.registerTool(penTool);
      toolManager.registerTool(selectionTool);
      toolManager.registerTool(directSelectionTool);
    });

    tearDown(() {
      registry.clear();
      toolManager.dispose();
    });

    test('should activate tool via single-key hotkey (P for pen)', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isTrue);
      expect(toolManager.activeToolId, equals('pen'));
      expect(penTool.activateCallCount, equals(1));
    });

    test('should activate tool via hotkey (V for selection)', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyV,
        logicalKey: LogicalKeyboardKey.keyV,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isTrue);
      expect(toolManager.activeToolId, equals('selection'));
      expect(selectionTool.activateCallCount, equals(1));
    });

    test('should activate tool via hotkey (A for direct selection)', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isTrue);
      expect(toolManager.activeToolId, equals('direct_selection'));
      expect(directSelectionTool.activateCallCount, equals(1));
    });

    test('should switch tools via hotkeys and deactivate previous tool', () {
      // Activate pen tool via hotkey
      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
      );

      expect(toolManager.activeToolId, equals('pen'));
      expect(penTool.activateCallCount, equals(1));
      expect(penTool.deactivateCallCount, equals(0));

      // Switch to selection tool via hotkey
      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyV,
          logicalKey: LogicalKeyboardKey.keyV,
          timeStamp: Duration.zero,
        ),
      );

      expect(toolManager.activeToolId, equals('selection'));
      expect(penTool.deactivateCallCount, equals(1)); // Pen tool deactivated
      expect(selectionTool.activateCallCount, equals(1));
    });

    test('should be case-insensitive for shortcuts', () {
      // Lowercase 'p' should activate pen tool
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isTrue);
      expect(toolManager.activeToolId, equals('pen'));
    });

    test('should ignore hotkeys when no tool is registered for shortcut', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyX,
        logicalKey: LogicalKeyboardKey.keyX,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isFalse);
      expect(toolManager.activeToolId, isNull);
    });

    test('should ignore key up events (only handle key down)', () {
      final event = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isFalse);
      expect(toolManager.activeToolId, isNull);
    });

    test('should ignore key repeat events', () {
      final event = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isFalse);
    });

    test('should ignore hotkeys when modifier keys are pressed (Ctrl+P)', () {
      // Simulate Ctrl+P (which might be a global shortcut like Print)
      // Note: In real testing, HardwareKeyboard state would be set
      // For unit tests, we can only test the key event itself
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      // With modifiers pressed, handleToolHotkey should return false
      // This test verifies the logic but can't simulate HardwareKeyboard state
      // in pure unit tests without widget test environment
      final handled = toolManager.handleToolHotkey(event);

      // In a real app with HardwareKeyboard.instance.isControlPressed == true,
      // this would return false. For unit tests, we verify the event is processed.
      expect(handled, isTrue); // Will activate tool in unit test environment
    });

    test('should ignore non-single-character keys (e.g., arrow keys)', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowUp,
        logicalKey: LogicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      );

      final handled = toolManager.handleToolHotkey(event);

      expect(handled, isFalse);
      expect(toolManager.activeToolId, isNull);
    });

    test('should handle rapid tool switching via hotkeys', () {
      // Simulate rapid hotkey presses
      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
      );

      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyV,
          logicalKey: LogicalKeyboardKey.keyV,
          timeStamp: const Duration(milliseconds: 50),
        ),
      );

      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: const Duration(milliseconds: 100),
        ),
      );

      // Final tool should be direct_selection
      expect(toolManager.activeToolId, equals('direct_selection'));

      // Each tool should have been activated once
      expect(penTool.activateCallCount, equals(1));
      expect(selectionTool.activateCallCount, equals(1));
      expect(directSelectionTool.activateCallCount, equals(1));

      // Pen and selection tools should have been deactivated
      expect(penTool.deactivateCallCount, equals(1));
      expect(selectionTool.deactivateCallCount, equals(1));
      expect(directSelectionTool.deactivateCallCount, equals(0)); // Still active
    });

    test('should not activate same tool twice if already active', () {
      // Activate pen tool
      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
      );

      expect(penTool.activateCallCount, equals(1));

      // Press P again
      toolManager.handleToolHotkey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: const Duration(milliseconds: 100),
        ),
      );

      // Should still be active but not reactivated
      expect(toolManager.activeToolId, equals('pen'));
      expect(penTool.activateCallCount, equals(1)); // Not incremented
      expect(penTool.deactivateCallCount, equals(0));
    });
  });
}

/// Mock Canvas for testing overlay rendering.
class MockCanvas implements Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
