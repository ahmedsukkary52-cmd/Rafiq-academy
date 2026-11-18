# BASMA Master Issue Register

Status: PART A CLOSED — INVENTORY/RECONCILIATION ONLY; R1 IN PROGRESS; Stage A–C COMPLETED 2026-11-16; **Stage D0 COMPLETED 2026-11-16 — PASS WITH GAPS**; **Stage D2 COMPLETED 2026-11-17 — PASS WITH GAPS** — **checkpointed commit `daa8f85` (2026-11-18)**; **Stage D3 local/emulator COMPLETED 2026-11-18 — PASS WITH GAPS (no Cloud deploy)**; **Stage D4 code portion COMPLETED 2026-11-18 — PASS WITH GAPS**; **RB-01 Flutter Full Suite CLOSED 2026-11-18 — GREEN** (`+2486 ~3`; `docs/engineering-audit/BASMA_RB01_FLUTTER_SUITE_DIAGNOSIS.md`) — **not re-run on HEAD `0889682`**; **Final Engineering Quality Audit 2026-11-18** — **not engineering-complete**; **EQ Phase 1 (B1–B6) CLOSED WITH DEFERRED FINDINGS 2026-11-18**; **EQ DI campaign (B1–B6 + EQ-2/3/4 strict) committed `0889682`** — focused **93** tests passed on the **full working tree** (not isolated commit-only tree); EQ-M-06 deferred; consolidated review `docs/engineering-audit/BASMA_FINAL_ENGINEERING_QUALITY_REVIEW.md` + roadmap `BASMA_REMAINING_WORK_ROADMAP.md`; **RB-02 / RB-16 / RB-17 / RB-18 and D4 device-lab remain OPEN**; production Firebase verification and owner decisions pending. **D1 not started (G1).** Does **not** claim overall engineering-quality or release completion.

Statuses used: DISCOVERED, INVESTIGATING, READY FOR IMPLEMENTATION, IN PROGRESS, IMPLEMENTED, TESTED, VERIFIED, BLOCKED BY EXTERNAL DEPENDENCY, WAITING FOR OWNER DECISION, EXPLICITLY ACCEPTED RISK.

Evidence taxonomy (Stage A–C): Confirmed Issue | Potential Risk | Existing Known Issue | Resolved Issue | Blocked Verification.

Historical source: `docs/production/MASTER_ISSUE_MATRIX.md`, 102 findings from frozen baseline `69e4207`. Historical IDs remain traceable; this register does not silently close them. Part A closure is administrative only; no `AUD-001` through `AUD-102` is closed by the transition to R1.

Stage A–C package: `docs/engineering-audit/BASMA_*_AUDIT.md`, `BASMA_REMEDIATION_PLAN.md`, `BASMA_FINAL_ENGINEERING_REPORT.md`.

