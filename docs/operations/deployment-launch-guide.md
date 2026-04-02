# Deployment and Launch Guide — Documents App

Version: 1.0 | Date: 2026-03-25 | Owner: Product & Operations Team

## Overview

This guide provides step-by-step procedures for deploying Documents App from the launch-ready codebase into production environments and managing the go-live process.

## Pre-Launch Validation (48 hours before)

### 1. Verify All Audit Metrics

Run the full verification suite on the release candidate commit:

```bash
git checkout <release-commit-hash>
python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json
python3 scripts/audit_score.py --output-json audit/latest-report.json
```

**Expected outcome**: All 9 verifiers report PASS; audit scores are at 100.00% across Delivery, Quality, and Compliance.

**Gate**: If any check fails, roll back to previous stable commit and investigate. Do not proceed to launch.

### 2. Validate Encryption and Key Management

```bash
swift run DocumentOrganizer state-health
```

**Expected output**: "State health: healthy" with no warnings.

**Gate**: If key file is missing or corrupted, restore from secure backup before proceeding.

### 3. Review Audit Trail

Export and review the last 100 audit events:

```bash
swift run DocumentOrganizer audit 100 > audit-timeline-review.txt
```

**Gate**: Spot-check for unexpected `deleted` or `permissionChanged` events. If suspicious activity is found, investigate before launch.

### 4. Confirm Privacy Presets

Verify the default privacy preset is appropriate for target deployment:

```bash
swift run DocumentOrganizer privacy-preset
```

**Expected**: Balanced or Strict (not Permissive in production).

**Gate**: If Permissive is default, change PrivacyConfiguration default in Sources/Privacy/PrivacyPolicy.swift.

### 5. Documentation Review

- [ ] README.md is up to date with version and features
- [ ] CONTRIBUTING.md accurately reflects branch protection rules
- [ ] docs/compliance/ has all 4 GDPR artifacts (DPI, RoPA, LBM, IRR)
- [ ] docs/operations/ has release-rollback-checklist and this deployment guide
- [ ] ROADMAP.md shows all 7 phases at 100%

### 6. Stakeholder Sign-Off

Obtain approvals from:
- [ ] Product Lead: Feature set and UX readiness
- [ ] Security/Compliance: Privacy controls and GDPR alignment
- [ ] Operations: Monitoring and backup procedures in place
- [ ] Legal: GDPR documentation and incident response runbook reviewed

## Pre-Launch Preparation (24 hours before)

### 1. Build Release Artifacts

```bash
swift build --configuration release
```

Store the `.build/release/DocumentOrganizer` binary in a secure location (e.g., internal artifact repository).

### 2. Tag Release in Git

```bash
git tag -a v0.3.0 -m "Release 0.3.0 - Delivery 100% Quality 100% Compliance 100%"
git push origin v0.3.0
```

### 3. Create Release Notes

Template:

```
# DocumentOrganizer v0.3.0

**Release Date**: 2026-03-25  
**Status**: Launch-ready  
**Audit Score**: Delivery 100% | Quality 100% | Compliance 100%

## What's New
- Privacy-first document ingestion and categorization
- GDPR-compliant data-subject-rights workflows
- Extensible tool framework with 2 pilot plugins
- Comprehensive monitoring, alerting, and backup
- Production operations controls (retention, encryption, audit)

## Verification
- Swift test suite: 6/6 passing
- Full verification suite: 9/9 verifiers passing
- All 7 roadmap phases complete
- Zero critical gaps identified

## Known Limitations
- iOS/iPadOS native targets in development (Phase 2 post-launch)
- DOCX extraction on iOS pending (macOS only currently)
- Keyword-based categorization (ML model planned for Phase 3)

## Installation & Quick Start
See [README.md](../README.md#run-locally)

## Support & Issues
Report bugs or feature requests via GitHub Issues referencing this release tag.
```

### 4. Prepare Rollback Plan

- [ ] Tag the previous production version (if upgrading from existing deployment)
- [ ] Document rollback steps in case critical issue is discovered (see Rollback section below)
- [ ] Ensure restore points/backups are available

