# Reviewer handoff — academy relationships, Central Academy Directory, assistant role, temporary cover, halaqa codes

Read-only review guide. It describes the code as it is in this workspace on 2026-10-31. It contains
no secrets, credentials or real user data; every name and code below is synthetic test data.

## 1. Workspace and Git state

| Item | Value |
|---|---|
| Workspace | `D:\Temp\rafiq_foundation\verify` |
| Kind | Linked Git worktree of `D:\flutter projects\rafiq_academy` |
| HEAD | Detached at `796e3de4f9e469a9cd6a2c13f9c4c85317d30548` |
| Staged | Nothing |
| Working tree | About 387 uncommitted entries (modified + untracked, 2 deletions) |

**All work described here is uncommitted.** The commit hash alone does not identify this version;
review the folder itself. Use read-only Git only (for example
`git --no-optional-locks status --porcelain=v1 --untracked-files=all`). A full status snapshot taken
before the halaqa-code change is in `D:\Temp\rafiq_foundation\impl_logs\review_worktree_status.txt`.

The two deleted files (`admin_complaints_page.dart`, `admin_complaints_review_page.dart`) come from
the earlier Admin milestone, not from this work.

## 2. Architecture in one paragraph

Flutter app (Dart ^3.11, BLoC, go_router, get_it `sl`) over Firebase. All relationship and account
mutations are **trusted backend operations**: Firebase Functions v2 callables in `europe-west1`,
each implemented as a pure `xCore(db, callerUid, data)` function plus a thin `onCall` wrapper
that calls `assertBackendAllowed`. Firestore rules give the client read access only (scoped by
role) and deny client writes to every relationship field, academy code, counter and ledger. The
role source of truth is `users/{uid}.role`. Every relationship change appends an entry to
`relationshipHistory` inside the same transaction that changes the relationship.

## 3. Read these first

1. `functions/src/accounts/academyRefs.ts`: academy-code authority (counter + shared ledger).
2. `functions/src/relationships/relationshipHistory.ts`: append-only history contract.
3. `functions/src/staff/halaqaAssistantFunctions.ts`: assistant assignment and temporary cover.
4. `functions/src/halaqa/halaqaScheduleFunctions.ts`, `adminCreateHalaqaCore`: halaqa creation,
   including automatic H-codes.
5. `firestore.rules`: `halaqat`, `academyRefCounters`, `importRows`, `relationshipHistory`,
   `halaqaCoverPeriods`, `sessions` blocks and the `isCoverOfHalaqa` helper.
6. `lib/features/directory/data/academy_directory_repository.dart`: every directory query.
7. `functions/test/academy_relationships.emulator.test.mjs`: the end-to-end scenario
   (P-001 / S-001..S-003 / T-001 / V-001 / A-001 / H-001, cover, recovery, second Admin).

## 4. Backend callables (all `europe-west1`, Admin-only unless noted)

| Callable | File | Responsibility |
|---|---|---|
| `adminImportAcademyRow` | `functions/src/accounts/academyImportFunctions.ts` | One roster row (teacher, supervisor, assistant, parent, halaqa, student) using the roster's own code; idempotent via the `importRows/{ref}` ledger; adopts a same-kind, same-name code created in the app |
| `adminOnboardStudent` | `functions/src/accounts/onboardingFunctions.ts` | Student plus existing or new guardian, optional halaqa; `requestId` makes it idempotent |
| `adminCreateMemberAccount` | `functions/src/accounts/memberAccountFunctions.ts` | One parent, teacher, supervisor or assistant; username, next free code, one-time temporary password |
| `adminGetMemberAccount` | same | Account status (login kind, username, active, first-login pending, last sign-in, recovery log); never a password |
| `adminResetMemberPassword` | `functions/src/accounts/onboardingFunctions.ts` | New temporary password, returned once, never stored in plaintext; forces a change at the next sign-in; logs who reset and when |
| `completeFirstLogin` | same | Signed-in user completes the forced password change |
| `adminProvisionUser` | `functions/src/admin/adminProvisionUser.ts` | Creates another Admin (UI shows a warning and a confirmation) |
| `adminLinkParentChild` | `functions/src/relationships/parentLinkFunctions.ts` | Link or unlink a parent and a student |
| `adminReplaceParentLink` | same | Move a student from one parent to another in one transaction |
| `admitStudentToHalaqa` / `adminTransferStudent` | `functions/src/halaqa/membershipFunctions.ts` | Halaqa membership |
| `adminReassignHalaqaStaff` | `functions/src/staff/staffLifecycleFunctions.ts` | Change the primary teacher or supervisor; the supervisor may be removed, the teacher may not |
| `adminSetHalaqaAssistant` | `functions/src/staff/halaqaAssistantFunctions.ts` | Assign or unassign an assistant (at most 3 per halaqa) |
| `adminStartHalaqaCover` / `adminEndHalaqaCover` | same | Temporary cover by an assigned assistant or another teacher; opens or closes a `halaqaCoverPeriods` record |
| `adminCreateHalaqa` | `functions/src/halaqa/halaqaScheduleFunctions.ts` | Create a halaqa; now also allocates its H-code (section 6) |
| `recordSessionAttendance` | `functions/src/sessions/sessionRecordFunctions.ts` | Teacher, or the **active cover** for that halaqa; stamps who actually handled the session; the primary teacher stays on the session |

