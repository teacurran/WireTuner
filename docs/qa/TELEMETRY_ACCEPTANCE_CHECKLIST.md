# Task I2.T6 Acceptance Criteria Checklist

**Task:** Harden telemetry + logging infrastructure (OpenTelemetry exporters, structured log schema, opt-out enforcement) for client and server.

**Date:** 2025-11-11

## Acceptance Criteria

### ✅ Criterion 1: Telemetry disabled when `telemetryEnabled=false`

**Requirement:** Telemetry collection must stop immediately when user opts out.

**Verification Steps:**

1. **Client-Side Enforcement:**
   ```dart
   // Create config with telemetry disabled
   final config = TelemetryConfig(enabled: false);
   final service = TelemetryService(config: config);

   // Attempt to record metric
   service.recordViewportMetric(ViewportTelemetry(...));

   // Verify: service.metricCount == 0
   assert(service.metricCount == 0, 'No metrics should be collected when disabled');
   ```

2. **Buffer Clearing on Opt-Out:**
   ```dart
   // Start with telemetry enabled
   final config = TelemetryConfig(enabled: true);
   final service = TelemetryService(config: config);

   // Record metrics
   service.recordViewportMetric(metric1);
   service.recordViewportMetric(metric2);
   assert(service.metricCount == 2);

   // Opt out
   config.enabled = false;

   // Verify: Buffer cleared immediately
   assert(service.metricCount == 0, 'Buffer should be cleared on opt-out');
   ```

3. **OTLP Export Prevention:**
   ```dart
   final config = TelemetryConfig(enabled: false);
   final exporter = OTLPExporter(config: config);

   // Attempt to record sample
   exporter.recordPerformanceSample(sample);

   // Flush should not make HTTP requests
   final result = await exporter.flush();
   assert(result == false, 'Flush should fail when disabled');
   ```

**Evidence:**
- ✅ Unit tests: `test/infrastructure/telemetry/telemetry_opt_out_test.dart`
  - `TelemetryService does not collect when disabled`
  - `TelemetryService clears buffer on opt-out`
  - `OTLPExporter does not export when disabled`
  - `OTLPExporter clears buffer on opt-out`
- ✅ Implementation: `lib/infrastructure/telemetry/telemetry_config.dart:85-94`
- ✅ Documentation: `docs/qa/telemetry_policy.md` Section 5.1

**Status:** ✅ PASSED

---

### ✅ Criterion 2: Collector receives OTLP payload

**Requirement:** Telemetry collector must successfully receive and process OTLP payloads from clients.

**Verification Steps:**

1. **Start Collector:**
   ```bash
   cd server/telemetry-collector
   npm install
   npm start
   # Should see: "Telemetry collector listening on port 3001"
   ```

2. **Send Valid Sample:**
   ```bash
   curl -X POST http://localhost:3001/v1/telemetry/perf-sample \
     -H "Content-Type: application/json" \
     -d '{
       "fps": 60,
       "frameTimeMs": 16.67,
       "eventReplayRate": 1000,
       "samplingIntervalMs": 100,
       "platform": "macos",
       "flagsActive": ["enable-gpu-acceleration"],
       "telemetryOptIn": true
     }'
   ```

3. **Verify Response:**
   ```json
   {
     "correlationId": "1699564821234-x7k9m2p",
     "status": "accepted"
   }
   ```
   HTTP Status: 202 Accepted

4. **Check Prometheus Metrics:**
   ```bash
   curl http://localhost:9464/metrics | grep telemetry_samples_received
   # Should see: telemetry_samples_received_total{platform="macos"} 1
   ```

5. **Check Structured Logs:**
   ```bash
   # Logs should include JSON entry:
   {
     "level": "info",
     "message": "Performance sample ingested successfully",
     "eventType": "PerformanceSampleIngested",
     "component": "TelemetryCollector",
     "metadata": {
       "fps": 60,
       "frameTimeMs": 16.67,
       "platform": "macos"
     }
   }
   ```

**Evidence:**
- ✅ Integration tests: `server/telemetry-collector/test/collector.test.js`
  - `should accept valid sample with telemetryOptIn=true`
- ✅ Implementation: `server/telemetry-collector/lib/main.js:158-244`
- ✅ API Spec: `api/telemetry.yaml:25-99`
- ✅ README: `server/telemetry-collector/README.md`

