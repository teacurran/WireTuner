# WireTuner Feature Flag Rollout Guide

<!-- anchor: feature-flag-rollout -->

**Task Reference:** I5.T5
**Requirements:** Section 3.5 (Feature Flags), FR-012 (A/B Testing), FR-013 (Phased Rollouts)
**Owner:** DevOps/Product Team
**Version:** 1.0.0

---

## Overview

This runbook provides step-by-step procedures for managing LaunchDarkly feature flags across WireTuner environments. Feature flags enable safe, gradual rollouts of new features and provide instant rollback capabilities without code deployments.

**Key Principles:**
1. **Start OFF in production** - new flags default to disabled
2. **Version-controlled configs** - LaunchDarkly JSON bundles committed to git
3. **Gradual rollout** - 10% → 50% → 100% with monitoring between stages
4. **Instant rollback** - toggle flags OFF without deployment
5. **Traceability** - document rollout history, tie flags to FR/ADR references

**Architecture Reference:** Section 3.5 (Deployment & Release Pipeline)

---

## LaunchDarkly Environment Mapping

**WireTuner uses the following LaunchDarkly environments:**

| Environment | Purpose | Update Frequency | Approval Required |
|-------------|---------|------------------|-------------------|
| `development` | Local developer testing | On-demand | No |
| `staging` | Pre-production validation, QA testing | Multiple times daily | Tech Lead |
| `production` | Live customer traffic | Controlled rollouts | Product Owner + DevOps |

**Project:** `wiretuner`
**SDK Keys:** Stored in AWS Secrets Manager (`/wiretuner/launchdarkly/sdk-key-{env}`)

---

## Feature Flag Lifecycle

### 1. Flag Creation

**When creating a new feature flag:**

```bash
# Via LaunchDarkly CLI
launchdarkly-cli flags create \
  --project wiretuner \
  --key new_feature_name \
  --name "New Feature Name" \
  --description "FR-XXX: Brief description of feature purpose" \
  --tags "iteration:I5,team:frontend,type:release" \
  --variations '{"true": true, "false": false}' \
  --default-on-variation false \
  --default-off-variation false
```

**Flag Naming Convention:**
- **Prefix by scope:** `ui_`, `api_`, `infra_`, `experiment_`
- **Snake_case:** `gpu_acceleration`, `new_pdf_exporter`, `realtime_collaboration_v2`
- **Versioning:** Append `_v2`, `_v3` for iterative feature rewrites

**Required Metadata:**
- **Tags:** Iteration ID (e.g., `iteration:I5`), team, feature type
- **Description:** Reference to FR/NFR/ADR (e.g., "FR-008: GPU-accelerated rendering")
- **Maintainer:** Engineering lead responsible for flag lifecycle

### 2. Default States (Per Environment)

**Configure initial states for all environments:**

| Environment | Default State | Rollout % | Reason |
|-------------|---------------|-----------|--------|
| `development` | ON | 100% | Allow devs to test immediately |
| `staging` | ON | 100% | Full QA validation before production |
| `production` | OFF | 0% | Safe default, controlled rollout |

**Command:**
```bash
# Set production flag to OFF (safe default)
launchdarkly-cli flags update \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --on false
```

### 3. Version-Controlled Configuration

**All LaunchDarkly configs must be committed to git:**

**File:** `config/launchdarkly/flags.json`
```json
{
  "flags": {
    "gpu_acceleration": {
      "key": "gpu_acceleration",
      "on": true,
      "fallthrough": {
        "variation": 0,
        "rollout": {
          "bucketBy": "userId",
          "variations": [
            {"variation": 0, "weight": 10000},
            {"variation": 1, "weight": 90000}
          ]
        }
      },
      "variations": [
        {"value": true, "name": "ON"},
        {"value": false, "name": "OFF"}
      ],
      "metadata": {
        "requirement": "FR-015",
        "iteration": "I4",
        "rollout_plan": "10% → 50% → 100% over 7 days"
      }
    }
  }
}
```

**Commit workflow:**
```bash
git add config/launchdarkly/flags.json
git commit -m "feat(flags): add gpu_acceleration flag (FR-015)"
git push origin main
```

---

## Rollout Procedures

### Phase 1: Pre-Rollout Validation

**Before enabling any flag in production:**

