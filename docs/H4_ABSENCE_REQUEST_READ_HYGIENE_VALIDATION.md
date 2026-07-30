# H4 — Absence Request Read Hygiene Validation

**Status:** Approved (product)  
**Date:** 2026-07-31  
**Scope:** Slice H4 only (`docs/PRODUCTION_HARDENING_PHASE0.md`)  
**Out of scope:** H5+, A-H20 inbox events, server-side date indexes (B-R4), new product features

---

## Intent

One shared استئذان read policy for teacher / supervisor / parent — without changing W7 ownership or attendance.

| Item | Delivery |
|------|----------|
| **A-H5** | `AbsenceRequestFirestoreReads` owns `halaqaId` / `requestedBy` queries + day/status filters + sorts |
| **A-H6** | `AbsenceRequest*` entity/model/projection moved to `lib/shared/` (parent re-exports for compatibility) |
| **A-H20** | **Skipped** (no new product features) |

---

## Preserved W7 contracts

| Actor | Read semantics |
|-------|----------------|
| Teacher | `halaqaId` query → pending + same calendar day → sort `studentId` ASC |
| Supervisor | per supervised `halaqaId` → all statuses + same day → sort status then `studentId` |
| Parent | `requestedBy` full history → sort `date` DESC (no day filter) |
| Submit / review | Unchanged writers; no attendance I/O on review |

---

## What shipped

| Owner | Path |
|-------|------|
| Entity / status | `lib/shared/domain/absence_request.dart` |
| Projection | `lib/shared/domain/absence_request_projection.dart` |
| Model | `lib/shared/data/absence_request_model.dart` |
| Reads | `lib/shared/data/absence_request_firestore_reads.dart` |
| Parent re-exports | `parent_entities.dart`, `parent_model.dart`, `absence_request_projection.dart` |

---

## Regression tests

| Suite | Result |
|-------|--------|
| `test/shared/absence_request_firestore_reads_test.dart` | Pass |
| `test/shared/absence_request_ids_test.dart` | Pass |
| `test/features/parent/absence_request_projection_test.dart` | Pass |
| `test/features/parent/submit_absence_request_usecase_test.dart` | Pass |
| `test/features/teacher/review_absence_request_usecase_test.dart` | Pass |
| `test/features/supervisor/get_supervised_absence_requests_usecase_test.dart` | Pass |

---

## Stop gate

**H4 approved.** H5 (roster whereIn chunking) may proceed.
