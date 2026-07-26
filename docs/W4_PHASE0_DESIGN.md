# W4 — Absence Awareness & Parent Day Signal
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Phase 0 approved with workflow + multi-channel adjustments (2026-07-26). **Pre-Slice Pass** (`docs/W4_PRESLICE_PRODUCTION_VALIDATION.md`) · **Slice 1 Pass** (`docs/W4_SLICE1_PRODUCTION_VALIDATION.md`). Awaiting Slice 2 approval.  
**Date:** 2026-07-26  
**Predecessors:** W1 + W2 + W3 complete; `docs/POST_W3_PRODUCT_AUDIT.md` approved with Category A/B adjustment  
**Standing rule:** If an assumption is wrong: **stop**, update this document, then continue.  

### Classification

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed directly in current code or an approved product decision |
| **Inference** | Conclusion supported by Verified facts, but not an approved product rule |
| **Product Decision** | A choice that changes workflow behavior and requires approval |

### Debt-track boundary

- **Category A — Product & Architecture debt** may be addressed inside W4 only when it directly protects or simplifies this workflow.
- **Category B — Platform Hardening** (`firestore.rules`, `storage.rules`, deploy wiring, CI, release pipeline) is tracked as a later **Release Readiness** milestone. It does **not** block W4 and is not part of the proposed W4 slices.

---

## 0. Goal (workflow, not a notification feature)

### 0.1 Workflow (approved)

W4 is an **academy attendance-awareness workflow**. The notification is only one consequence of that workflow.

```text
Teacher completes attendance
  → attendanceRecords remain the SSOT
  → academy derives an operational event (student explicitly absent / absence corrected)
  → parent can immediately know the child was absent
  → weekly / later reports continue to reuse the same attendance data
```

W4 is **not**:

- a new attendance module,
- a generic messaging product,
- a “notifications feature” whose business meaning lives in the inbox.

The **attendance document** is the single source of truth. Any parent-facing message is a **projection** of attendance transitions. Reports never read notifications to decide what happened.

### 0.2 Delivery channels (approved constraint — do not over-engineer)

Identify the **academy event** first. Delivery second.

| Concept | Role |
|---------|------|
| Attendance SSOT | `attendanceRecords` with deterministic day IDs |
| Academy event | Stable operational fact (e.g. student absent recorded / absence corrected) |
| Delivery channel | Projection of that event (in-app inbox today; FCM / SMS / email / WhatsApp later) |

W4 only implements the **attendance** events. Future workflows may emit other events (`HomeworkAssigned`, `HomeworkReviewed`, …) using the same pattern — **Inference / reserved names**, not Pre-Slice work.

**Hard rule:** the attendance save / attendance repository must **not** depend on one concrete notification writer. Attendance may emit events through a narrow sink/port; today’s sink may write in-app notifications only. Adding FCM later must not rewrite attendance policy or day-save semantics.

The proposed MVP delivery is still an **in-app** parent signal. **OS push is not implemented** and must not be promised in copy.

---

## 1. Real academy workflow

### 1.1 Operational sequence

```text
Before the halaqa
  Parent may know the child will be absent
      └─ Current استئذان stack cannot complete this operation (write only)

During / after the halaqa
  Teacher selects Present / Absent / Late for every roster student
      └─ Save is enabled when the full loaded roster has a selection
            └─ Atomic day save → attendanceRecords (SSOT)
                  ├─ Derive academy events from status transitions
                  │     previous → explicit absent  → StudentAbsentRecorded
                  │     explicit absent → present/late → StudentAbsenceCorrected
                  │     unchanged absent / late / present → no event
                  ├─ Resolve linked parent account(s) for affected students
                  └─ Publish events through AcademyEventSink
                        └─ Current sink: in-app notifications only
                        └─ Future sinks: FCM / SMS / email / WhatsApp (not W4)

Later correction
  Teacher changes Absent → Present or Late and saves again
      └─ Attendance document is updated (SSOT)
      └─ Correction event is published for the same operational identity

Parent
  Opens parent home / notification inbox (current channel)
      └─ Sees child name + actual attendance date + neutral status wording
      └─ Weekly report remains the aggregate truth surface (same attendance data)
```

