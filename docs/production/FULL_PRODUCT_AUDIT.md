# Full Product Audit — Rafiq Academy

**Frozen baseline:** branch `feature/full-product-audit`  
**Commit:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Commit message:** `chore(integration): freeze all interfaces for full product audit`  
**Audit date:** 2026-09-09  
**Method:** Read-only inspection of that commit via a detached worktree. **No source changes. No refactors. No commits. No pushes. No invented backend contracts.**

Working tree at audit start was `feature/parent-interface` (not this freeze). Findings describe **only** commit `69e4207`.

Prior workflow docs (`docs/POST_W8_PRODUCT_AUDIT.md`, `docs/PRODUCT_ARCHITECTURE_COMPLETION_REPORT.md`, W1–W8 / H1–H8 validations) were used as **historical product-decision records**, then re-checked against this freeze. Where they disagree with the freeze, the freeze wins and the old inventory is marked **stale**.

---

## How to read this report

| Bucket | Meaning |
|--------|---------|
| **1. Confirmed existing behavior** | Observed in this commit |
| **2. Confirmed product decisions** | Explicit in code comments / approved docs, still holding |
| **3. Missing contracts** | No SSOT / no writer / no rules / no issuer |
| **4. Actual defects** | Implementation contradicts an encoded contract or breaks an operated flow |
| **5. UX inconsistencies** | Same job, different chrome |
| **6. Security / privacy** | Authz, phones, Storage, false paid |
| **7. Scalability** | Patterns that fail at hundreds/thousands |
| **8. Questions** | Need product/backend; not silently resolved |

Issue IDs: `docs/production/MASTER_ISSUE_MATRIX.md` (AUD-001 … AUD-102). Follow-up IDs AUD-094–AUD-102 after specialist re-reads of the same freeze.

| Priority | Count |
|----------|------:|
| P0 | 8 |
| P1 | 37 |
| P2 | 44 |
| P3 | 13 |
| **Total** | **102** |

---

## Executive verdict

The freeze contains a **coherent operated-day core** (homework, attendance, inferred teaching day, supervisor oversight, استئذان, admission/transfer) and **five large role shells** that look like one Academy in IA — but it does **not** yet behave as one coherent commercial + Quran-progress product.

| Loop | Freeze verdict |
|------|----------------|
| Operate the day (assign, attend, evaluate, oversee) | **Works** if a halaqa already has a schedule and roster (W1–W3, W6). Evaluation **create** is gated on today’s inferred meeting (`noSessionToday`). Attendance is **not** equivalently gated (AUD-094). Evaluation is **not** gated on attendance. |
| Signal استئذان / homework / absence to parents | **Works** if `parentProfiles.childrenIds` is pre-seeded (W4, W5, W7). |
| Admit / move students between halaqat | **Works** (W8 + Supervisor transfer). Exit/unenroll and parent-link do **not**. |
| Create an operable Halaqa from Admin | **UI works; business loop does not** — schedule is never written (AUD-018). |
| Quran progress numbers across roles | **Displays**; **does not compute** from recitation SSOT (AUD-020–023). |
| Payments Vodafone → proof → review → overdue → suspend | **Proof + Supervisor review exist** only for **pre-existing** payment docs. Invoice issuance, overdue writer, destination number, and suspension **missing**. Wallet + Paymob leftovers can create a **false paid** state (AUD-007–013). |
| Chat | **1:1 text** for policy pairs. **No** teacher+students group. Unbounded listeners. Admin can read all threads. |
| Authz | Router isolates **screens**. Firestore/Storage do **not** isolate **data** (P0). |
| AR / EN + LTR | **Arabic RTL only.** Language rows are inert. |
| Light / Dark | Theme objects exist; most screens hardcode light surfaces/text. |

**Production readiness:** not ready. P0 Authz + false-paid paths + public self-registration + undeployed rules wiring dominate.

Highest-risk flows: **payments paid-state**, **Firestore/Storage open writes**, **self-signup + open rules**, **halaqa-without-schedule**, **progress metrics**.

---

## 1. Confirmed existing behavior

### Platform

