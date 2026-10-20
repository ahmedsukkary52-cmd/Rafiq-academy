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
- B14: `setHalaqaMeetingLink` (Admin set/update/clear; assigned Supervisor
  add-only) and the shared link validation in `adminCreateHalaqa`. Step 5
  removes the only other `meetingLink` write path, so this callable must be
  live and smoke-checked before step 5.

Smoke (real project, test accounts only): one attendance save, one
evaluation (exactly one `evaluation_create_or_correct` audit with
`actorRole: "teacher"`, and a server `createdAt` on the document), one Admin
correction of that evaluation (one more audit with `actorRole: "admin"`,
`createdAt` unchanged), one avatar purchase with insufficient coins (must fail), one
admission into a 3rd halaqa (must fail), one Teacher award (recipient
`totalStars` +1 exactly once). B14: an Admin sets, updates and clears a test
halaqa's link (one `halaqa_meeting_link_change` audit each, no URL in it);
the assigned Supervisor can add a link only while none is stored; another
Supervisor, a Teacher and a Student are denied; an `http://` link is rejected.

## 4. Client release

Ship the Flutter build that calls the callables above. Old builds still write
attendance / evaluations / membership / coins / award counters directly; those writes start
failing at step 5, so enforce a minimum app version (or wait for adoption)
before step 5.

**B10 minimum-version gate.** The build carries a gate that reads the public
document `appConfig/clientVersion` before restoring the session and again
whenever the app returns to the foreground. Schema:

| Field | Type | Required | Meaning |
|---|---|---|---|
| `minimumBuildNumber` | integer, 1 to 2100000000 | yes | Builds whose number is lower see a blocking Arabic update screen. |
| `androidUpdateUrl` | `https://` string | no | Store link for the Android update button. |
| `iosUpdateUrl` | `https://` string | no | Store link for the iOS update button. |

Store it as a Firestore integer, not a double. Other fields are ignored. If
the document is missing or malformed, or the server and cache are both
unreachable, the app is allowed (fails open). A URL that is present but not a
valid `https` link with a host makes the whole document malformed. With no
URL for the platform, the screen shows retry only. No store URLs exist yet,
so no update button appears until they are added.

Rules: anyone, signed out included, may `get` only this document; `list` and
every client write (Admin included) are denied. Change it only through the
approved deployment procedure (Firebase console or Admin SDK by the release
owner), never from the app.

Order:

1. Bump the `+N` in `pubspec.yaml` and `kAppBuildNumber` in
   `lib/core/constants/app_build_number.dart` together;
   `test/core/constants/app_build_number_test.dart` fails if they differ.
   The gate compares against `kAppBuildNumber`, the constant compiled into
   the app, not the store build number. Do not pass `--build-number` to
   `flutter build` unless the constant is changed to the same value. If the
   store number is overridden (say 42) while `kAppBuildNumber` stays lower
   (say 1), setting `minimumBuildNumber` to the store number makes the newest
   build block itself; recovery is lowering the value in the console.
2. Create `appConfig/clientVersion` with `minimumBuildNumber` not exceeding
   the `kAppBuildNumber` compiled into the gated build being distributed,
   before distributing that build.
3. Verify before distributing: read the document back (console or Admin SDK)
   and confirm `minimumBuildNumber` is an integer no higher than that
   `kAppBuildNumber`, and that any store URL is the intended `https` link.
   Open the gated build on a test device and confirm it reaches login or the
   role home, not the update screen. Before §5 (Firestore rules deployment),
   the gate fails open. Therefore, repeat the device check once the Firestore
   rules deployment is live.
4. Distribute the gated build and replace every older build on test devices.
   Builds made before B10 have no gate and cannot be blocked; they must be
   replaced by hand.
5. Only then deploy step 5. The `appConfig` read rule ships in the same
   `firestore.rules` file, so before step 5 the gate's read is denied and the
   gate fails open; it starts blocking only after step 5 is live.
6. For later breaking changes, raise `minimumBuildNumber` to the first
   compatible build's `kAppBuildNumber` before deploying the change, after
   the same read-back and device check.

## 5. Firestore rules

Deploy `firestore.rules`. This is the step that actually closes the client
write paths (payments review, attendance, live evaluation, `studentIds`,
server-owned profile fields, user-addressed notifications, Student/Parent
directory scans, off-roster / multi-recipient client achievements, student
submissions at live-evaluation ids or carrying `createdAt`, and direct Admin
writes of `halaqat.meetingLink`). Until it ships, the old paths remain open.

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
- After step 5, rolling Functions back to a build without `setHalaqaMeetingLink`
  leaves no way to change a meeting link until rules are rolled back too.
