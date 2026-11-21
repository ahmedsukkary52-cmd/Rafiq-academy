# BASMA — Security & Code Review Deep Assessment

**Date:** 2026-11-19  
**Branch:** `unify/basma-v1`  
**HEAD:** `8ce64fe97440c33acefaf1e140022ddbe0075ab5`  
**Nature:** Local security / architecture / tooling deep assessment after G0 + EQ/T1.  
**Overall verdict:** **PASS WITH GAPS** — strong emulator/static gates; Cloud and ownership remain **OWNER / CLOUD VERIFICATION REQUIRED**.  
**Follow-up:** EQ-T-04 **CLOSED** (`+2525 ~3`); `reactToChatMessage` AuthZ fixed; see §F1–F6.  
**Security Closure Campaign (2026-11-20):** `proxy-addr`/`node-forge` bumped; priority callables AuthZ tested; see §C1–C7 — **campaign closed**.  
**Do not treat this report as “Secure” or “Production Ready.”**

---

## Evidence classes

| Label | Meaning |
|-------|---------|
| **Verified** | Command/test output this pass |
| **Inferred** | From code/docs without re-execution |
| **Emulator** | Local Firebase Emulator / Node unit (not Cloud) |
| **Cloud / device** | Requires live project or physical lab |
| **Owner** | Requires owner approval / decision |

---

## 1. Git state

### Before

| Item | Value |
|------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (**match**) |
| Staged | `0` |
| Tracked modified | `196` |
| Untracked | `73` |
| G0 report | Present |
| EQ/T1 report | Present |

No unexpected staged content. Pre-existing dirty tree **preserved**.

### After (this task)

| Item | Value |
|------|--------|
| HEAD | Unchanged `8ce64fe…` |
| Staged | `0` |
| Tracked modified | `198` |
| Untracked | `73` (+ this report when created) |
| Git mutations | **None** (no add/commit/push/reset/stash/checkout) |
| Cloud / IAM / Billing | **Untouched** |

### Files changed by this task

| File | Why |
|------|-----|
| `test/architecture/dependency_boundaries_test.dart` | Align Group C allowlist with intentional EQ DI composition-root edges from `0889682` |
| `lib/features/audio_library/data/repositories/audio_library_repository_impl.dart` | Remove unused `cloud_firestore` import (analyzer warning) |
| `lib/features/audio_library/presentation/bloc/audio_event.dart` | Remove unused `flutter/material.dart` import (analyzer warning) |
| `docs/engineering-audit/BASMA_SECURITY_AND_CODE_REVIEW_DEEP_ASSESSMENT.md` | This report (untracked) |

**Not introduced by this task:** pre-existing WT edits including `audio_bloc.dart` playback-completed handling and ~196 other tracked mods.

---

## 2. Architecture failures — root cause

### Failures under assessment

Prior Full Suite: `+2523 ~3 -2` on dirty WT. Both failures in `dependency_boundaries_test`:

1. `C: core -> role imports` — *only the 4 known core files import role or staff modules*
2. `C: core -> role imports` — *generated DI config is reached only via injection_container*

### Actual cause (**Verified**)

Single composition-root file already in **HEAD** (`0889682`, still present at `8ce64fe`):

`lib/core/di/injection_container.dart` lines 7–12 — six manual repository imports for EQ-P1-05/06, EQ-3, EQ-4 (avoid `injectable` regen / **EQ-M-06**).

| Import target | Fails test 1? | Fails test 2? | Classification |
|---------------|---------------|---------------|----------------|
| `features/accounts/.../academy_accounts_repository.dart` | No (`accounts` not a role module) | Yes | **Stale allowlist** — intentional composition-root registration |
| `features/admin/.../admin_reports_repository.dart` | Yes (`admin` is role) | Yes | **Stale allowlist** — same |
| `features/assistant/.../cover_duty_repository.dart` | No | Yes | **Stale allowlist** |
| `features/chat/.../chat_groups_repository.dart` | No | Yes | **Stale allowlist** |
| `features/complaints/.../complaints_repository.dart` | No | Yes | **Stale allowlist** |
| `features/directory/.../academy_directory_repository.dart` | No | Yes | **Stale allowlist** |

**Not** a substantive cross-role architecture leak: `_diContainer` is already the composition-root stop boundary in Groups A/B/D+; dedicated `*_di_boundary_test.dart` suites lock the manual registration design; docs in `injection_container.dart` and EQ progress log document the pattern.

**Correction to EQ/T1 report inference:** these failures were **not** dirty-WT collateral — they are **HEAD@8ce64fe** vs outdated Group C pins left behind when `0889682` added manual DI without updating `dependency_boundaries_test`.

### Fix applied this pass

Group C allowlist updated deliberately to:

- Include `_diContainer` among known core→role importers, pinning its sole role target to `admin_reports_repository.dart`.
- Expand `importsOf(_diContainer)` to the six exact manual edges + generated config.

### Re-test

```
flutter test test/architecture/dependency_boundaries_test.dart
→ +71 All tests passed!  (Verified)
```

Full Suite not re-run end-to-end this pass after the fix (time); targeted arch suite is green. Recommend a later Full Suite checkpoint for EQ-T-04 closeout.

---

## 3. Security tools inventory & execution

