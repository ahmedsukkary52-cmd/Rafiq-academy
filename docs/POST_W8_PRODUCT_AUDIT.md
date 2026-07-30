# Post-W8 Product Audit

**Date:** 2026-07-30  
**Scope:** Academy as a complete product after W1–W8  
**Method:** Read-only investigation. **No Phase 0. No code. No commits. No pushes.**  
**Predecessors:** `docs/W8_COMPLETION_PRODUCTION_VALIDATION.md`, `docs/POST_W7_PRODUCT_AUDIT.md`,
`docs/POST_W7_W8_WORKFLOW_RERANK.md`, `docs/W8_PHASE0_DESIGN.md`

### Classification legend

| Tag           | Meaning                                     |
|---------------|---------------------------------------------|
| **Verified**  | Observed in current code / approved docs    |
| **Inference** | Reasonable conclusion from Verified facts   |
| **Accepted**  | Explicitly deferred in an approved decision |

### Track boundary (standing)

| Track             | Meaning                                                                                                        |
|-------------------|----------------------------------------------------------------------------------------------------------------|
| **Workflow (Wn)** | Complete academy operation with clear owner, coherent fact contract, reusable architecture — same bar as W1–W8 |
| **Platform Epic** | Trust / identity / device handoff — parallel track, not Wn                                                     |
| **Category B**    | Release / infra (rules, Storage, CI, capability flags) — does not gate Wn                                      |
| **Capability**    | Channel, polish, or surface that moves talk/presentation without owning a new academy operation                |

### Workflow bar (W1–W8 standard)

A candidate qualifies as **W9** only if it is all of:

1. **Complete academy operation** — who does what → what fact is written → who observes
2. **Clear business owner** — one workflow owns the write; observers project
3. **Coherent fact contract** — invariant / SSOT shape (not a second parallel truth)
4. **Reusable with W1–W8** — extends operated day / membership / awareness without inventing a side
   system
5. **Long-term product value** — still valuable after the day loop and admit path already work

**Messaging, dashboards, and infra unlocks are excluded from W9 ranking** (same re-rank discipline
as Post-W7).

---

## 0. Executive verdict

**W1–W8 close a coherent operated academy core.**

| Loop                                             | Status                                       |
|--------------------------------------------------|----------------------------------------------|
| Operate the day (assign, attend, ready, oversee) | **Closed** (W1–W3, W6)                       |
| Signal and excuse (awareness + استئذان)          | **Closed** (W4, W5, W7)                      |
| Admit members into operated halaqat              | **Closed** (W8 — Academy Admission Workflow) |

| Role           | What they can answer today                                                                                       |
|----------------|------------------------------------------------------------------------------------------------------------------|
| **Teacher**    | What must I do today? · Mark presence · Assign/review · Classify استئذان · See roster from membership            |
| **Parent**     | Absence / homework awareness · Submit/see استئذان · Weekly % from attendance SSOT · Act only for linked children |
| **Supervisor** | Which halaqat need attention? · Read-only استئذان · Admit into Academy Admission · Escalate to teacher           |
| **Admin**      | Admit student into halaqa (W8 surface)                                                                           |
| **Student**    | Consume membership (established / not established) · Day work when admitted                                      |

**Architecture held through W8.**

| Check                                                                                       | Verdict                         |
|---------------------------------------------------------------------------------------------|---------------------------------|
| Attendance remains operational presence SSOT                                                | **Pass (Verified)**             |
| استئذان remains contextual (not presence)                                                   | **Pass (Verified)**             |
| Membership owned by Academy Admission; consumers observe established / not established only | **Pass (Verified)** — Rules 1–8 |
| Observers project; they do not invent membership or attendance                              | **Pass (Verified)**             |

**Center of gravity after W8:** The product no longer fails because “who belongs in which halaqa” is
orphaned. Remaining holes are **adjacent lifecycles** (family link, membership exit), *
*commercial/blocked paths** (payments), **capabilities** (chat, awards polish), and **platform /
Category B**.

### W9 recommendation (this audit)

**No mandatory W9.** The W1–W8 family is internally consistent; the academy can operate without
opening another workflow immediately.

**If product chooses to expand now**, two candidates **do** meet the W1–W8 workflow bar (ranked in
§5). Neither is forced by coherence the way membership was after W7.

**Do not treat messaging, P-E1, or Category B as W9.**

---

## 1. What W1–W8 own

| Workflow | One-line ownership                               | Status   |
|----------|--------------------------------------------------|----------|
| **W1**   | Homework assign → submit → review                | Complete |
| **W2**   | Attendance register SSOT                         | Complete |
| **W3**   | Teacher day orchestration                        | Complete |
| **W4**   | Absence awareness (events → parent)              | Complete |
| **W5**   | Homework awareness (events → parent)             | Complete |
| **W6**   | Supervisor day oversight                         | Complete |
| **W7**   | استئذان lifecycle (submit → classify → project)  | Complete |
| **W8**   | Academy Admission — membership invariant (admit) | Complete |

