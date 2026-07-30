# W1 — Production Validation Report

**Date:** 2026-07-25  
**Branch:** `feature/teacher-module-production-cleanup`  
**Method:** Code-level QA + product engineering review (no live device farm).  
**Verdict after fixes:** **W1 Done** for application-layer production readiness, with documented platform gaps.

---

## Scope

Validate the full Daily Lesson & Homework Loop for **Teacher**, **Student**, and **Parent**.

Fix policy: only **small**, **production-safe**, **necessary** gaps. No new features. No W2.

---

## Executive summary

| Actor | Core journey | Result |
|-------|--------------|--------|
| Teacher | Assign → (optional pending) → Review | Pass after P0 fixes |
| Student | Receive → Complete (D8) → See reviewed | Pass (with accepted gaps) |
| Parent | Weekly report reviewed-only | Pass after multi-child race fix |

**P0 failures found and fixed in this validation pass:**

1. Teacher class detail students tab never rebuilt (`buildWhen` omitted students).  
2. Assign/review sheets left stale submission bloc state on dismiss.  
3. Parent multi-child weekly report race (stale overwrite).  
4. Homework overdue showed “متبقي 0 ساعات” instead of late.  
5. Review sheet lacked explicit auth guard.  
6. Missing in-repo `firestore.indexes.json` for W1 queries.

---

## Scenario matrix

Legend: **Pass** / **Fail→Fixed** / **Accept** (known platform/product gap, not a W1 app bug).

### Teacher

| # | Scenario | Expected | Actual (pre-fix) | Result | Root cause | Fix / layer |
|---|----------|----------|---------------------|--------|------------|-------------|
| T1 | Create one assignment | Batch: 1 assignment + 1 notification per student | Implemented end-to-end | **Pass** | — | — |
| T2 | Multiple assignments | Always create new docs; latest `dueDate` is current | Matches D7 | **Pass** | Equal `dueDate` tie undefined | **Accept** (D7) |
| T3 | Empty halaqa | Block assign; show empty students | Assign blocked; **students tab stuck loading** | **Fail→Fixed** | Outer `buildWhen` ignored `students*` | **Presentation** |
| T4 | Offline on send | Arabic network error; no silent success | Repository `NetworkFailure` + snackbar | **Pass** | — | — |
| T5 | Review pending | Same-doc update + student notification | Transaction + UI sheet | **Pass** | — | — |
| T6 | Review twice | Second attempt rejected | Guard: `reviewStatus != pending` | **Pass** | — | — |
| T7 | Live «تقييم جديد» | Still creates graded docs | Separate `.add()` path | **Pass** | Shared submission status if two sheets | **Accept** (one sheet at a time) |
| T8 | Notifications once per op | One notif per student assign; one per review | Atomic batch / txn | **Pass** | Re-assign creates new notif by design | **Accept** |
| T9 | Navigation | Class → تكليف; evals → review | Wired | **Pass** | — | — |
| T10 | Loading/error/success/reset | Full lifecycle | OK when sheet stays open | **Pass** | Dismiss mid-flight left stale state | **Fail→Fixed** (sheet `whenComplete` reset) |
| T11 | Unauthenticated | Cannot assign/review | Router + assign auth check; review lacked check | **Fail→Fixed** | Missing review auth guard | **Presentation** |
| T12 | Sheet dismiss | Reset submission state | No reset on swipe-away | **Fail→Fixed** | No dismiss hook | **Presentation** |

### Student

| # | Scenario | Expected | Actual | Result | Root cause | Fix / layer |
|---|----------|----------|--------|--------|------------|-------------|
| S1 | Receive new homework | Home + Homework latest by `dueDate` | Dual watch SSOT | **Pass** | — | — |
| S2 | Refresh Home/Homework | Re-attach / restart watch | Implemented | **Pass** | — | — |
| S3 | Logout / re-login / restart | Clean uid-bound state | Cold start OK; singleton may flash stale until reload | **Accept** | No logout reset on `@singleton` blocs | Future small lifecycle fix; not W1 feature |
| S4 | Due date passes | Honest overdue label; complete policy clear | Showed “0 hours left”; complete still allowed | **Fail→Fixed** (label) | No overdue copy | **Presentation**; blocking after due = product decision later |
| S5 | Empty states | Honest empty | Home + Homework empty copy | **Pass** | — | — |
| S6 | Offline toggle/complete/load | Error + retry | Load/error/snackbar present | **Pass** | No offline queue | **Accept** |
| S7 | Complete reading+listening only | D8 deferred recitation | `requiredTasks` excludes recitation | **Pass** | — | — |
| S8 | Deferred recitation honesty | No fake upload / pending | Capability gate + dialog | **Pass** | — | — |
| S9 | After real submit (Storage on) | Waiting copy, not fake grade | Subtitle points to evaluations | **Pass** | Path inactive until flag+Blaze | **Accept** (infra) |
| S10 | Reviewed results only | Pending hidden | Client filter + empty honesty | **Pass** | — | — |
| S11 | Notifications inbox | Assign/review appear for uid | Writers + `whereIn` audience | **Pass** | Index must exist in console | **Fail→Fixed** (indexes file) |
| S12 | Navigation | Home → homework / evals | Wired | **Pass** | — | — |
| S13 | Double complete | Reject second | Transaction guard | **Pass** | — | — |
| S14 | Wrong student / unauth | Mutations owner-only | Client queries by uid; mutations by doc id | **Accept** | No `firestore.rules` in repo | **Firestore** platform gap |
| S15 | Progress with deferred | Finish ignores deferred | Entity semantics correct | **Pass** | — | — |

