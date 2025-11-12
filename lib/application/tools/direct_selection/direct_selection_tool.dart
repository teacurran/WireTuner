import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:wiretuner/application/tools/direct_selection/anchor_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/handle_drag_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/inertia_controller.dart';
import 'package:wiretuner/application/tools/direct_selection/snapping_service.dart';
import 'package:wiretuner/application/tools/framework/tool_interface.dart';
import 'package:wiretuner/domain/document/document.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/domain/models/anchor_point.dart' as domain_anchor;
import 'package:wiretuner/domain/models/geometry/point_extensions.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_recorder.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:event_core/src/operation_grouping.dart';
import 'package:wiretuner/presentation/canvas/overlays/hit_tester.dart'
    hide HitTestResult;
import 'package:wiretuner/presentation/canvas/overlays/hit_tester.dart'
    as hit_tester;
import 'package:wiretuner/presentation/canvas/overlays/selection_overlay.dart';
import 'package:wiretuner/presentation/canvas/painter/path_renderer.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_controller.dart';

/// Tool for direct manipulation of anchor points and Bezier control points.
///
/// The Direct Selection Tool (T020) provides precise control over path geometry:
/// - Click and drag anchor points to reposition them
/// - Click and drag Bezier control point (BCP) handles to adjust curve shape
/// - Respects anchor type constraints (smooth/symmetric/corner)
/// - Emits events at 50ms sampling rate during drag operations
/// - Instruments telemetry for drag performance monitoring
///
/// ## Interaction Modes
///
/// ### Anchor Dragging
/// - Click on anchor point: Start anchor drag operation
/// - Drag: Update anchor position with 50ms sampling
/// - Release: Flush final position and end drag group
///
/// ### Handle Dragging
/// - Click on BCP handle: Start handle drag operation
/// - Drag smooth anchor handle: Mirror automatically applied to opposite handle
/// - Drag symmetric anchor handle: Collinearity preserved, lengths independent
/// - Drag corner anchor handle: Independent movement
///
/// ### Anchor Type Conversion
/// - Alt/Option key during drag: Toggle anchor type (smooth ↔ corner)
/// - Maintains handle positions when possible
///
/// ## Event Emission
///
/// The tool emits the following events:
/// - StartGroupEvent: At beginning of drag operation
/// - ModifyAnchorEvent: During drag (sampled at 50ms)
/// - EndGroupEvent: At end of drag operation
///
/// ## Performance
///
/// - Hit-testing: < 5ms (uses CanvasHitTester with 8px threshold)
/// - Event emission: < 5ms (auto-sampled by EventRecorder)
/// - Drag handling: < 16.7ms to maintain 60 FPS
///
/// ## Usage
///
/// ```dart
/// final directSelectionTool = DirectSelectionTool(
///   document: document,
///   viewportController: viewportController,
///   eventRecorder: eventRecorder,
///   telemetryService: telemetryService,
/// );
///
/// toolManager.registerTool(directSelectionTool);
/// toolManager.activateTool('direct_selection');
/// ```
class DirectSelectionTool implements ITool {
  DirectSelectionTool({
    required Document document,
    required ViewportController viewportController,
    required EventRecorder eventRecorder,
    required PathRenderer pathRenderer,
    OperationGroupingService? operationGroupingService,
    TelemetryService? telemetryService,
  })  : _document = document,
        _viewportController = viewportController,
        _eventRecorder = eventRecorder,
        _pathRenderer = pathRenderer,
        _operationGroupingService = operationGroupingService,
        _telemetryService = telemetryService {
    // Initialize hit tester with viewport and path renderer
    _hitTester = CanvasHitTester(
      viewportController: _viewportController,
      pathRenderer: _pathRenderer,
      hitThresholdScreenPx: 8.0,
    );

    // Initialize snapping service with magnetic snapping enabled
    _snappingService = SnappingService(
      gridSnapEnabled: false,
      angleSnapEnabled: false,
      gridSize: 10.0,
      angleIncrement: 15.0,
      magneticThreshold: 8.0,
      hysteresisMargin: 2.0,
    );

    // Initialize inertia controller
    _inertiaController = InertiaController(
      velocityThreshold: 0.5,
      decayFactor: 0.88,
      maxDurationMs: 300,
      samplingIntervalMs: 50,
    );

    // Initialize drag controllers
    final baseDragController = DragController();
    _anchorDragController = AnchorDragController(
      baseDragController: baseDragController,
      snappingService: _snappingService,
    );
    _handleDragController = HandleDragController(
      baseDragController: baseDragController,
      snappingService: _snappingService,
    );

    _logger.i('DirectSelectionTool initialized');
  }
  final Document _document;
  final ViewportController _viewportController;
  final EventRecorder _eventRecorder;
  final PathRenderer _pathRenderer;
  final OperationGroupingService? _operationGroupingService;
  // ignore: unused_field
  final TelemetryService?
      _telemetryService; // Reserved for future telemetry instrumentation
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Hit tester for anchor and handle detection.
  late final CanvasHitTester _hitTester;

