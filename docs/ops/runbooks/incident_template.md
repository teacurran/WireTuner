# WireTuner Incident Response Template

<!-- anchor: incident-template -->

**Task Reference:** I5.T5
**Requirements:** Section 3.7 (Incident Playbooks), NFR-007 (Reliability)
**Version:** 1.0.0

---

## Incident Metadata

**Fill out immediately upon incident detection:**

```yaml
incident_id: INC-YYYY-MM-DD-NNN
severity: [P0 | P1 | P2 | P3]
status: [INVESTIGATING | IDENTIFIED | MONITORING | RESOLVED]
affected_service: [API | Collaboration | Import | Export | Infrastructure]
impact: [OUTAGE | DEGRADED | PARTIAL | MINOR]
customer_impact: [ALL | ENTERPRISE | SUBSET | NONE]
detection_time: YYYY-MM-DD HH:MM:SS UTC
response_time: YYYY-MM-DD HH:MM:SS UTC
resolution_time: YYYY-MM-DD HH:MM:SS UTC (or TBD)
incident_commander: [Name]
on_call_engineer: [Name]
stakeholders_notified: [Yes | No | Partial]
```

---

## Severity Definitions

**Reference:** Section 3.7 (Operational Procedures), PagerDuty escalation policies

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P0** | **Critical Outage** - Service unavailable, data loss risk, security breach | Immediate (< 5 min) | API returning 500s for all requests, database corruption, authentication system down |
| **P1** | **Major Degradation** - Core functionality impaired, significant user impact | < 15 minutes | Collaboration sync delays > 30s, import/export failing for 50%+ users, OT transform errors |
| **P2** | **Moderate Issue** - Feature impaired, workaround available, localized impact | < 1 hour | PDF export quality degraded, specific file format import broken, dashboard metrics missing |
| **P3** | **Minor Issue** - Cosmetic or low-impact bug, no workaround needed | < 24 hours | UI rendering glitch, telemetry sampling drift, status page formatting |

**Escalation:** P0/P1 incidents require immediate executive notification and status page updates.

---

## Phase 1: Detection & Initial Response

### Symptoms & Alert Source

**How was the incident detected?**
- [ ] CloudWatch alarm (specify metric: _________________)
- [ ] PagerDuty alert (alert name: _________________)
- [ ] Synthetic monitor failure (endpoint: _________________)
- [ ] Customer report (ticket ID: _________________)
- [ ] Internal user observation (reported by: _________________)
- [ ] Security scan / anomaly detection (tool: _________________)

**Observable Symptoms:**
```
[Describe what users/systems are experiencing]
Examples:
- API latency spiked from 200ms to 5000ms
- Collaboration sessions not syncing across clients
- Import wizard showing "Unknown error" for all SVG files
- Redis pub/sub fan-out lag exceeding 10 seconds
```

**Initial Metrics Snapshot:**
```
[Capture baseline metrics - see Section 3.5 KPIs]
- Event replay rate: _____ events/sec (baseline: 1000/sec)
- Snapshot duration: _____ ms (baseline: 500ms)
- OT transform latency: _____ ms (baseline: 50ms)
- Queue depth: _____ messages (baseline: < 100)
- Error rate: _____ % (baseline: < 0.5%)
- Active collaboration sessions: _____ (typical: ~200)
```

**Quick Links:**
- CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/...
- PagerDuty Incident: https://wiretuner.pagerduty.com/incidents/...
- Logs (Kibana): https://logs.wiretuner.app/...
- Datadog APM: https://app.datadoghq.com/...

---

## Phase 2: Investigation & Diagnosis

### Hypotheses & Testing

**Working Hypotheses (prioritized):**
1. [Hypothesis 1 - e.g., "Database connection pool exhausted"]
   - **Test:** Check PostgreSQL `max_connections`, query for long-running transactions
   - **Result:** _________________
   - **Conclusion:** [Confirmed | Rejected | Inconclusive]

2. [Hypothesis 2 - e.g., "Redis pub/sub fan-out lag due to slow consumer"]
   - **Test:** Identify slow consumers via `CLIENT LIST`, check network I/O
   - **Result:** _________________
   - **Conclusion:** [Confirmed | Rejected | Inconclusive]

3. [Hypothesis 3 - e.g., "Feature flag evaluation timeout"]
   - **Test:** LaunchDarkly API latency, check flag evaluation counts
   - **Result:** _________________
   - **Conclusion:** [Confirmed | Rejected | Inconclusive]

### Diagnostic Commands

**Document commands executed during investigation:**

```bash
# Example: Check database locks (Section 3.7 - database lock resolution)
psql -h $DB_HOST -U wiretuner -c "SELECT * FROM pg_stat_activity WHERE state != 'idle';"

# Example: Inspect Redis pub/sub lag
redis-cli CLIENT LIST | grep -i "age=.*flags=P"

# Example: Check EKS pod health
kubectl get pods -n wiretuner-prod -o wide
kubectl logs -n wiretuner-prod deployment/wiretuner-api --tail=100

# Example: Query CloudWatch logs
aws logs filter-log-events --log-group-name /aws/eks/wiretuner/api \
  --start-time $(date -d '30 minutes ago' +%s)000 \
  --filter-pattern "ERROR"

# Example: Feature flag evaluation stats
curl -H "Authorization: $LD_API_KEY" \
  https://app.launchdarkly.com/api/v2/flags/wiretuner/production
```

