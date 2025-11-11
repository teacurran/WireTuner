import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:resp_client/resp_client.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/export/svg_exporter.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';

/// Service for exporting documents to PDF format via background worker queue.
///
/// This service implements the PDF export pipeline described in FR-020:
/// 1. Generate SVG using [SvgExporter]
/// 2. Enqueue job to Redis-backed worker queue
/// 3. Poll job status until complete
/// 4. Handle retries and failures
///
/// ## Architecture
///
/// The PDF export process is fully asynchronous and non-blocking:
/// - Client generates SVG and enqueues job
/// - Rust worker consumes job and processes via resvg
/// - Client polls status until job completes
/// - UI updates via status callbacks
///
/// ## Redis Communication
///
/// This service uses the `resp_client` package to communicate with Redis
/// using the RESP protocol directly (not HTTP API). It maintains a persistent
/// connection for efficient command execution.
///
/// ## Usage
///
/// ```dart
/// final exporter = PdfExporterAsync(
///   redisHost: 'localhost',
///   redisPort: 6379,
/// );
///
/// final jobId = await exporter.exportToFile(document, '/path/to/output.pdf');
/// final result = await exporter.waitForCompletion(jobId);
/// ```
class PdfExporterAsync {
  /// Logger instance for export operations.
  final Logger _logger = Logger();

  /// SVG exporter for generating intermediate SVG content.
  final SvgExporter _svgExporter = SvgExporter();

  /// Redis host address.
  final String redisHost;

  /// Redis port number.
  final int redisPort;

  /// Redis connection.
  Connection? _connection;

  /// Telemetry service for metrics.
  final TelemetryService? telemetryService;

  /// UUID generator for job IDs.
  static const _uuid = Uuid();

  /// Creates a PDF exporter with the specified Redis configuration.
  ///
  /// Parameters:
  /// - [redisHost]: Redis server hostname (default: 'localhost')
  /// - [redisPort]: Redis server port (default: 6379)
  /// - [telemetryService]: Optional telemetry service for metrics
  PdfExporterAsync({
    this.redisHost = 'localhost',
    this.redisPort = 6379,
    this.telemetryService,
  });

  /// Ensures Redis connection is established.
  Future<void> _ensureConnected() async {
    if (_connection != null) {
      return;
    }

    try {
      _logger.d('Connecting to Redis: $redisHost:$redisPort');
      _connection = await connectSocket(redisHost, port: redisPort);
      _logger.i('Redis connection established');
    } catch (e, stackTrace) {
      _logger.e('Failed to connect to Redis', error: e, stackTrace: stackTrace);
      throw PdfExportException('Failed to connect to Redis: $e');
    }
  }

  /// Exports a document to PDF by enqueueing a background job.
  ///
  /// This method:
  /// 1. Generates SVG content for the document
  /// 2. Creates a PDF export job
  /// 3. Enqueues the job to Redis
  /// 4. Returns the job ID for status polling
  ///
  /// The actual PDF conversion happens asynchronously in the worker.
  /// Use [waitForCompletion] or [getStatus] to track progress.
  ///
  /// Parameters:
  /// - [document]: The document to export
  /// - [outputPath]: File path for the PDF output
  /// - [artboardIds]: Optional list of artboard IDs (null = all artboards)
  ///
  /// Returns the job ID for status tracking.
  ///
  /// Throws:
  /// - [PdfExportException] if job enqueue fails
  Future<String> exportToFile(
    Document document,
    String outputPath, {
    List<String>? artboardIds,
  }) async {
    final startTime = DateTime.now();

    try {
      _logger.d(
        'Starting PDF export: document=${document.id}, path=$outputPath',
      );

      // Generate SVG content
      final svgContent = _svgExporter.generateSvg(document);

      // Create job
      final jobId = _uuid.v4();
      final job = PdfExportJobRequest(
        jobId: jobId,
        documentId: document.id,
        svgContent: svgContent,
        outputPath: outputPath,
        metadata: PdfJobMetadata(
          artboardIds:
              artboardIds ?? document.artboards.map((ab) => ab.id).toList(),
          exportScope: artboardIds == null ? 'all' : 'selected',
          clientVersion: '0.1.0',
        ),
      );

      // Enqueue job
      await _enqueueJob(job);

      final duration = DateTime.now().difference(startTime);
      _logger.i(
        'PDF export job enqueued: job_id=$jobId, ${duration.inMilliseconds}ms',
      );

      // Record telemetry
      telemetryService?.recordSnapshotMetric(
        durationMs: duration.inMilliseconds,
        compressionRatio: 1.0,
        documentId: document.id,
      );

      return jobId;
    } catch (e, stackTrace) {
      _logger.e('PDF export failed', error: e, stackTrace: stackTrace);
      throw PdfExportException('Failed to enqueue PDF export job: $e');
    }
  }

