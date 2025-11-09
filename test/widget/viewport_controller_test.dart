import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/document/document.dart' as domain;
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_binding.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

void main() {
  group('Viewport Keyboard Shortcuts', () {
    late ViewportController controller;
    late DocumentProvider documentProvider;

    setUp(() {
      controller = ViewportController();
      documentProvider = DocumentProvider();
    });

    tearDown(() {
      controller.dispose();
      documentProvider.dispose();
    });

    testWidgets('zoom in with + key', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Focus the widget
      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      final initialZoom = controller.zoomLevel;

      // Press Shift+= (plus key)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      // Zoom should have increased
      expect(controller.zoomLevel, greaterThan(initialZoom));
      expect(controller.zoomLevel, closeTo(initialZoom * 1.1, 0.01));

      // Verify viewport was updated in document
      expect(documentProvider.viewport.zoom, controller.zoomLevel);
    });

    testWidgets('zoom in with numpad +', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      final initialZoom = controller.zoomLevel;

      // Press numpad +
      await tester.sendKeyDownEvent(LogicalKeyboardKey.add);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.add);
      await tester.pump();

      // Zoom should have increased
      expect(controller.zoomLevel, greaterThan(initialZoom));
    });

    testWidgets('zoom out with - key', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Set initial zoom to 2.0
      controller.setZoom(2.0);
      await tester.pump();

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      final initialZoom = controller.zoomLevel;

      // Press minus key
      await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
      await tester.pump();

      // Zoom should have decreased
      expect(controller.zoomLevel, lessThan(initialZoom));
      expect(controller.zoomLevel, closeTo(initialZoom * 0.9, 0.01));

      // Verify viewport was updated in document
      expect(documentProvider.viewport.zoom, controller.zoomLevel);
    });

    testWidgets('zoom out with numpad -', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      controller.setZoom(2.0);
      await tester.pump();

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      final initialZoom = controller.zoomLevel;

      // Press numpad -
      await tester.sendKeyDownEvent(LogicalKeyboardKey.numpadSubtract);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.numpadSubtract);
      await tester.pump();

      // Zoom should have decreased
      expect(controller.zoomLevel, lessThan(initialZoom));
    });

    testWidgets('reset viewport with Cmd+0 on Mac',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Modify viewport state
      controller.setPan(const Offset(100, 200));
      controller.setZoom(2.5);
      await tester.pump();

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Press Cmd+0 (Mac)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      // Viewport should be reset
      expect(controller.panOffset, Offset.zero);
      expect(controller.zoomLevel, 1.0);

      // Verify viewport was updated in document
      expect(documentProvider.viewport.zoom, 1.0);
    });

    testWidgets('reset viewport with Ctrl+0 on Windows/Linux',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Modify viewport state
      controller.setPan(const Offset(100, 200));
      controller.setZoom(2.5);
      await tester.pump();

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Press Ctrl+0 (Windows/Linux)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      // Viewport should be reset
      expect(controller.panOffset, Offset.zero);
      expect(controller.zoomLevel, 1.0);
    });

    testWidgets('multiple zoom operations', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Zoom in 3 times
      for (int i = 0; i < 3; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
      }

      // Should be approximately 1.1^3 = 1.331
      expect(controller.zoomLevel, closeTo(1.331, 0.01));

      // Zoom out 2 times
      for (int i = 0; i < 2; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
        await tester.pump();
      }

      // Should be approximately 1.331 * 0.9^2 = 1.08
      expect(controller.zoomLevel, closeTo(1.08, 0.01));
    });

    testWidgets('zoom respects min/max constraints',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Try to zoom out beyond minimum (0.05)
      controller.setZoom(0.06);
      await tester.pump();

      // Zoom out multiple times
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
        await tester.pump();
      }

      // Should be clamped to minimum
      expect(controller.zoomLevel, ViewportController.minZoom);

      // Try to zoom in beyond maximum (8.0)
      controller.setZoom(7.5);
      await tester.pump();

      // Zoom in multiple times
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
      }

      // Should be clamped to maximum
      expect(controller.zoomLevel, ViewportController.maxZoom);
    });
  });

  group('Space Bar Pan Mode', () {
    late ViewportController controller;
    late DocumentProvider documentProvider;

    setUp(() {
      controller = ViewportController();
      documentProvider = DocumentProvider();
    });

    tearDown(() {
      controller.dispose();
      documentProvider.dispose();
    });

    testWidgets('activates pan mode on space bar press',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              debugMode: true,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Initially no pan mode indicator
      expect(find.text('PAN MODE (Space)'), findsNothing);

      // Press space bar
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Pan mode indicator should appear
      expect(find.text('PAN MODE (Space)'), findsOneWidget);

      // Release space bar
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Pan mode indicator should disappear
      expect(find.text('PAN MODE (Space)'), findsNothing);
    });

    testWidgets('does not show pan mode indicator when debug mode disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              debugMode: false,
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Press space bar
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Pan mode indicator should not appear when debug mode is off
      expect(find.text('PAN MODE (Space)'), findsNothing);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
    });

    testWidgets('space bar does not trigger on repeat',
        (WidgetTester tester) async {
      int panModeActivations = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ViewportBinding(
                controller: controller,
                onViewportChanged: (viewport) {
                  documentProvider.updateViewport(viewport);
                  panModeActivations++;
                },
                child: const SizedBox.expand(
                  child: Placeholder(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Press space bar
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();

      final initialActivations = panModeActivations;

      // Simulate key repeat (should be ignored)
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Should not have triggered additional activations
      expect(panModeActivations, initialActivations);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
    });
  });

  group('Viewport State Persistence', () {
    late ViewportController controller;
    late DocumentProvider documentProvider;

    setUp(() {
      controller = ViewportController();
      documentProvider = DocumentProvider();
    });

    tearDown(() {
      controller.dispose();
      documentProvider.dispose();
    });

    testWidgets('viewport changes persist to document',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Perform pan gesture
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(100, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Verify viewport was updated in document
      final viewport = documentProvider.viewport;
      expect(viewport, isNotNull);

      // Pan offset should have been applied
      // Note: The exact values depend on coordinate system conversion
      expect(controller.panOffset, const Offset(100, 50));
    });

    testWidgets('viewport state survives document save/restore',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      // Set custom viewport state
      controller.setPan(const Offset(200, 100));
      controller.setZoom(1.5);
      await tester.pump();

      // Wait for viewport to sync
      await tester.pumpAndSettle();

      // Serialize document
      final json = documentProvider.toJson();

      // Create new provider and restore
      final restoredProvider = DocumentProvider();
      restoredProvider.loadFromJson(json);

      // Verify viewport was preserved
      expect(restoredProvider.viewport.zoom, closeTo(1.5, 0.01));

      restoredProvider.dispose();
    });

    testWidgets('keyboard shortcuts persist viewport changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewportBinding(
              controller: controller,
              onViewportChanged: (viewport) {
                documentProvider.updateViewport(viewport);
              },
              child: const SizedBox.expand(
                child: Placeholder(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Placeholder));
      await tester.pump();

      // Zoom in via keyboard
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      // Wait for state sync
      await tester.pumpAndSettle();

      // Verify zoom was persisted
      expect(
        documentProvider.viewport.zoom,
        closeTo(controller.zoomLevel, 0.01),
      );
    });
  });

  group('DocumentProvider', () {
    test('initializes with default document', () {
      final provider = DocumentProvider();
      expect(provider.document.id, 'default-doc');
      expect(provider.document.title, 'Untitled');
      expect(provider.viewport.zoom, 1.0);
      provider.dispose();
    });

    test('initializes with custom document', () {
      const customDoc = domain.Document(
        id: 'custom-doc',
        title: 'Custom Title',
        viewport: domain.Viewport(
          zoom: 2.0,
          pan: Point(x: 100, y: 50),
        ),
      );

      final provider = DocumentProvider(initialDocument: customDoc);
      expect(provider.document.id, 'custom-doc');
      expect(provider.document.title, 'Custom Title');
      expect(provider.viewport.zoom, 2.0);
      expect(provider.viewport.pan.x, 100);
      expect(provider.viewport.pan.y, 50);
      provider.dispose();
    });

    test('updates viewport and notifies listeners', () {
      final provider = DocumentProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      const newViewport = domain.Viewport(
        zoom: 1.5,
        pan: Point(x: 100, y: 50),
        canvasSize: domain.Size(width: 1920, height: 1080),
      );

      provider.updateViewport(newViewport);

      expect(notified, isTrue);
      expect(provider.viewport.zoom, 1.5);
      expect(provider.viewport.pan.x, 100);
      expect(provider.viewport.pan.y, 50);
      provider.dispose();
    });

    test('does not notify if viewport unchanged', () {
      final provider = DocumentProvider();
      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      final viewport = provider.viewport;
      provider.updateViewport(viewport);

      expect(notificationCount, 0);
      provider.dispose();
    });

    test('updates title and notifies listeners', () {
      final provider = DocumentProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.updateTitle('New Title');

      expect(notified, isTrue);
      expect(provider.document.title, 'New Title');
      provider.dispose();
    });

    test('serializes and deserializes document', () {
      const customDoc = domain.Document(
        id: 'test-doc',
        title: 'Test Document',
        viewport: domain.Viewport(
          zoom: 2.5,
          pan: Point(x: 200, y: 100),
        ),
      );

      final provider = DocumentProvider(initialDocument: customDoc);
      final json = provider.toJson();

      final restoredProvider = DocumentProvider();
      restoredProvider.loadFromJson(json);

      expect(restoredProvider.document.id, 'test-doc');
      expect(restoredProvider.document.title, 'Test Document');
      expect(restoredProvider.viewport.zoom, 2.5);
      expect(restoredProvider.viewport.pan.x, 200);
      expect(restoredProvider.viewport.pan.y, 100);

      provider.dispose();
      restoredProvider.dispose();
    });

    test('createNew resets document', () {
      final provider = DocumentProvider(
        initialDocument: const domain.Document(
          id: 'old-doc',
          title: 'Old Title',
          viewport: domain.Viewport(zoom: 3.0),
        ),
      );

      provider.createNew(id: 'new-doc', title: 'New Title');

      expect(provider.document.id, 'new-doc');
      expect(provider.document.title, 'New Title');
      expect(provider.viewport.zoom, 1.0);
      provider.dispose();
    });
  });
}