| Tool | Installed initially? | Action this pass | External data? | Recommendation |
|------|----------------------|------------------|----------------|----------------|
| **Gitleaks** v8.30.1 | No | Downloaded binary to `D:\Temp\basma_sec_tools` (outside repo); scanned repo + history locally | No upload | **Use now** for every release gate |
| **OSV-Scanner** v2.7.1 | No | Same temp dir; scanned `pubspec.lock`, `functions/package-lock.json`, `rules_test/package-lock.json` | Fetches OSV vulnerability DB (expected) | **Use now**; **do not** auto-bump deps |
| **Semgrep** | No; no real Python on host | **Not run** — Windows Store Python stub only; npm `semgrep@0.0.1` is not the real CLI | Would be local if installed | Later with owner-approved local Python/pip; Dart rules remain limited |
| **CodeQL** | No | **Feasibility only** — no CLI, no `.github` workflows | GitHub Advanced Security / Actions typically | Owner decision; weak Dart support |
| **flutter analyze** | Yes | Full project | No | Primary static gate |
| **dart format --set-exit-if-changed** | Yes | Touched arch test only | No | Touched files only |
| **Architecture tests** | Yes | Fixed + green | No | Keep as merge gate |
| **rules_test** Firestore/Storage | Yes | Full aggregates + standalone | Local emulator | Before any Rules deploy |
| **functions test:wave-a** | Yes | Full Wave-A unit | No Cloud | Keep |
| **Callable wrapper emulator suites** | Yes | High-risk + high-impact | Local emulator | Expand remaining GAPs |
| Snyk / Dependabot / SaaS | Not configured | **Not used** | Would upload | Owner only |

---

## 4. Gitleaks findings

**Command:** `gitleaks detect --source . --report-format json --redact=100`  
**Result:** `236` commits scanned · **15** hits · exit 1  
**Secrets are not printed in this report.**

| Path (current or historical) | Rule | Triage | Class |
|------------------------------|------|--------|-------|
| `fcm_pending_revocation_store.dart` prefs key name | `generic-api-key` | Prefs key string, not a credential | **FALSE POSITIVE** |
| `award_grant_idempotency_test.dart` key const name | `generic-api-key` | Test constant name | **FALSE POSITIVE** |
| `functions/test/admin_staff.emulator.test.mjs` | `generic-api-key` | Emulator test fixture password pattern | **FALSE POSITIVE** / test-only |
| `functions/src/accounts/academyCredentials.ts` alphabet | `generic-api-key` | Password alphabet charset, not a secret | **FALSE POSITIVE** |
| `lib/core/firebase/app_firebase.dart` emulator `apiKey` | `gcp-api-key` | Demo/emulator FirebaseOptions | **FALSE POSITIVE** / expected |
| `android/app/google-services.json` | `gcp-api-key` | Firebase **client** API key (mobile-embedded by design) | **INFORMATIONAL** — restrict in GCP API key console; not a server secret |
| `lib/firebase_options.dart` | `gcp-api-key` | Same client keys | **INFORMATIONAL** |
| `parent_state.dart` (historical commit) | `jwt` / `jwt-base64` | Current file line is payment destination fields; historical match | **FALSE POSITIVE** / historical |

**Confirmed secret leakage (server keys, private keys, service accounts):** **none** in this scan.

**Limitation:** Gitleaks ≠ proof that no secrets exist outside matched rules.

---

## 5. OSV dependency findings

**Command:** `osv-scanner scan` on three lockfiles  
**Result:** **80** vulnerability records · exit 1  
**pubspec.lock:** **0** reported vulns (**Verified**)  
**functions/package-lock.json** + **rules_test/package-lock.json:** all 80 hits

### Notable packages (functions lockfile)

| Package | Locked | Highest noted sev | Notes |
|---------|--------|-------------------|-------|
| `axios` | `1.18.0` (declared `^1.7.2`) | HIGH (multiple GHSA) | Direct dep; **do not auto-bump** without Functions regression tests |
| `proxy-addr` | `2.0.7` | **CRITICAL** (GHSA-jqcg-44mw-7w3h) | Likely transitive |
| `node-forge` | `1.4.0` | HIGH (many) | Common Firebase Admin transitive |
| `@grpc/grpc-js` | `1.14.4` | HIGH | Transitive |
| `follow-redirects` | `1.16.0` | HIGH | Via axios |
| `body-parser` / `qs` / `uuid` / `protobufjs` / `fast-xml-parser` / `@fastify/busboy` | various | LOW–HIGH | Mostly transitive |

**rules_test** shares overlapping transitive findings (`node-forge`, `@grpc/grpc-js`, …) — test-harness risk ≠ production Functions runtime, but still hygiene debt.

### Policy this pass

- **No dependency updates performed** (compatibility + lockfile blast radius).  
- Class: **HIGH RISK** for Functions supply-chain hygiene until a controlled bump+test campaign.  
- Class: **NOT VERIFIED** for exploitability in this app’s call paths.

---

## 6. Semgrep findings

**Not executed.**

| Blocker | Detail |
|---------|--------|
| Runtime | No usable Python 3 (`py` missing; `python` is Store stub) |
| npm | `semgrep@0.0.1` is not the real Semgrep CLI |
| SaaS | Forbidden without owner approval |

**Dart/Flutter coverage caveat:** even with Semgrep installed, community Dart rules are thinner than for JS/TS/Python. Functions TypeScript would benefit more than Flutter UI.

**Recommendation:** Owner-approved local Semgrep install later; start with `functions/src` + `p/javascript` / security packs — still not a substitute for Rules/callable emulator matrices.

---

## 7. CodeQL feasibility

| Aspect | Assessment |
|--------|------------|
| Languages in repo | Dart/Flutter (primary), TypeScript (`functions`), some JS tests |
| Local CLI | **Not installed** |
| GitHub Actions | **No** `.github` workflows |
| Dart support | Historically limited / incomplete vs JS/Java |
| Best fit here | TypeScript Functions analysis if Actions + CodeQL enabled |
| This pass | **Feasibility only — NOT RUN** |

**OWNER DECISION REQUIRED** to enable GitHub CodeQL or install CLI — no workflow created.

---

## 8. Firestore Rules test matrix

**Project:** `demo-rafiq-rules` only · **Emulator** · no Cloud writes

| Suite group | Command / script | Result |
|-------------|------------------|--------|
| Aggregate `test:all:firestore` | `firebase emulators:exec --only firestore` | **294 pass / 0 fail** (**Verified**) |
| Standalone R1 / admin milestone / profile privacy / academy relationships | same, four files | **39 pass / 0 fail** (**Verified**) |

Coverage themes exercised (suite intent):