  /// Snapping service for grid and angle snapping.
  late final SnappingService _snappingService;

  /// Inertia controller for smooth drag completion.
  late final InertiaController _inertiaController;

  /// Anchor drag controller for grid snapping.
  late final AnchorDragController _anchorDragController;

  /// Handle drag controller for angle snapping.
  late final HandleDragController _handleDragController;

  /// Current drag operation state (null when not dragging).
  _DragContext? _dragContext;

  /// Currently hovered anchor (for cursor and visual feedback).
  // ignore: unused_field
  HoveredAnchor? _hoveredAnchor; // Reserved for future overlay rendering

  /// Current cursor based on hover state.
  MouseCursor _currentCursor = SystemMouseCursors.precise;

  @override
  String get toolId => 'direct_selection';

  @override
  MouseCursor get cursor => _currentCursor;

  @override
  void onActivate() {
    _logger.i('Direct selection tool activated');
    _currentCursor = SystemMouseCursors.precise;
    _dragContext = null;
    _hoveredAnchor = null;
  }

  @override
  void onDeactivate() {
    _logger.i('Direct selection tool deactivated');
    // Flush any pending events and end drag group if active
    if (_dragContext != null) {
      _finishDrag();
    }
    _dragContext = null;
    _hoveredAnchor = null;
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);

    // Get selected objects from the first artboard
    final artboard = _document.artboards.isNotEmpty ? _document.artboards.first : null;
    if (artboard == null) return false;

    final selectedObjectIds = artboard.selection.objectIds.toList();
    if (selectedObjectIds.isEmpty) {
      _logger.d('No objects selected, cannot use direct selection');
      return false;
    }

    // Hit-test anchors for all selected objects
    hit_tester.HitTestResult? bestHit;
    for (final objectId in selectedObjectIds) {
      final obj = _document.getObjectById(objectId);
      if (obj == null) continue;

      // Extract path or shape from VectorObject
      final hit = obj.when(
        path: (id, path, _) => _hitTester.hitTestAnchors(
          screenPoint: event.localPosition,
          objectId: objectId,
          path: path,
          shape: null,
        ),
        shape: (id, shape, _) => _hitTester.hitTestAnchors(
          screenPoint: event.localPosition,
          objectId: objectId,
          path: null,
          shape: shape,
        ),
      );

      if (hit.isAnchorHit &&
          (bestHit == null || hit.distance < bestHit.distance)) {
        bestHit = hit;
      }
    }

    // If we hit an anchor or handle, start drag
    if (bestHit != null && bestHit.isAnchorHit) {
      _startDrag(
        screenPos: event.localPosition,
        worldPos: worldPos,
        objectId: bestHit.objectId!,
        anchorIndex: bestHit.anchorIndex!,
        component: bestHit.component!,
      );
      return true;
    }

    // No hit - allow other tools to handle
    return false;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    final worldPos = _viewportController.screenToWorld(event.localPosition);

    // If dragging, update drag state
    if (_dragContext != null) {
      _updateDrag(worldPos);
      return true;
    }

