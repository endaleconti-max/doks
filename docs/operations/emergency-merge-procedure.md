# Emergency Merge Procedure

This procedure defines controlled branch-protection override only for critical production incidents.

## Purpose

Allow rapid mitigation when production impact is severe and waiting for normal PR flow would materially increase harm.

## Allowed Conditions

Emergency merge is allowed only when at least one condition is true:

- Sev-1 production outage
- Active security incident requiring immediate mitigation
- Data integrity risk with ongoing customer impact

Non-emergency feature work is never allowed via this procedure.

## Required Approvals

Both approvals are mandatory before merge:

1. Incident commander approval
2. One code owner approval

Record both approvers in the incident channel and incident ticket.

## Authorized Roles

- Incident commander: [fill role or names]
- Code owners: [fill team]
- Executor of emergency merge: [fill role or names]

## Procedure

1. Declare incident in incident channel and create incident ticket.
2. Post impact summary, mitigation plan, and rollback plan.
3. Capture explicit approvals from incident commander and one code owner.
4. Apply minimal patch for mitigation only.
5. Run targeted verification locally:
   - swift build
   - swift test
   - python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json
6. Merge using approved override path.
7. Announce deployment and monitor for 30 minutes minimum.
8. If mitigation fails, execute rollback from deployment runbook.

## Required Audit Trail

Record all of the following:

- Incident ID
- Approver names and timestamps
- Commit hash(es)
- Reason normal merge path was bypassed
- Verification outputs
- Rollback plan and result

## Post-Incident Requirements

Within 24 hours:

1. Open corrective PR to align emergency changes with normal review path.
2. Complete post-mortem including prevention actions.
3. Review whether branch rules or observability should be improved.

## Template

Copy and fill this in incident channel:

```text
Emergency merge request
Incident: [ID]
Severity: [Sev-1 / Security / Data Integrity]
Impact: [short summary]
Mitigation commit: [hash]
Rollback commit/plan: [hash or plan]
Approvals:
- Incident commander: [name @ time]
- Code owner: [name @ time]
Verification:
- swift build: PASS/FAIL
- swift test: PASS/FAIL
- verify_all.py: PASS/FAIL
```
