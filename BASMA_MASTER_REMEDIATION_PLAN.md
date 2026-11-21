# BASMA Master Remediation Plan

Status: PART A CLOSED — INVENTORY/RECONCILIATION ONLY. R1 IN PROGRESS on current branch `unify/basma-v1` at `bb0a905`; no release approval. Integration/Foundation remain preserved dirty snapshots and are not recovered or integrated.

**2026-11-16 Stage A–C principal audit:** completed (discovery + classification + plan only). Authoritative next-wave remediation narrative: [`docs/engineering-audit/BASMA_REMEDIATION_PLAN.md`](docs/engineering-audit/BASMA_REMEDIATION_PLAN.md). Executive map: [`docs/engineering-audit/BASMA_FINAL_ENGINEERING_REPORT.md`](docs/engineering-audit/BASMA_FINAL_ENGINEERING_REPORT.md).

**2026-11-16 Stage D0:** completed — local security/chat regression harness + docs (`BASMA_D0_VERIFICATION_REPORT.md`). Status **PASS WITH GAPS** (Flutter full suite / live re-probe not run; git CLI blocked on agent host).

**2026-11-17 Stage D2:** completed — chat cursor pagination (BASMA-103), inbox/query bounds (BASMA-104/107 partial), lifecycle fixes, unit tests, docs under `docs/engineering-audit/BASMA_D2_*.md`. Status **PASS WITH GAPS**. **No commit/push yet — awaiting owner approval of commit proposal.** **Do not start D1/D3/D4 without separate owner approval.** No cloud deploy in D2.

## Source of truth and preservation

- Current repository: `D:\flutter projects\rafiq_academy-unify`.
- Historical audit baseline: `feature/full-product-audit` at `69e4207`.
- Product locks remain authoritative in `docs/production/PRODUCT_DECISIONS_LOCKED.md`.
- The current worktree contains pre-existing tracked and untracked changes. They are preserved; no reset, checkout, stash, clean, staging, commit, push, merge, deployment, migration, or production data operation is authorized.
- Registered worktrees, including the dirty integration and release worktrees, are preserved and must be reviewed before any integration decision.
- Protected Quran source/derived data is excluded from inspection and processing.

## Recovered implementation streams

1. **Security/data contracts:** current history includes Wave A rules, privacy, billing, sessions, membership, chat, notification, projection, and authority work after the frozen audit.
2. **Backend authority:** Functions include callable and emulator-test work for provisioning, billing, sessions, membership, chat, FCM, awards, relationships, and meeting-link policy. Production enablement remains gated.
3. **Role UI passes:** parent, admin, student, supervisor, and teacher branches/worktrees contain valuable but independently scoped work. They are not interchangeable and must not be merged by assumption.
4. **Release preparation:** flavor, signing, Codemagic, and iOS preparation exists locally, but production Firebase, billing, signing, Apple, and CI gates remain open.
5. **A/C/D focused work:** Admin toggle, Supervisor enrollment, and AudioLibrary corrections are implemented in the current worktree, with focused mocked tests previously passing. Emulator/device verification is still separate work.

## Worktree and branch divergence inventory

Comparison command: `git rev-list --left-right --count unify/basma-v1...<branch>`; counts are `current-only / branch-only`.

| Worktree / branch | HEAD | Divergence | Recovery value / status |
|---|---|---:|---|
| `rafiq_academy` / `feature/parent-interface` | `62fac62` | `57 / 0` | Parent/emulator safety history is already reachable; worktree clean at inventory time. |
| `rafiq_academy-admin-agent3-home` / `feature/admin-agent3-home` | `2c75b04` | `81 / 0` | Admin UI commits reachable; worktree clean at inventory time. |
| `rafiq_academy-full-audit` / `feature/full-product-audit` | `69e4207` | `63 / 0` | Frozen audit baseline; preserve as historical evidence, not current source of truth. |
| `rafiq_academy-student` / `feature/student-production-pass` | `aeff001` | `65 / 0` | Student production-pass commits reachable; generated Windows files were dirty. |
| `rafiq_academy-teacher` / `feature/teacher-production-pass` | `82fecf1` | `65 / 0` | Teacher production-pass commits reachable; generated Windows files were dirty. |
| `rafiq_academy-foundation` / `foundation/c66753d` | `796e3de` | `10 / 0` | Backend test/Node 22 foundation reachable; worktree has local changes and untracked files. |
| `rafiq_academy-supervisor-agent3-roster` / `feature/supervisor-agent3-roster` | `70362e0` | `81 / 1` | One unique roster-refresh commit; preserve and review before adaptation. |
| `rafiq_academy-integration` / `feature/ios-codemagic-unsigned-check` | `c66753d` | `27 / 0` | No branch-only commits relative to current; large dirty implementation set remains the highest preservation risk. |
| `rafiq_release_wt` / `release/ios-unsigned-check` | `97ce920` | `66 / 3` | Three branch-only release commits plus dirty configuration; preserve pending release review. |
| Temporary verification worktrees | detached | n/a | Four detached worktrees; preserve and inventory independently. |

