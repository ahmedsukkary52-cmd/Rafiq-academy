# W1 — Daily Lesson & Homework Loop  
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** **W1 complete** (Pre-Slice + Slices 1–7).  
**File key / Figma:** Basma (Copy) — teacher class/evals + student homework/evaluations as UX reference only  
**Architecture:** Feature-first Clean Architecture + BLoC + Firestore SSOT (`assignments`)

### Permanent rule (during implementation)

If a previous slice or design assumption is found incorrect: **stop**, explain, update this design, then continue. Never build on a known flawed foundation.

---

## 1. Existing architecture

### 1.1 End-to-end map (current)

```text
TeacherClassDetail «تكليف» ──► TeacherBloc.SendAssignmentEvent
                                          │
                                          ▼
                               SendAssignmentUseCase
                                          │
                                          ▼
                               TeacherRepository.sendAssignment
                                          │
                                          ▼
                    TeacherRemoteDatasource.sendAssignment
                                          │
                    batch: assignments + notifications (per student)
                                          │
                    (seeds via AssignmentModel.defaultHomeworkFields — no fake media)
                                          │
          ┌───────────────────────────────┴───────────────────────────────┐
          ▼                                                               ▼
 StudentBloc watchLatestAssignment                          HomeworkBloc Load/Watch
 (Home «درس اليوم»)                                         (StudentHomeworkPage)
          │                                                               │
          └────────────── reads same assignment doc ──────────────────────┘
                                          │
                    ToggleTask / CompleteHomework (required: reading+listening)
                    Recitation deferred until AppCapabilities.audioUploadsEnabled
                                          │
                    (optional) SubmitRecitation → Storage + pending record
                                          │
          ┌───────────────────────────────┴───────────────────────────────┐
          ▼                                                               ▼
 TeacherEvaluationsPage ← review pending (update same doc)     Live «تقييم جديد»
          │
          ▼
 StudentEvaluationsPage ← reviewed only (+ Home last eval)
          │
          ▼
 ParentHomePage weekly report ← reviewed-only counts/notes
          │
          ▼
 NotificationsPage ← assign + review writers (audience=studentId)
```

### 1.2 Inventory by layer

