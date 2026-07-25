# W3 — Daily Halaqa Session Operations
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Approved (D1–D10). **Pre-Slice + Slice 1 + Slice 2 + Slice 3 + Slice 4 production-validated (Pass) — W3 COMPLETE.** (`docs/W3_SLICE4_PRODUCTION_VALIDATION.md`)  
**Predecessors:** W1 Done (`docs/W1_PRODUCTION_VALIDATION.md`), W2 Done (`docs/W2_PRODUCTION_VALIDATION.md`), audit (`docs/POST_W2_PRODUCT_AUDIT.md`)  
**Architecture:** Feature-first Clean Architecture + BLoC + Firestore SSOT  
**Standing rule:** If a slice/assumption is found wrong: **stop**, explain, update this doc, then continue.

### Core mandate for W3

**Do NOT invent a new "Session" module.** W3 is an **orchestration layer** that turns the teacher's day into one operational experience by **reusing** Homework (W1), Attendance (W2), Evaluations, and Schedule. Reuse before building. No new collections. No new status fields unless a product decision explicitly approves one.

---

## 0. Goal (operations, not screens)

Answer the teacher's real question every day:

> "It is today. I arrived. **What must I do for my halaqa(t) right now, and what did I forget?**"

W3 makes the app say — from existing data:

**Before the session:** which of my halaqat meet today, roster ready, is today's homework assigned, any leftover pending reviews.  
**During the session:** mark attendance, evaluate recitation, (re)assign homework — all reachable from one place.  
**After the session:** is today's register complete, is homework assigned, are yesterday's reviews cleared — an honest "day done / day incomplete" signal.

---

## 1. Real academy operations research

A teacher at a Qur'an halaqa/maktab, from arrival to departure, performs a repeatable ritual. Below, each step is classified against the **current codebase**.

Legend: **Verified** (implemented) · **Partial** (exists but not orchestrated/complete) · **Missing** · **Product decision**.

### 1.1 Arrival / "what is today?"

| # | Real operation | Classification | Evidence |
|---|----------------|----------------|----------|
| O1 | Teacher knows which halaqa(t) they own | **Verified** | `GetTeacherHalaqatUseCase` → `TeacherBloc.halaqat`; dashboard lists them |
| O2 | Teacher knows **which halaqat meet today** | **Partial** | `halaqat.schedule` slots exist; `HalaqaWeeklySessionsMapper` derives weekly sessions **but only for one halaqa and only on the student schedule page**. No teacher "today across my halaqat" view |
| O3 | Teacher handles **multiple halaqat** today | **Partial** | Dashboard shows `halaqat.first` as "next"; no per-day multi-halaqa agenda |
| O4 | Teacher handles **multiple sessions in one day** | **Partial** | Mapper emits one `ClassSessionEntity` per slot; not surfaced for teacher, not deduped to "today" |
| O5 | **No session today** | **Missing** | Nothing computes "today has 0 sessions"; dashboard always shows a halaqa shortcut |
| O6 | Today is a **holiday / off day** | **Product decision** | No holiday concept; only weekly slots exist |

### 1.2 Before the session (readiness)

| # | Real operation | Classification | Evidence |
|---|----------------|----------------|----------|
| O7 | Roster is loaded and correct | **Verified** | `GetHalaqaStudentsUseCase` (needs `whereIn` chunking — audit P1-2) |
| O8 | Is **today's homework already assigned?** | **Missing (derivable)** | `assignments` has `halaqaId`, `assignedBy`, `dueDate`; no query "did this halaqa get an assignment for today?" |
| O9 | Are there **leftover pending reviews** from yesterday? | **Partial** | `recitationRecords.reviewStatus == 'pending'` exists; `getHalaqaRecitationRecords` loads all then UI filters; not summarized as "N pending" pre-session |
| O10 | Meeting link ready (online halaqa) | **Verified** | `halaqat.meetingLink`; class detail "join" button |

### 1.3 During the session (execution)

