# Data contract audit

**Baseline:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
Collections named from `FirestoreCollections` + rules + live queries. **If a writer is not in `lib/`, it is not an app contract.**

Legend: **W** writer in app · **R** reader · **S** seed/tool only · **—** none

---

## Collection inventory

| Collection | In rules? | App W | App R | Notes |
|------------|-----------|-------|-------|-------|
| `users` | Yes (signed-in RW except create=self) | Register, Admin toggle, admission `isActive` | Auth, chat, directories | Phone on doc (AUD-003) |
| `studentProfiles` | Yes open | Register create; homework coins; awards dual; admission `halaqaId` | Student/teacher/parent/supervisor | Progress fields **stale** |
| `parentProfiles` | Yes open | **No childrenIds writer** | Parent home, event recipient resolver | AUD-015 |
| `teacherProfiles` | Yes open | Create halaqa `halaqatIds` union; Admin quota/rating | Teacher/Admin | assignStaff **skips** array repair |
| `supervisorProfiles` | Yes open | **None** in Dart (AUD-100) | **None** in Dart | Constants + rules only; staff identity is `users.role` + `halaqat.supervisorId` |
| `halaqat` | Yes open | Create, admission roster, assignStaff | All roles | `schedule[]` optional empty |
| `attendanceRecords` | Yes open | Teacher save day | Teacher/student/parent/analytics | SSOT presence |
| `recitationRecords` | Yes open | Teacher eval/review; student pending submit | Many | SSOT evaluations |
| `assignments` + `activityResponses` | Yes + recursive | Teacher assign/activity | Student/teacher | W1 + activities |
| `absenceRequests` | Yes open | Parent submit; teacher review | Supervisor read helpers | W7 not presence |
| `achievements` | Yes open | Teacher/supervisor/admin grant | Student/parent/teacher | H7 dual field names |
| `payments` | Yes open | Proof update; wallet paid; supervisor review | Parent/supervisor/admin | **No create** |
| `wallets` + `ledger` | **Not in rules** | Wallet pay transaction | Parent getWallet | AUD-035 |
| `notifications` | Yes open | Event handler upsert; Admin broadcast add; mark read | Role inboxes | Two shapes: per-observer vs audience |
| `conversations` + `messages` | Yes (tighter) | getOrCreate, send, mark read, admin group ensure | Chat streams | Group only admin_internal |
| `complaints` | Yes open | Admin/parent paths (UI exists) | Admin review | Confirm writers before assuming |
| `supervisorReports` | Yes open | Ops stack; H6 hid some UI | ? | Stale H6 vs reports tab |
| `posts` + comments | Yes recursive | Posts datasource | Student/content? Teacher tab removed | Leftover |
| `calendarEvents` | Yes open | Calendar datasource | Supervisor calendar, student | |
| `contentLibrary` | Yes open | Admin/student content | Content library | |
| `reciters` / `surahAudios` / `listeningProgress` | Yes open | Audio library progress write | Student audio | |
| `reviewSchedules` | Yes open | Review schedule feature | Student | |
| `academySettings` | **Admin only** | Communication settings | Admin | One of the few tight rules |
| `sessions` | **No** | — | — | **Not a collection** |
| `academies` | **No** | Seed/tool only | None in app | Demo/seed leftover — not an app contract |

Storage paths (app):

| Path | Writer | Rules |
|------|--------|-------|
| `payment_proofs/{parentId}/{paymentId}/{file}` | Parent | Signed-in read; owner image write <10MB; no delete |
| `recitations/{studentId}/{assignmentId}/…` | Student if flag true | Catch-all signed-in RW |
| Award images | Awards datasource | Catch-all |
| Avatars | `users.profileImageUrl` / student `avatarId` catalog | Catch-all if uploaded |

`firebase.json` deploys **indexes only**, not these rules files.

---

## Document shapes (observed)

### `users/{uid}`

Fields used: `name`, `role`, `phone`, `email`, `profileImageUrl`, `isActive`, `createdAt`.  
No `suspensionReason`, no custom claims. Role is **Firestore profile**, not Auth claims (`firestore.rules` comment).

### `studentProfiles/{uid}`

`uid`, `name`, `avatarId`, `level`, `coins`, `points` (homework), `totalStars`, `streakDays`, `halaqaId`, `halaqaName`, `currentPlanName`, `overallProgressPercent` (**entity comment: current surah %; UI treats as overall / دقة الحفظ** — AUD-096), `totalVersesMemorized`, `completedJuz`, `completedSurahs`, `createdAt`, plus award dual-write aliases (H7).

**Primary membership pointer:** `halaqaId` (W8 consumption). Roster SSOT: `halaqat.studentIds`.

### `parentProfiles/{id}`

`childrenIds: string[]` — **read-only in app**.

### `halaqat/{id}`

`name`, `teacherId`, `supervisorId`, `studentIds[]`, `schedule[]` `{day,startTime,endTime}`, `meetingLink`, `status`, `createdAt`.

Schedule day labels: Arabic and English parsed in mapper.

### `attendanceRecords/{id}`

Preferred id `{sessionId}_{studentId}` with `sessionId={halaqaId}_yyyyMMdd`. Fields: `studentId`, `halaqaId`, `date`, `status` (`present|absent|late|excused`), `sessionId`, plus legacy ids retired on save.

### `recitationRecords/{id}`

Evaluation identity session+halaqa+student+type. Grades Arabic strings. `reviewStatus` pending vs reviewed (legacy missing ⇒ reviewed). `versesRange`, `notes`, `behaviorGrade`, `date`.