**Log Excerpts:**
```
[Paste relevant error logs, stack traces, or anomalies]
```

### Root Cause Analysis

**Confirmed Root Cause:**
```
[Describe the underlying technical cause]
Example:
- Deployment at 14:35 UTC introduced N+1 query in collaboration endpoint
- Database CPU spiked to 95%, connection pool exhausted within 10 minutes
- API gateway timeouts cascaded, affecting all real-time collaboration sessions
```

**Contributing Factors:**
- [Factor 1 - e.g., "Load testing did not simulate concurrent collaboration sessions"]
- [Factor 2 - e.g., "Database query monitoring alerts had 10-minute delay"]
- [Factor 3 - e.g., "No circuit breaker for LaunchDarkly API calls"]

**Blueprint References:**
- Architecture: `docs/blueprint/04_Operational_Architecture.md` Section 3.X
- ADR: `docs/adr/ADR-XXX-topic.md`
- Related Incidents: INC-YYYY-MM-DD-XXX

---

## Phase 3: Remediation & Mitigation

### Immediate Actions (Mitigation)

**Actions taken to restore service (may not fix root cause):**

1. **[Timestamp]** - [Action description]
   - **Executed by:** [Name]
   - **Command/Change:** `[command or manual change]`
   - **Result:** [Success | Partial | Failed]
   - **Impact:** [Restored XX% of traffic, reduced error rate to X%]

**Example:**
- **14:45 UTC** - Rolled back API deployment to previous version
  - **Executed by:** On-call engineer (Jane Doe)
  - **Command:** `argocd app rollback wiretuner-api --revision 12345`
  - **Result:** Success
  - **Impact:** Error rate dropped from 45% to 2% within 5 minutes

### Permanent Fix (Resolution)

**Actions to address root cause:**

1. **[Timestamp]** - [Permanent fix description]
   - **Change:** [Code fix, config update, infrastructure change]
   - **PR/Ticket:** [Link to GitHub PR or JIRA ticket]
   - **Deployed:** [Timestamp or "Pending next release"]
   - **Verification:** [How fix was validated]

**Example:**
- **15:30 UTC** - Optimized collaboration query to use indexed lookup
  - **Change:** Added database index on `sessions.updated_at`
  - **PR:** https://github.com/wiretuner/api/pull/456
  - **Deployed:** 16:00 UTC to production
  - **Verification:** Load test with 100 concurrent sessions, latency < 200ms

### Feature Flag Changes

**If feature flags were toggled during incident:**

| Flag Name | Previous State | New State | Timestamp | Reason |
|-----------|----------------|-----------|-----------|--------|
| `new_collab_sync` | 50% rollout | OFF | 14:50 UTC | Suspected cause of OT transform errors |
| `gpu_acceleration` | ON | OFF | 15:00 UTC | GPU fallback loop detected |

**Rollback Documentation:** See `docs/ops/runbooks/feature_flag_rollout.md`

---

## Phase 4: Communication & Stakeholder Updates

### Internal Communications

**PagerDuty Notifications:**
- [ ] Incident created and assigned
- [ ] Escalated to [Team/Person]
- [ ] Status updates posted every [15/30/60] minutes
- [ ] Incident resolved and closed

**Slack/Teams Updates:**
- [ ] #incidents channel notified
- [ ] #engineering-all briefed on root cause
- [ ] #customer-success alerted (if customer-facing)

### External Communications

**Status Page Updates:**
- [ ] Initial notification posted (timestamp: _________________)
- [ ] Updates during investigation (frequency: _________________)
- [ ] Resolution announcement (timestamp: _________________)
- [ ] Postmortem link shared (if public incident)

**Status Page Script:**
```bash
# See scripts/ops/update_status_page.sh
scripts/ops/update_status_page.sh \
  --status "investigating" \
  --component "Collaboration API" \
  --message "We are investigating delays in real-time collaboration sync."
```

**Customer Notifications:**
- [ ] Enterprise customers emailed (list: _________________)
- [ ] In-app toast notification triggered
- [ ] RSS feed updated
- [ ] Community forum pinned post (if prolonged)

**Email Template:**
```
Subject: [WireTuner] Service Incident - [Brief Description]

Dear WireTuner Users,

We experienced an incident affecting [service/feature] between [start time] and [end time] UTC.

Impact: [Description of user-visible impact]
Root Cause: [High-level explanation]
Resolution: [What we did to fix it]

We apologize for the disruption. For technical details, see our status page: https://status.wiretuner.app/incidents/INC-XXX

Thank you,
WireTuner Operations Team
```