| # | Real operation | Classification | Evidence |
|---|----------------|----------------|----------|
| O11 | **Take attendance** (P/A/L) | **Verified** | W2: `TeacherAttendancePage` → `SaveDayAttendanceEvent`, deterministic IDs |
| O12 | **Evaluate recitation** (live) | **Verified** | `AddRecitationRecordEvent`; evaluations page "+ تقييم جديد" |
| O13 | **Review pending** homework submissions | **Verified** | `UpdateRecitationReviewEvent` (transaction, same doc) |
| O14 | **Assign / adjust homework** for next time | **Verified** | W1: `SendAssignmentEvent` from class detail |
| O15 | Everything reachable from **one place** during class | **Partial** | All exist, but split across class-detail tabs + separate routes; no single "run today's session" surface |

### 1.4 After the session (closeout / honesty)

| # | Real operation | Classification | Evidence |
|---|----------------|----------------|----------|
| O16 | Was **attendance actually taken today?** | **Missing (derivable)** | `attendanceRecords` by `halaqaId` + today range already queried in W2 datasource; not surfaced as "register complete? N/total" on the day agenda |
| O17 | Was **homework assigned** for the day? | **Missing (derivable)** | See O8 |
| O18 | Are **yesterday's reviews cleared?** | **Partial** | Pending count derivable from `recitationRecords`; not summarized |
| O19 | Honest **"today's work: done / incomplete"** signal | **Missing** | No aggregation of O16–O18 |
| O20 | Parents/students perceive the day | **Verified (indirect)** | Parent weekly + student progress already reflect attendance + reviewed recitations |

### 1.5 Definition — "Today's work" (approved)

**Derived at read time (D8/D10)** from Verified data — "Today's work" for a halaqa that has a session today =

1. **Attendance register complete** — reuse W2 `attendanceRecords` + `AttendancePolicy` (roster covered for calendar day).  
2. **Homework assigned** — reuse **exact W1 definition** (D3): current assignment = latest `dueDate` (W1 D7). No second interpretation.  
3. **Pending reviews** — reuse W1 `reviewStatus == pending` on `recitationRecords` (D4 — never reimplement).  

W3 does **not** invent new persisted state; it **derives** signals and deep-links into existing workflows (D5).

---

## 2. Workflow diagram (orchestration of existing pieces)

```text
                         ┌──────────────────────────────────────────┐
                         │  Teacher opens app (arrival)               │
                         └───────────────────┬──────────────────────┘
                                             │  reuse: GetTeacherHalaqatUseCase
                                             ▼
                    ┌────────────────────────────────────────────────┐
                    │  DAY AGENDA (new orchestration, no new module)   │
                    │  for each halaqa: derive today's session(s)      │
                    │  reuse: HalaqaWeeklySessionsMapper (per halaqa)  │
                    └───────┬───────────────┬───────────────┬─────────┘
              today has     │               │ no session    │ multiple
              session(s)    ▼               ▼ today         ▼ halaqat/sessions
        ┌───────────────────────────┐  ┌──────────────┐  ┌──────────────────┐
        │ Readiness per session:     │  │ honest empty │  │ list, sorted by   │
        │  • roster (GetHalaqaStud.) │  │ "لا حصص اليوم"│  │ startAt           │
        │  • homework assigned? (der)│  └──────────────┘  └──────────────────┘
        │  • attendance complete?(der)│
        │  • pending reviews? (der)  │
        └───────────┬────────────────┘
                    │ tap a session → REUSE existing surfaces (no new screens)
        ┌───────────┼───────────────────────────────┬───────────────────────┐
        ▼           ▼                                ▼                       ▼
  Attendance   Evaluations                     Assign homework         Class detail
  (W2 page)    (add + review pending)          (W1 sheet)              (roster/tabs)
  SaveDay...   Add/UpdateRecitation...         SendAssignment...       existing route
        │           │                                │                       │
        └───────────┴────────────────────────────────┴───────────────────────┘
                    │ after actions → same derived signals refresh
                    ▼
        ┌────────────────────────────────────────────┐
        │  DAY CLOSEOUT signal (derived, honest):      │
        │  register complete? homework assigned?       │
        │  reviews cleared? → "اليوم مكتمل / ناقص"      │
        └────────────────────────────────────────────┘
                    │ downstream (already Verified)
                    ▼
     Parent weekly report + Student progress reflect the day (no W3 change)
```

---

## 3. Existing implementation map

### 3.1 By layer (what already exists)

