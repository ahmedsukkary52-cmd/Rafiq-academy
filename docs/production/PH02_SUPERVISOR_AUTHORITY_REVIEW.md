# PH-02 — Supervisor Authority Review & Evaluation Contract

Status: **PH-02 CLOSED.** B1 (Teacher 24h edit window) and B2 (Admin
evaluation correction) were locked by the product and implemented in the final
closure patch (§3, §5). Nothing is deployed, committed or pushed. All results
come from the emulator project `demo-rafiq-rules`.

Evidence read: `PRODUCT_DECISIONS_LOCKED.md`, `SECURITY_DATA_CONTRACT_FREEZE.md`,
`WAVE_A_IMPLEMENTATION_SPEC.md`, `SECURITY_IMPLEMENTATION_SPEC.md` (§2 matrix,
§6, §9–§11, §20, §23), the approved `W6_PHASE0_DESIGN`, `PH02_CLOSURE_PATCH_REPORT.md`,
`PH02_DEPLOYMENT_ORDER.md`, `firestore.rules`, `storage.rules`, every exported
Cloud Function, and the Supervisor client (`features/supervisor`).

How Supervisor is modelled: an **elevated operational role scoped to the
halaqat whose `supervisorId` is the caller** (`halaqat` is the SSOT; never a
client claim). Inside that scope Supervisor gets the operational powers the
locked contracts grant (admission, transfer, payment review, awards,
achievements, reports, read of every operational record). Supervisor does not
take over the Teacher's live classroom operations: the approved W6 Rule 1/6/S5
and spec §10.1 say so explicitly. Academy-wide and system-sensitive operations
stay Admin-only.

Legend: ✔ allowed · ✖ denied · **CF** = enforced inside a Cloud Function
(role loaded server-side from `users/{uid}.role`) · "supervised" = halaqa with
`supervisorId == caller` · "own halaqa" = `teacherId == caller`.

---

## 1. Final authority matrix

### 1.1 Halaqa structure and sessions

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Halaqa create | ✔ any (empty roster) | ✖ | ✖ | ✖ | ✖ | Rules `halaqat` create `isAdmin()` | Spec §2 "✖ create (unless later product expands)" |
| Halaqa edit (name, staffing) | ✔ any (never `studentIds`) | ✖ | ✖ | ✖ | ✖ | Rules `halaqat` update `isAdmin()` | Spec §2; §23 |
| Schedule slots | ✔ any | ✖ (default) | ✖ | R (halaqa doc readable) | R | Rules `halaqat` update `isAdmin()` | Spec §2 "U supervised (**TBD**)"; §23 "Supervisor schedule edit rights — NON-BLOCKING, default Admin-only" |
| Session creation / materialization | ✔ any | ✖ | ✔ own halaqa | ✖ | ✖ | **CF** `materializeSession` (`canMaterialize`: admin, or teacher of halaqa) | Spec §2 sessions "C/U own halaqa"; Supervisor "R supervised" |
| Session status / cancel | ✔ any | ✖ | ✔ own session (status only) | ✖ | ✖ | Rules `sessions` update (admin or `teacherId == uid`, snapshot frozen) | Spec §2; WA-8 |
| Session read | ✔ | ✔ (rules: any signed-in — see §9 F3) | ✔ | ✔ | ✔ | Rules `sessions` read `signedIn()` | Spec §2 wants scoped reads |

### 1.2 Live teaching records

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Attendance record | ✔ any, any time (correction audited `attendance_correct`) | ✖ (read + escalation view only) | ✔ own halaqa, real session, operational-day window | ✖ | ✖ | **CF** `recordSessionAttendance`; Rules deny all client writes | Spec §9.1/§9.3; W6 S5 "Takes attendance … for the teacher — Must not" |
| Attendance read | ✔ | ✔ supervised | ✔ own halaqa | ✔ linked child | ✔ own | Rules `canReadStudentRecord` | Spec §2 |
| Evaluation create | ✔ any halaqa, same gates | ✖ | ✔ own halaqa, real session, Present/Late | ✖ | ✖ | **CF** `upsertSessionEvaluation`; Rules deny all client writes | Spec §10.1; D7; D7.1 |
| Evaluation edit / correction | ✔ any time, incl. after the Teacher window (B2) | ✖ ("✖ unless product expands") | ✔ own halaqa, **24h from server `createdAt`** (B1) | ✖ | ✖ | **CF** `upsertSessionEvaluation` (audited) | D7.1; spec §10.1; W6 Rule 1/6 |
| Evaluation read | ✔ | ✔ supervised | ✔ own halaqa | ✔ linked child | ✔ own | Rules `canReadStudentRecord` | Spec §2 |
| Homework review (pending submission) | ✖ | ✖ | ✔ own halaqa | ✖ | submit own | Rules `teacherReviewOfPendingOk` / `studentSubmissionOk` | Spec §2 assignments |
| Absence request (استئذان) classify | R | R supervised | ✔ own halaqa | create for linked child | R own | Rules `absenceRequests` | W7 |
| Progress / verse aggregates | R | R supervised | R own halaqa | R linked | R own | No client write; projector not built yet (D11, Wave C) | Spec §10.3 |
| Supervisor reports | R all | ✔ create own; R own | ✖ | ✖ | ✖ | Rules `supervisorReports` | H6 |

