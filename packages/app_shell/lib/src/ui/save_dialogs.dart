/// UI dialogs for document save operations.
///
/// Provides blocking progress indicators and error dialogs for Save/Save As flows.
/// Integrates with file picker for Save As destination selection.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Save dialogs helper for displaying progress and error UI.
///
/// **Usage:**
/// ```dart
/// final dialogs = SaveDialogs();
///
/// // Show progress during save
/// dialogs.showSaveProgress(
///   context: context,
///   message: 'Saving document...',
/// );
///
/// // Hide progress on completion
/// dialogs.hideSaveProgress(context);
///
/// // Show error dialog
/// await dialogs.showSaveError(
///   context: context,
///   message: 'Failed to save document',
///   filePath: '/path/to/file.wiretuner',
/// );
///
/// // Show file picker for Save As
/// final path = await dialogs.showSaveAsDialog(
///   context: context,
///   defaultFileName: 'Untitled.wiretuner',
/// );
/// ```
class SaveDialogs {
  /// Shows a blocking progress dialog during save operations.
  ///
  /// Call [hideSaveProgress] when the save completes or fails.
  ///
  /// [context]: Build context for dialog
  /// [message]: Progress message to display
  void showSaveProgress({
    required BuildContext context,
    String message = 'Saving document...',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissal during save
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

  /// Hides the save progress dialog.
  ///
  /// Call this after save completes (success or failure).
  void hideSaveProgress(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Shows an error dialog with actionable messaging.
  ///
  /// [context]: Build context for dialog
  /// [message]: User-friendly error message
  /// [filePath]: Optional file path to include in error display
  ///
  /// Returns a Future that completes when the user dismisses the dialog.
  Future<void> showSaveError({
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
            Text('Save Failed'),
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
  void showSaveSuccess({
    required BuildContext context,
    String message = 'Document saved successfully',
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

  /// Shows a file picker dialog for Save As operation.
  ///
  /// [context]: Build context for dialog
  /// [defaultFileName]: Default file name to suggest
  /// [initialDirectory]: Optional initial directory to open
  ///
  /// Returns the selected file path, or null if user canceled.
  Future<String?> showSaveAsDialog({
    required BuildContext context,
    String defaultFileName = 'Untitled.wiretuner',
    String? initialDirectory,
  }) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document As',
        fileName: defaultFileName,
        allowedExtensions: ['wiretuner'],
        type: FileType.custom,
        initialDirectory: initialDirectory,
      );

      if (result == null) {
        // User canceled
        return null;
      }

      // Ensure .wiretuner extension
      String filePath = result;
      if (!filePath.endsWith('.wiretuner')) {
        filePath = '$filePath.wiretuner';
      }

      return filePath;
    } catch (e) {
      // File picker error
      if (context.mounted) {
        await showSaveError(
          context: context,
          message: 'Failed to open file picker.\n\n$e',
        );
      }
      return null;
    }
  }

  /// Shows a confirmation dialog for overwriting an existing file.
  ///
  /// [context]: Build context for dialog
  /// [filePath]: File path that will be overwritten
  ///
  /// Returns true if user confirms overwrite, false if canceled.
  Future<bool> showOverwriteConfirmation({
    required BuildContext context,
    required String filePath,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Overwrite File?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A file with this name already exists. Do you want to replace it?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              filePath,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    return result ?? false; // Default to false if dialog dismissed
  }

  /// Shows an unsaved changes confirmation dialog.
  ///
  /// [context]: Build context for dialog
  ///
  /// Returns true if user wants to save, false if discard, null if cancel.
  Future<bool?> showUnsavedChangesDialog({
    required BuildContext context,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'Do you want to save the changes you made to this document?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Don't Save
            child: const Text("Don't Save"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Save
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