### 1.2 Product-practice classification

| Practice | Classification | W4 consequence |
|----------|----------------|----------------|
| Manual teacher register is attendance SSOT | **Verified** (`W2_PHASE0_DESIGN.md:134`) | Events/notifications never create or override attendance |
| Parents commonly expect an absence alert | **Verified** research framing (`W2_PHASE0_DESIGN.md:136`) | W4 reopens W2 D2 as a workflow consequence |
| Late counts as attended | **Verified / Approved W2 D1** | Late never produces an absence event |
| Attendance remains calendar-day + halaqa based | **Verified / Approved W2 D7, W3 D6** | No session/slot ID is introduced |
| A later attendance correction should reach the parent | **Inference** | Product Decision D-W4-4 |
| Delivery may later include push/SMS/email | **Product Decision** (channel strategy) | Keep a sink/port; implement in-app only now |
| A parent may submit an excuse before/after absence | **Verified academy practice**, **not a Rafiq rule** | Requires a separate coherent approval workflow |
| Teacher vs supervisor/admin owns excuse approval | **Unverified** | Must not be guessed inside W4 |

---

## 2. Current implementation map

### 2.1 Teacher register — Verified and reusable

| Step | Current owner | Verified behavior |
|------|---------------|-------------------|
| Select statuses | `TeacherAttendancePage` | Explicit selection only; no default-present (`teacher_attendance_page.dart:28–29`) |
| Register completeness before save | `TeacherAttendancePage` | Save enabled only when every loaded student has a selection (`:85–88`, `:216–222`) |
| Status set | `AttendanceStatus` | `present`, `absent`, `late` only (`teacher_repository.dart:10`) |
| Build records | `TeacherAttendancePage._saveAttendance` | Includes student/halaqa/date/status/teacher (`:334–348`) |
| Save orchestration | `TeacherBloc._onSaveDayAttendance` | Submission state; reloads day and W3 agenda only after success (`teacher_bloc.dart:257–292`) |
| Persist day | `TeacherRemoteDatasourceImpl.saveDayAttendance` | Reads existing day, validates batch size, deterministic IDs, merge writes, deletes legacy duplicates, one atomic commit (`teacher_remote_datasource_impl.dart:73–143`) |
| Attendance identity | `AttendancePolicy.documentId` | `{halaqaId}_{studentId}_{yyyyMMdd}` (`attendance_policy.dart:48–59`) |
| W3 readiness | `AttendancePolicy.isRegisterComplete` | Roster IDs must be contained in marked IDs (`:62–89`) |

**Direct consequence:** a successful save from the current attendance UI is already a full-selection day write. W4 must not invent a second `registerSubmitted` or `sessionCompleted` flag.

**Verified nuance — completeness has two owners:**

1. **UI save gate** requires every *loaded* student to have an explicit selection.
2. **W3 agenda completeness** uses raw `halaqa.studentIds` via `AttendancePolicy.isRegisterComplete`.

The datasource does **not** enforce full roster by itself (`saveDayAttendance` accepts any non-empty list). The UI roster is `halaqa.studentIds ∩ existing users`, so a roster id with no `users` document can keep the agenda incomplete while the attendance page never shows that student. W4 should fire from the **successful attendance save transition**, not invent a second completeness rule; the roster mismatch remains Category A debt and must not be papered over with a new flag.

### 2.2 Parent linkage — Partially implemented

