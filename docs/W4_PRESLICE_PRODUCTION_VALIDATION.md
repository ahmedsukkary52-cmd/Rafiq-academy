# W4 Pre-Slice — Academy Event Foundation · Production Validation

**Status:** Pass  
**Date:** 2026-07-26  
**Design:** `docs/W4_PHASE0_DESIGN.md` (workflow + multi-channel adjustments approved)  
**Scope:** Pre-Slice only — no UI, no attendance↔notification coupling, no Category B

---

## What shipped

| Artifact | Role |
|----------|------|
| `AcademyEvent` (`StudentAbsentRecorded`, `StudentAbsenceCorrected`) | Operational facts derived from attendance transitions |
| `AcademyEventSink` + `NoOpAcademyEventSink` | Delivery port — attendance will never depend on one channel |
| `AttendanceAbsenceTransitions` | Pure projector; explicit `'absent'` only (not `isAbsentStatus`) |
| `AcademyEventIds` | Deterministic `eventId` + future in-app delivery id helper |
| `ParentRecipientResolver` + `getParentIdsByStudentIds` | Chunked reverse lookup over existing `parentProfiles.childrenIds` |

**Not in Pre-Slice:** wiring into `saveDayAttendance`, in-app notification sink, parent inbox UI, FCM/SMS, `absenceRequests`.

---

## Constraint compliance

| Constraint | Result |
|------------|--------|
| Workflow, not notification feature | Pass — events are facts; sink is a port |
| Attendance remains SSOT | Pass — no attendance writes changed |
| Multi-channel ready without over-engineering | Pass — one abstract sink; NoOp registered |
| No new collections / fields | Pass |
| No duplicate business rules | Pass — explicit absent projector beside `AttendancePolicy` |
| Category B not included | Pass |

---

## Gates

| Gate | Result |
|------|--------|
| Unit tests (transitions + recipient resolver) | Pass |
| Existing suite | Pass |
| `flutter analyze` (touched) | Clean |
| `dart format` | Clean |

**Stop:** awaiting approval before Slice 1.