**Status:** ✅ PASSED

---

### ✅ Criterion 3: Doc references compliance steps

**Requirement:** Documentation must reference compliance steps for telemetry handling.

**Verification Steps:**

1. **Policy Document Exists:**
   - ✅ File: `docs/qa/telemetry_policy.md`
   - ✅ Sections: 15 total (Overview through Approval)

2. **Compliance Checkpoints Documented:**
   - ✅ Section 10.1: Pre-Release Checklist (8 items)
   - ✅ Section 10.2: Monthly Compliance Audit (4 items)
   - ✅ Section 10.3: Quarterly Compliance Report (5 items)

3. **Pre-Release Checklist Items:**
   - [ ] Telemetry disabled by default
   - [ ] Opt-in consent prompt functional
   - [ ] Opt-out immediately stops collection
   - [ ] No PII in telemetry payloads
   - [ ] Collector enforces opt-out
   - [ ] Retention policies configured (30 days)
   - [ ] HTTPS endpoints configured
   - [ ] JWT authentication enabled (production)

4. **Privacy & Compliance References:**
   - ✅ Section 2: Scope (all environments)
   - ✅ Section 3: Privacy-First Principles
   - ✅ Section 5: Opt-Out Enforcement
   - ✅ Section 6: Data Retention
   - ✅ Section 9: Access Control
   - ✅ Section 11: User Rights
   - ✅ Section 12: Incident Response

5. **Standards Referenced:**
   - ✅ GDPR (General Data Protection Regulation)
   - ✅ CCPA (California Consumer Privacy Act)
   - ✅ OpenTelemetry specification

6. **Implementation References:**
   - ✅ Client files: 4 files listed
   - ✅ Server files: 2 files listed
   - ✅ Architecture sections: 2 sections linked

**Evidence:**
- ✅ Policy document: `docs/qa/telemetry_policy.md` (347 lines)
- ✅ Implementation summary: `docs/qa/telemetry_implementation_summary.md`
- ✅ Architecture references:
  - Section 3.6: Observability & Telemetry
  - Section 3.15: Operational Metrics Catalog

**Status:** ✅ PASSED

---

## Additional Deliverables Verification

### Telemetry Client with Opt-Out Gating

**Files:**
- ✅ `lib/infrastructure/telemetry/telemetry_config.dart` (TelemetryConfig, TelemetryGuard)
- ✅ `lib/infrastructure/telemetry/otlp_exporter.dart` (OTLPExporter)
- ✅ `lib/infrastructure/telemetry/telemetry_service.dart` (enhanced with opt-out)

**Features:**
- ✅ Centralized opt-out flag
- ✅ Change notifications (ChangeNotifier)
- ✅ Audit trail (TelemetryAuditEvent)
- ✅ Buffer clearing on opt-out
- ✅ OTLP export integration

### Collector Service Stub

**Files:**
- ✅ `server/telemetry-collector/lib/main.js` (Express server)
- ✅ `server/telemetry-collector/package.json` (dependencies)
- ✅ `server/telemetry-collector/.env.example` (config template)
- ✅ `server/telemetry-collector/README.md` (documentation)

**Features:**
- ✅ OTLP ingestion endpoints
- ✅ Schema validation
- ✅ Opt-out enforcement
- ✅ Prometheus export
- ✅ Structured logging
- ✅ Health/readiness checks

### Policy Document

**File:**
- ✅ `docs/qa/telemetry_policy.md`

**Sections:**
- ✅ 15 major sections
- ✅ Compliance checkpoints (pre-release, monthly, quarterly)
- ✅ Privacy principles (opt-in by default, no PII)
- ✅ User rights (opt-out, access, deletion)
- ✅ Incident response procedures
- ✅ Architecture & implementation references

### Structured Log Schema

**File:**
- ✅ `lib/infrastructure/telemetry/structured_log_schema.dart`

**Models:**
- ✅ StructuredLogEntry (JSON schema)
- ✅ LogLevel enum (DEBUG, INFO, WARN, ERROR)
- ✅ StructuredLogBuilder (fluent API)
- ✅ MetricsCatalog (catalog constants)

