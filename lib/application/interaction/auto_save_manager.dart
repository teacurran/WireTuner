/// Auto-save manager for continuous document persistence.
///
/// Implements the auto-save strategy from Section 7.12 of the architecture,
/// providing:
/// - Debounced auto-save with 200ms idle threshold
/// - Deduplication to avoid redundant saves
/// - Integration with EventStoreGateway for event persistence
/// - Status callbacks for UI feedback
///
/// **Auto-Save Strategy:**
/// - Triggers after 200ms of idle time following the last event
/// - Only persists when there are actual unsaved changes
/// - Does NOT record `document.saved` events (only manual saves do)
/// - Resets timer on every new event (debounce behavior)
///
/// **Manual Save Integration:**
/// - Manual saves call [flushPendingAutoSave] first to ensure all events persisted
/// - Manual saves compare sequence numbers to detect changes since last save
/// - Records `document.saved` event only when actual changes exist
///
/// **Threading:** All methods must be called from the UI isolate.
library;

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';

/// Callback for status updates when auto-save operations complete.
///
/// Parameters:
/// - [status]: The status of the auto-save operation
/// - [message]: User-friendly status message
/// - [eventCount]: Optional number of events saved
typedef AutoSaveStatusCallback = void Function({
  required AutoSaveStatus status,
  required String message,
  int? eventCount,
});

/// Status of auto-save operations.
enum AutoSaveStatus {
  /// Auto-save completed successfully.
  saved,

  /// No changes to save.
  noChanges,

  /// Auto-save failed.
  failed,
}

/// Manager for auto-save operations with debounce and deduplication.
///
/// **Usage:**
/// ```dart
/// final autoSaveManager = AutoSaveManager(
///   eventGateway: eventGateway,
///   documentId: 'doc-123',
///   onStatusUpdate: (status, message, {eventCount}) {
///     statusBar.showMessage(message);
///   },
/// );
///
/// // Record an event (triggers auto-save timer)
/// autoSaveManager.onEventRecorded();
///
/// // Manual save workflow
/// await autoSaveManager.flushPendingAutoSave();
/// final hasChanges = autoSaveManager.hasChangesSinceLastManualSave(currentSequence);
/// if (hasChanges) {
///   // Record document.saved event...
/// }
///
/// // Cleanup
/// autoSaveManager.dispose();
/// ```
class AutoSaveManager {
  /// Creates an auto-save manager.
  ///
  /// Parameters:
  /// - [eventGateway]: Gateway for event persistence
  /// - [documentId]: Document ID to manage auto-saves for
  /// - [onStatusUpdate]: Optional callback for status notifications
  /// - [idleThresholdMs]: Idle time before auto-save (default: 200ms)
  AutoSaveManager({
    required EventStoreGateway eventGateway,
    required String documentId,
    this.onStatusUpdate,
    this.idleThresholdMs = 200,
  })  : _eventGateway = eventGateway,
        _documentId = documentId;

  final EventStoreGateway _eventGateway;
  final String _documentId;

  /// Optional callback for status notifications.
  final AutoSaveStatusCallback? onStatusUpdate;

  /// Idle time in milliseconds before auto-save triggers.
  final int idleThresholdMs;
  final Logger _logger = Logger();

  /// Timer for debounced auto-save.
  Timer? _autoSaveTimer;

  /// Sequence number at last auto-save flush.
  int _lastAutoSavedSequence = -1;

  /// Sequence number at last manual save.
  int _lastManualSaveSequence = -1;

  /// Whether auto-save is currently in progress.
  bool _isSaving = false;

  /// Whether there are pending changes that need auto-save.
  bool _hasPendingChanges = false;

  /// Called when an event is recorded.
  ///
  /// This triggers the auto-save debounce timer. If events are being recorded
  /// rapidly, the timer is continuously reset until there's a 200ms idle period.
  void onEventRecorded() {
    _hasPendingChanges = true;

    // Cancel previous timer (debounce behavior)
    _autoSaveTimer?.cancel();

    // Start new auto-save timer
    _autoSaveTimer = Timer(
      Duration(milliseconds: idleThresholdMs),
      () => _performAutoSave(),
    );

    _logger.d(
        'Event recorded for document $_documentId, auto-save scheduled in ${idleThresholdMs}ms',);
  }

