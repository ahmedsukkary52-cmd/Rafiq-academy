# W5 — Parent Academic Awareness
## Phase 0 Technical Design

**Status:** Phase 0 approved · Pre-Slice Pass · Slice 1 Pass · Slice 2 Pass · **W5 COMPLETE** (`docs/W5_COMPLETION_PRODUCTION_VALIDATION.md`)  
**Date:** 2026-07-29  
**Predecessors:** W1–W4 complete; Post-W4 cross-workflow audit approved  
**Standing rule:** If an assumption is wrong: **stop**, update this document, then continue.

### Classification

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed directly in current code or an approved product decision |
| **Inference** | Conclusion supported by Verified facts, but not an approved product rule |
| **Product Decision** | A choice that changes workflow behavior and requires approval |

### Permanent architecture rules

#### 1. Domain ownership over feature ownership

| Rule | Meaning |
|------|---------|
| Single owner | If a business rule belongs to the academy domain, it has one owner even when multiple workflows consume it |
| Extract on concept, not on duplication | Do not create helpers merely because two features share code; extract only when a clear domain concept exists |
| Prefer domain move over `utils` dumps | Move ownership to the correct domain; do not grow `shared/utils` as a dumping ground |
| Justify ownership | Every proposed extraction must explain **why that object belongs to that domain**, not only that it is duplicated |

#### 2. Event ownership — domain fact, never a notification (**approved**)

An `AcademyEvent` represents **what happened in the academy**. It must never represent a delivery action.

| Domain facts (allowed) | Delivery actions (forbidden as event names/types) |
|------------------------|---------------------------------------------------|
| `HomeworkAssigned` | `SendHomeworkNotification` |
| `HomeworkReviewed` | `NotifyParent` |
| `StudentAbsentRecorded` | `ShowInboxCard` |

Delivery channels (in-app, push, email, SMS, …) are **projections** of that fact and remain outside the academy domain.

#### 3. Three-layer ownership — what / who / how (**approved**)

```text
Teacher → SSOT → AcademyEvent → observers → delivery projections
```

| Layer | Owns | Must not own |
|-------|------|--------------|
| **Academy domain** | **What happened** (`AcademyEvent`, SSOT-derived facts) | Who is told; how they are told; inbox copy |
| **Observer layer** | **Who should know** (subject student, linked parents, later supervisor / analytics / audit / …) | Event meaning; channel transport; Arabic inbox wording |
| **Delivery layer** | **How they are informed** (`AcademyEventSink`, in-app composer, future FCM/SMS/…) | Inventing business facts; deciding academy eligibility rules in ad-hoc channel code |

Do not let these responsibilities leak into each other.

#### 4. Event evolution — reusable academy event stream (**approved**)

Design every event so **future observers** (Supervisor, Analytics, Audit Log, AI Assistant, …) can subscribe **without changing the workflow that emitted it**.

W5 must **not** optimize only for parent notifications. W5 optimizes for a **reusable academy event stream**. The first concrete delivery remains in-app signals to student + linked parents (D-W5-1); that is a consumer choice, not the event’s identity.

#### 5. Event versioning and stability (**approved**)

Once an `AcademyEvent` becomes **public** inside the academy domain (emitted on a live write path), treat it as a **stable contract**.

| Rule | Meaning |
|------|---------|
| No silent renames | Do not rename a public event type |
| No silent semantic changes | Do not change what an existing event means |
| Evolve by addition | If behavior must change, introduce a **new** event kind rather than mutating an old one |
| Protect observers | Observers must not break because another workflow evolves |

Pre-Slice types that have not yet been emitted on a live path may still be tightened for payload ownership before their first public publish (Slice 1 for `HomeworkAssigned`).

#### 6. Event payload ownership (**approved**)

Every `AcademyEvent` carries only the **minimum immutable facts** true at the moment it occurred.

