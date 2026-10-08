# Product Decisions Locked — Wave 0 Complete

**Status:** LOCKED — authoritative for implementation planning  
**Locked date:** 2026-09-10  
**Code baseline (unchanged):** `feature/full-product-audit` @ `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Companion:** `IMPLEMENTATION_PLAN.md`, `FIREBASE_BILLING_CHECKLIST.md`

These decisions supersede open questions in `FULL_PRODUCT_AUDIT.md` §8 and the previous “Product Decisions Blocking Implementation” table in the implementation plan. They do **not** rewrite historical audit findings; they resolve what to build next.

**Do not silently change these decisions in code.** If a detail is still open, mark it Engineering / Schema / Infrastructure TBD.

---

## D1 — Registration

- **No public self-registration.**
- Accounts are provisioned through an **Admin-controlled workflow**.
- Do not invent a new identity writer unless explicitly required during implementation.
- **Engineering TBD:** exact Admin Auth provisioning mechanism (Console-only vs callable Cloud Function vs existing Admin UI extension). Freeze has **no** Admin `createUser` path today.

## D2 — Payment Rail

- **Vodafone Cash + screenshot proof only.**
- **Paymob OUT** of current scope (quarantine/remove client + functions from product path).
- **Wallet OUT** as a payment rail (quarantine wallet→paid path).
- Parent pays externally and uploads proof.
- Payment remains `pending_review` until authorized review.
- Becoming `paid` is **not** a Parent client write.

## D3 — Invoice Ownership

- **Admin** owns pricing rules / defaults / overrides.
- **Backend/system** automatically generates invoices from those rules.
- Invoice stores **final amount as a snapshot**.
- Later pricing changes affect **future** invoices only, not existing ones.
- **Schema TBD:** pricing rules document shape under `academySettings` (or dedicated collection).
- **Infrastructure TBD:** invoice generator trigger (scheduled job vs membership event vs both).

## D4 — Overdue

- Overdue status is **stored** on the payment document.
- A **scheduled backend job** updates overdue after due date.
- Do **not** rely only on client-side calculation for SSOT.

## D5 — Suspension / Non-payment (PAYMENT ACCESS POLICY)

**Distinct from D21 (no-Halaqa) and from administrative archive.**

- Use a **payment-specific suspension / access policy**; do **not** blindly overload `users.isActive` for payment delinquency.
- Timeline:
  1. Before due date → reminders
  2. Due date → warning
  3. After due date → stored overdue + warnings
  4. After **configurable grace period** → Parent access **and** child access suspended
- Suspended Parent UI may show **only**:
  1. Pay Now
  2. Contact Admin  
  **No** Skip / Later / Continue.
- Proof remains `pending_review` until reviewed (suspension does not auto-pay).
- **Admin** handles reinstatement.
- **Schema TBD:** payment-access / suspension fields (separate from login `isActive` and from no-Halaqa state). Exact field names and where they live (`users`, `parentProfiles`, `studentProfiles`, or a dedicated access doc).

## D6 — Vodafone Destination

- Official Vodafone Cash destination is stored in **`academySettings`**.
- Admin can edit it.
- Parent reads the **current** value.
- Never hard-code an invented number (freeze `transferDestination = ''` must be replaced by settings read).

## D7 — Evaluation Attendance Gate

- Evaluation requires a linked **Session** + **Attendance**.
- Student must be **Present** or **Late**.
- **Absent** cannot be evaluated for that session.

### D7.1 — Evaluation edit / correction (PH-02 closure, B1 / B2)

- **Teacher** of the Halaqa creates the evaluation and may edit/correct it for **24 hours** after it was first created. The anchor is the server-set `recitationRecords.createdAt`, written once on creation; client clocks and request fields never move it. From 24h on, the Teacher is denied server-side.
- **Admin** may create or correct an evaluation at any time, including after the Teacher window closes, under the same real-session / roster / Present-Late gates.
- **Supervisor** reviews (reads) evaluations of supervised Halaqat; Supervisor does **not** create, edit or correct evaluations.
- Every evaluation create/correction is audited (`evaluation_create_or_correct`). The audit never contains grades or notes.

## D8 — Halaqa Creation

- Production Halaqa creation requires **≥1 Schedule Slot**.
- No production Halaqa without a schedule.

## D9 — Multiple Slots / Sessions

- Each Schedule Slot gets its **own Session**.
- Hard conflict validation must prevent conflicting duplicate slots where applicable for:
  - Teacher
  - Student
  - Same Halaqa
- **Supervisor conflict is allowed** (Supervisor is an operator, not a required participant in every session).
- Backend validation must prevent race-condition conflicts; **UI-only validation is insufficient**.
- **Engineering TBD:** conflict engine (transaction / callable / Cloud Function) and exact conflict definition (time overlap rules).

## D10 — First-class Sessions

- Persist first-class **`sessions/{sessionId}`** documents.
- Session links at least: `halaqaId`, `slotId`, date/time, status (**Schema TBD** for full field set).
- Attendance / Evaluation / Progress / Notifications reference the **real Session**.
- Do **not** continue relying on synthetic `{halaqaId}_yyyyMMdd` as production SSOT.
- **Migration TBD:** dual-read / backfill strategy for historical attendance/eval docs keyed by synthetic day ids.

## D11 — Quran Progress Semantics

| Concept | Meaning | Source |
|---------|---------|--------|
| `overallProgressPercent` | Overall Quran **MEMORIZATION** progress | Memorization evaluations only |
| Revision progress | Separate | Revision evaluations / plans |
| Accuracy | Evaluation **quality** metric | Grades — **not** overallProgressPercent |
| Mushaf last-read | Reading position only | D23 — **not** memorization |

- Every Evaluation is typed **memorization** or **revision**.
- Every Evaluation stores the real **`versesRange`**.
  - **Open follow-up (not part of PH-02):** the live Teacher evaluation flow does not collect a range today (the Teacher UI deliberately omits it, so stored `versesRange` is `""`). The source and format of the range — free text, surah + ayah span, page, or derived from the assignment — are not defined by any locked contract. It must be decided together with the Wave C progress projector; nothing was invented.
- Do not mix revision into memorization percentage.
- Do not label memorization % as «دقة الحفظ».

## D12 — Parent / Student Relationship

- **Admin** is final authority.
- Parent can submit **Add Student Request** with child details (avoid retyping).
- Admin reviews and assigns student to Halaqa (or creates Halaqa if needed).
- Supervisor may perform **limited linking** only within authorized Halaqat.
- Parent **cannot** directly write `childrenIds`.
- `childrenIds` is updated as the result of an authorized admission/assignment workflow.
- **W8 remains** the relationship/admission workflow.
- **Chat dependency (D14):** 1:1 Parent↔Teacher (and related) authorization must use this relationship graph, not role pairs alone.

## D13 — Admin Chat Oversight

- Admin **may** monitor all academy conversations (intentional).
- Separate from normal relationship authorization (D14).
- Admin UI must clearly distinguish at least:
  - My Conversations
  - Monitored Conversations
  - Parents / Teachers / Supervisors / Students
  - Halaqa Groups
- Monitored messages expose sender identity, role, timestamp, and media indicator when relevant.
- Authorization must **not** depend on bubble color/order.

## D14 — Chat Scope / Relationship

- Support **1:1** conversations.
- Support **Halaqa Group Chat**: Teacher + Supervisor + Students of that Halaqa.
- Teacher can announce to the whole Halaqa group.
- Supervisor **direct** messaging remains **1:1**; Halaqa Group is the defined group exception.
- Admin can monitor all conversations including groups (D13).
- **1:1 relationship authorization must be enforced server-side.**
- Parent cannot message arbitrary students/staff based on role alone.
- Student / Parent / Halaqa relationships must be validated (depends on D12 membership graph).
- **Schema TBD:** Halaqa group conversation id / membership sync when roster changes.
- **Engineering TBD:** soft-delete vs tombstone for edit/delete (see D20).

## D15 — Language / Theme

- **Arabic only** for current release.
- **RTL only**.
- English / LTR are **OUT**.
- Do **not** build fake language switching (remove/hide dead language rows).
- **Dark/Light theme switching is OUT** of current product requirement.
- Do not spend implementation effort on a full theme-switch system unless later requested.
- Wave G focuses on: Arabic RTL consistency, shared chrome/states, terminology — **not** EN locale or dark-mode program.

## D16 — Phone Privacy

- `users.phone` is readable by **Admin only**.
- Teacher / Supervisor / Parent / Student: **no**.
- Must be enforced by **backend authorization**, not merely hidden in UI.
- Non-Admin search/list/detail must not expose phones.
- Chat uses userId / relationships, not phone numbers.
- Student search/disambiguation: `studentId` + full/triple name + Halaqa name (+ non-sensitive contextual field if needed). Arabic search normalization where appropriate. **Never** phone as primary disambiguation for non-Admin.

## D17 — Live Evaluation Notification

- When a Live Evaluation is created:
  1. Evaluation is persisted
  2. Appropriate Academy Event / Notification is created
  3. Parent receives notification (**in-app + FCM** per D19)
  4. Parent can open the evaluation
- Notification is linked to student / session / evaluation.
- Real delivery required — not a fake static message.

## D18 — Admin Student Management

- Roster shows status clearly (Active / Inactive / Suspended / No-Halaqa / Archived — as defined by final access model; **Schema TBD** for enum).
- Do **not** overload the roster with many actions.
- Clicking a student opens **Student Profile**.
- Student Profile centralizes admin actions as applicable: Transfer, Contact parent/family, Grant award, Suspend, Reactivate, View data / membership / schedule / progress / evaluations / payment status.
- Status changes use **authorized backend workflow**.

## D19 — FCM Push Notifications

- Real **FCM Push Notifications are IN SCOPE**.
- Do not limit to in-app only.
- Cloud Functions / backend may be used where needed.
- **Infrastructure dependency:** Blaze / billing checklist (`FIREBASE_BILLING_CHECKLIST.md`) must be completed before enabling paid services on the academy account.
- Do not guess costs.

## D20 — Chat Media

- Chat supports: Text, Images, Voice Messages, Edit, Delete.
- Media requires proper Firebase Storage paths / rules / authorization.
- Add image / audio / profile-picture / attachment storage to the billing checklist.
- **Delete semantics TBD:** do not hard-delete historical data without an explicit retention contract (prefer soft-delete / tombstone / redaction plan).
- **Infrastructure TBD:** Storage path layout for chat media.

## D21 — Student Without Halaqa / Removal

**Three distinct states — do not collapse:**

| State | Meaning |
|-------|---------|
| **Payment suspension (D5)** | Access limited due to non-payment / grace expiry |
| **No-Halaqa (temporary)** | Account + history kept; student not on any active Halaqa roster; waiting for assignment |
| **Archive / deactivation** | Permanently removed from active academy operations; history retained for authorized Admin |

- Transfer from one Halaqa requires a **target** Halaqa.
- A student may temporarily have **NO Halaqa** while keeping account and historical data.
- Student UI: clear message — not assigned, waiting for assignment.
- Archived/removed students must not remain in active Halaqa rosters / groups / operational notifications.
- Historical attendance / evaluation / progress / payment / chat / award records remain available to authorized Admin workflows.
- Do **not** implement destructive hard-delete without an explicit data-retention policy (**Policy TBD**).

## D22 — Idle Timeout

- **No** app-level idle session timeout.
- Use Firebase Auth persistence normally.
- Do not force re-login merely because the app was idle.

## D23 — Mushaf

- First open default = **Surah Al-Fatihah** (not Al-Mulk / 67).
- After reading history exists → open at student’s **last-read position** (per student).
- Reading position is **NOT** memorization progress (D11).
- Mushaf UI is a **major UX requirement**: substantial redesign, two polished visual styles/modes, benchmark against established Quran-reader UX.
- Not a minor padding/color polish task.
- **Engineering TBD:** last-read persistence schema; two visual mode implementation approach.

## D24 — supervisorProfiles

- Treat as **legacy / experimental**.
- Do **NOT** make it a new source of truth.
- Before deleting references, perform a dependency search.
- If truly unused, quarantine / remove stale references safely.
- SSOT for supervisor identity remains `users.role` + `halaqat.supervisorId`.

---

## Access-state separation (mandatory)

```
Login / account kill switch (users.isActive)     ← Admin / Auth disable — NOT payment delinquency
     ≠