### 5. Notify Stakeholders

Send launch notification to:
- [ ] Product team
- [ ] Support team (if applicable)
- [ ] Security & compliance team
- [ ] Any end-user groups (beta testers, pilot customers)

Template message:

```
Subject: DocumentOrganizer v0.3.0 — Launch Window Confirmation

We are launching DocumentOrganizer v0.3.0 on [DATE] at [TIME] [TIMEZONE].

Launch window: [TIME] - [TIME] (2 hours)

What to expect:
- Service will be unavailable during deployment (~15 minutes)
- All state will be preserved
- Users must re-authenticate on first use after update

Rollback plan: If critical issues arise, we have a rollback procedure in place. 
ETA for resolution: [TIME]

Questions? Contact [ops-contact]
```

## Go-Live Procedure (Day of Launch)

### 1. Pre-Flight Checks (30 minutes before)

Run one final verification:

```bash
swift build --configuration release
swift test
```

Confirm:
- [ ] Build completes without warnings
- [ ] All 6 tests pass
- [ ] No new errors in compilation

### 2. Announce Maintenance Window

Post a status notification to users (if applicable):

```
Maintenance Window: [DATE] [TIME] - [TIME]

We are deploying DocumentOrganizer v0.3.0 with new privacy controls and 
monitoring capabilities. The service will be unavailable for ~15 minutes.

We appreciate your patience.
```

### 3. Deploy Release Binary

1. Stop any running DocumentOrganizer instances
2. Backup current state files:
   ```bash
   cp -r audit/organizer-state.* backup/pre-launch-state/
   ```
3. Deploy the release binary to target environment
4. Start the service with the release binary
5. Confirm service is responsive:
   ```bash
   swift run DocumentOrganizer list
   ```

### 4. Run Smoke Tests

Execute basic workflows to confirm functionality:

```bash
# Test import
echo "Invoice #001\nTotal: 100 EUR" > /tmp/test-invoice.txt
swift run DocumentOrganizer import /tmp/test-invoice.txt

# Test list and search
swift run DocumentOrganizer list
swift run DocumentOrganizer search invoice

# Test health check
swift run DocumentOrganizer state-health
```

**Gate**: If any smoke test fails, proceed to Rollback section.

### 5. Clear Maintenance Notification

Post a status update:

```
✅ Maintenance Complete

DocumentOrganizer v0.3.0 is now live!

Improvements:
- Enhanced privacy controls (strict/balanced/permissive presets)
- Comprehensive audit logging
- Data-subject-rights workflows (access, portability, erasure)
- Automatic retention enforcement
- Monitoring and alerting

Thank you for your patience.
```

## Post-Launch Monitoring (First 24 hours)

### 1. Monitor Key Signals

Every 15 minutes for the first 4 hours, then every hour for 24 hours:

```bash
# Health check
swift run DocumentOrganizer state-health

# Audit event count (should increase slowly if features are used)
swift run DocumentOrganizer audit 10

# Export latest metrics snapshot
python3 scripts/audit_score.py --output-json audit/latest-report.json
```

**Alert thresholds**:
- State health changes to "attention-needed" → investigate immediately
- Import/list/search commands fail consistently → invoke rollback
- Audit events show unexpected `deleted` records → check retention policy

### 2. Monitor System Resources

- CPU usage: < 50% during normal operation
- Memory: < 1 GB for typical document counts (< 10k docs)
- Disk: Check that state file is encrypted (size will be larger than plaintext)

### 3. Check Backup Integrity

Verify that automated backups (if configured) are being created:

```bash
ls -lh backup/ | tail -5
```

### 4. Engage Support Team

Notify support:
- [ ] New features available to users
- [ ] Point to CONTRIBUTING.md for feedback process
- [ ] Review common issues and resolutions

## Rollback Procedure (If Critical Issue Found)

### Immediate Actions (< 5 minutes)