- Flutter app, `go_router`, injectable DI, per-role `Bloc`s as singletons, Firebase Auth + Firestore + Storage.
- Roles: `student | parent | teacher | supervisor | admin` (`AppRoles`).
- Feature flag: `AppCapabilities.audioUploadsEnabled = false`.
- Network gate: `NetworkInfoImpl` (5s timeout → assume online) then repository `NetworkFailure` if checker says offline.

### Navigation

- Auth: `/`, `/onboarding`, `/login`, `/register`.
- Role homes: `/student`, `/parent`, `/teacher`, `/supervisor`, `/admin`.
- `AppRouteAccess`: path must prefix the role home (exception: supervisor → teacher attendance/halaqa).
- Parent and Supervisor extra screens often use `Navigator.push`, not GoRouter (AUD-052).

### Operated day (works when data exists)

- **Homework (W1):** Teacher assign → student consume → review writes `recitationRecords`; events `HomeworkAssigned` / `HomeworkReviewed`.
- **Attendance (W2):** Teacher `SaveDayAttendance`; docs `{sessionId}_{studentId}`; `late` = attended; `excused` excluded from % denominator.
- **Day readiness (W3/W6):** `HalaqaDayReadiness` projector; Teacher agenda; Supervisor board; supervisor may escalate into teacher routes.
- **Events (W4/W5):** `FanOutAcademyEventSink` → `InAppAcademyEventHandler` → `notifications` upsert (deterministic ids).
- **استئذان (W7):** `absenceRequests`; teacher classify; supervisor read; does not rewrite attendance.
- **Admission (W8):** `AcademyAdmissionFirestore.establishMembership` atomic `isActive` + roster `arrayUnion` + primary `halaqaId`. Supervisor admit/transfer delegates here.

### Payments (partial)

- Proof contract encoded in `ParentPaymentProofContract`: Storage `payment_proofs/{parentId}/{paymentId}/{fileName}`; Firestore proof fields; `reviewStatus=pending_review`; parent Dart path does not set `status=paid`.
- Supervisor review: scoped to students in supervised halaqat; approve sets `status=paid`; reject/partial do not.
- Parent UI: history, overdue chips **if stored status is overdue**, wallet CTA, proof upload.

### Chat (partial)

- 1:1 `ConversationIdGenerator`; `ChatPermissionPolicy` pairs.
- Text send; conversation unread; Admin internal group `admin_internal_group`.
- Student gateway resolves teacher via `halaqa.teacherId` (fallback assignment assigner).

### Identity flags

- Login refuses `users.isActive != true` with «هذا الحساب موقوف…».
- Admin can toggle **teacher** `isActive`. Students show نشط/موقوف on the directory; that tab does **not** dispatch `ToggleAccountStatusEvent` (AUD-099).

---

## 2. Confirmed product decisions (still holding)

| Decision | Evidence |
|----------|----------|
| Audio recitation upload not required until Storage/Blaze flag | `AppCapabilities` |
| FCM not registered; in-app only | `DiModule`, H3 |
| Family link out of W8 | no `childrenIds` writer; Post-W8 |
| Unenroll out of W8 | no dedicated exit; transfer exists |
| Teacher posts tab removed | H6 + teacher home |
| Orphan routes removed | `/student/history`, `/teacher/calendar`, `/teacher/content` |
| Operational session id `{halaqaId}_yyyyMMdd` | `AttendancePolicy`, `EvaluationPolicy`, mapper `_asOperationalDay` |
| Same-day slots collapse to one operational day | mapper D6 |
| Admin may read all conversations | rules + `watchAllConversations` |
| Proof is not paid | Dart proof update; Supervisor approve is paid |
| Category B: full role rules, CI, App Check, FCM | comments in rules + old completion report — **still unfinished** |

**Stale vs this freeze (do not trust blindly):**

- H6 `adminProductUiAdmitOnly = true` — Admin is a **5-tab console** (dashboard, students, management hub, finance, settings).
- H6 teacher 4-tab labels — Teacher is **5 tabs** including awards.
- `AdminOpsBroadcast` comment “UI absent” — `AdminBroadcastPage` is wired.
- Post-W8 “no firestore.rules in repo” — **rules files exist now**, but `firebase.json` does not deploy them.