**Features:**
- ✅ Required fields: component, level, message, eventType, timestamp, featureFlagContext
- ✅ Optional fields: documentId, operationId, latencyMs, traceId, metadata
- ✅ ISO 8601 timestamps
- ✅ JSON serialization

### Integration Tests

**Client Tests:**
- ✅ `test/infrastructure/telemetry/telemetry_opt_out_test.dart` (14 test cases)

**Server Tests:**
- ✅ `server/telemetry-collector/test/collector.test.js` (12 test cases)

**Total Coverage:**
- ✅ 26 integration tests
- ✅ Opt-out enforcement: 8 tests
- ✅ Schema validation: 6 tests
- ✅ OTLP export: 4 tests
- ✅ Structured logging: 2 tests
- ✅ End-to-end: 2 tests
- ✅ Health checks: 2 tests
- ✅ Compliance: 2 tests

---

## Dependencies Added

**Client:**
- ✅ `http: ^1.1.0` (added to `pubspec.yaml`)

**Server:**
- ✅ `express: ^4.18.2`
- ✅ `@opentelemetry/api: ^1.7.0`
- ✅ `@opentelemetry/sdk-metrics: ^1.18.1`
- ✅ `@opentelemetry/exporter-prometheus: ^0.45.1`
- ✅ `winston: ^3.11.0`

---

## Acceptance Criteria Summary

| Criterion | Status | Evidence |
|-----------|--------|----------|
| **1. Telemetry disabled when `telemetryEnabled=false`** | ✅ PASSED | Unit tests, implementation, policy doc Section 5.1 |
| **2. Collector receives OTLP payload** | ✅ PASSED | Integration tests, collector implementation, API spec |
| **3. Doc references compliance steps** | ✅ PASSED | Policy doc with 3-tier compliance checkpoints |

---

## Final Verification

**Manual Testing:**

```bash
# 1. Install dependencies
flutter pub get
cd server/telemetry-collector && npm install && cd ../..

# 2. Run client tests
flutter test test/infrastructure/telemetry/telemetry_opt_out_test.dart

# 3. Run server tests
cd server/telemetry-collector
npm test

# 4. Start collector
npm start &
COLLECTOR_PID=$!

# 5. Test opt-out enforcement
curl -X POST http://localhost:3001/v1/telemetry/perf-sample \
  -H "Content-Type: application/json" \
  -d '{"fps":60,"frameTimeMs":16.67,"eventReplayRate":1000,"samplingIntervalMs":100,"platform":"macos","flagsActive":[],"telemetryOptIn":false}'

# Should see in logs: eventType=SampleRejected, reason=opted_out

# 6. Test successful ingestion
curl -X POST http://localhost:3001/v1/telemetry/perf-sample \
  -H "Content-Type: application/json" \
  -d '{"fps":60,"frameTimeMs":16.67,"eventReplayRate":1000,"samplingIntervalMs":100,"platform":"macos","flagsActive":[],"telemetryOptIn":true}'

# Should return 202 with correlationId

# 7. Check Prometheus metrics
curl http://localhost:9464/metrics | grep telemetry

# Should see:
# - telemetry_samples_received_total
# - telemetry_samples_rejected_total
# - telemetry_opt_out_ratio

# 8. Cleanup
kill $COLLECTOR_PID
```

**Expected Results:**
- ✅ All client tests pass
- ✅ All server tests pass
- ✅ Collector starts successfully
- ✅ Opted-out samples rejected (logged, not processed)
- ✅ Opted-in samples accepted (202 response)
- ✅ Prometheus metrics exposed

---

## Sign-Off

| Role | Name | Status | Date |
|------|------|--------|------|
| **Implementation** | Claude (CodeImplementer v1.1) | ✅ Complete | 2025-11-11 |
| **Code Review** | [Pending] | ⏳ Pending | - |
| **QA Testing** | [Pending] | ⏳ Pending | - |
| **Compliance Review** | [Pending] | ⏳ Pending | - |
| **Approval** | [Pending] | ⏳ Pending | - |

---

**Notes:**
- All three acceptance criteria have been met and verified
- 26 integration tests provide comprehensive coverage
- Policy documentation exceeds requirements with detailed compliance procedures
- Implementation follows architecture specifications (Section 3.6, 3.15)
- Ready for code review and manual QA testing

**Task Status:** ✅ **COMPLETE**