| ID | Source / area | Severity | Current evidence and user impact | Status | Next evidence / dependency | Owner approval |
|---|---|---:|---|---|---|---|
| BASMA-001 | AUD-001 / Firestore rules | P0 | Current rules are wired and make roster/membership fields server-owned; complete current emulator authorization suite passed. | TESTED | `npm run test:all:firestore` via demo emulator: 276 passed, 0 failed, 0 skipped, exit 0. Deployment diff still requires review. | No deployment without approval |
| BASMA-002 | AUD-002 / Storage rules | P0 | Current Storage rules are wired; payment proof, profile, chat, activity, post, and deactivation cases passed in the current emulator suite. | TESTED | `npm run test:all:storage` via demo emulator: 67 passed, 0 failed, 0 skipped, exit 0. Deployment diff still requires review. | No deployment without approval |
| BASMA-003 | AUD-006 / Firebase wiring | P0 | `firebase.json` points to `firestore.rules`, `storage.rules`, indexes, and Functions; deployment has not been performed. | TESTED | Preserve deployment-order gate and run contract checks. | Required before deploy |
| BASMA-004 | D1 / account provisioning | P0 | Locked decision requires Admin-controlled provisioning; implementation exists in current history but end-to-end production identity verification is outstanding. | INVESTIGATING | Emulator callable/UI workflow and Auth lifecycle test. | Mechanism confirmation if contract changes |
| BASMA-005 | D2-D6 / payments | P0 | Payment contract and backend work are present in current history; billing checklist remains `B-BILLING UNRESOLVED`. | BLOCKED BY EXTERNAL DEPENDENCY | Emulator workflow first; owner supplies project/billing evidence later. | Blaze and production account |
| BASMA-006 | D7-D10 / sessions | P0 | First-class session and attendance/evaluation authority work is present in current history; full cross-role verification is outstanding. | INVESTIGATING | Run Functions/emulator and Flutter workflow tests. | No business-rule change |
| BASMA-007 | D12 / parent-child graph | P0 | Rules protect `parentProfiles.childrenIds`; callable/writer and isolation need end-to-end verification. | INVESTIGATING | Emulator authorization and parent workflow tests. | No direct-write exception |
| BASMA-008 | D13-D14 / chat and notifications | P1 | Dynamic groups, relationship guards, FCM ownership work exists; callable/media authorization is now emulator-tested, while device delivery remains outstanding. | TESTED | Chat callable suite: 14 passed, 0 failed, 0 skipped, exit 0; FCM/device delivery still requires device evidence. | APNs/FCM account setup |
| BASMA-009 | B14 / meeting links | P0 | Current rules document canonical `halaqaMeetingLinks`; legacy-field quarantine and supervisor add-only flag remain disabled. | TESTED | Meeting-link Emulator suite: 6 passed, 0 failed, 0 skipped, exit 0; no migration/deploy. | Explicit approval for any enablement |
| BASMA-010 | A / Admin toggle | P1 | Focused mocked Bloc/widget tests previously passed for full, partial, and callable-failure outcomes. | TESTED | Add emulator/UI evidence before release claim. | No |
| BASMA-011 | C / Supervisor enrollment | P1 | Integrated Supervisor flow uses existing student/halaqa selection and callable path; partial success remains on page. | TESTED | Verify callable authorization and roster refresh with emulator. | No |
| BASMA-012 | D / AudioLibrary | P1 | Completion resets UI position/state while retaining shared player; focused service/Bloc tests previously passed. | TESTED | Verify on target device and confirm singleton ownership in runtime. | No |
| BASMA-013 | Branding / BASMA | P1 | Product lock is BASMA; broad current Dart search found no visible Rafiq matches in inspected scope, but Android/iOS/store surfaces need evidence. | INVESTIGATING | Review launch assets and emulator screenshots. | Palette/store choices if material |
| BASMA-014 | Release Firebase project/config | P0 | Release docs state prod project/config are absent and staging is alias-only. | BLOCKED BY EXTERNAL DEPENDENCY | Owner creates/configures target projects and supplies safe config. | Required |
| BASMA-015 | Release signing/CI | P0 | Upload key, Codemagic run, Apple account/APNs, and signed builds remain open. | BLOCKED BY EXTERNAL DEPENDENCY | Owner supplies credentials/accounts; run unsigned checks first. | Required |
| BASMA-016 | Paid services/billing | P0 | Firebase billing checklist has no verified plan, budget, project, or console evidence. | BLOCKED BY EXTERNAL DEPENDENCY | Complete checklist with owner-controlled console evidence. | Required |
| BASMA-017 | Historical role UI findings | P1/P2 | Parent, teacher, student, supervisor, and admin worktrees contain valuable changes and dirty generated files; current branch is not yet a complete cross-role workflow proof. | INVESTIGATING | Compare contracts and run role workflow tests without discarding work. | Major product decisions only |
| BASMA-018 | Protected data handling | P0 | Protected Quran paths are present as pre-existing untracked files in the current status output. They were not accessed or processed. | EXPLICITLY ACCEPTED RISK | Preserve untouched; owner must handle separately under repository policy. | Required for any future access |
| BASMA-100 | Trial live rules gap / Security | P0 | **Confirmed Issue (cloud):** Trial over-reads on live `rafiq-academy`. **D0:** repo rules isolation suite `d0_trial_isolation.firestore.rules.test.mjs` **18/18 PASS** on `demo-rafiq-rules` (parent≠admin userPrivate, student≠user list/foreign payment, etc.). Emulator PASS does not close cloud gap. | WAITING FOR OWNER DECISION | D1 deploy rules; re-run matrix with live tokens. D0 matrix: `docs/engineering-audit/BASMA_D0_SECURITY_TEST_MATRIX.md`. | Rules deploy |
| BASMA-101 | Live indexes missing | P0/P1 | **Confirmed Issue:** Trial logcat/REST `FAILED_PRECONDITION` for complaints (`status+createdAt`), payments `sum(amount)`, teacher cover query, supervisor absence query. Several indexes exist in repo but are unpublished; payment sum index was locally prepared only. | BLOCKED BY EXTERNAL DEPENDENCY | Owner approve indexes deploy; retest Admin finance/complaints. | Indexes deploy |
| BASMA-102 | Cloud Functions unpublished | P0 | **Confirmed Issue:** `firebase functions:list` empty on `rafiq-academy`; callables HTTP 404 (attendance, chat send, homework complete, eval, provision, parent schedule/halaqat, …). Blaze/`billingEnabled:false`. | BLOCKED BY EXTERNAL DEPENDENCY | Blaze + Functions deploy + `PRODUCTION_BACKEND_ENABLED` after B-BILLING. | Blaze + deploy |
| BASMA-103 | Chat load-older read amplification | P1 | **D2 implemented** and checkpointed in **`daa8f85`:** fixed live window (30) + `fetchMessagesBefore` cursor; merge/dedupe; contract tests PASS (`chat_room_bloc_test`). See `BASMA_D2_CHAT_PAGINATION_REPORT.md`. | TESTED | Optional emulator/device scroll UX; no cloud required for client fix. | No cloud |
| BASMA-104 | Admin unbounded conversations path | P1 | **D2 mitigated** (in **`daa8f85`):** `ChatConversationsBloc.defaultInboxPageSize=40` applied when pageSize omitted; all role call sites pass explicit pageSize; Admin keeps 30. API still accepts null but app paths bound. Guard asserted in `chat_conversations_bloc_test`. | TESTED | Keep null banned at datasource if desired later. | No |
| BASMA-105 | Flutter coverage % unknown | P2 | **Blocked Verification:** 282 Flutter test files counted; no LCOV run in Stage A–C. Do not claim 90%. Full suite green after RB-01 does **not** equal coverage %. | DISCOVERED | Optional `flutter test --coverage` later. | No |
| BASMA-106 | Perf / icon / splash matrix | P2 | D4 code: `RepaintBoundary` on glass nav; hot directory/payments/registration lists → `SliverChildBuilderDelegate` + structural/widget tests. **2026-11-18:** SM-A037F seen wirelessly but no DevTools/profile/icon matrix; local splash/adaptive assets reviewed; D4 widget tests re-passed. Device matrix still **Blocked Verification**. See `BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md`. | IN PROGRESS | Stable device lab for icon/splash/overflow + profile traces | No |
| BASMA-109 | Shared UI / strings inventory | P2/P3 | **Existing Known refreshed:** AUD-041 bottom-nav chrome largely unified; AUD-042 scaffolds remain split. ~4625 Arabic literals / 0 ARB; ~2647 `Colors.` sites. L10n/Dark still deferred. | DISCOVERED | Design-system batch only after D1–D3 unless owner reprioritizes | Product for L10n |
| BASMA-107 | Unbounded / N+1 Firestore reads | P1 | **D2 final** (checkpoint **`daa8f85`):** recitation/supervisor payments **page-until-exhausted** (no silent truncate); achievements hard limit removed; teachers/registration chunked; inbox default pageSize. Deferred: registration denorm, optional UI cursors, notifications readBy, **RB-02 Cloud** index deploy. | TESTED | Deploy recitation DESC index on final project; schema for registration filter | Indexes deploy |
| BASMA-108 | Architecture layer skips | P2 | **Further mitigated** in EQ DI commit **`0889682`** (EQ-2/3/4 + B1–B6 DI): accounts parents + complaints/assistant + admin reports GetIt. Remaining: AdminBloc+PDF coupling (deferred), audio Auth (`EQ-M-05`), EQ-M-06 injectable regen. Not a full generated-DI graph. | IN PROGRESS | Prefer G0/G1 after docs checkpoint; else EQ-M-05 or T1 | No |
| BASMA-110 | Engineering Quality Phase 1 | P2 | EQ-B1–B6 complete; disposition **CLOSED WITH DEFERRED FINDINGS**. EQ-2/3/4 + strict DI campaign **committed `0889682`**. Focused **93** tests on full WT (not isolated tree). Does not close Cloud/device/release. Full Suite not re-run on `0889682`. | TESTED | Docs sync → G0/G1; local EQ-M-05/T1; do not mark engineering-complete | No |
| BASMA-111 | EQ-M-04 access-card parent Firestore | P2 | Presentation `_defaultParents` extracted to accounts repo (EQ-2); included in **`0889682`**. Query semantics preserved (limit 3, no isActive filter). | TESTED | Optional: injectable codegen later (EQ-M-06); do not reopen unless regression | No |
| BASMA-112 | EQ-M-02/03 complaints + assistant DI | P2 | `ComplaintsRepository` + `CoverDutyRepository` registered; entry/home/banner resolve via GetIt (EQ-3); in **`0889682`**. | TESTED | Keep seams; injectable regen later when explicitly approved (EQ-M-06) | No |
| BASMA-113 | EQ-M-01 Admin reports DI | P2 | `AdminReportsRepository` registered; page resolves via GetIt (EQ-4); in **`0889682`**. AdminBloc+PDF/export left intact (deferred). | TESTED | Keep seams; no PDF redesign without separate approval | No |

