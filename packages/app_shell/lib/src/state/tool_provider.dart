import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wiretuner/application/tools/framework/cursor_service.dart';
import 'package:wiretuner/application/tools/framework/tool_manager.dart';
import 'package:wiretuner/application/tools/framework/tool_registry.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';

/// Provider configuration for the tool system.
///
/// This module provides a centralized way to wire up the tool system with
/// Flutter's Provider for dependency injection. It ensures:
/// - Singleton enforcement for [ToolManager] and [CursorService]
/// - Proper initialization order (CursorService → ToolManager)
/// - Automatic disposal when the widget tree is torn down
/// - Hot reload support
///
/// ## Architecture
///
/// The provider hierarchy follows this structure:
///
/// ```
/// MultiProvider
///   ├─ ChangeNotifierProvider<CursorService> (singleton)
///   └─ ChangeNotifierProxyProvider<CursorService, ToolManager> (singleton)
///        └─ depends on CursorService + optional EventRecorder
/// ```
///
/// ## Usage
///
/// ### Basic Setup (without EventRecorder)
///
/// ```dart
/// void main() {
///   runApp(
///     MultiProvider(
///       providers: [
///         ...ToolProvider.providers(),
///       ],
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ### Advanced Setup (with EventRecorder)
///
/// ```dart
/// void main() {
///   final eventRecorder = EventRecorder(...);
///
///   runApp(
///     MultiProvider(
///       providers: [
///         Provider.value(value: eventRecorder),
///         ...ToolProvider.providers(),
///       ],
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ### Accessing in Widgets
///
/// ```dart
/// class Toolbar extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final toolManager = context.watch<ToolManager>();
///
///     return Row(
///       children: [
///         for (final toolId in ['pen', 'selection'])
///           IconButton(
///             icon: Icon(Icons.edit),
///             onPressed: () => toolManager.activateTool(toolId),
///             color: toolManager.activeToolId == toolId
///                 ? Colors.blue
///                 : Colors.grey,
///           ),
///       ],
///     );
///   }
/// }
///
/// class Canvas extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final toolManager = context.read<ToolManager>();
///     final cursorService = context.watch<CursorService>();
///
///     return MouseRegion(
///       cursor: cursorService.currentCursor,
///       child: Listener(
///         onPointerDown: toolManager.handlePointerDown,
///         onPointerMove: toolManager.handlePointerMove,
///         onPointerUp: toolManager.handlePointerUp,
///         child: CustomPaint(
///           painter: CanvasPainter(),
///           foregroundPainter: ToolOverlayPainter(toolManager),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Initialization
///
/// Tools can be registered at app startup using the [ToolRegistry]:
///
/// ```dart
/// void main() {
///   // Register tool definitions
///   final registry = ToolRegistry.instance;
///   registry.registerDefinition(
///     ToolDefinition(
///       toolId: 'pen',
///       name: 'Pen Tool',
///       description: 'Create vector paths',
///       category: ToolCategory.drawing,
///       shortcut: 'P',
///       factory: () => PenTool(),
///     ),
///   );
///
///   runApp(
///     MultiProvider(
///       providers: ToolProvider.providers(),
///       builder: (context, _) {
///         // Initialize tools from registry
///         final toolManager = context.read<ToolManager>();
///         for (final def in registry.definitions) {
///           toolManager.registerTool(def.factory());
///         }
///
///         // Activate default tool
///         toolManager.activateTool('selection');
///
///         return MyApp();
///       },
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// ## Hot Reload Support
///
/// The providers are configured to survive hot reload:
/// - Tools remain registered across hot reload
/// - Active tool state is preserved
/// - Cursor state is maintained
///
/// ## Testing
///
/// For testing, you can provide mock instances:
///
/// ```dart
/// testWidgets('toolbar switches tools', (tester) async {
///   final mockToolManager = MockToolManager();
///
///   await tester.pumpWidget(
///     ChangeNotifierProvider<ToolManager>.value(
///       value: mockToolManager,
///       child: Toolbar(),
///     ),
///   );
///
///   // Test interactions
/// });
/// ```
///
/// Related: Section 2 (State Management Stack), T018 (Tool Framework)
class ToolProvider {
  /// Private constructor to prevent instantiation (static-only class).
  ToolProvider._();

