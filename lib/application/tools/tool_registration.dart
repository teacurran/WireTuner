import 'package:wiretuner/application/tools/framework/tool_registry.dart';
import 'package:wiretuner/application/tools/pen/pen_tool.dart';
import 'package:wiretuner/application/tools/selection/selection_tool.dart';
import 'package:wiretuner/application/tools/direct_selection/direct_selection_tool.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:event_core/src/operation_grouping.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';

/// Registers all built-in tool definitions with the [ToolRegistry].
///
/// This function should be called at application startup to populate
/// the tool registry with definitions for pen, selection, and direct selection tools.
///
/// ## Architecture
///
/// Tool registration follows a two-phase initialization pattern:
/// 1. **Registration Phase** (this function): Register tool metadata and factories
/// 2. **Instantiation Phase** (ToolManager): Create tool instances when needed
///
/// This separation allows for:
/// - Centralized tool metadata (shortcuts, categories, tooltips)
/// - Lazy tool instantiation (only create when activated)
/// - Easy discovery for UI toolbars and menus
///
/// ## Usage
///
/// Call this function during app initialization, before creating the ToolManager:
///
/// ```dart
/// void main() {
///   // Register tools first
///   registerBuiltInTools();
///
///   // Then create ToolManager with registered definitions
///   final toolManager = ToolManager(...);
///   // ...
/// }
/// ```
///
/// ## Registered Tools
///
/// - **Pen Tool** (ID: 'pen', Shortcut: 'P')
///   - Category: Drawing
///   - Creates vector paths with Bezier curves
///   - Supports anchor placement, handle adjustment, path closing
///
/// - **Selection Tool** (ID: 'selection', Shortcut: 'V')
///   - Category: Selection
///   - Selects and moves vector objects
///   - Supports marquee selection, modifier-based selection modes
///
/// - **Direct Selection Tool** (ID: 'direct_selection', Shortcut: 'A')
///   - Category: Selection
///   - Direct manipulation of anchor points and Bezier handles
///   - Supports grid snapping, angle snapping, inertia
///
/// Related: T018 (Tool Framework), Section 2 (Tool System Architecture)
void registerBuiltInTools() {
  final registry = ToolRegistry.instance;

  // Register Pen Tool (FR-001 to FR-007, FR-025)
  registry.registerDefinition(
    ToolDefinition(
      toolId: 'pen',
      name: 'Pen Tool',
      description: 'Create vector paths with bezier curves',
      category: ToolCategory.drawing,
      shortcut: 'P',
      icon: 'pen',
      factory: () {
        // Note: Factory returns a function that accepts dependencies
        // Actual instantiation happens in ToolManager or app shell
        throw UnimplementedError(
          'Pen tool factory requires Document, ViewportController, and EventRecorder. '
          'Use createPenTool() factory function instead.',
        );
      },
    ),
  );

  // Register Selection Tool (FR-008 to FR-015)
  registry.registerDefinition(
    ToolDefinition(
      toolId: 'selection',
      name: 'Selection Tool',
      description: 'Select and move vector objects',
      category: ToolCategory.selection,
      shortcut: 'V',
      icon: 'selection',
      factory: () {
        throw UnimplementedError(
          'Selection tool factory requires Document, ViewportController, and EventRecorder. '
          'Use createSelectionTool() factory function instead.',
        );
      },
    ),
  );

  // Register Direct Selection Tool (FR-016 to FR-024)
  registry.registerDefinition(
    ToolDefinition(
      toolId: 'direct_selection',
      name: 'Direct Selection Tool',
      description: 'Adjust anchor points and bezier handles',
      category: ToolCategory.selection,
      shortcut: 'A',
      icon: 'direct_selection',
      factory: () {
        throw UnimplementedError(
          'Direct selection tool factory requires Document, ViewportController, '
          'EventRecorder, PathRenderer, OperationGroupingService, and TelemetryService. '
          'Use createDirectSelectionTool() factory function instead.',
        );
      },
    ),
  );
}

/// Factory function for creating a PenTool instance with required dependencies.
///
/// This function encapsulates the construction logic for PenTool, ensuring
/// all required dependencies are provided.
///
/// Example:
/// ```dart
/// final penTool = createPenTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
/// toolManager.registerTool(penTool);
/// ```
PenTool createPenTool({
  required Document document,
  required ViewportController viewportController,
  required EventRecorder eventRecorder,
}) {
  return PenTool(
    document: document,
    viewportController: viewportController,
    eventRecorder: eventRecorder,
  );
}

/// Factory function for creating a SelectionTool instance with required dependencies.
///
/// Example:
/// ```dart
/// final selectionTool = createSelectionTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
/// );
/// toolManager.registerTool(selectionTool);
/// ```
SelectionTool createSelectionTool({
  required Document document,
  required ViewportController viewportController,
  required EventRecorder eventRecorder,
}) {
  return SelectionTool(
    document: document,
    viewportController: viewportController,
    eventRecorder: eventRecorder,
  );
}

/// Factory function for creating a DirectSelectionTool instance with required dependencies.
///
/// Example:
/// ```dart
/// final directSelectionTool = createDirectSelectionTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
///   pathRenderer: pathRenderer,
///   operationGroupingService: operationGroupingService,
///   telemetryService: telemetryService,
/// );
/// toolManager.registerTool(directSelectionTool);
/// ```
DirectSelectionTool createDirectSelectionTool({
  required Document document,
  required ViewportController viewportController,
  required EventRecorder eventRecorder,
  required PathRenderer pathRenderer,
  OperationGroupingService? operationGroupingService,
  TelemetryService? telemetryService,
}) {
  return DirectSelectionTool(
    document: document,
    viewportController: viewportController,
    eventRecorder: eventRecorder,
    pathRenderer: pathRenderer,
    operationGroupingService: operationGroupingService,
    telemetryService: telemetryService,
  );
}
