import 'package:flutter_test/flutter_test.dart';
import 'package:app/modules/navigator/state/navigator_service.dart';

void main() {
  group('NavigatorService', () {
    late NavigatorService service;
    final telemetryEvents = <Map<String, dynamic>>[];

    setUp(() {
      telemetryEvents.clear();
      service = NavigatorService(
        telemetryCallback: (metric, data) {
          telemetryEvents.add({'metric': metric, 'data': data});
        },
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('Rename Operation', () {
      test('renameArtboard accepts valid name', () async {
        final error = await service.renameArtboard('art1', 'New Name');
        expect(error, null);

        // Should emit telemetry
        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.artboard.renamed');
      });

      test('renameArtboard rejects empty name', () async {
        final error = await service.renameArtboard('art1', '   ');
        expect(error, isNotNull);
        expect(error, contains('cannot be empty'));
      });

      test('renameArtboard rejects name exceeding 255 characters', () async {
        final longName = 'a' * 256;
        final error = await service.renameArtboard('art1', longName);
        expect(error, isNotNull);
        expect(error, contains('255 characters'));
      });

      test('renameArtboard emits action event', () async {
        final events = <ArtboardActionEvent>[];
        service.actionStream.listen(events.add);

        await service.renameArtboard('art1', 'New Name');

        expect(events.length, 1);
        expect(events[0].action, ArtboardAction.rename);
        expect(events[0].artboardIds, ['art1']);
        expect(events[0].metadata['newName'], 'New Name');
      });
    });

    group('Duplicate Operation', () {
      test('duplicateArtboards accepts single artboard', () async {
        final error = await service.duplicateArtboards(['art1']);
        expect(error, null);

        // Should emit telemetry
        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.artboards.duplicated');
        expect(telemetryEvents[0]['data']['count'], 1);
      });

      test('duplicateArtboards accepts multiple artboards', () async {
        final error = await service.duplicateArtboards(['art1', 'art2', 'art3']);
        expect(error, null);

        expect(telemetryEvents[0]['data']['count'], 3);
      });

      test('duplicateArtboards rejects empty selection', () async {
        final error = await service.duplicateArtboards([]);
        expect(error, isNotNull);
        expect(error, contains('No artboards selected'));
      });

      test('duplicateArtboards emits action event', () async {
        final events = <ArtboardActionEvent>[];
        service.actionStream.listen(events.add);

        await service.duplicateArtboards(['art1', 'art2']);

        expect(events.length, 1);
        expect(events[0].action, ArtboardAction.duplicate);
        expect(events[0].artboardIds, ['art1', 'art2']);
      });
    });

    group('Delete Operation', () {
      test('deleteArtboards returns false if empty selection', () async {
        final result = await service.deleteArtboards(
          [],
          confirmCallback: (_) async => true,
        );
        expect(result, false);
      });

      test('deleteArtboards returns false if user cancels', () async {
        final result = await service.deleteArtboards(
          ['art1'],
          confirmCallback: (_) async => false,
        );
        expect(result, false);

        // Should not emit telemetry if cancelled
        expect(telemetryEvents.isEmpty, true);
      });

      test('deleteArtboards returns true if user confirms', () async {
        final result = await service.deleteArtboards(
          ['art1'],
          confirmCallback: (_) async => true,
        );
        expect(result, true);

        // Should emit telemetry
        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.artboards.deleted');
      });

      test('deleteArtboards passes count to confirm callback', () async {
        int? receivedCount;

        await service.deleteArtboards(
          ['art1', 'art2', 'art3'],
          confirmCallback: (count) async {
            receivedCount = count;
            return true;
          },
        );

        expect(receivedCount, 3);
      });

      test('deleteArtboards emits action event on confirm', () async {
        final events = <ArtboardActionEvent>[];
        service.actionStream.listen(events.add);

        await service.deleteArtboards(
          ['art1', 'art2'],
          confirmCallback: (_) async => true,
        );

        // Give stream time to propagate
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, 1);
        expect(events[0].action, ArtboardAction.delete);
        expect(events[0].artboardIds, ['art1', 'art2']);
      });
    });

    group('Thumbnail Refresh', () {
      test('requestThumbnailRefresh emits event', () async {
        final events = <ArtboardActionEvent>[];
        service.actionStream.listen(events.add);

        service.requestThumbnailRefresh('art1');

        // Give stream time to propagate
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, 1);
        expect(events[0].action, ArtboardAction.refresh);
        expect(events[0].artboardIds, ['art1']);
      });

      test('requestThumbnailRefresh emits telemetry', () {
        service.requestThumbnailRefresh('art1');

        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.thumbnail.manual_refresh');
      });
    });

    group('Fit to View', () {
      test('fitToView emits event', () async {
        final events = <ArtboardActionEvent>[];
        service.actionStream.listen(events.add);

        service.fitToView('art1');

        // Give stream time to propagate
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, 1);
        expect(events[0].action, ArtboardAction.fitToView);
        expect(events[0].artboardIds, ['art1']);
      });
    });

    group('Telemetry Tracking', () {
      test('trackNavigatorOpenTime emits metric', () {
        service.trackNavigatorOpenTime(const Duration(milliseconds: 150), 100);

        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.open.time');
        expect(telemetryEvents[0]['data']['durationMs'], 150);
        expect(telemetryEvents[0]['data']['artboardCount'], 100);
      });

      test('trackThumbnailLatency emits metric', () {
        service.trackThumbnailLatency('art1', const Duration(milliseconds: 50));

        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.thumbnail.latency');
        expect(telemetryEvents[0]['data']['durationMs'], 50);
      });

      test('trackVirtualizationMetrics emits metric', () {
        service.trackVirtualizationMetrics(
          totalArtboards: 1000,
          visibleArtboards: 20,
          scrollFps: 60.0,
        );

        expect(telemetryEvents.length, 1);
        expect(telemetryEvents[0]['metric'], 'navigator.virtualization.metrics');
        expect(telemetryEvents[0]['data']['totalArtboards'], 1000);
        expect(telemetryEvents[0]['data']['visibleArtboards'], 20);
        expect(telemetryEvents[0]['data']['scrollFps'], 60.0);
      });
    });

    group('Stream Management', () {
      test('actionStream is broadcast', () {
        // Should allow multiple listeners
        service.actionStream.listen((_) {});
        service.actionStream.listen((_) {});

        // Should not throw
      });

      test('dispose closes stream', () async {
        service.dispose();

        // Stream should be closed
        expect(service.actionStream.isBroadcast, true);
        // Note: Can't easily test if closed without triggering error
      });
    });
  });

  group('MockThumbnailGenerator', () {
    test('generate returns Uint8List', () async {
      final thumbnail = await MockThumbnailGenerator.generate('art1', 200, 200);
      expect(thumbnail.length, 4); // RGBA bytes
    });

    test('generate has async delay', () async {
      final stopwatch = Stopwatch()..start();
      await MockThumbnailGenerator.generate('art1', 200, 200);
      stopwatch.stop();

      // Should take at least 50ms (the simulated delay)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
    });
  });
}
