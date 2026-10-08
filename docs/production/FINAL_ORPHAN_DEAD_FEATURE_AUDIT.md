# Final Product Orphan & Dead-Feature Audit (Audit Only)

> **Scope:** the whole repository across Admin, Supervisor, Teacher, Parent and Student.
> **Mode:** read-only. Nothing was deleted, refactored, renamed or rewritten, and no rules, schema, commit, push or deploy changes were made. This file is the only artifact created.
> **Authority for contradictions:** `docs/production/PRODUCT_DECISIONS_LOCKED.md` (D1–D24, including D7.1).
> **Mushaf authority:** `docs/production/MUSHAF_UX_SPEC.md` (appendices C–F). Figma is not used as Mushaf authority, and Mushaf is not redesigned here.
> **Economy rule:** `coins`, `points`, `totalStars`, avatars, awards/achievements and badges are audited **separately** and never merged.
> **Out of scope:** PH-02 is CLOSED (see `PH02_CLOSURE_PATCH_REPORT.md`) and is not reopened. PH-02 items appear here only as a dependency or as evidence.

---

## A. Current baseline

| Item | Value |
|---|---|
| Branch | `feature/parent-interface` |
| HEAD | `90201f100bbe3c09e4ef169bc37f739b58cac34d`: "test(security): complete Wave A test strategy" |
| Recent commits | `90201f1`, `4be8a3c`, `8424b3b`, `146d2a1`, `4cfc7f3`, `3154e15`, `35be67f`, `fd6e756` |
| Working tree | Dirty before this audit: 82 modified, 1 deleted (`lib/shared/data/academy_admission_firestore.dart`), 44 untracked, plus 1 `rules_test/node_modules` entry. Most of it is uncommitted PH-01/PH-02 work. This audit added one untracked file, this report. |
| Flutter / Dart | Flutter 3.44.9 stable, Dart 3.12.2 |
| `flutter analyze` | Re-run during this audit: 120 issues (0 errors, 7 warnings, 113 infos), the same as the PH-02 baseline; 0 new. Log: `build/ph01/orphan_analyze.log`. |
| Flutter tests | Latest full run on an identical Dart tree: 693 passed, 2 skipped. 105 `*_test.dart` files. |
| Rules tests | 170/170 (`firestore`, `storage`, `ph01`, `ph02` suites) |
| Functions unit tests | 237/237 |
| PH-02 emulator suite | 50/50 (`demo-rafiq-rules` only) |
| Docs | 90 files under `docs/` |
| Router | Single flat `GoRouter` (`lib/core/router/router_app.dart`) with 35 `GoRoute`s and no `ShellRoute`. Role shells are `IndexedStack`s. |
| State | 21 Blocs, 0 Cubits. DI uses injectable/get_it (`lib/core/di/injection_container.config.dart`). |

---

## B. Executive summary

The product is **materially incomplete in four places that block production use**:

1. **Parent ↔ child linking.** `childrenIds` has no writer.
2. **Admin has no UI at all.** This includes payment-proof review.
3. **Halaqa/schedule creation (D8)** exists only in the Firebase console.
4. **Students cannot honestly earn homework coins.** The server requires recitation tasks, but audio uploads are disabled.

Dead code is moderate and concentrated in:
- the retired H-era academy-event pipeline;
- pre-Mushaf Student legacy;
- unrouted Calendar/Register pages;
- test-only contract classes.

The Mushaf reader stack is **active** and must be kept. The Student audio-library stack is **unreachable**, which is a genuine product decision, not a removal candidate yet.

| Classification | Count |
|---|---|
| KEEP | 28 |
| COMPLETE | 33 |
| QUARANTINE | 14 |
| REPLACE | 7 |
| REMOVE | 21 |
| DECISION REQUIRED | 8 |
| **Total candidates** | **111** |

The IDs are `K-xx` (keep inventory), `OA-xx` (backlog) and `E-xx` (economy). Gaps in the OA numbering are intentional: those IDs were merged into E-items or into OA-02.

---

## C. Route / page inventory

Source: `lib/core/router/router_app.dart`, `lib/core/router/app_routes.dart` and the role shells.

| Role | Route / entry | Page | Reachable from UI | Status |
|---|---|---|---|---|
| Auth | `/splash` | SplashPage | initial | KEEP |
| Auth | `/login` | LoginPage | redirect | KEEP |
| Auth | `/forgot-password` | ForgotPasswordPage | login link | KEEP |
| Auth | *(none)* | `RegisterPage` (`features/auth/presentation/pages/register_page.dart`) | **No**: no route and no import | REMOVE (OA-52, D1) |
| Student | `/student` shell tab 0 | StudentHomePage | yes | KEEP |
| Student | tab 1 / `/student/mushaf` | Mushaf reader (MushafReaderHost) | yes (tab + push) | KEEP (duplicate entry, K-25) |
| Student | tab 2 / `/student/badges` | StudentBadgesPage | yes (tab + push) | KEEP |
| Student | tab 3 "خريطتي" | placeholder | yes | DECISION (OA-31) |
| Student | tab 4 profile | StudentProfileTab | yes | KEEP |
| Student | `/student/audio` | StudentAudioLibraryPage → AllRecitersPage | **No**: the only push (student_home_page:262) runs when `latestAssignment == null`, and in that case student_daily_task_widget:71–86 renders no button | DECISION (OA-30) |
| Student | `/student/recitation` | StudentRecitationPage | yes (homework) | KEEP |
| Student | `/student/homework`, `/student/activities`, `/student/schedule`, `/student/progress`, `/student/review-schedule`, `/student/streak`, `/student/settings`, `/student/avatar-shop`, `/student/notifications`, `/student/chat`, `/student/content-library` | respective pages | yes | KEEP, except content library (OA-33) and streak (E-12) |
| Student | *(none)* | `StudentMushafDashboard` | **No**: a test asserts it is unused | REMOVE (OA-45) |
| Teacher | `/teacher` shell (dashboard, halaqa, awards tab, chat, profile) | Teacher shell tabs | yes | KEEP |
| Teacher | `/teacher/halaqa/:id/attendance`, `/evaluations`, `/awards`, `/analytics`, `/homework`, `/activities`, `/absences` | standalone pages, also embedded as tabs | yes | KEEP (K-25) |
| Teacher | `/teacher/student/:id` | `StudentProfilePage` (lives in `features/student/…`) | yes | KEEP (misplaced folder, OA-66) |
| Parent | `/parent` shell (home, children, notifications, subscriptions) | Parent shell tabs | yes | KEEP |
| Parent | `/parent/subscriptions`, `/parent/notifications`, `/parent/reports` | pages | yes | KEEP. Reports have a bug (OA-08). |
| Parent | child detail pages | `MaterialPageRoute` (`parent_destinations.dart:21`) | yes, but not deep-linkable | KEEP |
| Supervisor | `/supervisor` | SupervisorHomePage (day board, admission, escalation) | yes | KEEP. No logout (OA-06). |
| Admin | `/admin` | AdminHomePage: empty state "واجهة الإدارة غير مفعّلة بعد" | yes | COMPLETE (OA-02) |
| — | *(none)* | `CalendarPage` (`features/calendar/...`) | **No**: route removed in H6 | QUARANTINE (OA-34) |
| Dev | *(none)* | `TeacherExcusesPreviewApp` | No: dev host | REMOVE (OA-53) |

Unused route constants: `AppRoutes.studentEvals`, `studentNotifs`, `teacherHalaqa`, `teacherStudent` (OA-57).

---

## D. Navigation audit