---

## 3. Missing contracts

Do not invent these. They are absent as SSOT/writers:

1. **Who creates `payments/{id}`** (period, amount, child, dueDate) — AUD-009 / AUD-037  
2. **Overdue transition** (store vs derive) — AUD-010  
3. **Payment → reminder → suspend → reason → Admin reactivate** — AUD-011  
4. **Configurable Vodafone destination** — AUD-012 (`transferDestination = ''`)  
5. **Payment / award / session-reminder AcademyEvents** — AUD-014, 030, 031  
6. **Parent↔child `childrenIds` writer** — AUD-015  
7. **Admin staff provisioning** — AUD-016  
8. **Password reset** — AUD-017  
9. **Persisted session entity / open-close lifecycle** — AUD-024  
10. **Teacher+students group chat** — AUD-027 (rules forbid >2 participants)  
11. **English locale + LTR** — AUD-044  
12. **Fee catalog / multi-child invoice** — AUD-037  
13. **Membership exit** — AUD-040  
14. **Quran progress projector** (what % means: whole Quran vs level vs surah) — AUD-020  
15. **Evaluation requires attendance?** — AUD-025 (currently no)  
16. **Admin silent chat oversight vs privacy** — AUD-054 (implemented; policy unclear for production)

---

## 4. Actual defects (selected; full matrix in companion)

- Open Firestore/Storage (AUD-001, AUD-002) and undeployed rules wiring (AUD-006).
- Self-registration of active students (AUD-005).
- Wallet/Paymob vs Vodafone (AUD-007, AUD-013); rules do not protect `status=paid` (AUD-004, AUD-008).
- Admin create halaqa **without schedule** (AUD-018) → Teacher **eval create** / today agenda empty; **attendance can still write** a synthetic day id (AUD-094).
- Progress/streak/juz/verses/admin % not updated or hardcoded 0 (AUD-020–023, AUD-039). Field meaning of `overallProgressPercent` contradicts UI (AUD-096); live eval stores empty `versesRange` (AUD-097).
- Parent weekly “verses” = recitation **document count** (AUD-022).
- Unbounded chat/admin listeners and full `payments.get()` (AUD-026, AUD-028, AUD-034).
- Missing indexes: recitation `halaqaId+date`; payments `parentId+dueDate` (AUD-032, AUD-033).
- Teacher reassignment does not maintain `teacherProfiles.halaqatIds` (AUD-019).

---

## 5. UX inconsistencies

See `SHARED_UI_AUDIT.md`. Headline: five bottom navs, three subpage headers (Teacher has no shared subpage scaffold), mixed back icons (including forward-ios used as back), Cairo vs NotoNaskh, light tokens on dark mode, Arabic-only copy, dead language rows, five Pulse skeleton copies, استئذان vs اعتذار terminology (AUD-102), inconsistent skeletons vs spinners. `AppErrorWidget` exists and is underused.

---

## 6. Security / privacy

See `AUTH_SECURITY_AUDIT.md`. Headline P0s: collection-wide signed-in writes; Storage catch-all; phones on `users` readable by any Auth user; parent/any user can mark payments paid at rules layer; public register.

---

## 7. Scalability

See `FIREBASE_SCALABILITY_AUDIT.md`. Headline: unbounded chat messages and Admin conversation snapshots; Admin finance loads all payments; awards dual unbounded queries; notification `readBy` on broadcast docs; no pagination on several lists; client aggregations; missing indexes; halaqa activity `responseCount` read-modify-write race (AUD-101).

Reasonable today for a **demo / tens of students**. Not reasonable for **thousands** without query windows, totals docs, and rules.

---

## PART 1 — Product flow audit (end-to-end)

Notation: **Works** / **Partial** / **Breaks** / **No contract**.

### F1 — Login