  /// Returns the list of providers for the tool system.
  ///
  /// This method creates the provider hierarchy with proper dependencies.
  /// The [eventRecorder] is optional but recommended for production use.
  ///
  /// **Important**: If providing an [EventRecorder], ensure it's added to
  /// the provider tree BEFORE calling this method:
  ///
  /// ```dart
  /// MultiProvider(
  ///   providers: [
  ///     Provider.value(value: myEventRecorder),
  ///     ...ToolProvider.providers(),
  ///   ],
  /// )
  /// ```
  static List<SingleChildWidget> providers() {
    return [
      // 1. CursorService (no dependencies)
      ChangeNotifierProvider<CursorService>(
        create: (_) => CursorService(),
        lazy: false, // Initialize immediately for hot reload support
      ),

      // 2. ToolManager (depends on CursorService, optional EventRecorder)
      ChangeNotifierProxyProvider<CursorService, ToolManager>(
        create: (context) {
          final cursorService = context.read<CursorService>();

          // Try to get EventRecorder if available
          dynamic eventRecorder;
          try {
            eventRecorder = context.read<EventRecorder>();
          } catch (e) {
            // EventRecorder not provided, that's OK
            eventRecorder = null;
          }

          return ToolManager(
            cursorService: cursorService,
            eventRecorder: eventRecorder,
          );
        },
        update: (context, cursorService, previousToolManager) {
          // Preserve existing ToolManager instance on dependency updates
          // This ensures hot reload doesn't lose tool state
          return previousToolManager ?? ToolManager(
            cursorService: cursorService,
            eventRecorder: null,
          );
        },
        lazy: false, // Initialize immediately
      ),
    ];
  }

  /// Creates a singleton ToolManager provider with explicit dependencies.
  ///
  /// This is an alternative to [providers] for cases where you want more
  /// control over the provider setup or need to provide EventRecorder explicitly.
  ///
  /// Example:
  /// ```dart
  /// MultiProvider(
  ///   providers: [
  ///     ChangeNotifierProvider(create: (_) => CursorService()),
  ///     ToolProvider.createToolManagerProvider(
  ///       eventRecorder: myEventRecorder,
  ///     ),
  ///   ],
  /// )
  /// ```
  static ChangeNotifierProxyProvider<CursorService, ToolManager>
      createToolManagerProvider({
    dynamic eventRecorder,
  }) {
    return ChangeNotifierProxyProvider<CursorService, ToolManager>(
      create: (context) {
        final cursorService = context.read<CursorService>();
        return ToolManager(
          cursorService: cursorService,
          eventRecorder: eventRecorder,
        );
      },
      update: (context, cursorService, previousToolManager) {
        return previousToolManager ?? ToolManager(
          cursorService: cursorService,
          eventRecorder: eventRecorder,
        );
      },
      lazy: false,
    );
  }

  /// Helper to initialize tools from the registry.
  ///
  /// This should be called after the providers are set up, typically in
  /// a builder or initState.
  ///
  /// Example:
  /// ```dart
  /// MultiProvider(
  ///   providers: ToolProvider.providers(),
  ///   builder: (context, _) {
  ///     ToolProvider.initializeToolsFromRegistry(context);
  ///     return MyApp();
  ///   },
  /// )
  /// ```
  static void initializeToolsFromRegistry(
    BuildContext context, {
    String? defaultToolId,
  }) {
    final toolManager = context.read<ToolManager>();
    final registry = ToolRegistry.instance;

    // Register all tools from the registry
    for (final definition in registry.definitions) {
      final tool = definition.factory();
      toolManager.registerTool(tool);
    }

    // Activate default tool if specified
    if (defaultToolId != null && toolManager.registeredTools.containsKey(defaultToolId)) {
      toolManager.activateTool(defaultToolId);
    }
  }
}