### 1.3 Membership and relationships

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Student admission (`studentIds` add) | ✔ any halaqa (also activates account) | ✔ supervised halaqa only (no activation) | ✖ | ✖ | ✖ | **CF** `admitStudentToHalaqa` (max-2, lock doc, audited `student_admit`) | Spec §2 "Admit/transfer via CF within supervised"; W8 |
| Student transfer | ✔ any → any | ✔ **only when both source and target are supervised** (new) | ✖ | ✖ | ✖ | **CF** `adminTransferStudent` (atomic, max-2, audited `student_transfer`) | Spec §2 roster row; §20.1 |
| Student removal from a halaqa (no-halaqa) | no workflow exists | no workflow exists | ✖ | ✖ | ✖ | — | Spec §20.1 lists it; not built (§10 B5) |
| Student archive / unarchive | ✔ | ✖ | ✖ | ✖ | ✖ | **CF** `adminSetStudentLifecycle` (`assertCallerIsAdmin`, audited) | C14 / WA-15 |
| Account provisioning / role | ✔ | ✖ | ✖ | ✖ | ✖ | **CF** `adminProvisionUser`; Rules `roleUnchanged()` | Spec §2; D16 |
| Parent↔student link (`childrenIds`) | ✔ via provisioning | ✖ today (D12 "limited linking" not built) | ✖ | ✖ write | ✖ | Rules deny client writes | D12; spec §6.1 (§10 B4) |
| Relationship read | ✔ | ✔ (rules: any staff — see §9 F2) | ✔ (rules: any staff) | own | ✖ | Rules `parentProfiles` read | Spec §6.1 "Supervisor (supervised students' links)" |

### 1.4 Homework, awards, achievements

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Homework / activity create | ✖ | ✖ (read supervised) | ✔ own halaqa, rostered student | ✖ | ✖ | Rules `teacherCreateOk` | Spec §2 assignments "R supervised" |
| Homework completion + reward | ✖ | ✖ | ✖ | ✖ | ✔ own | **CF** `completeHomework` | PH-02 economy |
| Credited award (`grantAward`, +10 points / +1 star) | ✔ any halaqa | ✔ supervised halaqat | ✔ own halaqat | ✖ | ✖ | **CF** `grantAward`; Rules deny `points`/`totalStars` writes | Spec §2 awards "C/grant supervised / own halaqa" |
| Record-only achievement (no credit) | ✔ rostered student | ✔ rostered student of a supervised halaqa | ✔ rostered student of own halaqa (no client uses it) | ✖ | ✖ | Rules `recordOnlyAchievementOk` (tightened, see §7) | Same row; H7 |
| Achievement read | ✔ | ✔ (any staff) | ✔ (any staff) | linked child | own / recipient | Rules `achievements` read | PH-01 |

