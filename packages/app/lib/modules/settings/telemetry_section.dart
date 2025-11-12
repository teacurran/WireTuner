/// Telemetry settings UI section.
///
/// This module provides UI controls for telemetry opt-in/opt-out, upload
/// preferences, and audit trail viewing with clear visual feedback of
/// privacy state.
library;

import 'package:flutter/material.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';

/// Telemetry settings section widget.
///
/// Provides toggles for telemetry collection and upload with visual
/// feedback about current state and audit trail.
class TelemetrySettingsSection extends StatefulWidget {
  const TelemetrySettingsSection({
    required this.telemetryConfig,
    this.onConfigChanged,
    super.key,
  });

  /// Telemetry configuration instance.
  final TelemetryConfig telemetryConfig;

  /// Callback when configuration changes (for persistence).
  final VoidCallback? onConfigChanged;

  @override
  State<TelemetrySettingsSection> createState() =>
      _TelemetrySettingsSectionState();
}

class _TelemetrySettingsSectionState extends State<TelemetrySettingsSection> {
  bool _showAuditTrail = false;

  @override
  void initState() {
    super.initState();
    // Listen for config changes to update UI
    widget.telemetryConfig.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    widget.telemetryConfig.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    setState(() {});
    widget.onConfigChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.telemetryConfig;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Telemetry & Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Help improve WireTuner by sharing anonymous usage metrics.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Telemetry enabled toggle
            _SettingsToggle(
              title: 'Enable Telemetry',
              subtitle:
                  'Collect anonymous performance and usage metrics locally',
              value: config.enabled,
              icon: config.enabled
                  ? Icons.check_circle
                  : Icons.block,
              iconColor: config.enabled ? Colors.green : Colors.red,
              onChanged: (value) {
                setState(() {
                  config.enabled = value;
                });
                widget.onConfigChanged?.call();
              },
            ),

            const SizedBox(height: 16),

            // Upload enabled toggle (only active when telemetry enabled)
            Opacity(
              opacity: config.enabled ? 1.0 : 0.5,
              child: _SettingsToggle(
                title: 'Enable Upload',
                subtitle:
                    'Upload metrics to remote collector for analytics (optional)',
                value: config.uploadEnabled,
                icon: config.uploadEnabled
                    ? Icons.cloud_upload
                    : Icons.cloud_off,
                iconColor: config.uploadEnabled ? Colors.blue : Colors.grey,
                enabled: config.enabled,
                onChanged: config.enabled
                    ? (value) {
                        setState(() {
                          config.uploadEnabled = value;
                        });
                        widget.onConfigChanged?.call();
                      }
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            // Sampling rate display
            Row(
              children: [
                const Icon(Icons.track_changes, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                const Text(
                  'Sampling Rate:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(config.samplingRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Retention period display
            Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                const Text(
                  'Local Retention:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(
                  '${config.retentionDays} days',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Audit trail section
            ExpansionPanelList(
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: (panelIndex, isExpanded) {
                setState(() {
                  _showAuditTrail = !isExpanded;
                });
              },
              children: [
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const ListTile(
                      leading: Icon(Icons.history, size: 20),
                      title: Text(
                        'Audit Trail',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  },
                  body: _AuditTrailView(
                    auditTrail: config.auditTrail,
                  ),
                  isExpanded: _showAuditTrail,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Privacy notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All metrics are anonymized and never include personal data. '
                      'You can opt-out at any time, and all local data will be immediately cleared.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings toggle widget with icon and subtitle.
class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
    this.iconColor,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 24,
            color: enabled ? iconColor : Colors.grey,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: enabled ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.grey : Colors.grey.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Audit trail view widget.
class _AuditTrailView extends StatelessWidget {
  const _AuditTrailView({
    required this.auditTrail,
  });

  final List<TelemetryAuditEvent> auditTrail;

  @override
  Widget build(BuildContext context) {
    if (auditTrail.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No audit events recorded yet.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: auditTrail.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, thickness: 1),
        itemBuilder: (context, index) {
          final event = auditTrail[auditTrail.length - 1 - index];
          final action = event.nowEnabled ? 'Opted In' : 'Opted Out';
          final actionColor = event.nowEnabled ? Colors.green : Colors.red;

          return ListTile(
            dense: true,
            leading: Icon(
              event.nowEnabled ? Icons.check_circle : Icons.cancel,
              color: actionColor,
              size: 20,
            ),
            title: Text(
              action,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: actionColor,
              ),
            ),
            subtitle: Text(
              _formatTimestamp(event.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
