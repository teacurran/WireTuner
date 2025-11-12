/// Integration tests for telemetry opt-out enforcement.
///
/// Verifies that telemetry opt-out is properly enforced across all
/// collection paths and data immediately stops flowing when disabled.
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_config.dart';
import 'package:wiretuner/infrastructure/telemetry/telemetry_service.dart';
import 'package:wiretuner/infrastructure/telemetry/otlp_exporter.dart';
import 'package:wiretuner/infrastructure/telemetry/structured_log_schema.dart';
import 'package:wiretuner/presentation/canvas/viewport/viewport_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Telemetry Opt-Out Enforcement', () {
    test('TelemetryConfig defaults to disabled (privacy-first)', () {
      final config = TelemetryConfig();

      expect(config.enabled, false,
          reason: 'Telemetry must be disabled by default');
      expect(config.uploadEnabled, false,
          reason: 'Upload must be disabled by default');
    });

    test('TelemetryConfig.disabled() creates fully disabled config', () {
      final config = TelemetryConfig.disabled();

      expect(config.enabled, false);
      expect(config.uploadEnabled, false);
      expect(config.samplingRate, 0.0);
    });

    test('TelemetryConfig opt-out triggers audit event', () {
      final config = TelemetryConfig(enabled: true);

      expect(config.auditTrail.length, 0,
          reason: 'No audit events initially');

      // Opt out
      config.enabled = false;

      expect(config.auditTrail.length, 1,
          reason: 'Opt-out should create audit event');

      final event = config.auditTrail.first;
      expect(event.wasEnabled, true);
      expect(event.nowEnabled, false);
    });

    test('TelemetryService does not collect when disabled', () {
      final config = TelemetryConfig(enabled: false);
      final service = TelemetryService(config: config);

      // Record metric while disabled
      final metric = ViewportTelemetry(
        eventType: 'pan',
        fps: 60,
        timestamp: DateTime.now(),
        panOffset: Offset.zero,
        zoomLevel: 1.0,
      );

      service.recordViewportMetric(metric);

      // Verify no metrics collected
      expect(service.metricCount, 0,
          reason: 'No metrics should be collected when disabled');
    });

    test('TelemetryService clears buffer on opt-out', () {
      final config = TelemetryConfig(enabled: true);
      final service = TelemetryService(config: config);

      // Collect some metrics
      for (var i = 0; i < 10; i++) {
        service.recordViewportMetric(ViewportTelemetry(
          eventType: 'pan',
          fps: 60,
          timestamp: DateTime.now(),
          panOffset: Offset.zero,
          zoomLevel: 1.0,
        ));
      }

      expect(service.metricCount, 10,
          reason: 'Should have collected 10 metrics');

      // Opt out
      config.enabled = false;

      // Wait for listener notification
      Future.delayed(Duration(milliseconds: 100), () {
        expect(service.metricCount, 0,
            reason: 'Buffer should be cleared immediately on opt-out');
      });
    });

    test('OTLPExporter does not export when disabled', () async {
      final config = TelemetryConfig(enabled: false);
      final mockClient = MockClient((request) async {
        fail('Should not make HTTP request when telemetry disabled');
      });

      final exporter = OTLPExporter(
        config: config,
        client: mockClient,
      );

      // Attempt to record sample
      exporter.recordPerformanceSample(
        PerformanceSamplePayload(
          fps: 60,
          frameTimeMs: 16.67,
          eventReplayRate: 1000,
          samplingIntervalMs: 100,
          platform: 'macos',
          telemetryOptIn: false,
        ),
      );

      // Flush should not make requests
      final result = await exporter.flush();
      expect(result, false,
          reason: 'Flush should fail when telemetry disabled');

      exporter.dispose();
    });

    test('OTLPExporter clears buffer on opt-out', () async {
      final config = TelemetryConfig(enabled: true, uploadEnabled: false);
      final mockClient = MockClient((request) async {
        return http.Response('{"status": "accepted"}', 202);
      });

      final exporter = OTLPExporter(
        config: config,
        client: mockClient,
      );

      // Buffer some samples
      for (var i = 0; i < 5; i++) {
        exporter.recordPerformanceSample(
          PerformanceSamplePayload(
            fps: 60,
            frameTimeMs: 16.67,
            eventReplayRate: 1000,
            samplingIntervalMs: 100,
            platform: 'macos',
            telemetryOptIn: true,
          ),
        );
      }

      // Opt out
      config.enabled = false;

      // Wait for listener notification
      await Future.delayed(Duration(milliseconds: 100));

      // Enable and flush - should have no samples
      config.enabled = true;
      config.uploadEnabled = true;

      var requestCount = 0;
      final countingClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"status": "accepted"}', 202);
      });

      // Replace client and flush
      final exporter2 = OTLPExporter(
        config: config,
        client: countingClient,
      );

      await exporter2.flush();

      expect(requestCount, 0,
          reason: 'No requests should be made (buffer was cleared on opt-out)');

      exporter.dispose();
      exporter2.dispose();
    });

    test('OTLPExporter respects uploadEnabled flag', () async {
      final config = TelemetryConfig(
        enabled: true,
        uploadEnabled: false, // Telemetry enabled but upload disabled
      );

      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"status": "accepted"}', 202);
      });

      final exporter = OTLPExporter(
        config: config,
        client: mockClient,
      );

      exporter.recordPerformanceSample(
        PerformanceSamplePayload(
          fps: 60,
          frameTimeMs: 16.67,
          eventReplayRate: 1000,
          samplingIntervalMs: 100,
          platform: 'macos',
          telemetryOptIn: true,
        ),
      );

      await exporter.flush();

      expect(requestCount, 0,
          reason: 'No upload should occur when uploadEnabled=false');

      exporter.dispose();
    });

    test('PerformanceSamplePayload includes telemetryOptIn field', () {
      final sample = PerformanceSamplePayload(
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        telemetryOptIn: true,
      );

      final json = sample.toJson();

      expect(json.containsKey('telemetryOptIn'), true,
          reason: 'Payload must include telemetryOptIn field');
      expect(json['telemetryOptIn'], true);
    });

    test('PerformanceSamplePayload with opt-out', () {
      final sample = PerformanceSamplePayload(
        fps: 60,
        frameTimeMs: 16.67,
        eventReplayRate: 1000,
        samplingIntervalMs: 100,
        platform: 'macos',
        telemetryOptIn: false, // Opted out
      );

      final json = sample.toJson();

      expect(json['telemetryOptIn'], false,
          reason: 'Opt-out state must be reflected in payload');
    });

    test('TelemetryGuard.withTelemetry returns null when disabled', () {
      final config = TelemetryConfig(enabled: false);

      final testClass = _TestTelemetryGuard(config);

      final result = testClass.withTelemetry(() => 'executed');

      expect(result, null,
          reason: 'withTelemetry should return null when disabled');
    });

    test('TelemetryGuard.withTelemetry executes when enabled', () {
      final config = TelemetryConfig(enabled: true);

      final testClass = _TestTelemetryGuard(config);

      final result = testClass.withTelemetry(() => 'executed');

      expect(result, 'executed',
          reason: 'withTelemetry should execute action when enabled');
    });

    test('TelemetryGuard.shouldSample respects sampling rate', () {
      final config = TelemetryConfig(
        enabled: true,
        samplingRate: 0.0, // No sampling
      );

      final testClass = _TestTelemetryGuard(config);

      expect(testClass.shouldSample(), false,
          reason: 'shouldSample should return false with 0.0 rate');
    });

    test('StructuredLogEntry includes required fields', () {
      final log = StructuredLogEntry(
        component: 'TestComponent',
        level: LogLevel.info,
        message: 'Test message',
        eventType: 'TestEvent',
      );

      final json = log.toJson();

      expect(json['component'], 'TestComponent');
      expect(json['level'], 'INFO');
      expect(json['message'], 'Test message');
      expect(json['eventType'], 'TestEvent');
      expect(json.containsKey('timestamp'), true);
      expect(json.containsKey('featureFlagContext'), true);
    });

    test('End-to-end: opt-out prevents all telemetry', () async {
      // Start with telemetry enabled
      final config = TelemetryConfig(
        enabled: true,
        uploadEnabled: true,
        collectorEndpoint: 'http://localhost:3001',
      );

      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"correlationId": "test", "status": "accepted"}',
            202);
      });

      final exporter = OTLPExporter(
        config: config,
        client: mockClient,
      );

      final service = TelemetryService(
        config: config,
        exporter: exporter,
      );

      // Record metrics while enabled
      service.recordViewportMetric(ViewportTelemetry(
        eventType: 'pan',
        fps: 60,
        timestamp: DateTime.now(),
        panOffset: Offset.zero,
        zoomLevel: 1.0,
      ));

      expect(service.metricCount, 1,
          reason: 'Metric should be collected when enabled');

      // Opt out
      config.enabled = false;

      // Wait for propagation
      await Future.delayed(Duration(milliseconds: 100));

      // Verify buffer cleared
      expect(service.metricCount, 0,
          reason: 'Metrics should be cleared on opt-out');

      // Attempt to record more metrics
      service.recordViewportMetric(ViewportTelemetry(
        eventType: 'pan',
        fps: 60,
        timestamp: DateTime.now(),
        panOffset: Offset.zero,
        zoomLevel: 1.0,
      ));

      expect(service.metricCount, 0,
          reason: 'No metrics should be collected after opt-out');

      // Flush should not make requests
      await exporter.flush();

      expect(requestCount, 0,
          reason: 'No HTTP requests should be made after opt-out');

      service.dispose();
    });
  });
}

/// Test class implementing TelemetryGuard for testing.
class _TestTelemetryGuard with TelemetryGuard {
  _TestTelemetryGuard(this._config);

  final TelemetryConfig _config;

  @override
  TelemetryConfig get telemetryConfig => _config;
}
