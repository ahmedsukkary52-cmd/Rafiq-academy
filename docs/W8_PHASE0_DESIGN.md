# W8 — Student Onboarding / Halaqa Membership Lifecycle

## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Rules 1–8 locked · Slice 2 **approved** · **completion gate Pass** · awaiting approval
before next-workflow recommendation  
**Date:** 2026-07-30  
**Predecessors:** W8 Slice 2 approved; Rule 8 locked (membership completeness is observable)  
**Standing rule:** If an assumption is wrong: **stop**, update this document, then continue.

### Classification

| Tag                  | Meaning                                                                             |
|----------------------|-------------------------------------------------------------------------------------|
| **Verified**         | Observed directly in current code or an approved product decision                   |
| **Inference**        | Conclusion supported by Verified facts, but not an approved product rule            |
| **Product Decision** | A choice that changes workflow behavior and requires approval before implementation |

### Permanent architecture rules (carried forward + W8)

| Rule                                                                             | Source          | W8 consequence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|----------------------------------------------------------------------------------|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Attendance is the SSOT for presence                                              | W2              | Membership does **not** invent presence; roster enables attendance, it does not mark it                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Homework / assignment ownership                                                  | W1              | Membership enables assign targets; it does not create homework facts                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Event = domain fact, not notification                                            | W4/W5           | Membership lifecycle facts (if any) are optional later; delivery is not ownership                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Supervisor observes, does not take over teaching                                 | W6              | Supervisor may participate in membership under explicit Product Decision; must not become a second teacher write path for day ops                                                                                                                                                                                                                                                                                                                                                                                             |
| Domain ownership over feature ownership                                          | Standing        | One membership write owner; extract only for real domain concepts                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Outcomes are projections, not new business facts                                 | W7 Rule 2       | Downstream W1–W7 **consume** membership; they must not invent local membership flags                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Rule 1 — Membership is an academy lifecycle, not user administration**         | **Locked (W8)** | The workflow answers only: **“How does a student become an active member of a halaqa?”** It must **not** become account CRUD, password reset, role editing, or generic user management.                                                                                                                                                                                                                                                                                                                                       |
| **Rule 2 — Membership has one completion contract**                              | **Locked (W8)** | A student is a completed academy member **only when the required membership invariants are simultaneously satisfied.**                                                                                                                                                                                                                                                                                                                                                                                                        |
| **Rule 3 — The workflow owns the membership invariant, not an individual field** | **Locked (W8)** | The academy guarantees membership through a **product-approved invariant set**. Implementation may satisfy that set using **one or more existing fields**. Ownership belongs to the **workflow write path**, not to any single field. No field is promoted to definitive Source of Truth at this stage. If no field can safely own membership alone, keep the **invariant as the contract** — do **not** invent a new abstraction.                                                                                            |
| **Rule 4 — Ownership is decided before implementation**                          | **Locked (W8)** | The **Business Owner** (workflow-level), the **membership invariant** it maintains, and **every other existing writer** (project or retire) must be **explicitly product-approved before Pre-Slice**. Ownership is **not** permanently bound to today’s use-case name. Pre-Slice may **verify** that the **Current Implementation Owner** matches the Business Owner; it must **not** decide ownership. If ownership cannot be determined confidently from product intent, **stop** and request an explicit Product Decision. |
| **Rule 5 — Membership invariants are atomic**                                    | **Locked (W8)** | **Academy Admission Workflow** must establish the **complete** membership invariant as **one logical operation**. The system must never be left partially admitted. If the invariant cannot be established completely, membership is **incomplete**. W1–W7 may assume membership is only **complete** or **not established** — no intermediate membership state.                                                                                                                                                              |
| **Rule 6 — Admission is idempotent**                                             | **Locked (W8)** | Executing Academy Admission Workflow repeatedly for the **same student + halaqa** must **converge to the same invariant**. Must never duplicate roster membership, partially rewrite projections, emit different membership state, or depend on prior attempts. Always reconcile toward the approved invariant. **Implementation property**, not a new business rule.                                                                                                                                                         |
| **Rule 7 — Membership reconciliation is invariant-driven**                       | **Locked (W8)** | Academy Admission Workflow always reconciles **toward the approved membership invariant**. It must **never** assume one field is authoritative and copy it into the others. Every write establishes the invariant **directly**. Future storage/SSOT changes must preserve the invariant contract without changing W1–W7 consumers. **Implementation rule**, not a new business rule.                                                                                                                                          |
| **Rule 8 — Membership completeness is observable**                               | **Locked (W8)** | Externally, Academy Admission exposes only **two** states: **membership established** or **membership not established**. W1–W7 must never infer partial membership from individual fields. Completion gate verifies consumers observe the **workflow contract**, not storage details or intermediate writes. **Workflow guarantee**, not a storage rule.                                                                                                                                                                      |

