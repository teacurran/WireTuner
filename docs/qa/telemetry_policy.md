# WireTuner Telemetry Policy

**Version:** 1.0
**Last Updated:** 2025-11-11
**Owner:** WireTuner Engineering & Compliance Team

## 1. Overview

This document defines WireTuner's telemetry collection, processing, retention, and opt-out policies. It ensures compliance with privacy regulations (GDPR, CCPA) and establishes operational procedures for telemetry infrastructure.

## 2. Scope

This policy applies to:
- Desktop client telemetry (macOS, Windows)
- Backend telemetry collection services
- All telemetry data pipelines and storage
- Development, staging, and production environments

## 3. Privacy-First Principles

### 3.1 Opt-In by Default

- Telemetry is **disabled by default** (`telemetryEnabled=false`)
- Users must explicitly opt-in via Settings UI
- Opt-in/opt-out state is stored locally and respected immediately
- No telemetry data is collected or buffered when opted out

### 3.2 User Consent

- First-run experience includes clear telemetry consent prompt
- Consent prompt explains:
  - What data is collected
  - How data is used
  - User's right to opt-out at any time
  - No functional degradation when opted out
- Consent state is auditable and logged

### 3.3 No Personally Identifiable Information (PII)

Telemetry data must NOT include:
- User names or email addresses
- File paths containing usernames
- IP addresses (stripped at ingestion)
- Hardware serial numbers
- License keys or credentials

Document IDs and UUIDs are anonymized/hashed before upload.

## 4. Data Collection

### 4.1 Performance Metrics

When telemetry is enabled, the following performance metrics are collected:

| Metric | Description | Frequency | Catalog Name |
|--------|-------------|-----------|--------------|
| FPS | Frames per second | Per viewport update | `render.fps` |
| Frame Time | Frame render time (ms) | Per viewport update | `render.frame_time_ms` |
| Cursor Latency | Cursor response latency (μs) | Per interaction | `cursor.latency_us` |
| Event Replay Rate | Events replayed per second | Per document operation | `event.replay.rate` |
| Snapshot Duration | Snapshot creation time (ms) | Per snapshot | `snapshot.duration_ms` |
| Tool Operations | Tool activation and operation counts | Per tool use | `tool.operation.count` |

### 4.2 Diagnostic Events

- Crash reports (with stack traces, no PII)
- Event replay inconsistencies (state hash mismatches)
- Performance warnings (FPS drops, memory pressure)
- Feature flag contexts (active flags during operation)

### 4.3 Platform Context

- Platform identifier (`macos`, `windows`)
- Application version
- Active feature flags (no user-specific data)

### 4.4 Sampling

- Production telemetry uses 10% sampling rate by default
- Debug/development uses 100% sampling
- Sampling rate configurable via `TelemetryConfig.samplingRate`

## 5. Opt-Out Enforcement

### 5.1 Client-Side Enforcement

**Implementation:** `TelemetryConfig` (`lib/infrastructure/telemetry/telemetry_config.dart`)

- Centralized opt-out flag checked BEFORE any data collection
- When `telemetryEnabled=false`:
  - No metrics are recorded
  - No logs are buffered
  - Existing buffers are cleared immediately
  - No network requests to collector
- Opt-out state changes trigger audit events

### 5.2 Server-Side Enforcement

**Implementation:** Telemetry Collector (`server/telemetry-collector/lib/main.js`)

- Each payload includes `telemetryOptIn` boolean field
- Collector validates `telemetryOptIn=true` before processing
- When `telemetryOptIn=false`:
  - Payload is rejected (returns 202 but discards data)
  - Rejection logged for audit
  - Metric `telemetry.samples.rejected{reason="opted_out"}` incremented
- Configurable via `TELEMETRY_OPT_OUT_ENFORCE` environment variable

### 5.3 Audit Trail

All opt-in/opt-out state changes are recorded in:
- Client-side: `TelemetryConfig._auditTrail` (in-memory, session-scoped)
- Server-side: Structured logs with `eventType=TelemetryOptOut`
- Audit events include timestamp, previous state, new state

**Verification:**
```dart
// Client-side audit trail
final config = TelemetryConfig();
config.enabled = false; // Triggers audit event
print(config.auditTrail); // List of TelemetryAuditEvent
```

