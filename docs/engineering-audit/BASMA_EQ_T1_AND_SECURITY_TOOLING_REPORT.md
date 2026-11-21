# BASMA — EQ/T1 Execution & Security / Code-Review Tooling Report

**Date:** 2026-11-19  
**Branch:** `unify/basma-v1` @ `8ce64fe97440c33acefaf1e140022ddbe0075ab5`  
**Nature:** Local T1 hygiene + tooling inventory/execution under G0 safety boundaries.  
**Verdict:** **PASS WITH GAPS**

---

## Evidence classes

| Label | Meaning |
|-------|---------|
| **Verified** | Command/test output this pass |
| **Inferred** | From code/docs without re-execution |
| **Emulator** | Local Firebase Emulator / Node unit (not Cloud) |
| **Cloud / device** | Requires live project or physical lab |
| **Owner** | Requires owner approval |

---

## 1. Git state

### Before

| Item | Value |
|------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (**match**) |
| Staged | `0` |
| Tracked modified | `196` |
| Untracked | `70` (grew during prior G0/G1 docs; see After) |
| G0 report | Present |
| G1 + BASMA-101 §14 | Present |

No unexpected staged content. Pre-existing dirty tree **preserved**.

### After (this task)

| Item | Value |
|------|--------|
| HEAD | Unchanged `8ce64fe…` |
| Staged | `0` |
| Source / config / indexes / Functions | **Not modified** by this task |
| Tracked modified | Still `196` (unchanged by this pass’s product/config edits) |
| Untracked | `73` (includes this report + new test dirs; prior G0/G1 docs retained) |
| New untracked tests | `test/features/onboarding/` · `test/features/review_schedule/` |
| New untracked report | This file |
| Git mutations | **None** (no add/commit/push/reset/stash) |

---

## 2. T1 scope (extracted)

**Sources:** `BASMA_REMAINING_WORK_ROADMAP.md` Phase T1; `BASMA_FINAL_ENGINEERING_QUALITY_REVIEW.md` §5.D; register BASMA-105 / BASMA-108 / BASMA-110; progress log “next: EQ-M-05 or T1”.

| ID | Title | Prior status | This pass |
|----|-------|--------------|-----------|
| **EQ-T-01** | onboarding / review_schedule feature tests | Open (zero/thin) | **Done (local)** — new focused tests |
| **EQ-T-02** | Coverage % campaign (BASMA-105) | Optional / DISCOVERED | **Not run** — optional; LCOV not executed |
| **EQ-T-03** | Callable wrapper coverage (30 core-only) | Open / release-adjacent | **Not expanded** — emulator campaign; out of T1 “fill gaps selectively”; existing gate unit re-checked |
| **EQ-T-04** | Re-prove Full Suite on dirty tree | Open (RB-01 historical only) | **FAILING** — `+2523 ~3 -2` (arch); see §5 |
| **EQ-M-05** | Audio bloc `FirebaseAuth` coupling | Open (schedule later) | **Not implemented** — requires injectable/`injection_container.config.dart` change (overlaps **EQ-M-06** deferred). Documented as architecture decision |
| **EQ-M-06** | Injectable regen | Deferred | Untouched |

**Not in T1:** PDF/AdminBloc redesign, Cloud deploy, G0 owner decisions, Quran/Mushaf.

---

## 3. What was implemented

### EQ-T-01 — new tests only (no product behavior change)

| File | Purpose |
|------|---------|
| `test/features/onboarding/onboarding_page_test.dart` | Widget: first slide advance, Skip → prefs+notifier, last CTA finishes |
| `test/features/review_schedule/review_month_mapper_test.dart` | Pure mapper: Hijri range, status completed/today/upcoming, ayah-only label |
| `test/features/review_schedule/get_review_month_usecase_test.dart` | Use case Right path + `ServerException` + sanitized unexpected `ServerFailure` |

### EQ-M-05 — deferred with rationale

`AudioLibraryBloc` is `@injectable` and wired in **generated** `injection_container.config.dart` with `FirebaseAuth`. Removing Auth from the bloc constructor requires codegen or a manual config patch (EQ-M-06 risk on dirty WT). Existing `test/features/audio_library/audio_library_bloc_test.dart` already fakes Auth.

**Owner/architecture decision required** before implementing EQ-M-05 (approve dedicated DI patch vs regen).

