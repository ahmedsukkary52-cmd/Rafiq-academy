# Post-W2 Product & Architecture Audit

**Date:** 2026-07-25  
**Branch:** `feature/teacher-module-production-cleanup`  
**Scope:** W1 (Daily Lesson & Homework) + W2 (Attendance) as one academy product  
**Method:** Read-only code investigation. **No code changes. No commits.**  
**Predecessor reports:** `docs/W1_PRODUCTION_VALIDATION.md`, `docs/W2_PRODUCTION_VALIDATION.md`

### Classification legend

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed in current code / config |
| **Inference** | Reasonable product/tech conclusion from Verified facts |
| **Accepted** | Explicitly deferred or accepted in W1/W2 decisions |

---

## 0. Executive verdict

W1 and W2 **do form one coherent academy core**, not two unrelated apps:

- Shared roster (`halaqat.studentIds` + `users`)
- Shared Arabic UI language and `AppErrorWidget` / snackbar patterns
- Shared parent weekly surface that already combines **attendance + reviewed recitations**
- Shared teacher entry from class detail (تكليف + حضور)
- Attendance percentages now share one `AttendancePolicy` (W2 D1)

They are still **two independently operated rituals** rather than one **daily session operations loop**. The teacher can assign homework and mark attendance, but the product does not yet say: *“Today is a session for this halaqa → complete register → teach → assign → parents see the day.”*

**Do not start W3 until this audit is reviewed and W3 scope is approved.**

---

## 1. Cross-workflow consistency

Compare Homework (W1) vs Attendance (W2) across product behaviors.

### 1.1 Consistency matrix

| Concern | Homework (W1) | Attendance (W2) | Consistent? | Finding |
|---------|---------------|-----------------|-------------|---------|
| **Loading** | SectionStatus + shell/stream patterns | SectionStatus + `_shellReady` shell | Mostly | **Verified** — both honest; attendance has stronger stale-date protection |
| **Empty** | Honest empty homework / evals | Honest empty roster / week / progress | Yes | **Verified** |
| **Error** | `AppErrorWidget` + snackbars on mutations | Same | Yes | **Verified** |
| **Retry** | Error retry + pull-to-refresh on student homework/home | Error retry only (no pull-to-refresh on attendance / parent / progress) | **No** | **Verified** inconsistency |
| **Refresh** | Student homework & home: `RefreshIndicator` | Teacher attendance: change date / leave-return; Parent & progress: retry button only | **No** | **Verified** — refresh UX uneven |
| **Permissions (client)** | Auth check on assign/review sheets | Auth check on save | Partial | **Verified** client auth; **server ownership unverified** (no rules in repo) |
| **Navigation** | Class detail → تكليف sheet; evals → review | Class detail → «فتح سجل الحضور» route | Partial | **Verified** — assign is in-place sheet; attendance is full page (UX asymmetry, not a bug) |
| **Wording** | تكليف / واجباتي / بانتظار المراجعة | حضور / تأخر / غياب + late-included captions | Mostly | **Verified** Arabic copy is clear; terminology differs by domain (expected) |
| **Localization** | Hardcoded Arabic strings | Hardcoded Arabic strings | Yes | **Verified** — no ARB/`AppLocalizations`; both same approach |
| **Analytics** | Recitation grades feed teacher analytics | Attendance % uses `AttendancePolicy` | Partial | **Verified** — analytics does **not** filter `reviewStatus == pending` for performance distribution (unlike parent/student honesty) |
| **Date handling** | Assignment `dueDate` end-of-day; “current” = latest dueDate | Calendar day midnight via `AttendancePolicy.dayStart` | **No shared policy** | **Verified** — two date models; week definitions also diverge (below) |
| **Teacher visibility** | Assign + review pending | Day register + analytics % | Yes (by role) | **Verified** |
| **Student visibility** | Home + Homework + reviewed evals | Progress report only (no dedicated attendance history) | Intentional W2 scope | **Verified** — student never queries attendance outside progress report |
| **Parent visibility** | Weekly reviewed recitations + notes | Weekly attended/total/% | Yes (same card) | **Verified** — strongest product glue between W1 and W2 |
| **Notifications** | Assign + review writers | Deferred (D2) | **By design** | **Accepted** — parents get homework signals but not absence signals |
| **Idempotent writes** | Assign always creates new auto-id docs | Deterministic day IDs + batch | **No** | **Verified** — attendance harder/safer; homework re-assign creates duplicates by design (W1 D7) |
| **Batch size guard** | Assign: no 500-op preflight | Attendance: preflight refuse | **No** | **Verified** post-W2 inconsistency |

