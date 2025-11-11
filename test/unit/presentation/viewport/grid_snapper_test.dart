import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/presentation/canvas/viewport/grid_snapper.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('GridSnapper', () {
    late GridSnapper snapper;
    late ViewportController controller;

    setUp(() {
      snapper = GridSnapper(
        config: const GridSnapConfig(
          enabled: true,
          gridSize: 10.0,
          snapThreshold: 5.0,
        ),
      );
      controller = ViewportController();
    });

    group('Configuration', () {
      test('initializes with default config', () {
        final defaultSnapper = GridSnapper();
        expect(defaultSnapper.config.enabled, isTrue);
        expect(defaultSnapper.config.gridSize, equals(10.0));
      });

      test('allows config updates', () {
        snapper.config = const GridSnapConfig(
          enabled: false,
          gridSize: 20.0,
        );

        expect(snapper.config.enabled, isFalse);
        expect(snapper.config.gridSize, equals(20.0));
      });

      test('copyWith creates modified config', () {
        final original = const GridSnapConfig(
          enabled: true,
          gridSize: 10.0,
          showGrid: true,
        );

        final modified = original.copyWith(gridSize: 20.0);

        expect(modified.enabled, isTrue);
        expect(modified.gridSize, equals(20.0));
        expect(modified.showGrid, isTrue);
      });
    });

    group('Screen-Space Snapping', () {
      test('snapPointToGrid returns original when disabled', () {
        snapper.config = const GridSnapConfig(enabled: false);

        final worldPoint = event_base.Point(x: 103.7, y: 207.3);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        expect(snapped.x, equals(worldPoint.x));
        expect(snapped.y, equals(worldPoint.y));
      });

      test('snapPointToGrid snaps to grid at zoom 1.0', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final worldPoint = event_base.Point(x: 103.7, y: 207.3);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // At zoom 1.0, world = screen
        // 103.7 -> 100, 207.3 -> 210 (grid size 10)
        expect(snapped.x, equals(100.0));
        expect(snapped.y, equals(210.0));
      });

      test('snapPointToGrid maintains screen-space consistency at zoom 2.0', () {
        controller.setZoom(2.0);
        controller.setPan(Offset.zero);

        // World point that maps to screen (103.7, 207.3)
        // At zoom 2.0: world = screen / 2
        final worldPoint = event_base.Point(x: 51.85, y: 103.65);

        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // Screen coords: (103.7, 207.3) -> snap to (100, 210)
        // World coords: (100, 210) / 2.0 = (50, 105)
        expect(snapped.x, closeTo(50.0, 0.1));
        expect(snapped.y, closeTo(105.0, 0.1));
      });

      test('snapPointToGrid maintains screen-space consistency at zoom 0.5', () {
        controller.setZoom(0.5);
        controller.setPan(Offset.zero);

        // World point that maps to screen (103.7, 207.3)
        // At zoom 0.5: world = screen / 0.5
        final worldPoint = event_base.Point(x: 207.4, y: 414.6);

        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // Screen coords: (103.7, 207.3) -> snap to (100, 210)
        // World coords: (100, 210) / 0.5 = (200, 420)
        expect(snapped.x, closeTo(200.0, 0.1));
        expect(snapped.y, closeTo(420.0, 0.1));
      });

      test('snapPointToGrid respects pan offset', () {
        controller.setZoom(1.0);
        controller.setPan(const Offset(50, 30));

        final worldPoint = event_base.Point(x: 53.7, y: 177.3);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // World 53.7 -> screen 103.7 (53.7 + 50) -> snap 100 -> world 50
        // World 177.3 -> screen 207.3 (177.3 + 30) -> snap 210 -> world 180
        expect(snapped.x, closeTo(50.0, 0.1));
        expect(snapped.y, closeTo(180.0, 0.1));
      });

      test('snapPointToGrid handles negative coordinates', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final worldPoint = event_base.Point(x: -103.7, y: -207.3);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        expect(snapped.x, equals(-100.0));
        expect(snapped.y, equals(-210.0));
      });

      test('snapPointToGrid with different grid sizes', () {
        snapper.config = const GridSnapConfig(gridSize: 25.0);
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final worldPoint = event_base.Point(x: 38.7, y: 63.2);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // 38.7 / 25 = 1.548 rounds to 2, so 2 * 25 = 50
        // 63.2 / 25 = 2.528 rounds to 3, so 3 * 25 = 75
        expect(snapped.x, equals(50.0));
        expect(snapped.y, equals(75.0));
      });
    });

    group('Distance Snapping', () {
      test('snapDistanceToGrid returns original when disabled', () {
        snapper.config = const GridSnapConfig(enabled: false);

        final worldDistance = 23.7;
        final snapped = snapper.snapDistanceToGrid(worldDistance, controller);

        expect(snapped, equals(worldDistance));
      });

      test('snapDistanceToGrid snaps distance at zoom 1.0', () {
        controller.setZoom(1.0);

        final worldDistance = 23.7;
        final snapped = snapper.snapDistanceToGrid(worldDistance, controller);

        // 23.7 -> 20 (grid size 10)
        expect(snapped, equals(20.0));
      });

      test('snapDistanceToGrid maintains screen-space consistency at zoom 2.0', () {
        controller.setZoom(2.0);

        // World distance that becomes 23.7 screen pixels
        final worldDistance = 11.85;
        final snapped = snapper.snapDistanceToGrid(worldDistance, controller);

        // Screen: 23.7 -> snap 20 -> world: 20 / 2 = 10
        expect(snapped, closeTo(10.0, 0.1));
      });

      test('snapDistanceToGrid handles zero and negative', () {
        controller.setZoom(1.0);

        expect(snapper.snapDistanceToGrid(0, controller), equals(0.0));
        expect(snapper.snapDistanceToGrid(-23.7, controller), equals(-20.0));
      });
    });

    group('Snap Detection', () {
      test('wouldSnap returns true within threshold', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        // 103 is 3px from grid line at 100
        final worldPoint = event_base.Point(x: 103, y: 100);
        expect(snapper.wouldSnap(worldPoint, controller), isTrue);
      });

      test('wouldSnap returns false beyond threshold', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        // Grid lines at 100, 110, 120, etc
        // Point at 116 is 6px from 120 and 6px from 110
        // Minimum distance is 6px which exceeds threshold of 5px
        // However, wouldSnap checks if EITHER dx or dy is within threshold
        // Let's use a point where both coordinates are beyond threshold
        final worldPoint = event_base.Point(x: 116, y: 116);

        // But the implementation snaps to nearest grid, so it will be within threshold
        // Let me check the actual implementation more carefully
        // The point will snap from (116, 116) to (120, 120), distance = 4 each
        // So it WILL be within threshold. We need a point far from any grid line
        // But with grid size 10, every point is at most 5 pixels from a grid line!
        // The test is flawed - with grid size 10 and threshold 5, every point snaps

        // Solution: use a different grid config with smaller threshold
        final customSnapper = GridSnapper(
          config: const GridSnapConfig(gridSize: 10.0, snapThreshold: 2.0),
        );

        // Point at (106, 104) is 4px from nearest grid in both dimensions
        // which is > 2px threshold, so it should not snap
        final testPoint = event_base.Point(x: 106, y: 104);
        expect(customSnapper.wouldSnap(testPoint, controller), isFalse);
      });

      test('wouldSnap returns false when disabled', () {
        snapper.config = const GridSnapConfig(enabled: false);

        final worldPoint = event_base.Point(x: 101, y: 100);
        expect(snapper.wouldSnap(worldPoint, controller), isFalse);
      });

      test('wouldSnap checks both X and Y', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        // X is on grid, Y is within threshold
        final point1 = event_base.Point(x: 100, y: 103);
        expect(snapper.wouldSnap(point1, controller), isTrue);

        // Both coordinates within threshold
        final point2 = event_base.Point(x: 103, y: 103);
        expect(snapper.wouldSnap(point2, controller), isTrue);
      });
    });

    group('Grid Line Generation', () {
      test('generateGridLines returns empty when disabled', () {
        snapper.config = const GridSnapConfig(showGrid: false);

        final grid = snapper.generateGridLines(
          const Size(100, 100),
          controller,
        );

        expect(grid.verticalLines, isEmpty);
        expect(grid.horizontalLines, isEmpty);
      });

      test('generateGridLines generates correct line positions', () {
        snapper.config = const GridSnapConfig(gridSize: 10.0, showGrid: true);
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final grid = snapper.generateGridLines(
          const Size(100, 100),
          controller,
        );

        // Should have lines at 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100
        expect(grid.verticalLines.length, equals(11));
        expect(grid.horizontalLines.length, equals(11));

        expect(grid.verticalLines.first, equals(0.0));
        expect(grid.verticalLines.last, equals(100.0));
        expect(grid.horizontalLines.first, equals(0.0));
        expect(grid.horizontalLines.last, equals(100.0));
      });

      test('generateGridLines with larger grid size', () {
        snapper.config = const GridSnapConfig(gridSize: 25.0, showGrid: true);

        final grid = snapper.generateGridLines(
          const Size(100, 100),
          controller,
        );

        // Should have lines at 0, 25, 50, 75, 100
        expect(grid.verticalLines.length, equals(5));
        expect(grid.horizontalLines.length, equals(5));

        expect(grid.verticalLines, equals([0.0, 25.0, 50.0, 75.0, 100.0]));
      });

      test('generateGridLines handles zero grid size', () {
        snapper.config = const GridSnapConfig(gridSize: 0.0, showGrid: true);

        final grid = snapper.generateGridLines(
          const Size(100, 100),
          controller,
        );

        expect(grid.verticalLines, isEmpty);
        expect(grid.horizontalLines, isEmpty);
      });
    });

    group('Grid Origin Offset', () {
      test('getGridOriginOffset at zero pan', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final originOffset = snapper.getGridOriginOffset(controller);

        expect(originOffset.dx, equals(0.0));
        expect(originOffset.dy, equals(0.0));
      });

      test('getGridOriginOffset with pan', () {
        controller.setZoom(1.0);
        controller.setPan(const Offset(15, 23));

        final originOffset = snapper.getGridOriginOffset(controller);

        // Origin at (15, 23) screen, modulo 10 = (5, 3)
        expect(originOffset.dx, equals(5.0));
        expect(originOffset.dy, equals(3.0));
      });
    });

    group('Edge Cases', () {
      test('handles very small grid sizes', () {
        snapper.config = const GridSnapConfig(gridSize: 0.1);
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final worldPoint = event_base.Point(x: 1.234, y: 5.678);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // 1.234 -> 1.2, 5.678 -> 5.7 (grid 0.1)
        expect(snapped.x, closeTo(1.2, 0.01));
        expect(snapped.y, closeTo(5.7, 0.01));
      });

      test('handles very large grid sizes', () {
        snapper.config = const GridSnapConfig(gridSize: 1000.0);
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        final worldPoint = event_base.Point(x: 1234, y: 5678);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // 1234 -> 1000, 5678 -> 6000 (grid 1000)
        expect(snapped.x, equals(1000.0));
        expect(snapped.y, equals(6000.0));
      });

      test('handles extreme zoom levels', () {
        snapper.config = const GridSnapConfig(gridSize: 10.0);
        controller.setZoom(ViewportController.maxZoom); // 8.0

        final worldPoint = event_base.Point(x: 12.5, y: 25.7);
        final snapped = snapper.snapPointToGrid(worldPoint, controller);

        // Screen: (12.5*8, 25.7*8) = (100, 205.6) -> snap (100, 210)
        // World: (100/8, 210/8) = (12.5, 26.25)
        expect(snapped.x, closeTo(12.5, 0.1));
        expect(snapped.y, closeTo(26.25, 0.1));
      });
    });
  });
}
