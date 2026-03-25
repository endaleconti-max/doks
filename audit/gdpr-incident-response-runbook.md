# Incident Response Runbook Draft

Date: 2026-03-25
Status: Draft

## Scope
Incidents affecting confidentiality, integrity, or availability of local document data and audit logs.

## Severity Levels
- SEV-1: Data exposure or irreversible data loss.
- SEV-2: Integrity issue affecting categorization or audit accuracy.
- SEV-3: Local service degradation without data impact.

## Response Steps
1. Detect and triage.
2. Contain impact (disable tool permissions if needed, isolate affected files).
3. Assess affected records using audit timeline and state snapshots.
4. Recover (restore from backup when available, validate integrity).
5. Document timeline, impact, and remediation actions.
6. Capture follow-up tasks for prevention.

## Notification Guidance
- Local-first mode has no default external processor notifications.
- If integrated with external services in future, add notification and legal escalation matrix.

## Approval
Pending formal review and sign-off.
