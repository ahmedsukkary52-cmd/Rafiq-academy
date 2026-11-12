# J.10 release runbook (`rafiq-academy`)

Status: **prepared only — nothing here has been executed.** No build was
made, no Firebase setting or document was changed, nothing was deployed,
exported, migrated or rotated.

Scope: `rafiq-academy` is the only real Firebase project (the `dev` alias;
seed and test data only, `RELEASE_PLATFORM_SETUP.md`). `rafiq-academy-staging`
and `rafiq-academy-prod` are aliases without projects. `demo-rafiq-rules` is
the local emulator. A release to real users needs the prod project first
(`RELEASE_PLATFORM_SETUP.md` B1) and then this runbook repeated there.

Detail lives in `PH02_DEPLOYMENT_ORDER.md` (deploy wrapper, B10 gate, rules
and rollback) and `B14_MEETING_LINKS.md` (meeting links, calendar,
compatibility). This file only orders the J.10 steps and their checks.

## 1. The approved J.10 build

**Source.** The J.10 client exists only as uncommitted changes on top of
`796e3de` in the review worktree; no commit or binary contains it yet. The
approved build is one made from a commit (by the owner) that contains all of
them. Record that commit SHA as the release identity. In that commit:

- `lib/features/parent/data/parent_child_halaqat_response.dart` exists and
  defines `kParentChildHalaqatCallable = 'getParentChildHalaqat'`.
- `supervisor_remote_datasource_impl.dart` and `chat_remote_datasource.dart`
  contain no `teacherProfiles`.
