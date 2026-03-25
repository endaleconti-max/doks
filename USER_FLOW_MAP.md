# Documents App User Flow Map (V1)

## Purpose
Translate wireframes into implementation-ready user journeys with handoff states, events, and green-light criteria.

## Flow A: First-Time Import and Auto-Categorization
1. User lands on Home Dashboard.
2. User selects Import action.
3. System ingests document content.
4. System classifies document with confidence and reason.
5. System writes audit event.
6. User sees imported item in Recent Docs and Inbox (if low confidence).

Entry points:
- Home quick action: Import
- Drag and drop into app shell

Primary states:
- Idle
- Importing
- Categorizing
- Imported
- Import failed

Required events:
- imported
- categorization_completed

Green-light checks:
- Import completes without crash for supported text formats.
- Category and explanation are visible on first result view.
- Audit timeline contains import event with timestamp.

## Flow B: Review Queue and Manual Correction
1. User opens Inbox filtered to needs review.
2. User selects a queued document.
3. User inspects suggested category and explanation.
4. User accepts suggestion or changes category.
5. System saves correction and records recategorization event.
6. System applies correction-learning influence for future similar documents.

Entry points:
- Dashboard needs-review card
- Sidebar Inbox navigation

Primary states:
- Queue loaded
- Reviewing
- Correcting
- Saved
- Save failed

Required events:
- recategorized

Green-light checks:
- Correction saves and persists across app restart.
- Updated category appears instantly in list and detail.
- Audit timeline shows recategorization actor and reason.

## Flow C: Search and Retrieval
1. User opens Search Hub.
2. User enters text query and optionally applies filters.
3. System returns matching documents by name, preview, and category.
4. User opens a result into Document Detail.

Entry points:
- Global search shortcut
- Search tab in app shell

Primary states:
- Empty query
- Querying
- Results
- No results

Green-light checks:
- Results include filename and category context.
- No-results state provides recovery guidance.
- Open result transitions to Document Detail without losing search context.

## Flow D: Audit and Privacy Verification
1. User opens Settings > Privacy.
2. User reviews processing mode and retention controls.
3. User opens audit timeline.
4. User exports audit data.

Entry points:
- Settings tab
- Document Detail audit panel

Primary states:
- Privacy controls visible
- Audit timeline loaded
- Export ready
- Export complete

Required events:
- exported

Green-light checks:
- Local-only processing mode is clearly displayed.
- Export produces a readable audit file.
- Timeline includes imports, corrections, deletions, and exports when applicable.

## End-to-End Golden Journey
1. Import two sample documents.
2. Recategorize one document.
3. Import a similar document and verify correction-learning influence.
4. Search for the document and open detail.
5. Export audit timeline.

Pass criteria:
- All five steps complete without blockers.
- Explanation is shown for auto-categorization decisions.
- Audit events are present for each major action.

## Handoff to Engineering
Implementation anchors in current codebase:
- Ingestion: Sources/Ingestion/DocumentIngestionService.swift
- Categorization: Sources/Categorization/CategoryEngine.swift
- Orchestration and audit: Sources/Services/OrganizerService.swift
- CLI verification surface: Sources/DocumentOrganizer/DocumentOrganizer.swift

Definition of Done for V1 flow implementation:
- Each flow above has one reproducible smoke test path.
- Each required event is persisted and retrievable.
- Green-light checks are verified in daily roadmap update logs.
