# W6 — Supervisor Day Oversight
## Phase 0 Technical Design

**Status:** Phase 0 approved · **W6 COMPLETE** (see `W6_COMPLETION_PRODUCTION_VALIDATION.md`)  
**Date:** 2026-07-29  
**Predecessors:** W1–W5 complete; Post-W5 roadmap re-rank approved (W6 = Supervisor Day Oversight)  
**Standing rule:** If an assumption is wrong: **stop**, update this document, then continue.

### Classification

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed directly in current code or an approved product decision |
| **Inference** | Conclusion supported by Verified facts, but not an approved product rule |
| **Product Decision** | A choice that changes workflow behavior and requires approval |

### Permanent architecture rules (W6)

#### Rule 1 — Supervisor is an operational observer, not another teacher (**approved**)

The supervisor workflow must answer:

- Which halaqat need attention?
- Which teacher needs support?
- Which classroom is blocked?
- Which daily workflows are incomplete?

It must **not** become another place to perform teacher operations.

The supervisor should **coordinate**, not duplicate teacher responsibilities.

#### Rule 2 — Escalation over duplication (**approved**)

Whenever possible, the supervisor should navigate to the **existing teacher-owned workflow** instead of performing the same action from a second UI.

For every supervisor action, ask:

- Is this **supervision**?
- Or is this actually **teaching**?

If it is teaching, **deep-link / escalate** to the existing workflow instead of creating another write path.

#### Rule 3 — Exception-first design (**approved**)

The supervisor should not spend time looking at healthy halaqat.

The default experience should surface only **exceptions**:

- attendance incomplete  
- homework missing  
- pending reviews  
- blocked workflows  

Healthy halaqat should be **minimized or collapsed by default**.

The supervisor’s attention is the scarce resource.

#### Rule 4 — Explain why, not only what (**approved**)

Every readiness signal should answer two questions:

- What is incomplete?  
- Why is it incomplete?  

Avoid generic statuses.

Examples:

- Attendance not submitted.  
- Homework not assigned today.  
- 3 recitations still pending review.  

The supervisor should immediately know the next action without opening multiple screens.

Presentation owns wording; the shared readiness projection owns the **facts** (gap kind + quantities) that make those answers possible.

#### Rule 5 — Readiness must be role-neutral (**approved**)

`HalaqaDayReadinessProjector` should describe only **academy facts**.

It must never know:

- Teacher UI  
- Supervisor UI  
- Dashboard layout  
- Card priority  
- Colors  
- Navigation  
- Permissions  

Those belong entirely to the presentation layer.

The projector answers only:

- What is complete?  
- What is incomplete?  
- Why is it incomplete?  

Nothing more.

**Priority belongs to the consumer.** Teacher and Supervisor may consume the same readiness differently:

- Teacher focuses on “what do I need to do?”  
- Supervisor focuses on “which halaqat require attention?”  

Both consume the same readiness projection **without changing it**.

If any supervisor (or teacher) presentation logic appears inside the projector, treat it as an architectural regression.

#### Rule 6 — Escalation is guidance, not ownership (**approved**)

The supervisor does **not** “take over” the workflow.

The supervisor’s responsibility is to identify the blocked workflow and **direct attention** to the existing owner.

Escalation should always answer:

- Who owns this action?  
- Why does it need attention?  
- Where should the supervisor go?  

It should **never** transfer business ownership from teacher to supervisor.

**Permission fallback (presentation):** if the supervisor cannot navigate to the teacher workflow, the UI still provides teacher name, halaqa name, and readiness explanation — **without** exposing unavailable actions.

If escalation requires modifying the projector or creating supervisor-specific business logic → architectural regression.

#### Rule 7 — Every operational conclusion must be explainable (**approved**)

The supervisor should never see a status that cannot be traced back to academy facts.

Every readiness or escalation state must be explainable by answering:

- Which academy facts produced this state?  
- Which workflow owns those facts?  
- Which action would resolve the issue?  

The explanation must be derived from the existing **W1–W5 facts**, never from supervisor-specific calculations.

If any displayed state cannot be explained from existing academy facts → architectural regression.

### Standing product rules carried forward

- Domain ownership over feature ownership  
- Event = domain fact (not notification)  
- What / who / how separation; event evolution; versioning; payload ownership; observer independence; ordering; delivery isolation; idempotency; observability; future compatibility  
- No Category B work inside W6 (rules, Storage/Blaze, CI, B-R8 client retries)  
- Platform Epic **P-E1** (role logout / identity reset) stays **out of W6** unless a slice is blocked without it  

### Debt-track boundary

- **Category A** may join W6 only when it directly protects or simplifies this oversight workflow.  
- **Category B** does not gate W6.

---

## 0. Goal (oversight, not a second teacher app)

### 0.1 Workflow (proposed)

W6 gives the supervisor a **read projection** of today’s operated day across supervised halaqat, derived from the same W1–W5 facts teachers already produce.

