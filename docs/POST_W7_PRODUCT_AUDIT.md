# Post-W7 Product Audit

**Date:** 2026-07-30  
**Scope:** Academy as a complete product after W1–W7 (Homework · Attendance · Teacher Day Ops ·
Absence Awareness · Parent Academic Awareness · Supervisor Day Oversight · Parent Absence Request /
استئذان Lifecycle)  
**Method:** Read-only investigation. **No code changes. No commits. No pushes.**  
**Predecessors:** `docs/POST_W6_PRODUCT_AUDIT.md`, `docs/W6_COMPLETION_PRODUCTION_VALIDATION.md`,
`docs/W7_COMPLETION_PRODUCTION_VALIDATION.md`, `docs/W7_PHASE0_DESIGN.md`

### Classification legend

| Tag           | Meaning                                     |
|---------------|---------------------------------------------|
| **Verified**  | Observed in current code / approved docs    |
| **Inference** | Reasonable conclusion from Verified facts   |
| **Accepted**  | Explicitly deferred in an approved decision |

### Track boundary (standing)

| Track          | Meaning                                                                                                                   |
|----------------|---------------------------------------------------------------------------------------------------------------------------|
| **Category A** | Workflow / product / architecture debt that may travel with future business workflows when it protects or simplifies them |
| **Category B** | Platform / release-readiness / infrastructure — serious, but does **not** gate the next business workflow                 |

**Platform Epic P-E1** (role logout + identity reset) is **not** a business workflow. It remains a
parallel platform track and is **excluded from W8 ranking**.

---

## 0. Executive verdict

**W1–W7 now close one coherent academy day loop: operate → signal → excuse → observe.**

| Role           | What they can answer today                                                                                                              |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| **Teacher**    | What must I do today? (W3) · Mark presence (W2) · Assign/review homework (W1) · Classify استئذان (W7)                                   |
| **Parent**     | Was my child absent? (W4) · Was homework assigned/reviewed? (W5) · Submit/see استئذان outcome (W7) · Weekly attendance % from SSOT (W2) |
| **Supervisor** | Which supervised halaqat need attention? (W6) · See today’s استئذان as read-only facts (W7) · Escalate to teacher workflows (W6)        |

**Architecture held through W7.**

| Check                                                       | Verdict                                                                                                                                            |
|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| Attendance remains the single **operational** presence SSOT | **Pass (Verified)** — only `attendanceRecords` / `saveDayAttendance` write presence                                                                |
| Absence requests remain **contextual** only                 | **Pass (Verified)** — Rule 1: review updates `absenceRequests` status/`reviewedBy` only; never rewrites attendance                                 |
| Observers own no business rules; they project facts         | **Pass (Verified)** — Parent list + Supervisor section read docs; D-W7-6 = B (no new request event lifecycle); W6 readiness still shared projector |

**The product’s center of gravity has shifted again.** The operated day + excuse ritual is closed
enough to run. The largest **business** holes are no longer “mark attendance,” “see unexplained
absence,” or “submit استئذان.” They are **human coordination after facts are known**, plus
long-standing **shared-domain hygiene** and **Category B / P-E1** trust/infra tracks.

**Three findings dominate this audit:**

1. **Verified — presence SSOT and request context stayed correctly separated.** W7 did not create a
   second attendance owner. Weekly % still uses attendance facts only.
2. **Verified — parent still has no messaging surface**, while `ChatPermissionPolicy` already allows
   parent ↔ supervisor/admin (and deliberately **not** parent ↔ teacher). After W4–W7, parents have
   facts and requests but no in-app path to discuss them with the academy staff role the product
   already designated.
3. **Verified — Category B + P-E1 remain untouched** (no `firestore.rules` / `storage.rules` in
   repo, no CI, audio uploads disabled, B-R8 at-most-once, parent/supervisor/admin logout UI
   absent). They do **not** enter W8 ranking.

**Recommended next business workflow (W8):** Parent ↔ Supervisor Operational Messaging — give
parents a real chat surface against the **existing** permission policy, completing coordination
after W6/W7 facts without inventing a second SSOT or reopening teacher write ownership.
Justification in §6. **Await approval before Phase 0.**

---

## 1. Product whole — what W1–W7 own