### 1.5 Payments

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Payment / invoice read | ✔ | ✔ supervised students | ✖ | ✔ own | ✖ | Rules `payments` read (`isSupervisorOfStudent`) | Freeze §4.7 |
| Proof image read | ✔ | ✔ supervised students | ✖ | ✔ own | ✖ | `storage.rules` `payment_proofs` | Freeze §4.7; spec §2 |
| Proof submit | ✖ | ✖ | ✖ | ✔ own unpaid | ✖ | Rules `parentProofOnlyUpdate` | D6 |
| Review → paid / reject / partial | ✔ any | ✔ supervised students (no client UI yet) | ✖ | ✖ | ✖ | **CF** `reviewPaymentProof` (transactional, idempotent, audited `payment_review`) | Freeze §4.7 |
| Generate invoices / pricing / Vodafone destination | ✔ | ✖ | ✖ | ✖ (reads destination) | ✖ | **CF** `adminGenerateInvoice`; Rules `pricingRules`/`academySettings` | Spec §11.3 |
| `paymentAccess` read | ✔ | ✖ (fail closed — §9 F5) | ✖ | ✔ own | ✖ | Rules `paymentAccess` | Freeze §2.4 grants ✔; no consumer exists |
| Reinstate / suspend access | ✔ reinstate; suspend = scheduler | ✖ | ✖ | ✖ | ✖ | **CF** `adminReinstatePaymentAccess`, `processPaymentOverdueGrace` | D5; freeze §4.7 |

### 1.6 Communication, profiles, sensitive data, platform

| Capability | Admin | Supervisor | Teacher | Parent | Student | Enforcement | Source |
|---|---|---|---|---|---|---|---|
| Broadcast notifications | ✔ role audiences | ✖ | ✖ | ✖ | ✖ | Rules `notifications` create `isAdmin()` | Spec §2 |
| Academy notification fan-out | server | server | server | server | server | **CF** triggers (`notifyParentsOnEvaluation`, `notifyOnAssignmentCreated`, attendance) | C11 |
| Own notifications (read / mark read) | ✔ | ✔ own audience | ✔ | ✔ | ✔ | Rules `isNotificationAudience` | Spec §2 |
| 1:1 chat | ✔ monitor + own pairs | ✔ relationship-valid pairs (supervised students/parents/teachers, Admin) | ✔ relationship-valid | ✔ relationship-valid | ✔ own teacher/supervisor | **CF** `createDirectConversation` (`chatRelationship`) | D13 |
| Halaqa group chat | monitor, not member | member of supervised groups | member + announce | ✖ (D14) | member of own | **CF** `syncHalaqaGroupOnWrite`; Rules participants | D14 |
| Message edit / soft-delete | via CF | own via CF | own via CF | own via CF | own via CF | **CF** `editChatMessage`, `softDeleteChatMessage` | D20 |
| `users` identity (name, role) | ✔ | ✔ (list allowed for staff, unscoped — §9 F1) | ✔ (same) | get by id; list Admin cards only | same as Parent | Rules `users` | Spec §2; freeze §16.3 |
| `studentProfiles` | ✔ R/U safe fields | R (any staff — §9 F2) | R (any staff) | R linked | R own; peers on own roster | Rules `studentProfiles` | Spec §2 |
| Student directory search | ✔ | ✔ roster-derived (`visibleTo`) | ✔ roster-derived | ✖ | ✖ | Rules `studentSearch` | C13 |
| Phone (`userPrivate`) | ✔ | ✖ | ✖ | ✖ (own only) | own | Rules `userPrivate`; `hasExposedPhone` guards | D16 |
| Email (`users.email`) | ✔ | readable (§9 F1) | readable | readable | readable | Rules `users` get | Not in freeze; see §9 |
| FCM devices | own | own | own | own | own | Rules `fcmTokens/{uid}/devices` self-only; delivery ledger Admin-read, CF-written | D19 |
| Audit logs | R (Admin only); written by CF | ✖ read/write; may be the audited actor | ✖ read/write; may be the audited actor | ✖ | ✖ | Rules `auditLogs` write `false`; `buildAuditLogEntry` | C16 (amended §6) |
| Calendar events / content library | ✔ create/delete | ✔ create | ✔ create | R | R | Rules `calendarEvents` / `contentLibrary` | Spec §2 "per product" |
| Mushaf last-read | R | ✖ | ✖ | ✖ | own | Rules `mushafReading` | D23 / C15 |

---

## 2. Evaluation authority model

One callable, `upsertSessionEvaluation`, with two writers: the halaqa's
Teacher (inside the 24h window) and Admin (any time). It enforces all of the
following server-side, in one transaction:

- caller role from `users/{uid}.role`: `teacher` with `halaqat/{id}.teacherId == caller`, or `admin`;
- a real `sessions/{sessionId}` of that halaqa that is not cancelled
  (synthetic `{halaqa}_{yyyymmdd}` ids are rejected);