- Auth required; role + roster + halaqa scope  
- Cross-user / cross-family / directory over-read denials (incl. D0 trial isolation)  
- `userPrivate` owner/admin get; no list; no client writes  
- Deactivated `isActive == false` revocation  
- Backend-authoritative fields (payments, attendance, evaluations, roster, meeting links, economy, audit)  
- Complaints / staff / relationships client-write denials  

**Limitation:** Emulator Rules ≠ live `rafiq-academy` Rules text (BASMA-100 historically over-read on Cloud).

---

## 9. Storage Rules test matrix

| Suite group | Result |
|-------------|--------|
| Aggregate `test:all:storage` | **71 pass / 0 fail** (**Verified**) |

Coverage themes:

- Path ownership; catch-all deny  
- Payment-proof privacy (parent create own; others denied; admin read; no client update/delete)  
- MIME/size ceilings; chat media participant binding  
- Deactivated access revocation  
- Halaqa library / activities scoping  
- WA-12 legacy path hardening  

**Limitation:** Emulator ≠ Cloud Storage Rules deployment state.

---

## 10. Callable Functions authorization matrix

### Inventory (**Verified** from source)

| Item | Count |
|------|-------|
| Active exported `onCall` in `functions/src/index.ts` | **53** |
| Quarantined / not exported (`createPaymentIntention`) | **1** |
| Distinct Flutter client callable names | **46** |
| Backend-only / maintenance (no Flutter caller) | **7** (backfills, migrate, etc.) |

**Universal gate:** all **53** active callables call `assertBackendAllowed` → fail-closed unless emulator `demo-*` **or** `PRODUCTION_BACKEND_ENABLED=true`.

**Role SSOT:** `users/{uid}.role` via `activeRoleOf` / `loadCallerRole` / `assertCallerIsAdmin` (not client-supplied role).

### Emulator / unit evidence this pass

| Harness | Result |
|---------|--------|
| `npm --prefix functions run test:wave-a` | **651 pass / 0 fail / 1 skipped** (**Verified**) |
| `high_risk_account_wrappers` (auth+firestore+functions) | **3 pass** in combined run; sensitive suite aborted for missing storage |
| Sensitive + high-impact wrappers (auth+firestore+functions+**storage**) | **8 pass / 0 fail** (**Verified**) |

### Coverage status (string presence in emulator/callable tests — approximate)

| Status | Callables |
|--------|-----------|
| **COVERED** (mentioned in emulator/callable suites) | Most of the 53 — provisioning, billing, chat, payments, sessions, awards, complaints, onboarding, staff, groups, parent projections, … |
| **GAP** (no/weak suite hit this inventory) | `adminSyncHalaqaGroup`, `ensureAdminGroupConversation`, `adminBackfillStudentSearch`, `adminBackfillStudentLifecycle`, `adminSetStudentLifecycle`, `supervisorOnboardStudent` (may still have unit coverage elsewhere), quarantined `createPaymentIntention` |
| **EQ-T-03** | Full wrapper negative matrix still selective — not expanded this pass |

### Condensed AuthZ pattern map

| Pattern | Examples |
|---------|----------|
| Admin-only (`assertCallerIsAdmin` / role admin) | provision, billing, backfills, member create/get/active, import, staff lifecycle, chat group admin ops |
| Parent + ownership | `submitPaymentProof`, parent schedule/halaqat/achievements |
| Teacher/supervisor scoped | attendance, evaluation, awards, admit/transfer, meeting link (supervisor add-only) |
| Student self | `completeHomework`, `purchaseAvatar` |
| Participant chat | send/edit/delete/react + Storage ownership checks |
| First-login special | `completeFirstLogin` (password-change flags; activeRole empty until done) |

**Status column for release:** Emulator AuthZ **PASS WITH GAPS** · Cloud AuthZ **NOT VERIFIED** (Functions historically unpublished on `rafiq-academy`).

---

## 11. Tests run and exact results

| Command / focus | Result |
|-----------------|--------|
| `flutter test test/architecture/dependency_boundaries_test.dart` | **+71** pass |
| `flutter test test/features/onboarding test/features/review_schedule` | **+9** pass |
| `flutter analyze --no-fatal-infos` | **192** issues: **7 warning** (unused imports), **185 info** — **0 error** |
| `dart format --set-exit-if-changed` on arch test | Formatted once; then clean |
| Gitleaks | 15 hits triaged (§4) |
| OSV-Scanner | 80 lockfile records (§5) |
| Firestore rules aggregate | 294/0 |
| Firestore standalone | 39/0 |
| Storage rules aggregate | 71/0 |
| Functions Wave-A | 651/0/1 skip |
| Callable wrappers (corrected emulator set) | 8/0 (+3 account earlier) |
| Full `flutter test` suite | **Not re-run** after arch fix (prior EQ/T1: `+2523 ~3 -2`) |
| Semgrep / CodeQL | **Not run** |
| `flutter pub outdated` | **Failed** (corrupt/missing pub cache yaml for `url_launcher_linux`) — environment issue |

---

## 12. Confirmed vulnerabilities

| ID | Finding | Class |
|----|---------|-------|
| Cloud Rules drift | Live `rafiq-academy` historically over-readable vs repo Rules (BASMA-100) | **CONFIRMED VULNERABILITY** on **Cloud** (prior evidence) — **NOT re-probed** this pass |
| Missing Cloud indexes | Complaints query `FAILED_PRECONDITION` on device (BASMA-101) | **HIGH RISK** / Cloud config gap |
| Unpublished Functions | Callables 404 / Blaze gated historically (BASMA-102) | **HIGH RISK** for prod readiness (fail-closed locally is good; Cloud incomplete) |
| OSV CRITICAL/HIGH deps | e.g. `proxy-addr`, `axios`, `node-forge` family | **HIGH RISK** supply chain — **NOT VERIFIED** exploit path |
| Client Firebase API keys in repo | Expected for mobile | **INFORMATIONAL** — restrict keys in GCP |