| Workflow | One-line ownership                                                              | Status   |
|----------|---------------------------------------------------------------------------------|----------|
| **W1**   | Daily lesson & homework: assign → submit → review → parent weekly visibility    | Complete |
| **W2**   | Attendance register SSOT → student/parent aggregates                            | Complete |
| **W3**   | Teacher day orchestration over W1/W2 + schedule                                 | Complete |
| **W4**   | Absence awareness: attendance transitions → events → parent day signal          | Complete |
| **W5**   | Parent academic awareness via homework academy events                           | Complete |
| **W6**   | Supervisor day oversight: shared readiness projection + guidance escalation     | Complete |
| **W7**   | استئذان lifecycle: parent submit → teacher classify → parent/supervisor project | Complete |

### 1.1 End-to-end operated academy (**Verified**)

```text
Schedule (today)
  → Teacher readiness (W3) over shared HalaqaDayReadinessProjector
  → Attendance SSOT (W2) → Absence events (W4) → Parent inbox
  → Homework SSOT (W1) → Homework events (W5) → Parent inbox
  → Same readiness → Supervisor board (W6) → escalate to teacher workflows
  → Parent استئذان (W7) → Teacher classify request only (Rule 1)
  → Parent + Supervisor project request status (Rule 2; D-W7-6 B)
```

### 1.2 What it still cannot do as a closed business loop (**Verified**)

| Gap                                              | Evidence                                                                                    |
|--------------------------------------------------|---------------------------------------------------------------------------------------------|
| Parent discusses academy facts with staff in-app | No parent chat routes/UI; student/teacher chat exist; policy allows parent↔supervisor/admin |
| Parent ↔ teacher direct chat                     | **Policy forbids** (`ChatPermissionPolicy`) — Product Decision required to change           |
| Safe multi-role device handoff                   | No parent/supervisor/admin logout UI; singleton blocs retain prior projections (**P-E1**)   |
| Student audio submit as product                  | `AppCapabilities.audioUploadsEnabled = false`                                               |
| Parent payments                                  | Initiate path throws / unavailable; no payment UI product                                   |
| Admin product surface                            | Home is “Coming Soon”; stubs exist                                                          |
| استئذان inbox signals                            | **Accepted** D-W7-6 = B; no `AbsenceRequest*` academy events                                |
| Live already-reviewed eval → academy event       | Accepted W5 residual                                                                        |

---

## 2. Mandatory architecture checks (post-W7)

### 2.1 Attendance remains the single operational SSOT (**Verified**)

| Fact                  | Evidence                                                                                                             |
|-----------------------|----------------------------------------------------------------------------------------------------------------------|
| Presence writes       | Teacher `saveDayAttendance` → `attendanceRecords` via `AttendancePolicy.documentId`                                  |
| Aggregates / weekly % | Parent weekly report still reads attendance records + `AttendancePolicy.attendancePercent`                           |
| W7 review path        | `ReviewAbsenceRequestUseCase` / datasource update `status` + `reviewedBy` only                                       |
| UI contract           | Teacher attendance copy states decision does not rewrite attendance; parent outcome copy states request ≠ attendance |

**Verdict:** Pass. No second presence owner.

### 2.2 Absence requests remain contextual only (**Verified**)

| Fact                     | Evidence                                               |
|--------------------------|--------------------------------------------------------|
| Collection role          | `absenceRequests` = intent + classification            |
| Submit                   | Allowed before attendance (D-W7-2); no attendance gate |
| Approve/reject           | Request status only (Rule 1 / D-W7-3)                  |
| No `excused` wire status | Still three attendance statuses only                   |

**Verdict:** Pass.

### 2.3 Observers project facts; they do not own rules (**Verified**)

| Observer                | Projection source                      | Owns writes?                                     |
|-------------------------|----------------------------------------|--------------------------------------------------|
| Parent (W7 list)        | Own `absenceRequests` by `requestedBy` | Submit only (authorized children); no attendance |
| Teacher (W7 queue)      | Pending for owned halaqa + day         | Classify request only                            |
| Supervisor (W7 section) | Supervised halaqat’ requests for today | **Read-only**; escalate to attendance route      |
| Supervisor (W6 board)   | Shared readiness projector             | Guidance only (`TeacherWorkflowOwnership`)       |
| Parent inbox (W4/W5)    | Academy event fan-out                  | Delivery projection; publishers stay domain      |

**Verdict:** Pass. Rule 2 held; no observer-owned lifecycle flags.

---

## 3. Cross-workflow consistency & duplication

### 3.1 Held correctly (**Verified**)

