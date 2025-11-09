import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';
import 'cursor_service.dart';

/// Context information for cursor state determination.
///
/// Provides contextual information that affects which cursor should be
/// displayed, such as hover state, modifier keys, and tool-specific modes.
class CursorContext {
  /// Creates cursor context with the given parameters.
  const CursorContext({
    this.isHoveringHandle = false,
    this.isHoveringAnchor = false,
    this.isHoveringObject = false,
    this.isDragging = false,
    this.isAngleLocked = false,
    this.isSnapping = false,
    this.customState,
  });

  /// Whether the cursor is hovering over a control handle.
  final bool isHoveringHandle;

  /// Whether the cursor is hovering over an anchor point.
  final bool isHoveringAnchor;

  /// Whether the cursor is hovering over a selectable object.
  final bool isHoveringObject;

  /// Whether a drag operation is in progress.
  final bool isDragging;

  /// Whether angle locking is active (e.g., Shift key held).
  final bool isAngleLocked;

  /// Whether snapping is active.
  final bool isSnapping;

  /// Tool-specific custom state for cursor determination.
  final Map<String, dynamic>? customState;

  /// Creates a copy with the given fields replaced.
  CursorContext copyWith({
    bool? isHoveringHandle,
    bool? isHoveringAnchor,
    bool? isHoveringObject,
    bool? isDragging,
    bool? isAngleLocked,
    bool? isSnapping,
    Map<String, dynamic>? customState,
  }) =>
      CursorContext(
        isHoveringHandle: isHoveringHandle ?? this.isHoveringHandle,
        isHoveringAnchor: isHoveringAnchor ?? this.isHoveringAnchor,
        isHoveringObject: isHoveringObject ?? this.isHoveringObject,
        isDragging: isDragging ?? this.isDragging,
        isAngleLocked: isAngleLocked ?? this.isAngleLocked,
        isSnapping: isSnapping ?? this.isSnapping,
        customState: customState ?? this.customState,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CursorContext &&
        other.isHoveringHandle == isHoveringHandle &&
        other.isHoveringAnchor == isHoveringAnchor &&
        other.isHoveringObject == isHoveringObject &&
        other.isDragging == isDragging &&
        other.isAngleLocked == isAngleLocked &&
        other.isSnapping == isSnapping;
  }

  @override
  int get hashCode => Object.hash(
        isHoveringHandle,
        isHoveringAnchor,
        isHoveringObject,
        isDragging,
        isAngleLocked,
        isSnapping,
      );
}

/// Enhanced cursor manager with platform-specific mappings and context awareness.
///
/// The [CursorManager] extends the base [CursorService] functionality by adding:
/// - Platform-specific cursor mappings (macOS vs Windows)
/// - Context-aware cursor selection (hover states, modifier keys)
/// - Integration with tool hint system
///
/// ## Platform-Specific Behavior
///
/// Per acceptance criteria, the cursor manager enforces platform parity:
/// - **macOS**: Uses [SystemMouseCursors.precise] for drawing tools
/// - **Windows**: Uses [SystemMouseCursors.basic] for drawing tools
///
/// This ensures consistent UX across platforms while respecting native conventions.
///
/// ## Architecture
///
/// ```
/// Tool → CursorManager → CursorService → MouseRegion
///                ↓
///         PlatformMapper
///         ContextResolver
/// ```
///
/// The manager acts as a smart layer between tools and the cursor service,
/// translating tool requests into platform-appropriate cursors.
///
/// ## Usage
///
/// ```dart
/// final cursorManager = CursorManager(cursorService: cursorService);
///
/// // Set cursor based on tool and context
/// cursorManager.setToolCursor(
///   toolId: 'pen',
///   baseCursor: SystemMouseCursors.precise,
///   context: CursorContext(isSnapping: true),
/// );
///
/// // Update context dynamically
/// cursorManager.updateContext(
///   context.copyWith(isHoveringHandle: true),
/// );
/// ```
///
/// ## Frame Budget Compliance
///
/// Per acceptance criteria, cursor updates must propagate within <1 frame.
/// The manager achieves this by:
/// - Delegating to synchronous [CursorService]
/// - Avoiding async operations
/// - Batching cursor changes (only updating when cursor actually changes)
///
/// Related: I3.T5, Decision 6 (platform parity)
class CursorManager extends ChangeNotifier {
  /// Creates a cursor manager wrapping the given cursor service.
  CursorManager({
    required CursorService cursorService,
    TargetPlatform? platform,
  })  : _cursorService = cursorService,
        _platform = platform ?? defaultTargetPlatform {
    _logger.d('CursorManager initialized for platform: $_platform');
  }

  /// The underlying cursor service.
  final CursorService _cursorService;

  /// The target platform for cursor mapping.
  final TargetPlatform _platform;

  /// Logger for debugging cursor decisions.
  final Logger _logger = Logger();

  /// Current cursor context.
  CursorContext _context = const CursorContext();

  /// Base cursor for the active tool.
  MouseCursor? _baseCursor;

