# Post-W6 Product Audit

**Date:** 2026-07-29  
**Scope:** Product as a whole after W1–W6 (Homework · Attendance · Teacher Day Ops · Absence Awareness · Parent Academic Awareness · Supervisor Day Oversight)  
**Method:** Read-only investigation. **No code changes. No commits. No pushes.**  
**Predecessors:** `docs/POST_W2_PRODUCT_AUDIT.md`, `docs/POST_W3_PRODUCT_AUDIT.md`, `docs/POST_W5_WORKFLOW_ROADMAP.md`, `docs/W5_COMPLETION_PRODUCTION_VALIDATION.md`, `docs/W6_COMPLETION_PRODUCTION_VALIDATION.md`

### Classification legend

| Tag | Meaning |
|-----|---------|
| **Verified** | Observed in current code / approved docs |
| **Inference** | Reasonable conclusion from Verified facts |
| **Accepted** | Explicitly deferred in an approved decision |

### Track boundary (standing)

| Track | Meaning |
|-------|---------|
| **Category A** | Workflow / product / architecture debt that may travel with future business workflows when it protects or simplifies them |
| **Category B** | Platform / release-readiness / infrastructure — serious, but does **not** gate the next business workflow |

**Platform Epic P-E1** (role logout + identity reset) is **not** a business workflow. It remains a parallel platform track.

---

## 0. Executive verdict

**W1–W6 now form one coherent operated academy day across three roles:**

| Role | What they can answer today |
|------|----------------------------|
| **Teacher** | What must I do today? (W3) — attendance, homework, reviews owned by W1/W2 |
| **Parent** | Was my child absent? (W4) · Was homework assigned / reviewed? (W5) |
| **Supervisor** | Which supervised halaqat need attention, and who owns the fix? (W6) |

**Architecture held.** W6 did not invent a second readiness model or supervisor write SSOT. Shared `HalaqaDayReadinessProjector` is the correct extraction pattern. Escalation is guidance, not ownership transfer.

**The product’s center of gravity has shifted.** Teacher and supervisor loops for the *operated day* are closed enough to observe and run. The largest **business** holes are no longer “mark attendance” or “see homework” — they are **incomplete adjacent loops** that still leave academy operations half-finished (especially استئذان), plus **shared-device trust** (P-E1) that is platform, not W7.

**Three findings dominate this audit:**

1. **Verified — the operated day is multi-role; identity reset is not.** Teacher and student can log out; parent / supervisor / admin cannot. Singleton blocs retain the previous user’s projections. This undermines W4–W6 on shared devices but is **P-E1 (Platform Epic)**, not the next business workflow.  
2. **Verified — absence is still a half-product.** W2 records marks; W4 notifies unexplained absence; `absenceRequests` / استئذان remains a write-only orphan with no parent UI and no approval path (**Accepted** since W2 D3, still true).  
3. **Verified — Category B release blockers remain untouched** (no `firestore.rules` / `storage.rules` in repo, thin `firebase.json`, no CI, audio uploads disabled, B-R8 at-most-once). They do not gate W7 product scope.

**Recommended next business workflow (W7):** Parent Absence Request (استئذان) lifecycle — close the orphan absence-intent loop on top of W2/W4 facts. Justification in §6. **Await approval before Phase 0.**

---

## 1. Product whole — what W1–W6 own

| Workflow | One-line ownership | Status |
|----------|-------------------|--------|
| **W1** | Daily lesson & homework: assign → submit → review → parent weekly visibility | Complete |
| **W2** | Attendance register SSOT → student/parent aggregates | Complete |
| **W3** | Teacher day orchestration (“what must I do today?”) over W1/W2 + schedule | Complete |
| **W4** | Absence awareness: attendance transitions → academy events → parent day signal | Complete |
| **W5** | Parent academic awareness via reusable homework academy events | Complete |
| **W6** | Supervisor day oversight: read projection of W1–W5 + guidance escalation | Complete |

