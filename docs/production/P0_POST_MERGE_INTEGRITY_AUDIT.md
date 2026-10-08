# P0 Post-Merge Integrity Audit

Date: 2026-10-06 · Scope: «P0 POST-MERGE INTEGRITY AUDIT». This was a read-only audit.

Nothing in the code was modified, cleaned, deleted, committed, pushed or deployed. No Firebase production configuration was touched. This document is the only file written.

Sources read:
- `P0_COMPLETION_REPORT.md`;
- `PRODUCT_DECISIONS_LOCKED.md`;
- the PH-02 closure documents;
- `FINAL_ORPHAN_DEAD_FEATURE_AUDIT`;
- `git status` / `git diff` against HEAD `90201f1`;
- the Cloud Functions sources, `firestore.rules`, and the Flutter data, presentation and DI layers;
- the P0 and PH-02 test suites.

---

## Summary

P0 is functionally intact. One real regression must be fixed before staging: **B-1**, a Cloud Functions region mismatch that makes Admin reinstatement (and invoice generation) unreachable from the app.

Everything else is verified safe, is a minor residual, or is a deferred business decision.

---

## 1. Entity / model integrity

No existing entity or model file under `lib/**/domain/entities` or `lib/**/data/models` was modified by P0. The P0 entities are new and confined to `admin_operations_entities.dart` and `features/halaqa_plan`.

| Area | SSOT | Finding |
|---|---|---|
| Payment | `payments/{id}` (`status`, `reviewStatus`, `amountPaidConfirmed`, `remainingAmount`) + `paymentAccess/{parentId}` | Unchanged. The only P0 shape is `PaymentReviewItem`, a read projection. |
| Parent / child | `parentProfiles.childrenIds` (D12) | Unchanged. No second relationship store. |
| Halaqa / schedule | `halaqat.studentIds`, `halaqat.schedule[]` with `slotId` | `HalaqaEntity` keeps `slotId`. No duplicate schedule model. |
| Session | `sessions/v1|halaqaId|slotId|date` | Unchanged and server-materialized. |
| Homework | `assignments` + `homeworkRewards/{assignmentId}` | The marker is new and server-only. The `assignment_homework_fields_ensure` seed no longer writes `isSubmitted` and sets `kind` only when it is missing. |
| Reward | `studentProfiles.coins` (server-owned) | `points` is quarantined; nothing credits it. |
| Notification | `NotificationTypes` | Unchanged. Deep links are derived, not stored. |

`app_constants` changes:
- adds the `mushafReading` collection constant (a Mushaf wave, not P0);
- aliases `appName` to `AcademyBranding`.

No duplicate entity classes were found.

## 2. Admin operations

- **Routes.** `/admin/accounts`, `/admin/parent-links`, `/admin/halaqat`, `/admin/membership`, `/admin/payments` and `/admin/access` are declared once each. The route table has 44 constants and no duplicate values. Access goes through `AppRouteAccess.isAllowed`.
- **Bloc ownership.** `AdminOperationsBloc` handles provisioning, linking, Halaqa, slot, transfer and reinstatement. `PaymentReviewBloc` handles proof listing and review. Each class is defined once. `PaymentReviewBloc` has no reinstate event.
- **DI.** Each Bloc is registered once as a factory in `injection_container.config.dart`. There are no duplicate registrations.
- **States.** Loading, success and error states are surfaced in the pages through `admin_operation_widgets.dart`.
- **Callables.** All operations go through real callables: `adminProvisionUser`, `adminLinkParentChild`, `adminCreateHalaqa`, `adminAddHalaqaSlot`, `adminTransferStudent`, `admitStudentToHalaqa`, `reviewPaymentProof` and `adminReinstatePaymentAccess`. There are no mocks in production code.
- **Server authorization.** Each callable calls `assertBackendAllowed` and checks the caller role server-side (`loadCallerRole` / `assertCallerIsAdmin`).
- **Exception (B-1).** `adminReinstatePaymentAccess` and `adminGenerateInvoice` are deployed to `us-central1`, but the app calls them through the single `europe-west1` `FirebaseFunctions` instance (see §3).

