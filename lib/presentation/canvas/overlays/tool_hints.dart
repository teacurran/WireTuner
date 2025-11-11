import 'package:flutter/material.dart';
import 'package:wiretuner/application/tools/framework/cursor_manager.dart';

/// Represents a hint message with internationalization support.
class HintMessage {
  /// Creates a hint message.
  const HintMessage({
    required this.key,
    required this.text,
    this.icon,
    this.color,
  });

  /// Internationalization key for the hint.
  ///
  /// This allows hints to be translated in future iterations.
  /// Format: "hint.{category}.{specific}"
  /// Example: "hint.snapping.enabled", "hint.angle_lock.active"
  final String key;

  /// The display text for the hint.
  ///
  /// This is the default English text. In future iterations,
  /// this will be looked up from localization resources using [key].
  final String text;

  /// Optional icon to display with the hint.
  final IconData? icon;

  /// Optional color override for the hint.
  final Color? color;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HintMessage &&
        other.key == key &&
        other.text == text &&
        other.icon == icon &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(key, text, icon, color);
}

/// Predefined hint messages for common tool states.
class ToolHints {
  /// Hint shown when angle locking is active (Shift key held).
  static const angleLock = HintMessage(
    key: 'hint.angle_lock.active',
    text: 'Angle Locked (45°)',
    icon: Icons.straighten,
    color: Colors.blue,
  );

  /// Hint shown when snapping is active.
  static const snapping = HintMessage(
    key: 'hint.snapping.enabled',
    text: 'Snapping Enabled',
    icon: Icons.grid_on,
    color: Colors.green,
  );

  /// Hint shown when grid snapping is active.
  static const gridSnap = HintMessage(
    key: 'hint.snapping.grid',
    text: 'Snap to Grid',
    icon: Icons.grid_4x4,
    color: Colors.green,
  );

  /// Hint shown when object snapping is active.
  static const objectSnap = HintMessage(
    key: 'hint.snapping.objects',
    text: 'Snap to Objects',
    icon: Icons.layers,
    color: Colors.green,
  );

  /// Hint shown when guide snapping is active.
  static const guideSnap = HintMessage(
    key: 'hint.snapping.guides',
    text: 'Snap to Guides',
    icon: Icons.horizontal_rule,
    color: Colors.purple,
  );

  /// Hint for creating a path with the pen tool.
  static const penDrawing = HintMessage(
    key: 'hint.pen.drawing',
    text: 'Click to add points',
    icon: Icons.edit,
  );

  /// Hint for adjusting Bezier handles.
  static const penHandles = HintMessage(
    key: 'hint.pen.handles',
    text: 'Drag to adjust curve',
    icon: Icons.control_camera,
  );

  /// Hint for selection mode.
  static const selection = HintMessage(
    key: 'hint.selection.mode',
    text: 'Click to select',
    icon: Icons.touch_app,
  );

  /// Hint for dragging objects.
  static const dragging = HintMessage(
    key: 'hint.selection.dragging',
    text: 'Dragging object',
    icon: Icons.open_with,
  );

  /// Hint for direct selection of anchors.
  static const directSelection = HintMessage(
    key: 'hint.direct_selection.mode',
    text: 'Select anchor points',
    icon: Icons.control_point,
  );

  /// Hint for creating a rectangle.
  static const rectangle = HintMessage(
    key: 'hint.rectangle.creating',
    text: 'Drag to create rectangle',
    icon: Icons.crop_square,
  );

  /// Hint for creating an ellipse.
  static const ellipse = HintMessage(
    key: 'hint.ellipse.creating',
    text: 'Drag to create ellipse',
    icon: Icons.circle_outlined,
  );
}

