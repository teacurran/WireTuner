# WireTuner Release Checklist

<!-- anchor: release-checklist -->

**Task Reference:** I5.T5
**Requirements:** NFR-002 (Release Process), Section 3.29 (Operational Checklists)
**Owner:** DevOps/Release Engineer
**Version:** 1.0.0

---

## Overview

This runbook provides a comprehensive checklist for WireTuner releases, ensuring all quality gates, operational readiness criteria, and stakeholder communications are completed before production deployment.

**Release Phases:**
1. Pre-Release Preparation
2. Build & Artifact Generation
3. Quality Assurance & Testing
4. Deployment & Rollout
5. Post-Release Monitoring

---

## Phase 1: Pre-Release Preparation

### Code Freeze & Branch Management

- [ ] **Create release branch** from `main` (e.g., `release/v0.1.0`)
- [ ] **Lock release branch** - require approval for all commits
- [ ] **Tag release candidate** - `git tag -a v0.1.0-rc1 -m "Release candidate 1"`
- [ ] **Verify dependencies** - run `flutter pub outdated`, review security advisories
- [ ] **Update version numbers** in `pubspec.yaml`, `Info.plist`, `build.gradle`

**Requirements:** FR-001 (Version Control), ADR-003 (Branching Strategy)

### Feature Flags & Configuration

- [ ] **Review LaunchDarkly feature flags** - ensure production states are correct
- [ ] **Validate feature flag JSON** - check syntax, default values, rollout percentages
- [ ] **Document new flags** - update `docs/ops/runbooks/feature_flag_rollout.md`
- [ ] **Test flag toggles** - verify ON/OFF behavior in staging environment
- [ ] **Prepare rollback config** - export current production flag state

**Requirements:** Section 3.5 (Feature Flags), FR-012 (A/B Testing)

### Database & Infrastructure

- [ ] **Review database migrations** - check for breaking changes, rollback plans
- [ ] **Validate Terraform plans** - run `terraform plan`, ensure no unexpected drift
- [ ] **Verify secrets rotation** - check AWS KMS, LaunchDarkly API keys, signing certificates
- [ ] **Backup production data** - snapshot PostgreSQL, Redis to S3 (multi-AZ)
- [ ] **Confirm disaster recovery readiness** - test restore procedures in staging

**Requirements:** Section 3.5 (Infrastructure), NFR-004 (Data Persistence)

### Documentation & Communications

- [ ] **Draft release notes** - use template from `docs/reference/release_notes.md`
- [ ] **Update API documentation** - reflect breaking changes, new endpoints
- [ ] **Notify enterprise customers** - send technical bulletins for major changes
- [ ] **Prepare status page** - draft maintenance window announcements
- [ ] **Schedule stakeholder briefing** - demo new features to support/sales teams

**Requirements:** Section 3.28 (Customer Communication), FR-020 (Documentation)

---

## Phase 2: Build & Artifact Generation

### Automated Builds

- [ ] **Trigger CI pipeline** - via `scripts/ops/release_pipeline.sh --version <VERSION>`
- [ ] **Verify macOS DMG** - signed and notarized, spctl passes
- [ ] **Verify Windows installer** - signed MSI/EXE, authenticode valid
- [ ] **Check artifact checksums** - SHA256 hashes match, published in release notes
- [ ] **Upload to artifact repository** - S3 bucket with versioned paths
- [ ] **Tag Docker images** - backend services with git SHA and version tag

**Requirements:** Section 3.5 (Deployment Pipeline), NFR-003 (Code Signing)

**Scripts:**
```bash
# Dry run (local testing)
scripts/ops/release_pipeline.sh --version 0.1.0 --dry-run

# Full signed release
scripts/ops/release_pipeline.sh --version 0.1.0
```

### Artifact Validation

- [ ] **Download artifacts** - verify file integrity, no corruption
- [ ] **Test macOS install** - clean machine install, launch app, check for warnings
- [ ] **Test Windows install** - clean machine install, verify Explorer integration
- [ ] **Scan for vulnerabilities** - run Snyk/Trivy on binaries and Docker images
- [ ] **Review security scan results** - remediate or risk-accept with expiry dates

**Requirements:** Section 3.5 (Security Scanning), NFR-005 (Security)

---

## Phase 3: Quality Assurance & Testing

### Automated Testing

- [ ] **Unit tests** - 100% pass rate required (`flutter test`)
- [ ] **Integration tests** - API endpoints, database interactions, OT transforms
- [ ] **Golden image tests** - visual regression checks for UI components
- [ ] **Performance regression** - compare snapshot duration, event replay latency
- [ ] **Load testing** - collaboration session stress tests, 50+ concurrent users

**Requirements:** NFR-006 (Testing Coverage), Section 3.20 (Performance Benchmarks)

### Manual Testing (Staging Environment)

- [ ] **Smoke test core workflows** - import SVG, export PDF, real-time collaboration
- [ ] **Test feature flags** - toggle new features ON/OFF, verify graceful degradation
- [ ] **Cross-platform validation** - macOS 13+, Windows 10+, verify parity
- [ ] **Offline mode** - test local-first editing, snapshot replay without network
- [ ] **Disaster recovery drill** - restore from backup, verify data integrity

**Requirements:** FR-005 (Cross-Platform), NFR-008 (Offline Capability)

### Observability & Monitoring

- [ ] **Deploy to staging** - EKS cluster with canary rollout strategy
- [ ] **Verify CloudWatch dashboards** - KPIs visible, no missing metrics
- [ ] **Test PagerDuty alerts** - trigger synthetic failures, confirm escalation
- [ ] **Review runbook links** - ensure alerts reference correct blueprint anchors
- [ ] **Validate telemetry ingestion** - Mixpanel events, sampling presets correct

