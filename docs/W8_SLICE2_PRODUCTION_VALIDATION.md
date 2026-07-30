# W8 Slice 2 — Operational Readiness for W1–W7 Consumers · Production Validation

**Status:** Pass  
**Date:** 2026-07-30  
**Design:** `docs/W8_PHASE0_DESIGN.md` (Rules 1–7; Slice 1 approved)  
**Scope:** Slice 2 only — prove day-ops / student surfaces consume membership without local
membership logic; **no completion gate / Slice 3 UI**

---

## Locked rule (before implementation)

**Rule 7 — Membership reconciliation is invariant-driven.**

- Academy Admission reconciles toward the approved invariant.
- Never assume one field is authoritative and copy it into the others.
- Every write establishes the invariant **directly**.
- Future SSOT/storage changes must not force W1–W7 consumer rewrites.
- Implementation rule — not a new business rule.

---

## What shipped

| Artifact                       | Role                                                                                                                                |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| Rule 7 documented              | Invariant-driven reconcile; W1–W7 storage-independent                                                                               |
| `AcademyMembershipConsumption` | Explicit consume contracts: roster for day-ops, profile pointer for student, `isActive` as login gate only                          |
| `AcademyAdmissionFirestore`    | Rule 7 comments — direct target writes, not field-to-field copy                                                                     |
| Operational readiness tests    | Complete invariant ⇒ W3 projector sees roster; student pointer resolves; incomplete leaves pointer unset; no single-field authority |

**Not in Slice 2:** empty/error membership UX (Slice 3), production completion gate (Slice 4),
eligibility queue, field SSOT promotion, unenroll.

---

## Product workflow validation

| Check                                                         | Result                                                        |
|---------------------------------------------------------------|---------------------------------------------------------------|
| Teacher/W3 readiness uses `halaqa.studentIds` as roster input | Pass — consumption helper + projector test                    |
| Student home resolves via `studentProfiles.halaqaId`          | Pass — `studentFacingHalaqaId`                                |
| `isActive` alone ≠ membership                                 | Pass — invariant + login-gate tests                           |
| No local `isMember` / membership invent in consumers          | Pass — consumption API documents read-only surfaces           |
| Rule 7 — no single-field copy authority                       | Pass — roster≠profile and profile≠roster incompleteness tests |
| W1–W7 code paths unchanged as membership writers              | Pass — Slice 2 adds consume documentation/tests only          |

---

## Gates

| Gate                                                             | Result |
|------------------------------------------------------------------|--------|
| `test/shared/academy_membership_operational_readiness_test.dart` | Pass   |
| Existing membership invariant / register tests                   | Pass   |
| `dart analyze` (touched)                                         | Clean  |
| `dart format`                                                    | Clean  |

---

## Stop

**Awaiting approval before the completion gate** (Slice 3 visibility / Slice 4 production
validation).