### Parent

| # | Scenario | Expected | Actual | Result | Root cause | Fix / layer |
|---|----------|----------|--------|--------|------------|-------------|
| P1 | Reviewed-only counts/notes | Pending excluded | Datasource filter | **Pass** | — | — |
| P2 | Pending submits excluded | Not in totals | Filter `reviewStatus != pending` | **Pass** | — | — |
| P3 | Placeholder notes hidden | Not as teacher notes | String strip + pending exclude | **Pass** | Blunt `.contains` | **Accept** |
| P4 | Empty week / no children | Honest empty | UI states present | **Pass** | — | — |
| P5 | Offline report | Network error | Repository guard | **Pass** | — | — |
| P6 | Refresh / switch child | Correct child’s report | Race: stale report overwrite | **Fail→Fixed** | No in-flight child guard | **Presentation/Bloc** |
| P7 | Scope = weekly report only | No invented screens | `/parent` home only | **Pass** | — | — |

### Cross-cutting

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| X1 | Duplicate batch / partial assign | **Pass** | Single atomic `batch.commit` |
| X2 | Complete vs review race | **Pass** | Separate docs; submit blocked after complete |
| X3 | Equal dueDate order | **Accept** | D7 |
| X4 | Legacy fake seed docs | **Accept** | New writes clean; historical optional migration |
| X5 | `audioUploadsEnabled` flip | **Pass** | D8 |
| X6 | Design doc inventory drift | **Accept** | Slice 7 map updated; older inventory rows may lag |
| X7 | Firestore indexes | **Fail→Fixed** | Added `firestore.indexes.json` — **must deploy** to project |
| X8 | Firestore security rules | **Accept** | Not in repo; production depends on console rules |

---

## Fixes applied in this validation pass

| Fix | Layer |
|-----|--------|
| Include `students*` in class detail `buildWhen` | Presentation |
| Reset assignment/recitation submission on sheet dismiss | Presentation |
| Auth check on pending review submit | Presentation |
| Parent child-switch clears report + ignores stale emits | Bloc |
| Overdue homework label | Presentation |
| Commit `firestore.indexes.json` for W1 queries | Firestore config |

---

## Remaining non-blockers (explicitly accepted for W1 Done)

1. **Firestore security rules** not versioned in repo — deploy/verify ownership rules outside this PR.  
2. **Singleton logout cleanup** (Student/Notifications blocs) — polish; cold start OK.  
3. **D7 equal-dueDate tie-break** — product-accepted.  
4. **Storage/Blaze off** — D5/D8 by design.  
5. **Parent notify / FCM** — D3 deferred.  
6. **Blocking complete after due date** — label fixed; hard block needs product decision.

---

## Definition of Done checklist

- [x] All actors can complete their W1 part in app code  
- [x] No fake seeds on new assigns  
- [x] Architecture reused (no parallel stacks)  
- [x] Loading / empty / error / retry / refresh audited  
- [x] Validation failures that blocked honesty/UX fixed  
- [x] `flutter analyze` + `dart format` + commit + push  
- [x] Known platform gaps documented (not silently ignored)

**Workflow status: Done.**

---

## Recommended next workflow (W2) — not a screen

**W2 — Attendance Loop (Teacher mark → Parent weekly honesty → Student/parent visibility)**

Why highest value next:

1. Already partially real (`recordAttendance`, parent weekly attendance counts).  
2. Closes another multi-actor academy day ritual alongside homework.  
3. Smaller Storage/infra dependency than audio.  
4. Reuses halaqa students + parent report patterns from W1.

Do **not** start W2 from a Figma attendance mock alone — Phase 0 design + actor journey first, same rules as W1.
