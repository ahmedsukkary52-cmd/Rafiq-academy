# BASMA — Engineering Quality Remediation Progress

**Started:** 2026-11-18  
**Plan:** `BASMA_ENGINEERING_QUALITY_REMEDIATION_PLAN.md`  
**Audit:** `BASMA_FINAL_ENGINEERING_QUALITY_AUDIT.md`  
**Phase 1 closeout review:** `BASMA_FINAL_ENGINEERING_QUALITY_REVIEW.md`  
**Roadmap:** `BASMA_REMAINING_WORK_ROADMAP.md`  
**Git baseline (Phase 1 start):** `HEAD bb0a905` · staged 39 · status_rows 303  

**Phase 1 disposition:** **CLOSED WITH DEFERRED FINDINGS** (EQ-B1–B6). Not overall engineering-quality complete.

RB-01 remains **CLOSED** (historical Full Suite `+2486 ~3`; **not re-run** on latest HEAD). RB-02 / RB-16 / RB-17 / RB-18 and D4 device-lab remain **OPEN**. EQ-M-06 deferred. No Cloud/signing/product ID changes claimed complete.

### Checkpoint note (2026-11-18, after Phase 1 batches)

| Checkpoint | Commit | Notes |
|------------|--------|-------|
| D2 Firestore/chat pagination | `daa8f85` | Historical batch rows below still record pre-commit `bb0a905` / staged-39 baselines |
| Strict EQ DI campaign (B1–B6 + EQ-2/3/4) | `0889682` | Excluded supervisor onboard product, D4/UX, PDF, docs from that commit |
| Focused EQ verification | **93** tests | Ran on the **full working tree** before commit — **not** an isolated commit-only tree |
| Current HEAD at docs sync | `0889682` | See `BASMA_REMAINING_WORK_ROADMAP.md` |

---

## Execution map (Phase 1)

| ID | Class | Priority | Status | Notes |
|----|-------|----------|--------|-------|
| EQ-P1-01 | Architectural | High | **Done (batch 1)** | Admin broadcast audience count: data layer + DI Firestore |
| EQ-P1-02 | Architectural + Defect | High | **Done (batch 1)** | Admin halaqa document load: data layer + DI Firestore (was `FirebaseFirestore.instance`) |
| EQ-P1-03 | Defect (error handling) | Medium | **Done (batch 1)** | `student_activities_page` no longer swallows all errors in AuthBloc reads |
| EQ-P1-04 | Maintainability | High | **Partial (batch 2–3 + EQ-4 DI)** | Ledger/settings Auth extracted; reports **repository GetIt done** (EQ-4); AdminBloc+PDF coupling deferred |
| EQ-P1-05 | Architectural | High | **Done for accounts/directory/complaints/assistant/reports samples** | GetIt registration + consumers; audio Auth still deferred |
| EQ-P1-06 | Architectural | High | **Done (batch 5)** | ChatGroupsRepository registered; presentation no longer builds Storage/Functions |
| EQ-P1-07 | Maintainability | High | Open | Mega-page splits (only when touching) |
| EQ-P1-08 | Critical | Critical | Blocked | Cloud rules/Functions/prod (owner Wave 0) |
| EQ-P1-09 | Test gap | Medium | Open | onboarding / review_schedule feature tests |
| EQ-P1-10 | Performance | Medium | Open | Eager ListView triage (measured) |
| EQ-P1-11 | Optional | Low | Deferred | Rename `teacher_evalutation_page` |
| EQ-P1-12 | Branding | Low | Partial | Settings fixed earlier; trial login still shows infra `rafiq-academy` (intentional ops copy) |

---

## Batch 1 — Admin Firestore extraction + Auth read reliability

### Problems addressed

1. **EQ-P1-01 / Q-H1 sample:** `admin_broadcast_page.dart` counted audience via `FirebaseFirestore.instance` in presentation → wrong Firebase app risk on emulator/local flavors; architecture leak.  
2. **EQ-P1-02 / Q-H1 sample:** `admin_halaqa_details_page.dart` same `instance` anti-pattern for halaqa doc load.  
3. **EQ-P1-03:** `student_activities_page.dart` used empty `catch (_)` around AuthBloc reads → swallowed unexpected errors.

### Not addressed (and why)

