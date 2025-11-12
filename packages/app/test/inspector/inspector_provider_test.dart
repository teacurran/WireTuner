import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/modules/inspector/state/inspector_provider.dart';

void main() {
  group('InspectorProvider', () {
    late InspectorProvider provider;
    List<Map<String, dynamic>> dispatchedCommands = [];

    setUp(() {
      dispatchedCommands = [];
      provider = InspectorProvider(
        commandDispatcher: (cmd, data) {
          dispatchedCommands.add({'command': cmd, 'data': data});
        },
      );
    });

    tearDown(() {
      provider.dispose();
    });

    group('Selection Management', () {
      test('hasSelection returns false when no selection', () {
        expect(provider.hasSelection, false);
        expect(provider.selectionCount, 0);
      });

      test('updateSelection with single object sets currentProperties', () {
        final props = ObjectProperties(
          objectId: 'obj1',
          objectType: 'Rectangle',
          x: 100,
          y: 200,
          width: 150,
          height: 100,
        );

        provider.updateSelection(['obj1'], [props]);

        expect(provider.hasSelection, true);
        expect(provider.selectionCount, 1);
        expect(provider.isMultiSelection, false);
        expect(provider.currentProperties, props);
        expect(provider.multiSelectionProperties, null);
      });

      test('updateSelection with multiple objects sets multiSelectionProperties', () {
        final props1 = ObjectProperties(
          objectId: 'obj1',
          objectType: 'Rectangle',
          x: 100,
          y: 200,
          width: 150,
          height: 100,
          fillColor: Colors.red,
        );

        final props2 = ObjectProperties(
          objectId: 'obj2',
          objectType: 'Rectangle',
          x: 200, // Different X
          y: 200, // Same Y
          width: 150, // Same width
          height: 100, // Same height
          fillColor: Colors.red, // Same fill
        );

        provider.updateSelection(['obj1', 'obj2'], [props1, props2]);

        expect(provider.hasSelection, true);
        expect(provider.selectionCount, 2);
        expect(provider.isMultiSelection, true);
        expect(provider.currentProperties, null);
        expect(provider.multiSelectionProperties, isNotNull);

        final multi = provider.multiSelectionProperties!;
        expect(multi.selectionCount, 2);
        expect(multi.x, null); // Different values
        expect(multi.y, 200.0); // Same value
        expect(multi.width, 150.0); // Same value
        expect(multi.height, 100.0); // Same value
        expect(multi.fillColor, Colors.red); // Same value
      });

      test('updateSelection with empty list clears selection', () {
        final props = ObjectProperties(objectId: 'obj1', objectType: 'Rectangle');
        provider.updateSelection(['obj1'], [props]);

        provider.updateSelection([], []);

        expect(provider.hasSelection, false);
        expect(provider.currentProperties, null);
        expect(provider.multiSelectionProperties, null);
      });
    });

    group('Property Updates', () {
      setUp(() {
        final props = ObjectProperties(
          objectId: 'obj1',
          objectType: 'Rectangle',
          x: 100,
          y: 200,
          width: 150,
          height: 100,
        );
        provider.updateSelection(['obj1'], [props]);
      });

      test('updateTransform stages changes without dispatching', () {
        provider.updateTransform(x: 250, y: 350);

        expect(provider.currentProperties!.x, 250);
        expect(provider.currentProperties!.y, 350);
        expect(provider.hasStagedChanges, true);
        expect(dispatchedCommands, isEmpty);
      });

      test('updateFill stages changes', () {
        provider.updateFill(color: Colors.blue, opacity: 0.8);

        expect(provider.currentProperties!.fillColor, Colors.blue);
        expect(provider.currentProperties!.fillOpacity, 0.8);
        expect(provider.hasStagedChanges, true);
      });

      test('updateStroke stages changes', () {
        provider.updateStroke(
          color: Colors.black,
          width: 2.0,
          cap: StrokeCap.round,
          join: StrokeJoin.bevel,
        );

        expect(provider.currentProperties!.strokeColor, Colors.black);
        expect(provider.currentProperties!.strokeWidth, 2.0);
        expect(provider.currentProperties!.strokeCap, StrokeCap.round);
        expect(provider.currentProperties!.strokeJoin, StrokeJoin.bevel);
        expect(provider.hasStagedChanges, true);
      });

      test('updateBlend stages changes', () {
        provider.updateBlend(mode: BlendMode.multiply, opacity: 0.5);

        expect(provider.currentProperties!.blendMode, BlendMode.multiply);
        expect(provider.currentProperties!.opacity, 0.5);
        expect(provider.hasStagedChanges, true);
      });

      test('applyChanges dispatches command and clears staged changes', () {
        provider.updateTransform(x: 250, y: 350);
        provider.applyChanges();

        expect(provider.hasStagedChanges, false);
        expect(dispatchedCommands.length, 1);
        expect(dispatchedCommands[0]['command'], 'updateObjectProperties');
        expect(dispatchedCommands[0]['data']['objectId'], 'obj1');
      });

      test('resetChanges clears staged changes without dispatching', () {
        provider.updateTransform(x: 250, y: 350);
        provider.resetChanges();

        expect(provider.hasStagedChanges, false);
        expect(dispatchedCommands, isEmpty);
      });
    });

    group('Multi-Selection Properties', () {
      test('computes mixed values correctly', () {
        final props1 = ObjectProperties(
          objectId: 'obj1',
          objectType: 'Rectangle',
          x: 100,
          y: 200,
          width: 150,
          height: 100,
          fillColor: Colors.red,
          strokeWidth: 1.0,
        );

        final props2 = ObjectProperties(
          objectId: 'obj2',
          objectType: 'Circle',
          x: 200, // Different
          y: 200, // Same
          width: 100, // Different
          height: 100, // Same
          fillColor: Colors.blue, // Different
          strokeWidth: 1.0, // Same
        );

        final props3 = ObjectProperties(
          objectId: 'obj3',
          objectType: 'Rectangle',
          x: 150, // Different
          y: 200, // Same
          width: 200, // Different
          height: 100, // Same
          fillColor: Colors.green, // Different
          strokeWidth: 1.0, // Same
        );

        provider.updateSelection(['obj1', 'obj2', 'obj3'], [props1, props2, props3]);

        final multi = provider.multiSelectionProperties!;
        expect(multi.selectionCount, 3);
        expect(multi.x, null); // Mixed
        expect(multi.y, 200.0); // Shared
        expect(multi.width, null); // Mixed
        expect(multi.height, 100.0); // Shared
        expect(multi.fillColor, null); // Mixed
        expect(multi.strokeWidth, 1.0); // Shared
      });
    });

    group('Edge Cases', () {
      test('updateTransform on empty selection does nothing', () {
        provider.updateTransform(x: 100);

        expect(provider.hasStagedChanges, false);
        expect(dispatchedCommands, isEmpty);
      });

      test('applyChanges with no staged changes does nothing', () {
        final props = ObjectProperties(objectId: 'obj1', objectType: 'Rectangle');
        provider.updateSelection(['obj1'], [props]);

        provider.applyChanges();

        expect(dispatchedCommands, isEmpty);
      });

      test('aspectRatioLocked toggle preserves aspect ratio', () {
        final props = ObjectProperties(
          objectId: 'obj1',
          objectType: 'Rectangle',
          width: 200,
          height: 100,
          aspectRatioLocked: false,
        );
        provider.updateSelection(['obj1'], [props]);

        provider.updateTransform(aspectRatioLocked: true);

        expect(provider.currentProperties!.aspectRatioLocked, true);
        expect(provider.currentProperties!.width, 200);
        expect(provider.currentProperties!.height, 100);
      });
    });
  });
}
