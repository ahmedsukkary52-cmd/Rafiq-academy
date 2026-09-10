# Implementation Plan

**Phase:** Contract & Dependency Planning — **Wave 0 COMPLETE**  
**Not in scope yet:** source changes, rules deploys, commits, pushes, branch moves, worktree changes.

**Authoritative product locks:** `docs/production/PRODUCT_DECISIONS_LOCKED.md` (D1–D24)  
**Security specification (Wave A prerequisite):** `docs/production/SECURITY_IMPLEMENTATION_SPEC.md`  
**Security/data contract freeze:** `docs/production/SECURITY_DATA_CONTRACT_FREEZE.md`  
**Wave A blueprint:** `docs/production/WAVE_A_IMPLEMENTATION_SPEC.md`  
**WA-0→WA-2 batch status:** `docs/production/WAVE_A_BATCH_WA0_WA2_STATUS.md`  
**Billing gate:** `docs/production/FIREBASE_BILLING_CHECKLIST.md` (D19 / D20 / Functions)

---

## 1. Purpose

This is the master implementation roadmap for Rafiq Academy after the read-only full product audit **and** the Product Decision Lock.

It maps **AUD-001 → AUD-102** onto a **dependency-aware** sequence. Wave 0 decisions are **LOCKED**. Implementation units that previously said “Blocked pending Wave 0” are now **Planned** against those locks. Remaining unknowns are labeled **Engineering TBD**, **Schema TBD**, or **Infrastructure TBD** — not silent inventions.

**Implementation may start only after** this locked plan is accepted. First engineering wave is **Wave A** (security), not reopening D1–D24.

---

## 2. Source of Truth

| Artifact | Role |
|----------|------|
| Frozen integration commit `69e4207801b17fc5dede30d82b07d4a48a6a1c92` on `feature/full-product-audit` | **Code baseline** (what exists today) |
| Worktree `D:/flutter projects/rafiq_academy-full-audit` | Inspected freeze tree (untouched) |
| `PRODUCT_DECISIONS_LOCKED.md` | **Authoritative product contracts** (what to build) |
| `FIREBASE_BILLING_CHECKLIST.md` | Paid-services gate before Blaze / academy migrate |
| `MASTER_ISSUE_MATRIX.md` | AUD records (historical findings; freeze evidence) |
| `FULL_PRODUCT_AUDIT.md` | Product verdict; §8 questions **resolved by locks** |
| Other `docs/production/*_AUDIT.md` | Contracts / authz / UI / scale evidence |
| Prior W1–W8 / H1–H8 / ADR docs | Historical; **locks + freeze win** on conflict |

Where freeze code contradicts a locked decision, the freeze is a **defect to fix**, not a product choice.

---

## 3. Repository / Worktree Map

Inspected **without** creating, deleting, detaching, or checking out branches owned by other worktrees.

### Live worktrees

| Worktree | HEAD | Branch | Relation to freeze `69e4207` |
|----------|------|--------|------------------------------|
| `D:/flutter projects/rafiq_academy` | `29db7ee` | `feature/parent-interface` | Ancestor of freeze. Planning docs live here. |
| `D:/flutter projects/rafiq_academy-full-audit` | `69e4207` | `feature/full-product-audit` | **Frozen integration baseline.** |
| `D:/flutter projects/rafiq_academy-admin-agent3-home` | `2c75b04` | `feature/admin-agent3-home` | Ancestor of freeze. |
| `D:/flutter projects/rafiq_academy-teacher` | `82fecf1` | `feature/teacher-production-pass` | Ancestor of freeze. |
| `D:/flutter projects/rafiq_academy-student` | `9470d6e` | `feature/student-production-pass` | Ancestor of freeze. Local dirty student UI ≠ freeze. |
| `D:/flutter projects/rafiq_academy-supervisor-agent3-roster` | `70362e0` | `feature/supervisor-agent3-roster` | Not ancestor; one commit ahead (roster refresh) — re-inspect before U-MEM. |

**Do not implement against older per-role worktrees.** Implement against a branch derived from the freeze (or the freeze worktree) once coding starts.

---

## 4. Current Baseline

**Commit:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**App shape:** Flutter, `go_router`, injectable/`GetIt`, per-role **Bloc** singletons, Firebase Auth + Firestore + Storage. Paymob functions exist in repo but are **OUT** per D2 (quarantine). Wallet paid path exists but is **OUT** per D2.

**Freeze vs locks (selected gaps to close):**

| Lock | Freeze today |
|------|----------------|
| D1 No public register | Public `/register` creates active student |
| D2 Vodafone+proof only | Wallet can mark paid; Paymob leftovers |
| D3 Auto invoices | No invoice issuer |
| D4 Stored overdue job | No overdue writer |
| D5 Payment access policy | Only `users.isActive` kill switch |
| D6 Vodafone in academySettings | `transferDestination = ''` |
| D7 Eval needs Session+Present/Late | Eval independent of attendance; synthetic day ids |
| D8 Schedule required | Create halaqa with `schedule: []` |
| D9 Per-slot sessions + conflicts | Same-day slots collapse; no sessions collection |
| D10 First-class sessions | Inferred `{halaqaId}_yyyyMMdd` |
| D11 Memorization ≠ accuracy ≠ revision | Stale %; empty `versesRange`; mislabeled accuracy |
| D12 childrenIds via W8 / Admin | No writer; Parent cannot link |
| D13 Admin monitor intentional | watchAll exists; UI not sectioned as required |
| D14 1:1 + Halaqa group + relationship rules | Role-pair only; groups rules-forbidden except admin_internal |
| D15 AR/RTL only; no theme program | Dead language row; dark theme code exists but **out of product scope** |
| D16 Phone Admin-only | Any signed-in can read `users.phone` |
| D17 Live eval notify | No AcademyEvent on live eval |
| D18 Profile-centric Admin student actions | Roster badge without toggle; actions not centralized |
| D19 FCM in scope | In-app only (H3 deferred) — **overridden by D19** |
| D20 Chat media/edit/delete | Text only; message update/delete false |
| D21 No-Halaqa ≠ suspend ≠ archive | Transfer only; no explicit no-Halaqa UX |
| D22 No idle timeout | Matches freeze (keep) |
| D23 Al-Fatihah + last-read + mushaf redesign | Default surah 67; no last-read product |
| D24 supervisorProfiles legacy | Declared unused — quarantine, not SSOT |