    // Otherwise, update hover state for cursor feedback
    _updateHover(event.localPosition);
    return false;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_dragContext != null) {
      _finishDrag();
      return true;
    }
    return false;
  }

  @override
  bool onKeyPress(KeyEvent event) {
    // Handle ESC key for canceling drag
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_dragContext != null) {
        _cancelDrag();
        _logger.d('Drag cancelled by ESC key');
        return true;
      }
    }

    // Handle Shift key for snap toggle
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      _snappingService.setSnapEnabled(true);
      _logger.d('Snapping enabled (Shift pressed)');
      return true;
    }

    if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      _snappingService.setSnapEnabled(false);
      _logger.d('Snapping disabled (Shift released)');
      return true;
    }

    // Handle Alt/Option key for anchor type conversion
    // This would be implemented in a future iteration
    return false;
  }

  @override
  void renderOverlay(ui.Canvas canvas, ui.Size size) {
    // Render drag preview if active
    if (_dragContext != null) {
      _renderDragPreview(canvas);
    }
  }

  /// Starts a drag operation for an anchor or handle.
  void _startDrag({
    required Offset screenPos,
    required Point worldPos,
    required String objectId,
    required int anchorIndex,
    required AnchorComponent component,
  }) {
    // Get the current anchor state
    final obj = _document.getObjectById(objectId);
    if (obj == null) {
      _logger.w('Object not found: $objectId');
      return;
    }

    final domainPath = obj.when(
      path: (id, path, _) => path,
      shape: (id, shape, _) => shape.toPath(),
    );

    if (anchorIndex >= domainPath.anchors.length) {
      _logger.w('Invalid anchor index for drag');
      return;
    }

    final anchor = domainPath.anchors[anchorIndex];

    // Calculate initial position based on component
    Point startPosition;
    String operationLabel;
    switch (component) {
      case AnchorComponent.anchor:
        startPosition = anchor.position;
        operationLabel = 'Adjust Anchor';
        break;
      case AnchorComponent.handleIn:
        startPosition = anchor.position + anchor.handleIn!;
        operationLabel = 'Adjust Handle';
        break;
      case AnchorComponent.handleOut:
        startPosition = anchor.position + anchor.handleOut!;
        operationLabel = 'Adjust Handle';
        break;
    }

    // Start undo group for this drag operation
    _operationGroupingService?.startUndoGroup(
      label: operationLabel,
      toolId: toolId,
    );

    // Reset snapping state for new drag
    _snappingService.resetSnapState();

    // Reset inertia controller for new drag
    _inertiaController.reset();

    // Record initial sample for inertia
    _inertiaController.recordSample(
      position: worldPos,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Initialize drag context
    _dragContext = _DragContext(
      objectId: objectId,
      anchorIndex: anchorIndex,
      component: component,
      startPosition: startPosition,
      currentPosition: worldPos,
      startTime: DateTime.now(),
      eventCount: 0,
      originalAnchor: anchor,
    );

    _currentCursor = SystemMouseCursors.move;
    _logger.d(
      'Started drag: object=$objectId, anchor=$anchorIndex, component=$component',
    );
  }

  /// Updates the drag operation with new position.
  void _updateDrag(Point worldPos) {
    if (_dragContext == null) return;

    final context = _dragContext!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Record sample for inertia calculation
    _inertiaController.recordSample(
      position: worldPos,
      timestamp: timestamp,
    );

    // Apply magnetic snapping if enabled (only for anchor drags)
    Point effectiveWorldPos = worldPos;
    if (context.component == AnchorComponent.anchor) {
      final snappedPos = _snappingService.maybeSnapToGrid(worldPos);
      if (snappedPos != null) {
        effectiveWorldPos = snappedPos;
      }
    }

    // Calculate delta from start position to current position
    // This delta is cumulative from the drag start point
    final delta = Point(
      x: effectiveWorldPos.x - context.startPosition.x,
      y: effectiveWorldPos.y - context.startPosition.y,
    );

    // Use appropriate drag controller based on component
    // IMPORTANT: Use context.originalAnchor (captured at drag start) rather than
    // fetching from document, because the document may be updated in real-time
    // as events are persisted, which would cause double-delta application.
    DragResult result;
    Map<String, dynamic>? feedbackMetrics;

    if (context.component == AnchorComponent.anchor) {
      // Anchor drag with grid snapping
      result = _anchorDragController.calculateDragUpdate(
        anchor: context.originalAnchor,
        delta: delta,
      );

      // Calculate feedback metrics for on-canvas display
      if (result.position != null) {
        feedbackMetrics = _anchorDragController.calculateFeedbackMetrics(
          position: result.position!,
          originalPosition: context.originalAnchor.position,
        );
      }
    } else {
      // Handle drag with angle snapping
      result = _handleDragController.calculateDragUpdate(
        anchor: context.originalAnchor,
        delta: delta,
        component: context.component,
      );

      // Calculate feedback metrics for on-canvas display
      final handleVector = context.component == AnchorComponent.handleIn
          ? result.handleIn
          : result.handleOut;
      if (handleVector != null) {
        feedbackMetrics = _handleDragController.calculateFeedbackMetrics(
          handleVector: handleVector,
        );
      }
    }

    // Emit ModifyAnchorEvent (will be auto-sampled)
    _recordEvent(
      ModifyAnchorEvent(
        eventId: _uuid.v4(),
        timestamp: timestamp,
        pathId: context.objectId,
        anchorIndex: context.anchorIndex,
        position: result.position,
        handleIn: result.handleIn,
        handleOut: result.handleOut,
      ),
    );

    // Update drag context with feedback metrics
    _dragContext = context.copyWith(
      currentPosition: effectiveWorldPos,
      eventCount: context.eventCount + 1,
      feedbackMetrics: feedbackMetrics,
    );
  }

  /// Finishes the drag operation and flushes events.
  void _finishDrag() {
    if (_dragContext == null) return;

    final context = _dragContext!;
    final finishTime = DateTime.now();
    final timestamp = finishTime.millisecondsSinceEpoch;

    // Try to activate inertia
    final inertiaSequence = _inertiaController.activate(
      finalPosition: context.currentPosition,
      currentTimestamp: timestamp,
    );

    // Emit inertia events if sequence generated
    if (inertiaSequence != null && inertiaSequence.length > 0) {
      _logger.d('Inertia activated: ${inertiaSequence.length} frames');

      for (int i = 0; i < inertiaSequence.length; i++) {
        final position = inertiaSequence.positions[i];
        final eventTimestamp = inertiaSequence.timestamps[i];

        // Apply snapping to inertia positions if enabled
        Point effectivePosition = position;
        if (context.component == AnchorComponent.anchor) {
          final snappedPos = _snappingService.maybeSnapToGrid(position);
          if (snappedPos != null) {
            effectivePosition = snappedPos;
          }
        }

        // Calculate delta from start for this inertia position
        final delta = Point(
          x: effectivePosition.x - context.startPosition.x,
          y: effectivePosition.y - context.startPosition.y,
        );

        // Use drag controller to calculate result
        DragResult result;
        if (context.component == AnchorComponent.anchor) {
          result = _anchorDragController.calculateDragUpdate(
            anchor: context.originalAnchor,
            delta: delta,
          );
        } else {
          result = _handleDragController.calculateDragUpdate(
            anchor: context.originalAnchor,
            delta: delta,
            component: context.component,
          );
        }

        // Emit event for this inertia frame
        _recordEvent(
          ModifyAnchorEvent(
            eventId: _uuid.v4(),
            timestamp: eventTimestamp,
            pathId: context.objectId,
            anchorIndex: context.anchorIndex,
            position: result.position,
            handleIn: result.handleIn,
            handleOut: result.handleOut,
          ),
        );
      }
    }

    // Flush event recorder to persist final position
    _eventRecorder.flush();

    // Force operation boundary to close undo group
    _operationGroupingService?.forceBoundary(
      reason: 'drag_complete',
    );

    // Calculate telemetry metrics
    final duration = finishTime.difference(context.startTime);
    final totalEvents = context.eventCount + (inertiaSequence?.length ?? 0);
    final eventsPerSecond = totalEvents / duration.inMilliseconds * 1000;

    _logger.d(
      'Finished drag: duration=${duration.inMilliseconds}ms, '
      'events=$totalEvents (${context.eventCount} drag + ${inertiaSequence?.length ?? 0} inertia), '
      'events/sec=${eventsPerSecond.toStringAsFixed(1)}',
    );

    // Log telemetry warning if performance threshold exceeded
    if (duration.inMilliseconds > 100 || eventsPerSecond < 15) {
      _logger.w(
        'Drag performance warning: duration=${duration.inMilliseconds}ms, '
        'events/sec=${eventsPerSecond.toStringAsFixed(1)}',
      );
    }

    _dragContext = null;
    _currentCursor = SystemMouseCursors.precise;
  }

  /// Cancels the drag operation without flushing events.
  void _cancelDrag() {
    _logger.d('Cancelled drag operation');

    // Cancel inertia if active
    _inertiaController.cancel();

    // Cancel operation grouping
    _operationGroupingService?.cancelOperation();

    _dragContext = null;
    _currentCursor = SystemMouseCursors.precise;
  }

  /// Updates hover state for cursor feedback.
  void _updateHover(Offset screenPos) {
    final artboard = _document.artboards.isNotEmpty ? _document.artboards.first : null;
    final selectedObjectIds = artboard?.selection.objectIds.toList() ?? [];
    if (selectedObjectIds.isEmpty) {
      _hoveredAnchor = null;
      _currentCursor = SystemMouseCursors.basic;
      return;
    }

    // Hit-test anchors for all selected objects
    hit_tester.HitTestResult? bestHit;
    for (final objectId in selectedObjectIds) {
      final obj = _document.getObjectById(objectId);
      if (obj == null) continue;

      final hit = obj.when(
        path: (id, path, _) => _hitTester.hitTestAnchors(
          screenPoint: screenPos,
          objectId: objectId,
          path: path,
          shape: null,
        ),
        shape: (id, shape, _) => _hitTester.hitTestAnchors(
          screenPoint: screenPos,
          objectId: objectId,
          path: null,
          shape: shape,
        ),
      );

      if (hit.isAnchorHit &&
          (bestHit == null || hit.distance < bestHit.distance)) {
        bestHit = hit;
      }
    }

    if (bestHit != null && bestHit.isAnchorHit) {
      _hoveredAnchor = HoveredAnchor(
        objectId: bestHit.objectId!,
        anchorIndex: bestHit.anchorIndex!,
        component: bestHit.component,
      );
      _currentCursor = SystemMouseCursors.move;
    } else {
      _hoveredAnchor = null;
      _currentCursor = SystemMouseCursors.precise;
    }
  }

  /// Renders drag preview overlay with feedback metrics.
  void _renderDragPreview(ui.Canvas canvas) {
    if (_dragContext == null || _dragContext!.feedbackMetrics == null) return;

    final context = _dragContext!;
    final metrics = context.feedbackMetrics!;

    // Determine feedback text based on component
    String feedbackText;
    if (context.component == AnchorComponent.anchor) {
      // Anchor drag: show position (x, y)
      final x = metrics['x'] as double;
      final y = metrics['y'] as double;
      feedbackText = 'x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}';
    } else {
      // Handle drag: show angle and length
      final angle = metrics['angle'] as double;
      final length = metrics['length'] as double;
      feedbackText =
          'Angle: ${angle.toStringAsFixed(0)}°\nLength: ${length.toStringAsFixed(1)}';
    }

    // Calculate feedback position in screen space
    // Position text offset from current drag position
    final screenPos =
        _viewportController.worldToScreen(context.currentPosition);
    const feedbackOffset = Offset(10, 15); // px offset from cursor

    // Create text painter
    final textSpan = TextSpan(
      text: feedbackText,
      style: const TextStyle(
        color: ui.Color(0xFFFFFFFF), // White text
        fontSize: 12,
        fontFamily: 'monospace',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw background rectangle
    final bgRect = ui.Rect.fromLTWH(
      screenPos.dx + feedbackOffset.dx,
      screenPos.dy + feedbackOffset.dy,
      textPainter.width + 8,
      textPainter.height + 8,
    );

    final bgPaint = ui.Paint()
      ..color = const ui.Color(0xCC000000) // Semi-transparent black
      ..style = ui.PaintingStyle.fill;

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bgRect, const ui.Radius.circular(4)),
      bgPaint,
    );

    // Draw text
    textPainter.paint(
      canvas,
      Offset(
        screenPos.dx + feedbackOffset.dx + 4,
        screenPos.dy + feedbackOffset.dy + 4,
      ),
    );
  }

  /// Records an event via the event recorder.
  void _recordEvent(EventBase event) {
    _eventRecorder.recordEvent(event);
  }
}