- the student is on that halaqa's roster;
- attendance for that session is `present` or `late` (D7);
- `recitationRecords/{sessionId}_{studentId}_{type}` is upserted
  (deterministic id, so replays converge), and same-day legacy duplicates are retired;
- an existing document at that id is adopted only if it is a live evaluation of
  the same session (no `assignmentId`, not `pending`); anything else fails closed;
- a change-only `evaluation_create_or_correct` audit (§6).

All client writes to live evaluations are denied by rules, for every role.
Supervisor reads evaluations in scope and never writes them (§4).

## 3. Teacher evaluation edit rules (B1)

- Teacher may create an evaluation for their own halaqa while the D7 gate holds,
  and edit/correct it for **24 hours after it was first created**.
- **Anchor:** `recitationRecords.createdAt`, a `FieldValue.serverTimestamp()`
  written once, on creation only. It is a new field: the model only had
  `updatedAt`, which moves on every save and so cannot bound the window.
  Corrections (Teacher or Admin) never rewrite it.
- **Boundary:** open while `now < createdAt + 24h`
  (`isWithinTeacherEditWindow`); at exactly 24h the Teacher is denied with
  `failed-precondition` "انتهت مهلة تعديل التقييم (24 ساعة) — التصحيح متاح للمسؤول فقط".
- **Clock:** `now` is the Cloud Function's clock. The callable wrapper passes
  only `uid` and `data` to the core, and no request field (`createdAt`, `now`,
  `updatedAt`) is read — a unit test pins this.
- **Missing anchor** (a document written before this patch): fails closed for
  the Teacher; Admin can correct.
- **Anchor forgery:** rules forbid `createdAt` on student submissions and
  reserve `*_memorization` / `*_review` ids for live evaluations; no client can
  update a live evaluation at all.
- Every real change is audited: actor is the Teacher (server-derived),
  `operation` is `create` or `correct`. An identical replay produces no audit.
- Edits never re-push to parents (per-device delivery ledger, D17) and never
  touch progress (D11 projector is out of PH-02 scope).

## 4. Supervisor evaluation correction rules

**Decision: Supervisor does not create or correct evaluations.** This rests on
explicit locked evidence, not on an older reading of the role:

- Spec §10.1: Supervisor | Read | Edit "✖ **unless product expands**" | Delete ✖.
- Spec §2: evaluations "R supervised".
- Approved W6 Rule 1: "Supervisor is an operational observer, not another teacher".
  Rule 6: escalation "should never transfer business ownership from teacher to supervisor".
  S5: "Takes attendance / reviews / assigns for the teacher — **Must not**".

What Supervisor review means today:
- Read every evaluation and attendance record of supervised halaqat.
- Escalate through the teacher views (router allowlist `/teacher/attendance/`, `/teacher/halaqa/`).
- File `supervisorReports`.

Rules tests and an emulator test prove that the read works, that it is scoped,
and that writes are denied.

If the academy wants Supervisor correction, that is a product expansion (§10 B3).
The engineering path is ready:
- extend `upsertSessionEvaluationCore` with `role === "supervisor" && halaqa.supervisorId === uid`;
- keep the same session/D7 gates;
- the audit already records the actor through `actorForCallerRole`, so no contract change is needed.

## 5. Admin correction rules

- **Attendance:** Admin corrects at any time. A correction outside the Teacher
  window is audited as `attendance_correct` (spec §9.3, implemented).
- **Evaluation (B2):** Admin creates or corrects through the same
  `upsertSessionEvaluation` callable at any time, including after the Teacher
  window. The real-session, non-cancelled, halaqa-match, roster and
  Present/Late gates all still apply. The write is transactional, keeps
  `teacherId` as the halaqa Teacher and never moves `createdAt`. Every real
  change is audited with `actorRole: "admin"` and `operation: "correct"` (or
  `create`); an identical replay adds nothing; concurrent corrections serialize
  and each real change is audited once. There is no Admin correction screen —
  B2 is server authority only, no UI was added.

## 6. C16 audit changes

The conflict was that spec §20.1 requires evaluation create/correction to be
audited, while C16 §16.2 allowed only `admin` / `system` actors.

Resolution (no weakening):

