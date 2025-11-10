import 'package:logger/logger.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_navigator.dart';
import 'package:wiretuner/presentation/state/document_provider.dart';

/// Service that coordinates undo/redo operations between EventNavigator and DocumentProvider.
///
/// The [UndoService] acts as a bridge between the event sourcing infrastructure
/// and the Flutter UI layer. It:
/// - Wraps the EventNavigator to provide undo/redo operations
/// - Converts replayed state maps into Document instances
/// - Updates DocumentProvider with the reconstructed document
/// - Handles errors and warnings from event replay
///
/// **Usage Example:**
/// ```dart
/// final service = UndoService(
///   navigator: eventNavigator,
///   documentProvider: documentProvider,
/// );
///
/// // Initialize the service
/// await service.initialize();
///
/// // Perform undo
/// if (await service.canUndo()) {
///   await service.undo();
/// }
///
/// // Perform redo
/// if (await service.canRedo()) {
///   await service.redo();
/// }
/// ```
///
/// **Design Rationale:**
/// - **Separation of Concerns**: Event sourcing logic is separate from UI state management
/// - **Type Safety**: Converts untyped maps to strongly-typed Document instances
/// - **Error Handling**: Gracefully handles corrupt events and deserialization failures
/// - **Observable**: Integrates with Flutter's ChangeNotifier pattern via DocumentProvider
///
/// **Integration Points:**
/// - Uses [EventNavigator] for event replay and state reconstruction
/// - Updates [DocumentProvider] to trigger UI updates
/// - Logs warnings for corrupt events or deserialization issues
class UndoService {
  /// Creates an undo service.
  ///
  /// **Parameters:**
  /// - [navigator]: The EventNavigator for state reconstruction
  /// - [documentProvider]: The DocumentProvider to update with reconstructed state
  UndoService({
    required EventNavigator navigator,
    required DocumentProvider documentProvider,
  })  : _navigator = navigator,
        _documentProvider = documentProvider;

  final EventNavigator _navigator;
  final DocumentProvider _documentProvider;
  final Logger _logger = Logger();

