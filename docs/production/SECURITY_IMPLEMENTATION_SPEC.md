# Security Implementation Specification — Rafiq Academy

**Status:** SPECIFICATION ONLY — Wave 0 locked; Wave A prerequisite  
**Code baseline:** `feature/full-product-audit` @ `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Authoritative product locks:** `PRODUCT_DECISIONS_LOCKED.md` (D1–D24)  
**Companions:** `IMPLEMENTATION_PLAN.md`, `AUTH_SECURITY_AUDIT.md`, `DATA_CONTRACT_AUDIT.md`, `FIREBASE_SCALABILITY_AUDIT.md`, `FIREBASE_BILLING_CHECKLIST.md`, **`SECURITY_DATA_CONTRACT_FREEZE.md`** (frozen schemas / CF boundaries)

**This document does not contain Firestore/Storage rules code and does not authorize implementation yet.** It defines the security contracts that later Wave A+ agents must satisfy.

**Freeze gap (context only):** Today most collections are signed-in RW; `users.phone` is world-readable to signed-in clients; payment `status=paid` is client-writable at rules layer; chat create is role-pair / size≤2; no `sessions` collection. Those are **defects relative to this spec**, not product choices.

---

## 0. Legend

| Symbol | Meaning |
|--------|---------|
| **✔** | Allowed under stated conditions |
| **✖** | Forbidden |
| **CF** | Trusted backend / Cloud Function / Admin SDK only |
| **Rules** | Must be enforceable in Firestore/Storage rules (or equivalent server gate) |
| **Client** | App/use-case defense-in-depth only — **never** sole control |
| **TBD** | Engineering/Schema/Infrastructure still open; do not invent |

**Roles** (string constants in freeze `AppRoles`): `admin` | `supervisor` | `teacher` | `parent` | `student`

---

## 1. Security Principles

1. **Firebase Auth identity** is the only principal (`request.auth.uid`). No anonymous academy access.
2. **Application role** is stored on `users/{uid}.role` (freeze pattern). Role is a **privileged field**: clients must not escalate it. Prefer Admin/CF writes for role assignment (D1).
3. **Server-side authorization is the source of truth.** UI hide, GoRouter `AppRouteAccess`, and domain policies (e.g. `ChatPermissionPolicy`) are defense-in-depth only.
4. **Least privilege / deny-by-default** for sensitive collections: payments, users.phone, settings, membership mutations, session/attendance/eval writes outside ownership.
5. **Ownership checks** on self-scoped data (own profile non-privileged fields, own notifications, own FCM tokens, own payment proofs).
6. **Relationship checks** for parent↔child (D12) and 1:1 chat (D14).
7. **Halaqa membership checks** for roster, attendance, evaluation, Halaqa group chat (D8–D10, D14).
8. **Admin-only privileged operations:** phone read (D16), pricing rules (D3), academy Vodafone destination write (D6), payment access reinstatement (D5), archive/deactivate (D21), full chat monitor (D13), staff provisioning (D1).
9. **Historical-data preservation:** no destructive hard-delete of operational history without an explicit retention policy (D20, D21). Prefer soft-delete / archive / tombstone.
10. **State separation (mandatory):**
    - `users.isActive` = login / account kill switch (Admin / Auth disable) — **not** payment delinquency
    - Payment access suspension (D5) = separate fields/policy
    - No-Halaqa waiting (D21) = membership absence, not suspension
    - Archive/deactivation (D21) = out of active operations; history retained for Admin

11. **Custom claims:** freeze does **not** use Auth custom claims; rules use `users/{uid}.role`. Migrating to claims is optional hardening — **not required by locks**. If kept as profile role, **role field immutability** is mandatory.

12. **App Check:** required for production clients that talk to Firebase (AUD-062). Not a substitute for ownership rules.

---

## 2. Role / Permission Matrix

Conditions use freeze collections where they exist. `sessions` and payment-access fields are **locked as required** but **Schema TBD**.

### 2.1 Legend for cells

`R` read · `C` create · `U` update · `X` delete/archive · `A` approve/review · `M` monitor  
`own` = self · `linked` = parent↔child via authorized `childrenIds` · `halaqa` = teacherId/supervisorId/roster · `staff` = teacher|supervisor|admin as noted

### 2.2 Matrix (summary)

| Resource / action | Admin | Supervisor | Teacher | Parent | Student |
|-------------------|-------|------------|---------|--------|---------|
| **users** non-phone fields | R/U*/X* | R scoped staff/students in supervised halaqat | R roster students + related staff | R linked children + related staff names | R own; limited peer names for chat |
| **users.phone** | **R only** | ✖ | ✖ | ✖ | ✖ |
| **users.role / isActive** | U via authorized workflow | ✖ escalate; limited admit may set isActive true via W8 helper today → **must become CF/Rules-hardened** | ✖ | ✖ | ✖ self-escalate |
| **studentProfiles** | R/U privileged | R supervised; limited U via admit/transfer CF | R/U operational non-progress fields in own halaqa | R linked children | R/U own non-privileged (avatar etc.) |
| **overallProgressPercent / verse aggregates** | R | R supervised | R own halaqa | R linked | R own; **✖ client set** (CF projector) |
| **parentProfiles.childrenIds** | U via admission workflow | Limited link in authorized halaqat (**CF**) | ✖ | **✖ write**; R own | ✖ |
| **Add Student Request** | A/reject/assign | Limited within scope **TBD** if product allows | ✖ | **C** request only | ✖ |
| **teacherProfiles / halaqatIds** | R/U | R | R own | R related | R related teacher display |
| **supervisorProfiles** | Quarantine (D24) — **not SSOT** | — | — | — | — |
| **halaqat** create (≥1 slot) | **C** | ✖ create (unless later product expands) | ✖ | ✖ | ✖ |
| **halaqat** roster `studentIds` | U via CF/admission | Admit/transfer via **CF** within supervised | ✖ arbitrary array edit | ✖ | ✖ |
| **halaqat** schedule slots | C/U | U supervised (**TBD** if Supervisor edits schedule) | ✖ or read-only | R linked child schedule | R own |
| **sessions** | R/M; privileged override **TBD** | R supervised | C/U own halaqa sessions (materialize/status per policy) | R linked child sessions | R own |
| **attendance** | R | R supervised; escalate into teacher flows per product | **C/U** for own halaqa session | R linked | R own |
| **evaluations** (`recitationRecords` live path) | R | R supervised | **C/U** if Session+Present/Late | R linked | R own |
| **awards / achievements** | C/grant | C/grant supervised | C/grant own halaqa | R linked | R own |
| **pricing rules** | **C/U** | ✖ | ✖ | ✖ | ✖ |
| **invoices / payments create** | via **CF** from rules | ✖ client create | ✖ | ✖ | ✖ |
| **payment proof submit** | R all | R/A supervised (**IMPORTANT TBD** reviewer role) | ✖ | **U proof fields only** on own invoices | ✖ |
| **mark paid / overdue / reinstate access** | Reinstate **✔**; paid/overdue via **CF**/reviewer | Review→paid if authorized (**TBD**) | ✖ | ✖ | ✖ |
| **academySettings** (incl. Vodafone dest) | R/W | ✖ write; Vodafone **R** via Parent-safe projection **or** Rules field split **TBD** | ✖ | **R Vodafone destination only** (D6) | ✖ |
| **notifications** | C broadcast; R ops | R own audience | R own | R own | R own |
| **FCM tokens** | Ops **TBD** | own token C/U/X | own | own | own |
| **conversations 1:1** | R all (M); C own pairs | C/R relationship-valid | C/R relationship-valid | C/R relationship-valid | C/R with **own** teacher |
| **Halaqa group chat** | M all; not automatic member | Member of supervised groups | Member + announce | **✖ not member** (D14) | Member of own halaqa group |
| **messages** send | Own threads only (not spoof as monitor) | If participant | If participant | If participant | If participant |
| **messages** edit/delete | Privileged **TBD**; soft-delete preferred | Own messages per policy | Own | Own | Own |
| **chat media Storage** | Monitor read | Participant | Participant | Participant | Participant |
| **payment_proofs Storage** | R | R if reviewer | ✖ | **C** own path; R own | ✖ |
| **assignments / homework** | R | R supervised | C/U own halaqa | R linked awareness | R/U own submissions |
| **calendarEvents / contentLibrary** | C/U as product | R/U per product | R | R | R |
| **wallets / Paymob** | **OUT** (D2) — quarantine | OUT | OUT | OUT | OUT |

\*Admin user updates: authorized Admin profile workflows only; still audit.

**Parent academySettings read (D6):** Freeze `academySettings` is Admin-only RW. Spec requires Parent to read Vodafone destination without reading all Admin settings. **Enforcement TBD:** separate public-safe settings doc, or CF that returns destination only, or field-level Rules if/when supported pattern is chosen — do not open full `academySettings` to Parent.

---

## 3. Authentication

### 3.1 Authenticated vs unauthenticated

| Path | Policy |
|------|--------|
| Unauthenticated | Splash, onboarding, login only. **No** `/register` public signup (D1). Password reset UI may exist later without inventing a new registration flow. |
| Authenticated | Role home via `users.role`; data access per matrix |

### 3.2 Registration / provisioning (D1)

- **No public self-registration.**
- Accounts provisioned through **Admin-controlled workflow**.
- Freeze today: public `RegisterWithEmail` creates Auth + `users` + student profile — **must be removed/disabled** from product path.
- Freeze W8 / Supervisor “register” = **admit existing `studentId`** into halaqa (`AcademyAdmissionFirestore`) — **keep this admission path**; it is not Auth user creation.
- **Do not invent a new registration product flow.**  
  **Engineering TBD (BLOCKER for staff onboarding):** Admin Auth provisioning mechanism (Console-only vs callable using Admin SDK). Spec requires: only trusted backend may `createUser`; client must not call `createUserWithEmailAndPassword` for academy identities in production.

### 3.3 Firebase Auth vs application profile

- Auth uid **must** equal `users/{uid}` document id.
- Missing `users/{uid}` after Auth success → fail closed (freeze already errors).
- Missing/invalid `role` → fail closed; do not default to Admin.
- Inconsistent role vs profile collection (e.g. teacher without teacherProfiles) → allow login only if product defines; **operational writes** still require membership checks.

### 3.4 Inactive / suspended / archive (do not conflate)

| State | Login | App access |
|-------|-------|------------|
| `users.isActive == false` or Auth disabled | **Blocked** | — |
| Payment-suspended (D5) | **Allowed** (unless also isActive false) | Parent: Pay Now + Contact Admin only; child: suspended access per D5 |
| No-Halaqa (D21) | Allowed if isActive | Student sees waiting message; not on roster/groups/ops notifies |
| Archived (D21) | **TBD** whether login blocked or limited Admin-only restore — **IMPORTANT**; default recommendation: treat as deactivated for client apps, Admin can still read history |

### 3.5 Logout / persistence (D22)

- Logout: `signOut` + clear session projections (freeze H1).
- **No** app-level idle timeout.
- Firebase Auth persistence = normal.

### 3.6 Deleted / disabled Auth users

- Auth `user-disabled` → login error (freeze maps Arabic message).
- Rules must deny when `request.auth == null`.
- Stolen token until revoke: App Check + short-lived tokens + disable Auth user on archive — **IMPORTANT**.

### 3.7 Password reset

- Freeze: Coming Soon copy only. Operational need remains.
- Security: use Firebase `sendPasswordResetEmail` (or Admin reset) — **no** custom token emailed from client. Not a new registration flow.

---

## 4. Role Authorization

### 4.1 Core rule

**Every privileged operation must be enforced by Firestore Rules and/or a trusted Cloud Function.**  
Client checks are mandatory for UX but **insufficient**.

### 4.2 How authorization is composed

1. `request.auth != null`
2. Load `users/{uid}.role` (or future claims)
3. Resource-specific predicate:
   - self uid
   - Admin
   - `halaqat.teacherId == uid` / `supervisorId == uid` / `studentIds` contains
   - `parentProfiles.childrenIds` contains studentId
   - conversation `participantIds` contains (or Admin monitor read)
4. Field-level: deny writes to server-managed fields (see §18)

### 4.3 Router is not security

`AppRouteAccess` / bottom nav / hidden buttons **do not** authorize SDK calls.

### 4.4 Domain policies

`ChatPermissionPolicy.canChat(roleA, roleB)` today is **role-pair only**. Target (D14): must also validate **relationship graph**; Rules/CF must mirror that. Domain policy remains defense-in-depth.

---

## 5. Phone Privacy (D16)

### 5.1 Policy

- **Only Admin** may read `users.phone`.
- Teacher / Supervisor / Parent / Student must **never** receive phone via Firestore reads, list/search/detail, chat hydration, or API responses.
- Chat authorization uses **userId + relationship/role**, never phone.

### 5.2 Technical enforcement (required)

Because Firestore Rules cannot easily strip a single field from an otherwise-readable document:

| Approach | Notes |
|----------|-------|
| **Preferred for Wave A** | Non-Admin **cannot** `get`/`list` full `users/{id}` documents that contain phone. Expose safe projections: denormalized `publicProfiles/{uid}` or embedded `participants[]` with name/role/image only (freeze already stores participant snapshots on conversations — extend this pattern; **do not** copy phone into snapshots). |
| **Admin-only** | Admin SDK / Admin-role Rules allow full `users` read including phone. |
| **Self** | Whether a user may read **own** phone: product lock says “Admin only” for `users.phone` readability in cross-role sense. **IMPORTANT TBD:** may self read own phone on account screen? Spec recommendation: **own phone readable by self**; still never by other non-Admin roles. Confirm if product intended absolute Admin-only including self — if absolute, account UI must not bind phone from `users` for non-Admin (use separate self-editable field written only by self with Rules). |

**UI hiding alone is forbidden as the control.**

### 5.3 Search

Non-Admin student search: `studentId`, full/triple name, Halaqa name, optional non-sensitive contextual field. Arabic normalization (**Engineering TBD**). **Never** phone.

---

## 6. Student / Parent Relationship Security (D12)

### 6.1 Authority

| Action | Who |
|--------|-----|
| Submit Add Student Request | Parent (**C** request doc only) |
| Approve / reject / assign Halaqa | **Admin** (final authority) |
| Limited link within authorized Halaqat | Supervisor (**CF** + scope check) |
| Mutate `parentProfiles.childrenIds` | **CF / Admin SDK only** as result of admission/assignment — **never** Parent client |
| Unlink | Admin (and Supervisor only if product later allows within scope) — **IMPORTANT TBD** unlink UX |
| Read relationship | Admin; Parent (own); Supervisor (supervised students’ links); Teacher (roster students’ parent link for ops — **without phone**) |

### 6.2 W8

W8 admission/transfer remains the membership workflow (`AcademyAdmissionFirestore` pattern). Relationship writes must be atomic with roster/`halaqaId` updates where applicable.

### 6.3 Historical integrity

- Unlink / transfer must **not** delete historical attendance, evaluations, payments, chat, awards.
- Chat 1:1 authorization for Parent↔Teacher must use **current** relationship graph; historical messages remain readable to prior participants + Admin monitor.

### 6.4 Request collection

Freeze has **no** Add Student Request collection. **Schema TBD** for request docs. Security requirement once exists: Parent creates own requests; only Admin (and scoped Supervisor if allowed) updates status; Parent cannot set `approved` or write `childrenIds`.

---

## 7. Halaqa / Membership Security

### 7.1 Creation (D8)

- Production create requires **≥1 schedule slot**.
- Enforce in **CF or Rules** (Rules can reject empty `schedule` array on create). Prefer CF if conflict validation (D9) runs in same transaction.

### 7.2 Roster

- Clients must **not** arbitrary `arrayUnion`/`arrayRemove` on `halaqat.studentIds`.
- Mutations only via trusted admission/transfer/archive workflows (CF).

### 7.3 Transfer (D21)

- Transfer requires **target Halaqa**.
- Temporary **no-Halaqa** allowed (clear primary `halaqaId`, remove from all active rosters) without destroying account/history.
- No-Halaqa ≠ payment suspension ≠ archive.

### 7.4 Archive (D21)

- Remove from active rosters, Halaqa groups, operational notification fan-out.
- Preserve historical records for Admin.
- No hard-delete without retention policy (**Policy TBD**).

### 7.5 Halaqa group membership (D14)

- Members: Teacher + Supervisor + Students of that Halaqa.
- **Parent is not** a Halaqa group member.
- Admin monitors groups (D13), not automatic group participant unless product adds Admin to group separately.
- Membership sync on admit/transfer/archive must be **server-side** (**Schema TBD** group id).

### 7.6 Inactive halaqa

- `halaqat.status != active` → block new attendance/eval/session materialization for that halaqa (product lock + AUD-038). Exact Supervisor override **TBD**.

---

## 8. Schedule / Session Security (D9, D10)

### 8.1 Authority

| Action | Who | Enforcement |
|--------|-----|-------------|
| Create/edit schedule slots | Admin (primary); Supervisor edit **TBD** | Rules/CF; ≥1 slot on create |
| Create/materialize `sessions/{sessionId}` | Teacher of halaqa and/or **CF scheduler** | Server validates slot+date; no client-invented conflicting ids |
| Change session status | Teacher of halaqa; Admin override **TBD** | Rules ownership |
| Read sessions | Teacher/Supervisor of halaqa; linked Parent; Student of session; Admin | Rules |

### 8.2 SSOT

- `sessions/{sessionId}` is authoritative (D10).
- Attendance / evaluation / progress events / notifications reference **sessionId**.
- Synthetic `{halaqaId}_yyyyMMdd` must not remain production SSOT (**Migration TBD**).

### 8.3 Conflict validation (D9)

- Hard conflicts for **Teacher**, **Student**, **same Halaqa**.
- **Supervisor** time conflicts **allowed**.
- **UI-only validation insufficient** → CF/transaction (**Engineering TBD** — BLOCKER before multi-slot production).

### 8.4 Immutability

- After session **completed/closed**, historical start/end and slot linkage should be immutable except Admin correction workflow with audit (**IMPORTANT TBD** correction policy).
- Do not allow clients to rewrite `sessionId` on past attendance/eval docs.

---

## 9. Attendance Security (D7)

### 9.1 Who may mark / edit

| Role | Mark | Edit |
|------|------|------|
| Teacher of session’s halaqa | ✔ | ✔ within edit window |
| Supervisor | Read; escalate to teacher flows (freeze) — write **TBD** unless product grants |
| Admin | Read; correction **TBD** | |
| Parent/Student | Read own/linked only | ✖ |

### 9.2 Session ownership

- Attendance write must reference existing `sessions/{sessionId}` owned by teacher’s halaqa.
- Prevent writes for students not on roster **at session time** (snapshot roster on session **Schema TBD** vs live roster — **IMPORTANT**).

### 9.3 After completion

- Edit after session end: freeze uses end-time / midnight policy (`AttendancePolicy.canEditSession`). Preserve a defined window; after window → Admin-only correction with audit (**TBD** exact window product confirmation — NON-BLOCKING if freeze policy kept).

### 9.4 Historical integrity

- Prefer deterministic doc ids; retire legacy duplicates via existing policy patterns.
- No client delete of attendance history.

### 9.5 Evaluation gate dependency

- Evaluation create/update for a session requires attendance status ∈ {`present`, `late`} for that student+session (D7). Enforce in **EvaluationService + CF/Rules** (Rules alone may be hard — prefer CF or batched write that reads attendance).

---

## 10. Evaluation / Progress Security (D11, D17)

### 10.1 Create / edit

| Role | Create live eval | Edit | Delete |
|------|------------------|------|--------|
| Teacher of halaqa | ✔ if D7 gate passes | ✔ within window **TBD** | Soft-delete / Admin only **TBD** |
| Supervisor | Read | ✖ unless product expands | ✖ |
| Parent/Student | Read linked/own | ✖ | ✖ |
| Admin | Read / correction **TBD** | | |

### 10.2 Required fields

- `evaluationType` ∈ {`memorization`, `revision`} (names **Schema TBD** but concept locked).
- Non-empty validated `versesRange`.
- `sessionId` required; must match attendance gate.

### 10.3 Progress mutation

- Clients **must not** directly set `overallProgressPercent`, memorization aggregates, or revision aggregates.
- Progress projected **server-side** after eval commit (CF or trusted transaction) from memorization evals only (D11).
- Accuracy remains grade metric — never write it into `overallProgressPercent`.
- Mushaf last-read (D23) is a **separate** document/field; students may update **own** last-read only.

### 10.4 Live evaluation notification (D17)

Pipeline (trusted):

1. Persist evaluation (authorized teacher write or CF)
2. Publish Academy Event via existing sink pattern (`FanOutAcademyEventSink` / handler) — **server-side after commit**
3. Create notification for linked parents (resolve via `childrenIds`)
4. FCM send (D19) via CF — client must not choose arbitrary recipients
5. Parent may open evaluation only if linked (Rules)

Clients must **not** fabricate notification docs for other users.

---

## 11. Payment / Invoice Security (D2–D6)

### 11.1 Rail

- Vodafone Cash + screenshot proof **only**.
- Paymob / wallet **OUT** — quarantine client paths and functions; do not authorize wallet→paid.

### 11.2 Field ownership on `payments/{id}`

| Fields | Writer |
|--------|--------|
| `amount`, `dueDate`, `studentId`, `parentId`, initial `status` | **CF** invoice generator (D3) — immutable amount snapshot |
| Proof fields + `method=vodafone_cash` + `reviewStatus=pending_review` | Parent (own invoices only) |
| `reviewStatus` approved/rejected/partial, `reviewedBy/At/Notes`, `amountPaidConfirmed`, `remainingAmount` | Authorized reviewer (**CF** preferred) |
| `status=paid`, `paidAt` | Reviewer/CF only — **never Parent** |
| `status=overdue` | Scheduled CF (D4) only |
| Payment-access suspension / reinstate | CF + **Admin reinstate** (D5) |

### 11.3 Actions matrix

| Action | Admin | Supervisor | Parent |
|--------|-------|------------|--------|
| Edit pricing rules | ✔ | ✖ | ✖ |
| Generate invoices | CF from Admin rules | ✖ | ✖ |
| Submit proof | R | R if reviewer | ✔ own |
| Review / approve / reject / partial | ✔ and/or Supervisor — **IMPORTANT TBD** | Freeze today: Supervisor scoped | ✖ |
| Mark paid | via approve path | via approve if authorized | ✖ |
| Alter overdue | ✖ client | ✖ | ✖ |
| Reinstate payment access | ✔ | ✖ (unless later granted) | ✖ |
| Edit Vodafone destination | ✔ `academySettings` | ✖ | R safe projection |

### 11.4 Protections

- Client cannot change invoice `amount` after creation.
- Client cannot set `paid` / clear overdue / forge `reviewedBy`.
- Duplicate proof: allow resubmit per freeze product, but clear prior review fields only via controlled update; race with review → **transaction / CF** (AUD-064).
- Replay: Storage path keyed by parentId/paymentId; Rules ensure parentId == auth.uid.
- Grace suspension (D5): CF only; Parent UI limited — **Rules must also deny** non-allowed writes while suspended (except proof submit + contact/chat-to-Admin).

### 11.5 Audit trail

Require auditable records for review, overdue transitions, suspension, reinstatement (**Schema TBD** audit collection vs fields on payment).

---

## 12. Chat Security (D13, D14, D20)

### 12.1 Create conversation

| Kind | Allowed when |
|------|----------------|
| 1:1 | Role pair **and** relationship graph valid (D14); both participants listed; Rules reject arbitrary UID pairs |
| Halaqa group | Created/synced by **CF** from halaqa roster; id **Schema TBD**; members Teacher+Supervisor+Students |
| Admin internal | Admin only (`admin_internal_group` exists in freeze) |

Parent cannot message arbitrary staff/students by role alone.

### 12.2 Send / read

- Send: must be participant; `senderId == auth.uid`.
- Read: participant **or** Admin monitor (D13).
- Admin monitor is **read**; Admin must not inject messages into monitored threads as fake participant unless explicitly in My Conversations.

### 12.3 Membership changes

- Halaqa group add/remove: **CF** on roster change — not client array edits.
- Teacher announcements: Teacher member can send to group (ordinary message or typed `announcement` — **Schema TBD**).

### 12.4 Edit / delete (D20)

- Prefer **soft-delete / tombstone** (`deletedAt`, `deletedBy`, redacted text) for historical integrity.
- Hard delete of Storage media / message docs: **Policy TBD** (BLOCKER before enabling hard delete).
- Freeze Rules currently `allow update, delete: if false` on messages — must be redesigned carefully for edit/soft-delete with sender ownership + time window **TBD**.

### 12.5 Admin UI separation (D13)

- Authorization must not depend on bubble color/order.
- Monitored views: show sender identity, role, timestamp, media indicator.
- Separate query surfaces: My Conversations vs Monitored (Rules still allow Admin read-all).

### 12.6 Media

See §13. Upload/download only if conversation participant (or Admin monitor read).

---

## 13. Storage Security

### 13.1 Known freeze paths

| Category | Path (freeze) | Upload | Read | Delete |
|----------|---------------|--------|------|--------|
| Payment proofs | `payment_proofs/{parentId}/{paymentId}/{file}` | Parent owner; image; &lt;10MB | Today: any signed-in → **target: Parent owner + authorized reviewers + Admin** | `false` (evidence) |
| Catch-all | `/{allPaths=**}` | Any signed-in → **must be removed** | Same | Must close |

### 13.2 Required categories (paths **Infrastructure TBD** unless noted)

| Category | Upload | Read | Delete | Validation |
|----------|--------|------|--------|------------|
| Profile pictures | Own uid path | Auth users who may see avatar (no phone) | Own replace; hard delete **TBD** | size/type |
| Chat images | Participant of conversationId | Participants + Admin monitor | Soft-delete message; file retention **TBD** | image/* size cap |
| Voice messages | Participant | Participants + Admin monitor | Same | audio/* duration/size cap |
| Attachments | Participant if product enables | Same | TBD | type allowlist |
| Award images | Granting staff | Relevant roles | TBD | |
| Mushaf/recitation audio | Only if `audioUploadsEnabled` (currently false) | Per homework ownership | TBD | |

### 13.3 Orphans

- Proof: Storage then Firestore update can orphan files — accept as evidence or CF cleanup **NON-BLOCKING**.
- Chat media: on soft-delete, retain until retention job (**Policy TBD**).

### 13.4 Archive

- Archived users: media remains for Admin historical access; public/client reads denied.

---

## 14. FCM / Notification Security (D17, D19)

### 14.1 Tokens

| Action | Who |
|--------|-----|
| Register/update/delete token | **Own uid only** (Rules: `fcmTokens/{uid}` or subcollection under user) |
| Write arbitrary recipient tokens | ✖ |

**Schema TBD** for token docs.

### 14.2 Notification documents

- Clients must not create notifications for arbitrary `audience` users.
- W4/W5 pattern: deterministic ids via handler after SSOT commit — keep server-side.
- Admin broadcast: Admin-only create (freeze AdminOpsBroadcast).
- Read: audience == self, or role broadcast membership, or Admin ops.

### 14.3 FCM send

- **CF only** using Admin SDK.
- Input: event id / notification id — not free-form user id lists from client.
- Idempotency: deterministic notification ids (freeze) + FCM collapse keys **TBD**.

### 14.4 Live evaluation flow

Eval commit → AcademyEvent → in-app notification → FCM to parent devices of linked parents. Parent opens evaluation under relationship Rules.

### 14.5 Spoofing

Deny client writes that set `type`, `title`, `studentId` targeting others. Prefer CF after trusted events.

---

## 15. Admin Oversight Security

### 15.1 Admin-only capabilities

- Read all phones (D16)
- Monitor all chats including groups (D13)
- Pricing rules / invoice policy (D3)
- Vodafone destination write (D6)
- Payment access reinstate (D5)
- Student Profile privileged actions (D18): transfer, suspend/reactivate (account and/or payment-access — distinguish), awards, view payments
- Archive/deactivate (D21)
- Staff provisioning (D1) via trusted path
- `academySettings` full access
- Quarantine management for OUT features (wallet/Paymob)

### 15.2 My vs Monitored conversations

| Surface | Authz |
|---------|-------|
| My Conversations | Admin is participant |
| Monitored Conversations | Admin read-all; UI labeled; message send still requires participation |

---

## 16. Search / Data Exposure

### 16.1 Safe fields (non-Admin)

`studentId`, display/full/triple name, `halaqaId`/`halaqaName`, avatarId/image URL, operational status badges that are non-sensitive (no-Halaqa, etc.)

### 16.2 Forbidden fields (non-Admin)

`phone`, payment proof URLs of unrelated families, other parents’ childrenIds lists beyond need-to-know, full `users` docs, arbitrary collection scans

### 16.3 Controls

- Prefer denormalized **safe search index** docs maintained by CF (**Engineering TBD** — IMPORTANT for Arabic search + phone absence).
- Prevent unrestricted `users` / `studentProfiles` collection list for Student/Parent.
- Teacher/Supervisor queries limited to supervised/taught halaqat.

---

## 17. Archive / Suspension / No-Halaqa States

| Capability | Active | Payment-suspended (D5) | No-Halaqa (D21) | Archived (D21) |
|------------|--------|------------------------|-----------------|----------------|
| Login (`isActive`) | ✔ | ✔ | ✔ | **TBD** (recommend block client) |
| Parent shell | Full | **Pay Now + Contact Admin only** | N/A | ✖ |
| Student learning ops | ✔ | Suspended per D5 | Waiting message; no roster ops | ✖ |
| Submit payment proof | ✔ | ✔ allowed | if Parent still linked | ✖ |
| Chat 1:1 | ✔ | Contact Admin allowed; other chats **TBD** (recommend allow Admin/Teacher contact only) | Student: limited **TBD** | ✖ client |
| Halaqa group | ✔ | per D5 | Removed from groups | Removed |
| Attendance/eval | ✔ | child suspended → no new evals | N/A | historical Admin only |
| Progress read | ✔ | linked Parent may still need Pay context | ✔ history | Admin |
| Admin historical read | ✔ | ✔ | ✔ | ✔ |

Payment-suspended child access: D5 says Parent **and** child access suspended after grace — enforce in Rules/CF feature gates, not only UI.

---

## 18. Firestore Security Model (conceptual — no rules code)

### 18.1 Always

- `isSignedIn()`
- Role from `users/{uid}.role` with **immutable role** for self-updates
- Deny-by-default on sensitive matches

### 18.2 Helpers (conceptual)

`isAdmin`, `isTeacherOfHalaqa`, `isSupervisorOfHalaqa`, `isStudentInHalaqa`, `isLinkedParentOf(studentId)`, `isConversationParticipant`, `isPaymentParent`, `isAuthorizedPaymentReviewer`

### 18.3 Immutable / server-managed fields (clients must not set)

Examples: `users.role`, `users.isActive` (except Admin/CF), `payments.amount`, `payments.status` paid/overdue, review fields, `childrenIds`, `halaqat.studentIds`, progress aggregates, notification audience for others, session conflict-critical timing after close, FCM send payloads

### 18.4 Where Rules are insufficient → CF required

| Operation | Why |
|-----------|-----|
| Invoice generation | Multi-doc + pricing snapshot |
| Overdue job | Scheduled, trusted time |
| Payment suspension / reinstate | Cross-user Parent+child |
| Session conflict validation | Multi-resource race |
| Authoritative assignment / childrenIds | Atomic membership graph |
| Progress projection | Aggregate integrity |
| Academy Event + FCM fan-out | Spoof prevention |
| Halaqa group membership sync | Roster fan-out |
| Finance totals | Avoid full-collection client trust |
| Admin Auth createUser | Admin SDK |
| Phone-safe user projection maintenance | Field stripping |

### 18.5 Deploy

- Do **not** wire `firebase.json` to today’s open rules.
- Tighten first; then AUD-006.

---

## 19. Cloud Functions / Trusted Backend Boundary

**Must not be trusted to the client:**

1. Auth user provisioning (D1)
2. Invoice generation from pricing rules (D3)
3. Overdue transitions (D4)
4. Payment access suspension after grace (D5)
5. Payment access reinstatement (Admin-triggered CF) (D5)
6. Session conflict validation / authoritative session materialization (D9–D10)
7. Student assignment / `childrenIds` mutation / transfer / archive roster sync (D12, D21)
8. Progress projection (D11)
9. Live-eval Academy Event + FCM (D17, D19)
10. Privileged notification fan-out / Admin broadcast push
11. Payment review→paid if Rules cannot safely express reviewer scope (**prefer CF**)
12. Quarantine/disable Paymob webhooks (D2)
13. Finance aggregate maintenance (scale)

**May remain client writes with tight Rules:** attendance within ownership+window; evaluation create after gate (or CF); proof field updates; own profile safe fields; own last-read; own FCM token; chat send as participant.

---

## 20. Auditability / Immutability

### 20.1 Must be auditable

| Event | Min data |
|-------|----------|
| Payment review approve/reject/partial | actor, paymentId, before/after status, timestamp |
| Payment suspension / reinstate | actor, parentId, studentIds, reason, timestamp |
| Student transfer / no-Halaqa / archive | actor, studentId, from/to halaqa, timestamp |
| Relationship childrenIds change | actor, parentId, studentId, action |
| Session create/status correction | actor, sessionId, fields |
| Attendance correction after window | actor, recordId |
| Evaluation create/correction | actor, evalId, sessionId, type, versesRange |
| Privileged Admin actions (pricing, Vodafone dest, phone-access ops) | actor, resource, timestamp |

### 20.2 Mechanism

**Schema TBD:** dedicated `auditLogs` collection (Admin read) vs append-only fields. Requirement: Admin-readable, client-tamper-resistant (CF write only).

---

## 21. Threat / Abuse Cases

| Threat | Required control | Boundary |
|--------|------------------|----------|
| Parent modifies `childrenIds` | Deny Parent write; CF admission only | Rules + CF |
| Student sets own progress % | Deny client write aggregates; CF projector | Rules + CF |
| Teacher edits another teacher’s halaqa | `teacherId` ownership checks | Rules |
| Parent/Student reads another student’s evals | Relationship / roster checks | Rules |
| Non-Admin reads phone | No full users read; safe projections | Rules + data shape |
| Client marks payment paid | Deny status paid to Parent; reviewer/CF only | Rules + CF |
| Client changes invoice amount | Immutable amount after create | Rules + CF |
| Client bypasses grace/suspension | CF sets access flags; Rules gate features | Rules + CF |
| User joins arbitrary Halaqa chat | CF membership; deny client member edit | Rules + CF |
| User messages unauthorized role/UID | Relationship create checks | Rules + CF |
| Upload media into another user’s path | Path uid/conversation binding | Storage Rules |
| Client fabricates live-eval notification | Deny arbitrary notification create | Rules + CF |
| Client writes arbitrary FCM recipients | Own token only; CF send | Rules + CF |
| Race: transfer / session / payment review | Transactions / CF single writer | CF |
| Broad collection scraping | No open list; scoped queries; App Check | Rules + App Check |
| Self role escalate to admin | Immutable `role` | Rules |
| Wallet/Paymob false paid | Feature quarantine (D2) | Remove + Rules deny |
| Supervisor conflict false block | Allow Supervisor overlap (D9) | Conflict engine |

---

## 22. Implementation Order (security dependencies)

### Before Wave A coding

1. Accept this spec + D1–D24.
2. Resolve **BLOCKER** TBDs in §23 that Wave A touches (especially phone read model, role immutability, public register removal approach, payment field locks).
3. Do not deploy open rules.

### Wave A (Security / Authorization foundation)

- Close public register path (D1)
- Role immutability + phone strategy (D16)
- Deny open RW; payments paid/review field locks (D2)
- Quarantine wallets Rules match / Paymob
- Conversation create relationship stubs (may complete in F but deny open create)
- Admin monitor read retained (D13)
- App Check plan
- `supervisorProfiles` quarantine (D24)
- Wire `firebase.json` only after tightness

### Before payment implementation (Wave D)

- BLOCKER: payment-access schema (D5)
- IMPORTANT: reviewer role Admin and/or Supervisor
- Pricing/invoice CF shape (D3)
- Overdue job (D4)
- academySettings Vodafone Parent-safe read (D6)
- Billing checklist if Functions needed

### Before session / attendance / evaluation (Wave B)

- BLOCKER: sessions schema + conflict engine (D9–D10)
- Attendance↔eval gate enforcement approach (D7)
- Schedule ≥1 slot enforcement (D8)

### Before progress (Wave C)

- Eval type + versesRange persisted
- CF projector; deny client aggregates (D11)

### Before chat (Wave F)

- D12 relationship graph writable via CF
- Halaqa group id/sync schema
- Soft-delete semantics (D20) before enabling edit/delete
- Storage media paths + Rules
- Billing for Storage/FCM if used

### Before FCM (Wave E)

- Billing checklist verification (D19)
- Token schema
- CF send pipeline; live-eval event path (D17)

### Before Mushaf media / audio uploads

- D23 last-read is low security risk (own write)
- Audio uploads remain gated (`audioUploadsEnabled=false`) until Storage Rules + billing ready

---

## 23. Open Security TBDs

| TBD | Class | Blocks |
|-----|-------|--------|
| Admin Auth `createUser` mechanism (D1) | **BLOCKER** | Staff/parent provisioning in production; not blocker for tightening Rules on existing users |
| Payment-access field schema vs `isActive` (D5) | **BLOCKER** | Wave D suspension/reinstate; feature gates |
| Whether non-Admin may read **own** phone | **IMPORTANT** | Account UI + Rules phone model |
| Parent-safe Vodafone destination read without opening full `academySettings` | **BLOCKER** | D6 Parent UX under least privilege |
| Pricing rules doc shape + invoice job trigger (D3) | **BLOCKER** | Wave D invoices |
| Grace period config location (D5) | **IMPORTANT** | Overdue→suspend CF |
| Payment reviewer = Admin and/or Supervisor | **IMPORTANT** | Review Rules/CF; freeze uses Supervisor |
| Full `sessions` schema + migration from synthetic ids (D10) | **BLOCKER** | Wave B production SSOT |
| Conflict engine + overlap definition (D9) | **BLOCKER** | Multi-slot safety |
| Roster snapshot on session vs live roster for attendance | **IMPORTANT** | Integrity of marks |
| Halaqa group conversation id + sync (D14) | **BLOCKER** | Group chat |
| Chat soft-delete vs hard-delete retention (D20) | **BLOCKER** | Enabling edit/delete/media purge |
| Storage media path layout (D20) | **BLOCKER** | Chat media |
| FCM token schema + send pipeline (D19) | **BLOCKER** | Push (after billing) |
| Billing / Blaze verification | **BLOCKER** | Functions/FCM/Storage scale enablement |
| Arabic search normalization + safe search index | **IMPORTANT** | Non-Admin search quality/security |
| Roster status enum (D18/D21) | **IMPORTANT** | Admin Student Profile clarity |
| Archived user login policy | **IMPORTANT** | D21 client gate |
| Mushaf last-read schema + two modes | **NON-BLOCKING** | Security low (own data); product UX |
| Attendance post-end edit window confirmation | **NON-BLOCKING** | Can keep freeze policy |
| Supervisor schedule edit rights | **NON-BLOCKING** | Default Admin-only until decided |
| Unlink parent-child UX beyond Admin | **NON-BLOCKING** | Default Admin-only |
| Audit log collection schema | **IMPORTANT** | Compliance; can start with payment fields |
| Data retention policy for archive/media | **IMPORTANT** | Hard-delete forbidden until set |
| Custom claims migration | **NON-BLOCKING** | Optional; profile role OK if immutable |

---

## 24. Consistency checklist (locks)

| Lock | Spec section |
|------|----------------|
| D1 | §3, §19 |
| D2 | §11, §21 |
| D3–D6 | §11 |
| D7 | §9, §10 |
| D8–D10 | §7, §8 |
| D11 | §10 |
| D12 | §6, §12 |
| D13–D14 | §12, §15 |
| D15 | Out of scope for security (AR/RTL) — no EN auth surfaces required |
| D16 | §5 |
| D17 | §10.4, §14 |
| D18 | §15, §17 |
| D19 | §14, §22 |
| D20 | §12, §13 |
| D21 | §7, §17 |
| D22 | §3.5 |
| D23 | §10 (separated from progress); §22 |
| D24 | §2 matrix quarantine |

---

## 25. Explicit non-goals

- Writing actual `firestore.rules` / `storage.rules` in this phase
- Reopening D1–D24
- Introducing Paymob, wallet rail, or public self-registration
- Treating UI/router as authorization
- Inventing final Storage paths, session field lists, or payment-access field names beyond requirements
- Enabling Blaze without `FIREBASE_BILLING_CHECKLIST.md` verification

---

**End of specification. Documentation only.**
