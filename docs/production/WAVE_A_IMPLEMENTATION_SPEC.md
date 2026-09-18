# Wave A Implementation Specification — Rafiq Academy

**Status:** DOCUMENTATION ONLY — blueprint for future coding agents  
**Date:** 2026-09-10  
**Code baseline:** `feature/full-product-audit` @ `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Architecture note:** Freeze uses **Bloc** (not Cubit). Do not migrate to Cubit in Wave A.

```
PRODUCT (D1–D24)
  → SECURITY_IMPLEMENTATION_SPEC
    → SECURITY_DATA_CONTRACT_FREEZE (C1–C16)
      → THIS DOCUMENT (Wave A blueprint)
        → future code / rules / functions (NOT this phase)
```

**Authoritative inputs (do not reopen):**  
`PRODUCT_DECISIONS_LOCKED.md`, `SECURITY_IMPLEMENTATION_SPEC.md`, `SECURITY_DATA_CONTRACT_FREEZE.md`, `IMPLEMENTATION_PLAN.md`, audits, `FIREBASE_BILLING_CHECKLIST.md`.

**This phase does not:** write `lib/`, Rules, Functions, indexes deploy, migrations execution, commits, or pushes.

---

## 1. Wave A purpose

Wave A builds the **security and data foundation** so later waves (B sessions/ops, D payments UX, E FCM fan-out, F chat media/groups) do not invent schemas or trust the client for privileged transitions.

### 1.1 In scope (Wave A must deliver)

| ID | Unit | Primary contracts | Primary decisions |
|----|------|-------------------|-------------------|
| **WA-0** | Billing verification gate | C12 | D19/D20 infra |
| **WA-1** | Auth provisioning + close public register | C1 | D1, D22 |
| **WA-2** | Authorization / Rules blueprint + phone model | C1, C3, C10 | D1, D2, D13, D14, D16, D24 |
| **WA-3** | `paymentAccess` foundation | C2 | D5 |
| **WA-4** | Academy settings split (`paymentPublic` + pricingDefaults) | C3, C4, C5 | D3, D5, D6 |
| **WA-5** | Pricing rules + invoice **ownership** foundation | C4 | D2, D3 |
| **WA-6** | Overdue/grace **job contract** (scheduler design) | C5 | D4, D5 |
| **WA-7** | `slotId` migration design + prerequisite | C6, C7 | D8–D10 |
| **WA-8** | `sessions` schema + materializer **contract** (stub OK) | C6, C7 | D9, D10 |
| **WA-9** | Conflict engine **contract** (CF final) | C7 | D9 |
| **WA-10** | Halaqa group id/membership **sync contract** | C8 | D14 |
| **WA-11** | Chat authz foundation (1:1 relationship; soft-delete fields) | C8, C9 | D13, D14, D20 |
| **WA-12** | Storage path foundation + catch-all removal plan | C10 | D2, D20 |
| **WA-13** | FCM token schema + send-chain contract | C11 | D17, D19 |
| **WA-14** | `studentSearch` projection | C13 | D16 |
| **WA-15** | Roster status dimensions (`lifecycle` + compose) | C14 | D5, D18, D21 |
| **WA-16** | `auditLogs` foundation | C16 | — |
| **WA-17** | Indexes prerequisites for Wave A queries | — | scalability audit |
| **WA-18** | Quarantine wallet / Paymob / `supervisorProfiles` | C4, D24 | D2, D24 |
| **WA-19** | Wave A test matrix | — | — |
| **WA-20** | Explicit exclusions | C15 etc. | D11, D15, D23 |

### 1.2 Intentionally later waves (document only here)

| Concern | Wave | Why not full Wave A feature |
|---------|------|------------------------------|
| Attendance/eval Present/Late gate UX + writers | **B** | Needs live sessions after B-SLOT-ID-MIGRATE |
| Progress projectors / versesRange UI | **C** | D11; needs eval contract from B |
| Parent Pay Now shell polish / full invoice UX | **D** | Schemas in A; product UI in D |
| Live-eval notify + FCM **send** in production | **E** | Blocked by **B-BILLING** for production send |
| Chat media upload UI + group UX polish | **F** | Paths/membership contracts in A |
| Shared AR chrome / terminology | **G** | D15 |
| Mushaf redesign / last-read UI | later / **U-MUSHAF** | C15 schema only optional stub |
| Unbounded listener pagination finish | **H/F** | Classify risks in A; fix in later |

### 1.3 Hard blockers affecting Wave A

| Blocker | Effect on Wave A |
|---------|------------------|
| **B-BILLING** | May design CF/FCM contracts and write emulator tests; **must not** enable Blaze / production FCM send / production scheduled invoice/overdue jobs until checklist Verified |
| **B-SLOT-ID-MIGRATE** | Session materialization and conflict engine **cannot go live** until existing `halaqat.schedule[]` entries have stable `slotId` |

---

## 2. Global dependency graph

```
Wave 0 locks (D1–D24) + C1–C16 freeze
        ↓
WA-0  Billing verification (C12)     ←── production CF/FCM gate
        ↓
WA-1  Admin provision CF + disable public register (C1)
WA-18 Quarantine wallet/Paymob/supervisorProfiles
        ↓
WA-2  Rules blueprint: role immutable, phone, paid fields,
      childrenIds deny, Storage catch-all removal plan
        ↓
WA-4  academySettings/paymentPublic + pricingDefaults (C3/C5)
WA-3  paymentAccess/{parentId} schema + Rules deny client write (C2)
WA-5  pricingRules + payments server fields (C4)
WA-16 auditLogs (C16)
        ↓
WA-14 studentSearch projection (C13)
WA-15 lifecycle + status compose (C14)
        ↓
