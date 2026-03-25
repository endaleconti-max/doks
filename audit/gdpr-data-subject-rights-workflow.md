# Data Subject Rights Workflow Draft

Date: 2026-03-25
Status: Draft

## Right of Access
- Retrieve stored records via list and search commands.
- Export audit evidence with export-audit command.

## Right to Erasure
- Delete individual records via delete command.
- Remove local state file to clear full local organizer history.

## Right to Portability
- Export audit timeline to JSON format.
- Export full organizer state with `swift run DocumentOrganizer export-state <output-path>`.

## Verification Checklist (To Execute)
- Completed: export-state command emits portable JSON with documents, events, and plugin permission grants.
- Completed: automated verification script `scripts/verify_data_subject_rights.py` passes all checks and writes evidence to `audit/data-subject-rights-report.json`.
- Completed: export includes complete event history for sampled records.
- Completed: delete removes record and prevents it from appearing in list/search.
- Completed: repeated run after process restart confirms deleted record stays absent.