### 1.2 Inconsistencies to track (every item)

1. **Refresh model** — Homework surfaces refresh; attendance/parent weekly/progress mostly do not.  
2. **Week definition** — Parent weekly starts **Saturday** (Egypt school week); student progress chart week starts **Sunday**; teacher analytics “weekly” = **rolling last 7 calendar days**. Same word «أسبوعي», three meanings.  
3. **Date/day policy** — Attendance uses shared `AttendancePolicy.dayStart`; homework/progress still use local `DateTime(y,m,d)` copies.  
4. **Date display formats** — Mix of `formatDateDmy`, `formatDateYmd`, and private `_formatDate` wrappers; attendance page uses custom weekday Arabic list.  
5. **Write idempotency philosophy** — Homework: always new docs; Attendance: upsert by deterministic id. Correct per domain, but undocumented as a product rule set.  
6. **Mutation batch safety** — Attendance guards Firestore 500 limit; assignment (`2 ops × N students`) does not.  
7. **Roster `whereIn` scale** — Shared teacher roster load used by attendance (and assignment context) is unchunked.  
8. **Pending honesty in analytics** — Parent/student filter pending recitations; teacher analytics grade distribution does not.  
9. **Notification symmetry** — Homework notifies students; absence does not notify parents (Accepted D2, but product asymmetry).  
10. **Navigation density** — Homework assign is a sheet on class detail; attendance is a separate route with a link-only tab (class “الحضور” tab is not the register itself).  
11. **Student attendance depth** — Student sees monthly % in progress report, not a day-by-day register (Accepted W2 scope; product gap for “why was I marked absent?”).  
12. **Localization infrastructure** — No shared i18n layer; every string is inline Arabic (consistent today, fragile for future languages).

### 1.3 What already coheres well

- Single parent weekly report combining W1 + W2 metrics.  
- Shared `SectionStatus` / `SubmissionStatus` / `AppErrorWidget` / snackbars.  
- Shared capability flag pattern (`AppCapabilities.audioUploadsEnabled`) for infra-gated honesty.  
- Teacher class detail as the operational hub for both rituals.  
- No fake attendance or fake homework seeds on the happy path after W1 Pre-Slice / W2 Pre-Slice.

---

## 2. Architecture audit

**Rule for this section:** report only. Do not refactor yet.

### 2.1 Duplicated business logic

| Area | Locations | Risk | Shared candidate |
|------|-----------|------|------------------|
| Legacy assignment `tasks` seed on read | `student_remote_datasource_impl.dart`, `homework_remote_datasource_impl.dart` | Dual migration; student needs write on teacher doc | One migration/use-case or admin script; reads stay read-only |
| Calendar day normalize | `AttendancePolicy.dayStart` vs local `DateTime(y,m,d)` in progress mapper, attendance page `_normalize`, parent week math | Drift / timezone bugs | `AcademyCalendar` / date policy |
| Week start | Parent Saturday week vs progress Sunday week vs analytics rolling 7 | Confusing «أسبوعي» | Same calendar policy with explicit week-start enum |
| Attendance aggregates | Centralized in `AttendancePolicy` (good) | Low after W2 | Keep as SSOT |
| Reviewed-recitation filter | Parent weekly, progress mapper, (missing in analytics) | Parent/teacher disagreement | Shared `RecitationPolicy.isParentVisible` |

### 2.2 Duplicated Firestore queries

