import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/framework/tool_registry.dart';
import 'package:wiretuner/application/tools/tool_registration.dart';

void main() {
  group('Tool Registration', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry.instance;
      registry.clear(); // Clear before each test
    });

    tearDown(() {
      registry.clear(); // Clean up after each test
    });

    test('registerBuiltInTools should register all three core tools', () {
      // Act
      registerBuiltInTools();

      // Assert
      expect(registry.definitions, hasLength(3));
      expect(registry.getDefinition('pen'), isNotNull);
      expect(registry.getDefinition('selection'), isNotNull);
      expect(registry.getDefinition('direct_selection'), isNotNull);
    });

    group('Pen Tool Definition', () {
      setUp(() {
        registerBuiltInTools();
      });

      test('should have correct metadata', () {
        final definition = registry.getDefinition('pen')!;

        expect(definition.toolId, equals('pen'));
        expect(definition.name, equals('Pen Tool'));
        expect(definition.description,
            equals('Create vector paths with bezier curves'));
        expect(definition.category, equals(ToolCategory.drawing));
        expect(definition.shortcut, equals('P'));
        expect(definition.icon, equals('pen'));
      });

      test('should be findable by shortcut', () {
        final definition = registry.getDefinitionByShortcut('P')!;

        expect(definition.toolId, equals('pen'));
      });

      test('should be in drawing category', () {
        final drawingTools =
            registry.getDefinitionsByCategory(ToolCategory.drawing);

        expect(drawingTools, hasLength(1));
        expect(drawingTools.first.toolId, equals('pen'));
      });
    });

    group('Selection Tool Definition', () {
      setUp(() {
        registerBuiltInTools();
      });

      test('should have correct metadata', () {
        final definition = registry.getDefinition('selection')!;

        expect(definition.toolId, equals('selection'));
        expect(definition.name, equals('Selection Tool'));
        expect(definition.description, equals('Select and move vector objects'));
        expect(definition.category, equals(ToolCategory.selection));
        expect(definition.shortcut, equals('V'));
        expect(definition.icon, equals('selection'));
      });

      test('should be findable by shortcut', () {
        final definition = registry.getDefinitionByShortcut('V')!;

        expect(definition.toolId, equals('selection'));
      });

      test('should be in selection category', () {
        final selectionTools =
            registry.getDefinitionsByCategory(ToolCategory.selection);

        expect(selectionTools, hasLength(2)); // selection + direct_selection
        expect(
          selectionTools.map((d) => d.toolId),
          containsAll(['selection', 'direct_selection']),
        );
      });
    });

    group('Direct Selection Tool Definition', () {
      setUp(() {
        registerBuiltInTools();
      });

      test('should have correct metadata', () {
        final definition = registry.getDefinition('direct_selection')!;

        expect(definition.toolId, equals('direct_selection'));
        expect(definition.name, equals('Direct Selection Tool'));
        expect(definition.description,
            equals('Adjust anchor points and bezier handles'));
        expect(definition.category, equals(ToolCategory.selection));
        expect(definition.shortcut, equals('A'));
        expect(definition.icon, equals('direct_selection'));
      });

      test('should be findable by shortcut', () {
        final definition = registry.getDefinitionByShortcut('A')!;

        expect(definition.toolId, equals('direct_selection'));
      });

      test('should be in selection category', () {
        final selectionTools =
            registry.getDefinitionsByCategory(ToolCategory.selection);

        expect(selectionTools, hasLength(2)); // selection + direct_selection
        expect(
          selectionTools.map((d) => d.toolId),
          contains('direct_selection'),
        );
      });
    });

    group('Unique Shortcuts', () {
      setUp(() {
        registerBuiltInTools();
      });

      test('each tool should have a unique shortcut', () {
        final penDef = registry.getDefinitionByShortcut('P')!;
        final selectionDef = registry.getDefinitionByShortcut('V')!;
        final directSelectionDef = registry.getDefinitionByShortcut('A')!;

        expect(penDef.toolId, equals('pen'));
        expect(selectionDef.toolId, equals('selection'));
        expect(directSelectionDef.toolId, equals('direct_selection'));
      });

      test('shortcuts should be case-insensitive', () {
        final penDefUpper = registry.getDefinitionByShortcut('P');
        final penDefLower = registry.getDefinitionByShortcut('p');

        expect(penDefUpper, equals(penDefLower));
      });
    });

    group('Category Distribution', () {
      setUp(() {
        registerBuiltInTools();
      });

      test('should have 1 drawing tool', () {
        final drawingTools =
            registry.getDefinitionsByCategory(ToolCategory.drawing);
        expect(drawingTools, hasLength(1));
      });

      test('should have 2 selection tools', () {
        final selectionTools =
            registry.getDefinitionsByCategory(ToolCategory.selection);
        expect(selectionTools, hasLength(2));
      });

      test('should have 0 shape tools', () {
        final shapeTools = registry.getDefinitionsByCategory(ToolCategory.shapes);
        expect(shapeTools, isEmpty);
      });
    });

    group('Registration Idempotency', () {
      test('calling registerBuiltInTools twice should not duplicate entries',
          () {
        registerBuiltInTools();
        registerBuiltInTools(); // Second call

        // Should still have exactly 3 tools (not 6)
        expect(registry.definitions, hasLength(3));
      });
    });
  });
}
