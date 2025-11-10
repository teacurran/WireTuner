/// Document lifecycle service for WireTuner.
///
/// This service orchestrates document operations including save, load, and close.
/// It acts as the application-level coordinator between DocumentProvider, SaveService,
/// and the event store infrastructure.
///
/// **Architecture:**
/// - Composes DocumentProvider (UI state), SaveService (persistence), and event gateway
/// - Manages dirty state tracking by coordinating sequence numbers
/// - Delegates all file operations to SaveService
/// - Provides high-level document lifecycle methods for UI consumption
///
/// **Threading:** All methods must be called from the UI isolate.
library;

import 'package:flutter/material.dart';
import 'package:app_shell/app_shell.dart';
import 'package:event_core/event_core.dart';
import 'package:io_services/io_services.dart';
import 'package:logger/logger.dart';

import '../../presentation/state/document_provider.dart';

/// Document service for managing document lifecycle operations.
///
/// **Usage:**
/// ```dart
/// final documentService = DocumentService(
///   documentProvider: documentProvider,
///   saveService: saveService,
///   eventGateway: eventGateway,
///   snapshotManager: snapshotManager,
///   logger: logger,
/// );
///
/// // Save document
/// final result = await documentService.saveDocument(context: context);
///
/// // Save As with file picker
/// final result = await documentService.saveDocumentAs(context: context);
///
/// // Check if document has unsaved changes
/// final isDirty = await documentService.hasUnsavedChanges();
/// ```
class DocumentService {
  /// Creates a document service with injected dependencies.
  DocumentService({
    required DocumentProvider documentProvider,
    required SaveService saveService,
    required EventStoreGateway eventGateway,
    required SnapshotManager snapshotManager,
    required Logger logger,
  })  : _documentProvider = documentProvider,
        _saveService = saveService,
        _eventGateway = eventGateway,
        _snapshotManager = snapshotManager,
        _logger = logger;

  final DocumentProvider _documentProvider;
  final SaveService _saveService;
  final EventStoreGateway _eventGateway;
  final SnapshotManager _snapshotManager;
  final Logger _logger;

  /// Helper for showing save dialogs.
  final _saveDialogs = SaveDialogs();