### Exact local status counts

Counts come from `git status --porcelain=v1` metadata only. Quran paths were excluded from displayed path summaries and were not opened or processed.

| Full path | Branch / detached | HEAD | Modified status entries | Untracked status entries |
|---|---|---|---:|---:|
| `D:\flutter projects\rafiq_academy` | `feature/parent-interface` | `62fac62848f3f81c10c88f9ae92088154f54c7d0` | 0 | 0 |
| `D:\flutter projects\rafiq_academy-admin-agent3-home` | `feature/admin-agent3-home` | `2c75b049f218aaa54f10629eb4fa6c7b09ce4bc0` | 0 | 0 |
| `D:\flutter projects\rafiq_academy-foundation` | `foundation/c66753d` | `796e3de4f9e469a9cd6a2c13f9c4c85317d30548` | 276 | 83 |
| `D:\flutter projects\rafiq_academy-full-audit` | `feature/full-product-audit` | `69e4207801b17fc5dede30d82b07d4a48a6a1c92` | 0 | 0 |
| `D:\flutter projects\rafiq_academy-integration` | `feature/ios-codemagic-unsigned-check` | `c66753d49a11e93a0f0c628a771a1093c3dd6960` | 217 | 115 |
| `D:\flutter projects\rafiq_academy-student` | `feature/student-production-pass` | `aeff001d5518de080842f238f74449e100fc95c3` | 3 | 0 |
| `D:\flutter projects\rafiq_academy-supervisor-agent3-roster` | `feature/supervisor-agent3-roster` | `70362e0bc592c57f3b18fc7a255c82889864f5a3` | 0 | 0 |
| `D:\flutter projects\rafiq_academy-teacher` | `feature/teacher-production-pass` | `82fecf123b5bb92c2b376fc9deabf449c13c37e1` | 3 | 0 |
| `D:\flutter projects\rafiq_academy-unify` | `unify/basma-v1` | `bb0a90585adb9ee684848cd547cb234cff2a47fa` | 45 | 15 |
| `D:\rafiq_release_wt` | `release/ios-unsigned-check` | `97ce920a83b9be4788f5e78bc0ed8beb071b7025` | 12 | 0 |
| `D:\Temp\basma_verify_wt_10256bd` | detached | `10256bd03bf336939183cce71ae4f0dcce410b25` | 9 | 1 |
| `D:\Temp\rafiq_foundation\run` | detached | `42db9c72a6e392a24f80370fa7e37e606e3d9445` | 1246 | 0 |
| `D:\Temp\rafiq_foundation\verify` | detached | `796e3de4f9e469a9cd6a2c13f9c4c85317d30548` | 234 | 139 |
| `D:\Temp\rafiq_foundation\wt` | detached | `42db9c72a6e392a24f80370fa7e37e606e3d9445` | 1246 | 0 |

Historical lead commits are present and inspectable: `0d8026c`, `42db9c7`, `4df4a19`, `3a4de04`, `54a09fa`, and `bc98706`. They are historical trial commits, not instructions to cherry-pick or merge.

## Dirty snapshot recovery classification

### Integration worktree

Metadata comparison against current HEAD `bb0a905` produced:

- 77 status paths matching the current branch content.
- 136 tracked paths with content differing from current HEAD.
- 115 untracked paths not present in current HEAD.
- 4 generated/artifact paths (`pubspec.lock` and generated Windows plugin files).

Important groups present in the dirty snapshot:

- **Functions:** admin provisioning/billing, payment review, sessions, lifecycle, notifications/FCM, search, audit, and Paymob quarantine changes; plus untracked migration, billing, achievements, FCM ownership, meeting-link, and emulator-test files.
- **Rules/security:** `firestore.rules`, `storage.rules`, indexes, rules tests, deactivation/privacy/media tests.
- **Payments:** payment proof submission/review, payment destinations, family billing, amount/status contracts, parent UI/tests.
- **Sessions:** schedule/session materialization and session-record changes plus contract tests.
- **Chat/FCM:** chat/message policy, media policy, FCM token ownership/revocation and foreground-push changes.
- **Role UI:** Admin finance/payment/operations, Parent payment/achievements, Supervisor payments/awards, Student meeting links, Teacher activity/profile changes.
- **Release:** Android manifests/build configuration, `codemagic.yaml`, Firebase flavor/configuration changes.

