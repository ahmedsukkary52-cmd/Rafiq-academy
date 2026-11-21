# BASMA RB-17 — Android Signing & Upload Key Readiness Audit

**Date:** 2026-11-18  
**Scope:** Local review + safe hardening of Android **upload** signing readiness.  
**Not in scope:** Creating a keystore, uploading secrets, Play Console enrollment, Firebase project creation, changing applicationId/namespace, running Codemagic workflows.

**Verdict:** `READY FOR OWNER KEY CREATION`

RB-17 register status remains **`OPEN`** until the owner creates/backups the upload key, wires Codemagic `basma_upload_key`, and (for a shippable AAB) completes related prod Firebase / ID confirmation gates.

---

## 1. Flavor signing state (actual)

| Flavor | applicationId | namespace | signingConfig | Store-bound? |
|--------|---------------|----------|---------------|--------------|
| **dev** | `com.example.rafiq_academy` (+ optional `.review`) | `com.example.rafiq_academy` | **debug** | No — local / emulator |
| **staging** | `com.basmaacademy.app.staging` | same namespace | **debug** | No — local / emulator |
| **trial** | `com.example.rafiq_academy` (**same as dev**) | same namespace | **debug** | No — academy trial APK; not Play upload |
| **prod** | `com.basmaacademy.app` (**provisional** — owner must confirm) | same namespace | **upload** only if key material complete; else **no** flavor signingConfig | Yes — intended Play AAB |

**dev vs trial applicationId collision:** Both use `com.example.rafiq_academy` with the **debug** key, so they **cannot** be installed side-by-side (one replaces the other). The optional `-PbasmaReviewBuild=true` path adds `.review` for a parallel personal review APK. **Not changed** in this audit (owner/product decision if a distinct trial ID is ever required).

**Firebase linkage (unchanged):** Flavor applicationIds must match registered Android apps in that flavor’s `google-services` / Dart options. Prod still lacks `android/app/src/prod/google-services.json` (RB-09 / B1 / B2) — blocks a runnable prod binary against Cloud, not the act of creating an upload keystore.

---

## 2. Current signing flow (detail)

**Source of truth:** `android/app/build.gradle.kts`

1. **Resolve upload key map**
   - Prefer `android/key.properties` (`rootProject.file("key.properties")`) with keys: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
   - Else Codemagic-injected env: `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`.
2. **`hasUploadKey`** = all four values non-blank.
3. **If `hasUploadKey`:** create `signingConfigs.upload` (passwords never hardcoded).
4. **Flavor attach**
   - dev / staging / trial → always `signingConfigs.debug`.
   - prod → `signingConfigs.upload` **only if** `hasUploadKey`.
5. **`buildTypes.release`** does **not** set `signingConfig` (so flavor config wins; no forced debug on release).
6. **Fail-closed guard** (`gradle.taskGraph.whenReady`): if `!hasUploadKey` and any task matches  
   `^(assemble|bundle|package|install)ProdRelease.*` → `GradleException` naming `key.properties` / `CM_KEYSTORE_*` (no secret values).

**Observed this pass:** `key.properties` absent; local `CM_*` unset; `flutter build apk --flavor prod --release` → exit 1 with upload-key message (log `D:\Temp\rb17_prod_failclosed.txt`).

**No unintended debug-signed prod release path found** when the guard is present: prod never assigns `"debug"`; missing key stops ProdRelease artifact tasks before packaging.

---

## 3. Release-guard review results

| Check | Result |
|-------|--------|
| Prod flavor references upload, not debug | Pass (contract test) |
| Dev / staging / trial on debug | Pass (trial coverage **added** this pass) |
| Release buildType does not force signingConfig | Pass |
| whenReady ProdRelease regex present | Pass |
| No literal passwords in Gradle | Pass |
| Fail-closed runtime without key | Pass (rebuild this pass) |
| Keystores tracked in Git | None (`git ls-files` empty for jks/keystore/key.properties) |
| `git check-ignore` | `android/key.properties`, `*.jks`, `*.keystore` ignored |

---

## 4. Codemagic review (static — workflow not run)

**Workflow:** `android-prod-release`

| Topic | Finding |
|-------|---------|
| Signing reference | `android_signing: [basma_upload_key]` — name-only; matches setup docs |
| Build | `flutter build appbundle --flavor prod --release` → expects signed **AAB** under `prodRelease` |
| Artifacts | `*.aab` + ProGuard mapping path only — **no** keystore / `key.properties` |
| Secrets in YAML | None (contract test rejects password-like keys) |
| Triggers / publishing | None |
| Missing keystore in CM account | Gradle `hasUploadKey=false` → same fail-closed exception (clear failure) |
| Debug signing risk in this workflow | Low: prod + release + CM signing injection; no `--debug` |
| Log leak risk in scripts | Scripts only `pub get` / `test` / `build appbundle` — no `echo` of `CM_*` |