Callables are exported from `functions/src/index.ts`.

## 5. Firestore collections involved

| Collection | Source of truth for | Client access (rules) |
|---|---|---|
| `users` | Role, name, `academyRef`, `isActive` | Role-scoped reads; no client role or code edits |
| `userPrivate` | Private email, `mustChangePassword` | Only two app readers are allowed (enforced by `test/security/no_personal_phone_policy_test.dart`) |
| `parentProfiles.childrenIds` | Parent → children | Admin, the parent themself, teacher/supervisor; never assistants |
| `studentProfiles.halaqaId` / `halaqat.studentIds` | Membership | Server-written |
| `halaqat` | `teacherId`, `supervisorId` (`""` = none), `assistantTeacherIds`, `coverTeacherId` + `coverId`, `academyRef` | Client create denied; Admin may change only non-relationship fields |
| `halaqaCoverPeriods` | Cover activation and completion | Admin read only |
| `relationshipHistory` | Append-only history, `subjectIds` array | Admin read only |
| `academyRefCounters/{kind}` | Last issued number per kind (`student`, `parent`, `teacher`, `supervisor`, `assistant`, `halaqa`) | Admin read only, no client writes |
| `importRows/{ref}` | Shared code ledger for import and app-created codes | Admin read only, no client writes |
| `halaqaNameIndex`, `halaqaScheduleLocks`, `halaqaMeetingLinks`, `onboardingRequests`, `auditLogs` | Supporting server state | Server-owned |
| `sessions`, `attendanceRecords`, `recitationRecords` | Session records | The cover reads its halaqa only while `coverId != ''` |

Rule and index files: `firestore.rules`, `firestore.indexes.json` (composite indexes for the
directory: `users` role+name / role+isActive+name / role+nameNormalized, `halaqat`
coverTeacherId+coverId and supervisorId+name, `halaqaCoverPeriods` halaqaId+startedAt,
`payments` studentId+dueDate, `relationshipHistory` subjectIds+at).

## 6. Academy codes (including the new halaqa codes)

- Format: `S-003`, `P-001`, `T-001`, `V-001`, `A-001`, `H-001` (`formatAcademyRef`).
- One authority: `academyRefCounters/{kind}` (last number) plus the shared `importRows/{ref}` ledger.
  `reserveAcademyRefInTx` (reads) and `claimAcademyRefInTx` (writes) run inside the caller's
  transaction; `allocateAcademyRef` wraps them for users.
- Halaqat created in the app: `adminCreateHalaqaCore` reserves and claims the next free H-code
  **in the same transaction that creates the halaqa** and stamps `halaqat.academyRef` (plus audit
  metadata `academyRef`). Consequences:
  - concurrent creates serialise on the counter document, so codes are never duplicated;
  - a replayed `requestId` returns the existing halaqa and code and consumes nothing;
  - a refused create (duplicate name, schedule conflict, invalid staff) consumes nothing;
  - codes already held in the ledger (for example an imported `H-001`) are skipped, never
    overwritten.
- Import passes the roster code through a server-only option (`options.academyRef`, never read
  from the client payload). It does not draw from the counter and keeps its own ledger entry.
  An import row repeating an app-created code for the same halaqa name is adopted ("existing").
- Existing codes are preserved. No migration or backfill was run: halaqat created in the app
  **before** this change still have no code.

## 7. Flutter routes and screens

| Route | Screen | File |
|---|---|---|
| `/admin/directory` | Central Academy Directory (overview, one tab per role, halaqat) | `lib/features/directory/presentation/admin_directory_page.dart` |
| `/admin/person/:uid` | Person profile (account + recovery card, relationships, history) | `admin_person_profile_page.dart` |
| `/admin/halaqa/:halaqaId` | Halaqa profile (staff, assistants, cover, students with parents, cover periods, history) | `admin_halaqa_profile_page.dart` |
| `/admin/add-member?role=` | Add a parent, teacher, assistant or supervisor | `admin_add_member_page.dart` |
| `/admin/onboard-student` (route `extra` = preselected parent) | Student wizard with guardian | `lib/features/accounts/presentation/admin_onboard_student_page.dart` |
| `/admin/accounts` | Admin accounts (second Admin) | existing `admin_accounts_page.dart` |
| `/assistant` | Assistant home: assigned halaqat read-only; active cover can record | `lib/features/assistant/presentation/assistant_home_page.dart` |
| `/teacher/cover` | Same screen for a teacher who is covering; opened from a banner on the teacher home | `teacher_cover_banner.dart`, `cover_attendance_page.dart` |

