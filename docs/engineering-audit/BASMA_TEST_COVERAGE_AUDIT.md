# BASMA Test Coverage Audit (Stage A)

**Date:** 2026-11-16  
**Rule:** No % coverage claim without a measured LCOV/cobertura report. This Stage did **not** run `flutter test --coverage`.

---

## 1. Verified facts — inventory

### 1.1 Flutter

- Earlier pass counted **282** dart files under `test/`; refined inventory: **272** `*_test.dart` ([Perf/UI inventory](b5e5c629-b260-4a4e-aa60-446cc96934bc)) — use `*_test.dart` as the meaningful suite count.
- Breakdown (approx): `features/` 191 (admin 32, parent 23, teacher 20, chat 18, student/supervisor 14 each, mushaf 12, …), `shared/` 51, `core/` 14, `security/` 12.
- **No** `integration_test/` directory.
- Includes mocked tests cited for BASMA-010–012.

### 1.1b Rules test packaging note

- `rules_test` aggregates `test:all:firestore` / `test:all:storage` do **not** include every rules test file on disk (several `*.firestore.rules.test.mjs` sit outside the aggregate script). File presence ≠ execution.

### 1.2 Cloud Functions / Rules (from Master Register — Existing Known evidence)

| Suite | Recorded result | Environment |
|-------|-----------------|-------------|
| Firestore rules | 276 passed | demo emulator |
| Storage rules | 67 passed | demo emulator |
| PH02 backend authority | 76 passed | emulator |
| P0 completion | 25 passed | emulator |
| Billing callables | 5 passed | emulator |
| Chat callables | 14 passed | emulator |
| Meeting links | 6 passed | emulator |
| Achievements | 7 passed | emulator |
| Additional trigger/wrapper groups | as listed in register | emulator |

**Caveat:** Emulator ≠ production. Live Trial showed rules gap and zero Functions.

### 1.3 `functions/package.json` scripts (verified)

Present: `test:ph02:emulator`, `test:p0:emulator`, `test:chat:emulator`, `test:billing:emulator`, `test:meeting-link:emulator`, `test:achievements:emulator`, `test:fcm:emulator`, wave-a bundle, etc.

### 1.4 Coverage gaps called out by register

- 30 callables **CORE TESTED ONLY** (wrapper auth not all executed).
- Scheduled `processPaymentOverdueGrace` runtime **not** invoked.
- FCM device delivery outstanding.
- Flutter cross-role workflows on emulator/device incomplete vs callable suites.

---

## 2. Measured results

- Coverage %: **Blocked Verification** (not run).
- Trial device journeys: qualitative PASS/FAIL in Integration audit — not automated tests.

---

## 3. Recommendations

1. Stage D: add regression tests for Trial over-read cases **after** rules deploy to a non-prod project or emulator mirror of production rules.
2. Message pagination unit tests for cursor vs growing-limit.
3. Do not chase 100% on generated/UI chrome.

---

## 4. Unresolved questions

- Branch coverage of payment state machine.
- Widget golden overflow suite existence/completeness.