## 3. Payment review

| Check | Result |
|---|---|
| Admin sees all pending receipts | Verified. The query is `reviewStatus == pending_review`, and Admin read is allowed by the rules. |
| Supervisor sees only its scope | Verified. The client queries per student of supervised Halaqat. The rules `isSupervisorOfStudent` and the server check (primary Halaqa `supervisorId == uid` plus roster membership) agree. |
| approve / partial / reject all use `reviewPaymentProof` | Verified. A single datasource method sends `decision.wire`. |
| Only `pending_review` is reviewable | Verified through the pure `decidePaymentReview` transition. |
| Idempotency | Verified. The audit id is derived from `paymentId` + `proofSubmittedAt` and checked inside the transaction, so a second review of the same proof is rejected. |
| Audit | Verified. A `paymentReview` audit entry is written in the same transaction as the payment update. |
| Parent / payment scope | Verified. The invoiced student must be in the parent's `childrenIds`. |
| No client mutation of payment status or `paymentAccess` | Verified. `payments` updates are limited to `parentProofOnlyUpdate`, and `paymentAccess` / `auditLogs` have `write: false`. |
| Reinstatement has one owner and needs no receipt | Verified on the client: `AdminOperationsBloc` → `/admin/access` picks a parent from the directory with no receipt. Verified on the server: the callable is Admin-only and change-only (an already `ok` record is a no-op without an audit entry), and writes a `paymentReinstate` audit entry. |

**B-1 — region mismatch.**

`functions/src/admin/adminBilling.ts` declares `adminGenerateInvoice` and `adminReinstatePaymentAccess` with `region: "us-central1"`. `lib/core/di/di_module.dart` provides `FirebaseFunctions.instanceFor(region: 'europe-west1')`, and `admin_remote_datasource_impl.dart` calls both names through it.

Callable URLs include the region, so both calls resolve to a non-existent `europe-west1` endpoint in production and in the emulator. The result is not-found / internal.

The mismatch already existed at HEAD. It is a regression in effect now because P0 made `/admin/access` the single reinstatement owner, which leaves no working reinstatement path from the app.

No test caught it:
- `wa3_wa5_billing.test.mjs` only asserts that the name exists in source;
- no emulator test invokes reinstatement through the client region.

All other callables invoked by the app are in `europe-west1`. The other `us-central1` functions are `adminMigrateHalaqaSlotIds`, which the app does not call, and `processOverdueGrace`, which is scheduled.

Minor, non-blocking: reinstatement is a read followed by a merge-set, not a transaction. It is change-only and idempotent, so a race at worst produces two audit entries.

## 4. Parent ↔ Student linking (D12)

- `childrenIds` cannot be written by any client, Admin included. It is excluded from every `parentProfiles` update branch.
- Linking is staff-controlled. `adminLinkParentChild` is Admin-only (`loadCallerRole == admin`), runs in a transaction with deduplicated next state (`nextChildrenIds`), and writes one audit entry. Re-linking is a no-op.
- Access is derived. Payment review re-reads `childrenIds` inside its own transaction, and emulator test "the new relationship is immediately authoritative" covers this.
- No old direct client write path to `parentProfiles.childrenIds` remains in `lib/`.

## 5. Halaqa + schedule