- Other admin Firebase pages — deferred to next batch to keep PR-sized.  
- Full DI registration of counters — injectable typedef defaults remain (same pattern as before; DI Firestore is the critical fix).  
- Quran/Mushaf empty catches — protected / separate review.  
- Cloud Critical items — owner gates.

### Files changed

| File | Change |
|------|--------|
| `lib/features/admin/data/admin_broadcast_audience_count.dart` | **New** — `countBroadcastAudienceForRole` |
| `lib/features/admin/data/admin_halaqa_document_loader.dart` | **New** — `loadAdminHalaqaDocument` |
| `lib/features/admin/presentation/pages/admin_broadcast_page.dart` | Default counter → data + `sl<FirebaseFirestore>()` |
| `lib/features/admin/presentation/pages/admin_halaqa_details_page.dart` | Doc load via data layer; preserved prior RTL chevron WT hunk |
| `lib/features/homework/presentation/pages/student_activities_page.dart` | Auth reads: rethrow unless `ProviderNotFoundException` |
| `test/features/admin/admin_broadcast_audience_architecture_test.dart` | **New** — layer/instance contract tests |

### Behavioral intent

- Audience count / halaqa details **same UX**; Firestore client now comes from GetIt (emulator-aware).  
- Activities page: unexpected Auth read failures **no longer silent** (tests without AuthBloc still OK).

### Tests (actual)

```text
flutter test test/features/admin/admin_broadcast_page_test.dart \
  test/features/admin/admin_broadcast_audience_architecture_test.dart \
  test/features/admin/admin_ops_broadcast_test.dart
→ All tests passed (5+)
```

```text
dart analyze <changed lib files>
→ No issues found (after dropping direct provider import)
```

### Risks remaining

- Presentation still imports data helpers for default loaders (pre-existing pattern); full usecase/DI registration is follow-up.  
- `runtimeType.toString()` check for ProviderNotFoundException is pragmatic without adding `provider` as a direct dependency.  
- Many other Firebase-in-UI sites unchanged.

### Git after batch 1

Recorded in the agent report for this turn (HEAD unchanged; staged count unchanged).

---

## Batch 2 — Admin payments ledger responsibility extraction

### Choice (ledger over reports)

| Candidate | Coupling | Extractable seam | Risk |
|-----------|----------|------------------|------|
| `admin_payments_ledger_page` | Self-contained `AdminPaymentsLedger` + local paging/filter machine | Load/filter/pagination + soft-fail summary; presentation labels | Low — existing fake-ledger widget tests |
| `admin_reports_page` | Tight with `AdminBloc`, PDF export, file picker, range presets, multi-type queries | Would need larger cut across bloc + PDF | Higher — easy to change export/filter UX |

**Selected:** `admin_payments_ledger_page` — clearest single responsibility (generation-guarded list session) without AdminBloc/PDF surface area. Reports deferred deliberately (not for file length).

### Problem / evidence

- Page owned filter/cursor/generation/loading/error **and** row/detail presentation in one State class (EQ-P1-04 / maintainability).
- Summary soft-fail and stale-fetch guards were hard to unit-test without widgets.
- Label/tone/date formatting duplicated across card + details.

### Responsibility extracted

1. **`AdminPaymentsLedgerSession`** (`ChangeNotifier`) — reload / `setFilter` / `loadMore`, generation guard, summary fire-and-forget soft-fail, user-facing page errors. Firestore stays in `AdminPaymentsLedger` (data); page keeps DI via `sl<FirebaseFirestore>()`.
2. **`admin_payment_ledger_labels.dart`** — date / chip label / tone only (no I/O).

Not extracted (intentionally): details-page load, proof image wiring, payment-architecture / ledger queries.

### Files changed

| File | Change |
|------|--------|
| `lib/features/admin/presentation/admin_payments_ledger_session.dart` | **New** — list/filter/paging session |
| `lib/features/admin/presentation/admin_payment_ledger_labels.dart` | **New** — presentation labels |
| `lib/features/admin/presentation/pages/admin_payments_ledger_page.dart` | Thin UI over session + labels; same filters/empty/error/pagination UX |
| `test/features/admin/admin_payments_ledger_session_test.dart` | **New** — session + labels unit tests |

### Behavioral intent

- Same filters, cursor paging, summary strip visibility on aggregate failure, empty copy, row → details navigation.
- No payment/Cloud/Quran changes.

### Tests (actual)