No new **CONFIRMED** auth bypass in **emulator** Rules/callable suites this pass.

---

## 13. False positives & unresolved

| Item | Class |
|------|-------|
| Most Gitleaks hits (§4) | **FALSE POSITIVE** |
| Firebase client API keys | **INFORMATIONAL** |
| OSV transitive volume without exploit proof | **NOT VERIFIED** |
| Semgrep/CodeQL absence | **NOT VERIFIED** (tooling gap) |
| Live Cloud Rules/Functions current text | **NOT VERIFIED** this pass |
| EQ-M-05 Audio Auth DI | Deferred — **OWNER DECISION REQUIRED** (overlaps EQ-M-06) |

---

## 14. Firebase ownership / billing / project strategy

**Policy this pass:** analysis only — **no** IAM, Billing, project create/transfer, or deploy.

### Definitions (must not confuse)

| Concept | Meaning |
|---------|---------|
| **Project ownership** | Google Cloud / Firebase project owner membership (Org/project IAM) |
| **IAM roles** | Granular permissions (Editor, Firebase Admin, Functions Developer, …) — least privilege for developers |
| **Billing account** | Who pays; linking Billing ≠ transferring project ownership by itself |
| **Aliases** | `.firebaserc` `staging` / `prod` names — **not** proven existing projects (G0) |

**Local facts (G0):** only `rafiq-academy` confirmed in CLI list; staging/prod aliases referenced but **not** present as projects; owner has indicated final production may be a **different** project — **do not** assume `rafiq-academy` is final prod.

### Scenario A — Existing project with Academy ownership

Use current `rafiq-academy` (or whichever project becomes canonical) after IAM/Billing hygiene.

| # | Point |
|---|--------|
| 1 Advantages | No Auth/user migration; no data/Storage copy; flavors/trial wiring already point here; fastest path to “someone pays + owns” |
| 2 Risks | Inherits any historical Rules gaps / trial data; unclear final-prod intent; single project mixing trial + future prod |
| 3 Cost sources | Blaze for Functions/FCM; Storage/Firestore usage; SMS/Auth if used — **no invented prices** |
| 4 Academy responsibilities | Own Billing account; hold Owner; recovery contacts; approve Blaze; legal data stewardship |
| 5 Dev team responsibilities | Least-privilege IAM; deploy Rules/Indexes/Functions when approved; no personal Billing |
| 6 Access-loss risk | Mitigate with ≥2 academy Owners + org recovery; avoid sole owner = contractor Google account |
| 7 Flavors | Trial already uses `rafiq-academy`; prod flavor still needs prod FirebaseOptions if this project is also prod |
| 8 Auth/FS/Storage/Functions/FCM | Stay in place; still need deploy + Blaze + gate env |
| 9 Future move | Harder later if prod data accumulates here |
| 10 Conditional recommendation | Prefer **only if** owner confirms this project **is** long-term production **or** dedicated “academy ops / trial” with accepted risk |

### Scenario B — New Production project (academy-owned)

| # | Point |
|---|--------|
| 1 Advantages | Clean production boundary; academy Billing/ownership from day one; leave trial dirt behind |
| 2 Risks | Full re-provision: Auth users, Firestore, Storage, Functions, secrets, indexes, Rules, FCM, app IDs, `google-services` / Dart options; migration integrity |
| 3 Cost sources | Second project Blaze + dual environments during cutover |
| 4 Academy | Create/own project + Billing; never share owner passwords with contractors — invite IAM instead |
| 5 Dev | Build out config, migrations, Codemagic prod signing, fail-closed until ready |
| 6 Access-loss | Better if academy owns from start |
| 7 Flavors | Prod applicationId + Firebase apps must match; staging may stay emulator/`demo-*` |
| 8 Services | All must be recreated or migrated with checksums/rollback plan |
| 9 Future | Best long-term isolation |
| 10 Conditional recommendation | Prefer when owner already decided “final prod ≠ current trial project” (aligned with verbal G0 intent) |

### Scenario C — Keep existing for trial/dev + separate prod

| # | Point |
|---|--------|
| 1 Advantages | Matches current alias design intent; isolates prod blast radius; developers can keep trial access without prod Owner |
| 2 Risks | Dual ops cost; alias/docs drift; accidental deploy to wrong project |
| 3 Cost | Two Blaze projects when both active |
| 4 Academy | Own **prod** Billing+Owner; may co-own or sponsor trial |
| 5 Dev | Strict deploy wrappers (`deploy:prod` guards); emulator `demo-*` for CI |
| 6 Access-loss | Split responsibility reduces single-point failure |
| 7 Flavors | Maps cleanly: trial→current, prod→new, staging→emulator or third |
| 8 Services | Prod empty until seeded/migrated; trial remains as-is |
| 9 Future | Easiest incremental path |
| 10 Conditional recommendation | **Default recommendation** unless owner explicitly wants a single-project world |

### Cross-cutting owner checklist (no credentials requested)

1. Who holds **Owner** on the chosen prod project (academy Google/Workspace accounts)?  
2. Which **Billing account** pays — academy-owned?  
3. Is `rafiq-academy` trial-only, or candidate prod?  
4. Create real project IDs for aliases (do not trust names in `.firebaserc` alone).  
5. Developer IAM: Firebase Admin / Functions Developer **without** Billing Admin unless needed.  
6. Recovery: second Owner + documented break-glass.  

Anything not visible in local files: **OWNER / CLOUD VERIFICATION REQUIRED**.

---

## 15. Owner decisions required

1. **Firebase project strategy** — A vs B vs C (§14).  
2. **Blaze / Billing** linkage for whichever project runs Functions.  
3. **Deploy** Rules + Indexes (BASMA-101) + Functions — only after strategy + Blaze.  
4. **EQ-M-05 / EQ-M-06** — Audio Auth DI vs injectable regen.  
5. **Dependency bump campaign** for Functions OSV HIGHs (axios et al.) — approve scope/tests.  
6. **Semgrep / CodeQL** install or GitHub enablement (data egress / Actions).  
7. **RB-16/17** prod applicationIds + upload keystore (still forbidden to create here).  
8. Optional: commit tests/docs/arch allowlist when authorized.

