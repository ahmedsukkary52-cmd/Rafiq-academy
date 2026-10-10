# Demo Academy Dataset

Permanent development dataset for Rafiq Academy. Created by expanding
`tool/seed_firestore.dart` (implementation: `tool/demo_academy_dataset.dart`).

## Status

The Dart seeder below writes with the client SDK, so the current
`firestore.rules` deny its writes (the first write, `academies/*`, has no rule
and hits the catch-all deny). It is kept until the Node seeder reaches data
parity. See "Node emulator seeder" for the replacement.

## How to run (Dart seeder)

The only target is `emulator` (`demo-rafiq-rules`). `dev`, `staging` and
`prod` are refused before Firebase is initialized; real projects are
configured outside the demo tools. The seeder prints `Target:` and `Project:`
before any write.

Start the emulators only through the fixed entry point, then seed in a
second terminal:

```bash
cd functions && npm run serve
flutter run -d windows -t tool/seed_firestore.dart --dart-define=SEED_TARGET=emulator
```

`npm run serve` builds Functions and then runs exactly
`firebase emulators:start --project demo-rafiq-rules --only auth,firestore,functions,storage`.
It rejects any extra argument (`npm run serve -- --project ...` fails before
building). Functions loaded by the emulator refuse to start unless the
project is a `demo-*` project, and the backend gate stays closed otherwise.

Do not start emulators with a bare `firebase emulators:start` or other ad hoc
commands: without `--project`, the Firebase CLI uses its user-level active
project for this folder, which can be a real project.

The `emulator` target uses fake emulator-only credentials (no real API key or
app ID) and connects Auth to `127.0.0.1:9099` and Firestore to
`127.0.0.1:8080` before any read or write.

Default password for **all** accounts: `SeedDemo123!` (emulator only).

The Dart seeder is idempotent (fixed Auth emails + document IDs).

## Node emulator seeder (`npm run seed:emulator`)

`functions/scripts/seed-emulator.mjs` seeds with firebase-admin against the
local emulators only. It takes no arguments and fails closed, in order:

1. Refuses extra Node options before anything else (exit 64): a non-empty
   `NODE_OPTIONS`, any `node` command-line option (`process.execArgv`), or
   `npm_config_node_options` (npm `node-options`). Values are never printed.
   This catches accidental preloads (`--require`, `--import`, `--loader`,
   `--inspect`, ...); code preloaded on purpose could still falsify it.
2. Refuses any argument (exit 64).
3. Reads the auth / firestore / hub / ui ports from `firebase.json`; all four
   must be pinned there (9099 / 8080 / 4400 / 4000), because the Firebase CLI
   moves an unpinned hub or UI to another free port. Hosts, when set, must be
   `127.0.0.1`, and the UI must not be disabled.
4. Refuses the environment if `GOOGLE_APPLICATION_CREDENTIALS`,
   `CLOUDSDK_CONFIG` or `GOOGLE_API_USE_CLIENT_CERTIFICATE` is set, gcloud
   application default credentials exist on
   disk, any project variable (`GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`,
   `GCP_PROJECT`, `CLOUDSDK_CORE_PROJECT`, `FIREBASE_CONFIG.projectId`) is not
   exactly `demo-rafiq-rules`, a proxy variable is set, or a pre-set emulator
   host differs from `127.0.0.1:<firebase.json port>`. The `demo-` prefix is
   not trusted on its own.
5. Installs a network allowlist on this process's `net` and `dns` modules
   before firebase-admin loads: TCP only to `127.0.0.1` / `::1` on the
   auth, firestore, hub and UI ports, and no `node:dns` lookups except
   loopback literals. A self-test must pass. It sets
   `METADATA_SERVER_DETECTION=none`, otherwise the Firestore client library
   probes the GCE metadata server. Not covered: UDP, native addons, worker
   threads and child processes; the libraries' two child-process paths
   (`gcloud` project lookup, mTLS cert provider) are kept unreachable by
   step 4.
6. Checks readiness over `127.0.0.1`: the hub lists auth and firestore on the
   expected ports, Auth reports `ready`, Firestore answers `Ok`.
7. Proves the running suite belongs to `demo-rafiq-rules` (exit 64 if any
   evidence is missing or disagrees). `singleProjectMode` is not evidence: the
   CLI only logs a warning for another project.
   - Hub `GET /`: the hub's `pid`, `version` and `origins`.
   - `hub-demo-rafiq-rules.json` in the OS temp directory, which the CLI
     writes when a hub starts for that project: same `pid`, `version` and
     `origins`. The file is only read, never created, repaired or deleted.
   - Hub `GET /emulators`: hub, auth, firestore and ui on `127.0.0.1` and
     the pinned ports.
   - Emulator UI `GET /api/config` (same CLI process): `projectId` is exactly
     `demo-rafiq-rules`, and its emulator entries equal the hub's.
8. Loads firebase-admin for `demo-rafiq-rules` and re-checks the project and
   emulator hosts.
