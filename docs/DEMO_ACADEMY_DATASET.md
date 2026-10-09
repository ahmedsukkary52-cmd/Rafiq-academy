# Demo Academy Dataset

Permanent development dataset for Rafiq Academy. Created by expanding
`tool/seed_firestore.dart` (implementation: `tool/demo_academy_dataset.dart`).

## How to run

A target is required (`emulator` | `dev` | `staging`). There is no default,
and production (`rafiq-academy-prod`) is always rejected before Firebase is
initialized. The seeder prints `Target:` and `Project:` before any write.

| Target | Firebase project |
|---|---|
| `emulator` | `demo-rafiq-rules` (local Auth + Firestore emulators) |
| `dev` | `rafiq-academy` |
| `staging` | `rafiq-academy-staging` (unavailable until its FirebaseOptions exist) |

Local emulators (preferred). Start them only through the fixed entry point,
then seed in a second terminal:

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
app ID) and connects Auth to `localhost:9099` and Firestore to
`localhost:8080` before any read or write. It is local testing only; the
`dev` target below writes to a real project.

Real dev project (an explicit password is required):

```bash
flutter run -d windows -t tool/seed_firestore.dart --dart-define=SEED_TARGET=dev --dart-define=SEED_PASSWORD=<password>
```

Default password for **all** accounts on the emulator target: `SeedDemo123!`.
The `dev` and `staging` targets never fall back to it.

Idempotent: fixed Auth emails + document IDs. Safe to re-run.

## What is created

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
