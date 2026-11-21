# BASMA G1 — Device & Flutter DevTools Diagnostics

**Date:** 2026-11-18  
**Phase:** G1 (device / DevTools lab)  
**Branch:** `unify/basma-v1`  
**Host:** Windows 11 (25H2) · Flutter 3.44.9 · Dart 3.12.2 · DevTools 2.57.0  
**Policy:** Evidence-first; no install/uninstall, no clear-data, no APK resign, no Firebase writes, no source/config edits, no Git mutations.

**Verdict (initial G1 pass, earlier 2026-11-18):** **BLOCKED** for physical device + DevTools attach. **PARTIAL** for local static/structure evidence.

**Verdict (reconnect + safe resume, 2026-11-18 ~23:22–23:24 +02):** ADB wireless **PASS** (stable). Installed-app cold start via `am start` **PASS**. Flutter DevTools / Observatory attach **BLOCKED** (no VM service). Performance metrics **NOT TESTED**. RB-18 and RB-D4-01..03 remain **OPEN**.

**Verdict (physical evidence pass, 2026-11-18 ~23:55–23:59 +02):** ADB still **PASS**. Foreground screenshot of authenticated Admin shell **PASS** (read-only). In-app branded loading/splash visuals **PASS**; launcher icon in app drawer **PASS**; Android 12+ system splash frame **PARTIAL**/incomplete. Bounded Logcat found actionable Firestore **FAILED_PRECONDITION** (complaints index) — aligns with known Cloud gap. Safe bottom-nav Home↔Settings **PASS**. DevTools still **BLOCKED**. RB-18 / RB-D4-01..03 remain **OPEN**.

---

## Evidence classes used in this report

| Tag | Meaning |
|-----|---------|
| **PASS** | Proven with named command/output this pass |
| **PARTIAL** | Some evidence exists; claim incomplete |
| **BLOCKED** | Could not run due to environment |
| **NOT TESTED** | Intentionally not attempted (policy or missing prerequisite) |

Distinguish carefully:

- **Device measurement** — from a connected physical Android session (none this pass).
- **Debug-build observation** — would not prove Release performance (N/A; no session).
- **Code/static inference** — file presence, XML wiring, unit/widget structure tests only.

---

## 1. Git state before / after

### Before diagnostics

