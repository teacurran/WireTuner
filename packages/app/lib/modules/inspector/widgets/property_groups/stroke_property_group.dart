import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stroke property group for the Inspector.
///
/// Provides controls for stroke color, width, cap, and join.
///
/// Related: Section 6.2 StrokeControlGroup
class StrokePropertyGroup extends StatelessWidget {
  final Color? strokeColor;
  final double? strokeWidth;
  final StrokeCap? strokeCap;
  final StrokeJoin? strokeJoin;
  final ValueChanged<Color?>? onColorChanged;
  final ValueChanged<double?>? onWidthChanged;
  final ValueChanged<StrokeCap?>? onCapChanged;
  final ValueChanged<StrokeJoin?>? onJoinChanged;

  const StrokePropertyGroup({
    Key? key,
    this.strokeColor,
    this.strokeWidth,
    this.strokeCap,
    this.strokeJoin,
    this.onColorChanged,
    this.onWidthChanged,
    this.onCapChanged,
    this.onJoinChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = 8.0;
    final hasStroke = strokeColor != null;

    return Semantics(
      label: 'Stroke properties',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Text(
              'Stroke',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),

          if (!hasStroke) ...[
            // Add stroke button
            Semantics(
              label: 'Add stroke',
              button: true,
              child: OutlinedButton.icon(
                onPressed: onColorChanged != null
                    ? () => onColorChanged!(Colors.black)
                    : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Stroke'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 32),
                ),
              ),
            ),
          ] else ...[
            // Color swatch + hex value
            Row(
              children: [
                // Color swatch
                Semantics(
                  label: 'Stroke color: #${strokeColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                  button: true,
                  child: GestureDetector(
                    onTap: onColorChanged != null ? () => _showColorPicker(context) : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: strokeColor,
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Hex value
                Expanded(
                  child: Text(
                    '#${strokeColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 14,
                    ),
                  ),
                ),

                // Remove stroke button
                Semantics(
                  label: 'Remove stroke',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onColorChanged != null
                        ? () => onColorChanged!(null)
                        : null,
                    tooltip: 'Remove stroke',
                  ),
                ),
              ],
            ),

            SizedBox(height: spacing),

            // Stroke width
            _StrokeWidthField(
              value: strokeWidth,
              onChanged: onWidthChanged,
            ),

            SizedBox(height: spacing),

            // Stroke cap
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'Cap:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: 'Stroke cap style',
                    container: true,
                    child: SegmentedButton<StrokeCap>(
                      segments: const [
                        ButtonSegment(
                          value: StrokeCap.butt,
                          label: Text('Butt'),
                        ),
                        ButtonSegment(
                          value: StrokeCap.round,
                          label: Text('Round'),
                        ),
                        ButtonSegment(
                          value: StrokeCap.square,
                          label: Text('Square'),
                        ),
                      ],
                      selected: {strokeCap ?? StrokeCap.butt},
                      onSelectionChanged: onCapChanged != null
                          ? (Set<StrokeCap> caps) => onCapChanged!(caps.first)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: spacing),

            // Stroke join
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'Join:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: 'Stroke join style',
                    container: true,
                    child: SegmentedButton<StrokeJoin>(
                      segments: const [
                        ButtonSegment(
                          value: StrokeJoin.miter,
                          label: Text('Miter'),
                        ),
                        ButtonSegment(
                          value: StrokeJoin.round,
                          label: Text('Round'),
                        ),
                        ButtonSegment(
                          value: StrokeJoin.bevel,
                          label: Text('Bevel'),
                        ),
                      ],
                      selected: {strokeJoin ?? StrokeJoin.miter},
                      onSelectionChanged: onJoinChanged != null
                          ? (Set<StrokeJoin> joins) => onJoinChanged!(joins.first)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Stroke Color'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Colors.black,
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.pink,
              Colors.white,
              Colors.grey,
            ].map((color) {
              return GestureDetector(
                onTap: () {
                  onColorChanged?.call(color);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: Colors.grey,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Stroke width numeric field.
class _StrokeWidthField extends StatefulWidget {
  final double? value;
  final ValueChanged<double?>? onChanged;

  const _StrokeWidthField({
    this.value,
    this.onChanged,
  });

  @override
  State<_StrokeWidthField> createState() => _StrokeWidthFieldState();
}

class _StrokeWidthFieldState extends State<_StrokeWidthField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.value!.toStringAsFixed(1) : '1.0',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_StrokeWidthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value != null ? widget.value!.toStringAsFixed(1) : '1.0';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commitValue();
    }
  }

  void _commitValue() {
    final parsed = double.tryParse(_controller.text);
    if (parsed != null && parsed >= 0) {
      widget.onChanged?.call(parsed);
    } else {
      _controller.text = widget.value != null ? widget.value!.toStringAsFixed(1) : '1.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Stroke width',
      textField: true,
      value: '${widget.value ?? 1.0} pixels',
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              'Width:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
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
                suffixText: 'px',
                suffixStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onSubmitted: (_) => _commitValue(),
            ),
          ),
        ],
      ),
    );
  }
}
