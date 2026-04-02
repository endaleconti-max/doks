<div align="right">

**Repository:** [fill]  
**Environment:** Production / Staging / Other: [fill]  
**Date:** [YYYY-MM-DD]  
**Completed by:** [name]  
**Reviewed by:** [name]

</div>

# GitHub Setup Signoff

This document records completion evidence for manual repository governance setup.

Use this together with [github-setup-checklist.md](github-setup-checklist.md).

## Evidence Links

- Branch protection rules screenshot: [link]
- Required status checks screenshot: [link]
- CODEOWNERS reviewer requirement screenshot: [link]
- Test PR link proving merge gate behavior: [link]
- Actions run link showing ci-verification pass: [link]

## Step Signoff

| Step | Requirement | Status | Evidence | Notes |
|---|---|---|---|---|
| 1 | Product team exists in org | PASS / FAIL / N-A | [link] | |
| 2 | Branch rule exists for main | PASS / FAIL | [link] | |
| 3 | Require PR review enabled (1+) | PASS / FAIL | [link] | |
| 4 | Require Code Owner review enabled | PASS / FAIL | [link] | |
| 5 | Require status checks enabled | PASS / FAIL | [link] | |
| 6 | Required check includes ci-verification / verification | PASS / FAIL | [link] | |
| 7 | Dismiss stale reviews enabled | PASS / FAIL | [link] | |
| 8 | Include administrators enabled | PASS / FAIL | [link] | |
| 9 | product-team has Maintain/Admin repo access | PASS / FAIL | [link] | |
| 10 | Test PR blocked before checks/review complete | PASS / FAIL | [link] | |
| 11 | Test PR merge enabled only after checks + review | PASS / FAIL | [link] | |
| 12 | Emergency merge procedure documented | PASS / FAIL / N-A | [link] | |

## Final Decision

- Governance setup complete: YES / NO
- Open items:
  - [item]
  - [item]
- Target date to close open items: [YYYY-MM-DD]

## Approvals

- DevOps owner signoff: [name] / [date]
- Engineering lead signoff: [name] / [date]
- Compliance signoff: [name] / [date]

## Follow-up

After signoff, run:

```bash
python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json
python3 scripts/audit_score.py --input audit/status.json --output-json audit/latest-report.json
python3 scripts/generate_launch_readiness_report.py
```

Then archive artifacts in your release ticket.