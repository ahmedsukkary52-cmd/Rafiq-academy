# Post-W3 Product & Architecture Audit

**Date:** 2026-07-26
**Branch:** `feature/teacher-module-production-cleanup`
**Scope:** W1 (Homework) + W2 (Attendance) + W3 (Daily Halaqa Session Operations) as one academy product
**Method:** Read-only investigation. **No code changes. No commits. No pushes.**
**Predecessors:** `docs/POST_W2_PRODUCT_AUDIT.md`, `docs/W3_PHASE0_DESIGN.md`, W1/W2/W3 validation docs

### Classification legend

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed in current code / config (file:line cited) |
| **Inference** | Reasonable conclusion from Verified facts |
| **Accepted** | Explicitly deferred in an approved decision (W1/W2/W3) |

### Deliverables in this document

1. §1 — Workflow coherence audit (product)
2. §2 — Architecture health audit
3. §3 — Product consistency audit (teacher login → logout)
4. §4 — Performance audit
5. §5 — Technical debt report (P0/P1/P2) incl. Firebase deployment + security
6. §6 — Updated roadmap + **Recommended W4** (one workflow)

---

## 0. Executive verdict

**W1+W2+W3 now form one operated academy day for the teacher.** W3 closed the gap the post-W2 audit identified: the dashboard answers "what must I do today", every readiness signal has a single owner (`AttendancePolicy`, `getLatestAssignmentDueDate`, `isPendingReview`, `GetTodayAgendaUseCase`), and closeout is a pure projection. The orchestration architecture held: no duplicated business rules were introduced by W3 itself.

**The biggest remaining workflow gap has moved from the teacher to the parent.** The audit findings are maintained in two independent tracks:

- **Category A — Product & Architecture debt:** correctness, maintainability, performance, and user-experience issues. These may be addressed before or during a workflow when they materially improve that workflow.
- **Category B — Platform Hardening:** rules, deploy configuration, CI, release infrastructure, and production pipeline. These remain serious **Release Readiness** work, but do **not** gate W4 or any individual product workflow.

Three findings dominate everything else in this audit:

1. **Verified — there are no security rules in the repository at all.** No `firestore.rules`, no `storage.rules`. Whatever protects the live project was clicked together in the console (or nothing does). The client writes fields it must never be trusted with: self-credited `points`/`coins`, notification `audience` (any authenticated user could target `'all'`), attendance `recordedBy`, review-status transitions.
2. **Verified — `firebase.json` cannot deploy what the repo does track.** It contains only the FlutterFire platform block — no `firestore` key — so `firestore.indexes.json` is undeployable from source, and **~11 composite indexes required by live queries are missing from that file anyway** (they were evidently created via console error links). Any fresh environment or index loss reproduces `FAILED_PRECONDITION` crashes.
3. **Verified — the teacher loop is closed, the parent loop is not.** A child can be marked absent every day and the parent finds out only if they open a passive weekly card. Attendance now gets reliably marked (W3's whole point) — but marking it has no social consequence. `absenceRequests` remains an orphan write API (Accepted W2 D3).

**Recommended W4: Absence Awareness & Parent Day Signal.** Platform Hardening is tracked separately as a Release Readiness milestone and does not gate W4. Full reasoning in §6.

---

## 1. Workflow coherence (W1 × W2 × W3)

### 1.1 What W3 fixed (Verified)

| Post-W2 gap | Now |
|-------------|-----|
| "Two independently operated rituals" | One agenda orchestrates attendance + homework + reviews per operational day (D6/D7) |
| No register-completion awareness | `AttendancePolicy.isRegisterComplete` is the SSOT; agenda + closeout both consume it |
| No "today's homework sent?" signal | `getLatestAssignmentDueDate` + `isSameCalendarDay` (one query, one day policy) |
| No end-of-day honesty | `TeacherDayAgenda.closeout` — pure projection, zero new I/O |
| Agenda staleness after writes | Every W1/W2 mutation success re-dispatches `LoadTodayAgendaEvent` (`teacher_bloc.dart:290,336,374,428`) |

### 1.2 Duplicated concepts (Verified)

1. **"Latest assignment" rule exists 4×.** The W1 D7 ordering (`orderBy dueDate DESC · limit 1`) is independently implemented in `student_remote_datasource_impl.dart:122–127` (one-shot) and `:160–166` (stream), `homework_remote_datasource_impl.dart:28–34` (one-shot + stream), and `teacher_remote_datasource_impl.dart:345–350` (halaqa-scoped, added in W3 Slice 2). A code comment (`teacher_remote_datasource_impl.dart:343`) is currently the only thing keeping them aligned. There is no `AssignmentPolicy`/query-builder owner for the single most load-bearing product rule in W1.
2. **Calendar-day normalization at ~13 sites** hand-rolls `DateTime(y, m, d)` instead of `AttendancePolicy.dayStart` — including inside the teacher feature that owns the policy (`teacher_attendance_page.dart:56,62`, `teacher_class_detail_page.dart:673,689,708`), plus parent, notifications, schedule, review_schedule, progress_report, calendar, admin.
3. **Same-day comparison duplicated 3× in the teacher feature alone** (`teacher_bloc.dart:232–236`, `teacher_attendance_page.dart:90–93` and `:129–132`) even though W3 added `AttendancePolicy.isSameCalendarDay` — the SSOT exists; old call sites were never migrated.
4. **Arabic weekday names encoded in 8 places, in 3 incompatible shapes**, with live spelling drift: `teacher_dashboard_tab.dart:486` emits `'الاثنين'`, `student_header_widget.dart:166` emits `'الإثنين'`, and `halaqa_weekly_sessions_mapper.dart:194–202` must accept **both** to work. That mapper tolerance is the only thing preventing a scheduling bug today.
5. **Three "week" definitions persist** (unresolved from post-W2 audit): parent weekly starts Saturday, student progress chart starts Sunday, teacher analytics uses a rolling 7 days. Same word «أسبوعي», three meanings.
6. **Recitation visibility policy still missing** (unresolved from post-W2 audit): parent/student filter pending recitations; teacher analytics grade distribution does not.

### 1.3 Inconsistent terminology (Verified)

| Concept | Names in the UI | Evidence |
|---------|-----------------|----------|
| Assignment | `تكليف` (teacher class detail: `teacher_class_detail_page.dart:218,794,853`), `واجب اليوم` (teacher dashboard `:351`; student card), `واجباتي`, `درس اليوم`, `حفظ اليوم` (`student_daily_task_widget.dart:80,141`) | **Five names for one Firestore document** |
| Halaqa vs meeting | `الحلقات/حلقاتي` (teacher nav) vs `حصص مجدوَلة` (W3 agenda) vs `حصصي` (student schedule) | The حلقة (group) / حصة (meeting) model is never explained to the user |
| «مراجعة» double meaning | Recitation *type* `مراجعة` and the teacher's *moderation action* `مراجعة التسميع` on the **same page** (`teacher_evalutation_page.dart:305,386,555,607`) | Genuinely ambiguous for a new teacher |
| تسميع vs تقييم | Student "sends تسميع" → teacher sees it under "التقييمات" → student sees the result as "تقييم" | Lifecycle naming never settles |
| Rewards | `منح شارة` (student row), `منح جائزة` (student profile), `منح الجائزة` (awards page), `منح إنجاز` (supervisor) — all one subsystem | 4 verbs, no visible hierarchy |
| Gender slip | `إرسال التسميع للمعلمة` (`student_recitation_page.dart:669`) vs `المعلم` everywhere else | Single occurrence |

**Recommendation (for a future consolidation pass, not now):** canonical glossary — `تكليف` = teacher action, `واجب` = student-facing object, `تسميع` = submission, `اعتماد/تدقيق التسميع` = teacher review action, `تقييم` = approved result.

### 1.4 Duplicated navigation (Verified)

Multiple entry points converging on one implementation are **by design** (W3 D5 deep-links) and are not defects. Two real problems:

1. **Student-row actions lie about their grain.** `تقييم` and `منح شارة` on a student row open **halaqa-wide** screens without preselecting that student (`teacher_class_detail_page.dart:524–535`) — the teacher must find the student again and can pick the wrong one.
2. **Link-only tabs.** Class detail "الحضور" and "التقييمات" tabs contain only a button to another page (`teacher_class_detail_page.dart:264–290`) — a whole tab that is one extra hop.

### 1.5 Duplicated loading / empty / error states (Verified)

- Shared `AppLoadingWidget` / `AppErrorWidget` exist (`shared_widgets.dart:323–369`) — **there is no shared empty-state widget**, and ~20 pages roll their own empty visuals with divergent icons/copy/retry behavior.
- Local loading spinners bypass the shared widget in ~8 places (incl. the W3 agenda card itself, `teacher_dashboard_tab.dart:191–200` — a deliberate section-level spinner, acceptable, but undocumented as a pattern).
- Local error implementations without retry: teacher profile stats (`teacher_profile_tab.dart:103–110`), router error screen (`router_app.dart:362–365`), and — worst — **analytics has no loading/error branch at all** (§3.4).
- **Posts comments bug:** `commentsError` is watched but never rendered; a load failure renders as `لا توجد تعليقات` (`posts_list_page.dart:643–660`) — an error disguised as a legitimate empty state.

### 1.6 Unnecessary user steps (Verified)

1. Student-row → evaluation/award requires reselecting the student (§1.4).
2. Link-only attendance/evaluations tabs add one hop each (§1.4).
3. Onboarding/auth redirects **discard the requested deep link** (`router_app.dart:116–143`) — a W3 agenda deep-link followed by a session expiry lands the teacher on the dashboard, not the intended register.
4. Supervisor student-linking requires manually typing raw student IDs (`supervisor_home_page.dart`).

---

## 2. Architecture health

### 2.1 Bloc responsibilities

**`TeacherBloc` is the outlier (Verified):** 399 lines, `@singleton`, **13 events, 25 state fields, 6 unrelated sections** (its own section comments name them: halaqat, agenda, students, evaluations, day-attendance, submissions). Consequences already visible:

- `copyWith` needs a custom `_Unset` sentinel and runs 80 lines (`teacher_state.dart:94–175`).
- Every consumer writes defensive `buildWhen` guards (8 conditions in `teacher_attendance_page.dart:172–181`).
- A dead field ships in every state copy: `attendanceError` (`teacher_state.dart:50`) — its own comment admits it is unused.

**Recommendation:** split along its existing section seams into `TeacherHalaqatBloc` (halaqat + agenda + selection), `TeacherAttendanceBloc`, `TeacherRecitationBloc` (evaluations + review + assignment). No read cost change — same use cases underneath.

**Other blocs:** `AdminBloc` (19 events, 10 sections) is the second offender but fronts a placeholder page. `AudioBloc` mixes player transport with catalog browsing and is the only bloc importing its own **data layer** (`audio_bloc.dart:12–13`). The remaining 16 blocs are cohesive.

**Singleton lifetime bug (Verified, P1):** `TeacherBloc`, `StudentBloc`, `ParentBloc`, `SupervisorBloc` are `@singleton` and **nothing resets them on logout** (`auth_bloc.dart:64` clears auth only; no `sl.reset()` anywhere). A second user on the same device sees the previous user's halaqat/agenda/roster until fresh loads land. Carried over unresolved from the post-W2 audit (P1-5).

### 2.2 UseCase responsibilities

- **~66 of ~75 use cases are one-line pass-throughs.** Real logic lives in exactly four: `GetTodayAgendaUseCase` (W3 orchestrator — correct), `GetOrCreateConversationUseCase` (chat permission gate), `CreatePostUseCase`/`AddCommentUseCase` (validation). The layer also earns its keep in 4 features whose repositories throw instead of returning `Either` (below).
- **Dead through all layers (Verified):** `RecordAttendanceUseCase` — registered in DI, called by nothing, delegates to `saveDayAttendance([record])` across use case → repository → datasource. `GetLatestAssignmentUseCase` (student) — registered, never resolved. Both are safe deletions.
- **Contract inconsistency:** `HomeworkRepository`, `ProgressReportRepository`, `ReviewScheduleRepository`, `ScheduleRepository` return raw futures and throw; the other 14 return `Either<Failure, T>` and check `NetworkInfo`. The `if (!await networkInfo.isConnected)` guard is copy-pasted 9× in `teacher_repository_impl.dart` alone — a base-class/wrapper candidate.

### 2.3 Read models

- `teacher/domain/read_models/teacher_day_agenda.dart` (W3) is the only read-model module and is the **pattern to copy** — documented as a projection, never persisted, closeout is a pure getter.
- Presentation content living in `domain/entities`: `avatar_catalog.dart` (emoji + display names), `RecitationGradeLabel` extension returning Arabic UI strings — see §2.6 for why that one is a correctness risk, not just a style issue.
- `AttendanceStatus` enum is declared inside `teacher_repository.dart:10` — a repository interface file — forcing pages to import a repository to reference a status.

### 2.4 Policies

| Policy | Status |
|--------|--------|
| `AttendancePolicy` | **Healthy SSOT** — day boundaries, register completeness, percentages; used by teacher/parent/analytics/progress/schedule. The remaining problem is **call sites that bypass it** (§1.2 items 2–3), not the policy itself |
| Latest-assignment rule | **No owner** — 4 duplicated query shapes (§1.2 item 1) |
| Recitation visibility | **Still missing** (post-W2 audit §2.5, unresolved) — analytics diverges from parent/student honesty |
| Academy calendar / week-start | **Still missing** (post-W2 audit, unresolved) — 3 week definitions + 8 weekday-name copies |
| `ChatPermissionPolicy` | Exists, correctly feature-scoped, **untested** |

### 2.5 Dependency directions (Verified violations)

1. **Teacher *domain* → schedule *data*** — `get_today_agenda_usecase.dart:9–10` imports `schedule/data/mappers/halaqa_weekly_sessions_mapper.dart` and hand-builds `HalaqaScheduleSourceModel`. This is **W3's own structural debt**: the mapper is pure scheduling logic with zero persistence concern and belongs in `schedule/domain/` (or shared), at which point the import becomes legal. Behavior is correct; the layering is not.
2. **Teacher/supervisor/homework/analytics/shared all import student-feature entities** — `HalaqaEntity`, `RecitationRecordEntity`, `AssignmentEntity` are cross-cutting domain concepts wearing a student label (~12 cross-feature imports; even `shared/utils/halaqa_schedule_label.dart:1` imports a student entity). They belong in a shared domain module.
3. **`AudioBloc` → own data layer** (`audio_bloc.dart:12–13`) — only presentation→data violation.
4. **23 presentation files resolve `sl<>` directly**, some bypassing their bloc into another feature's use cases (`student_recitation_page.dart:17–18`).
5. Naming debt: `supervisor/domain/repositories/parent_repository.dart` declares `SupervisorRepository`; typo filenames (`teacher_evalutation_page.dart`, `notifiaction_repository.dart`, `auth_remote_datasouce_impl.dart`, `posts_remote_datasorce_impl.dart`, `get_teacher_halaqt_usecase.dart`); three different datasource directory spellings (`data_sources/`, `data_source/`, `datasources/`).

### 2.6 Correctness risk hiding in the architecture (Verified, high priority)

**`RecitationGrade.label` is simultaneously the UI string and the Firestore wire format.** `teacher_remote_datasource_impl.dart:218–219` writes `'grade': grade.label` — the persisted value **is** the Arabic display label (`'ممتاز'`, `'جيد جداً'`). Renaming a label to fix copy would silently corrupt stored data and break every reader. This needs a stable wire code separated from the display string before any terminology cleanup (§1.3) can touch grades.

### 2.7 Extract / merge / simplify / remove summary

| Action | Item |
|--------|------|
| **Remove** | `RecordAttendanceUseCase` stack (4 files), `GetLatestAssignmentUseCase`, `TeacherState.attendanceError`, 2 dead composite indexes (§4.3) |
| **Extract** | `HalaqaWeeklySessionsMapper` → `schedule/domain/`; shared domain module for `HalaqaEntity`/`RecitationRecordEntity`/`AssignmentEntity`; `arabic_calendar.dart` (weekday names + week-start); latest-assignment query owner; shared empty-state widget |
| **Merge** | 4 latest-assignment query implementations; one-shot + stream duplicate methods (§4.4) |
| **Split** | `TeacherBloc` → 3 blocs (highest-leverage single change) |
| **Unify** | Repository `Either` contract + `NetworkInfo` guard across the 4 outlier features |
| **Fix** | Grade wire format (§2.6); singleton reset on logout; `AttendanceStatus` file location |

---

## 3. Product consistency (teacher experience, login → logout)

### 3.1 Screen-purpose check (Verified)

| Surface | Clear purpose? | Issue |
|---------|----------------|-------|
| Dashboard (W3 agenda) | **Yes** — answers "what should I do today" | — |
| Classes list | Yes | — |
| **Posts tab** | **No** — a primary bottom-nav slot showing a placeholder (`teacher_post_tab.dart:5–23`) while a fully implemented `PostsListPage` sits disconnected | Wire it or remove the tab |
| Messages tab | Yes | — |
| Profile tab | Yes | Stats error has no retry (`teacher_profile_tab.dart:103–110`); logout has **no confirmation** while student logout does |
| Class detail | Yes (operational hub) | Link-only tabs; student-row action grain (§1.4) |
| Attendance page | Yes | — |
| Evaluations page | Yes | «مراجعة» double meaning (§1.3) |

### 3.2 Dead ends (Verified)

- **`/parent`, `/supervisor`, `/admin` have no logout and no back path.** Only student and teacher can sign out. A parent on a shared device is stuck in the account.
- Router error page offers no recovery action (`router_app.dart:362–365`).

### 3.3 Unreachable features (Verified)

Routes/pages that exist but have **no in-app entry point**: `/teacher/halaqa/:id/analytics`, `/teacher/calendar`, `/teacher/content`, `/student/history` (explicit placeholder), `ChatConversationsPage`, `PostsListPage`. Decide per item: expose or delete the route.

### 3.4 Misleading UI (Verified — the most user-facing findings in this audit)

1. **Analytics shows false zeros.** No loading/error branch exists (`analytics_dashboard_page.dart:53–114`); header defaults null data to `0%` performance / `0%` attendance / `0` students (`:144–155`). A network failure is indistinguishable from a failing halaqa. Must be fixed **before** analytics gets an entry point.
2. **Certificates always say `حلقة المتقدمين`.** Hard-coded halaqa name in `awards_page.dart:611–620` — every certificate for any other halaqa carries the wrong name.
3. **Awards can attach to the wrong halaqa.** `student_profile_page.dart:154–170` prefers `selectedHalaqaId` → first teacher halaqa → student's actual halaqa, in that order; a stale selection grants an award under an unrelated halaqa.
4. **`إجمالي الطلاب` double-counts** students in multiple halaqat (sum of `studentIds.length`, `teacher_dashboard_tab.dart:101–104`, `teacher_profile_tab.dart:113–115`).
5. **Parent metric mislabeled.** The count of reviewed recitation docs is stored as `totalVersesMemorized` (`parent_remote_datasource_impl.dart:88–119`) and displayed as `تقييمات` (`parent_home_page.dart:268–273`) — it is neither.
6. **Inert controls:** login "forgot password" is non-interactive text (`login_page.dart:189–201`); settings `اللغة` row has no `onTap`; a post row has `onTap: () {}` (`posts_list_page.dart:626–639`).

---

## 4. Performance (high-value only)

### 4.1 The one big one: agenda derivation N+1 with an unbounded read (Verified)

`GetTodayAgendaUseCase._pendingActionsFor` issues **3 sequential Firestore round-trips per today-halaqa** (attendance, latest due date, recitations), and re-runs after **every** attendance/recitation/assignment write. Worse, the third read — `getHalaqaRecitationRecords` (`teacher_remote_datasource_impl.dart:249–266`) — has **no limit and no date filter**: it downloads every recitation record the halaqa has ever produced **to evaluate one boolean** (`.any(isPendingReview)`). This grows without bound over the halaqa's lifetime and is re-downloaded on every dashboard load and after every write.

**Fix shape (W4-adjacent, needs approval):** a scoped `where reviewStatus == 'pending' · limit 1` query (requires one new composite index) + running the per-halaqa checks concurrently. This does not change any policy — same rule, fewer bytes.

### 4.2 Write-on-read streams (Verified)

`watchLatestAssignment` / `watchLatestHomework` call `_ensureHomeworkFields` **inside `asyncMap`** — a merge **write** plus a follow-up **read** on every snapshot emission, and the write re-triggers the snapshot (`student_remote_datasource_impl.dart:160–173`, `homework_remote_datasource_impl.dart:51–59`). The legacy-seed logic (post-W2 audit P1-3) got worse, not better: it now amplifies live streams. Should be a one-time backfill.

### 4.3 Unbounded / at-risk queries (Verified)

- Admin financial summary reads the **entire `payments` collection** (`admin_remote_datasource_impl.dart:52–54`); complaints likewise (`:136–139`).
- `getHalaqaStudents` uses `whereIn` on document IDs **without chunking** (`teacher_remote_datasource_impl.dart:52–55`) — hard failure at >30 students per halaqa. Unresolved post-W2 P1-2.
- Analytics does per-student `users.doc().get()` in loops (`analytics_remote_datasource_impl.dart:184–187, 215–218`).
- Two declared composite indexes match no query (`attendanceRecords` halaqaId+studentId+date, halaqaId+status+date) — dead weight in `firestore.indexes.json`.

### 4.4 Duplicate live listeners

The latest-assignment query exists as both one-shot and stream in two features (4 methods total). If the student home card and homework page are alive for the same student, two independent listeners run the same query.

### 4.5 Rebuilds — healthy (Verified good news)

Every `BlocBuilder`/`BlocConsumer` over `TeacherState` uses `buildWhen`; the notification badge uses `BlocSelector`. **No high-value rebuild issue found.** This also independently confirms the W3 Slice 4 "no additional rebuilds" constraint held. No per-build heavy derivations over large lists were found; the expensive work is I/O (§4.1), not CPU.

---

## 5. Technical debt report — two-track classification

This classification supersedes the earlier single P0/P1/P2 queue for scheduling purposes. Priority remains recorded inside each category, but **Category B does not block W4**.

### 5.1 Category A — Product & Architecture debt

These issues directly affect current correctness, maintainability, performance, or user experience. They may be fixed before or during W4 only when the change improves or protects the approved workflow; unrelated cleanup stays in a separate debt slice.

| ID | Debt | Evidence | Consequence |
|----|------|----------|-------------|
| A-P0-1 | **Zero bloc / widget / router tests** | 5 pure-logic test files total; all 19 blocs, all repositories, `AppRouter.redirect` role-guard logic untested | Highest-risk untested code: auth redirect (`router_app.dart:112–157, 368–383`), `TeacherBloc` write paths, `ChatPermissionPolicy` |
| A-P0-2 | Singleton blocs never reset on logout — cross-user stale data | §2.1; carried from post-W2 P1-5 | A second user can briefly receive the previous user's halaqat, agenda, or roster |
| A-P0-3 | Analytics false zeros; no loading/error state | §3.4 item 1 | A network failure is presented as valid zero performance |
| A-P0-4 | Hard-coded certificate halaqa + wrong-halaqa award selection | §3.4 items 2–3 | Incorrect academy records/certificates |

#### Category A — P1 reliability / scale

| ID | Debt | Evidence |
|----|------|----------|
| A-P1-1 | Agenda N+1 + unbounded recitation read | §4.1 |
| A-P1-2 | Grade display label **is** the Firestore wire format | §2.6 |
| A-P1-3 | Roster `whereIn` unchunked (>30 students hard-fails) | §4.3; carried from post-W2 P1-2 |
| A-P1-4 | Assignment batch has no 500-op preflight (attendance does) | carried from post-W2 P1-1 |
| A-P1-5 | Write-on-read `_ensureHomeworkFields` inside live streams | §4.2; regression of post-W2 P1-3 |
| A-P1-6 | Raw `e.toString()` piped to users (~75 `ServerException(e.toString())` sites → `AppErrorWidget`/snackbars) | all datasources |
| A-P1-7 | Parent/supervisor/admin have no logout | §3.2 |
| A-P1-8 | Three week definitions; 8 weekday-name copies with spelling drift | §1.2 items 4–5; carried from post-W2 P1-7 |
| A-P1-9 | 4 latest-assignment query copies with no policy owner | §1.2 item 1 |
| A-P1-10 | Analytics includes pending recitations in grade mix | carried from post-W2 P1-6 |
| A-P1-11 | `TeacherBloc` combines six responsibilities | §2.1 |
| A-P1-12 | Teacher domain imports schedule data layer | §2.5 |

#### Category A — P2 maintainability / polish

TODOs (6, all product-deferral notes — mushaf lock, gamification, parent stream, admin workaround, hard-coded hadiths); ~90 deprecated `withOpacity` call sites; typo filenames (§2.5); stock README; no l10n framework (~2,375 Arabic-string lines across ~311 files — Accepted while Arabic-only); default lint set only; `com.example.rafiq_academy` package id; dead `_PlaceholderPage`; unreachable routes (§3.3); no `bloc_test`/`mocktail` dev-deps; posts comments error-as-empty bug (§1.5); missing shared empty-state widget; dead code removals listed in §2.7.

### 5.2 Category B — Platform Hardening / Release Readiness

These findings remain material release risks, but they are **not workflow prerequisites** and must not block W4. Maintain them as one explicit Release Readiness milestone to be completed before production release, after the product workflows are substantially complete.

| ID | Release-readiness debt | Evidence |
|----|------------------------|----------|
| B-R1 | No versioned `firestore.rules` | Zero project-wide matches for Firestore rules |
| B-R2 | No versioned `storage.rules` | Zero project-wide matches for Storage rules |
| B-R3 | `firebase.json` has no Firestore/Storage deploy blocks | It contains only FlutterFire platform config |
| B-R4 | `firestore.indexes.json` is incomplete (~11 live query composites missing; 2 apparently dead) | Query/index inventory in §4 and original audit |
| B-R5 | No CI or release pipeline | No `.github/workflows` or equivalent |
| B-R6 | No documented reproducible Firebase deployment process | Rules are absent and indexes appear console-managed |
| B-R7 | App Check / API-key restriction posture is unverified | Firebase client keys are committed (normal); backend enforcement cannot be verified |
| B-R8 | Academy-event delivery after attendance save is **at-most-once** | Verified W4 Slice 1/2: attendance commits first; idempotent transitions mean a failed `AcademyEventSink.publish` is not repaired by re-saving the same register. **Do not fix with client retries.** Eventual platforms: transactional outbox, server-side trigger, or event queue |

**Release Readiness target state:** versioned per-collection role/ownership rules; Storage path rules; deploy wiring for rules/indexes; reconciled composite-index manifest; CI (`flutter analyze` + `flutter test`); documented release command and environment ownership; durable academy-event delivery (B-R8) so parent projections survive a failed client publish.

### 5.3 Category-boundary rule

- A defect in current business behavior, data correctness, query design, architecture, or UX is **Category A**, even if it happens to involve Firestore.
- Rules, deployability, CI, App Check, release automation, and environment reproducibility are **Category B**.
- W4 may address Category A items that directly protect or simplify its workflow.
- W4 must **not** absorb Category B implementation. Category B is retained for the later Release Readiness milestone.

---

## 6. Updated roadmap & recommended W4

### 6.1 Candidate re-ranking

Scale: ● high / ◐ medium / ○ low. "Risk" = implementation risk (lower is better).

| Rank | Workflow | Product value | Academy value | Risk | Backend ready | Arch reuse | Maintainability | Notes |
|------|----------|:---:|:---:|:---:|:---:|:---:|:---:|-------|
| **1** | **Absence Awareness & Parent Day Signal** | ● | ● | ○ low | ● | ● | ● | See §6.2 |
| 2 | Teacher ↔ parent messaging completion | ◐ | ● | ◐ | ◐ | ● | ◐ | Chat exists but `ChatConversationsPage` unreachable, permission policy untested, conversations query unbounded + missing index — completing it is repair + product |
| 3 | Supervisor day-oversight (unmarked registers across teachers) | ◐ | ● | ○ | ● | ● | ● | Direct reuse of W3 agenda derivation per teacher; but supervisors currently can't even log out — parent loop matters first |
| 4 | Payments / fees completion | ◐ | ● | ● high | ○ | ◐ | ◐ | Cloud Function commented out (`parent_remote_datasource_impl.dart:156–173`); admin reads entire `payments` collection; requires Blaze + reconciliation decisions — backend NOT ready |
| 5 | Learning plan / memorization continuum | ● | ● | ● high | ○ | ◐ | ◐ | Biggest pedagogy design; needs stable daily ops (now true) *and* a settled recitation lifecycle vocabulary (§1.3) first |
| 6 | Full audio recitation path | ◐ | ● | ◐ | ○ | ● | ● | Still blocked on Storage/Blaze (`AppCapabilities`) — infra gate, not design gate |
| 7 | Admin dashboards | ○ | ○ | ◐ | ○ | ◐ | ◐ | Placeholder today; does not unlock daily operation |
| 8 | Gamification expansion | ○ | ○ | ◐ | ◐ | ◐ | ◐ | Not before core loops close |

### 6.2 Recommended W4 — **Absence Awareness & Parent Day Signal**

**One sentence:** when a teacher completes today's register, a parent whose child was marked absent learns about it the same day — and the orphaned استئذان (absence-excuse) API finally gets its product loop or gets removed.

**Why this beats every other remaining workflow:**

1. **It is the direct product consequence of W3.** W1–W3 closed the *teacher* loop: work is known, done, and honestly closed out. The data those workflows produce still reaches the parent only through a passive weekly card. Attendance marking is now reliable *because of W3* — which is precisely what makes a same-day absence signal trustworthy for the first time. Before W3 this feature would have fired on stale registers; now it fires on a register the agenda actively drives to completion. No other candidate is unblocked by W3 in this way.
2. **Highest academy value per unit of risk.** In a real Qur'an academy the absence conversation is the single most common parent–academy interaction. It builds the trust that retention and payment both depend on — and it must exist *before* messaging (rank 2) is useful, because absence is what parents message about.
3. **Backend is already there.** The `notifications` collection, schema, watcher, and badge are proven by W1 (assign/review notifications). `attendanceRecords` is the SSOT with deterministic day IDs. `absenceRequests` already has a write API waiting for an approve loop (Accepted W2 D3). **Zero new collections expected**; Phase 0 would confirm whether one `audience`-style field or a `parentId` recipient convention suffices within the existing schema.
4. **Maximum architecture reuse, minimum new surface.** The write trigger is the existing `SaveDayAttendanceEvent` success path; absence **signals** use explicit `'absent'` transitions via `AttendanceAbsenceTransitions` (not `AttendancePolicy.isAbsentStatus`, which treats null/unknown as absent for aggregates). The parent surface extends the existing weekly card + notifications inbox. This is W3-style orchestration of existing pillars — exactly the discipline the codebase is now good at.
5. **The alternatives each have a disqualifier today.** Messaging needs chat repair (unreachable page, untested permission policy, unbounded query) before it is a workflow rather than a fix-list. Payments' backend is demonstrably not ready (function commented out, full-collection scans). Learning plan needs the recitation vocabulary settled first. Supervisor oversight is valuable but observes a loop whose parent half doesn't exist yet. Admin/gamification do not unlock daily operation.

**Scheduling adjustment (approved after audit):** Platform Hardening does **not** gate W4. W4 Phase 0 may document the security assumptions around parent-facing notifications, but rules, deploy wiring, indexes-as-release-infrastructure, CI, and the production pipeline remain Category B and are deferred to the Release Readiness milestone.

**Explicitly OUT of W4 (proposed):** supervisor module, payments, messaging redesign, gamification, new attendance statuses, learning plans, any new collection without Phase 0 proof it cannot be avoided.

### 6.3 Updated roadmap (provisional — each step needs its own Phase 0)

| Step | Workflow | Gate |
|------|----------|------|
| **W4** | Absence Awareness & Parent Day Signal | Phase 0 product decisions; no Platform Hardening gate |
| W5 | Teacher ↔ parent messaging completion | Chat repair audit (reachability, permission tests, query bounds) |
| W6 | Supervisor day-oversight | Reuses W3 agenda derivation; add supervisor logout first |
| W7 | Payments completion | Blaze + Cloud Function readiness; reconciliation decisions |
| W8 | Learning plan / memorization continuum | Terminology glossary (§1.3) + recitation lifecycle settled |
| Category A debt track | §2.7 + §5.1, sliced small | May join a workflow only when it improves that workflow |
| Release Readiness milestone | Category B (§5.2) | After product workflows are substantially complete; before production release |

### 6.4 Audit conclusion

| Question | Answer |
|----------|--------|
| Are W1+W2+W3 one product? | **Yes for the teacher — the daily loop is closed and honestly reported.** |
| Biggest coherence gaps? | Terminology (5 names for assignment), missing empty-state/calendar/assignment-policy owners, unmigrated day-normalization call sites. |
| Biggest architecture risks? | `TeacherBloc` size, singleton logout leak, teacher-domain→schedule-data import, grade label as wire format. |
| Biggest platform risk? | **No security rules in source; indexes undeployable and incomplete.** |
| Biggest product gap? | **The parent never learns about an absence the day it happens.** |
| Recommended W4? | **Absence Awareness & Parent Day Signal.** Platform Hardening is tracked separately and does not gate it. |
| Ready to code W4? | **No — awaiting approval of this audit and a W4 Phase 0 design.** |

---

*End of post-W3 audit. No code was modified; the only artifact is this report file. No commits, no pushes.*
