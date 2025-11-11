import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Request to generate a thumbnail for an artboard.
class ThumbnailRequest {
  /// Unique identifier for this request.
  final String requestId;

  /// Artboard ID to render.
  final String artboardId;

  /// Target thumbnail width in pixels.
  final int width;

  /// Target thumbnail height in pixels.
  final int height;

  /// Priority level (higher = process first).
  final int priority;

  /// Timestamp when request was created.
  final DateTime timestamp;

  /// Serialized document data (for isolate transfer).
  final Map<String, dynamic>? documentData;

  const ThumbnailRequest({
    required this.requestId,
    required this.artboardId,
    required this.width,
    required this.height,
    this.priority = 0,
    required this.timestamp,
    this.documentData,
  });

  ThumbnailRequest copyWith({
    String? requestId,
    String? artboardId,
    int? width,
    int? height,
    int? priority,
    DateTime? timestamp,
    Map<String, dynamic>? documentData,
  }) {
    return ThumbnailRequest(
      requestId: requestId ?? this.requestId,
      artboardId: artboardId ?? this.artboardId,
      width: width ?? this.width,
      height: height ?? this.height,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      documentData: documentData ?? this.documentData,
    );
  }
}

/// Result of a thumbnail generation operation.
class ThumbnailResult {
  /// Request ID that generated this result.
  final String requestId;

  /// Artboard ID.
  final String artboardId;

  /// Generated thumbnail image data (PNG format).
  final Uint8List? imageData;

  /// Error message if generation failed.
  final String? error;

  /// Generation duration.
  final Duration duration;

  /// Timestamp when generation completed.
  final DateTime completedAt;

  const ThumbnailResult({
    required this.requestId,
    required this.artboardId,
    this.imageData,
    this.error,
    required this.duration,
    required this.completedAt,
  });

  bool get isSuccess => imageData != null && error == null;
}

/// Background worker for thumbnail generation.
///
/// Processes thumbnail requests asynchronously to avoid blocking the UI thread.
/// Supports both in-process (synchronous) and isolate-based (async) execution.
///
/// ## Architecture
///
/// This worker implements a queue-based processing model:
/// - Requests are prioritized (manual refresh > auto-refresh)
/// - Concurrent processing limit (default: 5)
/// - Isolate-based rendering for CPU-intensive operations
/// - Results delivered via callback
///
/// ## Usage
///
/// ```dart
/// final worker = ThumbnailWorker(
///   maxConcurrentJobs: 5,
///   onResult: (result) {
///     if (result.isSuccess) {
///       updateThumbnail(result.artboardId, result.imageData!);
///     }
///   },
/// );
///
/// worker.enqueue(ThumbnailRequest(
///   requestId: 'req_123',
///   artboardId: 'artboard_456',
///   width: 256,
///   height: 256,
///   timestamp: DateTime.now(),
/// ));
///
/// await worker.dispose();
/// ```
///
/// Related: FR-043 (Navigator thumbnail refresh), Section 7.5 (Performance)
class ThumbnailWorker {
  /// Maximum number of concurrent thumbnail generation jobs.
  final int maxConcurrentJobs;

  /// Callback invoked when a thumbnail is generated.
  final void Function(ThumbnailResult result)? onResult;

  /// Custom thumbnail generator function (for dependency injection).
  /// If null, uses the default isolate-based renderer.
  final Future<Uint8List?> Function(ThumbnailRequest request)? customGenerator;

  /// Request queue (priority-sorted).
  final List<ThumbnailRequest> _queue = [];

  /// Currently processing requests.
  final Set<String> _processing = {};

  /// Whether the worker is disposed.
  bool _isDisposed = false;

  /// Stream controller for processing events.
  final StreamController<void> _processingController = StreamController<void>.broadcast();

  ThumbnailWorker({
    this.maxConcurrentJobs = 5,
    this.onResult,
    this.customGenerator,
  });

  /// Enqueues a thumbnail generation request.
  ///
  /// Returns true if request was enqueued, false if worker is disposed
  /// or request is duplicate.
  bool enqueue(ThumbnailRequest request) {
    if (_isDisposed) {
      return false;
    }

    // Deduplicate: if same artboard is already queued/processing, update priority
    final existingIndex = _queue.indexWhere((r) => r.artboardId == request.artboardId);
    if (existingIndex >= 0) {
      // Replace with higher priority request
      final existing = _queue[existingIndex];
      if (request.priority > existing.priority) {
        _queue[existingIndex] = request;
        _sortQueue();
      }
      return true;
    }

    // Check if already processing
    if (_processing.contains(request.artboardId)) {
      return false;
    }

    // Add to queue
    _queue.add(request);
    _sortQueue();

    // Trigger processing
    _processingController.add(null);

    return true;
  }

