# W3 Slice 2 — Production Validation

**Date:** 2026-07-26  
**Scope:** Homework-assigned readiness on Teacher Day Agenda + architecture verification fixes  
**Verdict after fixes:** **Pass** — Slice 2 production-ready; Slice 3 may begin after explicit approval.

**Predecessors:** W1 Done, W2 Done, W3 Pre-Slice Pass, W3 Slice 1 Pass.

---

## Scope

Validate that Slice 2 (and the pre-Slice-2 architecture hardening) is safe for production as an **orchestration workflow**, not a new module:

- Reuse W1 homework (latest `dueDate` / D7) at halaqa scope
- Reuse W2 day boundaries (`AttendancePolicy`)
- No new collections/fields
- Thin orchestrator only
- `TeacherDayAgenda` remains a read projection

---

## Executive summary

| Area | Verdict |
|------|---------|
| Orchestrator purity | **Pass** after Fail→Fixed (id parsing, day predicate, empty-roster homework) |
| Homework readiness reuse | **Pass** — extends teacher DS; same D7 ordering as student latest query |
| Firestore schema | **Pass** — no new fields/collections |
| Index | **Pass** — `assignments(halaqaId, dueDate)` documented + justified; **must deploy** |
| Deep-links | **Pass** — existing routes only |
| Loading / empty / error / retry / refresh | **Pass** after Fail→Fixed (refresh waited only for halaqat) |
| Remaining-work honesty after writes | **Pass** after Fail→Fixed (agenda re-derived on attendance / assign / review success) |
| W1 / W2 regression | **Pass** — student `map()` and existing attendance/homework paths unchanged |
| Analyze / tests | **Pass** |

---

## Scenario matrix

Legend: **Pass** / **Fail→Fixed** / **Accept**

### Architecture

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| A1 | No duplicated attendance completeness | Owned by `AttendancePolicy.isRegisterComplete` | **Pass** | Moved out of use case in pre-Slice-2 audit |
| A2 | No duplicated homework due-date rule | Latest `dueDate` (W1 D7); day compare via `AttendancePolicy.isSameCalendarDay` | **Pass** after Fail→Fixed | Removed private `_isLatestDueToday` |
| A3 | No duplicated agenda derivation / D7 sort | Single `mapTodayOperationalDays` call | **Pass** | |
| A4 | No fragile operational-day id parsing | Explicit `TodayOperationalDay.halaqaId` | **Fail→Fixed** | Mapper returns typed `halaqaId` |
| A5 | `GetTodayAgendaUseCase` thin orchestrator | Reads + policy calls + projection only | **Pass** | |
| A6 | `TeacherDayAgenda` is read projection | Under `domain/read_models`; no business methods | **Pass** | |
| A7 | Homework reuses assignment infrastructure | `getLatestAssignmentDueDate` on teacher repo/DS | **Pass** | Same collection + D7 order as student |

### Product / workflow

| # | Check | Expected | Result | Notes |
|---|--------|----------|--------|-------|
| P1 | No assignment → sendHomework | Neutral «لم يتم إرسال واجب اليوم» | **Pass** | |
| P2 | Latest dueDate on today → no sendHomework | Removed from actionable agenda | **Pass** | End-of-day dueDate from assign sheet |
| P3 | Newer future dueDate as latest | Still needs today's assign (W1 D7) | **Accept** | Same as student "current" = latest dueDate |
| P4 | Empty roster | Never attendance or homework action | **Fail→Fixed** | Aligns with `sendAssignment` empty guard |
| P5 | Deep-link sendHomework | Existing `/teacher/halaqa/:id` only | **Pass** | Sheet open = Slice 3 |
| P6 | Deep-link attendance / reviews | Existing routes | **Pass** | |
| P7 | Pull-to-refresh | Waits for halaqat **and** agenda | **Fail→Fixed** | Was dismissing early |
| P8 | Agenda section error | Retry via `LoadTodayAgendaEvent` | **Pass** | |
| P9 | Honest empty | No session vs no remaining work | **Pass** | |
| P10 | After save attendance / assign / review | Agenda re-derives (remaining work drops) | **Fail→Fixed** | `LoadTodayAgendaEvent` on success |

### Firestore / platform

| # | Check | Result | Notes |
|---|--------|--------|-------|
| F1 | No new collections | **Pass** | |
| F2 | No new fields | **Pass** | Uses existing `halaqaId` + `dueDate` |
| F3 | New composite index required | **Pass** / **Must deploy** | `halaqaId` ASC + `dueDate` DESC |
| F4 | Why student query cannot suffice | **Pass** | Student-scoped latest cannot answer per-halaqa readiness without N reads and is not halaqa-level D7 |

### Cross-cutting

| # | Check | Result |
|---|--------|--------|
| X1 | `flutter analyze` on touched code | **Pass** (pre-existing `withOpacity` infos only) |
| X2 | Unit tests (agenda + policy + mapper) | **Pass** |
| X3 | Full `flutter test` | **Pass** |
| X4 | W1 student latest homework query untouched | **Pass** |
| X5 | W2 attendance save/read untouched in semantics | **Pass** |

---

## Fixes applied in this validation pass

1. **`TodayOperationalDay`** — mapper returns explicit `halaqaId`; use case no longer parses session ids.  
2. **`AttendancePolicy.isSameCalendarDay`** — homework day check uses W2 day SSOT; no private due-date policy in the orchestrator.  
3. **Empty roster** — skip `sendHomework` (matches existing `sendAssignment` refusal).  
4. **RefreshIndicator** — wait until agenda loaded/error after halaqat success.  
5. **Agenda invalidate** — re-derive after successful attendance save, assignment send, and recitation review/add.

---

## Remaining non-blockers (Accept)

| Item | Why accepted |
|------|----------------|
| `sendHomework` opens class detail, not the assign sheet | **Superseded by Slice 3** — `?assign=1` opens the existing sheet |
| Latest dueDate in the future hides an older "today" assign | Exact W1 D7 semantics at halaqa scope (D3). |
| Recitation readiness still loads full halaqa history | Same read as evaluations page; optimize later if needed. |
| Index must be deployed to Firebase project | Same platform gap pattern as W1/W2 indexes. |

---

## Definition of Done checklist (Slice 2)

- [x] No duplicated business rules  
- [x] Thin orchestrator  
- [x] Read projection (not domain entity)  
- [x] Homework reuses assignment infrastructure  
- [x] No new Firestore fields/collections  
- [x] Required index documented and justified  
- [x] Deep-links reuse existing routes  
- [x] Loading / empty / error / retry / refresh consistent  
- [x] No W1/W2 regression  
- [x] analyze clean (touched code)  
- [x] Relevant tests added and passing  
- [x] Docs updated; committed; pushed  

**Slice 2 = Pass.** Do not start Slice 3 until explicitly approved (this document records Pass so Slice 3 may begin when product owner says go).
