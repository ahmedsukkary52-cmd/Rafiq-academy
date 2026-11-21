# BASMA D2 — Firebase Efficiency Audit & Remediation

**Date:** 2026-11-20  
**Branch / HEAD:** `unify/basma-v1` @ `8ce64fe` (dirty working tree preserved; no git mutations, no Production/Cloud)  
**Emulator project (when used):** `demo-rafiq-rules` only  
**Prior baselines reused:** `BASMA_D2_*` reports, `BASMA_FIREBASE_EFFICIENCY_AUDIT.md`, `BASMA_CHAT_SYSTEM_AUDIT.md`, commit `daa8f85`  
**Verdict:** **PASS WITH GAPS**

---

## 1. Repository state at start

| Item | Value |
|------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe` |
| Working tree | Dirty (large WT from prior phases; preserved; no reset/stash/checkout) |
| Cloud / deploy | Not touched |

---

## 2. Audited areas and files

| Area | Primary files |
|------|----------------|
| Chat messages pagination | `chat_room_bloc.dart`, `chat_remote_datasource.dart` (`watchMessages` / `fetchMessagesBefore`) |
| Chat inbox pagination | `chat_conversations_bloc.dart`, role message tabs, `admin_chat_inbox_page.dart` |
| Chat listeners lifecycle | `ChatConversationsBloc` (restartable + ClearSession), `ChatRoomBloc.close`, `chat_room.dart` `_metaSub` |
| Admin oversight stream | `watchAllConversations` |
| Related deferred paths | Parent `getPayments`, student `getAchievements`, prior D2 recitation/supervisor payments |

---

## 3. Confirmed findings (by severity)

### High

| ID | Finding | Evidence | Impact |
|----|---------|----------|--------|
| D2-E-01 | Role inboxes used `pageSize=40` but **never called** `LoadMoreConversationsEvent` | Teacher / supervisor / parent message tabs had no scroll/footer wiring; only Admin inbox did | Threads older than the live window were **unreachable** while reads stayed capped — incomplete product behavior after D2 bounding |
| D2-E-02 | `watchAllConversations(limit: null)` still offered an **unbounded** academy-wide snapshot path | `chat_remote_datasource.dart` legacy branch (pre-fix) | Latent full-collection listener if any caller omitted limit |
| D2-E-09 | Teacher roster `getHalaqaStudents` loaded **all** `recitationRecords` for a halaqa | `teacher_remote_datasource_impl.dart` (pre-fix); confirmed by [Find unbounded Firestore queries](bbdf46fd-1ee8-41cb-8bee-81bb78964cb0) | Lifetime history growth on every class-detail open |
| D2-E-10 | Admin payment-proof review: unbounded pending + per-student serial queries + N+1 name reads | `admin_operations_remote_datasource_impl.dart` | Latency/reads scale with roster × pending — **deferred** (callable/product) |
| D2-E-11 | Registration requests: scan all active students then serial private-email reads | `admin_remote_datasource_impl.dart` | Full student fan-out — **deferred** (needs projection/callable) |

### Medium (investigated; deferred or already mitigated)

| ID | Finding | Notes |
|----|---------|--------|
| D2-E-03 | Parent `getPayments` unordered by limit | Unbounded `parentId` + `orderBy(dueDate)` — typically small; cursor UI needs product decision |
| D2-E-04 | Student achievements dual unbounded queries | Documented in prior D2 as out of staged set; needs indexes + cursor UI |
| D2-E-05 | Teacher Plus related-people fan-out | Batched `Future.wait` + one parent-links call; acceptable for assigned halaqat; no durable cache without membership version |

### Low / already correct

| ID | Finding | Notes |
|----|---------|--------|
| D2-E-06 | Chat room “load older” growing listener | **Already fixed** (BASMA-103): fixed live 30 + cursor older pages — re-verified in code + matrix tests |
| D2-E-07 | Inbox call sites omitting pageSize | **Already mitigated**: bloc defaults to 40; role homes/tabs pass `defaultInboxPageSize` |
| D2-E-08 | Room meta / upload subscriptions | `_metaSub.cancel` + `ChatRoomBloc.close` cancel uploads — verified in code |

---

## 4. Investigated — no change required this phase

- Chat message cursor pagination + realtime-during-older (prior matrix **12/12**).
- Admin inbox load-more already present.
- Attachment Emulator lifecycle (separate audit) — not re-run; no efficiency defect claimed there.
- Speculative app-wide SWR/cache — deferred until membership invalidation SSOT exists.

---

## 5. Fixes implemented (this phase)

| Fix | Root cause | Change | Regression |
|-----|------------|--------|------------|
| Role inbox Load More | Bound window without UI paging | `ChatInboxLoadMoreBinding` + footer; wired into **teacher**, **supervisor**, **parent** message tabs | Role inbox paging test + existing admin paging |
| Forbid unbounded admin watch | Legacy null-limit stream | `watchAllConversations` always `orderBy(lastMessageAt).limit(page)` with default **40** | Existing watch/paging tests |
| Teacher roster recitations | Lifetime `halaqaId`-only get | Same 30-day window as attendance + `orderBy(date desc)` (index already in repo) | `teacher_roster_recitation_bound_test.dart` |

**Not changed:** security rules, schema, Production, parent payments pagination, achievements cursors, admin payment-proof / registration N+1 (D2-E-10/11 — need callable or projected lists).

---

## 6. Before / after measurements

| Metric | Kind | Before | After |
|--------|------|--------|-------|
| Role inbox live listener window | Code / contract | 40 docs (bounded) | 40 docs (unchanged) |
| Role inbox older threads reachable | Product completeness | **No** (no LoadMore UI) | **Yes** (scroll + button → `LoadMoreConversationsEvent`) |
| Admin `watchAllConversations(null)` | Code path | Unbounded collection snapshots | Forced limit 40 |
| Chat room live message reads per open | Code (prior D2) | Fixed 30 | Unchanged |
| Teacher roster recitation reads | Code | Unbounded `halaqaId` get | Date ≥ now−30d + orderBy date |
| Firestore read counts on Emulator for a 50-thread inbox journey | **Not measured** this pass | — | Deferred (instrumentation gap) |

Labels: **Code/contract** vs **Measured**. No Production profiler.

---

## 7. Tests executed (exact)

```text
flutter test \
  test/features/chat/chat_groups_messaging_test.dart \
  test/features/chat/chat_conversations_bloc_test.dart \
  test/features/chat/chat_room_pagination_matrix_test.dart \
  test/features/chat/chat_room_bloc_test.dart \
  test/features/chat/chat_repository_watch_test.dart \
  test/features/teacher/teacher_messages_tab_test.dart \
  test/features/teacher/teacher_messages_group_inbox_test.dart
