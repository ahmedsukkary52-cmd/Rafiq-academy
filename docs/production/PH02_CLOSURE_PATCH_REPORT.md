# PH-02 Closure Patch Report

Scope: settle the two contracts that kept PH-02 open (evaluation edit window,
points / stars authority) and apply the minimum patch. Nothing was committed,
pushed or deployed. All suites ran against emulator project
`demo-rafiq-rules` only.

## A. Contract Decisions

### Evaluation

| Question | Answer | Source | Status |
|----------|--------|--------|--------|
| Who creates? | Teacher of the session's halaqa, only if the student is Present/Late on a real session | SECURITY_IMPLEMENTATION_SPEC §10.1, D7 | Implemented (PH-02) |
| Teacher edits? | Yes, for **24 hours** from the server-set `createdAt` (B1, final closure) | D7.1 | **Implemented** — server-enforced, denied from 24h on |
| Supervisor edits? | No ("✖ unless product expands"); remains read-only | §10.1, D7.1 | Implemented — callable denies Supervisor |
| Admin correction? | Yes, at any time, including after the Teacher window (B2, final closure) | D7.1 | **Implemented** — same gates, transactional, audited |
| Only during the operational session/day? | No — the window is anchored to evaluation creation, not the session day | D7.1 | Implemented |
| After the window? | Teacher denied; Admin corrects | D7.1 | Implemented |
| Audit? | "Evaluation create/correction" must be auditable (actor, evalId, sessionId, type, versesRange) | §20.1 | **Resolved by the Supervisor Authority Review**: C16 §16.2 was amended to allow a server-derived `teacher` actor, and `upsertSessionEvaluation` now emits change-only `evaluation_create_or_correct` audits (see `PH02_SUPERVISOR_AUTHORITY_REVIEW.md` §6) |
| Notifications on edit? | D17 notifies on **create**. PH-02 never re-pushes on edit (per-device delivery ledger); the in-app card is re-marked unread | D17 | Implemented |
| Progress on edit? | D11 requires a server projector from memorization evaluations; none exists yet (Wave C), so edits don't touch progress | D11, §10.3 | Out of PH-02 scope |

**Decision: RESOLVED (final closure patch).** The product locked B1 and B2
(PRODUCT_DECISIONS_LOCKED D7.1):
1. Teacher edit window = 24h. Anchor = `recitationRecords.createdAt`, a server
   timestamp written once on creation (new field; the model had only
   `updatedAt`, which moves on every save and would let a Teacher extend the
   window forever). Open while `now < createdAt + 24h`; a missing anchor fails
   closed (Admin only). `now` is the server clock; no request field is read.
2. Admin creates or corrects at any time through the same callable, keeping the
   real-session / roster / Present-Late gates. An Admin correction keeps
   `teacherId` (the halaqa Teacher) and never moves `createdAt`.
3. Audit scope — resolved: every create / Teacher correction / Admin
   correction emits `evaluation_create_or_correct` with the server-derived
   actor (`PH02_SUPERVISOR_AUTHORITY_REVIEW.md` §6).

Hardening that came with the anchor: student homework submissions can no
longer claim a live-evaluation id (`*_memorization` / `*_review`) or write
`createdAt` (rules), and the callable refuses to adopt any non-live document
found at the evaluation id.

Everything PH-02 already enforces is unchanged: real `sessionId`, the D7
Present/Late gate, the server transaction, synthetic-session rejection, the
attendance operational-day window, and the Admin attendance-correction audit.

### Points (`studentProfiles.points`)

- **Uses:**
  - Written by `completeHomework` (the homework reward, server) and by staff awards (+10 per recipient).
  - Read into `StudentProfileEntity.points` only.
  - **No screen, stat, ranking, query, spending path or notification reads it.** The "ربحت X نقطة" snackbar uses the callable's return value, not the profile field. Per-task `tasks[].points` are a separate homework-display field.
- **Authority:** now server-only (`completeHomework`, `grantAward`). Rules deny every client role.
- **Decision: QUARANTINE.** Authority is closed, but the field has no product consumer. No economy was invented and nothing was removed. The product must decide whether it is ever shown, ranked or spent.