Classification: this snapshot contains both content already matching current and substantial new/alternate implementations. It is not safe to merge as one unit. It requires file-level contract comparison and dependency-aware extraction.

### Foundation worktree

Metadata comparison against current HEAD produced:

- 184 status paths matching current branch content.
- 87 tracked paths differing from current HEAD.
- 81 untracked paths not present in current HEAD.
- 3 generated Windows plugin paths.

Against Integration’s dirty snapshot:

- 130 shared status paths.
- Only 3 shared regular files had identical content hashes: generated Windows plugin registrant files and `fcm_sign_out_preparation.dart`.
- 119 shared regular files had different content hashes.
- 202 Integration-only status paths.
- 225 Foundation-only status paths.

Foundation therefore contains independent/alternate work and is not merely disposable duplicate output. Its large set of modified and untracked files requires separate preservation and contract review.

### Temporary detached `run` and `wt`

Both have:

- HEAD `42db9c72a6e392a24f80370fa7e37e606e3d9445`.
- 1246 modified status entries.
- 0 untracked entries.
- All 1246 entries are identical deletions (` D`).
- 1192 non-protected status entries were compared; both status manifests produced the same SHA-256:
  `503eb216a02236218836a162ad4dec483896a0f45c58a1f5914e8a9651611832`.
- No Quran/protected path was opened or hashed.

They are metadata-identical deletion snapshots, not two independently differing implementations.

### Release worktree

Unique commits absent from current:

- `dce41f0` — isolated iOS flavors and release signing setup.
- `18dac38` — Android dev check on macOS CI.
- `97ce920` — chat authorization test correction and optional UI captures.

The 12 local modifications affect Android build/manifest configuration, iOS flavor xcconfigs and `Info.plist`, app entry/version configuration, two tests, and generated Windows plugin files. This work is valuable for release preparation but must remain separate from production feature integration until CI/build evidence exists.

## Dependency-aware execution roadmap

### R0 — Recovery and control (current)
- Maintain this plan, `BASMA_MASTER_ISSUE_REGISTER.md`, and `BASMA_RELEASE_READINESS.md`.
- Reconcile the historical 102-item matrix against current commits and current code; do not close items from historical claims alone.
- Inventory dirty worktrees and compare contracts before adapting valuable changes.

### R1 — Security and data integrity
- Run Firestore and Storage rules tests against current rules.
- Run callable authority/emulator suites for membership, staff scope, payments, sessions, chat, relationships, FCM, meetings, and account lifecycle.
- Verify `firebase.json` wiring and release deployment order without deploying.

**Current evidence:** Firestore rules `276/276`, Storage rules `67/67`, PH02 `76/76`, P0 `25/25`, billing `5/5`, chat/media `14/14`, B14 meeting links `6/6`, and parent achievements `7/7` passed under the local `demo-rafiq-rules` Emulator with exit code 0. The Parent Halaqat/Schedule exported-wrapper suite passed `5/5` with Auth + Functions + Firestore Emulator. The additional high-risk bundle passed `33/33`; assignment source-write trigger passed `1/1`; absence-request source-write trigger passed `1/1`; FCM synthetic handler suite passed `19/19`; and the isolated overdue pass/idempotency harness passed `1/1`. The previous PH02 `75/1` result was not reproducible in the required serial command. The active export inventory contains 64 Functions: 52 callables, 11 triggers, and 1 scheduled function. Strict wrapper evidence is now 22/52; 30 are Core-only and none remain in the former not-run category. R1-G's initial combined harness timed out, so it was split into Membership, Staff/Cover, Payments, and Chat Groups; all four isolated HTTP Emulator groups passed with exit code 0. Trigger evidence is 9 source-write paths, 2 synthetic-handler paths, 0 incidental/partial paths, and 0 confirmed untested triggers. The projection/group source-write suite passed 1/1 and covered the five previously partial triggers. R1 remains open for the remaining 30 callable wrappers, broader non-sensitive direct-write mapping, Flutter cross-role workflows, FCM/device delivery, scheduled-runtime wiring, and production configuration comparison.
- Record every remaining direct-write or scope gap as a tracked issue. The bounded inventory contains 15 path families and 22 main write operations; aggregate rules results are not treated as individual allowed/denied proof for all 22.

