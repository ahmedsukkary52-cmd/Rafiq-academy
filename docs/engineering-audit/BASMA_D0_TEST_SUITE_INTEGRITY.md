# BASMA D0 Test Suite Integrity

## Environment blockers

| Tool | Status |
|------|--------|
| `git.exe` on this machine | **Access denied** — Flutter wrapper fails unless a local PATH shim returns engine hash |
| Flutter tests | Ran via temporary `git.cmd` shim in `%TEMP%\basma_git_shim` (session-only; not committed) |
| Firebase emulators | Worked with `demo-rafiq-rules` |
| Live Firebase | Not contacted for D0 tests |

## Commands executed (actual)

### Firestore D0 isolation

```text
npx firebase emulators:exec --project demo-rafiq-rules --only firestore ^
  "npm --prefix rules_test run test:d0:isolation"
```

Result: **18 passed, 0 failed**, exit 0.

### Storage D0 payment proofs

```text
npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage ^
  "npm --prefix rules_test run test:d0:storage"
```

Result: **4 passed, 0 failed**, exit 0.

### Chat room bloc (Flutter)

```text
flutter test test/features/chat/chat_room_bloc_test.dart --reporter compact
```

Result: **17 passed, 1 skipped** (D2 contract placeholder), exit 0.

### Flutter analyze (scoped)

```text
flutter analyze lib/features/chat/presentation/bloc/chat_room_bloc.dart ^
  lib/features/chat/presentation/bloc/chat_room_state.dart
```

Result: **No issues found** (ran in ~63.5s).

### Not run in D0

| Suite | Reason |
|-------|--------|
| Full `test:all:firestore` / `test:all:storage` | Time/cost; D0 files wired into aggregates for future runs |
| Full `flutter test` | Git/Flutter friction; scoped chat suite sufficient for D0 chat work |
| Coverage LCOV | Not requested as claim; not run |
| Cloud Trial REST re-probe | Out of D0 scope (no live mutations; optional later) |

## Aggregation wiring (updated)

`rules_test/package.json`:

- `test:d0:isolation` → `d0_trial_isolation.firestore.rules.test.mjs`
- `test:d0:storage` → `d0_payment_proof.storage.rules.test.mjs`
- Both included in `test:all:firestore` / `test:all:storage`.

## Still outside aggregates (pre-existing)

Still not in `test:all:firestore` unless separately invoked:  
`academy_relationships`, `admin_milestone`, `profile_privacy`, `r1_sensitive_client_writes` (and storage `admin_messaging`). Documented earlier in Stage A; unchanged policy in D0 except D0 files were added to aggregates.

## Emulator project guard

`rules_test/project_id.mjs` defaults to `demo-rafiq-rules`. All D0 commands used `--project demo-rafiq-rules`.