**Critical ops constraint:** `firebase.json` deploys **indexes only**. Wire rules only **after** U-SEC-RULES tightness (AUD-006).

---

## 5. Issue Classification Summary

Primary classes unchanged in spirit; Wave 0 **Product Decision Required** items are now **Locked → Planned** for implementation.

| Classification | Meaning after Wave 0 |
|----------------|----------------------|
| Confirmed Bug | Freeze contradicts **locked** contract or leaks data |
| Missing Contract | Writer/SSOT still absent — implement per lock (may still have Schema TBD) |
| Locked Decision | D1–D24 recorded; no longer open product questions |
| Architecture/Infrastructure | Rules, indexes, Functions, FCM, billing checklist |
| Low Priority | Polish / hygiene within AR/RTL scope |
| Duplicate/Already Covered | Same underlying fix as driver AUD |
| Accepted / Out of release | D15 theme-switch & EN/LTR; AUD-060 audio uploads remain gated; AUD-081 posts removed |

Duplicates (implement once):

| Driver | Also covers |
|--------|-------------|
| AUD-001 | AUD-036 |
| AUD-003 | AUD-069 |
| AUD-004 | AUD-008 |
| AUD-023 | AUD-090 |
| AUD-044 | AUD-075, AUD-079, AUD-087 — resolve as **AR-only / hide fake language**, not EN ARB |
| AUD-046 | AUD-068, AUD-084 — **do not** run a dark-mode program (D15); fix only if light AR UI breaks |
| AUD-050 | AUD-051 |

**H3 / AUD-029 override:** Prior docs deferred FCM. **D19 locks FCM IN SCOPE.** Treat H3 “in-app only” as **stale** relative to the lock.

---

## 6. Dependency Graph

### 6.1 Core academy chain (locked)

```
Admin-provisioned Auth (D1)
  → Membership / W8 (D12) + childrenIds result
    → Halaqa with ≥1 schedule slot (D8)
      → Schedule slots
        → First-class sessions/{sessionId} per slot (D9, D10)
          → Attendance on session
            → Evaluation only if Present/Late (D7) + type + versesRange (D11)
              → Memorization / revision projectors (D11)
              → Live-eval notification (D17) + FCM (D19)
```

### 6.2 Payment chain (locked)

```
Admin pricing rules (D3)
  → Backend invoice generator (snapshot amount)
    → Vodafone destination from academySettings (D6)
      → Parent external pay + proof upload (D2)
        → pending_review → authorized review → paid/partial/rejected
          → Stored overdue via scheduled job (D4)
            → Reminders / warning / grace → payment access suspension (D5)
              → Admin reinstatement (D5, D18 profile actions)
```

Wallet and Paymob are **removed from the product path** (D2), not alternative rails.

### 6.3 Chat chain (locked)

```
Relationship graph (D12) + halaqa roster
  → Server-side 1:1 create/send (D14)
  → Halaqa Group (Teacher+Supervisor+Students) (D14)
  → Media / edit / delete with Storage rules (D20)
  → Admin monitoring overlay (D13) — intentional, separate UI sections
  → Optional chat notifications (Engineering TBD) + FCM (D19)
```

### 6.4 Access-state separation (D5 ≠ D21)

```
users.isActive (login kill switch / Admin disable)
  ≠ payment access suspension (D5)
  ≠ temporary no-Halaqa (D21)
  ≠ archive/deactivation (D21)
```

### 6.5 Progress ≠ reading (D11 ≠ D23)

```
Memorization %  ≠  Revision progress  ≠  Accuracy  ≠  Mushaf last-read
```

### 6.6 Shared infrastructure

```
Security rules (tight) → firebase.json
  → Data contracts / sessions / indexes
    → Billing checklist verified → Blaze / Functions / FCM / Storage media
      → Shared AR/RTL chrome & states (D15: no EN, no theme program)
        → Tests → Production QA
```

### 6.7 Must not build out of order

| If you build this first… | You will redo it when… |
|--------------------------|------------------------|
| Progress UI | Memorization vs revision vs accuracy fields (D11) |
| Attendance/eval on synthetic day ids | `sessions` SSOT (D10) |
| Wallet / Paymob UX | Quarantined by D2 |
| Open rules deploy | U-SEC-RULES |
| Chat without childrenIds/roster | D12 + D14 server checks |
| FCM before billing checklist | D19 infra gate |
| EN strings / dark theme system | Out of release (D15) |

---

## 7. Product Decisions — LOCKED (Wave 0 Complete)

Full text: `PRODUCT_DECISIONS_LOCKED.md`. Summary:

| ID | Lock (short) | Primary AUDs unblocked |
|----|--------------|------------------------|
| D1 | No public register; Admin-controlled provisioning | 005, 016 |
| D2 | Vodafone+proof only; Paymob OUT; Wallet OUT | 007, 013, 035 |
| D3 | Admin pricing; backend auto-invoices; amount snapshot | 009, 037, 080 |
| D4 | Overdue **stored**; scheduled job | 010, 034 |
| D5 | Payment-specific access policy; Pay Now + Contact Admin only; Admin reinstate | 011, 014 (reminders) |
| D6 | Vodafone destination in `academySettings` | 012 |
| D7 | Eval requires Session + Present/Late | 025 |
| D8 | ≥1 schedule slot on create | 018, 094 |
| D9 | One Session per slot; backend conflict validation (Teacher/Student/Halaqa; Supervisor OK) | 056 |
| D10 | Persist `sessions/{sessionId}` | 024, 057, 030 |
| D11 | Memorization %; typed evals; real versesRange; accuracy separate | 020–023, 039, 096, 097 |
| D12 | Parent Add-Student request; Admin assigns; childrenIds via W8; Parent cannot write | 015 |
| D13 | Admin monitors all chats; sectioned UI | 028, 054 |
| D14 | 1:1 + Halaqa groups; server-side relationship authz | 027, 098 |
| D15 | Arabic+RTL only; no EN/LTR; no dark/light program | 043–045, 075, 079, 087 |
| D16 | `users.phone` Admin-only (rules) | 003, 069 |
| D17 | Live eval → event → Parent notify + open | 095 |
| D18 | Roster status; actions on Student Profile | 099 |
| D19 | FCM IN SCOPE; billing checklist first | 029 |
| D20 | Text/image/voice + edit/delete; Storage rules; delete semantics TBD | 053, 077 |
| D21 | No-Halaqa temporary; archive ≠ payment suspend; no hard-delete | 040 |
| D22 | No app idle timeout | 070 |
| D23 | Al-Fatihah default; last-read; major mushaf redesign (2 modes) | 059 |
| D24 | `supervisorProfiles` legacy — quarantine, not SSOT | 100 |

**Still not inventable (TBD labels only):**

- **Engineering TBD:** Admin Auth createUser mechanism (D1); conflict engine (D9); mushaf two modes (D23); chat soft-delete (D20); FCM send pipeline shape.
- **Schema TBD:** payment-access fields (D5); pricing rules docs (D3); full `sessions` fields (D10); status enum for roster (D18); last-read doc (D23); Halaqa group conversation id (D14).
- **Infrastructure TBD:** invoice/overdue schedulers; Blaze enablement after billing checklist; Storage path layout for chat media; token collection for FCM.
- **Policy TBD:** data-retention for archive / chat delete (D20, D21).

**Safe engineering default:** Do not deploy current open rules. Tight rules first, then AUD-006.

---

## 8. Implementation Waves

| Wave | Name | Goal | Gate |
|------|------|------|------|
| **0** | Contract & Decision Lock | D1–D24 recorded | **COMPLETE** |
| **A** | Security / Authorization | Rules + identity + phone + paid-field lock | Locks D1,D2,D13,D14,D16,D24 |
| **B** | Halaqa / Schedule / Session / Attendance / Evaluation | Operable day on real sessions | D7–D10,D12,D18,D21 |
| **C** | Progress / Reports / Quran Metrics | Memorization vs revision vs accuracy | D11; Wave B eval |
| **D** | Payments | Vodafone rail; invoices; overdue; D5 access | D2–D6; Wave A payment rules |
| **E** | Notifications | Live eval + payment events + **FCM** | D17,D19; billing checklist; Waves B/D |
| **F** | Chat | Relationship 1:1 + Halaqa groups + media | D12–D14,D20; Storage rules; billing |
| **G** | Shared UI / States (AR/RTL) | Chrome, empty/error, terminology; **no EN/theme program** | D15 |
| **H** | Firebase Scalability / Infrastructure | Indexes, races, Functions, billing verification | Billing checklist; D19/D20 |
| **I** | Cross-interface QA / Hardening | Emulator + shells + lifecycle | A–H for in-scope |

Wave G may parallel B–F for AR/RTL chrome/states only. Wave H indexes (032/033) may start immediately. **Do not** enable Blaze until billing checklist verification.

---

## 9. Implementation Units

### U0 — Product Decision Lock

| | |
|--|--|
| **Status** | **COMPLETE** — see `PRODUCT_DECISIONS_LOCKED.md` |
| **AUD IDs** | All formerly blocked product AUDs now unlocked for planning |
| **Acceptance** | D1–D24 represented; coverage Status → Planned / Accepted |

---

### U-SEC-RULES — Firestore + Storage ownership + deploy wiring

| | |
|--|--|
| **AUD IDs** | 001, 002, 004, 006, 008, 035, 036, 100 |
| **Prerequisites** | U0 complete. Never deploy today’s open rules as production. |
| **Locked inputs** | D1, D2, D13, D14, D16, D24 |
| **Modules** | `firestore.rules`, `storage.rules`, `firebase.json` |
| **Data contract** | Freeze `users.role`; phone read Admin-only; `payments.status`/review locked; quarantine `wallets` (D2 OUT); quarantine `supervisorProfiles` (D24); conversation create relationship + Admin monitor read; Halaqa group size exception (D14) |
| **Tests** | Rules emulator: non-Admin cannot read phones; cannot set paid; cannot escalate role; Parent cannot write childrenIds; Storage catch-all closed |
| **Acceptance** | Signed-in ≠ academy-wide RW; `firebase.json` wires rules only after tightness |
| **Infra** | Rules then firebase.json |

---

### U-SEC-IDENTITY — Admin provisioning, close public register, phones, App Check

| | |
|--|--|
| **AUD IDs** | 005, 003, 016, 017, 062, 069, 070 |
| **Prerequisites** | U-SEC-RULES phone/role locks; D1, D16, D22 |
| **Modules** | Remove/disable public register path; Admin-controlled provisioning (**Engineering TBD** mechanism); password reset; App Check |
| **Acceptance** | No public self-signup; phones Admin-only in rules + UI; no idle timeout (D22) |
| **Infra** | Possible callable createUser; App Check; billing if Functions |

---

### U-MEM — Membership, childrenIds, no-Halaqa, archive, Admin Student Profile