### Standing boundaries

- **Category A** may join W8 only when it directly protects membership coherence (e.g. one atomic
  admit write matching the invariant set).
- **Category B** (rules, Storage, CI, B-R8) does not gate W8.
- **Platform Epic P-E1** (logout / identity reset) stays **out of W8**.
- **Messaging** stays a communication capability — **out of W8**.
- **Parent↔child linking** (`parentProfiles.childrenIds`) is a **related but separate**
  relationship — see §7 / out of scope.
- **Slice 2 approved** — completion gate (Slice 3 visibility + Slice 4 validation) may run.

---

## 0. Goal (lifecycle, not screens)

### 0.1 Business question (locked)

> **How does a student become an active member of a halaqa?**

### 0.2 Hard product constraints (from approval)

1. Membership is an **academy lifecycle**, not user administration (Rule 1).
2. Membership has **one completion contract** (Rule 2): completed only when **required invariants
   hold simultaneously**.
3. The **workflow owns the invariant**, not an individual field (Rule 3).
4. **Ownership is decided before implementation** (Rule 4) — at **workflow (Business Owner)** level,
   not permanently bound to a use-case name; Pre-Slice verifies the Current Implementation Owner
   matches.
5. **Membership invariants are atomic** (Rule 5) — complete invariant in one logical operation; no
   partial admission for W1–W7.
6. **Admission is idempotent** (Rule 6) — repeated admit for the same student+halaqa converges to
   the same invariant.
7. **Reconciliation is invariant-driven** (Rule 7) — never copy one field into others as authority;
   write the invariant directly.
8. **Membership completeness is observable** (Rule 8) — only established vs not established; no
   partial inference by consumers.
9. Do **not** promote any existing field to definitive Source of Truth at this stage.
10. Every downstream workflow must **consume** the resulting membership **without adding its own
    membership logic**.
11. Reuse existing approval, roster, and profile flows before proposing new abstractions.
12. Center design on the **complete lifecycle**, not on admin CRUD screens alone.
13. Do **not** invent another membership collection or `isMember` flag to paper over ambiguity — if
    no field can safely own membership alone, keep the invariant as the contract (Product Decision).

### 0.3 Required lifecycle shape

```text
Request / eligibility
  → Review
  → Approval
  → Membership activation
  → Halaqa assignment
  → Operational readiness for W1–W7
```

Each stage must map to **facts** (or an explicit Product Decision that a stage is collapsed / absent
today).

---

## 1. Real academy operations

| #  | Operation                                   | Classification                     | W8 consequence                                                     |
|----|---------------------------------------------|------------------------------------|--------------------------------------------------------------------|
| R1 | Student account exists and can authenticate | **Verified** (auth register)       | Eligibility / identity shell — not yet halaqa membership           |
| R2 | Student is placed on a halaqa roster        | **Verified** (partial writers)     | Core membership assignment                                         |
| R3 | Student profile points at a halaqa          | **Verified** (partial writers)     | Student-facing membership pointer                                  |
| R4 | Account may be marked active/inactive       | **Verified** (auth + admin toggle) | Login gate — must not be confused with roster membership alone     |
| R5 | Teacher operates day for rostered students  | **Verified** (W1–W3)               | Downstream consumer of roster                                      |
| R6 | Parent acts for linked children             | **Verified** (W4/W7)               | Separate parent↔child link; not membership SSOT                    |
| R7 | Supervisor oversees supervised halaqat      | **Verified** (W6)                  | May assist placement under Product Decision; does not own teaching |

---

## 2. Current implementation map (reuse first)

### 2.1 Write paths that change membership-related facts (**Verified**)

