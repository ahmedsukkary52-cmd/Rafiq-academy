# W8 Pre-Slice — Academy Admission Atomic Invariant · Production Validation

**Status:** Pass  
**Date:** 2026-07-30  
**Design:** `docs/W8_PHASE0_DESIGN.md` (Rules 1–5 locked; D-W8-1 / D-W8-7 approved)  
**Scope:** Pre-Slice only — atomic membership invariant + supervisor retarget; **no Slice 1 UI**

---

## What shipped

| Artifact                                        | Role                                                                                                     |
|-------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `AcademyMembershipInvariant`                    | Documents D-W8-7 contract; `isComplete` only when all four members hold together                         |
| `AcademyAdmissionFirestore.establishMembership` | Shared atomic Firestore batch: role precondition + `isActive` + profile `halaqaId` + roster `arrayUnion` |
| `ApproveNewStudentUseCase`                      | Current Implementation Owner of **Academy Admission Workflow** (documented)                              |
| Admin `approveNewStudent` datasource            | Delegates to shared atomic write                                                                         |
| `RegisterNewStudentUseCase`                     | Supervisor entry — **delegates to** `ApproveNewStudentUseCase` (not independent owner)                   |
| Supervisor `registerNewStudent` datasource      | Same shared atomic write (no partial two-step updates)                                                   |

**Not in Pre-Slice:** admin/supervisor admit UI redesign, eligibility queue, field SSOT promotion,
unenroll, new membership collection, Slice 1 surfaces.

---

## Constraint compliance

| Constraint                                                | Result                                                    |
|-----------------------------------------------------------|-----------------------------------------------------------|
| Business Owner = Academy Admission Workflow               | Pass — documented; not bound to use-case name             |
| Current Implementation Owner = `ApproveNewStudentUseCase` | Pass                                                      |
| Invariant = roster ∧ profile ∧ role ∧ isActive            | Pass — role gated before write; other three in one batch  |
| Rule 5 atomic — no partial admit                          | Pass — batch + no write if role ≠ student                 |
| Supervisor not independent owner                          | Pass — use case delegates to Current Implementation Owner |
| Self-register / toggle / W1–W7 unchanged as non-owners    | Pass — not modified as membership owners                  |
| No field SSOT / no new abstraction                        | Pass                                                      |
| No broad UI                                               | Pass                                                      |

---

## Gates

| Gate                                                                     | Result      |
|--------------------------------------------------------------------------|-------------|
| `test/shared/academy_membership_invariant_test.dart`                     | Pass        |
| `test/features/supervisor/register_new_student_usecase_test.dart`        | Pass        |
| `dart analyze` (touched)                                                 | Clean       |
| `dart format`                                                            | Clean       |
| injectable DI (`RegisterNewStudentUseCase` → `ApproveNewStudentUseCase`) | Regenerated |

---

## Stop

**Awaiting approval before Slice 1** (staff admit path UI invoking Academy Admission Workflow).