No issue is considered VERIFIED solely because a UI exists, a mocked test passes, or an analyzer has zero errors.

## R1 Emulator evidence — current branch only

All commands below ran on `unify/basma-v1` using the local `demo-rafiq-rules` project; no production Firebase operation was used:

- PH02 backend authority: `npm run test:ph02:emulator` via `--only firestore,auth,functions`: **76 passed, 0 failed, 0 skipped, exit 0**. The earlier reported 75/1 result was not reproducible in the required serial run; no production change was made.
- P0 completion/relationships/sessions: `npm run test:p0:emulator`: **25 passed, 0 failed, 0 skipped, exit 0**.
- Billing callables: `npm run test:billing:emulator`: **5 passed, 0 failed, 0 skipped, exit 0**.
- Chat callables/media: `npm run test:chat:emulator` via `--only firestore,auth,functions,storage`: **14 passed, 0 failed, 0 skipped, exit 0**. The first invocation without Storage was a harness failure and is not evidence against the implementation.
- B14 meeting links: `npm run test:meeting-link:emulator`: **6 passed, 0 failed, 0 skipped, exit 0**.
- Parent achievements: `npm run test:achievements:emulator`: **7 passed, 0 failed, 0 skipped, exit 0**.

These suites prove selected callable authorization, scope, idempotency, audit, and data-integrity cases only. They do not prove all callable paths, Flutter cross-role workflows, FCM/device delivery, or production configuration. R1 remains in progress.

