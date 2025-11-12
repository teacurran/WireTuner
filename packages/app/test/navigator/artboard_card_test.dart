import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/modules/navigator/state/navigator_provider.dart';
import 'package:app/modules/navigator/state/navigator_service.dart';
import 'package:app/modules/navigator/widgets/artboard_card.dart';

void main() {
  group('ArtboardCard Widget', () {
    late NavigatorProvider provider;
    late NavigatorService service;

    setUp(() {
      provider = NavigatorProvider();
      service = NavigatorService();
    });

    tearDown(() {
      provider.dispose();
      service.dispose();
    });

    Widget buildTestWidget(ArtboardCardState artboard, {bool isSelected = false}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          Provider.value(value: service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ArtboardCard(
              artboard: artboard,
              isSelected: isSelected,
            ),
          ),
        ),
      );
    }

    testWidgets('displays artboard title', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      expect(find.text('Test Artboard'), findsOneWidget);
    });

    testWidgets('displays artboard dimensions', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      expect(find.text('1920 × 1080'), findsOneWidget);
    });

    testWidgets('shows dirty indicator when artboard has unsaved changes', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        isDirty: true,
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      // Find the dirty indicator (small red circle)
      final dirtyIndicator = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );

      expect(dirtyIndicator, findsWidgets);
    });

    testWidgets('shows selection highlight when selected', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard, isSelected: true));

      // Selected cards have a thicker border
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.width, 2.0);
    });

    testWidgets('shows placeholder when no thumbnail', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
        thumbnail: null,
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('shows thumbnail image when available', (tester) async {
      final thumbnail = Uint8List.fromList([255, 0, 0, 255]); // Red pixel

      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
        thumbnail: thumbnail,
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('enters edit mode on double-tap title', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      // Double-tap the title
      await tester.tap(find.text('Test Artboard'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Test Artboard'));
      await tester.pumpAndSettle();

      // Should show text field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('commits rename on submit', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      // Add artboard to provider
      provider.openDocument(DocumentTab(
        documentId: 'doc1',
        name: 'Test Doc',
        path: '/test',
        artboardIds: ['art1'],
      ));

      await tester.pumpWidget(buildTestWidget(artboard));

      // Enter edit mode
      await tester.tap(find.text('Test Artboard'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Test Artboard'));
      await tester.pumpAndSettle();

      // Type new name
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should exit edit mode
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows hover effect on mouse enter', (tester) async {
      final artboard = ArtboardCardState(
        artboardId: 'art1',
        title: 'Test Artboard',
        dimensions: const Size(1920, 1080),
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(artboard));

      // Get initial container
      final containerFinder = find.byType(AnimatedContainer).first;
      final initialContainer = tester.widget<AnimatedContainer>(containerFinder);
      final initialDecoration = initialContainer.decoration as BoxDecoration;

      // Hover over card
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(ArtboardCard)));
      await tester.pumpAndSettle();

      // Should have shadow on hover
      final hoveredContainer = tester.widget<AnimatedContainer>(containerFinder);
      final hoveredDecoration = hoveredContainer.decoration as BoxDecoration;

      // Check if shadow was added (won't be present if selected)
      if (!tester.widget<ArtboardCard>(find.byType(ArtboardCard)).isSelected) {
        expect(hoveredDecoration.boxShadow, isNotNull);
      }
    });
  });
}