```text
flutter test test/features/admin/admin_payments_ledger_test.dart
→ All tests passed! (16)

flutter test test/features/admin/admin_payments_ledger_session_test.dart
→ All tests passed! (7)
  - labels (date/tone/awaiting-review)
  - reload / loadMore / setFilter
  - page failure keeps prior items
  - summary failure leaves list usable
  - stale in-flight fetch after reload ignored
```

Full Suite **not** run this batch.

### Analysis (actual)

```text
dart analyze lib/features/admin/presentation/admin_payments_ledger_session.dart \
  lib/features/admin/presentation/admin_payment_ledger_labels.dart \
  lib/features/admin/presentation/pages/admin_payments_ledger_page.dart \
  test/features/admin/admin_payments_ledger_session_test.dart \
  test/features/admin/admin_payments_ledger_test.dart
→ No issues found!
```

### Risks remaining

- Details page still loads record/history inline (acceptable; separate concern).
- Session still sits in presentation (not a domain usecase) — matches existing feature style; avoid over-abstracting.
- `admin_reports_page` and `admin_settings_tab` Firebase-in-UI paths unchanged.
- Stale `loadMore` that loses the race returns without forcing `loading=false` on the abandoned generation (pre-existing generation pattern; covered by unit test for ignored stale apply).

### Git before → after (Batch 2)

| | Before | After |
|--|--------|-------|
| HEAD | `bb0a905` | `bb0a905` (unchanged; no commit) |
| Staged files | 39 | 39 (staging untouched) |
| Status rows | ~312 | ~312+ (new untracked session/labels/tests + progress doc) |

No commit / push / reset / stash / checkout.

---

## Batch 3 — Admin settings Auth password-change extraction

### Choice

| Candidate in `admin_settings_tab` | Cohesive? | Decision |
|-----------------------------------|-----------|----------|
| `changeOwnPassword` (reauth + `updatePassword` + Auth code → Arabic `ServerException`) | Yes — single Auth orchestration with stable UX copy | **Extract** |
| `loginIdentifierLabel` | Pure presentation mapping; already unit-tested; no Firebase I/O | Leave in presentation |
| Navigation tiles / logout / import | UI routing only | Leave in widget |
| Expand `AuthRemoteDatasource` with change-password | Would regenerate DI/repo/usecase for one admin settings flow | Avoid — over-abstraction |

Auth repository already covers login/reset/logout only — no duplicate service existed to reuse. Followed Batch 1 data-helper + `sl<FirebaseAuth>()` pattern.

### Problem / evidence

- Final quality audit Q-H1 #3: Firebase Auth password path lived in the presentation page.
- Logic was already a top-level function (injectable via `PasswordChanger`) but still owned Auth SDK + error mapping inside the UI file.

### Responsibility extracted

- **`changeOwnPasswordWithAuth`** + **`adminChangeOwnPasswordMessage`** → `lib/features/admin/data/admin_change_own_password.dart`
- Presentation keeps a thin default `changeOwnPassword` → `sl<FirebaseAuth>()` + data helper; sheet/UI/validation unchanged.

### What remains in the widget (and why)

- Profile header from `AuthBloc`, tiles, logout confirmation, `ChangePasswordSheet` form/validation/busy/error SnackBar — presentation & interaction.
- Pre-existing unstaged UI hunks preserved (`SafeArea(bottom: false)`, access subtitle, section align, chevron).

### Files changed

| File | Change |
|------|--------|
| `lib/features/admin/data/admin_change_own_password.dart` | **New** — Auth orchestration + message map |
| `lib/features/admin/presentation/pages/admin_settings_tab.dart` | Delegate default changer to data + DI (pre-existing UI diffs kept) |
| `test/features/admin/admin_change_own_password_test.dart` | **New** — unit + architecture contract |

### Behavioral intent

- Same ordering: reauthenticate → updatePassword.
- Same Arabic `ServerException` messages and fail-closed missing session/email.
- Sheet still only surfaces `ServerException`; inject `PasswordChanger` for widget tests.

### Tests (actual)

```text
flutter test test/features/admin/admin_change_own_password_test.dart \
  test/features/admin/admin_settings_tab_test.dart --reporter expanded
→ All tests passed! (9)
  - message map
  - missing user/email fail-closed
  - success reauth+update
  - wrong-password (no update)
  - weak-password from update
  - architecture: data + sl<FirebaseAuth>(), no *.instance
  - existing settings widget/identifier tests
```

