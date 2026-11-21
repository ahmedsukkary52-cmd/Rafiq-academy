# BASMA Performance & UI Motion Audit (Stage A)

**Date:** 2026-11-16  
**No profile-mode instrumentation run in this Stage** → frame timings = **Blocked Verification**.  
Includes Icon / Splash / Responsive inventory (implementation deferred to Stage D).

---

## 1. Verified facts

### 1.1 Lists (enriched inventory — [Perf/UI inventory](b5e5c629-b260-4a4e-aa60-446cc96934bc))

| Pattern | Call sites | Files | Note |
|---------|----------:|------:|------|
| `ListView.builder` | 14 | 11 | Lazy |
| `ListView.separated` | 45 | 34 | Lazy (builder family) — earlier audits under-counted this |
| `ListView(` | 74 | 60 | Eager `children`; many are short forms, not unbounded rosters |
| `GridView.builder` / `.count` | 8 / 8 | — | Mix lazy/eager |
| `cacheExtent` / `RepaintBoundary` | 0 / 0 | — | **Potential Risk** on blurred nav + shells |

Skeletons: shared `AppSkeletonPulse` (~1100 ms) plus role wrappers; additional local shimmer controllers in chat/audio/excuses.

### 1.2 Rebuild / paint risks (code-read, not timed)

- `setState`: **573** sites / 109 files; student shell tab changes rebuild `AppFloatingBottomNav`.
- That nav is the only `BackdropFilter` (sigma 18) — shell `setState` repaints blur; **no** `RepaintBoundary` in `lib`.
- `BlocBuilder` 80 / `buildWhen` 79 — present but not a coverage ratio.

### 1.3 Chat UI performance coupling

- Message window grows by raising Firestore `limit` and re-subscribing — extra reads **and** full list rebuild (**Confirmed** / BASMA-103).

### 1.4 Motion system

- No `AppMotion` / shared duration-curve tokens under `lib/shared/theme`.
- `Duration(milliseconds:` ~61 sites — ad hoc. **P3** unless jank proven.

### 1.5 App icon

- Adaptive icon configured: [mipmap-anydpi-v26/ic_launcher.xml](../../android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml) with background color + foreground mipmaps across mdpi–xxxhdpi.
- Comments document safe-zone intent — good engineering hygiene.
- Visual quality on all launcher masks: **Blocked Verification** (no systematic screenshot matrix this Stage). SM-A037F install proves icon exists at runtime only.

### 1.6 Splash

- Flutter: [splash_page.dart](../../lib/features/auth/presentation/pages/splash_page.dart) — background aligned to native `#F5F6FA`.
- Native pre-12: `drawable(+v21)/launch_background.xml` + density `splash_icon.png`.
- Android 12+: `values-v31` / `values-night-v31` `windowSplashScreenBackground` + `AnimatedIcon` → `@drawable/splash_icon`.
- **`flutter_native_splash` not in pubspec** — splash is hand-wired. Double-splash / white frame: **Blocked Verification** on API 31+ devices.
- No artificial splash delay — keep for Stage D.

### 1.7 Responsive / overflow / SDK

- [SHARED_UI_AUDIT.md](../production/SHARED_UI_AUDIT.md) baseline `69e4207` is partly stale: **one** `AppFloatingBottomNav` now (AUD-041 partially superseded).
- Still no breakpoint/`shortestSide` API; `MediaQuery.` ~76 sites. Overflow on ~320 px: **Blocked Verification**.
- Gradle uses Flutter template `minSdk`/`targetSdk`/`compileSdk`. Trial APK aapt: **targetSdk=36**, package `com.example.rafiq_academy`; `minSdk` integer not in that dump.
- FVM pin **Flutter 3.44.9** (`.fvmrc`); local `.fvm/flutter_sdk` may be absent on this machine.
- SM-A037F: install PASS for morning APK; newer APK install later recovered separately — qualitative read journeys only; **no** frame timings.

### 1.8 Theme / colors

- `Colors.` ~**2647** / 179 files; `withOpacity` **41** / 9 files; `withValues` **296** / 92 files — migration incomplete (AUD-047).
- D15 forces light `themeMode`; dark ThemeData may remain unused.

---

## 2. Measured results

- Install/login smoke on SM-A037F succeeded for six roles (Trial).
- No DevTools build/raster ms captured this Stage.

---

## 3. Inferred risks

- Non-builder ListViews on large admin directories → jank on low-end.
- Heavy Figma-style pages (admin/teacher/parent) → large rebuild scopes.
- Image decode for payment proofs / chat media without size contracts → memory spikes (**Potential**).

---

## 4. Recommendations (classify for plan; do not implement now)

| Item | Severity | Effort band | Depends on |
|------|----------|-------------|------------|
| Chat older-page cursor + UI append | P1 | M | Firebase efficiency |
| Convert hot lists to builder + keys | P2 | M | Screen inventory |
| Motion tokens + reduced-motion | P3 | S–M | Design approval |
| Icon/splash visual QA matrix | P2 | S | Device lab |
| Overflow goldens multi-size | P2 | M | Test harness |

---

## 5. Unresolved questions

- Profile-mode baselines on low-end device.
- iOS splash/icon parity (Windows-focused Trial evidence only).
