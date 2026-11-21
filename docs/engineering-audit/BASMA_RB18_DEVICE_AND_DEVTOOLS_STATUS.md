# BASMA RB-18 / D4 — Device & DevTools Status

**Date:** 2026-11-18  
**Host:** Windows 10 · Flutter 3.44.9  
**Policy this pass:** One short device probe; if unstable or no debug session → defer physical lab; **do not block** remaining engineering work.

---

## 1. Device connectivity (quick probe)

| Check | Result |
|-------|--------|
| First `adb devices` | Empty (daemon starting) |
| Second probe | Wireless device appeared: **Samsung SM-A037F** (`adb-R9PT60KGKTV-26vnYl._adb-tls-connect._tcp`), Android 13 / API 33 |
| `flutter devices` | Lists `SM A037F (wireless)` + Windows/Chrome/Edge |
| Package installed | `com.example.rafiq_academy` present |
| Package meta | `versionName=1.0.0`, `versionCode=2`, `DEBUGGABLE`, `targetSdk=36`, `minSdk=24` |
| Process running | **No** (`pidof` empty) |
| Foreground | Launcher (`com.sec.android.app.launcher`), not BASMA |
| App data / uninstall | **Not touched** |

**Decision:** Do **not** spend the session on `flutter run`, wireless reconnect loops, or DevTools attach. No stable Flutter debug/Observatory session was available on the installed APK without a new debug launch (which risks long wireless churn and is not required to continue the plan).

---

## 2. Flutter DevTools

| Tool | Used? | Notes |
|------|-------|-------|
| Performance Timeline | **No** | No running Flutter debug isolate |
| Jank / slow frames | **No** | — |
| Widget Inspector / rebuilds | **No** | — |
| Memory / CPU | **No** | — |
| Network | **No** | — |
| Logcat skim | Yes (brief) | No Flutter FATAL in last ~200 lines; only adb shell noise |

**Explicit non-claims:** No profile-mode timings; debug numbers would not represent release (RB-D4-03 remains open).

---

## 3. Local RB-18 / D4 verification (files + tests)

### Verified from files

| Area | Finding |
|------|---------|
| Adaptive icon | `mipmap-anydpi-v26/ic_launcher.xml` + density `ic_launcher` / `ic_launcher_foreground` PNGs present |
| Splash (pre-12) | `launch_background.xml` → `@color/basma_launch_background` + `@drawable/splash_icon` |
| Splash (12+) | `values-v31` / `values-night-v31` set `windowSplashScreenBackground` + `windowSplashScreenAnimatedIcon` |
| Branding colors | `basma_launch_background` `#F5F6FA`; alias `rafiq_launch_background` kept for stale refs |
| iOS LaunchImage | Placeholder PNGs still **68 bytes** each — visual QA still needed on device/mac |
| User-facing “Rafiq Academy” | Found in student settings subtitle → **fixed this pass** to `AcademyBranding.displayName` |

### Verified from tests

| Command | Result |
|---------|--------|
| `flutter test test/shared/app_floating_bottom_nav_d4_test.dart test/shared/d4_lazy_list_structure_test.dart` | **All passed** (RepaintBoundary + narrow overflow + lazy structure) |

### Not verified on device

- Icon mask matrix (circle/squircle/OEM) — **RB-D4-01**
- Splash double-frame / Android 12+ visual — **RB-D4-02**
- Profile-mode jank on low-end — **RB-D4-03**
- Full physical install/smoke of all roles — **RB-18**

---

## 4. Blocker status impact

| ID | Status after this pass |
|----|------------------------|
| RB-18 | Remains **OPEN** — device seen once; no install/smoke matrix executed |
| RB-D4-01 | **OPEN** — assets present; no screenshot matrix |
| RB-D4-02 | **OPEN** — styles wired; no device visual confirm |
| RB-D4-03 | **OPEN** — no DevTools/profile traces |

Physical/device lab is **deferred**, not a stop on the Final Engineering Quality Audit.

---

## 5. Follow-up when a stable session exists

1. Prefer USB or a stable wireless session; one `flutter run --flavor …` with correct dart-defines.  
2. Open DevTools → Performance (profile if claiming ship perf) + Memory after role-home navigation.  
3. Capture icon/splash screenshots per RB-D4 matrix.  
4. Do **not** uninstall or wipe data to “fix” connectivity.
