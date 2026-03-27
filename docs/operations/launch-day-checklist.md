# Launch Day Checklist

Hour-by-hour deployment checklist for DocumentOrganizer production launch.

**Scheduled Date:** [INSERT DATE]  
**Deployment Owner:** [Name, Slack: @name]  
**Backup Owner:** [Name, Slack: @name]  
**On-Call Engineering:** [Name, on-call rotation]  
**Estimated Duration:** 4–6 hours  
**Rollback Window:** Within 4 hours, automatic rollback if error rate > 10%

---

## Pre-Launch Verification (T-24 Hours)

- [ ] All verifications passing: `python3 scripts/verify_all.py` returns PASS ✅ across all 9 checks
- [ ] Latest Swift build successful: `swift build -c release`
- [ ] Test suite passing: `swift test`
- [ ] Deployment guide reviewed by both deployment owner and backup owner
- [ ] Rollback procedure tested in staging (documented in [deployment-launch-guide.md](deployment-launch-guide.md#rollback-procedures))
- [ ] Emergency contact list verified and tested (See [monitoring-and-observability.md](monitoring-and-observability.md#part-6-escalation-contacts))
- [ ] Monitoring dashboards created and baseline metrics recorded
- [ ] Communication plan ready (Slack channels, email templates, status page)
- [ ] All team members who will execute launch have confirmed availability

---

## T-4 Hours: Pre-Launch Briefing

### 1. Deployment Owner: Review Launch Plan
- [ ] Open [deployment-launch-guide.md](deployment-launch-guide.md) on monitor 1
- [ ] Open [monitoring-and-observability.md](monitoring-and-observability.md#part-4-incident-response-runbooks) on monitor 2 for diagnostics
- [ ] Create Slack channel: `#documentorganizer-launch-live`
- [ ] Invite: On-call engineer, compliance officer, customer success lead, DevOps team
- [ ] Post launch timeline and escalation contacts in channel

### 2. All Team Members: Sync Call (15 min)
- [ ] Confirm everyone has read deployment guide
- [ ] Confirm current staging/production environment state
- [ ] Confirm DNS/routing is staged but not live (verify DNS still points to current version)
- [ ] Confirm database backups are current (< 1 hour old)
- [ ] Confirm rollback runbook is accessible and tested
- [ ] Confirm no concurrent maintenance windows or infrastructure changes planned

### 3. Health Check: Staging Environment
- [ ] Deploy to staging: Follow [deployment-launch-guide.md](deployment-launch-guide.md) platform-specific steps on staging environment
- [ ] Verify staging deployment successful: `curl https://staging-documentorganizer.company.internal/health` returns 200 OK
- [ ] Run smoke tests on staging:
  ```bash
  scripts/verify_all.py --package-path staging/
  ```
- [ ] If staging fails: Stop launch, diagnosis < 30 min, loop back to T-4 Hours
- [ ] If staging passes: ✅ Proceed to T-Launch

---

## T-0: Go/No-Go Decision

### Go/No-Go Criteria (All must be TRUE)

| Criterion | Status | Owner |
|-----------|--------|-------|
| All verifications passing (9/9 PASS) | ☐ PASS / ☐ FAIL | Deployment Owner |
| Staging deployment successful | ☐ YES / ☐ NO | Deployment Owner |
| Zero unresolved critical bugs | ☐ YES / ☐ NO | Engineering Lead |
| Monitoring dashboards operational | ☐ YES / ☐ NO | DevOps |
| Rollback procedure tested and ready | ☐ YES / ☐ NO | Backup Owner |
| Customer comms tested (email, status page) | ☐ YES / ☐ NO | Product Manager |
| All escalation contacts confirmed available | ☐ YES / ☐ NO | Deployment Owner |

### Decision
- **GO:** All 7 criteria are PASS/YES → Proceed to T-0 Deployment
- **NO-GO:** Any criterion is FAIL/NO → Hold launch, escalate, reschedule

Record the final decision and approver signatures in [release-signoff-record.md](release-signoff-record.md).

**Authorized by:** [Signature] at [Time]

---

## T-0 to T+30 Minutes: Deployment

### T-0:00 — Pre-Deployment Announcement
```
📢 POST TO #announcements (company-wide):
"DocumentOrganizer deployment beginning now. We anticipate 15-30 minute window. 
Services will be available the entire time. Minor latency may be experienced. 
Real-time status: #documentorganizer-launch-live"
```

- [ ] Post announcement to #announcements
- [ ] Post status page update: "Deployment in progress — no user impact expected"
- [ ] Log: "T-0:00 Deployment start" in #documentorganizer-launch-live

### T-0:05 — Begin Production Deployment
**Primary Operator:** Deployment Owner

Follow [deployment-launch-guide.md](deployment-launch-guide.md) platform-specific steps:

**macOS (AppKit Target):**
- [ ] Step 1: Build and package app bundle: `./scripts/package_macos_app.sh`
- [ ] Step 2: Configure notary profile once: `xcrun notarytool store-credentials "DocumentOrganizerNotary" --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>" --password "<APP_SPECIFIC_PASSWORD>"`
- [ ] Step 3: Export signing/notary env vars:
   `export SIGNING_IDENTITY="Developer ID Application: <Your Name> (<TEAM_ID>)"`
   `export NOTARY_PROFILE="DocumentOrganizerNotary"`
- [ ] Step 4: Notarize and staple: `./scripts/notarize_macos_app.sh`
- [ ] Step 5: Distribute via update channel (see deployment guide)
- [ ] Step 6: Monitor for client adoption (see monitoring dashboard)

**iOS/iPadOS (App Store):**
- [ ] Step 1: Build for App Store: `xcodebuild -scheme DocumentOrganizerApp archive`
- [ ] Step 2: Export: `xcodebuild -exportArchive -archivePath ... -exportOptionsPlist exportOptions.plist`
- [ ] Step 3: Upload to App Store Connect (via Transporter or xcodebuild)
- [ ] Step 4: Wait for review (expedited: 1-2 hours, or 24h standard)
- [ ] Step 5: Release to App Store (manual or phased rollout)
- [ ] Step 6: Monitor App Store reviews and crash reports in Xcode Organizer

**Web (if applicable):**
- [ ] Step 1: Build static assets: `swift build -c release`
- [ ] Step 2: Deploy to CDN: `push-release-to-cdn .build/release/`
- [ ] Step 3: Update DNS/load balancer (if DNS failover pattern)
- [ ] Step 4: Verify new deployment is live: Check version in public API headers

### T-0:20 — Deployment Complete (Estimated)

- [ ] Deployment owner confirms all steps completed without errors
- [ ] Log: "Deployment binary/app deployed to production" in #documentorganizer-launch-live
- [ ] Verify deployment using health check endpoint:
  ```bash
  curl -v https://documentorganizer.company.com/health
  # Expected: 200 OK, response includes version string matching release tag
  ```
- [ ] If health check fails → **Escalate to rollback immediately** (see "T+30 to T+45: Emergency Rollback")

---

## T+30 to T+60 Minutes: Post-Deployment Verification

### Health Checks (All must PASS)

1. **Application Health**
   - [ ] `/health` endpoint responds 200 OK
   - [ ] `/version` endpoint returns new version deployed
   - [ ] No critical errors in application logs (< 3 errors per minute)

2. **Core Functionality**
   - [ ] Can ingest a sample document (upload test.txt)
   - [ ] Categorization produces results within < 5 seconds
   - [ ] Can retrieve document (no 404 or auth errors)
   - [ ] Privacy policy is enforced (test data deletion after specified period)

3. **Data Integrity**
   - [ ] Audit logs are being written (check `/var/log/documentorganizer/audit.log`)
   - [ ] Sample document appears in database with correct metadata
   - [ ] User data (if migrated) is accessible and uncorrupted

4. **Performance**
   - [ ] Response times normal (p99 < 200ms for categorization)
   - [ ] CPU usage steady (< 50% of allocated)
   - [ ] Memory usage steady (no growth > 10MB/minute)
   - [ ] Disk I/O normal (no sustained 100% I/O wait)

### Verification Steps
```bash
# Run full verification suite on production
python3 scripts/verify_all.py --package-path . --output-json audit/launch-verification.json

# Check results
cat audit/launch-verification.json | jq '.results[] | select(.passed == false)'

# If results show PASS: ✅ Proceed to T+60
# If results show FAIL: 🔴 Escalate to incident response (see T+30 to T+45)
```

### Monitoring Dashboard Check
- [ ] Open monitoring dashboard (Datadog, Grafana, etc.)
- [ ] Verify metrics are flowing from production (not zero)
- [ ] Confirm ingestion success rate > 95%
- [ ] Confirm categorization events occurring
- [ ] Confirm no spike in error rates

---

## T+60 to T+120 Minutes: Stability Window

### Continuous Monitoring
- [ ] DevOps team watches monitoring dashboard (rotation: 30 min / person)
- [ ] Deployment owner available for immediate escalation
- [ ] On-call engineer standing by in #documentorganizer-launch-live
- [ ] Log spot checks every 15 minutes: "Metrics stable" or alert

### User Feedback Monitoring
- [ ] Customer success monitors incoming tickets for launch-related issues
- [ ] Check community forums / support channels for bug reports
- [ ] If issues found: Document in incident channel, do not silence alerts

### Success Criteria for T+120 Checkpoint
- [ ] Error rate < 1% (monitored dashboard)
- [ ] Response times normal (p99 < 200ms)
- [ ] Zero critical incidents reported
- If all pass: **Declare launch successful** ✅

---

## T+30 to T+45 Minutes: Emergency Rollback (If Needed)

**Trigger Conditions:**
- Error rate > 5% for > 2 consecutive minutes
- Any critical security issue detected
- Data corruption detected
- Health check failing
- > 10 support tickets about launch in < 5 minutes

### Immediate Actions
1. **Declare Incident**
   - [ ] Post in #documentorganizer-launch-live: "INCIDENT: Rolling back due to [reason]"
   - [ ] Assign incident commander (Deployment Owner or Backup Owner)
   - [ ] Open incident channel: #incident-documentorganizer-launch
   - [ ] Page on-call engineer immediately

2. **Begin Rollback** (See [deployment-launch-guide.md](deployment-launch-guide.md#rollback-procedures) for platform-specific steps)
   - [ ] Backup Owner initiates rollback procedures (read runbook on monitor 2)
   - [ ] Deployment Owner monitors rollback execution
   - [ ] Notify #announcements: "We detected an issue and are rolling back. Services will be briefly unavailable."

3. **Verify Rollback**
   - [ ] Health check passes on previous version
   - [ ] Audits and logs show rollback timestamp
   - [ ] Error rate drops to < 0.1%
   - [ ] All core functionality tests pass on rolled-back version

4. **Post-Mortem** (Within 24 hours)
   - [ ] Root cause analysis document created
   - [ ] Action items for fix identified
   - [ ] Retesting protocol established
   - [ ] Schedule retry launch for [date + 48 hours]

---

## T+120 Minutes: All-Clear & Communications

### Final Status Post
```
✅ POST TO #announcements:
"DocumentOrganizer launch complete. All systems nominally. 
Thank you to the team. Real-time status: https://status.company.com/documentorganizer"
```

- [ ] Post all-clear to #announcements
- [ ] Update status page: "Operational"
- [ ] Close #documentorganizer-launch-live (archive for reference)
- [ ] Log final update in #documentorganizer-launch-live: "Launch complete at [time]"

### Handoff to Operations
- [ ] Deployment owner provides daily monitoring checklist to on-call
- [ ] Point to [monitoring-and-observability.md](monitoring-and-observability.md)
- [ ] Confirm escalation contacts are in place
- [ ] Schedule post-launch retrospective for next week

### Documentation
- [ ] Deployment owner: Create summary in [deployment-launch-guide.md](deployment-launch-guide.md) with:
  - Actual deployment duration
  - Issues encountered and resolved
  - Lessons learned
  - Metrics on adoption (if applicable)

---

## Appendix A: Communication Templates

### Pre-Launch Email (T-24 Hours)

```
Subject: DocumentOrganizer Launch Tomorrow at [TIME] UTC

Team,

We are launching DocumentOrganizer to production tomorrow at [TIME] UTC.

Timeline:
- T-4h: Team briefing and staging verification
- T-0: Production deployment begins
- T+30m: Deployment complete, health checks start
- T+120m: All-clear if stable

No user-facing downtime is expected. Latency may increase < 5% during deployment.

Real-time updates: #documentorganizer-launch-live (Slack)

On-call team: See escalation contacts in #documentorganizer-launch-live

Please confirm you've read [deployment-launch-guide.md](deployment-launch-guide.md).

—Deployment Owner
```

### Status Page Update (T-0:00)

```
DEPLOYMENT IN PROGRESS

We are deploying DocumentOrganizer to production. Services remain available. 
Minor latency may be experienced. Estimated completion: [TIME].

Real-time updates on our Slack channel.
```

### All-Clear Post (T+120)

```
✅ DEPLOYMENT COMPLETE

DocumentOrganizer is now live in production. All health checks passed. 
Thank you to the team.

Next steps:
- Monitoring is active (https://status.company.com/documentorganizer)
- Post-launch retrospective: [Day/Date at Time]
- Questions: #documentorganizer-launch-live or escalate to @on-call-engineer
```

---

## Appendix B: Quick Reference Links

| Document | Purpose |
|----------|---------|
| [deployment-launch-guide.md](deployment-launch-guide.md) | Step-by-step platform-specific deployment |
| [monitoring-and-observability.md](monitoring-and-observability.md) | Post-launch observability and diagnostics |
| [github-setup-checklist.md](github-setup-checklist.md) | GitHub branch protection configuration |
| [CONTRIBUTING.md](../../CONTRIBUTING.md) | Developer workflows and release process |
| [incident-response-runbook.md](../compliance/incident-response-runbook.md) | GDPR and security incident response |

---

## Appendix C: Success Metrics (Post-Launch)

After launch, track these metrics for the first 30 days:

| Metric | Target | Action if Miss |
|--------|--------|-----------------|
| Error rate | < 1% | Investigate and patch |
| Document ingestion success rate | > 95% | Review format support |
| Categorization confidence | > 80% | Retrain model |
| API response time (p99) | < 200ms | Optimize top slow endpoints |
| Uptime | > 99.5% | Investigate outages |
| Customer satisfaction | ≥ 4.5/5 | Address feedback |
| Security incidents | 0 | Implement fixes immediately |

---

## Sign-Off

**Deployment Owner:** _________________ Date: _________  
**Backup Owner:** _________________ Date: _________  
**On-Call Engineer:** _________________ Date: _________  
**Product Manager:** _________________ Date: _________  

*By signing, all parties confirm they have reviewed the deployment plan, understand their roles, and are available for the launch window.*