| Writer                              | Path                                                                          | Writes                                                                                         | Completeness                                                          |
|-------------------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| **Admin `approveNewStudent`**       | `ApproveNewStudentUseCase` → `admin_remote_datasource_impl.approveNewStudent` | Batch: `users.isActive = true`; `studentProfiles.halaqaId`; `halaqat.studentIds` `arrayUnion`  | **Only complete triple write**                                        |
| **Admin `toggleAccountStatus`**     | `ToggleAccountStatusUseCase`                                                  | `users.isActive` only                                                                          | Activation / deactivation — **not** roster exit                       |
| **Supervisor `registerNewStudent`** | `RegisterNewStudentUseCase` → supervisor datasource                           | `halaqat.studentIds` `arrayUnion`; `studentProfiles.halaqaId`                                  | **Partial** — does **not** set `users.isActive`; does not create user |
| **Auth self-register**              | `RegisterWithEmailUseCase` / `AuthRemoteDatasourceImpl`                       | `users` with `role=student`, **`isActive: true`**; `studentProfiles` with **`halaqaId: null`** | Identity shell — **not** halaqa membership                            |
| **Unenroll / remove from roster**   | —                                                                             | —                                                                                              | **Missing** — no `arrayRemove` on `studentIds` in app code            |
| **`users.halaqaId`**                | —                                                                             | —                                                                                              | **Does not exist** on `UserEntity` / `UserModel`                      |

**Admin UI orphan (Verified):** `AdminHomePage` is “Coming Soon”; `ApproveNewStudentEvent` /
`AdminBloc` exist but no production UI dispatches approve.

**Supervisor UI (Verified):** Register dialog on `SupervisorHomePage` — free-text student id; copy
states it links an existing student, does not create an account.

### 2.2 Read paths that depend on membership (**Verified**)

| Consumer                          | Membership input                                       | Notes                                         |
|-----------------------------------|--------------------------------------------------------|-----------------------------------------------|
| Teacher `getHalaqaStudents`       | `halaqat.studentIds` → `users` whereIn                 | **No** `isActive` filter                      |
| Teacher `sendAssignment`          | `halaqat.studentIds`                                   | Empty roster → cannot assign                  |
| Teacher attendance UI             | Students from roster load                              | W2 register                                   |
| W3 `GetTodayAgendaUseCase`        | `halaqa.studentIds` → `HalaqaDayReadinessProjector`    | Empty roster changes homework/attendance gaps |
| W6 `GetSupervisorDayBoardUseCase` | Same `studentIds` → shared projector                   | Observation only                              |
| Student home / schedule / chat    | `studentProfiles.halaqaId` → `halaqat/{id}`            | Student-facing pointer                        |
| Student homework                  | Prefer assignment `halaqaId`, else profile `halaqaId`  | List keyed by `studentId`                     |
| Parent W7 halaqa picker           | `halaqat` where `studentIds` arrayContains child       | After parent↔child auth                       |
| Parent W7 / W4 auth               | `parentProfiles.childrenIds`                           | **Not** halaqa membership                     |
| Admin stats                       | Count `users` where `role=student` and `isActive=true` | Account activity, not roster                  |

### 2.3 Candidate fields for “active membership” (**Verified**)

| Field         | Collection              | Practical role today                                               |
|---------------|-------------------------|--------------------------------------------------------------------|
| `studentIds`  | `halaqat/{id}`          | **Operational roster** for teacher / W3 / W6 / W7 halaqa discovery |
| `halaqaId`    | `studentProfiles/{uid}` | **Student-facing pointer** for home / schedule / chat              |
| `isActive`    | `users/{uid}`           | **Login / account gate** (+ admin counts)                          |
| `role`        | `users/{uid}`           | Identity (`student`) — not placement                               |
| `status`      | `halaqat/{id}`          | Halaqa active/inactive (teacher queries `status == active`)        |
| `childrenIds` | `parentProfiles/{uid}`  | Parent–child relationship — **orthogonal** to membership           |

### 2.4 Current ownership reality (**Verified** — not a contract)

| Question                                                    | Finding                                                                      | Tag                                        |
|-------------------------------------------------------------|------------------------------------------------------------------------------|--------------------------------------------|
| What do day ops trust as “who is in the class?”             | `halaqat.studentIds`                                                         | **Verified**                               |
| What does the student app trust as “my halaqa?”             | `studentProfiles.halaqaId`                                                   | **Verified**                               |
| What does login trust as “may enter the app?”               | `users.isActive`                                                             | **Verified**                               |
| Is there one coherent “active member of halaqa” fact today? | **No** — three fields, two incomplete writers, no enforcement of consistency | **Verified**                               |
| Can code alone name a single ownership contract?            | **No** — guessing which field “really” owns membership would invent policy   | **Verified** → **Product Decision D-W8-7** |

