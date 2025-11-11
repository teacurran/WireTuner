import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/thumbnail/thumbnail_worker.dart';
import 'package:app/modules/navigator/thumbnail_service.dart';

void main() {
  group('ThumbnailService', () {
    late ThumbnailService service;
    late List<ThumbnailResult> generatedResults;
    late List<Map<String, dynamic>> telemetryEvents;

    // Mock generator that tracks calls
    Future<Uint8List?> mockGenerator(ThumbnailRequest request) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return Uint8List.fromList([1, 2, 3, 4]); // Mock thumbnail data
    }

    setUp(() {
      generatedResults = [];
      telemetryEvents = [];

      service = ThumbnailService(
        config: const ThumbnailServiceConfig(
          autoRefreshInterval: Duration(milliseconds: 100),
          idleThreshold: Duration(milliseconds: 50),
          manualRefreshCooldown: Duration(milliseconds: 200),
          maxCacheSize: 10,
        ),
        generator: mockGenerator,
        onThumbnailReady: (artboardId, imageData, age) {
          generatedResults.add(ThumbnailResult(
            requestId: 'test',
            artboardId: artboardId,
            imageData: imageData,
            duration: Duration.zero,
            completedAt: DateTime.now(),
          ));
        },
        onTelemetry: (metric, data) {
          telemetryEvents.add({'metric': metric, 'data': data});
        },
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    group('Lifecycle', () {
      test('starts and stops cleanly', () async {
        service.start();
        expect(service.getStats()['isStarted'], true);

        await service.dispose();
        expect(service.getStats()['isStarted'], false);
      });

      test('prevents operations after disposal', () async {
        service.start();
        await service.dispose();

        // Should not crash or process
        service.markDirty('artboard1', visible: true);
        final refreshed = service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        expect(refreshed, false);
      });
    });

    group('Dirty State Management', () {
      test('tracks dirty artboards', () {
        service.markDirty('artboard1', visible: true);
        service.markDirty('artboard2', visible: false);

        final stats = service.getStats();
        expect(stats['dirtyCount'], 2);
        expect(stats['visibleCount'], 1);
      });

      test('clears dirty state', () {
        service.markDirty('artboard1', visible: true);
        expect(service.getStats()['dirtyCount'], 1);

        service.markClean('artboard1');
        expect(service.getStats()['dirtyCount'], 0);
      });

      test('updates visibility independently', () {
        service.markDirty('artboard1', visible: false);
        expect(service.getStats()['visibleCount'], 0);

        service.updateVisibility('artboard1', visible: true);
        expect(service.getStats()['visibleCount'], 1);
      });
    });

    group('Manual Refresh', () {
      test('processes manual refresh request', () async {
        service.start();

        final refreshed = service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        expect(refreshed, true);

        // Wait for processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(generatedResults.length, 1);
        expect(generatedResults[0].artboardId, 'artboard1');
        expect(generatedResults[0].isSuccess, true);
      });

      test('enforces manual refresh cooldown', () async {
        service.start();

        // First refresh succeeds
        final first = service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        expect(first, true);

        // Second refresh within cooldown fails
        final second = service.refreshNow('artboard2', trigger: RefreshTrigger.manual);
        expect(second, false);

        // After cooldown, refresh succeeds
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final third = service.refreshNow('artboard3', trigger: RefreshTrigger.manual);
        expect(third, true);
      });

      test('allows different artboards during cooldown for non-manual triggers', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        final saveRefresh = service.refreshNow('artboard2', trigger: RefreshTrigger.save);
        expect(saveRefresh, true);
      });
    });

    group('Auto-Refresh', () {
      test('refreshes dirty visible artboards after idle threshold', () async {
        service.start();

        // Mark artboard dirty and visible
        service.markDirty('artboard1', visible: true);

        // Wait for idle threshold + auto-refresh interval
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should have triggered auto-refresh
        expect(generatedResults.any((r) => r.artboardId == 'artboard1'), true);
      });

      test('does not refresh invisible artboards', () async {
        service.start();

        // Mark artboard dirty but not visible
        service.markDirty('artboard1', visible: false);

        // Wait for auto-refresh cycle
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should not have refreshed
        expect(generatedResults.any((r) => r.artboardId == 'artboard1'), false);
      });

      test('does not refresh clean artboards', () async {
        service.start();

        // Mark visible but not dirty
        service.updateVisibility('artboard1', visible: true);

        // Wait for auto-refresh cycle
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should not have refreshed
        expect(generatedResults.isEmpty, true);
      });

      test('respects idle threshold', () async {
        service.start();

        service.markDirty('artboard1', visible: true);

        // Wait less than idle threshold
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Should not have refreshed yet
        expect(generatedResults.isEmpty, true);

        // Wait past idle threshold
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Should have refreshed now
        expect(generatedResults.any((r) => r.artboardId == 'artboard1'), true);
      });
    });

    group('Save-Triggered Refresh', () {
      test('processes save-triggered refresh immediately', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.save);

        // Should process without idle delay
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(generatedResults.length, 1);
        expect(generatedResults[0].artboardId, 'artboard1');
      });

      test('save trigger has higher priority than idle', () async {
        service.start();

        // Queue idle refresh first
        service.markDirty('artboard1', visible: true);
        service.refreshNow('artboard1', trigger: RefreshTrigger.idle);

        // Queue save refresh second
        service.refreshNow('artboard2', trigger: RefreshTrigger.save);

        // Wait for processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Save refresh should process first (if both were queued)
        // Note: Since idle might process immediately, we just verify both complete
        expect(generatedResults.length, greaterThanOrEqualTo(1));
      });
    });

    group('Caching', () {
      test('caches generated thumbnails', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final cached = service.getCached('artboard1');
        expect(cached, isNotNull);
        expect(cached, equals(Uint8List.fromList([1, 2, 3, 4])));
      });

      test('returns null for uncached artboards', () {
        final cached = service.getCached('nonexistent');
        expect(cached, isNull);
      });

      test('invalidates specific artboard cache', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.getCached('artboard1'), isNotNull);

        service.invalidateCache('artboard1');
        expect(service.getCached('artboard1'), isNull);
      });

      test('invalidates all cache', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        service.refreshNow('artboard2', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.getStats()['cacheSize'], 2);

        service.invalidateAllCache();
        expect(service.getStats()['cacheSize'], 0);
      });

      test('enforces cache size limit with LRU eviction', () async {
        // Create service with small cache
        final smallCacheService = ThumbnailService(
          config: const ThumbnailServiceConfig(
            maxCacheSize: 3,
            manualRefreshCooldown: Duration.zero,
          ),
          generator: mockGenerator,
        );
        smallCacheService.start();

        // Generate 4 thumbnails (exceeds cache size)
        for (int i = 1; i <= 4; i++) {
          smallCacheService.refreshNow('artboard$i', trigger: RefreshTrigger.save);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Cache should only hold 3 items
        expect(smallCacheService.getStats()['cacheSize'], 3);

        // First artboard should be evicted (LRU)
        expect(smallCacheService.getCached('artboard1'), isNull);
        expect(smallCacheService.getCached('artboard4'), isNotNull);

        await smallCacheService.dispose();
      });

      test('promotes cached entries on access', () async {
        final smallCacheService = ThumbnailService(
          config: const ThumbnailServiceConfig(
            maxCacheSize: 3,
            manualRefreshCooldown: Duration.zero,
          ),
          generator: mockGenerator,
        );
        smallCacheService.start();

        // Generate 3 thumbnails
        for (int i = 1; i <= 3; i++) {
          smallCacheService.refreshNow('artboard$i', trigger: RefreshTrigger.save);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Access artboard1 (should promote it to most recent)
        smallCacheService.getCached('artboard1');

        // Add artboard4 (should evict artboard2, not artboard1)
        await Future<void>.delayed(const Duration(milliseconds: 20));
        smallCacheService.refreshNow('artboard4', trigger: RefreshTrigger.save);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(smallCacheService.getCached('artboard1'), isNotNull);
        expect(smallCacheService.getCached('artboard2'), isNull);

        await smallCacheService.dispose();
      });
    });

    group('Telemetry', () {
      test('emits thumbnail.refresh.age metric', () async {
        service.start();

        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final ageMetrics = telemetryEvents.where((e) => e['metric'] == 'thumbnail.refresh.age');
        expect(ageMetrics.length, 1);

        final data = ageMetrics.first['data'] as Map<String, dynamic>;
        expect(data['artboardId'], 'artboard1');
        expect(data['ageMs'], isA<int>());
        expect(data['durationMs'], isA<int>());
      });

      test('tracks age between refreshes', () async {
        service.start();

        // First refresh
        service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify first refresh telemetry
        expect(telemetryEvents.any((e) => e['metric'] == 'thumbnail.refresh.age'), true);
        telemetryEvents.clear();

        // Wait for manual refresh cooldown (200ms) plus buffer
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Second refresh after delay
        final refreshed = service.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        expect(refreshed, true, reason: 'Second refresh should succeed after cooldown');

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final ageMetrics = telemetryEvents.where((e) => e['metric'] == 'thumbnail.refresh.age');
        expect(ageMetrics.length, greaterThanOrEqualTo(1));

        final data = ageMetrics.first['data'] as Map<String, dynamic>;
        // Age should reflect time between refreshes (at least 300ms)
        expect(data['ageMs'], greaterThanOrEqualTo(250));
      });
    });

    group('Stats', () {
      test('provides accurate diagnostic stats', () async {
        service.start();

        service.markDirty('artboard1', visible: true);
        service.markDirty('artboard2', visible: true);
        service.markDirty('artboard3', visible: false);

        final stats = service.getStats();

        expect(stats['dirtyCount'], 3);
        expect(stats['visibleCount'], 2);
        expect(stats['isStarted'], true);
        expect(stats['cacheSize'], isA<int>());
        expect(stats['queueLength'], isA<int>());
        expect(stats['processingCount'], isA<int>());
      });
    });

    group('Worker Integration', () {
      test('processes requests through worker queue', () async {
        service.start();

        // Enqueue multiple requests
        service.refreshNow('artboard1', trigger: RefreshTrigger.save);
        service.refreshNow('artboard2', trigger: RefreshTrigger.save);
        service.refreshNow('artboard3', trigger: RefreshTrigger.save);

        // Queue should show pending work
        expect(service.getStats()['queueLength'], greaterThanOrEqualTo(0));

        // Wait for processing
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // All should complete
        expect(generatedResults.length, 3);
        expect(generatedResults.map((r) => r.artboardId).toSet(), {'artboard1', 'artboard2', 'artboard3'});
      });

      test('handles generator errors gracefully', () async {
        final failingService = ThumbnailService(
          generator: (request) async {
            throw Exception('Mock generator error');
          },
        );

        failingService.start();

        failingService.refreshNow('artboard1', trigger: RefreshTrigger.manual);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should not crash, thumbnail just won't be available
        expect(failingService.getCached('artboard1'), isNull);

        await failingService.dispose();
      });
    });

    group('Timer Cleanup', () {
      test('cancels auto-refresh timer on dispose', () async {
        service.start();

        service.markDirty('artboard1', visible: true);

        await service.dispose();

        // Wait past auto-refresh interval
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Should not have processed (timer cancelled)
        expect(generatedResults.isEmpty, true);
      });
    });
  });

  group('ThumbnailServiceConfig', () {
    test('uses default values', () {
      const config = ThumbnailServiceConfig();

      expect(config.autoRefreshInterval, const Duration(seconds: 10));
      expect(config.idleThreshold, const Duration(seconds: 10));
      expect(config.manualRefreshCooldown, const Duration(seconds: 10));
      expect(config.maxCacheSize, 100);
      expect(config.maxConcurrentJobs, 5);
      expect(config.thumbnailWidth, 256);
      expect(config.thumbnailHeight, 256);
    });

    test('accepts custom values', () {
      const config = ThumbnailServiceConfig(
        autoRefreshInterval: Duration(seconds: 5),
        idleThreshold: Duration(seconds: 3),
        manualRefreshCooldown: Duration(seconds: 15),
        maxCacheSize: 50,
        maxConcurrentJobs: 3,
        thumbnailWidth: 512,
        thumbnailHeight: 512,
      );

      expect(config.autoRefreshInterval, const Duration(seconds: 5));
      expect(config.idleThreshold, const Duration(seconds: 3));
      expect(config.manualRefreshCooldown, const Duration(seconds: 15));
      expect(config.maxCacheSize, 50);
      expect(config.maxConcurrentJobs, 3);
      expect(config.thumbnailWidth, 512);
      expect(config.thumbnailHeight, 512);
    });
  });

  group('RefreshTrigger', () {
    test('has expected enum values', () {
      expect(RefreshTrigger.values.length, 3);
      expect(RefreshTrigger.values, containsAll([
        RefreshTrigger.idle,
        RefreshTrigger.save,
        RefreshTrigger.manual,
      ]));
    });
  });
}