---

## 16. Remaining EQ and release blockers

| Item | Status after this pass |
|------|------------------------|
| EQ-T-01 | Previously green (9 tests); reconfirmed |
| EQ-T-02 coverage % | Still optional / open |
| EQ-T-03 wrappers | Selective; gaps listed in §10 |
| EQ-T-04 Full Suite | Arch −2 **fixed in targeted suite**; Full Suite not re-proved green |
| EQ-M-05 Audio DI | Still **OWNER DECISION**; only unused imports cleaned |
| RB-02 Recitation index | Local JSON evidence prior; Cloud deploy still gated |
| BASMA-101 complaints index | Cloud missing; local JSON has match — deploy gated by G0 |
| RB-16 / RB-17 | Config reviewed prior; keystore/IDs/prod Firebase files open |
| RB-18 / D4 / G1 | Device partial; DevTools blocked; not re-run this pass |
| Production backend gate | Remains **closed** by design (**Verified** unit + Wave-A) |

---

## 17. Next recommended sequence

1. Owner chooses **Scenario C** (or documents why A/B) — no Cloud changes until then.  
2. ~~Re-run Full Suite for EQ-T-04~~ → **Done** (`+2525 ~3`).  
3. Controlled Functions dependency review (`proxy-addr` / `axios` / `node-forge`) with Wave-A + wrappers — **no blind npm update**.  
4. Remaining callable HTTP AuthZ gaps (`adminEndHalaqaCover`, `materializeSession`, `ensureAdminGroupConversation`, Core-only wrappers).  
5. When Cloud approved: deploy Rules → Indexes (complaints) → Functions on the **chosen** project with gate still fail-closed until explicit enable.  
6. Optional local Semgrep after Python install approval; EQ-M-05 only with EQ-M-06 decision.

---

## Scorecard

| Area | Result |
|------|--------|
| Git / Cloud / signing safety | **PASS** |
| Architecture −2 diagnosis + fix | **PASS** |
| Firestore Rules emulator | **PASS** (294+39) |
| Storage Rules emulator | **PASS** (71) |
| Functions Wave-A | **PASS** (651) |
| Callable wrapper AuthZ (sample) | **PASS WITH GAPS** |
| Gitleaks | **PASS WITH GAPS** (FP + informational client keys) |
| OSV | **PASS WITH GAPS** (80 findings; no auto-fix) |
| Semgrep | **BLOCKED** (no Python) |
| CodeQL | **BLOCKED** / feasibility only |
| Production readiness claim | **BLOCKED** (G0) |
| Firebase ownership strategy | **OWNER DECISION REQUIRED** |

### Overall: **PASS WITH GAPS**

**Verified this pass:** arch root cause + fix, analyze/T1, Gitleaks/OSV local, Rules+Storage emulator matrices, Functions Wave-A, callable wrapper subset, unused-import cleanup.  
**Inferred:** callable AuthZ patterns from source; ownership scenarios from G0 + IAM principles.  
**Needs Emulator (done where noted):** Rules/Storage/wrappers.  
**Needs Cloud:** live Rules/Functions/Indexes/IAM/Billing verification.  
**Needs Owner:** project strategy, Blaze, deploys, DI regen, SaaS/tool installs, signing IDs.

**Stop for owner review** — no stage/commit/push; no Cloud/IAM/Billing changes.

---

# Follow-up — 2026-11-19 (EQ-T-04 / OSV triage / Callable deep audit)

**Nature:** Execution follow-up on the same HEAD. Historical sections above are retained.  
**Follow-up overall:** **PASS WITH GAPS** (EQ-T-04 closed locally; OSV remediation deferred; Cloud still blocked)

---

## F1. Git state (follow-up)

### Before follow-up

| Item | Value |
|------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (**match**) |
| Staged | `0` |
| Tracked modified | `198` |
| Untracked | `74` |

### Diff review of prior local fixes (before new edits)

| File | Assessment |
|------|------------|
| `dependency_boundaries_test.dart` Group C | Deliberate allowlist pins for six EQ DI edges + `_diContainer` role pin — **not** an unbounded exception |
| Same file `_clampedAllowlist` / formatting | Pre-existing WT churn vs HEAD (not introduced as product behavior) |
| `audio_library_repository_impl.dart` / `audio_event.dart` | Unused-import removal only — **no behavior change** |

### After follow-up

| Item | Value |
|------|--------|
| HEAD | Unchanged `8ce64fe…` |
| Staged | `0` |
| Tracked modified | `200` |
| Untracked | `74` |
| Git mutations | **None** |

### Files changed this follow-up

| File | Why |
|------|-----|
| `functions/src/chat/chatGroupFunctions.ts` | Fix: `reactToChatMessageCore` now requires `loadUserRole` (blocks deactivated / inactive chat actors) |
| `functions/test/admin_messaging.emulator.test.mjs` | Negative test: deactivated participant cannot react |
| `functions/test/high_impact_account_creation_wrappers.emulator.test.mjs` | Added `supervisorOnboardStudent` AuthZ negative + happy-path (file was untracked WT) |
| This report | Follow-up documentation |

---

## F2. Full Flutter Suite — EQ-T-04

| Item | Value |
|------|--------|
| Command | `flutter test --reporter expanded` (no `USE_FIREBASE_EMULATOR`, no `FIGMA_CAPTURE`) |
| Flutter | 3.44.9 / Dart 3.12.2 |
| Log | `D:\Temp\basma_eq_t04_full_suite.txt` |
| **Final** | **`+2525 ~3` — All tests passed!** |
| **Exit code** | **`0`** (**Verified**) |
| Prior comparison | EQ/T1 dirty WT: `+2523 ~3 -2` → arch −2 removed; +2 additional passes vs that run |

### Skips (~3) — justified optional