- `CalendarModel.toCreateData` writes `'halaqaId': halaqaId` unconditionally.
- `lib/shared/data/academy_halaqa_firestore.dart` contains no `meetingLink`.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` and `flutter test`
  pass (what Codemagic runs).

**Build number: 2.** Every build since the B10 gate (`9327dc6`), including
`796e3de` and `c66753d`, has `kAppBuildNumber = 1` and `version: 1.0.0+1`.
J.10 uses `version: 1.0.0+2` and `kAppBuildNumber = 2` (Android
`versionCode` and iOS `CFBundleVersion` follow the pubspec; the version name
stays `1.0.0`). `app_build_number_test.dart` checks that the two match and
that the build is above 1. Setting `minimumBuildNumber: 2` in Firebase is a
separate owner step (§4 step 6). Do not pass `--build-number` to
`flutter build`.

**Flavor.** Builds against `rafiq-academy` are the `dev` flavor: Android
`com.example.rafiq_academy` (Codemagic `android-dev`: debug APK), iOS
`com.example.rafiqAcademy` (Codemagic builds iOS unsigned only, so an iOS
test device needs a separately signed build). `prod` cannot start until the
prod project exists.

**Replacing test builds (before the rules deploy):**

1. List every device with the app installed: owner, role tested, platform,
   flavor, how it was installed.
2. Install the approved build on each device (uninstall the old one first if
   the signature differs).
3. Confirm the installed build: Android
   `adb shell dumpsys package com.example.rafiq_academy | findstr versionCode`
   shows the approved number (the in-app label shows only `1.0.0`).
4. Sign in with each role used on that device and reach the role home.
5. Mark the device done. Proceed to the rules deploy only when every listed
   device is done, or the device is withdrawn.
6. Builds older than `9327dc6` have no gate and are never blocked: find and
   replace them explicitly.

## 2. Backend switch `PRODUCTION_BACKEND_ENABLED`

**Mechanism.** `functions/src/productionGate.ts`: a gated callable runs when
`process.env.PRODUCTION_BACKEND_ENABLED === "true"` (exact string) or, inside
the Functions emulator, the project is `demo-*`. Otherwise it throws
`failed-precondition`. It is one switch for every gated callable and job
(23 source files: payment proof and review, billing, overdue grace,
attendance and sessions, evaluation, schedules, membership and lifecycle,
economy, awards, parent achievements and links, chat, search, push,
provisioning, slot-id migration, meeting links, `getParentChildHalaqat`); it
cannot enable only the parent callable. `FCM_OWNERSHIP_ENABLED` is a separate gate and stays off.

**How it is set.** As a deployed Functions environment variable from a
committed dotenv file: `functions/.env.dev` (or `functions/.env.rafiq-academy`)
containing `PRODUCTION_BACKEND_ENABLED=true`. `.gitignore` deliberately keeps
`functions/.env` and `functions/.env.<alias>` trackable (only `.env.local` and
secrets are ignored). The Firebase CLI loads it during
`npm run deploy:dev`, so it takes effect only with a Functions deploy and
applies to all functions. No such file exists; it is not created here. Do
not set the variable by hand in the Cloud Run console: it is untracked and
the next deploy resets it.

**Precondition (blocking).** `FIREBASE_BILLING_CHECKLIST.md` records
**B-BILLING unresolved**; the gate's own message requires it Verified before
the switch. Cloud Functions deploys and Firestore managed exports (§3) also
need the Blaze plan on `rafiq-academy`.

**Enable (owner, after approval).** Create `functions/.env.dev` with the one
line above, commit it with the release, deploy Functions (§4 step 5).
**Disable / roll back:** remove the line (or set `false`) and redeploy
Functions; gated callables then fail with `failed-precondition`.

**Verify `getParentChildHalaqat` after the Functions deploy:**

1. `firebase functions:list --project dev` lists `getParentChildHalaqat`
   (v2, callable, `europe-west1`) next to `setHalaqaMeetingLink`.
2. Cloud console, Cloud Run service `getparentchildhalaqat`: the environment
   shows `PRODUCTION_BACKEND_ENABLED=true`; the service allows
   unauthenticated invocation (callables check Firebase Auth in code).
3. J.10 build, test Parent whose child is on a Halaqa roster: the household
   screen shows the Halaqa name with the teacher and supervisor contact
   rows, and the absence form lists the Halaqa. Symptom of a closed switch:
   the Halaqa name from the child profile with no staff rows.
4. `npm run logs:dev` (read-only): no `failed-precondition`, `internal` or
   `permission-denied` for `getParentChildHalaqat` from that session.
5. Deny cases (non-parent, unlinked child, inactive or profile-less parent,
   bad `studentId`) are proven by `parent_child_halaqat_callable.test.mjs`
   and `parent_child_halaqat.emulator.test.mjs`; the UI cannot send them.

## 3. Backup and read-only data inspection

Goal: before any copy, strip or calendar backfill, know exactly which values
are missing, conflicting or would be lost, from a verified backup, without a
connection from any script to the real project.

`functions/scripts/migration-inspect-release-data.mjs` reads only. It runs
against the isolated `demo-rafiq-rules` emulator loaded with the export, and
prints counts, id digests and capped document ids (no titles, links, URLs or
person ids). It reuses the B14 migration guards (fixed project, egress guard,
hub check, no credentials) and refuses `--apply`, `--confirm` and
`--strip-legacy`.

1. **Export (owner, read-only on data; needs Blaze).** Use a prefix without
   colons so it downloads on Windows:

   ```
   gcloud firestore export gs://<bucket>/rafiq-release-<yyyymmdd-hhmm> --project rafiq-academy
   ```

   Export everything: do not pass `--collection-ids`. A full export has the
   `all_namespaces/all_kinds` layout that the emulator import was rehearsed
   with; a collection export writes `kind_<collection>` folders, which step 3
   refuses. The inspection reads `halaqat`, `halaqaMeetingLinks`,
   `calendarEvents`, `users` and `studentProfiles` (the last two for the
   roster checks of the copy dry run).
2. **Check the operation.**
   `gcloud firestore operations describe <operation> --project rafiq-academy`:
   `state: SUCCESSFUL`; record `outputUriPrefix` and
   `progressDocuments.completedWork` (documents exported).
3. **Download** to an encrypted local folder outside the repository:
   `gsutil -m cp -r gs://<bucket>/rafiq-release-<...> <secure-dir>`. Then,
   from `functions/`, check the layout (reads folder names only):
   `node scripts/migration-check-export-layout.mjs <secure-dir>\rafiq-release-<...>`.
   It must print `"layout":"full","ok":true`; anything else (a `kind_*`
   collection export, a missing `.overall_export_metadata`, the parent folder
   instead of the export folder): stop and export again.
4. **Inspect.** From `functions/` after `npm run build`, with an isolated
   emulator config (Firestore `38080`, hub `34400`, no other emulators, e.g.
   `{"emulators":{"firestore":{"port":38080},"hub":{"port":34400},"ui":{"enabled":false},"singleProjectMode":true}}`):

   ```
   $env:MEETING_LINK_MIGRATION_EMULATOR="1"; $env:MEETING_LINK_MIGRATION_PORTS="38080,34400"
   Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS -ErrorAction SilentlyContinue
   firebase emulators:exec --config <isolated firebase.json> --project demo-rafiq-rules --only firestore --import <secure-dir>\rafiq-release-<...> "node scripts/migration-inspect-release-data.mjs --project demo-rafiq-rules > <secure-dir>\inspection.json"
   ```