| Include | Exclude |
|---------|---------|
| IDs, timestamps, actor, affected entity, workflow fact | Presentation copy, display labels invented for inbox UI, channel hints |

Observers / delivery may **enrich** later by reading repositories (e.g. student display name for inbox wording).

#### 7. Observer independence (**approved**)

| Rule | Meaning |
|------|---------|
| Independent execution | Each registered observer/handler runs independently |
| Isolated failure | Failure in one must not prevent others from processing the same event |
| Publisher ignorance | The event publisher (`AcademyEventSink.publish` caller) must not know which observers are registered |

Concrete W5 shape: a fan-out sink invokes registered handlers; emitters depend only on `AcademyEventSink`.

#### 8. Event ordering (**approved**)

For a single business transaction, observers must see `AcademyEvent`s in the **same logical order** in which the domain facts occurred.

| Rule | Meaning |
|------|---------|
| Publisher owns order | The emitter builds the ordered event list; the sink preserves that sequence |
| No registration-order dependence | Handlers must not infer meaning from the order they were registered |
| No implementation leakage | Observers must not rely on handler/channel internals for ordering |

#### 9. Delivery isolation (**approved**)

Fan-out is **best-effort**.

| Rule | Meaning |
|------|---------|
| Continue on failure | A failure in one handler must not stop the remaining handlers |
| Independent results | Every handler reports its own result; the fan-out aggregates without hiding per-handler outcomes |
| Unpublished warning | With today’s sole in-app handler, total failure still surfaces `hasUnpublishedEvents` (B-R8) |

#### 10. Idempotency ownership (**approved**)

| Rule | Meaning |
|------|---------|
| Event ids | Deterministic `eventId`s guarantee the same domain fact is published as one operational identity |
| Handler tolerance | Handlers must still tolerate duplicate delivery (e.g. deterministic in-app signal ids / upsert) |
| Shared responsibility | Do not rely only on the publisher for correctness |

#### 11. Event observability (**approved**)

Every `AcademyEvent` must be observable **without** coupling it to any delivery channel.

| Concern | Owner | Must not mix with |
|---------|-------|-------------------|
| Workflow / SSOT success | Academy domain | Inbox metrics, FCM receipts, copy |
| Fact published? | Academy publish outcome (`AcademyEventPublication`) | Channel-specific payloads |
| Which handlers processed / failed? | Channel-neutral handler reports on the publish report | Notification UI state |
| Delivery metrics (open rates, device tokens, …) | Delivery layer only | Teacher/homework write path |

The academy workflow must be able to answer:

1. Was the domain fact published?
2. Which observers/handlers processed it?
3. Which handlers failed?

…without importing notification-specific types into the homework/attendance workflow.

#### 12. Future compatibility (**approved**)

The current pipeline must remain capable of supporting Push, Email, SMS, Supervisor observers, Analytics, Audit log, and AI assistants **without changing the publisher**.

If a future feature requires modifying the Homework (or Attendance) emit path to support a new observer, treat that as an **architectural regression**.

### Debt-track boundary

- **Category A** may be addressed inside W5 only when it directly protects or simplifies this workflow.
- **Category B** (including **B-R8** at-most-once delivery, Storage/Blaze, rules, CI) does **not** gate W5 and must not be “solved” with client retries.

---

## 0. Goal (workflow extension, not a parallel parent product)

### 0.1 Workflow (approved direction)

W5 extends the **existing academy academic loop**. The direction is:

```text
Teacher → SSOT → Academy Event → Student + Parent observers
```

**not**

```text
Teacher → Notifications → Parent
```

```text
Teacher assigns homework / reviews a recitation
  → assignments / recitationRecords remain the SSOT
  → academy derives operational events (HomeworkAssigned / HomeworkReviewed)
  → observer layer resolves who should know (reusable; not parent-only by design)
  → delivery projects to current channels (in-app today)
  → weekly / later reports continue to reuse the same assignment & recitation data
```

W5 is **not**:

- a new parent homework module,
- a second parent “academic feed” with its own truth,
- a notifications feature whose meaning lives in the inbox,
- a parallel workflow beside W1–W4,
- an event model named or shaped as “send notification”.

The **assignment document** and the **recitation record** remain the single sources of truth. Any inbox card is a **delivery projection** of an academy fact through the **same `AcademyEvent` / `AcademyEventSink` boundary W4 introduced**. Reports never read notifications to decide what happened.

### 0.2 Why this extends W1–W4 rather than starting a parent side-path — Verified + Inference

| Fact | Tag |
|------|-----|
| Teacher `sendAssignment` already writes `assignments` + an in-app student notification in the **same batch** | **Verified** (`teacher_remote_datasource_impl.dart` assign path) |
| Teacher `updateRecitationReview` already writes grades on `recitationRecords` + an in-app student notification in the **same transaction** | **Verified** (review path) |
| Parent weekly report already aggregates attendance + reviewed recitations; it does **not** query `assignments` | **Verified** (`parent_remote_datasource_impl` weekly report) |
| `watchChildrenAssignments` is an empty-stream stub with no UI caller | **Verified** |
| W4 proved: SSOT → transition/fact → `AcademyEvent` → sink → in-app projection, without coupling the write path to one channel | **Verified** |
| Therefore parent academic awareness should attach to the **same commit points and the same event port**, not invent a parent-only query/workflow | **Inference** |

### 0.3 Delivery channels (reuse W4 — do not introduce a second mechanism)

| Concept | Role | Owner |
|---------|------|-------|
| Academic SSOT | `assignments`, `recitationRecords` | Academic write paths (teacher today) |
| Academy event | Stable operational **fact** | Academy domain (`AcademyEvent`) |
| Observer resolution | Who should know about that fact | **Observer layer** (not the event, not the inbox) |
| Delivery port | Channel-agnostic publish | `AcademyEventSink` |
| Current channel | In-app inbox projection | Notifications feature / in-app sink |
| Future channels / observers | FCM, SMS, Supervisor dashboards, Analytics, Audit, … | Additional subscribers/sinks — **not invented inside emitters** |

**Hard rules:**

1. `sendAssignment` and `updateRecitationReview` publish **domain events only** — never notification DTOs.
2. Emitters must not change when a new observer (e.g. Supervisor) is added later — only observation policy / subscribers expand.
3. W4 reserved `HomeworkAssigned` / `HomeworkReviewed` — **Verified**; W5 claims those fact names.

---

## 1. Real academy workflow

### 1.1 Operational sequence

```text
Teacher assigns homework for a halaqa roster
  → Atomic batch writes assignments/{id} per student (SSOT)
  → Derive academy events (one HomeworkAssigned per committed assignment doc)
  → Observer layer resolves who should know (student + linked parents today;
        supervisor / analytics / … can subscribe later without changing this write)
  → Delivery publishes through AcademyEventSink
        └─ Current channel: in-app signals for resolved observers
        └─ Future channels: additional sinks, same events

Student works the homework / (optionally later) submits recitation
  → Unchanged W1 student path
  → Audio submit remains gated by AppCapabilities.audioUploadsEnabled (Category B)

Teacher reviews a pending recitation OR adds a live evaluation
  → recitationRecords updated / created (SSOT)
  → Derive HomeworkReviewed only when a review transition actually occurs
  → Same observer → delivery path as assign

Parent / Student (current observers)
  Opens existing notifications inbox / badge
      └─ Sees projections of academy facts
      └─ Weekly report remains the aggregate truth surface (same SSOT data)
```

### 1.2 Product-practice classification

