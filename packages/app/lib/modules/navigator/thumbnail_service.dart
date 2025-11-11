import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:core/thumbnail/thumbnail_worker.dart';

/// Cache entry for a single thumbnail.
class _ThumbnailCacheEntry {
  /// Cached thumbnail data (PNG bytes).
  final Uint8List imageData;

  /// When this thumbnail was generated.
  final DateTime generatedAt;

  /// Last time this entry was accessed.
  DateTime lastAccessedAt;

  _ThumbnailCacheEntry({
    required this.imageData,
    required this.generatedAt,
  }) : lastAccessedAt = generatedAt;

  /// Age of this thumbnail since generation.
  Duration get age => DateTime.now().difference(generatedAt);

  /// Time since last access.
  Duration get timeSinceAccess => DateTime.now().difference(lastAccessedAt);

  void markAccessed() {
    lastAccessedAt = DateTime.now();
  }
}

/// Refresh trigger types.
enum RefreshTrigger {
  /// Auto-refresh after idle period.
  idle,

  /// Refresh triggered by document save.
  save,

  /// Manual refresh requested by user.
  manual,
}

/// Configuration for thumbnail service behavior.
class ThumbnailServiceConfig {
  /// Auto-refresh interval (default: 10 seconds per FR-043).
  final Duration autoRefreshInterval;

  /// Idle time before auto-refresh (default: 10 seconds).
  final Duration idleThreshold;

  /// Manual refresh cooldown (default: 10 seconds per wireframe).
  final Duration manualRefreshCooldown;

  /// Maximum cache size (number of thumbnails).
  final int maxCacheSize;

  /// Maximum concurrent thumbnail generations.
  final int maxConcurrentJobs;

  /// Target thumbnail width in pixels.
  final int thumbnailWidth;

  /// Target thumbnail height in pixels.
  final int thumbnailHeight;

  const ThumbnailServiceConfig({
    this.autoRefreshInterval = const Duration(seconds: 10),
    this.idleThreshold = const Duration(seconds: 10),
    this.manualRefreshCooldown = const Duration(seconds: 10),
    this.maxCacheSize = 100,
    this.maxConcurrentJobs = 5,
    this.thumbnailWidth = 256,
    this.thumbnailHeight = 256,
  });
}

/// Service for managing thumbnail generation and caching for Navigator.
///
/// This service implements the thumbnail pipeline with three refresh triggers:
/// 1. **Auto-refresh**: Periodic refresh of dirty/visible artboards
/// 2. **Save-triggered**: Immediate refresh when document is saved
/// 3. **Manual refresh**: User-initiated refresh via toolbar/context menu
///
/// ## Features
///
/// - **Background worker**: Uses [ThumbnailWorker] for async generation
/// - **LRU caching**: Caches thumbnails per artboard with size limit
/// - **Queue management**: Prioritizes manual > save > auto refresh
/// - **Cooldown enforcement**: Prevents excessive manual refresh requests
/// - **Telemetry**: Emits `thumbnail.refresh.age` and latency metrics
///
/// ## Architecture
///
/// This service sits between [NavigatorProvider] and [ThumbnailWorker]:
/// - Provider marks artboards as dirty and requests refreshes
/// - Service schedules work and manages cache
/// - Worker performs actual rendering in background
/// - Service delivers results back to provider
///
/// ## Usage
///
/// ```dart
/// final service = ThumbnailService(
///   generator: (request) => myGenerator.generate(request),
///   onThumbnailReady: (artboardId, imageData, age) {
///     navigatorProvider.updateArtboard(
///       artboardId: artboardId,
///       thumbnail: imageData,
///     );
///   },
/// );
///
/// // Start auto-refresh loop
/// service.start();
///
/// // Mark artboard as dirty
/// service.markDirty(artboardId, visible: true);
///
/// // Trigger immediate refresh
/// service.refreshNow(artboardId, trigger: RefreshTrigger.manual);
///
/// // Clean up
/// await service.dispose();
/// ```
///
/// Related: FR-043, FR-039, Section 7.5, Task I4.T2
class ThumbnailService {
  /// Service configuration.
  final ThumbnailServiceConfig config;

  /// Thumbnail generator function (injected dependency).
  final Future<Uint8List?> Function(ThumbnailRequest request) generator;

  /// Callback when thumbnail is ready.
  final void Function(String artboardId, Uint8List imageData, Duration age)? onThumbnailReady;

  /// Telemetry callback.
  final void Function(String metric, Map<String, dynamic> data)? onTelemetry;

  /// Background worker for async thumbnail generation.
  late final ThumbnailWorker _worker;