| | |
|--|--|
| **AUD IDs** | 015, 040, 099 |
| **Prerequisites** | D12, D18, D21; U-SEC-RULES |
| **Modules** | W8 admission; Parent Add-Student **request**; Admin assign; Supervisor limited link; Admin Student Profile actions (not roster overload); no-Halaqa UX; archive workflow |
| **Data contract** | `childrenIds` written only by authorized admission/assignment — **not** Parent. Separate fields for payment suspension (D5) vs no-Halaqa vs archive (**Schema TBD**) |
| **Acceptance** | Parent cannot write childrenIds; Student Profile hosts suspend/reactivate/transfer/etc.; no-Halaqa message distinct from payment suspend |
| **Search** | studentId + full name + Halaqa (+ contextual non-phone field); Arabic normalization (**Engineering TBD**) |

---

### U-HALAQA — Schedule-required create, assignStaff, inactive gate, conflicts

| | |
|--|--|
| **AUD IDs** | 018, 019, 038 (+ conflict side of 056) |
| **Prerequisites** | D8, D9; staff identities (D1) |
| **Modules** | `AcademyHalaqaFirestore`; Admin create UI with ≥1 slot; assignStaff dual-write; backend conflict validation |
| **Acceptance** | Cannot create production Halaqa without schedule; Teacher/Student/Halaqa conflicts blocked server-side; Supervisor overlap allowed |
| **Infra** | Conflict validation backend (**Engineering TBD**) |

---

### U-SESSION — First-class sessions, attendance, evaluation gate, versesRange

| | |
|--|--|
| **AUD IDs** | 024, 025, 056, 057, 094, 097 |
| **Prerequisites** | D7–D10; U-HALAQA |
| **Modules** | New `sessions` collection; materialize per slot; AttendanceService; EvaluationService; UpsertTeacherEvaluation |
| **Data contract** | `sessions/{sessionId}` SSOT; attendance/eval reference sessionId; eval blocked unless Present/Late; every eval typed memorization|revision + real `versesRange` |
| **Migration** | Dual-read synthetic day ids → sessions (**Migration TBD**) |
| **Acceptance** | No production reliance on synthetic day SSOT; absent students not evaluable |

---

### U-PROGRESS — Memorization / revision / accuracy / reports

| | |
|--|--|
| **AUD IDs** | 020–023, 039, 088, 089, 090, 096, 097 |
| **Prerequisites** | D11; U-SESSION |
| **Modules** | Projectors; Parent weekly; Admin stats; remove accuracy misuse of overallProgressPercent |
| **Acceptance** | overallProgressPercent = memorization only; revision separate; accuracy = quality; mushaf last-read not mixed in |
| **Infra** | Prefer write-on-commit projector |

---

### U-PAY-RAIL — Vodafone only; quarantine wallet/Paymob; academySettings destination

| | |
|--|--|
| **AUD IDs** | 007, 012, 013, 035 |
| **Prerequisites** | D2, D6 |
| **Modules** | Remove/hide wallet paid CTA; quarantine Paymob functions/client; Parent reads Vodafone from `academySettings`; Admin edits destination |
| **Acceptance** | Only Vodafone+proof path; no client `status=paid`; no invented destination number |
| **Infra** | Disable deployed Paymob if present |

---

### U-PAY-LIFECYCLE — Pricing, invoices, proof/review, overdue job, D5 access

| | |
|--|--|
| **AUD IDs** | 009–011, 014 (handoff E), 033, 034, 037, 063, 064, 080 |
| **Prerequisites** | D3–D5; U-SEC-RULES; U-PAY-RAIL; U-MEM for child linkage |
| **Modules** | Admin pricing rules; backend invoice generator (snapshot); proof; authorized review; overdue scheduler; payment-access suspension UX (Pay Now + Contact Admin only); Admin reinstate on Student/Parent profile flows |
| **Acceptance** | Parent completes Vodafone story without seed invoices; overdue stored by job; D5 ≠ `isActive` overload |
| **Infra** | Scheduled Functions; index parentId+dueDate; **no** full-collection Admin get |
| **Schema TBD** | Partial/remainder policy details if product keeps partial |

---

### U-NOTIF — Live eval, payment events, FCM

| | |
|--|--|
| **AUD IDs** | 014, 029, 030, 031, 067, 078, 095 |
| **Prerequisites** | D17, D19; billing checklist before Blaze; sessions (D10) for session-linked notifies |
| **Modules** | AcademyEvent on live eval; payment reminders; FCM token registration + send path; broadcast read model |
| **Acceptance** | Parent receives real live-eval notification and can open evaluation; FCM not in-app-only |
| **Infra** | FCM + Functions; see billing checklist |

---

### U-CHAT-AUTHZ — Relationship 1:1, Halaqa groups, Admin monitor UI

| | |
|--|--|
| **AUD IDs** | 098, 054, 055, 058, 092, 027 (group create) |
| **Prerequisites** | D12–D14; U-MEM; U-HALAQA; U-SEC-RULES |
| **Modules** | ChatPermissionPolicy → relationship checks; GetOrCreate; Halaqa group ensure; Admin inbox sections (My / Monitored / roles / Halaqa Groups) |
| **Acceptance** | Server rejects arbitrary role-pair chats; Halaqa group = Teacher+Supervisor+Students; Admin monitor intentional and labeled |
| **Connection** | D12 childrenIds/roster feeds D14; D13 overlay does not replace D14 |

---

### U-CHAT-MEDIA — Pagination, media, edit/delete

| | |
|--|--|
| **AUD IDs** | 026, 028, 053, 077 |
| **Prerequisites** | D20; U-CHAT-AUTHZ; Storage rules; billing checklist |
| **Modules** | Message pagination; image/voice upload; edit/delete with **delete semantics TBD** (prefer soft-delete) |
| **Acceptance** | No unbounded history download; media authorized by conversation membership |
| **Infra** | Storage paths (**Infrastructure TBD**) |

---

### U-UI-SYSTEM — Shared chrome / states (AR/RTL; no theme program)