```text
Teacher operates the day (W1–W5)
  → attendance / assignments / recitationRecords remain SSOT
  → shared readiness projection (same W3 rules)
  → supervisor sees exceptions first (Rule 3) with explainable gaps (Rule 4)
  → teaching actions escalate to teacher-owned workflows (Rule 2)
  → no supervisor-owned attendance, homework, or review write path
```

### 0.2 Success criteria (approved product bar)

At any moment the supervisor must be able to answer, using **existing W1–W5 facts**:

| Question | Same fact as teacher day (W3) |
|----------|-------------------------------|
| Which halaqat have **not** completed attendance? | Register incomplete — `AttendancePolicy` |
| Which halaqat still have **pending homework work**? | Latest assignment `dueDate` not today — W1 D7 |
| Which halaqat still have **pending reviews**? | Any `recitationRecords` with pending review |
| Which halaqat have **completed** today’s operational workflow? | Session today + no remaining attendance/homework/review gaps |

**Hard constraints:**

- Do **not** introduce a second SSOT.  
- Do **not** introduce supervisor-owned attendance, homework, or review logic.  
- Do **not** invent a new “session complete” flag in Firestore.

### 0.3 What W6 is not

- Another attendance register UI that writes marks  
- Another homework assign sheet  
- Another recitation review sheet  
- A supervisor-only notification product  
- Platform logout / session integrity (**P-E1**)

---

## 1. Real academy operations (supervisor)

| # | Real operation | Classification | W6 consequence |
|---|----------------|----------------|----------------|
| S1 | Supervisor owns a set of halaqat | **Verified** | `halaqat.where('supervisorId' == uid)` |
| S2 | Knows which teachers run those halaqat | **Partial** | `HalaqaEntity.teacherId` + display name (D-W6-4) |
| S3 | Sees which classrooms are blocked today | **Missing (derivable)** | Shared readiness projection across supervised set |
| S4 | Escalates to the teacher who must act | **Missing** | Rule 2 — D-W6-1 |
| S5 | Takes attendance / reviews / assigns for the teacher | **Must not** | Forbidden by Rule 1 |
| S6 | Issues achievements / writes reports / links students | **Verified** (existing supervisor home) | Secondary (D-W6-5) |

---

## 2. Current implementation map

### 2.1 Reusable — Verified

| Piece | Location | Role in W6 |
|-------|----------|------------|
| Supervised halaqa list | `getSupervisedHalaqat` | Input set for the day board |
| Today’s operational days | `HalaqaWeeklySessionsMapper.mapTodayOperationalDays` | Same “meets today?” as W3 |
| Register completeness | `AttendancePolicy.isRegisterIncomplete` | Attendance gap |
| Homework assigned today? | `getLatestAssignmentDueDate` + `isSameCalendarDay` | Homework gap (W1 D7) |
| Pending reviews | `RecitationRecordEntity.isPendingReview` | Review gap |
| Teacher day orchestration | `GetTodayAgendaUseCase` | Must consume shared readiness (D-W6-3) |
| Teacher day closeout | `TeacherDayAgenda.closeout` | Pattern for complete vs incomplete counts |
| Teacher deep-link targets | Attendance / class detail / evaluations routes | Escalation destinations when allowed |

### 2.2 Gaps — Verified

| Gap | Evidence |
|-----|----------|
| Supervisor has **zero** attendance/homework/review reads | `lib/features/supervisor/` never touches those collections |
| Teacher agenda **hides** completed halaqat | Only remaining-work items; supervisor needs completed too (collapsed by default — Rule 3) |
| Role guard locks supervisor to `/supervisor*` | `AppRouter._isAllowedRoute` — cannot open `/teacher/...` today |
| Day-readiness lived only under teacher feature | Pre-Slice extracts shared projector |
| No teacher display name on halaqa | Only `teacherId` — Slice 1 enrichment |

### 2.3 Domain-ownership note — Verified after D-W6-3

Day-readiness is an **academy operations** projection. One shared owner; teacher agenda and supervisor board both consume it. No duplicated `isRegisterIncomplete` / dueDate / pending checks.

---

## 3. Proposed workflow shape

### 3.1 Read model (projection only)

```text
SupervisorDayBoard (read projection, not persisted) — Slice 1+
  for each supervised halaqa that meets today:
    halaqaId, halaqaName
    teacherId + teacherDisplayName
    startAt
    readiness: HalaqaDayReadiness (shared Pre-Slice facts)
    default UI: exceptions first; healthy collapsed (Rule 3)
```

| Status | Meaning (derived) |
|--------|-------------------|
| needs attention (exception) | ≥1 gap |
| complete (healthy) | Session today and **zero** gaps — minimized by default |

No new Firestore fields. No supervisor event types required for MVP (**Inference**).

### 3.2 Answers mapped to UI (one job per section)

| Supervisor question | Board signal |
|---------------------|--------------|
| Which halaqat need attention? | Exception rows first (Rule 3) |
| Which teacher needs support? | Halaqa name + teacher display name (D-W6-4) |
| Which classroom is blocked? | Explainable gaps (Rule 4) |
| Which daily workflows are incomplete? | Same gaps |
| Which halaqat completed today’s workflow? | Healthy set — collapsed / secondary |