- **D8:** an empty schedule is rejected before any write. The cap is 14 slots. Day labels are canonicalized, and `HH:mm` is validated with end after start.
- **Slot → Session contract:** each slot keeps a stable `slotId`. `materializeSession` creates the deterministic `v1|halaqaId|slotId|date` id with Cairo dates (`billing/cairoTime`). `weekdayFromSlotDayLabel` accepts the Flutter labels.
- **Conflicts (D9):** same-Halaqa, same-Teacher and student-roster intersections are hard conflicts. **Supervisor overlap is intentionally allowed** (`sessionConflict.ts`, `WAVE_A_IMPLEMENTATION_SPEC`, `SECURITY_DATA_CONTRACT_FREEZE` C7).
- **Teacher lock:** `halaqaScheduleLocks/teacher_{id}` is read and written inside the transaction, which serializes concurrent creations for one Teacher (emulator test: exactly one succeeds).
- **Idempotency:** retries with the same `requestId` return the original result.
- **Audit:** `halaqa_create` and `halaqa_schedule_change`, written in the transaction.
- **No bypass:** Halaqa `create` is denied by the rules. Admin updates exclude `studentIds`, `schedule`, `teacherId`, `createdBy` and `createdAt`. Locks have `write: false`. No client `halaqat` writes exist in `lib/`.
- **Documentation inaccuracy (no code impact):** `P0_COMPLETION_REPORT.md` §2 says the Supervisor overlap check is "preserved". The code correctly allows Supervisor overlap, so the wording should say "Supervisor overlap allowance preserved".

## 6. Homework reward security

- The reward is server-owned. `completeHomeworkCore` derives the amount from the fixed server `requiredHomeworkKinds` (`rewardForRequiredKinds`), never from client `tasks`, `points` or extra kinds. Emulator tests cover forged task lists.
- The `homeworkRewards/{assignmentId}` marker is read with `tx.getAll` and created with `tx.create` in the same transaction as the coin increment, so it is paid at most once. Covered by emulator tests:
  - retry returns `alreadyRewarded`;
  - concurrent completion credits exactly once;
  - Teacher reopen cannot re-credit;
  - legacy `completedAt` without a marker never re-credits.
- `completedAt` cannot be set, moved or cleared by clients (rules test).
- **Disabled audio does not block completion.** `SERVER_CAPABILITIES.audioUploadsEnabled = false`, so the required kinds are `reading` and `listening`. When enabled, recitation requires a real `recitationRecords` document under `recitations/{uid}/{assignmentId}/`.
- **No points.** Only `coins` is incremented. `awardedPoints` is a legacy response alias equal to the coin amount and is not persisted.
- **No new points/game system.** The client's `completeHomework` calls the callable. The old client transaction is removed, and avatar purchase uses `purchaseAvatar`.
- **Minor residual (non-blocking):** `studentOwnHomeworkUpdate` lets a student set `kind` from empty to `lessonHomework` once, on their own assignment, before completion. This exists for legacy homework. Halaqa tasks and activities have an empty `studentId` and are not affected. The reward stays fixed and once-only.

## 7. خطة الحلقة

- `features/halaqa_plan` is a read-only projection built from assignments.
- There is no competing «خريطتي» SSOT and no stored plan document.
- الجديد and المراجعة are separate sections.
- `versesRange` is not parsed and no completion percentages are shown.

## 8. Audio Library

- The Audio Library is separate from the Mushaf audio: `AudioLibraryBloc` / `AudioPlayerService` versus `MushafAudioBloc`.
- It is reachable through restored routes.
- **Player lifetime:** `AudioPlayerService` is a lazy singleton. `AudioLibraryBloc` calls `stop()` on close, and the only `_player.dispose()` is inside the service itself. No page or Bloc disposes the shared player.
- **Progress:** progress uses the deterministic `listeningProgressDocId` (`{userId}_{surahAudioId}`, with `/` sanitized), so updates hit the same record. The rules require a `userId` match.

## 9. Notifications / push

- `notification_deep_links.dart` resolves the destination by type and role. Document IDs are only references.
- The destination page re-checks authorization through the normal rules and repositories, and falls back to a safe state when the destination is unavailable.
- **One router:** `MyApp` is a StatefulWidget with a single `late final GoRouter _router`. The font-size `ValueListenableBuilder` only rewraps `MediaQuery` (`textScaler`) above `routerConfig: _router`, so no second router is created.
- **Residual (device-unverified):** a cold-start push open racing the splash redirect has not been verified on a physical device. This needs device QA in staging and is not a code regression.

## 10. Chat / posts / content

