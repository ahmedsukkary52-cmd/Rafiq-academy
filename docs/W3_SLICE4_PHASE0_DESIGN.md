# W3 Slice 4 — Day Closeout
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Approved (D-C1..D-C5 = recommended A) — **Implemented + production-validated (Pass)** (`docs/W3_SLICE4_PRODUCTION_VALIDATION.md`)  
**Date:** 2026-07-26  
**Parent workflow:** W3 Daily Halaqa Session Operations (`docs/W3_PHASE0_DESIGN.md`)  
**Predecessors:** Pre-Slice + Slice 1 + Slice 2 + Slice 3 production-validated (Pass)  
**Standing rule:** If an assumption is wrong: **stop**, update this doc, then continue.  
**This document:** Design only. **Do not implement** until explicitly approved.

---

## 0. Goal (operations, not screens)

In a real Qur'an academy, the teaching day does not end when the Zoom call ends. It ends when the teacher can honestly answer:

> **"Have I finished today's operational work for every halaqa that met today?"**

That is **Day Closeout**.

It is **not**:
- a new "Session completed" button,
- a persisted flag,
- a report for supervisors,
- a motivational summary,
- a second definition of attendance / homework / reviews.

It **is** an honest, assistive signal derived from work the teacher already did (or still owes) through W1 and W2 — the same three pillars already orchestrated by the Day Agenda.

---

## 1. What "Day Closeout" means in a real academy

### 1.1 Operational meaning (Verified against academy practice + W3 D2)

For each halaqa that has an **operational teaching day today** (W3 D6: one calendar day per halaqa, not per slot), the day is complete only when:

| Pillar | Academy meaning | Already owned by |
|--------|-----------------|------------------|
| **Register** | Every roster student has a day mark | W2 + `AttendancePolicy.isRegisterComplete` |
| **Homework** | Today's current assignment exists (W1 D7 latest `dueDate` on today's calendar day) | W1 + Slice 2 `getLatestAssignmentDueDate` |
| **Reviews** | No leftover pending submissions await the teacher | W1 `RecitationRecordEntity.isPendingReview` |