  /// Current tool ID for logging.
  String? _activeToolId;

  /// Returns the current cursor context.
  CursorContext get context => _context;

  /// Returns the current cursor from the underlying service.
  MouseCursor get currentCursor => _cursorService.currentCursor;

  /// Returns the active tool ID.
  String? get activeToolId => _activeToolId;

  /// Sets the cursor for a tool with platform-specific mapping.
  ///
  /// This is the primary method tools should use to set their cursor.
  /// The manager will:
  /// 1. Apply platform-specific mappings
  /// 2. Consider the current context
  /// 3. Update the cursor service if needed
  ///
  /// Example:
  /// ```dart
  /// // Pen tool activation
  /// cursorManager.setToolCursor(
  ///   toolId: 'pen',
  ///   baseCursor: SystemMouseCursors.precise,
  /// );
  ///
  /// // Selection tool hovering over handle
  /// cursorManager.setToolCursor(
  ///   toolId: 'selection',
  ///   baseCursor: SystemMouseCursors.click,
  ///   context: CursorContext(isHoveringHandle: true),
  /// );
  /// ```
  void setToolCursor({
    required String toolId,
    required MouseCursor baseCursor,
    CursorContext? context,
  }) {
    _activeToolId = toolId;
    _baseCursor = baseCursor;

    if (context != null) {
      _context = context;
    }

    final resolvedCursor = _resolveCursor();
    _cursorService.setCursor(resolvedCursor);

    _logger.d(
      'Tool cursor set: toolId=$toolId, base=$baseCursor, '
      'resolved=$resolvedCursor, platform=$_platform',
    );
  }

  /// Updates the cursor context without changing the base cursor.
  ///
  /// This is useful when tool state changes (e.g., mouse moves over a handle)
  /// but the base tool cursor remains the same.
  ///
  /// Example:
  /// ```dart
  /// // User hovers over a handle
  /// cursorManager.updateContext(
  ///   CursorContext(isHoveringHandle: true),
  /// );
  ///
  /// // User presses Shift for angle lock
  /// cursorManager.updateContext(
  ///   context.copyWith(isAngleLocked: true),
  /// );
  /// ```
  void updateContext(CursorContext context) {
    if (_context == context) {
      return; // No change
    }

    _context = context;
    final resolvedCursor = _resolveCursor();
    _cursorService.setCursor(resolvedCursor);

    _logger.d('Context updated: $context → cursor=$resolvedCursor');
    notifyListeners();
  }

  /// Resets the cursor to the default state.
  ///
  /// This clears the tool cursor, context, and resets the cursor service.
  void reset() {
    _activeToolId = null;
    _baseCursor = null;
    _context = const CursorContext();
    _cursorService.reset();
    _logger.d('Cursor manager reset');
    notifyListeners();
  }

  /// Resolves the final cursor based on platform, base cursor, and context.
  ///
  /// This is the core logic that determines which cursor to display.
  /// Priority order:
  /// 1. Context-specific overrides (hovering, dragging)
  /// 2. Platform-specific mappings
  /// 3. Base cursor
  MouseCursor _resolveCursor() {
    // If no base cursor, return default
    if (_baseCursor == null) {
      return SystemMouseCursors.basic;
    }

    // Context overrides take priority
    if (_context.isDragging) {
      // Use move cursor during drag
      return SystemMouseCursors.move;
    }

    if (_context.isHoveringHandle) {
      // Use move cursor over handles
      return SystemMouseCursors.move;
    }

    if (_context.isHoveringAnchor) {
      // Use precise cursor over anchors
      return _mapPreciseCursor();
    }

    // Apply platform-specific mapping to base cursor
    return _mapCursorForPlatform(_baseCursor!);
  }

  /// Maps a cursor to the platform-specific equivalent.
  ///
  /// This implements the platform parity requirements from Decision 6:
  /// - macOS uses precise cursors for drawing tools
  /// - Windows uses basic cursors for drawing tools
  MouseCursor _mapCursorForPlatform(MouseCursor cursor) {
    // Only map precise cursor differently per platform
    if (cursor == SystemMouseCursors.precise) {
      return _mapPreciseCursor();
    }

    // All other cursors are platform-agnostic
    return cursor;
  }

  /// Maps the precise cursor based on platform.
  ///
  /// - macOS: [SystemMouseCursors.precise]
  /// - Windows/Linux: [SystemMouseCursors.basic]
  MouseCursor _mapPreciseCursor() {
    switch (_platform) {
      case TargetPlatform.macOS:
        return SystemMouseCursors.precise;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return SystemMouseCursors.basic;
      default:
        // Fallback for other platforms (iOS, Android, Fuchsia)
        return SystemMouseCursors.basic;
    }
  }

  @override
  void dispose() {
    _logger.d('CursorManager disposed');
    super.dispose();
  }

  @override
  String toString() => 'CursorManager('
      'tool: $_activeToolId, '
      'base: $_baseCursor, '
      'current: ${_cursorService.currentCursor}, '
      'platform: $_platform'
      ')';
}
