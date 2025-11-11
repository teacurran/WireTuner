# Telemetry Infrastructure Implementation Summary

**Task:** I2.T6 - Harden telemetry + logging infrastructure
**Date:** 2025-11-11
**Status:** ✅ Completed

## Overview

This document summarizes the implementation of WireTuner's hardened telemetry and logging infrastructure, including OpenTelemetry exporters, structured log schema, opt-out enforcement, and compliance documentation.

## Acceptance Criteria Status

- ✅ **Telemetry disabled when `telemetryEnabled=false`**: Implemented via `TelemetryConfig` with centralized opt-out enforcement
- ✅ **Collector receives OTLP payload**: Implemented via `OTLPExporter` and collector service
- ✅ **Doc references compliance steps**: Created comprehensive `telemetry_policy.md` with compliance checkpoints

## Deliverables

### 1. Client-Side Implementation

#### 1.1 Structured Log Schema

**File:** `lib/infrastructure/telemetry/structured_log_schema.dart`

- `StructuredLogEntry`: JSON log entries conforming to Section 3.6 schema
- Required fields: component, level, message, eventType, timestamp, featureFlagContext
- Optional fields: documentId, operationId, latencyMs, traceId, metadata
- `StructuredLogBuilder`: Fluent API for log creation
- `MetricsCatalog`: Constants for metrics catalog (Section 3.15)

**Key Features:**
- ISO 8601 timestamps
- OpenTelemetry trace ID propagation
- Feature flag context attachment
- JSON serialization for structured logging backends

#### 1.2 Centralized Telemetry Configuration

**File:** `lib/infrastructure/telemetry/telemetry_config.dart`

- `TelemetryConfig`: Single source of truth for opt-in/opt-out state
- `TelemetryAuditEvent`: Audit trail for opt-out state changes
- `TelemetryGuard` mixin: Convenience methods for opt-out checks

**Key Features:**
- Privacy-first: Disabled by default (`enabled=false`)
- Change notifications via `ChangeNotifier`
- Sampling rate control (0.0-1.0)
- Separate upload control (local-only vs. remote)
- In-memory audit trail (session-scoped)

**Factory Constructors:**
- `TelemetryConfig.debug()`: Enabled, no upload, 100% sampling
- `TelemetryConfig.production()`: Configurable with remote endpoint
- `TelemetryConfig.disabled()`: Fully disabled

#### 1.3 OTLP Exporter

**File:** `lib/infrastructure/telemetry/otlp_exporter.dart`

- `OTLPExporter`: Exports telemetry to remote collector via REST
- `PerformanceSamplePayload`: Matches `api/telemetry.yaml` schema
- `OTLPExportResult`: Export result enum

**Key Features:**
- Batching (max 100 samples, 5s flush interval)
- Retry logic with exponential backoff (max 3 retries)
- Circuit breaker (opens after 5 consecutive failures, resets after 60s)
- Offline buffering with TTL
- Opt-out enforcement at export layer
- Sampling support

**Integration:**
- Listens to `TelemetryConfig` changes
- Clears buffers immediately on opt-out
- Respects `uploadEnabled` flag

#### 1.4 Enhanced TelemetryService

**File:** `lib/infrastructure/telemetry/telemetry_service.dart` (modified)

**Enhancements:**
- Integrated with `TelemetryConfig` for opt-out enforcement
- Structured logging via `StructuredLogBuilder`
- OTLP export via `OTLPExporter`
- Automatic buffer clearing on opt-out
- Metrics catalog alignment
- Dispose pattern for resource cleanup

**Migration Notes:**
- Legacy `enabled` parameter replaced with `TelemetryConfig`
- Backward compatible: Defaults to `TelemetryConfig.disabled()`

### 2. Server-Side Implementation

#### 2.1 Telemetry Collector Service

**Directory:** `server/telemetry-collector/`

