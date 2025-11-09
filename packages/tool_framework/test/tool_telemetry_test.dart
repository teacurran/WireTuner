import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:tool_framework/src/tool_telemetry.dart';

void main() {
  group('ToolTelemetry', () {
    late Logger logger;
    late EventCoreDiagnosticsConfig config;
    late ToolTelemetry telemetry;

    setUp(() {
      logger = Logger(level: Level.debug);
      config = EventCoreDiagnosticsConfig.debug();
      telemetry = ToolTelemetry(logger: logger, config: config);
    });

    tearDown(() {
      telemetry.dispose();
    });

    group('Undo Group Lifecycle', () {
      test('startUndoGroup returns valid groupId', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        expect(groupId, isNotEmpty);
        expect(groupId, startsWith('undo-pen-'));
      });

      test('startUndoGroup throws if group already active', () {
        telemetry.startUndoGroup(toolId: 'pen', label: 'Create Path');

        expect(
          () => telemetry.startUndoGroup(toolId: 'pen', label: 'Create Path'),
          throwsStateError,
        );
      });

      test('endUndoGroup succeeds with matching groupId', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        expect(
          () => telemetry.endUndoGroup(
            toolId: 'pen',
            groupId: groupId,
            label: 'Create Path',
          ),
          returnsNormally,
        );
      });

      test('endUndoGroup throws if no group active', () {
        expect(
          () => telemetry.endUndoGroup(
            toolId: 'pen',
            groupId: 'fake-group-id',
            label: 'Create Path',
          ),
          throwsStateError,
        );
      });

      test('endUndoGroup throws if groupId mismatch', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        expect(
          () => telemetry.endUndoGroup(
            toolId: 'pen',
            groupId: 'wrong-group-id',
            label: 'Create Path',
          ),
          throwsStateError,
        );
      });

      test('multiple tools can have active groups simultaneously', () {
        final penGroupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        final selectionGroupId = telemetry.startUndoGroup(
          toolId: 'selection',
          label: 'Move Objects',
        );

        expect(penGroupId, isNot(equals(selectionGroupId)));

        // Both can end successfully
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: penGroupId,
          label: 'Create Path',
        );

        telemetry.endUndoGroup(
          toolId: 'selection',
          groupId: selectionGroupId,
          label: 'Move Objects',
        );
      });
    });

    group('Sample Recording', () {
      test('recordSample increments sample count', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');
        telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');
        telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');

        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        final metrics = telemetry.getMetrics();
        expect(metrics['sampleCounts']['pen'], equals(3));
      });

      test('recordSample tracks operation counts by event type', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'direct_selection',
          label: 'Move Anchor',
        );

        telemetry.recordSample(
          toolId: 'direct_selection',
          eventType: 'ModifyAnchorEvent',
        );
        telemetry.recordSample(
          toolId: 'direct_selection',
          eventType: 'ModifyAnchorEvent',
        );
        telemetry.recordSample(
          toolId: 'direct_selection',
          eventType: 'ModifyHandleEvent',
        );

        telemetry.endUndoGroup(
          toolId: 'direct_selection',
          groupId: groupId,
          label: 'Move Anchor',
        );

        final metrics = telemetry.getMetrics();
        final opCounts = metrics['operationCounts']['direct_selection'];
        expect(opCounts['ModifyAnchorEvent'], equals(2));
        expect(opCounts['ModifyHandleEvent'], equals(1));
      });

      test('recordSample without active group logs warning', () {
        // This should log a warning but not throw
        expect(
          () => telemetry.recordSample(
            toolId: 'pen',
            eventType: 'AddAnchorEvent',
          ),
          returnsNormally,
        );
      });
    });

    group('Activation Tracking', () {
      test('recordActivation increments activation count', () {
        telemetry.recordActivation('pen');
        telemetry.recordActivation('pen');
        telemetry.recordActivation('selection');

        final metrics = telemetry.getMetrics();
        expect(metrics['activationCounts']['pen'], equals(2));
        expect(metrics['activationCounts']['selection'], equals(1));
      });
    });

    group('Undo Label Management', () {
      test('endUndoGroup stores last completed label', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        expect(
          telemetry.getLastCompletedLabel('pen'),
          equals('Create Path'),
        );
      });

      test('labels are tool-specific', () {
        final penGroupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: penGroupId,
          label: 'Create Path',
        );

        final selectionGroupId = telemetry.startUndoGroup(
          toolId: 'selection',
          label: 'Move Objects',
        );
        telemetry.endUndoGroup(
          toolId: 'selection',
          groupId: selectionGroupId,
          label: 'Move Objects',
        );

        expect(
          telemetry.getLastCompletedLabel('pen'),
          equals('Create Path'),
        );
        expect(
          telemetry.getLastCompletedLabel('selection'),
          equals('Move Objects'),
        );
      });

      test('getLastCompletedLabel returns null if no operations completed', () {
        expect(telemetry.getLastCompletedLabel('pen'), isNull);
      });

      test('allLastCompletedLabels returns all labels', () {
        final penGroupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: penGroupId,
          label: 'Create Path',
        );

        final selectionGroupId = telemetry.startUndoGroup(
          toolId: 'selection',
          label: 'Move Objects',
        );
        telemetry.endUndoGroup(
          toolId: 'selection',
          groupId: selectionGroupId,
          label: 'Move Objects',
        );

        final labels = telemetry.allLastCompletedLabels;
        expect(labels['pen'], equals('Create Path'));
        expect(labels['selection'], equals('Move Objects'));
        expect(labels.length, equals(2));
      });

      test('labels persist across flush calls', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        telemetry.flush();

        expect(
          telemetry.getLastCompletedLabel('pen'),
          equals('Create Path'),
        );
      });
    });

    group('Flush Behavior', () {
      test('flush resets activation counts', () async {
        telemetry.recordActivation('pen');
        telemetry.recordActivation('selection');

        await telemetry.flush();

        final metrics = telemetry.getMetrics();
        expect(metrics['activationCounts'], isEmpty);
      });

      test('flush resets sample counts', () async {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        await telemetry.flush();

        final metrics = telemetry.getMetrics();
        expect(metrics['sampleCounts'], isEmpty);
      });

      test('flush resets operation counts', () async {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        await telemetry.flush();

        final metrics = telemetry.getMetrics();
        expect(metrics['operationCounts'], isEmpty);
      });

      test('flush resets undo group completion counts', () async {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        await telemetry.flush();

        final metrics = telemetry.getMetrics();
        expect(metrics['undoGroupCompletions'], isEmpty);
      });

      test('flush does not clear last completed labels', () async {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        await telemetry.flush();

        expect(
          telemetry.getLastCompletedLabel('pen'),
          equals('Create Path'),
        );
      });

      test('flush does not clear active undo groups', () async {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        await telemetry.flush();

        final metrics = telemetry.getMetrics();
        expect(metrics['activeUndoGroups']['pen'], equals(groupId));
      });
    });

    group('ChangeNotifier Integration', () {
      test('endUndoGroup triggers notifyListeners', () {
        var notified = false;
        telemetry.addListener(() {
          notified = true;
        });

        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        notified = false; // Reset after startUndoGroup

        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        expect(notified, isTrue);
      });
    });

    group('Metrics Disabled Mode', () {
      test('operations are no-op when metrics disabled', () {
        final disabledTelemetry = ToolTelemetry(
          logger: logger,
          config: EventCoreDiagnosticsConfig.silent(),
        );

        final groupId = disabledTelemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        expect(groupId, isEmpty);

        disabledTelemetry.recordSample(
          toolId: 'pen',
          eventType: 'AddAnchorEvent',
        );

        disabledTelemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        final metrics = disabledTelemetry.getMetrics();
        expect(metrics['sampleCounts'], isEmpty);
        expect(metrics['activationCounts'], isEmpty);

        disabledTelemetry.dispose();
      });
    });

    group('Edge Cases', () {
      test('excessive sample count logs warning', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );

        // Emit 101 samples to trigger warning
        for (var i = 0; i < 101; i++) {
          telemetry.recordSample(toolId: 'pen', eventType: 'AddAnchorEvent');
        }

        // Should log warning but not throw
        expect(
          () => telemetry.endUndoGroup(
            toolId: 'pen',
            groupId: groupId,
            label: 'Create Path',
          ),
          returnsNormally,
        );
      });

      test('getMetrics returns immutable maps', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        final metrics = telemetry.getMetrics();
        final labels = metrics['lastCompletedLabels'] as Map;

        // Attempting to modify should throw
        expect(
          () => labels['fake'] = 'Fake Label',
          throwsUnsupportedError,
        );
      });

      test('dispose with active groups logs warning', () {
        // Create a separate telemetry instance for this test
        // to avoid interfering with tearDown
        final testTelemetry = ToolTelemetry(
          logger: logger,
          config: config,
        );

        testTelemetry.startUndoGroup(toolId: 'pen', label: 'Create Path');

        // Should log warning but not throw
        expect(() => testTelemetry.dispose(), returnsNormally);
      });
    });

    group('Tool-Specific Labels', () {
      test('pen tool labels', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'pen',
          label: 'Create Path',
        );
        telemetry.endUndoGroup(
          toolId: 'pen',
          groupId: groupId,
          label: 'Create Path',
        );

        expect(
          telemetry.getLastCompletedLabel('pen'),
          equals('Create Path'),
        );
      });

      test('selection tool labels', () {
        final groupId = telemetry.startUndoGroup(
          toolId: 'selection',
          label: 'Move Objects',
        );
        telemetry.endUndoGroup(
          toolId: 'selection',
          groupId: groupId,
          label: 'Move Objects',
        );

        expect(
          telemetry.getLastCompletedLabel('selection'),
          equals('Move Objects'),
        );
      });

      test('direct selection tool labels', () {
        final moveAnchorGroupId = telemetry.startUndoGroup(
          toolId: 'direct_selection',
          label: 'Move Anchor',
        );
        telemetry.endUndoGroup(
          toolId: 'direct_selection',
          groupId: moveAnchorGroupId,
          label: 'Move Anchor',
        );

        expect(
          telemetry.getLastCompletedLabel('direct_selection'),
          equals('Move Anchor'),
        );

        final adjustHandleGroupId = telemetry.startUndoGroup(
          toolId: 'direct_selection',
          label: 'Adjust Handle',
        );
        telemetry.endUndoGroup(
          toolId: 'direct_selection',
          groupId: adjustHandleGroupId,
          label: 'Adjust Handle',
        );

        expect(
          telemetry.getLastCompletedLabel('direct_selection'),
          equals('Adjust Handle'),
        );
      });

      test('shape tool labels', () {
        final rectangleGroupId = telemetry.startUndoGroup(
          toolId: 'rectangle',
          label: 'Create Rectangle',
        );
        telemetry.endUndoGroup(
          toolId: 'rectangle',
          groupId: rectangleGroupId,
          label: 'Create Rectangle',
        );

        expect(
          telemetry.getLastCompletedLabel('rectangle'),
          equals('Create Rectangle'),
        );

        final ellipseGroupId = telemetry.startUndoGroup(
          toolId: 'ellipse',
          label: 'Create Ellipse',
        );
        telemetry.endUndoGroup(
          toolId: 'ellipse',
          groupId: ellipseGroupId,
          label: 'Create Ellipse',
        );

        expect(
          telemetry.getLastCompletedLabel('ellipse'),
          equals('Create Ellipse'),
        );
      });
    });
  });
}