| Principle                      | Evidence                                                                                                      |
|--------------------------------|---------------------------------------------------------------------------------------------------------------|
| One readiness math             | `HalaqaDayReadinessProjector` — teacher agenda + supervisor board                                             |
| Attendance day encoding        | W7 request ids + teacher/supervisor request day filters use `AttendancePolicy.dayStart` / `isSameCalendarDay` |
| Events = facts (where used)    | W4/W5 kinds only; no request events under D-W7-6 B                                                            |
| Supervisor does not teach      | W6 Rule 6 + W7 read-only استئذان                                                                              |
| Deterministic request identity | `AbsenceRequestIds` aligned with attendance day encoding                                                      |

### 3.2 Duplicated or drifted logic after W1–W7 (**Verified**)

| Issue                                                       | Detail                                                                                                                                   | Risk                                                                                              |
|-------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| **Absence request reads ×3 feature stacks**                 | Parent list · teacher pending · supervisor day projection — similar Firestore `halaqaId` / `requestedBy` queries in separate datasources | Drift if day filter / status semantics diverge — extract **read port**, not a second status model |
| **`AbsenceRequestEntity` lives under parent feature**       | Teacher + supervisor import parent domain/model                                                                                          | Layering smell; concept is academy-wide                                                           |
| **`AbsenceRequestProjection` under parent domain**          | Supervisor UI imports parent package for labels                                                                                          | Same — move with entity to shared when touched                                                    |
| **Latest-assignment query still ×4**                        | Student / homework / teacher / parent `orderBy dueDate DESC limit 1`                                                                     | Still no `AssignmentPolicy`                                                                       |
| **Calendar-day SSOT under-adopted outside W7 touch points** | Many UI/local day normalizations still hand-rolled                                                                                       | Pre-W7 debt; W7 improved its own path                                                             |
| **Three “week” definitions**                                | Parent Saturday · progress Sunday · analytics rolling 7                                                                                  | **Accepted** debt                                                                                 |
| **Legacy notification artifacts**                           | Active fan-out path vs leftover composers/sinks                                                                                          | Cleanup hygiene                                                                                   |
| **Admin broadcast bypasses event stream**                   | Direct `notifications.add`                                                                                                               | Parallel delivery ownership                                                                       |
| **Schedule mapper imported by domain use cases**            | Teacher + supervisor → `schedule/data/...`                                                                                               | Layering debt                                                                                     |
| **Operational readiness I/O still dual-orchestrated**       | Teacher agenda + supervisor board each load attendance/homework/reviews                                                                  | Shared projector for **rules**; I/O port still missing                                            |

### 3.3 Parallel ownership / second-SSOT check

| Area                     | After W7                                          | Verdict                                             |
|--------------------------|---------------------------------------------------|-----------------------------------------------------|
| Attendance marks         | Single collection                                 | **Healthy**                                         |
| Absence requests         | Single collection; status owned by teacher review | **Healthy**                                         |
| Day readiness            | Shared projector                                  | **Healthy**                                         |
| Homework assign/review   | Single collections + events                       | **Healthy**                                         |
| Request outcome delivery | UI projection only (B)                            | **Healthy** (no duplicated event lifecycle)         |
| Assignment “latest” rule | Query duplicated 4×                               | **At risk** — extract before new homework consumers |
| Request day-scoped reads | Query pattern duplicated across roles             | **At risk of drift** — extract shared read helper   |

**Inference:** W7 closed the orphan product hole without regressing ownership. New duplication is
mostly **read adapters** for the same fact — acceptable short-term, extract before W8+ if messaging
or more request consumers appear.

---

## 4. Shared concepts — extract now vs later

| Concept                                     | Status                             | Recommendation                                                            |
|---------------------------------------------|------------------------------------|---------------------------------------------------------------------------|
| **Halaqa day readiness**                    | Extracted (W6)                     | Keep; do not fork                                                         |
| **Academy events + sink**                   | Extracted (W4/W5)                  | Keep; retire legacy composers when safe                                   |
| **AttendancePolicy**                        | Shared; better adopted on W7 paths | Continue migrating bypass sites when touching files                       |
| **AbsenceRequestIds**                       | Shared util                        | Keep                                                                      |
| **Absence request entity/model/projection** | Feature-owned (parent)             | **Category A:** move to shared domain when next workflow touches requests |
| **Absence request day-scoped reads**        | Duplicated adapters                | **Category A:** thin shared read port (filter/auth stay in use cases)     |
| **Assignment “current/latest” policy**      | Still missing                      | **Category A** before any new homework consumer                           |
| **Operational day reads port**              | Still missing                      | **Category A** — I/O only, no new rules                                   |
| **User display-name lookup**                | Still duplicated                   | **Category A** helper                                                     |
| **Week-start / weekday labels**             | Fragmented                         | **Category A** glossary + helpers                                         |
| **HalaqaWeeklySessionsMapper location**     | Data imported by domain            | **Category A** domain port                                                |

