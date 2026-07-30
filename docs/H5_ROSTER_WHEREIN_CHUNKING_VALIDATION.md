# H5 — Roster whereIn Chunking Validation

**Status:** Approved (product)  
**Date:** 2026-07-31  
**Scope:** Slice H5 only (`docs/PRODUCTION_HARDENING_PHASE0.md`) — **A-H10 roster `whereIn` chunking first**  
**Out of scope:** H6+, admin payments/complaints pagination, chat unbounded streams, استئذان index work (B-R4), new product features

---

## Intent

Eliminate Firestore `whereIn` / `array-contains-any` hard-fail when id lists exceed **30**, without changing product behavior, ordering contracts, or ownership.

| Item | Delivery |
|------|----------|
| **A-H10 (roster first)** | Shared `FirestoreInQuery` + chunked teacher halaqa roster load |
| Already-chunked callers | Supervisor display names, in-app event student names, parent recipient resolve — same helper, same limit |

---

## Preserved contracts

| Path | Behavior |
|------|----------|
| Teacher `getHalaqaStudents` | Same halaqa → `studentIds` → users `whereIn` by document id; results concatenated in chunk order (no new sort). Empty roster → `[]`. |
| Supervisor `getUserDisplayNames` | Same trim/dedupe → chunked `whereIn` → name map |
| In-app `_studentNamesFor` | Same set of student ids → chunked `whereIn` → name map |
| Parent `ParentRecipientResolver` | Same normalize/chunk/merge API; limit still 30 |

---

## What shipped

| Owner | Path |
|-------|------|
| Shared chunk helper | `lib/shared/utils/firestore_in_query.dart` |
| Teacher roster (critical) | `lib/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart` |
| Supervisor names | `lib/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart` |
| In-app names | `lib/features/notifications/data/sinks/in_app_academy_event_handler.dart` |
| Parent resolve | `lib/features/parent/domain/services/parent_recipient_resolver.dart` |

---

## Regression tests

| Suite | Coverage | Result |
|-------|----------|--------|
| `test/shared/firestore_in_query_test.dart` | Empty, ≤30 (single batch), 31 (30+1), 65 (3 batches), normalize order | Pass |
| `test/features/parent/parent_recipient_resolver_test.dart` | Existing parent chunk/merge contracts | Pass |

---

## Stop gate

**H5 approved.** H6 (surface cleanup) may proceed.