| | |
|--|--|
| Entry | `/login` |
| Roles | All |
| Preconditions | Firebase Auth user + `users/{uid}` with `role`, `isActive==true` |
| Path | LoginPage → AuthBloc `LoginWithEmailEvent` → `LoginWithEmailUseCase` → `AuthRemoteDatasourceImpl.loginWithEmail` → Auth `signIn` + Firestore get |
| Writes | None |
| Reads | `users/{uid}` |
| Permission | Auth; Firestore users read (open) |
| Result | `AuthAuthenticated` → `AppRouteAccess.homeForRole` |
| Errors | Mapped Arabic Auth errors; missing doc; inactive account |
| Breaks | No password reset (AUD-017). Inactive = generic message, no reason (AUD-011). |

### F2 — Public register (student)

| | |
|--|--|
| Entry | `/register` |
| Writes | Auth user; `users/{uid}` `role=student`, `isActive=true`; `studentProfiles/{uid}` zeros |
| Result | Active student **not** on a halaqa |
| Downstream | Combined with open rules, this identity can read academy data (AUD-001+005) |
| Intended | Admin-provisioned identities |
| Verdict | **Works technically / wrong product** |

### F3 — Admin creates Halaqa

| | |
|--|--|
| Entry | `/admin/create-halaqa` |
| UseCase | `CreateHalaqaUseCase` → `AcademyHalaqaFirestore.createHalaqa` |
| Writes | `halaqat/{newId}` name, teacherId, supervisorId, `studentIds=[]`, **`schedule=[]`**, meetingLink, status=active; maybe `teacherProfiles.halaqatIds` arrayUnion |
| Reads | Teacher profile existence |
| Notifications | None |
| Other roles | Teacher may see halaqa via `teacherId` query; **eval create / today agenda empty** without schedule; **attendance still writes** `{halaqaId}_yyyyMMdd` (AUD-094) |
| Verdict | **Visual create works; operated session does not** (AUD-018) |

### F4 — Admin/Supervisor assign students

| | |
|--|--|
| Admit | Admin `/admin/admit` or Supervisor register page → `AcademyAdmissionFirestore` |
| Transfer | Supervisor transfer page → same Firestore helper (move vs add-to-second) |
| Parent link | **No writer** (AUD-015) |
| Verdict | Admit/transfer **works**. Family link **no contract**. Exit **no contract**. |

### F5 — Teacher conducts session + attendance + evaluation

| | |
|--|--|
| Session | Inferred if `schedule` has a slot whose weekday = today. Id `{halaqaId}_yyyyMMdd`. No “open session” write. |
| Attendance | `SaveDayAttendanceUseCase` / `AttendanceService`; publishes absence transitions |
| Evaluation | `EvaluationService.openEvaluation`; upsert recitationRecords; **not** requiring attendance |
| End session | Clock vs `sessionEndAt` or midnight; no session-closed document |
| Parent/Student visibility | Attendance % from records; evaluations from recitationRecords; **profile progress unchanged** |
| Notifications | Absence yes; homework pending→reviewed emits W5; **live eval upsert does not publish** `AcademyEvent` (AUD-095) |
| Verdict | **Works when schedule exists.** Couplings (attend before eval, progress update, session close) **missing/weak**. |

### F6 — Student progress update

| | |
|--|--|
| Display | `studentProfiles.overallProgressPercent` et al. |
| Writer after eval | **None** |
| Verdict | **UI only** (AUD-020) |

### F7 — Parent views result

| | |
|--|--|
| Preconditions | `childrenIds` seeded |
| Reads | Attendance marks, recitation, profile fields, weekly report (verses = doc count) |
| Verdict | **Partial** — real attendance/evals if linked; progress numbers stale/misleading |

### F8 — Parent submits payment

| | |
|--|--|
| Preconditions | `payments/{id}` already exists, `parentId` match, not paid |
| Writes | Storage proof; Firestore proof fields + `method=vodafone_cash` + `reviewStatus=pending_review` |
| Alternate | Wallet transaction sets **paid** immediately (AUD-007) |
| Initiate Paymob | Throws unavailable (AUD-013) |
| Notifications | None (AUD-014) |
| Verdict | **Proof path partial** (no invoice, no destination). **Wallet path contradicts intended model.** |

### F9 — Supervisor reviews payment