**Do not extract prematurely as “platform services”:** payments, audio, admin console — still
product-blocked or incomplete.

---

## 5. Category A — business workflow / architecture debt

| ID         | Item                                                              | Why it belongs with future work                                                                 |
|------------|-------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| **A-W7-1** | Move `AbsenceRequestEntity` / model / projection to shared domain | Teacher + supervisor already depend on parent feature                                           |
| **A-W7-2** | Shared absence-request read helper (day + halaqa scope)           | Prevent teacher/supervisor/parent query drift                                                   |
| **A-W7-3** | Optional D-W7-6 = A request outcome events                        | Only if product wants inbox parity; must stay fact projections (Rule 2) — **not** a second SSOT |
| **A-W6-1** | Shared operational-reads port for readiness I/O                   | Protects teacher + supervisor                                                                   |
| **A-W6-2** | `AssignmentPolicy` / single latest-due owner                      | Any homework-adjacent Wn                                                                        |
| **A-W6-3** | Migrate remaining calendar-day call sites to `AttendancePolicy`   | Ongoing                                                                                         |
| **A-W6-4** | Quarantine/delete legacy notification composers                   | Dual delivery hygiene                                                                           |
| **A-W6-5** | Weekly-sessions derivation behind domain port                     | Layering                                                                                        |
| **A-W6-6** | Terminology / glossary pass                                       | UX consistency                                                                                  |
| **A-W6-7** | Live already-reviewed eval → event                                | W5 residual                                                                                     |
| **A-W6-8** | Escalation honesty vs server rules                                | Client gates exist; server rules are Category B                                                 |

Category A may join W8 **only when it directly protects that workflow**.

---

## 6. Category B — platform / release readiness (does not gate W8)

| ID            | Item                               | Current state (**Verified**)                                               |
|---------------|------------------------------------|----------------------------------------------------------------------------|
| **B-R1**      | `firestore.rules`                  | Absent from repo                                                           |
| **B-R2**      | `storage.rules`                    | Absent from repo                                                           |
| **B-R3**      | `firebase.json` full deploy wiring | FlutterFire-oriented; rules/indexes not a complete source-controlled stack |
| **B-R4**      | Composite index completeness       | Partial / historically console-driven                                      |
| **B-R5**      | CI                                 | No `.github/workflows` evidenced                                           |
| **B-R6**      | Reproducible deploy docs           | Blocked by missing rules                                                   |
| **B-R7**      | App Check posture                  | Not evidenced                                                              |
| **B-R8**      | At-most-once academy-event publish | Client publish-after-commit; no durable retry                              |
| **B-Storage** | Audio uploads / Blaze              | `audioUploadsEnabled = false`                                              |

### Platform Epic (separate from workflow ranking)

| ID       | Item                                                              | Why not W8                                                                                                              |
|----------|-------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| **P-E1** | Logout + singleton identity reset for parent / supervisor / admin | **High trust** on shared devices after W4–W7, but **not** a business workflow. Track in parallel; do not Phase-0 as W8. |

---

## 7. Re-ranked remaining **business** workflows (current product value)

Ranking criteria: closes a real academy loop · reuses W1–W7 facts · backend readiness · avoid
Category B · maintainability · does not invent parallel ownership · respects standing product
policy.

