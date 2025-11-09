import 'dart:collection';
import 'dart:convert';
import 'package:logger/logger.dart';
import '../persistence/event_store.dart';
import 'event_replayer.dart';

/// Manages document state navigation for undo/redo operations with LRU caching.
///
/// The [EventNavigator] provides time-travel capabilities for documents by
/// maintaining a cache of recently visited states and coordinating with the
/// [EventReplayer] to reconstruct states at arbitrary sequence numbers.
///
/// **Usage Example:**
/// ```dart
/// // Create navigator
/// final navigator = EventNavigator(
///   documentId: 'doc123',
///   replayer: eventReplayer,
///   eventStore: eventStore,
/// );
///
/// // Undo operation
/// if (await navigator.canUndo()) {
///   final result = await navigator.undo();
///   if (result.hasIssues) {
///     print('Warning: ${result.warnings.length} issues during undo');
///   }
///   updateUI(result.state);
/// }
///
/// // Redo operation
/// if (await navigator.canRedo()) {
///   final result = await navigator.redo();
///   updateUI(result.state);
/// }
///
/// // Navigate to arbitrary sequence
/// final result = await navigator.navigateToSequence(5000);
/// updateUI(result.state);
/// ```
///
/// **Key Features:**
/// - **LRU Cache**: Keeps 10 most recently visited states in memory
/// - **Corruption Handling**: Gracefully handles corrupt events via EventReplayer
/// - **Efficient Navigation**: Cache hits avoid expensive replay operations
/// - **Performance**: Repeated undo/redo within cache window is < 1ms
///
/// **Design Rationale:**
/// - **Why LRU cache?** Users often undo/redo multiple times in quick succession
/// - **Why 10 entries?** Balances memory usage vs cache hit rate for typical workflows
/// - **Why immutable states?** Prevents accidental mutation bugs
/// - **Why async?** All operations may trigger database queries + replay
///
/// **Performance Characteristics:**
/// - Cache hit: < 1ms (simple map lookup + clone)
/// - Cache miss: 50-200ms (snapshot load + event replay via EventReplayer)
/// - Target: < 100ms for undo/redo operations (typically < 100 events to replay)
///
/// **Thread Safety**: Designed for single-threaded use on main isolate.
class EventNavigator {
  /// Creates an [EventNavigator] for the specified document.
  ///
  /// **Parameters:**
  /// - [documentId]: The document to navigate
  /// - [replayer]: EventReplayer for reconstructing states
  /// - [eventStore]: EventStore for querying max sequence number
  /// - [initialSequence]: Optional starting sequence (defaults to latest)
  ///
  /// **Usage Example:**
  /// ```dart
  /// final navigator = EventNavigator(
  ///   documentId: 'doc123',
  ///   replayer: eventReplayer,
  ///   eventStore: eventStore,
  ///   initialSequence: 100, // Start at sequence 100
  /// );
  /// ```
  EventNavigator({
    required String documentId,
    required EventReplayer replayer,
    required EventStore eventStore,
    int? initialSequence,
  })  : _documentId = documentId,
        _replayer = replayer,
        _eventStore = eventStore,
        _currentSequence = initialSequence ?? -1;
  final String _documentId;
  final EventReplayer _replayer;
  final EventStore _eventStore;
  final Logger _logger = Logger();

  /// Current sequence number the navigator is positioned at
  int _currentSequence = -1;

  /// Maximum sequence number available in the document
  int _maxSequence = -1;

  /// LRU cache of recently visited states (sequence -> state)
  /// Uses LinkedHashMap for insertion-order preservation
  final LinkedHashMap<int, dynamic> _stateCache = LinkedHashMap();

  /// Maximum number of states to keep in cache
  static const int _maxCacheSize = 10;

  /// Returns the current sequence number the navigator is positioned at.
  int get currentSequence => _currentSequence;

  /// Returns the maximum sequence number available in the document.
  ///
  /// This value is cached and updated whenever we query the event store.
  int get maxSequence => _maxSequence;

