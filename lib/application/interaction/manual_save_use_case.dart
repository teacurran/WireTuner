/// Manual save use case with deduplication and auto-save coordination.
///
/// Implements the manual save workflow from Section 7.12 of the architecture,
/// providing:
/// - Deduplication: Prevents redundant document.saved events when no changes exist
/// - Auto-save coordination: Flushes pending auto-save before manual save
/// - Snapshot triggering: Creates snapshots during manual saves
/// - Status feedback: Provides UI-friendly status messages
///
/// **Manual Save Workflow:**
/// 1. Flush pending auto-save to ensure all events persisted
/// 2. Compare current sequence with last manual save sequence
/// 3. If no changes, show "No changes to save" and skip
/// 4. If changes exist, record document.saved event
/// 5. Trigger snapshot creation if threshold reached
/// 6. Update UI with save status
///
/// **Threading:** All methods must be called from the UI isolate.
library;

import 'package:event_core/event_core.dart';
import 'package:io_services/io_services.dart';
import 'package:logger/logger.dart';

import 'auto_save_manager.dart';

/// Result of a manual save operation.
sealed class ManualSaveResult {
  const ManualSaveResult();
}

/// Manual save succeeded with new document.saved event.
class ManualSaveSuccess extends ManualSaveResult {
  /// Creates a manual save success result.
  const ManualSaveSuccess({
    required this.sequenceNumber,
    required this.message,
    required this.snapshotCreated,
  });

  /// Sequence number of the document.saved event.
  final int sequenceNumber;

  /// User-friendly success message.
  final String message;

  /// Whether a snapshot was created during this save.
  final bool snapshotCreated;

  @override
  String toString() =>
      'ManualSaveSuccess(seq: $sequenceNumber, snapshot: $snapshotCreated, msg: $message)';
}

/// Manual save skipped because no changes exist.
class ManualSaveSkipped extends ManualSaveResult {
  /// Creates a manual save skipped result.
  const ManualSaveSkipped({
    required this.message,
  });

  /// User-friendly message explaining why save was skipped.
  final String message;

  @override
  String toString() => 'ManualSaveSkipped(msg: $message)';
}

/// Manual save failed due to error.
class ManualSaveFailure extends ManualSaveResult {
  /// Creates a manual save failure result.
  const ManualSaveFailure({
    required this.message,
    required this.technicalDetails,
  });

  /// User-friendly error message.
  final String message;

  /// Technical error details for logging.
  final String technicalDetails;

  @override
  String toString() => 'ManualSaveFailure(msg: $message)';
}

/// Use case for manual document saves (Cmd/Ctrl+S).
///
/// Coordinates between AutoSaveManager, SaveService, and EventStoreGateway
/// to provide a complete manual save workflow with deduplication.
///
/// **Usage:**
/// ```dart
/// final manualSaveUseCase = ManualSaveUseCase(
///   autoSaveManager: autoSaveManager,
///   saveService: saveService,
///   eventGateway: eventGateway,
///   snapshotManager: snapshotManager,
///   documentId: 'doc-123',
///   logger: logger,
/// );
///
/// // User presses Cmd/Ctrl+S
/// final result = await manualSaveUseCase.execute(
///   documentState: documentProvider.toJson(),
///   title: 'My Document',
/// );
///
/// // Handle result
/// if (result is ManualSaveSuccess) {
///   statusBar.show('Saved', duration: 2.seconds);
/// } else if (result is ManualSaveSkipped) {
///   statusBar.show('No changes to save', duration: 2.seconds);
/// }
/// ```
class ManualSaveUseCase {
  /// Creates a manual save use case.
  ManualSaveUseCase({
    required AutoSaveManager autoSaveManager,
    required SaveService saveService,
    required EventStoreGateway eventGateway,
    required SnapshotManager snapshotManager,
    required String documentId,
    required Logger logger,
  })  : _autoSaveManager = autoSaveManager,
        _saveService = saveService,
        _eventGateway = eventGateway,
        _snapshotManager = snapshotManager,
        _documentId = documentId,
        _logger = logger;