/// Widget that displays contextual hints based on tool state.
///
/// ToolHintsOverlay provides visual feedback to users about:
/// - Active modifier keys (Shift for angle lock, etc.)
/// - Snapping state
/// - Tool-specific instructions
///
/// ## Design Rationale
///
/// The overlay is designed to:
/// - Be non-intrusive (semi-transparent, corner-positioned)
/// - Update within 1 frame (uses ChangeNotifier)
/// - Support internationalization (hint keys + future i18n)
/// - Integrate with cursor manager for consistent UX
///
/// ## Performance
///
/// - Only rebuilds when hints change
/// - Uses const widgets where possible
/// - Minimal painting overhead (simple boxes and text)
///
/// ## Usage
///
/// ```dart
/// Stack(
///   children: [
///     Canvas(...),
///     SelectionOverlay(...),
///     ToolHintsOverlay(
///       cursorManager: cursorManager,
///       hints: [
///         if (isAngleLocked) ToolHints.angleLock,
///         if (isSnapping) ToolHints.snapping,
///       ],
///     ),
///   ],
/// )
/// ```
///
/// Related: I3.T5, Decision 6 (platform parity)
class ToolHintsOverlay extends StatelessWidget {
  /// Creates a tool hints overlay.
  const ToolHintsOverlay({
    super.key,
    required this.hints,
    this.position = ToolHintPosition.bottomRight,
  });

  /// The hints to display.
  final List<HintMessage> hints;

  /// Position of the hint overlay.
  final ToolHintPosition position;

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: position == ToolHintPosition.bottomRight ||
              position == ToolHintPosition.bottomLeft
          ? 16.0
          : null,
      top: position == ToolHintPosition.topRight ||
              position == ToolHintPosition.topLeft
          ? 16.0
          : null,
      right: position == ToolHintPosition.bottomRight ||
              position == ToolHintPosition.topRight
          ? 16.0
          : null,
      left: position == ToolHintPosition.bottomLeft ||
              position == ToolHintPosition.topLeft
          ? 16.0
          : null,
      child: _HintContainer(hints: hints),
    );
  }
}

/// Internal widget that renders the hint container.
class _HintContainer extends StatelessWidget {
  const _HintContainer({required this.hints});
  final List<HintMessage> hints;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < hints.length; i++) ...[
              _HintItem(hint: hints[i]),
              if (i < hints.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      );
}

/// Internal widget that renders a single hint item.
class _HintItem extends StatelessWidget {
  const _HintItem({required this.hint});
  final HintMessage hint;

  @override
  Widget build(BuildContext context) {
    final color = hint.color ?? Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hint.icon != null) ...[
          Icon(
            hint.icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          hint.text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// Position options for the tool hints overlay.
enum ToolHintPosition {
  /// Top-right corner of the canvas.
  topRight,

  /// Top-left corner of the canvas.
  topLeft,

  /// Bottom-right corner of the canvas.
  bottomRight,

  /// Bottom-left corner of the canvas.
  bottomLeft,
}

/// Widget that integrates with CursorManager to display context-based hints.
///
/// This widget automatically derives hints from the cursor context and displays
/// them using [ToolHintsOverlay].
///
/// Example:
/// ```dart
/// ContextualToolHints(
///   cursorManager: cursorManager,
///   toolHints: {
///     'pen': [ToolHints.penDrawing],
///     'selection': [ToolHints.selection],
///   },
/// )
/// ```
class ContextualToolHints extends StatelessWidget {
  /// Creates contextual tool hints that watch the cursor manager.
  const ContextualToolHints({
    super.key,
    required this.cursorManager,
    this.toolHints = const {},
    this.position = ToolHintPosition.bottomRight,
  });

  /// The cursor manager to watch for context changes.
  final CursorManager cursorManager;

  /// Tool-specific base hints.
  ///
  /// Map from tool ID to list of hints to display when that tool is active.
  final Map<String, List<HintMessage>> toolHints;

  /// Position of the hint overlay.
  final ToolHintPosition position;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: cursorManager,
        builder: (context, _) {
          final hints = _deriveHints();
          return ToolHintsOverlay(
            hints: hints,
            position: position,
          );
        },
      );

  /// Derives hints from cursor context and active tool.
  List<HintMessage> _deriveHints() {
    final hints = <HintMessage>[];

    // Add tool-specific base hints
    final toolId = cursorManager.activeToolId;
    if (toolId != null && toolHints.containsKey(toolId)) {
      hints.addAll(toolHints[toolId]!);
    }

    // Add context-based hints
    final context = cursorManager.context;

    if (context.isAngleLocked) {
      hints.add(ToolHints.angleLock);
    }

    if (context.isSnapping) {
      hints.add(ToolHints.snapping);
    }

    if (context.isDragging) {
      hints.add(ToolHints.dragging);
    }

    return hints;
  }
}