| Skip | Reason |
|------|--------|
| `emulator_mode_fcm_test` | `skip: useFirebaseEmulator` — requires `--dart-define=USE_FIREBASE_EMULATOR=true` |
| `teacher_home_figma_capture_test` (2) | `skip: !enabled` — requires `FIGMA_CAPTURE=1` |

No failures. No expectation-weakening.

### EQ-T-04 decision

**CLOSED** for current Working Tree @ HEAD `8ce64fe` + local fixes above.  
Evidence class: **Verified locally** on dirty WT (not an isolated clean checkout). Optional skips documented.  
Does **not** prove Cloud readiness.

---

## F3. OSV — reproduce, dedupe, triage

| Item | Value |
|------|--------|
| Tool | osv-scanner **2.7.1** (scalibr 0.5.3) |
| Scanned | `pubspec.lock`, `functions/package-lock.json`, `rules_test/package-lock.json` |
| Data egress | Package names/versions to OSV DB only (no source/repo upload) |
| Raw findings | **80** (exit 1) |
| Unique advisories (id+pkg) | **51** |
| Unique packages | **11** |
| pubspec.lock | **0** |
| functions lockfile raw | **52** |
| rules_test lockfile raw | **28** |

### Severity (unique advisories)

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 23 |
| MODERATE | 18 |
| LOW | 9 |

### Direct vs transitive (functions)

| Package | Direct? | In prod tree? | Notes |
|---------|---------|---------------|-------|
| `axios@1.18.0` | **Yes** (`^1.7.2`) | Yes | **Only imported by quarantined** `createPaymentIntention` — active runtime path **not** using axios |
| `proxy-addr@2.0.7` | No (via `express`) | Yes | CRITICAL GHSA-jqcg-44mw-7w3h; fixed in `2.0.8` |
| `node-forge@1.4.0` | No (via `firebase-admin`) | Yes | Multiple HIGHs; mostly fixed in `1.4.1` |
| `@fastify/busboy`, `@grpc/grpc-js`, `body-parser`, `follow-redirects`, `fast-xml-parser`, … | Transitive | Yes (functions) and/or rules_test | Supply-chain hygiene |

### Top risks & classification

| Finding | Class | Exploitability note | Remediation (proposed, **not applied**) |
|---------|-------|---------------------|----------------------------------------|
| `proxy-addr` CRITICAL | **HIGH** (scanner CRITICAL) | Express transitive; **NOT VERIFIED** as reachable attack in callable surface | Bump via lockfile refresh after Wave-A+wrappers; Node 22 compatible |
| `axios` HIGHs | **MEDIUM** / mitigated | Direct dep but **quarantined Paymob-only** usage | Prefer bump to `>=1.20.0` when Paymob reconsidered; or remove unused direct dep |
| `node-forge` HIGHs | **MEDIUM** | Via firebase-admin | Wait for firebase-admin release / controlled override after tests |
| rules_test-only overlaps | **INFORMATIONAL** / **NOT APPLICABLE** to prod runtime | Test harness | Refresh rules_test lock separately |
| Remaining MODERATE/LOW | **LOW**–**NEEDS INVESTIGATION** | No exploit proof this pass | Batch with next Functions dependency campaign |

**No lockfile updates performed.**

---

## F4. Callable Functions — complete coverage audit

### Current counts (**Verified** from source)

| Item | Count |
|------|-------|
| Total `index.ts` exports | **65** |
| Active `onCall` | **53** |
| Quarantined `onCall` | **1** (`createPaymentIntention`) |
| Flutter active callable names | **46** |
| Flutter constant without client call | `materializeSession` |
| Backend-only / maintenance exports | **7** |

### AuthZ matrix summary (54 onCall defs)

| Coverage class | Count | Notes |
|----------------|-------|-------|
| EMULATOR_NEGATIVE_AUTHZ (HTTP or Core) | **43** (was; +supervisor HTTP now) | Most high-risk ops covered |
| EMULATOR_POSITIVE only | **3** | e.g. `adminEndHalaqaCover`, `materializeSession`, backfill name |
| UNIT_ONLY | **6** | maintenance/backfill/sync |
| NONE (active) | **0** after this follow-up (`supervisorOnboardStudent` filled) | Quarantined Paymob still NONE |

Full per-callable Auth / Role / Ownership / Input / Output / Tests detail is retained in the explore audit working notes; key patterns:

- All **53** active callables: `assertBackendAllowed`  
- Role SSOT: `users/{uid}` via `activeRoleOf` / `loadCallerRole` / `assertCallerIsAdmin` — **not** client-supplied role  
- High-risk payments/onboarding/staff/chat: ownership or scope checks present (**Inferred** + prior emulator evidence)

### Confirmed defect fixed this follow-up

| Finding | Class | Fix | Evidence |
|---------|-------|-----|----------|
| `reactToChatMessage` allowed deactivated users still listed in `participantIds` to write `reactions.*` | **CONFIRMED VULNERABILITY** (emulator AuthZ gap) | Call `loadUserRole` before reaction write | `admin_messaging.emulator.test.mjs` journey 9 — **3/3 pass** including deactivated deny |

### Negative tests added (**Emulator verified**)

| Suite | Result |
|-------|--------|
| `admin_messaging.emulator.test.mjs` | **3 pass / 0 fail** |
| `high_impact_account_creation_wrappers.emulator.test.mjs` (incl. new supervisor cases) | **2 pass / 0 fail** |

`supervisorOnboardStudent` now covers: null → UNAUTHENTICATED; admin/teacher/parent/other-supervisor → PERMISSION_DENIED; owning supervisor → 200.

### Remaining high-value gaps (not closed this pass)

- HTTP wrapper negatives for Core-only suites (attendance, economy, awards, complaints, …)  
- `adminEndHalaqaCover` / `materializeSession` / `ensureAdminGroupConversation` AuthZ HTTP  
- Admin maintenance backfills wrong-role HTTP  
- Storage: `adminUpdateChatGroup` imagePath existence not verified server-side (Rules gate Admin upload)

