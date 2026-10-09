# PH-02 — Backend Authority Deployment Order

Status: **documented only — nothing in PH-02 has been deployed.**
Verified against emulator project `demo-rafiq-rules` only. Emulator results are
not production evidence; each step below needs its own smoke check in the real
project.

## Deploy targets

| Alias (`.firebaserc`) | Firebase project |
|---|---|
| `dev` | `rafiq-academy` |
| `staging` | `rafiq-academy-staging` |
| `prod` | `rafiq-academy-prod` |

**Project status:** `rafiq-academy` is the existing dev project.
`rafiq-academy-staging` and `rafiq-academy-prod` have **not** been created yet.
Defining an alias in `.firebaserc` does not create a Firebase project; creating
each project and configuring its billing and permissions are separate
prerequisites before anything can be deployed to it.

There is no `default` alias. Every deploy names its project explicitly
(`firebase deploy --only ... --project <alias>`) and never relies on
`firebase use` or the CLI's active project. Functions deploy through
`npm run deploy:dev` / `deploy:staging` / `deploy:prod` in `functions/`,
which call `scripts/deploy-functions.mjs <target>`. The wrapper checks the
alias against `.firebaserc`, refuses any extra argument (so
`npm run deploy:dev -- --project prod` or `-- --only firestore` fails before
building), and then runs only `npm run build` and
`firebase deploy --only functions --project <target>`. `deploy:prod` also
refuses to run unless `CONFIRM_PROD_DEPLOY=rafiq-academy-prod` is set.
Each step below runs against staging first.

Known limitation: the read-only `logs:*` scripts still pass npm-forwarded
arguments to the Firebase CLI, so `npm run logs:dev -- --project prod` reads
production logs. They cannot deploy or write.

## Local emulator testing (separate from deploys)

Emulator testing never deploys and never targets `dev`, `staging` or `prod`.
Use only `npm run serve` in `functions/`, which calls
`scripts/serve-emulators.mjs`. It takes no arguments (any extra argument is
refused before building), builds, and then runs exactly
`firebase emulators:start --project demo-rafiq-rules --only auth,firestore,functions,storage`.

In emulator mode (`FUNCTIONS_EMULATOR=true`) Functions require a `demo-*`
project: startup fails if any resolved project ID (`FIREBASE_CONFIG`,
`GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, Admin app options) is not `demo-*`
or none can be resolved, and the backend gate does not open for the emulator
in that case. With a real project ID, the Functions emulator would send calls
for non-emulated services to that real project.

Avoid a bare `firebase emulators:start` or other ad hoc emulator commands:
without `--project`, the Firebase CLI falls back to its user-level active
project for this folder, which can be a real project. The Functions emulator
test suites (`functions/test/*.emulator.test.mjs`) refuse to run unless the
project ID is `demo-*`. The `rules_test/` suites default to `demo-rafiq-rules`
and are normally run with `--project demo-rafiq-rules`, but do not
independently enforce a `demo-*` project.

## 0. Preconditions (blocking)

| Gate | Why |
|------|-----|
| **B-BILLING / Blaze verified** (operational) | Every PH-02 transition (payment review, attendance, evaluation, membership, homework reward, avatar purchase, staff award, notification fan-out) now runs in Cloud Functions. Client-side notification fan-out was removed, so academy notifications stop until Functions are live. |
| ~~Evaluation edit contract decided~~ — **resolved** (D7.1) | Teacher edits for 24h from the server-set `recitationRecords.createdAt`; Admin corrects at any time; Supervisor read-only; every create/correction audited. No longer a gate. |
| **PH-01 deploy gates done** | `adminMigrateUserPhones` must have emptied every `users.phone` before the PH-01/PH-02 rules ship. |

## 1. Data migrations (Admin callables, run once, idempotent)

1. `adminMigrateUserPhones` (PH-01) — confirm zero remaining `users.phone`.
2. `adminMigrateHalaqaSlotIds` (WA-7) — every `schedule[]` slot carries a
   stable `slotId`. `recordSessionAttendance` fails closed on slots without it.
3. `adminBackfillStudentSearch`, `adminBackfillStudentLifecycle` (WA-14/15)
   if not already run.

No PH-02 migration rewrites historical attendance or evaluation documents.
Legacy synthetic-session docs stay readable (client dual-read) and are only
retired when the same student/day is re-saved through the new callables.

`createdAt` (the B1 edit-window anchor) is not backfilled. Any live evaluation
written before the new callable has no anchor, so the Teacher can no longer
edit it and only Admin can correct it (fail closed). This is intentional: a
backfilled anchor would be an invented creation time.

## 2. Firestore indexes

Deploy `firestore.indexes.json` first and wait until every index is
**READY** — the PH-02 callables query `recitationRecords`
(`halaqaId, studentId, date`) and `attendanceRecords` by session/day.

## 3. Cloud Functions

Deploy all exports in `functions/src/index.ts`. PH-02 additions:

- Callables: `reviewPaymentProof`, `recordSessionAttendance`,
  `upsertSessionEvaluation`, `admitStudentToHalaqa`, `adminTransferStudent`,
  `completeHomework`, `purchaseAvatar`, `grantAward` (award record +
  fixed `points`/`totalStars` credit). `adminTransferStudent` also accepts a
  Supervisor when both halaqat are supervised by the caller (no client UI yet).
- Triggers: `notifyParentsOnEvaluation` (evaluation + homework-review
  fan-out, IDs-only FCM payload), `notifyOnAssignmentCreated`.

Smoke (real project, test accounts only): one attendance save, one
evaluation (exactly one `evaluation_create_or_correct` audit with
`actorRole: "teacher"`, and a server `createdAt` on the document), one Admin
correction of that evaluation (one more audit with `actorRole: "admin"`,
`createdAt` unchanged), one avatar purchase with insufficient coins (must fail), one
admission into a 3rd halaqa (must fail), one Teacher award (recipient
`totalStars` +1 exactly once).

## 4. Client release

Ship the Flutter build that calls the callables above. Old builds still write
attendance / evaluations / membership / coins / award counters directly; those writes start
failing at step 5, so enforce a minimum app version (or wait for adoption)
before step 5.

## 5. Firestore rules

Deploy `firestore.rules`. This is the step that actually closes the client
write paths (payments review, attendance, live evaluation, `studentIds`,
server-owned profile fields, user-addressed notifications, Student/Parent
directory scans, off-roster / multi-recipient client achievements, student
submissions at live-evaluation ids or carrying `createdAt`). Until it ships,
the old paths remain open.

## 6. Storage rules

Deploy `storage.rules` (unchanged in PH-02; redeploy only to keep the
release set consistent).

## 7. Post-deploy smoke

- Each role: login, dashboard, the flows from step 3 through the UI.
- Parent device: receives one push per evaluation (no duplicate on edit).
- Rules: a Student `users` collection list is denied; a Parent can still
  load Admin contacts.

## Rollback

- Functions and client can roll back independently while old rules are live.
- After step 5, rolling back the client without rolling back rules breaks
  attendance, evaluation, admission, avatar and award flows — roll back rules first.