| | |
|--|--|
| Scope | Payments where `studentId` in supervised halaqat |
| Writes | review fields; approve → `status=paid` |
| Rules | Any signed-in could do the same write (AUD-004) |
| Verdict | **App path works if invoices exist; not a security boundary** |

### F10 — Admin sees payment / totals

| | |
|--|--|
| Reads | Entire `payments` collection; client sums paid/due/overdue **stored statuses** |
| Verdict | **Partial** — unbounded; overdue undercount; zeros elsewhere on dashboard |

### F11 — Overdue / suspend / reactivate

| | |
|--|--|
| Overdue writer | **None** |
| Suspend from payment | **None** |
| Admin reactivate | Teacher `isActive=true` toggle exists (generic, no reason). Student directory does not dispatch it (AUD-099) |
| Verdict | **No contract** for the stated commercial policy |

### F12 — Teacher homework → student submit → teacher review

| | |
|--|--|
| Assign | Teacher write `assignments` + events |
| Student submit | Marks assignment submitted; coins increment; audio blocked by flag |
| Review | Recitation record graded; W5 event |
| Verdict | **Works** (audio optional/blocked). Progress profile still not updated. |

### F13 — Messaging

| | |
|--|--|
| Teacher↔Student | **Works in UI** (1:1 text) if teacherId resolvable. Policy is **role-pair only** — not halaqa/parent-link (AUD-098) |
| Teacher+students group | **No contract** (rules size ≤ 2) |
| Parent↔Teacher/Supervisor/Admin | Policy **allows** any matching roles; Parent UI **seeds** 1:1 chats (AUD-055) |
| Verdict | 1:1 **works** for happy path; groups **missing**; relationship not enforced; privacy of Admin read **decision needed** |

### F14 — Notifications generated

| | |
|--|--|
| Produced | Absence recorded/corrected; homework assigned/reviewed; halaqa activity published; Admin ops broadcast (separate pipeline) |
| Not produced | **Live session evaluation** (AUD-095); session reminder; payment*; awards; suspension; account changes (except generic) |
| Push | None |
| Verdict | **Partial in-app** |

### F15 — Student achievement generated

| | |
|--|--|
| Grant | Teacher/Supervisor/Admin awards write `achievements` (H7 dual fields) |
| Auto from Quran/streak | **No** (counters static) |
| Notify | **No** event |
| Verdict | **Manual grant works; automatic achievement no contract; notify missing** |

---

## PART 2 — Role audit (cross-interface)

### ADMIN

| Area | Freeze status |
|------|----------------|
| Login | Works if seeded admin user |
| Dashboard | Counts students/teachers/halaqat; attendance% and verses **hardcoded 0** |
| Students | Directory + profile (`StudentProfilePage`) + admit |
| Student profile | Shared student profile; shows phone |
| Teachers | Directory, rating, quota, activate/deactivate — **no create** |
| Teacher profile | Not a dedicated rich profile; management row |
| Supervisors | Directory page routed |
| Halaqat | List + create (**no schedule editor**) |
| Schedule | **Not captured at create** |
| Assignments | Not an Admin-owned write; teacher-owned |
| Payments | Review list + finance sums (unbounded; stored statuses) |
| Reports | CSV/PDF export from loaded AdminBloc stats (inherits zeros) |
| Awards/grants | Rewards page exists |
| Notifications | Shared inbox wrapper |
| Settings | Communication settings + account |
| Account state | Teacher `isActive` toggle; student badge is **display-only** on the students tab (AUD-099) |
| Permissions | Router `/admin/*` only; Firestore not scoped |

### SUPERVISOR

Home, students, halaqa detail, attendance (read/escalate), follow-up, excuses (read), payments review, awards grant, messages (no students), reports tab, announcements (via destinations), calendar, transfers/admission, account.

Session **execution** remains teacher-owned (W6). Payments review **works** on existing docs. Parent link **cannot** be created here.

### TEACHER