### 1.1 What the product can do end-to-end (**Verified**)

```text
Schedule (today) → Teacher readiness (W3)
                 → Attendance SSOT (W2) → Absence events (W4) → Parent inbox
                 → Homework SSOT (W1) → Homework events (W5) → Parent inbox
                 → Same readiness facts → Supervisor board (W6) → guide to teacher workflows
```

### 1.2 What it still cannot do as a closed business loop (**Verified**)

| Gap | Evidence |
|-----|----------|
| Parent requests excused absence (استئذان) | Write use case / bloc hooks exist; **no UI**; no list/approve readers |
| Safe multi-role device handoff | No parent/supervisor/admin logout UI; no GetIt/bloc identity reset |
| Student audio submit as product | `AppCapabilities.audioUploadsEnabled = false` |
| Parent payments | Cloud Function path commented / throws; no payment UI |
| Teacher ↔ parent operational chat as product | Policy + student chat exist; parent↔teacher surface incomplete |
| Admin product surface | Home is “Coming Soon”; backend stubs exist |
| Live already-reviewed eval → academy event | Accepted W5 residual; pending path already events |

---

## 2. Cross-workflow consistency

### 2.1 Held correctly (**Verified**)

| Principle | Evidence |
|-----------|----------|
| One readiness math | `HalaqaDayReadinessProjector` consumed by teacher agenda + supervisor board |
| Attendance SSOT | `attendanceRecords` + `AttendancePolicy` for register completeness |
| Homework “today” meaning | W1 D7 latest `dueDate` calendar day via `AttendancePolicy.isSameCalendarDay` in projector |
| Events = facts, not notification products | W4/W5 pipeline; teacher datasources do not write homework/absence notifications |
| Supervisor does not own teaching writes | Rule 6 + `TeacherWorkflowOwnership` |
| No supervisor-persisted day-complete flag | W6 read projections only |

### 2.2 Inconsistencies still open (**Verified**)

| Issue | Detail |
|-------|--------|
| **Calendar-day SSOT under-adopted** | `AttendancePolicy.dayStart` / `isSameCalendarDay` exist; many call sites still hand-roll `DateTime(y,m,d)` (teacher attendance/class detail, parent, calendar, schedule, progress, notifications, admin) |
| **Latest-assignment query ×4** | Same `orderBy dueDate DESC limit 1` pattern in student / homework / teacher / parent datasources — no `AssignmentPolicy` owner |
| **Three “week” definitions** | Parent Saturday week · progress Sunday week · analytics rolling 7 — same Arabic “أسبوعي”, three meanings (**Accepted** debt since post-W2) |
| **Arabic weekday spelling drift** | Multiple encodings; mapper must accept variants |
| **Terminology sprawl** | تكليف / واجب / درس / تسميع / تقييم / مراجعة; rewards verbs still fragmented |
| **Dual legacy notification artifacts** | Active: `FanOutAcademyEventSink` + `InAppAcademyEventHandler`. Legacy files remain: `InAppAcademyEventSink`, `AbsenceSignalComposer` (tests only / not the DI path) |
| **Admin broadcast bypasses event stream** | Direct `notifications.add` for broadcast — parallel delivery ownership |
| **Schedule mapper in domain use cases** | Teacher + supervisor domain import `schedule/data/mappers/halaqa_weekly_sessions_mapper.dart` (layering debt) |

### 2.3 Parallel ownership / second-SSOT risk check

| Area | Risk after W6 | Verdict |
|------|---------------|---------|
| Day readiness | Shared projector | **Healthy** |
| Attendance marks | Single collection | **Healthy** |
| Homework assign/review | Single collections + events | **Healthy** |
| Supervisor oversight | Projection only | **Healthy** |
| Assignment “latest” rule | Query duplicated 4× | **At risk** — extract policy, don’t add a 5th copy |
| In-app signals | Active path vs legacy composers | **Cleanup** — Category A hygiene |
| Absence requests | Orphan collection/API | **Incomplete product**, not a second SSOT yet |

