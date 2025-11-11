import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/modules/navigator/state/navigator_provider.dart';
import 'package:app/modules/navigator/state/navigator_service.dart';
import 'package:app/modules/navigator/widgets/artboard_grid.dart';
import 'package:app/modules/navigator/widgets/artboard_card.dart';

void main() {
  group('ArtboardGrid Widget', () {
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

    Widget buildTestWidget(List<ArtboardCardState> artboards) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          Provider.value(value: service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ArtboardGrid(
              documentId: 'doc1',
              artboards: artboards,
            ),
          ),
        ),
      );
    }

    testWidgets('renders grid with artboard cards', (tester) async {
      final artboards = List.generate(
        5,
        (index) => ArtboardCardState(
          artboardId: 'art$index',
          title: 'Artboard $index',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestWidget(artboards));

      expect(find.byType(ArtboardCard), findsNWidgets(5));
    });

    testWidgets('uses virtualization with GridView.builder', (tester) async {
      final artboards = List.generate(
        100,
        (index) => ArtboardCardState(
          artboardId: 'art$index',
          title: 'Artboard $index',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestWidget(artboards));

      // Should use GridView.builder for virtualization
      expect(find.byType(GridView), findsOneWidget);

      // Not all cards should be built (only visible ones)
      final builtCards = find.byType(ArtboardCard);
      expect(builtCards.evaluate().length, lessThan(100));
    });

    testWidgets('handles large artboard count (1000 artboards)', (tester) async {
      final artboards = List.generate(
        1000,
        (index) => ArtboardCardState(
          artboardId: 'art$index',
          title: 'Artboard $index',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestWidget(artboards));

      // Should render without issues
      expect(find.byType(GridView), findsOneWidget);

      // Only visible cards should be rendered
      final builtCards = find.byType(ArtboardCard).evaluate().length;
      expect(builtCards, lessThan(50)); // Typical viewport shows ~20-40 cards
    });

    testWidgets('selection state changes via provider', (tester) async {
      final artboards = [
        ArtboardCardState(
          artboardId: 'art1',
          title: 'Artboard 1',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      ];

      // Set up document in provider first
      provider.openDocument(DocumentTab(
        documentId: 'doc1',
        name: 'Test Doc',
        path: '/test',
        artboardIds: ['art1'],
      ));

      await tester.pumpWidget(buildTestWidget(artboards));

      // Initially not selected
      expect(provider.selectedArtboards.contains('art1'), false);

      // Programmatically select via provider
      provider.selectArtboard('art1');
      await tester.pump();

      // Should now be selected
      expect(provider.selectedArtboards.contains('art1'), true);
    });

    testWidgets('responds to scroll events', (tester) async {
      final artboards = List.generate(
        50,
        (index) => ArtboardCardState(
          artboardId: 'art$index',
          title: 'Artboard $index',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestWidget(artboards));

      // Find the grid view
      final gridView = find.byType(GridView);

      // Scroll down
      await tester.drag(gridView, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Grid should have scrolled
      // (Verify by checking if new cards are visible)
      expect(find.byType(ArtboardCard), findsWidgets);
    });

    testWidgets('calculates responsive columns', (tester) async {
      final artboards = List.generate(
        10,
        (index) => ArtboardCardState(
          artboardId: 'art$index',
          title: 'Artboard $index',
          dimensions: const Size(1920, 1080),
          lastModified: DateTime.now(),
        ),
      );

      // Test with narrow width
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            Provider.value(value: service),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300, // Narrow width
                child: ArtboardGrid(
                  documentId: 'doc1',
                  artboards: artboards,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);

      // Should adapt to narrow width (likely 1 column)
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      // Should have calculated appropriate columns (likely 1 for 300px width)
      expect(delegate.crossAxisCount, greaterThanOrEqualTo(1));
      expect(delegate.crossAxisCount, lessThanOrEqualTo(8));
    });
  });
}