| Layer | Component | Today's role | W3 use |
|-------|-----------|--------------|--------|
| **Schedule** | `halaqat.schedule` (Firestore field) | Weekly slots (day + start/end) | Source of "does this halaqa meet today?" |
| | `ScheduleRemoteDatasource.getHalaqaScheduleSource` | Reads one halaqa's schedule | Reuse per halaqa (or extend to teacher's set) |
| | `HalaqaWeeklySessionsMapper` | Slots → `ClassSessionEntity` weekly, with live/upcoming/ended | Reuse to compute **today's** sessions |
| | `GetWeeklySessionsUseCase` / `ScheduleBloc` | Per-halaqa weekly sessions (student page) | Reuse logic; **not** the teacher-day aggregator yet |
| | `ClassSessionEntity` (live/upcoming/ended, canJoin) | Session VO | Reuse as agenda row |
| **Teacher** | `GetTeacherHalaqatUseCase` → `TeacherBloc.halaqat` | Teacher's halaqat + `schedule` + `studentIds` | Iterate halaqat for today's agenda |
| | `TeacherDashboardTab` | Header + stats + `halaqat.first` shortcut | Candidate host for Day Agenda (reuse, enhance) |
| | `GetHalaqaStudentsUseCase` | Roster | Readiness: roster size / names |
| | `GetHalaqaAttendanceForDateUseCase` | Day attendance (deduped) | Readiness: register complete? |
| | `SaveDayAttendanceUseCase` (W2) | Atomic day save | During session |
| | `GetHalaqaRecitationRecordsUseCase` | All halaqa recitations | Readiness: pending count; During: review |
| | `AddRecitationRecordUseCase` / `UpdateRecitationReviewUseCase` | Live eval / review | During session |
| | `SendAssignmentUseCase` (W1) | Assign homework to roster | During session; readiness: assigned? |
| **Homework** | `assignments` (`halaqaId`, `assignedBy`, `dueDate`, tasks) | SSOT | Derive "assigned for today?" |
| **Attendance** | `attendanceRecords` (deterministic day IDs) | SSOT | Derive "register complete?" |
| **Evaluations** | `recitationRecords` (`reviewStatus`) | SSOT | Derive "pending reviews?" |
| **Shared** | `AttendancePolicy` | Day/percent/dedupe | Reuse dayStart + dedupe for completeness |
| | `halaqaScheduleLabel` | Schedule display | Reuse labels |
| | `time_format.dart` | Date/time formatting | Reuse |
| | `SectionStatus` / `AppErrorWidget` / snackbars | State + UX | Reuse |
| **Routing** | `/teacher`, `/teacher/halaqa/:id`, `/teacher/attendance/:id`, `/teacher/halaqa/:id/evaluations` | Existing destinations | Agenda deep-links into these |

### 3.2 Entry points already wired

- Teacher home → dashboard tab (default surface on arrival).  
- Dashboard → class detail (`/teacher/halaqa/:id`).  
- Class detail tabs → attendance (link), evaluations (link), assign (sheet), roster.  
- All the "do the work" actions exist and are Verified from W1/W2.

---

## 4. Reuse map (W3 = wiring, not building)

| W3 need | Reuse (existing) | New (thin) required? |
|---------|------------------|----------------------|
| Teacher's halaqat | `GetTeacherHalaqatUseCase` | No |
| Does halaqa meet today? | `HalaqaWeeklySessionsMapper` + `halaqat.schedule` | Thin: filter mapper output to **today** (in-memory) |
| Aggregate **all** teacher halaqat sessions today | `GetWeeklySessionsUseCase` (per halaqa) | Thin: orchestrating use case that maps over `TeacherBloc.halaqat` (no new datasource, no new collection) |
| Register complete? | `GetHalaqaAttendanceForDateUseCase` + `AttendancePolicy` | Thin: compare deduped count vs roster size |
| Homework assigned for today? | `assignments` query | Thin: **one** query use case `hasAssignmentForDay(halaqaId, day)` (reuse collection + likely reuse existing index) |
| Pending reviews count | `GetHalaqaRecitationRecordsUseCase` | Thin: count `reviewStatus == pending` (client) |
| Take attendance / evaluate / review / assign | W2 page, evaluations page, W1 sheet | No — deep-link |
| State/UX | `SectionStatus`, `AppErrorWidget`, `RefreshIndicator` | No |
| Day/date | `AttendancePolicy.dayStart`, `time_format` | No |