**Inference:** Admin `approveNewStudent` is the only writer that updates all three surfaces
together. That makes it the natural **implementation nucleus** for whatever contract product locks —
not proof that a contract already exists.

### 2.5 Membership completion contract (Rules 2–5)

#### 2.5.1 Locked principles

| Rule       | Locked statement                                                                                                                                                                                                          |
|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Rule 2** | A student is a completed academy member only when the required membership invariants are **simultaneously** satisfied.                                                                                                    |
| **Rule 3** | The **workflow** owns the membership invariant, **not** an individual field. Implementation may satisfy the set using **one or more existing fields**.                                                                    |
| **Rule 4** | **Ownership is decided before implementation.** Ownership is defined at the **workflow (Business Owner)** level. Pre-Slice may verify the **Current Implementation Owner**; it must **not** determine Business Ownership. |
| **Rule 5** | **Membership invariants are atomic.** Academy Admission Workflow establishes the complete invariant as one logical operation; never leaves a partial admit; W1–W7 see only complete or not established.                   |
| **Rule 6** | **Admission is idempotent.** Repeated execution for the same student+halaqa converges to the same invariant; no roster duplicates; reconcile toward the approved contract.                                                |
| **Rule 7** | **Reconciliation is invariant-driven.** Never treat one field as authoritative and copy into others; establish the invariant directly; keep W1–W7 independent of storage implementation.                                  |
| **Rule 8** | **Membership completeness is observable.** Only two external states: established / not established; consumers never infer partial membership from individual fields.                                                      |

| Locked now                           | Status                    |
|--------------------------------------|---------------------------|
| Rules 2–8                            | **Locked**                |
| D-W8-1 / D-W8-7 package              | **Approved**              |
| No field promoted to definitive SSOT | **Locked** for this stage |
| No new membership abstraction        | **Locked**                |

#### 2.5.2 Business Owner vs Current Implementation Owner

| Layer                            | Meaning                          | Stability       |
|----------------------------------|----------------------------------|-----------------|
| **Business Owner**               | **Academy Admission Workflow**   | **Stable**      |
| **Current Implementation Owner** | `ApproveNewStudentUseCase` today | **Replaceable** |

#### 2.5.3 Approved ownership package (D-W8-1 + D-W8-7) — **LOCKED**

##### A. Business Owner (D-W8-1) — **Approved**

**Academy Admission Workflow** — sole workflow-level owner of the membership invariant.

##### B. Current Implementation Owner — **Approved**

`ApproveNewStudentUseCase` (current implementation only; replaceable).

##### C. Membership invariant (D-W8-7) — **Approved**

Completed membership ⟺ all hold simultaneously:

1. roster contains the student
2. profile `halaqaId` matches
3. `role = student`
4. `isActive = true`

**The invariant itself is the product contract.** No field SSOT. Future SSOT promotion only after
invariant ownership is implemented and verified, if ever needed.

##### D. Other writers — **Approved**

| Writer                          | Disposition                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| Supervisor `registerNewStudent` | **Implementation of Academy Admission Workflow** — not an independent owner |
| Self-registration               | Eligibility only                                                            |
| `ToggleAccountStatus`           | Supporting Gate only                                                        |
| W1–W7                           | Consumers only                                                              |

##### E. Atomicity (Rule 5) — **Locked**

Complete invariant in one logical operation. Partial = incomplete. No intermediate membership state
for W1–W7.

#### 2.5.4 Field classification vocabulary

| Class                         | Meaning                                                                                                                                          |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **Candidate Source of Truth** | Field that some consumers treat as answering membership today; **not** definitive owner                                                          |
| **Derived Projection**        | May be assigned **only after** a definitive SSOT is promoted (post ownership approval + implementation match); never independently authoritative |
| **Supporting Gate**           | Needed for login, eligibility, or operability; **not** membership completion by itself                                                           |
| **Legacy Compatibility**      | Absent, unused for membership, or a separate relationship that must not become membership SSOT                                                   |

**Promotion rule (Rule 3):** Do **not** promote any existing field to definitive Source of Truth *
*at this stage**.

If no existing field can safely own membership without inconsistencies, **keep the invariant as the
contract** — do **not** invent a new abstraction.

#### 2.5.5 Classification of existing fields (**no definitive SSOT**)

