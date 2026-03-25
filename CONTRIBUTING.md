# Contributing to Documents App

## Overview

This document outlines the contribution process, CI/CD verification gates, and branch protection rules that ensure code quality and compliance before production deployment.

## Development Workflow

1. **Create a feature branch** from `main`
2. **Implement and test locally** using provided VS Code tasks or CLI commands
3. **Run local validation** to ensure compliance before pushing
4. **Push to GitHub** and open a pull request
5. **CI verification** runs automatically and gates the PR
6. **Review and merge** only after all CI checks pass and code review completes

## Local Validation

### One-Command Full Suite (Recommended)

```bash
python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json
```

This consolidates all 9 verification checks and produces a pass/fail result in **audit/full-verification-summary.json**.

### Build and Test

```bash
swift build
swift test
```

### Individual Verification Scripts

Run any single verifier directly:

```bash
# Data subject rights workflows (access, portability, erasure)
python3 scripts/verify_data_subject_rights.py --package-path . --output-json audit/data-subject-rights-report.json

# Retention and deletion enforcement
python3 scripts/verify_retention_enforcement.py --package-path . --output-json audit/retention-enforcement-report.json

# GDPR documentation completeness
python3 scripts/verify_gdpr_documentation.py --package-path . --output-json audit/gdpr-documentation-report.json

# Privacy control implementation
python3 scripts/verify_privacy_controls.py --package-path . --output-json audit/privacy-controls-report.json

# Quality baseline metrics
python3 scripts/verify_quality_baseline.py --package-path . --output-json audit/quality-baseline-report.json

# Security baseline (encryption, permissions, gates)
python3 scripts/verify_security_baseline.py --package-path . --output-json audit/security-baseline-report.json

# Backup and disaster recovery
python3 scripts/verify_backup_restore.py --package-path . --output-json audit/backup-restore-report.json

# Monitoring and alerting
python3 scripts/verify_monitoring_alerting.py --package-path . --output-json audit/monitoring-alerting-report.json

# Release and rollback checklist
python3 scripts/verify_release_checklist.py --package-path . --output-json audit/release-checklist-report.json
```

### VS Code Tasks

Run from the Command Palette (`Cmd+Shift+P` → Run Task):
- **Run DocumentOrganizer Samples** – Basic smoke test
- **Run Full Verification Suite** – Complete CI simulation

## CI/CD Pipeline

GitHub Actions workflow: [.github/workflows/ci-verification.yml](.github/workflows/ci-verification.yml)

Runs on:
- Every push to `main` or `master`
- Every pull request
- Manual trigger via workflow_dispatch

### Pipeline Steps

1. **Checkout** – Clone the repository
2. **Set up Swift 6.2** – Swift build environment
3. **Set up Python 3.11** – Verification script environment
4. **Build** – `swift build`
5. **Test** – `swift test`
6. **Full Verification** – `python3 scripts/verify_all.py`
7. **Audit Score** – `python3 scripts/audit_score.py`
8. **Upload Artifacts** – All `audit/*.json` files available for download

### Status Checks

The following GitHub status check is enforced by branch protection:
- **verify (macos-14)** – Must pass before merge is allowed

## Branch Protection Rules

### Recommended Configuration

To prevent unverified code from reaching production, configure branch protection on `main`:

**Settings → Branches → Branch protection rules → Add rule**

#### Required Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Branch name pattern | `main` | Protect the primary production branch |
| Require a pull request before merging | ✅ | Enforce code review |
| Require status checks to pass | ✅ | Gate on CI verification |
| **Status checks that must pass** | `verify (macos-14)` | Require all tests and verifications |
| Require branches to be up to date before merging | ✅ | Prevent stale branch merges |
| Require code reviews before merging | ✅ | Enforce at least 1 approval |
| Required number of reviewers | 1 | Minimum review count |
| Dismiss stale pull request approvals when new commits are pushed | ✅ | Reviews must be current |
| Require review from Code Owners | ✅ | CODEOWNERS file controls approval |
| Restrict who can push to matching branches | ✅ | Only authorized developers |