**Net new code footprint (proposed):** one orchestration use case + one bloc (or extend `TeacherBloc`) + one agenda UI surface (host inside existing teacher dashboard). **No new Firestore collection. No new persisted field** (unless a decision below approves one).

---

## 5. Product gaps (what's genuinely absent)

| ID | Gap | Nature | Notes |
|----|-----|--------|-------|
| G1 | No **teacher "today across my halaqat"** aggregation | Missing orchestration | Core of W3 |
| G2 | No **"is today a session day?"** for teacher | Missing (derivable) | Mapper exists; not filtered to today for teacher |
| G3 | No **"homework assigned today?"** signal | Missing (derivable) | Needs "for today" definition (D3) |
| G4 | No **"register complete?"** signal | Missing (derivable) | Reuse W2 day query + roster |
| G5 | No **pending-review backlog** summary | Missing (derivable) | Count from recitationRecords |
| G6 | No **day closeout / honest "day incomplete"** | Missing | Aggregate G3–G5 |
| G7 | No **holiday / no-session** concept | Product decision | Weekly slots only |
| G8 | Attendance **not bound** to a specific session slot | Carried from W2 D7 | Keep calendar-day; do not bind unless D5 |
| G9 | Multiple sessions same day for same halaqa | Product decision | Two slots same weekday → one register or two? (D6) |
| G10 | No absence/late **notification** to parents at session close | Deferred (W2 D2) | Out of W3 unless reopened |

---

## 6. Product decisions (approved)

| # | Decision | Resolution |
|---|----------|------------|
| **D1** | Agenda host | **Approved** — enhance existing `TeacherDashboardTab`. No new page/route |
| **D2** | Product objective | **Approved** — dashboard answers one question: **What should I do today?** Everything in W3 supports that |
| **D3** | Homework "for today" | **Approved** — reuse **exact W1 definition** (latest `dueDate` / W1 D7). No second interpretation. Homework SSOT stays in W1 |
| **D4** | Policies | **Approved** — reuse every existing W1/W2 policy (attendance, homework, evaluation, reporting). **Never reimplement** inside W3 |
| **D5** | Execution | **Approved** — agenda orchestrates only; execution deep-links into existing screens. No duplicated UI |
| **D6** | Multiple slots same day | **Approved** — same halaqa + same calendar day = **one** operational teaching day. Do not split attendance/homework by slot |
| **D7** | Multi-halaqa order | **Approved** — stable execution order: **schedule time first**; if equal/missing, fall back to **stable app ordering** (`halaqaId` lexicographic). Never random across launches |
| **D8** | Readiness derivation | **Approved** — all readiness indicators derived at **read time**. Never cache operational state |
| **D9** | Tone | **Approved** — assist, never blame. Neutral copy only (e.g. «لم يتم تسجيل الحضور بعد»، «لم يتم إرسال واجب اليوم»، «توجد تسميعات بانتظار المراجعة») |
| **D10** | Persistence | **Approved** — no new collections, fields, orchestration persistence, `sessionCompleted`, or `teacherOpenedSession`. Compute from existing data |

### Engineering rules (approved)

- Before every slice: search for existing helpers/policies/mappers/formatters; prefer reuse; extend safely rather than create parallels.
- Orchestration layer owns only: determine today's work → determine readiness → navigate to existing workflows.
- Business logic remains owned by W1 and W2.

---

## 7. Proposed slices (small, releasable, reuse-first)

Order mirrors W1/W2: derive/read first, then optional actions. Each slice: analyze → format → commit → push → usable.