| Practice | Classification | W5 consequence |
|----------|----------------|----------------|
| Assignment doc is homework SSOT | **Verified** (W1) | Events/notifications never create or override assignments |
| Recitation record is evaluation SSOT | **Verified** (W1) | Events never create grades |
| Student already receives assign + review in-app messages | **Verified** | W5 must not drop student delivery while adding parents |
| Parent expects to know what was assigned / how it was graded | **Inference** (academy practice; post-W4 audit gap) | Product decisions D-W5-1 … D-W5-4 |
| Same event port as absence | **Verified** W4 architecture intent | Reuse `AcademyEventSink`; no second writer |
| Migrating inline notifies out of the teacher batch inherits at-most-once delivery | **Verified** analogy to W4 / B-R8 | Accept for W5; do not add client retry |
| Parent needs a dedicated homework list page | **Inference / likely false for MVP** | Prefer inbox projection + existing weekly card (D-W5-6) |

---

## 2. Current implementation map

### 2.1 What already exists and must be reused — Verified

| Piece | Location | Reuse in W5 |
|-------|----------|-------------|
| `AcademyEvent` sealed hierarchy | `lib/shared/domain/academy_event.dart` | Add homework/review event kinds |
| `AcademyEventSink` port | `lib/shared/domain/academy_event_sink.dart` | Unchanged contract |
| `InAppAcademyEventSink` | `lib/features/notifications/data/sinks/…` | Extend to compose new event kinds |
| `ParentRepository.getParentIdsByStudentIds` | parent feature | Reuse for parent observers |
| `ParentRecipientResolver` | parent domain service | Chunking/merge ownership stays here |
| Parent inbox + badge + route | W4 parent home / `NotificationsPage` | No second inbox |
| Deterministic in-app delivery ids | `AcademyEventIds.inAppDeliveryId` | Reuse pattern; move helper if ownership clarified (D-W5-8) |
| Teacher assign + review write paths | `teacher_remote_datasource_impl` | Emit events post-commit / replace inline notif writes |

### 2.2 What must not be treated as W5 foundations — Verified

| Item | Why |
|------|-----|
| `watchChildrenAssignments` empty stream | Dead API; wiring it would create a **parallel parent homework workflow** |
| New parent “academic dashboard” | Duplicates weekly report + inbox; feature ownership creep |
| New notification collection or schema | Existing `notifications` + `audience` / `readBy` suffice |
| Client retry / outbox for failed publish | **B-R8** — platform later |
| Enabling `audioUploadsEnabled` | Category B / Storage — out of W5 |
| Supervisor observation of assign/review | Supervisor is outside W1–W4 loop; out of W5 |

### 2.3 The leak W5 is justified to close — Verified

Today, teacher academic writes **compose delivery inside the business transaction**:

| Write | Inline notification | Problems |
|-------|---------------------|----------|
| `sendAssignment` | `type: assignment`, auto doc id, student audience only | Delivery owned by teacher datasource; parents excluded; retry duplicates |
| `updateRecitationReview` | `type: assignment` (mislabel), auto doc id, student audience only | Same; review ≠ assignment type |

W5’s architecture job is to move those consequences behind `AcademyEventSink` while adding parent eligibility — **one boundary, two observers**, not a parent-only side channel.

---

## 3. Domain ownership map (apply the permanent rule)

### 3.1 Concepts and owners

| Concept | Belongs to | Why (domain reason, not “it’s duplicated”) | W5 action |
|---------|------------|----------------------------------------------|-----------|
| Assignment document truth | **Assignment / academic work domain** | It is the academy’s record of what a student was asked to do | Keep SSOT; do not mirror into notifications or parent state |
| Recitation review truth | **Recitation / evaluation domain** | It is the academy’s record of assessed oral work | Keep SSOT on `recitationRecords` |
| “Something academically happened” | **Academy event domain** | Cross-workflow operational **fact**, channel-agnostic | Add `HomeworkAssigned` / `HomeworkReviewed` |
| Who should know | **Observer layer** | Eligibility is not a notification and not part of the fact payload | Pure observation specs + resolver port |
| Parent↔student link | **Parent relationship domain** | Relationship data in `parentProfiles` | Used by observer resolver, not by emitters |
| How they are informed | **Delivery layer** | In-app / future channels project facts to observers | Sink + signal composer |
| Latest-assignment query | **Assignment domain** (if extracted) | Ordering rule defines “current homework” for the academy, not a UI helper | **Not required for W5 MVP path** (events fire at write time). Defer extraction unless a slice must read “current assignment” for parents |
| Calendar-day utility | **Academy time domain** | Shared meaning of an operational day | Out of W5 unless a slice touches day boundaries |
| Attendance absence rules | **Attendance domain** (`AttendancePolicy` / transitions) | Unrelated to homework facts | Do not touch |