Home (5 tabs: الرئيسية، الطلاب، الجوائز، الرسائل، حسابي — contradicts H6 4-tab note), halaqat/classes, session via inferred day, students, attendance (can write without today’s slot — AUD-094), evaluation (blocked without today’s slot), review/memorization, homework/tasks (Firestore activities + leftover mock store for tests), awards, messages, student profile, analytics (index risk), notifications, excuses («الاعتذار» vs Parent «الاستئذان» — AUD-102), account. No shared Teacher subpage scaffold.

Posts tab **removed**. Content route **removed**. Calendar route **removed**.

### PARENT

Home, children (needs `childrenIds`), child profile, progress (stale %), attendance, evaluations, homework awareness (events), payments (no issuer), notifications, messages (seeded 1:1), account.

Cannot self-link children. Cannot complete Vodafone payee step in-app.

### STUDENT

Home tabs: الرئيسية، مصحفي، badges (elevated star), خريطتي، حسابي. Progress (stale + contradictory meaning — AUD-096), Quran mushaf (default surah 67), review schedule, schedule (inferred week), attendance %, evaluation list, homework, submissions (audio blocked), achievements (manual + mislabeled accuracy), awards, messages (teacher only), notifications, settings (dark/font; language dead).

Self-register possible. Membership not established until W8.

---

## PART 3 — Halaqa + session lifecycle (answers)

| Question | Answer in this freeze |
|----------|------------------------|
| Can a Halaqa exist without a valid schedule? | **Yes.** Create writes `schedule: []`. |
| Where is day/time stored? | `halaqat.schedule[]` `{day, startTime, endTime}` strings. |
| Is session generated or inferred? | **Inferred.** No `sessions` collection. Operational id `{halaqaId}_yyyyMMdd`. Weekly UI ids `{halaqaId}_$index` are a **second shape**. |
| Source of truth? | Schedule slots + local clock. Attendance/eval documents hang off synthetic ids. |
| Overlapping sessions? | Same calendar day **collapsed** to one operational day (earliest start, latest end). |
| Second session before previous completed? | **Not as a second SSOT session.** One id per halaqa per day. |
| Evaluation for the wrong session? | Live open uses today’s inferred id. Opening an existing card uses stored `sessionId`. Providing a mismatched `sessionId`+date is trusted if passed in. No attendance coupling. |
| Attendance without a session? | Without a **document** session: **yes, always** (inference). **Without today’s schedule: attendance still writes** via `_resolveSessionBounds` fallback to `{halaqaId}_yyyyMMdd` (AUD-094). Evaluation create does **not** share that fallback. |
| Evaluation without attendance/session? | Without attendance: **yes**. Without inferred session today: **create blocked** (`noSessionToday`). Live upsert then stores empty `versesRange` (AUD-097) and **no** academy event (AUD-095). |
| Old sessions remain incomplete? | **Yes.** Completeness is a projection; no closeout record. Past days become read-only after end/midnight. |
| Teacher changes? | `assignStaff` updates `halaqat.teacherId` only; `teacherProfiles.halaqatIds` can go stale. Student chat fallback may hit old `assignedBy`. |
| Student moves Halaqa? | Transfer/admit updates roster + primary `halaqaId`. Historical attendance/eval remain on old ids. Parent link unchanged (none). |
| Halaqa inactive? | `status` field exists; not consistently gated in eval/attendance services. |
| Schedule changes? | No Admin schedule editor in create flow. If schedule docs change, **future inference** changes; **past attendance ids do not migrate**. |

---

## PART 4 — Student progress / Quran logic