  /// Cancels pending requests for a specific artboard.
  void cancel(String artboardId) {
    _queue.removeWhere((r) => r.artboardId == artboardId);
  }

  /// Cancels all pending requests.
  void cancelAll() {
    _queue.clear();
  }

  /// Returns the number of pending requests.
  int get queueLength => _queue.length;

  /// Returns the number of currently processing requests.
  int get processingCount => _processing.length;

  /// Sorts queue by priority (highest first) and timestamp (oldest first).
  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.timestamp.compareTo(b.timestamp);
    });
  }

  /// Starts processing the queue.
  ///
  /// This method is called automatically when requests are enqueued.
  /// It processes up to [maxConcurrentJobs] requests concurrently.
  Future<void> _processQueue() async {
    while (!_isDisposed && _queue.isNotEmpty && _processing.length < maxConcurrentJobs) {
      final request = _queue.removeAt(0);
      _processing.add(request.artboardId);

      // Process asynchronously without blocking queue
      _processRequest(request).then((result) {
        _processing.remove(request.artboardId);
        onResult?.call(result);

        // Continue processing if more requests available
        if (_queue.isNotEmpty) {
          _processingController.add(null);
        }
      }).catchError((error) {
        _processing.remove(request.artboardId);
        onResult?.call(ThumbnailResult(
          requestId: request.requestId,
          artboardId: request.artboardId,
          error: error.toString(),
          duration: Duration.zero,
          completedAt: DateTime.now(),
        ));
      });
    }
  }

  /// Processes a single thumbnail request.
  Future<ThumbnailResult> _processRequest(ThumbnailRequest request) async {
    final startTime = DateTime.now();

    try {
      // Use custom generator if provided, otherwise use default
      final imageData = customGenerator != null
          ? await customGenerator!(request)
          : await _defaultGenerator(request);

      final duration = DateTime.now().difference(startTime);

      return ThumbnailResult(
        requestId: request.requestId,
        artboardId: request.artboardId,
        imageData: imageData,
        duration: duration,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      return ThumbnailResult(
        requestId: request.requestId,
        artboardId: request.artboardId,
        error: e.toString(),
        duration: duration,
        completedAt: DateTime.now(),
      );
    }
  }

  /// Default thumbnail generator (placeholder).
  ///
  /// In production, this would:
  /// 1. Deserialize document data
  /// 2. Render using RenderingPipeline in isolate
  /// 3. Convert ui.Image to PNG bytes
  ///
  /// For now, returns a placeholder colored rectangle.
  Future<Uint8List?> _defaultGenerator(ThumbnailRequest request) async {
    // Simulate rendering delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Return placeholder (1x1 gray pixel, UI will scale)
    final bytes = Uint8List(4);
    bytes[0] = 200; // R
    bytes[1] = 200; // G
    bytes[2] = 200; // B
    bytes[3] = 255; // A

    return bytes;
  }

  /// Starts the background processing loop.
  void start() {
    _processingController.stream.listen((_) {
      if (!_isDisposed) {
        _processQueue();
      }
    });

    // Kick off initial processing
    _processingController.add(null);
  }

  /// Disposes the worker and releases resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _queue.clear();
    _processing.clear();
    await _processingController.close();
  }
}

/// Isolate-based thumbnail generator entry point.
///
/// This function runs in a separate isolate to avoid blocking the UI thread
/// during expensive thumbnail generation operations.
///
/// ## Protocol
///
/// 1. Main isolate sends [ThumbnailRequest] via SendPort
/// 2. Worker isolate processes request (renders thumbnail)
/// 3. Worker isolate sends [ThumbnailResult] back via SendPort
///
/// Related: BackgroundWorkerPool (Blueprint Section 1.2)
Future<void> thumbnailWorkerIsolate(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is ThumbnailRequest) {
      // TODO: Implement actual rendering logic
      // For now, just send a placeholder result
      final result = ThumbnailResult(
        requestId: message.requestId,
        artboardId: message.artboardId,
        imageData: Uint8List(4), // Placeholder
        duration: const Duration(milliseconds: 50),
        completedAt: DateTime.now(),
      );

      sendPort.send(result);
    }
  }
}