| | |
|--|--|
| **AUD IDs** | 041, 042, 048, 049, 052, 076, 082, 083 (+ 046/047/068/084 only if light UI broken) |
| **Prerequisites** | D15 — **no** dark/light feature work; **no** EN |
| **Modules** | Shared scaffolds/nav/states; Parent routing cleanup; force RTL consistently |
| **Acceptance** | Consistent Arabic RTL chrome; loading/empty/error; do not implement theme switcher |

---

### U-UI-L10N — Arabic-only cleanup + terminology

| | |
|--|--|
| **AUD IDs** | 043, 044, 045, 075, 079, 087, 093, 102 |
| **Prerequisites** | D15 |
| **Modules** | Remove/hide language row; keep AR strings; unify استئذان terminology (AUD-102); calendar `ar` |
| **Acceptance** | No fake language switching; no EN ARB project this release |

---

### U-MUSHAF — Al-Fatihah, last-read, two polished modes

| | |
|--|--|
| **AUD IDs** | 059 (+ related student mushaf UX) |
| **Prerequisites** | D23; distinct from U-PROGRESS (D11) |
| **Modules** | Default Al-Fatihah; per-student last-read; substantial redesign with **two** visual modes |
| **Acceptance** | Reading position ≠ memorization %; major UX bar met |
| **Schema TBD** | last-read persistence |

---

### U-FB-INDEX — Missing indexes

| | |
|--|--|
| **AUD IDs** | 032, 033 (+ sessions indexes when schema known) |
| **Prerequisites** | None for existing queries; sessions indexes after Schema TBD |
| **Infra** | `firestore.indexes.json` only |

---

### U-FB-SCALE — Listeners, aggregates, races, billing verification

| | |
|--|--|
| **AUD IDs** | 026/028/034 overlap, 065, 078, 101 |
| **Prerequisites** | Query shapes from D/E/F; **FIREBASE_BILLING_CHECKLIST** verified before Blaze |
| **Modules** | Pagination; activity `responseCount` transaction; awards windows; Functions schedulers |
| **Acceptance** | Correctness races fixed; scale acceptable for target; billing checklist filled |

---

### U-HYGIENE — CI, leftovers, quarantine Paymob/wallet/supervisorProfiles

| | |
|--|--|
| **AUD IDs** | 050, 051, 060, 061, 081, 085, 086, 091, 100 |
| **Prerequisites** | D2, D24; AUD-060 remains gated uploads |
| **Acceptance** | Paymob/wallet not on product path; supervisorProfiles not SSOT; CI exists; debug logs off in release |

---

### U-QA — Tests and hardening

| | |
|--|--|
| **AUD IDs** | 071–074 |
| **Prerequisites** | Owning waves |
| **Tests** | Rules; payment lifecycle; progress math; role shells; session+eval gate; chat relationship; FCM send smoke (infra permitting) |

---

## 10. Cross-Interface Coordination Matrix

| Shared contract | Move together | Must not solo |
|-----------------|---------------|---------------|
| Admin Auth provision (D1) | Admin UI + Auth + rules | Public `/register` leftover |
| childrenIds / W8 (D12) | Admin, Supervisor, Parent, Teacher roster, **chat D14** | Parent direct write |
| Schedule + sessions (D8–D10) | Admin create, Teacher day, Student week, Supervisor board | Synthetic day-only attendance |
| Eval gate + versesRange (D7, D11) | Teacher, Student, Parent, progress | Independent eval create |
| Memorization vs revision vs accuracy | All progress UIs | Mushaf last-read (D23) |
| Vodafone + invoices + overdue + D5 | Parent, Supervisor review, Admin finance/profile reinstate | Wallet/Paymob |
| Chat relationship + Halaqa group | All five roles + rules | Role-pair UI only |
| Admin monitor (D13) | Admin inbox sections | Using bubble color as authz |
| Payment suspend vs no-Halaqa vs archive | Parent shell, Student shell, Admin profile | Overloading `isActive` |
| Phone Admin-only (D16) | Rules + all directories | Teacher profile phone |

---

## 11. Security Implementation Plan

### UI-only today (must become backend)

| Control | Today | Locked target |
|---------|-------|---------------|
| Register role | Page hardcodes student | No public register (D1) |
| Phone | Open read | Admin-only (D16) |
| Payment paid | Open write | Reviewer/backend only (D2) |
| childrenIds | Open write | Admission workflow only (D12) |
| Chat create | Role-pair client | Relationship server-side (D14) |
| Admin chat | watchAll | Allowed (D13) but labeled UI + rules |
| Eval without attendance | Allowed | Present/Late + session (D7) |

### Must fix before production (Wave A+)

- Ownership rules (AUD-001/002)
- Paid-field lock (AUD-004/008)
- Phone ACL (AUD-003)
- Close public register (AUD-005)
- Quarantine wallets (AUD-035) / Paymob (AUD-013)
- Conversation create relationship + Halaqa group exception (AUD-098/027)
- Wire firebase.json after tightness (AUD-006)

---

## 12. Firebase / Scalability Plan

| Item | Action |
|------|--------|
| Chat unbounded / Admin watch | Paginate; Admin monitor stays (D13) with query windows |
| Full payments get | Replace with scoped queries + aggregates |
| `studentIds` arrays | Acceptable for hundreds; plan split before thousands |
| Broadcast `readBy` | Per-observer or capped model |
| Activity responseCount | Transaction / increment (AUD-101) |
| Sessions collection | New indexes (**Schema TBD**) |
| FCM + Functions + Storage media | Billing checklist before Blaze |
| Paymob functions | Quarantine/remove (D2) |
| Overdue / invoice / reminders | Scheduled Functions (D3–D5) |
| Conflict validation | Backend (D9) |

---

## 13. Test Strategy

Keep **Bloc** + Clean Architecture (freeze is Bloc).

