# Production Hardening Sprint — Phase 0 Design

**Status:** Approved · H1–H3 approved · H4 implemented (awaiting H4 sign-off before H5)  
**Date:** 2026-07-31  
**Context:** W1–W8 workflow family **complete and approved**. **No W9.**  
**Method:** Phase 0 design approved; execution proceeds slice-by-slice.  
**H1 deliverable:** `docs/H1_IDENTITY_VALIDATION.md`  
**H2 deliverable:** `docs/H2_DAY_HOMEWORK_SSOT_VALIDATION.md`  
**H3 deliverable:** `docs/H3_EVENT_DELIVERY_HYGIENE_VALIDATION.md`  
**H4 deliverable:** `docs/H4_ABSENCE_REQUEST_READ_HYGIENE_VALIDATION.md`  
**Predecessors:** `docs/W8_COMPLETION_PRODUCTION_VALIDATION.md`, `docs/POST_W8_PRODUCT_AUDIT.md`, `docs/POST_W7_PRODUCT_AUDIT.md`, `docs/POST_W6_PRODUCT_AUDIT.md`

### Standing rule

If an assumption is wrong: **stop**, update this document, then continue.

### Sprint goals (locked intent)

| Goal | In scope | Out of scope |
|------|----------|--------------|
| Eliminate **Category A** debt that **protects** existing W1–W8 workflows | Yes | New product workflows / features |
| Reduce architectural complexity **without** changing product behavior | Yes | Behavior-changing UX redesign |
| Improve performance where workflows are unnecessarily expensive | Yes | Premature optimization of unused surfaces |
| Increase unit / widget / integration test coverage | Yes | Full E2E product rewrite |
| Remove duplication; strengthen **existing** shared abstractions | Yes | Inventing new domain systems |
| Prepare production readiness | Document Category B; execute release slices only when approved | Treating Category B as “must ship before any A slice” unless product says so |

### Classification

| Track | Meaning |
|-------|---------|
| **Category A (A-H\*)** | Architecture / hygiene debt that protects or simplifies live W1–W8 paths |
| **Category B (B-R\*)** | Release / infra — serious; does **not** invent product; may run as parallel **Release Readiness** track |
| **Platform Epic P-E1** | Logout + identity reset — trust; pairs with A-H1; **not** a business workflow |

### Explicitly excluded from this sprint

| Excluded | Why |
|----------|-----|
| W9 / parent↔child linking / membership exit / transfer | Product workflows — Post-W8 deferred |
| Messaging as a product feature | Capability, not hardening |
| Payments / complaints full product loops | New or incomplete product, not debt cleanup |
| Enabling audio uploads or FCM as “features” without B-R2 / handlers | Capability unlock gated by Category B |
| Field SSOT promotion for membership | Product Decision, not hardening |

---

## 0. Executive verdict

W1–W8 closed the **operated academy + membership admit** core. The highest remaining risk is no longer “missing ritual,” but:

1. **Shared-device identity leakage** across singleton blocs (hurts every observer after logout).  
2. **Day / latest-assignment duplication** (W1/W3/W5 can drift).  
3. **استئذان / roster query scale** (W7 full-collection filters; W2/W3 `whereIn` unchunked).  
4. **Category B absence** (no versioned rules / CI) — production trust, parallel track.

**Recommended posture:** Run a **Category A–first hardening sprint** in small slices; keep **Release Readiness (Category B + P-E1)** as an explicit parallel track that product can prioritize before store ship.

---

## 1. Architecture held (do not regress)

| Guarantee | Source |
|-----------|--------|
| Attendance is presence SSOT | W2 |
| استئذان is contextual only | W7 |
| Academy Admission owns membership invariant | W8 Rules 1–8 |
| Events are domain facts; delivery is projection | W4/W5 |
| Observers do not invent membership / attendance | W6–W8 |

Hardening must **preserve behavior**. Prefer extract/share/test/delete-dead over rewrite.

---

## 2. Category A inventory (hardening)