| Rank  | Candidate                                               | Product value now                                                    | Dependency                                            | Backend ready?                                                  | Reuse of W1–W7                  | Maintainability          | Notes                                             |
|-------|---------------------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------------|-----------------------------------------------------------------|---------------------------------|--------------------------|---------------------------------------------------|
| **1** | **Parent ↔ Supervisor operational messaging**           | **High** — parents have facts/requests but no staff dialogue surface | Existing `ChatPermissionPolicy` + chat stack          | Partial UI (student/teacher chat exist; parent surface missing) | High (coordination after W4–W7) | Good if scoped to policy | Closes human loop without new SSOT                |
| 2     | Teacher ↔ parent direct messaging                       | Medium–High **if** policy changes                                    | Requires **Product Decision** to allow parent↔teacher | Same chat stack                                                 | Medium                          | Policy + UX risk         | Currently **forbidden** by design                 |
| 3     | Awards / encouragement coherence (teacher + supervisor) | Medium                                                               | Existing awards + supervisor issue                    | Mostly ready                                                    | Medium                          | Terminology debt         | Polish, not the biggest hole                      |
| 4     | استئذان inbox via academy events (D-W7-6 A)             | Medium                                                               | W7 facts + W4/W5 sink                                 | Ready for thin event kinds                                      | High                            | Must obey Rule 2         | Better as **Category A** companion than a full Wn |
| 5     | Admin operational console                               | Medium commercially                                                  | Admin stubs                                           | Low UI                                                          | Low event reuse                 | Poor until rules (B)     | Premature as W8                                   |
| 6     | Live-eval → academy event residual                      | Low–Medium                                                           | W5 pipeline                                           | Small                                                           | High                            | Good                     | Prefer Category A attach                          |
| —     | Student audio submit                                    | High when unblocked                                                  | Storage / Blaze                                       | **Blocked (B)**                                                 | Existing path                   | Neutral                  | Not Wn until infra                                |
| —     | Payments                                                | High commercially                                                    | Cloud Function                                        | **Blocked**                                                     | Low                             | Poor                     | Not W8                                            |
| —     | P-E1 logout / identity reset                            | **High trust**                                                       | Auth + DI reset                                       | Ready                                                           | Protects all observers          | Improves                 | **Platform Epic — not W8**                        |

### Recommended W8 — Parent ↔ Supervisor Operational Messaging

**One sentence:** Let a linked parent open and continue in-app conversations with the supervisor (
and admin if already allowed), so academy facts from W4–W7 can be discussed without inventing a new
ownership path for attendance, homework, or استئذان.

**Why this is the highest-value business workflow now (not the previous roadmap):**

1. **The operated day + excuse loop is closed.** Ranking must follow **current** holes. استئذان is
   no longer the top unfinished ritual.
2. **Verified product asymmetry.** Student and teacher have chat routes; parent has **none**,
   despite policy already allowing parent ↔ supervisor/admin. That is an incomplete coordination
   loop, not infrastructure theater.
3. **Natural extension of W6/W7 roles.** Supervisor already observes readiness and استئذان and
   escalates to teachers. Messaging completes Parent → Supervisor → Teacher guidance without giving
   parents a second write path into teacher SSOTs.
4. **Respects standing chat policy.** Recommending parent↔teacher as W8 would require reopening a
   Product Decision the domain policy currently rejects. W8 should ship against **existing**
   `ChatPermissionPolicy`.
5. **Backend not Category-B-blocked.** Conversation id generation, permission use cases, and room UI
   already exist for other roles — W8 is primarily parent surface + reachability/list flows, not a
   new chat product invention.
6. **Does not invent parallel ownership.** Messages remain communication; attendance, homework, and
   request status stay in their collections. Prefer deep-links/references to existing facts over
   duplicating status into chat.

**Explicitly not W8:** P-E1 logout, Storage/audio, payments, admin console, parent↔teacher policy
flip without approval, reopening attendance SSOT, treating D-W7-6 A as the whole next workflow.

**Suggested Category A companions if W8 is approved:** only what messaging needs (e.g. display-name
helper, conversation list empty/error/retry consistency). Do **not** force AssignmentPolicy or
absence-entity moves unless W8 touches those files.

---

## 8. Audit deliverables checklist

| Requested                                     | Location      |
|-----------------------------------------------|---------------|
| Whole-product view after W1–W7                | §0–§1         |
| Attendance SSOT verification                  | §2.1          |
| Absence requests contextual-only verification | §2.2          |
| Observers project-only verification           | §2.3          |
| Duplicated business logic across W1–W7        | §3            |
| Shared concepts to extract                    | §4            |
| Category A vs Category B                      | §5–§6         |
| Platform Epics kept separate from ranking     | §6 + §7 table |
| Re-rank remaining business workflows          | §7            |
| W8 recommendation + justification             | §7            |

---

## 9. Stop gate

**Deliverable for this step:** `docs/POST_W7_PRODUCT_AUDIT.md` only.

**Do not start W8 Phase 0 until product approves:**

1. This audit’s Category A / B / P-E1 separation
2. **W8 = Parent ↔ Supervisor Operational Messaging** (or an explicit alternate)
3. Confirmation that **parent↔teacher chat remains out of scope** unless a separate Product Decision
   changes `ChatPermissionPolicy`
4. Confirmation that **P-E1 remains a Platform Epic**, not W8

**No implementation. No commits. No pushes.**