| Query pattern | Callers | Note |
|---------------|---------|------|
| `attendanceRecords` by `studentId` + date range | Parent weekly, progress report | Same shape; could share a read adapter |
| `attendanceRecords` by `halaqaId` + date range | Teacher day load/save, analytics | Attendance already dedupes; analytics now uses policy |
| `recitationRecords` by `studentId` + date range | Parent weekly, progress | Parallel to attendance |
| `recitationRecords` by `halaqaId` + date range | Analytics | **No composite index in repo** for this pair (see Firestore) |
| Roster via `halaqat` + `users whereIn uid` | Teacher students load | Unchunked; shared by W1/W2 |

### 2.3 Duplicated date formatting / helpers

| Helper | Location |
|--------|----------|
| `formatDateDmy` / `formatDateYmd` / time helpers | `lib/shared/utils/time_format.dart` — **good shared base** |
| Private `_formatDate` wrappers | Parent home, achievements, last-evaluation widget, posts, PDF |
| Weekday Arabic labels | Attendance page, analytics chart (`أح…سب`), progress chart labels |

**Recommendation:** expand `time_format.dart` (or `academy_calendar.dart`) rather than new ad-hoc lists.

### 2.4 Duplicated widgets / UI patterns

| Pattern | Note |
|---------|------|
| Metric tiles / summary rows | Parent weekly `_MetricTile`, progress `_SummaryRow`, attendance `_AttendanceSummaryRow` — similar jobs, different widgets |
| Empty / error | Shared `AppErrorWidget` reused well |
| Bottom sheets for teacher mutations | Assign + review sheets; attendance uses full page |

Not urgent to unify visually; unify **state lifecycle** (refresh/reset) first.

### 2.5 Policy classes

| Policy | Status |
|--------|--------|
| `AttendancePolicy` | **Exists and used** — model to copy |
| Homework completion / deferred audio | Embedded in entities + `AppCapabilities` — OK |
| Recitation visibility (pending vs reviewed) | **No shared policy class** — duplicated filters |
| Academy calendar / week | **Missing** |

### 2.6 Shared infrastructure recommendations (do not build yet)

1. **`AcademyCalendar`** — dayStart, weekStart (Saturday default for Rafiq), rolling windows, “today”.  
2. **`RecitationVisibilityPolicy`** — pending excluded from parent/student/analytics unless graded live.  
3. **Roster reader** — chunked `whereIn`, ordered by `studentIds`, membership checks.  
4. **Batch write helper** — estimate ops, refuse >500 with Arabic message (already on attendance; missing on assign).  
5. **Legacy assignment migration** — stop dual read-time mutators.  
6. **Auth lifecycle reset** — clear singleton blocs on logout.  
7. **Versioned Firestore rules + deploy path** — platform, not feature work.

---

## 3. Firestore audit (W1 + W2 collections)

### 3.1 Collections touched

| Collection | W1 | W2 | Role |
|------------|----|----|------|
| `assignments` | R/W SSOT | — | Homework |
| `recitationRecords` | R/W (submit/review/live eval) | R (parent/progress/analytics) | Learning evidence |
| `notifications` | C on assign/review | — (D2 deferred) | Student inbox |
| `attendanceRecords` | — | R/W SSOT | Register |
| `halaqat` | R roster/schedule slots | R roster | Class |
| `users` | R names | R names | Identity |
| `parentProfiles` | R children | R children | Parent link |
| `absenceRequests` | — | Orphan write API only | **Not in W2 product surface** |
| `studentProfiles` | R/W progress overlay | — | Accuracy % etc. |

**No new collections required** for coherence fixes or the suggested W3 direction (prefer `halaqat.schedule` + derived register completeness).

### 3.2 Indexes (`firestore.indexes.json`)