| Step | Name | What it adds | Immediately usable? |
|------|------|--------------|---------------------|
| **Pre-Slice** | Today-session derivation helper | **Done + validated** — `mapTodayOperationalDays`; unit tests; day SSOT = `AttendancePolicy.dayStart`; sole consumer of `map()` still `ScheduleRepositoryImpl` | Foundation |
| **Slice 1** | **Day Agenda + zero-new-query readiness + deep-links** | **Done + validated** — `TeacherDashboardTab` (D1) consumes a derived `TeacherDayAgenda` (`GetTodayAgendaUseCase` in the bloc, never the widget tree). Lists today's halaqat with **remaining** work only; each row deep-links to the existing attendance page / evaluations. Readiness reuses existing reads with **no new query/index**: register-incomplete (W2 `attendanceRecords(halaqaId,date)` + roster) and pending reviews (W1 `reviewStatus`). Completed work is removed; calm honest empty states. Replaced the old shortcut + quick-links cards → dashboard is simpler. | Yes — teacher sees today's work and navigates |
| **Slice 2** | **Homework-assigned readiness** | **Done + validated** — `TeacherAgendaAction.sendHomework` via W1 D7 at halaqa scope (`getLatestAssignmentDueDate`: `where halaqaId` + `orderBy dueDate desc` + `limit 1`). "Today" = latest dueDate's calendar day via `AttendancePolicy.dayStart`. Deep-link → existing class detail (assign sheet host). New composite index documented below. | Yes — completes "what's missing" |
| **Slice 3** | **Deep-link actions (remaining)** | **Done + validated** — `sendHomework` → `/teacher/halaqa/:id?assign=1`; opens existing assign sheet once when `studentsHalaqaId` matches. See `docs/W3_SLICE3_PRODUCTION_VALIDATION.md`. | Yes — one hub to run the day |
| **Slice 4** | **Day closeout signal** | Aggregate Slice 2 into honest "اليوم مكتمل / ناقص" with neutral D9 wording | Yes — end-of-day honesty |
| **Slice 5** | Consistency audit + production validation | W1/W2-style report; refresh/empty/error/permissions parity | DoD |

**Optional later (not W3 unless approved):** absence notifications, supervisor register view, holiday calendar.

### Index/query note (Verified)

**Slice 2 requires one new composite index** on `assignments`:

| Fields | Why required |
|--------|----------------|
| `halaqaId` ASC + `dueDate` DESC | Teacher readiness must answer "what is this halaqa's current assignment?" using the **same W1 D7 rule** (latest `dueDate`) but scoped to the halaqa. |

**Why an existing query cannot satisfy this:**
- The only existing assignments read is student-scoped: `where studentId` + `orderBy dueDate desc` + `limit 1` (Home / Homework).
- That cannot answer per-halaqa readiness without N student queries (roster size) and still would not be a single halaqa-level "current" under D7.
- `sendAssignment` already writes `halaqaId`; no new field. Extending `TeacherRemoteDatasource` with `getLatestAssignmentDueDate` reuses the collection and W1 ordering — only the equality field changes from `studentId` → `halaqaId`.

Register-complete continues to reuse the existing `attendanceRecords(halaqaId, date)` query + `AttendancePolicy.isRegisterComplete` (no new index).

### Pre-Slice production validation (2026-07-25)

**Verdict: Pass.** Slice 1 may begin after explicit approval.

| Area | Result |
|------|--------|
| Architecture | Extended existing mapper; no new business-rule layer; no W1/W2 logic copied; `AttendancePolicy.dayStart` is day-boundary SSOT |
| Correctness | 16 unit tests covering empty / one / multi-halaqa / multi-slot / out-of-order / equal-time / day-boundary / overnight clamp / duplicates / deterministic |
| Maintainability | Pure, deterministic, no Firestore/Bloc/UI/nav/cache |
| Performance | O(H×S) over already-loaded schedules — acceptable (H and S small); not optimized further |
| Regression | Only `ScheduleRepositoryImpl` calls `map()`; weekly `map()` regression tests pass |
| Fix applied | D7 sort uses map-key `halaqaId` instead of parsing operational-day ids |

**Accepted pre-existing behavior (not a Pre-Slice regression):** if slot `endTime` ≤ `startTime` (e.g. overnight `22:00–01:00`), `map()` clamps end to `startAt + 1h` on the same calendar day. W3 D6 remains calendar-day operational (no overnight session model).

### Slice 1 production validation (2026-07-26)

**Verdict: Pass.** Slice 2 may begin after explicit approval.