### Code Owners

Create a `.github/CODEOWNERS` file to control PR review requirements:

```
# All files require approval from core team
* @endaleconti

# Compliance and operations require extra scrutiny
docs/compliance/** @endaleconti
docs/operations/** @endaleconti

# Verification scripts require review
scripts/verify_*.py @endaleconti
```

## Audit Score Gates

The project is verified to meet these minimum thresholds before any production deployment:

| Metric | Minimum | Actual | Gate Status |
|--------|---------|--------|-------------|
| Delivery | 90% | 100% | ✅ PASS |
| Quality | 90% | 100% | ✅ PASS |
| Compliance | 90% | 100% | ✅ PASS |
| Overall | 90% | 100% | ✅ PASS |

The [audit/latest-report.json](../audit/latest-report.json) is generated on every CI run and contains the authoritative scores.

## Verification Artifacts

After CI completes, audit artifacts are available:
- **audit/full-verification-summary.json** – Consolidated pass/fail for all 9 checks
- **audit/latest-report.json** – Computed delivery/quality/compliance scores
- **audit/data-subject-rights-report.json** – Data-subject-rights verification
- **audit/retention-enforcement-report.json** – Retention/deletion verification
- **audit/gdpr-documentation-report.json** – GDPR documentation check
- **audit/privacy-controls-report.json** – Privacy control implementation check
- **audit/quality-baseline-report.json** – Quality metrics verification
- **audit/security-baseline-report.json** – Security and encryption verification
- **audit/backup-restore-report.json** – Disaster recovery verification
- **audit/monitoring-alerting-report.json** – Operations monitoring check
- **audit/release-checklist-report.json** – Release readiness check

Download from the GitHub Actions workflow "Artifacts" section.

## Handling CI Failures

If a CI check fails:

1. **Review the failure details** in the GitHub Actions logs
2. **Run the failing check locally** to reproduce
3. **Fix the issue** and push a new commit
4. **CI re-runs automatically** on push
5. **All checks must pass** before the PR can be merged

### Common Issues

| Issue | Resolution |
|-------|-----------|
| `swift test` fails | Fix test failures in `Tests/` directory and re-run locally |
| Verification script fails | Check the specific report JSON in `audit/` for detailed checks that failed |
| Audit score below threshold | Review which delivery/quality/compliance metric regressed and address |
| Artifact upload fails | Non-critical; audit files may not exist yet if earlier steps failed |

## Release Process

Before cutting a release:

1. **Ensure all CI checks pass** on the commit
2. **Verify audit score** meets or exceeds 90% on all metrics
3. **Review release checklist** in `docs/operations/release-rollback-checklist.md`
4. **Tag the commit** with semantic versioning
5. **Create release notes** referencing the audit report

Example:
```bash
git tag -a v0.3.0 -m "Release 0.3.0 - Audit: Delivery 100% Quality 100% Compliance 100%"
git push origin v0.3.0
```

## Code Style

- **Swift**: Follow Apple's Swift API Design Guidelines
- **Python**: Follow PEP 8
- **JSON**: Use 2-space indentation (matching existing config files)
- **Markdown**: Use reference links and descriptive headers

## Security

- **Never commit** API keys, private keys, or credentials
- **Sensitive data** in documents should be redacted before committing
- **Encryption keys** are generated locally and never stored in the repository

See [docs/risk-register.md](../risk-register.md) for security risk assessment.

## Questions?

Refer to:
- [README.md](../README.md) – Project overview and quick start
- [ROADMAP.md](../ROADMAP.md) – Delivery phases and milestone tracking
- [docs/category-taxonomy.md](../docs/category-taxonomy.md) – Category definitions
- [docs/compliance/](../docs/compliance/) – GDPR and compliance documentation
- [docs/operations/](../docs/operations/) – Release and operational procedures
- [docs/risk-register.md](../risk-register.md) – Risk assessment and mitigations