### R2 — Critical business workflows
- Verify Admin-controlled account provisioning and lifecycle.
- Verify invoice creation, proof submission/review, overdue/grace, and payment-access policy.
- Verify parent-child relationship writer and isolation.
- Verify first-class sessions, attendance, evaluation gates, and closeout.
- Verify membership admission/transfer/exit and roster refresh.

### R3 — Cross-role product workflows
- Verify Quran journey semantics and progress projection without accessing protected Quran data.
- Verify chat relationship/group/media workflows and FCM delivery.
- Verify teacher attendance/evaluation, supervisor scope, admin finance/operations, and parent reporting end-to-end.
- Remove or wire every visible dead action discovered by evidence.

### R4 — Shared architecture and UX
- Consolidate only proven duplicate data access, error mapping, navigation, and shared UI patterns.
- Preserve authorization boundaries while reducing repeated listeners and requests.
- Complete Arabic RTL BASMA branding review, including Android launch assets and splash behavior.

### R5 — Release gates
- Close Firebase project/configuration, Blaze/budget, signing, Codemagic, iOS, store metadata, privacy, and device verification gates.
- Build and test release artifacts only after owner-controlled credentials and project decisions are supplied.

## Feature-level dirty snapshot assessment

This assessment uses path inventories, current-branch contracts, existing test inventories, and metadata/content comparisons. It is not a Production Audit and no snapshot code was executed or merged.

### Count reconciliation

- **Foundation:** raw status was 276 modified + 83 untracked = 359. Four entries are protected/excluded paths (2 modified, 2 untracked), leaving 355 eligible entries. Those classify as 184 same-as-current, 87 different tracked files, 81 new files, and 3 generated files. The arithmetic is `184 + 87 + 81 + 3 = 355`; generated files are separated from same/different.
- **Integration:** raw status was 217 modified + 115 untracked = 332, with no excluded entries. Those classify as 77 same-as-current, 136 different tracked files, 115 new files, and 4 generated files. The arithmetic is `77 + 136 + 115 + 4 = 332`.
- **Integration/Foundation shared paths:** 130 shared status paths comprise 95 modified/modified, 6 Integration-modified/Foundation-deleted, 5 untracked/untracked, 23 Integration-untracked/Foundation-modified, and 1 Integration-untracked/Foundation-deleted. File comparison produced 3 identical regular-file hashes, 119 different regular-file hashes, and 8 missing/non-file cases. Therefore `3 + 119 + 8 = 130`; the eight are deleted Foundation paths or directory entries, not omitted hashes.

### Recovery classifications