| Layer | Piece | Role in W1 |
|-------|--------|------------|
| **Routes** | `/student/homework` | Student homework page |
| | `/student` (home) | «درس اليوم» from latest assignment |
| | `/student/evaluations` | Student sees reviewed results |
| | `/teacher/halaqa/:halaqaId` | Class detail — **no assign entry** |
| | `/teacher/halaqa/:halaqaId/evaluations` | List + create live eval; pending display only |
| | `/parent` | Weekly report (indirect visibility) |
| | `/student/notifications`, `/teacher/notifications` | Inbox read path |
| **UI pages** | `StudentHomeworkPage` | Tasks, complete, open recitation |
| | `StudentHomePage` | Assignment preview card |
| | `StudentEvaluationsPage` | Reviewed records only |
| | `StudentRecitationPage` | Local record + homework submit context |
| | `TeacherClassDetailPage` | Nav to attendance/evals/awards — **no تكليف** |
| | `TeacherEvaluationsPage` | Timeline + «تقييم جديد» sheet; pending label only |
| | `ParentHomePage` | Children + weekly report |
| | `NotificationsPage` | Mark read / mark all |
| **Blocs** | `TeacherBloc` | `SendAssignmentEvent`, `AddRecitationRecordEvent`, evals load |
| | `HomeworkBloc` | Load/Watch, ToggleTask, CompleteHomework, SubmitRecitation |
| | `StudentBloc` | Watch assignment, LoadRecitationRecords |
| | `ParentBloc` | GetWeeklyReport |
| | `NotificationsBloc` | Watch / mark read |
| **Events / state (teacher)** | `SendAssignmentEvent` | Params: halaqaId, ranges, dueDate, teacherId |
| | `assignmentSubmissionStatus` | idle/submitting/success/error — **unused by UI** |
| | `AddRecitationRecordEvent` | Creates **new** graded record |
| | `LoadHalaqaEvaluationsEvent` | Lists halaqa `recitationRecords` |
| **Use cases** | `SendAssignmentUseCase` | ✅ Exists |
| | `AddRecitationRecordUseCase` | ✅ Exists (create only) |
| | Homework get/watch/toggle/complete/submit | ✅ Exist |
| | Parent `GetWeeklyReportUseCase` | ✅ Exists |
| | **No** `UpdateRecitationReviewUseCase` | ❌ Missing |
| | **No** homework notification create use case | ❌ Missing |
| **Repos / datasources** | `TeacherRemoteDatasource.sendAssignment` | Batch one doc per `halaqa.studentIds` |
| | `TeacherRemoteDatasource.addRecitationRecord` | `.add()` only |
| | `HomeworkRemoteDatasourceImpl` | SSOT on `assignments` + submit to Storage/`recitationRecords` |
| | `StudentRemoteDatasource` | Latest assignment + evals query |
| | `ParentRemoteDatasourceImpl.getWeeklyReport` | Attendance + recitations week window |
| | `NotificationsRemoteDatasource` | Watch + mark read (**no create**) |
| | `AdminRemoteDatasource.broadcastNotification` | Pattern for create (audience/title/body/type/readBy) |
| **Models / entities** | `AssignmentEntity` / `AssignmentModel` | Lesson + homework fields on one doc |
| | `AssignmentTaskEntity` | kinds: reading, listening, recitation, quiz |
| | `HomeworkEntity` | Presentation mapping from assignment |
| | `RecitationRecordEntity` | `reviewStatus`, null grades until review, `assignmentId`/`taskId`/`audioUrl` |
| | `WeeklyReportEntity` | Aggregated parent view |
| | `NotificationEntity` | Inbox item |
| **Firestore** | `assignments` | SSOT lesson + homework |
| | `recitationRecords` | Live grades + pending student submits |
| | `halaqat` | `studentIds`, `teacherId` for batch assign |
| | `studentProfiles` | Points/coins on complete |
| | `users` | Names |
| | `parentProfiles` | `childrenIds` |
| | `attendanceRecords` | Parent weekly (adjacent) |
| | `notifications` | Inbox; writers sparse |
| **Storage** | `recitations/{studentId}/{assignmentId}/{taskId}_{ts}.m4a` | Coded; **Blaze off** |
| **Notifications** | `NotificationTypes.assignment` | Constant exists; **never written** by W1 |

### 1.3 How they currently interact (summary)

1. **Assign path is backend-complete, UI-orphaned.** `SendAssignmentEvent` → use case → batch `assignments` docs. No page dispatches it.
2. **Student consume path works** if assignment docs exist (Home watch + Homework).
3. **Submit recitation path is coded** but Storage-gated; writes `reviewStatus: pending` with null grades.
4. **Teacher review of pending is UI-incomplete and data-incomplete** — list shows pending; only **create new** graded records exists; no `update` of pending docs.
5. **Student result path is ready** — evaluations query **excludes** pending; once a record is reviewed, student can see it.
6. **Parent path is thin but real** — weekly report counts week recitations + last notes string; no dedicated homework/eval screens.
7. **Notifications** — student/teacher can read inbox; W1 never creates docs. Admin broadcast shows the intended schema.

---

## 2. Workflow audit

| Step | Actor | Status | Evidence |
|------|-------|--------|----------|
| Teacher opens class → assigns today’s lesson/homework | Teacher | ❌ Missing UI | `SendAssignment*` unused from pages; class detail has no تكليف CTA |
| Assignment docs created per student | System | ✅ Implemented | `sendAssignment` batch + `defaultHomeworkFields` |
| Student receives on Home + Homework | Student | ✅ Implemented | Watch/get latest `assignments` |
| Student toggles non-recitation tasks | Student | ✅ Implemented | `ToggleTaskEvent` |
| Student completes homework (points once) | Student | ✅ Implemented | `isSubmitted` / `completedAt` guard |
| Student submits recitation audio | Student | 🟡 Partial | Full code path; Storage disabled → not production-usable |
| Student sees “waiting for review” honesty | Student | 🟡 Partial | Homework copy mentions waiting; no reviewed result until teacher updates |
| Teacher sees pending submissions | Teacher | 🟡 Partial | Badge «بانتظار المراجعة»; no action |
| Teacher reviews / grades pending | Teacher | ❌ Missing | No update API/UI |
| Teacher live in-class evaluation | Teacher | ✅ Implemented | `AddRecitationRecord` + sheet |
| Student sees graded result | Student | ✅ Implemented *(blocked by missing review)* | Filters `!isPendingReview` |
| Parent sees result | Parent | 🟡 Partial | Weekly report aggregates recitations; not a clear “homework result”; may include pending notes |
| Notify student on new assignment | System | ❌ Missing | No writer; type constant exists |
| Notify student on review | System | ❌ Missing | Same |
| Notify parent on review | System | ❌ Missing | Product whether required |