| Capability | Classification | Evidence |
|------------|----------------|----------|
| Parent account knows its children | **Verified** | `parentProfiles/{parentUid}.childrenIds`; `getChildrenIds(parentId)` (`parent_remote_datasource_impl.dart:23–35`) |
| Parent can switch children | **Verified** | `ParentBloc` + `ParentHomePage` |
| Find parent account(s) from a student ID | **Missing** | No reverse lookup method/query exists |
| Auth/app creates `parentProfiles` | **Missing** | No creator under `lib/features/auth`; linking appears external/manual |
| Multiple linked parent accounts for one child | **Unverified data possibility** | Schema does not enforce one parent; product must decide recipient behavior |
| Parent has a notifications route | **Missing** | Router registers notifications only under student and teacher; `/parent` has no child routes (`router_app.dart:346–350`) |
| Parent starts the notifications watcher | **Missing** | Only `StudentHomePage` and `TeacherHomePage` dispatch `StartWatchingNotificationsEvent` |
| Parent ↔ teacher dispute chat | **Missing / blocked by policy** | `ChatPermissionPolicy` allows parent↔supervisor/admin, not parent↔teacher |

### 2.3 Notification infrastructure — Partially reusable

**Verified current schema**

```text
notifications/{autoId}
  audience: string          // uid, role, or "all"
  title: string
  body: string
  type: string
  readBy: string[]
  hasAudioAlert: bool
  createdAt: timestamp
```

| Capability | Classification | Evidence |
|------------|----------------|----------|
| Personal recipient | **Verified** | Query includes `audience == uid` (`notifications_remote_datasource.dart:40–46`) |
| Role/global recipient | **Verified** | Same query includes role and `all` |
| Per-user read state | **Verified** | `readBy` membership (`notification_model.dart:16–34`) |
| Real-time inbox + unread count | **Verified** | `NotificationsBloc` + `NotificationsPage` |
| Create/write repository API | **Missing by design** | `NotificationsRepository` is watch + mark-read only; writers live inline next to source mutations (W1 assign/review, admin broadcast) |
| Parent recipient | **Supported by schema, not wired** | A parent UID is a valid `audience` string |
| Attendance notification type | **Missing** | `NotificationTypes` has no attendance/absence type (`app_constants.dart:55–64`) |
| Deep-link metadata | **Missing** | Entity contains no route/data payload; tapping only marks read (`notification_page.dart:156–168`) |
| Idempotent notification identity | **Missing** | Existing assignment/review writers use auto IDs |
| Parent watcher isolation | **Missing / Category A** | Singleton watcher retains old notifications while switching users/roles; loading does not clear the list |
| OS push / FCM delivery | **Missing** | `FirebaseMessaging` is registered in DI only; no token storage, handler, sender, or function exists |

**Schema conclusion (Inference):** direct parent-UID notifications require **no new collection or field**. A deterministic document ID can provide idempotency without changing document shape. Parent-recipient discovery is the missing read. Child/date context can live in Arabic `title`/`body` for MVP; structured deep-link fields are not required for the inbox-only surface.

### 2.4 `absenceRequests` — Partially implemented but not a workflow

| Layer | Current state |
|-------|---------------|
| Entity/model | `studentId`, `requestedBy`, `date`, `reason`, `pending/approved/rejected`, optional `reviewedBy` |
| Write | `ParentRemoteDatasource.submitAbsenceRequest` uses auto-ID `.add()` |
| Use case / repository | Implemented |
| ParentBloc | Submit/reset events and submission state implemented |
| Parent UI | **None** |
| List/read requests | **None** |
| Approve/reject | **None** |
| Approver actor | **Undefined** |
| Link to halaqa | **Missing** — ambiguous if a student belongs to multiple halaqat |
| Effect on attendance / percentage | **Undefined**; W2 D6 explicitly rejected an `excused` attendance status |

**Verified conclusion:** exposing the current submit API would create a dead end. A full excuse lifecycle is larger than absence awareness and cannot be included without decisions about approver, halaqa identity, timing, and attendance effect.

### 2.5 Cloud / push automation

- **Verified:** Cloud Functions contain Paymob/payment code only; no attendance trigger or notification sender.
- **Verified:** Firebase Messaging is registered but otherwise unused.
- **Conclusion:** W4 cannot honestly promise an OS push alert by reusing current code. The available delivery mechanism is the existing Firestore-backed in-app inbox.

---

## 3. Reuse map