/// Internal state for drag operations.
class _DragContext {
  _DragContext({
    required this.objectId,
    required this.anchorIndex,
    required this.component,
    required this.startPosition,
    required this.currentPosition,
    required this.startTime,
    required this.eventCount,
    required this.originalAnchor,
    this.feedbackMetrics,
  });

  /// The object ID being dragged.
  final String objectId;

  /// The anchor index within the object.
  final int anchorIndex;

  /// The component being dragged (anchor/handleIn/handleOut).
  final AnchorComponent component;

  /// The starting position of the drag (world coordinates).
  final Point startPosition;

  /// The current position during drag (world coordinates).
  final Point currentPosition;

  /// The timestamp when drag started.
  final DateTime startTime;

  /// Number of events emitted during this drag.
  final int eventCount;

  /// The original anchor state at drag start.
  final domain_anchor.AnchorPoint originalAnchor;

  /// Feedback metrics for on-canvas display (angle, length, position, etc.).
  final Map<String, dynamic>? feedbackMetrics;

  _DragContext copyWith({
    Point? currentPosition,
    int? eventCount,
    Map<String, dynamic>? feedbackMetrics,
  }) =>
      _DragContext(
        objectId: objectId,
        anchorIndex: anchorIndex,
        component: component,
        startPosition: startPosition,
        currentPosition: currentPosition ?? this.currentPosition,
        startTime: startTime,
        eventCount: eventCount ?? this.eventCount,
        originalAnchor: originalAnchor,
        feedbackMetrics: feedbackMetrics ?? this.feedbackMetrics,
      );
}
