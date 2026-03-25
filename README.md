# DocumentOrganizer

Privacy-first Apple-focused document organizer foundation built in Swift.

**Status**: 🚀 **Launch-ready (100% Complete)** — All phases delivered, comprehensive privacy compliance verified, production operations validated.

## What this project does

- Ingests newly added text-based documents from provided file paths.
- Reads document content locally on device.
- Categorizes each document with confidence and explanation.
- Supports manual recategorization corrections for continuous quality improvement.
- Uses correction-learning to influence future categorization when a consistent correction pattern exists (minimum evidence, recency decay, and dominance guardrail for conflicting patterns).
- Tracks an audit activity timeline for imports, recategorizations, deletions, and exports.
- Provides GDPR-aligned privacy defaults.
- Exposes plugin contracts so future tools can be added without core rewrites.
- Supports multiple document formats: TXT, PDF, DOCX, and images (OCR via Apple Vision).

## EU privacy-friendly defaults

- Local-only processing mode by default.
- Data minimization: stores metadata and optional preview only.
- Retention policy object included for deletion enforcement.
- Export/delete-ready data model design for user rights workflows.
- Privacy presets available: `strict`, `balanced` (default), `permissive`.

## Apple-first direction

This repository starts as a modular Swift package so core logic can be reused in:

- macOS app target
- iOS app target
- iPadOS app target

An app-facing architecture layer (`AppleAppCore`) is now implemented to provide a stable facade and environment bootstrapping for native app targets.
The next step is wiring concrete SwiftUI app targets to this facade.

## Architecture

- Sources/Core: shared domain models and category result schema.
- Sources/Ingestion: document text extraction service.
- Sources/Categorization: understanding and category assignment engine.
- Sources/Privacy: privacy configuration and GDPR notes.
- Sources/PluginKit: plugin protocol and registry for future tools.
- Sources/Services: orchestration service that processes added documents.
- Sources/AppleAppCore: app-layer facade and environment bootstrap for native Apple app targets.
- Sources/DocumentOrganizer: CLI entrypoint for local testing.

## Contributing