### Storage vs Callable

Rules (71) + callable Storage verification (`sendChatMessage`, `submitPaymentProof`) remain distinct layers. Success of wrapper suites ≠ complete Storage callable coverage.

---

## F5. Prior security results — validity

| Prior result | Still valid? |
|--------------|--------------|
| Firestore 294+39 | Yes — no Rules edits this follow-up |
| Storage 71 | Yes |
| Wave-A 651 | Yes — source change limited to chat reaction AuthZ; rebuild done |
| Gitleaks triage | Yes — unchanged |
| Semgrep / CodeQL | Still not run |

---

## F6. Follow-up scorecard

| Area | Result |
|------|--------|
| EQ-T-04 Full Suite | **PASS** — **CLOSED** (`+2525 ~3`, exit 0) |
| OSV triage | **PASS WITH GAPS** — 51 unique advisories; no auto-bump |
| Callable audit | **PASS WITH GAPS** — 54 reviewed; 1 AuthZ defect fixed; gaps remain |
| `reactToChatMessage` fix | **PASS** (emulator) |
| Production / Cloud | **BLOCKED** |
| Owner decisions (G0/IAM/deps) | **OWNER DECISION REQUIRED** |

### Answers to completion questions

1. **EQ-T-04 closed?** **Yes** — Full Suite green on current WT with documented optional skips.  
2. **Confirmed vulns?** Cloud Rules drift (prior); **`reactToChatMessage` deactivated AuthZ** (fixed locally); BASMA-101 index still Cloud-missing.  
3. **OSV needing action?** `proxy-addr` CRITICAL + `axios` direct + `node-forge` via admin — planned controlled bump, **not** applied.  
4. **Callables reviewed?** **54** onCall definitions (53 active + 1 quarantined).  
5. **With suitable negative tests?** ~**44+** after this follow-up (HTTP or Core); exact HTTP wrapper coverage still incomplete for ~14 Core-only clients.  
6. **Sensitive ops still thin?** `adminEndHalaqaCover`, `materializeSession`, `ensureAdminGroupConversation`, maintenance backfills, several Core-only HTTP wrappers.  
7. **Next without Cloud decision?** Controlled Functions dependency bump proposal + remaining HTTP AuthZ emulator tests; optional Semgrep after Python install.

**Do not claim Production secure or ready to publish from these results.**

**Stop for owner review** — no stage/commit/push; no Cloud/IAM/Billing/lockfile mutations.

---

# Security Closure Campaign — 2026-11-20

**Goal:** Close highest remaining local security gaps; end Security Review expansion.  
**Campaign verdict:** **PASS WITH GAPS** — local High/Critical remediable items closed; Cloud + owner decisions remain.

---

## C1. Git state

### Before