- [ ] **Code deployed** - feature code is in production (behind flag)
- [ ] **Staging tested** - flag enabled at 100% in staging, QA passed
- [ ] **Metrics ready** - CloudWatch dashboards monitor feature KPIs
- [ ] **Rollback plan documented** - know how to disable flag instantly
- [ ] **Stakeholders notified** - product/support teams aware of rollout

**Validation Commands:**
```bash
# Verify flag exists in production
launchdarkly-cli flags get \
  --project wiretuner \
  --environment production \
  --key new_feature_name

# Check current state
launchdarkly-cli flags get-status \
  --project wiretuner \
  --environment production \
  --key new_feature_name
```

### Phase 2: Gradual Rollout (10% → 50% → 100%)

**Step 1: 10% Rollout (Canary)**

```bash
# Enable flag for 10% of users
launchdarkly-cli flags update-targeting \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --on true \
  --fallthrough-rollout '{"bucketBy": "userId", "variations": [{"variation": 0, "weight": 10000}, {"variation": 1, "weight": 90000}]}'
```

**Wait Period:** 2-24 hours (depending on feature risk)

**Monitoring Checklist:**
- [ ] Error rate within SLO (< 0.5%)
- [ ] Feature-specific metrics healthy (e.g., export success rate > 95%)
- [ ] No spike in support tickets related to feature
- [ ] CloudWatch logs show no new errors
- [ ] User feedback (if available) is positive or neutral

**If issues detected:** See "Rollback Procedure" below.

---

**Step 2: 50% Rollout**

```bash
# Increase to 50% of users
launchdarkly-cli flags update-targeting \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --fallthrough-rollout '{"bucketBy": "userId", "variations": [{"variation": 0, "weight": 50000}, {"variation": 1, "weight": 50000}]}'
```

**Wait Period:** 1-3 days

**Monitoring Checklist:** Same as 10% stage, plus:
- [ ] A/B test results (if applicable) show positive or neutral impact
- [ ] Performance benchmarks within tolerance (< 10% regression)

---

**Step 3: 100% Rollout (Full Availability)**

```bash
# Enable for all users
launchdarkly-cli flags update-targeting \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --fallthrough-rollout '{"bucketBy": "userId", "variations": [{"variation": 0, "weight": 100000}, {"variation": 1, "weight": 0}]}'

# Or simply set to ON without rollout
launchdarkly-cli flags update \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --on true \
  --fallthrough-variation 0
```

**Wait Period:** 7-14 days before archiving flag

**Post-Rollout Actions:**
- [ ] Update release notes with feature availability
- [ ] Schedule flag removal (see "Flag Retirement" below)
- [ ] Document rollout metrics in postmortem

### Phase 3: Monitoring & Validation

**During each rollout phase, monitor:**

**KPI Dashboard (CloudWatch):**
```bash
# Query feature-specific metrics
aws cloudwatch get-metric-statistics \
  --namespace WireTuner/Features \
  --metric-name NewFeatureUsageCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

**LaunchDarkly Evaluation Analytics:**
- Check evaluation counts: LD dashboard → Flags → `new_feature_name` → Evaluations
- Expected: Evaluations increase proportionally to rollout % (10% = ~1000 evals/hour if total = 10k/hour)

**Error Tracking:**
```bash
# Search logs for feature-related errors
aws logs filter-log-events \
  --log-group-name /aws/eks/wiretuner/api \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern '"new_feature_name" ERROR'
```

---

## Rollback Procedure

**Immediate Rollback (< 1 minute):**

```bash
# Disable flag instantly
launchdarkly-cli flags update \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --on false

# Verify rollback
launchdarkly-cli flags get \
  --project wiretuner \
  --environment production \
  --key new_feature_name | grep '"on": false'
```

**Post-Rollback Actions:**
- [ ] Notify stakeholders via Slack (#incidents, #engineering)
- [ ] Update status page if customer-facing issue
- [ ] Create incident ticket using `docs/ops/runbooks/incident_template.md`
- [ ] Document rollback reason in flag metadata
- [ ] Schedule postmortem to investigate root cause

**Rollback Triggers:**
- Error rate exceeds 2% for feature-specific endpoints
- Customer reports of data loss or corruption
- Performance degradation > 20% from baseline
- Security vulnerability discovered in feature code

---

## Advanced Targeting & Experiments

### User Segmentation

**Target specific user cohorts:**

```bash
# Enable for enterprise customers only
launchdarkly-cli flags update-targeting \
  --project wiretuner \
  --environment production \
  --key new_feature_name \
  --on true \
  --targets '[{"variation": 0, "values": ["enterprise_plan"]}]'