Routing and role guards: `lib/core/router/router_app.dart` (`AppRoutes`, `AppRouteAccess`). The
Admin hub tiles are in `lib/features/admin/presentation/pages/admin_management_tab.dart`. Other
directory code: `lib/features/directory/domain/` (models, `normalizeAcademyRef`, history
sentences), `directory_pickers.dart` (searchable pickers, no free-text IDs),
`directory_widgets.dart` (account and recovery card). Assistant data access:
`lib/features/assistant/data/cover_duty_repository.dart`.

## 8. Tests and how to run them

Emulator project `demo-rafiq-rules` only. The configs referenced below live outside the repo, in
`D:\Temp\rafiq_foundation\impl_logs\recon\emu\`.

| Suite | Location | Command (run from) |
|---|---|---|
| Flutter | `test/` (directory: `test/features/directory/`, assistant: `test/features/assistant/`, routes: `test/core/app_route_access_test.dart`) | `flutter test --no-pub` (repo root); `flutter analyze --no-pub` |
| Functions unit | `functions/test/*.test.mjs` | `npm run build` then `npm test` (`functions/`); `npm test` does **not** rebuild |
| Relationship core (emulator) | `functions/test/academy_relationships.emulator.test.mjs` and the other `admin_*` emulator tests | `npx firebase emulators:exec --project demo-rafiq-rules --config <emu>\cfg_auth\firebase.json --only auth,firestore,storage "node --test --test-concurrency=1 functions/test/<file>"` (repo root) |
| Rules | `rules_test/*.rules.test.mjs` (relationships: `academy_relationships.firestore.rules.test.mjs`) | `npx firebase emulators:exec --project demo-rafiq-rules --config <emu>\cfg\firebase.json --only firestore,storage "node --test --test-concurrency=1 <files>"` (`rules_test/`) |
| Callable (Functions emulator) | `functions/test/{admin_billing_callable,chat_message_callable,parent_achievements_callable,assignment_notification_trigger}.emulator.test.mjs` | Repo `firebase.json` with `--only auth,firestore,functions,storage` |

Latest results in this workspace (2026-10-31):
- Flutter: 1859 pass / 2 skip before the halaqa-code change; the directory suite (26) re-ran green after it.
- Analyzer: 0 errors, 7 old warnings.
- Functions unit: 615 pass / 1 skip.
- Rules: 371/371 across 16 files, including the new halaqa-code rules test.
- Relationship and Admin emulator suites (7 files): 58/58, run against the rebuilt Functions code.

## 9. Known incomplete requirements and open owner decisions

Missing or partial:
- There is no callable to remove a student from a halaqa entirely (only admit and transfer).
- Halaqat created in the app before the halaqa-code change have no code; no backfill was run.
- Name search on legacy accounts falls back to raw `name` prefix matching (the `nameNormalized`
  backfill was not run).
- A cover may record evaluations on the server, but the app has a screen only for cover attendance.
- Profiles show the last 6 payments; relationship history starts with the first change made
  through the system.
- The legacy Admin halaqat page and the create-halaqa form do not display the new H-code; it is
  shown in the Central Academy Directory (lists, search, profile).
- No real-device acceptance yet. Debug APKs are in `D:\Temp\rafiq_foundation\review_apk\`, built
  before the halaqa-code change. Only the emulator-routed APK exercises the new features; the dev
  flavor points at a project where none of this is deployed.

Owner decisions:
- The cap of 3 assistants per halaqa.
- Whether an assistant cover must be pre-assigned to the halaqa.
- Whether assistants may record while the primary teacher is present.
- Whether a cover gets homework and post tools.
- Whether students see guardian names.
- Promoting an existing account to Admin (today: create a new Admin).
- When to run the legacy name and halaqa-code backfills.
- Items carried over: logo text, Auth sign-up settings, credential delivery, PDF text direction.

## 10. Constraints the reviewer should keep

No deploys, no real Firebase data, no migrations or backfills, no Git writes in this worktree.
Protected files (`firebase.json`, `functions/package.json`, `lib/core/di/injection_container.config.dart`,
generated Windows plugin files, the admin broadcast and teacher announcement resolver and their
tests) are unchanged and checked by hash.