| ID | Title | Evidence (**Verified**) | Workflows at risk | Effort | Risk↓ | Notes |
|----|-------|-------------------------|-------------------|--------|-------|-------|
| **A-H1** | Incomplete singleton identity reset | `@singleton` Teacher/Student/Parent/Supervisor/Admin/Notifications/Chat/Posts blocs; logout mainly stops notifications (`main.dart`) | W3–W8 observers on shared devices | M | **High** | Pair with **P-E1** |
| **A-H2** | No `AssignmentPolicy` — latest-due duplicated ×4+ | `orderBy('dueDate', desc).limit(1)` in student / homework / teacher / parent datasources | W1, W3 readiness, W5 | M | **High** | Ex-A-W6-2 |
| **A-H3** | Calendar-day bypasses of `AttendancePolicy` | Hand-rolled `DateTime(y,m,d)` still in teacher UI, parent bloc, notifications, calendar, progress/review mappers, admin, student schedule | W2, W3, W4, W7 day keys | M | **High** | Ex-A-W6-3 |
| **A-H4** | Legacy notification composers / dual sink story | **Resolved in W5:** sole live path is `FanOutAcademyEventSink` + `InAppAcademyEventHandler`. `AbsenceSignalComposer` / `InAppAcademyEventSink` **deleted** (not in tree). H3 froze docs + DI comments. | W4/W5 delivery clarity | — | Done | Was Ex-A-W6-4 |
| **A-H5** | استئذان reads unbounded then client-filter | **H4:** shared `AbsenceRequestFirestoreReads` (same client filters; query shape unchanged pending B-R4 indexes) | W7 scale + drift | — | Consolidated | Was Ex-A-W7-2 |
| **A-H6** | `AbsenceRequest*` lives under parent; teacher/supervisor import it | **H4:** types in `lib/shared/`; parent re-exports | W7 maintainability | — | Done | Was Ex-A-W7-1 |
| **A-H7** | Dual awards schemas (`grantedBy`/`grantedAt` vs `issuedBy`/`date`) | Teacher awards vs supervisor issue; student reader tolerates both; stats query may miss supervisor docs | Encouragement surfaces (not Wn core) | M | Med | Coherence |
| **A-H8** | Orphan routes / unused pages | Analytics, calendar, content, student history routes; `ChatConversationsPage` unregistered; posts tab placeholder vs `PostsListPage` | Ops confusion; wrong wiring risk | S | Low | Cleanup |
| **A-H9** | AdminBloc writers without UI (except W8 admit) | Stats/finance/complaints/broadcast/teachers wired; home only admit | Accidental parallel delivery (broadcast) | S | Low–Med | Quarantine / document |
| **A-H10** | Heavy / unpaginated / unchunked queries | Admin full `payments`/`complaints`; chat streams unbounded; **roster `whereIn` unchunked** (fails >30); استئذان as A-H5 | W2/W3 hard-fail; W7/admin cost | M–L | **High** (roster) | Scale |
| **A-H11** | Critical-path test gaps | Strong: membership, readiness, استئذان ids. Weak: admit use case, homework assign/review, router guards, most blocs | Silent W1/W8 regressions | L | **High** | Incremental |
| **A-H12** | Homework write-on-read `_ensureHomeworkFields` | Live get/stream paths mutate docs | W1 side-effects / permissions | M | Med | Remove or migrate |
| **A-H13** | Domain imports schedule **data** mapper | `GetTodayAgendaUseCase` / supervisor board → `halaqa_weekly_sessions_mapper` | W3/W6 layering | S | Low | Domain port |
| **A-H14** | Operational readiness I/O duplicated | Projector shared; teacher vs supervisor load paths duplicate | W3/W6 drift | M | Med | Ex-A-W6-1 |
| **A-H15** | Admin broadcast bypasses academy event sink | Quarantined as `AdminOpsBroadcast` ops channel (H3); still direct `notifications.add` with `audience` — **not** sink-routed | Parallel ownership vs W4/W5 | — | Quarantined | Align into sink would be product change |
| **A-H16** | Supervisor reports write-only | `supervisorReports.add`; no in-app reader | False ops confidence | S | Low–Med | Hide / document / delete UI |
| **A-H17** | Teacher posts tab placeholder vs full posts feature | `TeacherPostsTab` unavailable; `PostsListPage` exists | Dead nav | S | Low | Wire or remove |
| **A-H18** | Widespread deprecated `withOpacity` | Analyze infos across UI | Noise hides real defects | S | Low | Touch-as-you-go |
| **A-H19** | `FirebaseMessaging` registered unused | **Cleared in H3:** removed from `DiModule` / injectable config; package remains for B-FCM | False FCM readiness | — | Done | With B-FCM |
| **A-H20** | Optional استئذان → inbox events | Accepted D-W7-6 B | Inbox parity only | M | Med | **Optional**; must stay projections |

---

## 3. Category B inventory (release readiness)

| ID | Title | Evidence (**Verified**) | Effort | Risk↓ |
|----|-------|-------------------------|--------|-------|
| **B-R1** | Versioned `firestore.rules` | Absent from repo | L | **High** |
| **B-R2** | Versioned `storage.rules` | Absent | M | **High** |
| **B-R3** | Complete `firebase.json` deploy wiring | FlutterFire-oriented only | S | **High** |
| **B-R4** | Composite index completeness vs live queries | Partial `firestore.indexes.json`; chat/absence patterns historically incomplete | M | Med–High |
| **B-R5** | CI (analyze + tests) | No `.github/workflows` | S | **High** |
| **B-R6** | Reproducible deploy docs | Blocked by missing rules | S | Med |
| **B-R7** | App Check / abuse posture | Not evidenced | M | Med |
| **B-R8** | Durable academy-event publish (outbox / trigger) | Client publish-after-commit only | L | **High** |
| **B-Storage** | Audio uploads gated off | `AppCapabilities.audioUploadsEnabled = false` | — | Unlock only with B-R2 |
| **B-FCM** | OS push productization | DI instance only | L | Med |

---

## 4. Platform Epic (parallel)

| ID | Title | Effort | Risk↓ | Relation |
|----|-------|--------|-------|----------|
| **P-E1** | Parent / supervisor / admin logout + full projection reset | M | **High** | Execute with **A-H1** |

