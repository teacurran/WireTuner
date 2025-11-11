import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/inspector_provider.dart';
import 'widgets/property_groups/transform_property_group.dart';
import 'widgets/property_groups/fill_property_group.dart';
import 'widgets/property_groups/stroke_property_group.dart';

/// Main Inspector panel widget.
///
/// Displays property editors for selected objects, organized into groups:
/// - Transform (position, size, rotation)
/// - Fill (color, opacity)
/// - Stroke (color, width, cap, join)
/// - Effects (future: shadows, blur)
///
/// ## Architecture
///
/// The Inspector panel is composed of:
/// - InspectorProvider (state management)
/// - Property group molecules (Transform, Fill, Stroke)
/// - Apply/Reset action buttons
///
/// ## States
///
/// - No Selection: Properties grayed out, "No selection" placeholder
/// - Single Selection: All properties editable
/// - Multi-Selection: Shared properties editable, differing properties show "—"
///
/// ## Usage
///
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => InspectorProvider(
///     commandDispatcher: (cmd, data) => eventStore.dispatch(cmd, data),
///   ),
///   child: InspectorPanel(),
/// )
/// ```
///
/// Related: FR-045, Section 6.2 component specs, Inspector wireframe
class InspectorPanel extends StatelessWidget {
  /// Creates an Inspector panel widget.
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Inspector panel',
      container: true,
      child: Container(
        width: 280, // Standard inspector panel width
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant, // tokens.surface.raised
          border: Border(
            left: BorderSide(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // Panel header
            _buildHeader(context),

            // Scrollable properties section
            Expanded(
              child: _buildPropertiesSection(context),
            ),

            // Action buttons (Apply/Reset)
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Properties',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesSection(BuildContext context) {
    return Consumer<InspectorProvider>(
      builder: (context, inspector, _) {
        if (!inspector.hasSelection) {
          return _buildNoSelectionState(context);
        }

        if (inspector.isMultiSelection) {
          return _buildMultiSelectionProperties(context, inspector);
        }

        return _buildSingleSelectionProperties(context, inspector);
      },
    );
  }

  Widget _buildNoSelectionState(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'No selection',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No selection',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select an object to edit properties',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSelectionProperties(
    BuildContext context,
    InspectorProvider inspector,
  ) {
    final props = inspector.currentProperties!;
    final spacing = 16.0; // tokens.spacing.spacing16

    return Semantics(
      label: 'Properties for ${props.objectType}',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Object type label
            Text(
              props.objectType,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),

            SizedBox(height: spacing),

            // Transform properties
            TransformPropertyGroup(
              x: props.x,
              y: props.y,
              width: props.width,
              height: props.height,
              rotation: props.rotation,
              aspectRatioLocked: props.aspectRatioLocked,
              onXChanged: (v) => inspector.updateTransform(x: v),
              onYChanged: (v) => inspector.updateTransform(y: v),
              onWidthChanged: (v) => inspector.updateTransform(width: v),
              onHeightChanged: (v) => inspector.updateTransform(height: v),
              onRotationChanged: (v) => inspector.updateTransform(rotation: v),
              onAspectRatioLockChanged: (v) =>
                  inspector.updateTransform(aspectRatioLocked: v),
            ),

            SizedBox(height: spacing),
            Divider(color: Theme.of(context).dividerColor),
            SizedBox(height: spacing),

            // Fill properties
            FillPropertyGroup(
              fillColor: props.fillColor,
              opacity: props.fillOpacity,
              onColorChanged: (c) => inspector.updateFill(color: c),
              onOpacityChanged: (o) => inspector.updateFill(opacity: o),
            ),

            SizedBox(height: spacing),
            Divider(color: Theme.of(context).dividerColor),
            SizedBox(height: spacing),

            // Stroke properties
            StrokePropertyGroup(
              strokeColor: props.strokeColor,
              strokeWidth: props.strokeWidth,
              strokeCap: props.strokeCap,
              strokeJoin: props.strokeJoin,
              onColorChanged: (c) => inspector.updateStroke(color: c),
              onWidthChanged: (w) => inspector.updateStroke(width: w),
              onCapChanged: (c) => inspector.updateStroke(cap: c),
              onJoinChanged: (j) => inspector.updateStroke(join: j),
            ),

            SizedBox(height: spacing),
            Divider(color: Theme.of(context).dividerColor),
            SizedBox(height: spacing),

            // Effects (placeholder for future)
            Text(
              'Effects',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: null, // TODO: Implement effects
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Shadow'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 32),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: null, // TODO: Implement effects
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Blur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectionProperties(
    BuildContext context,
    InspectorProvider inspector,
  ) {
    final props = inspector.multiSelectionProperties!;
    final spacing = 16.0;

    return Semantics(
      label: 'Properties for ${props.selectionCount} objects',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Multi-selection label
            Text(
              '${props.selectionCount} objects selected',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              'Mixed values shown as "—"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),

            SizedBox(height: spacing),

            // Transform properties (with mixed values)
            TransformPropertyGroup(
              x: props.x,
              y: props.y,
              width: props.width,
              height: props.height,
              rotation: props.rotation,
              aspectRatioLocked: props.aspectRatioLocked ?? false,
              onXChanged: (v) => inspector.updateTransform(x: v),
              onYChanged: (v) => inspector.updateTransform(y: v),
              onWidthChanged: (v) => inspector.updateTransform(width: v),
              onHeightChanged: (v) => inspector.updateTransform(height: v),
              onRotationChanged: (v) => inspector.updateTransform(rotation: v),
              onAspectRatioLockChanged: (v) =>
                  inspector.updateTransform(aspectRatioLocked: v),
            ),

            SizedBox(height: spacing),
            Divider(color: Theme.of(context).dividerColor),
            SizedBox(height: spacing),

            // Fill properties (with mixed values)
            FillPropertyGroup(
              fillColor: props.fillColor,
              opacity: props.fillOpacity,
              onColorChanged: (c) => inspector.updateFill(color: c),
              onOpacityChanged: (o) => inspector.updateFill(opacity: o),
            ),

            SizedBox(height: spacing),
            Divider(color: Theme.of(context).dividerColor),
            SizedBox(height: spacing),

            // Stroke properties (with mixed values)
            StrokePropertyGroup(
              strokeColor: props.strokeColor,
              strokeWidth: props.strokeWidth,
              strokeCap: props.strokeCap,
              strokeJoin: props.strokeJoin,
              onColorChanged: (c) => inspector.updateStroke(color: c),
              onWidthChanged: (w) => inspector.updateStroke(width: w),
              onCapChanged: (c) => inspector.updateStroke(cap: c),
              onJoinChanged: (j) => inspector.updateStroke(join: j),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<InspectorProvider>(
      builder: (context, inspector, _) {
        final hasStagedChanges = inspector.hasStagedChanges;

        return Semantics(
          label: 'Inspector actions',
          container: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                // Reset button
                Expanded(
                  child: Semantics(
                    label: 'Reset changes',
                    button: true,
                    enabled: hasStagedChanges,
                    child: OutlinedButton(
                      onPressed: hasStagedChanges ? inspector.resetChanges : null,
                      child: const Text('Reset'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Apply button
                Expanded(
                  child: Semantics(
                    label: 'Apply changes',
                    button: true,
                    enabled: hasStagedChanges,
                    child: ElevatedButton(
                      onPressed: hasStagedChanges ? inspector.applyChanges : null,
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
