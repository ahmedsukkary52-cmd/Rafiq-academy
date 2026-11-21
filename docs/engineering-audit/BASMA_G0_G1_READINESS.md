# BASMA G0/G1 — Cloud Readiness & Device Diagnostics

**Date:** 2026-11-20  
**Branch:** `unify/basma-v1`  
**HEAD:** `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (unchanged)  
**Policy:** Inspection only — **no** Blaze/IAM/ownership changes, **no** deploy, **no** `flutterfire configure`, **no** keystore creation, **no** install/uninstall/clear-data, **no** commit/push.

| Stage | Verdict |
|-------|---------|
| **G0** Cloud / Production readiness | **BLOCKED** |
| **G1** Physical device / DevTools | **NOT TESTED** (no Android device) / host tooling **PASS WITH GAPS** |

---

## 0. Note on prior work (ChatGPT sequencing)

Separate reports already existed:

- `BASMA_G0_CLOUD_AND_PRODUCTION_READINESS.md` (2026-11-19)
- `BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` (2026-11-18)

This document is the **unified G0+G1 deliverable** with **fresh verification** on 2026-11-20. It does **not** restart Chat/D2/D3/D4.

**Important delta vs Nov-19 G0:** CLI now lists **`basma-academy-production`** (was not present in the earlier G0 “verified aliases” snapshot). It is still **not** wired into `.firebaserc` or Flutter prod config.

---

## 1. Initial repository state

| Check | Result |
|-------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe` |
| Working tree | Dirty (~324 short-status lines); preserved |
| Git mutations | None |
| Cloud / Production mutations | **None** |

---

## 2. Existing reports reused

| Document | Use |
|----------|-----|
| `BASMA_G0_CLOUD_AND_PRODUCTION_READINESS.md` | Prior G0 inventory |
| `BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` | Prior device/DevTools evidence (incl. historical SM-A037F) |
| `BASMA_RELEASE_BLOCKERS.md` | RB-02…19 status |
| `BASMA_RB16_BUILD_CONFIG_REVIEW.md` / `BASMA_RB17_ANDROID_SIGNING_AUDIT.md` / `BASMA_RB18_…` | Release/signing/device |
| `FIREBASE_BILLING_CHECKLIST.md` | Blaze dependencies |
| `RELEASE_PLATFORM_SETUP.md` / Codemagic comments | Release wiring |
| D2 / D3 / D4 / Chat / Security Closure | Completed milestones — not re-audited |

---

## 3. G0 — Project / configuration findings

### 3.1 Firebase projects visible to this CLI account (2026-11-20)

`npx firebase projects:list` (**VERIFIED** this pass):

| Project ID | Display name | Notes |
|------------|--------------|--------|
| `rafiq-academy` | (current) | Trial / legacy development project · number `201515597019` |
| **`basma-academy-production`** | BASMA Academy production | **Exists** · number `764645874194` · resource location unspecified |
| Others | evently, movies-*, fitness, … | Unrelated to BASMA |

**Not in CLI list:** `rafiq-academy-staging`, `rafiq-academy-prod` (still referenced as aliases only).

### 3.2 Alias vs reality

| Alias (`.firebaserc`) | Target ID | Verified project? | Classification |
|-----------------------|-----------|-------------------|----------------|
| `dev` | `rafiq-academy` | **Yes** | READY (as trial/dev) |
| `staging` | `rafiq-academy-staging` | **No** | NOT YET VERIFIED / OWNER DECISION |
| `prod` | `rafiq-academy-prod` | **No** | NOT YET VERIFIED |
| — | `basma-academy-production` | **Yes** (CLI) | OWNER DECISION — whether this **is** the final prod target; **not** mapped in `.firebaserc` |

**Do not assume** alias strings equal live projects.  
**Do not assume** `basma-academy-production` is academy-owned, Blaze-enabled, or ready for deploy — ownership/billing **not** verified from repo alone.

### 3.3 Configuration → project mapping

| Surface | Points to | Status |
|---------|-----------|--------|
| `firebase.json` Flutter default | `rafiq-academy` | VERIFIED |
| `lib/firebase_options.dart` | `rafiq-academy` | VERIFIED |
| `android/app/google-services.json` | `rafiq-academy` · `com.example.rafiq_academy` | VERIFIED |
| `android/app/src/dev|staging/google-services.json` | `demo-rafiq-rules` | Emulator fakes |
| `android/app/src/prod/google-services.json` | — | **Missing** |
| iOS `GoogleService-Info.plist` | — | **Absent** (Dart options used historically) |
| `app_flavor.dart` | Trial → `rafiq-academy`; prod **refuses to start** until configured | VERIFIED fail-closed |
| Codemagic `android-prod-release` | Needs prod `google-services.json` + `basma_upload_key` | Explicitly blocked in YAML comments |