Full Suite **not** run. No Firebase Emulator required for these unit/widget fakes.

### Analysis (actual)

```text
dart analyze lib/features/admin/data/admin_change_own_password.dart \
  lib/features/admin/presentation/pages/admin_settings_tab.dart \
  test/features/admin/admin_change_own_password_test.dart \
  test/features/admin/admin_settings_tab_test.dart
→ No issues found!
```

### Risks remaining

- Presentation still imports the data helper for the default changer (same Batch 1 pattern).
- `admin_reports_page` Firebase/AdminBloc coupling unchanged.
- Directory/accounts DI gaps (EQ-P1-05) and chat Storage/Functions wiring (EQ-P1-06) open.
- Overlapping file: `admin_settings_tab.dart` already had unrelated unstaged UI edits before B3; Auth extraction only — those hunks untouched in intent.

### Git before → after (Batch 3)

| | Before | After |
|--|--------|-------|
| HEAD | `bb0a905` | `bb0a905` (unchanged; no commit) |
| Staged files | 39 | 39 (staging untouched) |
| `admin_settings_tab.dart` | Already unstaged `M` (UI) | Still unstaged `M` (UI + Auth delegate) |

No commit / push / reset / stash / checkout / staging change.

**EQ-B3 status:** complete (scoped extraction performed).

---

## Batch 4 — Directory / accounts DI boundary (EQ-P1-05 sample)

### Finding verification

| Claim | Current code | Verdict |
|-------|--------------|---------|
| Directory repo built in widget | `defaultDirectoryRepository()` constructed `FirestoreAcademyDirectoryRepository(firestore: sl<…>, functions: sl<…>)` in presentation | **Confirmed** — composition-root construction of concrete repo in UI (not `Firebase*.instance`) |
| No generated GetIt registration | No `@LazySingleton` / DiModule entry for directory or accounts | **Confirmed** |
| Deliberate composition-root only? | Pattern matches payments ledger defaults, but presentation still named the concrete class and re-built instances per page | **Partial leak** — clients were DI-correct; repository abstraction was not registered |
| Full Auth provisioning redesign needed? | No — callables/`AcademyAccountsRepository` semantics unchanged | Out of scope |

### Fix (smallest)

- Register existing `FirestoreAcademyDirectoryRepository` and `AcademyAccountsRepository` once in `registerDirectoryAndAccountsRepositories()` after generated `sl.init()` (manual; avoids rewriting staged `injection_container.config.dart`).
- `defaultDirectoryRepository()` → `sl<AcademyDirectoryRepository>()`.
- Admin onboard lazy `_repo` → `sl<AcademyAccountsRepository>()` (tests that inject submit/search never resolve GetIt).
- Supervisor onboard wrapper (directory-adjacent accounts entry) uses the same GetIt accounts repo.

**Not done:** migrating registrations into injectable codegen; remaining constructors in `admin_account_access_card`, `first_login_page`, `chat_groups_repository`; complaints/assistant DI gaps; AdminBloc for directory.

### Provisioning safety

No callable names, payloads, credential fields, role mapping, duplicate/`requestId` retry, or schema edits. UI tests still inject fake submit/search.

### Files changed

| File | Change |
|------|--------|
| `lib/core/di/injection_container.dart` | Register directory + accounts repos after init |
| `lib/features/directory/presentation/admin_directory_page.dart` | Resolve via `sl<AcademyDirectoryRepository>()` (pre-existing D4 lazy-list hunks kept) |
| `lib/features/accounts/presentation/admin_onboard_student_page.dart` | Resolve accounts via GetIt |
| `lib/features/supervisor/presentation/pages/supervisor_onboard_student_page.dart` | Same accounts resolution |
| `test/features/directory/directory_accounts_di_boundary_test.dart` | **New** — registration + source contract |

### Tests (actual)

```text
flutter test test/features/directory/directory_accounts_di_boundary_test.dart \
  test/features/directory/academy_directory_test.dart \
  test/features/directory/directory_domain_test.dart \
  test/features/accounts/admin_onboard_student_page_test.dart --reporter expanded
→ All tests passed! (33)  exit 0
```

Full Suite **not** run. No live provisioning / emulator account creation.

### Analysis (actual)