| Item | Value | Check |
|------|--------|-------|
| Branch | `unify/basma-v1` | **PASS** |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` | **PASS** (matches expected docs checkpoint) |
| Staged | `0` | **PASS** |
| Tracked modified | `196` | Recorded |
| Untracked | `68` | Recorded |
| Porcelain lines | `264` | Recorded |

No discrepancy vs expected HEAD/branch. Existing dirty tree preserved; not repaired.

### After diagnostics (expected)

| Item | Expectation |
|------|-------------|
| HEAD | Unchanged `8ce64fe…` |
| Staged | Still `0` |
| Source / tests / config | Untouched |
| New artifact | This file only: `docs/engineering-audit/BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` (untracked) |

No stage / commit / push performed.

---

## 2. Device discovery

| Check | Result | Class |
|-------|--------|-------|
| `adb devices -l` (1st) | Empty list after daemon auto-start on `tcp:5037` | **PASS** (empty proven) |
| `adb devices -l` (2nd, ~2s later) | Still empty | **PASS** (stable absence) |
| `flutter devices` / `--device-timeout 5` | Windows + Chrome + Edge only — **no Android** | **PASS** |
| `adb get-state` / `getprop` | `no devices/emulators found` | **PASS** |
| Package probe `com.example.rafiq_academy` / `com.basmaacademy.app` | Impossible — no device | **BLOCKED** |
| `adb mdns services` | Empty discovered services | **PASS** (no wireless ADB advert) |
| Prior RB-18 sighting (SM-A037F wireless) | Historical only (`BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md`) — **not present this pass** | Historical |

**Device found this pass:** none.

Do **not** assume the previously seen Samsung SM-A037F is still available.

---

## 3. ADB stability & Flutter devices

| Topic | Finding | Class |
|-------|---------|-------|
| ADB daemon | Started successfully; remained up for recheck | **PASS** |
| USB device | None attached | **BLOCKED** (device) |
| Wireless ADB | No mdns services; no prior wireless target | **BLOCKED** |
| Authorization / offline | N/A — no candidate device appeared | **NOT TESTED** |
| Flutter Android toolchain | SDK present; `flutter doctor`: Android licenses **not fully accepted** (warning) | **PARTIAL** (host tooling) |
| Emulators | Doctor lists emulator binary; none started this pass | **NOT TESTED** |

**Decision:** Stopped device reconnect loops after two empty probes. No long wireless pairing attempt.

---

## 4. Flutter DevTools session

| Question | Answer | Class |
|----------|--------|-------|
| Stable Flutter debug / Observatory / VM service on device? | **No** | **BLOCKED** |
| Listening ports typical for DevTools (8181/9100/…) | None observed | **PASS** (absence) |
| `dart` / `flutter` debug isolate for BASMA | No BASMA debug process found | **PASS** (absence) |
| DevTools Performance / Inspector / Memory / Network | **Not opened** — no attach target | **BLOCKED** |
| Forced `flutter run` / reinstall to create a session? | **Not done** (policy) | **NOT TESTED** by design |

`devtools_options.yaml` exists (extension toggles only). It is **not** a prior performance capture.

**Explicit non-claims:** No frame timings, jank %, rebuild counts, heap graphs, or network traces from this pass.

---

## 5. Actual measurements & conditions

| Measurement | Conditions | Result | Class |
|-------------|------------|--------|-------|
| Physical FPS / jank | Requires device + profile/debug attach | — | **BLOCKED** |
| Widget rebuilds | Requires Inspector session | — | **BLOCKED** |
| CPU / Memory | Requires DevTools or `adb shell dumpsys` on live app | — | **BLOCKED** |
| Flutter logs / logcat app stream | Requires device | — | **BLOCKED** |
| D4 nav structure + overflow widget tests | Host `flutter test` (no device) | **All passed** (see §7) | **PASS** (local only) |
| D4 lazy-list structure tests | Host `flutter test` reading WT sources | **4/4 passed** | **PASS** (local only) |

**Debug ≠ Release:** Even if Debug DevTools were available, numbers would **not** close RB-D4-03 profile/jank baselines.

---

## 6. Errors / issues discovered

| Issue | Severity | Notes |
|-------|----------|-------|
| No Android device for G1 lab | Blocks RB-18 / D4 visual | Environment, not app defect |
| Android licenses incomplete (`flutter doctor`) | Host hygiene | May affect some SDK operations; not exercised further |
| Visual Studio missing | Windows desktop only | Irrelevant to Android G1 |
| iOS LaunchImage placeholders still 68 bytes each | Known static gap | Visual QA still needed on device/mac (unchanged) |

No new runtime crash evidence — runtime was not reachable.

---

## 7. Local alternative checks (not device proof)

### 7.1 Flutter / Android host

| Item | Result | Class |
|------|--------|-------|
| Flutter 3.44.9 stable + DevTools 2.57.0 | Confirmed | **PASS** |
| Android SDK 37 / build-tools present | Confirmed via doctor | **PASS** |
| Connected Android device | None | **BLOCKED** |

### 7.2 Icon & splash (static file inventory)

| Area | Finding | Class |
|------|---------|-------|
| Adaptive icon XML | `mipmap-anydpi-v26/ic_launcher.xml` → background color + `ic_launcher_foreground` | **PASS** (files) |
| Density launcher PNGs | mdpi→xxxhdpi `ic_launcher` + foreground present (non-trivial sizes) | **PASS** (files) |
| Pre-12 splash | `drawable/launch_background.xml` → `basma_launch_background` + `splash_icon` | **PASS** (files) |
| Android 12+ splash | `values-v31` + `values-night-v31` set `windowSplashScreenBackground` + `windowSplashScreenAnimatedIcon` | **PASS** (files) |
| Brand colors | `basma_launch_background` `#F5F6FA`; `ic_launcher_background` `#1D5FA6`; `rafiq_launch_background` alias | **PASS** (files) |
| iOS LaunchImage | Three PNGs still **68 bytes** each (placeholders) | **PARTIAL** (presence) / visual **NOT TESTED** |
| Launcher mask matrix on OEM | — | **NOT TESTED** (needs device screenshots) |
| Splash double-frame on Android 12+ | — | **NOT TESTED** (needs device) |