**Live eval writer** (`UpsertTeacherEvaluationUseCase`) always sets `versesRange: ''` (“unused — never collect or validate in UI”) — AUD-097. Homework review may still populate ranges if that path collects them; do not treat `versesRange` as a live-eval SSOT.

### `assignments/{id}`

Homework + `kind` for activities. Subcollection `activityResponses`.

### `payments/{id}`

`studentId`, `parentId`, `amount`, `dueDate`, `status` (`paid|due|overdue`), `method`, `paidAt`, proof fields, review fields (`reviewStatus`, `reviewedBy`, `reviewedAt`, `reviewNotes`, `amountPaidConfirmed`, `remainingAmount`).

**Issuer:** none in app. **Overdue writer:** none.

### `notifications/{id}`

**Shape A (W4/W5):** deterministic id per observer+event; `audience` = uid.  
**Shape B (broadcast):** auto-id; `audience` = role/`all`; `channel=admin_ops_broadcast`; `readBy[]`.

### `conversations/{id}`

1:1 id `uidA_uidB` sorted. `participantIds`, `participants[]` (uid, name, role, image), unreadCounts, lastMessage*.  
Admin group id `admin_internal_group`, `kind=admin_group`.

Messages: `senderId`, `text`, `sentAt`. No edit/delete. No media metadata.

---

## Writers vs readers (critical facts)

| Fact | Owner writer | Observers |
|------|----------------|-----------|
| Presence | Teacher attendance | Student/parent %, W3/W6, W4 events |
| Live evaluation | Teacher recitation upsert; **no** `AcademyEvent` (AUD-095) | Student/parent lists; analytics; **not** profile %; **not** inboxes |
| Homework assignment | Teacher | Student, W5 |
| Membership roster | Admission Firestore | Teacher roster (not `isActive` filter — documented), student primary id |
| استئذان | Parent submit / teacher review | Supervisor |
| Payment paid | Supervisor approve **or** wallet txn **or** any client via rules | Finance sums |
| Progress % | **Nobody after register** | Everyone displays it |
| Parent family | **Nobody** | Parent UI + event recipients |
| Session lifecycle | **Nobody** (inferred) | Attendance/eval ids |
| Invoice | **Nobody** | Payment UIs |

---

## Session id contract split (defect)

| Producer | Id shape |
|----------|----------|
| Operational day / attendance / evaluation | `{halaqaId}_yyyyMMdd` |
| Weekly schedule `map()` | `{halaqaId}_{slotIndex}` |

Consumers that parse weekly ids as operational ids will **mismatch**. Attendance/eval use operational shape. Student week list uses index shape.

---

## Indexes (`firestore.indexes.json`)

Present: assignments (several), recitationRecords **studentId+date** (two), attendanceRecords (several), notifications audience+createdAt, conversations participantIds+lastMessageAt, posts.

**Missing vs live queries:**

- `recitationRecords` `halaqaId` + `date` (Analytics — AUD-032)
- `payments` `parentId` + `dueDate` (Parent — AUD-033)
- Possibly supervisor payments `studentId` whereIn (single-field default may suffice)
- Chat messages `sentAt` (single-field default)

---

## Cloud Functions

`functions/src/index.ts` exports `createPaymentIntention`, `paymobWebhook`. Dart initiate path is **commented/throwing**. If functions are deployed, a **second paid SSOT** (Paymob webhook) can exist. Not inventing webhook field mapping here — treat as **contradictory leftover**.

No functions for overdue, FCM, session reminder, invoice issue, progress aggregation.

---

## Dual-write / race notes

| Path | Atomic? |
|------|---------|
| Admission membership | Batch (good) |
| Create halaqa + teacher arrayUnion | Batch (good) |
| Assign staff | Halaqa only (bad) |
| Attendance save + event publish | Write then publish (event not transactional) |
| Halaqa activity reply | Read thread then merge-set `responseCount` / `respondentStudentIds` — **not** a transaction (AUD-101) |
| Proof upload | Storage then Firestore update (orphan files possible) |
| Wallet pay | Transaction wallet+payment (good **if** product wants wallet) |
| Payment review vs parent resubmit | Separate updates (race) |
| Awards grant + profile | Batched with chunk 400 |
| Chat send | Batch message + conversation lastMessage |

---

## What is **not** a contract (do not invent)

> **Wave 0 locks** (`PRODUCT_DECISIONS_LOCKED.md`) now **require** several of these as product contracts. They remain **absent in freeze code** until implementation. Do not invent field names beyond the locks — use Schema/Engineering TBD.

| Item | Freeze | Lock |
|------|--------|------|
| `sessions` documents | Missing | **D10 required** |
| Fee catalog / pricing rules | Missing | **D3** Admin pricing → backend invoices |
| Overdue job | Missing | **D4** stored + scheduled job |
| Payment-access suspension (≠ `isActive`) | Missing | **D5** |
| Vodafone destination in `academySettings` | Empty constant | **D6** |
| Parent Add-Student request + childrenIds writer | No writer | **D12** (Parent cannot write directly) |
| Halaqa group chat | Rules forbid >2 | **D14** required |
| FCM tokens | Missing | **D19** |
| Chat media Storage paths | Catch-all only | **D20** |
| Mushaf last-read | Missing | **D23** |
| English copy catalog | Missing | **OUT** (D15) |
| `supervisorProfiles` as SSOT | Unused | **D24** — do not elevate |

See `IMPLEMENTATION_PLAN.md` and `MASTER_ISSUE_MATRIX.md` for impacts.
)