### 3.4 Flavor separation

| Flavor | applicationId | Firebase intent | Separation |
|--------|---------------|-----------------|------------|
| `dev` | `com.example.rafiq_academy` | Emulator `demo-rafiq-rules` only | Guarded |
| `staging` | `com.basmaacademy.app.staging` | Emulator only | Guarded |
| `trial` | **Same** as `dev` | Live `rafiq-academy` | Side-by-side install collision with dev |
| `prod` | `com.basmaacademy.app` | Final prod — **not configured** | Fail-closed |

---

## 4. G0 — Ownership, billing, release checklist

| Item | Classification | Evidence / notes |
|------|----------------|------------------|
| Final Firebase project selection | **OWNER DECISION REQUIRED** | Choose `basma-academy-production` vs new academy-owned project vs stay on `rafiq-academy` (RB-09) |
| Academy Google account / IAM transfer | **BLOCKED BY ACADEMY** | Invitation ≠ registered Google account; ownership transfer pending (owner context) |
| Billing / Blaze | **OWNER DECISION REQUIRED** | Checklist unresolved; Functions/scheduler typically need Blaze (RB-06) |
| Map `.firebaserc` / Flutter prod options to chosen project | **TECHNICAL WORK REQUIRED** | Only after owner names project + provides configs — **do not** run `flutterfire configure` without approval |
| Prod `google-services.json` / iOS Firebase options | **TECHNICAL WORK REQUIRED** | Files absent |
| Auth + admin provisioning on prod | **OWNER DECISION REQUIRED** | Model ready in code; live project + operators TBD (RB-15) |
| Rules deploy | **OWNER DECISION REQUIRED** | Local Rules strong (D4); Cloud ≠ Emulator (RB-03) |
| Storage Rules deploy | **OWNER DECISION REQUIRED** | RB-04 |
| Indexes deploy | **OWNER DECISION REQUIRED** | Local JSON present; Cloud complaints index historically missing (RB-02 / BASMA-101) |
| Functions deploy + `PRODUCTION_BACKEND_ENABLED` | **OWNER DECISION REQUIRED** | Fail-closed gate (RB-05/07); unpublished historically on trial |
| Android prod applicationId confirmation | **OWNER DECISION REQUIRED** | Provisional `com.basmaacademy.app` (RB-16) |
| Android upload keystore / Play App Signing | **OWNER DECISION REQUIRED** | No `key.properties` / no keystore in tree; Codemagic expects `basma_upload_key` (RB-17) |
| iOS bundle ID / Apple signing | **OWNER DECISION REQUIRED** / **BLOCKED BY ACADEMY** | Unsigned CI path only; no Apple account evidence (RB-16/19) |
| Codemagic pipelines | **TECHNICAL WORK REQUIRED** after secrets | YAML present; prod workflow intentionally blocked |
| Store publish | **BLOCKED BY ACADEMY** | RB-19 |
| Emulator AuthZ / local backend quality | **READY** | D4 / Security Closure / Chat / D2 evidence (local only) |

---

## 5. Release prerequisites & blockers (still OPEN)

From `BASMA_RELEASE_BLOCKERS.md` + this pass (no status closed without Cloud/device evidence):

| ID | Topic | Status |
|----|-------|--------|
| RB-02 | Recitation composite index on **final** Cloud | OPEN |
| RB-03 / RB-04 | Firestore / Storage Rules on production target | OPEN |
| RB-05 | Functions deployed | OPEN |
| RB-06 | Blaze / budget | OPEN |
| RB-07 | Production backend gate unlock | OPEN |
| RB-08 | Prod secrets/env | OPEN |
| RB-09 | Final project selection | OPEN — **`basma-academy-production` now visible; decision still required** |
| RB-11…13 | Meeting-link migration / supervisor add | OPEN |
| RB-14 / RB-15 | Payment + account E2E on live | OPEN |
| RB-16 / RB-17 | Build IDs + signing | OPEN |
| RB-18 | Physical device matrix | OPEN |
| RB-19 | Store | OPEN |
| RB-01 / RB-10 | | CLOSED (documented) |

---

## 6. G1 — Environment / device findings (2026-11-20)