| Index | Used by | Status |
|-------|---------|--------|
| `assignments`: studentId + dueDate DESC | Student current homework | Present |
| `recitationRecords`: studentId + date ASC/DESC | Parent/progress/evals | Present |
| `attendanceRecords`: studentId + date ASC | Parent/progress | Present |
| `attendanceRecords`: halaqaId + date ASC | Teacher day / analytics | Present |
| `attendanceRecords`: halaqaId + studentId + date ASC | Legacy upsert shape | Present (less critical after D8) |
| `attendanceRecords`: halaqaId + status + date ASC | Was at-risk absent-only query | Present; at-risk now loads all statuses then dedupes |
| `notifications`: audience + createdAt DESC | Inbox | Present |
| `recitationRecords`: **halaqaId + date** | Teacher analytics | **Missing in repo** — **Verified** gap |

**Deploy risk:** `firebase.json` has **no Firestore rules/indexes deploy config** — only Flutter/Firebase app ids. Indexes in git ≠ indexes in project (**Accepted** repeatedly in W1/W2; still P0 for production).

### 3.3 Deterministic IDs

| Doc type | ID strategy | Idempotency |
|----------|-------------|-------------|
| `attendanceRecords` | `{halaqaId}_{studentId}_{yyyyMMdd}` | Strong — W2 D8 |
| `assignments` | Auto-id `.doc()` | Weak by design — re-assign = new docs (W1 D7) |
| `notifications` | Auto-id | Re-assign creates new notifs (Accepted) |
| `recitationRecords` | Auto-id on student submit / live eval; update same id on review | Review idempotent via transaction; submit retry can orphan Storage when uploads enabled (**Inference**) |

### 3.4 Write patterns & efficiency

| Flow | Pattern | Assessment |
|------|---------|------------|
| Attendance day save | Read day → batch set + delete legacy | Strong; atomic; preflight >500 |
| Assignment send | Batch: assignment + notification per student | Atomic per batch; **no** >500 preflight; fails entirely if oversize |
| Recitation review | Transaction update | Strong |
| Homework complete / task toggle | Transaction on assignment doc | Strong |
| Legacy tasks seed | Merge write during **read/watch** | Anti-pattern; duplicates logic |

### 3.5 Document ownership (application vs platform)

**Verified:** client datasources trust caller `teacherId` / `studentId` / route `halaqaId`.  
**Verified:** no `firestore.rules` in repository.  

Required production guarantees (must be enforced in console rules or callables):

- Teacher may write attendance/assignments/reviews only for `halaqat.teacherId == auth.uid`.  
- Student may mutate only own assignment tasks / own pending recitation submit.  
- Parent may read weekly aggregates only for `parentProfiles.childrenIds`.  
- Clients must not forge `recordedBy` / grades / `reviewStatus` transitions illegally.

### 3.6 Schema reuse opportunities

- Keep attendance calendar-day keyed (D7) — do **not** invent `sessionId` until product decides slot binding.  
- Reuse `halaqat.schedule` (already powers student schedule feature) for “is today a session day?” without a new collection.  
- Reuse `notifications` schema for future absence alerts (D2) — no new collection.  
- Keep `absenceRequests` dormant until a full approve loop exists — do not partially enable.

---

## 4. Product audit (real academy lens)

### 4.1 What the academy can do today

A teacher can:

1. Open a halaqa.  
2. Send a daily assignment to all students.  
3. Mark present / late / absent for a calendar day.  
4. Review pending student homework submissions (when audio path eventually on).  
5. See analytics trends.

A student can:

1. See current homework and complete reading/listening (recitation deferred by capability).  
2. See reviewed evaluations.  
3. See a 30-day attendance summary on the progress report.  
4. See a weekly schedule derived from `halaqat.schedule`.

A parent can:

1. See one weekly card: attendance % + reviewed activity + teacher notes.

### 4.2 Biggest missing workflow for *daily* operation

**Session operations / register completion.**

Homework and attendance exist as **tools**, but the academy day is still not an **operated session**:

- Schedule slots exist for display, yet attendance is unbound to “today’s meeting” (W2 D7 Accepted).  
- There is no teacher “today’s agenda”: which halaqat meet, which registers are unmarked, which need an assignment.  
- Parents are not alerted when a child is absent (D2 Accepted).  
- استئذان exists as orphan API only (D3 Accepted).