| Item | Before | After |
|---|---|---|
| `actorRole` allowed by `buildAuditLogEntry` | admin, system, supervisor | admin, system, supervisor, **teacher** |
| Actor derivation | per-callsite helpers | plus `actorForCallerRole(uid, role)`: maps only admin / supervisor / teacher from the server-loaded role; throws for parent / student / system / unknown |
| `evaluation_create_or_correct` | deferred | **emitted** by `upsertSessionEvaluation`, change-only, for Teacher create/correction and Admin create/correction |
| Target type | — | `evaluation` (target id = evaluation doc id) |
| Metadata allowlist | — | `+ evaluationType`, `versesRange`, `operation` (`create` / `correct`) |
| `student_transfer` actor | admin | admin or supervisor (scoped transfer) |
| Client writes to `auditLogs` | denied | still denied for every role and every claimed `actorRole` (new rules test) |

Evaluation audit metadata is `{sessionId, halaqaId, studentId,
evaluationType, versesRange, operation}`. Grades and free-text notes are never
copied into the audit. `versesRange` is recorded as stored, currently `""`
(see §9 F6). Request fields such as `actorRole` / `actorId` are ignored, and an
emulator test sends forged values to prove it.

The freeze doc (`SECURITY_DATA_CONTRACT_FREEZE.md` §16.2/§16.3) is amended to
match. Remaining deferred hooks: `payment_suspend`,
`relationship_children_change`, `session_create_or_correct`,
`admin_pricing_change`, `admin_vodafone_change`, `chat_message_moderate_delete`.

## 7. Award authority

**Credited awards — `grantAward`**
- **Who grants where:** Admin in any halaqa, Supervisor only where `supervisorId == caller`, Teacher only where `teacherId == caller`. Every requested halaqa must pass that check.
- **Recipients:** every recipient must be on the roster of one of those halaqat, and their profile must exist.
- **Amounts:** fixed server-side (`AWARD_POINTS_PER_RECIPIENT = 10`, `AWARD_STARS_PER_RECIPIENT = 1`). The client cannot send amounts.
- **Write:** one transaction creates the award doc (`tx.create`, server-set `grantedBy` / `issuedBy` / halaqa names) and increments each recipient profile.
- **Replay and concurrency:** the client-generated `awardId` makes replays safe. The same grantor gets `alreadyGranted` with no second credit, and a different grantor gets `already-exists`. Concurrent replays credit exactly once (emulator-tested).
- **Audit:** awards are not in spec §20.1. The award document itself is the immutable record: no update or delete, and the grantor is server-stamped. No audit action was invented.
- **Direct writes:** rules deny `points` / `totalStars` writes for every client role, including Admin.
- **Client callers:** the Teacher award flow (`AwardRemoteDatasourceImpl`) calls the callable. Admin has no grant UI (D18 gap, §10 B6).

**Record-only achievements (Supervisor "منح إنجاز")**
- **What it is:** an existing product path. The client writes `{studentId, type: star|badge|certificate, halaqaId, title, note, grantedBy, issuedBy, grantedAt, date}` and credits nothing.
- **Why it wasn't moved to `grantAward`:** the callable always credits +10 / +1, and the Supervisor types aren't award types. Moving it would invent a reward rule for Supervisor medals (§10 B7).
- **Gap found and fixed:** the old rule checked only `grantedBy == uid` and halaqa staffing, never the roster. The dialog even accepts a hand-typed student id when the halaqa is empty. So a Supervisor could put an achievement on any student in the academy, or forge `recipientStudentIds` to reach other students' lists.
- **New rule `recordOnlyAchievementOk`:**
  - `grantedBy` must be the caller, and `issuedBy`, if present, must be the caller;
  - the caller must be Admin or staff of the halaqa;
  - **the student must be on that halaqa's roster**;
  - the keys must be exactly the record-only shape, so no `recipientStudentIds` or `halaqaIds` (multi-recipient, credited awards stay callable-only).
- **Guarding the shape:** a Dart contract test pins the client payload to the rule's key list.

## 8. Points / stars classification

| Field | Class | Why |
|---|---|---|
| `studentProfiles.totalStars` | **KEEP** (server-owned) | Student-facing: displayed and consumed by Student screens. Written only by `grantAward` (+1 per recipient). |
| `studentProfiles.points` | **QUARANTINE** (server-owned) | Written by `completeHomework` and `grantAward`, but no screen, stat, ranking, query, spending path or notification reads it. No economy was invented. |
| `studentProfiles.coins` | KEEP, separate economy | `completeHomework` / `purchaseAvatar` only. Never mixed with awards. |