```

**Use Cases:**
- **Early access:** Beta testers, internal employees
- **Plan-based:** Enterprise vs. Free tier features
- **Geographic:** Region-specific rollouts (GDPR compliance)
- **Opt-in:** Users who enable experimental features in settings

### A/B Testing

**Run experiments with custom metrics:**

**LaunchDarkly Experiment Configuration:**
```json
{
  "key": "new_pdf_exporter_experiment",
  "variations": [
    {"value": "control", "name": "Legacy Exporter"},
    {"value": "treatment", "name": "New GPU-Accelerated Exporter"}
  ],
  "metrics": [
    {"key": "export_success_rate", "goal": "maximize"},
    {"key": "export_duration_ms", "goal": "minimize"}
  ],
  "allocation": {
    "control": 50,
    "treatment": 50
  }
}
```

**Evaluation:**
- Run for minimum 7 days or 1000 samples per variation
- Statistical significance: p-value < 0.05
- Decision: Promote treatment to 100% if success rate > control by 5%+

**Reference:** FR-012 (A/B Testing), Section 3.5 (Feature Flags)

---

## Flag Retirement & Cleanup

**After 100% rollout is stable (14+ days):**

### Step 1: Code Cleanup

**Remove flag conditionals from codebase:**

```dart
// Before (with flag)
if (featureFlags.isEnabled('new_feature_name')) {
  // New feature code
} else {
  // Legacy code
}

// After (flag removed)
// New feature code (only)
```

**Create PR:**
```bash
git checkout -b cleanup/remove-new-feature-flag
# Edit code to remove flag checks
git commit -m "refactor: remove new_feature_name flag (100% rolled out)"
git push origin cleanup/remove-new-feature-flag
```

### Step 2: Archive Flag in LaunchDarkly

```bash
# Archive flag (preserves history but hides from active list)
launchdarkly-cli flags archive \
  --project wiretuner \
  --key new_feature_name \
  --comment "Feature fully rolled out, flag removed from codebase in PR #456"
```

**Archived flags:**
- Remain in LaunchDarkly audit logs
- Cannot be accidentally toggled
- Can be restored if needed

### Step 3: Update Documentation

- [ ] Remove flag from `config/launchdarkly/flags.json`
- [ ] Update release notes to reflect permanent feature availability
- [ ] Archive flag metadata in `docs/ops/feature_flags/retired/`

**Retirement Cadence:** Review flags quarterly; aim to remove flags within 30 days of 100% rollout.

---

## Offline Client Behavior

**Installer Manifest Configuration:**

Section 3.5 specifies: "Installers reference a manifest JSON containing feature-flag bootstrap payloads."

**File:** `installers/manifest.json`
```json
{
  "version": "0.1.0",
  "feature_flags": {
    "gpu_acceleration": true,
    "new_pdf_exporter": false,
    "realtime_collaboration_v2": true
  },
  "config_baseline": {
    "telemetry_sampling_rate": 0.1,
    "snapshot_interval_ms": 30000
  }
}
```

**Behavior:**
- Offline clients use bootstrap values until they connect to LaunchDarkly
- Installers updated with each release to reflect production defaults
- Users can manually refresh flags via "Check for Updates" in app

---

## Emergency Procedures

### Global Kill Switch

**Disable all feature flags (circuit breaker):**

```bash
# Bulk disable all flags with specific tag
launchdarkly-cli flags bulk-update \
  --project wiretuner \
  --environment production \
  --tag "type:release" \
  --state off
```

**Use Case:** System-wide instability, all new features suspect

### Flag Evaluation Timeout

**If LaunchDarkly API is unreachable:**
- SDK uses local cache (TTL: 5 minutes)
- After cache expires, SDK uses hardcoded defaults (all flags OFF)
- CloudWatch alarm triggers if evaluation failures exceed 1%

**Monitoring:**
```bash
# Check LaunchDarkly API health
curl -I https://app.launchdarkly.com/api/v2/flags/wiretuner/production
# Expected: HTTP 200

# Check evaluation failure rate
aws cloudwatch get-metric-statistics \
  --namespace WireTuner/FeatureFlags \
  --metric-name EvaluationFailureRate \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

