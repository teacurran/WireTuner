/// Tests for telemetry settings UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';

import 'package:app/modules/settings/telemetry_section.dart';

void main() {
  group('TelemetrySettingsSection Widget', () {
    testWidgets('displays all UI elements', (tester) async {
      final config = TelemetryConfig.debug();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      // Check section header
      expect(find.text('Telemetry & Analytics'), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

      // Check toggles
      expect(find.text('Enable Telemetry'), findsOneWidget);
      expect(find.text('Enable Upload'), findsOneWidget);

      // Check info displays
      expect(find.textContaining('Sampling Rate'), findsOneWidget);
      expect(find.textContaining('Local Retention'), findsOneWidget);

      // Check privacy notice
      expect(find.textContaining('anonymized'), findsOneWidget);
    });

    testWidgets('toggle switches update config', (tester) async {
      final config = TelemetryConfig(enabled: false);
      var configChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
                onConfigChanged: () {
                  configChanged = true;
                },
              ),
            ),
          ),
        ),
      );

      // Initially disabled
      expect(config.enabled, false);

      // Find and tap the telemetry toggle
      final telemetrySwitch = find.byType(Switch).first;
      await tester.tap(telemetrySwitch);
      await tester.pumpAndSettle();

      // Config should be updated
      expect(config.enabled, true);
      expect(configChanged, true);
    });

    testWidgets('upload toggle is disabled when telemetry is off',
        (tester) async {
      final config = TelemetryConfig.disabled();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      // Find upload toggle section (should be opaque/disabled)
      final uploadSection = find.ancestor(
        of: find.text('Enable Upload'),
        matching: find.byType(Opacity),
      );
      expect(uploadSection, findsOneWidget);

      final opacityWidget = tester.widget<Opacity>(uploadSection);
      expect(opacityWidget.opacity, 0.5); // Disabled appearance
    });

    testWidgets('displays correct sampling rate', (tester) async {
      final config = TelemetryConfig(enabled: true, samplingRate: 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('displays correct retention period', (tester) async {
      final config = TelemetryConfig(enabled: true, retentionDays: 14);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      expect(find.text('14 days'), findsOneWidget);
    });

    testWidgets('audit trail expands and collapses', (tester) async {
      final config = TelemetryConfig.debug();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('No audit events recorded yet.'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Audit Trail'));
      await tester.pumpAndSettle();

      // Now visible
      expect(find.text('No audit events recorded yet.'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Audit Trail'));
      await tester.pumpAndSettle();

      // Hidden again
      expect(find.text('No audit events recorded yet.'), findsNothing);
    });

    testWidgets('displays audit events', (tester) async {
      final config = TelemetryConfig(enabled: false);

      // Toggle to create audit events
      config.enabled = true;
      config.enabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      // Expand audit trail
      await tester.tap(find.text('Audit Trail'));
      await tester.pumpAndSettle();

      // Should show audit events
      expect(find.text('Opted In'), findsOneWidget);
      expect(find.text('Opted Out'), findsOneWidget);
    });

    testWidgets('shows correct icons for telemetry state', (tester) async {
      final enabledConfig = TelemetryConfig.debug();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: enabledConfig,
              ),
            ),
          ),
        ),
      );

      // Check for enabled icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Now test with disabled config
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: TelemetryConfig.disabled(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for disabled icon
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('privacy notice is always visible', (tester) async {
      final config = TelemetryConfig.debug();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetrySettingsSection(
                telemetryConfig: config,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.privacy_tip), findsOneWidget);
      expect(
        find.textContaining('never include personal data'),
        findsOneWidget,
      );
    });
  });

  group('TelemetryConfig Integration', () {
    test('config changes notify listeners', () {
      var notified = false;
      final config = TelemetryConfig(enabled: false);

      config.addListener(() {
        notified = true;
      });

      config.enabled = true;

      expect(notified, true);
      expect(config.enabled, true);
    });

    test('audit trail tracks state changes', () {
      final config = TelemetryConfig(enabled: false);

      expect(config.auditTrail.isEmpty, true);

      config.enabled = true;
      config.enabled = false;
      config.enabled = true;

      expect(config.auditTrail.length, 3);
      expect(config.auditTrail[0].nowEnabled, true);
      expect(config.auditTrail[1].nowEnabled, false);
      expect(config.auditTrail[2].nowEnabled, true);
    });

    test('upload enabled depends on telemetry enabled', () {
      final config = TelemetryConfig(
        enabled: false,
        uploadEnabled: true, // Try to enable upload
      );

      // Upload should be blocked when telemetry is disabled
      expect(config.uploadEnabled, false);

      config.enabled = true;
      config.uploadEnabled = true;

      // Now upload should work
      expect(config.uploadEnabled, true);
    });
  });
}
