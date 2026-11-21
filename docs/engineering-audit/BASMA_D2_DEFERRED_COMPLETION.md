# BASMA — D2 Deferred Firebase Efficiency (Completion)

**Date:** 2026-11-21  
**Branch / HEAD (before & after):** `unify/basma-v1` @ `8ce64fe` (dirty WT preserved; **no** git mutations, **no** Production/Cloud)  
**Emulator project:** not required for the unit/bloc suites below; Cloud untouched  
**Prior docs reused:** `BASMA_D2_FIREBASE_EFFICIENCY.md`, `BASMA_G0_G1_READINESS.md`  
**Verdict:** **PASS WITH GAPS**

---

## 1. Git state

| Moment | Branch | HEAD | Working tree |
|--------|--------|------|----------------|
| Start | `unify/basma-v1` | `8ce64fe` | Dirty (~325 paths); preserved |
| End | `unify/basma-v1` | `8ce64fe` | Dirty (~353 paths); no reset/stash/checkout/commit/push |

Forbidden ops not run: reset, clean, stash, checkout, commit, push, merge, rebase.  
No Firebase deploy, rules/indexes deploy, seed, IAM, or billing changes.

---

## 2. Task status (A–F)

| ID | Task | Status | Notes |
|----|------|--------|-------|
| **A** | Admin payment-proof N+1 | **Fixed (client)** | Batched `users` name reads via `whereIn` chunks; supervisor pending queries parallelized (chunks of 8). Pending list itself still one admin query / per-student supervisor queries (rules-shaped). Callable projection still the long-term AuthZ+read win. |
| **B** | Registration full student scan | **Fixed (profiles-first)** | Candidates from `studentProfiles` where `halaqaId` is null **or** `''`, then batch `users` + parallel `userPrivate` email gets. No silent result cap. Residual: legacy uid with **no** profile doc. |
| **C** | Parent payment history pagination | **Fixed** | Firestore cursor (`dueDate` desc + `startAfterDocument`); ownership guard on cursor; bloc LoadMore droppable; UI load-more / error / retry. Index `parentId + dueDate` already in repo. |
| **D** | Student achievements pagination + indexes | **Fixed (UI path)** | Dual-query cursor page (`studentId`/`recipientStudentIds` + `orderBy date`); LoadMore UI; badges keep full merge. **Indexes added locally only** (not deployed). |
| **E** | Admin inbox cursor compatibility | **Fixed + verified** | `_olderPageCursorId` tracks raw Firestore tip (not client-resorted list tip). Equal-timestamp + concurrent LoadMore tests added; prior inbox paging tests still green. |
| **F** | Reads / listener measurements | **Partial (contract)** | Code-level before/after query shapes documented below. No Emulator read-counter instrumentation this pass — **not invented**. |

---

## 3. Confirmed issues (pre-fix)

1. Payment-proof review: serial per-student name `get`s (N+1) + serial supervisor pending queries.  
2. Registration: scan all active students + serial private-email reads.  
3. Parent `getPayments`: unbounded `parentId` + `orderBy(dueDate)`.  
4. Student achievements list: dual unbounded gets; no cursor UI; missing composite indexes in repo.  
5. Inbox LoadMore: cursor taken from merged/client-sorted tip → equal-`lastMessageAt` skip/dupe risk.  
6. No practical read meters on Emulator for these paths.

---

## 4. Files changed (why)

| File | Why |
|------|-----|
| `admin_operations_remote_datasource_impl.dart` | Batch names; parallel supervisor pending fetches |
| `admin_private_email_reader.dart` | `emailsOf` parallel private-email gets |
| `admin_remote_datasource_impl.dart` | Profiles-first registration candidates |
| `parent_remote_datasource*.dart` / `parent_repository*` / `get_payments_usecase.dart` / `parent_repositories.dart` | Payments cursor page API |
| `parent_bloc.dart` / `parent_event.dart` / `parent_state.dart` / `parent_subscriptions_page.dart` | LoadMore + first-page household load |
| `student_remote_datasource*.dart` / `student_repository*` / `get_achievements_usecase.dart` | Achievements cursor page API |
| `student_bloc.dart` / `student_event.dart` / `student_state.dart` / `student_achievements_page.dart` | Paged list + LoadMore; badges stay full |
| `chat_conversations_bloc.dart` | Stable older-page cursor |
| `firestore.indexes.json` | Achievements composites (local only) |
| Tests under `test/features/{admin,parent,student,chat}/` | Regressions for A helpers, C, D, E |
| Fake `getPaymentsPage` stubs in several parent usecase tests | Interface completeness |

---

## 5. Solution design

### A — Payment proofs
- Admin: single pending query (unchanged product: full pending set).  
- Names: `FirestoreInQuery.chunkIds` + `whereIn` on `users` (same pattern as admin payments ledger).  
- Supervisor: still one pending query per supervised student (rules), but `Future.wait` in parallel slices of 8.  
- AuthZ unchanged: Admin sees academy pending; Supervisor only students that rules allow.

### B — Registration
- Invert scan: `halaqaId isNull` ∪ `halaqaId == ''` on `studentProfiles`, then `users` `whereIn` filter `role=student && isActive`, then parallel emails.  
- Completeness residual without schema flag: student **without** a profile document.

