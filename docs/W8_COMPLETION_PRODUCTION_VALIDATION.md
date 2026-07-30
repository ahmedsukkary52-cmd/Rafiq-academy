# W8 — Student Onboarding / Halaqa Membership Lifecycle · Completion Validation

**Status:** Pass / W8 complete (awaiting product approval)  
**Date:** 2026-07-30  
**Design:** `docs/W8_PHASE0_DESIGN.md`  
**Slices:** Pre-Slice · Slice 1 · Slice 2 · Slice 3 (visibility) · Slice 4 (this gate)

---

## Locked Rule 8 (before completion gate)

**Membership completeness is observable.**

- Externally only: **membership established** | **membership not established**
- Consumers must never infer partial membership from individual fields
- Completion gate verifies consumers observe the **workflow contract**, not storage details or
  intermediate writes

---

## Lifecycle success criteria (§9)

| #  | Criterion                                                        | Result                                                      |
|----|------------------------------------------------------------------|-------------------------------------------------------------|
| 1  | Clear answer: how a student becomes an active member of a halaqa | Pass — Academy Admission Workflow end-to-end                |
| 2  | Rule 2 — simultaneous invariants                                 | Pass — `AcademyMembershipInvariant`                         |
| 3  | Rule 3 — workflow owns invariant, not a field                    | Pass — Business Owner locked                                |
| 4  | Rule 4 — ownership decided before implementation                 | Pass — D-W8-1 / D-W8-7 before Pre-Slice                     |
| 5  | Rule 5 — atomic admission                                        | Pass — `AcademyAdmissionFirestore` batch                    |
| 6  | Rule 6 — idempotent admission                                    | Pass — early return + `arrayUnion`                          |
| 7  | Rule 7 — invariant-driven reconcile                              | Pass — direct target writes                                 |
| 8  | Rule 8 — only two observable states                              | Pass — `AcademyMembershipObservation` + student empty state |
| 9  | No new membership abstraction                                    | Pass                                                        |
| 10 | Supervisor not independent owner                                 | Pass — delegates to Current Implementation Owner            |
| 11 | W1–W7 consume without local membership logic                     | Pass — `AcademyMembershipConsumption` + readiness tests     |
| 12 | Not account administration (Rule 1)                              | Pass                                                        |
| 13 | Out of scope held                                                | Pass — unenroll, parent link, messaging, P-E1 out           |

---

## Permanent rules held

| Rule                                       | Held |
|--------------------------------------------|------|
| Rule 1 — academy lifecycle, not user admin | Yes  |
| Rule 2 — one completion contract           | Yes  |
| Rule 3 — workflow owns invariant           | Yes  |
| Rule 4 — ownership before implementation   | Yes  |
| Rule 5 — atomic invariants                 | Yes  |
| Rule 6 — idempotent admission              | Yes  |
| Rule 7 — invariant-driven reconciliation   | Yes  |
| Rule 8 — completeness observable           | Yes  |

---

## Artifact map

| Stage                        | Owner                                       | Fact / surface                |
|------------------------------|---------------------------------------------|-------------------------------|
| Business Owner               | Academy Admission Workflow                  | Membership invariant contract |
| Current Implementation Owner | `ApproveNewStudentUseCase` (replaceable)    | Admit entry                   |
| Atomic write                 | `AcademyAdmissionFirestore`                 | Direct invariant members      |
| Supervisor entry             | `RegisterNewStudentUseCase` → Current Owner | Same workflow                 |
| Admin UI                     | `AdminHomePage` admit form                  | Staff path                    |
| Student not-established      | Student home Rule 8 empty card              | Observable not established    |
| Day-ops consume              | Roster via `halaqat.studentIds`             | W2/W3/W6/W7                   |
| Student consume              | Profile `halaqaId` pointer                  | Home / schedule               |

---

## Consumer observation audit (Rule 8)

| Consumer            | Observes                                         | Does not                                                            |
|---------------------|--------------------------------------------------|---------------------------------------------------------------------|
| Student home        | established / notEstablished via profile pointer | Infer from `isActive` alone; show schedule CTA when not established |
| Teacher roster / W3 | Roster membership for day ops                    | Filter roster by inventing membership from `isActive`               |
| Login               | Supporting gate `isActive`                       | Treat login alone as membership established                         |
| Invariant evaluator | established only when all members hold           | Treat roster-only or profile-only as established                    |

---

## Final gates

| Gate                                                                | Result |
|---------------------------------------------------------------------|--------|
| Pre-Slice / Slice 1 / Slice 2 validation docs                       | Pass   |
| `test/shared/academy_membership_*.dart` + supervisor register tests | Pass   |
| `dart analyze` (touched)                                            | Clean  |
| `dart format`                                                       | Clean  |

---

## Explicitly still out of W8

- Field definitive SSOT promotion
- Unenroll / transfer / multi-halaqa
- Parent↔child linking
- Messaging about admission
- P-E1 logout / identity reset
- Category B rules/indexes as the workflow
- Explicit `membershipRequests` queue (D-W8-2 B not chosen)

---

## Stop

**W8 completion gate Pass.** Awaiting approval before recommending the **next workflow**.
