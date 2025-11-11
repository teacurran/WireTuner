import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('ViewportController', () {
    late ViewportController controller;

    setUp(() {
      controller = ViewportController();
    });

    group('Basic Transformations', () {
      test('initializes with default values', () {
        expect(controller.zoomLevel, equals(1.0));
        expect(controller.panOffset, equals(Offset.zero));
      });

      test('initializes with custom values', () {
        final custom = ViewportController(
          initialPan: const Offset(100, 50),
          initialZoom: 2.0,
        );
        expect(custom.zoomLevel, equals(2.0));
        expect(custom.panOffset, equals(const Offset(100, 50)));
      });

      test('clamps initial zoom to valid range', () {
        final tooLow = ViewportController(initialZoom: 0.01);
        expect(tooLow.zoomLevel, equals(ViewportController.minZoom));

        final tooHigh = ViewportController(initialZoom: 100.0);
        expect(tooHigh.zoomLevel, equals(ViewportController.maxZoom));
      });

      test('pan updates offset and notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.pan(const Offset(50, 30));

        expect(controller.panOffset, equals(const Offset(50, 30)));
        expect(notified, isTrue);
      });

      test('setPan sets absolute offset', () {
        controller.pan(const Offset(100, 100));
        controller.setPan(const Offset(50, 30));

        expect(controller.panOffset, equals(const Offset(50, 30)));
      });

      test('setZoom updates zoom level', () {
        controller.setZoom(2.0);
        expect(controller.zoomLevel, equals(2.0));
      });

      test('setZoom clamps to valid range', () {
        controller.setZoom(0.01);
        expect(controller.zoomLevel, equals(ViewportController.minZoom));

        controller.setZoom(100.0);
        expect(controller.zoomLevel, equals(ViewportController.maxZoom));
      });

      test('reset returns to default state', () {
        controller.pan(const Offset(100, 100));
        controller.setZoom(2.0);

        controller.reset();

        expect(controller.zoomLevel, equals(1.0));
        expect(controller.panOffset, equals(Offset.zero));
      });
    });

    group('Coordinate Conversions', () {
      test('worldToScreen converts correctly at zoom 1.0', () {
        final worldPoint = event_base.Point(x: 100, y: 50);
        final screenOffset = controller.worldToScreen(worldPoint);

        expect(screenOffset.dx, equals(100.0));
        expect(screenOffset.dy, equals(50.0));
      });

      test('worldToScreen converts correctly with zoom', () {
        controller.setZoom(2.0);
        final worldPoint = event_base.Point(x: 100, y: 50);
        final screenOffset = controller.worldToScreen(worldPoint);

        expect(screenOffset.dx, equals(200.0));
        expect(screenOffset.dy, equals(100.0));
      });

      test('worldToScreen converts correctly with pan', () {
        controller.setPan(const Offset(50, 30));
        final worldPoint = event_base.Point(x: 100, y: 50);
        final screenOffset = controller.worldToScreen(worldPoint);

        expect(screenOffset.dx, equals(150.0));
        expect(screenOffset.dy, equals(80.0));
      });

      test('worldToScreen converts correctly with zoom and pan', () {
        controller.setZoom(2.0);
        controller.setPan(const Offset(50, 30));
        final worldPoint = event_base.Point(x: 100, y: 50);
        final screenOffset = controller.worldToScreen(worldPoint);

        expect(screenOffset.dx, equals(250.0));
        expect(screenOffset.dy, equals(130.0));
      });

      test('screenToWorld converts correctly at zoom 1.0', () {
        final screenOffset = const Offset(100, 50);
        final worldPoint = controller.screenToWorld(screenOffset);

        expect(worldPoint.x, equals(100.0));
        expect(worldPoint.y, equals(50.0));
      });

      test('screenToWorld is inverse of worldToScreen', () {
        controller.setZoom(1.5);
        controller.setPan(const Offset(75, 45));

        final originalWorld = event_base.Point(x: 200, y: 150);
        final screen = controller.worldToScreen(originalWorld);
        final backToWorld = controller.screenToWorld(screen);

        expect(backToWorld.x, closeTo(originalWorld.x, 0.001));
        expect(backToWorld.y, closeTo(originalWorld.y, 0.001));
      });

      test('screenDistanceToWorld converts distance correctly', () {
        controller.setZoom(2.0);
        final worldDistance = controller.screenDistanceToWorld(100);

        expect(worldDistance, equals(50.0));
      });

      test('worldDistanceToScreen converts distance correctly', () {
        controller.setZoom(2.0);
        final screenDistance = controller.worldDistanceToScreen(50);

        expect(screenDistance, equals(100.0));
      });
    });

    group('Per-Artboard State', () {
      test('saveArtboardState stores current state', () {
        controller.setZoom(2.0);
        controller.setPan(const Offset(100, 50));

        controller.saveArtboardState('artboard-1');

        // Change state
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        // Should be able to restore
        final restored = controller.restoreArtboardState('artboard-1');
        expect(restored, isTrue);
        expect(controller.zoomLevel, equals(2.0));
        expect(controller.panOffset, equals(const Offset(100, 50)));
      });

      test('restoreArtboardState returns false for unknown artboard', () {
        final restored = controller.restoreArtboardState('unknown');
        expect(restored, isFalse);

        // Should reset to defaults
        expect(controller.zoomLevel, equals(1.0));
        expect(controller.panOffset, equals(Offset.zero));
      });

      test('saveArtboardState overwrites previous state', () {
        controller.setZoom(1.5);
        controller.saveArtboardState('artboard-1');

        controller.setZoom(2.5);
        controller.saveArtboardState('artboard-1');

        controller.restoreArtboardState('artboard-1');
        expect(controller.zoomLevel, equals(2.5));
      });

      test('clearArtboardState removes saved state', () {
        controller.setZoom(2.0);
        controller.saveArtboardState('artboard-1');

        controller.clearArtboardState('artboard-1');

        final restored = controller.restoreArtboardState('artboard-1');
        expect(restored, isFalse);
      });

      test('clearAllArtboardStates removes all saved states', () {
        controller.saveArtboardState('artboard-1');
        controller.saveArtboardState('artboard-2');
        controller.saveArtboardState('artboard-3');

        controller.clearAllArtboardStates();

        expect(controller.restoreArtboardState('artboard-1'), isFalse);
        expect(controller.restoreArtboardState('artboard-2'), isFalse);
        expect(controller.restoreArtboardState('artboard-3'), isFalse);
      });

      test('multiple artboards maintain separate states', () {
        // Setup artboard 1
        controller.setZoom(1.5);
        controller.setPan(const Offset(100, 100));
        controller.saveArtboardState('artboard-1');

        // Setup artboard 2
        controller.setZoom(2.5);
        controller.setPan(const Offset(200, 200));
        controller.saveArtboardState('artboard-2');

        // Restore artboard 1
        controller.restoreArtboardState('artboard-1');
        expect(controller.zoomLevel, equals(1.5));
        expect(controller.panOffset, equals(const Offset(100, 100)));

        // Restore artboard 2
        controller.restoreArtboardState('artboard-2');
        expect(controller.zoomLevel, equals(2.5));
        expect(controller.panOffset, equals(const Offset(200, 200)));
      });
    });

    group('Fit to Screen', () {
      test('fitToScreen calculates correct zoom for width-constrained content', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 1000, 100);
        final canvasSize = const Size(500, 500);

        controller.fitToScreen(contentBounds, canvasSize, padding: 0);

        // Available width: 500, content width: 1000
        // Expected zoom: 500 / 1000 = 0.5
        expect(controller.zoomLevel, equals(0.5));
      });

      test('fitToScreen calculates correct zoom for height-constrained content', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 100, 1000);
        final canvasSize = const Size(500, 500);

        controller.fitToScreen(contentBounds, canvasSize, padding: 0);

        // Available height: 500, content height: 1000
        // Expected zoom: 500 / 1000 = 0.5
        expect(controller.zoomLevel, equals(0.5));
      });

      test('fitToScreen respects padding', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 1000, 1000);
        final canvasSize = const Size(1000, 1000);

        controller.fitToScreen(contentBounds, canvasSize, padding: 100);

        // Available: 1000 - 200 = 800, content: 1000
        // Expected zoom: 800 / 1000 = 0.8
        expect(controller.zoomLevel, equals(0.8));
      });

      test('fitToScreen centers content', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 100, 100);
        final canvasSize = const Size(500, 500);

        controller.fitToScreen(contentBounds, canvasSize, padding: 0);

        // Content should be centered
        // Zoom will be 500/100 = 5.0
        // Content center: (50, 50) world
        // Canvas center: (250, 250) screen
        // Pan should be: canvasCenter - contentCenter * zoom
        // Pan = (250, 250) - (50, 50) * 5 = (0, 0)
        expect(controller.panOffset.dx, closeTo(0, 0.1));
        expect(controller.panOffset.dy, closeTo(0, 0.1));
      });

      test('fitToScreen centers offset content', () {
        final contentBounds = const Rect.fromLTWH(100, 100, 100, 100);
        final canvasSize = const Size(500, 500);

        controller.fitToScreen(contentBounds, canvasSize, padding: 0);

        // Content center: (150, 150) world
        // Zoom: 5.0
        // Canvas center: (250, 250) screen
        // Pan = (250, 250) - (150, 150) * 5 = (-500, -500)
        expect(controller.panOffset.dx, closeTo(-500, 0.1));
        expect(controller.panOffset.dy, closeTo(-500, 0.1));
      });

      test('fitToScreen clamps zoom to min', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 100000, 100000);
        final canvasSize = const Size(100, 100);

        controller.fitToScreen(contentBounds, canvasSize);

        expect(controller.zoomLevel, equals(ViewportController.minZoom));
      });

      test('fitToScreen clamps zoom to max', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 1, 1);
        final canvasSize = const Size(10000, 10000);

        controller.fitToScreen(contentBounds, canvasSize);

        expect(controller.zoomLevel, equals(ViewportController.maxZoom));
      });

      test('fitToScreen handles empty bounds', () {
        final contentBounds = const Rect.fromLTWH(0, 0, 0, 0);
        final canvasSize = const Size(500, 500);

        controller.fitToScreen(contentBounds, canvasSize);

        // Should center at origin with default zoom
        expect(controller.zoomLevel, equals(1.0));
        expect(controller.panOffset, equals(const Offset(250, 250)));
      });
    });

    group('Zoom with Focal Point', () {
      test('zoom maintains focal point position', () {
        controller.setZoom(1.0);
        controller.setPan(Offset.zero);

        // Focal point at (100, 100) screen
        final focalPoint = const Offset(100, 100);
        final worldFocal = controller.screenToWorld(focalPoint);

        // Zoom in by 2x
        controller.zoom(2.0, focalPoint: focalPoint);

        // World focal point should still map to screen focal point
        final newScreenFocal = controller.worldToScreen(worldFocal);
        expect(newScreenFocal.dx, closeTo(focalPoint.dx, 0.1));
        expect(newScreenFocal.dy, closeTo(focalPoint.dy, 0.1));
      });

      test('zoom respects min/max limits', () {
        controller.setZoom(ViewportController.minZoom);
        controller.zoom(0.5, focalPoint: Offset.zero);
        expect(controller.zoomLevel, equals(ViewportController.minZoom));

        controller.setZoom(ViewportController.maxZoom);
        controller.zoom(2.0, focalPoint: Offset.zero);
        expect(controller.zoomLevel, equals(ViewportController.maxZoom));
      });
    });
  });
}