| Finding | Evidence | Class / ID |
|---|---|---|
| `AuthError` falls through the redirect (returns `null`), and an unknown role is stuck on `/login` | `router_app.dart` redirect | COMPLETE, OA-05 |
| Supervisor and Admin shells have no logout control | supervisor/admin home pages | COMPLETE, OA-06 |
| The Supervisor allowlist `startsWith('/teacher/halaqa/')` also opens `/awards` and `/analytics`. AwardsPage has no role check; the server still enforces scope. | `router_app.dart` guard | COMPLETE, OA-07 |
| No client-side ownership check on `:halaqaId` / `:studentId`. Rules and callables enforce it. | router | KEEP (server-authoritative), noted |
| `debugLogDiagnostics: true` in the production router | `router_app.dart:154` | COMPLETE, OA-13 |
| Dead route `/student/audio` (see C) | home_page:262 vs daily_task_widget:71–86 | DECISION, OA-30 |
| Duplicate entry points (tab + pushed route) for badges, Mushaf, awards, attendance/evaluations and subscriptions | shells + router | KEEP, K-25. A second Mushaf instance via push is noted in OA-43. |
| Two notification surfaces: `NotificationsPage` (student/teacher) and `ParentNotificationsPage` | features/notifications, features/parent | REPLACE, OA-63 |
| Stale navigation comments | `lib/shared/.../h6_surface_cleanup.dart` | REPLACE (docs-as-code), OA-37 |
| No deep links from push taps | see J | COMPLETE, OA-11 |

---

## E. UI action audit (UI → Bloc → UseCase → Repo → DataSource → Firebase)

| UI action | Chain | Firebase sink | Status |
|---|---|---|---|
| Teacher records attendance | AttendancePage → TeacherBloc → RecordSessionAttendanceUseCase → repo → callable DS | `recordSessionAttendance` | KEEP (K-01) |
| Teacher evaluates | EvaluationsPage → TeacherBloc → UpsertSessionEvaluation → callable | `upsertSessionEvaluation` (24h, D7.1) | KEEP (K-02). No client 24h awareness (OA-16). |
| Teacher creates homework | HomeworkPage → TeacherBloc → CreateAssignment → Firestore DS | `assignments` + CF `notifyOnAssignmentCreated` | KEEP (K-04) |
| Teacher reviews submission | → HomeworkBloc/TeacherBloc → Firestore tx | `assignments` | KEEP (K-03). No reviewer/timestamp (OA-44). |
| Teacher grants award | AwardsPage → AwardsBloc → GrantAward → callable | `grantAward` | KEEP (E-10). Retry double-credit (E-03). |
| Student ticks homework / completes | HomeworkPage → HomeworkBloc → CompleteHomework → callable | `completeHomework` | **Blocked** for recitation tasks (E-07) |
| Student buys avatar | AvatarShopPage → StudentBloc → PurchaseAvatar → callable | `purchaseAvatar` | KEEP (E-04/05). Labels wrong (E-06). |
| Student reads Mushaf | MushafReaderHost → MushafBloc/MushafAudioBloc → C15 DS | `mushafReading` + prefs mirror | KEEP (K-13/14) |
| Student opens audio library | *(unreachable)* → AudioBloc → `listeningProgress` | `listeningProgress.add()` every ~5s | DECISION (OA-30) |
| Student submits recitation audio | HomeworkBloc `SubmitRecitation` (never dispatched) | Storage `recitations/…` (denied) | QUARANTINE (OA-71) |
| Parent uploads payment proof | SubscriptionsPage → ParentBloc → UploadProof → Storage + Firestore | `payment_proofs/`, `paymentProofs` | KEEP (K-09). **No reviewer UI (OA-03).** |
| Parent opens weekly report | ParentReportsPage reads `state.weeklyReport` | — | **Always empty**: `LoadWeeklyReportEvent` is never dispatched (parent_bloc:164/185), OA-08 |
| Parent submits absence | Parent → AbsenceBloc → Firestore | `absenceRequests` | KEEP (K-08) |
| Supervisor admits student | SupervisorHome → SupervisorBloc → AdmitStudent → callable | `admitStudentToHalaqa` | KEEP (K-07). Dialogs show raw studentIds (OA-26). |
| Supervisor issues achievement | SupervisorBloc.IssueAchievement → Firestore | `achievements` (record-only, client clock) | DECISION (E-11) |
| Admin anything | AdminHomePage placeholder; AdminBloc handles only `ClearAdminSessionEvent` | — | COMPLETE (OA-02) |
| Chat send / delete | ChatBloc → Firestore / callable | `chats` | KEEP (K-10). Edit/media not wired (OA-24). |
| Post create / like / comment | PostsBloc → Firestore | `posts` | KEEP (K-26). Delete/pin are dead (OA-61). Audience: OA-32. |
| No-op / "قريباً" actions (12) | student_home_page:719–728; settings_page:25–31, 51–69; teacher_profile_tab:71, 531–562 (language row :539–546); chat_room:342–349 (`onPressed: null`); teacher_dashboard_tab:521–528 (search snackbar); posts_list_page:707 (`onTap: () {}`) | — | COMPLETE (OA-26), language rows REMOVE (OA-27) |
| Fake values in UI | teacher_profile_tab:287/297/350/395; streak/level 0/1 | — | QUARANTINE (E-12), COMPLETE (OA-26) |

---

## F. Bloc / state audit

| Bloc | Status | Notes |
|---|---|---|
| AuthBloc | KEEP | The register event/use case is dead (OA-52) |
| StudentBloc | KEEP | Its monthly review schedule stack duplicates `features/review_schedule` and wastes a read on every refresh (OA-40). Its latest-homework watch overlaps HomeworkBloc (OA-65). |
| HomeworkBloc | KEEP | `SubmitRecitation` is never dispatched (OA-71) |
| TeacherBloc, ScheduleBloc, ChatBloc, NotificationsBloc, AbsenceBloc, ParentBloc, SupervisorBloc | KEEP | ParentBloc: `LoadWeeklyReport` is never dispatched (OA-08). SupervisorBloc: `SubmitSupervisorReport`/`ResetSubmitReport` are dead (OA-36). |
| MushafBloc, MushafAudioBloc | KEEP | `MushafPersistPosition`/`ToggleChrome` dead events and test-only `MushafAudioClearError` are out of scope (Mushaf not redesigned) and noted only |
| AudioBloc (library) | DECISION (OA-30) | `listeningProgress` `id: ''` → `.add()` loop (audio_bloc:508, DS:191). Its `close()` disposes the LazySingleton `AudioPlayerService` (audio_bloc:529). |
| AwardsBloc, AnalyticsBloc, ContentLibraryBloc | KEEP / DECISION | AnalyticsBloc is bypassed by direct `sl<GetHalaqaAnalyticsUseCase>` (OA-65). ContentLibrary: OA-33. |
| CalendarBloc | QUARANTINE (OA-34) | No routed UI; all events dead |
| AdminBloc | COMPLETE (OA-02) | Only `ClearAdminSessionEvent`; admin use cases unreachable |
| CertificateBloc / upload / posts dead events | QUARANTINE (OA-61) | `GenerateCertificate`, `DeleteFile`/`ResetUpload`, `DeletePost` (rules-denied)/`TogglePin` |
| Root providers | REMOVE (OA-55) | `main.dart:60–76` provides `BlocProvider.value` for **factory** Analytics/Awards/Calendar/ContentLibrary blocs. These instances are never consumed and never closed. |

---

## G. Domain / data audit