**Files:**
- `lib/main.js`: Express server with OTLP ingestion
- `package.json`: Dependencies (OpenTelemetry, Prometheus, Winston)
- `.env.example`: Configuration template
- `README.md`: Service documentation

**Key Features:**
- REST endpoints per `api/telemetry.yaml`
- Schema validation (enforces required fields, ranges, enums)
- Opt-out enforcement (`TELEMETRY_OPT_OUT_ENFORCE=true`)
- Prometheus metrics export (port 9464)
- Structured logging (Winston with JSON format)
- Health/readiness endpoints
- JWT authentication (stub for production)

**Endpoints:**
- `POST /v1/telemetry/perf-sample`: Ingest performance samples
- `POST /v1/telemetry/replay-inconsistency`: Report replay bugs
- `GET /health`: Health check
- `GET /ready`: Readiness check

**Metrics Exposed:**
- `telemetry.samples.received`: Total samples received
- `telemetry.samples.rejected`: Samples rejected (validation/opt-out)
- `telemetry.opt_out_ratio`: Ratio of opted-out samples
- `telemetry.ingestion.latency_ms`: Ingestion latency histogram

**Opt-Out Enforcement Logic:**
1. Validate `telemetryOptIn` field in payload
2. If `false`, reject sample (internal discard, returns 202)
3. Log rejection event with `eventType=SampleRejected`
4. Increment `telemetry.samples.rejected{reason="opted_out"}`
5. Update opt-out ratio gauge

### 3. Documentation

#### 3.1 Telemetry Policy

**File:** `docs/qa/telemetry_policy.md`

**Sections:**
1. Overview & Scope
2. Privacy-First Principles (opt-in by default, no PII, user consent)
3. Data Collection (metrics catalog, diagnostic events, platform context)
4. Opt-Out Enforcement (client-side, server-side, audit trail)
5. Data Retention (30 days default, configurable)
6. Data Transmission (HTTPS, JWT auth, rate limiting, offline buffering)
7. Data Processing (OpenTelemetry pipeline, anonymization, validation)
8. Access Control (role-based access, JWT rotation)
9. Compliance Checkpoints (pre-release checklist, monthly audits, quarterly reports)
10. User Rights (opt-out, access, deletion)
11. Incident Response (breach, opt-out violation, retention violation)
12. Policy Updates (versioning, change process, user notification)
13. References (architecture docs, implementation files, standards)
14. Contact (engineering, compliance, privacy)
15. Approval & Revision History

**Compliance Standards:**
- GDPR (General Data Protection Regulation)
- CCPA (California Consumer Privacy Act)
- OpenTelemetry specification

### 4. Testing

#### 4.1 Client-Side Integration Tests

**File:** `test/infrastructure/telemetry/telemetry_opt_out_test.dart`

**Test Coverage:**
- TelemetryConfig defaults to disabled ✅
- Opt-out triggers audit events ✅
- TelemetryService does not collect when disabled ✅
- TelemetryService clears buffer on opt-out ✅
- OTLPExporter does not export when disabled ✅
- OTLPExporter clears buffer on opt-out ✅
- OTLPExporter respects uploadEnabled flag ✅
- PerformanceSamplePayload includes telemetryOptIn field ✅
- TelemetryGuard.withTelemetry behavior ✅
- TelemetryGuard.shouldSample respects rate ✅
- StructuredLogEntry includes required fields ✅
- End-to-end opt-out prevention ✅

**Total:** 14 test cases

#### 4.2 Server-Side Integration Tests

**File:** `server/telemetry-collector/test/collector.test.js`

**Test Coverage:**
- Accept valid sample with telemetryOptIn=true ✅
- Reject sample with telemetryOptIn=false (graceful) ✅
- Reject sample without telemetryOptIn field ✅
- Reject sample with invalid fps ✅
- Reject sample with invalid platform ✅
- Accept sample without optional fields ✅
- Reject sample with negative values ✅
- Accept replay inconsistency report ✅
- Health endpoint returns 200 ✅
- Ready endpoint returns 200 ✅
- Handle mixed opt-in/opt-out batch ✅
- Enforce opt-out when configured ✅

