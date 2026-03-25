# Risk Register — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team

## 1. Purpose
Identify and track privacy, accuracy, scalability, and operational risks for the Documents App so that mitigations are planned before production use.

---

## 2. Risk Matrix

| ID | Category | Risk Description | Likelihood | Impact | Risk Level | Mitigation | Status |
|----|----------|-----------------|-----------|--------|------------|------------|--------|
| R-01 | Privacy | Encrypted state key lost → all stored documents permanently inaccessible | Low | Critical | High | Document key backup procedure; `state-health` diagnostic; never store key in plaintext inside the state file | Active |
| R-02 | Privacy | User imports a document containing special-category personal data (health, biometric) without awareness | Medium | High | High | Warn user on import if classifier assigns `medical` or `identification` category; display data minimization notice; strict preset enforces 90-day deletion | Active |
| R-03 | Privacy | Privacy state file exported with plaintext portability export and shared insecurely | Medium | High | High | `export-state` command produces plaintext JSON; document that export files must be treated as sensitive and deleted after transfer | Active |
| R-04 | Accuracy | Categorization model is keyword-only; novel document types silently fall to `general` | High | Medium | High | Persist correction feedback loop; expose confidence score; plan ML upgrade path in Phase 3 OCR/ML milestone | Active |
| R-05 | Accuracy | Duplicate detection based on content hash; hash collision risk (SHA-256) | Very Low | Medium | Low | SHA-256 collision probability is negligible; acceptable residual risk | Accepted |
| R-06 | Scalability | In-memory document store loaded fully at startup; performance degrades at high document counts | Medium | Medium | Medium | Benchmark at 10k documents; plan paged/indexed storage before Phase 6 | Planned |
| R-07 | Scalability | AES-GCM encryption/decryption of full state JSON on every save; latency grows with document count | Medium | Low | Low | Acceptable for initial single-user scope; revisit with chunked/streamed encryption in Phase 6 | Planned |
| R-08 | Compliance | Legal basis mapping incomplete before production data ingests personal data | High | Critical | Critical | Block production release until Phase 1 DPI and RoPA are approved; verified by `verify_data_subject_rights.py` | Active |
| R-09 | Compliance | GDPR breach notification window (72h) missed due to no incident response runbook | Medium | High | High | Incident response runbook created and approved before production; see `docs/compliance/incident-response-runbook.md` | Active |
| R-10 | Operations | No backup/restore verified; state file corruption would cause data loss | Medium | High | High | Phase 6 milestone: backup and restore validated; interim: export-state as manual backup | Planned |
| R-11 | Security | Binary is not code-signed or notarised; macOS Gatekeeper blocks on first run for end users | High | Medium | Medium | Add code signing and notarisation as Phase 6 release checklist item | Planned |
| R-12 | Security | Command injection not possible (args are file paths only, no shell eval); confirmed by code review | N/A | N/A | Accepted | N/A | Accepted |

---

## 3. Risk Levels
- **Critical**: Address before any production use
- **High**: Address before general availability
- **Medium**: Address before scaling beyond pilot
- **Low / Accepted**: Documented residual risk; monitored

---

## 4. Review Cadence
Risk register is reviewed at the end of each phase gate and updated when new features change threat surface.