5. **Verify the backup.** The emulator log shows `Importing data from
   ...overall_export_metadata`; `backup.totalDocuments` equals
   `completedWork` from step 2; `backup.emptyCollections` is empty; a second
   import gives the same `idsSha256` values. Keep `inspection.json` with the export path. Keep the
   bucket copy until links are rotated and the release is accepted.
6. **Privacy.** The export holds every link and personal field in the
   project. Never commit it or copy it into `impl_logs`; delete the local
   copy after review.

**Reading the report:**

| Field | Meaning | Action |
|---|---|---|
| `backup.emptyCollections` | An inspected collection with no documents: an incomplete export or the wrong project | Export again (full export) before trusting the roster figures |
| `calendarEvents.wouldBackfillToNull`, `review.missingHalaqaIdIds` | General events stored without `halaqaId`: readable by `get`, never listed by the `isNull` month query | Owner decision: backfill to `halaqaId: null` (needs a reviewed runner; none exists) or accept |
| `calendarEvents.review.orphanHalaqaIds` | Events of a deleted Halaqa: only Admin can read them | Review; delete or keep (Admin) |
| `calendarEvents.review.invalidHalaqaIdIds` | `halaqaId` empty, non-string or not a document id: Admin-only | Review |
| `calendarEvents.review.invalidDateIds` | `date` missing or not a Timestamp: never in a month view | Review |
| `meetingLinks.notYetCopied`, `strip.review.needsCopyIds` | Valid legacy link without a canonical document | Copy first; strip keeps them |
| `meetingLinks.lostOnStrip`, `strip.review.supersededLegacyIds`, `copy.review.conflictIds` | Legacy value differs from the canonical link; strip removes it (backup only) | Confirm the canonical link is right; include in rotation |
| `copy.review.invalidIds`, `strip.kept.invalidLegacy` | Invalid legacy value without a canonical document; never stripped | Admin sets a valid link with `setHalaqaMeetingLink` (it removes the legacy key) or accepts |
| `copy.review.malformedIds`, `strip.kept.canonicalMalformed` | Malformed canonical document; blocks the strip | Admin re-sets or clears the link with `setHalaqaMeetingLink` |
| `copy.review.orphanIds` | Canonical link for a missing Halaqa | Review |
| `copy.roster`, `copy.supervisors` | Who can read canonical links | Review |

Rehearsal (emulator only): an export of synthetic data, laid out like a
managed export (`<name>/<name>.overall_export_metadata`, no emulator
metadata file), was imported with `--import` and inspected; counts and
digests matched the source exactly. That export has the full-export layout
(`all_namespaces/all_kinds`), which is why step 1 exports everything and
step 3 refuses the `kind_<collection>` layout of a `--collection-ids`
export (`migration_check_export_layout.test.mjs`; the checker accepts the
rehearsal folders).

**Recovering a single value.** The report never prints link values. To
restore one (for example a `supersededLegacyIds` Halaqa), start the
emulator with `--import` of the backup and the Emulator UI enabled on
`127.0.0.1` only, read `halaqat/{id}.meetingLink` by hand, and have an Admin
set it with `setHalaqaMeetingLink` in the app. Never import a backup back
into the live project to restore one value: `gcloud firestore import`
overwrites every exported document of those collections, undoing all later
changes.

The copy and strip themselves still need an approved real-project runner
(§5); `migrate-meeting-links.mjs` refuses every real project.

## 4. Deployment order (`rafiq-academy`)

Each step: run only with approval; verify; continue only if every check
passes. "Stop" means do not start the next step.