**Scope reconciliation (honest note):** the approved plan put readiness in Slice 2. The approved Slice 1 constraints asked the agenda to also answer "what still needs attention?" and to remove completed work. To honor both while keeping Slice 1 small, Slice 1 ships only the two readiness signals that reuse existing reads with **no new Firestore query or index** (register-incomplete, pending reviews). The **homework-assigned** signal — the one that needs a new halaqa-scoped assignment query/index — is deferred to Slice 2, exactly where the design already flagged that index question.

| Area | Result |
|------|--------|
| Composition | Dashboard consumes `state.todayAgenda`; all derivation in `GetTodayAgendaUseCase` via the bloc — no computation in the widget tree |
| Orchestration only | Reuses `mapTodayOperationalDays` (D6/D7 + `AttendancePolicy` day SSOT), W2 attendance read, W1 recitation read + `isPendingReview`; no business rule or policy re-implemented |
| Persistence | Read-time only — no new collection/field, no cached flag, no orchestration state (D8/D10) |
| Remaining-work focus | Completed actions removed from the agenda; empty roster never actionable; honest empty states ("لا توجد حصص مجدوَلة اليوم" vs "لا يوجد عمل متبقٍّ اليوم") |
| Deep-links | Every row opens an existing route (`/teacher/attendance/:id`, `/teacher/halaqa/:id/evaluations`); no duplicated UI |
| Tone (D9) | Neutral wording: "لم يتم تسجيل الحضور بعد", "توجد تسميعات بانتظار المراجعة" |
| Simplicity | Removed `_HalaqaShortcutCard` + `_HalaqaQuickLinksCard`; one focused "عمل اليوم" section replaces two decorative cards |
| Correctness | 10 unit tests (empty / not-today / attendance-incomplete / pending-review / both-in-order / completed-removed / empty-roster / D7 ordering / two failure paths) |
| Analyze / format / tests | New code clean (remaining infos are pre-existing `withOpacity`); `dart format` applied; full suite green |
| Performance | O(today-halaqat) reads — 2 per today-halaqa (attendance + recitations). Recitation read is unbounded (same as evaluations page); acceptable for Slice 1, revisit if it grows |

### Architecture verification (pre-Slice 2, 2026-07-26)

Audited `GetTodayAgendaUseCase` against the orchestration rules. **Two violations found and fixed before Slice 2:**

| Rule | Slice 1 status | Fix |
|------|----------------|-----|
| Reuse W1/W2 policies | **Fail** — `_attendanceIncomplete` invented register-complete comparison inside the use case | Moved to `AttendancePolicy.isRegisterComplete` / `isRegisterIncomplete` (W2 policy SSOT) |
| Must not duplicate attendance logic | **Fail** (same) | Use case now only calls the policy |
| Must not duplicate recitation visibility | **Pass** — uses `RecitationRecordEntity.isPendingReview` only | — |
| Must not encode dashboard-specific business rules elsewhere | **Fail** — D7 sort re-encoded in the use case after per-halaqa mapper calls | Use case now calls `mapTodayOperationalDays` **once** over all sources and trusts mapper order |
| `TeacherDayAgenda` is a projection, not a domain model | **Warn** — lived under `domain/entities` | Moved to `domain/read_models/` with explicit projection docs |

After fixes: use case is a thin application orchestrator only.

### Slice 2 production validation (2026-07-26)

**Verdict: Pass** — full report: `docs/W3_SLICE2_PRODUCTION_VALIDATION.md`.

Validation found and fixed before Pass:

| Finding | Fix |
|---------|-----|
| Fragile parse of `${halaqaId}_yyyyMMdd` in orchestrator | Mapper returns `TodayOperationalDay(halaqaId, session)` |
| Private `_isLatestDueToday` in use case | `AttendancePolicy.isSameCalendarDay` |
| Empty roster showed sendHomework while assign is blocked | Skip homework action when roster empty |
| Pull-to-refresh dismissed before agenda finished | Wait for `todayAgendaStatus` loaded/error |
| Agenda stale after attendance / assign / review writes | `LoadTodayAgendaEvent` on those successes |

