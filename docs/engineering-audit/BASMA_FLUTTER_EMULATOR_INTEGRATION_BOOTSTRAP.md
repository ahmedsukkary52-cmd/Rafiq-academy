# BASMA — Flutter ↔ Firebase Emulator Integration Test Bootstrap

**Date:** 2026-11-21 (updated — physical-device integration retry)  
**Branch / HEAD:** `unify/basma-v1` @ `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (dirty WT preserved; **no** git mutations; **no** Production/Cloud)  
**Emulator project:** `demo-rafiq-rules` only  
**Verdict:** **PASS WITH GAPS** — Auth UI journeys **executed and passed** on SM-A037F vs Emulator; parent/student journeys **not completed** (ADB drops / slow Wi‑Fi install)

---

## 1. Git state

| Moment | Branch | HEAD | Working tree |
|--------|--------|------|----------------|
| Bootstrap start | `unify/basma-v1` | `8ce64fe` | Dirty (~354 paths) |
| Gradle diagnosis start | `unify/basma-v1` | `8ce64fe` | Dirty preserved |
| End of Gradle diagnosis | `unify/basma-v1` | `8ce64fe` | Dirty (~362 paths) |
| End of physical retry | `unify/basma-v1` | `8ce64fe` | Dirty WT preserved; **no** reset/stash/checkout/commit/push |

---

## 2. Why Integration Bootstrap was missing / broken before

| Prior claim (`INTEGRATION_TEST_PREREQUISITES.md`, Oct 2025) | Current reality |
|--------------------------------------------------------------|-----------------|
| `main.dart` always initializes Production `rafiq-academy` | **Obsolete.** Local flavors use fake `demo-rafiq-rules` options + `use*Emulator` on Auth/Firestore/Functions/Storage |
| No emulator switch allowed | Fail-closed `--dart-define=USE_FIREBASE_EMULATOR=true` already required for `dev`/`staging` |
| No `integration_test` package / folder | **Was true** — now added |
| Trial journey acceptance marked Flutter↔Emulator **BLOCKED** | Bootstrap path exists; Auth UI journeys **passed** on physical SM-A037F; parent/student journeys still gapped by ADB stability |

Root gap was **not** “guards block Emulator.” Guards already protect Production. The gap was missing **test entry points**, **health fail-closed**, **seed fixture for empty sessions**, and a **documented Android + adb reverse** runner. Secondary gap was the **Gradle hang** under sandboxed `GRADLE_USER_HOME`.

---

## 3. Design chosen (and why)

**Reuse production initialization — do not fork a toy app.**

1. `EmulatorHealth.assertReady()` — TCP probe of Auth/Firestore/Functions/Storage on `127.0.0.1`; **throws** if down (never contacts Cloud).  
2. Same `initializeAppFirebase()` + `initDependencies()` + real `MyApp` as release path.  
3. Require `USE_FIREBASE_EMULATOR=true` (already compile-time) + local flavor.  
4. Seed via Admin SDK against Emulator only (`seed-integration-fixture.mjs`), reusing `DEMO_ACCOUNTS` / `writeDemoDataset` — **no Rules weakening**.  
5. App keeps `127.0.0.1` + `automaticHostMapping: false` → Android needs **`adb reverse`**, not `10.0.2.2` (matches existing product decision).  
6. No Production hooks, no AuthZ bypass, no trial/prod flavors in the suite.

---

## 4. Files changed (bootstrap + this diagnosis pass)

| Path | Role |
|------|------|
| `pubspec.yaml` | `integration_test` SDK dep |
| `integration_test/support/emulator_health.dart` | Fail-closed port probes |
| `integration_test/support/demo_accounts.dart` | Emulator-only demo credentials mirror |
| `integration_test/support/integration_bootstrap.dart` | Health → Firebase → DI → `MyApp` |
| `integration_test/auth_role_routing_test.dart` | Journey 1 — auth + role homes + wrong password |
| `integration_test/student_data_load_test.dart` | Journey 2 — student profile from Firestore |
| `integration_test/parent_payments_load_test.dart` | Journey 3 — parent payments surface |
| `functions/scripts/seed-integration-fixture.mjs` | Fresh-session Admin seed for `demo-rafiq-rules` |
| `functions/package.json` | `seed:integration` script |
| `tool/run_flutter_emulator_integration.ps1` | Port checks + clear sandboxed `GRADLE_USER_HOME` + prefer physical device + `adb reverse` + `flutter test` |
| `docs/production/INTEGRATION_TEST_PREREQUISITES.md` | Updated (old Production-init claim removed) |
| `lib/features/auth/.../login_page.dart` | Stable `Key`s for identifier/password/submit (not a security bypass) |
| `test/core/firebase/integration_bootstrap_contract_test.dart` | Host-side contracts |
| `lib/features/parent/.../parent_subscriptions_page.dart` | **Compile fix:** `AppTextStyles.bodySmall` → `labelSmall` (blocked `assembleDevDebug` after hang cleared) |
| `integration_test/support/integration_bootstrap.dart` | Sign-out before journeys; bounded `pumpAndSettle`; wait for login keys (physical Auth persistence) |
| `integration_test/parent_payments_load_test.dart` | Bounded `pumpAndSettle` timeouts |

**Not changed:** Firebase project IDs, signing configs, applicationIds, Production guards, Gradle/AGP/Kotlin versions, caches (no wipe). No intentional `adb uninstall` / `pm clear`.

---

## 5. How to run Emulator + tests

```powershell
# A — Emulator Suite
npx firebase emulators:start --project demo-rafiq-rules --only auth,firestore,functions,storage
# or: npm --prefix functions run serve