**Not verified here:** Actual Codemagic injection of `CM_*`, presence of `basma_upload_key` in the team account, or a green signed AAB.

`android-dev-check` remains debug APK only (debug key) — appropriate; WT adds emulator dart-define (out of RB-17 mutation scope beyond observation).

---

## 5. Key / secret leak risks

| Risk | Mitigation status |
|------|-------------------|
| Commit `.jks` / `.keystore` / `key.properties` | Ignored in `android/.gitignore` **and** root `.gitignore` (root patterns **added** this pass) |
| Hardcoded passwords in Gradle/YAML | Absent; tested |
| Codemagic artifacts shipping keystore | Not in artifact globs |
| Chat / ticket paste of passwords | Process rule — owner must not paste secrets into chat |
| CI log printing env secrets | No such steps in `codemagic.yaml` |
| Leaving keystore inside repo working tree | Plan: store **outside** repo; `storeFile` absolute or carefully gitignored path |

---

## 6. Owner plan — create / store / restore upload keystore

**Do not create the key in this agent session.** When the owner is ready:

1. **Confirm** provisional prod `applicationId` (`com.basmaacademy.app`) before first Play upload.
2. On a trusted machine, generate upload keystore (example only):  
   `keytool -genkey -v -keystore <OUTSIDE_REPO>/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
3. Save **store password**, **key alias**, **key password** in a password manager; keep an **encrypted offline backup** of the `.jks`.
4. Fingerprints (for Firebase / Play console):  
   `keytool -list -v -keystore <path-to-upload-keystore.jks>`  
   Record SHA-1 / SHA-256; never commit the keystore.
5. **Local (optional):** `android/key.properties` → `storeFile`, `storePassword`, `keyAlias`, `keyPassword` (git-ignored).
6. **Codemagic:** Team settings → Android keystores → upload as reference name **`basma_upload_key`**.
7. **Play Console:** Enable **Play App Signing** on first upload — Google holds the **app signing key**; team keeps the **upload key**. Upload-key loss → Play support reset path; still treat backups as critical.
8. Register upload (and later Play App Signing) certificates on the **prod** Firebase Android app after that project exists.

---

## 7. Owner decisions still required

1. Confirm prod Android `applicationId` (permanent after first Play upload).  
2. Create + backup upload keystore (this RB-17 execution step).  
3. Upload keystore to Codemagic as `basma_upload_key`.  
4. Enroll Play App Signing (recommended) at first AAB upload.  
5. Prod Firebase project + `google-services.json` / options (RB-09 / B1 / B2) before a meaningful prod runtime.  
6. Whether trial should keep sharing dev’s applicationId (side-by-side install limitation).  
7. Release versioning bump policy remains: bump `pubspec` `+N` and `kAppBuildNumber` together (no CI `--build-number`).

---

## 8. Files changed this pass

| File | Change |
|------|--------|
| `test/core/release/release_signing_contract_test.dart` | Trial debug-key coverage; root gitignore asserts; Codemagic prod artifact/name asserts |
| `.gitignore` | Defense-in-depth `*.jks` / `*.keystore` / `key.properties` (kept existing `/_backups/` hunk) |
| `android/app/build.gradle.kts` | Comment accuracy only (trial + fail-closed note) — **no** signingConfig logic change |
| `docs/production/RELEASE_PLATFORM_SETUP.md` | Signing section: trial, upload vs App Signing, owner steps |
| `docs/engineering-audit/BASMA_RB17_ANDROID_SIGNING_AUDIT.md` | This report |
| `docs/production/BASMA_RELEASE_BLOCKERS.md` | RB-17 evidence notes; status stays OPEN |

**Not changed:** applicationId, namespace, Firebase projects, Codemagic account, keystores (none created), Quran/Mushaf, D2 staged set, payment indexes.

---

## 9. Tests run (this pass)

| Test | Result |
|------|--------|
| `flutter test test/core/release/release_signing_contract_test.dart` | **+11 All passed** |
| `flutter build apk --flavor prod --release` (no key) | **exit 1**, upload-key `GradleException` |
| Full Flutter Suite | **Not run** |
| Codemagic workflow execution | **Not run** |
| Real signed AAB | **Not produced** (correct — no key) |

---

## 10. Git state

Recorded in the agent final report for this task (HEAD unchanged; staging count unchanged; prior WT changes preserved).

---

## 11. RB-17 judgment

| Item | Status |
|------|--------|
| Technical signing wiring | Sound |
| Fail-closed without upload key | Proven |
| Codemagic YAML contract | Aligned (static) |
| Upload keystore exists | **No** — owner action |
| CI keystore registered | **Unknown / pending owner** |
| Play App Signing enrolled | **Pending owner** |
| Register status | **`OPEN`** |
| Audit verdict | **`READY FOR OWNER KEY CREATION`** |

Closing RB-17 requires named evidence of owner key creation/backup + Codemagic `basma_upload_key` wiring (and versioning process acknowledgment)—not merely this local audit.