| Item | Value |
|------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` |
| Staged | `0` |
| Tracked modified | `200` |
| Untracked | `74`–`75` |
| `reactToChatMessage` fix | Present (`loadUserRole` gate) |

### After

| Item | Value |
|------|--------|
| HEAD | Unchanged |
| Staged | `0` |
| Tracked modified | `201` (includes `functions/package-lock.json`) |
| Untracked | `75` (+ new priority AuthZ test) |
| Git mutations | **None** (no stage/commit/push) |

### Files changed this campaign

| File | Change |
|------|--------|
| `functions/package-lock.json` | `proxy-addr` 2.0.7→**2.0.8**; `node-forge` 1.4.0→**1.4.3** only |
| `functions/package.json` | **Unchanged** |
| `functions/test/priority_callable_authz.emulator.test.mjs` | **New** HTTP AuthZ for `ensureAdminGroupConversation` + `materializeSession` |
| `functions/test/high_risk_sensitive_wrappers.emulator.test.mjs` | Added `adminEndHalaqaCover` null/supervisor/teacher denials (WT file) |

No Flutter `lib/` edits → Full Suite **not** re-run (EQ-T-04 still closed from prior `+2525 ~3`).

---

## C2. Dependency remediation

### A. `proxy-addr` (CRITICAL GHSA-jqcg-44mw-7w3h / CVE-2026-90711)

| Aspect | Finding |
|--------|---------|
| Path | `firebase-functions` → `express@4.22.2` → `proxy-addr` |
| Installed before | `2.0.7` (prod tree) |
| Fixed | `2.0.8` (satisfies express `~2.0.7`) |
| App use of `req.ip` / trust proxy | **None** in `functions/src` |
| Exploit condition | Misconfigured IPv4-mapped IPv6 trust subnet |
| Applicability to BASMA callables | **Low** for active AuthZ (Firebase Auth, not IP ACL) |
| Action | **Updated** lockfile to 2.0.8 — minimal hygiene for CRITICAL in runtime tree |

### B. `node-forge`

| Aspect | Finding |
|--------|---------|
| Path | `firebase-admin@12.7.0` → `node-forge` (`^1.3.1`) |
| Before → After | `1.4.0` → **`1.4.3`** |
| firebase-admin | Left at `12.7.0` (no major bump / no overrides) |
| Action | **Updated** within existing range |

### C. `axios` / Paymob

| Aspect | Finding |
|--------|---------|
| Declared | `^1.7.2` → locked `1.18.0` |
| Source use | **Only** quarantined `createPaymentIntention` (not exported) |
| Action | **No bump** — not on active production path |
| Class | Vulnerable package, **not applicable** to active runtime |

### D. Remaining OSV (functions lockfile only, after update)

| Metric | Before (functions share of prior 80) | After |
|--------|--------------------------------------|-------|
| Raw | 52 (prior functions portion) | **30** |
| Unique advisories | — | **29** |
| CRITICAL | 1 (`proxy-addr`) | **0** |
| HIGH | many | **15** (mostly `axios` + other transitive) |
| `proxy-addr` hits | present | **0** |
| `node-forge` hits | present | **0** |

**Not auto-fixed:** axios family, remaining transitive MODERATE/HIGH without active path proof.

---

## C3. Priority Callables — AuthZ closure

### Code review (static)

| Callable | Auth | Role | Ownership / integrity | Verdict |
|----------|------|------|------------------------|---------|
| `adminEndHalaqaCover` | `requireAdmin` + gate | Admin via `activeRoleOf` | Halaqa cover fields; optional `coverId` race abort | **No code vuln** |
| `materializeSession` | `request.auth?.uid` + gate | `assertCanMaterialize` (admin / assigned teacher / active cover) | Ignores client teacher/roster; conflict locks | **No code vuln** |
| `ensureAdminGroupConversation` | `requireCallerUid` + gate | `loadCallerRole === admin` | Rejects client membership fields; membership from admin users query | **No code vuln** |

### Emulator HTTP negatives added / extended

| Suite | Result |
|-------|--------|
| `priority_callable_authz.emulator.test.mjs` | **2 pass / 0 fail** — ensureAdminGroup + materializeSession |
| `high_risk_sensitive_wrappers.emulator.test.mjs` | **4 pass / 0 fail** — includes `adminEndHalaqaCover` UNAUTHENTICATED + wrong-role |

Evidence class: **Emulator verified**.

---

## C4. HTTP wrappers (Core-only) — limited classification

The 14 Core-authZ-strong / HTTP-thin wrappers:

| Callable | Exposure | Class | Priority action now? |
|----------|----------|-------|----------------------|
| `recordSessionAttendance` | Exported `onCall` + Flutter | Authenticated role/scope (Core tested) | No — Core negatives exist |
| `upsertSessionEvaluation` | Same | Authenticated role/scope | No |
| `completeHomework` | Same | Student self | No |
| `purchaseAvatar` | Same | Student self | No |
| `grantAward` / `issueAchievement` / `getHalaqaAwards` | Same | Staff scoped | No |
| `setHalaqaMeetingLink` | Same | Admin/supervisor scoped | No |
| `adminAddHalaqaSlot` | Same | Admin | No |
| `submitComplaint` / `respondToComplaint` | Same | Role + ownership | No |
| `createDirectConversation` | Same | Relationship graph | No |
| `reactToChatMessage` | Same | **Fixed** deactivated AuthZ + Core test | Done |
| `adminGetMemberAccount` | Same | Admin read | No |

All are **Firebase Callable HTTPS endpoints** (not public anonymous APIs): require Auth token + `assertBackendAllowed` (fail-closed until production gate).  
**No dead exports deleted.** Highest previously thin HTTP AuthZ among campaign targets (`adminEndHalaqaCover`, `materializeSession`, `ensureAdminGroupConversation`) now covered.

---

## C5. Verification commands & results

| Check | Result |
|-------|--------|
| `npm --prefix functions run build` | **PASS** |
| `npm --prefix functions run test:wave-a` | **651 pass / 0 fail / 1 skip** |
| Priority + sensitive emulator AuthZ | **PASS** (see C3) |
| OSV re-scan `functions/package-lock.json` | CRITICAL **0**; proxy-addr/node-forge cleared |
| Full Flutter Suite | **Not re-run** (no Flutter changes; prior EQ-T-04 green) |

---

## C6. Confirmed vs remaining risks

### Closed / remediated locally this campaign

1. `proxy-addr` CRITICAL version in runtime tree → **2.0.8**  
2. `node-forge` HIGH advisories via admin → **1.4.3**  
3. Priority callable HTTP AuthZ evidence gaps → **tests added** (no product logic change needed)  
4. Prior: `reactToChatMessage` deactivated AuthZ (**already fixed**)

### Remaining (documented, not chased)

| Item | Why left |
|------|----------|
| `axios` HIGHs | Quarantined Paymob-only; no active export |
| Other transitive HIGH/MODERATE | No confirmed active exploit path; avoid broad bumps |
| Cloud Rules/Indexes/Functions deploy | **Cloud / Owner** |
| BASMA-101 live index | **Cloud** |
| Firebase ownership/Billing strategy | **Owner** |
| Semgrep/CodeQL | Explicitly out of campaign scope |
| Remaining Core-only HTTP wrapper expansion | Low marginal value after priority three closed |

---

## C7. Campaign scorecard & completion answers

| Area | Result |
|------|--------|
| Dependency High/Critical applicable | **PASS** (proxy-addr + node-forge done; axios N/A active) |
| Three priority callables | **PASS** (reviewed + emulator AuthZ) |
| HTTP wrappers classification | **PASS WITH GAPS** (classified; no mass rewrite) |
| OSV after | **PASS WITH GAPS** (0 CRITICAL; axios etc. remain) |
| Production claim | **BLOCKED** |
| Campaign complete? | **Yes** — proceed to next phase |

1. **Critical/High remediable locally closed?** **Yes** for applicable runtime (`proxy-addr`, `node-forge`). Axios left as non-applicable active path.  
2. **Confirmed vuln remaining?** No new local AuthZ defect found in the three callables. Cloud Rules drift / missing indexes remain **Cloud-not-verified**.  
3. **OSV after?** functions lockfile: **30 raw / 29 unique / 0 CRITICAL**; proxy-addr & node-forge cleared.  
4. **Three ops tested?** **Yes** (HTTP emulator negatives + positive where applicable).  
5. **HTTP wrappers?** 14 classified; priority AuthZ gaps closed; others Core-covered authenticated callables.  
6. **Move to next phase?** **Yes.**

### Recommended next phase (non-Security-expansion)

1. Owner: Firebase project/Billing strategy (G0 Scenario C).  
2. When approved: Cloud Rules → Indexes (BASMA-101) → Functions deploy with gate still fail-closed.  
3. Optional later: axios removal or bump when Paymob reconsidered; remaining transitive hygiene.  
4. Product/release track: RB-16/17 signing IDs, device/RB-18 — **outside** this security campaign.

**Campaign closed.** No stage/commit/push; no Cloud/IAM/Billing; no production gate enable.