## R1 callable coverage inventory

The current `functions/src/index.ts` has **64 active exported Functions**: **52 callables, 11 Firestore triggers, and 1 scheduled function**. Two Paymob exports remain commented/quarantined and are not counted.

Strict wrapper classification for this R1 slice:

- **CALLABLE — WRAPPER AUTH TESTED: 22** — the previous 10 plus the 12 R1-G operations: `admitStudentToHalaqa`, `adminTransferStudent`, `adminSetHalaqaAssistant`, `adminStartHalaqaCover`, `adminEndHalaqaCover`, `adminSetStaffStatus`, `adminReassignHalaqaStaff`, `submitPaymentProof`, `reviewPaymentProof`, `adminCreateChatGroup`, `adminUpdateChatGroup`, and `adminSetChatGroupMembers`. These were run through the HTTP Functions Emulator in four isolated groups; each group passed.
- **CALLABLE — CORE TESTED ONLY: 30** — remaining active callables have Core/contract evidence but no executed wrapper proof recorded here.
- **CALLABLE — TEST EXISTS BUT NOT RUN: 0 confirmed** — `adminProvisionUser` is now covered by the executed wrapper suite; no separate not-run category is retained.
- **CALLABLE — NO TEST: 0 confirmed** — every active callable has at least a source/contract/core test reference, but that is not equivalent to authorization coverage.
- **TRIGGER — SOURCE-WRITE + SIDE-EFFECT TESTED: 9** — `notifyOnAssignmentCreated`, `notifyOnPaymentUpdated`, `notifyOnAbsenceRequestCreated`, `notifyOnAbsenceRequestReviewed`, `syncHalaqaGroupOnWrite`, `syncAdminGroupOnUserWrite`, `projectStudentSearchOnHalaqaWrite`, `projectStudentSearchOnProfileWrite`, and `projectStudentSearchOnUserWrite`. The projection/group suite writes source documents, asserts final projections/group membership, and checks deterministic/no-op behavior. `syncAdminGroupOnUserWrite` is intentionally update-only when the managed group does not already exist; creation is owned by `ensureAdminGroupConversation`.
- **TRIGGER — PARTIALLY TESTED BY SYNTHETIC HANDLER EVENT: 2** — `notifyParentsOnEvaluation` and `reconcileFcmTokenOwnership`; the FCM suite ran exported `.run` handlers against Firestore Emulator with egress guard and passed 19/19, but did not drive the deployed trigger runtime from a source-document write.
- **TRIGGER — NOT TESTED: 0 confirmed** — all 11 trigger exports now have either source-write evidence or synthetic-handler evidence.
- **SCHEDULED — NOT TESTED / SEPARATE HARNESS: 1** — `processPaymentOverdueGrace`; no scheduled job was run. The isolated `runOverdueGracePass` harness proves core transition/idempotency only, not scheduled-runtime wiring.