**Requirements:** Section 3.5 (Ops Dashboards), Section 3.7 (Runbooks)

---

## Phase 4: Deployment & Rollout

### Pre-Deployment

- [ ] **Freeze deployments** - no unrelated changes to production infrastructure
- [ ] **Announce maintenance window** - status page, RSS feeds, in-app toasts
- [ ] **Scale infrastructure** - increase EKS node count, warm Redis caches
- [ ] **Enable feature flag overrides** - prepare emergency kill switches
- [ ] **Brief on-call team** - share incident template, escalation contacts

**Requirements:** Section 3.28 (Communications), Section 3.7 (Incident Response)

### Production Deployment

- [ ] **Deploy backend services** - Argo CD rolling update, monitor canary metrics
- [ ] **Wait for canary validation** - 10% traffic for 30 minutes, no errors
- [ ] **Promote to full rollout** - 100% traffic, monitor queue depth and latency
- [ ] **Publish installers** - update download links, RSS feed, GitHub releases
- [ ] **Enable feature flags** - gradual rollout (10% → 50% → 100%)

**Requirements:** Section 3.5 (Feature Flags), FR-013 (Phased Rollouts)

**Feature Flag Rollout:**
```bash
# See docs/ops/runbooks/feature_flag_rollout.md for detailed steps
launchdarkly-cli flags update --environment prod --flag new_feature --rollout 10
# Monitor for 1 hour, then increase to 50%, then 100%
```

### Post-Deployment Validation

- [ ] **Smoke test production** - verify core workflows on live environment
- [ ] **Check error rates** - CloudWatch logs, no spike in exceptions
- [ ] **Validate telemetry** - Mixpanel events flowing, no data loss
- [ ] **Test collaboration** - real-time OT transforms, pub/sub fan-out
- [ ] **Verify installer downloads** - publicly accessible, checksums match

**Requirements:** NFR-007 (Reliability), Section 3.20 (KPI Tracking)

---

## Phase 5: Post-Release Monitoring

### 48-Hour Watch Period

- [ ] **Monitor KPIs continuously** - event replay rate, snapshot duration, OT latency
- [ ] **Track error budgets** - SLO compliance, alert fatigue indicators
- [ ] **Review customer feedback** - support tickets, community forum posts
- [ ] **Audit LaunchDarkly evaluations** - flag evaluation counts, toggle frequency
- [ ] **Check Terraform drift** - run `terraform plan`, ensure no manual changes

**Requirements:** Section 3.29 (Post-Release Checklist), NFR-009 (SLOs)

**Monitoring Commands:**
```bash
# CloudWatch query for error rates
aws cloudwatch get-metric-statistics --namespace WireTuner/API --metric-name ErrorRate

# Check Terraform state
cd infrastructure/terraform && terraform plan -detailed-exitcode
```

### Issue Triage & Hotfixes

- [ ] **Categorize incidents** - P0 (outage), P1 (degraded), P2 (minor)
- [ ] **Document rollback criteria** - error rate thresholds, user impact metrics
- [ ] **Prepare hotfix branch** - if critical issues found, branch from release tag
- [ ] **Communicate status** - update status page, in-app toasts for known issues
- [ ] **Schedule postmortem** - if incidents occurred, follow incident template

**Requirements:** Section 3.7 (Incident Playbooks), ADR-005 (Hotfix Process)

### Release Finalization

- [ ] **Merge release branch** - to `main` after 48-hour stability period
- [ ] **Archive release artifacts** - S3 retention policy, delete temp builds
- [ ] **Update telemetry baselines** - new performance benchmarks for next release
- [ ] **Close release ticket** - JIRA/Linear task with final status
- [ ] **Conduct retrospective** - what went well, what to improve

**Requirements:** Section 4 (Quality Gates), NFR-010 (Continuous Improvement)

---

## Emergency Rollback Procedure

**Trigger Criteria:**
- Error rate exceeds 5% for 10+ minutes
- P0 incident affecting > 50% of users
- Data corruption or loss detected
- Security vulnerability actively exploited

**Rollback Steps:**

1. **Disable feature flags** - set all new flags to OFF immediately
   ```bash
   launchdarkly-cli flags bulk-update --environment prod --state off
   ```

2. **Revert backend deployment** - Argo CD rollback to previous version
   ```bash
   argocd app rollback wiretuner-api --revision previous
   ```

3. **Notify stakeholders** - status page, PagerDuty, executive team

4. **Restore database** - if data corruption, promote latest clean snapshot
   ```bash
   # See docs/ops/runbooks/disaster_recovery.md
   ```

5. **Publish rollback installers** - revert download links to previous version

6. **Document incident** - use `docs/ops/runbooks/incident_template.md`

**Requirements:** Section 3.7 (Disaster Recovery), FR-018 (System Resilience)

---

## Approval Sign-Off

**Required Approvals Before Production Deployment:**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Release Manager | | | |
| QA Lead | | | |
| DevOps Lead | | | |
| Security Review | | | |
| Product Owner | | | |

**Notes:** Automation refuses release promotions if checklist items remain unchecked (Section 3.29).

---

## References

- **Architecture:** `docs/blueprint/04_Operational_Architecture.md` (Section 3.5, 3.7, 3.29)
- **Release Notes Template:** `docs/reference/release_notes.md`
- **Feature Flag Runbook:** `docs/ops/runbooks/feature_flag_rollout.md`
- **Incident Template:** `docs/ops/runbooks/incident_template.md`
- **CI Scripts:** `scripts/ops/release_pipeline.sh`, `scripts/ci/build_*`

**Revision History:**
- v1.0.0 (2024-01-15): Initial release checklist created for Task I5.T5
