# Legal Basis Mapping — Documents App
Version: 1.0 | Date: 2026-03-25 | Owner: Product Team | GDPR Article 6 & 9

---

## 1. Purpose
Map every processing activity to its lawful basis under GDPR Article 6, and where special-category data is involved, to an additional condition under Article 9.

---

## 2. Legal Basis Table

| Processing Activity | Lawful Basis (Art. 6) | Basis Rationale | Art. 9 Condition (if applicable) | Notes |
|--------------------|-----------------------|-----------------|----------------------------------|-------|
| Document import and text extraction | Art. 6(1)(f) — Legitimate interests | The user's interest in organising their own local documents outweighs any privacy impact; processing is local-only, no third-party access | Art. 9(2)(a) — Explicit consent of the data subject (where special-category data present) | User actively initiates import; informed by privacy notice printed on startup |
| Automatic categorisation | Art. 6(1)(f) — Legitimate interests | Categorisation is the core value proposition; no automated decision with legal effect; user can correct | Art. 9(2)(a) where applicable | Category output labels document type only; does not extract health or biometric data into output fields |
| Audit event logging | Art. 6(1)(f) — Legitimate interests | Accountability and support for data-subject rights fulfilment is a legitimate interest; minimal data captured | N/A — audit log captures only metadata (file name, UUID, timestamps), not document content | |
| State encryption and persistence | Not a distinct processing purpose — necessary measure for lawful processing under all activities above | Technical security safeguard; required to meet Art. 25 data protection by design obligation | N/A | |
| Data portability export (`export-state`) | Art. 6(1)(c) — Compliance with legal obligation + Art. 6(1)(f) | GDPR Art. 20 right to data portability; the app implements the controller's obligation | N/A for the export mechanism itself | Output file security is user's responsibility once created |
| Retention policy enforcement (`enforce-retention`) | Art. 6(1)(f) + Art. 5(1)(e) storage limitation principle | Enforcing retention limits advances the storage-limitation principle; in user's interest | N/A | Auto-deletion only when `autoDeleteEnabled = true`; user controls via preset |
| Tool execution (PluginKit) | Art. 6(1)(f) — Legitimate interests | Tool runs locally, user-initiated, user-controlled permission grants | Art. 9(2)(a) if tool operates on special-category document | Permissions model enforces explicit grant before any tool can access a document |

---

## 3. Legitimate Interests Assessment (LIA) Summary — Primary Basis

**Purpose test**: The Documents App processes data solely to provide local document organisation to the user who controls all the data. There is no commercial exploitation, profiling, or sharing.

**Necessity test**: Text extraction and categorisation are strictly necessary for the service. Retention limits reduce processing duration to the minimum required.

**Balancing test**: The user is the controller and the primary data subject. There is no conflict between the controller's interests and the data subjects' rights because they are the same person. Third-party personal data in imported documents (e.g. names on invoices) is incidental, minimised to previews, and never shared.

**Outcome**: Legitimate interest is justified for all primary processing activities.

---

## 4. Special-Category Data Conditions (Art. 9)

Where documents classified as `medical` or `identification` are imported, the controller relies on:
- **Art. 9(2)(a) — Explicit consent**: The act of importing the document is an explicit, informed action by the user. The startup privacy notice informs the user that special-category data may be processed. The `strict` preset is recommended for any user storing such documents.

No other Art. 9 conditions apply.

---

## 5. Absence of Art. 6(1)(a) Consent as Primary Basis
Consent is not used as the primary legal basis for routine processing because the user is the controller, not just a data subject. Consent would be circular. Legitimate interests and legal obligation are the appropriate bases.

---

## 6. Review Date
Next review: 2026-09-25 or on any new processing activity or change in processing purpose.
