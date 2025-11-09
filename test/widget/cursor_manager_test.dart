import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/application/tools/framework/cursor_manager.dart';
import 'package:wiretuner/application/tools/framework/cursor_service.dart';

void main() {
  group('CursorManager Tests', () {
    group('Platform-Specific Cursor Mapping', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('macOS uses precise cursor for drawing tools', () {
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );

        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.precise),
        );
      });

      test('Windows uses basic cursor for drawing tools', () {
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.windows,
        );

        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.basic),
        );
      });

      test('Linux uses basic cursor for drawing tools', () {
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.linux,
        );

        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.basic),
        );
      });

      test('Non-precise cursors are platform-agnostic', () {
        // Test on macOS
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );

        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.click),
        );

        // Recreate for Windows
        cursorManager.dispose();
        cursorService.dispose();
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.windows,
        );

        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.click),
        );
      });
    });

    group('Context-Aware Cursor Selection', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('Hovering over handle shows move cursor', () {
        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
          context: const CursorContext(isHoveringHandle: true),
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.move),
        );
      });

      test('Dragging shows move cursor', () {
        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
          context: const CursorContext(isDragging: true),
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.move),
        );
      });

      test('Hovering over anchor shows precise cursor on macOS', () {
        cursorManager.setToolCursor(
          toolId: 'direct_selection',
          baseCursor: SystemMouseCursors.click,
          context: const CursorContext(isHoveringAnchor: true),
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.precise),
        );
      });

      test('Hovering over anchor shows basic cursor on Windows', () {
        cursorManager.dispose();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.windows,
        );

        cursorManager.setToolCursor(
          toolId: 'direct_selection',
          baseCursor: SystemMouseCursors.click,
          context: const CursorContext(isHoveringAnchor: true),
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.basic),
        );
      });

      test('Context overrides take priority over base cursor', () {
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
          context: const CursorContext(isDragging: true),
        );

        // Dragging override should take priority
        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.move),
        );
      });
    });

    group('Context Updates', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('updateContext changes cursor when context changes', () {
        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.click),
        );

        // Update context to hovering over handle
        cursorManager.updateContext(
          const CursorContext(isHoveringHandle: true),
        );

        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.move),
        );
      });

      test('updateContext does not trigger update for identical context', () {
        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        var notificationCount = 0;
        cursorManager.addListener(() => notificationCount++);

        // Update with identical context
        cursorManager.updateContext(const CursorContext());
        cursorManager.updateContext(const CursorContext());

        expect(notificationCount, equals(0));
      });

      test('updateContext notifies listeners when context changes', () {
        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        var notificationCount = 0;
        cursorManager.addListener(() => notificationCount++);

        cursorManager.updateContext(
          const CursorContext(isHoveringHandle: true),
        );

        expect(notificationCount, equals(1));
      });

      test('Context copyWith preserves unchanged fields', () {
        const original = CursorContext(
          isHoveringHandle: true,
          isSnapping: true,
        );

        final updated = original.copyWith(isDragging: true);

        expect(updated.isHoveringHandle, isTrue);
        expect(updated.isSnapping, isTrue);
        expect(updated.isDragging, isTrue);
        expect(updated.isAngleLocked, isFalse);
      });
    });

    group('Reset Behavior', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('reset clears tool cursor and context', () {
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
          context: const CursorContext(isSnapping: true),
        );

        cursorManager.reset();

        expect(cursorManager.activeToolId, isNull);
        expect(cursorManager.context, equals(const CursorContext()));
        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.basic),
        );
      });

      test('reset notifies listeners', () {
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        var notificationCount = 0;
        cursorManager.addListener(() => notificationCount++);

        cursorManager.reset();

        expect(notificationCount, equals(1));
      });
    });

    group('Frame Budget Compliance', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown() {
        cursorManager.dispose();
        cursorService.dispose();
      }

      test('cursor updates complete within 1ms', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          cursorManager.setToolCursor(
            toolId: 'pen',
            baseCursor: SystemMouseCursors.precise,
            context: CursorContext(isSnapping: i % 2 == 0),
          );
        }

        stopwatch.stop();

        // 100 updates should complete in <100ms total
        // (well within 16.67ms frame budget for each update)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('context updates complete within 1ms', () {
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          cursorManager.updateContext(
            CursorContext(isSnapping: i % 2 == 0),
          );
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('CursorContext Equality', () {
      test('identical contexts are equal', () {
        const context1 = CursorContext(
          isHoveringHandle: true,
          isSnapping: true,
        );
        const context2 = CursorContext(
          isHoveringHandle: true,
          isSnapping: true,
        );

        expect(context1, equals(context2));
        expect(context1.hashCode, equals(context2.hashCode));
      });

      test('different contexts are not equal', () {
        const context1 = CursorContext(isHoveringHandle: true);
        const context2 = CursorContext(isSnapping: true);

        expect(context1, isNot(equals(context2)));
      });
    });

    group('Integration with CursorService', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('cursor manager updates cursor service', () {
        var serviceNotificationCount = 0;
        cursorService.addListener(() => serviceNotificationCount++);

        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(serviceNotificationCount, equals(1));
        expect(
          cursorService.currentCursor,
          equals(SystemMouseCursors.precise),
        );
      });

      test('cursor manager respects cursor service batching', () {
        var serviceNotificationCount = 0;
        cursorService.addListener(() => serviceNotificationCount++);

        // Set same cursor multiple times
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        // Should only notify once (cursor service batches identical updates)
        expect(serviceNotificationCount, equals(1));
      });
    });

    group('Tool State Tracking', () {
      late CursorService cursorService;
      late CursorManager cursorManager;

      setUp(() {
        cursorService = CursorService();
        cursorManager = CursorManager(
          cursorService: cursorService,
          platform: TargetPlatform.macOS,
        );
      });

      tearDown(() {
        cursorManager.dispose();
        cursorService.dispose();
      });

      test('activeToolId tracks current tool', () {
        expect(cursorManager.activeToolId, isNull);

        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(cursorManager.activeToolId, equals('pen'));

        cursorManager.setToolCursor(
          toolId: 'selection',
          baseCursor: SystemMouseCursors.click,
        );

        expect(cursorManager.activeToolId, equals('selection'));
      });

      test('reset clears activeToolId', () {
        cursorManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(cursorManager.activeToolId, isNotNull);

        cursorManager.reset();

        expect(cursorManager.activeToolId, isNull);
      });
    });

    group('Platform Parity Requirements', () {
      test('macOS and Windows differ only on precise cursor', () {
        final macOSService = CursorService();
        final macOSManager = CursorManager(
          cursorService: macOSService,
          platform: TargetPlatform.macOS,
        );

        final windowsService = CursorService();
        final windowsManager = CursorManager(
          cursorService: windowsService,
          platform: TargetPlatform.windows,
        );

        // Test all common cursors except precise
        final testCursors = [
          SystemMouseCursors.basic,
          SystemMouseCursors.click,
          SystemMouseCursors.move,
          SystemMouseCursors.grab,
          SystemMouseCursors.grabbing,
        ];

        for (final cursor in testCursors) {
          macOSManager.setToolCursor(
            toolId: 'test',
            baseCursor: cursor,
          );

          windowsManager.setToolCursor(
            toolId: 'test',
            baseCursor: cursor,
          );

          expect(
            macOSService.currentCursor,
            equals(windowsService.currentCursor),
            reason: 'Cursor $cursor should be identical on both platforms',
          );
        }

        macOSManager.dispose();
        macOSService.dispose();
        windowsManager.dispose();
        windowsService.dispose();
      });

      test('precise cursor differs between macOS and Windows', () {
        final macOSService = CursorService();
        final macOSManager = CursorManager(
          cursorService: macOSService,
          platform: TargetPlatform.macOS,
        );

        final windowsService = CursorService();
        final windowsManager = CursorManager(
          cursorService: windowsService,
          platform: TargetPlatform.windows,
        );

        macOSManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        windowsManager.setToolCursor(
          toolId: 'pen',
          baseCursor: SystemMouseCursors.precise,
        );

        expect(
          macOSService.currentCursor,
          equals(SystemMouseCursors.precise),
        );

        expect(
          windowsService.currentCursor,
          equals(SystemMouseCursors.basic),
        );

        macOSManager.dispose();
        macOSService.dispose();
        windowsManager.dispose();
        windowsService.dispose();
      });
    });
  });
}