### Stars (`studentProfiles.totalStars`)

- **Uses:**
  - Written only by the staff award flow (+1 per recipient per award).
  - Read by the Student home header, the Student profile stat "نجمة" and the Student achievements header.
  - Not read by Parent, Teacher, Supervisor or Admin screens. No ranking, spending or notification.
- **Authority, before:** client batch writes, allowed by the rules as a bounded but repeatable increment with no award record behind it.
- **Authority, now:** server-only through the `grantAward` callable.
- **Decision: COMPLETE.** The purpose is clear (a Student-visible count of awards received), and the award feature is locked (SECURITY_IMPLEMENTATION_SPEC §2 awards row; D18 "Grant award"; D21 award history).

Derived award contract. Nothing new was invented; it comes from the locked matrix plus existing product values:

| Item | Contract | Source |
|------|----------|--------|
| Who grants | Admin (any halaqa), Supervisor (supervised halaqat), Teacher (own halaqat) | Spec §2 awards row |
| To whom | Students on the roster of a scoped halaqa | Spec §2 ("own halaqa") |
| Credit | +10 `points`, +1 `totalStars` per recipient, applied by the server | Pre-PH-02 constants in the awards datasource |
| Repeatable | Yes; each award is a new record | Existing behavior |
| Revoke | No — `achievements` update/delete denied | Existing rules |
| Audit | The `achievements` doc is the record (grantor, time, recipients); awards are not in the §20.1 must-audit list | §20.1 |
| Client input | Intent only: award id, type, title, description, image, halaqa scope, recipients — never an amount or a balance | This patch |
| Supervisor home "issue achievement" | Record only, no counter change — unchanged existing behavior | Existing behavior |

## B. Economy Classification

| Field | Classification | Source | Writer | Consumer | Action |
|-------|----------------|--------|--------|----------|--------|
| `coins` | KEEP | Homework reward / avatar price | `completeHomework` (+), `purchaseAvatar` (−) — server | Student home header, avatar shop | None (PH-02 final) |
| `points` | QUARANTINE | Homework reward, award | `completeHomework`, `grantAward` — server | None in UI | Client writes denied; purpose is a product decision |
| `totalStars` | COMPLETE → done | Award | `grantAward` — server | Student home, profile, achievements | Moved to callable (this patch) |
| `unlockedAvatarIds` | KEEP | Avatar purchase | `purchaseAvatar` — server | Avatar selection page | None |
| `avatarId` | KEEP | Avatar selection | `purchaseAvatar` — server; default at provisioning | Avatars across the app | None |
| `lastCompletedHomeworkId` | QUARANTINE | Homework completion | `completeHomework` — server | None | Server bookkeeping only; no action |

## C. Code Changes (this patch only)