  /// Exports a specific artboard to PDF.
  ///
  /// This is a convenience method that generates SVG for a single artboard
  /// and enqueues a PDF export job.
  Future<String> exportArtboardToFile(
    Artboard artboard,
    String outputPath, {
    String? documentTitle,
  }) async {
    final startTime = DateTime.now();

    try {
      _logger.d(
        'Starting artboard PDF export: artboard=${artboard.id}, path=$outputPath',
      );

      // Generate SVG for artboard
      final svgContent = _svgExporter.generateSvgForArtboard(
        artboard,
        documentTitle: documentTitle,
      );

      // Create job
      final jobId = _uuid.v4();
      final job = PdfExportJobRequest(
        jobId: jobId,
        documentId: artboard.id, // Use artboard ID as document ID
        svgContent: svgContent,
        outputPath: outputPath,
        metadata: PdfJobMetadata(
          artboardIds: [artboard.id],
          exportScope: 'current',
          clientVersion: '0.1.0',
        ),
      );

      // Enqueue job
      await _enqueueJob(job);

      final duration = DateTime.now().difference(startTime);
      _logger.i(
        'Artboard PDF export job enqueued: job_id=$jobId, ${duration.inMilliseconds}ms',
      );

      return jobId;
    } catch (e, stackTrace) {
      _logger.e('Artboard PDF export failed', error: e, stackTrace: stackTrace);
      throw PdfExportException('Failed to enqueue artboard PDF export: $e');
    }
  }

  /// Gets the current status of a PDF export job.
  ///
  /// Queries the Redis status key for the job and returns the current state.
  /// Returns `null` if the job is not found (expired or never existed).
  Future<PdfJobStatus?> getStatus(String jobId) async {
    try {
      await _ensureConnected();
      final statusKey = 'wiretuner:export:pdf:status:$jobId';

      // GET from Redis using RESP protocol
      final response = await _connection!.get(statusKey);

      if (response == null) {
        return null; // Job not found
      }

      final jobData = jsonDecode(response) as Map<String, dynamic>;
      return PdfJobStatus.fromJson(jobData);
    } catch (e) {
      _logger.e('Failed to get job status: $e');
      rethrow;
    }
  }