| Field            | Collection              | Role **today** (Verified)                         | Classification now                        |
|------------------|-------------------------|---------------------------------------------------|-------------------------------------------|
| `studentIds`     | `halaqat/{id}`          | Day-ops roster (teacher / W3 / W6 / W7 discovery) | **Candidate Source of Truth**             |
| `halaqaId`       | `studentProfiles/{uid}` | Student-facing “my halaqa” pointer                | **Candidate Source of Truth**             |
| `isActive`       | `users/{uid}`           | Login / account gate; admin counts                | **Supporting Gate**                       |
| `role`           | `users/{uid}`           | Identity (`student`)                              | **Supporting Gate**                       |
| `status`         | `halaqat/{id}`          | Halaqa operable for teacher queries               | **Supporting Gate**                       |
| `childrenIds`    | `parentProfiles/{uid}`  | Parent↔child for W4/W7                            | **Legacy Compatibility** (for membership) |
| `users.halaqaId` | —                       | **Does not exist**                                | **Legacy Compatibility** — do not invent  |

These candidates may **participate** in satisfying the invariant set. None of them **owns**
membership (Rule 3).

#### 2.5.6 Pre-Slice responsibility (Rule 4)

| Pre-Slice **may**                                                                                     | Pre-Slice **must not**                                         |
|-------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| **Verify** that the Current Implementation Owner realizes the approved **Business Owner** + invariant | Decide or “discover” Business Ownership                        |
| Retarget/retire other writers **as already decided** in §2.5.3 D                                      | Bind Business Ownership permanently to a use-case name         |
| Add tests that the approved invariant holds after the owned write                                     | Choose a different Business Owner mid-slice                    |
| Replace/rename Current Implementation Owner later while keeping Business Owner                        | Promote a field to definitive SSOT as a shortcut for ownership |

#### 2.5.7 How W1–W7 continue consuming membership (no local membership logic)

| Workflow | Allowed consume                                             | Forbidden local logic                                                    |
|----------|-------------------------------------------------------------|--------------------------------------------------------------------------|
| **W1**   | Assign via existing roster/profile fields as today          | Private member lists; inventing “active member” from `isActive` alone    |
| **W2**   | Attendance roster from `getHalaqaStudents` (`studentIds`)   | New membership authority inside attendance                               |
| **W3**   | `rosterStudentIds: halaqa.studentIds` into shared projector | Second roster derivation / membership cache                              |
| **W4**   | Parent recipients via `childrenIds`                         | Treating parent link as halaqa membership                                |
| **W5**   | Homework event subjects from homework facts                 | Membership caches                                                        |
| **W6**   | Supervised halaqat’ `studentIds`                            | Supervisor-side membership writes outside **Academy Admission Workflow** |
| **W7**   | Children auth + halaqa picker via roster contains           | Submit path inventing membership or bypassing existing fields            |

**Readiness for W1–W7** after admit = approved invariant set holds (maintained by **Academy
Admission Workflow**); consumers keep reading the **same** fields without new membership rules.

---

## 3. How W1–W7 depend on membership (**Verified**)

| Workflow                    | Dependency on membership                                                               | Own membership logic?                                  |
|-----------------------------|----------------------------------------------------------------------------------------|--------------------------------------------------------|
| **W1** Homework             | Assign iterates `halaqat.studentIds`; student resolves halaqa via profile / assignment | No — consumes roster/profile                           |
| **W2** Attendance           | Register UI loads roster via `getHalaqaStudents`                                       | No — consumes roster                                   |
| **W3** Teacher day ops      | Readiness uses `halaqa.studentIds` as `rosterStudentIds`                               | No — consumes roster                                   |
| **W4** Absence awareness    | Events fan out via parent↔child (`childrenIds`), not roster                            | Separate relationship                                  |
| **W5** Homework awareness   | Same event pipeline; subject students from homework facts                              | No membership invent                                   |
| **W6** Supervisor oversight | Board uses supervised halaqat’ `studentIds`                                            | No — consumes roster                                   |
| **W7** استئذان              | Parent auth via `childrenIds`; halaqa choices via `studentIds` arrayContains           | No — must keep consuming roster, not invent membership |

**W8 success criterion (locked intent):** After membership activation, W1–W7 continue to read **the
same roster/profile fields** — they must **not** grow private “isMember” flags or alternate
collections.

---

## 4. Lifecycle stage mapping (today vs required)