| # | Step | Verify | Stop / roll back |
|---|---|---|---|
| 0 | Preconditions: B-BILLING Verified and Blaze on `rafiq-academy` (`FIREBASE_BILLING_CHECKLIST.md`, evidence list); PH-01 contact cleanup done (`PH02_DEPLOYMENT_ORDER.md` §0–1); the release commit contains build 2 (§1) | Checklist signed | Any open item: stop |
| 1 | Pre-deploy tests on `demo-rafiq-rules`: rules `test:all:firestore`, Functions build and `npm test`, the parent and meeting-link unit and emulator suites, this inspection's suites, `flutter analyze`, `flutter test` | All pass on the release commit | Any failure: stop |
| 2 | Backup and inspection (§3) | Backup verified; every review list accepted by the owner | Unverified backup or unaccepted review ids: stop |
| 3 | Build and distribute the approved build; replace test builds (§1) | Every listed device done | Any device still on an old build without the gate: stop |
| 4 | `firebase deploy --only firestore:indexes --project dev` | Every index READY in the console | Index build error: stop |
| 5 | Functions: `functions/.env.dev` in the release, then `npm run deploy:dev` in `functions/` | §2 verification; PH-02 §3 smoke (incl. `setHalaqaMeetingLink`); logs clean | Deploy error, `failed-precondition` from a gated callable, new error rates: stop; redeploy the previous Functions (old rules still live, so independent) |
| 6 | Create `appConfig/clientVersion` `{ minimumBuildNumber: 2 }` (integer) in the console | Read back: integer 2; an approved-build device reaches home | Wrong type or value: fix or delete the document before step 7 |
| 7 | Save the live rules text from the console Rules tab to a file outside the repo, then `firebase deploy --only firestore:rules --project dev` | On the approved build, per role: Parent household and absence form; Supervisor day board and teachers page; Teacher classes with supervisor names; Student Halaqa and meeting link; calendar Halaqa and general events. An old gated build shows the update screen | Any denied screen on the approved build: publish the saved rules text in the console. Rolling back the client alone does not help (`PH02_DEPLOYMENT_ORDER.md` Rollback) |
| 8 | Fresh backup (§3 steps 1–5), then copy and strip with the approved runner (`B14_MEETING_LINKS.md` §8 step 4) | Re-inspect a new export: `strip.summary.legacyKeysRemaining == 0`, `notYetCopied == 0`, every expected canonical document present | Any failure count, `changedDuringRun` above 0, unaccepted review ids: stop; re-run the dry run (idempotent); restore single values from the backup through `setHalaqaMeetingLink` |
| 9 | Rotation (owner decision): links that sat in `halaqat.meetingLink` before the strip were readable by Parents, Teachers or unassigned staff, plus `supersededLegacyIds` | Each rotated link set through `setHalaqaMeetingLink` (one audit entry each) | — |
| 10 | Calendar backfill only if approved after step 2 | New export: `wouldBackfillToNull == 0` | — |

Between steps 7 and 8, Teacher, Supervisor and Student screens that `get` a
Halaqa still carrying a legacy link are denied (J.9); keep the window short
(`B14_MEETING_LINKS.md` §8).

**Rollback per step:**

| Step | How to undo | Notes |
|---|---|---|
| 4 Indexes | Nothing to undo; indexes are additive | If the CLI offers to delete indexes missing from the file, answer no |
| 5 Functions | Deploy the previous release commit's `functions/` with `npm run deploy:dev` | The CLI asks before deleting functions absent from the older source (e.g. `getParentChildHalaqat`); answer no. Disabling the switch alone: remove the line from `functions/.env.dev` and redeploy |
| 6 `appConfig` | Lower `minimumBuildNumber` or delete the document in the console | A missing document lets every build in (fails open) |
| 7 Rules | Publish the saved rules text in the console | Roll back rules before the client (`PH02_DEPLOYMENT_ORDER.md` Rollback) |
| 8 Copy | Canonical documents created by the run are listed in the run's evidence; removing them needs the runner's rollback path (§5) | Created only where none existed |
| 8 Strip | Not reversible in place; single values from the backup (§3 "Recovering a single value") | Hence the backup and `supersededLegacyIds` review first |
| 10 Calendar backfill | Delete `halaqaId` again on the ids in the runner's evidence (§5) | Only for events the run changed |

## 5. Approved real-project runners (not built)

No script here writes to a real project. Running the copy, strip or calendar
backfill on `rafiq-academy` needs a runner built, reviewed and approved for
that purpose. What it must provide, reusing existing parts:

**Meeting links (copy, then strip).**

- *Target and credentials:* explicit `--project` from the allowlist and a
  confirmation token naming it (as `migrate-guards.mjs` does for the contact
  cleanup); the credential file's `project_id` must match; emulator variables
  are refused; the project the SDK actually resolved is compared with the
  target (`connectionTargetProblem` in `meeting-link-migration-core.mjs`).
- *Plan:* a dry-run scan produces a plan with a digest
  (`buildMigrationPlan`); the owner approves that digest; the plan expires
  after 24 h; drift since the scan stops the run (`detectPlanDrift`).
- *Lock:* one create-only run lock with write fencing
  (`migrationLocks`, `decideLockAcquisition`, `decideLockRelease`).
