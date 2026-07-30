# W7 Slice 2 — Teacher Request Classification · Production Validation

**Status:** Pass  
**Date:** 2026-07-29  
**Design:** `docs/W7_PHASE0_DESIGN.md` (Rule 1 locked · D-W7-1 / D-W7-3)  
**Scope:** Slice 2 only — teacher pending queue + approve/reject as **request classification**; attendance decided independently

---

## Locked rule (before implementation)

**Rule 1 — Teacher decisions classify the request, not attendance.**

- Approve/reject changes **only** the absence request.  
- Attendance remains the only operational presence record.  
- The workflow never infers or rewrites attendance from a request decision.

---

## What shipped

| Artifact | Role |
|----------|------|
| `GetPendingAbsenceRequestsUseCase` | Pending requests for one calendar day after teacher→halaqa ownership check |
| `ReviewAbsenceRequestUseCase` | Single approve/reject path; ownership gate; refuses `pending` as decision |
| Teacher datasource review | Transaction updates `status` + `reviewedBy` only; never `attendanceRecords` |
| `TeacherBloc` pending + review | Loading / error / retry / refresh after decision |
| Attendance page section | Pending queue visible during attendance; copy states Rule 1 |
| Parent list (Slice 1) | Unchanged — refresh/open shows updated status (existing workflow) |

**Not in Slice 2:** academy events for request outcome (Slice 3), supervisor read model, attendance auto-mark, W4 signal changes.

---

## Product workflow validation

| Check | Result |
|-------|--------|
| Teacher sees only requests for authorized halaqat | Pass — use cases gate on `getTeacherHalaqat` |
| Approve / Reject updates only request state | Pass — datasource `update` status/`reviewedBy` only |
| Attendance records remain untouched | Pass — review path has zero attendance I/O; tests assert `saveDayAttendance` not called |
| Parent observes updated state via existing parent workflow | Pass — Slice 1 list + pull-to-refresh / reopen; no parallel parent writer |
| W4 absence notifications unchanged | Pass — no event/notification changes in Slice 2 |
| W2 attendance behavior unchanged | Pass — `saveDayAttendance` path untouched |
| No duplicated approval logic | Pass — single `ReviewAbsenceRequestUseCase` |
| Loading / empty / error / retry / refresh / permissions / nav | Pass — section statuses; empty collapses; `TeacherWorkflowOwnership` for actions; attendance route reuse |
| Rule 1 / D-W7-3 | Pass |

---

## Gates

| Gate | Result |
|------|--------|
| `test/features/teacher/review_absence_request_usecase_test.dart` | Pass |
| `test/features/teacher/get_today_agenda_usecase_test.dart` | Pass |
| Parent absence submit tests | Pass |
| `flutter analyze` (touched) | Clean |
| DI regenerated | Pass — use cases wired into `TeacherBloc` |

---

## Stop

Slice 3 / W7 completion — see `docs/W7_SLICE3_PRODUCTION_VALIDATION.md` and `docs/W7_COMPLETION_PRODUCTION_VALIDATION.md`.
