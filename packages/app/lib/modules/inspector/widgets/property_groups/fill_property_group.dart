import 'package:flutter/material.dart';

/// Fill property group for the Inspector.
///
/// Provides color picker and opacity slider for fill properties.
///
/// Related: Section 6.2 FillControlGroup, OpacitySlider
class FillPropertyGroup extends StatelessWidget {
  final Color? fillColor;
  final double? opacity;
  final ValueChanged<Color?>? onColorChanged;
  final ValueChanged<double?>? onOpacityChanged;

  const FillPropertyGroup({
    Key? key,
    this.fillColor,
    this.opacity,
    this.onColorChanged,
    this.onOpacityChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = 8.0;

    return Semantics(
      label: 'Fill properties',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Text(
              'Fill',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),

          // Color swatch + hex value
          Row(
            children: [
              // Color swatch
              Semantics(
                label: fillColor != null
                    ? 'Fill color: #${fillColor!.value.toRadixString(16).substring(2).toUpperCase()}'
                    : 'No fill color',
                button: true,
                child: GestureDetector(
                  onTap: onColorChanged != null ? () => _showColorPicker(context) : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: fillColor ?? Colors.transparent,
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: fillColor == null
                        ? Icon(
                            Icons.block,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Hex value display
              Expanded(
                child: Text(
                  fillColor != null
                      ? '#${fillColor!.value.toRadixString(16).substring(2).toUpperCase()}'
                      : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 14,
                  ),
                ),
              ),

              // Eyedropper button (future feature)
              Semantics(
                label: 'Pick color from canvas',
                button: true,
                enabled: false,
                child: IconButton(
                  icon: const Icon(Icons.colorize, size: 16),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: null, // TODO: Wire to eyedropper tool
                  tooltip: 'Pick color (coming soon)',
                ),
              ),
            ],
          ),

          SizedBox(height: spacing),

          // Opacity slider
          Semantics(
            label: 'Fill opacity',
            slider: true,
            value: '${((opacity ?? 1.0) * 100).toInt()}%',
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'Opacity:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: opacity ?? 1.0,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: '${((opacity ?? 1.0) * 100).toInt()}%',
                    onChanged: onOpacityChanged,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${((opacity ?? 1.0) * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    // TODO: Implement full color picker modal
    // For now, show simple dialog with preset colors
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Fill Color'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.pink,
              Colors.black,
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
          TextButton(
            onPressed: () {
              onColorChanged?.call(null);
              Navigator.of(context).pop();
            },
            child: const Text('Remove Fill'),
          ),
        ],
      ),
    );
  }
}
