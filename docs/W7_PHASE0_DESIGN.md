# W7 — Parent Absence Request (استئذان) Lifecycle
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Phase 0 approved · Pre-Slice Pass · Slice 1 Pass · Slice 2 Pass · awaiting Slice 3 approval  
**Date:** 2026-07-29  
**Predecessors:** W1–W6 complete; `docs/POST_W6_PRODUCT_AUDIT.md` (W7 recommendation approved)  
**Standing rule:** If an assumption is wrong: **stop**, update this document, then continue.

### Classification

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed directly in current code or an approved product decision |
| **Inference** | Conclusion supported by Verified facts, but not an approved product rule |
| **Product Decision** | A choice that changes workflow behavior and requires approval before implementation |

### Permanent architecture rules (carried forward + W7)

| Rule | Source | W7 consequence |
|------|--------|----------------|
| Attendance is the SSOT for presence | W2 | Request never replaces `attendanceRecords` |
| Late = attended in aggregates | W2 D1 | Unchanged |
| No `excused` attendance status (unless reopened) | W2 D6 **No** | Do not invent a fourth wire status without an explicit Product Decision |
| Event = domain fact, not notification | W4/W5 | Request lifecycle facts (if any) are events; inbox is a projection |
| What / who / how separation | W5 | Attendance ownership ≠ request ownership ≠ delivery |
| Supervisor observes, does not take over teaching | W6 Rules 1–2, 6 | Supervisor may see request context; teacher owns attendance decisions |
| Explainability from academy facts | W6 Rule 7 | Every displayed request state must cite request + attendance facts |
| Domain ownership over feature ownership | Standing | One owner per rule; extract only for real domain concepts |
| **Rule 1 — Teacher decisions classify the request, not attendance** | **Locked (Slice 2)** | Approve/reject changes **only** the absence request. Attendance remains the only operational presence record. The workflow **never** infers or rewrites attendance from a request decision. |

### Standing boundaries

- **Category A** may join W7 only when it directly protects this lifecycle (e.g. calendar-day via `AttendancePolicy` on request dates).  
- **Category B** (rules, Storage, CI, B-R8) does not gate W7.  
- **Platform Epic P-E1** (logout / identity reset) stays **out of W7** unless a slice is blocked without it.

---

## 0. Goal (lifecycle, not screens)

### 0.1 Workflow in one sentence

A parent submits an **استئذان** (absence request) as **contextual information** around an attendance calendar day; the **teacher** reviews it; **attendance remains the only presence SSOT**; parent (and optionally supervisor) see request outcome without a second attendance ownership path.

### 0.2 Hard product constraints (from approval + audit)

1. **Attendance is the SSOT.**  
2. An absence request is **contextual information around attendance**, never a replacement for it.  
3. **Do not** create parallel ownership for attendance decisions.  
4. Reuse existing attendance, parent relationship, and academy event architecture wherever possible.  
5. Center design on the **complete lifecycle**, not on request screens alone.

### 0.3 End-to-end lifecycle (required shape)

```text
Parent request
  → Teacher review / decision
  → Attendance consequence (without transferring SSOT)
  → Parent visibility
  → Supervisor visibility (if applicable)
```

---

## 1. Real academy operations

| # | Operation | Classification | W7 consequence |
|---|-----------|----------------|----------------|
| R1 | Teacher marks present / absent / late for a calendar day | **Verified** (W2) | Remains sole presence write path |
| R2 | Parent learns of unexplained absence the same day | **Verified** (W4 events → in-app) | Remains; W7 must not invent a parallel absence alert |
| R3 | Parent requests excused absence (استئذان) with reason | **Missing product** / **partial stack** | Close this loop |
| R4 | Teacher (or other role) approves or rejects the request | **Missing** | Must be defined (D-W7-1) |
| R5 | Attendance % / weekly report stay honest | **Verified** (W2 policy) | Must not silently rewrite aggregates via a second SSOT |
| R6 | Supervisor sees classrooms needing attention | **Verified** (W6 readiness) | Optional request context (D-W7-7) — observation only |

---

## 2. Current implementation map (reuse first)

### 2.1 Attendance SSOT — **Verified** (reuse)

| Piece | Location | Role in W7 |
|-------|----------|------------|
| Day register write | `saveDayAttendance` / `attendanceRecords` | Only path that decides presence |
| Wire statuses | `present` / `absent` / `late` (`AttendancePolicy`) | Unchanged unless D-W7-3 reopens W2 D6 |
| Deterministic attendance doc id | `AttendancePolicy.documentId` | Natural join key for “this day / student / halaqa” |
| Day boundaries | `AttendancePolicy.dayStart` / `isSameCalendarDay` | Request `date` must use the same day SSOT |
| Explicit absence transitions | `AttendanceAbsenceTransitions` | Unrelated to request approve; do not overload |

