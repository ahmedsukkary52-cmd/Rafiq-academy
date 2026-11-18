# BASMA D2 — Implementation Report

**Final engineering status:** PASS WITH GAPS
**Scope:** Chat cursor pagination, Firebase query bounds / N+1, listener lifecycle in chat/inbox, tests, docs.
**Out of scope (honored):** D1/D3/D4, cloud deploy, schema migrations, Quran/Mushaf, auto-commit.

## Phase 0 — Git baseline

| Item | Value |
|------|-------|
| Branch | `unify/basma-v1` |
| HEAD | `bb0a90585adb9ee684848cd547cb234cff2a47fa` |
| Working tree | Large dirty set (D0 docs/tests + prior role UI + D2 edits). No reset/stash/clean/commit performed. |
| Staged set | Isolated to D2-only hunks after mixed-file split (see Final Validation). |

## What shipped

### Chat pagination (BASMA-103) — DONE

Fixed live window + `fetchMessagesBefore` cursor; live watch limit never grows; merge buffer + droppable older fetch; D2 matrix green. Details: `BASMA_D2_CHAT_PAGINATION_REPORT.md`.

### Query / N+1 (BASMA-104/107) — PARTIAL

| Area | Behavior |
|------|----------|
| Inbox | `defaultInboxPageSize = 40` + existing LoadMore |
| Teachers profiles | Chunked `whereIn` (still full teacher scan) |
| Registration | Chunked parallel profiles (still full active-student scan; denorm deferred) |
| Recitation evaluations | `fullHistory` documentId pages (`maxRecords: null`) |
| Recitation home feed (non-today) | `newestByDate` + `maxRecords: 40` (bounded date query) |
| Recitation day readiness / today feed facts | `fullHistory` for `pendingReviewCount` |
| Supervisor payments | Page 40 by document id until exhausted + concurrency 8 |
| Student achievements | **Not part of D2 staged set** (HEAD already unbounded; WT rewrite is separate UX/resilience) |

Deferred items: `BASMA_D2_FIREBASE_QUERY_REMEDIATION.md`.

### Listener lifecycle — REVIEWED / SMALL FIXES

- `ChatRoomBloc`: clear merge buffer; stale older-request guard; keep `loadingOlder` across live ticks; `droppable()` on load-older.
- `ChatConversationsBloc`: empty live window clears stale older pages.
- Singleton inbox `@singleton` + `restartable()` retained; logout session fence unchanged.

## Gaps (open)

1. Registration still scans all active students (needs schema/CF).
2. Parent payments / listHalaqat / notifications `readBy` deferred.
3. Non-today Home Feed uses bounded `newestByDate` (missing-`date` omitted). Today/readiness still full-walk for pending counts (denorm = product decision).
4. Required `halaqaId ASC + date DESC` exists in unstaged mixed `firestore.indexes.json` — **not staged; Cloud status not verified**.
5. Chat older-buffer revalidation is **single-id** after local edit/delete (not full-buffer getAll). Peer older mutations remain non-realtime without a conversation signal.
6. Full `flutter test` remains non-green on WT outside D2 staged paths.
7. Prior UX (chat hardening, `submitReport` fanout, student chat copy, role inbox call sites) remains unstaged.

## Independent review notes

- Pagination merge prefers live over older for same id — correct for edits.
- Empty inbox merge fix prevents ghost threads when default limit is on.
- Supervisor `byId` map mutated from concurrent futures — safe on Dart single isolate.
- DI config patched manually for `FetchOlderMessagesUseCase`; recommend `build_runner` on next clean codegen pass.

## Related docs

- `BASMA_D2_CHAT_PAGINATION_REPORT.md`
- `BASMA_D2_FIREBASE_QUERY_REMEDIATION.md`
- `BASMA_D2_TEST_RESULTS.md`
- `BASMA_D2_FINAL_VALIDATION.md`