Without session glue, quality of daily operation depends on teacher memory and habit — the product does not enforce or guide the ritual.

### 4.3 Remaining workflows ranked by product value

| Rank | Workflow | Why it matters now | Unlocks academy? | Notes |
|------|----------|--------------------|------------------|-------|
| **1** | **Session operations** (schedule-aware day agenda + unmarked register + optional assign prompt) | Makes W1+W2 a daily habit, not two screens | **Yes — highest** | Reuse `halaqat.schedule` + `attendanceRecords`; no new collection required for v1 |
| **2** | **Absence awareness** (parent notify on absent + optional استئذان approve) | Completes social side of attendance | Yes for trust | Was D2/D3; needs approver role clarity |
| **3** | **Teacher ↔ parent pastoral messaging** | Real academies resolve absences/homework via chat | Yes for retention | Chat feature exists — audit completeness before rebuilding |
| **4** | **Learning plan / memorization continuum** | Turns isolated تكليف into a Qur’an progression | Yes for pedagogy | Bigger design; after daily ops stable |
| **5** | **Fees / payments UI completion** | Business survival | Yes for business, not daily teaching | Backend pieces exist; needs product + reconciliation decisions |
| **6** | **Full audio recitation path** | Completes talaqqi homework | Yes for traditional model | Blocked on Storage/Blaze (`AppCapabilities`) — infra, not a new workflow invention |
| **7** | **Supervisor unmarked-register & exceptions** | Multi-teacher ops | Only after #1 | W2 D4 deferred correctly |
| **8** | Admin dashboards | Oversight vanity | Rarely | Do **not** prioritize |
| **9** | Gamification / badges expansion | Engagement | No for core ops | Do **not** prioritize |

### 4.4 Explicit non-goals for next workflow

- New parallel attendance or homework modules from Figma.  
- Admin BI dashboards.  
- Gamification as “W3”.  
- New Firestore collections without Phase 0 approval.

---

## 5. Technical debt audit

Only real, justified debt.

### 5.1 P0 — release / safety blockers

| ID | Debt | Why P0 | Evidence |
|----|------|--------|----------|
| P0-1 | Firestore security rules not versioned / not deploy-configured | Any client with a valid auth session can be over-trusted | No `firestore.rules`; `firebase.json` has no Firestore block |
| P0-2 | Indexes must be deployed to `rafiq-academy` | W1/W2 queries fail or scan without composites | `firestore.indexes.json` present; deploy path absent |

### 5.2 P1 — reliability / scale / honesty

| ID | Debt | Why P1 | Evidence |
|----|------|--------|----------|
| P1-1 | Assignment batch lacks 500-op preflight | Halaqa >~250 students: assign+notify fails entirely | `sendAssignment` batch loop |
| P1-2 | Roster `whereIn` unchunked | Firestore `whereIn` operand limit breaks large halaqat for W1+W2 | `getHalaqaStudents` |
| P1-3 | Dual read-time assignment task seeding | Migration-as-read; requires student write; duplicated | Student + homework datasources |
| P1-4 | Missing `recitationRecords (halaqaId, date)` index in repo | Teacher analytics may fail at runtime | Analytics query vs `firestore.indexes.json` |
| P1-5 | Singleton blocs not cleared on logout | Cross-user flash / stale data risk | `@singleton` Teacher/Student/Parent/Notifications |
| P1-6 | Analytics includes pending recitations in grade mix | Breaks W1 honesty symmetry | No `reviewStatus` filter in analytics |
| P1-7 | Three conflicting “week” definitions | Product confusion as more weekly features land | Parent Sat / Progress Sun / Analytics rolling 7 |

### 5.3 P2 — maintainability / polish

