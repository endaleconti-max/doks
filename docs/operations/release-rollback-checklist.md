# Release and Rollback Checklist — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team

## Release Preconditions
- [ ] `swift test` passes in CI or local verification run.
- [ ] Latest audit score report generated (`audit/latest-report.json`).
- [ ] Quality baseline report is PASS (`audit/quality-baseline-report.json`).
- [ ] Data-subject-rights report is PASS (`audit/data-subject-rights-report.json`).
- [ ] Retention enforcement report is PASS (`audit/retention-enforcement-report.json`).
- [ ] Monitoring/alerting report is PASS (`audit/monitoring-alerting-report.json`).
- [ ] Security baseline report is PASS (`audit/security-baseline-report.json`).
- [ ] Backup/restore report is PASS (`audit/backup-restore-report.json`).
- [ ] Privacy preset defaults reviewed for intended deployment profile.
- [ ] Release notes include known limitations (e.g., DOCX extraction scope by platform).

## Release Procedure
1. Build and test:
   - `swift test`
2. Generate/refresh all verification artifacts in `audit/`.
3. Recompute score:
   - `.venv/bin/python scripts/audit_score.py`
4. Freeze release candidate commit hash.
5. Tag release and publish release notes.

## Rollback Triggers
- Repeated state-health failures in production-like validation.
- Security baseline regression.
- Backup/restore validation failure.
- Critical import/categorization regression.

## Rollback Procedure
1. Stop rollout and notify stakeholders.
2. Revert to previous known-good tag/commit.
3. Re-run `swift test` and core verification scripts.
4. Validate `state-health` and backup/restore workflow on rollback build.
5. Publish incident summary and remediation plan before reattempting release.

## Post-Release Validation
- [ ] Smoke test import/list/search/recategorize/delete.
- [ ] Verify audit export and state export commands.
- [ ] Verify `state-health` returns healthy.
- [ ] Confirm monitoring alerts are quiet under healthy state.