- **Halaqa group:** `buildHalaqaGroupMembership` projects Teacher + Supervisor + roster students only, and is documented as "Never includes Parent or Admin". Membership is CF-synced. Conversation `create` is false, and membership fields are frozen on update.
- **Parent 1:1:** `createDirectConversation` runs the server D14 relationship check (`isDirectChatRelationshipAllowed`) and rejects client-supplied `participantIds`.
- **Admin monitoring** is read access in the rules (`isAdmin()`), not membership.
- **Posts** are a Halaqa feed keyed on `audienceTarget == halaqaId`, separate from Chat. Only Halaqa staff or Admin author posts, and the audience is frozen. Legacy `"all"` posts are Admin-read-only.
- **Minor residual (pre-existing):** the author edit branch freezes `halaqaId`, `audienceTarget` and `authorId` but does not whitelist other keys. An author could edit counters on their own post.
- **Shared Content** (`contentLibrary`) is Halaqa-scoped with a `storagePath` pattern, has `update: false`, and is reachable from Halaqa Details.
- No pricing was invented. The 50 MB limit remains marked as a placeholder.

## 11. Legacy / duplicate code

| Check | Result |
|---|---|
| Payment-review Blocs, pages and widgets | One slice: `payment_review_{bloc,event,state}.dart` + `payment_review_page.dart`. The parent-side proof submission is a separate concern. |
| Admin ops Blocs | One `AdminOperationsBloc`. |
| Entities | No duplicates. |
| Old direct parent-child, roster or schedule writes | None remaining in `lib/`. |
| Old homework or points reward path | Removed from the client datasource. |
| Conflicting routes | None. |
| Duplicate DI registrations | None. |
| Duplicate callable wrappers | `admitStudentToHalaqa` is invoked from two call sites (Admin approve and Supervisor admit). Both are intentional and target the same callable. Each other callable name has one wrapper. |

The old/orphan candidates in `FINAL_ORPHAN_DEAD_FEATURE_AUDIT` were not deleted, as instructed.

## 12. Test integrity

The security assertions are carried by the emulator and rules suites, which exercise the real callables and rules:

- `p0_completion.emulator.test.mjs` (24 tests) covers:
  - P0-05: forged tasks, forged kinds, retry, concurrency, reopen, legacy, foreign student;
  - P0-01: unauthorized roles, forged ids, concurrent links, immediate authority;
  - P0-04: D8, D9, Supervisor overlap allowed, roster conflict, lock concurrency, idempotency, unauthorized roles.
- `p0_completion.rules.test.mjs` covers:
  - Halaqa create and schedule denial, locks, markers, `completedAt`, `kind` rewrite;
  - posts and content scope;
  - the Supervisor pending-proof query scope.
- `ph02_backend_authority.emulator.test.mjs` covers `reviewPaymentProof` (scope, transitions, idempotency, audit).

Fake-based tests that verify wiring only:
- Admin Bloc tests (`AdminOperationsBloc`, `PaymentReviewBloc`) use fake repositories, so they verify state transitions and the correct use case per event. They pass regardless of server authorization and must not be read as security evidence.
- `wa3_wa5_billing.test.mjs` asserts only that `adminReinstatePaymentAccess` exists in source. It does not prove the callable is reachable, which is why B-1 went undetected.

There is a coverage gap: no test asserts that the region of each app-invoked callable matches the client's `FirebaseFunctions` region.

## 13. Git / change scope

- HEAD is `90201f1`. The working tree carries several uncommitted waves: UI, Mushaf, PH-01, PH-02 and P0. The P0 files match `P0_COMPLETION_REPORT.md` §14.
- **Deleted:** `lib/shared/data/academy_admission_firestore.dart`. This predates P0 (recorded in `FINAL_ORPHAN_DEAD_FEATURE_AUDIT`) and nothing references it.
- **Generated or tooling files modified:**
  - `lib/core/di/injection_container.config.dart` (expected);
  - `windows/flutter/generated_plugin_registrant.{cc,h}`;
  - `pubspec.yaml` / `pubspec.lock`.
