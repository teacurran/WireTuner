import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/application/tools/framework/tool_registry.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Minimal fake tool for testing registry.
class MinimalFakeTool implements ITool {
  MinimalFakeTool(this._toolId);

  final String _toolId;

  @override
  String get toolId => _toolId;

  @override
  MouseCursor get cursor => SystemMouseCursors.basic;

  @override
  void onActivate() {}

  @override
  void onDeactivate() {}

  @override
  bool onPointerDown(PointerDownEvent event) => false;

  @override
  bool onPointerMove(PointerMoveEvent event) => false;

  @override
  bool onPointerUp(PointerUpEvent event) => false;

  @override
  bool onKeyPress(KeyEvent event) => false;

  @override
  void renderOverlay(Canvas canvas, Size size) {}
}

void main() {
  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry.instance;
      registry.clear(); // Clear before each test
    });

    tearDown(() {
      registry.clear(); // Clean up after each test
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = ToolRegistry.instance;
        final instance2 = ToolRegistry.instance;

        expect(identical(instance1, instance2), isTrue);
        expect(instance1, equals(instance2));
      });

      test('should maintain state across instance calls', () {
        final instance1 = ToolRegistry.instance;
        final definition = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        instance1.registerDefinition(definition);

        final instance2 = ToolRegistry.instance;
        expect(instance2.definitions, contains(definition));
      });
    });

    group('Tool Definition Registration', () {
      test('should register tool definition successfully', () {
        final definition = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Create vector paths',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        registry.registerDefinition(definition);

        expect(registry.definitions, contains(definition));
        expect(registry.getDefinition('pen'), equals(definition));
      });

      test('should replace existing definition with same ID', () {
        final definition1 = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool V1',
          description: 'Old',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        final definition2 = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool V2',
          description: 'New',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        registry.registerDefinition(definition1);
        registry.registerDefinition(definition2);

        expect(registry.getDefinition('pen'), equals(definition2));
        expect(registry.getDefinition('pen')?.name, equals('Pen Tool V2'));
      });

      test('should unregister tool definition', () {
        final definition = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        registry.registerDefinition(definition);
        expect(registry.getDefinition('pen'), isNotNull);

        registry.unregisterDefinition('pen');
        expect(registry.getDefinition('pen'), isNull);
      });

      test('should handle unregistering non-existent definition gracefully', () {
        // Should not throw
        registry.unregisterDefinition('nonexistent');
      });

      test('should register multiple definitions', () {
        final pen = ToolDefinition(
          toolId: 'pen',
          name: 'Pen',
          description: 'Draw',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        final selection = ToolDefinition(
          toolId: 'selection',
          name: 'Selection',
          description: 'Select',
          category: ToolCategory.selection,
          factory: () => MinimalFakeTool('selection'),
        );

        registry.registerDefinition(pen);
        registry.registerDefinition(selection);

        expect(registry.definitions, hasLength(2));
        expect(registry.definitions, containsAll([pen, selection]));
      });
    });

    group('Tool Factory', () {
      test('should create tool instances from factory', () {
        final definition = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        final tool1 = definition.factory();
        final tool2 = definition.factory();

        expect(tool1, isA<ITool>());
        expect(tool2, isA<ITool>());
        expect(tool1.toolId, equals('pen'));
        expect(tool2.toolId, equals('pen'));

        // Each call creates a new instance
        expect(identical(tool1, tool2), isFalse);
      });
    });

    group('Category Filtering', () {
      setUp(() {
        registry.registerDefinition(
          ToolDefinition(
            toolId: 'pen',
            name: 'Pen',
            description: 'Draw',
            category: ToolCategory.drawing,
            factory: () => MinimalFakeTool('pen'),
          ),
        );

        registry.registerDefinition(
          ToolDefinition(
            toolId: 'selection',
            name: 'Selection',
            description: 'Select',
            category: ToolCategory.selection,
            factory: () => MinimalFakeTool('selection'),
          ),
        );

        registry.registerDefinition(
          ToolDefinition(
            toolId: 'rectangle',
            name: 'Rectangle',
            description: 'Draw rect',
            category: ToolCategory.shapes,
            factory: () => MinimalFakeTool('rectangle'),
          ),
        );
      });

      test('should filter definitions by category', () {
        final drawingTools = registry.getDefinitionsByCategory(ToolCategory.drawing);

        expect(drawingTools, hasLength(1));
        expect(drawingTools.first.toolId, equals('pen'));
      });

      test('should return empty list for category with no tools', () {
        final textTools = registry.getDefinitionsByCategory(ToolCategory.text);

        expect(textTools, isEmpty);
      });

      test('should return multiple tools in same category', () {
        registry.registerDefinition(
          ToolDefinition(
            toolId: 'ellipse',
            name: 'Ellipse',
            description: 'Draw ellipse',
            category: ToolCategory.shapes,
            factory: () => MinimalFakeTool('ellipse'),
          ),
        );

        final shapeTools = registry.getDefinitionsByCategory(ToolCategory.shapes);

        expect(shapeTools, hasLength(2));
        expect(
          shapeTools.map((d) => d.toolId),
          containsAll(['rectangle', 'ellipse']),
        );
      });
    });

    group('Shortcut Lookup', () {
      test('should find definition by shortcut (case insensitive)', () {
        final definition = ToolDefinition(
          toolId: 'pen',
          name: 'Pen Tool',
          description: 'Draw',
          category: ToolCategory.drawing,
          shortcut: 'P',
          factory: () => MinimalFakeTool('pen'),
        );

        registry.registerDefinition(definition);

        expect(registry.getDefinitionByShortcut('P'), equals(definition));
        expect(registry.getDefinitionByShortcut('p'), equals(definition));
      });

      test('should throw if no tool found for shortcut', () {
        expect(
          () => registry.getDefinitionByShortcut('X'),
          throwsStateError,
        );
      });

      test('should handle definitions without shortcuts', () {
        registry.registerDefinition(
          ToolDefinition(
            toolId: 'pen',
            name: 'Pen',
            description: 'Draw',
            category: ToolCategory.drawing,
            factory: () => MinimalFakeTool('pen'),
          ),
        );

        expect(
          () => registry.getDefinitionByShortcut('P'),
          throwsStateError,
        );
      });
    });

    group('ToolDefinition Equality', () {
      test('should be equal if toolId matches', () {
        final def1 = ToolDefinition(
          toolId: 'pen',
          name: 'Pen V1',
          description: 'Old',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        final def2 = ToolDefinition(
          toolId: 'pen',
          name: 'Pen V2',
          description: 'New',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        expect(def1, equals(def2));
        expect(def1.hashCode, equals(def2.hashCode));
      });

      test('should not be equal if toolId differs', () {
        final def1 = ToolDefinition(
          toolId: 'pen',
          name: 'Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('pen'),
        );

        final def2 = ToolDefinition(
          toolId: 'selection',
          name: 'Tool',
          description: 'Test',
          category: ToolCategory.drawing,
          factory: () => MinimalFakeTool('selection'),
        );

        expect(def1, isNot(equals(def2)));
      });
    });
  });
}