**Teacher-day closeout** (across all of today's halaqat) =

- **No sessions today** → there is nothing to close out (honest idle day).  
- **All today's halaqat have zero pending agenda actions** → day complete.  
- **Any today's halaqa still has pending agenda actions** → day incomplete.

This matches the W3 Phase 0 after-session box (O16–O19) and approved "Today's work" definition (§1.5 of parent design).

### 1.2 Classification of current code

Legend: **Verified** · **Partial** · **Missing** · **Product decision**.

| # | Closeout concern | Classification | Evidence |
|---|------------------|----------------|----------|
| C-O1 | Know which halaqat meet today | **Verified** | `mapTodayOperationalDays` → `sessionsTodayCount` |
| C-O2 | Per-halaqa register complete? | **Verified** | Agenda action `takeAttendance` via W2 + policy |
| C-O3 | Per-halaqa homework assigned today? | **Verified** | Agenda action `sendHomework` via W1 D7 + day SSOT |
| C-O4 | Per-halaqa pending reviews? | **Verified** | Agenda action `reviewRecitations` via W1 `isPendingReview` |
| C-O5 | Remaining work list | **Verified** | `TeacherDayAgenda.items` (only incomplete halaqat) |
| C-O6 | Distinguish "no session" vs "all done" | **Verified (implicit)** | Empty states in `TeacherDashboardTab` |
| C-O7 | Explicit aggregate **"اليوم مكتمل"** | **Partial** | De-facto copy exists: «لا يوجد عمل متبقٍّ اليوم» — not framed as closeout |
| C-O8 | Explicit aggregate **"اليوم ناقص"** | **Missing** | When `items.isNotEmpty`, UI shows only cards — no day-level honesty line |
| C-O9 | Per-pillar counts (e.g. unmarked N/total) | **Missing (optional)** | Boolean readiness only; counts would need projecting more from the same reads |
| C-O10 | Time-gated closeout (only after last session ends) | **Product decision** | Schedule status exists on sessions; agenda does not currently gate by clock |
| C-O11 | Persist `sessionCompleted` / closeout write | **Out — forbidden** | W3 D8/D10 |
| C-O12 | Supervisor day-closeout dashboard | **Out of W3** | Parent design §8 / §9 |

---

## 2. Verified findings (post Slices 1–3)

### 2.1 Closeout can be a pure projection — Verified

`TeacherDayAgenda` already carries everything needed for a **boolean / halaqa-level** closeout:

| Field | Meaning for closeout |
|-------|----------------------|
| `sessionsTodayCount` | How many halaqat meet today (denominator) |
| `items` | Halaqat that still have remaining work (incomplete set) |
| `items.isEmpty && sessionsTodayCount > 0` | **Day complete** (all today's work done) |
| `items.isNotEmpty` | **Day incomplete** |
| `sessionsTodayCount == 0` | **No teaching day** (not incomplete — idle) |

Derivation formula (no new reads):

```text
incompleteHalaqatCount = items.length
completeHalaqatCount   = sessionsTodayCount - items.length

if sessionsTodayCount == 0     → NoSessionToday
else if items.isEmpty          → DayComplete
else                           → DayIncomplete
```

**Verified:** `GetTodayAgendaUseCase` already computes the three pillars per today-halaqa and drops finished work from `items`.  
**Verified:** Agenda refreshes after attendance save, assignment send, and recitation add/review (`LoadTodayAgendaEvent`) — closeout would stay live without new sync code if it reads the same projection.

### 2.2 No new Firestore schema — Verified

| Need | Satisfied by |
|------|----------------|
| Day boundary | `AttendancePolicy.dayStart` / `isSameCalendarDay` (W2) |
| Register | Existing `attendanceRecords` day query (W2) |
| Homework | Existing `getLatestAssignmentDueDate` + index from Slice 2 (W1) |
| Reviews | Existing `getHalaqaRecitationRecords` + `isPendingReview` (W1) |
| Today's halaqat | Existing `mapTodayOperationalDays` (Pre-Slice) |

**No new collections. No new fields. No `sessionCompleted`. No orchestration persistence (D8/D10).**

### 2.3 De-facto "complete" already exists — Verified

```374:376:lib/features/teacher/presentation/pages/teacher_dashboard_tab.dart
    final message = sessionsTodayCount == 0
        ? 'لا توجد حصص مجدوَلة اليوم'
        : 'لا يوجد عمل متبقٍّ اليوم';
```

Slice 4 should **reuse / reframe** this honesty, not invent a parallel empty state.

### 2.4 What is genuinely missing — Verified

1. An explicit **day-level incomplete** signal when actionable items remain.  
2. A single, named closeout concept in the read model (so the UI does not re-derive business meaning ad hoc).  
3. Neutral D9 Arabic for complete / incomplete that does not blame the teacher.

Optional (not required for Slice 4 MVP): per-pillar or per-student counts.

---

## 3. Existing architecture reuse map

```text
W1 Homework          W2 Attendance           W1 Reviews              Pre-Slice Schedule
─────────────        ──────────────          ───────────             ──────────────────
latest dueDate  ──┐  day marks + roster ──┐  isPendingReview ──┐    mapTodayOperationalDays
                  │                       │                    │              │
                  └───────────┬───────────┴────────┬───────────┘              │
                              ▼                    ▼                          ▼
                     GetTodayAgendaUseCase (orchestration — already Verified)
                              │
                              ▼
                     TeacherDayAgenda { items, sessionsTodayCount }
                              │
                              ▼
                     ★ Slice 4: DayCloseout projection (thin)
                              │
                              ▼
                     TeacherDashboardTab composition (extend, do not replace)
```

| Slice 4 need | Reuse | New? |
|--------------|-------|------|
| Today's halaqat count | `sessionsTodayCount` | No |
| Incomplete halaqat | `items` | No |
| Pillar readiness | Already inside agenda items' `pendingActions` | No |
| Refresh after work | Existing `LoadTodayAgendaEvent` hooks | No |
| Deep-links when incomplete | Existing agenda rows (Slices 1–3) | No new routes |
| DayCloseout enum / view bits | — | **Thin** read-model field or pure UI helper from agenda |
| Firestore | — | **None** |
| Policies | — | **None** (do not re-encode W1/W2 rules) |

**Critical reuse rule:** Slice 4 must **not** re-query attendance / assignments / recitations to decide closeout. That would duplicate orchestration already owned by `GetTodayAgendaUseCase`. Closeout = projection of `TeacherDayAgenda` (and optionally the same pending actions already listed).

---

## 4. Workflow diagram

```text
 Teacher finishes (or mid-day reviews) operational work
        │
        │  W1/W2 writes already trigger LoadTodayAgendaEvent
        ▼
 TeacherDayAgenda refreshed (read-time)
        │
        ├── sessionsTodayCount == 0
        │         → Closeout = NoSessionToday
        │         → UI: existing «لا توجد حصص مجدوَلة اليوم»
        │
        ├── sessionsTodayCount > 0 && items.isEmpty
        │         → Closeout = DayComplete
        │         → UI: honest complete (reframe «لا يوجد عمل متبقٍّ اليوم» / «اليوم مكتمل»)
        │
        └── items.isNotEmpty
                  → Closeout = DayIncomplete
                  → UI: calm incomplete line + existing agenda cards (deep-links)
                  → completeHalaqat = sessionsTodayCount - items.length
```

No new workflow. No new actor. Student/Parent surfaces remain unchanged (already reflect the day via W1/W2).

---

## 5. Product gaps

| ID | Gap | Nature | Recommended resolution |
|----|-----|--------|------------------------|
| G1 | No explicit **DayIncomplete** aggregate | Missing presentation | Add one calm line above/beside agenda when `items.isNotEmpty` |
| G2 | Complete copy not named as closeout | Partial | Prefer reusing / lightly reframing existing empty complete copy (D9) |
| G3 | Whether closeout is **teacher-day** or **per-halaqa** | Product decision | See D-C1 |
| G4 | Whether to show **counts** (مكتمل X من Y) | Product decision | See D-C2 |
| G5 | Whether closeout waits until sessions **ended** | Product decision | See D-C3 |
| G6 | Pending reviews from prior days in "today's" closeout | Already Verified behavior | Confirm as intentional (assistive) — D-C4 |

---

## 6. Required product decisions

### D-C1 — Closeout grain

| Option | Meaning |
|--------|---------|
| **A. Teacher-day aggregate (recommended)** | One signal for the whole day across all today's halaqat |
| B. Per-halaqa closeout only | Redundant with agenda cards; little new value |
| C. Both | Risk of a busier dashboard (conflicts with "simpler, not busier") |

**Recommendation: A.** The agenda already answers "what is left per halaqa." Closeout answers the single end-of-day question. Matches parent W3 Slice 4 wording («اليوم مكتمل / ناقص»).

### D-C2 — How much detail when incomplete?

| Option | Meaning |
|--------|---------|
| **A. Status + optional halaqa fraction (recommended)** | e.g. «لم يكتمل عمل اليوم» + «مكتمل 1 من 3 حلقات» — still neutral, no blame |
| B. Status only | Minimal; may under-inform multi-halaqa teachers |
| C. Per-pillar student counts (N/total unmarked, etc.) | Extra projection work; denser UI; **not** needed for MVP |

**Recommendation: A** for MVP. Counts use existing `sessionsTodayCount` and `items.length` only — still zero new queries. Defer per-pillar student counts.

### D-C3 — Time gating

| Option | Meaning |
|--------|---------|
| **A. Always show derived closeout (recommended)** | Mid-day "incomplete" is assistive ("what remains"), not accusatory |
| B. Only after last today's session `ended` | Requires clock/status gating; can hide useful remaining-work honesty earlier |
| C. Teacher dismisses closeout | Persistence — forbidden by D10 |

**Recommendation: A.** Aligns with D2 ("What should I do today?") and D9 (assist, never blame). Incomplete mid-day is information, not a reprimand.

### D-C4 — Pending reviews older than today

| Option | Meaning |
|--------|---------|
| **A. Keep current agenda rule (recommended)** | Any pending review blocks complete — leftover work is still today's responsibility |
| B. Only pending submitted "today" | New filter = new rule; conflicts with "reuse W1 visibility" |

**Recommendation: A (Verified current behavior).** Document explicitly so Slice 4 does not invent a second review window.

### D-C5 — Wording (D9)

Proposed neutral copy (pending approval):

| State | Proposed Arabic | Notes |
|-------|-----------------|-------|
| No session | «لا توجد حصص مجدوَلة اليوم» | **Verified** — keep |
| Complete | «لا يوجد عمل متبقٍّ اليوم» **or** «اكتمل عمل اليوم» | Prefer keeping existing honesty; optional soft reframe |
| Incomplete | «لم يكتمل عمل اليوم» | Neutral; avoids «قصّرت» / blame |
| Incomplete detail | «مكتمل {done} من {total} حلقات» | Optional under D-C2-A |

**Avoid:** motivational slogans, progress bars, badges, charts (Slice 1 constraints still apply).

---

## 7. How Slice 4 integrates with W1 / W2 / W3 (no new workflow)

```text
W1 ──► defines homework "current" + pending review visibility
W2 ──► defines calendar day + register completeness
W3 Pre–3 ──► orchestrates those into TeacherDayAgenda + deep-links
W3 Slice 4 ──► names the aggregate honesty of that same projection
```

Slice 4 does **not**:
- create a Closeout use case that re-fetches Firestore,
- create a CloseoutBloc,
- create a Closeout page/route,
- write any document,
- change W1/W2 policies.

Slice 4 **does**:
- extend the existing read projection (or a pure helper over it),
- compose one calm signal into `TeacherDashboardTab`,
- keep execution on existing agenda deep-links.

---

## 8. Proposed implementation slices (inside Slice 4)

Keep Slice 4 itself small and releasable.

| Step | Name | What it adds | Immediately usable? |
|------|------|--------------|---------------------|
| **4.0** | Closeout projection | Derive `DayCloseoutStatus` (or equivalent) from `TeacherDayAgenda` only — in read model helper or as fields on the projection produced by the existing use case **without new I/O** | Foundation |
| **4.1** | Dashboard closeout line | Show complete / incomplete / no-session using approved copy; incomplete may show `done/total` if D-C2-A approved | Yes — end-of-day honesty |
| **4.2** | Tests + production validation | Unit tests for projection matrix; analyze; format; commit; push; W1/W2-style validation doc | DoD for Slice 4 |

**Explicitly not separate product slices:** supervisor views, notifications, holiday engine, per-student unmarked counts.

---

## 9. Explicitly OUT of Slice 4

- ❌ New Firestore collections or fields  
- ❌ Persisted `sessionCompleted` / `dayClosed` / teacher acknowledgements  
- ❌ New Closeout page, route, or module  
- ❌ Re-querying attendance / assignments / recitations for closeout  
- ❌ Reimplementing W1/W2 policies  
- ❌ Statistics, charts, progress bars, badges, gamification  
- ❌ Supervisor / admin closeout dashboards  
- ❌ Absence notifications, استئذان, holidays  
- ❌ Changing Student / Parent surfaces  
- ❌ Time-travel / historical day closeout archive  
- ❌ Auto-closing or blocking navigation until "complete"

---

## 10. Risks

| Type | Risk | Mitigation |
|------|------|------------|
| **Architecture** | Closeout becomes a second orchestrator with its own reads | Hard rule: project from `TeacherDayAgenda` only |
| **Product** | "Incomplete" feels like blame mid-day | D9 wording + D-C3-A; assistive framing |
| **UX** | Dashboard gets busier | One short line; no new cards; reuse empty-state honesty |
| **Semantics** | Confusing "no session" with "incomplete" | Keep three-way status (NoSession / Complete / Incomplete) |
| **Scope creep** | Per-student unmarked counts | Defer; not required for closeout honesty |

---

## 11. Definition of Done (Slice 4)

Slice 4 is Done only if all are true:

1. Teacher can tell at a glance whether **today's operational work is complete, incomplete, or there is no session**.  
2. Closeout is derived **only** from existing `TeacherDayAgenda` (or the same use case output) — **no new Firestore I/O**.  
3. No new collections, fields, or persisted closeout state (D8/D10).  
4. No duplicated W1/W2 business rules.  
5. Incomplete state still routes work through **existing** agenda deep-links (D5).  
6. Neutral assistive wording only (D9).  
7. Dashboard stays simple (no charts/badges/stats).  
8. `flutter analyze` clean on touched code; formatted; tests for the projection matrix; committed and pushed.  
9. Production validation doc written (W1/W2/Slice 2–3 style).  
10. Parent W3 design updated to mark Slice 4 Done + validated.

---

## 12. Approval gate

**This is Phase 0 for Slice 4 only.**

Please approve or adjust:

1. **D-C1** — Teacher-day aggregate (recommended A)  
2. **D-C2** — Incomplete detail level (recommended A: status + done/total halaqat)  
3. **D-C3** — Always show derived closeout (recommended A)  
4. **D-C4** — Pending reviews of any day block complete (recommended A = current behavior)  
5. **D-C5** — Wording table above  

**Do not implement Slice 4 until this design is explicitly approved.**