| Stage                               | Required meaning                                     | Today (**Verified**)                                                                        | Gap                                     |
|-------------------------------------|------------------------------------------------------|---------------------------------------------------------------------------------------------|-----------------------------------------|
| **Request / eligibility**           | Someone asks / student becomes eligible for a halaqa | Self-register creates active user with `halaqaId: null`; no pending-membership document     | No explicit eligibility/request fact    |
| **Review**                          | Staff examines eligibility                           | No dedicated review queue                                                                   | Missing product surface                 |
| **Approval**                        | Decision to admit                                    | Admin approve use case exists; **no UI**                                                    | Orphaned write path                     |
| **Membership activation**           | Student may operate as academy member                | `users.isActive` set on register already `true`; approve sets `true` again; toggle can flip | Activation conflated with account login |
| **Halaqa assignment**               | Student belongs to a specific halaqa                 | Admin approve + supervisor register both set roster + profile (supervisor skips `isActive`) | Dual writers; drift risk                |
| **Operational readiness for W1–W7** | Roster/profile coherent so day ops work              | Works only when fields agree; teacher ignores `isActive`; student trusts profile            | No single post-condition guarantee      |

---

## 5. Required product decisions (approval gate)

### D-W8-1 — Who owns the membership write? (**Business Owner**)

Ownership is at the **workflow** level, not the use-case name.

| Option              | Business Owner                                                    | Current Implementation Owner (today)                                                                 |
|---------------------|-------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| **A (recommended)** | **Academy Admission Workflow**                                    | `ApproveNewStudentUseCase` / admin `approveNewStudent` batch — **replaceable**                       |
| B                   | Supervisor Placement Workflow                                     | `RegisterNewStudentUseCase` — incomplete today; only if product explicitly names this Business Owner |
| C                   | Dual Business Owners (admin + supervisor separate)                | **Rejected** under Rules 3–4                                                                         |
| D                   | Bound permanently to `ApproveNewStudentUseCase` as the owner name | **Rejected** — confuses Current Implementation with Business Owner                                   |
| E                   | Defer; Pre-Slice decides                                          | **Rejected** — violates Rule 4                                                                       |

**Recommendation: A.**

### D-W8-2 — What is “Request / eligibility” in v1?

| Option                                                                                                  | Meaning                                                                                            |
|---------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| **A. Existing student account with `role=student` and no coherent halaqa membership (recommended MVP)** | Eligibility = registered student not yet on target roster / null profile halaqa; no new collection |
| B. Explicit `membershipRequests` collection                                                             | Clear lifecycle stages; new abstraction — only if A cannot express review queue                    |
| C. Self-register creates pending (`isActive=false`) until approve                                       | Changes auth meaning; larger behavior change                                                       |

**Recommendation: A** for Phase 0 reuse; revisit B only if product needs a durable request queue.

### D-W8-3 — What is the membership SSOT post-condition?

**Superseded by Rules 2–3 + D-W8-7.** Kept for continuity.

Membership completion is **not** a single-field SSOT. It is a **workflow-owned invariant set** (Rule
3). Field SSOT promotion is **out of scope for this stage**.

### D-W8-4 — Relationship of `users.isActive` to membership

| Option                                                                                                                                                  | Meaning                                                                                                                          |
|---------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| **A. Login gate only; membership write may set `isActive=true` when admitting, but deactivation does not silently mean unenroll (recommended clarity)** | Matches current toggle behavior; W8 must document that deactivate ≠ remove from roster unless a later exit lifecycle is approved |
| B. `isActive=false` means not a member — writers must remove roster + clear profile                                                                     | Stronger; requires exit path W8 may or may not include                                                                           |
| C. Ignore `isActive` for membership entirely                                                                                                            | Teacher already ignores it; login still needs it                                                                                 |

**Recommendation: A** for W8 admit path; **exit/unenroll** is a separate decision (likely out of W8
v1 — see §7).

### D-W8-5 — Parent↔child linking in W8?

| Option                                     | Meaning                                                    |
|--------------------------------------------|------------------------------------------------------------|
| **A. Out of W8 (recommended)**             | Separate relationship; W4/W7 already consume `childrenIds` |
| B. In W8 — must link parent when admitting | Expands scope into family administration                   |

**Recommendation: A.**

### D-W8-6 — Academy events for membership?

| Option                                                | Meaning                                                    |
|-------------------------------------------------------|------------------------------------------------------------|
| **A. UI / read projections only in v1 (recommended)** | Like W7 D-W7-6 B — avoid new lifecycle ownership via inbox |
| B. Emit membership activated facts via existing sink  | Useful later; must remain projections of membership facts  |