### 1.1 Operated product shape (**Verified**)

```text
Academy Admission (W8)
  → Roster + profile + gates coherent (Rules 5–8)
  → Teacher day (W3) over W1/W2
  → Absence / homework events (W4/W5) → Parent inbox
  → Supervisor board (W6) + استئذان projection (W7)
  → Parent استئذان for linked children (W7; childrenIds assumed)
```

### 1.2 What it still cannot do (**Verified**)

| Gap                                     | Evidence                                                                                                                                 |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Staff link/unlink parent↔child in-app   | `childrenIds` read for W4/W7; **no** app writer (`arrayUnion`/`arrayRemove` on `childrenIds` not found in membership/parent write paths) |
| Unenroll / clear membership             | W8 out of scope; **no** `arrayRemove` on `halaqat.studentIds` in admit paths; deactivate ≠ exit                                          |
| Parent pay fees end-to-end              | `InitiatePayment` throws unavailable; CF commented; **no** payment UI on parent home                                                     |
| Parent discuss facts with staff in chat | Policy allows parent↔supervisor/admin; **no** parent chat routes/UI (**Accepted:** capability, not Wn)                                   |
| Safe multi-role device handoff          | No parent/supervisor/admin logout UI (**P-E1**)                                                                                          |
| Student audio submit                    | `AppCapabilities.audioUploadsEnabled = false`                                                                                            |
| Full admin console                      | Admit UI live; complaints/broadcast/finance/teachers remain UI-orphaned                                                                  |
| Firestore/Storage rules + CI            | **No** `firestore.rules` / `storage.rules` in repo; no CI workflows                                                                      |

---

## 2. Mandatory architecture checks (post-W8)

### 2.1 Attendance SSOT (**Verified**) — Pass

Presence writes remain teacher attendance paths; W7 still does not rewrite attendance; weekly %
still attendance-based.

### 2.2 Membership contract (**Verified**) — Pass

| Fact                                   | Evidence                                                    |
|----------------------------------------|-------------------------------------------------------------|
| Business Owner                         | Academy Admission Workflow                                  |
| Current Implementation Owner           | `ApproveNewStudentUseCase` (replaceable)                    |
| Atomic + idempotent + invariant-driven | `AcademyAdmissionFirestore`                                 |
| Observable states                      | `AcademyMembershipObservation` established / notEstablished |
| Supervisor admit                       | Delegates to Current Implementation Owner                   |

### 2.3 Observers project (**Verified**) — Pass

W4/W5/W6/W7 consumers unchanged as membership writers; Slice 2 consumption contracts document roster
vs profile vs login gate.

---

## 3. Remaining operations inventory

### 3.1 Platform Epic (not Wn)

| Candidate                          | Verified today                                                                                             | Why not Wn                                       |
|------------------------------------|------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| **P-E1 — Logout + identity reset** | Student/teacher logout exist; parent/supervisor/admin logout UI absent; singleton blocs retain projections | Trust / device handoff, not an academy operation |
| Password reset                     | Login “Coming Soon” copy only                                                                              | Auth platform                                    |

### 3.2 Category B (not Wn)

| Candidate                 | Verified today                                             | Why not Wn     |
|---------------------------|------------------------------------------------------------|----------------|
| Firestore / Storage rules | Absent from repo                                           | Release trust  |
| CI                        | No `.github/workflows`                                     | Release        |
| Audio uploads flag        | Disabled in `AppCapabilities`                              | Infra unlock   |
| FCM productization        | Messaging instance registered; not productized as delivery | Delivery infra |
| B-R8 durable event retry  | Client publish-after-commit                                | Infra          |

### 3.3 Capabilities (not Wn)

| Candidate                              | Verified today                                                                       | Why not Wn                                                     |
|----------------------------------------|--------------------------------------------------------------------------------------|----------------------------------------------------------------|
| **Parent ↔ staff messaging**           | Chat stack + policy; no parent UI                                                    | Communication channel — same classification as Post-W7 re-rank |
| Awards / encouragement coherence       | Dual schemas (`grantedBy` vs `issuedBy`); teacher/supervisor grant; weak parent view | Motivation polish / schema hygiene                             |
| Content library / calendar / analytics | Features + some orphan routes                                                        | Surfaces / CRUD, not new operational rituals                   |
| Progress / gamification Coming Soon    | Student map, plan placeholders, badges gifts                                         | Product polish                                                 |
| استئذان inbox events (D-W7-6 A)        | Accepted B — UI reads request docs                                                   | Category A companion to W7, not a new operation                |
| Admin broadcast / complaints respond   | Writers exist; UI orphaned; **no complaint submitter** in app                        | Console capability / incomplete loop                           |

### 3.4 True-workflow shape candidates