9. Reads Auth users, root collections and `_seedMeta/demo`. Any blocked
   connection, any existing data, or a leftover seed marker refuses the run.
   If the marker is `in_progress`, it also prints a read-only diagnosis (see
   "After a failed run") and still refuses.
10. Writes with `create()` only: `_seedMeta/demo` (`in_progress`, with the
    hub `pid` and CLI version for diagnosis only), Auth users with fixed
    UIDs, one batch of documents, read-back verification, a check that no
    connection was blocked, then `_seedMeta/demo` (`complete`). Each step
    waits at most `SEED_STEP_TIMEOUT_MS` (60 s). The seeder never retries a
    step itself; firebase-admin and its client libraries may retry some
    requests internally under their own policies, which differ by operation.
    After any failure or timeout the seeder sends no further write and exits
    1. A write already sent, including the one that sets `complete`, may
    still be applied later, even after the seeder has exited.

Dataset v1 is six accounts (`admin@`, `supervisor1@`, `teacher@`, `parent@`,
`student01@`, `student02@rafiq.demo`, UIDs `demo-<role>-NN`) with the same
`users`, `userPrivate` and role-profile fields `adminProvisionUser` writes.
`users` documents never carry `phone`.

### After a failed run

There is no reset, no rollback and nothing is deleted. The run is not
atomic: Auth users are created one by one. Any failure exits 1, and after
it the seeder sends no further write. The failed step's own request may
still have been applied ("landed" before its error) or may be applied later,
even after the seeder has exited. So a run that failed or timed out while
completing `_seedMeta/demo` can still leave it `complete`.

| Failed step | What may remain |
|---|---|
| Creating `_seedMeta/demo` | Nothing else was written; the marker may or may not exist. |
| An Auth user (first, middle or last) | The marker (`in_progress`), the earlier users, possibly that user. |
| The document batch | The marker and all users; the batch is all-or-nothing, so either none or all of its documents. |
| Read-back verification, or its reads | Everything was written; it did not verify. |
| Pre-completion blocked-connection check | Everything was written; the marker stays `in_progress`. |
| Completing `_seedMeta/demo` | Everything was written and verified; the marker may be `in_progress` or `complete`, so treat the dataset as unverified. |

Firestore triggers run in the background in the Functions emulator. Writing
`users` and `studentProfiles` starts `projectStudentSearchOnUserWrite` and
`projectStudentSearchOnProfileWrite`, which may create `studentSearch/{id}`
after the seeder has stopped, including after a failed run. The seeder
never writes `studentSearch`, and any data found there makes the next run
refuse. The reviewed trigger list is pinned by
`functions/test/seed_emulator_triggers_contract.test.mjs`.

**Timeouts.** A step that gets no answer within 60 s stops the run: no
further write is sent, and the error says `Seed stopped during <step>`. The
timeout only stops waiting. It does not cancel the request, which may still
be applied later, so the emulator may hold more data than the run saw. A
timeout is not proof that the write failed or that nothing was written.

**Diagnosis.** When a later run finds `_seedMeta/demo` in `in_progress`, it
refuses and then prints a read-only diagnosis. It runs after the same guards
and identity checks, only reads (`getUser` and document `get`), and prints
UIDs and counts, never emails, names or phone numbers:

- which of the dataset's demo accounts exist, and how many Auth users exist
  (one page; it says when there may be more);
- for each dataset collection, how many of the dataset's fixed document IDs
  exist, and which other root collections (for example `studentSearch`) are
  present.

Only the dataset's fixed IDs are checked, so the counts are not a complete
inventory. A read it could not do is reported as unknown, never as absent. If
the diagnosis itself fails, it reports the failure, which says nothing about
which data exists. If the network allowlist blocks a connection attempt
during the diagnosis, that is reported too and the output is treated as
incomplete. The diagnosis never makes the session acceptable for
seeding.

A `complete` marker is refused as well. It means the dataset looks complete,
not that the run which wrote it succeeded. If a probe or an unexpected error
leaves the marker's state undetermined, the seeder says it is unknown
rather than guessing.

- Do not re-run the seeder against a session where it failed while writing.
- Always start the emulators with `npm run serve` only: never `--import` or
  `--export-on-exit`, which would carry data into the next session.
- To retry, stop `npm run serve` (Ctrl+C in its terminal), start a new
  session with `npm run serve`, then run `npm run seed:emulator`.
- Stopping and restarting does not by itself prove the emulator is empty.
  The seeder's own pre-write checks (step 9) decide whether the new session
  is accepted; if they refuse, investigate instead of working around them.

### Node versions

The Firebase CLI, the Functions emulator, the seeder and the unit tests all
run on the host's Node (currently Node 24). `functions/package.json`
`engines.node` is `"20"`, and that is the runtime used on deploy. When the
requested major version is not installed locally, the CLI prints a warning and
runs the Functions emulator on the host's Node instead. So local runs do not
prove Node 20 behavior. No `.nvmrc` is provided.

### Deploy exclusion and status

The seeder files (`seed-emulator*.mjs`) are excluded from the Functions
upload by `firebase.json` → `functions.ignore`.

