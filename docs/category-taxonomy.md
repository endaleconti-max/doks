# Category Taxonomy Baseline — Documents App
Version: 1.1 | Date: 2026-03-25 | Owner: Product Team

## 1. Purpose
Define the canonical set of document categories supported by the categorisation engine so that stakeholders can verify coverage and label consistency before production use.

---

## 2. Category Definitions

| Category | Description | Example Documents | Primary Keyword Signals |
|----------|-------------|-------------------|------------------------|
| `invoice` | Commercial invoices, bills, payment demands | Invoice, credit note, pro-forma | invoice, vat, total due, bill to, payment terms |
| `contract` | Legal agreements between parties | Service contract, NDA, SLA, tenancy agreement | agreement, party, obligations, contract, terms and conditions |
| `resume` | CVs and job application documents | Curriculum vitae, résumé, cover letter | curriculum vitae, experience, skills, education, resume |
| `legal` | Court documents, statutory notices, legal opinions | Court order, GDPR notice, statutory declaration | plaintiff, defendant, court, statute, legal notice |
| `medical` | Health-related records (special-category personal data) | Medical report, prescription, discharge summary | diagnosis, prescription, patient, clinic, medical report |
| `education` | Academic records and credentials | Transcript, diploma, certificate of completion | transcript, student, course, university, grade |
| `finance` | Financial statements and account records | Bank statement, balance sheet, IBAN notice | statement, account, balance, transaction, iban |
| `identification` | Identity and travel documents (special-category personal data) | Passport copy, ID card scan, driver's licence | passport, id card, date of birth, nationality, document number |
| `correspondence` | General written communication | Email printout, letter, memo | dear, sincerely, regards, subject, message |
| `general` | Fallback for documents with no strong category signal | Miscellaneous text files | (no dominant signal) |

> **Total categories: 10** (9 semantic + 1 fallback)

---

## 3. Confidence Scoring
- Confidence is computed as `0.45 + (matchScore × 0.12)`, capped at 0.95.
- A document with no keyword matches receives category `general` with confidence 0.25.
- User corrections feed a decay-weighted learning mechanism (`correctionHalfLifeDays = 30`).

---

## 4. Coverage Assessment

| Use-case domain | Covered | Notes |
|-----------------|---------|-------|
| Financial documents | ✅ | `invoice`, `finance` |
| Legal & compliance | ✅ | `legal`, `contract` |
| Human resources | ✅ | `resume` |
| Healthcare | ✅ | `medical` (special-category — extra care required) |
| Identity | ✅ | `identification` (special-category — extra care required) |
| Education | ✅ | `education` |
| General correspondence | ✅ | `correspondence` |
| OCR / scanned documents | ✅ | Implemented for common image formats using Apple Vision OCR |
| Images without text | ✅ | Supported as OCR inputs; blank/no-text images return no extracted text |

---

## 5. Extension Process
New categories must be:
1. Proposed with ≥ 5 representative sample documents.
2. Reviewed for special-category personal data implications.
3. Added to `DocumentCategory` enum and `keywordMap` in `CategoryEngine.swift`.
4. Tested with the quality baseline verification script.