### 7.3 Local tests re-run this pass

```text
flutter test test/shared/app_floating_bottom_nav_d4_test.dart
→ All tests passed (RepaintBoundary + narrow 320 / textScale 1.3 overflow guard)

flutter test test/shared/d4_lazy_list_structure_test.dart
→ All tests passed! (4) — directory / supervisor payments / registration / nav blur isolation
```

These prove **structure / overflow guards on the host**, not physical rendering or jank.

### 7.4 Prior reports reused

| Doc | Use |
|-----|-----|
| `BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md` | Historical wireless SM-A037F sighting; still no DevTools then |
| `BASMA_RELEASE_BLOCKERS.md` | Authoritative OPEN statuses for RB-18 / D4 |

No prior DevTools timeline/export artifacts found in-repo.

---

## 8. What could not be done (and why)

| Intended G1 activity | Why blocked |
|----------------------|-------------|
| Stable ADB device identity / API level | No USB/wireless device |
| Confirm installed package / version on phone | No device |
| Attach DevTools to running Flutter isolate | No debug session; policy forbids forced reinstall/`flutter run` |
| Performance timeline / jank / rebuilds / memory | Depends on DevTools attach |
| Role smoke on physical UI | No device; also no Firebase write/login this pass |
| Release/profile jank baselines | Needs profile/release build + device lab |

---

## 9. Must re-test later (device / Release)

| Item | Required environment |
|------|----------------------|
| RB-18 physical install + multi-role smoke | Stable USB or reliable wireless ADB; owner lab time |
| RB-D4-01 icon mask matrix | Device screenshots (circle/squircle/OEM) |
| RB-D4-02 splash / Android 12+ visual | Cold start visual confirm on API 31+ |
| RB-D4-03 profile jank | **Profile or Release** build + DevTools/performance traces on low-end device |
| Logcat during real journeys | Device + running app (prefer without clearing data) |
| Optional: accept Android licenses | Host `flutter doctor --android-licenses` when owner ready |

G0 (Cloud/owner) and other engineering tracks are **not** blocked waiting for this phone.

---

## 10. Blocker status impact (evidence-only)

| ID | Prior | After initial G1 | After reconnect addendum (§12) | Rationale |
|----|-------|------------------|--------------------------------|-----------|
| **RB-18** | OPEN | OPEN | Remains **OPEN** (§13: Admin Home↔Settings only) | No multi-role smoke matrix |
| **RB-D4-01** | OPEN | OPEN | Remains **OPEN** (§13: drawer icon seen) | No full mask matrix |
| **RB-D4-02** | OPEN | OPEN | Remains **OPEN** (§13: in-app loading PASS) | OS splash frame not isolated |
| **RB-D4-03** | OPEN | OPEN | Remains **OPEN** | No DevTools/profile traces |
| RB-01 | CLOSED (historical) | Unchanged | Unchanged | Not re-litigated here |
| Cloud / signing blockers | OPEN | Unchanged | Unchanged | Out of G1 scope |

**Do not close** RB-18 or D4 device-lab items based on ADB presence, a single `am start`, desktop `flutter devices` entries, or host widget/structure tests alone.

---

## 11. Summary scorecard

| Area | Initial pass | After §12 reconnect |
|------|--------------|---------------------|
| Git baseline intact | **PASS** | **PASS** (`8ce64fe`, staged 0) |
| ADB | **PASS** (stable empty) | **PASS** (stable wireless SM-A037F) |
| Physical Android device | **BLOCKED** | **PASS** (connected) |
| Open installed app | **BLOCKED** | **PASS** (`am start` → pid 12842) |
| Flutter DevTools attach | **BLOCKED** | **BLOCKED** (no Observatory) |
| Performance / memory / rebuild metrics | **NOT TESTED** | **NOT TESTED** |
| Icon/splash static wiring | **PASS** (files) | Unchanged |
| Icon/splash on-device visual | **NOT TESTED** | See §13 (**PARTIAL**/PASS pieces; blockers still OPEN) |
| D4 local structure/overflow tests | **PASS** (host) | Unchanged |
| RB-18 / D4 closure | **NOT** claimed | Still **OPEN** (see §13) |

