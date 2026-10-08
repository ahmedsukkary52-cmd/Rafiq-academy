# Security / Data Contract Freeze — Rafiq Academy

**Status:** CONTRACT FREEZE (documentation only)  
**Date:** 2026-09-10  
**Code baseline:** `feature/full-product-audit` @ `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Product locks:** `PRODUCT_DECISIONS_LOCKED.md` (D1–D24) — **not reopened**  
**Security model:** `SECURITY_IMPLEMENTATION_SPEC.md`  
**Plan:** `IMPLEMENTATION_PLAN.md`  
**Wave A blueprint:** `WAVE_A_IMPLEMENTATION_SPEC.md`  
**WA-0→WA-2 batch status:** `WAVE_A_BATCH_WA0_WA2_STATUS.md`

```
PRODUCT DECISIONS (D1–D24)
        ↓
SECURITY MODEL (SECURITY_IMPLEMENTATION_SPEC)
        ↓
DATA CONTRACTS (this document)
        ↓
RULES / TRUSTED BACKEND BOUNDARY
        ↓
IMPLEMENTATION (future waves — not this phase)
```

**This document freezes security-critical contracts.** It does not contain Rules source, does not deploy, and does not modify application code.

---

## 0. How to read this freeze

### 0.1 Classification tags

| Tag | Meaning |
|-----|---------|
| **LOCKED** | Fixed by D1–D24 and/or this freeze; implementers must not invent alternatives |
| **IMPLEMENTATION-DEFINED BUT SAFE** | Exact code shape may vary; security semantics are fixed |
| **ENGINEERING/SECURITY CONTRACT** | Chosen here for secure architecture (not a silent product reopening of D1–D24) |
| **TBD — BLOCKING** | Prevents secure implementation of the named wave/unit |
| **TBD — NON-BLOCKING** | Can ship related work with documented defaults |

### 0.2 Evidence sources

| Source | Use |
|--------|-----|
| Freeze Dart entities / contracts | Prefer existing field names where compatible |
| D1–D24 | Product authority |
| `SECURITY_IMPLEMENTATION_SPEC.md` | Authz authority |
| Gaps in freeze | Defects to close — not “product allows open world” |

### 0.3 Freeze collections already evidenced

`users`, `studentProfiles`, `parentProfiles`, `teacherProfiles`, `halaqat` (+ `schedule[]`), `attendanceRecords`, `recitationRecords`, `payments`, `notifications`, `conversations`/`messages`, `academySettings/communication`, Storage `payment_proofs/{parentId}/{paymentId}/{fileName}`.

**Not in freeze today (required by locks):** `sessions`, pricing rules docs, payment-access docs, FCM token docs, audit logs, Parent-safe payment settings projection, Add Student Request docs, Halaqa group chat (beyond `admin_internal_group`).

---

## CONTRACT 1 — Admin User Creation (D1)

**Status:** **LOCKED** (security contract) + **IMPLEMENTATION-DEFINED BUT SAFE** (callable name / payload)

### 1.1 Policy

- No public self-registration.
- Auth identities for academy roles are **Admin-controlled**.
- Existing **studentId admission** (W8 / `AcademyAdmissionFirestore`) remains — it does **not** create Auth users.

### 1.2 Who creates Auth users

| Actor | Allowed? |
|-------|----------|
| Public client / `createUserWithEmailAndPassword` in production app | **✖ LOCKED** — remove/disable product path |
| Admin Flutter client calling Firebase Auth client SDK to create others | **✖ LOCKED** — insufficient privilege boundary |
| Trusted backend (Cloud Function / Admin SDK) invoked by authenticated Admin | **✔ LOCKED** — **ENGINEERING/SECURITY CONTRACT** |
| Firebase Console (ops bootstrap) | ✔ allowed for break-glass / initial Admin seed |

### 1.3 Authoritative flow (conceptual)

1. Authenticated Admin calls trusted callable (e.g. `adminProvisionUser`) with: email, temporary password or invite mode, display name, **role**, optional phone (Admin-only field), role-specific profile seeds.
2. CF verifies caller `users/{uid}.role == admin`.
3. CF creates Auth user via Admin SDK.
4. CF writes `users/{uid}` with **server-assigned** `role`, `isActive` (default per role policy), `email`, `name`, `phone` (if provided), `createdAt`.
5. CF creates role profile doc when required (`studentProfiles` / `parentProfiles` / `teacherProfiles`). **Do not** use `supervisorProfiles` as SSOT (D24).
6. Return uid to Admin UI.

### 1.4 Role assignment & SSOT

| Concern | Contract |
|---------|----------|
| Role SSOT | `users/{uid}.role` string (`AppRoles`) — **LOCKED** (matches freeze Rules pattern) |
| Custom claims | **Optional hardening** — not required. If added later, must mirror `users.role`; claims never sole SSOT until Rules migrate |
| Client self role change | **✖ LOCKED** |
| Role change after create | Admin-only via CF (or Admin SDK) — **LOCKED** |
| Profile consistency | CF creates Auth + `users` + profile in one logical operation; fail closed if any step fails |

### 1.5 Duplicates & partial failure

| Case | Contract |
|------|----------|
| Duplicate email | CF returns typed error; no orphan profile |
| Duplicate studentId / uid collision | Impossible if uid = Auth uid; admission uses existing uid |
| Auth created, Firestore failed | CF must compensate (delete Auth user **or** retry write with idempotency key). **IMPLEMENTATION-DEFINED BUT SAFE** — must not leave Auth user without `users` doc usable for login |
| Retry | Idempotent on email: if Auth user exists and `users` missing, Admin-only repair path |

### 1.6 Student admission path (unchanged product)

Supervisor/Admin admit **existing** `studentId` into halaqa — no Auth create. Membership writes must move to CF/Rules-hardened path (see Contract 14 / membership).

### 1.7 Freeze gap

Public `RegisterWithEmail` + datasource honoring arbitrary `role` = **defect**. Close in Wave A.

---

## CONTRACT 2 — Payment Access State (D5)

**Status:** **LOCKED** (semantics) · **ENGINEERING/SECURITY CONTRACT** (document shape)

### 2.1 Separation (mandatory)

| State machine | Purpose | Not for |
|---------------|---------|---------|
| `users.isActive` | Login kill switch / Admin disable / Auth disable | Payment delinquency |
| **Payment access** (this contract) | Commercial access after grace | No-Halaqa, archive |
| No-Halaqa | Membership waiting | Payment |
| Archive | Operational removal | Payment |

### 2.2 Document shape (minimum safe schema)

**ENGINEERING/SECURITY CONTRACT:** store payment-access on a dedicated doc:

`paymentAccess/{parentId}`

Rationale: Parent is the commercial actor; D5 suspends Parent **and** children; one parent may have multiple children/invoices.

| Field | Type (conceptual) | Owner | Client write |
|-------|-------------------|-------|--------------|
| `parentId` | string (= doc id) | CF | ✖ |
| `status` | enum below | CF | ✖ |
| `reason` | string | CF | ✖ |
| `primaryInvoiceId` | string? | CF | ✖ |
| `affectedStudentIds` | string[] | CF (from linked children + unpaid scope) | ✖ |
| `graceEndsAt` | timestamp? | CF | ✖ |
| `suspendedAt` | timestamp? | CF | ✖ |
| `warningIssuedAt` | timestamp? | CF | ✖ |
| `lastReminderAt` | timestamp? | CF | ✖ |
| `reinstatedAt` | timestamp? | CF | ✖ |
| `reinstatedBy` | uid? | CF | ✖ |
| `updatedAt` | timestamp | CF | ✖ |

**Allowed `status` values (LOCKED):**

| Status | Meaning |
|--------|---------|
| `ok` | No payment access restriction |
| `reminded` | Pre-due reminders sent (optional UX) |
| `due_warning` | On/after due, before grace end |
| `in_grace` | Past due; within Admin-configured grace |
| `suspended` | Past grace; Parent + children restricted |

Clients **MUST NOT** write `status`, `graceEndsAt`, `suspendedAt`, or reinstate fields.

### 2.3 Transitions (server-only)

```
ok → reminded → due_warning → in_grace → suspended
                 ↑_________________|  (scheduled CF)