| Candidate                           | Complete operation?                              | Clear owner?                                     | Fact contract?                                 | Reuse W1–W8?                  | Backend ready?                     | Meets Wn bar?                                        |
|-------------------------------------|--------------------------------------------------|--------------------------------------------------|------------------------------------------------|-------------------------------|------------------------------------|------------------------------------------------------|
| **Parent ↔ child linking**          | **Yes** — who may act for which student          | Admin (or staff) must own write; parents observe | `parentProfiles.childrenIds`                   | High — W4/W7 auth             | Fields exist; **writer missing**   | **Yes**                                              |
| **Membership exit / unenroll**      | **Yes** — leave halaqa under invariant Rules 5–8 | Academy Admission (or sibling Exit workflow)     | Invert / clear invariant members atomically    | High — keeps day ops coherent | **No exit writer**                 | **Yes**                                              |
| **Transfer / multi-halaqa**         | Yes if designed                                  | Admission owner                                  | Needs product rules beyond single-halaqa admit | High                          | **No seed**                        | **Conditional** — premature without Product Decision |
| **Payments / fees lifecycle**       | **Yes** commercially                             | Parent + admin reconcile                         | `payments`                                     | Low–medium                    | **Blocked** (initiate unavailable) | **No (blocked)**                                     |
| **Complaints full loop**            | Thin yes                                         | Parent/student submit + admin respond            | `complaints`                                   | Low                           | Respond exists; **submit missing** | **Weak** — orphan console, not academy day core      |
| **Makeup / catch-up after absence** | Would be                                         | Teacher                                          | Risk of second SSOT beside W2/W7               | Speculative                   | **No seed**                        | **No — premature**                                   |

---

## 4. Why leading non-workflows are not W9

### Messaging — still a capability

| Criterion                  | Result                                                    |
|----------------------------|-----------------------------------------------------------|
| Complete academy operation | **Fail** — delivers talk, not an operational fact class   |
| Clear business owner       | Bilateral conversation; no single academy decision owner  |
| Fact contract              | Chat is channel, not membership/attendance/homework truth |
| W1–W8 bar                  | Same rejection as Post-W7 re-rank                         |

### P-E1 — Platform Epic

Required for multi-role devices; does not close an academy ritual.

### Payments — true workflow shape, blocked

Would meet commercial workflow criteria **after** Cloud Functions / initiate path exist. Ranking it
as W9 now would open Phase 0 against a non-runnable backend.

### Awards / content / calendar — capability / polish

Grant and publish paths largely exist; pain is coherence, navigation orphans, and parent
projection — not a missing owned operation of W1–W8 weight.

---

## 5. Ranked true-workflow candidates (optional expansion)

| Rank  | Candidate                            | Why it meets the bar                                                                                                                                              | Why it is optional now                                                              |
|-------|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| **1** | **Parent ↔ Child Linking Lifecycle** | Precondition for every parent ritual (W4/W5/W7); SSOT `childrenIds` already consumed; writer missing — same “half-built precondition” shape membership had pre-W8 | Academy day + admit already run; linking often done out-of-band today               |
| **2** | **Membership Exit / Unenroll**       | Completes the other half of W8 under Rules 5–8; prevents stale roster/profile after leave; clear owner (Admission / Exit)                                         | Admit path unblocked the core; exit is lifecycle completeness, not day-loop blocker |
| **3** | **Transfer / multi-halaqa**          | Only after Product Decision; risk of weakening Rule 2/5/8                                                                                                         | No seed; do not invent                                                              |
| **—** | Payments                             | Meets shape when unblocked                                                                                                                                        | Category-B / CF blocked                                                             |
| **—** | Complaints loop                      | Possible thin workflow                                                                                                                                            | Not core operated academy                                                           |

---

## 6. W9 decision

| Question                                                  | Answer                                                                                                                                                            |
|-----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Must W9 start immediately for product coherence?          | **No**                                                                                                                                                            |
| Does any remaining candidate meet the W1–W8 workflow bar? | **Yes** — Linking (#1) and Membership Exit (#2)                                                                                                                   |
| Automatic recommendation as next Phase 0?                 | **None mandatory**                                                                                                                                                |
| If product **chooses** to open W9 now                     | Prefer **Parent ↔ Child Linking Lifecycle** as W9; treat Membership Exit as W10 candidate (or reopen under Academy Admission as an exit slice — Product Decision) |
| Explicitly not W9                                         | Messaging, P-E1, Category B, awards/content polish, payments (until unblocked), makeup                                                                            |

### Recommended product choices (await approval)

1. **Accept** that W1–W8 form a consistent operated-academy family; no forced W9.
2. **Classify** remaining work using §3–§5 (Workflow vs Platform vs B vs Capability).
3. **If expanding:** approve **W9 = Parent ↔ Child Linking Lifecycle** *or* explicitly choose
   Membership Exit instead *or* defer both.
4. **Do not** open Phase 0 until that choice is approved.

---

## 7. Stop gate

**No Phase 0. No code. No commits. No pushes.**

Awaiting approval of:

1. Post-W8 audit verdict (W1–W8 coherent; no mandatory W9).
2. Optional W9 selection (Linking / Exit / defer).
3. Continued exclusion of messaging / P-E1 / Category B from Wn ranking.