---

## 5. Proposed slices (small, behavior-preserving)

| Slice | Items | Intent | Est. |
|-------|-------|--------|------|
| **H0 — Preflight** | Inventory freeze; branch strategy; “no behavior change” checklist | Align team on bars | S |
| **H1 — Identity** | **P-E1** + **A-H1** | Safe multi-role handoff after W4–W8 | M |
| **H2 — Day & homework SSOT** | **A-H2**, **A-H3**, **A-H12**, **A-H13**, **A-H14** | One day owner; one latest-assignment owner; less W3/W6 I/O drift | M–L |
| **H3 — Event delivery hygiene** | **A-H4**, **A-H15**, **A-H19** | One sink story before FCM | S–M |
| **H4 — استئذان read hygiene** | **A-H5**, **A-H6** (+ **A-H20** only if product wants) | Scale + shared domain for W7 | M |
| **H5 — Query / scale** | **A-H10** (roster `whereIn` chunking **first**) | Prevent W2/W3 hard-fail >30 students | M |
| **H6 — Surface cleanup** | **A-H8**, **A-H9**, **A-H16**, **A-H17** | Delete/quarantine orphans; no new features | S |
| **H7 — Awards schema coherence** | **A-H7** | One achievements contract | M |
| **H8 — Test belt** | **A-H11** incremental | Admit, attendance save, استئذان review, router guards, critical blocs | L (ongoing) |
| **H9 — Analyze polish** | **A-H18** on touched files | Reduce noise | S |
| **RB — Release Readiness** | **B-R1…B-R8**, **B-Storage**, **B-FCM** | Production trust track | L (parallel) |

Each Category A slice: **validate behavior unchanged** → analyze → tests → format → stop for approval (same discipline as Wn slices).

---

## 6. Recommended execution order

### Track A — Hardening (primary)

```text
H0 Preflight
  → H1 Identity (P-E1 + A-H1)     [highest product risk]
  → H2 Day & homework SSOT        [W1/W3/W5 coherence]
  → H5 Roster chunking (A-H10 partial)  [hard-fail risk]
  → H4 استئذان read hygiene
  → H3 Event delivery hygiene
  → H6 Surface cleanup
  → H7 Awards coherence (optional priority)
  → H8 Test belt (continuous; attach to each slice)
  → H9 Polish (touch-as-you-go)
```

### Track B — Release Readiness (parallel; product-scheduled)

```text
B-R5 CI (fast win)
  → B-R1 / B-R2 rules (+ B-R3 / B-R4 / B-R6)
  → B-R8 durable event publish
  → B-R7 App Check
  → B-FCM / B-Storage only after handlers + rules
```

**Do not** block H1–H2 on Category B unless the release date requires rules first.

---

## 7. Impact summary

| Priority band | Items | Why first |
|---------------|-------|-----------|
| **P0** | H1, H2, roster chunk of H5 | Shared-device corruption; day/homework drift; roster >30 failure |
| **P1** | H4, H3, CI (B-R5) | W7 scale; delivery clarity; regression gate |
| **P2** | H6, H7, rest of H5, B-R1–B-R4 | Cleanup + release trust |
| **P3** | H8 continuous, H9, B-R7/B-R8/B-FCM | Depth and production durability |

---

## 8. Success criteria (sprint-level)

Hardening sprint passes when:

1. **No new product workflows** shipped.  
2. **P-E1 + A-H1:** parent/supervisor/admin can log out; singleton projections reset.  
3. **A-H2 / A-H3:** one latest-assignment owner; day math centralized on `AttendancePolicy` for remaining hot paths.  
4. **A-H10 roster:** `whereIn` chunked; teacher roster safe >30.  
5. **A-H5/A-H6:** استئذان reads shared and bounded/scoped.  
6. **Legacy composers** quarantined or deleted; one event sink story.  
7. **Test belt** covers admit + attendance save + استئذان review + router guards at minimum.  
8. **Category B** either completed to an approved release bar or explicitly deferred with owners/dates.  
9. Product behavior of W1–W8 **unchanged** (observable contracts Rules 1–8 still hold).

---

## 9. Approval record

| Item | Status |
|------|--------|
| W1–W8 complete; no W9 | **Accepted (product)** |
| Production Hardening Sprint goals | **Accepted (product)** |
| Category A inventory A-H1…A-H20 | **Documented** |
| Category B B-R1…B-R8 + B-Storage/B-FCM | **Documented** |
| Slice plan H0–H9 + RB | **Accepted (product)** |
| Phase 0 design | **Approved** |
| **H1 Identity (P-E1 + A-H1)** | **Approved (product)** |
| **H2 Day & homework SSOT** | **Approved (product)** |
| **H3 Event delivery hygiene** | **Approved (product)** |
| **H4 استئذان read hygiene** | **Implemented** — see `docs/H4_ABSENCE_REQUEST_READ_HYGIENE_VALIDATION.md` · awaiting sign-off |
| H5+ | **Blocked** until H4 approved |

**Stop after each slice. Do not begin H5 until H4 is approved.**