1. **Stop the service**:
   ```bash
   # Kill any running DocumentOrganizer processes
   pkill DocumentOrganizer
   ```

2. **Assess the issue**:
   - Is state corrupted? Check `state-health`
   - Are imports failing? Check file permissions
   - Are users unable to access data? Check encryption key

3. **Notify stakeholders**:
   ```
   ⚠️ Rollback Initiated
   
   We have identified a critical issue with v0.3.0 and are rolling back to [previous version].
   
   Service will return within ~30 minutes.
   ```

### Rollback Steps (5-15 minutes)

**Option 1: Restore previous version (state preserved)**

```bash
# Restore the previous release binary
cp releases/v0.2.9/DocumentOrganizer .build/release/DocumentOrganizer

# Start from existing state (unchanged)
swift run DocumentOrganizer list

# Verify state is readable
swift run DocumentOrganizer state-health
```

**Option 2: Full state reset (if state corruption suspected)**

```bash
# Backup corrupted state
mv audit/organizer-state.json audit/organizer-state.json.corrupted
mv audit/organizer-state.key audit/organizer-state.key.corrupted

# Restore from backup
cp backup/pre-launch-state/organizer-state.* audit/

# Verify restore
swift run DocumentOrganizer state-health
swift run DocumentOrganizer list
```

### Post-Rollback

1. **Announce rollback**:
   ```
   ✅ Rollback Complete — Service Restored
   
   We have reverted to v0.2.9 while we address the issue found in v0.3.0.
   
   Your data is safe and unaffected. Our team is investigating the root cause.
   
   Next update will include a fix. We appreciate your patience.
   ```

2. **Investigate root cause**:
   - Review logs: `swift run DocumentOrganizer audit 100`
   - Run diagnostics:
     ```bash
     swift run DocumentOrganizer state-health
     python3 scripts/verify_all.py --package-path . --output-json audit/post-rollback-diagnostics.json
     ```
   - Document findings in post-incident report

3. **Fix and re-test**:
   - Create a fix branch and implement the correction
   - Run full test suite and verification
   - Repeat pre-launch validation with fixed version
   - Schedule a new launch window (minimum 24 hours later)

4. **Post-Incident Review** (within 48 hours):
   - Conduct blameless post-mortem
   - Update [docs/risk-register.md](../risk-register.md) with lessons learned
   - Enhance monitoring or testing to prevent recurrence
   - Document in [docs/compliance/incident-response-runbook.md](../compliance/incident-response-runbook.md)

## Success Criteria

Launch is considered successful when all of the following are true:

- [ ] All pre-launch validation checks passed (100% audit scores)
- [ ] Service deployed and responding to commands
- [ ] Smoke tests passed (import, list, search, state-health)
- [ ] No critical alerts or errors in logs during first 24 hours
- [ ] Backup integration confirmed working
- [ ] Stakeholder notification sent to users
- [ ] Post-launch monitoring active and alerting configured

## Appendix: Emergency Contacts

| Role | Contact | On-Call | Escalation |
|------|---------|---------|-----------|
| Product Lead | [name] | [phone] | [manager] |
| Operations Lead | [name] | [phone] | [manager] |
| Security Lead | [name] | [phone] | [manager] |

## Appendix: Useful Commands

**Verify environment is ready**:
```bash
swift --version
python3 --version
cd /path/to/Documents\ App && swift build && swift test && python3 scripts/verify_all.py
```

**Full deployment simulation (test run)**:
```bash
# In a separate temp directory, clone & deploy
git clone /path/to/Documents\ App /tmp/deployment-test
cd /tmp/deployment-test
swift build --configuration release
swift test
python3 scripts/verify_all.py
swift run DocumentOrganizer state-health
```

**Monitor a deployment**:
```bash
# Every 15 minutes for 4 hours
while true; do
  date
  swift run DocumentOrganizer state-health | head -1
  sleep 900
done
```

**Generate post-launch report**:
```bash
# Collect all audit artifacts
tar czf audit-report-2026-03-25.tar.gz audit/*.json
# Upload to secure location
```
