# BASMA RB-16 — Android / iOS Build Configuration Review

**Date:** 2026-11-18  
**Host OS for this pass:** Windows 10 (static iOS review only; no Xcode Archive)  
**Flutter:** 3.44.9 (matches `codemagic.yaml` pin)  
**Blocker:** `RB-16` Android/iOS build configuration review  

This report is an engineering review of **release preparation config**. It does **not** create store releases, signing material, or Firebase projects.

---

## Status split

| Layer | Result |
|-------|--------|
| Formal local config review | **Complete** (this document) |
| Safe local config fix applied | `INTERNET` declared in main `AndroidManifest.xml` |
| Android prod store-ready | **No** — missing prod `google-services.json`, upload keystore (RB-17 / B8), owner ID confirmation |
| iOS Archive / signed build verified | **No** — requires macOS/Xcode / Codemagic (`ios-unsigned-check`) |
| Codemagic executed against this worktree | **No** — workflows defined; CI not proven here |
| RB-16 register status | Remains **`OPEN`** until remaining review gaps + owner/CI evidence are accepted |

---

## 1. Discovery summary

| Area | Found |
|------|--------|
| App name / version | `pubspec.yaml` → `rafiq_academy`, `version: 1.0.0+2` (= `versionName`/`versionCode`); `kAppBuildNumber = 2` |
| Default flavor | `default-flavor: dev` |
| Android Gradle | Kotlin DSL: `android/settings.gradle.kts`, `android/app/build.gradle.kts` |
| AGP / Gradle / Kotlin | AGP **8.11.1**, Gradle **8.14**, Kotlin **2.2.20**, Java **17** |
| SDK levels (Flutter defaults) | `minSdk 24`, `compileSdk 36`, `targetSdk 36` |
| Android flavors | `dev`, `staging`, `trial` (WT), `prod` |
| iOS flavor files | `Flavor-dev` / `Flavor-prod` + Mode wrappers; `configure_flavors.rb` |
| Codemagic | `codemagic.yaml` — 3 manual workflows |
| Release docs | `docs/production/RELEASE_PLATFORM_SETUP.md`, `RELEASE_RUNBOOK_J10.md` |
| Firebase aliases | `.firebaserc`: `dev→rafiq-academy`, `staging→rafiq-academy-staging`, `prod→rafiq-academy-prod` |

---

## 2. Android release configuration

### 2.1 Identifiers

| Flavor | applicationId | Label | Signing (config) |
|--------|---------------|-------|------------------|
| dev | `com.example.rafiq_academy` (+ optional `.review`) | بصمة (تطوير) | debug |
| staging | `com.basmaacademy.app.staging` | بصمة (تجريبي) | debug |
| trial (WT) | `com.example.rafiq_academy` (shares dev) | بصمة (تجربة الأكاديمية) | debug |
| prod | `com.basmaacademy.app` | بصمة | upload key when present |

- **namespace:** `com.example.rafiq_academy` (all flavors). Acceptable technically (`namespace` ≠ `applicationId`), but **Play-facing prod ID still needs owner confirmation** before first upload.
- **MainActivity** package matches namespace: `com.example.rafiq_academy.MainActivity`.

### 2.2 Build / Firebase guards (strengths)

- Prod release **fails closed** without upload key (`key.properties` or Codemagic `CM_KEYSTORE_*`).
- Local flavors (`dev`/`staging`) are **debug-only** and require `USE_FIREBASE_EMULATOR=true`; fake `google-services.json` must be `demo-rafiq-rules`.
- `trial` must **not** use the emulator dart-define (guard in Gradle WT).
- Dart `assertFirebaseRouting` refuses silent fallback to the wrong project; `prod` refuses to start until configured.

### 2.3 Manifest / Play-facing

| Topic | Finding |
|-------|---------|
| Launcher activity | `exported=true`, MAIN/LAUNCHER only — no custom deep-link intent-filters |
| Media permissions | Explicitly **removed** (`tools:node="remove"`) — good for Play policy |
| RECORD_AUDIO | Declared; runtime request expected |
| INTERNET | Was only in debug/profile app manifests; **release relied on `firebase_messaging` merge**. Fixed: declared in **main** manifest this pass |
| POST_NOTIFICATIONS | Comes from `firebase_messaging` merge (Android 13+) |
| Cleartext | Only via debug `networkSecurityConfig` — not on release path |
| ProGuard / R8 | **Not enabled** on release (`isMinifyEnabled` absent) — OK for first ship; mapping artifact path exists in Codemagic for when enabled |
| Adaptive icon | Present (`mipmap-anydpi-v26` + foreground) — `RELEASE_PLATFORM_SETUP` §5 text is partly stale vs current assets |
| Versioning | Tied to pubspec; Codemagic correctly avoids `--build-number` override (B10 / `kAppBuildNumber`) |

### 2.4 Firebase Android files

| File | Role |
|------|------|
| `android/app/google-services.json` | Dev/root (`rafiq-academy`) |
| `android/app/src/dev/google-services.json` | Emulator fake `demo-rafiq-rules` |
| `android/app/src/staging/google-services.json` | Emulator fake |
| `android/app/src/prod/google-services.json` | **Missing** — blocks prod Google Services step |

### 2.5 Existing unstaged Android/CI deltas (left untouched)

- `android/app/build.gradle.kts`: adds `trial` flavor + emulator guard (preserve).
- `codemagic.yaml`: `android-dev-check` builds with `USE_FIREBASE_EMULATOR=true` (preserve; aligns with local-flavor guards).