| Displayed number | Meaning in code | Source | Honest? |
|------------------|-----------------|--------|---------|
| `overallProgressPercent` | Entity comment: **current surah % only**. Widgets/teacher/parent treat it as **overall حفظ** / «دقة الحفظ» (AUD-096) | Register `0` / seeds; **no eval writer**; comment says “updated later from memorization plan” | **No** — stale, seed, **and naming contradiction** |
| `totalVersesMemorized` | Stored int | Same | **No** live |
| Parent weekly `totalVersesMemorized` | **Count of reviewed recitation docs** | Query | **Misleading label** |
| `completedJuz` / `completedSurahs` | Stored ints | Same | **No** live |
| `streakDays` | Stored int | Same | **No** live from attendance |
| `level` | Stored int default 1 | Profile | **No** level-up writer found |
| Donut on student home | `overallProgressPercent` | Profile | Misleading |
| Mushaf “الختمة x/٣٠” | `completedJuz` | Profile | Misleading |
| Achievements “accuracy” | `overallProgressPercent` | Profile | **Wrong metric** |
| Admin verses this month | Literal `0` | Hardcoded | Fake |
| Admin attendance % | Literal `0` | Hardcoded | Fake |
| Teacher/Supervisor progress bars | Profile field | Read | Stale |
| Analytics performance | Event-weighted **reviewed grades** | `recitationRecords` | **Honest for grades**; separate from profile % |
| Attendance % | attended / non-excused marks | `attendanceRecords` + `AttendancePolicy` | **Honest** |

**Mixing risks (flagged):**

- Overall Quran % vs current-level % vs **current surah %**: entity comment says surah; UI says overall/accuracy — **one stored field, three claimed meanings** (AUD-096).
- Live eval `versesRange` is always `''` — verse totals cannot be derived from session evals (AUD-097).
- Surah vs Quran-wide: mushaf UI has local catalog progress; profile overall is separate and not updated from mushaf.
- Static/seed values in demo dataset (`overallProgressPercent: 78` etc.) will look “real” in UI.

**Attendance % is the rare metric with a real SSOT and tests.** Quran progress is not.

---

## PART 5 — Payments (lifecycle vs freeze)

| Step | Status |
|------|--------|
| Parent selects period + children | **Missing contract** |
| Sees amount | Only if invoice docs exist |
| Pays Vodafone Cash externally | Off-app; destination **empty** |
| Upload screenshot | **Implemented** (size/type; Storage path) |
| Storage | Path encoded; rules: any signed-in **read**; owner write images <10MB |
| Firestore pending_review | **Implemented** in Dart |
| Supervisor approve/reject/partial | **Implemented** in Dart (roster scoped) |
| Parent sees status/history | **Implemented** for loaded docs |
| Admin sees payment | **Implemented** (full collection) |
| Totals update | Client reduce; no trigger |
| Overdue detected | **Only if stored `overdue`** |
| Reminders/escalation | **Missing** |
| Suspension + reason | **Missing** (`isActive` generic) |
| Contact Admin | Chat policy allows parent↔admin; not a payment-case flow |
| Admin reactivate | Generic teacher `isActive` toggle; student directory badge is display-only (AUD-099) |
| Proof ≠ paid | Dart proof path **yes**; rules **no**; wallet **no** |
| No fake paid | **Violated** by wallet + open rules |
| No Paymob | Dart initiate **disabled**; functions **still in repo** |
| Vodafone configurable | **Empty constant** |
| No invented number | **Honored** (blank) — also means unusable payee |

**Duplicate submissions:** Proof resubmit allowed; prior review fields deleted.  
**Partial:** reviewStatus partial; remainingAmount optional; no remainder invoice.  
**Multiple children / different halaqat:** no combined invoice policy.

---

## PART 6–19

Detailed in companion files:

- Auth/security → `AUTH_SECURITY_AUDIT.md`
- Chat / notifications → this file Part 1 F13–F14 + matrix
- Shared UI / RTL / l10n / theme / responsive → `SHARED_UI_AUDIT.md`
- Data contracts / Firebase / scale → `DATA_CONTRACT_AUDIT.md`, `FIREBASE_SCALABILITY_AUDIT.md`
- Tests → matrix AUD-071–074 and §Test audit below

### Test audit (summary)

~88 test files. **Strong:** membership invariant, attendance policy, evaluation policy/service, day readiness, event fan-out, some use cases (assign, save attendance, admit, proof submit, wallet pay, route access), chat permission/id.

**Missing:** Firestore/Storage rules tests; emulator integration; payment issuer/overdue/suspend; progress projector; password reset; widget tests for Admin/Parent/Supervisor shells; failure-state taxonomy; concurrency review vs resubmit; authorization beyond router.

H8 “critical-path belt” covers W1–W8 **happy** use cases, not commercial/Quran/Authz production bar.