---

## 3. Gap analysis

### G1 — Teacher assign UI  
| | |
|--|--|
| **Why missing** | Domain finished; presentation never wired |
| **Reuse** | `SendAssignmentEvent`, `TeacherBloc.assignmentSubmissionStatus`, `TeacherClassDetailPage`, Figma teacher class flows for UX only |
| **Minimal add** | Form/sheet: memorization range, review range, due date → dispatch existing event; loading/error/success/empty (no students) |
| **Category** | **Verified** (code + SSOT docs in `STUDENT_STATUS.md`) |

### G2 — Fake seed data in `defaultHomeworkFields`  
| | |
|--|--|
| **Why critical** | Assign today would write SoundHelix MP3 + dummy PDF + always-on «اختبار الفهم» task → **fake/misleading** (violates DoD) |
| **Reuse** | Same helper; strip or omit optional fields |
| **Minimal add** | Seed only real tasks teacher intends; **no** placeholder URLs; drop or gate quiz task |
| **Category** | **Verified** (code); quiz presence = **Product decision** (do not invent quiz content) |

### G3 — Update pending recitation (review)  
| | |
|--|--|
| **Why missing** | Only `.add()` for evaluations |
| **Reuse** | `RecitationRecordEntity` fields, `TeacherEvaluationsPage` pending card, grade enums, `AddRecitation` UI patterns |
| **Minimal add** | `updateRecitationReview` datasource/repo/use case/event; sheet on pending card: grade, behavior, notes → set `reviewStatus: reviewed`, set grades |
| **Category** | **Verified** (schema already has pending + null grades); grade scale **Verified** (`RecitationGrades` / entity enums) |

### G4 — Audio submit without Storage  
| | |
|--|--|
| **Why blocked** | Blaze not approved (`STUDENT_STATUS.md`) |
| **Reuse** | Existing submit path when Storage enabled; mushaf already shows honest “رفع التسجيل غير متاح حالياً” |
| **Minimal add for W1** | Honest disabled/empty for homework recitation upload; keep reading/listening/complete usable |
| **Category** | **Verified** infra decision; enabling Storage = **Product decision** |
| **Slice 2 discovery** | **Resolved by D8 Option A:** Recitation is **optional/deferred** while uploads are off — visible with honest copy, never blocks finish, never auto-completed, never creates pending without real audio. Flip `AppCapabilities.audioUploadsEnabled` when Storage is on so recitation becomes required again without redesigning W1. |

### G5 — Parent visibility  
| | |
|--|--|
| **Why thin** | Sprint-1 parent home only |
| **Reuse** | `getWeeklyReport` + parent home report card |
| **Minimal add** | Prefer last **reviewed** teacher note / count only reviewed records in week (or show clear “pending” exclusion). Avoid new parent module in W1 |
| **Category** | Filtering pending = **Inference** (student already excludes pending); dedicated parent eval screen = **out of W1** unless approved |

### G6 — Notifications on assign/review  
| | |
|--|--|
| **Why missing** | Inbox is read-only; create only in admin broadcast |
| **Reuse** | Admin create schema (`audience`, `title`, `body`, `type`, `readBy`, `hasAudioAlert`, `createdAt`); `NotificationTypes.assignment`; student/teacher inbox UI |
| **Minimal add** | Small writer helper/use case; on assign → `audience: studentId`; on review → `audience: studentId` (parent notify = **Product decision**) |
| **Category** | Schema **Verified**; parent notify **Product decision** |

