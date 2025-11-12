import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transform property group for the Inspector.
///
/// Provides fields for X, Y, W, H, and Rotation with aspect ratio lock.
/// Supports keyboard shortcuts (arrow keys ±1, Shift+arrow ±10).
///
/// Related: Section 6.2 CoordinateFieldPair, TransformMatrixEditor
class TransformPropertyGroup extends StatelessWidget {
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final double? rotation;
  final bool aspectRatioLocked;
  final ValueChanged<double?>? onXChanged;
  final ValueChanged<double?>? onYChanged;
  final ValueChanged<double?>? onWidthChanged;
  final ValueChanged<double?>? onHeightChanged;
  final ValueChanged<double?>? onRotationChanged;
  final ValueChanged<bool>? onAspectRatioLockChanged;

  const TransformPropertyGroup({
    Key? key,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.aspectRatioLocked = false,
    this.onXChanged,
    this.onYChanged,
    this.onWidthChanged,
    this.onHeightChanged,
    this.onRotationChanged,
    this.onAspectRatioLockChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = 8.0; // tokens.spacing.spacing8

    return Semantics(
      label: 'Transform properties',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Text(
              'Transform',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),

          // X, Y coordinates
          Row(
            children: [
              Expanded(
                child: _NumericField(
                  label: 'X',
                  value: x,
                  unit: 'px',
                  onChanged: onXChanged,
                  semanticLabel: 'X position',
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _NumericField(
                  label: 'Y',
                  value: y,
                  unit: 'px',
                  onChanged: onYChanged,
                  semanticLabel: 'Y position',
                ),
              ),
            ],
          ),

          SizedBox(height: spacing),

          // W, H dimensions with lock
          Row(
            children: [
              Expanded(
                child: _NumericField(
                  label: 'W',
                  value: width,
                  unit: 'px',
                  onChanged: onWidthChanged,
                  semanticLabel: 'Width',
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _NumericField(
                  label: 'H',
                  value: height,
                  unit: 'px',
                  onChanged: onHeightChanged,
                  semanticLabel: 'Height',
                ),
              ),
              SizedBox(width: 4),
              // Aspect ratio lock button
              Semantics(
                label: aspectRatioLocked
                    ? 'Aspect ratio locked'
                    : 'Aspect ratio unlocked',
                button: true,
                child: IconButton(
                  icon: Icon(
                    aspectRatioLocked ? Icons.lock : Icons.lock_open,
                    size: 16,
                  ),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: onAspectRatioLockChanged != null
                      ? () => onAspectRatioLockChanged!(!aspectRatioLocked)
                      : null,
                  tooltip: aspectRatioLocked
                      ? 'Unlock aspect ratio'
                      : 'Lock aspect ratio',
                ),
              ),
            ],
          ),

          SizedBox(height: spacing),

          // Rotation
          _NumericField(
            label: 'R',
            value: rotation,
            unit: '°',
            onChanged: onRotationChanged,
            semanticLabel: 'Rotation',
          ),
        ],
      ),
    );
  }
}

/// Numeric input field with label and unit display.
///
/// Supports:
/// - Click to edit
/// - Arrow keys ±1, Shift+arrow ±10
/// - Mixed value placeholder ("—")
/// - IBM Plex Mono font for numbers
class _NumericField extends StatefulWidget {
  final String label;
  final double? value;
  final String unit;
  final ValueChanged<double?>? onChanged;
  final String? semanticLabel;

  const _NumericField({
    required this.label,
    this.value,
    required this.unit,
    this.onChanged,
    this.semanticLabel,
  });

  @override
  State<_NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<_NumericField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.value!.toStringAsFixed(1) : '—',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_NumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.value != oldWidget.value) {
      _controller.text = widget.value != null ? widget.value!.toStringAsFixed(1) : '—';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _isEditing = true;
      if (widget.value != null) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    } else {
      _isEditing = false;
      _commitValue();
    }
  }

  void _commitValue() {
    final text = _controller.text.trim();
    if (text.isEmpty || text == '—') {
      widget.onChanged?.call(null);
      return;
    }

    final parsed = double.tryParse(text);
    if (parsed != null) {
      widget.onChanged?.call(parsed);
    } else {
      // Revert to previous value
      _controller.text = widget.value != null ? widget.value!.toStringAsFixed(1) : '—';
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final increment = isShift ? 10.0 : 1.0;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final current = widget.value ?? 0.0;
      widget.onChanged?.call(current + increment);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final current = widget.value ?? 0.0;
      widget.onChanged?.call(current - increment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      textField: true,
      value: widget.value != null ? '${widget.value} ${widget.unit}' : 'Mixed values',
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 16,
            child: Text(
              '${widget.label}:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Input field
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
                ],
                onSubmitted: (_) => _commitValue(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Unit label
          SizedBox(
            width: 24,
            child: Text(
              widget.unit,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