| Area | Result |
|------|--------|
| Homework readiness | W1 D7 at halaqa scope: latest `dueDate`; "today" via `AttendancePolicy.isSameCalendarDay` |
| Infrastructure | Extended `TeacherRepository` / remote DS with `getLatestAssignmentDueDate`; reuses `assignments` |
| Index | `assignments(halaqaId ASC, dueDate DESC)` — documented why student-scoped query cannot answer this |
| Deep-link | `sendHomework` → `/teacher/halaqa/:id` (existing host); sheet auto-open = Slice 3 |
| Tone (D9) | «لم يتم إرسال واجب اليوم» |
| Analyze / format / tests | Touched code clean; suite green |

---

## 8. Actors affected

| Actor | W3 impact |
|-------|-----------|
| **Teacher** | Primary — gains a daily operating surface orchestrating existing tools |
| **Student** | None new — already reflected via progress/homework (Verified) |
| **Parent** | None new — weekly report already reflects the day (Verified) |
| **Supervisor** | **Out of W3** (D9) |
| **Admin** | **Out of W3** |

---

## 9. Explicitly OUT of W3

- ❌ New **"Session" module / collection** (mandate: orchestrate, don't build).  
- ❌ New Firestore **collections**.  
- ❌ New persisted **fields** (`sessionId`, `sessionOperated`, holiday flags) — D10.  
- ❌ **Slot-bound attendance** (keep W2 D7 calendar-day; D6 = one day).  
- ❌ **Absence/late notifications** (W2 D2 deferred).  
- ❌ **استئذان / absenceRequests** UI (W2 D3).  
- ❌ **Supervisor** unmarked-register dashboard (W2 D4).  
- ❌ **Holiday/term calendar** engine.  
- ❌ **Payments, learning-plan engine, audio recitation infra** (separate workflows).  
- ❌ **Admin dashboards / gamification.**  
- ❌ Rebuilding attendance/homework/evaluation UIs — **deep-link into existing ones only** (D5).  
- ❌ Figma-driven parallel screens — Figma is **UI reference only**.  
- ❌ Reimplementing W1/W2 business rules inside W3 (D4).

---

## 10. Risks

| Type | Risk | Mitigation |
|------|------|------------|
| **Architecture** | W3 becomes a parallel "session" stack | Hard rule: orchestration + deep-links; reuse existing use cases/pages |
| **Product** | "Today's work" definition ambiguous | Lock D3 (assigned), D4 (pending), D6 (multi-slot) before Slice 2 |
| **Technical** | Per-halaqa schedule reads = N reads for N halaqat | Halaqat already loaded in `TeacherBloc` with `schedule` inline → derive today's sessions **in memory**, avoid extra reads |
| **Technical** | Homework-for-today query needs new index | Confirm in Slice 2; reuse existing shape if possible |
| **Product** | Empty/holiday confusion | Honest "لا حصص اليوم"; holidays deferred (D7) |
| **Scale** | Roster `whereIn` (audit P1-2) | Address as shared fix; not a new W3 debt |
| **Security** | No Firestore rules in repo (audit P0-1) | Platform gap; W3 reads teacher-owned data only, no widened writes |

---

## 11. Definition of Done (W3)

W3 is **Done** only if all are true:

1. Teacher immediately understands today's operational state (**What should I do today?** — D2).  
2. Every agenda item opens an **existing** workflow (D5).  
3. No business logic duplicated (D3, D4).  
4. No UI duplicated (D5).  
5. No Firestore schema changes (D10).  
6. No workflow-specific persistence (D10).  
7. Dashboard complexity is **reduced**, not increased (D1).  
8. Neutral assistive wording only (D9).  
9. `flutter analyze` clean; code formatted; committed and pushed per slice.  
10. Docs reflect the final architecture.  
11. Production validation (W1/W2 style) before marking Done.  
12. If a slice assumption is wrong: **stop**, update this doc, continue.

---

## Approval gate

**Phase 0 approved (D1–D10).**  
**Pre-Slice + Slice 1 + Slice 2 + Slice 3 production-validated (Pass)** —  
`docs/W3_SLICE2_PRODUCTION_VALIDATION.md`, `docs/W3_SLICE3_PRODUCTION_VALIDATION.md`.  
Execution remaining: Slice 4 (closeout) → 5 (audit + production validation).  
**Do not start Slice 4 until explicitly approved.**  
**Ops note:** deploy the `assignments(halaqaId, dueDate)` composite index before relying on homework readiness in production.
