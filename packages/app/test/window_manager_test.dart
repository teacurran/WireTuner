import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:app/app_shell/window_manager.dart';
import 'package:app/app_shell/window_descriptor.dart';

void main() {
  group('WindowManager', () {
    late WindowManager manager;

    setUp(() {
      manager = WindowManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('Window Registration', () {
      test('registers Navigator window', () async {
        final descriptor = WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        );

        final registered = await manager.registerWindow(descriptor);

        expect(registered.windowId, 'nav-doc1');
        expect(manager.windows.length, 1);
        expect(manager.getWindow('nav-doc1'), isNotNull);
      });

      test('registers artboard window', () async {
        final descriptor = WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
        );

        await manager.registerWindow(descriptor);

        expect(manager.windows.length, 1);
        expect(manager.isArtboardWindowOpen('doc1', 'art1'), true);
      });

      test('registers multiple windows for same document', () async {
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
        ));

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art2',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art2',
        ));

        final docWindows = manager.getWindowsForDocument('doc1');
        expect(docWindows.length, 3);
        expect(manager.getNavigatorForDocument('doc1'), isNotNull);
        expect(manager.getArtboardWindowsForDocument('doc1').length, 2);
      });

      test('emits opened event on registration', () async {
        final events = <WindowLifecycleEvent>[];
        manager.events.listen(events.add);

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await Future.delayed(Duration.zero); // Let stream emit

        expect(events.length, 1);
        expect(events[0].type, WindowLifecycleEventType.opened);
        expect(events[0].descriptor.windowId, 'nav-doc1');
      });
    });

    group('Window Lifecycle', () {
      test('unregisters window and removes from index', () async {
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        expect(manager.windows.length, 1);

        await manager.unregisterWindow('nav-doc1');

        expect(manager.windows.length, 0);
        expect(manager.getWindow('nav-doc1'), isNull);
        expect(manager.hasWindowsForDocument('doc1'), false);
      });

      test('persists viewport state on unregister', () async {
        ViewportSnapshot? persisted;

        manager = WindowManager(
          onPersistViewportState: (docId, artId, viewport) async {
            persisted = viewport;
          },
        );

        final viewport = ViewportSnapshot(
          panOffset: Offset(100, 50),
          zoom: 1.5,
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
          lastViewportState: viewport,
        ));

        await manager.unregisterWindow('art-doc1-art1');

        expect(persisted, isNotNull);
        expect(persisted!.panOffset, Offset(100, 50));
        expect(persisted!.zoom, 1.5);
      });

      test('emits closed event on unregister', () async {
        final events = <WindowLifecycleEvent>[];
        manager.events.listen(events.add);

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        events.clear(); // Clear opened event

        await manager.unregisterWindow('nav-doc1');

        await Future.delayed(Duration.zero);

        expect(events.any((e) => e.type == WindowLifecycleEventType.closed), true);
      });
    });

    group('Focus Management', () {
      test('tracks focused window', () async {
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
        ));

        manager.focusWindow('art-doc1-art1');

        expect(manager.focusedWindow?.windowId, 'art-doc1-art1');
      });

      test('blurs previous window when focusing new one', () async {
        final events = <WindowLifecycleEvent>[];
        manager.events.listen(events.add);

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
        ));

        events.clear();

        manager.focusWindow('nav-doc1');
        await Future.delayed(Duration.zero);

        manager.focusWindow('art-doc1-art1');
        await Future.delayed(Duration.zero);

        // Should have blur event for nav-doc1 and focus event for art
        expect(
          events.any((e) =>
              e.type == WindowLifecycleEventType.blurred &&
              e.descriptor.windowId == 'nav-doc1'),
          true,
        );
        expect(
          events.any((e) =>
              e.type == WindowLifecycleEventType.focused &&
              e.descriptor.windowId == 'art-doc1-art1'),
          true,
        );
      });

      test('persists viewport state on blur', () async {
        ViewportSnapshot? persisted;

        manager = WindowManager(
          onPersistViewportState: (docId, artId, viewport) async {
            persisted = viewport;
          },
        );

        final viewport = ViewportSnapshot(
          panOffset: Offset(200, 100),
          zoom: 2.0,
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
          lastViewportState: viewport,
        ));

        await manager.blurWindow('art-doc1-art1');

        expect(persisted, isNotNull);
        expect(persisted!.zoom, 2.0);
      });
    });

    group('Viewport State Updates', () {
      test('updates window viewport state', () async {
        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
        ));

        final newViewport = ViewportSnapshot(
          panOffset: Offset(150, 75),
          zoom: 1.8,
        );

        manager.updateWindow('art-doc1-art1', viewportState: newViewport);

        final window = manager.getWindow('art-doc1-art1');
        expect(window?.lastViewportState?.zoom, 1.8);
        expect(window?.lastViewportState?.panOffset, Offset(150, 75));
      });

      test('updates window dirty flag', () async {
        await manager.registerWindow(WindowDescriptor(
          windowId: 'art-doc1-art1',
          type: WindowType.artboard,
          documentId: 'doc1',
          artboardId: 'art1',
          isDirty: false,
        ));

        manager.updateWindow('art-doc1-art1', isDirty: true);

        final window = manager.getWindow('art-doc1-art1');
        expect(window?.isDirty, true);
      });
    });

    group('Artboard Window Operations', () {
      test('opens artboard window and sets initial viewport', () async {
        final viewport = ViewportSnapshot(
          panOffset: Offset(100, 100),
          zoom: 1.5,
        );

        final descriptor = await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
          initialViewportState: viewport,
        );

        expect(descriptor.windowId, 'art-doc1-art1');
        expect(descriptor.lastViewportState?.zoom, 1.5);
        expect(manager.isArtboardWindowOpen('doc1', 'art1'), true);
      });

      test('focuses existing artboard window instead of creating duplicate', () async {
        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
        );

        expect(manager.windows.length, 1);

        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
        );

        // Should still be 1 window, just focused
        expect(manager.windows.length, 1);
        expect(manager.focusedWindow?.artboardId, 'art1');
      });

      test('closes artboard window silently', () async {
        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
        );

        final closed = await manager.requestCloseArtboard('doc1', 'art1');

        expect(closed, true);
        expect(manager.isArtboardWindowOpen('doc1', 'art1'), false);
      });
    });

    group('Navigator Window Operations', () {
      test('closes Navigator with confirmation', () async {
        bool confirmCalled = false;

        manager = WindowManager(
          onConfirmClose: (docId) async {
            confirmCalled = true;
            return true; // User confirms
          },
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        final closed = await manager.requestCloseNavigator('doc1');

        expect(confirmCalled, true);
        expect(closed, true);
        expect(manager.hasWindowsForDocument('doc1'), false);
      });

      test('cancels Navigator close if user declines', () async {
        manager = WindowManager(
          onConfirmClose: (docId) async => false, // User cancels
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        final closed = await manager.requestCloseNavigator('doc1');

        expect(closed, false);
        expect(manager.hasWindowsForDocument('doc1'), true);
      });

      test('closes all windows when closing Navigator', () async {
        manager = WindowManager(
          onConfirmClose: (docId) async => true, // User confirms
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art1');
        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art2');

        expect(manager.getWindowsForDocument('doc1').length, 3);

        await manager.requestCloseNavigator('doc1');

        expect(manager.getWindowsForDocument('doc1').length, 0);
      });
    });

    group('Multi-Document Scenarios', () {
      test('manages windows for multiple documents independently', () async {
        // Document 1
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));
        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art1');

        // Document 2
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc2',
          type: WindowType.navigator,
          documentId: 'doc2',
        ));
        await manager.openArtboardWindow(documentId: 'doc2', artboardId: 'art1');

        expect(manager.getWindowsForDocument('doc1').length, 2);
        expect(manager.getWindowsForDocument('doc2').length, 2);
        expect(manager.windows.length, 4);
      });

      test('closes document without affecting other documents', () async {
        manager = WindowManager(
          onConfirmClose: (docId) async => true,
        );

        // Document 1
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));
        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art1');

        // Document 2
        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc2',
          type: WindowType.navigator,
          documentId: 'doc2',
        ));
        await manager.openArtboardWindow(documentId: 'doc2', artboardId: 'art1');

        // Close document 1
        await manager.closeDocument('doc1');

        expect(manager.getWindowsForDocument('doc1').length, 0);
        expect(manager.getWindowsForDocument('doc2').length, 2);
      });
    });

    group('Journey 15: Per-Artboard Viewport Persistence', () {
      test('simulates viewport persistence across window close/reopen', () async {
        ViewportSnapshot? persistedViewport;

        manager = WindowManager(
          onPersistViewportState: (docId, artId, viewport) async {
            persistedViewport = viewport;
          },
        );

        // Open artboard with initial viewport
        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
          initialViewportState: ViewportSnapshot(
            panOffset: Offset.zero,
            zoom: 1.0,
          ),
        );

        // User zooms to 200% and pans
        manager.updateWindow(
          'art-doc1-art1',
          viewportState: ViewportSnapshot(
            panOffset: Offset(100, 50),
            zoom: 2.0,
          ),
        );

        // User closes window
        await manager.requestCloseArtboard('doc1', 'art1');

        // Should have persisted the 200% zoom state
        expect(persistedViewport, isNotNull);
        expect(persistedViewport!.zoom, 2.0);
        expect(persistedViewport!.panOffset, Offset(100, 50));

        // User reopens artboard with persisted state
        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
          initialViewportState: persistedViewport,
        );

        final reopened = manager.getWindow('art-doc1-art1');
        expect(reopened?.lastViewportState?.zoom, 2.0);
        expect(reopened?.lastViewportState?.panOffset, Offset(100, 50));
      });
    });

    group('Journey 18: Artboard Window Lifecycle', () {
      test('artboard window closes silently without prompt', () async {
        bool confirmCalled = false;

        manager = WindowManager(
          onConfirmClose: (docId) async {
            confirmCalled = true;
            return true;
          },
        );

        await manager.openArtboardWindow(
          documentId: 'doc1',
          artboardId: 'art1',
        );

        await manager.requestCloseArtboard('doc1', 'art1');

        // Confirmation should NOT be called for artboard windows
        expect(confirmCalled, false);
        expect(manager.isArtboardWindowOpen('doc1', 'art1'), false);
      });

      test('Navigator close prompts and closes all artboards', () async {
        String? promptedDocId;
        int artboardCountAtPrompt = 0;

        manager = WindowManager(
          onConfirmClose: (docId) async {
            promptedDocId = docId;
            artboardCountAtPrompt =
                manager.getArtboardWindowsForDocument(docId).length;
            return true; // User confirms
          },
        );

        await manager.registerWindow(WindowDescriptor(
          windowId: 'nav-doc1',
          type: WindowType.navigator,
          documentId: 'doc1',
        ));

        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art1');
        await manager.openArtboardWindow(documentId: 'doc1', artboardId: 'art2');

        await manager.requestCloseNavigator('doc1');

        expect(promptedDocId, 'doc1');
        expect(artboardCountAtPrompt, 2); // Should know about 2 artboards
        expect(manager.hasWindowsForDocument('doc1'), false); // All closed
      });
    });
  });

  group('ViewportSnapshot', () {
    test('serializes to JSON', () {
      final snapshot = ViewportSnapshot(
        panOffset: Offset(123.5, 456.7),
        zoom: 1.8,
      );

      final json = snapshot.toJson();

      expect(json['panX'], 123.5);
      expect(json['panY'], 456.7);
      expect(json['zoom'], 1.8);
    });

    test('deserializes from JSON', () {
      final json = {
        'panX': 200.0,
        'panY': 150.0,
        'zoom': 2.5,
      };

      final snapshot = ViewportSnapshot.fromJson(json);

      expect(snapshot.panOffset.dx, 200.0);
      expect(snapshot.panOffset.dy, 150.0);
      expect(snapshot.zoom, 2.5);
    });

    test('handles missing JSON fields with defaults', () {
      final json = <String, dynamic>{};

      final snapshot = ViewportSnapshot.fromJson(json);

      expect(snapshot.panOffset, Offset.zero);
      expect(snapshot.zoom, 1.0);
    });
  });
}