**Inference:** W6 did not regress ownership. The remaining duplication is mostly **pre-W6 debt** that now matters more because more roles consume the same facts.

---

## 3. Shared concepts — extract now vs later

| Concept | Status | Recommendation |
|---------|--------|----------------|
| **Halaqa day readiness** | Extracted (W6) | Keep as academy-wide owner; do not fork |
| **Academy events + sink** | Extracted (W4/W5) | Keep; retire legacy composers when safe |
| **AttendancePolicy** | Shared, under-adopted | Category A: migrate bypass sites when touching those files |
| **Assignment “current/latest” policy** | Missing | Category A extract before any new homework consumer |
| **Operational day reads port** | Missing | Teacher + supervisor duplicate `_readinessFor` I/O — extract thin shared port (not new rules) |
| **User display-name lookup** | Duplicated (supervisor + notifications handler) | Category A shared helper |
| **Week-start / weekday labels** | Fragmented | Category A glossary + single helpers |
| **HalaqaWeeklySessionsMapper location** | Data layer imported by domain | Category A: move behind a domain port |

**Do not extract into “platform services” prematurely:** chat, payments, audio — still product-blocked or incomplete.

---

## 4. Category A — workflow / product debt (travel with future workflows)

| ID | Item | Why it belongs with future work |
|----|------|----------------------------------|
| **A-W6-1** | Extract shared operational-reads port for readiness I/O | Protects teacher + supervisor from drift |
| **A-W6-2** | `AssignmentPolicy` / single latest-due query owner | Any W7+ that touches homework must not add a 5th copy |
| **A-W6-3** | Migrate calendar-day call sites to `AttendancePolicy` | Especially if W7 touches absence dates |
| **A-W6-4** | Delete or quarantine legacy absence/homework notification composers once unused | Prevents dual delivery stories |
| **A-W6-5** | Move weekly-sessions derivation behind a domain port | Fixes teacher/supervisor → schedule/data import |
| **A-W6-6** | Terminology / glossary pass (تكليف vs واجب, تسميع vs تقييم) | UX consistency; not a workflow by itself |
| **A-W6-7** | Live already-reviewed eval → event (W5 residual) | Only if product wants parity with pending→reviewed |
| **A-W6-8** | Supervisor escalation + Firestore read permissions honesty | Client gates exist; server rules are Category B |

Category A items may join W7 **only when they directly protect that workflow**.

---

## 5. Category B — platform / release readiness (does not gate W7)

| ID | Item | Current state (**Verified**) |
|----|------|------------------------------|
| **B-R1** | `firestore.rules` | Absent from repo |
| **B-R2** | `storage.rules` | Absent from repo |
| **B-R3** | `firebase.json` deploy wiring | FlutterFire block only — indexes/rules not deployable from source as a full stack |
| **B-R4** | Composite index completeness | Partial; live queries historically created via console |
| **B-R5** | CI | No `.github/workflows` |
| **B-R6** | Reproducible deploy docs | Blocked by missing rules |
| **B-R7** | App Check posture | Not evidenced in repo |
| **B-R8** | At-most-once academy-event publish | Client publish-after-commit; no durable retry |
| **B-Storage** | Audio uploads / Blaze | `audioUploadsEnabled = false` |

**Platform Epic P-E1** (logout + singleton identity reset for parent/supervisor/admin): track separately from W7. High trust value; wrong shape for a business workflow Phase 0.

---

## 6. Re-ranked remaining **business** workflows (current product value)

Ranking criteria: closes a real academy loop · reuses W1–W6 facts · backend readiness · avoid Category B · maintainability · does not invent parallel ownership.