# B — Seed (empty session only)
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
$env:FIREBASE_STORAGE_EMULATOR_HOST="127.0.0.1:9199"
$env:FIREBASE_FUNCTIONS_EMULATOR_HOST="127.0.0.1:5001"
$env:GCLOUD_PROJECT="demo-rafiq-rules"
node functions/scripts/seed-integration-fixture.mjs

# C — Device + reverse + Flutter journeys
# Ensure GRADLE_USER_HOME is NOT a Cursor sandbox path.
powershell -File tool/run_flutter_emulator_integration.ps1
# or: powershell -File tool/run_flutter_emulator_integration.ps1 <adb-device-id>
```

Under `firebase emulators:exec` the seed script was also verified (see §7).

---

## 6. Integration journeys implemented

| # | Journey | File | Backend |
|---|---------|------|---------|
| 1 | Student/parent login → role home; wrong password denied | `auth_role_routing_test.dart` | Auth + Firestore Emulators |
| 2 | Student home shows seeded Arabic name | `student_data_load_test.dart` | Firestore profile |
| 3 | Parent opens subscriptions / payments UI | `parent_payments_load_test.dart` | Firestore payments graph from seed |

Chat attachment Flutter→Storage E2E deferred (needs stable on-device runner first).

---

## 7. Actual test results

### Host / Emulator (executed)

| Suite | Result |
|-------|--------|
| `flutter test test/core/firebase/integration_bootstrap_contract_test.dart` + `emulator_fail_closed_test.dart` | **+35 All tests passed** |
| `flutter analyze` on `integration_test` + login page + `app_firebase.dart` | **No issues found** |
| Seed fixture / Auth Emulator REST `student01@rafiq.demo` | **AUTH_OK** `uid=demo-student-01` (re-verified this pass) |
| Wrong password against Auth Emulator | **denied** |
| Firestore Emulator profile read with Auth token | **role=student**, Arabic name present |
| Parent Auth Emulator sign-in | **PARENT_AUTH_OK** |
| Emulator ports 9099/8080/5001/9199 | **Open** throughout diagnosis |

### On-device Flutter UI journeys

| Attempt | Outcome |
|---------|---------|
| Prior: `flutter test integration_test … -d emulator-5554` | Hung >30 min on `assembleDevDebug` (see §13) |
| This pass: physical SM-A037F Wi-Fi ADB | Seen earlier as `adb-R9PT60KGKTV-26vnYl._adb-tls-connect._tcp`; **lost before** `adb reverse` / `flutter test` |
| This pass: `integration_test` on physical phone | **NOT RUN** — no Android device in `adb devices` / `flutter devices` |

**Therefore:** Flutter **UI** journeys remain **implemented but not claimed executed**. Backend seed + Auth/Firestore Emulator identity for the same demo accounts **were** executed.

---

## 8. Authorization / negative cases checked

| Case | Layer | Result |
|------|-------|--------|
| Wrong password | Auth Emulator REST | Denied |
| Missing Emulator ports | `EmulatorHealth.assertReady` | Throws (contract test) |
| Local flavor without `USE_FIREBASE_EMULATOR` | `assertFirebaseRouting` | Throws (existing + contract) |
| Seed against non-empty Auth | Fixture script | Refuses (exit 64) |
| Non-`demo-rafiq-rules` project env | Fixture script | Refuses |
| Production guards / Rules | Unchanged | Not weakened |

UI-level AuthZ denials (cross-role screens) remain for a completed on-device run.

---

## 9. Mocks vs real Emulator backend

| Kind | What |
|------|------|
| **Real Emulator** | Seed Admin writes; Auth sign-in; Firestore profile read; fail-closed routing source contracts |
| **Not mocks of Firebase** | Integration journeys call real `initializeAppFirebase` / DI / `MyApp` |
| **Test doubles only** | Host contract tests do not talk to Firebase SDKs on-device; SharedPreferences mock for onboarding skip |

---

## 10. Limitations / what did not run

- Full `integration_test` on Android (physical or AVD) this pass: **blocked by missing ADB device** after Gradle was fixed.  
- Chat / attachment Flutter→Storage journey: not started.  
- Physical phone: was connected via TLS Wi-Fi ADB earlier in the session; **disconnected** before reverse/tests; no `adb uninstall` / `pm clear` performed.

---

## 11. Android Emulator vs physical phone

| Need | Answer |
|------|--------|
| Bootstrap design | Either works if `adb reverse` is applied (app uses `127.0.0.1`) |
| This diagnosis brief | **Physical phone required** — SM-A037F was verified then lost |
| AVD substitute | **Not used** this pass (would not satisfy physical-device objective) |

---

## 12. Next step recommendation (before claiming E2E / G1)

1. Re-establish ADB to SM-A037F (USB or Wireless debugging + pairing so `adb devices` shows the phone).  
2. Re-run signing/package check (already matched once — see §14).  
3. `adb reverse` 9099/8080/5001/9199 → run `tool/run_flutter_emulator_integration.ps1 <device-id>`.  
4. On green UI runs, add chat send + optional attachment Storage journey.  
5. Do **not** treat APK install alone as E2E success.

---

## 13. Gradle diagnosis (proven root cause) — 2026-11-21

### Toolchain (unchanged versions)

| Item | Value |
|------|--------|
| Java | OpenJDK **21.0.9** (`JAVA_HOME` = Android Studio JBR) |
| Gradle wrapper | **8.14** |
| AGP | **8.11.1** |
| Kotlin plugin | **2.2.20** |
| Daemon after fix | PID 20280 **IDLE** on Gradle 8.14 |

### What the hang was **not**

- Not an infinite Gradle configuration loop with a healthy cache.  
- Not fixed by wiping Gradle/Flutter caches (caches were **not** cleared).  
- Not fixed by changing AGP/Kotlin/Gradle versions.  
- Raw `:app:assembleDevDebug` **without** `-Pdart-defines` / `USE_FIREBASE_EMULATOR` **fails fast** (expected flavor guard) — that is not the hang.

### Proven cause

Agent/Cursor sandbox sometimes sets:

`GRADLE_USER_HOME=D:\Temp\cursor-sandbox-cache\...` (or similar under `Temp\cursor`)

That redirects dependency/wrapper resolution into a stalling sandbox cache. Clearing that env var and using Studio JBR for `JAVA_HOME` allowed a normal build.

### Secondary compile blocker (after hang cleared)

`AppTextStyles.bodySmall` missing → compile error in `parent_subscriptions_page.dart`. Minimal fix: use existing `AppTextStyles.labelSmall`.

### Build result

```text
flutter build apk --flavor dev --debug --dart-define=USE_FIREBASE_EMULATOR=true
Running Gradle task 'assembleDevDebug'...  182.6s
√ Built build\app\outputs\flutter-apk\app-dev-debug.apk
Exit=0
```

APK path: `build\app\outputs\flutter-apk\app-dev-debug.apk` (~187 MB, written 2026-11-21 07:01).

### Runner hardening

`tool/run_flutter_emulator_integration.ps1` now:

- Clears sandboxed `GRADLE_USER_HOME` when detected  
- Sets Studio JBR `JAVA_HOME` if unset  
- Probes Emulator ports and **refuses** to proceed if closed (no Production fallback)  
- Prefers a physical Android device over `emulator-*` when both exist  

---

## 14. Physical device verification & protection — 2026-11-21

### While connected (earlier same session)

| Check | Result |
|-------|--------|
| Serial | `adb-R9PT60KGKTV-26vnYl._adb-tls-connect._tcp` |
| Model | Samsung **SM-A037F** (`a03s`) |
| Android | **13** / API **33** |
| Package | `com.example.rafiq_academy` installed |
| Signing | Installed APK Signer SHA-1 `1fc14cf5…e425` **matches** local `~/.android/debug.keystore` SHA1 `1F:C1:4C:F5:…:E4:25` |
| Install policy | In-place debug update **safe** for signature; **no** `adb uninstall` / `pm clear` used |

### At reverse/test time (blocker)

| Check | Result |
|-------|--------|
| `adb devices -l` | **Empty** |
| `adb mdns services` | **Empty** (no wireless debugging advert) |
| `flutter devices` | Windows / Chrome / Edge only — **no Android** |
| Prior neighbor `192.168.1.5` | Became **Unreachable**; TCP 5555 closed |
| USB ADB | Not present as an authorized debug device |
| Actions taken | `adb kill-server` / `start-server` only; **no** phone settings reset; **no** uninstall; **no** data wipe |

**Stop reason:** Cannot prove Emulator reachability from the phone or run instrumented tests without a live ADB target. Substituting an AVD was **not** done for this physical-device brief.

---

## 15. Emulator connectivity plan (ready; not applied to phone)

Intended path once the phone reappears:

1. Confirm Emulator ports open on host (`demo-rafiq-rules`).  
2. `adb -s <device> reverse tcp:9099|8080|5001|9199 tcp:…` (app uses `127.0.0.1`, not host LAN IP).  
3. Device-side probe to `127.0.0.1:<port>` via reverse.  
4. Fail closed if ports unreachable — **never** fall back to Production.  
5. Run `tool/run_flutter_emulator_integration.ps1 <device-id>`.

Host Emulator + seed remained healthy while the phone was offline.

---

## 16. Report checklist (physical retry)

| # | Question | Answer |
|---|----------|--------|
| 1 | ADB attempts | Recheck found SM-A037F USB+Wi‑Fi; reverse applied; later USB/Wi‑Fi drops |
| 2 | Phone identity | SM-A037F, Android 13 / API 33, serial `R9PT60KGKTV` / wireless TLS id |
| 3 | APK/build | `app-dev-debug.apk` rebuilt during runs; signing matched debug keystore |
| 4 | Emulator connectivity | Ports open; `adb reverse` OK; device `nc` to 9099/8080/5001/9199 exit 0; seed Auth OK |
| 5 | Journeys executed | Auth role routing **3/3 PASS** on physical (Wi‑Fi run). Parent payments + student data **not completed** |
| 6 | Passed/failed/skipped | Passed: student login, parent login, wrong password. Failed/incomplete: parent payments, student data (ADB). USB re-run: **0 executed** (install/device lost) |
| 7 | Backend persistence | Seed Auth REST `demo-student-01` OK; Auth UI denials/logins against Auth Emulator proven by passing widgets |
| 8 | Remaining blockers | Unstable ADB (USB disconnect + slow Wi‑Fi install); Flutter may attempt `uninstall` after failed install when device drops |

---

## 17. Physical retry log — 2026-11-21 ~07:18–08:10 +02

### ADB connection attempts

| Attempt | Action | Outcome |
|---------|--------|---------|
| 1 | `adb devices -l` (recheck) | **PASS** — USB `R9PT60KGKTV` + wireless `adb-R9PT60KGKTV-26vnYl…` both `device` |
| 2 | mdns | Advertised `192.168.1.5:41917` `_adb-tls-connect` |
| 3 | Signing compare installed vs built vs debug keystore | **MATCH** SHA-1 `1fc14cf5…e425` |
| 4 | `adb reverse` + device `nc` to Emulator ports | **PASS** (USB then wireless) |
| 5 | Wi‑Fi suite (`physical-integration-test-r2.log`) | Auth **+3**; hung on next APK install (~513s); **stopped** |
| 6 | USB suite (`physical-integration-test-usb.log`) | Streamed install failed; then `device not found`; suite **+0 -3** load failures |
| 7 | Post-USB `adb devices` | **Empty** — phone gone again |

### Integration results (actual)

| Journey | Result | Evidence |
|---------|--------|----------|
| student demo login → StudentHomePage | **PASS** | Wi‑Fi run `+1` |
| parent demo login → ParentHomePage | **PASS** | Wi‑Fi run `+2` |
| wrong password stays on login | **PASS** | Wi‑Fi run `+3` |
| parent subscriptions/payments UI | **NOT COMPLETED** | Wi‑Fi hung on install; USB never started app |
| student home seeded name | **NOT COMPLETED** | Same |

Logs: `build/physical-integration-test-r2.log`, `build/physical-integration-test-usb.log`.

### Safety notes

- No Production / Cloud mutations; Emulator `demo-rafiq-rules` only.  
- No intentional `adb uninstall` / `pm clear` from our scripts.  
- Flutter tooling **attempted** `adb uninstall com.example.rafiq_academy` after failed USB install when the device was already gone — command **failed** (`device not found`); package state on phone unverified after disconnect.  
- Bootstrap fix: sign out Emulator Auth + bounded settle so login keys appear (first physical run had 0× `login-identifier`).

### Verdict rationale

**PASS WITH GAPS** — not full PASS (parent/student journeys unfinished; ADB unstable). Not **BLOCKED** (Auth UI E2E against Emulator on the real phone is proven).

**Owner action if reconnecting:** keep USB attached and screen awake; re-run `powershell -File tool/run_flutter_emulator_integration.ps1 R9PT60KGKTV` for the remaining files.

---

## Findings classification

| Bucket | Items |
|--------|-------|
| Confirmed → fixed | Missing `integration_test`; Gradle sandbox hang; `bodySmall`; physical bootstrap settle/sign-out |
| Proven on device | Auth role routing journeys vs Auth+Firestore Emulators on SM-A037F |
| Gaps | Parent payments + student data UI journeys; chat/attachment E2E |
| Blockers | Unstable physical ADB (Wi‑Fi install latency / USB drops) |

**Ahmed note:** Physical retry executed real Auth UI tests on SM-A037F with Emulator + `adb reverse`. Did **not** claim full suite PASS from APK build alone; remaining journeys need a stable USB session.
