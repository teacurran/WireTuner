import 'package:flutter/material.dart';
import 'package:wiretuner/infrastructure/export/pdf_exporter_async.dart';

/// Status panel for tracking PDF export job progress.
///
/// This panel displays real-time job status with:
/// - Progress indicator (queued/processing/complete/failed)
/// - Status message updates via polling (every 500ms)
/// - Auto-close on success after 2 seconds
/// - Error panel with red styling on failure
/// - Retry button for failed jobs
/// - Cancel button to dismiss panel
///
/// ## Polling Behavior
///
/// The panel polls the job status every 500ms until the job reaches a
/// terminal state (complete or failed). This provides responsive UI updates
/// without blocking the main thread.
///
/// ## Usage
///
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (context) => PdfStatusPanel(
///     jobId: jobId,
///     exporter: exporter,
///     onComplete: () => print('Export done!'),
///     onError: (error) => print('Export failed: $error'),
///   ),
/// );
/// ```
class PdfStatusPanel extends StatefulWidget {
  const PdfStatusPanel({
    required this.jobId,
    required this.exporter,
    this.onComplete,
    this.onError,
    super.key,
  });

  /// The job ID to track.
  final String jobId;

  /// The PDF exporter instance for status polling.
  final PdfExporterAsync exporter;

  /// Callback when export completes successfully.
  final VoidCallback? onComplete;

  /// Callback when export fails.
  final void Function(String error)? onError;

  @override
  State<PdfStatusPanel> createState() => _PdfStatusPanelState();
}

class _PdfStatusPanelState extends State<PdfStatusPanel> {
  PdfJobStatus? _status;
  bool _isPolling = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  /// Starts polling for job status updates.
  ///
  /// Polls every 500ms until the job reaches a terminal state or an error
  /// occurs. Auto-closes the panel 2 seconds after successful completion.
  Future<void> _startPolling() async {
    while (_isPolling && mounted) {
      try {
        final status = await widget.exporter.getStatus(widget.jobId);

        if (status == null) {
          setState(() {
            _errorMessage = 'Job not found';
            _isPolling = false;
          });
          widget.onError?.call('Job not found');
          return;
        }

        setState(() {
          _status = status;
        });

        // Handle terminal states
        if (status.isComplete) {
          _isPolling = false;
          widget.onComplete?.call();

          // Auto-close after 2 seconds
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        if (status.isFailed) {
          _isPolling = false;
          setState(() {
            _errorMessage = status.error ?? 'Unknown error';
          });
          widget.onError?.call(_errorMessage!);
          return;
        }

        // Poll every 500ms
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to poll status: $e';
          _isPolling = false;
        });
        widget.onError?.call(_errorMessage!);
        return;
      }
    }
  }

  /// Retries a failed job by closing the panel.
  ///
  /// Note: This doesn't re-enqueue the job automatically. The user must
  /// manually retry the export operation from the export dialog.
  Future<void> _handleRetry() async {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.picture_as_pdf_outlined),
          SizedBox(width: 12),
          Text('Exporting to PDF'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status message
            _buildStatusMessage(),
            const SizedBox(height: 16),

            // Progress indicator
            _buildProgressIndicator(),
            const SizedBox(height: 16),

            // Metadata (retry count, etc.)
            if (_status != null) _buildMetadata(),

            // Error message
            if (_errorMessage != null) _buildErrorMessage(),
          ],
        ),
      ),
      actions: [
        // Retry button (only for failed jobs)
        if (_status?.isFailed == true)
          TextButton.icon(
            onPressed: _handleRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),

        // Cancel/Close button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_status?.isTerminal == true ? 'Close' : 'Cancel'),
        ),
      ],
    );
  }

  /// Builds the status message display.
  Widget _buildStatusMessage() {
    if (_status == null) {
      return const Text('Initializing export...');
    }

    return Text(
      _status!.statusMessage,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  /// Builds the progress indicator with appropriate styling.
  ///
  /// Colors:
  /// - Blue: In progress (queued/processing)
  /// - Red: Failed
  /// - Green: Complete
  Widget _buildProgressIndicator() {
    if (_status == null) {
      return const LinearProgressIndicator();
    }

    if (_status!.isFailed) {
      return LinearProgressIndicator(
        value: 1.0,
        backgroundColor: Colors.red.shade100,
        color: Colors.red,
      );
    }

    if (_status!.isComplete) {
      return LinearProgressIndicator(
        value: 1.0,
        backgroundColor: Colors.green.shade100,
        color: Colors.green,
      );
    }

    return LinearProgressIndicator(
      value: _status!.progress,
    );
  }

  /// Builds the metadata display showing job details.
  Widget _buildMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job ID: ${widget.jobId}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Status: ${_status!.status}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        if (_status!.retryCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Retry attempts: ${_status!.retryCount}/3',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade700,
                ),
          ),
        ],
      ],
    );
  }

  /// Builds the error message panel with red styling.
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Failed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.red.shade900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