### G7 — Homework task kinds policy  
| | |
|--|--|
| **Why** | Default seed always creates reading/listening/recitation/quiz |
| **Reuse** | Task `kind` already drives student UI |
| **Minimal add** | Decide default task set for production assign (recommend: reading + listening + optional recitation; **no quiz content**) |
| **Category** | **Product decision** |

---

## 4. Firestore impact

### Collections touched (existing only — no new collections)

| Collection | Ops | Justification |
|------------|-----|----------------|
| `halaqat` | R | Student list for batch assign |
| `assignments` | C (batch), R, U | SSOT lesson/homework |
| `recitationRecords` | C (student submit / live eval), **U (new: review)** | Close pending |
| `studentProfiles` | U | Points on complete (existing) |
| `users` | R | Names |
| `parentProfiles` | R | Children ids |
| `attendanceRecords` | R | Parent weekly (existing) |
| `notifications` | **C (new writers)** | Assign/review events |

### Documents / fields (no new fields required for MVP)

**`assignments` (existing)**  
`studentId`, `halaqaId`, `assignedBy`, `newMemorizationRange`, `reviewRange`, `dueDate`, `title`, `tasks[]`, `isSubmitted`, `completedAt`, optional `teacherVoiceNote`, `attachments`  

**Change:** stop writing fake `teacherVoiceNote` / `attachments` URLs unless real.

**`recitationRecords` (existing)**  
`reviewStatus`, `grade`, `behaviorGrade`, `notes`, `assignmentId`, `taskId`, `audioUrl`, `storagePath`, `submittedAt`, …  

**Change:** update path sets grades + `reviewStatus: 'reviewed'` (+ optional `reviewedAt` — **only if approved**; otherwise reuse `notes`/existing fields). Prefer **no new field** unless needed → **Product decision** for `reviewedAt`.

**`notifications` create payload (existing admin pattern)**  
`audience` (uid), `title`, `body`, `type: assignment` (or `general`), `readBy: []`, `hasAudioAlert: false`, `createdAt`

### Indexes

| Query | Likely need |
|-------|-------------|
| `assignments` where `studentId` + order `dueDate` | May already exist in console |
| `recitationRecords` where `halaqaId` | Equality only + client sort — OK |
| `recitationRecords` where `studentId` + orderBy `date` | Composite — used today |
| `notifications` where `audience` in […] + orderBy `createdAt` | Used today |

**No new index designed unless a new query is introduced.** Review update is `doc.update` by id — no index.

### Storage paths

`recitations/{studentId}/{assignmentId}/{taskId}_{timestamp}.m4a` — **unchanged**; unused until Blaze.

### Notification events (proposed)

| Event | When | audience | type |
|-------|------|----------|------|
| Assignment created | After successful batch (per student) | `studentId` | `assignment` |
| Recitation reviewed | After successful review update | `studentId` | `assignment` or `general` |
| Parent notified | — | — | **Deferred — Product decision** |

---

## 5. Implementation plan (execution order)

**Pre-Slice is a prerequisite**, not a workflow slice. It must land before Slice 1 so assign never creates fake product data.

| Step | Name | Immediately usable? |
|------|------|---------------------|
| **Pre-Slice** | Remove all fake/default seeded homework content | Yes — safer seeds; no fake media/quiz |
| **Slice 1** | Teacher assigns homework | Yes — students receive via existing Home/Homework |
| **Slice 2** | Student receives and completes homework | Audit/harden existing path; honest non-audio UX |
| **Slice 3** | Teacher reviews pending recitations | Yes — closes pending → student can see grades |
| **Slice 4** | Student sees reviewed results | Confirm/harden evaluations path (already filters pending) |
| **Slice 5** | Parent visibility (weekly report scope only) | Reviewed activity honesty on existing home |
| **Slice 6** | Notification writers | Inbox already works |
| **Slice 7** | Workflow consistency audit | DoD / Rule 3 |

Each step: compile → `flutter analyze` → `dart format` → commit → push → releasable.

