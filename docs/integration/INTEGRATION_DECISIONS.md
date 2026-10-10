# Integration decisions — `integration/full-product`

Base: `feature/parent-interface` @ `62fac62`.
Merged: `feature/full-product-audit` @ `69e4207` (merge commit `9d09c1b`, merge base `29db7ee`).
Ported: `8898585`, `aeff001` (student), `70362e0` (supervisor).
`feature/teacher-production-pass` @ `82fecf1` and `feature/admin-agent3-home` @ `2c75b04` have no
commits missing from this branch (`git cherry`).

## Guiding rules

- Security rules, storage rules and Cloud Functions are Base, byte-for-byte. No permission widening.
- All privileged writes go through the existing callables (`adminCreateHalaqa`, `adminProvisionUser`,
  `adminLinkParentChild`, `adminTransferStudent`, `adminSetStudentLifecycle`, `admitStudentToHalaqa`,
  `grantAward`, `createDirectConversation`, `recordSessionAttendance`, `upsertSessionEvaluation`,
  `reviewPaymentProof`). No new callable was added.
- Payments are external: parent uploads proof, admin/supervisor reviews it via `reviewPaymentProof`;
  status / `paidAt` / remaining amount are derived server-side.
- `injection_container.config.dart` is regenerated with `build_runner`, never hand-merged.

## Audit merge — per-area resolution

### Core
- `firestore.rules`, `storage.rules`: Base.
- `router_app.dart`: Base `AuthRedirect` and admin routes kept; Audit routes added without duplicates
  (`adminHalaqatDirectory`, `adminPaymentsOverview` added; single `/admin/payments`, `/admin/halaqat`).
- DI config: regenerated (twice) with `build_runner`.

### Admin
- Audit 5-tab shell (`AdminHomePage`) kept; `AdminHomePage.actionLabels` (P0-02) surface on the
  management tab, logout on the settings tab.
- Datasource/repository: Audit read models over Base callables for every write.
- Removed the dead client-side `createHalaqa` chain (bloc events/handlers, repository/datasource
  methods, `CreateHalaqaParams`, unreachable `AdminCreateHalaqaPage`); halaqa creation is
  `adminCreateHalaqa` only. `create_halaqa_usecase.dart` renamed to
  `ensure_admin_internal_chat_usecase.dart` (only `EnsureAdminInternalChatUseCase` remains).
- `AdminState.createHalaqa*` fields left in place as dead state (no behaviour; cleanup candidate).
- `notification_page.dart`, `content_library_page.dart`: Base + `embeddedInAdmin` flag for the admin hub.

### Chat
- Base datasource/repository + Audit `watchAllConversations` (admin oversight, read-only).
- `chat_room.dart`: Base + `readOnly` mode for oversight.

### Supervisor
- Audit 5-tab shell. `IssueAchievementDialog` (Base, `@visibleForTesting`) moved to
  `presentation/widgets/issue_achievement_dialog.dart`; kept with its tests but not wired in the
  new shell (grant flow is the Audit `grantAward` page).
- `admitStudentToHalaqa` / `registerNewStudent` → `admitStudentToHalaqa` callable;
  `transferStudentBetweenHalaqat` → `adminTransferStudent` callable.
  Client-side `AcademyAdmissionFirestore` writes removed.
- Payments: listing scoped to supervised halaqat, queried per student (`isEqualTo`),
  `permission-denied` skipped (rules: `isSupervisorOfStudent`). Review → `reviewPaymentProof`
  (`approved→approve`, `rejected→reject`, `partial→partial`).
- Two supervisor payment UIs exist: the Audit page (callable review) and Base `/supervisor/payments`.

### Teacher
- Datasource: Base `recordSessionAttendance` / `upsertSessionEvaluation` write paths.
- `UpsertTeacherEvaluationUseCase`: Audit halaqa-ownership check first, then Base attendance gate.
- `teacher_excuses_page.dart`: Base + `TeacherWorkflowOwnership.canExecute` guard in `_review`.
- Audit-only `teacher_excuse_list_item_data.dart`, `teacher_excuse_request_card.dart` and its test
  removed; `teacher_pending_absence_section.dart` uses `AppStatusChip` + `teacherAbsenceStatusTone`.
- `teacher_profile_tab.dart`: Audit removals (no "coming soon", no fake satisfaction stat);
  dark-mode toggle removed (D15).
- Loading skeletons, class detail, classes page: Base. Dashboard: Audit (fake search CTA removed).

### Student
- `student_mushaf_page.dart`: Base mushaf + Audit capability gate
  (`AppCapabilities.audioUploadsEnabled = false` → recitation goes through homework).
- `student_home_page.dart`: Base plan tab kept; Audit loading skeletons.
- `student_bloc_test.dart`: Base; Audit suite kept as `student_bloc_load_test.dart`.

### Tests adapted (no assertion weakened)
- Supervisor bloc / dialog tests: fakes for new constructor dependencies.
- Chat bloc / teacher messages tests: `watchAllConversations` fake.
- Attendance-gate test: `getTeacherHalaqat` fake + new non-owner case.
- UI-4 admin honesty: same assertions, pointed at the management and settings tabs (the shell
  needs `AdminBloc`/`AuthBloc`).

## Ports

- `8898585` (`AppLoadingWidget` pulse skeleton): clean; full suite passes, no `pumpAndSettle` timeouts.
- `aeff001` (student production pass):
  - Tab 3 stays "خطة الحلقة" (its only entry point). Journey map moved to `StudentJourneyMapPage`
    at `/student/journey-map`, opened from the "خريطتي" quick action — **product decision**.
  - Settings: new grouped layout, but no dark-mode toggle (D15) and Base `AppBackButton` kept;
    `_SettingsGroup` is a `Material` so `ListTile` ink is visible.
  - Profile tab keeps Base "موارد الحلقة" (shared content + audio library).
- `70362e0` (supervisor roster refresh): membership fingerprint + transfer source prefill; Base
  payments loading kept in the Students tab; transfer use-case tests adapted. The branch-only
  "admission alias" test targets an API not present here and was not ported.

## Known gaps / follow-ups

- Admin internal chat is disabled until a callable supports the required conversation type.
- Halaqa staff reassignment (teacher/supervisor change) has no UI.
- No admin UI to configure the payment destination.
- Dual supervisor payment UIs should be consolidated.
- `IssueAchievementDialog` kept but unused; `AdminState.createHalaqa*` dead fields.