WA-7  schedule[] → slotId migration (B-SLOT-ID-MIGRATE)
        ↓
WA-8  sessions collection + materializer CF (C6)
WA-9  conflict validation CF (C7)
        ↓
WA-10 halaqa_group_{id} ensure/sync CF (C8)
WA-11 1:1 relationship create checks + message soft-delete fields (C9)
WA-12 Storage path Rules plan (C10)
        ↓
WA-13 fcmTokens schema; send CF stub (C11) — production send after WA-0
WA-6  overdue/grace scheduled CF — production after WA-0
WA-17 indexes as queries land
        ↓
Wave B / D / E / F feature completion
```

---

## 3. Contract ↔ Wave A unit map

| Contract | Wave A units | Notes |
|----------|--------------|-------|
| C1 | WA-1, WA-2 | Provision CF; close register; role immutable |
| C2 | WA-3, WA-6 | Doc + scheduled transitions (prod after billing) |
| C3 | WA-4 | `paymentPublic` |
| C4 | WA-5, WA-18 | pricingRules; payments snapshot fields; no wallet/Paymob |
| C5 | WA-4, WA-6 | gracePeriodDays; overdue job |
| C6 | WA-7, WA-8 | slotId + sessions |
| C7 | WA-9 | conflict CF |
| C8 | WA-10 | group sync |
| C9 | WA-11 | soft-delete fields |
| C10 | WA-12 | paths |
| C11 | WA-13 | tokens + send chain |
| C12 | WA-0 | billing gate |
| C13 | WA-14 | studentSearch |
| C14 | WA-15 | lifecycle dimensions |
| C15 | WA-20 exclusion / optional stub only | Mushaf UI out |
| C16 | WA-16 | auditLogs |

---

## 4. Implementation units (detailed)

Legend for mutations: **client** · **rules** · **CF callable** · **CF trigger** · **CF scheduled** · **server-transactional**

Architecture: Clean Architecture feature folders; **Bloc** for presentation; repositories + remote datasources; prefer extending existing shared contracts (`ParentPaymentProofContract`, `AcademyAdmissionFirestore`, `AdminCommunicationSettingsContract`, `AttendancePolicy`, `ChatPermissionPolicy`).

---

### WA-0 — Billing verification gate (C12)

| | |
|--|--|
| **Purpose** | Gate production Blaze / Functions / FCM / Storage growth |
| **Source** | C12, `FIREBASE_BILLING_CHECKLIST.md`, D19/D20 |
| **Baseline** | Checklist template; Verified column empty |
| **Target** | Every checklist row has Verified date + Firebase doc URL before production CF/FCM |
| **Schema** | None |
| **Client** | None |
| **Backend** | None until verified |
| **Security** | N/A |
| **Indexes** | None |
| **Migration** | None |
| **Tests** | Checklist completeness review |
| **Deps** | None |
| **Done when** | Pre-Blaze gate boxes checked; Paymob confirmed disabled on target project |
| **Non-goals** | Inventing prices; enabling Blaze in this doc phase |

**What Wave A may still do offline:** design CF interfaces, Rules text (later PR), emulator tests. **What it must not do in production:** schedule invoice/overdue/FCM send against unpaid Blaze.

---

### WA-1 — Auth provisioning + close public register (C1, D1)

| | |
|--|--|
| **Purpose** | Admin-controlled Auth identities; remove public self-signup |
| **Source** | C1, D1, D22; AUD-005, AUD-016 |
| **Baseline** | `RegisterWithEmailUseCase` / `AuthRemoteDatasourceImpl.registerWithEmail` creates Auth+users+studentProfiles; role argument honored; login checks `isActive`; W8 `AcademyAdmissionFirestore.establishMembership` admits **existing** studentId |
| **Target** | Public `/register` disabled/removed from product path; Admin UI calls CF `adminProvisionUser`; admission path unchanged (no Auth create) |

**Firestore**

| Path | Fields (min) | Read | Write |
|------|--------------|------|-------|
| `users/{uid}` | `name`, `role`, `email`, `phone?`, `profileImageUrl?`, `isActive`, `createdAt` | Admin: full; others: **no phone** (WA-2) | **CF** for create/role/`isActive` privileged; self safe fields only |
| `studentProfiles/{uid}` / `parentProfiles/{uid}` / `teacherProfiles/{uid}` | existing + `lifecycle` later (WA-15) | scoped | **CF** on provision |

**Mutations**

| Op | Boundary |
|----|----------|
| Create Auth user | **CF callable** (Admin SDK) |
| Assign role | **CF only** |
| Public register | **removed** |
| Admit existing student | Client today → **must become CF/server-transactional** (may land late A or early B; Rules must deny arbitrary roster writes in WA-2) |
| Idle timeout | None (D22) |

**Client impact (eventual)**

- Disable `RegisterPage` route / CTA
- Admin provision screen (new or extend teachers/students management) → callable
- Keep login/logout; password reset may use Auth API (AUD-017) — **NON-BLOCKING** if deferred

**Backend:** callable `adminProvisionUser` — verify admin role; create Auth; write users+profile; compensate on partial failure; audit log (WA-16)

**Security:** Rules deny `users.role` self-update; deny non-Admin create of other users’ docs

**Indexes:** none specific

**Migration:** existing self-registered students remain; no Auth delete

**Tests:** unit CF admin check; negative: student cannot call provision; register path gone; role escalate denied

**Deps:** WA-0 for production deploy of CF; design+emulator OK before

**Done when:** no production self-register; provision path works in emulator; role immutable

**Non-goals:** invent new product registration UX beyond Admin provision; custom claims required

---

### WA-2 — Authorization foundation / Rules blueprint (D16, D2, D14, D24)

| | |
|--|--|
| **Purpose** | Specify what Rules must enforce before `firebase.json` wires them (AUD-006) |
| **Source** | SECURITY_IMPLEMENTATION_SPEC §18; C1/C2/C3/C4/C10 |
| **Baseline** | Most collections signed-in RW; phone world-readable; paid writable; Storage catch-all |
| **Target** | Document exact Rule intents; implementation in coding phase |

**Phone model (LOCKED approach from freeze)**

- Non-Admin must not `get` full `users/{id}` containing phone.
- Prefer denormalized safe participant/search projections (`studentSearch`, conversation `participants[]` without phone).
- Admin full `users` read.
- **IMPORTANT TBD (non-blocking for Rules deny-others):** whether self may read own phone on account screen — freeze recommends own-read; confirm in WA-2 implementation notes if product insists Admin-absolute.

**Rules intents (not code here)**

| Resource | Intent |
|----------|--------|
| `users.role` / privileged fields | Immutable for self; Admin/CF only |
| `users.phone` | Admin (and optionally self) only |
| `parentProfiles.childrenIds` | Deny client write |
| `halaqat.studentIds` | Deny arbitrary client write |
| `payments.amount` / `status` paid\|overdue / review fields | Deny Parent; reviewer/CF only |
| `paymentAccess/*` | Deny all client writes |
| `pricingRules/*` | Admin only |
| `academySettings/communication` | Admin only |
| `academySettings/paymentPublic` | Admin write; Parent read |
| `wallets` | Deny / omit (D2 OUT) |
| `supervisorProfiles` | Quarantine deny or Admin-only unused |
| `conversations` create | Relationship checks; allow `halaqa_group_*` via CF |
| `messages` | Participant send; soft-delete fields per C9 |
| Storage | Remove catch-all; bind paths C10 |

**Client:** strip phone from non-Admin UI (defense-in-depth); router unchanged as non-security

**Deps:** WA-1 role SSOT

**Done when:** Rules PR checklist written; emulator negative tests listed; **do not deploy open rules**

**Non-goals:** Writing actual rules files in this documentation task

---

### WA-3 — paymentAccess foundation (C2, D5)

| | |
|--|--|
| **Purpose** | Server-owned commercial access state ≠ `users.isActive` |
| **Source** | C2 |
| **Baseline** | No collection; login uses `isActive` only |
| **Target** | `paymentAccess/{parentId}` exists; CF transitions; Parent reads own |

**Schema** — exactly C2 fields: `status` ∈ `ok|reminded|due_warning|in_grace|suspended`, `reason`, `primaryInvoiceId`, `affectedStudentIds`, `graceEndsAt`, `suspendedAt`, `warningIssuedAt`, `lastReminderAt`, `reinstatedAt`, `reinstatedBy`, `updatedAt`

| Who | Read | Write |
|-----|------|-------|
| Parent own | ✔ | ✖ |
| Admin | ✔ | via **CF reinstate** only |
| Supervisor (scoped) | ✔ | ✖ |
| Teacher/Student | ✖ | ✖ |

**Client:** Parent shell gate (Pay Now / Contact Admin) may be thin in A; full UX Wave D

**Backend:** scheduled transitions (WA-6); callable `adminReinstatePaymentAccess`

**Deps:** WA-4 grace config; WA-5 invoices for `primaryInvoiceId`

**Done when:** docs created by CF in emulator; client write denied; reinstate Admin-only

**Non-goals:** Merging into `isActive`; Skip/Later buttons

---

### WA-4 — Academy settings split (C3, D6)

| | |
|--|--|
| **Purpose** | Vodafone destination without exposing Admin settings |
| **Source** | C3; existing `AdminCommunicationSettingsContract` → `academySettings/communication` |
| **Baseline** | `transferDestination = ''`; communication Admin-only |
| **Target** | Three docs as freeze |

| Path | Owner | Parent |
|------|-------|--------|
| `academySettings/communication` | Admin RW | ✖ |
| `academySettings/pricingDefaults` | Admin RW (`gracePeriodDays`, currency default, …) | ✖ |
| `academySettings/paymentPublic` | Admin RW | **R** (`vodafoneCashDestination`, `updatedAt`, `updatedBy`) |

**Client:** replace empty constant with read of `paymentPublic`; Admin editor for destination + grace

**Backend:** optional — Admin client write OK if Rules Admin-only

**Never** hard-code a fake Vodafone number

**Deps:** WA-2 Rules allow Parent read on `paymentPublic` only

**Done when:** Parent can read destination; Teacher cannot; communication remains Admin-only

---

### WA-5 — Pricing rules + invoice ownership foundation (C4, D2, D3)

| | |
|--|--|
| **Purpose** | Separate pricing → invoice snapshot → proof → review → paid |
| **Source** | C4; freeze `PaymentEntity` / `ParentPaymentProofContract` |
| **Baseline** | No invoice creator; proof+Supervisor review exist; wallet can mark paid (OUT) |

**Chain (do not merge)**

```
pricingRules (Admin)
  → CF generate payments/{id} (amount snapshot, dueDate, periodKey, pricingRuleId/version, status=due)
    → Parent proof fields + method=vodafone_cash + reviewStatus=pending_review
      → Reviewer approve/reject/partial
        → status=paid (reviewer/CF) OR remain due/overdue
          → paymentAccess transitions (WA-3/WA-6)
            → Admin reinstate
```

**`pricingRules/{ruleId}`** — fields per C4; Admin only

**`payments/{id}`** — existing fields + server: `pricingRuleId`, `pricingRuleVersion`, `issuedAt`, `periodKey`, `currency`

| Field class | Writer |
|-------------|--------|
| Snapshot amount/due/ids | **CF create only**; immutable |
| Proof fields | Parent own |
| Review + paid | Supervisor scoped **or** Admin (C4 freeze) |
| overdue | **CF scheduled** (WA-6) |

**Client MUST NOT:** create invoice; set amount/paid/overdue; clear review

**Quarantine:** wallet paid path; Paymob functions/client (WA-18)

**Deps:** WA-0 for production generator; WA-4 defaults

**Done when:** CF can create idempotent invoice in emulator; Parent cannot set paid; wallet path unreachable

**Non-goals:** Full Parent finance UI polish (Wave D); inventing Paymob

---

### WA-6 — Overdue / grace scheduled jobs (C5)

| | |
|--|--|
| **Purpose** | Server clock drives overdue + paymentAccess |
| **Source** | C5; Cairo day contract |
| **Baseline** | No overdue writer |
| **Target** | Scheduled CF: idempotent pass over due invoices; set `status=overdue`; update `paymentAccess` using `gracePeriodDays` |

**Mutations:** **CF scheduled** only

**Idempotency:** re-run safe; compute from `dueDate`+grace, not last-run cursor alone

**Deps:** WA-0 production; WA-3; WA-4; WA-5

**Done when:** double-run test leaves single coherent state

**Non-goals:** Client-derived overdue as SSOT

---

### WA-7 — slotId migration (C6, B-SLOT-ID-MIGRATE)

| | |
|--|--|
| **Purpose** | Stable `slotId` on every `halaqat.schedule[]` element |
| **Source** | C6 §6.3 |
| **Baseline** | `{day, startTime, endTime}` only |
| **Target** | Each slot has `slotId` (uuid); Admin create requires ≥1 slot with ids (D8) |

**Migration:** one-time CF/Admin script — assign ids where missing; idempotent if `slotId` present

**Blocked until complete:** live session materialization (WA-8 go-live)

**Tests:** backfill idempotency; create halaqa rejects empty schedule

**Deps:** none product; engineering execution

**Done when:** all active halaqat slots have `slotId`; new writes always include it

---

### WA-8 — sessions foundation (C6, D10)

| | |
|--|--|
| **Purpose** | First-class `sessions/{sessionId}` SSOT |
| **Source** | C6 |
| **Baseline** | Synthetic `{halaqaId}_yyyyMMdd`; no collection |
| **Target** | Collection + materializer CF; dual-read legacy ids |

**Schema (min):** `halaqaId`, `slotId`, `date`, `startAt`, `endAt`, `status`, `teacherId`, `supervisorId?`, `createdAt`, `updatedAt`, `createdBy`  
Unique: `(halaqaId, slotId, date)`  
Do **not** unbounded-copy full student roster onto session by default

**Mutations:** materialize **CF** (and/or teacher create-with-CF validation); status updates teacher-owned via Rules after session exists

**Consumer contract:** new attendance/eval **must** use real `sessionId` (full writers Wave B)

**Deps:** WA-7, WA-9

**Done when:** can create session docs in emulator without conflict; legacy synthetic ids still readable as historical

**Non-goals:** Completing Teacher attendance UI rewrite (Wave B)

---

### WA-9 — Conflict engine (C7, D9)

| | |
|--|--|
| **Purpose** | Server-final overlap validation |
| **Source** | C7 half-open `[startAt, endAt)` |
| **Hard conflicts** | Teacher, Student (roster intersection), same Halaqa |
| **Allowed** | Supervisor overlap |
| **Exclude** | `cancelled`; past `completed` from future scheduling set |
| **Boundary** | **CF / server-transactional** — UI check non-authoritative |
| **Deps** | WA-8 |
| **Done when** | Concurrent create of overlapping teacher sessions → one fails |
| **Non-goals** | Soft “warnings only” for hard conflicts |

---

### WA-10 — Halaqa group membership (C8, D14)

| | |
|--|--|
| **Purpose** | Deterministic group conversation + CF sync |
| **Source** | C8 |
| **Id** | `halaqa_group_{halaqaId}` |
| **Members** | teacherId + supervisorId + studentIds — **not Parent** |
| **Baseline** | Rules size≤2 except `admin_internal_group` |
| **Mutations** | **CF** on halaqa create/staff/roster/archive — clients cannot self-join |
| **Admin** | Monitor (D13), not automatic member |
| **Deps** | WA-2 conversation Rules exception for `halaqa_group_*` created by CF |
| **Done when** | Ensure group idempotent; transfer removes/adds member |
| **Non-goals** | Parent-in-group; full chat UI (Wave F) |

---

### WA-11 — Chat authorization + soft-delete foundation (C9, D13, D14)

| | |
|--|--|
| **Purpose** | Relationship-bound 1:1; soft-delete fields; Admin monitor retained |
| **Baseline** | `ChatPermissionPolicy` role-pair only; message update/delete false |
| **Target** | Create 1:1 only if graph valid (student↔own teacher; parent↔linked child’s teacher/supervisor/admin; etc.); message fields `editedAt`, `deletedAt`, `deletedBy`, `deleted` |
| **Delete** | Soft-delete only; retention days **TBD — NON-BLOCKING** |
| **Admin UI** | Spec requires My vs Monitored — may stub data layer in A; full UI Wave F |
| **Deps** | WA-10 for groups; D12 childrenIds writer (membership CF — early A/B) |
| **Done when:** unauthorized GetOrCreate fails via CF relationship check; soft-delete tombstone fields + CF path work; Rules deny client create/update/delete of messages and conversation creates |
| **Non-goals:** Hard delete; media upload UI (WA-12 paths only) |
| **Implementation notes (WA-11):** `createDirectConversation` / `softDeleteChatMessage` / `editChatMessage` callables; client `ChatPermissionPolicy` is UX-only; conversation create Rules = false; message update/delete Rules = false |

---

### WA-12 — Storage paths (C10)

| Category | Path | Uploader | Readers | Delete |
|----------|------|----------|---------|--------|
| Payment proofs | `payment_proofs/{parentId}/{paymentId}/{file}` (existing) | Parent | Parent + reviewer + Admin | false |
| Profile images | `profile_images/{uid}/{file}` | own | visibility without phone | replace |
| Chat images | `chat_media/{conversationId}/{messageId}/{file}` | participant | participants + Admin monitor | soft + async GC later |
| Voice | `chat_voice/{conversationId}/{messageId}/{file}` | participant | same | same |
| Recitation | `recitations/{studentId}/{assignmentId}/…` | own if flag | teacher | gated false |

**Rules plan:** remove authenticated catch-all; default DENY for unspecified paths
**Deps:** WA-0 for production media scale
**Done when:** path matrix documented + Rules tests; catch-all removal on Rules checklist
**Non-goals:** Enabling `audioUploadsEnabled`
**Implementation notes (WA-12):** C10 paths hardened (payment ownership, chat participantIds + Admin read, awards grantor lock, recitations deny-all). Active app paths authorized without catch-all: `posts/{authorId}` create=owner; `content/{uploadedBy}` create/delete=owner; `halaqa_activities/.../images` create=student on `assignments`+halaqa roster (audio folder denied while capability OFF). Terminal Storage fallback deny-only. `firebase.json` → `storage.rules`. Dart: `StoragePathsContract`.

---

### WA-13 — FCM token + send chain (C11, D17, D19)

| | |
|--|--|
| **Purpose** | Own tokens; server send; live-eval chain contract |
| **Schema** | `fcmTokens/{uid}/devices/{deviceId}` — token, platform, timestamps, disabled |
| **Client** | Register/update/delete **own** tokens only |
| **Send** | **CF only** after event; no arbitrary recipient lists from client |
| **Live eval chain** | eval persist → AcademyEvent → notification → FCM → Parent opens eval (full wiring Wave E/B) |
| **Production gate** | **WA-0 / B-BILLING** |
| **Done when** | Token CRUD Rules; send CF exists in emulator; spoof notification denied |
| **Non-goals** | Claiming FCM production-ready without billing verification |

**Implementation notes (WA-13):** Tokens at `fcmTokens/{uid}/devices/{deviceId}` — owner-only read/create/update/delete, field set frozen to `token`/`platform`/`createdAt`/`updatedAt`/`disabled`; `disabledReason`/`disabledAt`/`lastSendAt`/`lastErrorCode` are Admin-SDK only; no Admin client read path. Send chain is CF-only: `notifyParentsOnEvaluation` (`onDocumentWritten recitationRecords/{recordId}`) → parent audience from `parentProfiles.childrenIds` → notification doc under the existing deterministic identity (`{parentId}_homework_reviewed_{recordId}`, reusing `AcademyEventIds`/`NotificationSignalIds`) → Admin SDK `sendEachForMulticast` → unregistered tokens marked `disabled`. Idempotency/authorization proof lives in CF-only `notificationDeliveries/{notificationId}` (status/attempts, max 3); a push is emitted only for notifications the server authored with that claim, so a forged `notifications/{id}` cannot trigger delivery. FCM payload carries stable ids only (`evaluationId`, `studentId`, `sessionId`, `halaqaId`) — never phone/private data. Production send stays behind the WA-0 gate (`resolvePushSendMode` over `productionGate` predicates; blocked logs and returns instead of throwing in a background trigger). Dart: `FcmTokenContract` + `FcmTokenRegistrar` (single registration point in the root auth listener, stable SharedPreferences device id). Deep-link UI handling remains Wave E.

---

### WA-14 — studentSearch projection (C13, D16)

| | |
|--|--|
| **Path** | `studentSearch/{studentId}` |
| **Fields** | `studentId`, `fullName`, `fullNameNormalized`, `halaqaId`, `halaqaName`, optional non-phone disambiguator — **never phone** |
| **Writer** | **CF trigger** on profile/halaqa changes |
| **Readers** | Role-scoped (Admin all; Supervisor/Teacher scoped) |
| **Normalization** | Strip tashkeel; unify alef; collapse space — IMPLEMENTATION-DEFINED details |
| **Done when** | Projection updates on rename; non-Admin query cannot see phone |
| **Non-goals** | Algolia |

---

### WA-15 — Roster status dimensions (C14, D18, D21)

| Dimension | Storage |
|-----------|---------|
| Login | `users.isActive` |
| Payment | `paymentAccess.status` |
| Halaqa | `halaqat.studentIds` (membership SSOT). `studentProfiles.halaqaId` is the display pointer only and is never membership authority |
| Lifecycle | `studentProfiles.lifecycle` = `active`\|`archived` (**CF/Admin**) |

**Composed display labels** (presentation only — never persisted, never in `studentSearch`). First match wins:

| Precedence | Condition | Label |
|-----------|-----------|-------|
| 1 | `lifecycle == archived` | مؤرشف |
| 2 | `users.isActive == false` | معطّل |
| 3 | `paymentAccess.status == suspended` | موقوف دفع |
| 4 | no membership in any `halaqat.studentIds` | بانتظار حلقة |
| 5 | otherwise | نشط |

`معطّل` closes the disabled-account gap in the original four-label table; it is the Login dimension and must never be conflated with `archived`. A dimension the viewer cannot read (e.g. Teacher and `paymentAccess`) is skipped, not assumed.

Transitions go through the Admin-only `adminSetStudentLifecycle` callable; clients cannot write `lifecycle` at all. Missing `lifecycle` reads as `active`, so no migration is required.

**DEFERRED INTEGRATION (D21 roster cascade):** archiving does **not** remove the student from `halaqat.studentIds`. That cascade touches the WA-14 `studentSearch` projection, WA-10 group membership sync, and live rosters, so it is deferred to a dedicated membership/archive integration wave.

**Deps:** WA-3  
**Done when:** archived ≠ payment suspended ≠ no_halaqa ≠ login disabled in data model tests  
**Non-goals:** Overloading roster with many actions (D18); Halaqa roster cascade

---

### WA-16 — auditLogs (C16)

| Path | `auditLogs/{logId}` |
|------|---------------------|
| Write | **CF / Admin SDK only** |
| Read | Admin only |
| NEW fields | `actorId`, `actorRole`, `action`, `targetType`, `targetId`, `timestamp`, `metadata` (+ recommended `source`) |
| Legacy | Historical docs may use `actorUid` / `createdAt` / old action names — **not rewritten** |
| Retention | **TBD — NON-BLOCKING** (no purge in WA-16) |
| Indexes | **None** in WA-16 (no Admin query UI) |
| Flutter | **None** (no audit entity/UI) |

**In scope:** shared builder/writer; normalize provision / reinstate / phone migrate / slot migrate / lifecycle set+backfill / studentSearch backfill; emit `invoice_create` when invoice `created === true`; Rules + contract tests.

**Change-only audits:** lifecycle noop, reinstate already-`ok`, idempotent invoice, zero-work migrations → no audit.

**Deferred hooks:** payment_review, payment_suspend (scheduler), transfer, childrenIds CF, pricing/vodafone CF, session/attendance/evaluation, chat moderate-delete — contract ready, not fabricated in WA-16.

**Done when:** shared helper + all seven writers normalized + invoice_create + Rules/authz tests + privacy/idempotency tests + docs aligned.

**Non-goals:** Admin UI, Flutter feature, retention purge, historical migration, new indexes, scheduler redesign, FCM/search per-write audits.

---

### WA-17 — Indexes / scalability prerequisites

**Wave A prerequisite indexes** (from scalability audit + new queries):

| Query need | Index | Wave |
|------------|-------|------|
| `recitationRecords` halaqaId+date | AUD-032 | Deploy early (H/A) |
| `payments` parentId+dueDate | AUD-033 | A/D |
| `sessions` halaqaId+date / teacherId+startAt | new | after WA-8 |
| `studentSearch` fullNameNormalized prefix | new | WA-14 |
| `paymentAccess` status (if listed) | optional | WA-3 |

**Classify known risks**

| Risk | Class |
|------|-------|
| Unbounded chat listeners / Admin watchAll | Later F/H — document; add pagination plan |
| payments full collection Admin get | Later D — replace with scoped queries when invoices exist |
| `halaqat.studentIds` unbounded | Monitoring — OK hundreds |
| broadcast `readBy[]` | Later E |
| Missing transactions assignStaff | Wave B with U-HALAQA |
| No App Check | WA-1/WA-2 enable after Rules |
| No CI | Later H — recommend start in A if cheap |
| Proof last-write-wins | D review transaction later D |
| Open Rules deploy | **Wave A must not** wire open rules |

---

### WA-18 — Quarantine OUT features (D2, D24)

| Item | Action | Status |
|------|--------|--------|
| Wallet → paid | Removed Parent UX (balance + pay); wallet/ledger client R/W denied | **Done (code/rules)** |
| Paymob functions/client | CF remain unexported; Flutter initiation stack removed | **Done (code)** |
| `supervisorProfiles` | Rules quarantine kept; unused Dart constant removed; no SSOT use | **Done (hygiene)** |

**Non-goals (explicit):** no Firebase data deletion, no migration, no deploy.

**AUD:** 007, 013, 035, 100

---

### WA-19 — Test strategy (Wave A)

| Area | Unit | Rules emulator | CF | Integration |
|------|------|----------------|-----|-------------|
| Provision | ✔ | student cannot call | ✔ | Admin creates teacher |
| Role escalate | ✔ | deny self role=admin | — | — |
| Phone | — | non-Admin get users.phone fails | — | UI no phone |
| childrenIds | — | Parent write fails | CF admit ok | — |
| paymentAccess | ✔ | Parent write fails | reinstate Admin | — |
| paymentPublic | — | Parent read dest; not communication | — | — |
| Invoice | ✔ immutable amount | Parent cannot set paid | create idempotent | — |
| Overdue job | — | — | double-run | — |
| slotId backfill | ✔ | — | idempotent | — |
| Session conflict | — | — | concurrent overlap | — |
| Group sync | — | client cannot join | ensure group | transfer |
| Chat 1:1 | policy+roster | create denied cross-halaqa | — | — |
| Soft-delete | ✔ | sender soft-delete | — | — |
| Storage catch-all | — | deny random path | — | — |
| FCM token | ✔ | own only | send spoof denied | — |
| studentSearch | ✔ normalized | no phone field | trigger update | — |
| lifecycle | ✔ | client cannot archive | — | — |
| auditLogs | — | client write denied | emitted | — |

Map: D1,D2,D5,D6,D9,D10,D14,D16,D19,D20,D21 → tests above. D7/D11/D17 full chains primarily Wave B/E.

#### WA-19 authoritative regression commands

WA-19 implementation closes three gaps: WA-17 indexes JSON contract test,
Functions `test:wave-a` runner, and this command matrix. **WA-19 is complete
only after the automated suites below pass.** Emulator green ≠ production
verified.

**A. Static checks (repo root)**

```bash
flutter analyze
dart format --set-exit-if-changed .
```

**B. Flutter contract / regression (repo root)**

Focused Wave A–relevant suites:

```bash
flutter test test/security test/features/parent test/features/schedule test/features/chat
```

Full suite (may include pre-existing unrelated failures outside WA-19 scope):

```bash
flutter test
```

**C. Cloud Functions (from `functions/`)**

```bash
npm run build
npm run test:wave-a
```

`npm test` delegates to `test:wave-a`. This runs **all** Wave A Functions
suites (WA-1, WA-3…WA-11, WA-13…WA-17), including Paymob-export quarantine
asserts and the WA-17 indexes contract. No production Firebase, FCM delivery,
Blaze, or secrets required.

**D. Firestore Rules (emulator)**

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-wa2 --only firestore \
  "npm --prefix rules_test test"
```

**Local note:** `firebase.json` maps Firestore emulator to port **8080**. If
Docker Desktop (or another process) already owns 8080, that command can fail
with HTTP 404 on the Rules API. Workaround: run `emulators:exec` with an
**ephemeral** config that points Firestore at a free port (e.g. 18080) and
absolute paths to repo `firestore.rules` — do **not** permanently change
repository Firebase configuration for a local port conflict. See
`rules_test/README.md`.

**E. Storage Rules (emulator)**

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-wa12 --only firestore,storage \
  "npm --prefix rules_test run test:storage"
```

**F. Production / operational gates (NOT local automated tests)**

These remain separate from WA-19 automated/emulator green:

| Gate | Class |
|------|--------|
| Blaze / billing checklist Verified (WA-0 / B-BILLING) | Operational |
| Production FCM delivery | Operational (blocked until Verified) |
| Production scheduled Cloud Functions (invoice/overdue) | Operational |
| Live `slotId` migration (B-SLOT-ID-MIGRATE) | Operational |
| Firestore indexes **deploy** to the academy project | Operational |
| App Check production configuration | Operational |

Automated unit/Rules/CF tests do **not** satisfy production verification.

**AUD:** Wave A exit criterion #19 (analyzer/format/tests plan documented).

---

### WA-20 — Explicit Wave A exclusions

| Excluded | Wave / note |
|----------|-------------|
| Evaluation Present/Late enforcement in Teacher UI | B (D7) |
| Progress % projector / versesRange collection UI | C (D11) |
| Mushaf redesign / two modes / last-read UX | C15 stub optional; UI later (D23) |
| EN locale / dark theme program | OUT (D15) |
| Full Parent suspended shell polish | D |
| Production FCM without billing verify | Blocked B-BILLING |
| Chat hard-delete / retention purge | TBD policy |
| Paymob / wallet | OUT forever this generation |
| Inventing Cubit migration | Keep Bloc |

---

## 5. Payment / billing precision

```
pricingRules (Admin)
    ↓ CF generate
payments invoice (amount snapshot, dueDate, status=due)
    ↓ Parent
proof + pending_review  (never paid)
    ↓ Supervisor scoped | Admin
review approve/reject/partial
    ↓ on approve
status=paid + paidAt
    ↓ parallel scheduled
overdue (CF) + paymentAccess grace/suspend (CF)
    ↓
Admin reinstate paymentAccess → ok
```

Official destination: **`academySettings/paymentPublic.vodafoneCashDestination` only**.

**B-BILLING blocks:** production scheduled invoice/overdue/suspend CFs and FCM send. Emulator development allowed.

---

## 6. Sessions / schedule precision

```
halaqat.schedule[] (+ slotId)     ← WA-7 required
    ↓
sessions/{sessionId}             ← WA-8
    ↓
attendance / evaluation          ← Wave B writers
    ↓
progress / notifications         ← C / E
```

Conflict: WA-9 server-final. Synthetic day ids: historical-only.

---

## 7. Chat / storage / FCM precision

- Group id `halaqa_group_{halaqaId}`; CF sync; Parent excluded  
- Soft-delete only  
- Storage paths §WA-12; catch-all removal  
- Tokens own-write; send CF; live-eval chain contract for E  

---

## 8. Migration table

| Migration | Required? | Why | Prerequisite | Order | Idempotent? | Verify |
|-----------|-----------|-----|--------------|-------|-------------|--------|
| schedule[] → slotId | **Required** before sessions live | B-SLOT-ID-MIGRATE | — | Before WA-8 go-live | Yes if skip existing slotId | All active halaqat have ids |
| Synthetic session ids → dual-read | Required strategy | C6 | WA-8 | With WA-8 | N/A | New writes use real ids |
| Backfill historical sessions | Optional | Nice-to-have | WA-7/8 | Later | Yes | Spot-check |
| Create paymentPublic + pricingDefaults | Required | C3/C5 | — | Early A | Upsert | Parent read dest |
| Backfill paymentAccess docs | Required when invoices exist | C2 | WA-5 | After first invoices | Upsert by parentId | Status coherent |
| Extend payments with pricing fields | Required for new invoices | C4 | — | With generator | New docs only | Old docs readable |
| studentSearch backfill | Required for search | C13 | — | Mid A | Upsert | Count matches students |
| lifecycle=active default | Required | C14 | — | Mid A | Set if missing | No null lifecycle |
| Ensure halaqa_group conversations | Required for groups | C8 | roster integrity | After Rules group allow | Ensure | Id deterministic |
| Chat message soft-delete fields | Optional backfill | C9 | — | With WA-11 | Defaults false | Old messages OK |
| FCM tokens | N/A if none | — | — | — | — | — |
| Storage path rewrite old objects | Not required if proofs already correct | C10 | — | — | — | Don’t claim safe without inventory |
| Disable Paymob | Required | D2 | Console access | Early | — | No live webhook |
| supervisorProfiles quarantine | Required search | D24 | — | Early | — | Grep zero SSOT use |
| auditLogs | Init empty | C16 | — | With first CF | — | Writes appear |

**Do not claim Storage historical rewrite is safe** without an inventory — leave as optional later.

---

## 9. Cross-interface contracts (Wave A)

| Interface | Wave A expectation |
|-----------|-------------------|
| Admin | Provision users; edit paymentPublic + pricing; reinstate access; monitor chat read remains |
| Supervisor | Still reviews payments (scoped); limited admit becomes CF; no phone |
| Teacher | No phone; cannot open arbitrary chats; sessions appear after WA-8 |
| Parent | Read Vodafone public settings; cannot write childrenIds/paid; paymentAccess read |
| Student | No directory phone; search N/A; lifecycle/no_halaqa messaging later |

---

## 10. Wave A exit criteria

Wave A is **not** done when files merely exist. Exit when:

1. [ ] WA-0 billing checklist Verified **or** explicit “emulator-only” waiver documented for non-prod  
2. [ ] Public register disabled; Admin provision CF works (emulator)  
3. [ ] Role self-escalate denied; phone non-Admin denied  
4. [ ] childrenIds / roster / paid / paymentAccess client writes denied in Rules tests  
5. [ ] paymentPublic readable by Parent; communication not  
6. [ ] pricingRules + invoice CF create idempotent; wallet/Paymob quarantined  
7. [ ] slotId present on all active schedules (B-SLOT-ID-MIGRATE cleared)  
8. [ ] sessions creatable; conflict test passes  
9. [ ] halaqa_group ensure/sync works; Parent not member  
10. [ ] 1:1 unauthorized create fails; soft-delete fields work  
11. [ ] Storage catch-all removal on Rules checklist; proof path tightened  
12. [ ] FCM token own-only; send CF spoof-denied (prod send only if WA-0 pass)  
13. [ ] studentSearch backfilled; no phone field  
14. [ ] lifecycle dimension present; status compose unit-tested  
15. [ ] auditLogs written for privileged CFs  
16. [ ] Indexes for landed queries deployed/planned  
17. [ ] Negative authorization tests green  
18. [ ] No open P0 assigned to Wave A remaining (open Rules must not be production-wired)  
19. [ ] Analyzer/format/tests plan for coding PRs documented  

---

## 11. Remaining blockers / TBDs

### Blockers

| ID | Blocks | Needed |
|----|--------|--------|
| **B-BILLING** | Production CF schedulers + FCM send + Blaze | Fill checklist Verified; confirm academy project; disable Paymob |
| **B-SLOT-ID-MIGRATE** | Session materialization go-live | Execute slotId backfill |

### Important non-blocking TBDs

| Item | Notes |
|------|-------|
| Self phone read for account UI | Recommend allow self; Admin-absolute alternative |
| Chat retention days | Soft-delete OK without purge |
| Admin sees deleted message body | Tombstone enough v1 |
| Invoice void/reissue pattern | Prefer new invoice later |
| Password reset timing | AUD-017; can follow WA-1 |
| childrenIds CF timing vs Rules deny | Deny first; CF admit next |
| Auto-reinstate on paid | **LOCKED Admin reinstate** |
| Supervisor schedule edit | Default Admin-only |
| `70362e0` roster refresh commit | Re-inspect before membership CF |
| Course Cubit vs Bloc | Keep Bloc |

### Contradictions noted (not guessed away)

1. `IMPLEMENTATION_PLAN.md` §7 still lists some “Schema TBD” items that **C1–C16 already froze** — treat **SECURITY_DATA_CONTRACT_FREEZE.md** as newer authority for schemas.  
2. Plan Wave A historically = “Rules + identity”; this Wave A spec **includes foundation schemas/CF contracts** for sessions/chat/FCM so agents do not rediscover them — full feature UX remains B/D/E/F.  
3. Freeze Rules comments still describe interim open world — target is this Wave A blueprint, not current Rules text.

---

## 12. Files this blueprint expects coding agents to touch later (not now)

| Area | Likely paths (freeze) |
|------|----------------------|
| Auth | `lib/features/auth/**`, `router_app.dart` register route |
| Admission | `lib/shared/data/academy_admission_firestore.dart` |
| Payments | `parent_payment_proof.dart`, parent/supervisor payment pages, Admin finance |
| Settings | `admin_communication_settings_contract.dart` + new paymentPublic contract |
| Halaqa/schedule | `academy_halaqa_firestore.dart`, schedule models, weekly mapper |
| Attendance/session | `attendance_policy.dart`, `attendance_service.dart` |
| Chat | `chat_permission_policy.dart`, chat datasources/blocs |
| Functions | `functions/src/**` (new callables/schedulers; quarantine paymob) |
| Rules | `firestore.rules`, `storage.rules`, `firebase.json` (after tightness) |
| Indexes | `firestore.indexes.json` |

---

## 13. Documentation cross-links

| Doc | Role |
|-----|------|
| `PRODUCT_DECISIONS_LOCKED.md` | D1–D24 |
| `SECURITY_IMPLEMENTATION_SPEC.md` | Authz matrix |
| `SECURITY_DATA_CONTRACT_FREEZE.md` | C1–C16 schemas |
| `IMPLEMENTATION_PLAN.md` | Multi-wave roadmap |
| **This file** | Wave A executable blueprint |

---

**End of Wave A Implementation Specification. Documentation only. STOP.**