Payment access suspension (D5)                  ← grace + Parent Pay Now / Contact Admin only
     ≠
No-Halaqa membership state (D21)                ← waiting for assignment; can still be payment-OK
     ≠
Archive / deactivation (D21)                    ← out of active operations; history retained
```

## Progress / reading separation (mandatory)

```
Memorization progress (overallProgressPercent)  ← memorization evals + versesRange
     ≠
Revision progress                               ← revision evals / plans
     ≠
Accuracy                                        ← grade quality metric
     ≠
Mushaf last-read position (D23)                 ← reader UX only
```

## Chat / relationship separation (mandatory)

```
Relationship graph (D12 membership + childrenIds via W8)
  → 1:1 create/send authorization (D14) — server-side
  → Halaqa group membership (D14)
Admin monitoring (D13) — intentional overlay; not a substitute for D14
```

---

## Representation check

| Decision | Represented |
|----------|:-----------:|
| D1–D24 | Yes — this document |
| D5 ≠ D21 | Yes — access-state separation |
| D11 ≠ D23 | Yes — progress / reading separation |
| D12 → D14 | Yes — relationship feeds chat authz |
| D13 ≠ D14 | Yes — oversight vs relationship |
| D19 + D20 → billing | Yes — `FIREBASE_BILLING_CHECKLIST.md` |
| D18 profile-centric | Yes |
| D24 non-SSOT | Yes |
| P0 wave decisions (P1–P10) | Yes — section below |

---

## P0 completion wave — locked decisions (2026-10-04)

Implementation and evidence: `P0_COMPLETION_REPORT.md`.

- **P1 — Homework rewards.** The server owns the reward. Recitation is not a required task while `audioUploadsEnabled` is false. The `homeworkRewards/{assignmentId}` marker, written in the same transaction as the credit, means a homework is never paid twice. The client only displays `awardedCoins`.
- **P2 — Points quarantine.** Nothing credits `points` any more (homework included). The field is kept. Coins, points and `totalStars` stay separate.
- **P3 — Supervisor awards.** `grantAward` keeps its scope and only increments `totalStars`.
- **P4 — Audio Library.** It is a separate feature from the Mushaf and is reachable from the Student profile tab. The player singleton is never disposed by a page Bloc. Listening progress is one document per `{uid}_{surahAudioId}`.
- **P5 — Messaging.** Halaqa groups contain the Teacher, Supervisor and Students (no Parents, no Admin). Parents use authorized 1:1 chats. Admin monitoring is not membership.
- **P6 — Posts.** Every new post targets exactly one Halaqa (`audienceTarget` = halaqaId). There is no academy-wide feed. Legacy `audienceTarget: 'all'` posts are visible to Admin only.
- **P7 — Shared Content.** Content is scoped to one Halaqa. Storage lives at `content_library/{halaqaId}/{uploaderUid}/…`, and the legacy `content/` path is read/delete only. Allowed files are PDF, audio, images and Word documents, up to 50 MB. The 50 MB cap is an engineering default, not a plan limit.
- **P8 — Halaqa plan («خطة الحلقة»).** It is a read-only projection of the student's lesson homework (`newMemorizationRange` and `reviewRange`, plus `isSubmitted`). The start point is the earliest recorded assignment. It shows no percentages and does not parse `versesRange`. The Mushaf last-read position is not progress.
- **P9 — Halaqa creation and roster.** These go through callables only: `adminCreateHalaqa`, `adminAddHalaqaSlot`, `admitStudentToHalaqa` and `adminTransferStudent`. A client may edit only the non-conflict fields `name`, `supervisorId` and `meetingLink`. `teacherId`, `schedule` and `studentIds` are frozen for clients.
- **P10 — Notification deep links.** Destinations are deterministic by type and role. Payloads carry the type only, and the role allowlist is re-checked on open. A type with no destination for the role shows «هذا الإشعار لا يرتبط بصفحة متاحة لحسابك».

### Deferred (documented, not implemented)

- **Points / game contract:** no mini-games and no external game API.
- **Halaqa-level plan contract:** a declared start, target and portions per track. A `versesRange` grammar is a prerequisite for any percentage.
- **Shared Content plan-limit contract:** paid-plan entitlement and per-plan storage limits. There is no pricing.
- **Teacher reassignment callable:** needs a conflict check. `teacherId` stays client-frozen until it exists.
- **Supervisor payment review for non-primary students:** proofs are listed only for students whose current Halaqa the Supervisor supervises.
- **Other deferred items:**
  - Supervisor evaluation correction.
  - D12 expansion.
  - Parent–child unlink policy (the callable supports unlinking; the policy on side effects is open).
  - An Admin award screen.
  - Supervisor schedule editing.
  - Audit retention.
  - Server-sent target IDs in notification payloads.