- `functions/src/awards/awardFunctions.ts` (new): the `grantAward` callable.
  - Checks role and halaqa scope, and requires every recipient to be on a scoped roster.
  - Validates the award type, the image path (bound to the grantor's folder) and a recipient cap.
  - Writes the award doc and the counter credits in one transaction.
  - Idempotent on a client-generated `awardId`.
  - Gated by `assertBackendAllowed`.
- `functions/src/index.ts`: exports `grantAward`.
- `firestore.rules`:
  - `points` and `totalStars` added to `serverOwnedProfileFields()`.
  - `staffAwardIncrement` removed; `studentProfiles` update is now Admin-only for safe fields.
- `lib/features/awards/data/datasources/award_remote_datasource_impl.dart`: the image upload is unchanged; the client now calls `grantAward` instead of batch-writing profiles.
- `lib/core/di/injection_container.config.dart`: `FirebaseFunctions` is injected into the awards datasource.
- Tests:
  - Functions unit tests: +4 (type-key parity with Dart, fixed credit values, role scope, image path).
  - Functions emulator: +7 (credit once, replay, concurrent replay, repeatable, scoped Supervisor/Admin, denials, bad input).
  - Rules: three old "staff increment allowed" tests converted to denials across all roles.
  - Flutter: new `test/security/ph02_award_authority_contract_test.dart` (+3).
  - Lint: `const` fix in `test/shared/evaluation_policy_test.dart`.
- Docs: `PH02_DEPLOYMENT_ORDER.md` updated (`grantAward`, award smoke check, evaluation blocker wording).

## D. Tests

| Suite | Before | After |
|-------|--------|-------|
| Firestore rules | 166/166 | **166/166** |
| Storage rules | 31/31 | **31/31** |
| Functions unit tests | 228/228 | **232/232** |
| PH-02 Functions emulator | 33/33 | **40/40** |
| Flutter full | 689 pass / 2 skipped | **692 pass / 2 skipped** |
| `flutter analyze` | 120 issues, 0 errors | **120 issues, 0 errors** (none in changed files) |
| `dart format` (changed Dart files) | — | clean |
| Encoding (changed files) | — | UTF-8, no BOM, no mojibake |

## E. Remaining Follow-ups

**Business decisions (none blocking PH-02)**
- ~~The evaluation edit contract~~ — resolved (B1/B2, §A).
- The purpose of `points`: display, ranking or spending, or eventual removal.
- D11 `versesRange` source/format for live evaluations (product/data-contract follow-up with the Wave C progress projector).

**Data minimization (documented only; no `publicProfiles` schema invented)**

| Read | Who can read today | What screens actually need | Exposure |
|------|--------------------|----------------------------|----------|
| `users/{uid}` single get | Any signed-in user (phone already moved to `userPrivate`) | Chat participant hydration, guardian name on the staff Student Profile, a Parent reading a child: `name`, `role`, `profileImageUrl` | **`email`** is on `users` and readable by every role |
| `users` list | Admin, staff; Student/Parent only for Admin docs (PH-02) | Admin/teacher directories; Parent "contact Admin" | Staff can list every user incl. `email` |
| `studentProfiles` | Admin, every Teacher/Supervisor (unscoped), self, linked parent, same-roster students | Staff roster/profile screens: name, avatar, halaqa, progress, stars | Staff read students outside their halaqat (§16.3 wants a halaqa scope) |
| `parentProfiles` | Admin, self, every Teacher/Supervisor | Teacher "contact parent" and the Student Profile guardian lookup need only the **parent id(s)** of one student | `childrenIds` (all siblings) readable by all staff (§16.2 "beyond need-to-know") |

Rules can't scope these reads without a projection (they can't iterate
`childrenIds` or check roster membership for list queries). The fix needs a
frozen projection or search-index contract (§16.3 "Engineering TBD"), so it
stays a follow-up. The `users` directory-scan restriction for Student/Parent
was already closed in PH-02.

**Payment-review UI**
- `reviewPaymentProof` is ready, but there is no Admin or Supervisor review screen.

**Awards (non-blocking)**
- D18 "Grant award" from the Admin Student Profile has no UI.
- There are no award notifications (AUD-031).
- The Supervisor issue path is record-only and gives no star credit (existing behavior; product may want it aligned).

**`publicProfiles`**
- Preferred by spec §5.2, but the fields aren't frozen. Not built.

**App Check**
- Not enabled (spec §22 Wave A plan). Needed against broad scraping.

**Blaze (operational gate, not a business blocker)**
- Cloud Functions need production billing.
- All PH-02 writes and FCM fan-out are server-side; academy notifications stop until Functions are live.
- No deploy in this round.

**Deployment, migrations and smoke tests**
- Follow `PH02_DEPLOYMENT_ORDER.md`: migrations, then indexes, Functions (now including `grantAward`), client with a minimum version, Firestore rules, Storage rules, then smoke tests.
- Emulator results are not production evidence.

## F. Verdict

**CLOSED** (final closure patch).

The points/stars contract is closed (stars COMPLETE via `grantAward`, points
QUARANTINE with server-only authority). The evaluation contract is closed: B1
(Teacher 24h window on a server anchor) and B2 (audited Admin correction) are
implemented and tested, and Supervisor stays read-only. Final suite counts are
in `PH02_SUPERVISOR_AUTHORITY_REVIEW.md` (Verification). Remaining items are
non-blocking follow-ups or deployment-only prerequisites
(`PH02_DEPLOYMENT_ORDER.md`).