| ID | Debt | Why P2 | Evidence |
|----|------|--------|----------|
| P2-1 | No shared `AcademyCalendar` | Date drift tax | Multiple dayStart/weekStart copies |
| P2-2 | Uneven refresh UX | DoD polish | Homework refresh vs attendance/parent/progress |
| P2-3 | Attendance class tab is link-only | Extra navigation hop | Teacher class detail |
| P2-4 | Orphan `absenceRequests` stack | Dead API invites accidental UI | Use case + event, no product surface |
| P2-5 | Hardcoded Arabic only | Future i18n cost | No localization framework |
| P2-6 | Little/no automated tests for W1/W2 flows | Regression risk | Test gap noted in W2 validation |
| P2-7 | Homework equal-`dueDate` ordering nondeterministic | Accepted W1 D7 | Auto-id order |
| P2-8 | Storage orphan risk when audio uploads enabled | Future W1 completion | Submit auto-id + Storage (**Inference**) |

---

## 6. Recommendations (before any W3 code)

### 6.1 Product

1. Treat W1+W2 as **done application workflows**, but acknowledge the academy still lacks a **daily session operating system**.  
2. Approve a narrow W3 only after agreeing what “today’s session” means without violating W2 D7 (calendar day) — schedule can **prompt**, not necessarily **bind** attendance docs.  
3. Keep D2/D3 deferred unless W3 explicitly includes parent absence communication.  
4. Do not open استئذان UI until an approver path is in the same workflow.

### 6.2 Platform (parallel to W3, not a feature slice)

1. Add and deploy `firestore.rules` with ownership checks.  
2. Wire Firestore indexes deploy; add missing `recitationRecords` halaqaId+date composite.  
3. Confirm indexes live in Firebase console for `rafiq-academy`.

### 6.3 Engineering (small, after approval — not this audit)

1. Extract `AcademyCalendar` + align week copy.  
2. Chunk roster queries; add assign batch preflight (parity with attendance).  
3. Remove duplicated assignment seed-on-read.  
4. Filter pending in analytics.  
5. Reset singleton blocs on logout.

---

## 7. Suggested W3 (for approval — do not start yet)

### Name

**W3 — Session Operations Loop**  
*(Teacher day agenda → register completion awareness → optional homework prompt → parent weekly remains the truth surface)*

### Goal (workflow, not screens)

Make the academy’s **daily teaching day** operable:

1. Teacher sees which of their halaqat are scheduled **today** (from existing `halaqat.schedule`).  
2. Teacher sees which of those still lack a complete attendance register for today.  
3. One tap into existing attendance page / assign sheet (reuse W1/W2).  
4. Optionally: end-of-day honesty that a session was “operated”.  

### Why this beats alternatives now

| Candidate | Why not W3 yet |
|-----------|----------------|
| Absence notifications / استئذان | Valuable, but depends on reliable daily marking first |
| Payments | Business-critical, not daily teaching ritual |
| Learning plan engine | Needs stable daily ops + clearer pedagogy decisions |
| Supervisor dashboard | Premature without register-completion signal |
| Admin / gamification | Does not unlock daily academy operation |

### Constraints (carry forward)

- Figma = UI reference only.  
- No new collections unless Phase 0 proves impossible to reuse `halaqat` + `attendanceRecords` + `assignments`.  
- Prefer prompts/derived completeness over new `sessionId` fields unless product reopens W2 D7.  
- Same slice discipline: Phase 0 → decisions → analyze/format/commit/push → production validation.  
- Fix P0 platform gaps in parallel or as Pre-Slice.

### Out of suggested W3

- Full استئذان FSM (unless explicitly expanded).  
- Supervisor module.  
- New attendance statuses.  
- Gamification.  
- Admin dashboards.

---

## 8. Audit conclusion

| Question | Answer |
|----------|--------|
| Are W1 and W2 one product? | **Yes at data/parent level; partially at daily-ops level.** |
| Biggest coherence gaps? | Week/date policy, refresh parity, notification asymmetry, analytics pending honesty, write-scale guards. |
| Biggest academy blocker now? | **Session operations / unmarked register awareness.** |
| Ready to code W3? | **No — awaiting Phase 0 approval after this audit.** |

---

*End of post-W2 audit. No code was modified for this document’s findings beyond creating this report file.*