  /// Saves the current document.
  ///
  /// If the document has never been saved (no file path), this will
  /// show a Save As dialog to prompt for a file location.
  ///
  /// If the document has a current file path, saves to that path.
  ///
  /// [context]: BuildContext for showing dialogs
  ///
  /// Returns [SaveResult] with success/failure details, or null if user canceled.
  Future<SaveResult?> saveDocument({
    required BuildContext context,
  }) async {
    _logger.i('Save requested for document: ${_documentProvider.document.id}');

    // Get current document state
    final documentId = _documentProvider.document.id;
    final title = _documentProvider.document.title;

    // Get current sequence number from event gateway
    final currentSequence = await _eventGateway.getLatestSequenceNumber();

    // Check if document has a file path
    final currentPath = _saveService.getCurrentFilePath(documentId);

    if (currentPath == null) {
      // New document - show Save As dialog
      _logger.i('Document has no path, redirecting to Save As');
      // Save As can return null if user cancels
      return await saveDocumentAs(context: context);
    }

    // Perform save with progress indicator
    if (!context.mounted) return _contextNotMountedError();

    _saveDialogs.showSaveProgress(
      context: context,
      message: 'Saving "$title"...',
    );

    try {
      // Trigger snapshot creation before save if needed
      await _ensureSnapshotIfNeeded(currentSequence);

      // Perform save
      final result = await _saveService.save(
        documentId: documentId,
        currentSequence: currentSequence,
        documentState: _documentProvider.toJson(),
        title: title,
      );

      // Hide progress dialog
      if (context.mounted) {
        _saveDialogs.hideSaveProgress(context);
      }

      // Handle result
      if (result is SaveSuccess) {
        _logger.i('Save succeeded: ${result.filePath}');
        if (context.mounted) {
          _saveDialogs.showSaveSuccess(
            context: context,
            message: 'Document saved',
            filePath: result.filePath,
          );
        }
      } else if (result is SaveFailure) {
        _logger.e('Save failed: ${result.technicalDetails}');
        if (context.mounted) {
          await _saveDialogs.showSaveError(
            context: context,
            message: result.userMessage,
            filePath: result.filePath,
          );
        }
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during save', error: e, stackTrace: stackTrace);

      // Hide progress dialog
      if (context.mounted) {
        _saveDialogs.hideSaveProgress(context);
      }

      // Show error dialog
      if (context.mounted) {
        await _saveDialogs.showSaveError(
          context: context,
          message: 'Failed to save document.\n\n$e',
        );
      }

      return SaveFailure(
        errorType: SaveErrorType.unknown,
        userMessage: 'Failed to save document.\n\n$e',
        technicalDetails: e.toString(),
      );
    }
  }

  /// Saves the document to a new file path (Save As).
  ///
  /// Shows a file picker dialog to select the destination file.
  ///
  /// [context]: BuildContext for showing dialogs
  ///
  /// Returns [SaveResult] with success/failure details.
  /// Returns null if the user canceled the file picker.
  Future<SaveResult?> saveDocumentAs({
    required BuildContext context,
  }) async {
    _logger.i('Save As requested for document: ${_documentProvider.document.id}');

    // Get current document state
    final documentId = _documentProvider.document.id;
    final title = _documentProvider.document.title;

    // Show file picker
    final filePath = await _saveDialogs.showSaveAsDialog(
      context: context,
      defaultFileName: '$title.wiretuner',
    );

    if (filePath == null) {
      // User canceled
      _logger.i('Save As canceled by user');
      return null;
    }

    // Get current sequence number
    final currentSequence = await _eventGateway.getLatestSequenceNumber();

    // Perform save with progress indicator
    if (!context.mounted) return _contextNotMountedError();

    _saveDialogs.showSaveProgress(
      context: context,
      message: 'Saving "$title" to ${_getFileName(filePath)}...',
    );

    try {
      // Trigger snapshot creation before save if needed
      await _ensureSnapshotIfNeeded(currentSequence);

      // Perform save as
      final result = await _saveService.saveAs(
        documentId: documentId,
        filePath: filePath,
        currentSequence: currentSequence,
        documentState: _documentProvider.toJson(),
        title: title,
      );

      // Hide progress dialog
      if (context.mounted) {
        _saveDialogs.hideSaveProgress(context);
      }

      // Handle result
      if (result is SaveSuccess) {
        _logger.i('Save As succeeded: ${result.filePath}');
        if (context.mounted) {
          _saveDialogs.showSaveSuccess(
            context: context,
            message: 'Document saved',
            filePath: result.filePath,
          );
        }
      } else if (result is SaveFailure) {
        _logger.e('Save As failed: ${result.technicalDetails}');
        if (context.mounted) {
          await _saveDialogs.showSaveError(
            context: context,
            message: result.userMessage,
            filePath: result.filePath,
          );
        }
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Save As', error: e, stackTrace: stackTrace);

      // Hide progress dialog
      if (context.mounted) {
        _saveDialogs.hideSaveProgress(context);
      }

      // Show error dialog
      if (context.mounted) {
        await _saveDialogs.showSaveError(
          context: context,
          message: 'Failed to save document to "$filePath".\n\n$e',
          filePath: filePath,
        );
      }

      return SaveFailure(
        errorType: SaveErrorType.unknown,
        userMessage: 'Failed to save document to "$filePath".\n\n$e',
        technicalDetails: e.toString(),
        filePath: filePath,
      );
    }
  }

  /// Checks if the document has unsaved changes.
  ///
  /// Compares the current sequence number with the last persisted sequence
  /// to determine dirty state.
  ///
  /// Returns true if there are unsaved changes, false otherwise.
  Future<bool> hasUnsavedChanges() async {
    final documentId = _documentProvider.document.id;
    final currentSequence = await _eventGateway.getLatestSequenceNumber();

    final dirtyState = await _saveService.checkDirtyState(
      documentId: documentId,
      currentSequence: currentSequence,
    );

    return dirtyState != DirtyState.clean;
  }

  /// Returns the current file path for the document, if any.
  ///
  /// Returns null if the document has never been saved.
  String? getCurrentFilePath() {
    final documentId = _documentProvider.document.id;
    return _saveService.getCurrentFilePath(documentId);
  }

  /// Closes the current document.
  ///
  /// Releases database connections and resources.
  /// Call this when closing a document to free resources.
  Future<void> closeDocument() async {
    final documentId = _documentProvider.document.id;
    _logger.i('Closing document: $documentId');

    try {
      await _saveService.closeDocument(documentId);
      _logger.i('Document closed successfully: $documentId');
    } catch (e, stackTrace) {
      _logger.e('Error closing document', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Ensures a snapshot is created if needed before saving.
  ///
  /// Checks if the snapshot manager policy requires a snapshot at the
  /// current sequence number. If so, creates one.
  Future<void> _ensureSnapshotIfNeeded(int currentSequence) async {
    // Record event for snapshot manager's activity tracking (if available)
    // Note: recordEventApplied is only on DefaultSnapshotManager, not the interface
    final manager = _snapshotManager;
    if (manager is DefaultSnapshotManager) {
      manager.recordEventApplied(currentSequence);
    }

    // Check if snapshot should be created
    if (_snapshotManager.shouldCreateSnapshot(currentSequence)) {
      _logger.i('Creating snapshot before save at sequence $currentSequence');

      await _snapshotManager.createSnapshot(
        documentState: _documentProvider.toJson(),
        sequenceNumber: currentSequence,
      );
    }
  }

  /// Extracts the file name from a file path.
  String _getFileName(String filePath) => filePath.split('/').last;

  /// Returns an error result for context not mounted scenarios.
  SaveResult _contextNotMountedError() => const SaveFailure(
        errorType: SaveErrorType.unknown,
        userMessage: 'Cannot show save dialog: context not mounted',
        technicalDetails: 'BuildContext not mounted during save operation',
      );
}