---

## Phase 5: Verification & Monitoring

### Post-Remediation Checks

**Verify service restoration:**
- [ ] **Smoke tests passed** - core workflows functional (import, export, collaborate)
- [ ] **KPIs returned to baseline** - event replay rate, OT latency, queue depth normal
- [ ] **Error rate < 0.5%** - CloudWatch metrics within SLO
- [ ] **No new alerts** - PagerDuty quiet for 30+ minutes
- [ ] **Customer reports stopped** - no new support tickets related to incident

**Monitoring Period:**
- Start: [Timestamp when fix deployed]
- Duration: [24/48 hours]
- Assigned to: [On-call or incident commander]

### Regression Checks

**Ensure fix did not introduce new issues:**
- [ ] Unit tests passing (CI: _________________)
- [ ] Integration tests passing (CI: _________________)
- [ ] Performance benchmarks within tolerance (< 10% regression)
- [ ] Security scan clean (Snyk/Trivy: _________________)

---

## Phase 6: Postmortem & Follow-Up

### Postmortem Meeting

**Schedule within 48 hours of resolution:**
- **Date/Time:** _________________
- **Attendees:** Incident commander, on-call, engineering leads, product owner
- **Agenda:**
  1. Timeline review (detection → resolution)
  2. Root cause analysis (5 Whys)
  3. What went well (effective actions)
  4. What went wrong (gaps, delays)
  5. Action items (prevention, detection, response improvements)

**Postmortem Document:** [Link to Confluence/Notion/Google Doc]

### Action Items

**Preventative Measures:**
- [ ] **[ACTION-1]** - [Description] | Owner: [Name] | Due: [Date] | Status: [Open/In Progress/Done]
- [ ] **[ACTION-2]** - [Description] | Owner: [Name] | Due: [Date] | Status: [Open/In Progress/Done]

**Example:**
- [ ] **ACTION-DB-001** - Add database query timeout to collaboration endpoint | Owner: Backend Team | Due: 2024-02-01 | Status: In Progress
- [ ] **ACTION-MON-002** - Reduce CloudWatch alert delay from 10 min to 2 min | Owner: DevOps | Due: 2024-01-25 | Status: Open

**Detection Improvements:**
- [ ] Add synthetic monitor for collaboration sync latency
- [ ] Create CloudWatch anomaly detection for OT transform errors
- [ ] Improve PagerDuty alert descriptions with runbook links

**Response Improvements:**
- [ ] Update runbook with new diagnostic commands
- [ ] Automate rollback procedure (feature flags + deployment)
- [ ] Conduct tabletop exercise for similar scenarios

### Knowledge Base Update

**Documentation to update:**
- [ ] Runbook: `docs/ops/runbooks/[specific_runbook].md`
- [ ] ADR: Create new ADR if architecture change required
- [ ] FAQ: Add incident scenario to troubleshooting guide
- [ ] Training: Brief team on new procedures

---

## Metrics & SLO Impact

**Incident Duration:**
- **Detection to Response:** _____ minutes (Target: < 5 min for P0, < 15 min for P1)
- **Response to Mitigation:** _____ minutes
- **Mitigation to Resolution:** _____ minutes
- **Total Duration:** _____ minutes

**SLO Compliance:**
- **Availability SLO:** _____ % (Target: 99.9%)
- **Error Budget Consumed:** _____ % (Monthly budget: 0.1% = ~43 min downtime)
- **Latency SLO:** _____ ms p95 (Target: < 500ms)

**Customer Impact:**
- **Affected Users:** _____ (total user base: ~10,000)
- **Failed Requests:** _____ (total requests during incident: ~1M)
- **Support Tickets:** _____ (related to incident)

---

## Approval & Sign-Off

**Incident Resolution Approved By:**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Incident Commander | | | |
| On-Call Engineer | | | |
| Engineering Manager | | | |
| Head of Operations | | | |

**Postmortem Completion:**
- Date: _________________
- Link: _________________

---

## References & Runbook Links

**Operational Runbooks:**
- Release Checklist: `docs/ops/runbooks/release_checklist.md`
- Feature Flag Rollout: `docs/ops/runbooks/feature_flag_rollout.md`
- Disaster Recovery: `docs/ops/runbooks/disaster_recovery.md` (TODO)

**Architecture & KPIs:**
- Operational Architecture: `docs/blueprint/04_Operational_Architecture.md` Section 3.5, 3.7
- Performance Benchmarks: Section 3.20

**Escalation Contacts:**
- PagerDuty: https://wiretuner.pagerduty.com/escalation_policies/...
- Slack: #incidents, #engineering-oncall
- Emergency Phone: [On-call rotation phone number]

**Automation Tools:**
- Status Page Script: `scripts/ops/update_status_page.sh`
- Rollback Automation: `argocd`, `launchdarkly-cli`
- Log Aggregation: Kibana, CloudWatch Insights

---

**Revision History:**
- v1.0.0 (2024-01-15): Initial incident template created for Task I5.T5
