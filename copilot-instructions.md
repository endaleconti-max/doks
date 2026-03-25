# Agent Startup Behavior

When asked to continue work without a specific ticket, refer to this guide and the latest roadmap entry.

## Current Project Status

**DocumentOrganizer** is at **100% Launch-Ready (as of 2026-03-25)**:
- All 7 roadmap phases complete (Delivery 100%, Quality 100%, Compliance 100%)
- Full verification suite deployed (9 executable scripts)
- GitHub Actions CI/CD with branch protection gates configured
- All audit reports show PASS across data-subject-rights, retention, GDPR docs, privacy controls, quality, security, backup/restore, monitoring, and release checklist
- Deployment and launch guide complete

## How to Continue

### For General Work
1. Read [ROADMAP.md](ROADMAP.md) section "12) 24-Hour Build and Roadmap Update Log" — latest entry is source of truth
2. Check [docs/operations/](docs/operations/) for operational procedures (release-rollback-checklist, deployment-launch-guide)
3. Run `python3 scripts/verify_all.py` before committing to ensure all checks still pass

### For Post-Launch Work (Phases 3+)
Priority initiatives in order:
1. **iOS/iPadOS Native Targets** — Wire AppleAppCore facade to native SwiftUI app targets
2. **DOCX Support on iOS** — Implement alternative to system `unzip` (pending)
3. **ML-Based Classification** — Integrate machine-learning categorization model to replace keywords
4. **Extended Tool Marketplace** — Formal registry and sandboxing for community tools
5. **Cross-Device Sync** — iCloud-backed state synchronization
6. **Advanced Search** — Full-text search with filters, pinning, saved searches

### For Operational/DevOps Work
- Update [.github/workflows/ci-verification.yml](.github/workflows/ci-verification.yml) if verification scripts change
- Maintain [docs/operations/deployment-launch-guide.md](docs/operations/deployment-launch-guide.md) with each production deployment
- Refer to [CONTRIBUTING.md](CONTRIBUTING.md) for branch protection and code review rules
- See [docs/risk-register.md](docs/risk-register.md) for security and operational risks

### For Compliance Work
- All GDPR audit artifacts are in [docs/compliance/](docs/compliance/): DPI, RoPA, LBM, IRR
- Incident response runbook: [docs/compliance/incident-response-runbook.md](docs/compliance/incident-response-runbook.md)
- Data subject rights verification: run `python3 scripts/verify_data_subject_rights.py`

## Code Architecture Overview

- **Sources/Core** — Domain models (DocumentCategory, DocumentRecord, AuditEvent, CategoryResult)
- **Sources/Ingestion** — Document extraction (TXT, PDF, DOCX, images via OCR)
- **Sources/Categorization** — Classification engine (keyword-based with correction learning)
- **Sources/Privacy** — Privacy presets (strict/balanced/permissive) + GDPR config
- **Sources/PluginKit** — Plugin framework + 2 pilot tools (text-to-markdown, versioned-text-cleanup)
- **Sources/Services** — Orchestration service (OrganizerService) + encryption + audit logging
- **Sources/AppleAppCore** — App facade (AppEnvironment, DocumentOrganizerFacade) for native targets
- **Sources/DocumentOrganizer** — CLI entrypoint for local testing
- **Tests/** — Test suite (OrganizerServiceTests, AppleAppCoreTests)
- **scripts/** — Verification suite (9 verifiers) + audit score calculator
- **docs/** — Complete operational and compliance documentation

## Build & Test Commands

```bash
# Build and test
swift build
swift test

# Run full verification (recommended before committing)
python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json

# Compute audit scores
python3 scripts/audit_score.py

# Run a specific verification
python3 scripts/verify_data_subject_rights.py --package-path . --output-json audit/data-subject-rights-report.json
```

## Development Workflow

1. Create a feature branch from `main`
2. Make changes and test locally
3. Run `python3 scripts/verify_all.py` to ensure all checks pass
4. Commit and push
5. GitHub Actions CI automatically runs the same verify suite
6. Pull request must pass all checks + 1 code review before merge

See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.