### 2.2 Absence request stack — **Verified** (partial reuse)

| Piece | Location | State |
|-------|----------|--------|
| Collection | `FirestoreCollections.absenceRequests` | Exists |
| Entity | `AbsenceRequestEntity`: + **`halaqaId`** (W7 Pre-Slice); statuses unchanged | Deterministic `id` |
| Model write | `toFirestore` includes `halaqaId` | — |
| Submit write | Deterministic doc `set` (pending); refuses overwrite of approved/rejected | No `.add()` auto-ID |
| Use case | Day normalize + child auth + deterministic id; **never touches attendance** | — |
| ParentBloc | `SubmitAbsenceRequestEvent` / reset + submission status | Wired; **no UI caller** |
| List / watch by parent | — | **Missing** |
| List pending by teacher | — | **Missing** |
| Approve / reject write | — | **Missing** |
| Link to attendance document | — | **Missing** |
| Effect on attendance mark | — | **Undefined** (W4 Phase 0 already flagged) |

**Verified conclusion:** The submit stack is reusable as a *starting write*, but shipping submit-only UI remains a dead end (same rejection reason as W4 D-W4-9 option C). W7 must complete review + visibility, not only open the form.

### 2.3 Parent relationship & visibility — **Verified** (reuse)

| Piece | Location | Role in W7 |
|-------|----------|------------|
| Parent ↔ children | `parentProfiles.childrenIds` | Authorize “requestedBy may request for this student” |
| Parent recipient resolver | W4/W5 observer path | Reuse for request outcome signals if events are chosen |
| In-app delivery | `AcademyEventSink` → fan-out → in-app handler | Prefer over new notification writers |
| Parent weekly attendance | Reads `attendanceRecords` directly | Must keep reading SSOT, not requests, for % |

### 2.4 Academy events (absence) — **Verified** (reuse / extend carefully)

| Event | Meaning | W7 interaction |
|-------|---------|----------------|
| `StudentAbsentRecorded` | Explicit `absent` mark written | May motivate a request; request does not replace it |
| `StudentAbsenceCorrected` | Absent → present/late | Independent teacher attendance action |
| Homework events (W5) | Unrelated | Do not couple |

**Inference:** New request lifecycle facts (submitted / approved / rejected), *if* product wants inbox visibility, should be **new event kinds** — not mutations of `StudentAbsentRecorded` meaning.

### 2.5 Teacher & supervisor surfaces — **Verified**

| Piece | Role in W7 |
|-------|------------|
| Teacher attendance / class detail | Existing place to **decide attendance**; escalation destination for “fix the mark” |
| `TeacherWorkflowOwnership` | Teacher executes teaching writes |
| Supervisor day board (W6) | Attendance **gap** visibility today; **no** request awareness yet |
| Supervisor escalation (Rule 6) | Guidance only — never approve by taking over attendance |

### 2.6 Explicitly unused / do not revive as W7 core — **Verified**

| Piece | Note |
|-------|------|
| Legacy `AbsenceSignalComposer` / old sink files | Not the DI path; Category A cleanup, not W7 feature |
| Admin broadcast `notifications.add` | Parallel delivery ownership — do not copy for استئذان |

---

## 3. Proposed lifecycle shape (design only)

### 3.1 Domain objects (conceptual)

```text
attendanceRecords          = presence SSOT (who was present/absent/late that day)
absenceRequests            = contextual استئذان record (intent + decision)
AcademyEvent (optional)    = facts about request lifecycle for observers
```

**Hard rule:** Approving a request must **not** silently become a second attendance writer. Any change to presence uses the **existing** teacher attendance save path (or does not change presence at all) — see D-W7-3.

### 3.2 Lifecycle stages

| Stage | Actor | Fact produced | Ownership |
|-------|-------|---------------|-----------|
| **Request** | Parent | `absenceRequests` doc `pending` | Parent may create for linked children only |
| **Review** | Teacher (recommended) | `approved` / `rejected` + `reviewedBy` | Teacher decides excuse **context**, not a parallel mark |
| **Attendance consequence** | Per D-W7-3 | Either no SSOT change, or teacher uses existing attendance workflow | Attendance remains teacher-owned |
| **Parent visibility** | Projection | Request status (+ optional event → inbox) | Must remain explainable vs the mark |
| **Supervisor visibility** | Projection (optional) | Pending/decided requests for supervised halaqat | Observation / guidance only (W6 Rule 6) |

### 3.3 Attendance consequence (**D-W7-3 approved: context only**)

Approve/reject updates **only** `absenceRequests` status. It **never** rewrites `attendanceRecords`.

During attendance, the teacher may **see** any pending request and still decides presence **independently** via the existing attendance workflow.

Optional deep-link guidance to the attendance page is presentation-only — not ownership transfer.