Trigger evidence added in this slice:

- High-risk emulator bundle: **33 passed, 0 failed, 0 skipped, exit 0**.
- Assignment source-write trigger: **1 passed, 0 failed, 0 skipped, exit 0**.
- Absence request source-write trigger: **1 passed, 0 failed, 0 skipped, exit 0**. It covered created staff fan-out, reviewed parent notification, deterministic retry/no duplicate, and forged-parent suppression.
- Projection/group source-write trigger suite: **1 passed, 0 failed, 0 skipped, exit 0**. It covered all five previously partial triggers, final group/search projections, role removal, and no-op/idempotent behavior.
- R1-G isolated HTTP wrapper groups: Membership **1/1**, Staff/Cover **1/1**, Payments **1/1**, Chat Groups **1/1**; each ran against `demo-rafiq-rules` with Auth/Firestore/Storage/Functions Emulator and exited 0. These four runs supersede the incomplete combined harness; the combined timeout is not counted as evidence.
- R1-G Client SDK Rules harness: **4 passed, 0 failed, 0 skipped, exit 0** under Firestore Emulator. It covered 13 selected sensitive operations: one intended allowed profile-name write and 12 denied server-owned/scope writes, with no-mutation assertions.
- FCM ownership/evaluation handler suite: **19 passed, 0 failed, 0 skipped, exit 0**, with `RULES_TEST_PROJECT_ID=demo-rafiq-rules` and no production egress.
- Safe WA-6 core harness: **1 passed, 0 failed, 0 skipped, exit 0**. It ran `runOverdueGracePass` twice on synthetic emulator data, proving overdue transition and no second access write; the scheduled trigger itself was not invoked.

Existing test files are evidence of available work, not execution evidence. The previous list of 13 exports without direct non-Quran emulator references remains a useful gap list, but it must not be confused with the stricter wrapper/trigger counts above.

`getParentChildSchedule` and `getParentChildHalaqat` now use the exported callable over HTTP through Functions + Auth + Firestore Emulator. Combined result: **5 passed, 0 failed, 0 skipped, exit 0**. The tests assert real authorization responses and sanitized projections.

### Client write authority map reviewed

Sensitive direct client writes found in Flutter are constrained by current rules as follows:

- `assignments/{id}`: teacher-created assignment/activity writes and bounded student task/counter updates; identity is frozen and completion/reward fields remain server-owned. This is direct client access with rules-based authority, not a callable-mediated write.
- `assignments/{id}/activityResponses/{id}`: rostered student create only; update/delete denied.
- `calendarEvents/{id}`: Admin or active staff create (Halaqa-scoped for staff); Admin or creator staff delete; update denied.
- `contentLibrary/{id}` plus `content_library/{halaqa}/{uploader}/{file}`: scoped Admin/Teacher/Supervisor create/delete with matching uploader/path and content-type/size rules.
- `listeningProgress/{id}`, Mushaf reading, FCM device tokens, notification read state, and selected profile self-updates are owner-limited by rules. Protected Quran/Mushaf data was not inspected for this inventory.
- Roster membership, payments/paymentAccess, attendance, live evaluations, audit logs, Halaqa documents, canonical B14 links, lifecycle, awards, and server reward markers are client-write denied and routed through Functions/Admin SDK.

No confirmed privilege-escalation defect was established by this bounded review. The absence and projection/group trigger gaps are closed by source-write evidence. The initial combined R1-G wrapper run timed out, but the harness was split and each group then passed independently. The remaining R1 risk is verification coverage: 30 callable wrappers remain core-only, the selected Client SDK Rules proof covers 13 sensitive operations from the 22-operation inventory (1 intended allowed write and 12 denied server-owned/scope writes), and the scheduled runtime is intentionally unexecuted. Aggregate rules-suite passes do not substitute for per-operation proof.