```text
dart analyze <EQ-B4 touched files>
→ 1 info: prefer_const_constructors on admin_directory_page.dart:381
  (pre-existing D4 UI hunk; not introduced by DI change)
→ No errors / warnings from this batch’s DI edits
```

### Risks remaining

- Manual GetIt registration parallel to injectable graphs (document for future `@LazySingleton` codegen when config is safely regenerable).
- Other accounts construction sites still build `AcademyAccountsRepository(...)` locally.
- EQ-P1-05 remainder: complaints / assistant / staff.
- EQ-P1-06 chat Storage/Functions presentation wiring open.
- Staged `injection_container.config.dart` untouched.

### Git before → after (Batch 4)

| | Before | After |
|--|--------|-------|
| HEAD | `bb0a905` | `bb0a905` |
| Staged files | 39 | 39 (staged content unchanged; config still staged-only prior work) |
| Status rows | 314 | 316 (+ DI boundary test; supervisor onboard was already untracked / edited) |

Pre-existing overlap: `admin_directory_page.dart`, `admin_onboard_student_page.dart` already unstaged (D4 / supervisor title flags). No commit/push/stage/reset/stash.

**EQ-B4 status:** complete (confirmed DI boundary fixed for directory + onboard sample).

---

## Batch 5 — Chat groups Storage/Functions DI boundary (EQ-P1-06)

### Finding verification

| Claim | Current code | Verdict |
|-------|--------------|---------|
| Presentation builds Storage/Functions repos | `resolveChatGroupsRepository()` constructed `ChatGroupsRepository(firestore/functions/storage: sl<…>)`; `chat_room` gated on three Firebase registrations | **Confirmed** |
| Bypass of existing chat abstractions? | Message send/media already go through injectable `ChatRemoteDatasource` / `ChatRepository` (Storage+Functions). Groups/oversight used a **sibling** repo never registered | **Confirmed partial** — not a second Storage stack; missing GetIt registration |
| Merge into ChatRepository? | Would redesign group callables into the D2 message repository | Rejected — too large; preserve ownership |

### Fix (smallest)

- Register existing `ChatGroupsRepository` once via `registerChatGroupsRepository()` after `sl.init()` (same manual GetIt pattern as EQ-B4; no staged injectable regen).
- `resolveChatGroupsRepository()` → `sl<ChatGroupsRepository>()`.
- `chat_room` availability check → `sl.isRegistered<ChatGroupsRepository>()` (drops direct Firebase client imports from that path).

Admin inbox / embedded pages keep calling `resolveChatGroupsRepository()` and inherit the fix.

### Chat runtime contracts preserved

No changes to send/edit/delete, uploads, progress/cancel, pagination, D2 live-window/cursors, refresh generations, callables, paths, or copy. Widget tests still inject `groups:` / `bloc:` fakes.

### Files changed

| File | Change |
|------|--------|
| `lib/core/di/injection_container.dart` | `registerChatGroupsRepository()` |
| `lib/features/chat/presentation/chat_groups_provider.dart` | Resolve via GetIt only |
| `lib/features/chat/presentation/pages/chat_room.dart` | Register check on repo type (pre-existing UI gradient hunks kept) |
| `test/features/chat/chat_groups_di_boundary_test.dart` | **New** — registration + source contract |

### Tests (actual)

```text
flutter test test/features/chat/chat_groups_di_boundary_test.dart \
  test/features/chat/chat_groups_messaging_test.dart \
  test/features/chat/chat_room_page_test.dart \
  test/features/chat/chat_repository_watch_test.dart --reporter expanded
→ All tests passed! (28)  exit 0
```

Full Suite **not** run. No live Firebase / emulator chat traffic.

### Analysis (actual)

```text
dart analyze lib/core/di/injection_container.dart \
  lib/features/chat/presentation/chat_groups_provider.dart \
  lib/features/chat/presentation/pages/chat_room.dart \
  test/features/chat/chat_groups_di_boundary_test.dart
→ No issues found!
```

### Risks remaining

- Manual GetIt registration (not injectable codegen) for groups repo.
- `ChatGroupsRepository.searchPeople` still constructs a local `AcademyAccountsRepository` with its injected clients (data-layer; not presentation).
- Staged D2 chat bloc/datasource hunks untouched by this batch.
- EQ-P1-05 remainder: complaints/assistant; leftover accounts constructors (`first_login`, `admin_account_access_card`).
- EQ-P1-04 reports still open.