| Rank | Candidate | Product value now | Dependency | Backend ready? | Reuse of W1–W6 | Maintainability | Notes |
|------|-----------|-------------------|------------|----------------|----------------|-----------------|-------|
| **1** | **استئذان / Absence Request lifecycle** | **High** — unexplained vs excused absence is unfinished academy ops | Builds on W2 marks + W4 signals | Partial (write exists; no UI/approve) | High | Good if request stays fact-driven | Closes orphan since W2 D3 |
| 2 | Teacher ↔ parent operational messaging | Medium–High — helps coordination after W6 guidance | Chat policy / reachability | Partial | Medium | Risky if it becomes a chat product | Useful; not the biggest broken loop |
| 3 | Awards / encouragement coherence (teacher + supervisor) | Medium | Existing awards + supervisor issue | Mostly ready | Medium | Terminology debt | Polish, not critical path |
| 4 | Admin operational console | Medium commercially | Admin stubs | Low UI | Low event reuse | Poor until rules (B) | Premature as W7 |
| 5 | Live-eval → academy event residual | Low–Medium | W5 pipeline | Ready for small slice | High | Good | Better as Category A on a homework/absence touch than a full Wn |
| — | Student audio submit | High when unblocked | Storage / Blaze | **Blocked (B)** | Existing submit path | Neutral | Not a product workflow until infra |
| — | Payments | High commercially | Cloud Function | **Blocked** | Low | Poor | Not W7 |
| — | P-E1 logout / identity reset | **High trust** | Auth + DI reset | Ready | Protects W4–W6 consumers | Improves | **Platform Epic — not W7** |

### Recommended W7 — Parent Absence Request (استئذان) Lifecycle

**One sentence:** Let a parent submit an excused-absence request against the same attendance day facts W2/W4 already own, and let the responsible teacher (guidance path for supervisor later) resolve it — without a second attendance SSOT.

**Why this is the highest-value business workflow now (not the old roadmap):**

1. **Product hole, not infrastructure theater.** After W4, parents *learn* about absence but still cannot *act* inside the academy’s excused-absence ritual. That is an incomplete business loop, visible in production intent since W2 D3.  
2. **Natural extension of owned facts.** Requests should reference calendar day + student + halaqa already governed by `AttendancePolicy` / attendance documents — not invent “supervisor attendance.”  
3. **Complements W6 without violating Rule 6.** Supervisor oversight already surfaces attendance gaps; استئذان gives the *parent* a proper write path and the *teacher* ownership of resolution. Escalation stays guidance.  
4. **Backend not Category-B-blocked.** Unlike audio/payments, the collection/API shape already exists as an orphan — W7 is product completion, not platform invention.  
5. **Previous roadmap is outdated.** Post-W5 ranked session integrity as W6; product correctly shipped Supervisor Oversight as W6 and parked logout as P-E1. Ranking must follow **current** gaps: unfinished absence intent > shared-device hygiene-as-workflow > blocked commercial features.

**Explicitly not W7:** P-E1 logout, Storage/audio, payments, admin console, inventing supervisor write clones.

**Suggested Category A companions if W7 is approved:** A-W6-3 (day boundaries on request dates), clear fact vs presentation split for request status, no parallel notification mechanism (prefer academy events if signals are needed).

---

## 7. Audit deliverables checklist

| Requested | Location |
|-----------|----------|
| Whole-product view after W1–W6 | §0–§1 |
| Cross-workflow inconsistencies | §2 |
| No duplicated rules / parallel ownership check | §2.1–§2.3 |
| Shared concepts to extract | §3 |
| Re-rank remaining business workflows | §6 |
| Category A vs Category B | §4–§5 |
| W7 recommendation + justification | §6 |

---

## 8. Stop gate

**Do not start W7 Phase 0 until product approves:**

1. This audit’s Category A / B / P-E1 separation  
2. **W7 = Parent Absence Request (استئذان) Lifecycle** (or an explicit alternate)  
3. Confirmation that **P-E1 remains a Platform Epic**, not W7  

**No implementation. No commits. No pushes.**