| Group | Current branch evidence | Snapshot value | Compatibility / tests | Classification |
|---|---|---|---|---|
| Auth and account provisioning | Current branch has Admin provisioning, onboarding, lifecycle, Auth guards, and locked D1 requiring Admin-controlled provisioning. | Integration contains provisioning/auth/privacy changes and callable tests; Foundation contains alternate Auth/DI/router changes. | D1-compatible in principle, but identity lifecycle, first-login gate, contact-field policy, and DI/router differences require contract comparison. Existing tests prove selected guards only, not full role onboarding. | **RECOVER AFTER REVIEW** |
| Firestore/Storage Rules | Current rules are wired and current emulator suites passed: Firestore 276/276 and Storage 67/67. | Both snapshots modify rules/tests; Integration adds broader privacy/media/deactivation coverage. Foundation has an alternate rules state. | Rules are security-critical and additive; any alternate rules version must be compared against current tests and B14/payment contracts. | **RECOVER AFTER REVIEW** |
| Functions and callable authority | Current branch contains authority helpers, provisioning, membership, billing, sessions, chat, audit, and emulator-test infrastructure. | Integration adds/changes admin, billing, lifecycle, sessions, notifications, search, migration guards, and emulator suites. Foundation contains a smaller alternate Functions/test set. | Callable tests establish contract cases only when executed; no snapshot code was executed in this step. Production gate and demo-project guard remain dependencies. | **RECOVER AFTER REVIEW** |
| Payments and payment review | Current history includes proof submission/review, invoice/payment contracts, overdue/grace, and payment-access concepts. | Integration adds family billing, payment destinations, proof-cycle, review amount, Admin/Supervisor payment UI and tests. | Compatible with external payment plus proof/review when preserving D2/D2-A1 and no wallet/Paymob path. Payment schema and callable response compatibility must be checked. | **RECOVER AFTER REVIEW** |
| Sessions and attendance | Current history contains first-class sessions, conflicts, attendance/evaluation policy work. | Integration changes session records/materialization and related tests; Foundation changes teacher attendance/evaluation/domain layers. | Likely valuable, but SSOT/session IDs and attendance/evaluation gates must match D7-D10. | **RECOVER AFTER REVIEW** |
| Chat and FCM | Current branch contains chat authorization/message contracts and FCM client/backend foundations. | Integration adds FCM ownership/revocation, foreground push, chat media/policy and emulator tests; Foundation has overlapping notification and chat UI changes. | Compatible with dynamic groups/individual conversations only if relationship authorization and token ownership remain authoritative. Device delivery is not proven by unit tests. | **RECOVER AFTER REVIEW** |
| Parent workflows | Current branch contains Parent screens and payment/achievement paths. | Integration contains parent payment, achievements, household, and receipt UI/domain additions. Foundation contains overlapping Parent data/domain/presentation changes. | Strong potential value, but duplicate entities/usecases and payment contract versions conflict until compared. | **RECOVER AFTER REVIEW** |
| Admin workflows | Current branch contains Admin shell, roster, toggle, operations, and settings changes. | Integration adds finance, payment destinations/review, provisioning, communication, and oversight surfaces. Foundation contains alternate Admin operations/reporting surfaces. | Admin features must preserve callable authority and avoid direct membership/payment writes. UI existence is not workflow proof. | **RECOVER AFTER REVIEW** |
| Supervisor workflows | Current branch contains integrated enrollment, roster, payment/meeting-link paths. | Integration contains payment/award/dashboard changes; the Supervisor branch has the unique roster-refresh commit. Foundation has alternate Supervisor domain/UI changes. | Supervisor scope must remain independent from Admin and B14 add-only must remain disabled. | **RECOVER AFTER REVIEW** |
| Student workflows — non-protected implementation | Current branch contains Student dashboard, journey, reports, audio-library integration, and meeting-link paths. | Integration adds student profile/meeting-link/home changes; Foundation contains alternate Student data/domain/presentation work and deletions/renames. | Non-protected paths can be reviewed against current contracts; no snapshot implementation has been recovered or integrated. | **RECOVER AFTER REVIEW** |
| Student workflows — Quran/Mushaf protected paths | Protected Quran/Mushaf data and derived paths were excluded from inspection, hashing, and processing. | Snapshot value cannot be assessed under the protection constraint. | No evidence is claimed and no access is authorized. | **UNKNOWN** |
| Teacher workflows | Current branch contains Teacher dashboard, attendance, evaluation, classes, messaging, and production-pass work. | Integration changes Teacher profile/activity/tasks and tests; Foundation contains substantial Teacher data/domain/presentation changes. | Attendance/evaluation changes must satisfy D7-D10 and assistant-cover rules. Current evidence is insufficient for safe extraction. | **RECOVER AFTER REVIEW** |
| Release configuration/Codemagic | Current branch already contains release flavor/configuration work. | Release has 3 unique commits and 12 local platform/test changes; Integration has overlapping release files. | Valuable for Android/iOS/Codemagic preparation, but no build/signing/CI evidence was produced in this step. | **RECOVER AFTER REVIEW** |
| Generated files/artifacts | Current/Foundation/Integration contain generated Windows files and lock/build artifacts. | No independent product value. | Regenerate from the selected source after integration; do not use as feature evidence. | **ALREADY PRESENT / IGNORE** |
| Wallet/Paymob active product paths | Locked D2 explicitly excludes wallet as payment rail and Paymob. | Any snapshot changes that restore or activate those paths would contradict product decisions. | Must not be recovered into the product path. | **REJECT** |

### Part A closure boundary

Part A is closed only for Inventory and Reconciliation. It does not mean any dirty snapshot was recovered, integrated, approved, or verified. Integration/Foundation remain preserved and classified as `RECOVER AFTER REVIEW` or `UNKNOWN` where shown above. The three unique Release commits and one unique Supervisor commit remain outside current and require later selective review.

Important work remains outside the current branch in dirty Integration/Foundation snapshots, plus the three unique Release commits and one unique Supervisor commit. The snapshots are now grouped and numerically reconciled, but Integration/Foundation are not safe bulk-recovery sources because shared paths are mostly content-different and several contracts overlap.

## Owner decisions still required

- Production Firebase project and billing account/Blaze approval.
- Production Android/iOS identifiers and signing credentials; confirm provisional iOS bundle ID and iPad support.
- Final account-provisioning operational mechanism if the existing callable/UI contract is insufficient.
- Payment-access policy details where schema remains TBD; no subscription enforcement may be invented.
- Retention/lifecycle policy for chat media and payment proofs.
- Any production migration or rule/function deployment approval.
