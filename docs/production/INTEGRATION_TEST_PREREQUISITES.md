# Integration Test Prerequisites (`integration_test`)

**Status:** Bootstrap implemented (2026-11-21) — device run still requires Android Emulator + local Firebase Emulator Suite.

## Why it was blocked historically

Older notes claimed `main.dart` always initialized the Production `rafiq-academy` project. That is **obsolete**.

Current fail-closed routing (`lib/core/firebase/app_firebase.dart` + `app_flavor.dart`):

- Local flavors (`dev` / `staging`) **require** `--dart-define=USE_FIREBASE_EMULATOR=true` and debug builds.
- Emulator options are fake keys for project **`demo-rafiq-rules`** only.
- Every Auth / Firestore / Functions / Storage client is wired to `127.0.0.1` with `automaticHostMapping: false`.
- Trial/prod flavors refuse Emulator routing.

What was still missing (and is now added):

- `integration_test` package + `integration_test/` journeys
- Emulator health probe that **fails closed** if ports are down
- Seed fixture script for a fresh Emulator session
- Runner script documenting `adb reverse` (required because the app uses `127.0.0.1`, not `10.0.2.2`)

## What already covers the backend today

- Firestore / Storage rules suites on `demo-rafiq-rules`
- Functions Emulator suites
- Flutter unit / bloc / widget tests under `test/`

## How to run Flutter ↔ Emulator integration

```powershell
# Terminal A — Emulator Suite (demo-rafiq-rules only)
npm --prefix functions run serve

# Terminal B — seed once on an empty session
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
$env:FIREBASE_STORAGE_EMULATOR_HOST="127.0.0.1:9199"
$env:FIREBASE_FUNCTIONS_EMULATOR_HOST="127.0.0.1:5001"
$env:GCLOUD_PROJECT="demo-rafiq-rules"
node functions/scripts/seed-integration-fixture.mjs

# Terminal C — Android Emulator + reverse + tests
flutter emulators --launch Pixel_9_Pro
# wait until device is online
powershell -File tool/run_flutter_emulator_integration.ps1
```

Or a single-device invocation:

```text
flutter test integration_test --flavor dev --dart-define=USE_FIREBASE_EMULATOR=true -d <android-id>
```

## Journeys covered by bootstrap

1. Auth + role routing (student / parent / wrong password)
2. Student home loads Firestore profile name
3. Parent payments surface loads from Emulator

## Hard rules

- Never run without `USE_FIREBASE_EMULATOR=true`
- Never use trial/prod flavors for these tests
- Never weaken Rules / Functions AuthZ for the suite
- Never seed against a non-empty Emulator session (fixture refuses)
- Never point at Production credentials or `rafiq-academy` Cloud