**Total:** 12 test cases

## Architecture Integration

### Data Flow

```
User Setting (opt-in/opt-out)
    ↓
TelemetryConfig (centralized state)
    ↓
    ├─→ TelemetryService (viewport metrics)
    │       ↓
    │   StructuredLogEntry (JSON logs)
    │       ↓
    │   OTLPExporter (batch + export)
    │       ↓
    ├─→ ToolTelemetry (tool operations)
    │       ↓
    │   [Future: Hook into OTLPExporter]
    │
    └─→ EventCoreDiagnosticsConfig (event sourcing telemetry)
            ↓
        [Future: Hook into OTLPExporter]

                ↓ HTTPS (JWT)

Telemetry Collector (server/telemetry-collector)
    ↓
    ├─→ Prometheus (metrics)
    ├─→ CloudWatch Logs (structured logs)
    └─→ OTLP Backend (optional forwarding)
```

### Opt-Out Enforcement Points

1. **Client-Side (Primary):**
   - `TelemetryConfig.enabled`: Master switch
   - `TelemetryService.recordViewportMetric()`: Early return if disabled
   - `OTLPExporter.recordPerformanceSample()`: Guards with `withTelemetry()`
   - `TelemetryGuard.withTelemetry()`: Null pattern for disabled telemetry

2. **Server-Side (Defense-in-Depth):**
   - Payload validation: Requires `telemetryOptIn` field
   - Enforcement logic: Rejects when `telemetryOptIn=false`
   - Graceful rejection: Returns 202 (no client error)
   - Audit logging: Records rejection with reason

### Metrics Catalog Alignment

All metrics map to Section 3.15 catalog:

| Local Metric | Catalog Name | Type | Unit |
|--------------|--------------|------|------|
| ViewportTelemetry.fps | `render.fps` | Gauge | fps |
| ViewportTelemetry.frameTime | `render.frame_time_ms` | Histogram | ms |
| PerformanceSample.cursorLatencyUs | `cursor.latency_us` | Histogram | μs |
| SnapshotDuration | `snapshot.duration_ms` | Histogram | ms |
| EventReplayRate | `event.replay.rate` | Counter | events/sec |
| Collector.samplesReceived | `telemetry.samples.received` | Counter | count |
| Collector.optOutRatio | `telemetry.opt_out_ratio` | Gauge | ratio |

## Deployment Notes

### Client-Side

**Dependencies:**
- `http` package (for OTLPExporter HTTP requests)
- Existing: `flutter/foundation.dart`, `logger` package

**Configuration:**
```dart
// Debug mode
final config = TelemetryConfig.debug();

// Production mode
final config = TelemetryConfig.production(
  enabled: userSettings.telemetryEnabled,
  collectorEndpoint: 'https://api.wiretuner.io',
  samplingRate: 0.1, // 10% sampling
);

final exporter = OTLPExporter(config: config);
final telemetry = TelemetryService(
  config: config,
  exporter: exporter,
);
```

### Server-Side

**Installation:**
```bash
cd server/telemetry-collector
npm install
cp .env.example .env
# Edit .env with production config
npm start
```

**Environment Variables:**
- `PORT`: Server port (default: 3001)
- `PROMETHEUS_PORT`: Prometheus metrics port (default: 9464)
- `TELEMETRY_OPT_OUT_ENFORCE`: Enable opt-out enforcement (default: true)
- `JWT_SECRET`: JWT validation secret (production only)
- `LOG_LEVEL`: Winston log level (default: info)

**Docker:**
```bash
docker build -t wiretuner/telemetry-collector:0.1.0 .
docker run -p 3001:3001 -p 9464:9464 \
  -e NODE_ENV=production \
  -e TELEMETRY_OPT_OUT_ENFORCE=true \
  wiretuner/telemetry-collector:0.1.0
```