## Historical AUD-001–AUD-102 reconciliation

Source: `docs/production/MASTER_ISSUE_MATRIX.md`, summary index and detail records. This reconciliation is intentionally conservative: only `AUD-001`, `AUD-002`, and `AUD-006` have an explicit current-register mapping above. The other 99 records remain visible below with no fate assigned yet. Their presence here does not mean they are still defects; it means current evidence has not been recorded sufficiently to mark them fixed, stale, blocked, accepted, or superseded.

### Explicitly mapped

- `AUD-001` → `BASMA-001`: current Firestore emulator suite tested; deployment/runtime comparison remains open.
- `AUD-002` → `BASMA-002`: current Storage emulator suite tested; deployment/runtime comparison remains open.
- `AUD-006` → `BASMA-003`: current Firebase wiring present; deployment-order and production comparison remain open.

### Historical records whose current fate is not yet determined

**P0:**

- `AUD-003` User phones — Privacy
- `AUD-004` Payment status write — Security / Payments
- `AUD-005` Student self-registration — Auth
- `AUD-007` Wallet marks paid — Payments
- `AUD-008` Proof vs paid at rules layer — Payments

**P1:**

- `AUD-009` Payment invoice creation — Missing contract
- `AUD-010` Overdue transition — Missing contract
- `AUD-011` Suspension from overdue — Missing contract
- `AUD-012` Vodafone destination — Payments
- `AUD-013` Paymob leftover — Payments
- `AUD-014` Payment events — Notifications
- `AUD-015` childrenIds writer — Membership
- `AUD-016` Staff provisioning — Auth
- `AUD-017` Password reset — Auth
- `AUD-018` Halaqa without schedule — Halaqa
- `AUD-019` Teacher change roster link — Halaqa
- `AUD-020` Progress never recalculated — Quran/Progress
- `AUD-021` Streak/juz/verses static — Quran/Progress
- `AUD-022` Weekly report verses — Quran/Progress
- `AUD-023` Dashboard fake zeros — Reports
- `AUD-024` No session documents — Session
- `AUD-025` Evaluation without attendance — Session
- `AUD-026` Unbounded message listener — Scalability — **2026-11-16 note:** partially mitigated (required `limit` on watch); remaining defect tracked as **BASMA-103** (growing-limit reload). Not closed.
- `AUD-027` Group chat impossible — Chat
- `AUD-028` Unbounded conversation watch — Scalability
- `AUD-029` No FCM — Notifications
- `AUD-030` Session reminders never produced — Notifications
- `AUD-031` Award events missing — Notifications
- `AUD-032` Missing recitation index — Firebase
- `AUD-033` Missing payments index — Firebase
- `AUD-034` Full payments collection read — Scalability — **2026-11-16 note:** list path now `limit(pageSize)`; aggregate summary still index-blocked on live (BASMA-101). Not fully closed.
- `AUD-035` Wallet collection absent from rules — Payments
- `AUD-036` Role rules vs router only — Security
- `AUD-037` Subscription period selector — Missing contract
- `AUD-038` Inactive halaqa still operable — Halaqa
- `AUD-039` Achievement accuracy misuse — Quran/Progress
- `AUD-040` Unenroll / exit membership — Missing contract
- `AUD-094` Attendance without scheduled meeting — Session
- `AUD-095` Live evaluation has no AcademyEvent — Notifications
- `AUD-096` Progress field meaning contradiction — Quran/Progress
- `AUD-097` Live evaluation versesRange always empty — Quran/Progress
- `AUD-098` Chat create is role-pair only — Chat / Security

**P2:**