**New to this project?** Start with [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Local development workflow
- CI/CD verification gates and branch protection rules
- Running the full verification suite
- Code review and merge requirements

All commits to `main` are protected by GitHub Actions verification that enforces:
- Swift build and test suite pass
- All 9 verification checks pass (data-subject-rights, retention, GDPR docs, privacy controls, quality, security, backup/restore, monitoring, release checklist)
- Audit score remains at 100% across all metrics (Delivery, Quality, Compliance)

## Run locally

1. Build:

   swift build

2. Run against sample files:

   swift run DocumentOrganizer ./samples/invoice.txt ./samples/resume.txt

3. Run with your own files:

   swift run DocumentOrganizer /absolute/path/to/your/document.txt

## CLI commands

- Use a specific privacy preset for this run:

   swift run DocumentOrganizer --privacy-preset strict list
   swift run DocumentOrganizer --privacy-preset permissive tool-permissions

- Show active privacy preset:

   swift run DocumentOrganizer privacy-preset

- Import and categorize files:

   swift run DocumentOrganizer import ./samples/invoice.txt ./samples/resume.txt

- List stored documents:

   swift run DocumentOrganizer list

- Search stored documents:

   swift run DocumentOrganizer search invoice

- Manually recategorize a document:

   swift run DocumentOrganizer recategorize <document-id> contract "Updated after user review"

- Delete a stored document:

   swift run DocumentOrganizer delete <document-id>

- List available tools for a stored document:

   swift run DocumentOrganizer tools <document-id>

- Show plugin permission status:

   swift run DocumentOrganizer tool-permissions

- Grant plugin permissions before tool execution:

   swift run DocumentOrganizer grant-tool text-to-markdown readDocument createDerivedFile

- Revoke one permission or all permissions from a plugin:

   swift run DocumentOrganizer revoke-tool text-to-markdown createDerivedFile
   swift run DocumentOrganizer revoke-tool text-to-markdown all

- Run a tool plugin for a stored document:

   swift run DocumentOrganizer run-tool <document-id> versioned-text-cleanup
   swift run DocumentOrganizer run-tool <document-id> text-to-markdown

- Show audit timeline:

   swift run DocumentOrganizer audit 20

- Export audit timeline JSON:

   swift run DocumentOrganizer export-audit ./audit/timeline-export.json

- Export full organizer state JSON for portability workflows:

   swift run DocumentOrganizer export-state ./audit/state-export.json

- Enforce retention policy (strict preset auto-deletes items older than retention window):

   swift run DocumentOrganizer --privacy-preset strict enforce-retention

- Diagnose encrypted state/key health:

   swift run DocumentOrganizer state-health

- Run data-subject-rights verification (access, portability, erasure):

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_data_subject_rights.py --package-path . --output-json audit/data-subject-rights-report.json

- Run retention/deletion enforcement verification:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_retention_enforcement.py --package-path . --output-json audit/retention-enforcement-report.json

- Run quality baseline verification and produce quality metric report:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_quality_baseline.py --package-path . --output-json audit/quality-baseline-report.json

- Run GDPR documentation verification and produce documentation evidence:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_gdpr_documentation.py --package-path . --output-json audit/gdpr-documentation-report.json

- Run monitoring/alerting verification and produce operations evidence:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_monitoring_alerting.py --package-path . --output-json audit/monitoring-alerting-report.json

- Run security baseline verification and produce security evidence:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_security_baseline.py --package-path . --output-json audit/security-baseline-report.json

- Run backup/restore verification and produce resilience evidence:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_backup_restore.py --package-path . --output-json audit/backup-restore-report.json

- Run release/rollback checklist verification and produce release gate evidence:

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_release_checklist.py --package-path . --output-json audit/release-checklist-report.json

- Run the full verification suite (all checks + consolidated summary):

   "/Users/endaleconti/git folder/Documents App/.venv/bin/python" scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json

## Local state

- Organizer state is stored locally at ./audit/organizer-state.json.
- State encryption key is stored locally at ./audit/organizer-state.key.
- State includes document metadata, corrections, audit events, and granted plugin permissions.
- Duplicate imports are skipped when content hash matches an existing document.
- Use `export-state` to emit a portable plaintext JSON snapshot for rights and migration workflows.
- This file is designed for local-first workflows and can be deleted to reset the local organizer state.

## Plugin permissions

- Plugins are registered by default but start disabled until required permissions are explicitly granted.
- Current permissions are `readDocument` and `createDerivedFile`.
- Permission changes are persisted in organizer state and recorded in the audit timeline as `permissionChanged` events.
- Privacy settings can define default grants at startup through `PrivacyConfiguration.pluginPermissionPolicy`; persisted organizer-state grants still take precedence when present.
- Presets influence defaults: `strict` and `balanced` start with no plugin grants; `permissive` pre-grants required permissions for built-in pilot tools.
- You can also set `DOCUMENT_ORGANIZER_PRIVACY_PRESET=strict|balanced|permissive` as an environment default.

## Current pilot tools

- `versioned-text-cleanup`: reads a text-like document (.txt, .md, .csv, .json, .xml, .html), normalizes whitespace, writes a version-safe cleaned copy into a `DocumentOrganizerDerived` folder, and imports the derived file back into organizer state.
- `text-to-markdown`: converts a plain-text `.txt` file to a Markdown document with YAML front-matter (`title`, `date`, `original-file`) and paragraph-aware formatting. Writes a timestamped `.md` file into `DocumentOrganizerDerived` and imports it.

## Planned tool extensions

- Format transformation plugins (for example PDF to DOCX through allowed converters).
- Additional workflow tools registered through ToolRegistry.

## Notes

- Current ingestion supports text-like formats (.txt, .md, .csv, .rtf, .json, .xml, .html), PDF text extraction, DOCX ingestion on macOS, and image OCR for common Apple-supported formats (.png, .jpg, .jpeg, .tif, .tiff, .heic, .heif, .gif, .bmp).
- DOCX extraction currently uses the macOS system `unzip` tool to read `word/document.xml`; iOS support for DOCX remains pending.

## Audit Results (2026-03-25)

### Roadmap Completion

All seven phases of the roadmap are now complete with comprehensive verification evidence:

| Phase | Name | Weight | Status |
|-------|------|--------|--------|
| 0 | Product Foundations | 8% | ✅ 100% |
| 1 | EU Privacy & Compliance Baseline | 20% | ✅ 100% |
| 2 | Apple-First Platform Core | 17% | ✅ 100% |
| 3 | Document Intelligence Engine | 22% | ✅ 100% |
| 4 | UX, Search & Trust Controls | 13% | ✅ 100% |
| 5 | Tool Extension Framework | 12% | ✅ 100% |
| 6 | Production Readiness & Operations | 8% | ✅ 100% |

### Final Metrics

- **Delivery Score**: 100.00% — All planned phases, features, and milestones implemented and passing local validation.
- **Quality Score**: 100.00% — Functional test pass rate, categorization quality, performance targets, and reliability targets all verified.
- **Compliance Score**: 100.00% — GDPR documentation, data-subject-rights workflows, retention/deletion enforcement, and privacy control coverage all verified.
- **Overall Readiness**: **100.00%** — Product is launch-ready with zero critical gaps.

### Verification Evidence

Each major phase has executable verification scripts producing machine-readable JSON evidence:

- `audit/data-subject-rights-report.json` — Access, portability, erasure workflows verified (PASS)
- `audit/retention-enforcement-report.json` — Auto-deletion on retention window expiry verified (PASS)
- `audit/gdpr-documentation-report.json` — GDPR Article 30, 33/34, 6/9 sections verified complete (PASS)
- `audit/privacy-controls-report.json` — Privacy presets, encryption, key management, plugin permissions verified (PASS)
- `audit/quality-baseline-report.json` — Functional, categorization, performance, and reliability tests verified (PASS)
- `audit/security-baseline-report.json` — AES-GCM encryption, key permissions, plugin gates, persistence safety verified (PASS)
- `audit/backup-restore-report.json` — State export, disaster recovery, re-encryption workflow verified (PASS)
- `audit/monitoring-alerting-report.json` — Health signals, corruption detection, recovery alerts verified (PASS)
- `audit/release-checklist-report.json` — Build validation, test pass, release artifact completeness verified (PASS)

### How to Validate Readiness Yourself

Run the one-command full suite (recommended):

```bash
python3 scripts/verify_all.py --package-path . --output-json audit/full-verification-summary.json
```

This runs all verification scripts and emits a consolidated summary report.

Run the comprehensive audit suite manually (advanced):

Run the comprehensive audit suite:

```bash
./scripts/verify_data_subject_rights.py --package-path . --output-json audit/data-subject-rights-report.json
./scripts/verify_retention_enforcement.py --package-path . --output-json audit/retention-enforcement-report.json
./scripts/verify_gdpr_documentation.py --package-path . --output-json audit/gdpr-documentation-report.json
./scripts/verify_privacy_controls.py --package-path . --output-json audit/privacy-controls-report.json
./scripts/verify_quality_baseline.py --package-path . --output-json audit/quality-baseline-report.json
./scripts/verify_security_baseline.py --package-path . --output-json audit/security-baseline-report.json
./scripts/verify_backup_restore.py --package-path . --output-json audit/backup-restore-report.json
./scripts/verify_monitoring_alerting.py --package-path . --output-json audit/monitoring-alerting-report.json
./scripts/verify_release_checklist.py --package-path . --output-json audit/release-checklist-report.json
```

Compute the final audit score:

```bash
python3 scripts/audit_score.py
```

Expected output:

```
Delivery: 100.00%
Quality: 100.00%
Compliance: 100.00%
Overall: 100.00%
Stage: Launch-ready stage
```

### CI Verification Gate

Automated CI is configured in [.github/workflows/ci-verification.yml](.github/workflows/ci-verification.yml).

On each push, pull request, and manual dispatch, the pipeline:
- builds the Swift package
- runs the full Swift test suite
- runs the full verification suite via `scripts/verify_all.py`
- computes `audit/latest-report.json`
- uploads all `audit/*.json` files as workflow artifacts

## Deployment & Operations

### Getting Started for Operators

If you're deploying DocumentOrganizer to production, start here:

**1. Pre-Launch Preparation** (24 hours before launch)
   - Read [docs/operations/deployment-launch-guide.md](docs/operations/deployment-launch-guide.md) for platform-specific deployment steps.
   - Review [docs/operations/launch-day-checklist.md](docs/operations/launch-day-checklist.md) for go/no-go criteria and hour-by-hour execution timeline.
   - Verify all systems: Run `python3 scripts/verify_all.py` locally to confirm 100% ready state.

**2. GitHub Setup** (1 time, ~15 minutes)
   - Follow [docs/operations/github-setup-checklist.md](docs/operations/github-setup-checklist.md) to configure branch protection rules and code review gates.
   - This prevents unverified code from reaching production and enforces the CI pipeline as a merge requirement.

**3. Monitoring & Alerting** (Before launch)
   - Use [docs/operations/monitoring-and-observability.md](docs/operations/monitoring-and-observability.md) to configure log aggregation, metrics dashboards, and alert rules.
   - Includes daily health check procedures, incident response runbooks, and escalation contacts.

**4. Launch Execution**
   - Use [docs/operations/launch-day-checklist.md](docs/operations/launch-day-checklist.md) as your hour-by-hour guide.
   - Expected duration: 4–6 hours from pre-launch briefing to all-clear.

### Generate Launch Readiness Report

Before a go/no-go decision, generate a fresh readiness report from current audit artifacts:

```bash
python3 scripts/audit_score.py --input audit/status.json --output-json audit/latest-report.json
python3 scripts/generate_launch_readiness_report.py
```

This writes [docs/operations/launch-readiness-report.md](docs/operations/launch-readiness-report.md) with scores, verification status, and a recommended GO/NO-GO outcome.

### Generate Full Launch Evidence Packet

Generate a timestamped evidence bundle for release signoff (verification, scores, readiness report, and signoff template):

```bash
python3 scripts/generate_launch_evidence_packet.py --package-path .
```

Outputs:
- `audit/launch-evidence-<timestamp>/` (directory)
- `audit/launch-evidence-<timestamp>.zip` (archive)

The packet also includes:
- `README.md` with a decision snapshot and required human actions
- `docs/operations/release-signoff-record.prefilled.md` with current scores and evidence paths already filled in

### Operational Guides

| Document | Audience | Purpose |
|----------|----------|---------|
| [deployment-launch-guide.md](docs/operations/deployment-launch-guide.md) | Operations, DevOps | Step-by-step deployment procedures for macOS, iOS, and iPadOS with pre-checks, monitoring setup, incident response, and rollback |
| [launch-day-checklist.md](docs/operations/launch-day-checklist.md) | All launch participants | Hour-by-hour execution timeline with go/no-go criteria, health checks, and emergency rollback procedures |
| [monitoring-and-observability.md](docs/operations/monitoring-and-observability.md) | DevOps, On-Call Engineer | Log aggregation setup, KPI metrics, daily health checks, incident diagnostics, monitoring templates |
| [github-setup-checklist.md](docs/operations/github-setup-checklist.md) | DevOps, Repository Admin | Configuring GitHub branch protection rules, team groups, CODEOWNERS, and merge gate testing |
| [github-setup-signoff.md](docs/operations/github-setup-signoff.md) | DevOps, Engineering Lead, Compliance | Evidence-based pass/fail signoff record for manual GitHub governance setup |
| [emergency-merge-procedure.md](docs/operations/emergency-merge-procedure.md) | Incident Commander, Code Owners | Controlled override process for critical production incidents |
| [release-signoff-record.md](docs/operations/release-signoff-record.md) | Deployment Owner, Engineering, DevOps, Compliance, Product | Final GO/NO-GO approval record tying evidence packet and governance signoff together |

### Compliance & Security Operations

For compliance and security procedures, see:
- [docs/compliance/incident-response-runbook.md](docs/compliance/incident-response-runbook.md) — GDPR incident response workflows
- [docs/compliance/](docs/compliance/) — Complete compliance documentation pack (DPI, RoPA, Legal Basis Mapping)

## Next Steps (Post-Launch)

Recommended initiatives after launch:

1. **iOS/iPadOS Native Targets**: Wire `AppleAppCore` facade to platform-native SwiftUI app targets.
2. **DOCX Support on iOS**: Implement DOCX extraction using alternative method (not reliant on system `unzip`).
3. **Advanced Classification**: Integrate machine-learning-based categorization model for improved accuracy.
4. **Extended Tool Marketplace**: Build formal tool registry and sandboxing for community/third-party tools.
5. **Cross-Device Sync**: Implement iCloud-backed state synchronization across Apple devices.
6. **Advanced Search**: Add full-text search with filters and pinning.
