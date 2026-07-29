# Post-W5 Roadmap — Recommended W6

**Date:** 2026-07-29  
**Predecessor:** W5 COMPLETE (`docs/W5_COMPLETION_PRODUCTION_VALIDATION.md`)

## Ranking (post-W5)

| Candidate | Product | Dependency | Backend ready | Reuse | Maintainability | Notes |
|-----------|---------|------------|---------------|-------|-----------------|-------|
| **Parent session integrity + logout** (hygiene that unblocks shared devices) | High for trust | Unblocks parent multi-account use of W4/W5 inbox | Ready | Reuses auth + notifications stop-watch | Improves | Was W5 Slice 3 / D-W5-9; small, Category A |
| **Supervisor day oversight** | Medium–High | Needs logout for supervisor first; observes W2/W3 facts | Ready for reads | Reuses agenda/attendance policies | Medium | Still outside the operated loop |
| Student audio submit loop | High | Storage / Blaze | **Blocked** (Category B) | Existing submit path | Neutral | Not a product workflow until infra |
| Teacher ↔ parent messaging | Medium | Chat reachability | Partial | Low event reuse | Risky | |
| Payments | High commercially | Cloud Function | **Blocked** | Low | Poor | |

## Recommended W6 — Parent & role session integrity (logout + identity reset)

**One sentence:** On shared devices, every academy role that receives W4/W5 projections can leave the account cleanly, and singleton blocs/inbox state reset so the next user never sees the previous observer’s facts.

**Why before Supervisor oversight or other workflows**

1. **Verified gap:** Parent (and supervisor/admin) still cannot log out; W4/W5 made the parent inbox load-bearing.
2. **Workflow dependency:** Supervisor day oversight and any further parent depth presuppose safe account switching.
3. **Backend ready:** No new collections; auth + existing `StopWatchingNotificationsEvent` pattern.
4. **Architecture:** Protects the event *consumers* without changing publishers — aligns with future-compatibility (no emitter changes).
5. **Scope:** Prefer a thin workflow/hygiene slice (parent logout + ParentBloc reset; optionally supervisor/admin logout in the same pass) rather than inventing a large new product surface.

**Explicitly not W6:** B-R8, Storage, payments, modifying Homework publishers for new observers.

Await approval before W6 Phase 0.