**Next when lab available:** Connect stable device → confirm package without reinstall if possible → only then consider debug attach or a separately approved profile build for RB-D4-03. Until then, continue G0 / local EQ work independently of phone availability.

---

## 12. Addendum — wireless reconnect & safe resume (2026-11-18 ~23:22–23:24 +02)

**Git at resume start:** `unify/basma-v1` @ `8ce64fe97440c33acefaf1e140022ddbe0075ab5` · staged `0` · tracked mod `196` · untracked `69`. No source/tests/config edits; no stage/commit/push. ADB daemon **not** restarted; network settings **not** changed.

### 12.1 ADB / Flutter connectivity (spaced probes)

| Probe | Time (+02) | `adb devices -l` | Notes |
|-------|------------|------------------|-------|
| 1 | 23:22:33 | `SM_A037F` · `device` · wireless `adb-R9PT60KGKTV-26vnYl._adb-tls-connect._tcp` | Flutter lists `SM A037F (wireless)` · Android 13 API 33 · android-arm64 |
| 2 | 23:22:56 | Same serial · still `device` | `getprop`: model `SM-A037F`, release `13`, sdk `33`, abi `arm64-v8a`; `echo ok_from_device` |
| 3 | 23:23:01 | Same · still `device` | Flutter still lists wireless device |
| 4 | 23:24:10 (post-launch) | Same · still `device` | `echo still_ok` |

**mdns:** `adb-R9PT60KGKTV-26vnYl` → `_adb-tls-connect._tcp` @ `192.168.1.5:38169` (matches expected endpoint family).

| Claim | Result |
|-------|--------|
| ADB connection success | **PASS** |
| Status `device` (not offline/unauthorized) | **PASS** |
| Stability across ≥3 spaced checks | **PASS** |

### 12.2 Installed package (no reinstall)

| Item | Evidence | Result |
|------|----------|--------|
| Package present | `com.example.rafiq_academy` only (`com.basmaacademy.app` absent) | **PASS** |
| Version | `versionName=1.0.0` · `versionCode=2` · `minSdk=24` · `targetSdk=36` | **PASS** |
| Debuggable | `DEBUGGABLE` in pkg flags | **PASS** (identity) |
| userId | `10918` before and after launch (no clear-data) | **PASS** |
| Uninstall / reinstall / resign | Not performed | Policy held |

### 12.3 App open (existing APK)

| Step | Evidence | Result |
|------|----------|--------|
| Launcher activity | `com.example.rafiq_academy/.MainActivity` | **PASS** |
| Start | `adb shell am start -n …/.MainActivity` → `Starting: Intent { cmp=… }` | **PASS** |
| Process | pid `12842` running; cmdline package name | **PASS** |
| Foreground | `topResumedActivity` / `mFocusedApp` = `.MainActivity` | **PASS** |
| `flutter run` | **Not** used | Policy held |
| Firebase login / writes | **Not** performed | Policy held |

**App open success:** **PASS** (process + focused activity). This is **not** a multi-role smoke matrix and does **not** close RB-18.

### 12.4 DevTools / Observatory

| Check | Result |
|-------|--------|
| Host listen ports 8181/9100/… | None for Flutter |
| `adb forward --list` | Empty |
| logcat banners `Observatory listening` / `Dart VM service` / `DevTools` | **None** found |
| Attach DevTools Performance/Inspector/Memory | **Not possible** without VM service |

**DevTools session success:** **BLOCKED** — installed debug APK launched via `am start` did not expose a Flutter VM service. Per policy, **no** `flutter run` was started solely to force a session.

### 12.5 Performance measurements

| Metric | Result |
|--------|--------|
| Frame timeline / jank % | **NOT TESTED** (no DevTools) |
| Widget rebuilds | **NOT TESTED** |
| CPU / Memory graphs | **NOT TESTED** |
| Network panel | **NOT TESTED** |

Logcat while focused: repeated OEM `IMGMapper` / HDR metadata noise (`SMPTE2086` / `CTA861_3`). **Not** treated as Flutter FATAL; **not** a performance claim.

**Explicit:** Debug cold-start without Observatory ≠ Release/profile evidence for RB-D4-03.

### 12.6 Scorecard delta (reconnect only)