| Check | Result | Class |
|-------|--------|-------|
| Flutter | 3.44.9 · Dart 3.12.2 · DevTools 2.57.0 | VERIFIED |
| Host OS | Windows 11 25H2 | VERIFIED |
| `adb devices -l` (twice) | **Empty** — no USB/wireless device | VERIFIED absence |
| `flutter devices` | Windows + Chrome + Edge only | VERIFIED |
| Samsung SM-A037F | **Not connected** this pass | Do not assume prior wireless session |
| Android SDK | Present (API 37 tooling); licenses **not fully accepted** | PARTIAL |
| Emulator | Available via Flutter tooling; **not started** | NOT TESTED |
| Installed app probe | Impossible without device | BLOCKED |
| DevTools / Observatory on device | No Android VM service | BLOCKED |
| Prior G1 evidence (Nov-18) | Wireless ADB + Admin screenshot + Logcat FAILED_PRECONDITION (complaints index) when device was present | Historical only |

**G1 physical diagnostics:** **NOT TESTED** this session (no device).  
**G1 host readiness:** tooling present with license gap → not a substitute for device lab.

---

## 7. DevTools measurements

| Metric | Result |
|--------|--------|
| Frame / jank | **NOT MEASURED** |
| Rebuild / memory / streams | **NOT MEASURED** |
| Profile-mode baselines (RB-D4-03) | **NOT MEASURED** |

No performance claims without measurement.

---

## 8. Reproducible runtime issues

| Finding | Severity | Status this pass |
|---------|----------|------------------|
| Live Firestore missing composite index (complaints) on `rafiq-academy` | RELEASE BLOCKER (Cloud) | Historical device Logcat; **not re-proven** without device |
| Prod flavor cannot start (intentional) | INFORMATIONAL | VERIFIED in `app_flavor.dart` |
| Staging/prod aliases without projects | HIGH (config risk) | VERIFIED via projects list |
| `basma-academy-production` exists but unwired | OWNER DECISION | VERIFIED existence; **NOT** claimed ready |

No new device-confirmed defect this pass.

---

## 9. Fixes and regression tests

**None.** G0/G1 scope forbids ownership/billing/signing/prod config changes. No low-risk local defect requiring a code fix was confirmed in this inspection.

---

## 10. Unverified areas

- Blaze / billing status of `basma-academy-production` and `rafiq-academy`
- IAM: whether academy org owns `basma-academy-production`
- Live Rules/Functions/Indexes text on either project
- Current install state of any APK on SM-A037F
- Codemagic remote secret presence (`basma_upload_key`)
- iOS Apple Developer enrollment

---

## 11. Academy / owner decisions required

1. Confirm whether **`basma-academy-production`** is the final production Firebase project (or create/transfer an academy-owned project).
2. Complete academy Google account registration + IAM ownership transfer.
3. Approve **Blaze** + budgets (or document Spark limitations).
4. Authorize wiring Flutter/Android/iOS + `.firebaserc` to the chosen project (**owner-approved** `flutterfire` / console apps).
5. Create and escrow Android upload keystore; register Codemagic `basma_upload_key`; Play App Signing.
6. Confirm prod `applicationId` / iOS bundle ID / iPad support.
7. Authorize Rules → Indexes → Functions deploy order on the **final** project (gate remains fail-closed until RB-07).
8. Reconnect physical device for RB-18 / DevTools when ready.

---

## 12. Remaining release blockers (summary)

**Hard blockers:** final project ownership + Blaze + prod Firebase client configs + signing + Cloud Rules/Indexes/Functions deploy + device verification + store enrollment.

**Local strengths (not release):** Emulator AuthZ (D4), efficiency (D2), chat/attachments, fail-closed flavors, Codemagic fail-closed prod workflow.

---

## 13. Recommended next roadmap step

1. **Owner workshop:** decide production project (`basma-academy-production` vs alternative) + academy account/IAM + Blaze.  
2. After written approval: technical wiring of prod Firebase configs (still no deploy until checklist signed).  
3. Parallel when phone available: **G1 device reconnect** for RB-18 / RB-D4 visuals / DevTools.  
4. Only then: Cloud deploy sequence (Rules → Indexes → Functions) under release runbook — **not** auto-started here.

Do **not** auto-start EQ-M-05/T1 or another audit phase from this report.

---

## Final verdicts

### G0: **BLOCKED**

Ready locally for emulator/trial engineering; **blocked** for production by ownership, billing, alias/project wiring, missing prod client configs, signing, and undeployed Cloud surfaces.

### G1: **NOT TESTED**

No physical Android device attached on 2026-11-20. Host Flutter/ADB tooling works with gaps (licenses). Prior Nov-18 device evidence remains historical and is **not** claimed as current PASS.

**Cloud/Production changes this phase:** **none**.
