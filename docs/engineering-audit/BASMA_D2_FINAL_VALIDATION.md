# BASMA D2 — Final Validation

**Date:** 2026-11-18
**Branch:** `unify/basma-v1` @ `bb0a90585adb9ee684848cd547cb234cff2a47fa`
**Status:** PASS WITH GAPS
**Staged set:** Isolated to D2-only (mixed hunks split; prior work retained in WT)

## Chat pagination acceptance

Matrix file: `test/features/chat/chat_room_pagination_matrix_test.dart`
Plus existing: `chat_room_bloc_test.dart`, `chat_repository_watch_test.dart`

| Group | Scenarios | Result |
|-------|-----------|--------|
| A Initial | newest-30 only; ascending order; live limit fixed; older not preloaded | PASS |
| B Older pages | sequential walk of 95 msgs to start; no gaps/dupes; no re-fetch of live set; stop after exhaust | PASS |
| C Realtime | new msgs during older fetch retained; tied timestamps deterministic | PASS |
| D Identity | id-based dedupe on overlap | PASS |
| E Lifecycle | droppable single fetch; close ignores late older; new room clean | PASS |
| F Failure | initial stream recover; older fail+retry keeps hasMore | PASS |
| G State | loadingOlder only in flight; hasMore after full older page | PASS |

**Command (targeted):**
`flutter test test/features/chat/chat_room_pagination_matrix_test.dart` → **12/12 PASS**

**Command (chat core, after isolation — omit student_chat_page_test from D2 claim):**
`flutter test test/features/chat/chat_room_bloc_test.dart test/features/chat/chat_conversations_bloc_test.dart test/features/chat/chat_repository_watch_test.dart test/features/chat/chat_room_pagination_matrix_test.dart`

### Can every older page be reached?

Yes — matrix B walks until `hasMore==false` and asserts `seen == full store (95 ids)`. Live window stays at 30 for every step (`watchLimits` all 30).

### Memory / `_byId`

- Buffer holds live + loaded older pages for the open room only.
- Cleared on `close()`; no eviction that drops reachable history while the room is open.
- Design limit: memory grows with scrolled history for one conversation session; Firestore remains source of truth for pages not yet loaded.

## Query bounds — silent truncation review

| Path | Final D2 behavior | Full data reachable? |
|------|-------------------|----------------------|
| Chat messages | fixed 30 + cursor | Yes (load older) |
| Inbox conversations | default pageSize 40 + LoadMore | Yes |
| Recitation evaluations | `fullHistory` documentId pages until exhausted + client date-desc | Yes — includes missing `date` |
| Recitation home feed (non-today) | `newestByDate` + `limit(40)` | Display-only; missing-`date` omitted; history via evaluations |
| Recitation home feed (today) / readiness | `fullHistory` for `pendingReviewCount` | Yes — no silent 100-cap under-count |
| Supervisor payments | page 40 by **document id** until exhausted + concurrency 8 | Yes — includes invoices **without** `dueDate` (pre-D2 `.get()` parity); display sort unchanged |
| Achievements | **not in D2 staged set** (HEAD already unbounded) | N/A for this commit |
| Parent payments | unchanged | Yes |
| Teachers / registration | chunked whereIn; still full scans | N/A (latency, not page cap) |

Contract unit tests: `halaqa_recitation_paging_test.dart` (missing-date + multi-page + ties), readiness beyond-100 pending, `supervisor_payments_paging_test.dart`.

## Indexes

- `fullHistory` uses `orderBy(documentId)` — no date composite required.
- `newestByDate` requires `recitationRecords`: `halaqaId ASC` + `date DESC`.
- That DESC composite exists in **unstaged** dirty `firestore.indexes.json` (not in HEAD; mixed with payment indexes). **Not staged. Cloud deploy status not verified.**

## Analyze

`flutter analyze` on chat + touched datasources: **No issues found** (prior D2 run).

## Full `flutter test`

```text
flutter test
→ +2410 ~3 -44, exit 1
```

Failures are outside D2. Suite is **not** claimed green. Emulator suites **not** re-run for D2 (no rules/functions change in staged set).

## Staged Diff (after isolation — no commit)

**In staged set (D2):** FetchOlder stack; chat room/conversations blocs; DI; admin teachers/registration chunking; teacher recitation paging + maxRecords call sites; supervisor **payments** paging only; D2 docs; D2 tests + signature fakes.

**Explicitly unstaged / left in WT:**
- `BASMA_MASTER_ISSUE_REGISTER.md`, `BASMA_MASTER_REMEDIATION_PLAN.md` (program history)
- Chat hardening (halaqa error helpers, callable map, stream handleError) — WT only
- `submitReport` notification fanout — WT only
- Student achievements rewrite — WT only (not a D2 silent-limit fix vs HEAD)
- `student_chat_page_test.dart` + `student_chat_page.dart` (copy/UX + pageSize call site)
- `firestore.indexes.json`, role inbox UI one-liners, other dirty tree

## Commit readiness

**READY FOR FINAL COMMIT REVIEW** of the isolated staged set. Do not commit until explicit owner approval. Do not push/merge.
