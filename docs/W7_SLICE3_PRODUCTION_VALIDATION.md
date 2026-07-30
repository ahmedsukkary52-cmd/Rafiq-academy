# W7 Slice 3 — Outcome Projections · Production Validation

**Status:** Pass  
**Date:** 2026-07-29  
**Design:** `docs/W7_PHASE0_DESIGN.md` (Rule 2 locked · D-W7-6 = B · D-W7-7 = A)  
**Scope:** Slice 3 only — parent + supervisor **projections** of existing request facts; no new lifecycle ownership

---

## Locked rule (before implementation)

**Rule 2 — Workflow outcomes are projections, not new business facts.**

- Parent outcome, supervisor visibility, and any future observer derive from existing `absenceRequests` (+ attendance remains separate SSOT).  
- No new workflow state, synchronization flag, or duplicated lifecycle.  
- Observers may project differently; they never own the workflow.

**D-W7-6 locked = B** for this slice: role UIs read `absenceRequests` (no new academy event kinds).  
**D-W7-7 locked = A:** supervisor read-only request context on supervised halaqat.

---

## What shipped

| Artifact | Role |
|----------|------|
| `AbsenceRequestProjection` | Shared status labels / decided check — presentation only |
| Parent absence list copy + fields | Outcome framing; projects `status`, `reviewedBy`, student/halaqa ids |
| `GetSupervisedAbsenceRequestsUseCase` | Read-only day projection after supervised-halaqa auth |
| Supervisor datasource read | `absenceRequests` by supervised halaqat + calendar day (all statuses) |
| `SupervisorAbsenceRequestsSection` | Display + escalate to teacher attendance; **no** approve |
| SupervisorBloc load/retry | Loading / empty / error / refresh beside day board |

**Not in Slice 3:** new `AcademyEvent` kinds, request inbox fan-out, supervisor approve, attendance coupling, Category B.

---

## Product workflow validation

| Check | Result |
|-------|--------|
| Parent outcome derived from existing request state | Pass — same `GetAbsenceRequestsUseCase` / entity fields |
| Supervisor visibility read-only + same facts | Pass — reads `absenceRequests`; escalate only |
| No duplicated request or attendance status | Pass — no new enums/flags; attendance untouched |
| No observer introduces new business logic | Pass — labels + auth scope only |
| W2 / W4 / W5 / W6 unchanged | Pass — no edits to attendance writers, absence events, homework events, readiness projector |
| Loading / empty / error / retry / refresh / permissions / nav | Pass |
| Rule 2 / D-W7-6 B / D-W7-7 A | Pass |

---

## Gates

| Gate | Result |
|------|--------|
| `test/features/parent/absence_request_projection_test.dart` | Pass |
| `test/features/supervisor/get_supervised_absence_requests_usecase_test.dart` | Pass |
| Existing W7 + W6 supervisor/teacher tests | Pass |
| `flutter analyze` (touched) | Clean |
| DI regenerated | Pass — use case wired into `SupervisorBloc` |

---

## Stop

Proceeding to **W7 completion gate** (`docs/W7_COMPLETION_PRODUCTION_VALIDATION.md`).