→ All tests passed! (+72)
```

Includes new case: `role inbox paging (participant filter) LoadMore uses participantUid…`.

Follow-up after codebase scan ([Find unbounded Firestore queries](bbdf46fd-1ee8-41cb-8bee-81bb78964cb0)):

```text
flutter test test/features/teacher/teacher_roster_recitation_bound_test.dart
```

Not re-run: full Flutter suite, Emulator Node suites (no Functions/rules change).

**Note:** The scan’s “Supervisor/Parent missing LoadMore” finding was already fixed in the same D2 pass before the scan finished; current tree wires `ChatInboxLoadMoreBinding` on teacher, supervisor, and parent.

---

## 8. Remaining risks / unverified

| Item | Status |
|------|--------|
| Device-level listener counts / DevTools timeline | NOT TESTED |
| Emulator measured read counts for inbox LoadMore journey | NOT MEASURED |
| Parent payments / achievements bounding | DEFERRED |
| Docs without `lastMessageAt` in admin oversight after always-`orderBy` | Edge: empty/null lastMessageAt sort last in Firestore; previously client-sorted unbounded set — acceptable with LoadMore for older activity |
| Flutter ↔ Emulator E2E | BLOCKED (existing prerequisite) |

---

## 9. Intentionally deferred

- Parent payment history pagination UI.
- Achievements cursor + composite indexes productization.
- Admin payment-proof review N+1 / registration full-student scan (D2-E-10/11) — prefer authorized callables or projections, not silent client caps.
- App-level roster/person cache with membership invalidation.
- Broad non-chat datasource sweep beyond confirmed High items.

---

## 10. Final verdict

### **PASS WITH GAPS**

High-impact chat efficiency/completeness gap (bounded inbox without LoadMore on role tabs) is fixed; unbounded admin watch legacy path removed; prior chat message cursor design remains intact and re-tested.

Gaps remain for non-chat unbounded lists, measured Emulator read tallies, and device profiling — so not a blanket PASS.