The seeder has not been run against the emulators yet; its guards are
covered by `functions/test/seed_emulator_*.test.mjs`.

## What is created (Dart seeder dataset)

The sections below describe the Dart seeder's full academy. The Node
seeder's dataset v1 is only the six accounts listed above.

### Academy
| Doc | Contents |
|---|---|
| `academies/demo_academy_rafiq` | Name, city, current semester, semester dates, settings |

### Users (Auth + `users/{uid}`)

| Count | Role | Email pattern |
|---:|---|---|
| 1 | Admin | `admin@rafiq.demo` |
| 2 | Supervisors | `supervisor1@rafiq.demo`, `supervisor2@rafiq.demo` |
| 3 | Teachers | `teacher@rafiq.demo`, `teacher2@rafiq.demo`, `teacher3@rafiq.demo` |
| 20 | Students | `student01@rafiq.demo` … `student20@rafiq.demo` |
| 12 | Parents | `parent@rafiq.demo`, `parent02@rafiq.demo` … `parent12@rafiq.demo` |

Legacy Auth aliases still created for older tooling: `supervisor@rafiq.demo`, `student1@rafiq.demo`, `student2@rafiq.demo`.

### Halaqat (3 active)

| ID | Name | Teacher | Supervisor | Students |
|---|---|---|---|---|
| `demo_halaqa_morning` | حلقة الفجر | `teacher@rafiq.demo` (عبدالله الحربي) | supervisor1 | student01–08 |
| `demo_halaqa_afternoon` | حلقة العصر | same teacher (2 halaqat) | supervisor2 | student09–14 |
| `demo_halaqa_evening` | حلقة المساء | teacher2 | supervisor1 | student15–20 |

Each halaqa has Arabic weekday schedule slots including **today**.

### Membership links
- `halaqat.studentIds`
- `studentProfiles.halaqaId` / `halaqaName`
- `teacherProfiles.halaqatIds`
- `parentProfiles.childrenIds` (parent@ has أحمد + سارة)

### Realistic scenarios
- **Outstanding student:** أحمد محمد (student01) — high points, weekly award, completed homework, excellent reviews
- **Overdue homework:** سارة علي (student02)
- **Newly enrolled:** فيصل تركي (student09) — recent `createdAt`
- **Parent with two children:** `parent@rafiq.demo`
- **Teacher with two halaqat:** `teacher@rafiq.demo` → morning + afternoon
- **Supervisor on multiple halaqat:** supervisor1 → morning + evening

### Sessions (`calendarEvents`)
Yesterday (completed), today (morning/afternoon/evening), tomorrow, next-week exam — status notes on docs.

### Attendance
Multi-day history (last 3 days + today) for morning & afternoon: mix of `present` / `late` / `absent`.  
Sara yesterday = absent + **approved** absence request (excused scenario).  
*(Domain status enum has no `excused`; excused = absent + approved استئذان.)*

### Homework
Completed, late/overdue, pending due tomorrow, pending due today (feeds Teacher pending tasks).

### Reviews
Several reviewed recitations (mixed grades) + 3 pending reviews for morning halaqa.

### Awards
Teacher grants (طالب الأسبوع، نجوم الأداء) + supervisor badge — dual-write schema via `AchievementsFirestoreContract`.

### Notifications
- **Admin announcements** (`channel: admin_ops_broadcast`): 2 teacher-targeted + 1 `all`  
  Newest teacher body:  
  `تذكير: موعد رفع التقييمات الشهرية غداً قبل الساعة 12 ظهراً`  
  → appears on Teacher Home automatically.
- Role/personal mix: teacher, teacher2, students, parent — read + unread.

### Posts
Admin (pinned), teacher morning/evening, supervisor — mixed dates; `audienceTarget` `all` or halaqa id.

### Teacher Home expectations (login `teacher@rafiq.demo`)
- Real student / session / pending / messages stats
- Today’s featured session from schedule
- Administrative announcement (newest admin ops broadcast)
- Recent activities (reviews, attendance, awards)
- Notification badge (unread)

## Credentials cheat-sheet

All passwords: **`SeedDemo123!`**

| Role | Email | Name |
|---|---|---|
| Admin | admin@rafiq.demo | خالد عبدالرحمن |
| Supervisor | supervisor1@rafiq.demo | فهد السبيعي |
| Supervisor | supervisor2@rafiq.demo | نورة القحطاني |
| Teacher (Home) | teacher@rafiq.demo | عبدالله الحربي |
| Teacher | teacher2@rafiq.demo | سارة العتيبي |
| Teacher | teacher3@rafiq.demo | يوسف الدوسري |
| Parent (2 kids) | parent@rafiq.demo | محمد العتيبي |
| Parent | parent02@rafiq.demo … parent12@rafiq.demo | (see seeder printout) |
| Student | student01@rafiq.demo … student20@rafiq.demo | (see seeder printout) |

Full list is printed by the seeder on success.

## Related
- `tool/seed_teacher_flow.dart` — smaller teacher-only seed (still available; not replaced)
- Admin Home banner filter: only notifications with `channel == admin_ops_broadcast`