suspended → ok   (Admin reinstate CF after valid paid review only)
```

- Proof `pending_review` does **not** auto-clear suspension or mark paid (D5).
- Valid **approved** review → `payments.status=paid` → may trigger reinstate eligibility; **Admin reinstate** remains explicit (D5) unless product later auto-reinstates — **LOCKED as Admin-triggered reinstate** for this freeze (matches D5 “Admin handles reinstatement”).

### 2.4 Read visibility

| Role | Read `paymentAccess/{parentId}` |
|------|----------------------------------|
| Parent (own) | ✔ (drives Pay Now / Contact Admin shell) |
| Admin | ✔ |
| Supervisor | ✔ for parents of students in supervised halaqat (**ENGINEERING/SECURITY**) |
| Teacher/Student | ✖ |

### 2.5 Child propagation

When `status == suspended`, CF sets feature gates for each `affectedStudentIds` entry (deny learning ops / group ops as per security spec). Prefer deriving child restriction from parent doc + `childrenIds` rather than duplicating writable flags on each student — if denormalized `studentProfiles.paymentAccessBlocked` is used for query convenience, it is **CF-only**.

### 2.6 Impossible client attacks

| Attack | Prevention |
|--------|------------|
| Write suspended → ok | Rules deny; only reinstate CF |
| Write overdue → paid on invoice | Contract 4/5 |
| Skip/Later bypass | UI + Rules deny non-allowed routes/writes while suspended |

---

## CONTRACT 3 — Academy Settings / Vodafone (D6)

**Status:** **LOCKED** (split Admin vs Parent-safe) · **ENGINEERING/SECURITY CONTRACT** (doc ids)

### 3.1 Existing freeze evidence

- `academySettings/communication` — Admin communication policy (`AdminCommunicationSettingsContract`). Rules: Admin RW.
- Vodafone destination currently empty constant `ParentPaymentProofContract.transferDestination` — **defect** vs D6.

### 3.2 Frozen layout

| Document | Purpose | Admin | Parent | Others |
|----------|---------|-------|--------|--------|
| `academySettings/communication` | Chat/comms policy (existing) | R/W | ✖ | ✖ |
| `academySettings/pricingDefaults` | Pricing defaults (Contract 4) | R/W | ✖ | ✖ |
| `academySettings/paymentPublic` | **Parent-safe payment projection** | R/W | **R** | ✖ Teacher/Student; Supervisor R optional |

### 3.3 `academySettings/paymentPublic` fields (LOCKED minimum)

| Field | Meaning | Client write |
|-------|---------|--------------|
| `vodafoneCashDestination` | Official number / destination string | ✖ (Admin/CF only) |
| `updatedAt` | Server timestamp | ✖ |
| `updatedBy` | Admin uid | ✖ |

**Forbidden on this doc:** other parents’ phones, staff phones, internal Admin notes, full pricing overrides, grace secrets if any.

**Grace period config** lives under Admin-only settings (e.g. `academySettings/pricingDefaults.gracePeriodDays`) — **not** on the public projection unless product explicitly wants Parents to see grace length (optional read — **NON-BLOCKING**; default: Parent does not need raw grace config, only resulting `paymentAccess` state).

### 3.4 Why separate doc

Firestore Rules cannot strip fields from `academySettings/*` selectively for Parent. Opening `communication` to Parent would over-expose. **Separate public projection is the frozen secure design.**

---

## CONTRACT 4 — Pricing + Invoice Generation (D3)

**Status:** **LOCKED** (behavior) · **ENGINEERING/SECURITY CONTRACT** (collections)

### 4.1 Pricing rule document

Collection: `pricingRules/{ruleId}` (Admin RW; all other roles ✖ write; Parent ✖ read of overrides — invoices carry snapshot)

| Field | Notes |
|-------|-------|
| `ruleId` | Doc id |
| `scope` | e.g. `academy_default` \| `halaqa` \| `student` — **IMPLEMENTATION-DEFINED BUT SAFE** |
| `scopeId` | halaqaId/studentId when scoped |
| `amount` | number |
| `currency` | string — default `EGP` **IMPLEMENTATION-DEFINED BUT SAFE** unless product sets otherwise |
| `billingPeriod` | e.g. `monthly` |
| `effectiveFrom` / `effectiveTo` | timestamps; null to = open |
| `active` | bool |
| `version` | int monotonic |
| `createdAt` / `updatedAt` / `updatedBy` | server |

Admin owns create/update. Inactive rules do not generate new invoices.

### 4.2 Invoice = existing `payments/{paymentId}` extended

Reuse freeze `PaymentEntity` fields as SSOT for commercial invoices (**LOCKED** — do not invent parallel invoice collection).

| Field (existing) | Writer after freeze |
|------------------|---------------------|
| `id` | CF on create |
| `studentId`, `parentId` | CF |
| `amount` | CF snapshot from rule — **immutable after create** |
| `dueDate` | CF |
| `status` | `due` \| `overdue` \| `paid` — CF/reviewer only for transitions |
| `method` | Parent sets `vodafone_cash` on proof; CF may leave null until proof |
| `paidAt` | Reviewer/CF on approve |
| Proof + review fields | Per `ParentPaymentProofContract` (freeze) |

**New server fields (ENGINEERING/SECURITY CONTRACT):**

| Field | Purpose |
|-------|---------|
| `pricingRuleId` | Source rule |
| `pricingRuleVersion` | Version snapshotted |
| `issuedAt` | Invoice creation time |
| `periodKey` | Idempotency key e.g. `yyyy-MM` + studentId |
| `currency` | Snapshot |

### 4.3 Client MUST NOT

- Choose/change `amount`, `dueDate`, `pricingRuleId`, `pricingRuleVersion`
- Set `status=paid` or clear `overdue`
- Create payment docs
- Alter `reviewedBy` / review fields

### 4.4 Generation responsibility

- **CF scheduled and/or event-triggered** from active pricing rules (D3).
- Admin configures rules; system generates invoices.

### 4.5 Idempotency

- Deterministic id **or** unique `periodKey`+`studentId` constraint — **IMPLEMENTATION-DEFINED BUT SAFE**.
- Retry must not create duplicate invoices for same student+period.
- Regeneration: do not rewrite historical `amount`; create future periods only.

### 4.6 Historical immutability

- Once issued, `amount` / `pricingRuleVersion` / `issuedAt` / `studentId` / `parentId` are immutable.
- Corrections: Admin/CF void+reissue pattern **TBD — NON-BLOCKING** (prefer new invoice + link, not mutate snapshot).

### 4.7 Payment reviewer (resolves IMPORTANT TBD)

**ENGINEERING/SECURITY CONTRACT (aligned with freeze + D5):**

| Action | Supervisor | Admin |
|--------|------------|-------|
| Review proof for students in supervised halaqat | ✔ | ✔ |
| Review any payment | ✖ | ✔ |
| Set `status=paid` via approve | ✔ (scoped) | ✔ |
| Reinstate `paymentAccess` | ✖ | ✔ only |

Wallet/Paymob remain OUT (D2).

---

## CONTRACT 5 — Overdue + Grace Period (D4, D5)

**Status:** **LOCKED**

### 5.1 Sources

| Datum | Source |
|-------|--------|
| Due date | `payments.dueDate` (CF-issued) |
| Grace length | Admin-only `academySettings/pricingDefaults.gracePeriodDays` (int ≥ 0) |
| Authoritative clock | **Server** (Cloud Functions scheduler) — **not** device time |

**Timezone:** **ENGINEERING/SECURITY CONTRACT** — evaluate due/grace in **Africa/Cairo** calendar days unless Admin later configures otherwise. Document in CF; do not trust client TZ.

### 5.2 Transitions

1. `now < dueDate` → reminders (CF + FCM); `paymentAccess` may be `reminded`
2. `now >= dueDate` and within grace → `payments.status=overdue` (stored); `paymentAccess=in_grace` / `due_warning`
3. `now >= dueDate + grace` → `paymentAccess=suspended`; propagate to children
4. Approved paid + Admin reinstate → `paymentAccess=ok`

### 5.3 Job idempotency

- Scheduled job may run twice: transitions must be **idempotent** (re-writing same `overdue` / same suspended state is no-op).
- Delayed job: catch up to current state in one pass (compute from dueDate+grace, not from “last run”).
- Payment received / approved during grace: invoice → paid; access remains until Admin reinstate (**LOCKED** per D5 Admin reinstatement).
- Proof `pending_review` during/after grace: does not block suspension; does not auto-pay.

### 5.4 Client

Cannot set overdue/paid/suspended. May read own invoice status and own `paymentAccess`.

---

## CONTRACT 6 — Session Schema + Migration (D9, D10)

**Status:** **LOCKED** (collection + minimum fields) · migration **LOCKED** strategy

### 6.1 Collection

`sessions/{sessionId}` — first-class SSOT.

### 6.2 Minimum fields

| Field | Required | Notes |
|-------|----------|-------|
| `sessionId` | ✔ | Doc id |
| `halaqaId` | ✔ | |
| `slotId` | ✔ | Stable id of schedule slot (**see 6.3**) |
| `date` | ✔ | Calendar date (Cairo) for the occurrence |
| `startAt` | ✔ | Timestamp absolute |
| `endAt` | ✔ | Timestamp absolute |
| `status` | ✔ | `scheduled` \| `in_progress` \| `completed` \| `cancelled` |
| `teacherId` | ✔ | Denormalized from halaqa at materialization (immutable after create except Admin correction) |
| `supervisorId` | optional | Denormalized; Supervisor conflict not blocked |
| `createdAt` / `updatedAt` | ✔ | Server |
| `createdBy` | ✔ | uid or `system` |

**Do NOT** store full unbounded `studentIds` copy on every session by default — membership derives from `halaqat.studentIds` at write time (**LOCKED** scalability). Optional frozen roster snapshot only if product later requires historical roster fidelity — **TBD — NON-BLOCKING**.

### 6.3 Slot identity

Freeze `halaqat.schedule[]` entries are `{day, startTime, endTime}` **without** slot ids today.

**ENGINEERING/SECURITY CONTRACT:** each schedule element MUST gain stable `slotId` (uuid) when written/edited. Sessions reference `slotId`. Migration: assign ids to existing slots before materializing sessions.

### 6.4 Lifecycle

| Status | Who may set |
|--------|-------------|
| `scheduled` | CF materializer / Teacher create-with-validation |
| `in_progress` / `completed` | Teacher of halaqa (Rules) within policy |
| `cancelled` | Teacher or Admin |

Historical completed sessions: `startAt`/`endAt`/`slotId`/`halaqaId` immutable except Admin audited correction.

### 6.5 Consumers

Attendance, evaluation, progress events, notifications **must** store `sessionId` pointing at this collection.

### 6.6 Migration from synthetic day ids

Freeze SSOT today: `{halaqaId}_yyyyMMdd` (`AttendancePolicy.sessionIdForDay`).

| Phase | Contract |
|-------|----------|
| Dual-read | New writes use real `sessions/{id}`; readers accept legacy synthetic ids on old attendance/eval |
| Historical-only | Legacy synthetic ids remain on old docs; **not** production SSOT for new ops |
| Backfill | Optional CF creates `sessions` for past days — **NON-BLOCKING** for Wave B go-live if dual-read works |
| No silent rewrite | Do not mass-rewrite historical attendance ids without migrator + audit |

Weekly UI ids `{halaqaId}_{slotIndex}` must not be used as operational session ids.

---

## CONTRACT 7 — Session Conflict Engine (D9)

**Status:** **LOCKED** (rules of conflict) · engine placement **LOCKED** (trusted backend)

### 7.1 Hard conflicts

Overlap is a hard conflict when any of:

- Same **teacherId**
- Same **student** (via halaqa roster intersection for candidate sessions)
- Same **halaqaId**

**Supervisor** time overlap: **allowed** (D9).

### 7.2 Overlap definition (LOCKED)

Use half-open intervals `[startAt, endAt)`:

- Exact same time → conflict
- Partial overlap → conflict
- Touching boundary (`a.endAt == b.startAt`) → **NOT** conflict
- `cancelled` sessions → excluded from conflict set
- `completed` past sessions → excluded for **future** scheduling conflicts; do not block history
- Draft: not in product — N/A

### 7.3 Validation

| Step | Actor |
|------|-------|
| Propose slot/session times | Admin/Teacher client |
| Final validation + write | **Trusted backend / transaction** — **LOCKED** |
| Race prevention | Transaction or single CF serializer per academy/halaqa |
| Duplicate session | Unique key `(halaqaId, slotId, date)` — **LOCKED** |

Client validation is UX-only.

---

## CONTRACT 8 — Halaqa Group Chat ID / Sync (D14)

**Status:** **LOCKED** (membership + id strategy)

### 8.1 Identity

**ENGINEERING/SECURITY CONTRACT:**

- Deterministic conversation id: `halaqa_group_{halaqaId}`
- `conversations/{id}` fields include `kind: 'halaqa_group'`, `halaqaId`, `participantIds`
- Optionally denormalize `halaqat.groupConversationId` for lookup — keep **both consistent via CF**

### 8.2 Membership SSOT

| Member | Source |
|--------|--------|
| Teacher | `halaqat.teacherId` |
| Supervisor | `halaqat.supervisorId` |
| Students | `halaqat.studentIds` |
| Parent | **✖ not member** |
| Admin | Monitor via D13; not automatic member |

### 8.3 Sync triggers (CF only)

On: create halaqa group, admit/transfer/archive student, assignStaff teacher/supervisor change.

Clients **MUST NOT** `arrayUnion` themselves into `participantIds`.

### 8.4 Behavior matrix

| Event | Group effect |
|-------|--------------|
| Student transfer out | Remove from old group; add to new (if any) |
| Student no-Halaqa | Remove from all halaqa groups |
| Student archive | Remove from groups; history retained |
| Teacher replacement | Remove old teacher; add new |
| Supervisor replacement | Remove old; add new |
| Duplicate create | Idempotent ensure on deterministic id |

### 8.5 Messaging

- Teacher may send announcements (message `type: announcement` optional — **IMPLEMENTATION-DEFINED BUT SAFE**)
- Supervisor **direct** chat remains 1:1; group is the group exception
- Admin monitors all groups (D13)

### 8.6 1:1 still relationship-bound

Create 1:1 only when D12/D14 graph allows; Rules + CF.

---

## CONTRACT 9 — Chat Delete / Retention (D20)

**Status:** **LOCKED** (soft-delete) · retention duration **TBD — NON-BLOCKING**

### 9.1 Message fields (extend freeze messages)

| Field | Notes |
|-------|-------|
| `senderId` | = auth uid on create |
| `text` / media refs | |
| `sentAt` | |
| `editedAt` | nullable |
| `deletedAt` | nullable — soft delete |
| `deletedBy` | uid |
| `deleted` | bool convenience |

### 9.2 Semantics (LOCKED)

- **Delete = soft-delete** for production v1.
- Content redacted in client UI for normal participants after delete.
- Media: mark deleted; **physical Storage delete asynchronous** only after retention policy — until then retain for Admin/audit.
- Edit: sender only; within time window **IMPLEMENTATION-DEFINED BUT SAFE** (recommend ≤ 15 minutes) enforced by CF/Rules.
- Hard delete of message docs: **forbidden** until retention policy set.

### 9.3 Who

| Action | Sender | Admin monitor | Other participants |
|--------|--------|---------------|--------------------|
| Edit own | ✔ | ✖ (unless sender) | ✖ |
| Soft-delete own | ✔ | ✔ moderated delete **ENGINEERING** | ✖ |
| See deleted body | ✖ (tombstone) | ✔ Admin monitor may see tombstone metadata; full body retention **TBD — NON-BLOCKING** | tombstone only |

### 9.4 Retention period

**TBD — NON-BLOCKING** for enabling soft-delete + media upload.  
Freeze `conversationRetentionDays` default 365 on communication settings — may inform later policy but **not** auto-hard-delete until Product/Policy confirms.

---

## CONTRACT 10 — Storage Media Paths

**Status:** **LOCKED** (path patterns + ownership)

### 10.1 Existing

| Category | Path | Upload | Read (target) | Delete |
|----------|------|--------|---------------|--------|
| Payment proofs | `payment_proofs/{parentId}/{paymentId}/{fileName}` | Parent owner; image; &lt;10MB (freeze) | Parent + reviewers + Admin | `false` (evidence) |

Catch-all `/{allPaths=**}` must be **removed** (security defect).

### 10.2 Frozen additional patterns (ENGINEERING/SECURITY)

| Category | Path | Uploader | Reader | Notes |
|----------|------|----------|--------|-------|
| Profile images | `profile_images/{uid}/{fileName}` | `uid == auth` | Signed-in per profile visibility (no phone) | Replace allowed |
| Chat images | `chat_media/{conversationId}/{messageId}/{fileName}` | Participant of conversation | Participants + Admin monitor | MIME image/*; size cap **IMPLEMENTATION-DEFINED** (use communication maxFileSizeMb as guide) |
| Voice messages | `chat_voice/{conversationId}/{messageId}/{fileName}` | Participant | Participants + Admin monitor | audio/* |
| Attachments | `chat_attachments/{conversationId}/{messageId}/{fileName}` | Participant if enabled | Same | allowlist types |
| Recitation audio | `recitations/{studentId}/{assignmentId}/…` | Student own; only if `audioUploadsEnabled` | Teacher of assignment + own | Gated false today |
| Award images | Keep existing awards path if present; lock to grantor staff | Staff | Relevant roles | |

### 10.3 Hard requirements

- Client **cannot** pick another user’s `{uid}` or foreign `{conversationId}` path — Rules bind path segments to auth + membership.
- Orphan cleanup: payment proofs retain; chat media GC after soft-delete + retention — CF responsibility.
- Historical archive: keep objects readable to Admin.

---

## CONTRACT 11 — FCM Token + Send Pipeline (D19, D17)

**Status:** **LOCKED**

### 11.1 Token docs

`fcmTokens/{uid}/devices/{deviceId}` (or equivalent subcollection) — **ENGINEERING/SECURITY CONTRACT**

| Field | Notes |
|-------|-------|
| `token` | string |
| `platform` | `android` \| `ios` \| `web` |
| `updatedAt` | |
| `createdAt` | |
| `disabled` | bool for invalid tokens |

- User may have **multiple** devices.
- Create/update/delete: **own uid only**.
- Idempotency: upsert by `deviceId` or token hash.

### 11.2 Send pipeline (LOCKED)

```
Trusted event (eval commit, payment reminder, …)
  → CF / server handler
    → write notifications/{id} (deterministic where possible)
    → read fcmTokens for authorized audience only
    → Admin SDK FCM send
    → mark invalid tokens disabled
```

Client **MUST NOT**:

- Choose arbitrary recipient uids for privileged notifies
- Write notification docs for other users’ `audience`
- Invoke raw FCM from client with server key

### 11.3 Live Evaluation chain (D17) — LOCKED

1. Teacher persists evaluation (authorized; D7 gate) — via the `upsertSessionEvaluation` callable. Teacher may edit for 24h from the server-set `createdAt`; Admin may correct afterwards; Supervisor is read-only (D7.1). Corrections never re-push (per-device delivery ledger).
2. Server publishes Academy Event (existing sink pattern; after commit)
3. Handler creates Parent notification(s) via `childrenIds` resolver
4. CF sends FCM to those parents’ tokens
5. Parent opens evaluation under relationship Rules

Fabricating steps 2–4 from client is forbidden.

### 11.4 Deduping

Keep freeze deterministic notification ids for W4/W5-style events; FCM collapse key **IMPLEMENTATION-DEFINED BUT SAFE**.

---

## CONTRACT 12 — Billing Verification (D19/D20 infra)

**Status:** **LOCKED** as process · prices **verification-needed**

See `FIREBASE_BILLING_CHECKLIST.md`. This freeze adds:

| Service | Blaze typically? | Cost drivers | Scale note | Migration | Budget |
|---------|------------------|--------------|------------|-----------|--------|
| Firestore | Verify (prod usually Blaze) | Reads/writes/storage | Avoid unbounded listeners | Project+indexes+rules | Alert on spike |
| Storage | Verify | GB stored/downloaded | Proofs+chat media grow | Bucket+rules | GB alerts |
| Cloud Functions | **Usually yes** | Invocations/time | Schedulers × academy | `functions/` `europe-west1` | Error+cost alerts |
| FCM | Verify; send path needs Functions | Message volume | Fan-out storms | Apps+Admin SDK | Cap broadcasts |
| Auth | Verify MAU limits | MAU | All roles | User export/import | — |
| App Check | Verify | Attestation | All clients | Providers | Enable post-rules |
| Paymob functions | **OUT** | Would cost if left | Disable | Do not migrate active | Confirm off |

**Do not invent dollar prices.** Mark each row Verified with Firebase doc URL before enabling Blaze on academy account.

**Pre-Blaze gate remains BLOCKING** for FCM/Functions production enablement — not for writing Rules offline or dual-read session design.

---

## CONTRACT 13 — Arabic Search Normalization (D16)

**Status:** **ENGINEERING/SECURITY CONTRACT** (projection) · algorithm details **IMPLEMENTATION-DEFINED BUT SAFE**

### 13.1 Safe search projection

Collection: `studentSearch/{studentId}` — CF-maintained on profile/halaqa changes.

| Field | Exposed to non-Admin search |
|-------|------------------------------|
| `studentId` | ✔ |
| `fullName` | ✔ |
| `fullNameNormalized` | ✔ (query key) |
| `halaqaId` / `halaqaName` | ✔ |
| `disambiguator` | ✔ non-sensitive (e.g. short code / birth year if product has it — else omit) |
| `phone` | **✖ never** |

### 13.2 Normalization rules (minimum)

Apply consistently on write:

- Strip Arabic diacritics (tashkeel)
- Normalize alef variants (أ إ آ ٱ → ا)
- Normalize teh marbuta / yeh variants as product chooses — document in code comments
- Collapse whitespace; lowercase Latin if any

### 13.3 Role scope

| Role | Query scope |
|------|-------------|
| Admin | All students |
| Supervisor | Students in supervised halaqat |
| Teacher | Own halaqa rosters |
| Parent | Linked children only (usually not directory search) |
| Student | ✖ directory |

### 13.4 Technology

Use Firestore prefix/`>=`/`<=` on `fullNameNormalized` or client filter within scoped results. **Do not** introduce Algolia/Elastic without a separate decision — mark as future if needed.

---

## CONTRACT 14 — Roster / Access Status Enum (D5, D18, D21)

**Status:** **LOCKED** (distinct dimensions)

Do **not** collapse into one enum field.

### 14.1 Dimensions

| Dimension | Field / derivation | Values |
|-----------|-------------------|--------|
| Account login | `users.isActive` | true / false |
| Payment access | `paymentAccess.status` | ok / reminded / due_warning / in_grace / **suspended** |
| Halaqa assignment | `studentProfiles.halaqaId` + roster membership | assigned / **no_halaqa** |
| Operational lifecycle | `studentProfiles.lifecycle` **or** `users.lifecycle` | `active` \| `archived` |

**ENGINEERING/SECURITY CONTRACT:** add `lifecycle: active|archived` on `studentProfiles` (CF/Admin only). Default `active`.

### 14.2 UI labels (compose)

| Label | Rule |
|-------|------|
| نشط / Active | lifecycle=active AND isActive AND payment not suspended AND has halaqa |
| موقوف دفع / Payment suspended | paymentAccess.suspended (Parent+child) |
| بانتظار حلقة / Waiting | no_halaqa AND lifecycle=active |
| مؤرشف / Archived | lifecycle=archived |

### 14.3 Transitions (who)

| Transition | Who |
|------------|-----|
| isActive toggle | Admin (authorized workflow / Student Profile) |
| payment suspend/reinstate | CF + Admin reinstate |
| assign/transfer/no-halaqa | CF admission/transfer (D12/D21) |
| archive | Admin CF |
| unarchive | Admin CF |

---

## CONTRACT 15 — Mushaf Last-Read (D23)

**Status:** **LOCKED** (ownership + separation from progress)

### 15.1 Storage

**ENGINEERING/SECURITY CONTRACT:** `mushafReading/{studentId}` (own uid only)

| Field | Client write (own) | Notes |
|-------|--------------------|-------|
| `surahNumber` | ✔ | 1 = Al-Fatihah default when missing |
| `ayahNumber` | ✔ | |
| `pageNumber` | optional | if UI uses pages |
| `updatedAt` | server or client | last-write-wins multi-device |
| `visualMode` | ✔ optional | which of two polished modes — UI concern |

### 15.2 Security

- Only owner R/W; Admin may R for support.
- **Not** memorization progress (D11).
- No privileged aggregates.

### 15.3 Multi-device

Last-write-wins on `updatedAt` — **IMPLEMENTATION-DEFINED BUT SAFE**.

Two visual modes: UI-only unless `visualMode` stored as above.

---

## CONTRACT 16 — Audit Log / Retention

**Status:** **LOCKED** (events + immutability) · retention days **TBD — NON-BLOCKING**

### 16.1 Collection

`auditLogs/{logId}` — **CF / Admin SDK write only**; Admin read; all other roles ✖

### 16.2 Executable NEW-document schema (WA-16)

| Field | Required | Notes |
|-------|----------|-------|
| `actorId` | ✔ | Authenticated caller UID, or `"system"` for future scheduler hooks |
| `actorRole` | ✔ | `"admin"`, `"system"`, `"supervisor"` or `"teacher"` (PH-02 amendment) — derived server-side from `users/{uid}.role`, never from client input |
| `action` | ✔ | Central vocabulary (below) |
| `targetType` | ✔ | e.g. `user`, `studentProfile`, `paymentAccess`, `invoice`, `migration` |
| `targetId` | ✔ | Deterministic subject / run id |
| `timestamp` | ✔ server | `FieldValue.serverTimestamp()` |
| `metadata` | ✔ map | Always present (may be `{}`); allowlisted operational facts only |
| `source` | recommended | Callable / scheduler name |

**NEW documents must not emit** legacy fields `actorUid` or `createdAt`.  
**Historical documents** may still contain those fields / old action names / flat extras — **not migrated** by WA-16.

### 16.3 Action vocabulary

**Emitted by WA-16 (existing server ops):**  
`user_provision`, `payment_reinstate`, `user_archive`, `user_unarchive`, `invoice_create`,  
plus operational migration actions: `admin_migrate_user_phones`, `halaqa_schedule_slotid_migrate`, `student_lifecycle_backfill`, `student_search_backfill`.

**Emitted by PH-02 (server-authoritative workflows):**  
`payment_review` (Admin / scoped Supervisor), `student_admit` (Admin / scoped Supervisor), `student_transfer` (Admin / Supervisor of both halaqat), `attendance_correct` (Admin outside the Teacher window), `evaluation_create_or_correct` (halaqa Teacher within 24h, or Admin at any time — D7.1; change-only, spec §20.1; metadata `sessionId`, `halaqaId`, `studentId`, `evaluationType`, `versesRange`, `operation` — never grades or notes). Actor roles `supervisor` / `teacher` are only ever produced by `actorForCallerRole` from the server-loaded role; Parent / Student never author audits. See `PH02_SUPERVISOR_AUTHORITY_REVIEW.md`.

**Deferred audit hooks** (contract ready; pending authoritative CF / scheduler):  
`payment_suspend`, `relationship_children_change`, `session_create_or_correct`, `admin_pricing_change`, `admin_vodafone_change`, `chat_message_moderate_delete`.

### 16.4 Immutability / retention

No client create/update/delete. Retention purge only via Admin CF after policy set (**TBD — NON-BLOCKING**).  
Delivery guarantee: at-least-once append with operation-level change-only idempotency; possible audit gap if mutation succeeds and audit write fails. No durable outbox in WA-16.

---

## Cross-Contract Invariants

1. Client never controls privileged state transitions (`paid`, `overdue`, `paymentAccess`, `lifecycle=archived`, `role`).
2. Client cannot elevate `users.role`.
3. Client cannot mutate `childrenIds` or `halaqat.studentIds` directly.
4. Client cannot fabricate payment status or review fields.
5. Client cannot fabricate evaluation → notification → FCM chain.
6. Client cannot choose arbitrary FCM recipients.
7. Client cannot access another user’s private data outside relationship/halaqa scope.
8. Non-Admin never receives `users.phone` (safe projections only).
9. Halaqa membership is authoritative and server-validated.
10. `sessions/{sessionId}` is authoritative for new attendance/evaluation.
11. Historical financial / evaluation / session records are not casually overwritten (snapshots immutable).
12. Payment suspension, no-Halaqa, and archive are separate dimensions.
13. Idempotency required for scheduled/backend operations (invoices, overdue, suspend, session ensure, group sync).
14. Race-sensitive operations require atomic/trusted validation (conflicts, review vs resubmit, transfer).
15. Firestore/Storage Rules are necessary but not sufficient where CF is marked required.

---

## Rules vs Trusted Backend Matrix

| Operation | Rules sufficient? | Trusted backend required? | Why |
|-----------|-------------------|---------------------------|-----|
| Profile safe-field read/update (own) | ✔ | — | Ownership |
| Phone read | ✔ (Admin-only / deny others) | Projection CF helpful | Field stripping limits |
| childrenIds mutation | ✖ alone | **✔** | Graph integrity |
| Student transfer / no-halaqa / archive | ✖ | **✔** | Multi-doc + groups |
| Halaqa create with slots | Partial (reject empty schedule) | **✔** if conflicts | D8/D9 |
| Session create / materialize | Partial | **✔** conflict final | D9 races |
| Session conflict validation | ✖ | **✔** | Multi-resource |
| Attendance write | ✔ with session+teacher checks | — | Ownership |
| Evaluation write | ✔ + attendance read hard | **✔ preferred** for gate | D7 integrity |
| Progress projection | ✖ | **✔** | Aggregate trust |
| Invoice creation | ✖ | **✔** | D3 |
| Payment proof submit | ✔ field allowlist | — | Parent own |
| Payment review → paid | Partial | **✔ preferred** | Scope + audit |
| Overdue transition | ✖ | **✔** | Scheduler |
| Payment suspension | ✖ | **✔** | Cross-user |
| Reinstatement | ✖ | **✔** Admin CF | D5 |
| Chat 1:1 create | ✔ if relationship expressible | CF may pre-check | D14 |
| Halaqa group membership | ✖ | **✔** | Sync |
| Message send | ✔ participant | — | |
| Message soft-delete | ✔ sender/Admin | — | |
| Storage upload | ✔ path bind | — | |
| FCM token write | ✔ own | — | |
| FCM send | ✖ | **✔** | D19 |
| Academy Event / notify create | ✖ for others | **✔** | Spoof |
| Audit log write | ✖ | **✔** | Tamper |
| Admin Auth createUser | ✖ | **✔** | Admin SDK |
| Vodafone public settings write | ✔ Admin | — | |
| Pricing rules write | ✔ Admin | — | |

---

## Implementation Dependency Order

```
C1 Admin provision + role immutability + close public register
C3 paymentPublic + C2 paymentAccess schema (docs exist)
C12 billing verification ──before── C11 FCM send / heavy Functions
        ↓
Wave A: Rules tightness (phone, paid fields, childrenIds deny, catch-all Storage)
        ↓
C6 sessions + C7 conflicts + slotId on schedule  → Wave B
        ↓
Attendance/Eval (D7) on sessionId → C11 live-eval notify (needs C11 tokens optional until FCM on)
        ↓
C4 pricing + invoices → C5 overdue/grace → C2 transitions → Wave D
        ↓
C8 group chat + C9 soft-delete + C10 media paths → Wave F
        ↓
C13 search projection → Admin/Teacher directories
C14 lifecycle fields → Admin Student Profile
C15 mushaf last-read → Mushaf work (parallel, low coupling)
C16 audit logs → enable with each privileged CF
```

### Hard dependencies

| Before… | Must freeze/implement |
|---------|----------------------|
| Wave A | C1 policy, C3 split, phone projection approach, deny paid/childrenIds |
| Wave B sessions | C6, C7, slotId |
| Attendance/Evaluation | C6 + D7 gate |
| Payments | C2, C3, C4, C5, reviewer matrix |
| Chat groups/media | C8, C9, C10 |
| FCM production | C11 + C12 verified |
| Search | C13 |
| Admin roster UX | C14 |
| Mushaf | C15 (independent) |

---

## FINAL BLOCKER REVIEW

### BLOCKERS REMAINING

| ID | Reason | Affected | Decision still needed? |
|----|--------|----------|------------------------|
| **B-BILLING** | Blaze/Functions/FCM not verified against live Firebase docs/account | C11 send, invoice/overdue/suspend CFs, media at scale | **Yes** — complete `FIREBASE_BILLING_CHECKLIST` Verified column (no invented prices) |
| **B-SLOT-ID-MIGRATE** | Existing `schedule[]` lacks `slotId` in freeze data | C6/C7 materialization | **Implementation task**, not product — blocked until migrator assigns ids (documented here; engineering execution remains) |

> Note: Former schema blockers (paymentAccess shape, paymentPublic doc, sessions fields, group id, soft-delete, storage paths, FCM token shape, Admin createUser boundary, reviewer roles) are **frozen above** as ENGINEERING/SECURITY CONTRACTs. They are no longer “unknown schemas.”

### IMPORTANT BUT NON-BLOCKING

| Item | Notes |
|------|-------|
| Audit retention days | Soft-delete works without purge |
| Admin visibility of deleted message bodies | Tombstone metadata enough for v1 |
| Session historical roster snapshot | Derive from halaqa unless disputes require freeze |
| Parent visibility of gracePeriodDays | Optional |
| Void+reissue invoice correction pattern | Prefer new invoice later |
| Mushaf pageNumber vs ayah | UI choice |
| Soft-delete edit window minutes | Recommend 15m |
| Arabic yeh/teh normalization edge cases | Document in code |
| Custom claims | Optional |
| Auto-reinstate on paid (vs Admin-only) | **LOCKED Admin reinstate** for now |

### FULLY FROZEN

- C1 Admin createUser via trusted backend; role SSOT `users.role`; no public register  
- C2 `paymentAccess/{parentId}` states + server-only transitions; ≠ `isActive`  
- C3 `academySettings/paymentPublic` vs Admin-only settings  
- C4 `pricingRules` + `payments` snapshots; client cannot set amount/paid  
- C5 Server overdue/grace; Cairo day evaluation contract  
- C6 `sessions/{sessionId}` minimum fields; legacy synthetic ids historical-only  
- C7 Half-open overlap; Teacher/Student/Halaqa hard; Supervisor allowed; CF final  
- C8 `halaqa_group_{halaqaId}`; CF membership sync; Parent not member  
- C9 Soft-delete messages; no hard-delete until retention policy  
- C10 Path ownership patterns; remove Storage catch-all  
- C11 Own tokens; CF send; live-eval chain  
- C12 Verification process (not prices)  
- C13 Safe `studentSearch` projection; no phone  
- C14 Four status dimensions + compose labels  
- C15 Own mushaf last-read ≠ progress  
- C16 CF-only audit logs  
- Payment reviewer: Supervisor scoped + Admin global; reinstate Admin-only  

---

## Consistency vs D1–D24

| D | Covered by |
|---|------------|
| D1 | C1 |
| D2 | C4 (vodafone only), OUT wallet/Paymob |
| D3 | C4 |
| D4 | C5 |
| D5 | C2, C5, C14 |
| D6 | C3 |
| D7 | C6 consumers + matrix |
| D8–D10 | C6, C7 |
| D11 | Progress client-deny (invariants); separate C15 |
| D12 | childrenIds CF; search C13 |
| D13–D14 | C8, C9 |
| D15 | N/A data (AR/RTL) |
| D16 | C3, C13, phone invariants |
| D17 | C11 |
| D18 | C14 |
| D19 | C11, C12 |
| D20 | C9, C10 |
| D21 | C14, C8 sync |
| D22 | Auth persistence (security spec) |
| D23 | C15 |
| D24 | No supervisorProfiles SSOT |

---

## Explicit non-goals

- Implementing Rules/Functions/migrations in this phase  
- Reopening D1–D24  
- Inventing Paymob/wallet  
- Publishing dollar cost estimates  
- Designing Mushaf UI  

**End of contract freeze. Documentation only. STOP.**