  /// Thumbnail cache (LRU).
  final Map<String, _ThumbnailCacheEntry> _cache = {};

  /// Access order for LRU eviction.
  final List<String> _cacheAccessOrder = [];

  /// Dirty artboard IDs (need refresh).
  final Set<String> _dirtyArtboards = {};

  /// Visible artboard IDs (eligible for auto-refresh).
  final Set<String> _visibleArtboards = {};

  /// Last refresh time per artboard (for cooldown enforcement).
  final Map<String, DateTime> _lastRefreshTime = {};

  /// Last manual refresh time (for global cooldown).
  DateTime? _lastManualRefreshTime;

  /// Auto-refresh timer.
  Timer? _autoRefreshTimer;

  /// Whether service is started.
  bool _isStarted = false;

  /// Whether service is disposed.
  bool _isDisposed = false;

  ThumbnailService({
    ThumbnailServiceConfig? config,
    required this.generator,
    this.onThumbnailReady,
    this.onTelemetry,
  }) : config = config ?? const ThumbnailServiceConfig() {
    _worker = ThumbnailWorker(
      maxConcurrentJobs: this.config.maxConcurrentJobs,
      customGenerator: generator,
      onResult: _handleThumbnailResult,
    );
  }

  /// Starts the auto-refresh loop.
  ///
  /// Must be called before service will process any requests.
  void start() {
    if (_isStarted || _isDisposed) return;

    _isStarted = true;

    // Start worker
    _worker.start();

    // Start auto-refresh timer
    _autoRefreshTimer = Timer.periodic(config.autoRefreshInterval, (_) {
      _processAutoRefresh();
    });

    debugPrint('[ThumbnailService] Started (interval: ${config.autoRefreshInterval})');
  }

  /// Marks an artboard as dirty (needs refresh).
  ///
  /// [artboardId]: Artboard to mark dirty
  /// [visible]: Whether artboard is currently visible in Navigator
  void markDirty(String artboardId, {required bool visible}) {
    if (_isDisposed) return;

    _dirtyArtboards.add(artboardId);

    if (visible) {
      _visibleArtboards.add(artboardId);
    } else {
      _visibleArtboards.remove(artboardId);
    }
  }

  /// Marks an artboard as clean (no refresh needed).
  void markClean(String artboardId) {
    _dirtyArtboards.remove(artboardId);
  }

  /// Updates visibility status for an artboard.
  void updateVisibility(String artboardId, {required bool visible}) {
    if (_isDisposed) return;

    if (visible) {
      _visibleArtboards.add(artboardId);
    } else {
      _visibleArtboards.remove(artboardId);
    }
  }

  /// Triggers immediate refresh for a specific artboard.
  ///
  /// Returns true if refresh was scheduled, false if cooldown is active.
  bool refreshNow(String artboardId, {required RefreshTrigger trigger}) {
    if (_isDisposed || !_isStarted) return false;

    // Enforce manual refresh cooldown
    if (trigger == RefreshTrigger.manual) {
      if (_lastManualRefreshTime != null) {
        final timeSinceLastManual = DateTime.now().difference(_lastManualRefreshTime!);
        if (timeSinceLastManual < config.manualRefreshCooldown) {
          debugPrint('[ThumbnailService] Manual refresh cooldown active '
              '(${config.manualRefreshCooldown.inSeconds - timeSinceLastManual.inSeconds}s remaining)');
          return false;
        }
      }
      _lastManualRefreshTime = DateTime.now();
    }

    // Enqueue request with priority based on trigger
    final priority = _getPriority(trigger);
    final request = ThumbnailRequest(
      requestId: '${artboardId}_${DateTime.now().millisecondsSinceEpoch}',
      artboardId: artboardId,
      width: config.thumbnailWidth,
      height: config.thumbnailHeight,
      priority: priority,
      timestamp: DateTime.now(),
    );

    final enqueued = _worker.enqueue(request);

    if (enqueued) {
      // Note: _lastRefreshTime is updated in _handleThumbnailResult when complete
      markClean(artboardId); // Will be marked dirty again if needed
      debugPrint('[ThumbnailService] Enqueued refresh for $artboardId (trigger: $trigger, priority: $priority)');
    }

    return enqueued;
  }