### 3.3 Escalation (Rule 2) — D-W6-1 **approved**

| Gap | Teaching action (forbidden to re-build) | Supervision / escalation |
|-----|----------------------------------------|---------------------------|
| Attendance incomplete | Mark register | Deep-link when permissions allow; else facts + responsible teacher |
| Homework pending | Send assignment | Same |
| Reviews pending | Review pending recitations | Same |

**Never** create supervisor-owned write paths.

### 3.4 Existing supervisor writes (achievements / reports / student link)

**D-W6-5 approved:** keep visible but secondary to the day board.

---

## 4. Product decisions — locked

| ID | Decision |
|----|----------|
| **D-W6-1** | Prefer cross-role deep-link when permissions allow; else facts + responsible teacher only. Never supervisor write clones. |
| **D-W6-2** | Show complete **and** incomplete; incomplete prioritized (Rule 3 collapses healthy). |
| **D-W6-3** | One shared readiness API consumed by teacher agenda + supervisor board. |
| **D-W6-4** | Show **teacher display name** and **halaqa name** (not IDs). |
| **D-W6-5** | Keep achievements/reports secondary. |
| **D-W6-6** | Exclude “no session today” from operational attention. |

---

## 5. Slices

| Slice | Intent |
|-------|--------|
| **Pre-Slice** | Shared day-readiness projection only (D-W6-3). Wire teacher agenda through it. **No** new business rules, SSOT, supervisor-specific ops logic, or supervisor UI. |
| **Slice 1** | Supervisor day board UI: consume shared readiness directly; exception-first + explainable gaps in **presentation only**; teacher + halaqa names; deep-links to existing teacher workflows when allowed |
| **Slice 2** | Escalation as guidance (Rule 6): who/why/where; permission fallback without fake actions; teacher workflows remain sole execution paths |
| **Slice 3** | Rule 7 explainability from W1–W5 facts; empty/error/loading polish; production validation + W6 completion gate |

### Slice 1 validation bar (approved)

After Slice 1, verify:

1. Supervisor board consumes the shared readiness projection **directly**  
2. No supervisor-specific readiness calculations exist  
3. Teacher behavior is unchanged  
4. The projector has **no** presentation knowledge (Rule 5)  
5. Deep-links only navigate to **existing** teacher-owned workflows  
6. Exception-first ordering is implemented entirely in the **presentation** layer  

If any supervisor logic appears inside the projector → architectural regression.

### Slice 2 validation bar (approved)

After Slice 2, verify:

1. Escalation introduces **no** new write paths  
2. Supervisor never performs teacher operations (writes gated to teacher role)  
3. Existing teacher workflows remain the **only** execution paths  
4. Permission fallbacks stay in the **presentation** layer  
5. Shared readiness projection remains **unchanged**  

If escalation modifies the projector or adds supervisor-specific business logic → architectural regression.

### Slice 3 validation bar (approved)

After Slice 3, verify:

1. Every supervisor status is explainable from underlying W1–W5 facts  
2. No supervisor-only state is persisted  
3. No new readiness rules are introduced  
4. Read-only supervision remains intact  
5. Teacher workflows remain the only execution paths  
6. The board never displays a conclusion that cannot be justified  

Then run the **full W6 completion gate**. Do **not** propose W7 until that gate passes and product approves recommending the next workflow.

Each slice: validate → analyze → tests → format → commit → push → **stop for approval**.

### Pre-Slice constraints (approved)

- Only establish the shared readiness projection  
- No new business rules  
- No new SSOT  
- No supervisor-specific attendance / homework / review logic  
- No UI beyond what is required to validate the projection  

After Pre-Slice production validation: **stop** and wait for approval before Slice 1.

---

## 6. Explicitly out of W6

- Supervisor-owned attendance / homework / review writes  
- Second SSOT or `dayComplete` documents  
- Parent logout / P-E1 session integrity (Platform Epic)  
- Wiring Supervisor as a live `AcademyEventHandler` (allowed later; not required for oversight MVP)  
- Live-eval → event residual (W5) unless it blocks pending-review honesty (it does not — pending path already events)  
- استئذان, payments, Storage, messaging policy rewrite  
- Category B platform hardening  

---

## 7. Success criteria checklist (for later validation)

W6 passes when a supervisor can open the app and, for **today’s supervised sessions**, see **exceptions first** with **explainable** gaps:

1. Halaqat with incomplete attendance (and why)  
2. Halaqat with homework still pending (and why — W1 D7)  
3. Halaqat with pending reviews (and why — including count)  
4. Halaqat with **no** remaining gaps (completed) — available but not the default focus  

…and every teaching CTA either escalates to a teacher-owned workflow or is absent (facts-only), with **zero** new supervisor write paths for those three rituals.

---

## 8. Approval record

| Item | Status |
|------|--------|
| Rules 1–2 | Approved |
| Rules 3–4 | Approved |
| Success criteria / no second SSOT | Approved |
| D-W6-1 … D-W6-6 | Approved as locked above |
| Slice plan + Pre-Slice scope | Approved |
| P-E1 logout remains Platform Epic | Confirmed |