**Recommendation: A** unless product requires inbox awareness in the same slices.

### D-W8-7 — Ownership package (invariant + other writers) — **Pre-Slice gate with D-W8-1**

**D-W8-7 remains a Product Decision.** Approve together with D-W8-1 as the §2.5.3 package.

| Option                                                                 | Meaning                                                                                                                                                                                                                                                                |
|------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **A. Approve §2.5.3 A–D as written (recommended)**                     | Business Owner = Academy Admission Workflow; Current Implementation Owner = `ApproveNewStudentUseCase` (replaceable); invariant = roster ∧ profile ∧ role ∧ isActive; supervisor independent write retired/retargeted; self-register and toggle not membership writers |
| B. Same Business Owner; different invariant set (must name explicitly) | Allowed only if product rewrites §2.5.3 C before Pre-Slice                                                                                                                                                                                                             |
| C. Different Business Owner name (must still be workflow-level)        | Allowed only with full §2.5.3 A–D rewritten                                                                                                                                                                                                                            |
| D. Bind ownership to use-case name as permanent owner                  | **Rejected**                                                                                                                                                                                                                                                           |
| E. Leave package unnamed for Pre-Slice discovery                       | **Rejected** — Rule 4                                                                                                                                                                                                                                                  |
| F. Invent new membership collection / `isMember`                       | **Rejected**                                                                                                                                                                                                                                                           |

**Recommendation: A** (with D-W8-1 A).

**Pre-Slice blocker:** No Pre-Slice until D-W8-1 A and D-W8-7 A (or an explicitly rewritten
equivalent package) are product-approved. After approval, Pre-Slice **verifies** that the Current
Implementation Owner realizes **Academy Admission Workflow** — it does **not** decide Business
Ownership.

---

## 5A. D-W8-1 / D-W8-7 package — **APPROVED**

| Decision                         | Lock                                                                                    |
|----------------------------------|-----------------------------------------------------------------------------------------|
| **D-W8-1**                       | **Business Owner** = **Academy Admission Workflow**                                     |
| **Current Implementation Owner** | `ApproveNewStudentUseCase` (**today only**; replaceable)                                |
| **D-W8-7 invariant**             | roster contains student ∧ profile `halaqaId` matches ∧ `role=student` ∧ `isActive=true` |
| **Rule 5**                       | Atomic complete invariant — no partial admission                                        |
| **Supervisor register**          | Implementation of Academy Admission Workflow (not independent owner)                    |
| **Self-register**                | Eligibility only                                                                        |
| **`ToggleAccountStatus`**        | Supporting Gate only                                                                    |
| **W1–W7**                        | Consumers only                                                                          |
| **Field SSOT**                   | **None**                                                                                |
| **New abstraction**              | **None**                                                                                |

**Pre-Slice unlocked.** Slice 1 remains blocked until Pre-Slice validation is approved.

---

## 6. Reuse checklist (before any new abstraction)

| Need                 | Reuse first                                                           | New only if unavoidable                                    |
|----------------------|-----------------------------------------------------------------------|------------------------------------------------------------|
| Coherent admit write | `ApproveNewStudentUseCase` / admin datasource batch                   | Thin shared domain use case wrapping the same three fields |
| Roster read          | `halaqat.studentIds` (teacher/supervisor already)                     | —                                                          |
| Student pointer      | `studentProfiles.halaqaId`                                            | —                                                          |
| Account gate         | `users.isActive` + existing login check                               | —                                                          |
| Supervisor surface   | Existing register dialog → retarget to owned use case                 | Do not keep a second partial writer                        |
| Admin surface        | Existing `AdminBloc` approve event                                    | Real page — not a new admin “user CRUD” module             |
| Eligibility list     | Query students with `role=student` and missing/ incoherent membership | New `membershipRequests` only if D-W8-2 = B                |
| Parent link          | Leave `parentProfiles.childrenIds` alone                              | —                                                          |
| Day ops readiness    | Unchanged W3/W6 projector inputs                                      | —                                                          |

**Do not invent:** `users.halaqaId`, a second roster collection, per-feature `isMember` flags,
password/role admin screens, messaging, or attendance/homework writes inside membership.

---

## 7. Explicitly out of scope (W8)

