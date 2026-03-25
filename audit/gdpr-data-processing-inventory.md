# GDPR Data Processing Inventory

Date: 2026-03-25
System: DocumentOrganizer
Owner: Product Team

## Processing Activities

1. Document import and text extraction
- Purpose: Organize user documents into categories.
- Data involved: File name, file path, content text (transient), content preview (policy-dependent), content hash.
- Source: User-selected local files.
- Storage: Local JSON state at audit/organizer-state.json.
- Retention: Controlled by privacy preset retention policy.

2. Categorization and correction learning
- Purpose: Improve category assignment quality.
- Data involved: Category results, confidence, explanation, user corrections.
- Source: Internal processing and user recategorization actions.
- Storage: Local JSON state.
- Retention: Same as organizer state retention policy.

3. Audit timeline events
- Purpose: Transparency and accountability for document lifecycle actions.
- Data involved: Event type, timestamp, actor, optional file name and document id, detail.
- Source: System and user actions.
- Storage: Local JSON state and optional exported audit file.
- Retention: Controlled by policy and user deletion/export operations.

4. Tool plugin execution
- Purpose: Run user-enabled transformations.
- Data involved: Plugin identifiers, permission grants/revocations, derived file paths.
- Source: User command actions and plugin output.
- Storage: Local JSON state and local derived files.
- Retention: Local file lifecycle plus policy controls.

## Cross-Border Transfer
No cross-border transfer in current local-only design.

## Third Parties
No third-party processors in current architecture.
