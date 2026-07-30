# H7 — Awards Schema Coherence Validation

**Status:** Implemented · awaiting product approval before H8  
**Date:** 2026-07-31  
**Scope:** Slice H7 only (`docs/PRODUCTION_HARDENING_PHASE0.md`) — **A-H7**  
**Out of scope:** H8 test belt, type-vocab UX merge, points/stars policy change, legacy doc migration, new awards product features

---

## Intent

One `achievements` write/read contract so teacher grants and supervisor issues no longer drift on actor/time fields — without changing W1–W8 workflows or awards UX.

| Item | Delivery |
|------|----------|
| **A-H7** | Shared `AchievementsFirestoreContract`; dual-write aliases on both writers; dual-read helpers for legacy docs |

---

## Contract

| Concern | Canonical + compat aliases |
|---------|----------------------------|
| Actor | `grantedBy` **and** `issuedBy` (same uid) |
| Time | `grantedAt` **and** `date` (same timestamp) |
| Text | `title` **and** `note` when a display string exists |
| Scope | `halaqaId` on teacher grants **and** supervisor issues |

Legacy single-shape docs remain readable via resolve helpers.

---

## What shipped

| Change | Path / note |
|--------|-------------|
| Shared contract | `lib/shared/data/achievements_firestore_contract.dart` |
| Teacher writer | `GrantedAwardModel.toFirestore` → dual-write |
| Teacher/student readers | `GrantedAwardModel` / `AchievementModel` use resolve helpers |
| Supervisor writer | `issueAchievement` → dual-write + `halaqaId` |
| Entity plumbing | `AchievementIssueEntity.halaqaId` (same dialog; no new UI) |

### Explicitly unchanged

- Teacher grant points / `totalStars` side-effect
- Award type vocabularies (teacher 4 keys vs supervisor 3 keys)
- Student achievements UI / badges filters
- No Firestore migration of old docs

---

## Regression tests

| Suite | Result |
|-------|--------|
| `test/shared/achievements_firestore_contract_test.dart` | Pass |

---

## Stop gate

**H7 complete for review.** Do **not** start H8 until product approves.