  /// Initializes the undo service by loading the initial document state.
  ///
  /// This method should be called once after creating the service. It loads
  /// the document at its latest state and updates the DocumentProvider.
  ///
  /// **Returns:** true if initialization succeeded, false otherwise
  ///
  /// **Throws:** Any exceptions from EventNavigator or DocumentProvider
  Future<bool> initialize() async {
    try {
      _logger.d('Initializing UndoService');

      // Load initial state via navigator
      final result = await _navigator.initialize();

      // Convert state to Document and update provider
      if (result.hasIssues) {
        _logger.w(
          'Initial state loaded with issues: '
          '${result.skippedSequences.length} skipped events',
        );
        for (final warning in result.warnings) {
          _logger.w('Warning: $warning');
        }
      }

      _updateDocumentFromState(result.state);

      _logger.i('UndoService initialized at sequence ${_navigator.currentSequence}');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to initialize UndoService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Returns the current event sequence number.
  int get currentSequence => _navigator.currentSequence;

  /// Returns the maximum event sequence number.
  int get maxSequence => _navigator.maxSequence;

  /// Checks if undo operation is possible.
  ///
  /// **Returns:** true if undo is possible, false otherwise
  Future<bool> canUndo() => _navigator.canUndo();

  /// Checks if redo operation is possible.
  ///
  /// **Returns:** true if redo is possible, false otherwise
  Future<bool> canRedo() => _navigator.canRedo();

  /// Performs an undo operation.
  ///
  /// Navigates to the previous event sequence and updates the document state.
  ///
  /// **Process:**
  /// 1. Call EventNavigator.undo() to get previous state
  /// 2. Convert state map to Document instance
  /// 3. Update DocumentProvider to trigger UI updates
  /// 4. Log any warnings from corrupted events
  ///
  /// **Returns:** true if undo succeeded, false otherwise
  ///
  /// **Throws:** [StateError] if undo is not possible
  Future<bool> undo() async {
    if (!await canUndo()) {
      _logger.w('Cannot undo: already at beginning of history');
      return false;
    }

    try {
      _logger.d('Performing undo from sequence ${_navigator.currentSequence}');

      final result = await _navigator.undo();

      if (result.hasIssues) {
        _logger.w(
          'Undo completed with issues: '
          '${result.skippedSequences.length} skipped events',
        );
        for (final warning in result.warnings) {
          _logger.w('Warning: $warning');
        }
      }

      _updateDocumentFromState(result.state);

      _logger.i('Undo successful, now at sequence ${_navigator.currentSequence}');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Undo failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Performs a redo operation.
  ///
  /// Navigates to the next event sequence and updates the document state.
  ///
  /// **Process:**
  /// 1. Call EventNavigator.redo() to get next state
  /// 2. Convert state map to Document instance
  /// 3. Update DocumentProvider to trigger UI updates
  /// 4. Log any warnings from corrupted events
  ///
  /// **Returns:** true if redo succeeded, false otherwise
  ///
  /// **Throws:** [StateError] if redo is not possible
  Future<bool> redo() async {
    if (!await canRedo()) {
      _logger.w('Cannot redo: already at latest state');
      return false;
    }

    try {
      _logger.d('Performing redo from sequence ${_navigator.currentSequence}');

      final result = await _navigator.redo();

      if (result.hasIssues) {
        _logger.w(
          'Redo completed with issues: '
          '${result.skippedSequences.length} skipped events',
        );
        for (final warning in result.warnings) {
          _logger.w('Warning: $warning');
        }
      }

      _updateDocumentFromState(result.state);

      _logger.i('Redo successful, now at sequence ${_navigator.currentSequence}');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Redo failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Navigates to a specific event sequence.
  ///
  /// This is used for scrubbing through history (e.g., clicking on a specific
  /// point in the history timeline).
  ///
  /// **Parameters:**
  /// - [targetSequence]: The event sequence number to navigate to
  ///
  /// **Returns:** true if navigation succeeded, false otherwise
  Future<bool> navigateToSequence(int targetSequence) async {
    try {
      _logger.d('Navigating to sequence $targetSequence');

      final result = await _navigator.navigateToSequence(targetSequence);

      if (result.hasIssues) {
        _logger.w(
          'Navigation completed with issues: '
          '${result.skippedSequences.length} skipped events',
        );
      }

      _updateDocumentFromState(result.state);

      _logger.i('Navigation successful, now at sequence ${_navigator.currentSequence}');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Navigation to sequence $targetSequence failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Converts a state map to a Document instance and updates DocumentProvider.
  ///
  /// This method handles the conversion from the untyped map returned by
  /// EventReplayer to a strongly-typed Document instance.
  ///
  /// **Parameters:**
  /// - [state]: The state map from EventReplayer (Map<String, dynamic>)
  ///
  /// **Error Handling:**
  /// - Logs errors if deserialization fails
  /// - Falls back to empty document if state is invalid
  void _updateDocumentFromState(dynamic state) {
    try {
      // EventReplayer returns Map<String, dynamic> placeholder states
      if (state is Map<String, dynamic>) {
        // Convert map to Document instance
        final document = Document.fromJson(state);
        _documentProvider.updateDocument(document);
        _logger.d('Updated document: ${document.id}');
      } else {
        _logger.e('Invalid state type: ${state.runtimeType}');
        // Fall back to empty document
        _documentProvider.updateDocument(
          Document(
            id: _documentProvider.document.id,
            title: 'Error Loading Document',
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to deserialize document from state',
        error: e,
        stackTrace: stackTrace,
      );
      // Fall back to empty document
      _documentProvider.updateDocument(
        Document(
          id: _documentProvider.document.id,
          title: 'Error Loading Document',
        ),
      );
    }
  }

  /// Clears the navigator cache.
  ///
  /// This is useful for testing or when memory needs to be reclaimed.
  void clearCache() {
    _navigator.clearCache();
  }

  /// Returns cache statistics for debugging.
  Map<String, dynamic> getCacheStats() => _navigator.getCacheStats();
}