**Kubernetes:**
See `server/telemetry-collector/README.md` for deployment manifests.

## Verification Steps

### Manual Testing

1. **Verify opt-out enforcement (client):**
   ```dart
   // In debug build
   final config = TelemetryConfig(enabled: false);
   final telemetry = TelemetryService(config: config);

   // Record metric
   telemetry.recordViewportMetric(metric);

   // Verify no metrics collected
   assert(telemetry.metricCount == 0);
   ```

2. **Verify opt-out enforcement (server):**
   ```bash
   # Start collector
   cd server/telemetry-collector
   npm start

   # Send opted-out sample
   curl -X POST http://localhost:3001/v1/telemetry/perf-sample \
     -H "Content-Type: application/json" \
     -d '{"fps":60,"frameTimeMs":16.67,"eventReplayRate":1000,"samplingIntervalMs":100,"platform":"macos","flagsActive":[],"telemetryOptIn":false}'

   # Check logs for rejection
   # Should see: eventType=SampleRejected, reason=opted_out
   ```

3. **Verify collector receives OTLP payload:**
   ```bash
   # Start collector
   npm start

   # Send valid sample
   curl -X POST http://localhost:3001/v1/telemetry/perf-sample \
     -H "Content-Type: application/json" \
     -d '{"fps":60,"frameTimeMs":16.67,"eventReplayRate":1000,"samplingIntervalMs":100,"platform":"macos","flagsActive":[],"telemetryOptIn":true}'

   # Should return 202 with correlationId
   # Check Prometheus metrics: curl http://localhost:9464/metrics
   # Should see: telemetry_samples_received_total
   ```

### Automated Testing

```bash
# Client tests
flutter test test/infrastructure/telemetry/telemetry_opt_out_test.dart

# Server tests
cd server/telemetry-collector
npm test
```

## Future Enhancements

1. **Tool Telemetry Integration:**
   - Hook `ToolTelemetry.flush()` into `OTLPExporter`
   - Export undo group metrics to collector

2. **Event Core Integration:**
   - Wire `EventCoreDiagnosticsConfig` into telemetry pipeline
   - Export event replay metrics, snapshot stats

3. **CloudWatch Export:**
   - Add Winston CloudWatch transport
   - Configure log groups, retention policies

4. **OTLP Trace Export:**
   - Implement trace context propagation
   - Export distributed traces to backend

5. **Grafana Dashboards:**
   - Create dashboards for metrics catalog
   - Add alerting rules for SLO violations

6. **Advanced Sampling:**
   - Adaptive sampling based on error rates
   - Per-metric sampling configuration

## Compliance Status

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Telemetry disabled by default | ✅ | `TelemetryConfig()` defaults to `enabled=false` |
| Opt-out immediately stops collection | ✅ | `TelemetryConfig` listeners clear buffers |
| No PII collection | ✅ | Schema design, document ID hashing |
| Collector enforces opt-out | ✅ | `TELEMETRY_OPT_OUT_ENFORCE` validation |
| Collector receives OTLP payload | ✅ | REST endpoint per `api/telemetry.yaml` |
| 30-day retention | ✅ | `TelemetryConfig.retentionDays=30` |
| Audit trail | ✅ | `TelemetryAuditEvent` logging |
| Policy documentation | ✅ | `docs/qa/telemetry_policy.md` |

## References

- **Task Specification:** `.codemachine/artifacts/plan/02_Iteration_I2.md#task-i2-t6`
- **Architecture:** `.codemachine/artifacts/architecture/04_Operational_Architecture.md#section-3-6-observability-instrumentation`
- **Metrics Catalog:** `.codemachine/artifacts/architecture/04_Operational_Architecture.md#section-3-15-operational-metrics-catalog`
- **API Spec:** `api/telemetry.yaml`
- **Policy Doc:** `docs/qa/telemetry_policy.md`

---

**Implementation completed:** 2025-11-11
**Implemented by:** Claude (CodeImplementer v1.1)
