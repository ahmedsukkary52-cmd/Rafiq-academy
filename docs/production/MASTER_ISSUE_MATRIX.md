# Master Issue Matrix — Full Product Audit

**Baseline:** `feature/full-product-audit` @ `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Method:** Read-only. No code changes. No invented contracts.  
**Companion reports:** `FULL_PRODUCT_AUDIT.md`, `CROSS_INTERFACE_SCENARIOS.md`, `SHARED_UI_AUDIT.md`, `DATA_CONTRACT_AUDIT.md`, `AUTH_SECURITY_AUDIT.md`, `FIREBASE_SCALABILITY_AUDIT.md`

### Priority

| Tag | Meaning |
|-----|---------|
| **P0** | Production blocker / security / data corruption / severe broken flow |
| **P1** | Critical business flow broken or materially incorrect |
| **P2** | Important UX / consistency / reliability issue |
| **P3** | Polish / minor issue |

### Status values used here

| Status | Meaning |
|--------|---------|
| **Open** | Confirmed in frozen tree |
| **Missing contract** | Product/backend contract does not exist in code |
| **Product decision needed** | Behavior is ambiguous; do not invent a fix |
| **Accepted / out of scope** | Prior docs explicitly deferred this; not treated as a silent defect |
| **Stale inventory** | Older hardening docs contradict this freeze |

### Counts (this matrix)

| Priority | Count |
|----------|------:|
| P0 | 8 |
| P1 | 37 |
| P2 | 44 |
| P3 | 13 |
| **Total** | **102** |

Follow-up pass after specialist re-reads of the same freeze (halaqa/session, payments/progress, auth/chat/notifications, Firebase contracts, UI/tests). New IDs: AUD-094–AUD-102.

---

## Summary index

| ID | Pri | Role | Feature | Category |
|----|-----|------|---------|----------|
| AUD-001 | P0 | All | Firestore rules | Security |
| AUD-002 | P0 | All | Storage rules | Security |
| AUD-003 | P0 | All | User phones | Privacy |
| AUD-004 | P0 | Parent/Any | Payment status write | Security / Payments |
| AUD-005 | P0 | Student | Self-registration | Auth |
| AUD-006 | P0 | Ops | firebase.json rules wiring | Production |
| AUD-007 | P0 | Parent | Wallet marks paid | Payments |
| AUD-008 | P0 | Parent | Proof vs paid at rules layer | Payments |
| AUD-009 | P1 | Parent/Admin | Payment invoice creation | Missing contract |
| AUD-010 | P1 | Parent | Overdue transition | Missing contract |
| AUD-011 | P1 | All | Suspension from overdue | Missing contract |
| AUD-012 | P1 | Parent | Vodafone destination | Payments |
| AUD-013 | P1 | Parent | Paymob leftover | Payments |
| AUD-014 | P1 | Parent | Payment events | Notifications |
| AUD-015 | P1 | Parent | childrenIds writer | Membership |
| AUD-016 | P1 | Admin | Staff provisioning | Auth |
| AUD-017 | P1 | All | Password reset | Auth |
| AUD-018 | P1 | Admin | Halaqa without schedule | Halaqa |
| AUD-019 | P1 | Admin | Teacher change roster link | Halaqa |
| AUD-020 | P1 | Student+ | Progress never recalculated | Quran/Progress |
| AUD-021 | P1 | Student+ | Streak/juz/verses static | Quran/Progress |
| AUD-022 | P1 | Parent | Weekly report “verses” | Quran/Progress |
| AUD-023 | P1 | Admin | Dashboard fake zeros | Reports |
| AUD-024 | P1 | Teacher | No session documents | Session |
| AUD-025 | P1 | Teacher | Evaluation without attendance | Session |
| AUD-026 | P1 | Chat | Unbounded message listener | Scalability |
| AUD-027 | P1 | Teacher/Student | Group chat impossible | Chat |
| AUD-028 | P1 | Admin | Unbounded conversation watch | Scalability |
| AUD-029 | P1 | All | No FCM | Notifications |
| AUD-030 | P1 | All | Session reminders never produced | Notifications |
| AUD-031 | P1 | Awards | Award events missing | Notifications |
| AUD-032 | P1 | Analytics | Missing recitation index | Firebase |
| AUD-033 | P1 | Parent | Missing payments index | Firebase |
| AUD-034 | P1 | Admin | Full payments collection read | Scalability |
| AUD-035 | P1 | Parent | Wallet collection absent from rules | Payments |
| AUD-036 | P1 | All | Role rules vs router only | Security |
| AUD-037 | P1 | Parent | Subscription period selector | Missing contract |
| AUD-038 | P1 | Teacher | Inactive halaqa still operable | Halaqa |
| AUD-039 | P1 | Student | Achievement “accuracy” misuse | Quran/Progress |
| AUD-040 | P1 | Admin | Unenroll / exit membership | Missing contract |
| AUD-041 | P2 | All | Five independent bottom navs | Shared UI |
| AUD-042 | P2 | All | Three independent subpage scaffolds | Shared UI |
| AUD-043 | P2 | All | Hardcoded RTL | RTL |
| AUD-044 | P2 | All | No English localization | L10n |
| AUD-045 | P2 | All | Language row is dead | L10n |
| AUD-046 | P2 | All | AppTextStyles ignore dark theme | Theme |
| AUD-047 | P2 | All | Hardcoded Colors.* | Theme |
| AUD-048 | P2 | All | Network taxonomy collapse | Network |
| AUD-049 | P2 | All | Loading/empty/error inconsistency | UX states |
| AUD-050 | P2 | Docs | H6 inventory stale | Consistency |
| AUD-051 | P2 | Teacher | H6 4-tab vs live 5-tab | Consistency |
| AUD-052 | P2 | Parent | Mixed Navigator / GoRouter | Navigation |
| AUD-053 | P2 | Chat | No edit/delete/media | Chat |
| AUD-054 | P2 | Chat | Admin silent read of all threads | Privacy |
| AUD-055 | P2 | Chat | Parent auto-seeds conversations | Chat |
| AUD-056 | P2 | Session | Same-day slots collapsed | Session |
| AUD-057 | P2 | Session | No closeout SSOT for old sessions | Session |
| AUD-058 | P2 | Teacher | Student chat assignedBy fallback | Chat |
| AUD-059 | P2 | Student | Mushaf default surah 67 | Product |
| AUD-060 | P2 | Student | Audio uploads disabled | Capability |
| AUD-061 | P2 | Ops | No CI workflows | Production |
| AUD-062 | P2 | Ops | No App Check | Security |
| AUD-063 | P2 | Payments | Partial vs status remaining | Payments |
| AUD-064 | P2 | Payments | Review vs parent resubmit race | Concurrency |
| AUD-065 | P2 | Awards | Dual-read unbounded grants | Scalability |
| AUD-066 | P2 | Supervisor | Reports tab vs hidden write stack | Reports |
| AUD-067 | P2 | Admin | Broadcast comment vs live UI | Consistency |
| AUD-068 | P2 | All | Scaffold background ignores dark | Theme |
| AUD-069 | P2 | Teacher/Admin | Phone on student profile | Privacy |
| AUD-070 | P2 | Auth | No session timeout policy | Auth |
| AUD-071 | P2 | Tests | No rules / authz tests | Tests |
| AUD-072 | P2 | Tests | No widget coverage of role shells | Tests |
| AUD-073 | P2 | Tests | No payment lifecycle integration | Tests |
| AUD-074 | P2 | Tests | No progress calculation tests | Tests |
| AUD-075 | P2 | Forms | Arabic-only validation copy | L10n |
| AUD-076 | P2 | Responsive | Fixed heights / unflexible Rows | Overflow |
| AUD-077 | P2 | Chat | No failed-send retry model | Chat |
| AUD-078 | P2 | Notifications | Read state is array `readBy` | Scalability |
| AUD-079 | P2 | Calendar | locale hardcoded `ar` | L10n |
| AUD-080 | P2 | Parent | Outstanding totals client-only | Payments |
| AUD-081 | P2 | Teacher | Posts feature unwired | Consistency |
| AUD-082 | P3 | All | Back/chevron icon mix | Shared UI |
| AUD-083 | P3 | Auth | Mixed NotoNaskh / Cairo | Shared UI |
| AUD-084 | P3 | Shared | AppButton white spinner | Theme |
| AUD-085 | P3 | Shared | Mock activity store leftover | Hygiene |
| AUD-086 | P3 | Router | debugLogDiagnostics true | Production |
| AUD-087 | P3 | Router | Error page Arabic-only | L10n |
| AUD-088 | P3 | Grades | Arabic grade strings as SSOT | Data |
| AUD-089 | P3 | Recitation | Dual “needs work” labels | Data |
| AUD-090 | P3 | Admin | Stats cards show 0 with no caption | UX |
| AUD-091 | P3 | Student | Default avatar `fox` | UX |
| AUD-092 | P3 | Chat | Default title «المعلم» | L10n |
| AUD-093 | P3 | Dates | Mixed eastern/western digits | L10n |
| AUD-094 | P1 | Teacher | Attendance without scheduled meeting | Session |
| AUD-095 | P1 | Teacher | Live eval has no AcademyEvent | Notifications |
| AUD-096 | P1 | Student+ | Progress field meaning contradiction | Quran/Progress |
| AUD-097 | P1 | Teacher | Live eval `versesRange` always empty | Quran/Progress |
| AUD-098 | P1 | Chat | Create is role-pair only, not relationship | Chat / Security |
| AUD-099 | P2 | Admin | Student `isActive` badge has no toggle | Auth |
| AUD-100 | P3 | Supervisor | `supervisorProfiles` unused | Data |
| AUD-101 | P2 | Teacher | Activity responseCount race | Concurrency |
| AUD-102 | P2 | All | استئذان vs اعتذار terminology | L10n |

---

## Findings (full records)

Each record uses the required fields. **Source of truth** is what the frozen code actually treats as SSOT — or **none** when missing.

---

### AUD-001

- **Priority:** P0
- **Role:** All
- **Feature:** Firestore authorization
- **Screen/File:** `firestore.rules` lines 91–171
- **Category:** Security
- **Current behavior:** After Auth, any signed-in user may `read, write` `users`, `studentProfiles`, `parentProfiles`, `teacherProfiles`, `supervisorProfiles`, `halaqat`, `attendanceRecords`, `recitationRecords`, `assignments`, `payments`, `notifications`, `complaints`, `posts`, `calendarEvents`, and related collections.
- **Expected behavior:** Per-role / ownership rules. Parent cannot write attendance. Student cannot write payments.status. Teacher cannot read unrelated halaqat.
- **Root cause:** Interim “signed-in access (pre-hardening parity)” left as the live matchers. Comment still labels full ownership as Category B.
- **Source of truth:** Client use cases + router allowlist — **not** Firestore.
- **Data impact:** Any compromised or curious client can rewrite academy facts.
- **UI impact:** UI permission checks are cosmetic.
- **Permission impact:** Router `AppRouteAccess` is bypassed by direct SDK access.
- **Backend impact:** Rules do not enforce product policy.
- **Dependency:** AUD-006 (rules may not even be deployed).
- **Recommended fix:** Role/ownership rules for every collection; deny-by-default. Do not ship this freeze as production Authz.
- **Verification method:** Rules unit tests + attempt cross-role writes from a student SDK.
- **Status:** Open

### AUD-002

- **Priority:** P0
- **Role:** All
- **Feature:** Storage authorization
- **Screen/File:** `storage.rules` `match /{allPaths=**}`
- **Category:** Security
- **Current behavior:** Payment-proof path is constrained, then a catch-all allows any signed-in user to read/write every other Storage object (avatars, recitations, chat, awards).
- **Expected behavior:** Path-scoped access; payment proofs readable by parent owner + reviewing staff only.
- **Root cause:** Catch-all after the proof matcher.
- **Source of truth:** None at Storage layer for non-proof files.
- **Data impact:** Proofs and any other uploads are world-readable among signed-in users; arbitrary writes possible.
- **UI impact:** Upload validation in Dart is not a security boundary.
- **Permission impact:** Staff-only review of proofs is not enforced (`allow read: if isSignedIn()` even on proof path).
- **Backend impact:** Storage is not a capability gate (`AppCapabilities.audioUploadsEnabled` is client-only).
- **Dependency:** AUD-006
- **Recommended fix:** Remove catch-all; enumerate paths; proof read limited to owner + supervisor/admin.
- **Verification method:** Storage rules tests with student vs parent vs supervisor tokens.
- **Status:** Open

### AUD-003

- **Priority:** P0
- **Role:** All
- **Feature:** Phone numbers
- **Screen/File:** `firestore.rules` `match /users/{userId}` allow read if signed in; `UserEntity.phone`; `ChatRemoteDatasource.getParticipant`
- **Category:** Privacy
- **Current behavior:** Every authenticated user can read every `users/{uid}` document, including `phone`. Chat participant hydration reads the same docs.
- **Expected behavior:** Phone visible only to self, Admin, and product-approved staff for that relationship.
- **Root cause:** Users read is not ownership-scoped.
- **Source of truth:** `users.phone`
- **Data impact:** Full academy phone book leak to any student/parent account.
- **UI impact:** Teacher/Admin student profile also renders phone (`student_profile_page.dart`).
- **Permission impact:** No field-level masking.
- **Backend impact:** Rules must hide `phone` or split public profile vs private contact.
- **Dependency:** AUD-001
- **Recommended fix:** Public profile projection without phone; private contact doc; staff queries via Admin SDK / callable.
- **Verification method:** Student SDK `users` collection get of a teacher/parent doc.
- **Status:** Open

### AUD-004

- **Priority:** P0
- **Role:** Parent / any signed-in
- **Feature:** Payment status
- **Screen/File:** `firestore.rules` `match /payments/{id}` allow write if signed in; `parent_remote_datasource_impl.dart` wallet path sets `status: paid`
- **Category:** Security / Payments
- **Current behavior:** Rules do **not** prevent a parent (or any user) from setting `status: paid`. App contract says parent must never write paid; only proof fields.
- **Expected behavior:** Parent may write proof* + `reviewStatus=pending_review` only. `status=paid` only via Supervisor/Admin (or trusted backend).
- **Root cause:** Rules comment describes the contract; matchers do not implement it.
- **Source of truth:** Intended: Supervisor review / (if product kept) wallet transaction. Actual: any client write.
- **Data impact:** False paid state; finance totals lie.
- **UI impact:** Parent history would show paid.
- **Permission impact:** Supervisor review is not authoritative.
- **Backend impact:** Need field-level allow rules or Admin SDK review callable.
- **Dependency:** AUD-007, AUD-008
- **Recommended fix:** Split parent update allow-list vs supervisor review fields.
- **Verification method:** Parent token update of `payments/{id}.status = paid`.
- **Status:** Open

### AUD-005

- **Priority:** P0
- **Role:** Student (unauthenticated entry)
- **Feature:** Registration
- **Screen/File:** `register_page.dart` forces `AppRoles.student`; `auth_remote_datasouce_impl.dart` `isActive: true` + `studentProfiles` create
- **Category:** Auth
- **Current behavior:** Anyone can create a Firebase Auth user and an active student identity. Login gate allows `isActive == true` even with `halaqaId: null`.
- **Expected behavior (product direction):** Sensitive academy identities are Admin-provisioned. Students enter via admission (W8), not public self-serve active membership.
- **Root cause:** Public `/register` + writer that activates immediately.
- **Source of truth:** Auth + `users` + `studentProfiles` created by the registrant.
- **Data impact:** Orphan students not on any roster; pollution of Admin student lists.
- **UI impact:** Student home works in “not established” membership but still a real Auth account.
- **Permission impact:** Combined with AUD-001, that account can read/write academy collections.
- **Backend impact:** Disable public sign-up or create `pending` identities only.
- **Dependency:** AUD-001, AUD-016
- **Recommended fix:** Product decision: close register, or register-as-request only (no `isActive`, no profile write).
- **Verification method:** Complete `/register` then query `users` and `studentProfiles`.
- **Status:** Open (current vs intended mismatch)

### AUD-006

- **Priority:** P0
- **Role:** Ops
- **Feature:** Firebase deploy wiring
- **Screen/File:** `firebase.json` — `firestore.indexes` only; no `firestore.rules`; no `storage.rules`
- **Category:** Production readiness
- **Current behavior:** Repo contains `firestore.rules` and `storage.rules`, but `firebase.json` does not reference them. `firebase deploy` from this file will not publish those rules.
- **Expected behavior:** Deployed rules match the repo files (once those files are actually restrictive).
- **Root cause:** Incomplete Category B wiring.
- **Source of truth:** Whatever is currently live in Firebase Console — **unknown from this repo**.
- **Data impact:** Production Authz may be older/open, or never updated.
- **UI impact:** None directly.
- **Permission impact:** Repo rules are not an operational control.
- **Backend impact:** Indexes may deploy without rules.
- **Dependency:** AUD-001, AUD-002
- **Recommended fix:** Add `rules` keys; confirm Console vs repo; never assume file presence == deployed.
- **Verification method:** `firebase.json` review + Console rules snapshot.
- **Status:** Open

### AUD-007

- **Priority:** P0
- **Role:** Parent
- **Feature:** Wallet pay
- **Screen/File:** `parent_wallet.dart`; `pay_payment_from_wallet_usecase.dart`; `parent_subscriptions_page.dart`; `parent_remote_datasource_impl.dart` transaction sets `status: paid`, `method: wallet`
- **Category:** Payments
- **Current behavior:** Parent UI shows wallet balance and “pay from wallet”. A Firestore transaction can mark the payment **paid** without Supervisor review, Vodafone proof, or a trusted payment provider.
- **Expected behavior (this audit’s stated model):** External Vodafone Cash + screenshot + pending_review. Proof is evidence, not SSOT. No accidental wallet/Paymob paid state.
- **Root cause:** Sprint-2 wallet contract left live beside the later proof contract.
- **Source of truth:** Conflicting: `ParentPaymentProofContract` vs `ParentWalletContract`.
- **Data impact:** False paid; finance `getFinancialSummary` counts `status==paid`.
- **UI impact:** Parent sees success snackbar «تم الدفع من المحفظة».
- **Permission impact:** If rules were strict, `wallets` is not even listed (AUD-035). If rules are open/not deployed, wallet paid succeeds.
- **Backend impact:** Two payment rails.
- **Dependency:** AUD-004, AUD-012, AUD-035
- **Recommended fix:** Product decision: remove wallet rail from UI+write path, **or** formally adopt wallet. Do not leave both.
- **Verification method:** Parent with `wallets/{id}.balance >= amount` pays an unpaid payment.
- **Status:** Open — contradiction, not resolved in this audit

### AUD-008

- **Priority:** P0
- **Role:** Parent
- **Feature:** Proof vs paid
- **Screen/File:** `parent_payment_proof.dart`; `submitPaymentProof` update; rules comment vs matchers
- **Category:** Payments
- **Current behavior:** App write for proof correctly does **not** set `status: paid` (sets `reviewStatus=pending_review`). Rules nevertheless allow setting paid. Supervisor **approved** sets `status: paid`.
- **Expected behavior:** Proof never equals paid. Rules match the app contract.
- **Root cause:** App contract implemented in Dart; not in rules.
- **Source of truth:** Intended: `reviewStatus` + Supervisor `status`. Actual: rules allow bypass.
- **Data impact:** Same as AUD-004.
- **UI impact:** Proof UI copy is honest; security is not.
- **Permission impact:** Supervisor review can be skipped via SDK.
- **Backend impact:** Field-level rules required.
- **Dependency:** AUD-001, AUD-004
- **Recommended fix:** Enforce allow-list on parent payment updates.
- **Verification method:** Proof submit then inspect doc; SDK attempt to set paid.
- **Status:** Open

### AUD-009

- **Priority:** P1
- **Role:** Parent / Admin / Supervisor
- **Feature:** Payment invoice creation
- **Screen/File:** No `payments.add` / `payments.doc().set` in `lib/`. Reads/updates only in parent, supervisor, admin datasources. Demo seed `tool/demo_academy_dataset.dart` also has **no** payments seed.
- **Category:** Missing contract
- **Current behavior:** Parent can list payments and upload proof **only if documents already exist**. There is no in-app flow: select period + children → create amount due.
- **Expected behavior (stated model):** Parent selects subscription/period + child/children → sees amount → pays externally.
- **Root cause:** Invoice issuance never implemented (or lives only outside this repo).
- **Source of truth:** **None** for who creates `payments/{id}` with `amount`, `dueDate`, `studentId`, `parentId`, `status`.
- **Data impact:** Empty payment history in a clean academy.
- **UI impact:** Subscriptions tab can look empty; proof CTA has nothing to attach to.
- **Permission impact:** N/A
- **Backend impact:** Need issuer (Admin/cron/callable) and amount policy.
- **Dependency:** AUD-037
- **Recommended fix:** Product/backend: define issuer, period, amount per child/halaqa, idempotent invoice ids.
- **Verification method:** Fresh academy, Parent subscriptions, Admin finance — all empty.
- **Status:** Missing contract

### AUD-010

- **Priority:** P1
- **Role:** Parent / Admin
- **Feature:** Overdue
- **Screen/File:** `PaymentModel._statusFromString` maps stored `overdue`; Admin/Parent filter on that enum. No writer of `status: 'overdue'` in `lib/`.
- **Category:** Missing contract
- **Current behavior:** Overdue UI works only if a document is **already** stored as `overdue`. Due-date in the past with `status: due` stays “due”.
- **Expected behavior:** Overdue detectable from dueDate vs clock, then reminders/escalation.
- **Root cause:** No job, no client derivation from `dueDate`.
- **Source of truth:** Stored string `status` only.
- **Data impact:** Finance overdue totals undercount.
- **UI impact:** Parent alerts (`ParentAlertKind.overduePayment`) never fire for merely-late `due` rows.
- **Permission impact:** N/A
- **Backend impact:** Scheduled function or derived view.
- **Dependency:** AUD-009, AUD-011, AUD-014
- **Recommended fix:** Product: store vs derive overdue; then implement one SSOT.
- **Verification method:** Insert `status: due` with past `dueDate`; observe UI.
- **Status:** Missing contract

### AUD-011

- **Priority:** P1
- **Role:** Parent / Student / Admin
- **Feature:** Account suspension from payment
- **Screen/File:** `ToggleAccountStatusEvent` sets `users.isActive`. Login blocks `!isActive`. No payment-overdue → suspend path. No “suspension reason” field on `UserEntity`.
- **Category:** Missing contract
- **Current behavior:** Admin can disable teacher/student accounts from management UI. Payment overdue does not suspend. User sees generic «هذا الحساب موقوف، يرجى التواصل مع الإدارة» with no reason and no in-app Admin contact-for-reactivation payment flow.
- **Expected behavior (stated model):** Overdue → reminders → suspension → reason visible → contact Admin → Admin reactivates.
- **Root cause:** `isActive` is a generic kill switch, not a payment-policy state machine.
- **Source of truth:** `users.isActive` only.
- **Data impact:** No audit trail of why an account was stopped.
- **UI impact:** No suspension-reason screen.
- **Permission impact:** Disabled Auth user vs `isActive` vs Firebase Auth `user-disabled` are separate.
- **Backend impact:** Need policy states: active / overdue / suspended_payment / disabled.
- **Dependency:** AUD-010
- **Recommended fix:** Product decision on whether non-payment suspends login or only features.
- **Verification method:** Mark payment overdue; confirm login still works.
- **Status:** Missing contract

### AUD-012

- **Priority:** P1
- **Role:** Parent
- **Feature:** Vodafone destination
- **Screen/File:** `ParentPaymentProofContract.transferDestination = ''`
- **Category:** Payments
- **Current behavior:** Empty destination by design («no invented academy number»). UI is instructions-only. Official number is not configurable in Admin settings either (no field found).
- **Expected behavior:** Official Vodafone destination remains configurable.
- **Root cause:** Constant empty; no `academySettings` payment destination.
- **Source of truth:** **None** (intentionally blank constant).
- **Data impact:** Parents cannot know where to send money from the app.
- **UI impact:** Proof upload without a payee.
- **Permission impact:** N/A
- **Backend impact:** Need Admin-configurable destination in `academySettings`.
- **Dependency:** AUD-009
- **Recommended fix:** Product: store destination in settings; never hardcode a phone in clients.
- **Verification method:** Read constant; inspect Admin communication settings (no payee field).
- **Status:** Partially implemented (upload exists; destination missing)

### AUD-013

- **Priority:** P1
- **Role:** Parent
- **Feature:** Paymob
- **Screen/File:** `initiatePayment` throws `الدفع الإلكتروني غير متاح حالياً`; commented callable `createPaymentIntention`; `functions/src/paymob/*` still exported from `functions/src/index.ts`; `PaymentInitiationEntity` still Paymob-shaped
- **Category:** Payments
- **Current behavior:** Electronic Paymob initiation is disabled in Dart. Cloud Functions for Paymob remain in tree. Parent bloc comment still says Paymob.
- **Expected behavior:** No accidental Paymob paid state; intended rail is Vodafone + proof.
- **Root cause:** Incomplete decommission vs new proof rail.
- **Source of truth:** None live for Paymob; functions may still be deployable.
- **Data impact:** If functions are deployed, a second paid path exists via webhook (`paymobWebhook.ts`).
- **UI impact:** Initiate-payment path errors if invoked.
- **Permission impact:** N/A
- **Backend impact:** Confirm functions are not deployed, or they are a live contradiction.
- **Dependency:** AUD-007
- **Recommended fix:** Product: delete or quarantine Paymob functions; remove wallet; keep one rail.
- **Verification method:** Call `InitiatePaymentUseCase`; inspect functions package.
- **Status:** Open — contradiction

### AUD-014

- **Priority:** P1
- **Role:** Parent / Supervisor / Admin
- **Feature:** Payment notifications
- **Screen/File:** `AcademyEvent` sealed types — absence, homework, activity only. No payment events. `InAppAcademySignalComposer` switch has no payment branch. `NotificationTypes.payment` exists unused as a producer.
- **Category:** Notifications
- **Current behavior:** Proof submit / approve / reject / overdue / suspension do not fan out academy events.
- **Expected behavior:** Event matrix for payment submitted/approved/rejected/overdue/suspension.
- **Root cause:** Payments never joined W4/W5 sink.
- **Source of truth:** None.
- **Data impact:** Inbox silent on the commercial loop.
- **UI impact:** Parent notifications page can render `payment` type **if** a doc is written some other way; app does not write it.
- **Permission impact:** N/A
- **Backend impact:** New event kinds + observers (parent, supervisor, admin).
- **Dependency:** AUD-009–011
- **Recommended fix:** Add payment facts to `AcademyEvent` after SSOT commit; do not notify from UI.
- **Verification method:** Submit proof; query `notifications` for parent uid.
- **Status:** Missing contract (producer)

### AUD-015

- **Priority:** P1
- **Role:** Parent / Admin
- **Feature:** Parent↔child link
- **Screen/File:** `getChildrenIds` reads `parentProfiles.childrenIds`. Grep: no `arrayUnion`/`arrayRemove` on `childrenIds` in `lib/`.
- **Category:** Missing contract
- **Current behavior:** Parent home is empty without a pre-seeded `childrenIds` array. W8 admit does not write parent links. Admin has no link/unlink UI found.
- **Expected behavior:** Staff can attach children to a parent; Parent then sees progress/payments/messages.
- **Root cause:** Post-W8 explicitly deferred family link; still deferred in this freeze.
- **Source of truth:** `parentProfiles.childrenIds` — **read-only in app**.
- **Data impact:** W4/W7 parent observers also depend on this array.
- **UI impact:** Parent children tab empty state.
- **Permission impact:** Parent cannot self-claim a student (good) but Admin cannot link either (gap).
- **Backend impact:** Need Admin/Supervisor writer with invariant.
- **Dependency:** W4/W5/W7 recipient resolution
- **Recommended fix:** Product workflow for family link; do not invent it in clients ad hoc.
- **Verification method:** Create parent Auth user; open Parent home.
- **Status:** Missing contract (documented as out of W8 historically; still a product hole)

### AUD-016

- **Priority:** P1
- **Role:** Admin
- **Feature:** Teacher / Supervisor / Admin creation
- **Screen/File:** `AdminTeachersPage` edits rating/quota/`isActive`. No `createUserWithEmailAndPassword` for staff in `lib/`. Register is student-only.
- **Category:** Auth
- **Current behavior:** Staff identities must be seeded (`tool/demo_academy_dataset.dart` / Console). Admin cannot provision teachers/supervisors in-app.
- **Expected behavior (product direction):** Admin provisions sensitive roles.
- **Root cause:** No Admin callable / invite flow.
- **Source of truth:** Firebase Auth + `users.role` created out of band.
- **Data impact:** Cannot onboard staff without engineering seed.
- **UI impact:** Teachers page is a directory, not a hiring flow.
- **Permission impact:** Public register cannot create staff (good) but Admin cannot either (gap).
- **Backend impact:** Needs Admin SDK invite + role doc.
- **Dependency:** AUD-005
- **Recommended fix:** Admin-only identity provisioning; disable public register.
- **Verification method:** Walk Admin teachers/supervisors pages for a create CTA.
- **Status:** Missing contract

### AUD-017

- **Priority:** P1
- **Role:** All
- **Feature:** Password reset
- **Screen/File:** No `sendPasswordResetEmail` / forgot-password route. Login maps Firebase errors only.
- **Category:** Auth
- **Current behavior:** User cannot recover a password in-app.
- **Expected behavior:** Reset via email (or Admin reset).
- **Root cause:** Not implemented.
- **Source of truth:** Firebase Auth passwords only.
- **Data impact:** Locked-out users stay locked.
- **UI impact:** No «نسيت كلمة المرور».
- **Permission impact:** N/A
- **Backend impact:** Standard Firebase reset or Admin SDK.
- **Dependency:** None
- **Recommended fix:** Add reset; localize errors.
- **Verification method:** Inspect login page + auth datasource.
- **Status:** Missing contract

### AUD-018

- **Priority:** P1
- **Role:** Admin / Teacher
- **Feature:** Halaqa creation
- **Screen/File:** `AdminCreateHalaqaPage` — name, teacher, supervisor, meeting link. `CreateHalaqaUseCase` does not pass `schedule`. `AcademyHalaqaFirestore.createHalaqa` defaults `schedule: []`.
- **Category:** Halaqa / Session
- **Current behavior:** A halaqa **can and does** exist without a valid schedule. Then `HalaqaWeeklySessionsMapper.mapTodayOperationalDays` returns empty → Teacher cannot open **evaluation create** (`noSessionToday`); today agenda is empty. **Attendance is not equivalently blocked** (AUD-094): `AttendanceService._resolveSessionBounds` falls back to `{halaqaId}_yyyyMMdd` for the selected/calendar day even with no slot.
- **Expected behavior:** Schedule/day/time exists before operated sessions.
- **Root cause:** Create UI never captured slots; write path allows empty schedule.
- **Source of truth:** `halaqat.schedule[]` `{day, startTime, endTime}`.
- **Data impact:** Operated academy loop never starts for that halaqa.
- **UI impact:** Teacher classes show halaqa; session CTAs disabled / blocked.
- **Permission impact:** N/A
- **Backend impact:** Need update-schedule write (not found as Admin edit schedule screen).
- **Dependency:** AUD-024
- **Recommended fix:** Require ≥1 slot at create **or** add schedule editor; do not silently create empty.
- **Verification method:** Admin create halaqa; inspect Firestore `schedule`; Teacher home today.
- **Status:** Open

### AUD-019

- **Priority:** P1
- **Role:** Admin / Teacher
- **Feature:** Teacher/supervisor reassignment
- **Screen/File:** `AcademyHalaqaFirestore.assignStaff` updates `halaqat.teacherId` / `supervisorId` only. Create path `arrayUnion`s `teacherProfiles.halaqatIds`; assign path does not move the array, does not `arrayRemove` old teacher.
- **Category:** Halaqa
- **Current behavior:** Changing teacher leaves stale `halaqatIds` on the previous teacher profile; new teacher profile may not list the halaqa.
- **Expected behavior:** Roster of “my halaqat” follows the live `halaqat.teacherId`.
- **Root cause:** Incomplete dual-write.
- **Source of truth:** Ambiguous: `halaqat.teacherId` vs `teacherProfiles.halaqatIds`.
- **Data impact:** Teacher home query if it uses profile array will miss/gain wrongly.
- **UI impact:** Depends which reader (teacher datasource uses `where teacherId` — need consistency check). Teacher list of halaqat in datasource queries `halaqat.where teacherId` (verified in teacher datasource) — **readers of teacherId are OK**; profile array is stale for any consumer of `halaqatIds`.
- **Permission impact:** N/A
- **Backend impact:** Transaction: halaqa + both teacher profiles.
- **Dependency:** None
- **Recommended fix:** Single SSOT `halaqat.teacherId`; treat `halaqatIds` as projection or update atomically.
- **Verification method:** Assign new teacher; read both profiles.
- **Status:** Open

### AUD-020

- **Priority:** P1
- **Role:** Student / Parent / Teacher / Supervisor
- **Feature:** overallProgressPercent
- **Screen/File:** Written only at student register (`0`) and seeds. Displayed on student home, mushaf dashboard, teacher class detail, supervisor roster, parent children. Evaluation/homework writes do **not** update it.
- **Category:** Quran / Progress
- **Current behavior:** Dashboards show a stored number that does not move when the teacher evaluates.
- **Expected behavior:** If the product claims “progress”, it must derive from recitation SSOT or a documented projector.
- **Root cause:** Profile fields treated as SSOT without a writer.
- **Source of truth:** **None live.** Display SSOT is a stale profile field.
- **Data impact:** Cross-role disagreement with actual recitationRecords.
- **UI impact:** Donut charts / percentages are misleading (0 or seed values).
- **Permission impact:** N/A
- **Backend impact:** Need a projector after evaluation commit.
- **Dependency:** AUD-021, AUD-022, AUD-039
- **Recommended fix:** Product: either stop displaying it, or define Quran-scope math and write it transactionally.
- **Verification method:** Record an evaluation; re-read `studentProfiles.overallProgressPercent`.
- **Status:** Open

### AUD-021

- **Priority:** P1
- **Role:** Student / Parent
- **Feature:** streakDays / completedJuz / totalVersesMemorized / level
- **Screen/File:** `student_profile_entity.dart` + model reads; register initializes zeros; homework submit increments `points`/`coins` only.
- **Category:** Quran / Progress
- **Current behavior:** Streak, juz, verses, level are stored profile counters with no operational updater from attendance/evaluation.
- **Expected behavior:** Traceable to recitation ranges / Quran catalog / attendance days.
- **Root cause:** Same as AUD-020.
- **Source of truth:** Stale profile fields / seeds.
- **Data impact:** Achievements and parent sums add meaningless numbers.
- **UI impact:** Student header “N يوم”, mushaf “الختمة x/٣٠”.
- **Permission impact:** N/A
- **Backend impact:** Define counters vs derived queries.
- **Dependency:** AUD-020
- **Recommended fix:** Derive or stop showing.
- **Verification method:** Attend a week; observe streakDays unchanged.
- **Status:** Open

### AUD-022

- **Priority:** P1
- **Role:** Parent
- **Feature:** Weekly report verses
- **Screen/File:** `parent_remote_datasource_impl.dart` `'totalVersesMemorized': reviewedDocs.length`
- **Category:** Quran / Progress
- **Current behavior:** Parent weekly “verses memorized” is the **count of reviewed recitation documents**, not verses/pages/juz.
- **Expected behavior:** If labeled verses, count verses from ranges; otherwise rename.
- **Root cause:** Field reuse.
- **Source of truth:** recitationRecords count, mislabeled.
- **Data impact:** Parent/Admin language lies.
- **UI impact:** Parent reports page.
- **Permission impact:** N/A
- **Backend impact:** Parse `versesRange` or store verse counts on the record.
- **Dependency:** AUD-020
- **Recommended fix:** Rename UI or compute from ranges.
- **Verification method:** Two reviews of one ayah each → UI shows “2 verses”.
- **Status:** Open

### AUD-023

- **Priority:** P1
- **Role:** Admin
- **Feature:** Academy stats
- **Screen/File:** `admin_remote_datasource_impl.getAcademyStats` sets `overallAttendancePercent: 0`, `totalVersesMemorizedThisMonth: 0` with comment that aggregation is not in functions.
- **Category:** Reports
- **Current behavior:** Admin dashboard shows zeros that look like metrics.
- **Expected behavior:** Real aggregation or explicit “unavailable”.
- **Root cause:** Client cannot cheaply compute academy-wide %; placeholders used.
- **Source of truth:** None.
- **Data impact:** Misleading leadership numbers.
- **UI impact:** Dashboard cards.
- **Permission impact:** N/A
- **Backend impact:** Scheduled aggregation / count queries.
- **Dependency:** AUD-034
- **Recommended fix:** Hide or compute honestly.
- **Verification method:** Seed attendance; Admin dashboard still 0%.
- **Status:** Open

### AUD-024

- **Priority:** P1
- **Role:** Teacher / All
- **Feature:** Session documents
- **Screen/File:** `AttendancePolicy.sessionIdForDay` `{halaqaId}_yyyyMMdd`; `HalaqaWeeklySessionsMapper._asOperationalDay`; no `sessions` collection in `FirestoreCollections`.
- **Category:** Session lifecycle
- **Current behavior:** Sessions are **inferred** from `halaqat.schedule` for “today”. Weekly student schedule mapper also builds ephemeral `{halaqaId}_$index` ids (different shape) for the week list.
- **Expected behavior:** Clear SSOT: generated session docs **or** documented inference. Not two id shapes.
- **Root cause:** Operational day id vs weekly UI id.
- **Source of truth:** Schedule slots + calendar clock. No persisted session lifecycle (open/close).
- **Data impact:** Cannot query historical sessions as entities; attendance/eval hang off synthetic ids.
- **UI impact:** Teacher “opens session” is opening today’s inferred day, not a document.
- **Permission impact:** N/A
- **Backend impact:** If overlapping real-world slots needed, inference collapses them (AUD-056).
- **Dependency:** AUD-018, AUD-025, AUD-056
- **Recommended fix:** Product: persist sessions or formally accept inference + one-id rule.
- **Verification method:** Compare weekly session.id vs attendance sessionId.
- **Status:** Missing contract (session entity) / implemented as inference

### AUD-025

- **Priority:** P1
- **Role:** Teacher
- **Feature:** Evaluation vs attendance
- **Screen/File:** `EvaluationService.openEvaluation` blocks only on no session today / missing halaqa / non-session record. Does not require an attendance mark.
- **Category:** Session
- **Current behavior:** Evaluation can be written for a student who was never marked. Attendance can exist without evaluation. Neither requires a persisted session doc.
- **Expected behavior (stated conceptual flow):** attend → then evaluate. Not encoded.
- **Root cause:** Separate SSOTs (`attendanceRecords`, `recitationRecords`) without a coupling invariant.
- **Source of truth:** Each collection independently.
- **Data impact:** Progress/eval history for absentees; attendance-only days.
- **UI impact:** Teacher can evaluate from evaluations page without completing register.
- **Permission impact:** N/A
- **Backend impact:** Optional gate in `EvaluationService` — product decision.
- **Dependency:** AUD-024
- **Recommended fix:** Product: require present/late, or allow eval without attendance explicitly.
- **Verification method:** Evaluate unmarked student on a scheduled day.
- **Status:** Product decision needed (current = allowed)

### AUD-026

- **Priority:** P1
- **Role:** Chat
- **Feature:** Message pagination
- **Screen/File:** `chat_remote_datasource.dart` `watchMessages` — `orderBy('sentAt').snapshots()` no `limit`
- **Category:** Scalability
- **Current behavior:** Entire conversation loaded into memory for every room.
- **Expected behavior:** Page / window recent N; load older on scroll.
- **Root cause:** Unbounded listener.
- **Source of truth:** `conversations/{id}/messages`
- **Data impact:** Cost + memory; large history fails on device.
- **UI impact:** Chat room jank.
- **Permission impact:** N/A
- **Backend impact:** Need indexes already on sentAt (single-field default).
- **Dependency:** AUD-028
- **Recommended fix:** Limit + cursor.
- **Verification method:** Seed 10k messages; open room.
- **Status:** Open

### AUD-027

- **Priority:** P1
- **Role:** Teacher / Student
- **Feature:** Teacher+students group
- **Screen/File:** `firestore.rules` conversation create: `participantIds.size() <= 2` except `admin_internal_group`. `ChatPermissionPolicy` is 1:1 role pairs. `ConversationIdGenerator` is two uids.
- **Category:** Chat
- **Current behavior:** Architecture **cannot** support a halaqa group. Admin internal group is the only group, Admin-only.
- **Expected behavior:** Only if product policy permits a teacher+students group — currently **no contract**.
- **Root cause:** 1:1 design + rules.
- **Source of truth:** 1:1 conversation docs.
- **Data impact:** N/A
- **UI impact:** Teacher messages are 1:1 list.
- **Permission impact:** Rules would reject group create.
- **Backend impact:** New conversation kind + rules.
- **Dependency:** Product policy
- **Recommended fix:** Do not implement groups without a new contract. Document as out of scope vs defect: **missing capability**, not a broken button.
- **Verification method:** Attempt 3-participant create.
- **Status:** Missing contract (capability)

### AUD-028

- **Priority:** P1
- **Role:** Admin
- **Feature:** Chat oversight
- **Screen/File:** `watchAllConversations` — `_conversationsRef.snapshots()` no query filter
- **Category:** Scalability / Privacy
- **Current behavior:** Admin listens to **all** conversation documents in the project.
- **Expected behavior:** If oversight is product-approved, still needs pagination/query. Privacy: Admin read of Teacher↔Student and Parent↔Teacher threads.
- **Root cause:** Oversight implemented as collection listen.
- **Source of truth:** `conversations`
- **Data impact:** Cost grows with every 1:1 in the academy.
- **UI impact:** Inbox eventually unusable.
- **Permission impact:** Rules allow Admin read of every conversation (explicit).
- **Backend impact:** Product decision on silent Admin read.
- **Dependency:** AUD-054
- **Recommended fix:** Product: keep/forbid oversight; if keep, query windows.
- **Verification method:** Count listeners in Admin chat inbox.
- **Status:** Open + product decision on privacy

### AUD-029

- **Priority:** P1
- **Role:** All
- **Feature:** Push
- **Screen/File:** `di_module.dart` FirebaseMessaging not registered (H3). Only `InAppAcademyEventHandler`.
- **Category:** Notifications
- **Current behavior:** In-app inbox only. No FCM tokens, no OS push.
- **Expected behavior:** Session reminders / payment overdue typically require push. Prior docs: B-FCM Category B.
- **Root cause:** Explicit deferral still true in this freeze.
- **Source of truth:** `notifications` docs.
- **Data impact:** N/A
- **UI impact:** Users who are not in the app miss events.
- **Permission impact:** N/A
- **Backend impact:** Outbox + FCM handler.
- **Dependency:** AUD-030
- **Recommended fix:** Treat as production gap if push is required for academy ops.
- **Verification method:** Kill app; produce absence event; no OS notification.
- **Status:** Accepted historically as Category B — still a production gap if push is in the freeze bar

### AUD-030

- **Priority:** P1
- **Role:** Student / Parent / Teacher
- **Feature:** Session reminders
- **Screen/File:** `NotificationTypes.sessionReminder` UI chrome exists (`notification_page.dart`, `parent_notifications_page.dart`). No producer writes that type. No scheduler.
- **Category:** Notifications
- **Current behavior:** Reminder UI can render a type that is never created by app logic.
- **Expected behavior:** Reminder before inferred session start.
- **Root cause:** Type reserved; no Cloud Scheduler / client producer.
- **Source of truth:** None.
- **Data impact:** Empty.
- **UI impact:** Dead type styling.
- **Permission impact:** N/A
- **Backend impact:** Needs schedule + FCM or in-app create.
- **Dependency:** AUD-024, AUD-029
- **Recommended fix:** Producer or remove UI type.
- **Verification method:** Grep writers of `session_reminder`.
- **Status:** Missing contract

### AUD-031

- **Priority:** P1
- **Role:** Student / Parent
- **Feature:** Award notifications
- **Screen/File:** `AwardsRemoteDatasourceImpl.grantAward` writes `achievements` + profile dual-write. No `AcademyEvent` for awards. `NotificationTypes.achievement` unused as producer.
- **Category:** Notifications / Awards
- **Current behavior:** Grant is persisted; inbox is not updated via the academy event pipeline.
- **Expected behavior:** Student/parent notified of award.
- **Root cause:** Awards outside W4/W5 sink (same pattern as payments).
- **Source of truth:** `achievements` SSOT; notifications not projected.
- **Data impact:** Students discover awards only by opening awards screens.
- **UI impact:** Notifications empty for grants.
- **Permission impact:** N/A
- **Backend impact:** New event kind.
- **Dependency:** H7 achievements contract (exists)
- **Recommended fix:** Publish after grant commit.
- **Verification method:** Grant award; query notifications.
- **Status:** Open

### AUD-032

- **Priority:** P1
- **Role:** Teacher
- **Feature:** Analytics query index
- **Screen/File:** `analytics_remote_datasource_impl.dart` comments require `recitationRecords (halaqaId ASC, date ASC)`. `firestore.indexes.json` has studentId+date indexes, **not** halaqaId+date for recitationRecords.
- **Category:** Firebase
- **Current behavior:** Analytics queries may fail at runtime with missing-index errors (or scan poorly).
- **Expected behavior:** Index present and deployed.
- **Root cause:** Inventory in Dart not reflected in indexes file.
- **Source of truth:** indexes file vs query.
- **Data impact:** Analytics Phase 2 broken in fresh projects.
- **UI impact:** Teacher analytics error state.
- **Permission impact:** N/A
- **Backend impact:** Add composite index.
- **Dependency:** None
- **Recommended fix:** Add index; deploy.
- **Verification method:** Open teacher analytics on a halaqa.
- **Status:** Open

### AUD-033

- **Priority:** P1
- **Role:** Parent
- **Feature:** Payments query index
- **Screen/File:** Parent `payments.where parentId orderBy dueDate desc`. `firestore.indexes.json` has **no** payments indexes.
- **Category:** Firebase
- **Current behavior:** First parent payment load may fail until a console-generated index exists (not in repo).
- **Expected behavior:** Index in repo.
- **Root cause:** Query added without index file update.
- **Source of truth:** Missing.
- **Data impact:** Parent subscriptions error.
- **UI impact:** Error, not empty.
- **Permission impact:** N/A
- **Backend impact:** Composite `parentId` + `dueDate`.
- **Dependency:** AUD-009
- **Recommended fix:** Add index.
- **Verification method:** Parent getPayments on a project using only repo indexes.
- **Status:** Open

### AUD-034

- **Priority:** P1
- **Role:** Admin
- **Feature:** Finance aggregation
- **Screen/File:** `getFinancialSummary` / `getPayments` — `payments.get()` entire collection, aggregate in client.
- **Category:** Scalability
- **Current behavior:** Fine for tens of invoices; fails cost/time at thousands.
- **Expected behavior:** Server aggregation or pagination + running totals.
- **Root cause:** Client-side reduce.
- **Source of truth:** All payment docs every load.
- **Data impact:** Cost; incomplete UI if query timeouts.
- **UI impact:** Admin finance tab.
- **Permission impact:** Combined with AUD-001 any user could also get().
- **Backend impact:** Scheduled totals doc.
- **Dependency:** AUD-009
- **Recommended fix:** Totals document maintained on write.
- **Verification method:** Seed 20k payments; open Admin finance.
- **Status:** Open

### AUD-035

- **Priority:** P1
- **Role:** Parent
- **Feature:** wallets collection
- **Screen/File:** `FirestoreCollections.wallets`; not mentioned in `firestore.rules`
- **Category:** Payments / Security
- **Current behavior:** If repo rules **were** deployed, wallet reads/writes deny-by-default. UI still offers wallet pay, then permission-denied (likely shown as generic server/network error).
- **Expected behavior:** Either wallet exists in rules **or** UI is gone.
- **Root cause:** Dual rails; rules not updated for wallets.
- **Source of truth:** Conflicting.
- **Data impact:** Wallet unusable under strict rules; dangerous under open rules.
- **UI impact:** Error on pay-from-wallet.
- **Permission impact:** Unknown at runtime due to AUD-006.
- **Backend impact:** Align rules with product rail.
- **Dependency:** AUD-007, AUD-006
- **Recommended fix:** Same product decision as AUD-007.
- **Verification method:** Deploy repo rules; try wallet pay.
- **Status:** Open

### AUD-036

- **Priority:** P1
- **Role:** All
- **Feature:** Route vs data authorization
- **Screen/File:** `AppRouteAccess.isAllowed` prefix home path; supervisor escalation into `/teacher/attendance/` and `/teacher/halaqa/`. Firestore still open.
- **Category:** Security
- **Current behavior:** Student cannot open `/admin` in GoRouter. Student **can** still read Admin collections via SDK.
- **Expected behavior:** Defense in depth: router **and** rules.
- **Root cause:** H8 locked navigation only.
- **Source of truth:** UI allowlist.
- **Data impact:** Same as AUD-001.
- **UI impact:** False sense of role isolation.
- **Permission impact:** Deep links bounce; data does not.
- **Backend impact:** Rules.
- **Dependency:** AUD-001
- **Recommended fix:** Rules first.
- **Verification method:** Student token get `halaqat` / `payments`.
- **Status:** Open

### AUD-037

- **Priority:** P1
- **Role:** Parent
- **Feature:** Subscription period + multi-child amount
- **Screen/File:** `parent_subscriptions_page.dart` lists existing `PaymentEntity` per `studentId`. No period picker that **creates** a combined invoice.
- **Category:** Missing contract
- **Current behavior:** Multi-child is display/filter over pre-existing per-student docs. Children in different halaqat have no amount policy.
- **Expected behavior:** Select period + children → amount.
- **Root cause:** No pricing/catalog.
- **Source of truth:** None for fees.
- **Data impact:** Cannot bill.
- **UI impact:** Visual subscriptions without a checkout cart.
- **Permission impact:** N/A
- **Backend impact:** Fee catalog + invoice issuer.
- **Dependency:** AUD-009
- **Recommended fix:** Product catalog.
- **Verification method:** UI inspection.
- **Status:** Missing contract

### AUD-038

- **Priority:** P1
- **Role:** Teacher
- **Feature:** Inactive halaqa
- **Screen/File:** `HalaqaEntity.isActive => status == 'active'`. Teacher classes can filter active. Mapper/evaluation do not take `status` when resolving today’s session from a loaded entity. Admin create always `status: active`. No Admin deactivate-halaqa write found in create path; status exists on entity.
- **Category:** Halaqa
- **Current behavior:** If a halaqa is not `active`, some lists hide it; if a stale entity is still loaded, session inference can still run. No full lifecycle for inactive (what happens to upcoming inferred sessions).
- **Expected behavior:** Inactive ⇒ no new attendance/eval; historical readable.
- **Root cause:** Status field without complete consumer set.
- **Source of truth:** `halaqat.status` (weakly enforced).
- **Data impact:** Possible writes against inactive halaqat depending on entry path.
- **UI impact:** Teacher filter vs supervisor lists may disagree.
- **Permission impact:** Rules do not check status.
- **Backend impact:** Gate writes in use cases.
- **Dependency:** AUD-018
- **Recommended fix:** Central gate in attendance/eval services.
- **Verification method:** Set status inactive; try SaveDayAttendance.
- **Status:** Partially implemented

### AUD-039

- **Priority:** P1
- **Role:** Student
- **Feature:** Achievements accuracy
- **Screen/File:** `student_achievements_page.dart` uses `overallProgressPercent` as `memorizationAccuracy`
- **Category:** Quran / Progress
- **Current behavior:** A stored overall % is labeled as accuracy.
- **Expected behavior:** Accuracy from graded recitations (see `AnalyticsRecitationHonesty`).
- **Root cause:** Field reuse.
- **Source of truth:** Wrong field.
- **Data impact:** Misleading gamification.
- **UI impact:** Achievements page.
- **Permission impact:** N/A
- **Backend impact:** Use reviewed grade weights.
- **Dependency:** AUD-020
- **Recommended fix:** Bind to recitation honesty helpers or remove metric.
- **Verification method:** Profile 40% + all excellent reviews still shows 40% “accuracy”.
- **Status:** Open

### AUD-040

- **Priority:** P1
- **Role:** Admin / Supervisor
- **Feature:** Membership exit
- **Screen/File:** Supervisor transfer/admit via `AcademyAdmissionFirestore`. No `arrayRemove` unenroll-without-destination as a dedicated exit. Admin `isActive=false` stops login but does not clear roster.
- **Category:** Missing contract
- **Current behavior:** Student can remain on `halaqat.studentIds` while `isActive` false (or vice versa depending on path). Transfer/move exists. True unenroll is still not a first-class operation (W8 out of scope historically).
- **Expected behavior:** Explicit exit: roster + primary `halaqaId` + observers.
- **Root cause:** W8 admit-only invariant.
- **Source of truth:** Incomplete.
- **Data impact:** Ghost roster members.
- **UI impact:** Teacher register still lists them if roster not cleaned.
- **Permission impact:** Login gate uses `isActive` only.
- **Backend impact:** Exit transaction.
- **Dependency:** W8
- **Recommended fix:** Product exit workflow.
- **Verification method:** Deactivate student; open teacher attendance roster.
- **Status:** Missing contract (historically accepted; still a freeze gap)

---

### AUD-041 through AUD-081 (P2)

#### AUD-041 — Five independent bottom nav implementations

- **Priority:** P2 · **Role:** All · **Feature:** Bottom navigation · **Category:** Shared UI
- **Screen/File:** `_TeacherBottomNav`, `_SupervisorBottomNav`, `_StudentBottomNav`, `_ParentBottomNav`, `AdminBottomNav`
- **Current:** Each shell copies height 64, shadow, selected color. Tab counts differ (Teacher 5 including awards; H6 claimed 4).
- **Expected:** One shared `AppBottomNav`.
- **Root cause:** Per-role Figma implementation.
- **Source of truth:** None for nav chrome.
- **UI impact:** Icon size/label/spacing drift.
- **Recommended fix:** Extract shared nav; keep destinations per role.
- **Verification:** Screenshot five shells.
- **Status:** Open

#### AUD-042 — Three subpage scaffolds

- **Priority:** P2 · **AdminSubpageScaffold** uses AppBar + `Icons.arrow_forward_ios_rounded` as back in RTL. **ParentSubpageScaffold** custom header, hardcoded `Color(0xFFF5FAFB)`. **SupervisorSubpageScaffold** `Icons.chevron_right_rounded` back. Teacher/Student mostly AppBar or custom Figma headers.
- **Expected:** One header primitive; back = semantic `BackButton` / `Directionality`.
- **Status:** Open

#### AUD-043 — Hardcoded RTL

- **Priority:** P2 · **File:** `main.dart` has **no** `locale` / `localizationsDelegates`. Many shells wrap `Directionality(textDirection: TextDirection.rtl)`. Teacher Figma cards force RTL internally.
- **Current:** App is Arabic-only RTL. LTR English cannot work even if strings existed.
- **Expected:** Direction follows locale; directional icons use `Icons.arrow_back` (auto-mirrors); non-directional icons do not flip.
- **Status:** Open (English is not implemented — see AUD-044)

#### AUD-044 — No localization system

- **Priority:** P2 · No `.arb`, no `easy_localization`, no `AppLocalizations`. All user-facing strings hardcoded Arabic (plus some English day-label parsers).
- **Status:** Missing contract for EN

#### AUD-045 — Language row dead

- **Priority:** P2 · Teacher/Student/Supervisor settings show «اللغة / العربية» with `onTap: null`.
- **Status:** Open

#### AUD-046 — AppTextStyles baked light colors

- **Priority:** P2 · `AppTextStyles.*` set `color: AppColors.textPrimary` (dark navy). Dark theme textTheme from GoogleFonts may differ, but widgets using `AppTextStyles` stay light-theme colored on dark backgrounds.
- **Status:** Open

#### AUD-047 — Hardcoded Colors.white / Color(0x…)

- **Priority:** P2 · Widespread (student mushaf, audio library, auth, notifications, parent header, etc.). Dark mode incomplete.
- **Status:** Open

#### AUD-048 — Error taxonomy collapse

- **Priority:** P2 · Repositories: `if (!await networkInfo.isConnected) return Left(NetworkFailure())` with default message «لا يوجد اتصال بالإنترنت». `NetworkInfoImpl` times out to **true** after 5s (good: avoids false offline). Remaining failures: `ServerFailure(e.message)` often `e.toString()` including Firebase codes. No distinct timeout / permission / not-found / conflict types in UI.
- **Failure class set:** Network, Server, Auth, Validation, Unexpected — permission-denied becomes Server/Auth mapped only on auth path.
- **Status:** Open

#### AUD-049 — Loading / empty / error

- **Priority:** P2 · Mix of page `CircularProgressIndicator`, role-specific skeletons (`admin_loading_skeletons`, `parent_loading_skeletons`, `supervisor_loading_skeletons`, teacher excuse skeletons). Many screens lack retry. Button loading via `AppButton.isLoading` is separate and not universal.
- **Status:** Open

#### AUD-050 — H6 inventory stale

- **Priority:** P2 · `H6SurfaceCleanup.adminProductUiAdmitOnly = true` and “broadcast UI absent” vs live Admin 5-tab console + broadcast route. Teacher posts removed remains true.
- **Status:** Stale inventory

#### AUD-051 — Teacher IA vs H6 labels

- **Priority:** P2 · Live teacher tabs: الرئيسية · الطلاب · الجوائز · الرسائل · حسابي. H6: الرئيسية، الحلقات، الرسائل، حسابي.
- **Status:** Stale inventory

#### AUD-052 — Parent routing mix

- **Priority:** P2 · Only `/parent`, `/parent/absence-requests`, `/parent/notifications` in GoRouter. Child profile, payments, chat, reports use `Navigator.push`. Deep links and `AppRouteAccess` cannot see those pages.
- **Status:** Open

#### AUD-053 — Chat text-only

- **Priority:** P2 · `ChatRoomPage` comment: text only; no audio/attachments/presence/read receipts. Rules `update, delete: if false` on messages. `markConversationAsRead` exists (unread counts on conversation doc).
- **Status:** Implemented subset; media = missing contract

#### AUD-054 — Admin silent chat read

- **Priority:** P2 · Product allows Admin oversight read-only rooms (`readOnly: true`). Privacy concern for Teacher↔Student and Parent threads.
- **Status:** Product decision needed (implemented)

#### AUD-055 — Parent chat seeding

- **Priority:** P2 · `ParentMessagesTab` auto `getOrCreateConversation` for linked staff. Creates empty conversations just by opening the tab.
- **Status:** Open

#### AUD-056 — Overlapping slots collapsed

- **Priority:** P2 · Mapper D6: multiple same-day slots → one operational day, earliest start, latest end. Second session cannot start as a separate SSOT before the first completes — there is only one `{halaqaId}_yyyyMMdd`.
- **Can a second session start before previous completed?** Not as a second operational session. Teacher cannot have two session ids that day.
- **Status:** Implemented (by design of inference) — flag if product needs two slots/day

#### AUD-057 — Incomplete old sessions

- **Priority:** P2 · No session document to leave “open”. Register completeness is a W3 projection. Historical days stay incomplete forever if teacher never saved marks. `AttendancePolicy.canEditSession` freezes after `sessionEndAt` or midnight.
- **Status:** Open (no closeout SSOT)

#### AUD-058 — Student chat fallback

- **Priority:** P2 · `StudentChatPage` uses `halaqat.teacherId`, else `assignments.assignedBy` — can open chat with a previous assigner if teacher changed.
- **Status:** Open

#### AUD-059 — Mushaf default surah 67

- **Priority:** P2 · Router: if no query, `surahNumber = 67` (Al-Mulk), not from profile current surah (which is not a written field).
- **Status:** Open / product decision

#### AUD-060 — Audio uploads gated

- **Priority:** P2 · `AppCapabilities.audioUploadsEnabled = false`. Student recitation upload throws. W1 accepted residual / Category B.
- **Status:** Accepted capability flag — still blocks homework audio

#### AUD-061 — No CI

- **Priority:** P2 · No `.github/workflows` in freeze.
- **Status:** Open

#### AUD-062 — No App Check

- **Priority:** P2 · Not in tree. Category B historically.
- **Status:** Open

#### AUD-063 — Partial payment

- **Priority:** P2 · Supervisor `partial` sets reviewStatus + remainingAmount; does **not** set `status: paid`. Parent `hasProofAwaitingReview` is false after partial. Resubmit allowed (proof write deletes prior review fields). No invoice for remaining amount.
- **Status:** Partially implemented

#### AUD-064 — Review vs resubmit race

- **Priority:** P2 · Parent `update` proof and Supervisor `update` review are not a transaction. Last writer wins.
- **Status:** Open

#### AUD-065 — Awards queries

- **Priority:** P2 · `_grantsForHalaqa` two unbounded queries (`halaqaId` and `halaqaIds` arrayContains), merge client-side, then optional limit 50.
- **Status:** Open

#### AUD-066 — Supervisor reports

- **Priority:** P2 · `supervisor_reports_tab.dart` exists in shell. H6 said report **write** UI hidden; Firestore `supervisorReports` still signed-in writable.
- **Status:** Open / stale comment risk

#### AUD-067 — AdminOpsBroadcast comment

- **Priority:** P2 · File says product UI absent / admit-only. `AdminBroadcastPage` is routed and hub-wired.
- **Status:** Stale inventory

#### AUD-068 — Dark scaffolds

- **Priority:** P2 · Role homes set `backgroundColor: AppColors.background` (light grey) inside Directionality scaffolds, overriding dark `scaffoldBackgroundColor`.
- **Status:** Open

#### AUD-069 — Student profile phone

- **Priority:** P2 · Teacher and Admin open `StudentProfilePage` showing phone from joined user profile.
- **Status:** Open (may be intended for staff — still a privacy flag vs students)

#### AUD-070 — Session persistence

- **Priority:** P2 · Default Firebase Auth persistence. No idle timeout. Shared-device H1 clears blocs on logout only.
- **Status:** Product decision needed

#### AUD-071 — No authorization tests

- **Priority:** P2 · Tests lock `AppRouteAccess` and use cases; no Firebase emulator rules tests.
- **Status:** Open

#### AUD-072 — Weak widget coverage of 5 role shells

- **Priority:** P2 · Teacher has some home/nav widget tests; Admin/Parent/Supervisor shells largely untested as widgets.
- **Status:** Open

#### AUD-073 — Payment flow tests incomplete

- **Priority:** P2 · Use case tests for proof submit / wallet pay / review status exist. No test that invoices are created, overdue derived, or rules block paid.
- **Status:** Open

#### AUD-074 — No progress math tests

- **Priority:** P2 · No test that evaluation updates profile progress (because it does not). No Quran-scope unit tests.
- **Status:** Open (gap matches AUD-020)

#### AUD-075 — Validation copy Arabic-only

- **Priority:** P2 · Auth/payment/halaqa validators return Arabic strings.
- **Status:** Open

#### AUD-076 — Overflow risk

- **Priority:** P2 · `AppButton` height 52 full width OK; many `Row`s with unsized `Text` for long Arabic names; donut 80×80 fixed; bottom nav 5 items on ~320 width will crush labels; Admin hub tiles.
- **Status:** Open (static review; not device-run in this audit)

#### AUD-077 — Chat send failure

- **Priority:** P2 · Chat room tracks `_pendingSend` locally; no durable outbox; message docs cannot be updated (rules). Retry = send a new message.
- **Status:** Open

#### AUD-078 — Notification readBy arrays

- **Priority:** P2 · Broadcast/inbox uses `readBy` arrays and per-observer docs for academy signals. Array grow is OK per-user docs for W4 signals; role broadcasts with `readBy` do not scale.
- **Status:** Open for `audience` = role/`all`

#### AUD-079 — Calendar locale `ar` hardcoded

- **Priority:** P2 · `calendar_page.dart`
- **Status:** Open

#### AUD-080 — Outstanding amounts

- **Priority:** P2 · Parent summary counts overdue/due in memory from loaded list. No academy-wide outstanding SSOT.
- **Status:** Open

#### AUD-081 — Posts unwired for teacher

- **Priority:** P2 · `PostsListPage` / `posts` collection live; teacher posts tab removed (H6). Student/admin content may still use related surfaces.
- **Status:** Accepted H6 + leftover stack

---

### AUD-082 through AUD-093 (P3)

#### AUD-082 — Back icons mixed

`arrow_back_rounded` (auth, onboarding), `arrow_back_ios` (notifications), `arrow_back_ios_new_rounded` (audio), `arrow_forward_ios_rounded` as **back** (admin scaffold in RTL), `chevron_right_rounded` as back (supervisor). Semantic back in RTL should be a mirroring back icon, not a hand-picked forward ios chevron unless Directionality is proven correct.

- **Directional:** back/forward/chevron/ios arrows.  
- **Non-directional:** language, wallet, groups, awards, headphones — should not flip.

#### AUD-083 — Font mix

Register/login titles `NotoNaskhArabic`; app theme Cairo.

#### AUD-084 — AppButton spinner `Colors.white`

Ignores `textColor` / dark surfaces.

#### AUD-085 — `HalaqaActivitiesMockStore`

Still in `lib/shared/presentation` but production teacher/student activities use `halaqa_activity` Firestore repository. Dead production path; tests still depend on mock.

#### AUD-086 — `GoRouter(debugLogDiagnostics: true)`

Noisy logs in production builds.

#### AUD-087 — Router errorBuilder Arabic hardcoded «الصفحة غير موجودة»

#### AUD-088 — Recitation grades Arabic strings as stored SSOT (`ممتاز` …)

English UI would need mapping; comparisons are locale-locked.

#### AUD-089 — Dual needs-work labels (`يحتاج إعادة` vs `يحتاج تحسين`) handled in analytics honesty — residual vocab split.

#### AUD-090 — Admin zeros without “غير محسوب” caption (pairs AUD-023).

#### AUD-091 — Default `avatarId: 'fox'` on self-register.

#### AUD-092 — Student chat route default name `'المعلم'`.

#### AUD-093 — Eastern digits helpers used on some teacher/parent surfaces, western on others.

---

### Follow-up findings (same freeze)

#### AUD-094

- **Priority:** P1
- **Role:** Teacher
- **Feature:** Attendance without a scheduled meeting
- **Screen/File:** `lib/shared/domain/attendance_service.dart` `_resolveSessionBounds` fallback to `AttendancePolicy.sessionIdForDay`; `TeacherAttendancePage` date picker
- **Category:** Session
- **Current behavior:** If no schedule slot matches today (or teacher picks another date), attendance still **writes** `attendanceRecords` with a synthetic `{halaqaId}_yyyyMMdd`. Evaluation **create** is blocked (`noSessionToday`). “Start session” only navigates.
- **Expected behavior:** Product must say whether marks are allowed only on scheduled meetings.
- **Root cause:** Attendance prefers schedule when present; otherwise invents a day id. Evaluation does not share that fallback for create.
- **Source of truth:** Split — eval create needs inferred meeting; attendance does not.
- **Data impact:** Presence facts that never matched a meeting.
- **UI impact:** Create-halaqa success then attendance can still be filled; eval cannot.
- **Permission impact:** None beyond open rules.
- **Backend impact:** None (no session doc).
- **Dependency:** AUD-018, AUD-024, AUD-025
- **Recommended fix:** Product: gate attendance on schedule **or** persist sessions. Do not leave eval and attendance on different fallbacks.
- **Verification method:** Admin-created empty-schedule halaqa → open `/teacher/attendance/{id}` → save register.
- **Status:** Open

#### AUD-095

- **Priority:** P1
- **Role:** Teacher / Parent / Student
- **Feature:** Live evaluation notifications
- **Screen/File:** `upsert_teacher_evaluation_usecase.dart` (no `AcademyEventSink`); contrast `UpdateRecitationReviewUseCase` → `HomeworkReviewed`
- **Category:** Notifications
- **Current behavior:** Live session eval upserts `recitationRecords` with `reviewStatus: reviewed` and **does not** publish an academy event. Homework pending→reviewed **does**.
- **Expected behavior:** If evaluation is a parent-visible academy fact, it should enter the same sink after commit.
- **Root cause:** Two write paths; only homework review is on W5.
- **Source of truth:** recitationRecords (eval exists); notifications (missing for live eval)
- **Data impact:** Parent/student inbox silent after in-class grading.
- **UI impact:** Evaluations pages still show the record if they query recitationRecords.
- **Permission impact:** N/A
- **Backend impact:** New event kind or reuse `HomeworkReviewed` (product: do not overload meaning).
- **Dependency:** AUD-014, AUD-025
- **Recommended fix:** Publish after live upsert **or** document live eval as non-notified.
- **Verification method:** Save live eval; query `notifications` for parent uid.
- **Status:** Open

#### AUD-096

- **Priority:** P1
- **Role:** Student / Parent / Teacher / Supervisor
- **Feature:** Meaning of `overallProgressPercent`
- **Screen/File:** `student_profile_entity.dart` comment: **current surah only** `(memorized ayahs / surah total) × 100`. `StudentProgressWidget` / teacher / supervisor treat it as **overall حفظ**. Achievements / progress report label it **دقة الحفظ**.
- **Category:** Quran / Progress
- **Current behavior:** One stored field, three claimed meanings. No writer from خطة الحفظ (“لاحقاً”).
- **Expected behavior:** One definition, matching UI copy, with a writer.
- **Root cause:** Denormalized field reused; plan system missing.
- **Source of truth:** **None live** — stale field + contradictory comments.
- **Data impact:** Cross-role dashboards incomparable.
- **UI impact:** Donut / bars / “accuracy” all bind the same int.
- **Permission impact:** N/A
- **Backend impact:** Define Quran-scope math before any projector.
- **Dependency:** AUD-020, AUD-039, AUD-097
- **Recommended fix:** Product decision on surah vs Quran vs accuracy; then rename UI or split fields.
- **Verification method:** Read entity comment vs widget copy vs stored value after an eval (unchanged).
- **Status:** Open — contradiction, not resolved

#### AUD-097

- **Priority:** P1
- **Role:** Teacher
- **Feature:** Evaluation verse amounts
- **Screen/File:** `upsert_teacher_evaluation_usecase.dart` — `versesRange: ''` with comment “unused — never collect or validate in UI”
- **Category:** Quran / Progress
- **Current behavior:** Live evals store grades/notes but **empty** verse ranges. Parent weekly “verses” therefore can only count **documents** (AUD-022). No ayah/juz aggregator is possible from live eval SSOT.
- **Expected behavior:** If progress is verses/pages/juz, evals must capture ranges or another writer must.
- **Root cause:** Explicit product comment on unused field — still displayed as verse metrics elsewhere.
- **Source of truth:** grades on recitationRecords; amounts **missing**
- **Data impact:** Cannot derive memorized amount from session evals.
- **UI impact:** Metrics that claim آيات are disconnected from eval writes.
- **Permission impact:** N/A
- **Backend impact:** Collect range **or** stop showing verse totals.
- **Dependency:** AUD-020, AUD-022, AUD-096
- **Recommended fix:** Product: restore versesRange in UI **or** drop verse claims.
- **Verification method:** Save live eval; read `versesRange` on the doc.
- **Status:** Open (encoded decision vs displayed metrics)

#### AUD-098

- **Priority:** P1
- **Role:** Chat
- **Feature:** Relationship vs role on create
- **Screen/File:** `ChatPermissionPolicy.canChat` role pairs only; `GetOrCreateConversationUseCase`; student UI binds halaqa teacher but policy does not. Firestore create: any two `participantIds` including self, size ≤ 2.
- **Category:** Chat / Security
- **Current behavior:** A crafted client that knows UIDs can open Teacher↔any-student or Parent↔any-teacher 1:1 if roles match. Halaqa ownership and `childrenIds` are **not** checked at create.
- **Expected behavior:** Only academy relationships (own teacher, linked parent, assigned supervisor).
- **Root cause:** Defense in depth is role-level, not graph-level.
- **Source of truth:** Role strings on `users`.
- **Data impact:** Unrelated 1:1 threads.
- **UI impact:** Happy path looks scoped.
- **Permission impact:** Rules do not encode halaqa/parent-link.
- **Backend impact:** Callable or rules using roster/childrenIds.
- **Dependency:** AUD-001, AUD-015, AUD-027
- **Recommended fix:** Enforce relationship in use case **and** rules.
- **Verification method:** Student token GetOrCreate with a teacher from another halaqa.
- **Status:** Open

#### AUD-099

- **Priority:** P2
- **Role:** Admin
- **Feature:** Student account toggle
- **Screen/File:** `admin_students_tab.dart` shows نشط/موقوف badge. `ToggleAccountStatusEvent` is wired on **teachers** (`admin_teachers_page.dart`). No toggle dispatch found on the student tab.
- **Category:** Auth
- **Current behavior:** Admin can **see** student active flag; reactivation/suspend for students is not the same control as teachers. Reject-registration sets `isActive=false`. Login still honors the flag if set out of band.
- **Expected behavior:** If Admin manages student accounts, a real toggle (with reason) or hide the badge as read-only.
- **Root cause:** Directory UI vs teacher management UI divergence.
- **Source of truth:** `users.isActive`
- **Data impact:** Operators may think they can unsuspend a student from that tab.
- **UI impact:** Misleading badge.
- **Permission impact:** N/A
- **Backend impact:** Wire same use case or document read-only.
- **Dependency:** AUD-011, AUD-016
- **Recommended fix:** Wire toggle or caption «عرض فقط».
- **Verification method:** Tap student row for disable control.
- **Status:** Open

#### AUD-100

- **Priority:** P3
- **Role:** Supervisor
- **Feature:** `supervisorProfiles`
- **Screen/File:** `FirestoreCollections.supervisorProfiles`; `firestore.rules` match; **no Dart datasource read/write**
- **Category:** Data
- **Current behavior:** Collection is reserved and world-writable if rules deploy; app uses `users.role == supervisor` + `halaqat.supervisorId`.
- **Expected behavior:** Use it or remove from rules/constants.
- **Root cause:** Placeholder profile collection.
- **Source of truth:** `halaqat.supervisorId` / `users`
- **Data impact:** Orphan docs possible.
- **UI impact:** None
- **Permission impact:** Open write if rules live
- **Backend impact:** Align constants, rules, app
- **Dependency:** AUD-001
- **Recommended fix:** Quarantine collection or implement.
- **Verification method:** Grep datasources for `supervisorProfiles`.
- **Status:** Open

#### AUD-101

- **Priority:** P2
- **Role:** Teacher / Student
- **Feature:** Halaqa activity replies
- **Screen/File:** `halaqa_activity_remote_datasource_impl.dart` — read thread then merge-set `responseCount` / `respondentStudentIds` (not a transaction)
- **Category:** Concurrency
- **Current behavior:** Concurrent replies can lose count / roster entries.
- **Expected behavior:** `increment` / transaction / arrayUnion.
- **Root cause:** Read-modify-write.
- **Source of truth:** assignment activity doc (racy)
- **Data impact:** Under-count respondents.
- **UI impact:** Thread vs badge disagree.
- **Permission impact:** N/A
- **Backend impact:** Transaction
- **Dependency:** None
- **Recommended fix:** `FieldValue.increment` + `arrayUnion`.
- **Verification method:** Two students reply together.
- **Status:** Open

#### AUD-102

- **Priority:** P2
- **Role:** Parent / Teacher / Supervisor
- **Feature:** Excuse / استئذان copy
- **Screen/File:** Parent `طلبات الاستئذان`; Teacher `طلبات الاعتذار`; Supervisor `الاعتذارات`; domain `absenceRequests`
- **Category:** L10n
- **Current behavior:** Same W7 fact, three Arabic product names (+ English “excuses” in code).
- **Expected behavior:** One term in all role UIs.
- **Root cause:** Per-role Figma strings.
- **Source of truth:** `absenceRequests` collection
- **Data impact:** None
- **UI impact:** Cross-role support confusion
- **Permission impact:** N/A
- **Backend impact:** None
- **Dependency:** AUD-044
- **Recommended fix:** Glossary; one string key when l10n exists.
- **Verification method:** Compare the three screens.
- **Status:** Open

---

## Classification buckets (do not collapse)

### Confirmed existing behavior (not defects by themselves)

- Attendance SSOT `attendanceRecords` with deterministic `{sessionId}_{studentId}`.
- Evaluation identity `{sessionId}_{halaqaId}_{studentId}_{type}` via `EvaluationPolicy`.
- W4/W5 in-app events for absence + homework + halaqa activity.
- W7 استئذان contextual, not presence.
- W8 admit/transfer via `AcademyAdmissionFirestore`.
- Chat 1:1 for policy pairs; Admin internal group.
- Dark mode + font size preferences (partially applied).
- Proof upload path + Supervisor approve/reject/partial **given an existing payment doc**.
- Admin `isActive` toggle for **teachers**; student flag is **displayed** (AUD-099).

### Confirmed product decisions (prior docs, still true unless noted)

- Audio uploads flag false.
- FCM deferred (H3).
- Family link out of W8.
- Unenroll out of W8.
- H6 removed teacher posts tab / some orphan routes.
- Session identity `{halaqaId}_yyyyMMdd` for operations.
- Late counts as attended.
- Admin may read all conversations (implemented; privacy still flagged).

### Missing contracts (still absent in freeze code — now **specified** by locks)

AUD-009, 010, 011, 012, 014, 015, 016, 017, 024, 027, 029 (FCM — D19), 030, 037, 040, 053 (media — D20), 096, 097. Product meaning is locked; writers/schemas may still be Schema/Infrastructure TBD. EN locale / dark theme program are **OUT** (D15). Fee catalog → D3 pricing rules. Suspension → D5 payment-access policy (≠ `isActive` only).

### Actual defects

AUD-001–008, 018–023, 025 (if product required gating), 026, 028, 032–036, 038–039, 043–049, 056–058, 063–065, 068, 094–098, 101, plus stale inventories.

### UX inconsistencies

AUD-041, 042, 049, 051, 082–084, 093.

### Security / privacy

AUD-001–008, 003, 028, 036, 054, 062, 069, 098.

### Scalability

AUD-026, 028, 034, 065, 078, client aggregations, unbounded Admin/Chat listeners.

### Questions requiring product/backend decisions

**RESOLVED.** See `PRODUCT_DECISIONS_LOCKED.md` (D1–D24) and `IMPLEMENTATION_PLAN.md` (Wave 0 complete). Historical open questions in `FULL_PRODUCT_AUDIT.md` §8 are mapped to locks. Remaining items are Engineering / Schema / Infrastructure TBD only — not open product choices.
)
