# BASMA Release Readiness

Status: NOT RELEASE READY. Part A Inventory/Reconciliation is closed administratively; R1 is in progress on `unify/basma-v1`. This document records evidence and gates; it is not approval to deploy.

## Evidence baseline

- Branch: `unify/basma-v1`
- HEAD: `bb0a90585adb9ee684848cd547cb234cff2a47fa`
- Historical audit baseline: `feature/full-product-audit` @ `69e4207`
- Current working tree: heavily modified with pre-existing tracked and untracked changes; preserve all changes.
- `firebase.json` currently wires Firestore rules/indexes, Storage rules, Functions, and emulators.
- No production Firebase deployment, live migration, seeder, paid-service activation, commit, push, or release build is claimed here.

## Gate status

| Gate | Status | Evidence / blocker |
|---|---|---|
| Product decisions | IMPLEMENTED / LOCKED | `docs/production/PRODUCT_DECISIONS_LOCKED.md`; no unilateral policy changes allowed. |
| Firestore authorization | TESTED | `npm run test:all:firestore` via `demo-rafiq-rules`: 276 passed, 0 failed, 0 skipped, exit 0. Production deployment remains unverified. |
| Storage authorization | TESTED | `npm run test:all:storage` via `demo-rafiq-rules`: 67 passed, 0 failed, 0 skipped, exit 0. Production deployment remains unverified. |
| Callable authority | PARTIALLY TESTED | Existing current-branch Emulator evidence includes PH02 76/76, P0 25/25, billing 5/5, chat/media 14/14, B14 meeting links 6/6, parent achievements 7/7, Parent Halaqat/Schedule wrappers 5/5, the high-risk account wrapper suite 2/2, and four isolated R1-G wrapper groups (Membership, Staff/Cover, Payments, Chat Groups), each 1/1. Strictly, 22 of 52 callable wrappers have executed HTTP Functions-Emulator authorization evidence; 30 remain core-only. |
| Firestore trigger authority | PARTIALLY TESTED | Nine triggers have source-write + side-effect evidence, including the two absence triggers and the five projection/group triggers (`1/1` for each focused suite); two have synthetic handler evidence (`19/19`). The scheduled runtime remains intentionally unexecuted. No R1-G trigger rerun was performed. |
| Admin/Supervisor/Audio focused work | TESTED (mocked) | Prior focused commands passed; this does not prove real Firebase/device behavior. |
| Production Firebase project | BLOCKED BY EXTERNAL DEPENDENCY | Release docs state prod project/config are not created. |
| Firebase billing/Blaze | BLOCKED BY EXTERNAL DEPENDENCY | `FIREBASE_BILLING_CHECKLIST.md` remains `B-BILLING UNRESOLVED`. |
| Android signing | BLOCKED BY EXTERNAL DEPENDENCY | Upload key not supplied/configured. |
| Codemagic | NOT VERIFIED | Workflows are prepared locally; no CI run evidence. |
| iOS build/signing/APNs | BLOCKED BY EXTERNAL DEPENDENCY | macOS/Codemagic, Apple account, APNs, and bundle-ID decisions remain. |
| Branding/screenshots/store metadata | NOT VERIFIED | BASMA direction exists in locks; launch/store visual verification remains. |
| Device/end-to-end verification | NOT VERIFIED | No release-device evidence in this recovery step. |

## Required evidence before release claim

1. Current Firestore and Storage rules tests pass with raw output and exit codes.
2. Callable emulator suites prove authorization, rejection, audit behavior, and data refresh for critical workflows.
3. Cross-role workflows pass against emulator-backed data, not only fakes.
4. Production Firebase project/configuration and rules diff are owner-approved.
5. Blaze plan, budget alerts, FCM platform registration, and required console evidence are recorded.
6. Android signing and Codemagic checks pass; iOS unsigned/signed checks pass on macOS as applicable.
7. Physical-device checks cover Auth, navigation, notifications, media, and critical role workflows.
8. Store metadata, screenshots, privacy/support information, and version/build are reviewed.

## Explicit non-claims

This file does not claim production readiness, zero vulnerabilities, clean working tree, emulator completion, signed build completion, or successful deployment.