### 3.2 Extractions / moved objects proposed for W5 (only if needed)

| Object | Proposed home | Ownership justification | Extract now? |
|--------|---------------|-------------------------|--------------|
| `HomeworkAssigned`, `HomeworkReviewed` (names TBD by D-W5-2) | `lib/shared/domain/academy_event.dart` | Same sealed academy-fact hierarchy as absence | **Yes** — core |
| Pure projector: assignment commit → events | Next to teacher write **or** small domain projector owned by academic events | Derives facts from successful writes; must not know channels | **Yes** — core |
| Pure projector: review transition → events | Same pattern as `AttendanceAbsenceTransitions`, but for review status/grade | Transition detection is a domain rule | **Yes** — core |
| Generalize `AbsenceSignalComposer` → channel composer for all `AcademyEvent`s | `features/notifications/domain` | It already owns in-app presentation; absence-only naming is feature accident | **Yes** — when event kinds expand |
| `AcademyEventIds.inAppDeliveryId` | Move beside notifications / signal identity | “in-app” is channel-specific; event id stays on academy events | **Yes** — Category A ownership fix while touching the file |
| `AssignmentPolicy` / latest-assignment gateway | Assignment domain module | Only if a workflow must **read** “current homework” with one rule | **No for MVP** — duplication remains documented debt |
| Shared empty-state / calendar utils / bloc splits | Various | Not domain concepts required by this workflow | **No** |

**Inference:** W5 should add **domain event kinds + projectors + channel composition**, not a new shared utils pack.

---

## 4. Gaps relative to the desired workflow

| # | Gap | Tag | W5 handling |
|---|-----|-----|-------------|
| G1 | Parents never receive assign/review signals | **Verified** | Core workflow |
| G2 | Teacher datasource owns notification copy + audience | **Verified** | Move behind sink |
| G3 | Review notify mislabeled `type: assignment` | **Verified** | Channel maps event → correct `NotificationTypes` |
| G4 | Auto-generated notification ids → duplicate cards on retry | **Verified** | Deterministic ids (W4 pattern) |
| G5 | `AbsenceSignalComposer` exhaustiveness breaks when new events are added until updated | **Verified** | Extend composer in same slice as new events |
| G6 | Parent cannot log out (W4-A1) | **Verified** | Category A — include if it protects the parent surface W5 extends |
| G7 | Singleton parent/teacher/student blocs not reset on logout (W4-A2) | **Verified** | Include **ParentBloc** reset only if logout is in scope; do not boil the ocean |
| G8 | No deep-link from notification to detail | **Verified** | Product Decision D-W5-7 |
| G9 | Live teacher evaluation creates `reviewed` records without pending transition | **Verified** | Decide whether that emits a review event (D-W5-4) |
| G10 | Student audio submit path unreachable | **Verified** / Category B | Out of W5 |
| G11 | B-R8 at-most-once | **Verified** | Inherit; document; no client retry |

---

## 5. Required product decisions

### D-W5-1 — Who observes academic events?

| Option | Meaning |
|--------|---------|
| **A. Student + every linked parent (recommended)** | Preserves today’s student notify; closes parent gap; matches multi-guardian model from D-W4-1 |
| B. Parents only | Regresses student UX unless inline student writes remain — **recreates dual mechanisms** |
| C. Parents + student + teacher | Teacher already knows; noise |