---

## 4. Commands & results (Verified)

| Command | Result |
|---------|--------|
| `flutter test` (3 new EQ-T-01 files) | **All tests passed!** (9) — exit 0 |
| `dart analyze test/features/onboarding test/features/review_schedule` | **No issues found** — exit 0 |
| `flutter test test/architecture/dependency_boundaries_test.dart` | **+69 −2** — failures in **pre-existing** WT: `core -> role imports` allowlist drift (**not** caused by new tests) |
| `npm run test:unit` in `functions/` (gate/Paymob quarantine) | **2 passed** — B-BILLING gate + Paymob not exported |
| Full `flutter test` (EQ-T-04) | Started on dirty tree; log `D:\Temp\basma_eq_t1_full_suite.txt` — **do not treat as green until complete** |
| Live Firebase / deploy / Cloud rules | **Not run** |
| Device lab | **Not re-run** (see G1) |

### Architecture failure note (pre-existing)

Failures: `C: core -> role imports only the 4 known core files…` and `generated DI config is reached only via injection_container`. These scan current dirty `lib/` — **Inferred** as WT collateral, not T1 regressions. Fixing them would be a separate EQ/architecture allowlist or WT cleanup task.

---

## 5. EQ-T-04 Full Suite

| Aspect | Status |
|--------|--------|
| Historical RB-01 | `+2486 ~3` — **not** on `0889682` |
| This pass | Full `flutter test` on **dirty WT**; log `D:\Temp\basma_eq_t1_full_suite.txt` |
| **Final** | **`+2523 ~3 -2` — Some tests failed** (~05:06 wall) |
| Failures | Both in `dependency_boundaries_test` (core→role allowlist + DI config via `injection_container` only) — pre-existing dirty-WT arch drift, **not** introduced by EQ-T-01 tests |
| Claim | **Cannot claim green** on current dirty tree |
| Limitation | Dirty-tree suite ≠ isolated HEAD `8ce64fe` proof |

**EQ-T-04 outcome for this pass:** **PASS WITH GAPS / not green** — re-prove after arch WT cleanup or on a cleaner checkpoint. Do **not** rewrite historical RB-01.

---

## 6. Security & Code-Review tooling inventory

### A. Static analysis & quality

| Tool | Installed? | Cost / account | External data? | Fit | Run now? | Recommendation |
|------|------------|----------------|----------------|-----|----------|----------------|
| `dart analyze` / IDE analyzer | Yes (`flutter_lints`) | Free | No | High | **Yes** — clean on new tests | Keep as primary gate |
| `dart format` | SDK | Free | No | High | Not batch-run (avoid mass WT churn) | Use on touched files only |
| Architecture `dependency_boundaries_test` | Yes | Free | No | High | **Yes** — 2 pre-existing fails | Fix in dedicated WT cleanup |
| `flutter test` | Yes | Free | No | High | **Yes** | Continue |
| `dart pub outdated` / deps | Available | Free | Pub.dev metadata | Medium | Optional later | After dependency freeze |
| custom_lint / DCM / very_good_analysis | **Not** in pubspec | Free/paid tiers | Usually local | Medium | **No** (needs add+owner) | Later if team wants stricter lint |
| Dead-code / unused dep scanners | Not configured | Varies | Possibly | Medium | **No** | Later |

### B. Security

| Tool / harness | Installed? | Cost / account | External? | Fit | Run now? | Recommendation |
|----------------|------------|----------------|-----------|-----|----------|----------------|
| `rules_test` Firestore/Storage suites | Yes (`rules_test/package.json`) | Free | Local emulator | High | Not full matrix this pass (time) | Run before Rules deploy (G0) |
| Functions emulator suites | Yes (`functions` scripts) | Free | Local | High | Gate unit **Yes** | Keep; wrapper gap = EQ-T-03 |
| `productionGate` / `PRODUCTION_BACKEND_ENABLED` | In source | Free | No | Critical | Unit **PASS** | Must stay closed (RB-07) |
| Local secret pattern scan (rg) | Ad-hoc | Free | No | Medium | **Yes** — 0 hits for PEM/AKIA in scanned globs | Not a substitute for secret manager review |
| `google-services.json` / options | Present | — | Contains client IDs (normal) | — | Not “secrets” but don’t paste | Keep git discipline |
| Snyk / OSV / Dependabot | **Not** configured (no `.github`) | Often paid/SaaS | **Yes** — may upload lockfiles | Medium | **No** without owner | Owner decision if SaaS OK |
| Firebase App Check / live Rules audit | Cloud | — | Cloud | High for prod | **Blocked** (G0) | After project+deploy |

