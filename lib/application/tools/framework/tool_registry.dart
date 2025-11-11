import 'package:logger/logger.dart';
import 'tool_interface.dart';

/// A registry that holds tool definitions and their associated metadata.
///
/// The [ToolRegistry] acts as a central repository for tool information,
/// separate from the [ToolManager] which handles runtime state. This separation
/// allows for:
/// - Static tool definitions that can be loaded at app startup
/// - Metadata about tools (shortcuts, categories, tooltips) without runtime overhead
/// - Easy tool discovery for UI toolbars and menus
///
/// ## Architecture
///
/// The registry follows a singleton pattern to ensure consistent tool definitions
/// across the application:
///
/// ```
/// ToolRegistry (singleton)
///       ↓ (provides definitions)
/// ToolManager (runtime state)
///       ↓ (instantiates tools)
/// Tool Instances (ITool)
/// ```
///
/// ## Usage
///
/// ```dart
/// // Register tools at app startup
/// final registry = ToolRegistry.instance;
/// registry.registerDefinition(
///   ToolDefinition(
///     toolId: 'pen',
///     name: 'Pen Tool',
///     description: 'Create vector paths with bezier curves',
///     category: ToolCategory.drawing,
///     shortcut: 'P',
///     factory: () => PenTool(),
///   ),
/// );
///
/// // Use in ToolManager initialization
/// final toolManager = ToolManager(...);
/// for (final def in registry.definitions) {
///   toolManager.registerTool(def.factory());
/// }
/// ```
///
/// Related: Section 2 (Tool System Architecture), T018 (Tool Framework)
class ToolRegistry {
  ToolRegistry._internal() {
    _logger.d('ToolRegistry singleton initialized');
  }

  /// Singleton instance.
  static final ToolRegistry _instance = ToolRegistry._internal();

  /// Returns the singleton instance of the tool registry.
  static ToolRegistry get instance => _instance;

  /// Map of tool definitions by toolId.
  final Map<String, ToolDefinition> _definitions = {};

  /// Logger for debugging.
  final Logger _logger = Logger();

  /// Returns an unmodifiable view of all registered tool definitions.
  Iterable<ToolDefinition> get definitions => _definitions.values;

  /// Returns a tool definition by ID, or null if not found.
  ToolDefinition? getDefinition(String toolId) => _definitions[toolId];

  /// Registers a tool definition.
  ///
  /// If a definition with the same toolId already exists, it will be replaced.
  ///
  /// Example:
  /// ```dart
  /// registry.registerDefinition(
  ///   ToolDefinition(
  ///     toolId: 'pen',
  ///     name: 'Pen Tool',
  ///     description: 'Create vector paths',
  ///     category: ToolCategory.drawing,
  ///     shortcut: 'P',
  ///     factory: () => PenTool(),
  ///   ),
  /// );
  /// ```
  void registerDefinition(ToolDefinition definition) {
    if (_definitions.containsKey(definition.toolId)) {
      _logger.w(
        'Tool definition "${definition.toolId}" already registered, replacing',
      );
    }

    _definitions[definition.toolId] = definition;
    _logger.i('Tool definition registered: ${definition.toolId}');
  }

  /// Unregisters a tool definition.
  void unregisterDefinition(String toolId) {
    if (_definitions.remove(toolId) != null) {
      _logger.i('Tool definition unregistered: $toolId');
    } else {
      _logger.w('Cannot unregister tool definition "$toolId": not found');
    }
  }

  /// Returns all definitions in a specific category.
  Iterable<ToolDefinition> getDefinitionsByCategory(ToolCategory category) {
    return _definitions.values.where((def) => def.category == category);
  }

  /// Returns a definition by keyboard shortcut, or null if not found.
  ToolDefinition? getDefinitionByShortcut(String shortcut) {
    return _definitions.values.firstWhere(
      (def) => def.shortcut?.toUpperCase() == shortcut.toUpperCase(),
      orElse: () => throw StateError('No tool found for shortcut: $shortcut'),
    );
  }

  /// Clears all registered definitions.
  ///
  /// **Warning**: This is primarily for testing. Do not call in production.
  void clear() {
    _definitions.clear();
    _logger.w('All tool definitions cleared');
  }
}

/// Categories for organizing tools in the UI.
enum ToolCategory {
  /// Selection and manipulation tools (selection, direct selection).
  selection,

  /// Drawing tools (pen, pencil).
  drawing,

  /// Shape tools (rectangle, ellipse, polygon, star).
  shapes,

  /// Text tools.
  text,

  /// Transform tools (rotate, scale, shear).
  transform,

  /// View tools (zoom, pan, hand).
  view,
}

/// Metadata and factory for a tool.
///
/// A [ToolDefinition] contains all static information about a tool without
/// instantiating it. This allows for lazy instantiation and easy UI generation.
class ToolDefinition {
  /// Creates a tool definition.
  const ToolDefinition({
    required this.toolId,
    required this.name,
    required this.description,
    required this.category,
    required this.factory,
    this.shortcut,
    this.icon,
  });

  /// Unique identifier for the tool (e.g., 'pen', 'selection').
  final String toolId;

  /// Human-readable name (e.g., 'Pen Tool').
  final String name;

  /// Brief description for tooltips.
  final String description;

  /// Category for UI grouping.
  final ToolCategory category;

  /// Optional keyboard shortcut (e.g., 'P', 'V', 'A').
  ///
  /// **Note**: Shortcuts should be single characters for simplicity.
  /// Modifier keys (Shift, Ctrl, Alt) are handled by the ToolManager.
  final String? shortcut;

  /// Optional icon name or icon data.
  ///
  /// This can be used by the UI to display tool icons in toolbars.
  final String? icon;

  /// Factory function to create an instance of the tool.
  ///
  /// This is called by the ToolManager when the tool needs to be instantiated.
  final ITool Function() factory;

  @override
  String toString() => 'ToolDefinition($toolId: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolDefinition &&
          runtimeType == other.runtimeType &&
          toolId == other.toolId;

  @override
  int get hashCode => toolId.hashCode;
}
