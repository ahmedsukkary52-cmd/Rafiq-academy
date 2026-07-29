# W7 — Parent Absence Request Lifecycle · Completion Validation

**Status:** Pass / W7 complete  
**Date:** 2026-07-29  
**Design:** `docs/W7_PHASE0_DESIGN.md`  
**Slices:** Pre-Slice · Slice 1 · Slice 2 · Slice 3 — all Pass

---

## Lifecycle success criteria (§8)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Linked parent can submit استئذان scoped to student + day + halaqa | Pass — Slice 1 + Pre-Slice auth/id |
| 2 | Halaqa teacher can approve/reject without a second attendance writer | Pass — Slice 2 Rule 1 |
| 3 | `attendanceRecords` remain the only presence SSOT; % unchanged by request alone | Pass — D-W7-3 / Rule 1 |
| 4 | Parent sees request outcome in addition to (not instead of) attendance | Pass — Slice 3 projection; weekly % still attendance |
| 5 | Supervisor sees request context for supervised halaqat; escalate only | Pass — Slice 3 D-W7-7 A |
| 6 | Inbox signals are projections of academy facts — not parallel ownership | Pass — D-W7-6 B (UI reads); W4 absence events unchanged |

---

## Permanent rules held

| Rule | Held |
|------|------|
| Attendance SSOT | Yes |
| Rule 1 — classify request, not attendance | Yes |
| Rule 2 — outcomes are projections | Yes |
| W2 / W4 / W5 / W6 reuse without rewriting their meaning | Yes |

---

## Artifact map

| Stage | Owner | Fact |
|-------|-------|------|
| Submit | Parent | `absenceRequests` pending (deterministic id) |
| Review | Teacher | `absenceRequests` approved/rejected + `reviewedBy` |
| Presence | Teacher attendance workflow | `attendanceRecords` only |
| Parent view | Projection | Reads own request docs |
| Supervisor view | Projection | Reads supervised request docs (read-only) |

---

## Final gates

| Gate | Result |
|------|--------|
| Pre-Slice / Slice 1 / Slice 2 / Slice 3 validation docs | Pass |
| Focused W7 + related regression tests | Pass |
| `flutter analyze` on W7-touched surfaces | Clean (infos only where pre-existing) |

---

## Explicitly still out of W7

- `excused` attendance status  
- Academy events for request lifecycle (future product may reopen D-W7-6 = A **without** inventing a second SSOT)  
- FCM / SMS / WhatsApp  
- P-E1 logout  
- Category B rules/indexes as the workflow  

---

## Stop

**W7 is Done.** Awaiting approval before recommending **W8**.