| Area | Finding | ID |
|---|---|---|
| Use cases with no caller | GetLatestAssignment (+ repo :27/:83, DS :179); GetLatestHomework; RecordAttendance (superseded by callable); AddRecitationRecord (rules-denied) | OA-47/48/49/50 |
| Use cases reachable only through dead AdminBloc | 8 billing use cases plus 4 Params, ProvisionUser (test-only), admin user management | OA-02 (wire, don't remove) |
| Student search client stack | 4 use cases plus studentSearch DS unused; the server projection is live | OA-28 |
| EditChatMessage | use case + DS `editMessage`, no UI | OA-24 (D20) |
| Zero-caller methods | `attachMirroredPostId`, `watchChildrenAssignments`, `getSurahAudioById` | OA-59 |
| Zero-reference classes/functions | ClassSessionModel, MushafQuranBundle, AppConstantsVersion, TeacherHomeStatTile, TeacherPulse, ParentProfileHeaderSkeleton, AppSkeletonLine, AppSkeletonCircle, halaqaScheduleLabel, formatTimeHm24, formatDateYmd, dateTimeFromFirestore, parentLinkedChildNames, mushafAudioStatusLabel, mushafAyahCountLabel, teacherSkeletonBar/Card, parentSkeletonCard, escalationWhereLabel, kLegacyReciterId | OA-58 |
| Test-only production code | AcademyMembershipConsumption, HalaqaGroupChatContract, SessionConflictContract, StudentStatusComposition, H6SurfaceCleanup, AcademySessionModel/Entity, HalaqaScheduleSlotModel, HalaqaActivitiesMockStore, formatStudentProfileJoinDate, RecitationGradeLabel.isPositive | OA-62, OA-54 |
| Academy event pipeline | `AcademyEventSink = FanOutAcademyEventSink(handlers: [])`; InAppAcademyEventHandler → observer resolver → signal composer → `upsertSignals` (rules-denied) is a dead chain | OA-38, OA-39 |
| Duplication | `HalaqaIdParams` defined 3×; pages call use cases via `sl<>` | OA-65 |
| Naming | Supervisor repository file `parent_repository.dart`; `notifiaction_repository.dart` (sic) | OA-66 |
| Legacy repair write | `assignment_homework_fields_ensure.dart:28–31` merge-sets `isSubmitted`, which rules deny on legacy docs | OA-09 |

---

## H. Firestore collection / field matrix

| Collection | Writers | Readers | UI consumer | Function consumer | Rules | Status |
|---|---|---|---|---|---|---|
| users | adminProvisionUser, admin lifecycle CFs | all roles (own) | all | many | yes | KEEP |
| users.`childrenIds` (parent) | **only `[]` at provisioning** (`adminProvisionUser.ts:63`); demo seeder (rules-denied) | academyNotificationStore:42, paymentReview:214, adminBilling:50, processOverdueGrace:53/184, loadChatRelationships:66, rules `isLinkedParentOf` | parent shell | yes | yes | **COMPLETE, P0 (OA-01)** |
| studentProfiles | admit/transfer CFs, economy CFs | student/teacher/parent | yes | yes | yes | KEEP. Fields: see below. |
| studentProfiles.overallProgressPercent, totalVersesMemorized, completedJuz, completedSurahs, currentPlanName | none | student/parent UI | shows 0 / empty | — | — | COMPLETE (OA-19, D11 Wave C) |
| studentProfiles.streakDays, level | none | home, header, streak page, parent, teacher | fake 0 / 1 | — | — | QUARANTINE (E-12) |
| studentProfiles.halaqaName | not refreshed on admit/transfer | UI | stale | — | — | COMPLETE (OA-18) |
| studentProfiles.badges | none | none | — | — | — | REMOVE (E-13) |
| studentProfiles.profileImageUrl | none (no Storage writer) | UI | placeholder | — | — | COMPLETE (OA-25) |
| studentProfiles.coins / points / totalStars / avatarId / unlockedAvatarIds / lastCompletedHomeworkId | economy CFs | see K | see K | — | server-only | see K |
| teacherProfiles.name / halaqatIds | none maintained | UI | stale | — | yes | COMPLETE (OA-29) |
| parentProfiles | provisioning | parent | yes | — | yes | KEEP |
| halaqat | **console only** | all | yes | yes | yes | COMPLETE (OA-04, D8) |
| sessions / sessionConflictLocks / studentMembershipLocks / notificationDeliveries | CFs only | CFs | none (sessions: no client reader) | yes | server-only; studentMembershipLocks default-deny | KEEP (K-23); explicit rule P3 (OA-73) |
| attendance / evaluations | PH-02 callables | teacher/parent/student | yes | yes | yes | KEEP. Admin correction overwrites `recordedBy` (noted in O). |
| assignments | teacher client; student homework fields; CF | yes | yes | economy | yes | KEEP. `postId` is read but never written (OA-59). |
| achievements | grantAward CF; Supervisor client (record-only) | yes | yes | — | yes | KEEP / DECISION (E-11) |
| awards | grantAward | yes | yes | — | server-only | KEEP |
| paymentProofs | parent client | supervisor/parent | parent only | reviewPaymentProof (no caller) | yes | COMPLETE (OA-03, OA-21) |
| invoices / subscriptions | admin CFs | parent/supervisor | yes | yes | yes | KEEP; admin UI is OA-02 |
| absenceRequests | parent / teacher | yes | yes | — | yes | KEEP. `reviewedAt` is never written (OA-44). |
| notifications | CFs + admin DS | student/teacher/parent | yes | yes | yes | KEEP. `data` is never read; `readBy` grows (OA-73). |
| chats / messages | client + CFs | yes | yes | yes | yes | KEEP |
| posts | teacher | **teachers only** | teacher | — | yes | DECISION (OA-32) |
| auditLogs | CFs only | admin | none (no admin UI) | yes | server-only | KEEP (K-21) |
| studentSearch | CF projection | — | none | yes | yes | KEEP (K-22) / client OA-28 |
| mushafReading | client (C15) | client | yes | — | yes | KEEP (K-14) |
| listeningProgress | AudioBloc `.add()` | AudioBloc | unreachable | — | yes | DECISION (OA-30) |
| surahAudios | seed | audio library | unreachable | — | yes | DECISION (OA-30) |
| reciters | none | **0 Dart reads** | — | — | yes | REMOVE (OA-67) |
| halaqaActivity (legacy, singular) | none | none | — | — | admin-read | REMOVE (OA-68) |
| halaqaActivities | teacher/student | yes | yes | — | yes | KEEP (K-05) |
| reviewSchedules | **none** | student review-schedule page, StudentBloc | always empty | — | yes | COMPLETE (OA-20) |
| calendarEvents | CalendarBloc (unrouted) | — | none | — | yes | QUARANTINE (OA-34) |
| complaints | **none possible** | admin rule only | none | — | yes | QUARANTINE (OA-35) |
| supervisorReports | unreachable event | none | none | — | yes | QUARANTINE (OA-36) |
| contentLibrary | staff upload (unrouted) | student page | student | — | yes | DECISION (OA-33) |
| wallets | Paymob (unexported) | none | none | — | yes | QUARANTINE (E-14, D2) |
| supervisorProfiles | none | none | none | — | yes | QUARANTINE (OA-70, D24) |

Probably missing indexes for: listeningProgress, reviewSchedules, contentLibrary, calendarEvents, and attendance `recordedBy`+`date`. These are only needed if the features are kept (OA-73).

---

## I. Storage matrix

| Path | Writer | Reader | Rules | Status |
|---|---|---|---|---|
| `payment_proofs/` | parent | supervisor/admin | yes | KEEP. No cleanup (OA-73). |
| `posts/` | teacher | teachers | yes | KEEP. No cleanup. |
| `halaqa_activities/` images | teacher/student | halaqa | yes | KEEP |
| `halaqa_activities/` audio | code path exists | — | **denied** | QUARANTINE (OA-71) |
| `recitations/` | `SubmitRecitation` (never dispatched); gate `audioUploadsEnabled=false` (`app_constants.dart:103`) | — | **denied** | QUARANTINE (OA-71) / DECISION (OA-15) |
| `profile_images/` | **none** | UI expects URL | yes | COMPLETE (OA-25) |
| `chat_media/`, `voice/`, `attachments/` | **none** (chat is text-only) | — | yes | COMPLETE (OA-24, D20) |
| `content_library/` | staff upload (unrouted) | student | yes | DECISION (OA-33) |

---

## J. Notification / FCM matrix

| Type | Generator | Recipients | Client handling | Status |
|---|---|---|---|---|
| evaluation (live) | CF `evaluationNotification` + push gate | parents only | in-app list; tap = mark read | KEEP (K-12) |
| homework / assignment | CF on create | students | in-app | KEEP |
| homework_reviewed | defined; never fires in practice | — | — | QUARANTINE (OA-23) |
| session_reminder, achievement, payment, message | **never generated** | — | enum mapping only | QUARANTINE (OA-23) |
| admin broadcast | admin DS | role/all | in-app; `readBy` grows and exposes readers | COMPLETE (OA-02, OA-73) |
| FCM token register | client | — | yes | KEEP |
| `disableDeviceToken` | client merge-set | — | fails when the doc doesn't exist | COMPLETE (OA-73) |
| Foreground / opened / initial message | **no `onMessage`, `onMessageOpenedApp` or `getInitialMessage` handler**; no deep links | — | — | COMPLETE (OA-11, D19) |
| Supervisor / Admin inbox | none watch notifications | — | — | COMPLETE (OA-22) |
| Teacher CF types | none except broadcast | — | — | COMPLETE (OA-22) |

Stale comment: `functions/src/.../evaluationNotification.ts:57` (OA-37).

---

## K. Economy audit

The kinds of value are kept separate. **Coins ≠ points ≠ stars.**

| ID | Item | Writer | Reader | Evidence | Class | Priority |
|---|---|---|---|---|---|---|
| E-01 | `coins` | `completeHomework` (+= reward), `purchaseAvatar` (−) | header, avatar shop | **Forgeable**: the student may rewrite `tasks`/`kind` (studentOwnHomeworkUpdate, rules ~566–573), and recitation records need no audio (rules 456–463). **Re-creditable**: the Teacher update branch freezes only identity fields (~573–575), so a Teacher can reopen completed homework. Labels are mixed: the dialog says "ربحت X نقطة", the header says "عملة", and the avatar shop says "نقطة". | COMPLETE | P1 |
| E-02 | `points` | `completeHomework` (+= reward) | **no reader** | Purpose is undefined in the locked decisions | DECISION REQUIRED | P1 |
| E-03 | `totalStars` | `grantAward` | badges, profile | Retry double-credits because the client generates a new awardId each call (`award_remote_datasource_impl.dart:101`) | COMPLETE | P1 |
| E-04 | `avatarId` | `purchaseAvatar` / select | student's own screens only | Avatars are not shown to other roles (corrects the PH-02 docs) | KEEP | — |
| E-05 | `unlockedAvatarIds` | `purchaseAvatar` | avatar shop | — | KEEP | — |
| E-06 | Avatar catalog / shop | Dart and TS catalog copies | shop | Two catalog sources; label "نقطة" for coins; premium avatars unreachable | COMPLETE | P1 |
| E-07 | `completeHomework` | callable | HomeworkBloc | `economyFunctions.ts:124–127` requires **all** tasks complete, and recitation tasks must reference a matching recitationRecord. The client `requiredTasks` (`homework_entity.dart:116–122`) skips recitation because `audioUploadsEnabled=false`. **Honest completion with a recitation task always fails, so coins can't be earned.** There are also no roster, lifecycle or payment checks. | COMPLETE | **P0** |
| E-08 | `lastCompletedHomeworkId` | `completeHomework` | **no reader** (lib + functions) | Dead write | REMOVE | P3 |
| E-09 | `tasks[].points` | teacher client | display | Client-editable display value the server ignores | REPLACE | P3 |
| E-10 | `grantAward` | callable | awards | Server-authoritative (PH-02) | KEEP (fix via E-03) | — |
| E-11 | Supervisor record-only achievements | SupervisorBloc (client clock) | badges | B7: should Supervisor achievements credit stars? | DECISION REQUIRED | P2 |
| E-12 | `streakDays` / `level` | none | home, streak page, header, parent, teacher | Fixed fake values (0 days / level 1). TODO at student_home_page:199: "points/streak logic not designed". | QUARANTINE | P1 |
| E-13 | `badges` field | none | none | Badges are computed from achievements | REMOVE | P3 |
| E-14 | Wallet / Paymob | `paymobWebhook.ts` (unexported) | none | D2: manual payments only. If re-exported, the webhook would set paid with no audit. | QUARANTINE | P3 |

No XP, leaderboard or shop beyond avatars exists. That is consistent with the locked decisions; do not add any.

---

## L. Student legacy audit

| Item | Current entry point | Current consumer | Old consumer | Replacement | Migration | Safe removal |
|---|---|---|---|---|---|---|
| StudentMushafDashboard | none | none (a test asserts it is unused) | pre-C15 dashboard | Mushaf tab (MushafReaderHost) | none | **Yes** (OA-45). Remove the asserting test with it. |
| `student_hadith_widget.dart` | none | 0 importers (one-line export) | old home | direct import | none | **Yes** (OA-46) |
| GetLatestAssignment chain | none | none | old daily task | HomeworkBloc watch | none | **Yes** (OA-47) |
| StudentMushafPage fallback loader (:230–248, :286–341), `AyahModel.fromJson`, `preferredSurah` | inside an active page | dead branch | pre-QuranText loader | QuranText datasource | none | **Yes** (OA-51). Keep the text 'تعذر تحميل المصحف' (test-asserted). |
| Monthly review schedule in StudentBloc | home refresh | StudentBloc state | old home card | `features/review_schedule` | none (no writer anyway) | After bloc/state edits (OA-40, REPLACE) |
| AddRecitationRecord | none | none | old recitation | — (rules deny) | none | **Yes** (OA-50) |
| `formatStudentProfileJoinDate`, `RecitationGradeLabel.isPositive` | none | tests only | old profile | — | none | With tests (OA-62) |
| StudentProfilePage (student folder) | teacher route | Teacher | — | — | move only | No. Active (OA-66). |
| Device-local `savedRecordings` (student_recitation_page:123–148) | recitation page | SharedPreferences (not per-user) | — | server recitations (gated) | per-user keying if kept | No (OA-72, QUARANTINE) |
| Audio library (StudentAudioLibraryPage, AllRecitersPage, AudioBloc, listeningProgress, surahAudios) | **unreachable** route | none | old home button | Mushaf audio (partial) | — | **No.** Product decision (OA-30). |

---

## M. Mushaf legacy audit

| Item | Status | Evidence |
|---|---|---|
| MushafReaderHost / MushafBlocScope / MushafBloc / MushafAudioBloc / JustAudioMushafEngine | KEEP (ACTIVE) | Student tab 1 + `/student/mushaf` |
| C15 `mushafReading` + per-student mirror `mushaf_last_read_v1_<uid>` | KEEP | MUSHAF_UX_SPEC appendices C–F match the code |
| Legacy pref `last_mushaf_page` | KEEP (compat): removed on write only | Do not remove the compat removal |
| Recitation mode (text 'وضع التسميع', test-locked) | QUARANTINE (OA-42) | Reachable by URL only |
| Mushaf audio keeps playing on tab switch; a second reader instance is created via push | COMPLETE (OA-43) | Two players could play together |
| `MUSHAF_UX_AUDIT.md` | REPLACE (mark historical) | Stale vs the spec |
| `MushafQuranBundle`, `mushafAudioStatusLabel`, `mushafAyahCountLabel` | REMOVE (OA-58) | Zero references |

No Mushaf redesign is proposed.

---

## N. Duplication / reuse

| Duplicate | Locations | Class |
|---|---|---|
| Notification lists | NotificationsPage vs ParentNotificationsPage | REPLACE (OA-63) |
| Stat cards (~10), bespoke skeleton animations (7), empty states, search bars, status/filter chips, award cards, progress widgets | across features | REPLACE (OA-64) |
| `_EvaluationCard` ×3 | teacher, parent, student | REPLACE (OA-64) |
| just_audio instances ×5 | Mushaf engine, AudioPlayerService, recitation, activities, chat | COMPLETE via OA-43 / DECISION via OA-30 |
| Latest-homework watch ×2 | StudentBloc + HomeworkBloc | REPLACE (OA-65) |
| `HalaqaIdParams` ×3 | domain | REPLACE (OA-65) |
| Avatar catalog ×2 | Dart + TS | COMPLETE (E-06) |

---

## O. Backend ownership

| Data | Owner | Writer | Reader | Authorization | Audit | Gap |
|---|---|---|---|---|---|---|
| Parent ↔ child link | Admin (D12) | **none** | CFs, rules | — | — | OA-01 |
| Attendance | Teacher; Admin correction | callable | roles | server | C16 | An Admin correction overwrites `recordedBy` (P3, OA-73) |
| Evaluation | Teacher (24h); Admin correction | callable | roles | server, D7.1 | C16 | — |
| Payment proof review | Admin/Supervisor | `reviewPaymentProof` (**no caller**) | parent | server | C16 | The audit omits the confirmed amount. On resubmit the parent client deletes `reviewedBy`/`reviewedAt`/`reviewNotes`/`amountPaidConfirmed`/`remainingAmount`, and the rules allow it. (OA-21) |
| Overdue / suspension | system | `processOverdueGrace` | parent/student | server | **not audited** | OA-21. D5 is enforced as a banner only (OA-10). |
| Membership | Supervisor/Admin | admit/transfer callables | roles | server | C16 | Student screens use only the primary `halaqaId`; supervisor payment scope uses the primary halaqa only (OA-17) |
| Homework review | Teacher | client tx | roles | rules | none | No reviewer or timestamp (OA-44) |
| Assignments `createdAt` | Teacher | client clock | — | rules | — | Timestamp inconsistency (OA-73) |
| Supervisor achievements | Supervisor | client (client clock) | roles | rules | none | E-11 |
| `sessions.updatedAt` | CF / teacher | accepts any client value | — | rules | — | OA-73 |
| Halaqa | Admin (D8) | console only | all | — | — | OA-04 |

Stale rules comment at `firestore.rules` 909–911 (OA-37; documentation only, no rule change).

---

## P. Security orphan audit

| Finding | Risk | Class |
|---|---|---|
| Rule blocks for orphan collections: `reciters`, `halaqaActivity` | Low (extra surface) | REMOVE (OA-67/68) in a rules wave |
| Rules for unreachable features: `calendarEvents`, `complaints`, `supervisorReports`, `contentLibrary` writes | Low | QUARANTINE / DECISION |
| Student can rewrite `tasks`/`kind` on own homework, so the coin reward can be forged | **Medium (economy integrity)** | COMPLETE (E-01) |
| Teacher can reopen completed homework, so coins can be re-credited | **Medium** | COMPLETE (E-01) |
| Recitation record accepted without audio or assignment match | Medium | COMPLETE (E-01) |
| Award retry double-credits stars | Medium | COMPLETE (E-03) |
| Parent can delete review fields on proof resubmit | Medium (audit integrity) | COMPLETE (OA-21) |
| `readBy` on broadcasts reveals who read it | Low–Medium (privacy) | COMPLETE (OA-73) |
| Supervisor UI allowlist exposes awards/analytics pages | Low (server enforces) | COMPLETE (OA-07) |
| Paymob webhook would set paid without audit if re-exported | Low (unexported) | QUARANTINE (E-14) |
| `upsertSignals` client write path (rules-denied) | None (dead) | REMOVE (OA-38) |
| `debugLogDiagnostics: true` logs routes in release | Low | COMPLETE (OA-13) |

No rule changes were made in this audit.

---

## Q. Test audit

| Category | Items | Class |
|---|---|---|
| Dead tests (test dead production code) | `student_activities_ui_batch`, `teacher_tasks_ui_batch` (mock store); `academy_membership_*`; `h6_surface_cleanup_test` | QUARANTINE (OA-74); remove with OA-54/OA-62 |
| Legacy tests | signal composer, observer resolver, event-publication/sink tests | QUARANTINE (OA-74); remove with OA-38 |
| Brittle | `teacher_home_figma_capture_test` | QUARANTINE (OA-74) |
| CI gaps | `rules_test npm test` runs only `firestore.rules.test`; `test:all` omits ph01/ph02; the PH-02 emulator suite is not in `functions npm test` | COMPLETE (OA-14) |
| No `integration_test/` | — | COMPLETE (OA-14) |
| Uncovered flows | parent child linking (none exists); payment review end-to-end; homework completion with a recitation task; teacher-reopen re-credit; award retry idempotency; router `AuthError`/unknown-role redirect; supervisor allowlist; push open handling; parent weekly report load; suspension gating; audio library | COMPLETE (pair with each fix) |

---

## R. Documentation audit

Contradictions are judged against `PRODUCT_DECISIONS_LOCKED.md`.

| Doc | Issue | Class |
|---|---|---|
| `IMPLEMENTATION_PLAN.md` | "Planned" rows, `/register` (contradicts D1), wallet (contradicts D2) | REPLACE (OA-37) |
| `SECURITY_IMPLEMENTATION_SPEC.md` | The §10.1 table is internally contradictory (a resolved note was added below it); `:767` is stale on the payment reviewer | REPLACE (OA-37) |
| `MUSHAF_UX_AUDIT.md` | Stale vs `MUSHAF_UX_SPEC.md` | REPLACE (mark historical) |
| `MASTER_ISSUE_MATRIX`, `FULL_PRODUCT_AUDIT`, `DATA_CONTRACT_AUDIT`, `CROSS_INTERFACE`, `FIREBASE_SCALABILITY`, `SHARED_UI_AUDIT`, `AUTH_SECURITY_AUDIT` | Fixed/obsolete claims: Paymob exported, a Supervisor review exists, AcademyAdmissionFirestore, public register | REPLACE (add historical banner) |
| `docs/` root W1–W8, POST_*, H1–H8 | Historical | KEEP as history (banner) |
| `DEMO_ACADEMY_DATASET.md` | The seeder is rules-denied (client SDK) | REPLACE |
| PH-02 docs (avatar visibility) | Avatars are shown only on the student's own screens | REPLACE (small correction) |
| Figma captures | Test artifacts, not authority | KEEP (non-authoritative) |

---

## S. Cleanup backlog

Format: **ID | Role | File/path | Type | Current behavior & evidence | Class | Why & dependencies | Risk | Recommended next action**

### P0: production blockers

| ID | Role | File/path | Type | Current behavior & evidence | Class | Why & dependencies | Risk | Next action |
|---|---|---|---|---|---|---|---|---|
| OA-01 | Admin/Parent | `functions/src/admin/adminProvisionUser.ts:63`; rules `isLinkedParentOf` | Missing workflow | `childrenIds` is written only as `[]`; 6 CF/rule consumers (see H) | COMPLETE | D12: Admin links children. Every parent feature depends on this. Depends on OA-02. | High: parents see nothing | Spec plus an Admin callable `linkParentChild` (audited, idempotent) with UI and tests |
| OA-02 | Admin | `features/admin/**`, AdminBloc | Missing UI | Placeholder "واجهة الإدارة غير مفعّلة بعد"; AdminBloc has only `ClearAdminSessionEvent`; billing/provision use cases unreachable; no logout | COMPLETE | D1/D3/D5/D18 Admin authority; server callables exist | High | Admin UI wave: provisioning, linking, invoices, payment review, reinstate, lifecycle, transfer, teacher management |
| OA-03 | Admin/Supervisor | `functions/src/payments/paymentReview*`; parent subscriptions page | Missing caller | `reviewPaymentProof` has no client caller, so proofs stay `pending_review` forever | COMPLETE | D3/D4. Depends on OA-02 (or a Supervisor surface per PH-02 scope). | High: billing stalls | Wire the review UI to the existing callable; add an e2e test |
| OA-04 | Admin | `halaqat` (no writer) | Missing workflow | Halaqa/schedule created only in the console | COMPLETE | D8. Depends on OA-02. | High: operational | Admin halaqa create/edit plus schedule callable with audit |
| E-07 | Student | `functions/src/economy/economyFunctions.ts:124–127`; `homework_entity.dart:116–122` | Broken flow | The server requires all tasks including recitation; the client skips recitation because `audioUploadsEnabled=false`, so honest completion fails | COMPLETE | Depends on the OA-15 decision (enable uploads, or have the server exclude recitation while the gate is off) | High: coin economy dead | Decide OA-15, then align the server's required-task set with the capability flag and add tests |

### P1: high

| ID | Role | File/path | Type | Current behavior & evidence | Class | Why & dependencies | Risk | Next action |
|---|---|---|---|---|---|---|---|---|
| OA-05 | All | `lib/core/router/router_app.dart` redirect | Guard gap | `AuthError` returns null; an unknown role is stuck on login | COMPLETE | Auth integrity | Medium | Route AuthError/unknown role to login with sign-out; add router tests |
| OA-06 | Supervisor/Admin | supervisor/admin home pages | Missing action | No logout | COMPLETE | Shared devices | Medium | Add the existing logout action to both shells |
| OA-07 | Supervisor | router allowlist | Guard breadth | `startsWith('/teacher/halaqa/')` exposes awards/analytics | COMPLETE | The server enforces scope; UI only | Low–Medium | Narrow the allowlist to the escalation pages |
| OA-08 | Parent | `parent_bloc.dart:164/185`; ParentReportsPage | Bug | `LoadWeeklyReportEvent` is never dispatched, so the report is always empty | COMPLETE | — | Medium | Dispatch on page open; add a widget test |
| OA-09 | Student | `assignment_homework_fields_ensure.dart:28–31` | Bug | Merge-sets `isSubmitted` on legacy docs and the rules deny it | COMPLETE | Legacy data | Medium | Count legacy docs; move the repair to a backfill CF or drop the write |
| OA-10 | Parent/Student | D5 banner widgets | Partial | Suspension is shown as a banner only; no gate | COMPLETE | D5 locked | Medium | Implement the D5 gating exactly as locked |
| OA-11 | All | FCM client service | Missing handlers | No `onMessage`/`onMessageOpenedApp`/`getInitialMessage`; no deep links | COMPLETE | D19 | Medium | Add handlers and a deep-link map for the generated types only |
| OA-12 | Teacher/Parent | grade label maps (client vs function) | Inconsistency | 'يحتاج إعادة' vs 'يحتاج تحسين' | COMPLETE | Same grade, two labels | Low–Medium | Pick the locked label; align both |
| OA-13 | All | `router_app.dart:154` | Config | `debugLogDiagnostics: true` | COMPLETE | Release logging | Low | Tie it to `kDebugMode` |
| OA-14 | QA | `rules_test/package.json`, `functions/package.json` | CI gap | Default scripts omit ph01/ph02 rules and the PH-02 emulator suite; no `integration_test/` | COMPLETE | Regression safety | Medium | Add the scripts to the default/CI targets |
| OA-15 | Student/Teacher | `app_constants.dart:103` `audioUploadsEnabled=false`; Storage `recitations/` denied | Capability | Recitation audio is off end-to-end | DECISION REQUIRED | Blocks E-07 and OA-71 | High | Product decides: enable audio uploads, or treat recitation as non-required while off |
| E-01 | Student/Teacher | rules ~566–575, 456–463; economy CF | Integrity | Coins are forgeable (task rewrite, no-audio record) and re-creditable (teacher reopen); labels mixed | COMPLETE | Depends on E-07 | Medium | Server snapshot of the required tasks at assignment creation; freeze completion state after credit; fix labels |
| E-02 | Student | `studentProfiles.points` | Undefined | Credited, never read | DECISION REQUIRED | Must not be merged with coins | Low | Product defines points or freezes the credit |
| E-03 | Teacher | `award_remote_datasource_impl.dart:101` | Idempotency | New awardId per call, so a retry double-credits stars | COMPLETE | — | Medium | Generate the awardId once per user intent; add a retry test |
| E-06 | Student | avatar catalog (Dart+TS), shop UI | Labels/catalog | "نقطة" used for coins; premium avatars unreachable; two catalogs | COMPLETE | — | Low–Medium | Single catalog source; coin label |
| E-12 | Student/Parent/Teacher | `streakDays`/`level` consumers; student_home_page:199 TODO | Fake data | Shows 0 / 1 always | QUARANTINE | No writer, no design | Medium (trust) | Hide the surfaces until designed |

### P2: medium

| ID | Role | File/path | Type | Current behavior & evidence | Class | Why & dependencies | Risk | Next action |
|---|---|---|---|---|---|---|---|---|
| OA-16 | Teacher | evaluations UI | UX | No client awareness of the 24h window; server error only | COMPLETE | D7.1 | Low | Show the window state from `createdAt` |
| OA-17 | Student/Supervisor | student screens; supervisor payment scope | Partial | Primary `halaqaId` only; the second membership is invisible | COMPLETE | Max-2 membership | Medium | Use membership lists |
| OA-18 | All | `studentProfiles.halaqaName` | Stale field | Not refreshed on admit/transfer | COMPLETE | — | Low | Refresh it in the membership callables, or resolve live |
| OA-19 | Student/Parent | progress fields | No writer | Shows 0 | COMPLETE | D11 Wave C projector | Low–Medium | Build the projector or hide the fields |
| OA-20 | Student | `reviewSchedules` | No writer | Page is always empty | COMPLETE | Revision plans | Low | Define the writer or hide the page |
| OA-21 | Parent/Admin | paymentProofs rules/CF | Audit gap | Confirmed amount not audited; parent can delete review fields; overdue/suspend not audited | COMPLETE | C16 | Medium | Freeze review fields; extend the audit |
| OA-22 | Supervisor/Admin/Teacher | notifications | Missing inbox | No watch for Supervisor/Admin; no CF types for teachers | COMPLETE | — | Low | Add inboxes when the types exist |
| OA-23 | All | notification types | Never generated | session_reminder, achievement, payment, message, homework_reviewed | QUARANTINE | — | Low | Keep the enum; don't build UI for them |
| OA-24 | All | chat edit/media; `chat_media/`, `voice/`, `attachments/` | Not wired | D20 media/edit absent | COMPLETE | D20 | Low | Wire to the existing callable/paths |
| OA-25 | Teacher/Student | `profile_images/`; edit "قريباً" | No writer | Placeholder images | COMPLETE | — | Low | Implement the upload or hide the action |
| OA-26 | All | 12 no-op spots (see E); teacher fake values; raw studentIds in supervisor dialogs | Stubs | "قريباً"/null handlers | COMPLETE | — | Low–Medium (trust) | Implement or hide each one |
| OA-27 | Teacher/Student | teacher_profile_tab:539–546; settings language row | Contradiction | Language row conflicts with D15 (Arabic only) | REMOVE | D15 | Low | Remove the rows |
| OA-28 | Teacher | student search client stack; dashboard search stub | Unwired | Server projection exists | COMPLETE | — | Low | Wire the teacher search to the existing use cases |
| OA-29 | Admin/Teacher | `teacherProfiles.name/halaqatIds` | Unmaintained | Stale | COMPLETE | OA-02 | Low | Maintain via the admin callables |
| OA-30 | Student | `/student/audio`, AudioBloc, `listeningProgress`, `surahAudios`, AudioPlayerService | Unreachable feature | Dead route; `.add()` loop every ~5s; disposed singleton; continueListening always null | DECISION REQUIRED | The spec lists the library as a separate surface | Medium if re-enabled | Decide restore vs retire; if restored, fix the id, the singleton and parallel audio first |
| OA-31 | Student | tab "خريطتي" | Placeholder | Empty | DECISION REQUIRED | The memorization-map concept is undefined | Low | Product defines it or hides the tab |
| OA-32 | Teacher/Student/Parent | posts | Audience | Visible only to teachers | DECISION REQUIRED | Not in the locked decisions | Low | Define the audience |
| OA-33 | Staff/Student | contentLibrary | Half-wired | Student-only route; staff upload unreachable | DECISION REQUIRED | — | Low | Keep (route the upload) or retire |
| OA-34 | All | `features/calendar/**`, `calendarEvents` | Unrouted | Route removed in H6; Bloc dead | QUARANTINE | Possible return | Low | Leave in place until the decision; exclude from the backlog |
| OA-35 | Admin | `complaints` | No writer possible | Admin-read rule only | QUARANTINE | — | Low | Decide with OA-02 |
| OA-36 | Supervisor | `supervisorReports`, SubmitSupervisorReport | Unreachable | UI removed | QUARANTINE | — | Low | Decide with the supervisor scope |
| OA-37 | Docs | see R; `h6_surface_cleanup.dart` comments; rules comment 909–911; evaluationNotification.ts:57 | Stale docs | Contradict the locked decisions | REPLACE | — | Low | Add historical banners and correct stale lines |
| OA-38 | Shared | InAppAcademyEventHandler, observer resolver, signal composer, `upsertSignals` + tests | Dead chain | Sink has `handlers: []`; the write is rules-denied | REMOVE | Remove the legacy tests together (OA-74) | Low | Remove in one PR with the tests |
| OA-39 | Teacher | `FanOutAcademyEventSink(handlers: [])` publish calls | No-op | Events go nowhere | QUARANTINE | C11 server fan-out exists | Low | Keep the interface until C11 replaces it fully |
| OA-40 | Student | StudentBloc monthly review schedule | Superseded | Wasted read per refresh | REPLACE | `features/review_schedule` | Low | Remove from StudentBloc after confirming the page uses the new feature |
| OA-42 | Student | Mushaf recitation mode | URL-only | Test-locked text | QUARANTINE | Spec F.6 | Low | Keep; no redesign |
| OA-43 | Student | Mushaf audio lifecycle | Bug | Doesn't stop on tab switch; second reader via push | COMPLETE | Spec | Low–Medium | Pause on tab leave; single host |
| E-11 | Supervisor | SupervisorBloc.IssueAchievement | Undefined | B7: star credit? Client clock | DECISION REQUIRED | — | Low | Product decides B7 |

### P3: low / hygiene

| ID | Role | File/path | Type | Current behavior & evidence | Class | Why & dependencies | Risk | Next action |
|---|---|---|---|---|---|---|---|---|
| OA-44 | Teacher | homework review; `absenceRequests.reviewedAt` | Missing metadata | No reviewer or timestamp | COMPLETE | — | Low | Add server timestamps |
| OA-45 | Student | `student_mushaf_dashboard.dart` | Dead page | 0 refs; a test asserts it is unused | REMOVE | Remove the test assertion together | Low | Delete in the cleanup wave |
| OA-46 | Student | `student_hadith_widget.dart` | Dead shim | 0 importers | REMOVE | — | Low | Delete |
| OA-47 | Student | GetLatestAssignment use case, repo :27/:83, DS :179 | Dead chain | 0 callers | REMOVE | DI regen | Low | Delete + regenerate DI |
| OA-48 | Student | GetLatestHomework + repo method | Dead | 0 callers | REMOVE | DI regen | Low | Delete |
| OA-49 | Teacher | RecordAttendanceUseCase + repo/DS `recordAttendance` | Superseded | Callable replaced it | REMOVE | DI regen | Low | Delete |
| OA-50 | Student | AddRecitationRecord event/use case/DS | Dead + denied | 0 dispatch | REMOVE | — | Low | Delete |
| OA-51 | Student | StudentMushafPage fallback loader, `AyahModel.fromJson`, `preferredSurah` | Dead branch | Superseded loader | REMOVE | Keep 'تعذر تحميل المصحف' | Low | In-file removal |
| OA-52 | Auth | `register_page.dart`, RegisterWithEmailUseCase, AuthBloc register path | Dead | No route; D1 says admin-created accounts | REMOVE | Update the wa0/wa2 test | Low | Delete |
| OA-53 | Teacher | `TeacherExcusesPreviewApp`, excuse FormSection/RequestCard/StatusChip | Dev/dead | 0 refs | REMOVE | — | Low | Delete |
| OA-54 | Teacher/Student | `HalaqaActivitiesMockStore` + 2 UI batch tests | Test-only | — | REMOVE | Tests together | Low | Delete |
| OA-55 | All | `main.dart:60–76` | Orphan instances | Factory blocs provided at the root and never used | REMOVE | — | Low | Remove the providers |
| OA-56 | Student | `@injectable` on StudentAudioLibraryPage (config :494) | Stray annotation | — | REMOVE | DI regen | Low | Remove the annotation |
| OA-57 | All | `AppRoutes.studentEvals/studentNotifs/teacherHalaqa/teacherStudent` | Unused consts | 0 refs | REMOVE | — | Low | Delete |
| OA-58 | All | zero-reference classes/functions (see G) | Dead code | 0 refs | REMOVE | Verify each with grep before deletion | Low | Batch delete |
| OA-59 | All | `attachMirroredPostId`, `watchChildrenAssignments`, `getSurahAudioById` | Dead methods | 0 callers | REMOVE | `getSurahAudioById` depends on OA-30 | Low | Delete (the audio one after OA-30) |
| OA-61 | All | GenerateCertificate, DeleteFile/ResetUpload, DeletePost/TogglePin | Dead events | Never dispatched; delete is rules-denied | QUARANTINE | Certificates/post moderation undefined | Low | Decide with the features |
| OA-62 | Shared | test-only contract classes (see G) | Test-only prod code | — | QUARANTINE | Docs-as-code value | Low | Move to test or delete with the tests |
| OA-63 | Parent/Student/Teacher | two notification pages | Duplicate | — | REPLACE | — | Low | Unify on one list widget |
| OA-64 | All | stat cards, skeletons, empty states, eval cards, chips, search bars | Duplicate UI | — | REPLACE | — | Low | Shared component wave |
| OA-65 | All | `sl<UseCase>` in pages; StudentBloc/HomeworkBloc overlap; `HalaqaIdParams` ×3 | Architecture drift | — | REPLACE | — | Low–Medium | Incremental |
| OA-66 | All | `parent_repository.dart` (supervisor), `notifiaction_repository.dart`, StudentProfilePage folder | Naming | — | REPLACE | Rename only | Low | Rename wave |
| OA-67 | Rules | `reciters` | Orphan collection | 0 reads | REMOVE | Rules wave + emulator tests | Low | Remove the rule block later |
| OA-68 | Rules | `halaqaActivity` (singular) | Legacy | No code refs | REMOVE | Data check first | Low | Remove after a console data check |
| OA-70 | Supervisor | `supervisorProfiles` | Orphan | D24 | QUARANTINE | D24 | Low | Keep quarantined |
| OA-71 | Student | `recitations/`, SubmitRecitation, activity audio | Gated | Denied/off | QUARANTINE | OA-15 | Low | Follow OA-15 |
| OA-72 | Student | `savedRecordings` (SharedPreferences) | Local data | Not per-user | QUARANTINE | OA-15 | Low | Key per uid if kept |
| OA-73 | All | `readBy` growth; `disableDeviceToken`; timestamp conventions; Admin attendance `recordedBy`; `studentMembershipLocks` explicit rule; missing indexes; Storage cleanup | Hygiene | — | COMPLETE | — | Low | Hygiene wave |
| OA-74 | QA | dead/legacy/brittle tests (see Q) | Tests | — | QUARANTINE | Removed together with their production code | Low | Pair with OA-38/54/62 |
| OA-75 | Teacher | D11 `versesRange` | Undefined semantics | Stored, meaning not locked | DECISION REQUIRED | D11 | Low | Product defines it (no invention) |
| E-08 | Student | `lastCompletedHomeworkId` | Dead write | No reader | REMOVE | Economy CF edit | Low | Drop the write later |
| E-09 | Teacher | `tasks[].points` | Misleading display | Server ignores it | REPLACE | E-01 | Low | Display the server reward |
| E-13 | Student | `studentProfiles.badges` | Dead field | No writer or reader | REMOVE | — | Low | Drop from the model |
| E-14 | Parent | wallets / `paymobWebhook.ts` | Quarantined | D2 | QUARANTINE | D2 | Low | Keep unexported |

### KEEP inventory (counted in totals)

| ID | Item |
|---|---|
| K-01 | Teacher attendance (`recordSessionAttendance`) |
| K-02 | Teacher live evaluation (`upsertSessionEvaluation`, D7.1) |
| K-03 | Homework submission review |
| K-04 | Assignment creation + `notifyOnAssignmentCreated` |
| K-05 | Halaqa activities (text/images) |
| K-07 | Supervisor admission (`admitStudentToHalaqa`) |
| K-08 | Absence requests |
| K-09 | Parent payment proof upload |
| K-10 | Chat 1:1 + group (text) + soft delete |
| K-11 | In-app notifications watch / readBy |
| K-12 | FCM token registration + evaluation push CF |
| K-13 | Mushaf reader stack |
| K-14 | C15 `mushafReading` + per-student prefs mirror |
| K-15 | Legacy `last_mushaf_page` removal-on-write |
| K-16 | Night mode device preference |
| K-18 | Student schedule / progress report |
| K-19 | Supervisor day board + escalation (read-only) |
| K-20 | Membership/payment/lifecycle server callables |
| K-21 | auditLogs (C16) |
| K-22 | studentSearch server projection |
| K-23 | Server-only collections (sessions, locks, notificationDeliveries) |
| K-24 | StudentRecitationPage |
| K-25 | Duplicate tab + route entry points |
| K-26 | Posts create/like/comment |
| K-28 | Teacher contact parent |

Together with E-04, E-05 and E-10 that makes 28 KEEP. K-06, K-17 and K-27 were merged into E-10, E-04/05 and E-11.

---

## T. Decision-required list

Only genuine decisions are listed.

| ID | Decision | Why it can't be inferred |
|---|---|---|
| OA-15 | Enable recitation audio uploads, or make recitation non-required while off? | Blocks E-07 (coins). The locked decisions don't set the capability timeline. |
| E-02 | What is `points` for (or should it stop being credited)? | No reader, no locked definition. **Must stay separate from coins.** |
| E-11 | B7: do Supervisor achievements credit stars? | Open in the PH-02 docs |
| OA-30 | Restore the Student audio library entry point or retire it? | The spec lists it as a surface, but it is unreachable |
| OA-31 | What is "خريطتي" (memorization map)? | No definition |
| OA-32 | Who is the audience for posts? | Not in the locked decisions |
| OA-33 | Keep the content library (route the staff upload) or retire it? | Half-wired |
| OA-75 | D11 `versesRange` semantics | Explicitly not invented in PH-02 |

---

## U. Safe removal candidates

These are strongly proven: zero references or superseded, with the evidence in G/L. Each still requires a grep re-check and a DI regeneration in its own PR.

1. OA-45 `StudentMushafDashboard` (+ its asserting test)
2. OA-46 `student_hadith_widget.dart`
3. OA-47 GetLatestAssignment chain
4. OA-48 GetLatestHomework chain
5. OA-49 RecordAttendance client chain
6. OA-50 AddRecitationRecord chain
7. OA-51 StudentMushafPage fallback loader (keep 'تعذر تحميل المصحف')
8. OA-52 RegisterPage + register use case (D1)
9. OA-53 TeacherExcusesPreviewApp + dead excuse widgets
10. OA-54 HalaqaActivitiesMockStore + its 2 tests
11. OA-55 orphan root BlocProviders
12. OA-56 stray `@injectable`
13. OA-57 unused route constants
14. OA-58 zero-reference classes/functions
15. OA-38 legacy academy-event handler chain + legacy tests

These are **not** safe yet:
- the audio library (OA-30);
- Calendar (OA-34);
- the `reciters`/`halaqaActivity` rule blocks (OA-67/68 need a rules wave and a data check);
- the economy fields E-08/E-13 (need a CF/model edit);
- the language rows (OA-27, a UI change).

---

## V. Recommended cleanup order

1. **Decisions first:** OA-15, E-02, E-11, OA-30, OA-31, OA-32, OA-33, OA-75.
2. **P0 completion wave:**
   - OA-02 Admin UI shell → OA-01 parent linking → OA-03 payment review → OA-04 halaqa/schedule;
   - E-07 homework reward (after OA-15).
3. **P1 integrity wave:**
   - E-01/E-03/E-06 economy integrity and labels;
   - OA-05/06/07/13 router/auth;
   - OA-08, OA-09, OA-10, OA-11, OA-12;
   - OA-14 CI scripts;
   - E-12 hide fake streak/level.
4. **P2 product completion:** OA-16–OA-29, OA-43, OA-21 audit gaps, and docs OA-37.
5. **P3 dead-code removal**, in small PRs, each with tests and DI regeneration: the list in U, then OA-40, OA-59, E-08, E-13, OA-27.
6. **Rules hygiene wave:** OA-67/68 and OA-73 (explicit `studentMembershipLocks`, indexes), with the emulator suites.
7. **Duplication/naming wave:** OA-63/64/65/66.

---

```
FINAL ORPHAN/DEAD-FEATURE AUDIT VERDICT
Audit-only: PASS
Repository modified: YES (this report file only: docs/production/FINAL_ORPHAN_DEAD_FEATURE_AUDIT.md)
Files deleted: 0
Routes deleted: 0
Firestore changes: 0
Storage changes: 0
Rules changes: 0
Commits: 0
Pushes: 0
Deployments: 0
Total candidates: 111
KEEP: 28
COMPLETE: 33
QUARANTINE: 14
REPLACE: 7
REMOVE: 21
DECISION REQUIRED: 8
Production blockers found: 5 (OA-01 parent linking, OA-02 Admin UI, OA-03 payment review caller, OA-04 halaqa/schedule creation, E-07 homework reward path)
High-risk cleanup candidates: OA-30 audio library (DECISION, not removal), OA-34 calendar, OA-67/OA-68 rule blocks, E-08/E-13 economy fields, OA-40 StudentBloc review stack
Business decisions required: 8 (OA-15, E-02, E-11, OA-30, OA-31, OA-32, OA-33, OA-75)
Recommended next wave: Decisions (Section T), then the P0 completion wave (Admin UI → parent linking → payment review → halaqa/schedule → homework reward)
```
