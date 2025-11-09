import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/presentation/canvas/overlay_layer.dart';
import 'package:wiretuner/presentation/canvas/overlay_registry.dart';

void main() {
  group('OverlayRegistry', () {
    late OverlayRegistry registry;

    setUp(() {
      registry = OverlayRegistry();
    });

    test('starts empty', () {
      expect(registry.isEmpty, isTrue);
      expect(registry.isNotEmpty, isFalse);
      expect(registry.count, equals(0));
    });

    test('registers and retrieves overlays', () {
      final entry = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      );

      registry.register(entry);

      expect(registry.count, equals(1));
      expect(registry.contains('test'), isTrue);
      expect(registry.get('test'), equals(entry));
    });

    test('replaces existing overlay with same id', () {
      final entry1 = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      );
      final entry2 = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 200,
        painter: _TestPainter(),
      );

      registry.register(entry1);
      registry.register(entry2);

      expect(registry.count, equals(1));
      expect(registry.get('test')?.zIndex, equals(200));
    });

    test('unregisters overlays', () {
      final entry = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      );

      registry.register(entry);
      expect(registry.contains('test'), isTrue);

      final removed = registry.unregister('test');
      expect(removed, isTrue);
      expect(registry.contains('test'), isFalse);
      expect(registry.isEmpty, isTrue);
    });

    test('unregister returns false for non-existent id', () {
      final removed = registry.unregister('nonexistent');
      expect(removed, isFalse);
    });

    test('sorts overlays by z-index ascending', () {
      registry.register(CanvasOverlayEntry.painter(
        id: 'c',
        zIndex: 300,
        painter: _TestPainter(),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'a',
        zIndex: 100,
        painter: _TestPainter(),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'b',
        zIndex: 200,
        painter: _TestPainter(),
      ));

      final sorted = registry.getSortedOverlays();

      expect(sorted.length, equals(3));
      expect(sorted[0].id, equals('a'));
      expect(sorted[0].zIndex, equals(100));
      expect(sorted[1].id, equals('b'));
      expect(sorted[1].zIndex, equals(200));
      expect(sorted[2].id, equals('c'));
      expect(sorted[2].zIndex, equals(300));
    });

    test('filters painters and widgets separately', () {
      registry.register(CanvasOverlayEntry.painter(
        id: 'painter1',
        zIndex: 100,
        painter: _TestPainter(),
      ));
      registry.register(CanvasOverlayEntry.widget(
        id: 'widget1',
        zIndex: 200,
        widget: const SizedBox(),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'painter2',
        zIndex: 300,
        painter: _TestPainter(),
      ));

      final painters = registry.getSortedPainters();
      final widgets = registry.getSortedWidgets();

      expect(painters.length, equals(2));
      expect(painters[0].id, equals('painter1'));
      expect(painters[1].id, equals('painter2'));

      expect(widgets.length, equals(1));
      expect(widgets[0].id, equals('widget1'));
    });

    test('clears all overlays', () {
      registry.register(CanvasOverlayEntry.painter(
        id: 'a',
        zIndex: 100,
        painter: _TestPainter(),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'b',
        zIndex: 200,
        painter: _TestPainter(),
      ));

      expect(registry.count, equals(2));

      registry.clear();

      expect(registry.isEmpty, isTrue);
      expect(registry.count, equals(0));
    });

    test('notifies listeners on register', () {
      var notified = false;
      registry.addListener(() {
        notified = true;
      });

      registry.register(CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      ));

      expect(notified, isTrue);
    });

    test('notifies listeners on unregister', () {
      registry.register(CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      ));

      var notified = false;
      registry.addListener(() {
        notified = true;
      });

      registry.unregister('test');

      expect(notified, isTrue);
    });

    test('does not notify on failed unregister', () {
      var notified = false;
      registry.addListener(() {
        notified = true;
      });

      registry.unregister('nonexistent');

      expect(notified, isFalse);
    });
  });

  group('OverlayEntry', () {
    test('creates painter entry', () {
      final painter = _TestPainter();
      final entry = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: painter,
      );

      expect(entry.isPainter, isTrue);
      expect(entry.isWidget, isFalse);
      expect(entry.getPainter(), equals(painter));
      expect(entry.widget, isNull);
    });

    test('creates widget entry', () {
      const widget = SizedBox();
      final entry = CanvasOverlayEntry.widget(
        id: 'test',
        zIndex: 100,
        widget: widget,
      );

      expect(entry.isWidget, isTrue);
      expect(entry.isPainter, isFalse);
      expect(entry.widget, equals(widget));
      expect(entry.getPainter(), isNull);
    });

    test('creates painter builder entry', () {
      final builder = () => _TestPainter();
      final entry = CanvasOverlayEntry.painterBuilder(
        id: 'test',
        zIndex: 100,
        builder: builder,
      );

      expect(entry.isPainter, isTrue);
      expect(entry.isWidget, isFalse);
      expect(entry.getPainter(), isA<_TestPainter>());
    });

    test('uses default hit-test behavior', () {
      final entry = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      );

      expect(entry.hitTestBehavior, equals(HitTestBehavior.translucent));
    });

    test('allows custom hit-test behavior', () {
      final entry = CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
        hitTestBehavior: HitTestBehavior.opaque,
      );

      expect(entry.hitTestBehavior, equals(HitTestBehavior.opaque));
    });
  });

  group('OverlayZIndex', () {
    test('defines correct tier ranges', () {
      // Document-derived tier (100-199)
      expect(OverlayZIndex.documentBase, equals(100));
      expect(OverlayZIndex.selection, equals(110));
      expect(OverlayZIndex.bounds, equals(120));

      // Tool-state tier (200-299)
      expect(OverlayZIndex.toolBase, equals(200));
      expect(OverlayZIndex.penPreview, equals(210));
      expect(OverlayZIndex.shapePreview, equals(220));
      expect(OverlayZIndex.snapping, equals(230));
      expect(OverlayZIndex.activeTool, equals(240));

      // Widget tier (300-399)
      expect(OverlayZIndex.widgetBase, equals(300));
      expect(OverlayZIndex.toolHints, equals(310));
      expect(OverlayZIndex.performance, equals(320));
    });

    test('maintains tier ordering', () {
      expect(OverlayZIndex.selection < OverlayZIndex.penPreview, isTrue);
      expect(OverlayZIndex.penPreview < OverlayZIndex.toolHints, isTrue);
      expect(OverlayZIndex.bounds < OverlayZIndex.activeTool, isTrue);
    });
  });

  group('OverlayLayer widget', () {
    testWidgets('renders empty when registry is empty', (tester) async {
      final registry = OverlayRegistry();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Look for CustomPaint within OverlayLayer only
      final customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsNothing);
    });

    testWidgets('renders painter overlays in z-index order', (tester) async {
      final registry = OverlayRegistry();

      // Register painters in reverse z-index order
      registry.register(CanvasOverlayEntry.painter(
        id: 'high',
        zIndex: 300,
        painter: _TestPainter(color: Colors.blue),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'low',
        zIndex: 100,
        painter: _TestPainter(color: Colors.red),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'mid',
        zIndex: 200,
        painter: _TestPainter(color: Colors.green),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Should render 3 CustomPaint widgets within OverlayLayer
      final customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsNWidgets(3));

      // Verify painters are in z-index order (Stack renders bottom-to-top)
      // Find the OverlayLayer's Stack specifically
      final overlayLayer = tester.widget<OverlayLayer>(find.byType(OverlayLayer));
      final context = tester.element(find.byWidget(overlayLayer));
      final stack = context.widget as OverlayLayer;

      // Check actual rendering order by finding the Stack children
      final stackFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(Stack),
      );
      final stackWidget = tester.widget<Stack>(stackFinder);
      expect(stackWidget.children.length, equals(3));

      // First child should be lowest z-index (low = 100)
      final firstPaint = stackWidget.children[0] as IgnorePointer;
      final firstCustomPaint = firstPaint.child as CustomPaint;
      final firstPainter = firstCustomPaint.painter as _TestPainter;
      expect(firstPainter.color, equals(Colors.red));

      // Second child should be mid z-index (mid = 200)
      final secondPaint = stackWidget.children[1] as IgnorePointer;
      final secondCustomPaint = secondPaint.child as CustomPaint;
      final secondPainter = secondCustomPaint.painter as _TestPainter;
      expect(secondPainter.color, equals(Colors.green));

      // Third child should be highest z-index (high = 300)
      final thirdPaint = stackWidget.children[2] as IgnorePointer;
      final thirdCustomPaint = thirdPaint.child as CustomPaint;
      final thirdPainter = thirdCustomPaint.painter as _TestPainter;
      expect(thirdPainter.color, equals(Colors.blue));
    });

    testWidgets('renders widget overlays on top of painters', (tester) async {
      final registry = OverlayRegistry();

      registry.register(CanvasOverlayEntry.painter(
        id: 'painter',
        zIndex: 100,
        painter: _TestPainter(),
      ));
      registry.register(CanvasOverlayEntry.widget(
        id: 'widget',
        zIndex: 200,
        widget: const Text('Overlay Widget'),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Should render painter and widget within OverlayLayer
      final customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
      expect(find.text('Overlay Widget'), findsOneWidget);

      // Widget should be rendered after painter in stack
      final stackFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(Stack),
      );
      final stack = tester.widget<Stack>(stackFinder);
      expect(stack.children.length, equals(2));
      expect(stack.children[0], isA<IgnorePointer>()); // Painter
      expect(stack.children[1], isA<KeyedSubtree>()); // Widget
    });

    testWidgets('uses IgnorePointer for translucent hit-test behavior',
        (tester) async {
      final registry = OverlayRegistry();

      registry.register(CanvasOverlayEntry.painter(
        id: 'translucent',
        zIndex: 100,
        painter: _TestPainter(),
        hitTestBehavior: HitTestBehavior.translucent,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Find IgnorePointer within OverlayLayer
      final ignorePointerFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(IgnorePointer),
      );
      expect(ignorePointerFinder, findsOneWidget);
    });

    testWidgets('uses Container for non-translucent hit-test behavior',
        (tester) async {
      final registry = OverlayRegistry();

      registry.register(CanvasOverlayEntry.painter(
        id: 'opaque',
        zIndex: 100,
        painter: _TestPainter(),
        hitTestBehavior: HitTestBehavior.opaque,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Should use Container for opaque overlays
      // Find Container that is a descendant of OverlayLayer
      final containerFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      // Should not wrap opaque painters in IgnorePointer
      final ignorePointerFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(IgnorePointer),
      );
      expect(ignorePointerFinder, findsNothing);
    });

    testWidgets('rebuilds when registry changes', (tester) async {
      final registry = OverlayRegistry();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      // Look for CustomPaint within OverlayLayer specifically
      var customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsNothing);

      // Add overlay
      registry.register(CanvasOverlayEntry.painter(
        id: 'test',
        zIndex: 100,
        painter: _TestPainter(),
      ));

      await tester.pump();

      customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      // Remove overlay
      registry.unregister('test');

      await tester.pump();

      customPaintFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsNothing);
    });
  });

  group('CompositeOverlayPainter', () {
    test('creates with list of painters', () {
      final painters = [
        _TestPainter(color: Colors.red),
        _TestPainter(color: Colors.blue),
      ];
      final composite = CompositeOverlayPainter(painters: painters);

      expect(composite.painters.length, equals(2));
    });

    testWidgets('paints all child painters', (tester) async {
      final painter1 = _TestPainter(color: Colors.red);
      final painter2 = _TestPainter(color: Colors.blue);

      final composite = CompositeOverlayPainter(painters: [painter1, painter2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: composite,
              size: const Size(100, 100),
            ),
          ),
        ),
      );

      // Verify both painters were painted
      expect(painter1.paintCalled, isTrue);
      expect(painter2.paintCalled, isTrue);
    });

    test('shouldRepaint when painter count changes', () {
      final composite1 = CompositeOverlayPainter(painters: [_TestPainter()]);
      final composite2 =
          CompositeOverlayPainter(painters: [_TestPainter(), _TestPainter()]);

      expect(composite2.shouldRepaint(composite1), isTrue);
    });

    test('shouldRepaint when child painter shouldRepaint returns true', () {
      final painter1 = _TestPainter(shouldRepaintValue: false);
      final painter2 = _TestPainter(shouldRepaintValue: true);

      final composite1 = CompositeOverlayPainter(painters: [painter1]);
      final composite2 = CompositeOverlayPainter(painters: [painter2]);

      expect(composite2.shouldRepaint(composite1), isTrue);
    });
  });

  group('Overlay stacking integration', () {
    testWidgets('verifies document < tool < widget tier ordering',
        (tester) async {
      final registry = OverlayRegistry();

      // Register overlays from different tiers
      registry.register(CanvasOverlayEntry.painter(
        id: 'selection',
        zIndex: OverlayZIndex.selection, // 110
        painter: _TestPainter(color: Colors.red),
      ));
      registry.register(CanvasOverlayEntry.painter(
        id: 'pen-preview',
        zIndex: OverlayZIndex.penPreview, // 210
        painter: _TestPainter(color: Colors.green),
      ));
      registry.register(CanvasOverlayEntry.widget(
        id: 'tool-hints',
        zIndex: OverlayZIndex.toolHints, // 310
        widget: const Text('Hints'),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayLayer(registry: registry),
          ),
        ),
      );

      final stackFinder = find.descendant(
        of: find.byType(OverlayLayer),
        matching: find.byType(Stack),
      );
      final stack = tester.widget<Stack>(stackFinder);
      expect(stack.children.length, equals(3));

      // First: selection (z-index 110)
      final first = stack.children[0] as IgnorePointer;
      final firstPaint = first.child as CustomPaint;
      final firstPainter = firstPaint.painter as _TestPainter;
      expect(firstPainter.color, equals(Colors.red));

      // Second: pen preview (z-index 210)
      final second = stack.children[1] as IgnorePointer;
      final secondPaint = second.child as CustomPaint;
      final secondPainter = secondPaint.painter as _TestPainter;
      expect(secondPainter.color, equals(Colors.green));

      // Third: tool hints widget (z-index 310)
      final third = stack.children[2] as KeyedSubtree;
      expect(third.child, isA<Text>());
    });
  });
}

/// Test painter for overlay testing.
class _TestPainter extends CustomPainter {
  _TestPainter({
    this.color = Colors.transparent,
    this.shouldRepaintValue = false,
  });

  final Color color;
  final bool shouldRepaintValue;
  bool paintCalled = false;

  @override
  void paint(Canvas canvas, Size size) {
    paintCalled = true;
    final paint = Paint()..color = color;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_TestPainter oldDelegate) => shouldRepaintValue;
}