```text
TeacherAttendancePage
  full loaded roster explicitly selected
            │
            ▼
SaveDayAttendance (attendanceRecords SSOT)
  existing-day read + deterministic IDs + atomic batch
            │
            ▼
AttendanceAbsenceTransitions (pure)
  explicit absent / correction events only
            │
            ▼
AcademyEvent (StudentAbsentRecorded / StudentAbsenceCorrected)
  stable eventId from attendance document id
            │
            ├──────── Parent recipient resolver
            │          parentProfiles.childrenIds (chunked)
            │
            └──────── AcademyEventSink (port)
                       │
                       ├─ W4: InAppNotificationSink → notifications collection
                       └─ Later: FcmSink / SmsSink / EmailSink / WhatsAppSink
                                  (add without changing attendance save)

Parent weekly report
  continues to read attendanceRecords directly (never notifications)
```

| W4 need | Reuse | New (thin) |
|---------|-------|------------|
| Attendance SSOT | Existing day save + deterministic IDs | Nothing |
| Explicit absence / correction | `AttendancePolicy` status constants | Pure transition projector (not `isAbsentStatus`) |
| Academy event identity | `AttendancePolicy.documentId` | `AcademyEvent.eventId` |
| Parent relationship | `parentProfiles.childrenIds` | Reverse recipient resolver |
| Delivery today | Existing `notifications` schema + inbox | One sink implementation behind a port |
| Future channels | — | Additional sinks only |
| Weekly truth | Existing weekly report | No duplicate attendance history |

**Hard rule:** `saveDayAttendance` persists attendance and may request event publication through `AcademyEventSink`. It must not import or embed a concrete FCM/SMS/notification writer.

---

## 4. Workflow-state derivation (no parallel attendance logic)

W4 acts on **explicit status transitions**, not on “not attended”:

```text
previous != 'absent'  AND current == 'absent'
    → StudentAbsentRecorded

previous == 'absent'  AND current == 'absent'
    → no event (idempotent re-save)

previous == 'absent'  AND current in {'present', 'late'}
    → StudentAbsenceCorrected

all other transitions
    → no event
```

Attendance truth remains the deterministic `attendanceRecords` document. Prior status comes from the existing pre-save day query (raw Firestore status strings — **not** the model path that maps unknown → absent).

**Important policy hazard (Verified):** `AttendancePolicy.isAbsentStatus` means “not attended” and treats null/unknown as absent. W4 must use **explicit `'absent'`** only. Centralizing that projector next to `AttendancePolicy` (with tests) is a justified Category A Pre-Slice improvement.

---

## 5. Architecture options and Firestore / I/O impact

### 5.1 Recommended write architecture

| Option | Meaning | Verdict |
|--------|---------|---------|
| **A. Attendance SSOT save → derive AcademyEvent → AcademyEventSink (recommended)** | Attendance never depends on one channel; today’s sink writes in-app notifications | Matches approved constraint |
| B. Inline notification writes inside `saveDayAttendance` | Couples attendance to one delivery mechanism | **Rejected** by approved Phase 0 adjustment |
| C. Cloud Function on attendance write | Cleaner later hardening | Category B / platform; out of W4 |
| D. Separate notify use case with its own meaning of absence | Second business rule | Reject |

**Boundary ownership:**

1. **Attendance path** owns SSOT write and asks for event derivation after previous/current statuses are known.
2. **Shared/domain** owns `AcademyEvent` + transition projector + `AcademyEventSink` port.
3. **Parent feature** owns reverse recipient lookup (`parentProfiles`).
4. **In-app notification sink** (Slice 1) owns mapping events → `notifications` docs. Future channels are additional sinks.

### 5.2 Existing collections only

| Collection | W4 operation | Reason |
|------------|--------------|--------|
| `attendanceRecords` | Existing read + batch write | SSOT; unchanged |
| `parentProfiles` | New reverse recipient read | Resolve parent document IDs from existing `childrenIds` |
| `notifications` | Written only by the in-app sink | One channel projection; not the SSOT |