---

## Best Practices & Guidelines

### Naming & Organization

- **Prefix flags by type:** `release_`, `experiment_`, `ops_`, `kill_switch_`
- **Use tags liberally:** Iteration, team, FR reference, expiry date
- **Keep descriptions updated:** Change log in flag comments

### Security

- **Avoid sensitive data in flag keys/values** - use config service for secrets
- **Audit flag changes** - LaunchDarkly logs all updates with user/timestamp
- **Restrict production access** - only DevOps and Product Owners can modify prod flags

### Performance

- **Limit flag evaluations in hot paths** - cache results locally if called > 100/sec
- **Use bulk evaluations** - SDK supports batch lookups to reduce network calls
- **Monitor SDK performance** - flag evaluation latency should be < 1ms (local cache)

### Compliance

- **GDPR:** Do not bucket users by PII; use anonymized user IDs
- **Data retention:** LaunchDarkly stores evaluation data for 30 days (configurable)
- **Change control:** All flag updates require git commit + approval (see Section 4)

---

## Troubleshooting

### Flag Not Updating for User

**Symptom:** User reports old behavior despite flag enabled

**Diagnosis:**
1. Check flag state: `launchdarkly-cli flags get ...`
2. Verify user in rollout bucket: Check user ID hash vs. rollout %
3. Inspect SDK evaluation logs: Look for client-side cache invalidation
4. Test with flag targeting: Add user ID to explicit targets

**Resolution:**
- Increase rollout % to 100% if user unexpectedly in OFF bucket
- Force SDK to refresh: Restart app or call `ldClient.flush()`

### High Evaluation Latency

**Symptom:** CloudWatch shows `FeatureFlagEvaluationLatency > 10ms`

**Diagnosis:**
- Check LaunchDarkly API latency: External monitoring
- Inspect SDK cache hit rate: Should be > 99%
- Look for network issues: VPC routing, security groups

**Resolution:**
- Increase SDK polling interval to reduce API calls
- Enable SDK streaming mode for real-time updates
- Consider local flag relay server for high-throughput apps

### Flag Evaluation Failures

**Symptom:** SDK returns default values, CloudWatch alarm triggered

**Diagnosis:**
- Verify LaunchDarkly API key: Check AWS Secrets Manager
- Check network connectivity: `curl https://app.launchdarkly.com`
- Inspect SDK logs: Look for authentication errors

**Resolution:**
- Rotate API key if expired/compromised
- Whitelist LaunchDarkly IPs in security groups
- Implement circuit breaker pattern with fallback defaults

---

## Quick Reference Commands

```bash
# List all production flags
launchdarkly-cli flags list --project wiretuner --environment production

# Get flag details
launchdarkly-cli flags get --project wiretuner --environment production --key FLAG_KEY

# Enable flag for 10% of users
launchdarkly-cli flags update-targeting \
  --project wiretuner --environment production --key FLAG_KEY \
  --on true \
  --fallthrough-rollout '{"bucketBy": "userId", "variations": [{"variation": 0, "weight": 10000}, {"variation": 1, "weight": 90000}]}'

# Disable flag immediately
launchdarkly-cli flags update --project wiretuner --environment production --key FLAG_KEY --on false

# Archive retired flag
launchdarkly-cli flags archive --project wiretuner --key FLAG_KEY

# Bulk disable all release flags
launchdarkly-cli flags bulk-update --project wiretuner --environment production --tag "type:release" --state off
```

---

## References

**Architecture:**
- Operational Architecture: `docs/blueprint/04_Operational_Architecture.md` Section 3.5
- Feature Requirements: FR-012 (A/B Testing), FR-013 (Phased Rollouts)

**Related Runbooks:**
- Release Checklist: `docs/ops/runbooks/release_checklist.md`
- Incident Template: `docs/ops/runbooks/incident_template.md`

**External Documentation:**
- LaunchDarkly Docs: https://docs.launchdarkly.com/
- LaunchDarkly CLI: https://github.com/launchdarkly/ld-cli-core

**Approval & Review:**
- LaunchDarkly flag changes require git commit approval (Section 4 directives)
- Production flag updates logged in `#ops-audit` Slack channel

---

**Revision History:**
- v1.0.0 (2024-01-15): Initial feature flag runbook created for Task I5.T5
