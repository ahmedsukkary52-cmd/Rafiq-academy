# W3 Slice 3 — Production Validation

**Date:** 2026-07-26  
**Scope:** Assign-sheet deep-link (`/teacher/halaqa/:id?assign=1`) on existing class detail  
**Verdict after fixes:** **Pass** — Slice 3 production-ready. Do **not** start Slice 4 until explicitly approved.

**Predecessors:** W1 Done, W2 Done, W3 Pre-Slice/Slice 1/Slice 2 Pass.

---

## Scope

Validate that Slice 3 only **orchestrates navigation into the existing W1 assign sheet**, without a second entry path, duplicate dialogs/submissions, or agenda desync.

---

## Executive summary

| Area | Verdict |
|------|---------|
| Deep-link reuses existing assign flow | **Pass** — same `_openSendAssignmentSheet` / `_SendAssignmentSheet` / `SendAssignmentEvent` |
| No second entry path / duplicated routing | **Pass** — query flag on existing `halaqa/:halaqaId` route only |
| Agenda sync after assign / attendance / review | **Pass** — `LoadTodayAgendaEvent` on those successes (Slice 2); dashboard listens to `todayAgenda*` |
| No duplicate sheets / submissions | **Pass** after Fail→Fixed |
| No stale-roster auto-open | **Pass** after Fail→Fixed |
| Empty / error / loading consistent | **Pass** |
| W1 / W2 regression | **Pass** |
| Analyze / tests | **Pass** |

---

## Scenario matrix

Legend: **Pass** / **Fail→Fixed** / **Accept**

### Deep-link & routing

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| D1 | `?assign=1` opens existing sheet | Same bottom sheet as class-detail button | **Pass** | |
| D2 | No new assign route / page | Query on existing path only | **Pass** | |
| D3 | Agenda `sendHomework` URL | `/teacher/halaqa/:id?assign=1` | **Pass** | |
| D4 | Without query | Sheet does not auto-open | **Pass** | `openAssignSheet` default false |
| D5 | Empty roster deep-link | Snackbar; no sheet | **Pass** | Existing guard |

### Duplicate / race safety

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| R1 | Auto-open against previous halaqa's loaded roster | Must not open | **Fail→Fixed** | `studentsHalaqaId` + `AssignSheetDeepLinkGate` |
| R2 | Auto-open only once per page visit | One sheet | **Pass** after Fail→Fixed | Gate `hasOpened` |
| R3 | Deep-link + manual button while sheet open | No stacked sheets | **Fail→Fixed** | `_assignSheetVisible` |
| R4 | Rapid double-tap submit | Single `SendAssignmentEvent` | **Fail→Fixed** | Submit status guard + disabled button |
| R5 | Concurrent student loads | Ignore stale response | **Fail→Fixed** | Same pattern as day-attendance date guard |

### Agenda synchronization

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| A1 | After successful assign | Agenda re-derives | **Pass** | Bloc success → `LoadTodayAgendaEvent` |
| A2 | After attendance save | Agenda re-derives | **Pass** | Slice 2 |
| A3 | After review / add recitation | Agenda re-derives | **Pass** | Slice 2 |
| A4 | Return to dashboard (pop) | Sees updated agenda without pull | **Pass** | Singleton bloc + IndexedStack dashboard |
| A5 | Pull-to-refresh | Waits for halaqat + agenda | **Pass** | Slice 2 fix |

### Navigation & states

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| N1 | Pop from class detail | Returns to previous route | **Pass** | Standard GoRouter |
| N2 | Dismiss sheet without submit | Reset submission; agenda unchanged | **Pass** | `whenComplete` reset |
| N3 | Students loading | Loading UI; no premature sheet | **Pass** after Fail→Fixed |
| N4 | Students error | Error + retry; no sheet | **Pass** | |
| N5 | Halaqat loading / error | Existing scaffolds | **Pass** | Unchanged |

### Cross-cutting

| # | Check | Result |
|---|--------|--------|
| X1 | No duplicated assignment business logic | **Pass** — W1 write path untouched |
| X2 | No duplicated agenda derivation | **Pass** |
| X3 | `flutter analyze` on touched code | **Pass** (pre-existing infos only) |
| X4 | Gate unit tests | **Pass** |
| X5 | Full `flutter test` | **Pass** |

---

## Fixes applied in this validation pass

1. **`studentsHalaqaId` on `TeacherState`** — set when loading/loaded students; stale responses ignored (parity with `dayAttendanceDate`).  
2. **`AssignSheetDeepLinkGate`** — opens once only when `studentsStatus == loaded` **and** `studentsHalaqaId == page.halaqaId`.  
3. **Removed unsafe “open on any loaded” post-frame path** — post-frame only observes status; never opens against a foreign roster.  
4. **`_assignSheetVisible`** — prevents stacked sheets from deep-link + button / double open.  
5. **Submit re-entry guard** — ignore tap while `assignmentSubmissionStatus == submitting`.

---

## Remaining non-blockers (Accept)

| Item | Why accepted |
|------|----------------|
| Query param stays in URL after sheet opens | Harmless; one-shot gate prevents re-open on rebuild |
| No widget/integration golden for the sheet | Gate + existing W1 submit path covered; full UI pump deferred |
| Index deploy for Slice 2 homework readiness | Platform ops; unchanged by Slice 3 |

---

## Definition of Done checklist (Slice 3)

- [x] Deep-link only reuses existing assignment flow  
- [x] Agenda stays synchronized after assign / attendance / review  
- [x] No duplicate dialogs or duplicate submissions  
- [x] Navigation back from class detail correct  
- [x] Empty / error / loading consistent  
- [x] No duplicated routing / assignment / agenda logic  
- [x] No W1/W2 regression  
- [x] analyze clean (touched code)  
- [x] Tests updated and passing  
- [x] Docs updated; committed; pushed  

**Slice 3 = Pass.** Stop here — Slice 4 requires explicit approval.