No new collection is required. No new attendance field is required.

### 5.3 Recipient lookup

1. Collect student IDs from derived absence/correction events.
2. Resolve parent profiles using `childrenIds arrayContainsAny` in chunks (Firestore operand limit).
3. Match returned profiles’ `childrenIds` to affected students.
4. Pass recipients with the event to the sink (or let the sink resolve once via the parent port).

### 5.4 Atomicity and failure

- Attendance save remains the SSOT commit.
- Recipient-resolution failure before publish follows D-W4-5 (fail closed recommended).
- Empty recipient set is not an error: attendance saves; no channel message is produced.
- In-app sink should use deterministic delivery document IDs derived from `eventId` + parent UID so re-saves do not spam.

### 5.5 Platform boundary

Category B Release Readiness remains deferred and does not gate W4.

---

## 6. Product gaps

| ID | Gap | Classification | Recommended disposition |
|----|-----|----------------|-------------------------|
| G1 | No absence communication after register save | **Missing** | Core W4 |
| G2 | No reverse student→parent resolution | **Missing architecture** | Extend existing parent-link read; chunked |
| G3 | Parent has no notification entry/watcher | **Missing UI composition** | Reuse inbox + unread badge; no new page |
| G4 | Re-save would duplicate an auto-ID notification | **Missing correctness** | Deterministic signal ID + transition rule |
| G5 | Absent→present/late leaves a false historical message | **Missing correctness** | Correction update to same signal |
| G6 | Notification singleton can retain another user's list | **Category A stale state** | Fix as part of parent watcher integration |
| G7 | Parent may be unlinked | **Verified possible state** | Attendance still valid; no recipient exists |
| G8 | Multiple linked parents | **Product Decision** | Recommend notify every linked parent |
| G9 | Historical register edits | **Product Decision** | Recommend signal every genuine transition; include actual date |
| G10 | No OS push | **Verified missing** | Explicitly out of W4 MVP |
| G11 | `absenceRequests` has no coherent lifecycle | **Partially implemented** | Keep dormant; separate Phase 0 later |
| G12 | No `excused` attendance status | **Approved W2 D6** | Do not add in W4 |
| G13 | UI roster vs raw `halaqa.studentIds` can diverge | **Verified Category A** | Do not invent a second completeness flag; track as debt |
| G14 | Unknown attendance string maps to `absent` on read | **Verified** | Another reason W4 must use explicit status transitions, not `isAbsentStatus` |

---

## 7. Required product decisions

### D-W4-1 — Who receives an absence signal?

| Option | Meaning |
|--------|---------|
| **A. Every linked parent account (recommended)** | Query all `parentProfiles` containing the student; each receives personal read state |
| B. First parent only | Depends on unstable ordering and silently excludes another guardian |
| C. Parent + student | Expands W4 beyond the identified parent gap |

**Recommendation: A.** The existing schema permits multiple links; do not invent a primary guardian.

### D-W4-2 — Which statuses generate the signal?

| Option | Meaning |
|--------|---------|
| **A. Explicit `absent` only (recommended)** | Preserves approved W2 D1: `late` is attended |
| B. Absent + late | Contradicts current attendance product meaning |

**Recommendation: A.** Do not use “not attended” as a proxy; match the explicit status.

### D-W4-3 — First-save and repeat-save behavior

| Option | Meaning |
|--------|---------|
| **A. Transition-based + deterministic (recommended)** | Create only when entering absent; same absent re-save is a no-op |
| B. Notify on every save containing absent | Duplicate alerts and parent distrust |

**Recommendation: A.** Notification identity derives from parent UID + deterministic attendance ID.

### D-W4-4 — Corrections

| Option | Meaning |
|--------|---------|
| **A. Update the same signal to a correction and make it unread again (recommended)** | Parent sees that the academy corrected the record; no contradictory duplicate remains |
| B. Delete the absence signal | Parent may have seen it; deletion hides the correction |
| C. Create a second correction notification | Preserves history but leaves two conflicting cards and adds noise |
| D. Do nothing | Leaves known false information |