### Git before → after (Batch 5)

| | Before | After |
|--|--------|-------|
| HEAD | `bb0a905` | `bb0a905` |
| Staged files | 39 | 39 (unchanged; chat_room/provider/container not staged) |
| Status rows | 316 | 318 (+ boundary test; provider now modified) |

Overlap: `chat_room.dart` already had unstaged UI gradient edits; `injection_container.dart` already carried EQ-B4 registrations. No commit/push/stage/reset/stash.

**EQ-B5 status:** complete (confirmed presentation Storage/Functions construction removed for groups repo).

---

## Batch 6 — Remaining `AcademyAccountsRepository` construction sites

### Constructor inventory (all `AcademyAccountsRepository(` / type uses)

| Site | Classification | Action |
|------|----------------|--------|
| `injection_container.dart` `registerDirectoryAndAccountsRepositories` | (1) Composition-root | **Retain** |
| `academy_accounts_repository.dart` class constructor | Definition | **Retain** |
| `admin_onboard_student_page` / `supervisor_onboard_student_page` | Already `sl<>` (B4) | No change |
| `first_login_page` default `_submitter` | (2) Presentation construction | **→ `sl<AcademyAccountsRepository>()`** |
| `admin_account_access_card` default reset | (2) Presentation construction | **→ `sl<AcademyAccountsRepository>()`** |
| `ChatGroupsRepository.searchPeople` local ctor | (3) Data-layer ownership smell | **Inject `accounts` via constructor; DI supplies `sl<>`** |
| Test source asserts / fakes | (4) Test-only | Updated contracts |

No obsolete occurrences found. `_defaultParents` on the access card still uses `sl<FirebaseFirestore>()` for parent links — **not** an accounts-repo ctor; deferred (separate presentation Firestore read).

### Why chat `searchPeople` changed

Reusing `searchMembers` is legitimate accounts ownership (same indexes). Per-call `AcademyAccountsRepository(...)` duplicated the registered singleton. Injecting `accounts` at composition root keeps chat→accounts data dependency explicit without GetIt inside methods or circular features.

### Files changed

| File | Change |
|------|--------|
| `lib/features/auth/presentation/pages/first_login_page.dart` | Default submit via GetIt (UI copy hunks preserved) |
| `lib/features/accounts/presentation/admin_account_access_card.dart` | Default reset via GetIt |
| `lib/features/chat/data/chat_groups_repository.dart` | Required `accounts` field; `searchPeople` uses it |
| `lib/core/di/injection_container.dart` | Pass `accounts: sl<AcademyAccountsRepository>()` into groups repo |
| `test/features/directory/directory_accounts_di_boundary_test.dart` | Assert first-login + access card |
| `test/features/chat/chat_groups_di_boundary_test.dart` | Assert accounts wiring |

### Behavior preservation

First-login submit/login sequence, access-card confirm/reset/credentials display, chat people-search query/roles/excludeUid/error mapping unchanged. Test seams (`submit` / `reset`) unchanged.

### Tests (actual)

```text
flutter test test/features/accounts/first_login_and_access_test.dart \
  test/features/directory/directory_accounts_di_boundary_test.dart \
  test/features/chat/chat_groups_di_boundary_test.dart \
  test/features/chat/chat_groups_messaging_test.dart
→ All tests passed! (22)

# Boundary pair alone (also green):
flutter test …directory_accounts_di_boundary… …chat_groups_di_boundary…
→ All tests passed! (4)
```

Full Suite **not** run.

### Analysis (actual)

```text
dart analyze <EQ-B6 touched lib + boundary tests>
→ No issues found!
```

### Remaining DI / Phase 1 findings (deferred)

- `admin_account_access_card._defaultParents` Firestore reads in presentation.
- Complaints / assistant / staff full DI graphs (EQ-P1-05 remainder).
- `admin_reports_page` AdminBloc+PDF (EQ-P1-04) — higher blast radius.
- Mega-page splits (EQ-P1-07), Cloud Critical (EQ-P1-08 owner), onboarding/review_schedule test gaps (EQ-P1-09), measured ListView triage (EQ-P1-10).
- Manual GetIt registrations awaiting injectable regen when staged config is safe.

### Git before → after (Batch 6)

| | Before | After |
|--|--------|-------|
| HEAD | `bb0a905` | `bb0a905` |
| Staged | 39 | 39 (unchanged) |
| Status rows | 318 | 320 |