### 3.4 Join to attendance day (**D-W7-4**)

Requests require `halaqaId`. Join key: `(halaqaId, studentId, calendarDay)` aligned with `AttendancePolicy.documentId` style.

A request may exist **before** any attendance mark (D-W7-2). Soft link to `attendanceDocumentId` is optional when a mark later appears — it does not create the mark.

### 3.5 Event strategy (**Product Decision D-W7-6**)

| Option | Meaning |
|--------|---------|
| **A. Emit academy facts** `AbsenceRequestSubmitted` / `Approved` / `Rejected` (recommended if inbox visibility is in scope) | Reuses W4/W5 what/who/how; delivery via existing sink |
| B. Poll Firestore only in role UIs | Simpler; weaker cross-role awareness; still valid |
| C. Direct `notifications.add` from parent/teacher writers | **Rejected** — parallel delivery ownership |

Payloads must stay fact-shaped (ids, day, actors, status) — no presentation copy (W5 rules).

---

## 4. Required product decisions (approval gate)

### D-W7-1 — Who reviews / decides the request?

| Option | Meaning |
|--------|---------|
| **A. Halaqa teacher (recommended)** | Matches attendance ownership; supervisor stays observer |
| B. Supervisor | Conflicts with W6 “not another teacher” if decision implies attendance power |
| C. Admin only | Slow; orphans teacher day ops |
| D. Teacher approve + supervisor escalate visibility only | Compatible with A |

**Recommendation: A** (+ D for W6-aligned visibility).

### D-W7-2 — When may a parent submit? (**approved**)

**Parents may submit an absence request before attendance is taken.**

| Locked rule | Meaning |
|-------------|---------|
| Timing | Before **or** after the register — request is not gated on an existing `absent` mark |
| Nature | Contextual information only |
| Attendance | Request must **never** modify attendance automatically |
| Teacher day | During attendance, the teacher **sees** any pending request and decides attendance **independently** |
| Decision write | Approve/reject updates **only** request status (D-W7-3) and **never** rewrites attendance |

### D-W7-3 — Attendance consequence of approve/reject (**approved: context only**)

Approve/reject updates `absenceRequests` only. No auto-write to `attendanceRecords`. Teacher attendance workflow remains the sole presence write path.

### D-W7-4 — Must requests carry `halaqaId`?

| Option | Meaning |
|--------|---------|
| **A. Yes — required field (recommended)** | Enables teacher scope + attendance doc join; fixes multi-halaqa ambiguity |
| B. No — student+date only | Keeps current entity shape; teacher routing ambiguous |

**Recommendation: A** (additive field; existing orphan docs without it remain non-workflow).

### D-W7-5 — Request identity

| Option | Meaning |
|--------|---------|
| **A. Deterministic id** e.g. `{halaqaId}_{studentId}_{yyyyMMdd}` (recommended) | Idempotent resubmit; aligns with attendance id style |
| B. Keep auto-ID `.add()` | Allows duplicate pending requests for same day |

**Recommendation: A** with clear conflict policy (D-W7-8).

### D-W7-6 — Academy events for request lifecycle?

See §3.5. **Recommendation: A** if parent/teacher/supervisor need inbox-quality signals; otherwise B for UI-only MVP.

### D-W7-7 — Supervisor visibility in W7?

| Option | Meaning |
|--------|---------|
| **A. Read-only pending/decided request context on supervised halaqat (recommended light)** | Completes lifecycle clause; Rule 6 — no approve write for supervisor |
| B. Out of W7 — teacher + parent only | Smaller; leaves “if applicable” unused |
| C. Supervisor can approve | **Rejected** by W6 Rules 1/6 unless product overrides |

**Recommendation: A** (observe + escalate to teacher workflow).

### D-W7-8 — Duplicate / supersede policy

| Option | Meaning |
|--------|---------|
| **A. One open (`pending`) request per (halaqa, student, day); resubmit updates reason (recommended)** | Matches deterministic id |
| B. Many pending allowed | Noise; unclear which decision wins |
| C. Parent may submit again only after reject | Stricter process |

**Recommendation: A.**

### D-W7-9 — Relationship to W4 absence inbox signals

| Option | Meaning |
|--------|---------|
| **A. Keep W4 absence signals unchanged; add separate request outcome signals (recommended)** | Absence mark fact ≠ excuse decision fact |
| B. Suppress W4 absent signal when a pending/approved request exists | Hides SSOT; risky |
| C. Replace W4 copy with استئذان language | Couples unrelated facts |

**Recommendation: A.**

### D-W7-10 — Parent visibility surfaces

| Option | Meaning |
|--------|---------|
| **A. Request status on parent absence/day context + optional inbox via events (recommended)** | Lifecycle complete without a second attendance history |
| B. Inbox only | Easy to miss vs the mark |
| C. Weekly report absorbs request into % | Violates “not a replacement” if it alters attended math |