## 9. Security / data-minimization findings

Inventory only. No `publicProfiles` schema exists in the freeze, so none was
created. Phone exposure is already closed: `users.phone` is rejected by
`hasExposedPhone` and phones live in Admin/self-only `userPrivate` (D16).

| # | Finding | Exposure | Recommendation |
|---|---|---|---|
| F1 | `users/{uid}.email` (written by `adminProvisionUser`) is readable by any signed-in user via `get`, and by Teacher/Supervisor via unscoped `list`. | Staff and peers can read emails; the client only shows email on the user's own profile. | Move email to `userPrivate` (Admin + self) in a follow-up migration, the same pattern as the PH-01 phone move. |
| F2 | `studentProfiles` and `parentProfiles` (including `childrenIds`) are readable by **any** Teacher/Supervisor, not just supervised/rostered students. | Academy-wide family graph for every staff member. Spec §6.1 scopes it to "supervised students' links" / roster parents. | Scope reads to `isRosterStaffOf(studentId)` (CF-maintained `studentSearch.visibleTo`) and parent reads to a projection. Needs query migration of `getParentIdsByStudentIds` (`arrayContainsAny`), which rules cannot scope per element. |
| F3 | `sessions` readable by any signed-in user. | Schedule metadata only (no PII), but wider than spec §2. | Scope to staff of the halaqa / rostered students / linked parents when session reads are migrated. |
| F4 | `users` `list` for staff is unscoped (roster screens list users by id). | Names and roles for the whole academy. | Same projection work as F2. |
| F5 | Supervisor `paymentAccess` read is granted by freeze §2.4 but denied by rules. | None (fail closed). No Supervisor screen consumes it. | Add a CF-maintained projection only when a consumer exists. |
| F6 | `recitationRecords.versesRange` is always `""` for live evaluations. D11 / spec §10.2 require a real range. | Data quality, not security. | Investigated in the final closure: the Teacher flow deliberately never collects a range (`// Product: versesRange is unused — never collect or validate in UI.`), and no locked contract defines its source or format (free text vs surah/ayah span vs page vs assignment-derived). Not derivable → separate product/data-contract follow-up with the Wave C projector. Homework submissions already carry the assignment's range. |
| F7 | Supervisor admission does **not** activate accounts (Admin only). | Correct per spec §2 users.isActive row. | — |

## 10. Exact remaining business decisions

| # | Decision | Status | Effect today |
|---|---|---|---|
| B1 | Teacher evaluation edit window | **RESOLVED** — 24h from server `createdAt` (D7.1) | Implemented and tested |
| B2 | Admin evaluation correction | **RESOLVED** — any time, audited (D7.1) | Implemented and tested |
| B10 | D11 `versesRange` source/format for live evaluations | Non-blocking product/data-contract follow-up | Stored as `""` |
| B3 | Supervisor evaluation correction | Non-blocking product expansion (spec §10.1 "✖ unless product expands") | Denied; engineering path in §4 |
| B4 | D12 "limited linking" workflow for Supervisor (and Add Student Request schema) | Non-blocking; spec §6.4 "Schema TBD" | No linking workflow for any role besides Admin provisioning |
| B5 | Remove a student from a halaqa (no-halaqa) / unlink | Non-blocking; spec §6.1 "IMPORTANT TBD unlink UX" | No workflow; transfer and archive exist |
| B6 | Admin "Grant award" UI on Student Profile (D18) | Non-blocking UI gap | Callable supports Admin; no screen |
| B7 | Should Supervisor record-only achievements credit `totalStars`? | Non-blocking | They stay record-only (no credit) |
| B8 | Supervisor schedule edit rights | Non-blocking; spec §23 default Admin-only | Admin-only |
| B9 | Audit retention period | Non-blocking (C16.4) | No purge |

### Verification (emulator `demo-rafiq-rules`, final closure patch B1/B2)

| Suite | Result |
|---|---|
| Firestore rules (`firestore.rules.test`, `ph01_authorization`, `ph02_backend_authority`) | 170 / 170 |
| Functions unit (`npm run test:wave-a`) | 237 / 237 |
| PH-02 emulator (`ph02_backend_authority.emulator.test`) | 50 / 50 |
| Flutter full suite | 693 passed, 2 skipped |
| `flutter analyze` | 120 issues — identical to the baseline (0 new) |
| Storage rules | not touched |