Overlap: `first_login_page.dart` / `injection_container.dart` already unstaged. No commit/push/stage/reset/stash.

**EQ-B6 status:** complete.

---

## Phase 1 disposition

**B — Close with deferred findings.**

Confirmed high-priority, safe, in-scope presentation→Firebase / missing-GetIt samples from the remediation plan (admin broadcast/halaqa DI, ledger session, settings password, directory/accounts registration, chat groups Storage/Functions, remaining accounts ctors) are addressed across EQ-B1–B6. Remaining items are real but belong to separate higher-risk or owner-gated work (reports/PDF, complaints/assistant graphs, Cloud Wave 0, test-gap campaigns, measured performance).

Phase 1 engineering-quality **remediation campaign** may close under disposition B; overall engineering quality / release readiness is **not** claimed complete.

---

## EQ-2 — Access-card linked parents extraction (EQ-M-04)

### Finding

**Confirmed:** `_defaultParents` in `admin_account_access_card` queried `parentProfiles` (`childrenIds` arrayContains) then `users/{id}` for names via `sl<FirebaseFirestore>()` in presentation.

### Abstraction chosen

Extend existing **`AcademyAccountsRepository.listLinkedParentsForStudent`** (already GetIt-registered) — same feature ownership as password reset / member search; no new competing parent source.

### Behavior preserved

- `parentProfiles` + `childrenIds` arrayContains + `limit(3)`
- Name from `users` doc; empty string if missing
- **No** `isActive` filter (historical access-card semantics; differs from `searchMembers`)
- Presentation still swallows load errors so student reset remains available
- `loadParents` / `reset` test seams unchanged

### Files

| File | Change |
|------|--------|
| `lib/features/accounts/data/academy_accounts_repository.dart` | `listLinkedParentsForStudent` |
| `lib/features/accounts/presentation/admin_account_access_card.dart` | Default load via `sl<>().listLinkedParentsForStudent` |
| `test/features/accounts/list_linked_parents_for_student_test.dart` | **New** unit + source contract |

### Tests / analyze

```text
flutter test test/features/accounts/list_linked_parents_for_student_test.dart \
  test/features/accounts/first_login_and_access_test.dart
→ All tests passed! (11)

dart analyze <touched files> → No issues found!
```

Full Suite / emulator **not** run.

### Git (EQ-2)

HEAD `bb0a905` · staged 39 unchanged · no commit/push/stage. Overlap: access card + accounts repo already unstaged (B6 / supervisor onboard).

**EQ-2 status:** complete. Phase 1 remains closed (not reopened).

### Next recommendation after EQ-2

Owner/lab unavailable for G0/G1 → **EQ-3 complaints/assistant DI sample** (roadmap). If owner ready for Cloud/signing → **G0**; if device lab ready → **G1**.

---

## EQ-3 — Complaints / Assistant DI (EQ-M-02 / EQ-M-03)

### Findings

| Site | Issue | Verdict |
|------|-------|---------|
| `complaints_entry.defaultComplaintsRepository` | Built `ComplaintsRepository` with `sl` Firebase clients | **Confirmed** → fixed |
| `assistant_home_page.defaultCoverDutyRepository` | Built `FirestoreCoverDutyRepository` with `sl` clients | **Confirmed** → fixed |
| `teacher_cover_banner` | Gated on `isRegistered<FirebaseFirestore>()` | **Confirmed** → fixed |
| Pages that take injected `repository` | Test/composition seams | **Retain** (not violations) |
| Repo unit tests constructing with fakes | Test-only | **Retain** |

### Fix

- `registerComplaintsAndAssistantRepositories()` after `sl.init()` (manual GetIt; no injectable regen / staged config touch).
- Defaults → `sl<ComplaintsRepository>()` / `sl<CoverDutyRepository>()`.
- Banner gate → `isRegistered<CoverDutyRepository>()`.

### Behavior preserved

No callable/path/status/attendance/UI changes. Widget tests still inject fake repos.

### Files

| File | Change |
|------|--------|
| `lib/core/di/injection_container.dart` | Register complaints + cover-duty |
| `lib/features/complaints/presentation/complaints_entry.dart` | GetIt resolve |
| `lib/features/assistant/presentation/assistant_home_page.dart` | GetIt resolve |
| `lib/features/assistant/presentation/teacher_cover_banner.dart` | Repo registration check |
| `test/features/complaints/complaints_assistant_di_boundary_test.dart` | **New** |

