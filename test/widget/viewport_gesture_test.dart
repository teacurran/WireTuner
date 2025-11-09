import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart' as domain;
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/models/path.dart' as domain_path;
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:wiretuner/presentation/canvas/painter/document_painter.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_binding.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';

void main() {
  group('ViewportState', () {
    late ViewportController controller;
    late ViewportState state;
    domain.Viewport? capturedViewport;
    ViewportTelemetry? capturedTelemetry;

    setUp(() {
      controller = ViewportController();
      state = ViewportState(
        controller: controller,
        onViewportChanged: (viewport) => capturedViewport = viewport,
        onTelemetry: (telemetry) => capturedTelemetry = telemetry,
      );
    });

    tearDown(() {
      state.dispose();
      controller.dispose();
      capturedViewport = null;
      capturedTelemetry = null;
    });

    test('initializes with default canvas size', () {
      expect(state.canvasSize, const Size(800, 600));
      expect(state.isPanning, isFalse);
      expect(state.lastFps, 0.0);
    });

    test('updates canvas size and notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);

      state.updateCanvasSize(const Size(1920, 1080));

      expect(state.canvasSize, const Size(1920, 1080));
      expect(notified, isTrue);
    });

    test('converts to domain viewport correctly', () {
      // Set controller to known state
      controller.setPan(const Offset(100, 50));
      controller.setZoom(2.0);

      final viewport = state.toDomainViewport();

      // Verify zoom
      expect(viewport.zoom, 2.0);

      // Verify canvas size
      expect(viewport.canvasSize.width, 800);
      expect(viewport.canvasSize.height, 600);

      // Verify pan conversion from screen to world coordinates
      // Controller pan: (100, 50)
      // Domain pan = (canvasSize/2 - controllerPan) / zoom
      //            = ((400, 300) - (100, 50)) / 2.0
      //            = (300, 250) / 2.0
      //            = (150, 125)
      expect(viewport.pan.x, closeTo(150, 0.001));
      expect(viewport.pan.y, closeTo(125, 0.001));
    });

    test('syncs from domain viewport correctly', () {
      // Create domain viewport
      const domainViewport = domain.Viewport(
        pan: Point(x: 100, y: 50),
        zoom: 1.5,
        canvasSize: domain.Size(width: 1024, height: 768),
      );

      state.syncFromDomain(domainViewport);

      // Verify controller was updated
      expect(controller.zoomLevel, 1.5);

      // Verify canvas size
      expect(state.canvasSize.width, 1024);
      expect(state.canvasSize.height, 768);

      // Verify pan conversion from world to screen coordinates
      // Domain pan: (100, 50), zoom: 1.5, canvasSize: (1024, 768)
      // Controller pan = canvasSize/2 - domainPan * zoom
      //                = (512, 384) - (100, 50) * 1.5
      //                = (512, 384) - (150, 75)
      //                = (362, 309)
      expect(controller.panOffset.dx, closeTo(362, 0.001));
      expect(controller.panOffset.dy, closeTo(309, 0.001));
    });

    test('round-trip domain sync preserves state', () {
      // Set initial controller state
      controller.setPan(const Offset(200, 100));
      controller.setZoom(2.5);

      // Convert to domain and back
      final domain = state.toDomainViewport();
      state.syncFromDomain(domain);

      // Verify state is preserved (within floating point precision)
      expect(controller.panOffset.dx, closeTo(200, 0.01));
      expect(controller.panOffset.dy, closeTo(100, 0.01));
      expect(controller.zoomLevel, closeTo(2.5, 0.001));
    });

    test('handles pan gesture sequence', () {
      // Start pan
      state.onPanStart(
        DragStartDetails(
          globalPosition: const Offset(100, 100),
        ),
      );
      expect(state.isPanning, isTrue);

      // Update pan
      state.onPanUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(150, 120),
          delta: const Offset(50, 20),
        ),
      );

      // Verify controller was updated
      expect(controller.panOffset, const Offset(50, 20));

      // Verify telemetry was captured
      expect(capturedTelemetry, isNotNull);
      expect(capturedTelemetry!.eventType, 'pan');
      expect(capturedTelemetry!.panDelta, const Offset(50, 20));

      // End pan
      state.onPanEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(100, 50)),
        ),
      );
      expect(state.isPanning, isFalse);

      // Verify domain viewport was updated
      expect(capturedViewport, isNotNull);
    });

    test('accumulates pan deltas during gesture', () {
      state.onPanStart(DragStartDetails());

      // Multiple updates
      state.onPanUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(100, 100),
          delta: const Offset(10, 5),
        ),
      );
      state.onPanUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(110, 105),
          delta: const Offset(20, 15),
        ),
      );
      state.onPanUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(130, 120),
          delta: const Offset(5, 10),
        ),
      );

      // Total pan should be sum of deltas
      expect(controller.panOffset, const Offset(35, 30));

      state.onPanEnd(DragEndDetails());
    });

    test('handles scale gesture for zoom', () {
      // Start scale
      state.onScaleStart(
        ScaleStartDetails(focalPoint: const Offset(400, 300)),
      );

      // Update scale (zoom in by 1.5x)
      state.onScaleUpdate(
        ScaleUpdateDetails(
          focalPoint: const Offset(400, 300),
          scale: 1.5,
        ),
      );

      // Verify zoom was updated
      expect(controller.zoomLevel, 1.5);

      // Verify telemetry
      expect(capturedTelemetry, isNotNull);
      expect(capturedTelemetry!.eventType, 'zoom');
      expect(capturedTelemetry!.zoomFactor, 1.5);

      // End scale
      state.onScaleEnd(ScaleEndDetails());

      // Verify domain viewport was updated
      expect(capturedViewport, isNotNull);
    });

    test('ignores scale updates without scale change', () {
      state.onScaleStart(ScaleStartDetails());

      final initialZoom = controller.zoomLevel;

      // Update with scale = 1.0 (no zoom change)
      state.onScaleUpdate(
        ScaleUpdateDetails(
          focalPoint: const Offset(400, 300),
          scale: 1.0,
        ),
      );

      // Zoom should be unchanged
      expect(controller.zoomLevel, initialZoom);
    });

    test('handles scroll wheel zoom', () {
      // Simulate scroll wheel event (scroll up = zoom in)
      state.onPointerSignal(
        const PointerScrollEvent(
          scrollDelta: Offset(0, -10),
          position: Offset(400, 300),
        ),
      );

      // Should zoom in (factor = 1.1)
      expect(controller.zoomLevel, greaterThan(1.0));

      // Verify telemetry
      expect(capturedTelemetry, isNotNull);
      expect(capturedTelemetry!.eventType, 'scroll_zoom');

      // Verify domain viewport was updated
      expect(capturedViewport, isNotNull);
    });

    test('scroll down zooms out', () {
      // Start at zoom 2.0
      controller.setZoom(2.0);

      // Simulate scroll wheel event (scroll down = zoom out)
      state.onPointerSignal(
        const PointerScrollEvent(
          scrollDelta: Offset(0, 10),
          position: Offset(400, 300),
        ),
      );

      // Should zoom out (factor = 0.9)
      expect(controller.zoomLevel, lessThan(2.0));
    });

    test('reset returns to default state', () {
      // Modify state
      controller.setPan(const Offset(100, 200));
      controller.setZoom(2.0);

      // Reset
      state.reset();

      // Verify reset to defaults
      expect(controller.panOffset, Offset.zero);
      expect(controller.zoomLevel, 1.0);

      // Verify domain viewport was updated
      expect(capturedViewport, isNotNull);
    });

    test('notifies listeners on controller changes', () {
      var notified = false;
      state.addListener(() => notified = true);

      // Change controller directly
      controller.pan(const Offset(10, 10));

      // State should notify its listeners
      expect(notified, isTrue);
    });

    test('disposes cleanly', () {
      // Create a new isolated state just for this test
      final testController = ViewportController();
      final testState = ViewportState(controller: testController);

      // Dispose should not throw
      testState.dispose();
      testController.dispose();

      // Second dispose should also not throw (idempotent)
      // Note: ChangeNotifier.dispose() will throw in debug mode if called twice
      // so we don't test that here.
    });
  });

  group('ViewportBinding', () {
    late ViewportController controller;

    setUp(() {
      controller = ViewportController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('builds with child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              child: const SizedBox(
                width: 800,
                height: 600,
                child: Text('Canvas'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Canvas'), findsOneWidget);
    });

    testWidgets('handles pan gestures', (WidgetTester tester) async {
      domain.Viewport? capturedViewport;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) => capturedViewport = viewport,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Initial state
      expect(controller.panOffset, Offset.zero);

      // Simulate drag gesture
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();

      await gesture.moveBy(const Offset(50, 30));
      await tester.pump();

      // Verify pan was applied
      expect(controller.panOffset, const Offset(50, 30));

      await gesture.up();
      await tester.pump();

      // Verify viewport change was notified
      expect(capturedViewport, isNotNull);
    });

    testWidgets('handles multiple pan updates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Simulate continuous drag
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();

      // Multiple small movements
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(5, 3));
        await tester.pump();
      }

      // Total pan should be sum of all movements
      expect(controller.panOffset, const Offset(50, 30));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('renders debug overlay in debug mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              debugMode: true,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Should show FPS counter
      expect(find.textContaining('FPS:'), findsOneWidget);
      expect(find.textContaining('Zoom:'), findsOneWidget);
      expect(find.textContaining('Pan:'), findsOneWidget);
    });

    testWidgets('hides debug overlay when debug mode disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              debugMode: false,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Should not show FPS counter
      expect(find.textContaining('FPS:'), findsNothing);
    });

    testWidgets('updates debug overlay during pan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              debugMode: true,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Start pan
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();

      // Should show panning indicator
      await gesture.moveBy(const Offset(50, 30));
      await tester.pump();

      expect(find.text('PANNING'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      // Panning indicator should disappear
      expect(find.text('PANNING'), findsNothing);
    });

    testWidgets('provides ViewportState via context',
        (WidgetTester tester) async {
      ViewportState? foundState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              child: Builder(
                builder: (context) {
                  foundState = ViewportBinding.maybeOf(context);
                  return const Placeholder();
                },
              ),
            ),
          ),
        ),
      );

      expect(foundState, isNotNull);
    });

    testWidgets('emits telemetry during gestures', (WidgetTester tester) async {
      ViewportTelemetry? capturedTelemetry;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onTelemetry: (telemetry) => capturedTelemetry = telemetry,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Perform pan gesture
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(50, 30));
      await tester.pump();

      // Verify telemetry was captured
      expect(capturedTelemetry, isNotNull);
      expect(capturedTelemetry!.eventType, 'pan');
      expect(capturedTelemetry!.panDelta, const Offset(50, 30));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('integrates with DocumentPainter', (WidgetTester tester) async {
      final paths = [
        domain_path.Path.line(
          start: const Point(x: 0, y: 0),
          end: const Point(x: 100, y: 100),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              child: CustomPaint(
                painter: DocumentPainter(
                  paths: paths,
                  viewportController: controller,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify initial render
      expect(tester.takeException(), isNull);

      // Pan and verify repaint
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(50, 30));
      await tester.pump();

      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pump();
    });
  });

  group('Coordinate Transformations', () {
    late ViewportController controller;
    late ViewportState state;

    setUp(() {
      controller = ViewportController();
      state = ViewportState(
        controller: controller,
        canvasSize: const Size(800, 600),
      );
    });

    tearDown(() {
      state.dispose();
      controller.dispose();
    });

    test('world to screen conversion at default zoom', () {
      // At zoom 1.0, pan (0,0), world coordinates map directly to screen
      const worldPoint = Point(x: 100, y: 50);
      final screenPoint = controller.worldToScreen(worldPoint);

      expect(screenPoint.dx, 100);
      expect(screenPoint.dy, 50);
    });

    test('screen to world conversion at default zoom', () {
      // At zoom 1.0, pan (0,0), screen coordinates map directly to world
      const screenPoint = Offset(100, 50);
      final worldPoint = controller.screenToWorld(screenPoint);

      expect(worldPoint.x, 100);
      expect(worldPoint.y, 50);
    });

    test('world to screen with zoom', () {
      controller.setZoom(2.0);

      const worldPoint = Point(x: 100, y: 50);
      final screenPoint = controller.worldToScreen(worldPoint);

      // World coordinate should be scaled by zoom
      expect(screenPoint.dx, 200);
      expect(screenPoint.dy, 100);
    });

    test('screen to world with zoom', () {
      controller.setZoom(2.0);

      const screenPoint = Offset(200, 100);
      final worldPoint = controller.screenToWorld(screenPoint);

      // Screen coordinate should be divided by zoom
      expect(worldPoint.x, 100);
      expect(worldPoint.y, 50);
    });

    test('world to screen with pan', () {
      controller.setPan(const Offset(50, 30));

      const worldPoint = Point(x: 100, y: 50);
      final screenPoint = controller.worldToScreen(worldPoint);

      // World coordinate should be offset by pan
      expect(screenPoint.dx, 150);
      expect(screenPoint.dy, 80);
    });

    test('screen to world with pan', () {
      controller.setPan(const Offset(50, 30));

      const screenPoint = Offset(150, 80);
      final worldPoint = controller.screenToWorld(screenPoint);

      // Screen coordinate should have pan subtracted
      expect(worldPoint.x, 100);
      expect(worldPoint.y, 50);
    });

    test('world to screen with zoom and pan', () {
      controller.setPan(const Offset(50, 30));
      controller.setZoom(2.0);

      const worldPoint = Point(x: 100, y: 50);
      final screenPoint = controller.worldToScreen(worldPoint);

      // Apply zoom then pan: (100*2 + 50, 50*2 + 30) = (250, 130)
      expect(screenPoint.dx, 250);
      expect(screenPoint.dy, 130);
    });

    test('screen to world with zoom and pan', () {
      controller.setPan(const Offset(50, 30));
      controller.setZoom(2.0);

      const screenPoint = Offset(250, 130);
      final worldPoint = controller.screenToWorld(screenPoint);

      // Reverse: ((250-50)/2, (130-30)/2) = (100, 50)
      expect(worldPoint.x, 100);
      expect(worldPoint.y, 50);
    });

    test('transformations are invertible', () {
      controller.setPan(const Offset(123, 456));
      controller.setZoom(1.5);

      const original = Point(x: 100, y: 200);
      final screen = controller.worldToScreen(original);
      final roundTrip = controller.screenToWorld(screen);

      expect(roundTrip.x, closeTo(original.x, 0.001));
      expect(roundTrip.y, closeTo(original.y, 0.001));
    });
  });

  group('TelemetryService', () {
    test('records viewport metrics when enabled', () {
      final service = TelemetryService(enabled: true);

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: const Offset(50, 30),
          panDelta: const Offset(10, 5),
          zoomLevel: 1.0,
        ),
      );

      expect(service.metricCount, 1);
      expect(service.panEventCount, 1);
    });

    test('ignores metrics when disabled', () {
      final service = TelemetryService(enabled: false);

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: Offset.zero,
          zoomLevel: 1.0,
        ),
      );

      expect(service.metricCount, 0);
    });

    test('calculates average FPS correctly', () {
      final service = TelemetryService(enabled: true);

      // Add metrics with different FPS
      for (double fps in [60.0, 58.0, 62.0, 59.0, 61.0]) {
        service.recordViewportMetric(
          ViewportTelemetry(
            timestamp: DateTime.now(),
            eventType: 'pan',
            fps: fps,
            panOffset: Offset.zero,
            zoomLevel: 1.0,
          ),
        );
      }

      expect(service.averageFps, closeTo(60.0, 0.1));
    });

    test('tracks min and max FPS', () {
      final service = TelemetryService(enabled: true);

      for (double fps in [60.0, 45.0, 70.0, 55.0]) {
        service.recordViewportMetric(
          ViewportTelemetry(
            timestamp: DateTime.now(),
            eventType: 'pan',
            fps: fps,
            panOffset: Offset.zero,
            zoomLevel: 1.0,
          ),
        );
      }

      expect(service.minFps, 45.0);
      expect(service.maxFps, 70.0);
    });

    test('counts event types correctly', () {
      final service = TelemetryService(enabled: true);

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: Offset.zero,
          zoomLevel: 1.0,
        ),
      );

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'zoom',
          fps: 60.0,
          panOffset: Offset.zero,
          zoomLevel: 2.0,
        ),
      );

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 58.0,
          panOffset: Offset.zero,
          zoomLevel: 1.0,
        ),
      );

      expect(service.panEventCount, 2);
      expect(service.zoomEventCount, 1);
    });

    test('calculates total pan distance', () {
      final service = TelemetryService(enabled: true);

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: Offset.zero,
          panDelta: const Offset(30, 40), // distance = 50
          zoomLevel: 1.0,
        ),
      );

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: Offset.zero,
          panDelta: const Offset(60, 80), // distance = 100
          zoomLevel: 1.0,
        ),
      );

      expect(service.totalPanDistance, closeTo(150, 0.1));
    });

    test('clears metrics', () {
      final service = TelemetryService(enabled: true);

      service.recordViewportMetric(
        ViewportTelemetry(
          timestamp: DateTime.now(),
          eventType: 'pan',
          fps: 60.0,
          panOffset: Offset.zero,
          zoomLevel: 1.0,
        ),
      );

      expect(service.metricCount, 1);

      service.clear();

      expect(service.metricCount, 0);
    });

    test('limits metrics history', () {
      final service = TelemetryService(
        enabled: true,
        maxMetricsHistory: 5,
      );

      // Add 10 metrics
      for (int i = 0; i < 10; i++) {
        service.recordViewportMetric(
          ViewportTelemetry(
            timestamp: DateTime.now(),
            eventType: 'pan',
            fps: 60.0,
            panOffset: Offset.zero,
            zoomLevel: 1.0,
          ),
        );
      }

      // Should only keep last 5
      expect(service.metricCount, 5);
    });
  });
}