| Area | Initial pass | After reconnect |
|------|--------------|-----------------|
| Physical ADB device | BLOCKED (absent) | **PASS** (stable wireless) |
| Open installed app | BLOCKED | **PASS** (`am start`) |
| DevTools attach | BLOCKED | **BLOCKED** (no VM service) |
| Performance metrics | NOT TESTED | **NOT TESTED** |
| RB-18 | OPEN | Remains **OPEN** (no smoke matrix / role journeys) |
| RB-D4-01..03 | OPEN | Remain **OPEN** (no screenshot matrix / splash visual proof / profile traces) |

### 12.7 Still required for closure

- RB-18: structured physical smoke (roles/journeys) with evidence notes — optional owner-approved debug attach if DevTools needed.
- RB-D4-01/02: on-device icon/splash visuals (screenshots).
- RB-D4-03: **profile or release** build + DevTools/timeline on device (separate approval if new install required).
- Do **not** use this addendum alone to mark device-lab blockers CLOSED.

---

## 13. Addendum — physical screenshots, Logcat, icon/splash, safe nav (2026-11-18 ~23:55–23:59 +02)

### 13.1 Preconditions re-verified (do not assume §12 still current)

| Check | Result | Class |
|-------|--------|-------|
| Branch / HEAD | `unify/basma-v1` @ `8ce64fe97440c33acefaf1e140022ddbe0075ab5` | **PASS** |
| Git counts at start | staged `0` · tracked mod `196` · untracked `69` | **PASS** |
| ADB | Same wireless serial · status `device` · SM-A037F · API 33 | **PASS** |
| Package | `com.example.rafiq_academy` · `1.0.0` / `versionCode=2` · `DEBUGGABLE` · `userId=10918` | **PASS** |
| Process at start | pid `12842` · `MainActivity` resumed (session from §12 still alive) | **PASS** |
| Reinstall / clear-data / Firebase writes / `flutter run` | Not performed | Policy held |

Screenshots and Logcat dumps were saved **outside the repo** under:

`D:\Temp\basma_g1_diagnostics\`

**Do not commit** these PNGs/logs (may include demo account UI and unrelated launcher widgets).

### 13.2 Display metrics

| Metric | Value | Class |
|--------|-------|-------|
| Resolution | `720 x 1600` | **PASS** |
| Density | `300` dpi (~1.875) | **PASS** |
| Refresh | 60 Hz | **PASS** |
| Orientation | `rotation 0` (portrait) | **PASS** |
| System night mode | `cmd uimode night` → **yes** | **PASS** (system) |
| App UI theme observed | Light/teal Admin chrome despite system night=yes | **PARTIAL** (app may not follow system dark; product D5) |

### 13.3 Current app screen (screenshot)

| Item | Finding | Class |
|------|---------|-------|
| Capture | `adb shell screencap` → `basma_g1_foreground_20261118_235552.png` | **PASS** |
| Auth state | Already inside **Admin** shell (no login performed this pass) | **PASS** (observation) |
| First content | Admin Home / dashboard RTL; bottom nav 5 tabs | **PASS** |
| Partial data failure UI | Banner: Arabic “unable to load some data / pull to retry”; financial tiles show `—` while student/supervisor/teacher counts render | **PASS** (UI observed) |
| Sensitive data handling | Demo-style academy manager title on screen; Settings later showed a **trial demo** email — treat as lab identity, **not** published into Git | Redacted in narrative |

No real-account sign-in this pass. No pull-to-retry executed (would re-query Cloud; avoided as unnecessary for evidence).

### 13.4 Startup / bounded Logcat

| Source | Notes |
|--------|-------|
| Buffer dump | `basma_g1_logcat_recent.txt` (~110 KB, last ~800 lines) — mostly OEM / unrelated apps |
| App pid dump (old pid 12842) | Dominated by `IMGMapper` HDR metadata noise — **informational / OEM**, not Flutter FATAL |
| Cold start (new pid `16338`) | `basma_g1_coldstart_log_20261118_235755.txt` |

**Actionable (app-related):**

| Finding | Class |
|---------|-------|
| Firestore listen on `complaints` (`status in [open,in_progress]` + `orderBy createdAt`) → **`FAILED_PRECONDITION` — query requires an index** on project `rafiq-academy` | **PASS** (error proven) — maps to known **BASMA-101** / Cloud indexes gap |
| Firestore gRPC channel init present (ConnectivityManager stack through `GrpcCallProvider`) | **PASS** (Firebase client initializing) |
| `OnBackInvokedCallback` not enabled in manifest (warning) | Low / informational |
| No `FATAL EXCEPTION` / Flutter red-screen / missing AssetManifest in captured windows | **PARTIAL** (absence in sampled windows only) |

**Non-actionable / excluded:** WifiVendorHal, WhatsApp `msys`, MediaProvider URI revoke, VoLTE subscribe timeouts — other processes.

Console index deep-links from Logcat are **redacted** in this report (`[FIREBASE_CONSOLE_INDEX_LINK_REDACTED]`).

### 13.5 Icon & splash on device

| Observation | Evidence | Class |
|-------------|----------|-------|
| Launcher icon (app drawer) | `basma_g1_drawer_*.png` — BASMA blue/teal fingerprint-style icon; label **«بصمة (تجربة الأكاديمية)»** | **PASS** (one OEM drawer view) |
| Icon on primary home page | Not present on the captured home page (other widgets only) | **PARTIAL** — icon lives in drawer / another page |
| Circle/squircle/OEM mask matrix | Single drawer capture only | **NOT TESTED** fully → RB-D4-01 stays **OPEN** |
| In-app branded loading / splash | Cold `force-stop` + `am start` (data preserved); early/mid/after frames show white screen + BASMA logo tile + «بصمة» + academy tagline + teal spinner | **PASS** (branded Flutter loading UI) |
| Android 12+ **system** splash (`windowSplashScreen*`) first frame | Not isolated from Flutter loading UI in captures (wireless timing / `am start -W` timed out ~10s) | **PARTIAL** → RB-D4-02 stays **OPEN** |
| Static XML/PNG audit (§7) | Still valid as file presence; this section adds **on-device** visual evidence | Distinguished |

`am force-stop` used only to recreate a cold start; **no** clear-storage / uninstall.

### 13.6 Navigation smoke (read-only, authenticated session)

Session was already authenticated as Admin (lab/demo). Only bottom-nav taps:

| Action | Result | Class |
|--------|--------|-------|
| Tap Settings tab | Settings page rendered (account card, security row, academy settings list, logout affordance visible) — **no** password change / import / payment edit / logout tapped | **PASS** |
| Tap Home tab | Returned to Admin dashboard with same partial-load banner | **PASS** |
| Students / Management / Financial deep flows | **NOT TESTED** (risk of write or heavy Cloud queries) | **NOT TESTED** |
| Messages, payments submit, attendance, meetings, admin mutations | Skipped | Policy |

### 13.7 Flutter attach / DevTools

| Check | Result | Class |
|-------|--------|-------|
| Observatory / VM service banners | None | **BLOCKED** |
| `flutter attach` (12s job timeout) | **TIMEOUT_NO_VM_SERVICE** | **BLOCKED** |
| DevTools Performance / Memory / Rebuilds | Not opened | **BLOCKED** |
| Logcat ≠ DevTools | Explicit — Logcat access is **not** a DevTools session | Noted |

### 13.8 Blocker statuses after §13

| ID | Status | Why not closed |
|----|--------|----------------|
| **RB-18** | **OPEN** | Admin Home↔Settings only; no multi-role / journey matrix |
| **RB-D4-01** | **OPEN** | One drawer icon sighting ≠ full mask matrix |
| **RB-D4-02** | **OPEN** | In-app loading branded **PASS**; OS splash frame not proven |
| **RB-D4-03** | **OPEN** | No profile/Release DevTools jank traces |

### 13.9 Remains untested / next lab steps

- Multi-role smoke (teacher/parent/student/supervisor) without writes where possible.
- Screenshot matrix for launcher masks; dedicated Android 12+ system splash still capture.
- Owner-approved Profile/Release + DevTools for RB-D4-03.
- Cloud index deploy for complaints (and related finance indexes) under G0 — explains dashboard `—` / partial load (correlate, do not “fix” in this G1 pass).
- Do not treat Debug `am start` performance as Release evidence.

### 13.10 Scorecard (this physical pass only)

| Area | Result |
|------|--------|
| ADB stability re-check | **PASS** |
| Foreground screenshot | **PASS** |
| Startup Logcat actionable finding | **PASS** (index FAILED_PRECONDITION) |
| Launcher icon on-device | **PASS** (drawer) / matrix **NOT TESTED** |
| Branded loading/splash UI | **PASS** |
| OS splash / mask matrix | **PARTIAL** / **NOT TESTED** |
| Read-only Admin nav | **PASS** (Home↔Settings) |
| DevTools / performance | **BLOCKED** / **NOT TESTED** |
| RB-18 / D4 closure | **NOT** claimed — remain **OPEN** |

---

## 14. Investigation — Firestore `FAILED_PRECONDITION` on `complaints` (BASMA-101)

**Date:** 2026-11-19 (investigation; evidence from device pass 2026-11-18 ~23:58 +02)  
**Tracker:** **BASMA-101** (live indexes missing)  
**Scope:** Read-only code + Logcat + `firestore.indexes.json` comparison. **No** index deploy, Rules/Functions change, source edit, or live write.

### 14.1 Original runtime evidence

| Field | Value |
|-------|--------|
| Device | SM-A037F · Android 13 · package `com.example.rafiq_academy` · cold-start pid `16338` |
| Log file | `D:\Temp\basma_g1_diagnostics\basma_g1_coldstart_log_20261118_235755.txt` |
| Timestamp | `11-18 23:58:15.551` |
| Tag | `W Firestore: (25.1.4)` |
| Project | `rafiq-academy` (from console link path) |
| SDK wording | `Listen for Query(...)` failed — client SDK target language; app code path uses **`.get()`** (see §14.2), not an app-level `.snapshots()` listener on this query |

**Query string from Logcat (verbatim shape):**

```text
Query(complaints where statusin[open,in_progress] order by -createdAt, -__name__);limitType=LIMIT_TO_FIRST
```

**Status description (verbatim intent):** `The query requires an index` + Firebase Console `create_composite` link for `collectionGroups/complaints`.

Decoded composite payload (ASCII-readable fields): collection group **`complaints`**, fields **`status`**, **`createdAt`**, **`__name__`** — consistent with `status ASC` + `createdAt DESC` (+ automatic `__name__`).

**Not claimed:** credentials/tokens; console deep-link kept redacted in narrative as `[FIREBASE_CONSOLE_INDEX_LINK_REDACTED]` where republished.

**Differential diagnosis:** Message text is explicitly **missing composite index**, not permission-denied, not failed precondition from Rules, not malformed path. Confidence that this particular `FAILED_PRECONDITION` is **index-related: confirmed**.

### 14.2 Exact failing query and source location

**Call chain (Admin Home / dashboard load):**

1. `AdminDashboardTab` / Admin shell loads via `AdminBloc`  
2. `AdminBloc._onLoadComplaints` → `GetComplaintsUseCase`  
   - `lib/features/admin/presentation/bloc/admin_bloc.dart` (≈238–264)  
3. `GetComplaintsUseCase` → `AdminRepository.getComplaints()`  
   - `lib/features/admin/domain/usecases/get_complaints_usecase.dart`  
4. `AdminRepositoryImpl` → `AdminRemoteDatasource.getComplaints()`  
5. **Firestore construction** — `AdminRemoteDatasourceImpl.getComplaints()`:

```195:206:lib/features/admin/data/datasources/admin_remote_datasource_impl.dart
  Future<List<ComplaintEntity>> getComplaints() async {
    try {
      // Dashboard preview of the open queue; the complaints screen paginates.
      final snap = await firestore
          .collection(FirestoreCollections.complaints)
          .where(
            'status',
            whereIn: [ComplaintStatuses.open, ComplaintStatuses.inProgress],
          )
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
```

| Constraint | Value |
|------------|--------|
| Collection path | `complaints` (`FirestoreCollections.complaints`) — **COLLECTION** scope (not collection-group query API) |
| Filter | `whereIn` on `status` ∈ `{ open, in_progress }` (`ComplaintStatuses.open` / `.inProgress`) |
| Order | `createdAt` **DESC** (SDK also orders by `__name__` DESC as tie-breaker — matches Logcat `-__name__`) |
| Limit | `20` (`LIMIT_TO_FIRST`) |
| Read API | `.get()` (one-shot) |

**Related (not the Logcat `statusin` shape):** `ComplaintsRepository.fetchPage` uses `status` **equality** + `createdAt` DESC — same composite index family, different filter cardinality (`lib/features/complaints/data/complaints_repository.dart`).

UI correlation: Admin Home partial-load / open-queue complaints section depends on this load (`admin_dashboard_tab.dart` + `complaintsStatus`). Financial `—` tiles are **separate** queries (also under BASMA-101 historically) and were **not** proven by this same Logcat line.

### 14.3 Required index (if confirmed)

For this query Firestore requires a composite index equivalent to:

| Property | Required |
|----------|----------|
| Collection group id | `complaints` |
| Query scope | `COLLECTION` |
| Fields | `status` **ASCENDING**, `createdAt` **DESCENDING** (plus implicit `__name__` DESC) |

This matches the Console `create_composite` payload decoded from the device log.

### 14.4 Repository `firestore.indexes.json` comparison

**Present in repo (also on HEAD `8ce64fe` — not only dirty WT):**

```json
{
  "collectionGroup": "complaints",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

| Check | Result |
|-------|--------|
| Collection / group name | **Match** (`complaints`) |
| Scope | **Match** (`COLLECTION`) |
| Field set & directions | **Match** (`status` ASC + `createdAt` DESC) |
| `whereIn` vs equality | Same composite supports both for this field pair |
| Also present | Separate `senderId` + `createdAt` DESC index (complainant list path) — **not** the failing query |

**WT note:** `firestore.indexes.json` is modified in the working tree for other reasons (e.g. RB-02 / payments). The **complaints status+createdAt** entry already exists on committed HEAD; this investigation did **not** edit the file.

**Critical distinction:** Repo declaration ≠ Cloud deployment. Device error proves the index is **missing or not ready on live `rafiq-academy`**, regardless of local JSON.

### 14.5 Root cause and confidence

| Item | Assessment |
|------|------------|
| **Root cause** | Client Admin dashboard `getComplaints()` issues `status whereIn [open,in_progress]` + `orderBy createdAt DESC` + `limit 20` against `complaints`; live project lacks the matching composite index |
| **Confidence** | **Confirmed** (Logcat explicit index message + decoded composite + exact source match) |
| **Ruled out for this line** | Generic “other” FAILED_PRECONDITION without index text; wrong collection name; Rules-only denial (would typically be PERMISSION_DENIED) |
| **Not proven here** | Whether payments aggregate / cover / absence indexes also failed in the same session (separate BASMA-101 items) |

### 14.6 Local tests / emulator checks performed

| Check | Result |
|-------|--------|
| Device Logcat re-read | Done |
| Code path + constants verification | Done |
| `firestore.indexes.json` vs HEAD complaints entries | Done |
| New emulator query harness | **Not run** (no safe need; would not prove Cloud) |
| Live Cloud `indexes` list / deploy | **NOT VERIFIED** / **not attempted** (policy) |

### 14.7 Cloud existence

**NOT VERIFIED** via Console/`firebase` CLI this pass. Runtime `FAILED_PRECONDITION` on device is sufficient to treat Cloud as **missing or unavailable** for this composite until owner-deployed evidence exists.

### 14.8 BASMA-101 status impact

Register already records BASMA-101 as **Confirmed Issue** / **BLOCKED BY EXTERNAL DEPENDENCY** for unpublished indexes including complaints `status+createdAt`. This G1 investigation **reconfirms** that slice with a precise query+file citation.

**No register status change** in this task (documentation update limited to this G1 report; evidence does not close BASMA-101).

### 14.9 Recommended next action (owner-gated)

1. **G0 / owner approval:** deploy Firestore indexes from the approved `firestore.indexes.json` (or Console create for the complaints composite) to the **final** Firebase project (RB-09), not assumed forever-`rafiq-academy`.  
2. Wait until index status is **Enabled** in Console.  
3. Retest Admin Home complaints load on device (read-only) — expect Logcat index error gone; confirm `complaintsStatus` loaded.  
4. Separately verify other BASMA-101 indexes (payments aggregates, etc.).  
5. **Do not** “fix” by weakening the query in app code without a separate engineering decision.

**Approval required:** indexes deploy + target project confirmation. No code change recommended solely from this investigation.
