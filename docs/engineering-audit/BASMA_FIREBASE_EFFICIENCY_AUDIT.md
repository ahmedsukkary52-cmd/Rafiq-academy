# BASMA Firebase Efficiency Audit (Stage A)

**Date:** 2026-11-16  
**Reconciles:** [docs/production/FIREBASE_SCALABILITY_AUDIT.md](../production/FIREBASE_SCALABILITY_AUDIT.md) (baseline `69e4207`) against **current** tree + Trial runtime evidence.  
**No cloud deploy / no code changes.**

---

## 1. Verified facts (current tree)

### 1.1 Chat messages / conversations

- `watchMessages`: bounded `limit` (room starts ~30) — **Resolved** vs “load entire history on open.”
- `ChatRoomBloc` “load older” **increases `limit` and restarts the watch** — **Confirmed Issue (BASMA-103)**; no hard cap noted.
- Admin inbox: **Resolved in UI** with `adminInboxPageSize` (30) + `fetchConversationsAfter` cursor; `watchAllConversations(limit==null)` still unbounded (**Potential Risk** / BASMA-104).
- Role `watchConversations`: **Confirmed Issue** — home/message tabs often omit `pageSize`, so per-user conversation listeners are unbounded (acceptable only while few threads).

### 1.2 Payments

- Admin `getPayments` / ledger page: **Resolved** vs full collection (`limit` 20 + cursor).
- Summary aggregates: **Existing Known** live index gap (BASMA-101).
- Parent `getPayments` (`parentId` + orderBy, **no limit**): **Potential Risk**.
- Supervisor `getPaymentsForStudents` / pending proofs: **Confirmed Issue** — per-student queries (N+1) and/or unbounded pending sets; supervisor path also N+1 user name reads ([Firebase inventory](05a5586a-e62b-4afb-8ba2-9221951668af)).

### 1.3 Trial-confirmed expensive / failing queries (live `rafiq-academy`)

| Query | Result | Taxonomy | Source |
|-------|--------|----------|--------|
| `complaints` status IN + orderBy createdAt | FAILED_PRECONDITION | Confirmed Issue (Index not deployed) | Runtime diagnosis |
| `payments` aggregate sum(amount) by status | FAILED_PRECONDITION | Confirmed Issue | Runtime + REST |
| `halaqat` coverTeacherId + coverId | FAILED_PRECONDITION | Confirmed Issue (index in repo, not live) | logcat |
| `absenceRequests` halaqaId + date | FAILED_PRECONDITION | Confirmed Issue | Supervisor logcat |
| Callables (attendance, chat send, etc.) | HTTP 404 | Confirmed Issue (Functions unpublished) | REST + device |

### 1.4 Additional Confirmed / Potential query risks (current tree)

| Area | Label | Note |
|------|-------|------|
| Teacher `getHalaqaRecitationRecords` / roster recitation | Confirmed Issue | `halaqaId` only, **no limit** — history grows unbounded |
| Admin `getRegistrationRequests` | Confirmed Issue | Scans all active students then N profile/email reads |
| `listUsersByRole` / `getAllTeachers` | Confirmed Issue | Unbounded role lists; teachers N+1 profiles |
| `listHalaqat` | Potential Risk | No filter/limit |
| Student achievements dual queries | Potential Risk | Often unbounded then merge |
| Notifications `readBy` arrayUnion | Confirmed Issue | Shared docs grow with every reader |
| Repo indexes file | Measured | **45** composite indexes defined; cloud deploy still gated |

### 1.5 Still directionally true from historical scalability audit

- Large `halaqat.studentIds` arrays as scale ceiling.
- Default Firestore persistence; no app-level SWR policy documented.
- Dollar cost under assumed academy sizes often modest vs Blaze floor; **failure mode is index errors + slow screens**, not necessarily five-figure bills (Assumed model in agent annex).

---

## 2. Measured results

| Metric | Value | Notes |
|--------|-------|-------|
| Trial admin active halaqat count | 9 (then cleaned empty → 5) | Device + REST; empty halaqas deleted later same day by owner request |
| Trial student user list visible | 25 docs | Rules gap — security report |
| Chat message watch | limited | Measured from code, not profiler |

**No production cost dashboard numbers** were pulled this Stage — cost model below is **Assumed**.

---

## 3. Assumed usage / cost model

Assumptions (explicit):

- 1 academy; average 2 halaqat/teacher; 15 students/halaqa; parent opens app 1×/day; teacher session 1×/day; chat 20 messages/day/active conversation; admin opens dashboard 5×/day.
- Each home open ≈ 5–40 document reads depending on role (Trial shows non-trivial fan-out).
- Growing chat “load older” doubles window reads each page (Confirmed pattern).

| Users (students≈) | Inferred daily reads order | Primary drivers |
|-------------------|----------------------------|-----------------|
| 100 | Low thousands | Per-user listeners + admin aggregates |
| 500 | Mid tens of thousands | Admin payments/chat oversight + chat windows |
| 1,500 | High tens–low hundreds of thousands | Unbounded admin paths + large history |
| 5,000–10,000 | Not viable without pagination, indexes, projected summaries | Finance O(n), chat history, roster arrays |

Label: **Inferred** — not measured billing export.

---

## 4. Recommendations (priority for Stage D planning)

1. **P0/P1:** Deploy indexes (owner approval) matching repo + payment sum composites.
2. **P1:** Replace chat load-older growing-limit with `startAfterDocument` older page + keep small live window.
3. **P1:** Forbid `watchAllConversations` without limit; always page admin inbox.
4. **P2:** Summary docs / server aggregates for admin dashboards instead of multi-query client merges.
5. Do not enable more realtime listeners without lifecycle ownership proof.

---

## 5. Unresolved questions

- Exact read counts per role session on emulator with Seed — Blocked Verification (not run this Stage A pass).
- Whether all awards/calendar unbounded gets remain after recent dirty-tree changes — needs file-by-file Stage D spike.
