/// Save status indicator widget for displaying auto-save and manual save feedback.
///
/// Provides visual feedback for:
/// - Auto-save operations ("Auto-saved" with subtle styling)
/// - Manual save operations ("Saved" with prominent styling)
/// - No-change saves ("No changes to save")
/// - Save errors
///
/// Follows WCAG accessibility guidelines with appropriate contrast and
/// screen-reader-friendly labels.
library;

import 'package:flutter/material.dart';
import 'package:wiretuner/application/interaction/auto_save_manager.dart';

/// Status of the save operation being displayed.
enum SaveIndicatorStatus {
  /// Auto-save completed successfully.
  autoSaved,

  /// Manual save completed successfully.
  saved,

  /// No changes to save.
  noChanges,

  /// Save operation failed.
  error,

  /// Idle (no status to show).
  idle,
}

/// A status indicator widget for save operations.
///
/// Displays temporary status messages with appropriate styling based on
/// the save operation type.
///
/// **Usage:**
/// ```dart
/// // In your widget tree
/// SaveStatusIndicator(
///   controller: saveStatusController,
/// )
///
/// // Trigger status updates
/// saveStatusController.showAutoSaved();
/// saveStatusController.showSaved();
/// saveStatusController.showNoChanges();
/// saveStatusController.showError('Failed to save');
/// ```
class SaveStatusIndicator extends StatelessWidget {
  /// Creates a save status indicator widget.
  const SaveStatusIndicator({
    super.key,
    required this.controller,
  });

  /// Controller that manages the status state.
  final SaveStatusController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
        if (controller.status == SaveIndicatorStatus.idle) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(controller.status),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(controller.status),
                size: 16,
                color: _getTextColor(controller.status),
              ),
              const SizedBox(width: 6),
              Text(
                controller.message,
                style: TextStyle(
                  fontSize: 12,
                  color: _getTextColor(controller.status),
                  fontWeight: _getFontWeight(controller.status),
                ),
              ),
            ],
          ),
        );
        },
      );

  Color _getBackgroundColor(SaveIndicatorStatus status) {
    switch (status) {
      case SaveIndicatorStatus.autoSaved:
        return Colors.grey[300]!;
      case SaveIndicatorStatus.saved:
        return Colors.green[100]!;
      case SaveIndicatorStatus.noChanges:
        return Colors.blue[100]!;
      case SaveIndicatorStatus.error:
        return Colors.red[100]!;
      case SaveIndicatorStatus.idle:
        return Colors.transparent;
    }
  }

  Color _getTextColor(SaveIndicatorStatus status) {
    switch (status) {
      case SaveIndicatorStatus.autoSaved:
        return Colors.grey[700]!;
      case SaveIndicatorStatus.saved:
        return Colors.green[900]!;
      case SaveIndicatorStatus.noChanges:
        return Colors.blue[900]!;
      case SaveIndicatorStatus.error:
        return Colors.red[900]!;
      case SaveIndicatorStatus.idle:
        return Colors.black;
    }
  }

  IconData _getIcon(SaveIndicatorStatus status) {
    switch (status) {
      case SaveIndicatorStatus.autoSaved:
      case SaveIndicatorStatus.saved:
        return Icons.check_circle;
      case SaveIndicatorStatus.noChanges:
        return Icons.info;
      case SaveIndicatorStatus.error:
        return Icons.error;
      case SaveIndicatorStatus.idle:
        return Icons.circle;
    }
  }

  FontWeight _getFontWeight(SaveIndicatorStatus status) {
    switch (status) {
      case SaveIndicatorStatus.autoSaved:
        return FontWeight.normal;
      case SaveIndicatorStatus.saved:
      case SaveIndicatorStatus.noChanges:
      case SaveIndicatorStatus.error:
        return FontWeight.w600;
      case SaveIndicatorStatus.idle:
        return FontWeight.normal;
    }
  }
}

/// Controller for managing save status indicator state.
///
/// Handles automatic hiding of status messages after a timeout.
class SaveStatusController extends ChangeNotifier {
  SaveIndicatorStatus _status = SaveIndicatorStatus.idle;
  String _message = '';

  /// Current status being displayed.
  SaveIndicatorStatus get status => _status;

  /// Current message text.
  String get message => _message;

  /// Shows auto-save status (subtle, 1 second duration).
  void showAutoSaved({int? eventCount}) {
    _updateStatus(
      SaveIndicatorStatus.autoSaved,
      'Auto-saved',
      const Duration(seconds: 1),
    );
  }

  /// Shows manual save status (prominent, 2 seconds duration).
  void showSaved({bool snapshotCreated = false}) {
    _updateStatus(
      SaveIndicatorStatus.saved,
      snapshotCreated ? 'Saved (snapshot created)' : 'Saved',
      const Duration(seconds: 2),
    );
  }

  /// Shows no-changes status (2 seconds duration).
  void showNoChanges() {
    _updateStatus(
      SaveIndicatorStatus.noChanges,
      'No changes to save',
      const Duration(seconds: 2),
    );
  }

  /// Shows error status (persistent until dismissed or new status).
  void showError(String errorMessage) {
    _updateStatus(
      SaveIndicatorStatus.error,
      errorMessage,
      null, // No auto-hide for errors
    );
  }

  /// Manually clears the current status.
  void clear() {
    _status = SaveIndicatorStatus.idle;
    _message = '';
    notifyListeners();
  }

  void _updateStatus(
    SaveIndicatorStatus newStatus,
    String newMessage,
    Duration? autoHideDuration,
  ) {
    _status = newStatus;
    _message = newMessage;
    notifyListeners();

    if (autoHideDuration != null) {
      Future.delayed(autoHideDuration, () {
        if (_status == newStatus) {
          // Only clear if status hasn't changed
          clear();
        }
      });
    }
  }
}

/// Provider wrapper for SaveStatusController.
///
/// Integrates with AutoSaveManager to automatically update status.
class SaveStatusProvider extends ChangeNotifier {
  /// Creates a save status provider.
  SaveStatusProvider({
    required this.controller,
    AutoSaveManager? autoSaveManager,
  }) {
    // Wire up auto-save callbacks
    if (autoSaveManager != null) {
      _setupAutoSaveCallbacks(autoSaveManager);
    }
  }

  /// The underlying status controller.
  final SaveStatusController controller;

  void _setupAutoSaveCallbacks(AutoSaveManager autoSaveManager) {
    // Note: This would require AutoSaveManager to accept a callback
    // For now, this is a placeholder for integration
  }

  /// Handles auto-save status updates.
  void onAutoSaveCompleted({int? eventCount}) {
    controller.showAutoSaved(eventCount: eventCount);
  }

  /// Handles manual save status updates.
  void onManualSaveCompleted({bool snapshotCreated = false}) {
    controller.showSaved(snapshotCreated: snapshotCreated);
  }

  /// Handles no-changes status.
  void onNoChangesToSave() {
    controller.showNoChanges();
  }

  /// Handles save errors.
  void onSaveError(String errorMessage) {
    controller.showError(errorMessage);
  }
}