| Kind | Examples |
|------|----------|
| Unit | Session materialization; eval Present/Late gate; memorization projector; Chat relationship; payment access state machine; conflict rules |
| Widget | AR/RTL shells; Parent suspended shell (Pay Now / Contact Admin only); no-Halaqa student message; Admin Student Profile; mushaf modes |
| Integration | Admin provision → W8 link → Teacher session → attendance → eval → notify Parent; invoice → proof → review → overdue → D5 suspend → reinstate |
| Rules emulator | Phone, paid, childrenIds, chat create, Admin monitor read |
| Concurrency | Slot conflict (D9); payment review vs resubmit; activity count |
| Infra | FCM send smoke after billing gate |

Course PR bar unchanged: screenshots, Jira, size limits, checklist, approval.

---

## 14. Migration / Backward Compatibility

| Change | Strategy |
|--------|----------|
| Public register removal | Disable route; migrate demo users via Admin/seed |
| Sessions SSOT | Dual-read synthetic ids; backfill (**Migration TBD**) |
| Schedule required | Backfill empty-schedule halaqat before enforcing |
| Wallet/Paymob paid history | Leave historical; stop new false paid |
| Progress fields | Recompute memorization from typed evals + versesRange |
| childrenIds | Populate via W8/Admin assign; Parent request queue |
| Chat grandfather | Relationship-invalid 1:1: freeze vs migrate (**Engineering TBD**) |
| supervisorProfiles | Quarantine; dependency search before delete (D24) |
| Theme/language code | Hide dead controls; do not build EN/dark programs (D15) |
| Mushaf default 67 → Al-Fatihah | Change default; add last-read |

---

## 15. Regression Risk Matrix

| Area | Risk | Mitigation |
|------|------|------------|
| Rules tighten | Permission-denied | Emulator matrix |
| Close register | Demo signup broken | Admin provision path first |
| Sessions migration | Orphan attendance/eval | Dual-read period |
| Eval gate | Teachers blocked mid-day | Require attendance UX clarity |
| D5 access fields | Confused with isActive / no-Halaqa | Explicit state machine + tests |
| Remove wallet | Parent tab crash | Hide CTA; keep history read if needed |
| Halaqa groups | Roster churn membership | Sync on admit/transfer/archive |
| FCM | Cost / spam | Billing checklist; audience caps |
| Chat delete | History loss | Soft-delete contract before hard delete |
| Mushaf redesign | Scope creep | Treat as dedicated U-MUSHAF; not polish |

---

## 16. Recommended Execution Order

1. **U0** — complete (locks recorded).
2. **U-FB-INDEX** (032/033) early.
3. **FIREBASE_BILLING_CHECKLIST** verification (before Functions/FCM/Blaze).
4. **U-SEC-RULES** → **U-SEC-IDENTITY**.
5. **U-HALAQA** + **U-MEM** (incl. D18 Student Profile).
6. **U-SESSION** (sessions + D7/D9/D10).
7. **U-PROGRESS** + start **U-MUSHAF** (parallel OK; keep D11≠D23).
8. **U-PAY-RAIL** → **U-PAY-LIFECYCLE** (D5).
9. **U-NOTIF** (D17 + D19 FCM).
10. **U-CHAT-AUTHZ** → **U-CHAT-MEDIA**.
11. **U-UI-SYSTEM** / **U-UI-L10N** (AR/RTL only) parallel from step 5.
12. **U-FB-SCALE** + **U-HYGIENE**.
13. **U-QA** / Wave I.

---

## 17. Definition of Done

A unit is done when:

1. Behavior matches `PRODUCT_DECISIONS_LOCKED.md` for its D-ids.
2. Client and **rules** agree (no UI-only security).
3. Schema/Engineering/Infrastructure TBDs for that unit are either resolved in the PR or explicitly deferred with owner.
4. Tests listed for the unit are green.
5. Cross-interface matrix rows re-checked.
6. No P0 open (open rules, false paid, role self-escalation, public register).
7. If unit needs Functions/FCM/Storage media: billing checklist row verified.

Production bar: Waves A, B (sessions), D (if commercial), E (FCM for required notifies), F (authz), I.

---

## 18. Final PR / Release Checklist

- [ ] Implements listed AUD IDs / one unit; matches locked D-ids
- [ ] No drive-by refactors; no EN/theme program (D15)
- [ ] Jira + screenshots (affected roles; 320-width if layout)
- [ ] Unit / widget / rules tests as applicable
- [ ] Indexes updated if queries changed
- [ ] `firebase.json` not wiring **open** rules
- [ ] Paymob/wallet not reintroduced (D2)
- [ ] Sessions used as SSOT where unit touches day ops (D10)
- [ ] D5 / D21 states not collapsed
- [ ] D11 / D23 not mixed
- [ ] D12 → D14 relationship enforced server-side if chat touched
- [ ] D13 Admin monitor UI labeled if Admin chat touched
- [ ] Billing checklist updated if new paid service
- [ ] Analyzer + tests; size limits; approval
- [ ] No secrets committed

---

## 19. Firebase Billing / Paid Features

Required deliverable for Wave H / before Blaze: complete `FIREBASE_BILLING_CHECKLIST.md` (FCM, Functions, Firestore, Storage, profile pics, chat images/voice, attachments, gated audio, App Check, legacy Paymob quarantine). **Do not invent prices.**

---

### AUD Coverage

Status legend: **Planned** = unlocked by D1–D24 / ready to implement; **Grouped** = driver AUD; **Accepted** = out of release or already locked deferred capability.