  /// Processes auto-refresh cycle.
  ///
  /// Refreshes dirty, visible artboards that haven't been refreshed recently.
  void _processAutoRefresh() {
    if (_isDisposed || !_isStarted) return;

    final dirtyAndVisible = _dirtyArtboards.intersection(_visibleArtboards);

    if (dirtyAndVisible.isEmpty) {
      return;
    }

    debugPrint('[ThumbnailService] Auto-refresh checking ${dirtyAndVisible.length} artboards');

    // Filter artboards that passed idle threshold
    final now = DateTime.now();
    final eligibleArtboards = dirtyAndVisible.where((artboardId) {
      final lastRefresh = _lastRefreshTime[artboardId];
      if (lastRefresh == null) return true;

      final timeSinceRefresh = now.difference(lastRefresh);
      return timeSinceRefresh >= config.idleThreshold;
    }).toList();

    // Enqueue refreshes
    for (final artboardId in eligibleArtboards) {
      refreshNow(artboardId, trigger: RefreshTrigger.idle);
    }
  }

  /// Handles thumbnail generation result from worker.
  void _handleThumbnailResult(ThumbnailResult result) {
    if (_isDisposed) return;

    if (result.isSuccess) {
      // Calculate age BEFORE updating lastRefreshTime
      final age = _getThumbnailAge(result.artboardId);

      // Cache thumbnail
      _cacheSet(result.artboardId, result.imageData!);

      // Update last refresh time (after calculating age)
      _lastRefreshTime[result.artboardId] = DateTime.now();

      // Emit telemetry
      onTelemetry?.call('thumbnail.refresh.age', {
        'artboardId': result.artboardId,
        'ageMs': age.inMilliseconds,
        'durationMs': result.duration.inMilliseconds,
      });

      // Deliver to callback
      onThumbnailReady?.call(result.artboardId, result.imageData!, age);

      debugPrint('[ThumbnailService] Thumbnail ready for ${result.artboardId} '
          '(age: ${age.inSeconds}s, duration: ${result.duration.inMilliseconds}ms)');
    } else {
      debugPrint('[ThumbnailService] Thumbnail generation failed for ${result.artboardId}: ${result.error}');
    }
  }

  /// Gets thumbnail from cache.
  Uint8List? getCached(String artboardId) {
    final entry = _cache[artboardId];
    if (entry != null) {
      entry.markAccessed();
      _cachePromote(artboardId);
      return entry.imageData;
    }
    return null;
  }

  /// Invalidates cached thumbnail for an artboard.
  void invalidateCache(String artboardId) {
    _cache.remove(artboardId);
    _cacheAccessOrder.remove(artboardId);
  }

  /// Invalidates all cached thumbnails.
  void invalidateAllCache() {
    _cache.clear();
    _cacheAccessOrder.clear();
  }

  /// Adds thumbnail to cache with LRU eviction.
  void _cacheSet(String artboardId, Uint8List imageData) {
    // Remove if exists (will re-add at end)
    if (_cache.containsKey(artboardId)) {
      _cacheAccessOrder.remove(artboardId);
    } else if (_cache.length >= config.maxCacheSize) {
      // Evict least recently used
      final evictKey = _cacheAccessOrder.removeAt(0);
      _cache.remove(evictKey);
      debugPrint('[ThumbnailService] Cache evicted: $evictKey');
    }

    _cache[artboardId] = _ThumbnailCacheEntry(
      imageData: imageData,
      generatedAt: DateTime.now(),
    );
    _cacheAccessOrder.add(artboardId);
  }

  /// Promotes artboard to most recently used in cache.
  void _cachePromote(String artboardId) {
    _cacheAccessOrder.remove(artboardId);
    _cacheAccessOrder.add(artboardId);
  }

  /// Gets priority value for refresh trigger.
  int _getPriority(RefreshTrigger trigger) {
    switch (trigger) {
      case RefreshTrigger.manual:
        return 100; // Highest priority
      case RefreshTrigger.save:
        return 50; // Medium priority
      case RefreshTrigger.idle:
        return 10; // Lowest priority
    }
  }

  /// Gets age of thumbnail since last refresh.
  Duration _getThumbnailAge(String artboardId) {
    final lastRefresh = _lastRefreshTime[artboardId];
    if (lastRefresh == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(lastRefresh);
  }

  /// Returns diagnostic information about service state.
  Map<String, dynamic> getStats() {
    return {
      'cacheSize': _cache.length,
      'queueLength': _worker.queueLength,
      'processingCount': _worker.processingCount,
      'dirtyCount': _dirtyArtboards.length,
      'visibleCount': _visibleArtboards.length,
      'isStarted': _isStarted,
    };
  }

  /// Stops the service and releases resources.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _isStarted = false;

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;

    await _worker.dispose();

    _cache.clear();
    _cacheAccessOrder.clear();
    _dirtyArtboards.clear();
    _visibleArtboards.clear();
    _lastRefreshTime.clear();

    debugPrint('[ThumbnailService] Disposed');
  }
}
