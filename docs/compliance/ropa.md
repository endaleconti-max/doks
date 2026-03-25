# Records of Processing Activities (RoPA) — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team | GDPR Article 30

---

## 1. Controller Information

| Field | Value |
|-------|-------|
| Controller name | End user of the Documents App (self-controlled personal tool) |
| Contact | N/A — personal use / local-only |
| DPO | Not required (no large-scale processing of special-category data) |
| Last updated | 2026-03-25 |

---

## 2. Record Entries

### Entry 1 — Document Import and Local Storage

| GDPR Article 30(1) field | Details |
|--------------------------|---------|
| a) Name and contact of controller | End user |
| b) Purposes of processing | Personal document organisation and retrieval |
| c) Description of categories of data subjects | The user; any third parties mentioned in imported documents |
| c) Description of categories of personal data | General personal data: name, address, financial data. Potentially special-category: health data (`medical` category), identity documents (`identification` category) |
| d) Categories of recipients | None — no data shared |
| e) Third-country transfers | None |
| f) Retention period | Default 180 days (balanced preset); 90 days (strict preset). Documents are deleted on user request or automated retention enforcement. |
| g) Technical/organisational measures | AES-256-GCM encryption at rest; local filesystem only; no remote access; user-controlled key in `audit/organizer-state.key` |

---

### Entry 2 — Automatic Categorisation

| GDPR Article 30(1) field | Details |
|--------------------------|---------|
| b) Purposes | Classify document into category for organisation |
| c) Data categories | Extracted document text used for classification; no output field contains personal data |
| Automated decision-making | Category assignment is a convenience label; no legal or significant effect on the data subject |
| Safeguards | Confidence score exposed; user can correct any category; correction is audit-logged |

---

### Entry 3 — Audit Log

| GDPR Article 30(1) field | Details |
|--------------------------|---------|
| b) Purposes | Accountability; support for data subject rights (access, deletion, portability) |
| c) Data categories | Document file name, UUID, event timestamps, category changes, actor |
| f) Retention | Perpetual while state file exists; events for a deleted document are marked deleted |
| g) Measures | Events are part of the encrypted state; exportable to JSON by user via `export-audit` |

---

### Entry 4 — Data Portability Export

| GDPR Article 30(1) field | Details |
|--------------------------|---------|
| b) Purposes | GDPR Art. 20 data portability — enable user to receive their data in a structured, machine-readable format |
| c) Data categories | All stored documents and events at time of export |
| Output security | Plaintext JSON; user is responsible for secure handling of the export file |

---

## 3. Special-Category Data (GDPR Article 9) Notice
The engine may classify documents as `medical` or `identification`. These categories signal the presence of special-category personal data. **The app does not extract, store, or further process the special-category data beyond the encrypted document preview.** Users should apply the `strict` privacy preset which enforces 90-day auto-deletion.

---

## 4. Data Subject Rights Fulfilment

| Right | Mechanism | Tested |
|-------|-----------|--------|
| Access (Art. 15) | `list`, `search`, `export-state` commands | ✅ verified |
| Rectification (Art. 16) | `recategorize` command | ✅ verified |
| Erasure (Art. 17) | `delete` command; `enforce-retention` | ✅ verified |
| Data portability (Art. 20) | `export-state` command | ✅ verified |
| Restriction of processing (Art. 18) | Full erasure via `delete` or preset change to `strict` | ✅ verified |

---

## 5. Review Date
Next review: 2026-09-25 or upon any new processing activity or architecture change.