### Explicitly **out of W1** (unless re-approved)

- Firebase Storage / Blaze enablement  
- Memorization plans / surah locks  
- Parent dedicated evaluations/attendance/schedule screens  
- FCM push  
- Quiz/game educational content  
- New Firestore collections  
- Changing assignment versioning rules (D7 is reuse of current behavior)

### Optional later branch of **same** journey (not blocking W1 DoD)

- **W1-Storage:** Enable upload when Blaze approved — completes audio branch only.

---

## 6. Risks

| Type | Risk | Mitigation |
|------|------|------------|
| **Technical** | Batch assign N students fails partially | Keep single `batch.commit`; surface error; no silent partial UI |
| **Technical** | Composite indexes missing in some envs | Stick to existing queries; document console indexes |
| **Technical** | Race: student completes while teacher reviews | Transaction on review; student evals already ignore pending |
| **Product** | Default task set (quiz?) | Slice 0 + explicit approval |
| **Product** | Fake voice/PDF historically seeded | Slice 0 stops new fakes; optional cleanup script later |
| **Product** | Parent “result” expectations vs weekly summary | Slice 3 honesty; no fake dedicated screen |
| **Migration** | Old assignment docs with dummy URLs | Leave historical; UI already handles missing/broken audio with errors |
| **Performance** | Notify N students = N writes | Acceptable for halaqa size; batch writes |
| **Security** | No `firestore.rules` in repo | Do not widen client write surface; review update must be teacher-authenticated only (existing Auth pattern); flag rules gap as platform risk |
| **Security** | Student forging reviewed grades | Only teacher update path sets grades; keep student submit grades null |
| **Architecture** | Parallel “homework assign” feature | Forbidden — reuse `SendAssignment*` |

---

## 7. Success criteria / test plan

### Teacher scenario

1. Sign in as teacher with halaqa that has ≥1 linked student.  
2. Open class detail → send assignment (ranges + due date).  
3. **Expect Firestore:** one new `assignments/{id}` per studentId with real fields, **no** SoundHelix/dummy PDF.  
4. Open evaluations → if pending exists → review with grades.  
5. **Expect Firestore:** same `recitationRecords/{id}` updated: `reviewStatus: reviewed`, non-null grades.  
6. **Expect:** optional `notifications` doc with `audience: <studentId>`.

### Student scenario

1. Sign in as assigned student.  
2. Home shows درس اليوم; Homework lists tasks.  
3. Complete reading/listening; finish homework.  
4. **Expect:** `tasks` updates; on complete `isSubmitted` + points on `studentProfiles` (existing rules).  
5. After teacher review: Evaluations shows graded entry (not while pending).  
6. Notification inbox shows assign/review items if Slice 4 shipped.

### Parent scenario

1. Sign in as parent linked via `parentProfiles.childrenIds`.  
2. Open weekly report for that child after a reviewed recitation in-week.  
3. **Expect:** report reflects reviewed activity (not treating pending as final grade).  
4. Firestore: **read-only** for parent on these collections (no new parent writes in W1).

### Regression checks

- Live «تقييم جديد» still creates graded records.  
- Chat / attendance unrelated paths unchanged.  
- `flutter analyze` clean; `dart format`; each slice committed + pushed.

### Definition of Done (W1)

Per standing rules: all actors can complete their part · no fake seeds · architecture reused · loading/empty/error/retry/refresh/permissions · analyze + format + commit + push · no duplicate assign/review stacks · maintainable.  
**Audio upload** may remain infra-blocked; W1 DoD requires **honest non-audio loop** + review path ready for when Storage returns.

---

## Decision log

| # | Decision | Category | Resolution |
|---|----------|----------|------------|
| D1 | Remove fake voice/PDF from new assigns / seeds | Verified (DoD) | **Approved** |
| D2 | Default tasks: reading + listening + recitation; **no quiz** | Product decision | **Approved** |
| D3 | Parent push notification on review | Product decision | **Defer** (student notify only) |
| D4 | Add `reviewedAt` field | Product decision | **No** |
| D5 | W1 complete without Storage | Verified | **Yes** |
| D6 | Parent visibility via weekly report honesty only | Inference | **Yes** |
| D7 | Assignment versioning | **Verified** (reuse current code) | See below |
| D8 | Homework finish vs recitation while Storage off | **Product decision** | **Approved — Option A + deferred** |