---

## 3. iOS release configuration (static review on Windows)

| Topic | Finding |
|-------|---------|
| Bundle IDs | Dev `com.example.rafiqAcademy` (matches `firebase_options`); Prod **provisional** `com.basmaacademy.app` |
| Deployment target | **13.0** (`Podfile` + `IPHONEOS_DEPLOYMENT_TARGET`) |
| Signing in pbxproj | Automatic; **no** `DEVELOPMENT_TEAM` |
| Entitlements | `aps-environment` = `development` (Xcode flips to production on App Store export — per docs) |
| Info.plist | Mic + Photo Library usage strings (Arabic); `remote-notification` background mode; display name via `$(APP_DISPLAY_NAME)` |
| URL schemes | **None** declared in Info.plist |
| GoogleService-Info.plist | **Absent** — intentional; Dart `FirebaseOptions` used |
| Xcode flavors in committed `project.pbxproj` | Still base Debug/Release/Profile only — flavors applied by `ios/scripts/configure_flavors.rb` (Codemagic / macOS) |
| Podfile.lock | Not treated as proven on this Windows host |
| Device family | iPhone + iPad (`TARGETED_DEVICE_FAMILY` per setup doc) — **owner must confirm iPad** before App Store |

**Cannot claim from this host:** `pod install` success, unsigned `flutter build ios`, Archive, Export, or signing validity.

---

## 4. Codemagic

| Workflow | Purpose | Ready? |
|----------|---------|--------|
| `android-dev-check` | analyze + **full** `flutter test` + dev debug APK (+ emulator define in WT) | Config ready; not executed here |
| `android-prod-release` | tests + signed AAB via `basma_upload_key` | **Blocked** — prod Firebase (B1/B2), keystore (B8) |
| `ios-unsigned-check` | configure flavors + `--no-codesign` builds | Needs macOS instance + repo connection; not run here |

Risk notes (no secrets printed):

- Flutter pin **3.44.9** matches local toolchain used this pass.
- Signing references by **name only** (`basma_upload_key`); no keystores in repo (`key.properties` absent / gitignored).
- Wrong-Firebase risk mitigated by flavor dart/Gradle guards; **prod workflow still must not run** until prod config exists.
- `android-dev-check` runs the **full** test suite in CI (separate from local RB-01 close decision).

---

## 5. Findings by priority

### P0 — blocks store / prod binary

1. Prod Firebase project + `android/app/src/prod/google-services.json` + prod `FirebaseOptions` missing (RB-09 / B1 / B2).
2. Play upload keystore not present locally/CI (RB-17 / B8).
3. iOS unsigned/CI path not yet proven green (`ios-unsigned-check`).

### P1 — must decide before first store record

4. Confirm Android prod applicationId `com.basmaacademy.app`.
5. Confirm iOS prod bundle ID (currently provisional copy of Android ID).
6. Confirm iPad support (screenshots / device family).
7. Dev/trial still use `com.example.*` IDs — acceptable for non-store; do **not** ship prod under `com.example`.

### P2 — polish / follow-ons (RB-D4 / RB-18 / RB-19)

8. Icon/splash/store asset matrix still open (RB-D4-01/02); setup doc §5 partially stale.
9. No R8 minify yet — optional for later hardening.
10. No custom Android App Links / iOS URL schemes — OK unless product requires them.
11. `namespace` remains `com.example.rafiq_academy` — fine technically; rebrand package path is optional later.

### P3 — process / documentation

12. Codemagic not connected / not run against current branch.
13. `RELEASE_PLATFORM_SETUP.md` dated 2026-10-21; trial flavor and some assets evolved in WT since then.

---

## 6. Fixes applied this pass

| Change | Why |
|--------|-----|
| `android/app/src/main/AndroidManifest.xml` — add `INTERNET` | Release networking must not depend solely on plugin manifest merge |
| This evidence document | Durable RB-16 review record |
| `BASMA_RELEASE_BLOCKERS.md` RB-16 notes | Reflect review outcome; status stays OPEN |

**Not changed (owner / out of scope):** applicationId, bundle ID, Firebase project, signing keys, payment indexes, Quran/Mushaf, D2 staged set, RB-01/02 artifacts, `build.gradle.kts` / `codemagic.yaml` existing WT hunks.

---

## 7. Verification run this pass

| Check | Result |
|-------|--------|
| Flavor / iOS contract tests | `flavor_config_contract_test` + `app_flavor_test` + `ios_flavor_contract_test` → **+37 All passed** |
| Gradle `:app:tasks --group=build` | **BUILD SUCCESSFUL** (~9m); lists `assembleDev/Staging/Trial/Prod`, `bundleProd`. Log: `D:\Temp\rb16_gradle_tasks.txt` |
| Kotlin DSL warning | `Unsupported Kotlin plugin version` — project requests Kotlin **2.2.20** while embedded-kotlin expects **2.0.21** (P2 note; did not fail configure) |
| Prod release without keystore | `flutter build apk --flavor prod --release` → **fails closed** with upload-key message (exit 1). Log: `D:\Temp\rb16_prod_release_attempt.txt` |
| Full Flutter Suite | **Not run** (RB-01 closed) |
| iOS Archive / codesign | **Not run** (Windows) |
| Store upload | **Not run** |

---

## 8. Ready for RB-17?

**Partially.** Android **signing wiring** already exists and is appropriate to proceed into **RB-17 owner/CI keystore setup** in parallel with remaining RB-16 external gaps.  
Do **not** treat RB-16 as closed solely because this review finished.