### Tests / analyze

```text
flutter test test/features/complaints/complaints_assistant_di_boundary_test.dart \
  test/features/complaints/complaints_pages_test.dart \
  test/features/complaints/complaints_repository_test.dart \
  test/features/assistant/assistant_home_page_test.dart
→ All tests passed! (22)

dart analyze <EQ-3 touched files> → No issues found!
```

Full Suite **not** run.

### Git

HEAD `bb0a905` · staged 39 unchanged · `injection_container.dart` already unstaged (B4–B6). No commit/stage/checkpoint.

**EQ-3 status:** complete. Phase 1 remains closed (not reopened). Overall engineering/release **not** complete.

### Next after EQ-3

If no owner/lab: **EQ-4 Admin reports DI** (careful; no PDF rewrite) **or** prefer **G0/G1** when available. Recommend documenting G0/G1 blockers and scheduling EQ-4 only as local engineering follow-on.

---

## EQ-4 — Admin Reports DI (EQ-M-01 / EQ-P1-04 remainder — DI only)

### Findings (inspect)

| Site | Issue | Verdict |
|------|-------|---------|
| `admin_reports_page` default repo | Built `AdminReportsRepository(firestore: sl<FirebaseFirestore>())` in presentation | **Confirmed** → fixed |
| Optional `repository:` ctor | Test/composition seam | **Retain** |
| AdminBloc roster/teachers load on reports page | Presentation↔bloc coupling | **Deferred** (higher blast radius; not a GetIt leak) |
| PDF / export / fonts / CSV / filters | Report behavior | **Out of scope** — untouched |
| `admin_report_pdf.dart` pre-existing unstaged edits | Unrelated dirty tree | **Do not rewrite** |

### Fix

- `registerAdminReportsRepository()` after `sl.init()` (manual GetIt; no injectable regen / staged config touch).
- `defaultAdminReportsRepository()` → `sl<AdminReportsRepository>()`.
- Page default: `widget.repository ?? defaultAdminReportsRepository()`.

### Deferred (documented, not forced)

- AdminBloc dependency for roster/teachers on the reports page.
- PDF generator / export / Arabic font / page split (EQ-M-07).
- Full “thin reports UI” extraction beyond repository registration.

### Behavior preserved

Report queries, aggregations, filters, CSV/PDF export, download/share/print, and widget test injection seams unchanged.

### Files

| File | Change |
|------|--------|
| `lib/core/di/injection_container.dart` | `registerAdminReportsRepository` |
| `lib/features/admin/presentation/pages/admin_reports_page.dart` | GetIt resolve; drop direct Firestore import |
| `test/features/admin/admin_reports_di_boundary_test.dart` | **New** |

### Tests / analyze

```text
flutter test test/features/admin/admin_reports_di_boundary_test.dart \
  test/features/admin/admin_reports_test.dart \
  test/features/admin/admin_report_export_test.dart
→ All tests passed! (18)

dart analyze <EQ-4 touched files> → No issues found!
```

Full Suite **not** run.

### Git

HEAD `bb0a905` · staged 39 unchanged · `injection_container.dart` already unstaged (B4–EQ-3). `admin_report_pdf.dart` left alone. No commit/stage/checkpoint.

**EQ-4 status:** complete (DI registration only). Phase 1 remains closed (not reopened). Overall engineering/release **not** complete.

### Next after EQ-4

Prefer **G0** (owner Cloud/signing) or **G1** (device lab) when available. Local follow-on without owner/lab: **EQ-M-05 audio Auth coupling** or **T1** suite hygiene — **do not start EQ-5/PDF redesign** unless separately approved.

---

## Checkpoint — Strict EQ DI commit (2026-11-18)

**Later note (does not rewrite batch evidence above):** The approved strict EQ DI campaign (hub + helpers + consumers + boundary tests; no D4/UX/supervisor-onboard/PDF/docs) was committed as **`0889682`** (parent **`daa8f85`**). Pre-commit focused verification: **93** tests on the **full working tree** (boundary/unit + consumer suites). Full Flutter Suite **not** re-run. EQ-M-06 remains deferred. Next: documentation sync, then G0/G1 by owner/lab availability.
