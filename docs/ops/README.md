# WireTuner Operations Documentation

<!-- anchor: ops-documentation -->

**Task Reference:** I5.T5
**Requirements:** Section 3.7 (Operational Procedures), Section 4 (Directives)
**Version:** 1.0.0

---

## Overview

This directory contains all operational runbooks, procedures, and automation scripts for WireTuner releases, incident response, and production management.

**Contents:**
- **Runbooks:** Step-by-step operational procedures
- **Scripts:** Automated release and incident management tools
- **Templates:** Standardized incident and maintenance templates

---

## Quick Links

### Runbooks

| Runbook | Purpose | When to Use |
|---------|---------|-------------|
| [Release Checklist](runbooks/release_checklist.md) | Complete pre/post-release procedures | Before every production deployment |
| [Incident Template](runbooks/incident_template.md) | Incident response and postmortem | During P0-P3 incidents |
| [Feature Flag Rollout](runbooks/feature_flag_rollout.md) | LaunchDarkly flag management | Feature rollouts, A/B tests, experiments |

### Automation Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| [Release Pipeline](../../scripts/ops/release_pipeline.sh) | Orchestrate macOS/Windows builds | `release_pipeline.sh --version 0.1.0` |
| [Status Page](../../scripts/ops/update_status_page.sh) | Automate status page updates | `update_status_page.sh --status investigating ...` |
| [macOS DMG](../../tools/installer/macos/build_dmg.sh) | Build signed macOS installer | `build_dmg.sh --version 0.1.0` |
| [Windows MSI](../../tools/installer/windows/build_msi.ps1) | Build signed Windows installer | `build_msi.ps1 -Version 0.1.0` |

---

## Release Operations

### Standard Release Workflow

1. **Pre-Release (1-2 days before):**
   - Follow [Release Checklist](runbooks/release_checklist.md) Phase 1
   - Review feature flags: [Feature Flag Runbook](runbooks/feature_flag_rollout.md)
   - Validate staging environment
   - Draft release notes

2. **Build Artifacts:**
   ```bash
   # Full production build (signed and notarized)
   scripts/ops/release_pipeline.sh --version 0.1.0

   # Dry run (local testing without signing)
   scripts/ops/release_pipeline.sh --version 0.1.0 --dry-run
   ```

3. **Deploy to Production:**
   - Backend services: Argo CD rolling update
   - Desktop installers: Publish to S3, update download links
   - Feature flags: Gradual rollout (10% → 50% → 100%)

4. **Post-Release (48 hours):**
   - Monitor KPIs: Error rates, latency, queue depth
   - Triage incidents: Use [Incident Template](runbooks/incident_template.md)
   - Update status page: [Status Page Script](../../scripts/ops/update_status_page.sh)

### Hotfix Workflow

**For critical production issues:**

1. Create hotfix branch from release tag: `git checkout -b hotfix/v0.1.1 v0.1.0`
2. Implement minimal fix, no feature changes
3. Fast-track review (skip full QA for P0 incidents)
4. Deploy via release pipeline: `scripts/ops/release_pipeline.sh --version 0.1.1`
5. Update incident: `scripts/ops/update_status_page.sh --action resolve --incident-id INC-XXX`

**Reference:** ADR-005 (Hotfix Process - TODO), Section 3.7 (Incident Playbooks)

---

## Incident Response

### Severity Levels

| Severity | Response Time | Examples | Escalation |
|----------|---------------|----------|------------|
| **P0** | < 5 minutes | API outage, data loss, security breach | Immediate exec notification |
| **P1** | < 15 minutes | Collaboration sync broken, 50%+ users affected | DevOps lead + on-call |
| **P2** | < 1 hour | Feature degraded, workaround available | On-call engineer |
| **P3** | < 24 hours | Cosmetic bug, low user impact | Standard ticket queue |

### Incident Workflow

1. **Detection:** CloudWatch alarm, PagerDuty, customer report
2. **Create Incident:**
   ```bash
   scripts/ops/update_status_page.sh \
     --status investigating \
     --component collaboration \
     --message "Investigating delays in real-time sync" \
     --action create
   ```
3. **Investigate:** Follow [Incident Template](runbooks/incident_template.md) Phase 2
4. **Remediate:** Deploy fix or roll back feature flags
5. **Resolve Incident:**
   ```bash
   scripts/ops/update_status_page.sh \
     --status resolved \
     --incident-id INC-2024-01-15-001 \
     --message "Issue resolved, all systems operational" \
     --action resolve
   ```
