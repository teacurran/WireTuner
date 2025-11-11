import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart' as event_base;
import 'package:wiretuner/domain/models/geometry/rectangle.dart';
import 'package:wiretuner/presentation/canvas/viewport/nudge_service.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

void main() {
  group('NudgeService', () {
    late NudgeService nudgeService;
    late ViewportController controller;
    String? lastToastMessage;

    setUp(() {
      controller = ViewportController();
      lastToastMessage = null;
      nudgeService = NudgeService(
        controller: controller,
        config: const NudgeConfig(
          nudgeDistance: 1.0,
          largeNudgeDistance: 10.0,
          overshootThreshold: 50.0,
        ),
        onToast: (message) => lastToastMessage = message,
      );
    });

    tearDown(() {
      nudgeService.dispose();
    });

    group('Configuration', () {
      test('initializes with default config', () {
        final service = NudgeService(controller: controller);
        expect(service.config.nudgeDistance, equals(1.0));
        expect(service.config.largeNudgeDistance, equals(10.0));
      });

      test('allows config updates', () {
        nudgeService.config = const NudgeConfig(
          nudgeDistance: 2.0,
          largeNudgeDistance: 20.0,
        );

        expect(nudgeService.config.nudgeDistance, equals(2.0));
        expect(nudgeService.config.largeNudgeDistance, equals(20.0));
      });

      test('copyWith creates modified config', () {
        final original = const NudgeConfig(
          nudgeDistance: 1.0,
          largeNudgeDistance: 10.0,
          overshootThreshold: 50.0,
        );

        final modified = original.copyWith(nudgeDistance: 2.0);

        expect(modified.nudgeDistance, equals(2.0));
        expect(modified.largeNudgeDistance, equals(10.0));
        expect(modified.overshootThreshold, equals(50.0));
      });
    });

    group('Basic Nudging', () {
      test('nudge right creates positive X delta', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
        );

        expect(result.delta.x, equals(1.0));
        expect(result.delta.y, equals(0.0));
        expect(result.overshoot, isFalse);
      });

      test('nudge left creates negative X delta', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.left,
          largeNudge: false,
        );

        expect(result.delta.x, equals(-1.0));
        expect(result.delta.y, equals(0.0));
      });

      test('nudge down creates positive Y delta', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.down,
          largeNudge: false,
        );

        expect(result.delta.x, equals(0.0));
        expect(result.delta.y, equals(1.0));
      });

      test('nudge up creates negative Y delta', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.up,
          largeNudge: false,
        );

        expect(result.delta.x, equals(0.0));
        expect(result.delta.y, equals(-1.0));
      });

      test('large nudge uses larger distance', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: true,
        );

        expect(result.delta.x, equals(10.0));
        expect(result.delta.y, equals(0.0));
      });
    });

    group('Screen-Space Nudging', () {
      test('nudge distance adjusts with zoom', () {
        controller.setZoom(2.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
        );

        // 1px screen = 0.5 world units at zoom 2.0
        expect(result.delta.x, equals(0.5));
      });

      test('nudge distance adjusts with zoom out', () {
        controller.setZoom(0.5);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
        );

        // 1px screen = 2 world units at zoom 0.5
        expect(result.delta.x, equals(2.0));
      });

      test('large nudge maintains screen-space consistency', () {
        controller.setZoom(2.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: true,
        );

        // 10px screen = 5 world units at zoom 2.0
        expect(result.delta.x, equals(5.0));
      });
    });

    group('Cumulative Tracking', () {
      test('tracks cumulative delta within grouping window', () async {
        controller.setZoom(1.0);

        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        expect(nudgeService.cumulativeDelta.x, equals(1.0));

        await Future.delayed(const Duration(milliseconds: 50));
        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        expect(nudgeService.cumulativeDelta.x, equals(2.0));

        await Future.delayed(const Duration(milliseconds: 50));
        nudgeService.nudge(direction: NudgeDirection.down, largeNudge: false);
        expect(nudgeService.cumulativeDelta.x, equals(2.0));
        expect(nudgeService.cumulativeDelta.y, equals(1.0));
      });

      test('resets cumulative tracking after window expires', () async {
        controller.setZoom(1.0);

        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        expect(nudgeService.cumulativeDelta.x, equals(1.0));

        // Wait for grouping window to expire (200ms + buffer)
        await Future.delayed(const Duration(milliseconds: 250));

        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        expect(nudgeService.cumulativeDelta.x, equals(1.0)); // Reset
      });

      test('isGroupingActive returns true within window', () async {
        controller.setZoom(1.0);

        expect(nudgeService.isGroupingActive, isFalse);

        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        expect(nudgeService.isGroupingActive, isTrue);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(nudgeService.isGroupingActive, isTrue);

        await Future.delayed(const Duration(milliseconds: 200));
        expect(nudgeService.isGroupingActive, isFalse);
      });

      test('cumulative tracking works in multiple directions', () async {
        controller.setZoom(1.0);

        nudgeService.nudge(direction: NudgeDirection.right, largeNudge: false);
        await Future.delayed(const Duration(milliseconds: 50));
        nudgeService.nudge(direction: NudgeDirection.left, largeNudge: false);
        await Future.delayed(const Duration(milliseconds: 50));
        nudgeService.nudge(direction: NudgeDirection.down, largeNudge: false);

        // Right +1, Left -1, Down +1
        expect(nudgeService.cumulativeDelta.x, equals(0.0));
        expect(nudgeService.cumulativeDelta.y, equals(1.0));
      });
    });

    group('Overshoot Detection', () {
      test('detects right edge overshoot', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 800, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        // Content right edge at 1000, artboard right edge at 900
        // Moving right will overshoot by 100 units
        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isTrue);
        expect(result.overshootMessage, isNotNull);
        expect(result.overshootMessage, contains('right'));
        expect(lastToastMessage, isNotNull);
      });

      test('detects left edge overshoot', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: -40, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        // Content left edge at -40, artboard left edge at 0
        // Already overshooting by 40 units, moving left makes it worse
        final result = nudgeService.nudge(
          direction: NudgeDirection.left,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        // Should not detect yet as threshold is 50
        expect(result.overshoot, isFalse);

        // Now move more to exceed threshold
        final result2 = nudgeService.nudge(
          direction: NudgeDirection.left,
          largeNudge: true, // 10 more units = 50 total
          contentBounds: const Rectangle(x: -50, y: 300, width: 200, height: 100),
          artboardBounds: artboardBounds,
        );

        expect(result2.overshoot, isTrue);
        expect(result2.overshootMessage, contains('left'));
      });

      test('detects top edge overshoot', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 400, y: -60, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        final result = nudgeService.nudge(
          direction: NudgeDirection.up,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isTrue);
        expect(result.overshootMessage, contains('top'));
      });

      test('detects bottom edge overshoot', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 400, y: 550, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        // Content bottom at 650, artboard bottom at 600
        final result = nudgeService.nudge(
          direction: NudgeDirection.down,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isTrue);
        expect(result.overshootMessage, contains('bottom'));
      });

      test('respects overshoot threshold', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 860, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        // Content right at 1060, artboard right at 900 = 160 overshoot (> 50 threshold)
        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isTrue);

        // Now test just under threshold
        final contentBounds2 = const Rectangle(x: 890, y: 300, width: 200, height: 100);
        // Content right at 1090, artboard right at 900 = 190 overshoot
        // But moving right by 1 doesn't add much
        final result2 = nudgeService.nudge(
          direction: NudgeDirection.left, // Move back in bounds
          largeNudge: false,
          contentBounds: contentBounds2,
          artboardBounds: artboardBounds,
        );

        expect(result2.overshoot, isTrue); // Still overshooting significantly
      });

      test('no overshoot when content within bounds', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 400, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isFalse);
        expect(result.overshootMessage, isNull);
        expect(lastToastMessage, isNull);
      });

      test('no overshoot detection when bounds not provided', () {
        controller.setZoom(1.0);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
        );

        expect(result.overshoot, isFalse);
        expect(result.overshootMessage, isNull);
      });
    });

    group('Toast Notifications', () {
      test('toast callback invoked on overshoot', () {
        controller.setZoom(1.0);
        lastToastMessage = null;

        final contentBounds = const Rectangle(x: 850, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(lastToastMessage, isNotNull);
        expect(lastToastMessage, contains('boundary'));
      });

      test('toast not invoked when no overshoot', () {
        controller.setZoom(1.0);
        lastToastMessage = null;

        final contentBounds = const Rectangle(x: 400, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(lastToastMessage, isNull);
      });

      test('toast includes overshoot distance', () {
        controller.setZoom(1.0);
        lastToastMessage = null;

        final contentBounds = const Rectangle(x: 900, y: 300, width: 200, height: 100);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        // Content right edge: 900 + 200 = 1100
        // After nudge: 1100 + 1 = 1101
        // Artboard right edge: 900
        // Overshoot: 1101 - 900 = 201
        expect(lastToastMessage, contains('201')); // 201 units overshoot
      });
    });

    group('Edge Cases', () {
      test('handles zero content bounds', () {
        controller.setZoom(1.0);

        final contentBounds = const Rectangle(x: 0, y: 0, width: 0, height: 0);
        final artboardBounds = const Rectangle(x: 0, y: 0, width: 900, height: 600);

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
          contentBounds: contentBounds,
          artboardBounds: artboardBounds,
        );

        expect(result.overshoot, isFalse);
      });

      test('handles extreme zoom levels', () {
        controller.setZoom(ViewportController.maxZoom); // 8.0

        final result = nudgeService.nudge(
          direction: NudgeDirection.right,
          largeNudge: false,
        );

        // 1px screen = 1/8 = 0.125 world units
        expect(result.delta.x, equals(0.125));
      });

      test('handles rapid consecutive nudges', () async {
        controller.setZoom(1.0);

        for (var i = 0; i < 10; i++) {
          final result = nudgeService.nudge(
            direction: NudgeDirection.right,
            largeNudge: false,
          );
          expect(result.delta.x, equals(1.0));
        }

        expect(nudgeService.cumulativeDelta.x, equals(10.0));
      });
    });
  });
}