**Recommendation: A.** One event, multiple observers. Do not keep inline student writes alongside parent events.

### D-W5-2 — Event naming / grain

| Option | Meaning |
|--------|---------|
| **A. `HomeworkAssigned` + `HomeworkReviewed` (recommended)** | Matches W4 reserved names; review closes the homework/recitation academic loop |
| B. `HomeworkAssigned` + `RecitationReviewed` | More precise if live evaluations are not “homework” |
| C. One generic `AcademicUpdate` | Weak domain meaning; hard to compose copy and audiences |

**Recommendation: A**, with review event payload carrying enough context (student, ranges/grade labels as display projections only, record id for identity). If live evaluations should also notify, treat them as the same **reviewed recitation** fact (see D-W5-4), not a third event kind.

### D-W5-3 — Where does observer policy live?

| Option | Meaning |
|--------|---------|
| A. Channel sink decides observers ad hoc | Buries “who should know” inside delivery — **rejected by approved ownership rule** |
| **B. Dedicated observer layer: pure specs + resolver port (approved)** | Academy emits facts; observer layer maps fact → observer specs (subject student, linked parents, later supervisor/…); delivery only informs resolved ids |
| C. Put audience lists on the event at emission time | Couples emitters to today’s consumers; blocks event evolution |

**Approved: B.** Observation specs stay channel-agnostic so Supervisor / Analytics / Audit can subscribe later by extending the observer layer — **without changing** `sendAssignment` / `updateRecitationReview`.  
W5’s first resolved set remains student + linked parents for homework events, and linked parents for absence events (**Verified** W4 behavior preserved).

### D-W5-4 — When does a review event fire?

| Option | Meaning |
|--------|---------|
| **A. Pending → reviewed transition only (recommended baseline)** | Mirrors W4 transition discipline; idempotent re-review blocked by existing status check |
| B. Also when teacher creates a live evaluation already `reviewed` | Parents learn about in-session grades; different transition shape (create, not pending→reviewed) |
| C. Any grade field change | Noisy; harder idempotency |

**Recommendation: A + B as one fact type** (“recitation result became available to observers”), with deterministic id keyed by `recitationRecordId` (and maybe revision token if grades can change — default: first reviewed write wins unless product wants corrections).  
**Product Decision needed:** do grade corrections after `reviewed` emit an update event? (**Inference:** follow W4 correction spirit only if teachers can edit reviewed grades today — verify in Slice 0.)

### D-W5-5 — Failure semantics

| Option | Meaning |
|--------|---------|
| **A. Same as approved W4: academic write commits first; publish secondary; surface partial warning to teacher; never roll back SSOT (recommended)** | Consistent academy behavior |
| B. Keep notifications inside the Firestore batch/transaction for assign/review only | Restores dual paradigms; blocks multi-channel |

**Recommendation: A.** Explicitly accept **B-R8** for homework/review events once inline writes are removed. Teacher copy stays channel-neutral (as W4 snackbar).

### D-W5-6 — Parent surface

| Option | Meaning |
|--------|---------|
| **A. Existing notifications inbox + badge only (recommended)** | Extends W4 surface; no parallel parent homework workflow |
| B. Inbox + new parent homework list reading `assignments` | Useful later; is a **different workflow** (parent study oversight), not required to close awareness |
| C. Only enrich weekly report | Too slow for “immediately know”; collapses day signal into week aggregate |

**Recommendation: A.** Weekly report remains aggregate SSOT projection; inbox is day signal. Do **not** activate `watchChildrenAssignments` in W5.

### D-W5-7 — Notification actions / deep links

| Option | Meaning |
|--------|---------|
| **A. Mark-read only for W5 (recommended MVP)** | Matches current absence behavior; avoids unfinished parent detail pages |
| B. Deep-link to a new parent detail screen | Requires inventing parent screens W5 is trying not to create |
| C. Deep-link only for student (evaluations / homework routes) | Asymmetric; parents still land nowhere useful |