| Out                                                                       | Why                                                       |
|---------------------------------------------------------------------------|-----------------------------------------------------------|
| Account CRUD (create arbitrary roles, edit profile admin, password reset) | Rule 1 — not membership lifecycle                         |
| Parent↔child linking / unlinking                                          | Separate relationship (D-W8-5 A)                          |
| Unenroll / transfer / multi-halaqa membership                             | No current writer; new lifecycle — needs its own decision |
| Messaging about admission                                                 | Capability, not this workflow                             |
| P-E1 logout / identity reset                                              | Platform Epic                                             |
| Category B rules/indexes/CI                                               | Does not gate Phase 0 design                              |
| Changing W2 attendance statuses or W7 request semantics                   | Downstream consumers only                                 |
| Payments, audio uploads, awards coherence                                 | Other candidates                                          |
| Making teacher/supervisor invent local membership caches                  | Violates “consume resulting membership”                   |

---

## 8. Proposed slices (design only — after Rule 4 ownership package approval)

| Slice         | Intent                                                                                                                                                                 |
|---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Pre-Slice** | Shared atomic admit write + supervisor delegates to Current Implementation Owner; invariant tests; **no Slice 1 UI** — see `docs/W8_PRESLICE_PRODUCTION_VALIDATION.md` |
| **Slice 1**   | Staff admit path UI invoking **Academy Admission Workflow** (admin + supervisor); Rule 6 idempotent admit                                                              |
| **Slice 2**   | Operational readiness proof: teacher roster / student home / W3 readiness consume membership without local logic — see `docs/W8_SLICE2_PRODUCTION_VALIDATION.md`       |
| **Slice 3**   | Visibility for “not established” (Rule 8) — see `docs/W8_SLICE3_PRODUCTION_VALIDATION.md`                                                                              |
| **Slice 4**   | Completion gate — see `docs/W8_COMPLETION_PRODUCTION_VALIDATION.md`                                                                                                    |

Each slice: validate → analyze → tests → format → commit → push → **stop for approval**.

---

## 9. Success criteria (for later validation)

W8 passes when:

1. A clear answer exists to: **how a student becomes an active member of a halaqa** (stages
   identifiable end-to-end).
2. **Rule 2 holds:** completed membership = simultaneous required invariants.
3. **Rule 3 holds:** **Academy Admission Workflow** (Business Owner) maintains the invariant set; no
   individual field owns membership.
4. **Rule 4 holds:** Business Owner, invariant, and other-writer disposition were **product-approved
   before Pre-Slice**; Pre-Slice only verified the Current Implementation Owner matches; ownership
   was **not** permanently bound to a use-case name.
5. **Rule 5 holds:** membership invariant established atomically; W1–W7 never consume partial
   admission.
6. **Rule 6 holds:** repeated admission for the same student+halaqa converges to the same invariant.
7. **Rule 7 holds:** reconciliation is invariant-driven; W1–W7 stay independent of storage
   implementation.
8. **Rule 8 holds:** only established / not established are externally observable; consumers do not
   infer partial membership.
9. No new membership abstraction was invented to paper over ambiguity.
10. Other former writers are projections or retired per the approved package — no diverging
    membership contracts.
11. W1–W7 continue to **consume** existing fields **without** new local membership rules (§2.5.7).
12. The workflow is **not** an account-administration module (Rule 1).
13. Out-of-scope items (unenroll, parent linking, messaging, P-E1) remain out unless explicitly
    reopened.

---

## 10. Approval record

| Item                                                  | Status                                                   |
|-------------------------------------------------------|----------------------------------------------------------|
| W8 = Student Onboarding / Halaqa Membership Lifecycle | **Approved** (re-rank)                                   |
| Phase 0 path map / investigation                      | **Approved**                                             |
| **Rules 1–8**                                         | **Locked**                                               |
| D-W8-1 / D-W8-7                                       | **Approved**                                             |
| Pre-Slice / Slice 1 / Slice 2                         | **Approved**                                             |
| Slice 3 (observability)                               | **Pass** — `docs/W8_SLICE3_PRODUCTION_VALIDATION.md`     |
| Completion gate (Slice 4)                             | **Pass** — `docs/W8_COMPLETION_PRODUCTION_VALIDATION.md` |
| Any existing field as definitive SSOT                 | **Not promoted**                                         |
| Next workflow recommendation                          | **Blocked** until completion approval                    |

**W8 completion gate Pass. Stop here. Await approval before recommending the next workflow.**
