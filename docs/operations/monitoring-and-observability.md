# Monitoring and Observability Runbook

Guide for operations and support teams to monitor DocumentOrganizer health, configure alerts, and debug issues in production.

**Timeline:** ~30 minutes setup, ~5 minutes daily checks  
**Required:** Access to deployment environment, log aggregation system, monitoring platform  
**Audience:** DevOps / Operations / Support Engineering

---

## Overview

DocumentOrganizer generates audit logs, categorization events, and privacy enforcement records that must be monitored to:
- Detect performance degradation or errors
- Comply with GDPR audit requirements
- Respond to data subject requests
- Identify categorization model drift
- Track usage patterns for capacity planning

---

## Part 1: Log Aggregation Setup

### Target Logs to Collect

1. **Application Logs** (from DocumentOrganizerService)
   - Ingestion errors (unsupported formats, OCR failures)
   - Categorization results (confidence scores, model updates)
   - Privacy policy enforcements (retention deletions, data exports)
   - Plugin execution (tool loads, failures)

2. **Audit Logs** (from AuditEvent)
   - All document operations (created, categorized, deleted)
   - User actions (search, filter, export)
   - System events (policy changes, model retrains)
   - Timestamps and actor information (for GDPR traceability)

3. **Security Logs**
   - Authentication attempts
   - Authorization failures
   - Encryption key rotations
   - Suspicious pattern detection

### Configuration by Platform

#### macOS (on-device logging)

**Option A: File-based logging**

1. Logs are written to: `~/Library/Logs/DocumentOrganizer/`
2. Configure logrotate (or equivalent):
   ```bash
   # /etc/logrotate.d/documentorganizer
   ~/Library/Logs/DocumentOrganizer/*.log {
       daily
       rotate 30
       compress
       delaycompress
       notifempty
   }
   ```

**Option B: System log integration (syslog)**

1. Update `Sources/Services/OrganizerService.swift` to use `os_log`:
   ```swift
   import os.log

   let auditLog = OSLog(subsystem: "com.apple.DocumentOrganizer.audit", category: "audit-events")
   
   os_log("Document processed: %{public}@", log: auditLog, type: .info, documentId)
   ```

2. View logs via Console.app or Terminal:
   ```bash
   log stream --predicate 'subsystem == "com.apple.DocumentOrganizer.audit"'
   ```

#### iOS/iPadOS (CloudKit-based)