| AUD ID | Classification | Implementation Unit | Wave | Dependencies | Status |
|--------|----------------|---------------------|------|--------------|--------|
| AUD-001 | Confirmed Bug | U-SEC-RULES | A | D1/D16; tight before deploy | Planned |
| AUD-002 | Confirmed Bug | U-SEC-RULES | A | D2 proof paths; D20 media paths | Planned |
| AUD-003 | Confirmed Bug | U-SEC-IDENTITY | A | D16; U-SEC-RULES | Planned |
| AUD-004 | Confirmed Bug | U-SEC-RULES + U-PAY-LIFECYCLE | A/D | D2 | Planned |
| AUD-005 | Confirmed Bug | U-SEC-IDENTITY | A | D1 | Planned |
| AUD-006 | Architecture/Infrastructure | U-SEC-RULES | A | After tightness | Planned |
| AUD-007 | Confirmed Bug | U-PAY-RAIL | D | D2 quarantine wallet | Planned |
| AUD-008 | Duplicate/Already Covered | U-SEC-RULES (004) | A | AUD-004 | Grouped |
| AUD-009 | Missing Contract | U-PAY-LIFECYCLE | D | D3 | Planned |
| AUD-010 | Missing Contract | U-PAY-LIFECYCLE | D | D4 | Planned |
| AUD-011 | Missing Contract | U-PAY-LIFECYCLE | D | D5 | Planned |
| AUD-012 | Missing Contract | U-PAY-RAIL | D | D6 | Planned |
| AUD-013 | Confirmed Bug | U-PAY-RAIL | D | D2 Paymob OUT | Planned |
| AUD-014 | Missing Contract | U-NOTIF | E | D5 reminders; D19 | Planned |
| AUD-015 | Missing Contract | U-MEM | B | D12 | Planned |
| AUD-016 | Missing Contract | U-SEC-IDENTITY | A | D1 Engineering TBD | Planned |
| AUD-017 | Missing Contract | U-SEC-IDENTITY | A | Auth reset | Planned |
| AUD-018 | Confirmed Bug | U-HALAQA | B | D8 | Planned |
| AUD-019 | Confirmed Bug | U-HALAQA | B | — | Planned |
| AUD-020 | Confirmed Bug | U-PROGRESS | C | D11; U-SESSION | Planned |
| AUD-021 | Confirmed Bug | U-PROGRESS | C | D11 | Planned |
| AUD-022 | Confirmed Bug | U-PROGRESS | C | D11 | Planned |
| AUD-023 | Confirmed Bug | U-PROGRESS | C | D11 | Planned |
| AUD-024 | Missing Contract | U-SESSION | B | D10 | Planned |
| AUD-025 | Confirmed Bug | U-SESSION | B | D7 | Planned |
| AUD-026 | Architecture/Infrastructure | U-CHAT-MEDIA | F | Pagination | Planned |
| AUD-027 | Missing Contract | U-CHAT-AUTHZ | F | D14 Halaqa group | Planned |
| AUD-028 | Architecture/Infrastructure | U-CHAT-MEDIA | F | D13 monitor + windows | Planned |
| AUD-029 | Missing Contract | U-NOTIF | E | D19 FCM + billing | Planned |
| AUD-030 | Missing Contract | U-NOTIF | E | D10 sessions | Planned |
| AUD-031 | Missing Contract | U-NOTIF | E | Awards events | Planned |
| AUD-032 | Architecture/Infrastructure | U-FB-INDEX | H | — | Planned |
| AUD-033 | Architecture/Infrastructure | U-FB-INDEX | H | — | Planned |
| AUD-034 | Architecture/Infrastructure | U-PAY-LIFECYCLE | D | D3 queries | Planned |
| AUD-035 | Confirmed Bug | U-PAY-RAIL | D | D2 OUT | Planned |
| AUD-036 | Duplicate/Already Covered | U-SEC-RULES (001) | A | AUD-001 | Grouped |
| AUD-037 | Missing Contract | U-PAY-LIFECYCLE | D | D3 | Planned |
| AUD-038 | Confirmed Bug | U-HALAQA | B | — | Planned |
| AUD-039 | Confirmed Bug | U-PROGRESS | C | D11 accuracy separate | Planned |
| AUD-040 | Missing Contract | U-MEM | B | D21 | Planned |
| AUD-041 | Low Priority | U-UI-SYSTEM | G | D15 AR only | Planned |
| AUD-042 | Low Priority | U-UI-SYSTEM | G | D15 | Planned |
| AUD-043 | Confirmed Bug | U-UI-L10N | G | D15 force RTL | Planned |
| AUD-044 | Missing Contract | U-UI-L10N | G | D15 **AR-only** (no EN ARB) | Planned |
| AUD-045 | Confirmed Bug | U-UI-L10N | G | D15 hide language row | Planned |
| AUD-046 | Low Priority | U-UI-SYSTEM | G | D15: no theme program; fix only if light broken | Planned |
| AUD-047 | Low Priority | U-UI-SYSTEM | G | Same | Planned |
| AUD-048 | Confirmed Bug | U-UI-SYSTEM | G | — | Planned |
| AUD-049 | Confirmed Bug | U-UI-SYSTEM | G | — | Planned |
| AUD-050 | Low Priority | U-HYGIENE | H | — | Planned |
| AUD-051 | Duplicate/Already Covered | U-HYGIENE (050) | H | AUD-050 | Grouped |
| AUD-052 | Architecture/Infrastructure | U-UI-SYSTEM | G | — | Planned |
| AUD-053 | Missing Contract | U-CHAT-MEDIA | F | D20 | Planned |
| AUD-054 | Confirmed Bug | U-CHAT-AUTHZ | F | D13 intentional + UI | Planned |
| AUD-055 | Confirmed Bug | U-CHAT-AUTHZ | F | D14 | Planned |
| AUD-056 | Confirmed Bug | U-SESSION | B | D9 per-slot | Planned |
| AUD-057 | Missing Contract | U-SESSION | B | D10 | Planned |
| AUD-058 | Confirmed Bug | U-CHAT-AUTHZ | F | 019 | Planned |
| AUD-059 | Confirmed Bug | U-MUSHAF | G/H | D23 | Planned |
| AUD-060 | Accepted | U-HYGIENE | H | Uploads gated | Accepted |
| AUD-061 | Architecture/Infrastructure | U-HYGIENE | H | CI | Planned |
| AUD-062 | Architecture/Infrastructure | U-SEC-IDENTITY | A | App Check + billing | Planned |
| AUD-063 | Confirmed Bug | U-PAY-LIFECYCLE | D | Partial policy Schema TBD | Planned |
| AUD-064 | Confirmed Bug | U-PAY-LIFECYCLE | D | Transaction | Planned |
| AUD-065 | Architecture/Infrastructure | U-FB-SCALE | H | — | Planned |
| AUD-066 | Low Priority | U-PROGRESS | C | — | Planned |
| AUD-067 | Low Priority | U-NOTIF | E | — | Planned |
| AUD-068 | Duplicate/Already Covered | U-UI-SYSTEM (046) | G | D15 | Grouped |
| AUD-069 | Duplicate/Already Covered | U-SEC-IDENTITY (003) | A | D16 | Grouped |
| AUD-070 | Accepted | U-SEC-IDENTITY | A | D22 no idle timeout | Accepted |
| AUD-071 | Architecture/Infrastructure | U-QA | I | Rules tests | Planned |
| AUD-072 | Architecture/Infrastructure | U-QA | I | Shells | Planned |
| AUD-073 | Architecture/Infrastructure | U-QA | I | Payment lifecycle | Planned |
| AUD-074 | Architecture/Infrastructure | U-QA | I | Progress math | Planned |
| AUD-075 | Duplicate/Already Covered | U-UI-L10N (044) | G | AR validation copy | Grouped |
| AUD-076 | Confirmed Bug | U-UI-SYSTEM | G | — | Planned |
| AUD-077 | Missing Contract | U-CHAT-MEDIA | F | D20 | Planned |
| AUD-078 | Architecture/Infrastructure | U-NOTIF / U-FB-SCALE | E/H | — | Planned |
| AUD-079 | Duplicate/Already Covered | U-UI-L10N (044) | G | Keep `ar` | Grouped |
| AUD-080 | Architecture/Infrastructure | U-PAY-LIFECYCLE | D | D3 | Planned |
| AUD-081 | Accepted | U-HYGIENE | H | Posts removed | Accepted |
| AUD-082 | Low Priority | U-UI-SYSTEM | G | — | Planned |
| AUD-083 | Low Priority | U-UI-SYSTEM | G | — | Planned |
| AUD-084 | Duplicate/Already Covered | U-UI-SYSTEM (046) | G | D15 | Grouped |
| AUD-085 | Low Priority | U-HYGIENE | H | — | Planned |
| AUD-086 | Low Priority | U-HYGIENE | H | — | Planned |
| AUD-087 | Duplicate/Already Covered | U-UI-L10N (044) | G | AR error page OK | Grouped |
| AUD-088 | Architecture/Infrastructure | U-PROGRESS | C | Grades encoding | Planned |
| AUD-089 | Low Priority | U-PROGRESS | C | — | Planned |
| AUD-090 | Duplicate/Already Covered | U-PROGRESS (023) | C | AUD-023 | Grouped |
| AUD-091 | Low Priority | U-HYGIENE | H | — | Planned |
| AUD-092 | Low Priority | U-CHAT-AUTHZ | F | — | Planned |
| AUD-093 | Low Priority | U-UI-L10N | G | Digits | Planned |
| AUD-094 | Confirmed Bug | U-SESSION | B | D8/D10 | Planned |
| AUD-095 | Confirmed Bug | U-NOTIF | E | D17 | Planned |
| AUD-096 | Confirmed Bug | U-PROGRESS | C | D11 | Planned |
| AUD-097 | Missing Contract | U-SESSION + U-PROGRESS | B/C | D11 | Planned |
| AUD-098 | Confirmed Bug | U-CHAT-AUTHZ | F | D12+D14 | Planned |
| AUD-099 | Confirmed Bug | U-MEM | B | D18 profile actions | Planned |
| AUD-100 | Low Priority | U-HYGIENE / U-SEC-RULES | H/A | D24 quarantine | Planned |
| AUD-101 | Confirmed Bug | U-FB-SCALE | H | — | Planned |
| AUD-102 | Confirmed Bug | U-UI-L10N | G | Terminology | Planned |

