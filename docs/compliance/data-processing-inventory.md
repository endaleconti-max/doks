# Data Processing Inventory (DPI) — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team | GDPR Article 30 reference

---

## 1. Overview
This inventory lists every data processing activity performed by the Documents App, recording the personal data categories processed, the purpose, whether any third parties are involved, and applicable retention periods. It fulfils the record-keeping obligation under GDPR Article 30.

This inventory is also used to support data subject rights workflows by mapping each activity to access, portability, and erasure mechanisms.

---

## 2. Processing Activities

### Activity 1: Document Import and Text Extraction

| Field | Value |
|-------|-------|
| **Processing activity** | Import a document from the local filesystem, extract its text content |
| **Controller** | End user (local-only processing) |
| **Processor** | None — all processing runs on-device |
| **Legal basis** | Legitimate interest of the controller (personal document management, Art. 6(1)(f)) |
| **Data categories** | May include any category of personal data depending on imported document (e.g. name, address, financial data, health data, identity) |
| **Special category?** | Possible — user may import medical or identification documents; classified automatically and flagged by `medical` / `identification` categories |
| **Data subjects** | The user and any third parties named in imported documents |
| **Retention** | Governed by `DataRetentionPolicy.retentionDays`; default 180 days; `strict` preset enforces 90-day auto-deletion |
| **Recipients** | None — no data leaves the device |
| **Third country transfers** | None |
| **Technical controls** | AES-GCM encryption at rest; plaintext accessible only via local decryption key |

---

### Activity 2: Automatic Document Categorisation

| Field | Value |
|-------|-------|
| **Processing activity** | Classify document into a category using keyword matching on extracted text |
| **Legal basis** | Legitimate interest (Art. 6(1)(f)) — necessary for the organisation service |
| **Data categories** | Extracted text (may contain personal data) |
| **Output** | Category label + confidence score + keyword explanation — no personal data extracted into these fields |
| **Profiling?** | No — classification is document-type labelling, not subject profiling |
| **Retention** | Same as activity 1 |

---

### Activity 3: Audit Event Logging

| Field | Value |
|-------|-------|
| **Processing activity** | Record a timestamped log entry for each import, categorisation change, deletion, and tool execution |
| **Legal basis** | Legitimate interest (Art. 6(1)(f)) — accountability and data-subject rights support |
| **Data categories** | Document file name, document UUID, event type, actor (`user` / `system`), free-text detail |
| **Retention** | Events persist as long as the state file exists; purged when document is deleted by user or by retention policy |
| **Recipients** | None — audit log is local only; exportable by the user via `export-audit` |

---

### Activity 4: State Persistence and Encryption

| Field | Value |
|-------|-------|
| **Processing activity** | Serialize organiser state (documents + events) to disk in AES-GCM-encrypted JSON |
| **Legal basis** | Necessary for the performance of the service (functional requirement) |
| **Data categories** | All data held in memory (see activities 1–3) |
| **Encryption** | AES-256-GCM; key stored at `audit/organizer-state.key` (32 raw bytes) |
| **Key management** | Key is generated once and stored only on the user's device; no escrow |

---

### Activity 5: Data Portability Export

| Field | Value |
|-------|-------|
| **Processing activity** | On user request (`export-state`), write a plaintext JSON snapshot of all documents and audit events |
| **Legal basis** | Compliance with GDPR Art. 20 data portability right |
| **Output** | Unencrypted JSON — user is responsible for securing the output file |
| **Retention** | Export file is not managed by the app after creation |

---

## 3. Data Flow Diagram (summary)

```
User filesystem  →  [Import]  →  Text extraction  →  [Categorise]
                                                            ↓
                                               Encrypted state on disk
                                                            ↓
                              [User commands: list / search / delete / export]
```

No data exits the device boundary under any normal operation.

---

## 4. Review Date
Next review: 2026-09-25 or when a new processing activity is introduced.