  /// Waits for a job to complete, polling status at regular intervals.
  ///
  /// This method polls the job status every [pollInterval] until the job
  /// reaches a terminal state (complete or failed). The [timeout] parameter
  /// limits the total wait time.
  ///
  /// Parameters:
  /// - [jobId]: The job ID to wait for
  /// - [pollInterval]: How often to poll (default: 500ms)
  /// - [timeout]: Maximum wait time (default: 5 minutes)
  ///
  /// Returns the final job status.
  ///
  /// Throws:
  /// - [TimeoutException] if timeout is exceeded
  /// - [PdfExportException] if job fails
  Future<PdfJobStatus> waitForCompletion(
    String jobId, {
    Duration pollInterval = const Duration(milliseconds: 500),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException(
          'PDF export timed out after ${timeout.inSeconds}s',
          timeout,
        );
      }

      // Poll status
      final status = await getStatus(jobId);

      if (status == null) {
        throw PdfExportException('Job not found: $jobId');
      }

      // Check terminal states
      if (status.status == 'complete') {
        _logger.i('PDF export completed: job_id=$jobId');
        return status;
      }

      if (status.status == 'failed') {
        final error = status.error ?? 'Unknown error';
        _logger.e('PDF export failed: job_id=$jobId, error=$error');
        throw PdfExportException('PDF export failed: $error');
      }

      // Wait before next poll
      await Future.delayed(pollInterval);
    }
  }

  /// Enqueues a PDF export job to Redis.
  Future<void> _enqueueJob(PdfExportJobRequest job) async {
    await _ensureConnected();

    const queueKey = 'wiretuner:export:pdf:queue';
    const statusKeyPrefix = 'wiretuner:export:pdf:status';

    final jobJson = jsonEncode(job.toJson());

    try {
      // RPUSH to queue using RESP protocol
      await _connection!.rpush(queueKey, [jobJson]);

      // SET status key with initial state
      final statusKey = '$statusKeyPrefix:${job.jobId}';
      await _connection!.set(statusKey, jobJson);

      // EXPIRE status key after 24 hours (86400 seconds)
      await _connection!.expire(statusKey, 86400);

      _logger.d('Job enqueued: job_id=${job.jobId}');
    } catch (e, stackTrace) {
      _logger.e('Failed to enqueue job', error: e, stackTrace: stackTrace);
      throw PdfExportException('Failed to enqueue job: $e');
    }
  }

  /// Disposes resources and closes Redis connection.
  void dispose() {
    _connection?.close();
    _connection = null;
    _logger.d('Redis connection closed');
  }
}

/// PDF export job request payload.
class PdfExportJobRequest {
  const PdfExportJobRequest({
    required this.jobId,
    required this.documentId,
    required this.svgContent,
    required this.outputPath,
    required this.metadata,
  });

  final String jobId;
  final String documentId;
  final String svgContent;
  final String outputPath;
  final PdfJobMetadata metadata;

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'document_id': documentId,
        'svg_content': svgContent,
        'output_path': outputPath,
        'metadata': metadata.toJson(),
        'status': 'queued',
        'retry_count': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

/// Job metadata for telemetry and tracking.
class PdfJobMetadata {
  const PdfJobMetadata({
    required this.artboardIds,
    required this.exportScope,
    required this.clientVersion,
    this.userId,
  });

  final List<String> artboardIds;
  final String exportScope;
  final String clientVersion;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'artboard_ids': artboardIds,
        'export_scope': exportScope,
        'client_version': clientVersion,
        if (userId != null) 'user_id': userId,
      };
}

/// PDF export job status response.
class PdfJobStatus {
  const PdfJobStatus({
    required this.jobId,
    required this.documentId,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.error,
  });

  final String jobId;
  final String documentId;
  final String status; // queued, processing, complete, failed
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? error;

  factory PdfJobStatus.fromJson(Map<String, dynamic> json) {
    return PdfJobStatus(
      jobId: json['job_id'] as String,
      documentId: json['document_id'] as String,
      status: json['status'] as String,
      retryCount: json['retry_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      error: json['error'] as String?,
    );
  }

  /// Returns true if the job is in a terminal state.
  bool get isTerminal => status == 'complete' || status == 'failed';

  /// Returns true if the job completed successfully.
  bool get isComplete => status == 'complete';

  /// Returns true if the job failed.
  bool get isFailed => status == 'failed';

  /// Returns a human-readable status message.
  String get statusMessage {
    switch (status) {
      case 'queued':
        return 'Waiting in queue...';
      case 'processing':
        return 'Converting to PDF...';
      case 'complete':
        return 'Export complete';
      case 'failed':
        return 'Export failed: ${error ?? "Unknown error"}';
      default:
        return 'Unknown status: $status';
    }
  }

  /// Returns progress percentage (0.0 to 1.0).
  double get progress {
    switch (status) {
      case 'queued':
        return 0.1;
      case 'processing':
        return 0.5;
      case 'complete':
        return 1.0;
      case 'failed':
        return 0.0;
      default:
        return 0.0;
    }
  }
}

/// Exception thrown during PDF export operations.
class PdfExportException implements Exception {
  const PdfExportException(this.message);

  final String message;

  @override
  String toString() => 'PdfExportException: $message';
}