  /// Initializes the navigator by loading the latest state.
  ///
  /// This method should be called before any navigation operations.
  /// It loads the document at its latest state and caches it.
  ///
  /// **Usage Example:**
  /// ```dart
  /// final navigator = EventNavigator(...);
  /// final result = await navigator.initialize();
  /// if (result.hasIssues) {
  ///   showWarnings(result.warnings);
  /// }
  /// ```
  ///
  /// **Returns:** ReplayResult with the initial document state
  Future<ReplayResult> initialize() async {
    _logger.d('Initializing navigator for document: $_documentId');

    // Query max sequence
    _maxSequence = await _eventStore.getMaxSequence(_documentId);
    _currentSequence = _maxSequence;

    _logger.d('Document has max sequence: $_maxSequence');

    if (_maxSequence < 0) {
      // Empty document
      _logger.w('Document $_documentId has no events');
      final emptyState = {
        'id': _documentId,
        'title': 'Empty Document',
        'layers': [],
      };
      _putCache(_currentSequence, emptyState);
      return ReplayResult(state: emptyState);
    }

    // Load latest state
    return await navigateToSequence(_maxSequence);
  }

  /// Checks if undo operation is possible.
  ///
  /// Undo is possible if current sequence > 0.
  ///
  /// **Returns:** true if undo is possible, false otherwise
  Future<bool> canUndo() async => _currentSequence > 0;

  /// Checks if redo operation is possible.
  ///
  /// Redo is possible if current sequence < max sequence.
  ///
  /// **Returns:** true if redo is possible, false otherwise
  Future<bool> canRedo() async {
    // Refresh max sequence to handle new events
    final latestMax = await _eventStore.getMaxSequence(_documentId);
    if (latestMax > _maxSequence) {
      _maxSequence = latestMax;
    }
    return _currentSequence < _maxSequence;
  }

  /// Performs an undo operation (navigate to previous sequence).
  ///
  /// **Process:**
  /// 1. Check if undo is possible (currentSequence > 0)
  /// 2. Navigate to (currentSequence - 1)
  /// 3. Return state at previous sequence
  ///
  /// **Usage Example:**
  /// ```dart
  /// if (await navigator.canUndo()) {
  ///   final result = await navigator.undo();
  ///   updateDocumentState(result.state);
  /// }
  /// ```
  ///
  /// **Returns:** ReplayResult with state at previous sequence
  ///
  /// **Throws:** [StateError] if undo is not possible
  Future<ReplayResult> undo() async {
    if (!await canUndo()) {
      throw StateError('Cannot undo: already at sequence 0');
    }

    _logger.d(
        'Undo: navigating from $_currentSequence to ${_currentSequence - 1}');
    return await navigateToSequence(_currentSequence - 1);
  }

  /// Performs a redo operation (navigate to next sequence).
  ///
  /// **Process:**
  /// 1. Check if redo is possible (currentSequence < maxSequence)
  /// 2. Navigate to (currentSequence + 1)
  /// 3. Return state at next sequence
  ///
  /// **Usage Example:**
  /// ```dart
  /// if (await navigator.canRedo()) {
  ///   final result = await navigator.redo();
  ///   updateDocumentState(result.state);
  /// }
  /// ```
  ///
  /// **Returns:** ReplayResult with state at next sequence
  ///
  /// **Throws:** [StateError] if redo is not possible
  Future<ReplayResult> redo() async {
    if (!await canRedo()) {
      throw StateError('Cannot redo: already at latest sequence');
    }

    _logger.d(
        'Redo: navigating from $_currentSequence to ${_currentSequence + 1}');
    return await navigateToSequence(_currentSequence + 1);
  }