## 6. Data Retention

### 6.1 Client-Side Retention

- Local telemetry logs: **30 days** (default)
- Configurable via `TelemetryConfig.retentionDays`
- Automatic purge of logs older than retention period
- Immediate purge on opt-out

### 6.2 Server-Side Retention

- CloudWatch Logs: **30 days** (configurable per log group)
- Prometheus metrics: **90 days** (aggregated, no raw samples)
- S3 archives (if enabled): **1 year** (for incident investigation)
- Support case pinning: Extended retention with user consent

### 6.3 Retention Enforcement

- Automated CloudWatch log expiration policies
- Monthly audit of retention policy violations
- Metric: `retention.policy.violations` (must be 0)

## 7. Data Transmission

### 7.1 Transport Security

- All telemetry uploaded via HTTPS (TLS 1.3+)
- JWT authentication required for all endpoints
- Certificate pinning in production builds

### 7.2 Endpoints

**Production:**
```
https://api.wiretuner.io/v1/telemetry/perf-sample
https://api.wiretuner.io/v1/telemetry/replay-inconsistency
```

**Staging:**
```
https://staging-api.wiretuner.io/v1/telemetry/perf-sample
```

**Local Development:**
```
http://localhost:3001/v1/telemetry/perf-sample
```

### 7.3 Rate Limiting

- Client: Max 100 samples/minute
- Server: 1000 requests/minute per API key
- 429 responses include `Retry-After` header

### 7.4 Offline Buffering

- Client buffers up to 100 samples locally when offline
- Buffer cleared on opt-out or when upload succeeds
- No indefinite buffering (TTL: 24 hours)

## 8. Data Processing

### 8.1 OpenTelemetry Pipeline

```
Desktop Client
    ↓ OTLP (HTTPS)
Telemetry Collector (server/telemetry-collector)
    ↓
    ├─→ Prometheus (metrics aggregation)
    ├─→ CloudWatch Logs (structured logs)
    └─→ OTLP Backend (optional forwarding)
```

### 8.2 Anonymization

- Document IDs hashed with SHA-256 before upload
- IP addresses stripped at ingestion boundary
- User agents sanitized (version only, no identifiers)

### 8.3 Validation

- All payloads validated against `api/telemetry.yaml` schema
- Invalid payloads rejected with 400 Bad Request
- Validation errors logged for debugging

## 9. Access Control

### 9.1 Data Access

- **Engineering:** Read-only access to aggregated metrics (Grafana dashboards)
- **DevOps:** Full access to raw logs (incident response)
- **Compliance:** Audit trail access (verification)
- **Support:** No direct access (must escalate to DevOps)

### 9.2 Authentication

- JWT tokens issued by auth service
- Tokens expire after 1 hour
- Refresh tokens valid for 7 days
- Token rotation enforced

### 9.3 Audit Logging

All telemetry data access logged:
- Timestamp
- User/service account
- Data accessed (log query, metric dashboard)
- Purpose (incident ID, ADR reference)

## 10. Compliance Checkpoints

### 10.1 Pre-Release Checklist

Before each release, verify:

- [ ] Telemetry disabled by default (`telemetryEnabled=false`)
- [ ] Opt-in consent prompt functional
- [ ] Opt-out immediately stops collection (manual test)
- [ ] No PII in telemetry payloads (Spectral validation)
- [ ] Collector enforces opt-out (`TELEMETRY_OPT_OUT_ENFORCE=true`)
- [ ] Retention policies configured (30 days)
- [ ] HTTPS endpoints configured (no HTTP in production)
- [ ] JWT authentication enabled (production only)

### 10.2 Monthly Compliance Audit

- Review opt-out ratio: `telemetry.opt_out_ratio` metric
- Verify retention policy: `retention.policy.violations = 0`
- Audit trail review: Sample 10% of opt-out events
- PII scan: Automated regex scan of log samples

### 10.3 Quarterly Compliance Report

- Total telemetry samples collected
- Opt-out ratio trend
- Retention policy violations (must be 0)
- Security incidents (telemetry-related)
- Policy updates/revisions

## 11. User Rights

### 11.1 Right to Opt-Out