**Coverage:** 102 / 102. No AUD ID omitted. **No AUD remains Blocked on Wave 0 product questions.**

---

## Unresolved Engineering / Schema / Infrastructure TBDs

1. Admin Auth user provisioning mechanism (D1).
2. Payment-access field schema vs `users.isActive` (D5).
3. Pricing rules document shape + invoice job trigger (D3).
4. Grace period config location (D5).
5. Full `sessions` document schema + materialization job (D10).
6. Migration dual-read/backfill synthetic day → sessions.
7. Conflict validation implementation (D9).
8. Halaqa group conversation id + roster sync (D14).
9. Chat edit/delete retention / soft-delete (D20).
10. Chat media Storage path layout (D20).
11. FCM token collection + send pipeline (D19).
12. Blaze verification rows in billing checklist (no invented prices).
13. Arabic search normalization details.
14. Student roster status enum (Active / payment-suspended / no-Halaqa / archived) (D18/D21).
15. Mushaf last-read schema + two visual modes approach (D23).
16. Data-retention policy for archive and media delete (D20/D21).
17. Whether authorized payment **reviewer** remains Supervisor-scoped, Admin, or both (**Engineering TBD** — freeze has Supervisor review; locks say “authorized review” + Admin reinstate).
18. Re-inspect `70362e0` supervisor roster refresh before U-MEM.

**Planning phase stops here. No application code, rules, indexes, deploys, commits, or pushes.**