- **Suspicious untracked files (report only, not cleaned):**
  - `unit_out.txt` at the repository root (a test output dump);
  - `.cursor/mcp.json` (local editor configuration);
  - `rules_test/node_modules/`. Neither the root `.gitignore` nor a `rules_test/.gitignore` covers it, so a blanket `git add` would stage it.

No unrelated broad refactors were found in the P0 file set.

---

## 14. Final classification

### A. VERIFIED SAFE

- Entity/model integrity: no duplicate or modified SSOT entities.
- Admin routes, Bloc ownership and DI, with real callables and server role checks (except B-1).
- `reviewPaymentProof`:
  - pending-only transitions;
  - Admin-all and Supervisor-scope access;
  - parent/child scope;
  - idempotent per proof;
  - transactional audit.
- No client mutation of `payments.status`, `paymentAccess` or `auditLogs`.
- A single reinstatement owner that needs no receipt (server logic correct).
- D12: `childrenIds` server-only, Admin-only callable with audit, derived access, no old path.
- Halaqa + schedule:
  - D8, `slotId` → Session contract, Cairo dates;
  - D9 hard conflicts with Supervisor overlap allowed;
  - Teacher lock, `requestId` idempotency, audit;
  - no bypass.
- Homework reward:
  - server-fixed amount, once-only marker in a transaction (retry, concurrency, reopen, legacy);
  - disabled audio not blocking completion;
  - no points credited and no new game system.
- خطة الحلقة: a read-only projection with no competing SSOT.
- Audio Library: separate from the Mushaf audio, reachable, shared player not disposed, same progress record.
- Notifications: a single router instance, font-size changes do not recreate it, and deep links are type/role aware with authorization re-checked.
- Chat, posts and content:
  - the Halaqa group excludes Parents and Admin;
  - 1:1 is relationship-based;
  - Admin monitoring is read-only;
  - posts are a Halaqa feed;
  - content is Halaqa-scoped.
- Legacy and duplicates: no conflicting Blocs, routes, DI or wrappers.

### B. NEEDS FIX BEFORE STAGING

- **B-1 — callable region mismatch.** `adminReinstatePaymentAccess` and `adminGenerateInvoice` are deployed to `us-central1`, while the app calls them through the `europe-west1` client. Admin reinstatement (the only P0 reinstatement path) and invoice generation are unreachable from the app. The fix must align the region on one side and add a region-consistency test. It was not applied, per the audit-only scope.
- **B-2 — documentation correction.** `P0_COMPLETION_REPORT.md` §2 wording on Supervisor overlap ("check preserved") must be changed to "overlap allowance preserved". This is a documentation fix only and changes no behaviour.

### Minor residuals (non-blocking, tracked)

- Reinstatement is not transactional (change-only and idempotent; at worst a duplicate audit entry).
- The legacy one-time student `kind` set to `lessonHomework` on the student's own empty-kind assignment.
- The post author edit branch does not whitelist keys (pre-existing).
- Admin Bloc tests are wiring-only, as noted in §12.
- Push cold start versus the splash redirect needs device QA.
- Untracked `unit_out.txt`, `.cursor/mcp.json` and an un-ignored `rules_test/node_modules/` must be handled at commit time.

### C. DEFERRED BUSINESS DECISIONS

- Shared Content limits and pricing: the 50 MB limit is a placeholder, and no pricing is defined.
- Legacy `"all"` posts: currently Admin-read-only; whether to migrate, archive or delete them is a business decision.
- Supervisor payment review for students whose primary Halaqa is supervised by someone else. These students are skipped by design under the current scope rule; whether co-supervisors should review them is a business decision.

---

## 15. Status confirmations

- **P0 remains CLOSED.** B-1 is a pre-existing deployment-region defect surfaced by this audit. It does not reopen the P0 design or decisions.
- **PH-02 remains CLOSED.**
- **No deployment was performed.**
- **No commit or push was performed.**
- No code, rules, Firebase configuration or orphan files were modified by this audit. Only this document was written.
