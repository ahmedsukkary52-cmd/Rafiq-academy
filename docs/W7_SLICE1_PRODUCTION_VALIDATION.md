# W7 Slice 1 — Parent Absence Submission Workflow · Production Validation

**Status:** Pass  
**Date:** 2026-07-29  
**Design:** `docs/W7_PHASE0_DESIGN.md` (D-W7-2 / D-W7-3 / D-W7-4 / D-W7-5)  
**Scope:** Slice 1 only — parent **submit + list own requests** as a product workflow; **no** teacher review, events, or supervisor visibility

---

## What shipped

| Artifact | Role |
|----------|------|
| `GetAbsenceRequestsUseCase` | Lists `absenceRequests` for `requestedBy == parentId` (client-sorted by date) |
| `GetHalaqatForStudentUseCase` | Halaqa picker after **parent→child** auth (no ownership leak) |
| Datasource list / halaqa lookup | Read-only; never touches `attendanceRecords` |
| `ParentBloc` list + halaqa + submit refresh | Loading / error / retry / refresh after success |
| `ParentAbsenceRequestsPage` + `/parent/absence-requests` | Submit form + own-request list |
| Parent home entry | Navigation to absence workflow |

**Not in Slice 1:** teacher approve/reject, attendance pending banner, academy events, supervisor read model, Category B / P-E1.

---

## Product workflow validation (not UI-only)

| Check | Result |
|-------|--------|
| Parent authorization + child ownership on submit | Pass — `SubmitAbsenceRequestUseCase` via `getChildrenIds` |
| Parent authorization + child ownership on halaqa list | Pass — `GetHalaqatForStudentUseCase` gates before repo call |
| Deterministic IDs under repeated submissions | Pass — same `{halaqaId}_{studentId}_{yyyyMMdd}`; test covers resubmit |
| Attendance remains SSOT | Pass — submit/list/halaqa paths have **zero** attendance I/O; UI copy states request is contextual |
| `absenceRequests` never modify attendance | Pass — datasource `set` only on absence collection |
| Loading / empty / error / retry / refresh / navigation | Pass — section statuses + `RefreshIndicator` + home → route + snackbar reset |
| No duplicated attendance or request identity logic | Pass — reuses `AttendancePolicy.dayStart` + `AbsenceRequestIds` |
| Reuses W2/W4/W6 policies where applicable | Pass — W2 day SSOT; no new attendance/write ownership; W6 not in scope (supervisor Slice 3+) |
| Pending visible whether or not attendance exists (D-W7-2) | Pass — no absent-mark gate on submit or list |

---

## Gates

| Gate | Result |
|------|--------|
| `test/shared/absence_request_ids_test.dart` | Pass |
| `test/features/parent/submit_absence_request_usecase_test.dart` | Pass (incl. repeated deterministic id) |
| `test/features/parent/get_halaqat_for_student_usecase_test.dart` | Pass |
| Existing parent observer tests | Pass |
| `flutter analyze` (touched) | Clean |
| `dart format` | Clean |
| DI regenerated | Pass — new use cases wired into `ParentBloc` |

---

## Stop

Slice 2 approved path available — see `docs/W7_SLICE2_PRODUCTION_VALIDATION.md`.