Users can opt-out at any time via:
- Settings → Privacy → Telemetry → Disable
- Command-line flag: `--disable-telemetry`
- Environment variable: `WIRETUNER_TELEMETRY_ENABLED=false`

Opt-out takes effect immediately (no app restart required).

### 11.2 Right to Access

Users can request:
- Copy of telemetry data collected (via support ticket)
- Audit trail of opt-in/opt-out state changes
- Confirmation of data deletion

Response time: Within 30 days (GDPR compliance).

### 11.3 Right to Deletion

Users can request deletion of all telemetry data:
- Submit support ticket with request
- DevOps purges data from all systems (CloudWatch, S3, Prometheus)
- Confirmation email sent within 7 days

## 12. Incident Response

### 12.1 Telemetry Data Breach

If telemetry data is compromised:

1. **Immediate:** Disable collector ingestion (kill switch)
2. **Within 1 hour:** Notify compliance team
3. **Within 24 hours:** Assess data exposure (PII risk)
4. **Within 72 hours:** Notify affected users (if PII exposed)
5. **Within 7 days:** Root cause analysis and remediation plan

### 12.2 Opt-Out Violation

If telemetry collected while opted out:

1. **Immediate:** Investigate root cause (client vs. server bug)
2. **Within 1 hour:** Deploy hotfix or kill switch
3. **Within 24 hours:** Purge improperly collected data
4. **Within 7 days:** Notify affected users and provide audit log

### 12.3 Retention Violation

If data retained beyond policy:

1. **Immediate:** Identify affected data (log group, metric, etc.)
2. **Within 24 hours:** Purge expired data
3. **Within 7 days:** Fix retention policy configuration
4. **Within 30 days:** Verify no recurrence (monthly audit)

## 13. Policy Updates

### 13.1 Versioning

- Policy version follows semantic versioning (MAJOR.MINOR)
- MAJOR: Breaking changes (e.g., new data collection)
- MINOR: Clarifications, non-breaking updates

### 13.2 Change Process

1. Propose change via ADR (Architecture Decision Record)
2. Review by Engineering + Compliance teams
3. User notification (if MAJOR change requires new consent)
4. Update policy document (this file)
5. Update client consent prompt (if applicable)

### 13.3 Notification

Users notified of MAJOR policy changes via:
- In-app notification (next launch after update)
- Release notes
- Email (if opted-in to communications)

## 14. References

### 14.1 Architecture Documents

- **Section 3.6:** Observability & Telemetry ([04_Operational_Architecture.md](../../.codemachine/artifacts/architecture/04_Operational_Architecture.md))
- **Section 3.15:** Operational Metrics Catalog ([04_Operational_Architecture.md](../../.codemachine/artifacts/architecture/04_Operational_Architecture.md))

### 14.2 Implementation Files

**Client-Side:**
- `lib/infrastructure/telemetry/telemetry_config.dart` - Opt-out configuration
- `lib/infrastructure/telemetry/telemetry_service.dart` - Desktop telemetry service
- `lib/infrastructure/telemetry/otlp_exporter.dart` - OTLP export
- `lib/infrastructure/telemetry/structured_log_schema.dart` - Log schema

**Server-Side:**
- `server/telemetry-collector/lib/main.js` - Collector service
- `api/telemetry.yaml` - OpenAPI specification

### 14.3 Compliance Standards

- **GDPR:** General Data Protection Regulation (EU)
- **CCPA:** California Consumer Privacy Act
- **OpenTelemetry:** https://opentelemetry.io/docs/specs/otlp/

## 15. Contact

- **Engineering Lead:** [engineering@wiretuner.io](mailto:engineering@wiretuner.io)
- **Compliance Officer:** [compliance@wiretuner.io](mailto:compliance@wiretuner.io)
- **Privacy Inquiries:** [privacy@wiretuner.io](mailto:privacy@wiretuner.io)

---

**Approval:**

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Engineering Lead | [Pending] | [Pending] | [Pending] |
| Compliance Officer | [Pending] | [Pending] | [Pending] |
| Legal Counsel | [Pending] | [Pending] | [Pending] |

---

**Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-11 | Claude (CodeImplementer) | Initial policy draft for I2.T6 |
