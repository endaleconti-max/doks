# Documents App Low-Fidelity Wireframe Spec (V1)

## 1) Purpose
This document translates the design map into implementation-ready wireframes with:
- Screen regions and layout rules.
- Component IDs and reusable patterns.
- Interaction and state behaviors.
- Acceptance checks for design handoff.

## 2) Global App Shell
All core screens use the same shell.

## Shell Regions
- `R-TopBar` (height: 64)
- `R-Sidebar` (width: 260 desktop, bottom tab bar on mobile)
- `R-Main` (fluid content)
- `R-Inspector` (width: 340 desktop, bottom sheet on mobile)
- `R-BatchTray` (height: 56, hidden unless multi-select)

## Global Spacing and Grid
- Base spacing scale: 4, 8, 12, 16, 24, 32.
- Main content padding: 24 desktop, 16 tablet, 12 mobile.
- Card gap: 16 desktop, 12 mobile.
- Minimum touch target: 44x44.

## Global Components
- `C-SearchGlobal`: command+K capable search field.
- `C-PrivacyBadge`: status badge with popover.
- `C-ImportButton`: primary import action.
- `C-StatusPill`: processing status indicator.

## 3) Screen Spec: Home Dashboard
## Goal
Immediate situational awareness and fastest path to inbox or search.

## Region Layout
- `R-Main` uses 12-column grid desktop, 1-column mobile.
- Row 1: `C-NeedsReviewCard` (span 4), `C-RecentDocsCard` (span 8).
- Row 2: `C-CategoryHealthCard` (span 6), `C-QuickActionsCard` (span 6).
- `R-Inspector`: `C-ProcessingFeed`, `C-AlertsList`.

## Components
- `C-NeedsReviewCard`: count, trend, CTA to Inbox.
- `C-RecentDocsList`: 10 items with timestamp and category chip.
- `C-CategoryHealthChart`: top categories, low-confidence bucket.
- `C-QuickActions`: Import, Scan, Bulk Categorize, Create Rule.

## Key Interactions
- Tap needs-review card -> navigate to Inbox with `filter=needs_review`.
- Tap any recent doc -> open Document Detail.
- Tap privacy badge -> open compact privacy popover.

## 4) Screen Spec: Inbox (Review Queue)
## Goal
High-throughput review for newly ingested documents.

## Region Layout
- Header: `C-InboxHeader` with filters and counts.
- Body split: `C-QueueList` (40%), `C-ReviewPane` (60%).
- Footer: `R-BatchTray` appears on 2+ selection.

## Queue Row Template (`C-QueueRow`)
- Left: file icon + filename.
- Middle: source, date, suggested category.
- Right: confidence badge + overflow actions.

## Review Pane (`C-ReviewPane`)
- `C-DocMiniPreview`
- `C-SuggestedCategoryBlock`
- `C-ReasonSummary`
- Action row: Accept, Change, Defer, Archive.

## Key Interactions
- Enter key on focused row -> Accept suggestion.
- Cmd+Shift+M -> Change category modal.
- Multi-select -> batch accept / batch change / defer.
- "Apply to similar" opens preview count before commit.

## 5) Screen Spec: Document Detail
## Goal
Deep review and control for a single document.

## Region Layout
- Main center: `C-DocumentPreview`.
- Right inspector sections:
  - `C-MetadataPanel`
  - `C-CategoryPanel`
  - `C-WhyPanel`
  - `C-AuditPanel`
  - `C-ToolActionsPanel`

## Top Action Bar
- Rename, Move, Share, Reveal in Finder.

## Key Interactions
- Category chip is always editable inline.
- Why panel defaults open first visit, remembers preference.
- Audit panel is immutable and exportable.

## 6) Screen Spec: Categories Workspace
## Goal
Manage taxonomy and category quality.

## Region Layout
- Left rail: `C-CategoryTree`.
- Main content: `C-CategoryDocumentList`.
- Top controls: Rename, Merge, Split, Sort.
- Right pane: `C-CategoryStats`, `C-RulePreview`.

## Key Interactions
- Drag docs across categories with confirmation for bulk moves.
- Merge categories shows conflict summary before apply.
- Rule preview shows sample incoming matches before save.

## 7) Screen Spec: Search Hub
## Goal
Fast, precise retrieval across all indexed content.

## Region Layout
- Top: `C-SearchPrimary`.
- Left facets: `C-FacetPanel`.
- Main results: `C-SearchResults` with list/grid toggle.
- Secondary row: `C-SavedSearchBar`.

## Facets
- Category, Date range, Source, File type, Confidence, Tags.

## Key Interactions
- Typing updates results under 200 ms target after debounce.
- Save search persists query + filters + sort.
- No-results state proposes adjacent categories and term suggestions.

## 8) Screen Spec: Settings and Privacy
## Goal
Provide transparent control over data and intelligence behavior.

## Region Layout
- Tab rail: General, Privacy, Categorization, Storage, Plugins.
- Tab content panel for each section.

## Privacy Tab Components
- `C-ProcessingModeCard`
- `C-PluginPermissionMatrix`
- `C-RetentionControls`
- `C-AuditExport`

## Categorization Tab Components
- `C-ConfidenceThresholdSlider`
- `C-AutoApplyRulesToggle`
- `C-LearningFromCorrectionsToggle`

## Key Interactions
- Destructive actions require confirm dialog with consequence text.
- Reset learned behavior uses secondary confirmation step.

## 9) Reusable Component IDs and States
## Core IDs
- `C-DocumentCard`
- `C-DocumentRow`
- `C-CategoryChip`
- `C-ConfidenceBadge`
- `C-WhyDrawer`
- `C-BatchActionTray`
- `C-PrivacyBadge`
- `C-ProcessingIndicator`

## Required States for Each Component
- Default
- Hover/focus
- Loading
- Empty
- Error
- Disabled

## 10) Interaction Rules (System-wide)
- Single click selects, double click opens detail.
- Keyboard-first support on all primary actions.
- Undo toast after destructive actions (archive/delete/category merge).
- Every categorization decision must expose a reason path.
- Every plugin action must generate an audit event.

## 11) Responsive Rules
- Desktop: Sidebar + main + inspector visible.
- Tablet: Sidebar collapsible, inspector as slide-over.
- Mobile: Bottom nav, stacked main content, inspector as bottom sheet.

## 12) Initial Design Tokens
- Type scale: 12, 14, 16, 20, 24, 30.
- Radius: 8 (controls), 12 (cards), 16 (dialogs).
- Elevation: 0, 1, 2, 3 (minimal shadows).
- Motion durations: 120 ms, 180 ms, 220 ms.
- Motion easing: standard ease-out for enter, ease-in for exit.

## 13) Golden Flow (Prototype Path)
1. Import 20 documents from mixed sources.
2. Review only low-confidence items in Inbox.
3. Correct 3 categories and apply one correction to similar docs.
4. Retrieve a target doc in Search and open Detail.
5. Verify privacy mode and audit trail in Settings.

Success criteria:
- Flow completes in under 3 minutes.
- No blocked steps.
- User can explain why each auto-category was chosen.

## 14) Handoff Checklist
- All 6 screens wireframed at desktop and mobile.
- All core components mapped by ID.
- Empty/loading/error states designed.
- Keyboard shortcuts defined for critical flows.
- Privacy and audit affordances visible on every relevant screen.