6. **Postmortem:** Within 48 hours, document learnings and action items

---

## Feature Flag Management

### Flag Lifecycle

1. **Create Flag:** LaunchDarkly CLI or web UI
   - Naming: `{prefix}_{feature_name}` (e.g., `ui_new_exporter`)
   - Tags: `iteration:I5`, `team:frontend`, `type:release`
   - Default: OFF in production

2. **Gradual Rollout:**
   ```bash
   # 10% canary
   launchdarkly-cli flags update-targeting ... --rollout 10%
   # Wait 2-24 hours, monitor KPIs

   # 50% rollout
   launchdarkly-cli flags update-targeting ... --rollout 50%
   # Wait 1-3 days

   # 100% full availability
   launchdarkly-cli flags update-targeting ... --rollout 100%
   ```

3. **Monitor:** LaunchDarkly evaluation counts, CloudWatch feature metrics

4. **Retire Flag:** After 14+ days at 100%, remove from code and archive
   ```bash
   launchdarkly-cli flags archive --key feature_name
   ```

**Detailed Guide:** [Feature Flag Rollout Runbook](runbooks/feature_flag_rollout.md)

---

## Installer Build Details

### macOS DMG

**Script:** [tools/installer/macos/build_dmg.sh](../../tools/installer/macos/build_dmg.sh)

**Features:**
- Flutter release build compilation
- Code signing with Developer ID Application certificate
- Apple notarization via `notarytool`
- Stapling notarization ticket for offline verification
- SHA256 checksum generation

**Requirements:**
- macOS 13+ build host
- Xcode Command Line Tools
- Environment variables: `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`, `DEVELOPER_ID`

**Example:**
```bash
# Full signed and notarized DMG
tools/installer/macos/build_dmg.sh --version 0.1.0

# Local testing (skip notarization)
tools/installer/macos/build_dmg.sh --version 0.1.0 --skip-notarize
```

**Verification:**
```bash
# Check signature
codesign -dvv build/macos/WireTuner-0.1.0.dmg

# Verify notarization
spctl -a -vv -t install build/macos/WireTuner-0.1.0.dmg
```

### Windows MSI/Installer

**Script:** [tools/installer/windows/build_msi.ps1](../../tools/installer/windows/build_msi.ps1)

**Features:**
- Flutter release build compilation
- Code signing with Authenticode certificate (signtool)
- Inno Setup or WiX Toolset installer generation
- SHA256 checksum generation

**Requirements:**
- Windows 10+ build host
- Windows SDK (for signtool.exe)
- Inno Setup 6 or WiX Toolset v3.11+
- Environment variables: `WINDOWS_PFX_PATH`, `WINDOWS_PFX_PASSWORD`

**Example:**
```powershell
# Full signed installer
.\tools\installer\windows\build_msi.ps1 -Version 0.1.0

# Local testing (skip signing)
.\tools\installer\windows\build_msi.ps1 -Version 0.1.0 -SkipSigning
```

**Verification:**
```powershell
# Check signature
signtool verify /pa /v build\windows\WireTuner-Setup-0.1.0.exe
```

---

## Monitoring & Observability

### Key Performance Indicators (KPIs)

**From Section 3.5:**
- **Event Replay Rate:** Events/sec (baseline: ~1000/sec)
- **Snapshot Duration:** Milliseconds (target: < 500ms)
- **OT Transform Latency:** Milliseconds (target: < 50ms)
- **Queue Depth:** Messages in pub/sub (target: < 100)
- **Error Rate:** Percentage (SLO: < 0.5%)
- **Collaboration Sessions:** Active concurrent sessions (~200 typical)

### Dashboards

**CloudWatch:**
- API Gateway: Latency, error rates, request counts
- Collaboration: OT latency, event replay, session counts
- Import/Export: Job success rates, processing times
- Infrastructure: EKS pod health, RDS connections, Redis memory

**Access:** https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=WireTuner

### Alerts

**PagerDuty Escalation:**
1. On-call engineer (< 5 min response)
2. DevOps lead (< 15 min escalation)
3. Engineering manager (< 30 min escalation)

**Alert Links:** All alerts include runbook anchors (e.g., `#incident-database-locks`)

---

## Disaster Recovery

### Backup Strategy

