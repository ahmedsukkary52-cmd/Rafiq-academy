# Integration Test Prerequisites (`integration_test`)

**Status:** Not started — blocked on environment (2026-10-07, Release Readiness Fix Pass, Phase 12).

## Why it was not implemented

- `lib/main.dart` always calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`,
  which targets the **production** project `rafiq-academy`. There is no emulator hook and no
  staging project.
- An on-device `integration_test` run would therefore sign in, write attendance, evaluations,
  chat messages and payment proofs against **production data**. That is unsafe.
- The fix pass explicitly forbids adding a permanent emulator switch or changing the
  environment architecture, so the safe paths below were not built.
- `integration_test` is not in `pubspec.yaml` and no `integration_test/` directory exists.

## What already covers the backend today

- Firestore rules: `npm --prefix rules_test run test:all:firestore` (emulator, project `demo-rafiq-rules`).
- Storage rules: `npm --prefix rules_test run test:all:storage`.
- Functions unit/contract: `npm --prefix functions test`.
- Functions emulator suite: `npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore,functions,storage "<the four *.emulator.test.mjs files>"`.
- Flutter: Bloc, repository/datasource contract and widget tests under `test/` (hand-written fakes).

## Prerequisites (one of the following must exist first)

1. **Emulator entry point (recommended for CI)**
   - A separate test-only entry point (e.g. `integration_test/app_test.dart` calling a
     `bootstrapForTest()` that runs `useAuthEmulator` / `useFirestoreEmulator` /
     `useFunctionsEmulator('…', 5001)` / `useStorageEmulator` before `runApp`).
   - Must not change `lib/main.dart` behaviour for release builds.
   - Seed script for the `demo-rafiq-rules` emulator: one admin, teacher, supervisor,
     parent, linked student, halaqa with schedule, invoice.
   - Android emulator host mapping (`10.0.2.2`) and cleartext allowance for debug only.
   - Requires an explicit decision, because it is a (test-only) environment switch.
2. **Staging Firebase project**
   - Depends on the paused environment-split work (separate project, `google-services.json`
     / `GoogleService-Info.plist` per flavor, `.firebaserc` alias, deployed rules/indexes/
     Functions, billing checklist).

## Critical journeys to cover once unblocked

- Login per role → correct home (incl. deactivated-account rejection).
- Teacher: open halaqa → save attendance → live evaluation → parent receives notification.
- Supervisor: issue achievement; admit student; review payment proof.
- Parent: submit payment proof (Storage upload) → status reflects review.
- Chat: start allowed conversation, send text/image/voice, edit, delete; denied pair rejected.
- Student: homework complete → coins awarded server-side.

## Tooling

- Add `integration_test: sdk: flutter` to `dev_dependencies`.
- Run with `flutter test integration_test --no-pub -d <device>` (emulators running first).
- Firebase Test Lab is out of scope for this pass.