**Recommendation: A** for parents. Optional later Category A: student taps navigate to existing homework/evaluations routes.

### D-W5-8 — `inAppDeliveryId` ownership

| Option | Meaning |
|--------|---------|
| **A. Move channel delivery id helper out of `AcademyEvent` into notifications/signal identity (recommended)** | Domain ownership: event id ≠ channel row id |
| B. Leave as-is | Works; keeps channel detail in academy domain |

**Recommendation: A** while touching the file for new event ids.

### D-W5-9 — Parent logout (Category A)

| Option | Meaning |
|--------|---------|
| **A. Add parent logout + confirm, and stop notification watch / clear ParentBloc on `AuthUnauthenticated` (recommended)** | Directly protects the parent surface W4/W5 share |
| B. Defer logout | Leaves W4-A1 open on the workflow we are extending |
| C. Also fix supervisor/admin logout | Good hygiene; not required for W5 academic awareness |

**Recommendation: A** (parent only). Supervisor/admin remain roadmap hygiene.

### D-W5-10 — Wording

| Option | Meaning |
|--------|---------|
| **A. Neutral Arabic, child name + factual assign/review summary, no panic tone (recommended)** | Consistent with W4 absence copy discipline |
| B. Include full grade text in notification title | Loud; grade remains on SSOT / evaluations |

**Recommendation: A.** Body may mention grade display label for review events; title stays calm («تكليف جديد», «تم تقييم التسميع», etc.). Exact strings approved at slice time.

---

## 6. Proposed implementation slices

| Slice | Intent | Domain focus |
|-------|--------|--------------|
| **Pre-Slice** | Claim `HomeworkAssigned` / `HomeworkReviewed` as **facts**; event ids; observer specs + resolver port; generalize in-app composer; move channel delivery id out of academy domain; **no teacher write migration** | Event + observer + delivery boundaries |
| **Slice 1** | `sendAssignment`: remove inline notif; publish events after successful batch; delivery informs resolved observers | Assignment write ↔ events |
| **Slice 2** | `updateRecitationReview` (+ live eval if D-W5-4 includes it): remove inline notif; transition-based events | Review write ↔ events |
| **Slice 3** | Parent surface hardening: logout (D-W5-9), ParentBloc identity reset; copy polish; production validation | Parent session owns access to projections |

Each slice: validate → `flutter analyze` → tests → format → commit → push → **stop for approval**.

---

## 7. Explicitly out of W5

- Durable / exactly-once delivery (**B-R8**)
- FCM / SMS / email / WhatsApp
- Enabling Storage / student audio submit loop
- Parent homework list / `watchChildrenAssignments` activation
- Wiring Supervisor / Analytics / Audit as live observers (design must allow them; implementation is later)
- Payments, chat, analytics entry points
- Extracting `AssignmentPolicy` / calendar-day mega-refactors unless a slice is blocked without them
- Solving G13 roster divergence (unless it blocks event correctness — it should not)
- Client-side retry/replay/persistence for failed publish

---

## 8. Success criteria (Phase 0 → later validation)

W5 is successful when:

1. Teacher assign/review still persist exactly one SSOT write path.  
2. Those writes publish **domain facts** (`AcademyEvent`) only — never notification commands.  
3. Observer resolution is reusable and not hard-wired inside emitters.  
4. Linked parents (and students, per D-W5-1) can observe assign/review via current delivery without a new parent workflow.  
5. Identical re-save / non-transition writes produce **no** duplicate events.  
6. No second notification mechanism exists beside the W4 port.  
7. A future observer can be added by extending the observer/delivery layers **without** changing assign/review workflows.  
8. B-R8 remains acknowledged, not papered over.

---

## 9. Approval gate

**Phase 0 approved in principle** with the additional permanent rules (event ownership, three-layer what/who/how, event evolution).

Pre-Slice implements only the boundary pieces above — **no Slice 1 teacher migration until Pre-Slice is approved.**