**Recommendation: A**; weekly % continues to use attendance SSOT only.

---

## 4b. Locked decisions (Phase 0 approval)

| ID | Status |
|----|--------|
| Architectural constraints (SSOT, no request-owned attendance, reuse W2/W4/W5/W6) | **Locked** |
| **Rule 1** — Teacher decisions classify the request, not attendance | **Locked** (Slice 2) |
| **D-W7-2** | **Approved** — submit allowed before attendance; never auto-modifies attendance |
| **D-W7-3** | **Approved** — approve/reject updates request status only |
| D-W7-1, D-W7-4…D-W7-10 | Follow recommendations unless later overridden |

---

## 5. Reuse checklist (before any new abstraction)

| Need | Reuse first | New only if unavoidable |
|------|-------------|-------------------------|
| Presence truth | `attendanceRecords` + `AttendancePolicy` | — |
| Day identity | `dayStart` / `documentId` | — |
| Parent authorization | `parentProfiles.childrenIds` / existing parent child loads | Thin guard in submit use case |
| Submit write | `SubmitAbsenceRequestUseCase` + ParentBloc events | Fields: `halaqaId`, deterministic id, maybe `reviewedAt` |
| Teacher review list | Teacher halaqat + students reads | Query `absenceRequests` by teacher scope (halaqa/student/day) |
| Approve/reject | — | Single update path on `absenceRequests` (status + `reviewedBy`) |
| Attendance change | Existing attendance UI / `saveDayAttendance` | **No** request-owned attendance writer |
| Parent/teacher signals | `AcademyEventSink` + observer resolver | New event kinds if D-W7-6 = A |
| Supervisor view | W6 board patterns / supervised halaqat | Read projection of requests — no new SSOT |
| Explainability | W6 Rule 7 style provenance | Map request status + attendance mark to “why” |

**Do not invent:** a second attendance collection, supervisor approve writes, notification writers inside parent/teacher datasources, or `excused` status without reopening W2 D6.

---

## 6. Proposed slices (design only — after Phase 0 approval)

| Slice | Intent |
|-------|--------|
| **Pre-Slice** | Schema honesty: `halaqaId` + deterministic identity + day normalization; authorize parent→child; submit must not touch attendance; **no UI** beyond tests |
| **Slice 1** | Parent submit + list own requests (status visible); pending visible whether or not attendance exists yet (D-W7-2) |
| **Slice 2** | Teacher pending queue (visible during attendance) + approve/reject (request doc only; D-W7-3); attendance decided independently |
| **Slice 3** | Visibility: parent outcome (+ events if D-W7-6 = A); supervisor read-only if D-W7-7 = A |
| **Slice 4** | Production validation against lifecycle success criteria |

Each slice: validate → analyze → tests → format → commit → push → **stop for approval**.

---

## 7. Explicitly out of W7

- Replacing attendance SSOT or auto-rewriting marks from approve (unless product rejects D-W7-3 A)  
- Adding `excused` attendance status without reopening W2 D6  
- Supervisor (or admin) performing attendance writes via استئذان  
- Submit-only UI without review path  
- FCM / SMS / WhatsApp push (Category B / future sinks)  
- P-E1 logout / singleton reset  
- Payments, audio uploads, messaging product, admin console  
- Rewriting W4 `StudentAbsentRecorded` meaning  
- Category B rules/indexes/CI as the workflow itself  

---

## 8. Success criteria (for later validation)

W7 passes when:

1. A linked parent can submit an استئذان that is clearly scoped to attendance facts (student + day + halaqa per decisions).  
2. The halaqa teacher can approve or reject without a second attendance writer.  
3. `attendanceRecords` remain the only presence SSOT; weekly/parent % unchanged by request status alone (under recommended D-W7-3 A).  
4. Parent can see request outcome in addition to (not instead of) the attendance mark.  
5. If D-W7-7 = A, supervisor can see request context for supervised halaqat and only escalate — never own the decision.  
6. Any inbox signals are projections of academy facts (or explicit UI reads) — not parallel notification ownership.  

---

## 9. Approval record

| Item | Status |
|------|--------|
| Lifecycle centering | Approved |
| Attendance SSOT; request = context only; no parallel attendance ownership | **Locked** |
| Reuse W2/W4/W5/W6 before new abstractions | **Locked** |
| **D-W7-2** pre-attendance submit + never auto-modify attendance | **Approved** |
| **D-W7-3** request-status-only on approve/reject | **Approved** |
| Remaining D-W7-1, D-W7-4…D-W7-10 recommendations | Follow unless overridden |

**Pre-Slice may proceed. Stop after Pre-Slice production validation before Slice 1.**