### D7 — Assignment versioning (Verified — reuse)

Current implementation already defines behavior. **Do not invent a new model.**

| Question | Answer in code today |
|----------|----------------------|
| What is “Today’s Assignment”? | Not calendar-day filtered. It is the student’s assignment with the **latest `dueDate`** (`orderBy dueDate desc`, `limit 1`). Used by Home and Homework. |
| Can multiple assignments exist for the same halaqa? | **Yes.** `sendAssignment` creates a **new** doc per student (`.doc()` + batch). Old docs remain. |
| Replace vs create? | **Always create another.** Does not update/delete prior assignments. |
| What does Student Home show if multiple exist? | Only the latest-by-`dueDate` document. |

**Implication for Slice 1:** Teacher assign UI sets `dueDate` (typically end of selected day). New assigns become “current” when their `dueDate` is newest. Tie-breaking among equal `dueDate` values is Firestore-undefined — accept existing behavior; do not add versioning fields unless a later product decision requires it.

### D8 — Homework completion without Storage (Approved — Option A + refinement)

**Resolution:** Recitation is **optional / deferred** while Firebase Storage uploads are disabled — not a failed required task.

| Rule | Behavior |
|------|----------|
| Required to finish today’s homework | **Reading + listening** only (`AppCapabilities.audioUploadsEnabled == false`) |
| Recitation task | Stays visible; marked deferred with honest copy: uploads unavailable until enabled |
| Blocks finish? | **No** |
| Auto-complete recitation? | **Never** |
| Pending `recitationRecords` without real audio? | **Never** |
| Fake uploaded audio? | **Never** |
| When Storage enabled later | Set `AppCapabilities.audioUploadsEnabled = true` → recitation becomes **required** for finish on the same workflow (no W1 redesign) |

**Copy (student-facing):** Arabic UI equivalent of: “Audio submission will be available when uploads are enabled.”

**Implication:** Slice 3 review UI still ships (live «تقييم جديد» + pending cards for real Storage submits). Homework pending volume stays near zero until Blaze.

---

## Approval gate

**W1 implementation complete** through Slice 7.  
If a later change discovers a flawed assumption: stop, update this doc, then continue.

---

## Slice 7 — Consistency audit (2026-07-25)

| Check | Teacher assign | Student homework | Teacher review | Student evals | Parent week | Notifications |
|-------|----------------|------------------|----------------|---------------|-------------|---------------|
| Loading | Sheet button + submission status | Page spinner | List + refresh bar | Page spinner | Report section | Inbox stream |
| Empty | Guard: no students | Empty + pull refresh | Empty + pull refresh | Honest empty (pending excluded) | Empty copy honesty | Existing inbox |
| Error + retry | Snackbar + reset | AppErrorWidget retry | AppErrorWidget retry | AppErrorWidget retry | Section retry | Stream errors surfaced |
| Refresh | N/A (one-shot) | Pull-to-refresh | Pull-to-refresh | Pull-to-refresh | Existing reload | Watch stream |
| Permissions | Auth uid as assignedBy | Auth uid queries | Teacher Auth for live add; review by doc id | Auth uid | Parent childrenIds | audience=uid |
| Nav | Class detail → تكليف | Home → homework / evals | Pending card → review sheet | Home last eval → evals | Home report only | Role inboxes |
| Honesty | No fake seeds | Recitation deferred (D8) | Same-doc review | Reviewed only | Reviewed only | Real events only |

**Known platform gaps (not invented in W1):** no `firestore.rules` in repo; Storage/Blaze off (`AppCapabilities.audioUploadsEnabled`); FCM push not in scope; parent notify deferred (D3).

**Ship commits:** Pre-Slice `8081b27` → S1 `a95dba8` → S2 `b5a2fc3` → S3 `aefbfef` → S4 `e06c73c` → S5 `7a6dc63` → S6 `90522ff` → S7 (this).