### C. Automated PR / code review

| Tool | Status | Recommendation |
|------|--------|----------------|
| GitHub Actions / Dependabot | **No** `.github` workflows found | Optional later |
| Codemagic | `codemagic.yaml` present — analyze/test/build; `basma_upload_key` name-only | Config review OK; **don’t** run prod release |
| Cursor Bugbot / Security Review | Available as agent skills when requested | Use on PR diffs when owner asks |
| Copilot/CodeQL etc. | Not installed | Owner decision |

### D. CI/CD & production gates

| Check | Result |
|-------|--------|
| Codemagic `flutter test` in workflows | Present (static) |
| Prod signing | `android_signing: [basma_upload_key]` — no keystore in repo |
| Prod flavor Cloud | Fail-closed until Firebase configured (app_flavor) |
| Backend gate | Unit denies production without env flags — **Verified** |
| GitHub CI | Absent |

**Production gate status:** remains **closed** by design — **PASS** for “not accidentally opened”.

---

## 7. Findings severity

| Severity | Finding | Class |
|----------|---------|--------|
| Pre-existing / Medium | Architecture boundary tests −2 on dirty `lib/` | Verified fail; not introduced by T1 |
| Confirmed (prior G1) | BASMA-101 complaints index missing on Cloud | Cloud — not re-fixed here |
| Info | EQ-M-05 blocked on DI regen policy | Owner/architecture |
| Info | EQ-T-02 coverage % still unknown | Optional |
| Info | No GitHub Actions | Process gap |
| Low | Secret regex scan clean for common PEM/AKIA patterns | Local only; not exhaustive |

**No new product/security vulnerability was “fixed” in lib/** this pass — T1 added **tests**.

---

## 8. Limitations (do not overclaim)

- Emulator / unit gate ≠ Cloud AuthZ.  
- Analyze + tests ≠ absence of vulnerabilities.  
- Dirty-tree Full Suite ≠ proof of clean HEAD `8ce64fe`.  
- Device/Cloud readiness still per G0/G1.  
- Quran/Mushaf untouched.

---

## 9. Proposed register / roadmap updates (**not applied this task**)

Suggest owner later:

1. BASMA-110 / EQ-T-01 → note “focused onboarding + review_schedule tests added (untracked until docs/tests commit)”.  
2. EQ-M-05 → “blocked pending EQ-M-06 / DI config change approval”.  
3. EQ-T-04 → attach Full Suite log result when finished.  
4. Roadmap: after T1 tests land, next local = EQ-M-05 (if approved) or SEC tooling SaaS decision; Cloud remains G0.

---

## 10. Scorecard

| Area | Result |
|------|--------|
| Git / Firebase / signing safety | **PASS** (no mutations/deploys) |
| EQ-T-01 | **PASS** (9 tests) |
| EQ-T-02 | **NOT RUN** (optional) |
| EQ-T-03 | **PASS WITH GAPS** (gate unit only; wrappers not expanded) |
| EQ-T-04 | **PASS WITH GAPS** — dirty WT `+2523 ~3 -2` (arch allowlist); not green |
| EQ-M-05 | **OWNER DECISION REQUIRED** (DI) |
| Tooling inventory | **PASS** |
| Security local gates | **PASS WITH GAPS** |
| Production readiness claim | **BLOCKED** (G0) |

### Overall: **PASS WITH GAPS**

---

## 11. Recommended next phase

1. EQ-T-04 recorded: **`+2523 ~3 -2`** — decide whether to fix dirty-WT arch allowlist drift before claiming green.  
2. Owner: approve whether to implement **EQ-M-05** with manual DI config patch vs injectable regen (**EQ-M-06**).  
3. Owner: G0 decisions (project/Blaze/indexes) — still blocks Cloud security proof.  
4. Optional: commit **tests + this report** only when owner authorizes a docs/tests commit (not done here).  
5. SEC: optional SaaS scanners only with owner approval for data egress.

**Stop for owner review** — no stage/commit/push performed.