**PostgreSQL:**
- Continuous WAL archiving to S3 (multi-AZ)
- Automated snapshots every 6 hours
- Retention: 30 days
- Cross-region replication: us-east-1 → us-west-2

**Redis:**
- RDB snapshots every 15 minutes
- AOF persistence enabled
- Retention: 7 days

**Recovery Time Objective (RTO):** < 15 minutes
**Recovery Point Objective (RPO):** < 1 hour

### Recovery Procedures

**Database Restore:**
```bash
# List available snapshots
aws rds describe-db-snapshots --db-instance-identifier wiretuner-prod

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier wiretuner-prod-restored \
  --db-snapshot-identifier wiretuner-prod-2024-01-15-00-00
```

**Collaboration Session Draining:**
```bash
# Graceful shutdown: allow sessions to complete, block new connections
kubectl scale deployment wiretuner-collaboration --replicas=0

# Force drain: terminate all sessions immediately
redis-cli FLUSHDB
```

**Reference:** Section 3.5 (Disaster Recovery Drills), Section 3.7 (Runbooks)

---

## Security & Compliance

### Secrets Management

**AWS Secrets Manager:**
- Database credentials: `/wiretuner/db/credentials`
- LaunchDarkly API keys: `/wiretuner/launchdarkly/sdk-key-{env}`
- Code signing certificates: `/wiretuner/signing/{macos|windows}`

**Rotation Schedule:**
- Database passwords: Every 90 days
- API keys: Every 180 days
- Signing certificates: Before expiry (annually)

### Vulnerability Scanning

**Tools:**
- **Snyk:** Dependency scanning (CI integration)
- **Trivy:** Container image scanning
- **Clair:** Registry scanning (ECR)

**Policy:** Findings block releases until remediated or risk-accepted with expiry dates.

### Audit Logs

**LaunchDarkly:** All flag changes logged with user, timestamp, before/after states
**Terraform:** State changes tracked in git, plans require approval
**AWS CloudTrail:** All infrastructure API calls logged for 90 days

---

## Continuous Improvement

### Quarterly Reviews

**Topics:**
- Runbook effectiveness (incident resolution times)
- Backup/restore drills (RTO/RPO compliance)
- Feature flag retirement (reduce technical debt)
- Alert fatigue analysis (false positive rates)

### Metrics Tracking

**Release Frequency:** Target 2 weeks (biweekly releases)
**Incident MTTR:** Mean time to resolution (target: < 2 hours for P1)
**Deployment Success Rate:** Percentage of releases without rollback (target: > 95%)
**Feature Flag Lifespan:** Days from creation to retirement (target: < 60 days)

---

## Contact & Escalation

### Teams

| Team | Responsibilities | Slack Channel |
|------|------------------|---------------|
| DevOps | Infrastructure, releases, monitoring | #devops |
| On-Call | Incident response, first responder | #oncall |
| Security | Vulnerability management, compliance | #security |
| Support | Customer communications, tickets | #support |

### Emergency Contacts

**PagerDuty:** https://wiretuner.pagerduty.com/
**Status Page:** https://status.wiretuner.app/
**Incident Hotline:** [On-call rotation phone - TODO]

---

## References

### Architecture Documents

- [Operational Architecture](../blueprint/04_Operational_Architecture.md) - Section 3.5, 3.7, 3.28, 3.29
- [Plan Overview](../blueprint/01_Plan_Overview_and_Setup.md) - Section 4 (Directives)
- [Release Notes Template](../reference/release_notes.md)

### External Documentation

- **LaunchDarkly:** https://docs.launchdarkly.com/
- **AWS CloudWatch:** https://docs.aws.amazon.com/cloudwatch/
- **Argo CD:** https://argo-cd.readthedocs.io/
- **PagerDuty:** https://support.pagerduty.com/

### CI/CD Scripts

- [macOS CI Build](../../scripts/ci/build_macos_release.sh)
- [Windows CI Build](../../scripts/ci/build_windows_release.ps1)

---

## Change Log

**v1.0.0 (2024-01-15):**
- Initial ops documentation created for Task I5.T5
- Release pipeline automation scripts
- Runbooks: Release checklist, incident template, feature flag rollout
- Status page automation integration

**Future Enhancements:**
- Disaster recovery runbook (Section 3.7)
- Database migration procedures
- Terraform automation integration
- Canary deployment automation

---

**Maintained by:** DevOps Team
**Last Updated:** 2024-01-15
**Review Schedule:** Quarterly
