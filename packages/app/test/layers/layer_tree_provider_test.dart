import 'package:flutter_test/flutter_test.dart';
import 'package:app/modules/layers/state/layer_tree_provider.dart';

void main() {
  group('LayerTreeProvider', () {
    late LayerTreeProvider provider;
    List<Map<String, dynamic>> dispatchedCommands = [];

    setUp(() {
      dispatchedCommands = [];
      provider = LayerTreeProvider(
        commandDispatcher: (cmd, data) {
          dispatchedCommands.add({'command': cmd, 'data': data});
        },
      );
    });

    tearDown(() {
      provider.dispose();
    });

    group('Layer Management', () {
      test('loadLayers populates tree', () {
        final layers = [
          const LayerNode(
            layerId: 'layer1',
            name: 'Background',
            type: 'Rectangle',
          ),
          const LayerNode(
            layerId: 'layer2',
            name: 'Logo',
            type: 'Path',
          ),
        ];

        provider.loadLayers(layers);

        expect(provider.rootLayers.length, 2);
        expect(provider.totalLayerCount, 2);
        expect(provider.flattenedLayers.length, 2);
      });

      test('addLayer adds to root when no parentId', () {
        final layer = const LayerNode(
          layerId: 'layer1',
          name: 'New Layer',
          type: 'Rectangle',
        );

        provider.addLayer(layer);

        expect(provider.rootLayers.length, 1);
        expect(provider.totalLayerCount, 1);
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'addLayer');
      });

      test('removeLayer removes from tree', () {
        final layers = [
          const LayerNode(layerId: 'layer1', name: 'Layer 1', type: 'Rectangle'),
          const LayerNode(layerId: 'layer2', name: 'Layer 2', type: 'Rectangle'),
        ];
        provider.loadLayers(layers);

        provider.removeLayer('layer1');

        expect(provider.rootLayers.length, 1);
        expect(provider.rootLayers[0].layerId, 'layer2');
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'removeLayer');
      });

      test('renameLayer updates layer name', () {
        final layers = [
          const LayerNode(layerId: 'layer1', name: 'Old Name', type: 'Rectangle'),
        ];
        provider.loadLayers(layers);

        provider.renameLayer('layer1', 'New Name');

        expect(provider.rootLayers[0].name, 'New Name');
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'renameLayer');
        expect(dispatchedCommands[0]['data']['name'], 'New Name');
      });
    });

    group('Visibility & Lock Toggles', () {
      setUp(() {
        final layers = [
          const LayerNode(
            layerId: 'layer1',
            name: 'Layer 1',
            type: 'Rectangle',
            isVisible: true,
            isLocked: false,
          ),
        ];
        provider.loadLayers(layers);
      });

      test('toggleVisibility changes visibility state', () {
        provider.toggleVisibility('layer1');

        expect(provider.rootLayers[0].isVisible, false);
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'toggleLayerVisibility');
        expect(dispatchedCommands[0]['data']['isVisible'], false);

        provider.toggleVisibility('layer1');

        expect(provider.rootLayers[0].isVisible, true);
        expect(dispatchedCommands.length, 2);
        expect(dispatchedCommands[1]['data']['isVisible'], true);
      });

      test('toggleLock changes lock state', () {
        provider.toggleLock('layer1');

        expect(provider.rootLayers[0].isLocked, true);
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'toggleLayerLock');
        expect(dispatchedCommands[0]['data']['isLocked'], true);

        provider.toggleLock('layer1');

        expect(provider.rootLayers[0].isLocked, false);
        expect(dispatchedCommands.length, 2);
        expect(dispatchedCommands[1]['data']['isLocked'], false);
      });
    });

    group('Selection Management', () {
      setUp(() {
        final layers = [
          const LayerNode(layerId: 'layer1', name: 'Layer 1', type: 'Rectangle'),
          const LayerNode(layerId: 'layer2', name: 'Layer 2', type: 'Rectangle'),
          const LayerNode(layerId: 'layer3', name: 'Layer 3', type: 'Rectangle'),
        ];
        provider.loadLayers(layers);
      });

      test('selectLayer clears previous selection', () {
        provider.selectLayer('layer1');
        expect(provider.selectedLayerIds, {'layer1'});

        provider.selectLayer('layer2');
        expect(provider.selectedLayerIds, {'layer2'});
      });

      test('toggleLayerSelection adds/removes from selection', () {
        provider.toggleLayerSelection('layer1');
        expect(provider.selectedLayerIds, {'layer1'});

        provider.toggleLayerSelection('layer2');
        expect(provider.selectedLayerIds, {'layer1', 'layer2'});

        provider.toggleLayerSelection('layer1');
        expect(provider.selectedLayerIds, {'layer2'});
      });

      test('selectRange selects layers in range', () {
        provider.selectRange('layer1', 'layer3');

        expect(provider.selectedLayerIds, {'layer1', 'layer2', 'layer3'});
      });

      test('clearSelection removes all selections', () {
        provider.selectLayer('layer1');
        provider.clearSelection();

        expect(provider.selectedLayerIds, isEmpty);
        expect(provider.hasSelection, false);
      });
    });

    group('Tree Expansion', () {
      test('toggleExpansion toggles group expansion state', () {
        final layers = [
          LayerNode(
            layerId: 'group1',
            name: 'Group 1',
            type: 'Group',
            isExpanded: true,
            children: const [
              LayerNode(layerId: 'child1', name: 'Child 1', type: 'Rectangle', depth: 1),
            ],
          ),
        ];
        provider.loadLayers(layers);

        // Initially expanded - should show 2 layers (group + child)
        expect(provider.flattenedLayers.length, 2);

        provider.toggleExpansion('group1');

        // Now collapsed - should show 1 layer (group only)
        expect(provider.flattenedLayers.length, 1);
        expect(provider.rootLayers[0].isExpanded, false);

        provider.toggleExpansion('group1');

        // Expanded again - should show 2 layers
        expect(provider.flattenedLayers.length, 2);
        expect(provider.rootLayers[0].isExpanded, true);
      });
    });

    group('Virtualization', () {
      test('flattenedLayers handles 100+ layers efficiently', () {
        // Create 150 layers
        final layers = List.generate(
          150,
          (i) => LayerNode(
            layerId: 'layer$i',
            name: 'Layer $i',
            type: 'Rectangle',
          ),
        );
        provider.loadLayers(layers);

        expect(provider.totalLayerCount, 150);

        // Verify flattened list is correct (this will build the cache)
        final flattened = provider.flattenedLayers;
        expect(flattened.length, 150);
        expect(provider.visibleLayerCount, 150);
        expect(flattened[0].node.layerId, 'layer0');
        expect(flattened[149].node.layerId, 'layer149');
      });

      test('flattenedLayers respects expansion state for nested groups', () {
        final layers = [
          LayerNode(
            layerId: 'group1',
            name: 'Group 1',
            type: 'Group',
            isExpanded: true,
            children: [
              const LayerNode(
                layerId: 'child1',
                name: 'Child 1',
                type: 'Rectangle',
                depth: 1,
              ),
              LayerNode(
                layerId: 'group2',
                name: 'Nested Group',
                type: 'Group',
                depth: 1,
                isExpanded: false, // Collapsed
                children: const [
                  LayerNode(
                    layerId: 'child2',
                    name: 'Nested Child',
                    type: 'Rectangle',
                    depth: 2,
                  ),
                ],
              ),
            ],
          ),
        ];
        provider.loadLayers(layers);

        // Should show: group1, child1, group2 (but NOT child2 because group2 is collapsed)
        expect(provider.flattenedLayers.length, 3);
        expect(provider.flattenedLayers[0].node.layerId, 'group1');
        expect(provider.flattenedLayers[1].node.layerId, 'child1');
        expect(provider.flattenedLayers[2].node.layerId, 'group2');
      });
    });

    group('Filter Search', () {
      setUp(() {
        final layers = [
          const LayerNode(layerId: 'layer1', name: 'Background', type: 'Rectangle'),
          const LayerNode(layerId: 'layer2', name: 'Logo', type: 'Path'),
          const LayerNode(layerId: 'layer3', name: 'Text Layer', type: 'Text'),
        ];
        provider.loadLayers(layers);
      });

      test('setFilterText filters layers by name', () {
        provider.setFilterText('logo');

        expect(provider.flattenedLayers.length, 1);
        expect(provider.flattenedLayers[0].node.name, 'Logo');
      });

      test('setFilterText is case insensitive', () {
        provider.setFilterText('BACK');

        expect(provider.flattenedLayers.length, 1);
        expect(provider.flattenedLayers[0].node.name, 'Background');
      });

      test('setFilterText with empty string shows all layers', () {
        provider.setFilterText('logo');
        expect(provider.flattenedLayers.length, 1);

        provider.setFilterText('');
        expect(provider.flattenedLayers.length, 3);
      });
    });

    group('Layer Reordering', () {
      setUp(() {
        final layers = [
          const LayerNode(layerId: 'layer1', name: 'Layer 1', type: 'Rectangle'),
          const LayerNode(layerId: 'layer2', name: 'Layer 2', type: 'Rectangle'),
        ];
        provider.loadLayers(layers);
        provider.selectLayer('layer1');
      });

      test('moveLayerUp dispatches command', () {
        provider.moveLayerUp('layer1');

        expect(dispatchedCommands.length, 2); // 1 for select, 1 for move
        expect(dispatchedCommands[1]['command'], 'moveLayerUp');
        expect(dispatchedCommands[1]['data']['layerId'], 'layer1');
      });

      test('moveLayerDown dispatches command', () {
        provider.moveLayerDown('layer1');

        expect(dispatchedCommands.length, 2);
        expect(dispatchedCommands[1]['command'], 'moveLayerDown');
      });

      test('moveLayerToFront dispatches command', () {
        provider.moveLayerToFront('layer1');

        expect(dispatchedCommands.length, 2);
        expect(dispatchedCommands[1]['command'], 'moveLayerToFront');
      });

      test('moveLayerToBack dispatches command', () {
        provider.moveLayerToBack('layer1');

        expect(dispatchedCommands.length, 2);
        expect(dispatchedCommands[1]['command'], 'moveLayerToBack');
      });
    });
  });
}