1. Configure CloudKit logs to export to your observability platform
2. Set up CloudKit dashboard alerts in [Developer Account → Monitoring](https://developer.icloud.com/)
3. Log structure: `CKRecord` with fields:
   - `timestamp` (date created)
   - `auditEventType` (see AuditEvent enum)
   - `documentId` (string)
   - `result` (success/failure)
   - `errorCode` (if applicable)

#### Centralized (Datadog, Splunk, ELK Stack)

Reference implementation for Datadog:

```python
# scripts/logging_config.py - Add to project if using centralized logging
import logging
from datadog import initialize, api
from datadog_checks.base import AgentCheck

class DocumentOrganizerCheck(AgentCheck):
    def check(self, instance):
        """
        Send DocumentOrganizer audit events to Datadog.
        Scrapes audit/latest-report.json for metrics.
        """
        audit_report = self.read_json("audit/latest-report.json")
        
        self.gauge("documentorganizer.audit.delivery_score", audit_report["delivery"])
        self.gauge("documentorganizer.audit.compliance_score", audit_report["compliance"])
        
        self.event(
            title="DocumentOrganizer Audit Report",
            text=f"Delivery: {audit_report['delivery']}%, "
                 f"Quality: {audit_report['quality']}%, "
                 f"Compliance: {audit_report['compliance']}%",
            alert_type="info"
        )
```

---

## Part 2: Metrics to Monitor

### Key Performance Indicators (KPIs)

| Metric | Threshold | Alert | Runbook |
|--------|-----------|-------|---------|
| **Ingestion Success Rate** | < 95% | Critical | See "Diagnostic: Ingestion Failures" |
| **Categorization Confidence** | < 80% | Warning | See "Diagnostic: Low Confidence" |
| **Privacy Deletion Latency** | > 24h from request | Critical | See "Diagnostic: Retention Enforcement" |
| **Audit Log Write Success** | < 99% | Critical | See "Diagnostic: Audit Log Failures" |
| **Plugin Load Time** | > 5s | Warning | See "Diagnostic: Plugin Performance" |
| **Storage Used vs. Quota** | > 80% quota | Warning | See "Diagnostic: Storage Pressure" |
| **Data Subject Request Backlog** | > 10 pending | High | See "Diagnostic: DSR Processing" |

### Setup Alerting Rules

#### Datadog Example

```python
# alerts/ingestion-failures.json
{
  "title": "DocumentOrganizer: High Ingestion Failure Rate",
  "type": "metric alert",
  "query": "avg(last_5m):avg:documentorganizer.ingestion.failed{*} / avg:documentorganizer.ingestion.total{*} > 0.05",
  "notify_no_data": false,
  "thresholds": {
    "critical": 0.05,
    "warning": 0.02
  },
  "notification_presets": {
    "preset_name": "not_specified"
  },
  "notification": "@pagerduty-documentorganizer @slack-ops-critical"
}
```

---

## Part 3: Daily Health Checks

Run these checks once per day (automated or manual):

### Automated Daily Check Script

```bash
#!/bin/bash
# scripts/daily-health-check.sh

set -euo pipefail

# 1. Verify audit logs are being written
AUDIT_AGE=$(find ~/Library/Logs/DocumentOrganizer -name "audit.log" -ctime -1)
if [[ -z "$AUDIT_AGE" ]]; then
    echo "⚠️  WARNING: No audit logs written in last 24h"
    # Alert on-call
fi

# 2. Check audit report is current
REPORT_AGE=$(( $(date +%s) - $(stat -f%m audit/latest-report.json) ))
if [[ $REPORT_AGE -gt 86400 ]]; then
    echo "⚠️  WARNING: Audit report not updated in 24h (age: ${REPORT_AGE}s)"
fi

# 3. Verify compliance score hasn't regressed
COMPLIANCE_SCORE=$(jq '.compliance' audit/latest-report.json)
if (( $(echo "$COMPLIANCE_SCORE < 100" | bc -l) )); then
    echo "⚠️  WARNING: Compliance score dropped to ${COMPLIANCE_SCORE}%"
    # Investigate and escalate
fi

# 4. Check for critical errors in recent logs
ERRORS=$(grep -c "ERROR\|CRITICAL" ~/Library/Logs/DocumentOrganizer/audit.log || true)
if [[ $ERRORS -gt 10 ]]; then
    echo "⚠️  ALERT: ${ERRORS} critical errors in audit log"
fi

# 5. Verify plugin loading succeeds
if ! swift run DocumentOrganizer --verify-plugins > /dev/null 2>&1; then
    echo "⚠️  ALERT: Plugin verification failed"
fi

echo "✅ Health check complete at $(date)"
```

**Schedule:** Cron job to run daily at 6 AM:
```bash
0 6 * * * /Users/endaleconti/DocumentOrganizer/scripts/daily-health-check.sh >> /var/log/documentorganizer-healthcheck.log 2>&1
```

---

## Part 4: Incident Response Runbooks

### Diagnostic: Ingestion Failures

**Symptom:** Ingestion success rate < 95% or specific file types failing

**Steps:**

1. Check recent logs for ingestion errors:
   ```bash
   grep -i "ingestion\|error" ~/Library/Logs/DocumentOrganizer/audit.log | tail -20
   ```

2. Identify pattern (format, size, corruption):
   ```bash
   # Example: Large DOCX files failing on Apple Silicon
   grep "docx.*error\|size.*exceeded" ~/Library/Logs/DocumentOrganizer/audit.log
   ```

3. Check disk space and available resources:
   ```bash
   df -h /                              # Disk
   top -l 1 | head -20                 # CPU/Memory
   ```

4. If format-specific:
   - DOCX: Verify system has LibreOffice/unzip available (macOS). On iOS, fall back to plaintext extraction
   - PDF: Check if OCR is enabled; disable if CPU usage high
   - Images: Verify Vision.framework is available

5. Resolution:
   - **Transient**: Wait 15 minutes and monitor ingestion queue
   - **Format issue**: Document workaround in user guide or skip format
   - **Resource constrained**: Trigger scaling or reduce concurrent ingestions
   - **Persistent**: Escalate to engineering for investigation

**Escalation:** If > 1 hour unresolved, page on-call engineer

---

### Diagnostic: Low Confidence Categorization

**Symptom:** Categorization confidence < 80% or increasing number of manual corrections

**Steps:**

1. Check categorization model metadata:
   ```bash
   cat audit/latest-report.json | jq '.categorization_engine'
   ```

2. If model drift detected (confidence declining over time):
   - Check if document distribution has changed (new categories, formats, languages)
   - Review manual corrections to identify mislabeled documents
   - Trigger model retraining with corrected examples

3. If specific category has low confidence:
   - Examine keywords and rules for that category in `CategoryEngine.swift`
   - Add new keywords or refine rules based on recent documents
   - A/B test with new rule set on sample batch

4. If all categories low:
   - Check if model file is corrupted: `file audit/model.bin`
   - Restore from backup: `cp audit/model.bin.backup audit/model.bin`
   - Restart service and monitor

**Escalation:** If manual correction rate > 30%, escalate to ML/categorization team

---

### Diagnostic: Retention Enforcement Failing

**Symptom:** Documents not deleted after retention period expires

**Steps:**

1. Verify retention policy is loaded:
   ```bash
   grep "retention.*policy\|deletion\|enforce" ~/Library/Logs/DocumentOrganizer/audit.log | tail -10
   ```

2. Check document metadata for deletion markers:
   ```bash
   # Swift REPL or test script
   let doc = try DocumentRecord(id: ...) // Load suspect document
   print("Created: \(doc.createdAt)")
   print("Category: \(doc.category)")
   print("Retention Days: \(doc.privacyPolicy.retentionDays)")
   print("Should delete at: \(doc.createdAt.addingTimeInterval(TimeInterval(doc.privacyPolicy.retentionDays * 86400)))")
   ```

3. If deletion date passed but document not deleted:
   - Check if privacy enforcement is enabled in policy
   - Verify cron/scheduler is running (for periodic cleanup)
   - Check disk quota hasn't been exceeded (may block deletes)
   - Check file permissions: `ls -la ~/Library/ApplicationSupport/DocumentOrganizer`

4. Manual deletion if needed:
   ```bash
   # Only if confirmed safe (coordinate with compliance team)
   rm ~/Library/ApplicationSupport/DocumentOrganizer/documents/{documentId}
   # Log in audit trail: "Manual deletion due to [reason]"
   ```

**Escalation:** If > 5 documents overdue for deletion, page compliance officer immediately

---

### Diagnostic: Audit Log Failures

**Symptom:** Audit log not being written or audit report score < 100%

**Steps:**

1. Verify audit logs directory exists and is writable:
   ```bash
   ls -la ~/Library/Logs/DocumentOrganizer/
   touch ~/Library/Logs/DocumentOrganizer/test.tmp && rm ~/Library/Logs/DocumentOrganizer/test.tmp
   ```

2. Check system log for permission errors:
   ```bash
   log stream --level debug | grep -i "audit\|permission"
   ```

3. If permission issue:
   ```bash
   # Ensure app has write access
   chmod -R u+w ~/Library/Logs/DocumentOrganizer/
   chmod -R u+w ~/Library/ApplicationSupport/DocumentOrganizer/
   ```

4. If logs are being written but audit report not refreshing:
   ```bash
   python3 scripts/audit_score.py  # Manually recompute
   ```

5. If audit_score.py fails:
   - Check Python 3.11+ is available: `python3 --version`
   - Verify all verify_*.py scripts exist and are executable
   - Run individual script: `python3 scripts/verify_audit_logs.py` (hypothetical)

**Escalation:** If audit trail is compromised, escalate to security immediately

---

### Diagnostic: Plugin Performance Degradation

**Symptom:** Plugin load time > 5s or plugin failures increasing

**Steps:**

1. Profile plugin loading:
   ```bash
   # Add timing instrumentation to ToolPlugin.swift
   let start = Date()
   let result = try plugin.execute(input: ...)
   print("Plugin execution time: \(Date().timeIntervalSince(start))s")
   ```

2. Check for plugin updates that may have introduced slowness:
   - Review recent plugin version upgrades in `ROADMAP.md`
   - Check if plugin is making network calls (should be sandboxed/disabled)
   - Monitor memory usage while plugins load: `top -l 1 | grep DocumentOrganizer`

3. If specific plugin is slow:
   - Review plugin code for synchronous disk/network operations
   - Move I/O to background queues if possible
   - Consider unloading unused plugins

4. If all plugins are slow:
   - Check system resources (CPU, RAM, disk I/O)
   - Verify plugin cache is working: `ls -la ~/Library/Caches/DocumentOrganizer/plugins/`

**Escalation:** If plugin sandboxing is violated, revoke plugin immediately and alert security

---

## Part 5: Scheduled Maintenance

### Weekly

- Review ingestion error logs for patterns
- Check categorization confidence distribution
- Verify no documents are overdue for retention deletion
- Generate audit summary report and review with compliance team

### Monthly

- Retrain categorization model if drift detected (> 5% confidence drop)
- Review and rotate encryption keys if policy requires
- Capacity planning: Check storage growth rate
- Security review: Check for unusual access patterns in audit logs

### Quarterly

- Full security audit of privacy controls (run `python3 scripts/verify_privacy_controls.py`)
- Backup integrity verification (run `python3 scripts/verify_backup_restore.py`)
- Documentation review: Update runbooks based on incidents

---

## Part 6: Escalation Contacts

| Issue | Owner | Contact | Response |
|-------|-------|---------|----------|
| Critical deployment/infrastructure | DevOps | @on-call-devops or escalation@company.com | 15min |
| Audit log/compliance failure | Compliance Officer | @compliance or +1-555-XXXX | 30min |
| Data subject request backlog | Privacy Team | @privacy-team | 1hour |
| Plugin security issue | Security Team | security@company.com | 5min |
| High error rate / availability | Engineering Oncall | @on-call-engineer | 15min |

---

## Part 7: No-Data and Silence Alerts

Configure these to catch monitoring blind spots:

- **Audit log write failure:** Alert if no new audit events in 1 hour
- **Metrics upload failure:** Alert if metrics not sent to observability platform in 15 minutes
- **Monitoring agent health:** Alert if monitoring agent has not reported in 30 minutes

Example Datadog configuration:
```python
{
  "title": "DocumentOrganizer Monitoring Agent No Data",
  "type": "metric alert",
  "query": "avg(last_15m):avg:datadog.agent.check_status{service:documentorganizer} < 1",
  "no_data_timeframe": 15,
  "notify_no_data": true
}
```

---

## Appendix A: Log Format Reference

### Audit Event Log Structure

```json
{
  "timestamp": "2026-03-25T14:23:45Z",
  "eventType": "document_categorized",
  "documentId": "doc-abc123",
  "category": "invoice",
  "confidence": 0.94,
  "userId": "user-xyz789",
  "privacyLevel": "strict",
  "encryptionAlgorithm": "AES-256",
  "retentionDays": 365,
  "status": "success",
  "executionTimeMs": 245
}
```

### Available Event Types

- `document_ingested` — File uploaded and parsed
- `document_categorized` — Auto-categorization complete
- `category_corrected` — Human correction applied
- `privacy_policy_applied` — Retention/deletion rules enforced
- `plugin_loaded` — Tool executed
- `encryption_applied` — Document encrypted
- `data_subject_request_received` — GDPR request processed
- `retention_deletion_executed` — Document deleted per policy
- `backup_created` — Backup snapshot written
- `model_retrained` — ML model updated with new examples

---

## Appendix B: Health Check Dashboards

### Template: Grafana Dashboard

```json
{
  "panels": [
    {
      "title": "Ingestion Success Rate",
      "targets": [{"expr": "rate(documentorganizer_ingestion_success_total[5m]) / rate(documentorganizer_ingestion_total[5m])"}],
      "threshold": 0.95
    },
    {
      "title": "Categorization Confidence (avg)",
      "targets": [{"expr": "avg(documentorganizer_categorization_confidence)"}],
      "threshold": 0.80
    },
    {
      "title": "Retention Deletions in Queue",
      "targets": [{"expr": "count(documentorganizer_deletion_overdue_documents)"}],
      "threshold": 10
    },
    {
      "title": "Audit Log Write Latency",
      "targets": [{"expr": "histogram_quantile(0.99, documentorganizer_audit_write_duration_ms)"}],
      "threshold": 500
    }
  ]
}
```

---

## Next Steps After Setup

1. Configure log aggregation using platform of choice (Datadog, Splunk, etc.)
2. Set up alerting rules for KPIs listed in Part 2
3. Schedule daily health check script
4. Create runbook summaries and post in team wiki/Slack
5. Walk through incident response procedures with on-call team
6. Set up escalation rotations and verify contact information
