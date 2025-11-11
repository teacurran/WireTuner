/// UI dialogs for document open/load operations.
///
/// Provides file picker, progress indicators, error dialogs, and version
/// compatibility warnings for document loading flows.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Open dialogs helper for displaying progress, error, and warning UI.
///
/// **Usage:**
/// ```dart
/// final dialogs = OpenDialogs();
///
/// // Show file picker
/// final path = await dialogs.showOpenDialog(context: context);
///
/// // Show progress during load
/// dialogs.showLoadProgress(
///   context: context,
///   message: 'Loading document...',
/// );
///
/// // Hide progress on completion
/// dialogs.hideLoadProgress(context);
///
/// // Show error dialog
/// await dialogs.showLoadError(
///   context: context,
///   message: 'Failed to load document',
///   filePath: '/path/to/file.wiretuner',
/// );
///
/// // Show version warning
/// await dialogs.showVersionWarning(
///   context: context,
///   fileVersion: 2,
///   appVersion: 1,
/// );
/// ```
class OpenDialogs {
  /// Shows a file picker dialog for opening a document.
  ///
  /// [context]: Build context for dialog
  /// [initialDirectory]: Optional initial directory to open
  ///
  /// Returns the selected file path, or null if user canceled.
  Future<String?> showOpenDialog({
    required BuildContext context,
    String? initialDirectory,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open Document',
        allowedExtensions: ['wiretuner'],
        type: FileType.custom,
        initialDirectory: initialDirectory,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User canceled
        return null;
      }

      return result.files.first.path;
    } catch (e) {
      // File picker error
      if (context.mounted) {
        await showLoadError(
          context: context,
          message: 'Failed to open file picker.\n\n$e',
        );
      }
      return null;
    }
  }

  /// Shows a blocking progress dialog during load operations.
  ///
  /// Call [hideLoadProgress] when the load completes or fails.
  ///
  /// [context]: Build context for dialog
  /// [message]: Progress message to display
  void showLoadProgress({
    required BuildContext context,
    String message = 'Loading document...',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissal during load
      builder: (context) => PopScope(
        canPop: false, // Prevent back button dismissal
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hides the load progress dialog.
  ///
  /// Call this after load completes (success or failure).
  void hideLoadProgress(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Shows an error dialog with actionable messaging.
  ///
  /// [context]: Build context for dialog
  /// [message]: User-friendly error message
  /// [filePath]: Optional file path to include in error display
  ///
  /// Returns a Future that completes when the user dismisses the dialog.
  Future<void> showLoadError({
    required BuildContext context,
    required String message,
    String? filePath,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Load Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            if (filePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Path: $filePath',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a success toast notification (non-blocking).
  ///
  /// [context]: Build context for snackbar
  /// [message]: Success message to display
  /// [filePath]: Optional file path to include
  void showLoadSuccess({
    required BuildContext context,
    String message = 'Document loaded successfully',
    String? filePath,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  if (filePath != null)
                    Text(
                      filePath,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows a version incompatibility warning for unsupported file versions.
  ///
  /// This is displayed when a file was created with a newer version of the app
  /// and cannot be opened by the current version.
  ///
  /// [context]: Build context for dialog
  /// [fileVersion]: File format version from the document
  /// [appVersion]: Current application version
  ///
  /// Returns a Future that completes when the user dismisses the dialog.
  Future<void> showVersionWarning({
    required BuildContext context,
    required int fileVersion,
    required int appVersion,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Incompatible File Version'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This file was created with WireTuner version $fileVersion or newer.\n'
              'You are running version $appVersion.\n\n'
              'Please upgrade to the latest version of WireTuner to open this file.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Download: https://wiretuner.app/download',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Shows a migration progress dialog for long-running migrations.
  ///
  /// [context]: Build context for dialog
  /// [fromVersion]: Original file version
  /// [toVersion]: Target version
  void showMigrationProgress({
    required BuildContext context,
    required int fromVersion,
    required int toVersion,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  'Upgrading file format from v$fromVersion to v$toVersion...',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hides the migration progress dialog.
  void hideMigrationProgress(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Shows a warning toast for downgrade scenarios.
  ///
  /// This is displayed when opening a file that was saved with a newer version
  /// but the migration was successful (non-blocking warning).
  ///
  /// [context]: Build context for snackbar
  /// [warnings]: List of feature downgrades/losses
  void showDegradeWarning({
    required BuildContext context,
    required List<String> warnings,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('File Format Downgraded'),
                  const SizedBox(height: 4),
                  Text(
                    warnings.join(', '),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Downgrade Details'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The following features were downgraded or removed:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ...warnings.map((warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Shows a snapshot corruption warning dialog.
  ///
  /// This is displayed when a snapshot CRC check fails and the system
  /// falls back to an earlier snapshot or full replay.
  ///
  /// [context]: Build context for dialog
  ///
  /// Returns a Future that completes when the user dismisses the dialog.
  Future<void> showSnapshotCorruptionWarning({
    required BuildContext context,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Snapshot Corruption Detected'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A snapshot was corrupted and has been recovered by replaying events.\n\n'
              'Document loading may be slower.\n\n'
              'Consider re-saving the document to rebuild snapshots.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
