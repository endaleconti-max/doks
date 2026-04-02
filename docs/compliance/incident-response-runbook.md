# Incident Response and Breach Notification Runbook — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team | GDPR Article 33 & 34

---

## 1. Scope
This runbook covers:
- Personal data breach detection and containment for the Documents App.
- GDPR-mandated breach notification obligations (Art. 33 — supervisory authority; Art. 34 — data subject).
- Recovery procedures for the encrypted state file.

Incident handling is aligned with data subject rights obligations so that post-incident actions preserve access, erasure, and portability guarantees.

---

## 2. Breach Classification

| Severity | Definition | Examples |
|----------|-----------|---------|
| **P1 — Critical** | Confirmed exfiltration or unauthorised access to unencrypted personal data | State file decrypted and copied by malicious process; export file sent to unintended recipient |
| **P2 — High** | Potential exposure; data at risk but not confirmed exfiltrated | Encryption key file (`audit/organizer-state.key`) accessed by another user or process on the same machine |
| **P3 — Medium** | Integrity or availability loss; no confirmed exposure | State file corrupted; retention enforcement deletes wrong documents |
| **P4 — Low** | Minor anomaly; no personal data impact | Audit log entry missing; unexpected app crash with no state change |

---

## 3. Detection Sources

| Source | Description |
|--------|-------------|
| User reports | User notices unexpected document deletions, category changes, or export file in unexpected location |
| `state-health` command | Reports key file missing or state file inconsistency |
| OS-level audit logs | File access logs on macOS (`/var/log/`, Unified Logging) show unexpected access to `audit/organizer-state.*` |
| Key file size anomaly | `state-health` reports key file length ≠ 32 bytes, indicating tampering |

---

## 4. Response Procedures

### P1 — Critical: Confirmed Breach

**Target containment window: 1 hour**

1. **Contain**: Remove the affected machine from network if applicable. Revoke any cloud sync that includes the `audit/` directory.
2. **Preserve evidence**: Copy `audit/organizer-state.json`, `audit/organizer-state.key`, and any export files to a secure, isolated location. Do not modify.
3. **Assess scope**: Identify which documents were stored. Do any contain special-category personal data (`medical`, `identification` category)? Query with `.build/debug/DocumentOrganizer list`.
4. **Erase exposed state**: Run `.build/debug/DocumentOrganizer enforce-retention` with `strict` preset, then manually delete `audit/organizer-state.json` and `audit/organizer-state.key`.
5. **Notify** (see Section 5).
6. **Recover**: Re-import only documents confirmed necessary; generate new encryption key on first import.

---

### P2 — High: Potential Exposure

**Target assessment window: 4 hours**

1. Run `state-health` to confirm key integrity.
2. Check OS audit logs for access to `audit/organizer-state.*` by unexpected processes.
3. If compromise confirmed: escalate to P1.
4. If not confirmed: document the anomaly, increase monitoring frequency.

---

### P3 — Medium: Integrity / Availability Loss

1. Run `state-health` to diagnose the issue.
2. Restore state from most recent `export-state` backup if available.
3. If no backup: acknowledge data loss; re-import documents from original sources.
4. File a post-incident report.

---

### P4 — Low: Minor Anomaly

1. Note in project issue tracker.
2. Investigate root cause; apply fix in next release.

---

## 5. Notification Obligations (GDPR Art. 33 & 34)

### 5.1 Supervisory Authority (Art. 33)
- **Threshold**: A personal data breach that is likely to result in a risk to the rights and freedoms of natural persons.
- **Deadline**: 72 hours from becoming aware of the breach.
- **Content required**: Nature of the breach; categories and approximate number of data subjects and records; likely consequences; measures taken or proposed.
- **How**: Via the national DPA online portal (e.g. in Germany: BfDI; in Ireland: DPC).
- **Note**: For personal use with no broader impact, formal notification may not be required, but it is best practice to document the decision not to notify.

### 5.2 Data Subjects (Art. 34)
- **Threshold**: Breach is likely to result in **high risk** to individuals (e.g. special-category data was accessed).
- **Deadline**: Without undue delay.
- **Content**: Plain-language description of the breach; name and contact of DPO or contact point; likely consequences; remedial steps taken; steps the individual can take to protect themselves.

---

## 6. Post-Incident Review
Within 5 business days of containment:
1. Complete a written root-cause analysis.
2. Update this runbook if the procedure was inadequate.
3. Update the risk register (`docs/risk-register.md`) with lessons learned.
4. Check whether any risk entries (R-01 through R-12) need mitigation changes.

---

## 7. Key Contacts

| Role | Responsibility |
|------|---------------|
| Product Owner | Initial breach coordinator |
| Legal / DPO (if designated) | Notification decisions |
| Engineering Lead | Technical containment and recovery |

---

## 8. Test Schedule
This runbook should be exercised with a tabletop simulation at least once before production launch (Phase 6 acceptance criterion).
