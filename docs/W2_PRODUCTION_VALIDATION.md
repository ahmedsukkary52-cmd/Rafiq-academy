# W2 — Production Validation Report

**Date:** 2026-07-25  
**Branch:** `feature/teacher-module-production-cleanup`  
**Method:** Code-level QA + product engineering review (no live device farm).  
**Verdict after fixes:** **W2 Done** for application-layer production readiness, with documented platform gaps.

---

## Scope

Validate the full Attendance Loop for **Teacher → Student → Parent**.

Approved decisions applied: D1 (late = attended, one shared rule), D2 (no notifications), D3 (no استئذان UI), D4 (no supervisor), D6 (no excused status), D7 (calendar day), D8 (deterministic IDs, no new fields).

Fix policy: only **small**, **production-safe**, **necessary** gaps. No new features. No W3.

---

## Executive summary

| Actor | Core journey | Result |
|-------|--------------|--------|
| Teacher | Mark day register → atomic save → reload | Pass after P0 date-race fix |
| Student | Progress report 30-day attendance | Pass after 30-day boundary fix |
| Parent | Weekly attended / total / % | Pass (policy + dedupe + honesty copy) |

**P0 failures found and fixed in this validation pass:**

1. Teacher date change / concurrent load could overwrite the wrong day’s register map.  
2. Teacher could change date while a save was in flight.

**P1 gaps fixed in this validation pass:**

1. Student “آخر ٣٠ يوماً” queried 31 calendar days.  
2. Analytics “weekly” chart aggregated the full month by weekday.  
3. At-risk absence counts used raw docs (legacy dupes) and claimed “consecutive”.  
4. Weekly chart drew a non-zero bar for 0%.  
5. Oversized day batch had no clear preflight error.

---

## Shared policy (D1)

| Surface | Uses `AttendancePolicy` | Late = attended | Day dedupe |
|---------|-------------------------|-----------------|------------|
| Parent weekly | Yes | Yes | Yes |
| Student progress | Yes | Yes | Yes |
| Teacher analytics % / weekly | Yes | Yes | Yes |
| Teacher day register counters | Status counts only (not %) | N/A | Load prefers deterministic id |

No remaining duplicate attendance-% implementations in active paths.

---

## Scenario matrix

Legend: **Pass** / **Fail→Fixed** / **Accept** (known platform/product gap).

### Teacher

| # | Scenario | Expected | Result | Notes |
|---|----------|----------|--------|-------|
| T1 | Load roster + day marks | Loading → register | **Pass** | |
| T2 | Empty halaqa | Honest empty; Save off | **Pass** | |
| T3 | Load failure | Error + retry | **Pass** | |
| T4 | Must mark every student | Save blocked until all selected | **Pass** | |
| T5 | Save full day | Single atomic batch; deterministic IDs | **Pass** | |
| T6 | Offline save | Error; no silent success | **Pass** | NetworkFailure path |
| T7 | Double-submit same marks | Idempotent; no dup docs | **Pass** | D8 |
| T8 | Legacy auto-id duplicate | Deterministic wins; legacy deleted on save | **Pass** | |
| T9 | Change date during save | Blocked / no wrong-day overwrite | **Fail→Fixed** | Disable nav + `dayAttendanceDate` guard |
| T10 | Rapid date changes | Only selected day syncs map | **Fail→Fixed** | Stale load ignored |
| T11 | Unowned halaqa write | Denied by server rules | **Accept** | Rules not in repo (same as W1) |
| T12 | Huge roster (>~500 ops) | Clear error; no partial write | **Fail→Fixed** | Preflight refuse |

### Student

| # | Scenario | Expected | Result | Notes |
|---|----------|----------|--------|-------|
| S1 | No attendance in range | Honest empty attendance | **Pass** | |
| S2 | Late record | Counts as attended | **Pass** | D1 |
| S3 | Legacy duplicate | Count once | **Pass** | |
| S4 | “آخر ٣٠ يوماً” | Exactly 30 calendar days | **Fail→Fixed** | lookback − 1 |
| S5 | Load error | Error + retry | **Pass** | |
| S6 | Honesty copy | Late included in attendance | **Pass** | Label on card |

### Parent

| # | Scenario | Expected | Result | Notes |
|---|----------|----------|--------|-------|
| P1 | Empty week | Honest empty | **Pass** | |
| P2 | Late record | Included as attended | **Pass** | D1 |
| P3 | Legacy duplicate | Count once | **Pass** | |
| P4 | Child switch while loading | No other child’s report | **Pass** | W1 race guard |
| P5 | Honesty copy | Late included | **Pass** | Caption under metrics |
| P6 | Scope = weekly report only | No invented attendance history | **Pass** | D3 out |

### Analytics (teacher read)

| # | Scenario | Expected | Result | Notes |
|---|----------|----------|--------|-------|
| A1 | Overall attendance % | Policy + dedupe + late | **Pass** | |
| A2 | Weekly bars | Last 7 calendar days only | **Fail→Fixed** | |
| A3 | 0% day | No fake bar height | **Fail→Fixed** | |
| A4 | Repeated absence risk | Dedupe; non-consecutive wording | **Fail→Fixed** | |

### Cross-cutting

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| X1 | No new collections / fields | **Pass** | |
| X2 | No notification writers (D2) | **Pass** | Deferred |
| X3 | No استئذان / supervisor (D3/D4) | **Pass** | |
| X4 | `firestore.indexes.json` attendance composites | **Pass** | **Must deploy** to project |
| X5 | Firestore security rules | **Accept** | Not versioned in repo |

---

## Fixes applied in this validation pass

| Fix | Layer |
|-----|--------|
| Track `dayAttendanceDate`; ignore stale day loads | Bloc + presentation |
| Disable date nav / picker while saving; require loaded day match before Save | Presentation |
| 30-day progress window = today − 29 … today | Data |
| Weekly analytics = last 7 calendar days | Data |
| At-risk absences deduped; copy = “خلال آخر أسبوعين” | Data + domain label |
| Zero % weekly bar height = 0 | Presentation |
| Batch size preflight refuse (>500 ops) | Data |

---

## Remaining non-blockers (explicitly accepted for W2 Done)

1. **Firestore security rules** not versioned in repo — deploy/verify ownership rules outside this PR.  
2. **Indexes must be deployed** from `firestore.indexes.json` to the Firebase project.  
3. Same-child parent reload token hardening — low impact without pull-to-refresh.  
4. Absence notifications (D2), استئذان UI (D3), supervisor unmarked registers (D4) — deferred by approval.  
5. No attendance-focused automated tests yet.

---

## Workflow Done criteria

- [x] Single shared attendance rule (`AttendancePolicy`) for all actor percentages  
- [x] Teacher day save atomic + deterministic IDs  
- [x] Parent weekly + student progress aligned and honest  
- [x] Consistency audit + production validation documented  
- [x] Analyze → format → commit → push for each slice  

**W2 status: Done.**