  /// Navigates to an arbitrary sequence number.
  ///
  /// This is the core navigation method used by undo(), redo(), and
  /// direct sequence navigation requests.
  ///
  /// **Process:**
  /// 1. Validate target sequence (must be >= 0 and <= maxSequence)
  /// 2. Check cache for target sequence
  /// 3. If cache hit: return cached state (fast path)
  /// 4. If cache miss: use EventReplayer to reconstruct state (slow path)
  /// 5. Cache the result
  /// 6. Update current sequence
  ///
  /// **Usage Example:**
  /// ```dart
  /// // Navigate to specific point in history
  /// final result = await navigator.navigateToSequence(5000);
  /// if (result.hasIssues) {
  ///   print('Encountered ${result.skippedSequences.length} corrupt events');
  /// }
  /// updateDocumentState(result.state);
  /// ```
  ///
  /// **Parameters:**
  /// - [targetSequence]: Sequence number to navigate to
  ///
  /// **Returns:** ReplayResult with state at target sequence
  ///
  /// **Throws:** [ArgumentError] if target sequence is invalid
  Future<ReplayResult> navigateToSequence(int targetSequence) async {
    // Validate target sequence
    if (targetSequence < 0) {
      throw ArgumentError(
          'Target sequence cannot be negative: $targetSequence');
    }

    // Refresh max sequence in case new events were added
    final latestMax = await _eventStore.getMaxSequence(_documentId);
    if (latestMax > _maxSequence) {
      _maxSequence = latestMax;
    }

    if (targetSequence > _maxSequence) {
      throw ArgumentError(
        'Target sequence $targetSequence exceeds max sequence $_maxSequence',
      );
    }

    _logger.d(
      'Navigating from sequence $_currentSequence to $targetSequence',
    );

    // Check cache first
    final cachedState = _getCache(targetSequence);
    if (cachedState != null) {
      _logger.d('Cache hit for sequence $targetSequence');
      _currentSequence = targetSequence;
      // Return cached state wrapped in ReplayResult
      return ReplayResult(state: _cloneState(cachedState));
    }

    // Cache miss - replay to target sequence
    _logger.d('Cache miss for sequence $targetSequence, replaying...');
    final result = await _replayer.replayToSequence(
      documentId: _documentId,
      targetSequence: targetSequence,
    );

    // Cache the result (if no issues, or if configured to cache even with issues)
    // For now, always cache to improve performance
    _putCache(targetSequence, result.state);

    // Update current sequence
    _currentSequence = targetSequence;

    if (result.hasIssues) {
      _logger.w(
        'Navigation to sequence $targetSequence completed with issues: '
        '${result.skippedSequences.length} skipped events',
      );
    } else {
      _logger.i('Successfully navigated to sequence $targetSequence');
    }

    return result;
  }

  /// Retrieves a state from cache.
  ///
  /// Also updates LRU order by removing and re-inserting the entry.
  dynamic _getCache(int sequence) {
    if (!_stateCache.containsKey(sequence)) {
      return null;
    }

    // Update LRU order: remove and re-add to move to end
    final state = _stateCache.remove(sequence);
    _stateCache[sequence] = state;
    return state;
  }

  /// Stores a state in cache with LRU eviction.
  ///
  /// If cache exceeds max size, evicts the oldest entry (first in LinkedHashMap).
  void _putCache(int sequence, dynamic state) {
    // If already cached, remove old entry to update position
    if (_stateCache.containsKey(sequence)) {
      _stateCache.remove(sequence);
    }

    // Add to cache (goes to end of LinkedHashMap)
    _stateCache[sequence] = _cloneState(state);

    // Evict oldest if over capacity
    if (_stateCache.length > _maxCacheSize) {
      final oldestKey = _stateCache.keys.first;
      _stateCache.remove(oldestKey);
      _logger.d('Evicted sequence $oldestKey from cache (LRU)');
    }
  }

  /// Clones a state to prevent mutation of cached states.
  ///
  /// Uses JSON serialization for deep cloning.
  /// TODO: Replace with proper Document.clone() method when Document model exists.
  dynamic _cloneState(dynamic state) {
    // For Map-based placeholder states, use JSON round-trip for deep clone
    if (state is Map<String, dynamic>) {
      return jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
    }
    // For other types, return as-is (immutable objects don't need cloning)
    return state;
  }

  /// Clears the state cache.
  ///
  /// Useful for testing or when memory needs to be reclaimed.
  void clearCache() {
    _logger.d('Clearing state cache (${_stateCache.length} entries)');
    _stateCache.clear();
  }

  /// Returns cache statistics for debugging.
  Map<String, dynamic> getCacheStats() => {
        'size': _stateCache.length,
        'capacity': _maxCacheSize,
        'sequences': _stateCache.keys.toList(),
        'currentSequence': _currentSequence,
        'maxSequence': _maxSequence,
      };
}