- *Writes:* the existing per-Halaqa transactions only (`tx.create` of a
  missing canonical document; `tx.update` deleting `halaqat.meetingLink` when
  `decideStrip` allows it), with outcome and manifest records in
  `migrationRuns` so an ambiguous commit is resolved from evidence
  (`resolveUncertainCommit`), not guessed.
- *Conflicts:* the copy never overwrites an existing canonical document. A
  legacy value that differs from the canonical one (`supersededLegacyIds`)
  is stripped only if its id is in the approved plan and the verified
  backup (§3) holds it; any other conflict is kept and reported. The
  emulator-only strip in `migrate-meeting-links.mjs` reports these ids
  (`needsReview`) but does not hold them back, so it is not this runner.
- *Rollback:* only from recorded evidence (`rollbackEvidence`,
  `decideRollbackDelete`); the strip is reversible only from the backup.
- *Output:* counts, reason codes and ids; never a link.
- *Verification:* re-inspect a new export (§3) and apply the release gate
  (`releaseGateDecision`).
- *Before approval:* unit tests, an emulator suite (including concurrent
  runs and lost acknowledgements, as the current emulator suites do), a run
  on an imported backup in the emulator, and code review.

The core module states which obligations it cannot prove (same transaction
for read set and write, real SDK target, loaded code versions); those are the
runner's to prove.

**Calendar backfill (`halaqaId` missing → `null`).**

- Same target, credential and token checks (token
  `calendar-halaqa-null-backfill:<projectId>`); dry run by default.
- Scope: `calendarEvents` documents where the `halaqaId` key is absent,
  as listed by the inspection; orphan, invalid and date problems are
  reported only.
- Write: `update({ halaqaId: null })` with a `lastUpdateTime` precondition
  from the read (as `migrate-contact-fields.mjs` does); no other field; a
  document changed since the read is skipped.
- Evidence: the ids changed and their new update times, for a rollback that
  deletes `halaqaId` only where it is still `null` and unchanged.
- Verification: a new export shows `wouldBackfillToNull == 0`.
- Tests: unit (classification, refusals), emulator (precondition failure,
  concurrent app write, idempotent re-run).

A new production project starts without this legacy data, so neither runner
is needed there.

## 6. Functions tests outside `npm test`

`npm test` runs the fixed list in `test:wave-a` of the protected
`functions/package.json`; these are not in it and run only by hand:

| Kind | File |
|---|---|
| Unit | `parent_child_halaqat_callable.test.mjs`, `migration_inspect_release_data.test.mjs`, `fcm_ownership_gate.test.mjs`, `migration_check_export_layout.test.mjs` |
| Firestore emulator (B14 migration env) | `migrate_meeting_links.emulator.test.mjs`, `meeting_link_migration_core.emulator.test.mjs`, `migration_inspect_release_data.emulator.test.mjs` |
| Emulator (emulators and env per file header) | `parent_child_halaqat.emulator.test.mjs`, `fcm_ownership_gate.emulator.test.mjs`, `fcm_token_ownership.emulator.test.mjs`, `migrate_audit_contact_data.emulator.test.mjs`, `migrate_scripts.emulator.test.mjs` |

Unit: `node --test test/<file>` from `functions/` after `npm run build`.
B14 migration env suites, from a folder holding an isolated config
(Firestore `38080`, hub `34400`):

```
$env:MEETING_LINK_MIGRATION_EMULATOR="1"; $env:MEETING_LINK_MIGRATION_PORTS="38080,34400"
firebase emulators:exec --config <isolated firebase.json> --project demo-rafiq-rules --only firestore "node --test --test-concurrency=1 <repo>/functions/test/<file>"
```

The other emulator files use their own opt-in variables, ports and emulators
(for example `AUDIT_EMULATOR_IT`, `MIGRATE_EMULATOR_IT` with Auth), stated in
each file's header. Adding them to `npm test` needs an approved change to
`functions/package.json`.

**Proposed change (owner approval).** Only the four unit files, appended to
the end of the `test:wave-a` value, after `test/migrate_meeting_links.test.mjs`:

```
 test/parent_child_halaqat_callable.test.mjs test/migration_inspect_release_data.test.mjs test/fcm_ownership_gate.test.mjs test/migration_check_export_layout.test.mjs
```

No other key, dependency or the lockfile changes. Together they pass on
Node 22 without an emulator. The emulator suites stay manual, like the
existing `test:*:emulator` scripts, because they need an isolated emulator
config and opt-in variables.
