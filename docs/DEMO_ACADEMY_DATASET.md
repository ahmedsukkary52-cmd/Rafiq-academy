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

1. Refuses any argument (exit 64).
2. Reads the auth / firestore / hub ports from `firebase.json`; hosts, when
   set, must be `127.0.0.1`.
3. Refuses the environment if `GOOGLE_APPLICATION_CREDENTIALS`,
   `CLOUDSDK_CONFIG` or `GOOGLE_API_USE_CLIENT_CERTIFICATE` is set, gcloud
   application default credentials exist on
   disk, any project variable (`GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`,
   `GCP_PROJECT`, `CLOUDSDK_CORE_PROJECT`, `FIREBASE_CONFIG.projectId`) is not
   exactly `demo-rafiq-rules`, a proxy variable is set, or a pre-set emulator
   host differs from `127.0.0.1:<firebase.json port>`. The `demo-` prefix is
   not trusted on its own.
4. Installs a network allowlist on this process's `net` and `dns` modules
   before firebase-admin loads: TCP only to `127.0.0.1` / `::1` on the
   emulator ports, and no `node:dns` lookups except loopback literals. A
   self-test must pass. It sets `METADATA_SERVER_DETECTION=none`, otherwise
   the Firestore client library probes the GCE metadata server. Not covered:
   UDP, native addons, worker threads, child processes and code preloaded via
   `NODE_OPTIONS`; the libraries' two child-process paths (`gcloud` project
   lookup, mTLS cert provider) are kept unreachable by step 3.
5. Checks readiness over `127.0.0.1`: the hub lists auth and firestore on the
   expected ports, Auth reports `ready`, Firestore answers `Ok`.
6. Loads firebase-admin for `demo-rafiq-rules` and re-checks the project and
   emulator hosts.
7. Reads Auth users, root collections and `_seedMeta/demo`. Any blocked
   connection, any existing data, or a leftover seed marker refuses the run.
8. Writes with `create()` only: `_seedMeta/demo` (`in_progress`), Auth users
   with fixed UIDs, one batch of documents, read-back verification, a check
   that no connection was blocked, then `_seedMeta/demo` (`complete`).

Dataset v1 is six accounts (`admin@`, `supervisor1@`, `teacher@`, `parent@`,
`student01@`, `student02@rafiq.demo`, UIDs `demo-<role>-NN`) with the same
`users`, `userPrivate` and role-profile fields `adminProvisionUser` writes.
`users` documents never carry `phone`.

There is no reset and nothing is deleted. The run is not atomic: Auth users
are created one by one. If a run fails part-way it exits 1 and
`_seedMeta/demo` stays `in_progress`, so the next run refuses to start. If
creating `_seedMeta/demo` itself fails, nothing else was written and the
marker may or may not exist. Either way, `npm run serve` keeps emulator data
in memory only: stop the emulators, start them again with `npm run serve`,
then re-run the seeder.

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
