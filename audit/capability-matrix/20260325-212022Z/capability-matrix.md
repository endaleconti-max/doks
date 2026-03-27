# DocumentOrganizer Capability Matrix

Timestamp (UTC): 20260325-212022Z

## 1) Import
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.

Document: invoice.txt
ID: 76B205CF-1FB8-4DB8-BA7B-6BB5C033E6F1
Category: invoice
Confidence: 0.95
Why: Matched category signals such as 'payment terms'.

Document: resume.txt
ID: D95D0228-1835-41BF-B1D6-3E4D6B8116AE
Category: resume
Confidence: 0.93
Why: Matched category signals such as 'resume'.
[0/1] Planning build
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.73s)
```

## 2) Search
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Found 1 result(s) for 'invoice':
- 76B205CF-1FB8-4DB8-BA7B-6BB5C033E6F1 | invoice.txt | invoice
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.11s)
```

## 3) Recategorize
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Updated invoice.txt to category contract.
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.12s)
```

## 4) Delete
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Deleted document D95D0228-1835-41BF-B1D6-3E4D6B8116AE from organizer state.
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.11s)
```

## 5) Export Audit
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Audit timeline exported to /Users/endaleconti/git folder/Documents App/audit/capability-matrix/20260325-212022Z/timeline-export.json
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.11s)
```

## 6) Export State
```text
Processing mode: local-only
- Privacy preset: balanced.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Organizer state exported to /Users/endaleconti/git folder/Documents App/audit/capability-matrix/20260325-212022Z/state-export.json
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.11s)
```

## 7) Retention Enforcement (strict preset)
```text
Processing mode: local-only
- Privacy preset: strict.
- Data minimization: only metadata and preview snippets are stored by default.
- Purpose limitation: categorization output is used only for organization features.
- Encryption at rest: local organizer state is encrypted with AES-GCM.
- Storage limitation: retention policy can enforce deletion windows.
- User rights support: records can be exported and deleted by identifier.
Retention policy enforcement:
  auto-delete enabled : yes
  retention days      : 90
  scanned documents   : 1
  deleted documents   : 0
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'DocumentOrganizer' complete! (0.11s)
```

## Summary
- Import: PASS
- Search: PASS
- Recategorize: PASS
- Delete: PASS
- Export audit: PASS
- Export state: PASS
- Retention enforcement command: PASS
- Remaining documents after matrix run: 1
- Artifact: /Users/endaleconti/git folder/Documents App/audit/capability-matrix/20260325-212022Z/timeline-export.json
- Artifact: /Users/endaleconti/git folder/Documents App/audit/capability-matrix/20260325-212022Z/state-export.json