**Recommendation: A.** Attendance record remains SSOT; the notification is a current communication projection.

### D-W4-5 — Failure semantics

| Option | Meaning |
|--------|---------|
| ~~A. Fail closed before any write if recipient resolution errors~~ | Superseded — see below |
| **B. Save attendance and surface a partial warning (implemented in Slice 1)** | Attendance is the primary operation; a publication failure is reported, not hidden |
| C. Best effort, silent | Unacceptable for the workflow's core promise |

An empty recipient set is **not** an error: the register saves, but there is no linked parent to notify.

**Superseded by the approved Slice 1 constraints (2026-07-26).** Publication must describe a *successful* attendance save, and recipient resolution must stay outside the attendance domain — so resolution cannot precede the commit. Attendance now commits first; a publication failure leaves the register valid and tells the teacher «تم حفظ الحضور، لكن تعذّر إبلاغ أولياء الأمور بالتغييرات». Because an unchanged re-save correctly emits no event, a failed publication is not repaired by retrying; a durable outbox or server-side trigger is out of W4 scope and is raised at the Slice 2 gate.

### D-W4-6 — Historical edits

| Option | Meaning |
|--------|---------|
| **A. Signal every genuine transition within the existing editable window, with the actual date (recommended)** | A late-entered or corrected register remains honest |
| B. Today only | Quiet, but parents never learn about valid late entries/corrections |

### D-W4-7 — Delivery channel

| Option | Meaning |
|--------|---------|
| **A. Existing in-app inbox only for W4 (recommended)** | Verified architecture; available live while open and on next open |
| B. Add OS push | Requires token lifecycle + backend sender; not reusable today |

Copy and documentation must say “in-app signal/notification”, not promise phone push delivery.

### D-W4-8 — Parent surface

| Option | Meaning |
|--------|---------|
| **A. Reuse `NotificationsPage` + unread badge from ParentHome (recommended)** | No duplicated inbox; minimal composition |
| B. Add a dedicated absence-history page | Duplicates weekly attendance truth and expands scope |
| C. Put only a transient banner on ParentHome | Easy to miss; no read state |

### D-W4-9 — `absenceRequests` / استئذان

| Option | Meaning |
|--------|---------|
| **A. Keep dormant and explicitly out of W4 (recommended)** | A later Phase 0 must decide approver, halaqa link, timing, and attendance effect |
| B. Include full request + approve/reject loop | Materially larger workflow and requires unresolved product rules |
| C. Expose submit-only UI | Creates a guaranteed dead end — reject |

### D-W4-10 — Wording

Recommended neutral Arabic:

| Event | Proposed copy |
|-------|---------------|
| New absence | Title: «تم تسجيل غياب» · Body: «تم تسجيل غياب {studentName} بتاريخ {date}» |
| Corrected to present | Title: «تم تحديث الحضور» · Body: «تم تحديث حالة {studentName} بتاريخ {date} إلى حاضر» |
| Corrected to late | Title: «تم تحديث الحضور» · Body: «تم تحديث حالة {studentName} بتاريخ {date} إلى متأخر» |

Avoid blame, disciplinary language, and claims that an excuse was accepted.

---

## 8. Proposed implementation slices (after approval)

### Pre-Slice — correctness foundation ✅ Pass

1. Introduce a thin `AcademyEvent` model + `AcademyEventSink` port (no concrete FCM/SMS; no UI).
2. Add a tested explicit absence-transition projector beside `AttendancePolicy` (never `isAbsentStatus`).
3. Define deterministic `eventId` from existing attendance document identity.
4. Add a chunked parent-recipient resolver on the parent data boundary.
5. Unit tests for transitions, event identity, recipient chunking / multi-parent / no-parent.

**Done.** Validation: `docs/W4_PRESLICE_PRODUCTION_VALIDATION.md`. No attendance↔notification coupling, no UI, no Category B. **Stop — await Slice 1 approval.**

### Slice 1 — end-to-end parent awareness workflow ✅ Pass