  /// Performs the auto-save operation.
  ///
  /// This is called automatically after the idle threshold expires.
  /// Only saves if there are pending changes.
  Future<void> _performAutoSave() async {
    // Clear timer reference since it's now fired
    _autoSaveTimer = null;

    if (!_hasPendingChanges) {
      _logger.d('No pending changes for document $_documentId, skipping auto-save');
      return;
    }

    if (_isSaving) {
      _logger.d('Auto-save already in progress for document $_documentId, skipping');
      return;
    }

    _isSaving = true;
    _logger.d('Performing auto-save for document $_documentId');

    try {
      // Get current sequence number
      final currentSequence = await _eventGateway.getLatestSequenceNumber();

      // Check if anything changed since last auto-save
      if (currentSequence == _lastAutoSavedSequence) {
        _logger.d('No new events since last auto-save (sequence: $currentSequence)');
        _hasPendingChanges = false;
        _isSaving = false;
        return;
      }

      // Events are already persisted by EventStoreGateway.persistEvent()
      // Auto-save just ensures they're flushed if using batching
      // Note: We don't record document.saved for auto-save

      final previousSequence = _lastAutoSavedSequence;
      _lastAutoSavedSequence = currentSequence;
      _hasPendingChanges = false;

      final eventCount = previousSequence == -1
          ? currentSequence + 1
          : currentSequence - previousSequence;
      _logger.i(
          'Auto-save completed for document $_documentId at sequence $currentSequence',);

      // Notify status callback
      onStatusUpdate?.call(
        status: AutoSaveStatus.saved,
        message: 'Auto-saved',
        eventCount: eventCount > 0 ? eventCount : null,
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Auto-save failed for document $_documentId',
        error: e,
        stackTrace: stackTrace,
      );

      // Don't reset pending changes flag - will retry on next event
      onStatusUpdate?.call(
        status: AutoSaveStatus.failed,
        message: 'Auto-save failed',
      );
    } finally {
      _isSaving = false;
    }
  }

  /// Flushes any pending auto-save immediately.
  ///
  /// This should be called before manual saves to ensure all events are
  /// persisted before recording the document.saved event.
  ///
  /// Returns the current sequence number after flush.
  Future<int> flushPendingAutoSave() async {
    _logger.d('Flushing pending auto-save for document $_documentId');

    // Cancel pending timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    // If auto-save is in progress, wait for it
    while (_isSaving) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Perform auto-save if there are pending changes
    if (_hasPendingChanges) {
      await _performAutoSave();
    }

    // Return current sequence number
    return await _eventGateway.getLatestSequenceNumber();
  }

  /// Checks if there are changes since the last manual save.
  ///
  /// Used for manual save deduplication - if no changes, don't record
  /// a redundant document.saved event.
  ///
  /// Parameters:
  /// - [currentSequence]: Current event sequence number
  ///
  /// Returns true if there are changes to save, false otherwise.
  bool hasChangesSinceLastManualSave(int currentSequence) {
    if (_lastManualSaveSequence == -1) {
      // Never saved manually - consider it changed if we have events
      return currentSequence >= 0;
    }

    return currentSequence > _lastManualSaveSequence;
  }

  /// Records that a manual save occurred at the given sequence.
  ///
  /// This updates the last manual save marker for deduplication.
  void recordManualSave(int sequenceNumber) {
    _lastManualSaveSequence = sequenceNumber;
    _logger.i(
        'Manual save recorded for document $_documentId at sequence $sequenceNumber',);
  }

  /// Returns whether auto-save is currently enabled and active.
  bool get isActive => _autoSaveTimer != null || _hasPendingChanges;

  /// Returns the sequence number of the last auto-save.
  int get lastAutoSavedSequence => _lastAutoSavedSequence;

  /// Returns the sequence number of the last manual save.
  int get lastManualSaveSequence => _lastManualSaveSequence;

  /// Returns whether auto-save is currently in progress.
  bool get isSaving => _isSaving;

  /// Disposes resources and cancels timers.
  ///
  /// Call this when the document is closed or the manager is no longer needed.
  void dispose() {
    _logger.d('Disposing auto-save manager for document $_documentId');
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _hasPendingChanges = false;
    _isSaving = false;
  }
}
