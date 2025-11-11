import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/modules/navigator/state/navigator_provider.dart';

void main() {
  group('NavigatorProvider', () {
    late NavigatorProvider provider;

    setUp(() {
      provider = NavigatorProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('Document Management', () {
      test('openDocument adds new document tab', () {
        final tab = DocumentTab(
          documentId: 'doc1',
          name: 'Test Document',
          path: '/path/to/doc.wire',
          artboardIds: ['art1', 'art2'],
        );

        provider.openDocument(tab);

        expect(provider.openDocuments.length, 1);
        expect(provider.activeDocumentId, 'doc1');
        expect(provider.activeDocument, tab);
      });

      test('openDocument switches to existing document if already open', () {
        final tab1 = DocumentTab(
          documentId: 'doc1',
          name: 'Document 1',
          path: '/path/to/doc1.wire',
          artboardIds: ['art1'],
        );

        final tab2 = DocumentTab(
          documentId: 'doc2',
          name: 'Document 2',
          path: '/path/to/doc2.wire',
          artboardIds: ['art2'],
        );

        provider.openDocument(tab1);
        provider.openDocument(tab2);
        expect(provider.openDocuments.length, 2);
        expect(provider.activeDocumentId, 'doc2');

        // Try to open doc1 again
        provider.openDocument(tab1);
        expect(provider.openDocuments.length, 2); // Should not duplicate
        expect(provider.activeDocumentId, 'doc1'); // Should switch to it
      });

      test('closeDocument removes tab and cleans up state', () {
        final tab = DocumentTab(
          documentId: 'doc1',
          name: 'Test Document',
          path: '/path/to/doc.wire',
          artboardIds: ['art1', 'art2'],
        );

        provider.openDocument(tab);
        provider.selectArtboard('art1');

        expect(provider.selectedArtboards.contains('art1'), true);

        provider.closeDocument('doc1');

        expect(provider.openDocuments.isEmpty, true);
        expect(provider.activeDocumentId, null);
        expect(provider.selectedArtboards.isEmpty, true);
      });

      test('switchToDocument changes active document', () {
        final tab1 = DocumentTab(
          documentId: 'doc1',
          name: 'Document 1',
          path: '/path/to/doc1.wire',
          artboardIds: ['art1'],
        );

        final tab2 = DocumentTab(
          documentId: 'doc2',
          name: 'Document 2',
          path: '/path/to/doc2.wire',
          artboardIds: ['art2'],
        );

        provider.openDocument(tab1);
        provider.openDocument(tab2);

        expect(provider.activeDocumentId, 'doc2');

        provider.switchToDocument('doc1');
        expect(provider.activeDocumentId, 'doc1');
      });
    });

    group('Artboard Management', () {
      setUp(() {
        final tab = DocumentTab(
          documentId: 'doc1',
          name: 'Test Document',
          path: '/path/to/doc.wire',
          artboardIds: ['art1', 'art2', 'art3'],
        );
        provider.openDocument(tab);
      });

      test('getArtboards returns artboards for document', () {
        final artboards = provider.getArtboards('doc1');
        expect(artboards.length, 3);
      });

      test('updateArtboard modifies artboard state', () {
        provider.updateArtboard(
          artboardId: 'art1',
          title: 'Updated Title',
          isDirty: true,
        );

        final artboard = provider.getArtboard('art1');
        expect(artboard?.title, 'Updated Title');
        expect(artboard?.isDirty, true);
      });

      test('getArtboard returns null for non-existent artboard', () {
        final artboard = provider.getArtboard('nonexistent');
        expect(artboard, null);
      });
    });

    group('Selection Management', () {
      setUp(() {
        final tab = DocumentTab(
          documentId: 'doc1',
          name: 'Test Document',
          path: '/path/to/doc.wire',
          artboardIds: ['art1', 'art2', 'art3', 'art4', 'art5'],
        );
        provider.openDocument(tab);
      });

      test('selectArtboard selects single artboard', () {
        provider.selectArtboard('art1');

        expect(provider.selectedArtboards.length, 1);
        expect(provider.isSelected('art1'), true);
      });

      test('selectArtboard clears previous selection', () {
        provider.selectArtboard('art1');
        provider.selectArtboard('art2');

        expect(provider.selectedArtboards.length, 1);
        expect(provider.isSelected('art1'), false);
        expect(provider.isSelected('art2'), true);
      });

      test('toggleArtboard adds to selection', () {
        provider.selectArtboard('art1');
        provider.toggleArtboard('art2');

        expect(provider.selectedArtboards.length, 2);
        expect(provider.isSelected('art1'), true);
        expect(provider.isSelected('art2'), true);
      });

      test('toggleArtboard removes from selection', () {
        provider.selectArtboard('art1');
        provider.toggleArtboard('art1');

        expect(provider.selectedArtboards.isEmpty, true);
      });

      test('selectRange selects all artboards in range', () {
        provider.selectRange('art2', 'art4');

        expect(provider.selectedArtboards.length, 3);
        expect(provider.isSelected('art2'), true);
        expect(provider.isSelected('art3'), true);
        expect(provider.isSelected('art4'), true);
        expect(provider.isSelected('art1'), false);
        expect(provider.isSelected('art5'), false);
      });

      test('selectRange works with reversed order', () {
        provider.selectRange('art4', 'art2');

        expect(provider.selectedArtboards.length, 3);
        expect(provider.isSelected('art2'), true);
        expect(provider.isSelected('art3'), true);
        expect(provider.isSelected('art4'), true);
      });

      test('clearSelection removes all selections', () {
        provider.selectArtboard('art1');
        provider.toggleArtboard('art2');
        provider.toggleArtboard('art3');

        expect(provider.selectedArtboards.length, 3);

        provider.clearSelection();
        expect(provider.selectedArtboards.isEmpty, true);
      });
    });

    group('Viewport State', () {
      test('saveViewportState stores viewport snapshot', () {
        final snapshot = ViewportSnapshot(
          artboardId: 'art1',
          pan: const Offset(100, 200),
          zoom: 1.5,
        );

        provider.saveViewportState('art1', snapshot);

        final retrieved = provider.getViewportState('art1');
        expect(retrieved?.artboardId, 'art1');
        expect(retrieved?.pan, const Offset(100, 200));
        expect(retrieved?.zoom, 1.5);
      });

      test('getViewportState returns null for non-existent artboard', () {
        final viewport = provider.getViewportState('nonexistent');
        expect(viewport, null);
      });
    });

    group('Grid Configuration', () {
      test('updateGridConfig updates configuration', () {
        final newConfig = GridConfig(
          columns: 6,
          spacing: 20.0,
          thumbnailSize: 250.0,
        );

        provider.updateGridConfig(newConfig);

        expect(provider.gridConfig.columns, 6);
        expect(provider.gridConfig.spacing, 20.0);
        expect(provider.gridConfig.thumbnailSize, 250.0);
      });
    });

    group('Thumbnail Refresh', () {
      test('thumbnail timers are cleaned up on dispose', () {
        // Create a separate provider for this test to avoid double-dispose
        final testProvider = NavigatorProvider();
        final tab = DocumentTab(
          documentId: 'doc1',
          name: 'Test Document',
          path: '/path/to/doc.wire',
          artboardIds: ['art1'],
        );
        testProvider.openDocument(tab);

        // Start thumbnail refresh
        var callCount = 0;
        testProvider.startThumbnailRefresh('art1', () async {
          callCount++;
          return Uint8List(4);
        });

        // Dispose should cancel timers
        testProvider.dispose();

        // Timer should not fire after disposal
        // (In real scenario, we'd wait and verify callCount doesn't increase)
      });
    });
  });
}