### C — Parent payments
- `getPaymentsPage(parentId, limit=30, afterPaymentId?)` → `startAfterDocument`.  
- Cursor ownership check (`parentId` must match).  
- Bloc: droppable LoadMore; dedupe by id; error keeps loaded rows.  
- Subscriptions UI: load-more button + retry.

### D — Achievements
- Page API merges two ordered queries; cursors are per-query raw tips.  
- `LoadAchievementsEvent(paged: true)` for list; default `paged: false` keeps full merge for badges/reader.  
- Indexes (local): `studentId + date DESC`; `recipientStudentIds CONTAINS + date DESC`.  
- Docs missing `date` are excluded by `orderBy(date)` (legacy gap; dual-write covers new writes).

### E — Inbox cursor
- `_olderPageCursorId` set from live tip until first older page, then from each raw `fetchConversationsAfter` page’s last id.  
- Client `_byRecency` sort of `_older` no longer moves the next cursor.

---

## 6. Tests actually run

```text
flutter test \
  test/features/parent/parent_bloc_test.dart \
  test/features/parent/parent_payments_pagination_test.dart \
  test/features/chat/chat_inbox_cursor_compat_test.dart \
  test/features/student/student_achievements_pagination_test.dart \
  test/features/admin/admin_d2_deferred_efficiency_test.dart \
  test/features/student/student_bloc_load_test.dart
→ All tests passed! (+32)

flutter test test/features/chat/chat_groups_messaging_test.dart --name "inbox paging"
→ All tests passed! (+2)
```

```text
flutter analyze <8 touched lib files>
→ 1 unused_import warning fixed (parent_bloc); re-clean on next analyze expected 0 on those files
```

**Not claimed:** Emulator rules AuthZ re-run for payments/achievements; Production profiler; Functions Emulator.

---

## 7. Measurements available (contract / code)

| Path | Before (code) | After (code) |
|------|---------------|--------------|
| Payment-proof names | 1 `get` / distinct student | ⌈N/30⌉ `whereIn` reads |
| Supervisor pending | Serial N student queries | Same N queries, parallel ×8 |
| Registration | All active students + 1 profile chunk pass + N emails | Only null/empty-halaqa profiles + user chunks + parallel emails |
| Parent payments (home + subscriptions first paint) | Unbounded get | ≤30 docs + cursor |
| Student achievements list first paint | 2 unbounded gets | 2× ≤20 ordered gets |
| Admin inbox LoadMore cursor | Merged list tip | Raw Firestore page tip |
| Active inbox listeners | Unchanged (one live window + optional older pages) | Unchanged |

---

## 8. Not measured

- Exact Emulator/Firestore **read counts** for a seeded N=50/200 journey.  
- Listener leak under real navigation (code review only: chat still uses `restartable` + session clear; parent/student LoadMore are one-shot gets, not listeners).  
- Wall-clock latency on device.

---

## 9. Indexes required

| Collection | Fields | Why | Repo | Cloud |
|------------|--------|-----|------|-------|
| `payments` | `parentId` ASC, `dueDate` DESC | Parent page query | Already present | Must exist in target project (not deployed this pass) |
| `achievements` | `studentId` ASC, `date` DESC | Paged studentId query | **Added** to `firestore.indexes.json` | **Not deployed** |
| `achievements` | `recipientStudentIds` CONTAINS, `date` DESC | Paged recipients query | **Added** | **Not deployed** |

Until Cloud indexes exist, paged achievements will fail with a failed-precondition / link-to-create-index error (fail closed — not silent empty success).

---

## 10. Remaining risks / deferred

| Item | Why still open |
|------|----------------|
| Supervisor payment-proof fan-out | Rules require per-student queries; Callable/projection is an architecture decision |
| Registration without profile doc | Needs denorm `needsHalaqaAssignment` or callable |
| Achievements legacy docs without `date` | Excluded from ordered pages; full `getAchievements` still covers badges |
| Unbounded `getPayments` / `getAchievements` APIs | Kept for compatibility; UI paths prefer pages |
| Index deploy | Owner / Production gate |

---

## 11. Blocked on Firebase Production

- Deploying the two new achievements composite indexes.  
- Any Production seed / measurement against live billing.  
- Callable redesign for Admin payment-proof / registration projections.

---

## 12. Next step recommendation

1. Deploy **only** the new achievements indexes to the non-prod project when Blaze/owner allows; verify paged achievements on Emulator/`demo-rafiq-rules` first.  
2. Optionally design a **Callable** for pending payment proofs (Admin/Supervisor scoped) to collapse supervisor fan-out.  
3. Add a denorm flag or callable for registration completeness (legacy no-profile).  
4. Optional: Emulator read-counter harness for A/C/D journeys (task F instrumentation).

---

## Findings classification (step 2)

| Bucket | Items |
|--------|-------|
| Confirmed → fixed | A name N+1, B full scan, C unbounded payments, D list paging+indexes file, E cursor tip |
| Existing fixes verified | Chat inbox live window + prior LoadMore wiring (still green) |
| Measurable benefit (contract) | Fewer name gets; fewer registration user reads; bounded payment/achievement first pages |
| Deferred / not justified yet | App-wide SWR cache; supervisor pending Callable without product/AuthZ design |
| Blockers / owner | Cloud index deploy; Production measurement |

**Ahmed note:** This brief asked to **complete deferred D2 work**, not to re-audit D2 or restate the old plan — executed as implementation + tests + this report.