1. After attendance SSOT save, derive academy events and publish through `AcademyEventSink`.
2. Provide the W4 in-app notification sink (deterministic delivery ids; existing `notifications` schema).
3. Compose `NotificationsPage` + unread badge into `ParentHomePage`; parent nested route + watcher restart.
4. Keep weekly report unchanged as aggregate attendance truth.

**Done.** Validation: `docs/W4_SLICE1_PRODUCTION_VALIDATION.md`. Teacher saves/corrects a register; every linked parent can see the in-app projection of the attendance event. **Stop — await Slice 2 approval.**

### Slice 2 — production validation and workflow closure

- First absent save, identical re-save, absent→present, absent→late.
- Current and historical editable dates.
- No linked parent, one parent, multiple parents, multiple children.
- Attendance remains SSOT even if a future channel is added.
- Parent loading/empty/error/retry, unread/read behavior, logout/account switching.
- W1/W2/W3 regression suite, analyze, format, tests, docs, commit, push.

---

## 9. Explicitly out of W4

- ❌ Full استئذان submit/list/approve/reject workflow
- ❌ New `excused` attendance status
- ❌ Supervisor/admin absence dashboard
- ❌ Attendance history page
- ❌ Generic parent–teacher messaging / dispute redesign
- ❌ Parent acknowledgement beyond inbox read state
- ❌ OS push / FCM / SMS / Email / WhatsApp **delivery in W4** (ports reserved; channels later)
- ❌ Automatic attendance from Zoom/meeting duration
- ❌ Makeup, rescheduling, billing consequences, disciplinary escalation
- ❌ New session IDs or slot-bound attendance
- ❌ New Firestore collection
- ❌ Category B Platform Hardening (rules, deploy config, CI, release pipeline)

---

## 10. Risks and mitigations

| Risk | Category | Mitigation |
|------|----------|------------|
| Duplicate parent alerts on repeat save | Correctness | Transition comparison + deterministic ID |
| False alert remains after correction | Correctness | Update same signal and reset read state |
| Unknown/null status interpreted as absent | Architecture | Explicit status transition policy; tests |
| Parent lookup N+1 | Performance | Chunked `arrayContainsAny`, once per save |
| Signal writes exceed 500-op batch | Scale | Include every write/delete in preflight |
| Notification failure blocks core attendance | Product trade-off | D-W4-5 approval; no silent partial state |
| No linked parent | Product reality | Attendance succeeds; no fake recipient |
| Parent sees previous account's notifications | Stale singleton state | Clear/restart watcher on identity/audience change |
| User expects phone push | UX | Explicit in-app scope/copy; no push promise |
| Excuse API accidentally exposed | Product dead end | Keep it dormant and out of routes/UI |

---

## 11. Definition of Done

W4 is complete only if:

1. Attendance records remain the single source of truth; no `registerSubmitted` / notification-derived attendance state.
2. Only an explicit transition to `absent` creates a `StudentAbsentRecorded` event; late remains attended.
3. Re-saving unchanged absence does not emit a new event or spam delivery.
4. Absent→present/late emits `StudentAbsenceCorrected` for every linked parent channel recipient.
5. Attendance save does not depend on one concrete delivery implementation (`AcademyEventSink` port).
6. Current channel is in-app notifications only; weekly report still reads attendance directly.
7. No-parent and multi-parent cases are honest.
8. No new Firestore collection; any query/type/ID convention is documented and tested.
9. `absenceRequests` remains inaccessible unless a later full workflow is approved.
10. Platform Hardening remains separately tracked and does not enter W4 scope.
11. Loading/empty/error/retry and account-switch behavior are validated for the parent surface.
12. Relevant tests pass; `flutter analyze` is clean; format, validation docs, commit, and push occur per approved slice.

---

## 12. Approval gate

**Phase 0 direction approved** with workflow + multi-channel adjustments.

D-W4-1 … D-W4-10 remain as recommended **A** unless superseded later.

**Pre-Slice complete and validated.** Stop — await approval before Slice 1.