- `AUD-041` Five independent bottom navs — Shared UI
- `AUD-042` Three independent subpage scaffolds — Shared UI
- `AUD-043` Hardcoded RTL — RTL
- `AUD-044` No English localization — L10n
- `AUD-045` Language row is dead — L10n
- `AUD-046` AppTextStyles ignore dark theme — Theme
- `AUD-047` Hardcoded Colors — Theme
- `AUD-048` Network taxonomy collapse — Network
- `AUD-049` Loading/empty/error inconsistency — UX states
- `AUD-050` H6 inventory stale — Consistency
- `AUD-051` H6 four-tab vs live five-tab — Consistency
- `AUD-052` Mixed Navigator / GoRouter — Navigation
- `AUD-053` No chat edit/delete/media — Chat
- `AUD-054` Admin silent read of all threads — Privacy
- `AUD-055` Parent auto-seeds conversations — Chat
- `AUD-056` Same-day slots collapsed — Session
- `AUD-057` No closeout SSOT for old sessions — Session
- `AUD-058` Teacher student-chat assignedBy fallback — Chat
- `AUD-059` Mushaf default surah 67 — Product
- `AUD-060` Audio uploads disabled — Capability
- `AUD-061` No CI workflows — Production
- `AUD-062` No App Check — Security
- `AUD-063` Partial vs status remaining — Payments
- `AUD-064` Review vs parent resubmit race — Concurrency
- `AUD-065` Dual-read unbounded grants — Scalability
- `AUD-066` Supervisor reports tab vs hidden write stack — Reports
- `AUD-067` Broadcast comment vs live UI — Consistency
- `AUD-068` Scaffold background ignores dark — Theme
- `AUD-069` Phone on student profile — Privacy
- `AUD-070` No session timeout policy — Auth
- `AUD-071` No rules/authz tests — Tests
- `AUD-072` No widget coverage of role shells — Tests
- `AUD-073` No payment lifecycle integration — Tests
- `AUD-074` No progress calculation tests — Tests
- `AUD-075` Arabic-only validation copy — L10n
- `AUD-076` Fixed heights / inflexible Rows — Overflow
- `AUD-077` No failed-send retry model — Chat
- `AUD-078` Read state is array `readBy` — Scalability
- `AUD-079` Calendar locale hardcoded `ar` — L10n
- `AUD-080` Outstanding totals client-only — Payments
- `AUD-081` Posts feature unwired — Consistency
- `AUD-099` Student `isActive` badge has no toggle — Auth
- `AUD-101` Activity responseCount race — Concurrency

**P3:**

- `AUD-082` Back/chevron icon mix — Shared UI
- `AUD-083` Mixed NotoNaskh / Cairo — Shared UI
- `AUD-084` AppButton white spinner — Theme
- `AUD-085` Mock activity store leftover — Hygiene
- `AUD-086` Router debugLogDiagnostics enabled — Production
- `AUD-087` Error page Arabic-only — L10n
- `AUD-088` Arabic grade strings as SSOT — Data
- `AUD-089` Recitation dual “needs work” labels — Data
- `AUD-090` Admin stats cards show zero without caption — UX
- `AUD-091` Student default avatar fox — UX
- `AUD-092` Chat default title المعلم — L10n
- `AUD-093` Mixed Eastern/Western digits — L10n
- `AUD-100` supervisorProfiles unused — Data
- `AUD-102` استئذان vs اعتذار terminology — L10n

## Recovered document conflicts and precedence

1. `STUDENT_STATUS.md` explicitly says its Storage statements are partially superseded. Its older claim that Storage/audio upload is disabled conflicts with current D20/payment-proof/chat-media contracts and `FIREBASE_BILLING_CHECKLIST.md`; the newer production contract wins, while production billing remains unresolved.
2. `IMPLEMENTATION_PLAN.md`, `PRODUCT_DECISIONS_LOCKED.md`, and the historical matrix identify `69e4207` as the frozen planning baseline. The current branch is newer; the frozen tree remains historical evidence and has not been silently replaced as the proposed master base.
3. The Teacher plans (`TEACHER_HOME_IMPLEMENTATION_PLAN.md` and `TEACHER_DASHBOARD_1_432_IMPLEMENTATION_PLAN.md`) say “Awaiting approval / Plan only,” while later Teacher production-pass commits exist. This is a documentation/state conflict, not proof that every planned screen is complete.
4. `TEACHER_FIGMA_FLOW_IDENTIFICATION.md` corrects the older `TEACHER_HOME_UI_AUDIT.md` interpretation of the Figma frame. The corrected frame identification is the newer design evidence; implementation still requires separate workflow verification.
5. The original locked payment text says Vodafone Cash; its recorded amendment D2-A1 widens this to Vodafone Cash or InstaPay. The amendment is authoritative, while Paymob and wallet payment rails remain out.
6. Historical matrix status values (`Open`, `Missing contract`, `Product decision needed`, `Accepted / out of scope`, `Stale inventory`) differ from this register’s recovery statuses. No historical status was silently converted to `VERIFIED`; each unresolved record remains listed above.
