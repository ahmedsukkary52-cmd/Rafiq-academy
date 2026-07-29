# W7 Pre-Slice — Absence Request Foundation · Production Validation

**Status:** Pass  
**Date:** 2026-07-29  
**Design:** `docs/W7_PHASE0_DESIGN.md` (D-W7-2 / D-W7-3 approved)  
**Scope:** Pre-Slice only — schema honesty + authorize + deterministic identity; **no UI**

---

## What shipped

| Artifact | Role |
|----------|------|
| `AbsenceRequestIds` | Deterministic `{halaqaId}_{studentId}_{yyyyMMdd}` (aligned with attendance day encoding) |
| `AbsenceRequestEntity.halaqaId` | Required halaqa scope (D-W7-4) |
| `SubmitAbsenceRequestUseCase` | Day normalize, parent→child auth, force `pending`; **no attendance I/O** |
| Datasource submit | `set` on deterministic id; refuse overwrite of approved/rejected; never writes `attendanceRecords` |

**Not in Pre-Slice:** parent/teacher UI, approve/reject API, academy events, supervisor visibility, attendance page pending-request display.

---

## Constraint compliance

| Constraint | Result |
|------------|--------|
| Attendance remains SSOT | Pass — submit path has zero attendance reads/writes |
| Request never owns attendance (D-W7-2 / D-W7-3) | Pass |
| Submit allowed before attendance taken (D-W7-2) | Pass — no absent-mark gate |
| Reuse W2 day policy | Pass — `AttendancePolicy.dayStart` |
| Parent→child authorization | Pass — `getChildrenIds` |
| No UI beyond tests | Pass |
| Category B / P-E1 not included | Pass |

---

## Gates

| Gate | Result |
|------|--------|
| `test/shared/absence_request_ids_test.dart` | Pass |
| `test/features/parent/submit_absence_request_usecase_test.dart` | Pass |
| Existing parent observer tests | Pass |
| `flutter analyze` (touched) | Clean |
| `dart format` | Clean |

---

## Stop

Awaiting approval before **Slice 2** (teacher pending queue + approve/reject).

_Slice 1 shipped and validated — see `docs/W7_SLICE1_PRODUCTION_VALIDATION.md`._