---

## PART 20–21

- Matrix: `MASTER_ISSUE_MATRIX.md`
- Scenarios: `CROSS_INTERFACE_SCENARIOS.md`

---

## 8. Questions requiring product / backend decisions

**RESOLVED (Wave 0 — 2026-09-10).** Authoritative answers: `PRODUCT_DECISIONS_LOCKED.md` (D1–D24). Implementation roadmap: `IMPLEMENTATION_PLAN.md`. Billing gate: `FIREBASE_BILLING_CHECKLIST.md`.

This historical audit section listed open questions at freeze time. They are **no longer open product questions**. Remaining work is Engineering / Schema / Infrastructure TBD only (see implementation plan).

| # | Former question | Lock |
|---|-----------------|------|
| 1 | Public register? | **D1** No public self-registration; Admin-controlled provisioning |
| 2 | Payment rail? | **D2** Vodafone+proof only; Paymob OUT; Wallet OUT |
| 3 | Who issues invoices? | **D3** Admin pricing; backend auto-generates; amount snapshot |
| 4 | Overdue stored vs derived? | **D4** Stored; scheduled backend job |
| 5 | Suspend login vs features? | **D5** Payment-specific access policy (≠ blind `isActive`); Pay Now + Contact Admin only |
| 6 | Vodafone destination? | **D6** `academySettings`; Admin edits; Parent reads |
| 7 | Eval require attendance? | **D7** Yes — Session + Present/Late |
| 8 | Schedule required / attendance without meeting? | **D8** ≥1 slot required; **D10** real sessions |
| 9 | Two slots same day? | **D9** One Session per slot; backend conflicts |
| 10 | Persist sessions? | **D10** Yes — `sessions/{sessionId}` |
| 11 | Progress % meaning / versesRange? | **D11** Memorization %; typed evals; real versesRange; accuracy separate |
| 12 | Who writes childrenIds? | **D12** Admission/W8 workflow; Parent request; Admin assigns; Parent cannot write |
| 13 | Admin chat oversight? | **D13** Yes, intentional; sectioned UI |
| 14 | Group chat / relationship? | **D14** 1:1 + Halaqa groups; server-side relationship authz |
| 15 | English/LTR? | **D15** Arabic+RTL only; EN/LTR OUT; dark/light program OUT |
| 16 | Phone visibility? | **D16** Admin only (rules) |
| 17 | Deploy open rules? | Still **no** — tight rules first, then AUD-006 |
| 18 | Live eval notify? | **D17** Yes — event + Parent notify (+ FCM per D19) |
| 19 | Admin student toggle on roster? | **D18** Roster shows status; actions on Student Profile |

Additional locks not in the original numbered list: **D19** FCM IN; **D20** chat media/edit/delete; **D21** no-Halaqa ≠ payment suspend ≠ archive; **D22** no idle timeout; **D23** Al-Fatihah + last-read + mushaf redesign; **D24** `supervisorProfiles` legacy non-SSOT.

---

## Files in this documentation set

| File | Contents |
|------|----------|
| `FULL_PRODUCT_AUDIT.md` | This master report (freeze evidence) |
| `MASTER_ISSUE_MATRIX.md` | AUD-001–102 full records |
| `CROSS_INTERFACE_SCENARIOS.md` | 18 scenario traces |
| `SHARED_UI_AUDIT.md` | Design system / RTL / l10n / theme / responsive / states |
| `DATA_CONTRACT_AUDIT.md` | Collections, fields, writers, readers |
| `AUTH_SECURITY_AUDIT.md` | Auth, roles, rules, privacy |
| `FIREBASE_SCALABILITY_AUDIT.md` | Queries, listeners, indexes, scale |
| `IMPLEMENTATION_PLAN.md` | Dependency-aware roadmap (Wave 0 complete) |
| `PRODUCT_DECISIONS_LOCKED.md` | Authoritative D1–D24 |
| `FIREBASE_BILLING_CHECKLIST.md` | Paid services / Blaze gate |

Historical audit STOP still applies to **source**: no code, no commit, no push from the audit itself. Planning docs may be updated for locks.
)