  final AutoSaveManager _autoSaveManager;
  final SaveService _saveService;
  final EventStoreGateway _eventGateway;
  // ignore: unused_field - SnapshotManager used via SaveService integration
  final SnapshotManager _snapshotManager;
  final String _documentId;
  final Logger _logger;

  /// Executes the manual save workflow.
  ///
  /// Parameters:
  /// - [documentState]: Current document state for snapshot creation
  /// - [title]: Document title for metadata
  /// - [filePath]: Optional file path (null triggers Save As behavior)
  ///
  /// Returns [ManualSaveResult] indicating success, skip, or failure.
  Future<ManualSaveResult> execute({
    required Map<String, dynamic> documentState,
    required String title,
    String? filePath,
  }) async {
    _logger.i('Manual save requested for document $_documentId');

    try {
      // Step 1: Flush pending auto-save to ensure all events persisted
      _logger.d('Flushing pending auto-save before manual save');
      final currentSequence = await _autoSaveManager.flushPendingAutoSave();

      // Step 2: Check if anything changed since last manual save (deduplication)
      if (!_autoSaveManager.hasChangesSinceLastManualSave(currentSequence)) {
        _logger.i(
          'No changes since last manual save at sequence ${_autoSaveManager.lastManualSaveSequence}',
        );
        return const ManualSaveSkipped(
          message: 'No changes to save',
        );
      }

      // Step 3: Record document.saved event
      _logger.d('Recording document.saved event at sequence $currentSequence');
      final savedEventData = createDocumentSavedEvent(
        eventId: _generateEventId(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        sequenceNumber: currentSequence + 1,
        filePath: filePath ?? _saveService.getCurrentFilePath(_documentId) ?? '',
        eventCount: currentSequence + 1,
      );

      await _eventGateway.persistEvent(savedEventData);

      final newSequence = currentSequence + 1;

      // Step 4: Perform save operation via SaveService
      _logger.d('Delegating to SaveService for persistence');
      final saveResult = await _saveService.save(
        documentId: _documentId,
        currentSequence: newSequence,
        documentState: documentState,
        title: title,
      );

      if (saveResult is SaveFailure) {
        _logger.e('SaveService failed: ${saveResult.technicalDetails}');
        return ManualSaveFailure(
          message: saveResult.userMessage,
          technicalDetails: saveResult.technicalDetails,
        );
      }

      final success = saveResult as SaveSuccess;

      // Step 5: Update auto-save manager's last manual save marker
      _autoSaveManager.recordManualSave(newSequence);

      _logger.i(
        'Manual save completed: seq=$newSequence, snapshot=${success.snapshotCreated}',
      );

      return ManualSaveSuccess(
        sequenceNumber: newSequence,
        message: 'Saved',
        snapshotCreated: success.snapshotCreated,
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Unexpected error during manual save',
        error: e,
        stackTrace: stackTrace,
      );
      return ManualSaveFailure(
        message: 'Failed to save document',
        technicalDetails: e.toString(),
      );
    }
  }

  /// Generates a unique event ID.
  String _generateEventId() =>
      'evt-${DateTime.now().millisecondsSinceEpoch}-${_documentId.hashCode}';
}

/// Creates a document.saved event as a JSON map.
///
/// This event marks an intentional save checkpoint in the event stream,
/// distinct from auto-save which happens silently in the background.
///
/// Returns a JSON map that can be persisted via EventStoreGateway.
Map<String, dynamic> createDocumentSavedEvent({
  required String eventId,
  required int timestamp,
  required int sequenceNumber,
  required String filePath,
  required int eventCount,
}) => {
      'eventId': eventId,
      'timestamp': timestamp,
      'eventType': 'document.saved',
      'sequenceNumber': sequenceNumber,
      'filePath': filePath,
      'eventCount': eventCount,
      'savedAt': DateTime.now().toIso8601String(),
    };
