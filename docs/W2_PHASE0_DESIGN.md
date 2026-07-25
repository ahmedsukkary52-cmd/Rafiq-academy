# W2 — Attendance Loop  
## Phase 0 Technical Design (Investigation Only — No Implementation Yet)

**Status:** Approved (D1–D8). Implementation in progress.  
**File key / Figma:** Basma (Copy) — teacher/parent frames as **UI reference only** (not business logic).  
**Architecture:** Feature-first Clean Architecture + BLoC + Firestore SSOT (`attendanceRecords`)  
**Predecessor:** W1 Done (`docs/W1_PRODUCTION_VALIDATION.md`)

### Permanent rule (during implementation)

If a previous slice or design assumption is found incorrect: **stop**, explain, update this design, then continue. Never build on a known flawed foundation.

---

## 0. Goal (workflow, not screens)

Complete the academy **attendance loop**:

**Teacher marks the day’s register → records are honest SSOT → Student/Parent see consistent attendance → (optional later) absence awareness / supervisor oversight.**

Optimize for long-term maintainability and product value — reuse existing teacher register + parent weekly + student progress report before inventing modules.

---

## 1. Existing architecture

### 1.1 End-to-end map (current)

```text
TeacherClassDetail «الحضور» (link only)
        │
        ▼
TeacherAttendancePage ──► SaveDayAttendanceEvent
        │                      (sequential RecordAttendanceUseCase per student)
        ▼
TeacherRemoteDatasource.recordAttendance
        │  normalize date → dayStart midnight
        │  upsert: query halaqaId+studentId+date range → update OR .add()
        ▼
Firestore `attendanceRecords`
  { studentId, studentName, halaqaId, date, status, recordedBy }
  status ∈ { present | absent | late }
        │
        ├──► ParentHomePage weekly report
        │      attendedSessions = count(status == 'present')   ← late EXCLUDED
        │      totalSessions    = all attendance docs in week
        │
        ├──► StudentProgressReportPage (30 days)
        │      attendanceDays = present OR late               ← late INCLUDED
        │      absenceDays    = absent
        │
        ├──► AnalyticsDashboardPage (halaqa)
        │      % typically present-only (verify on implement)
        │
        └──► Admin getTeacherActivityLog (recordedBy) — no UI

Parent absenceRequests write path exists (SubmitAbsenceRequestUseCase)
        └──► Firestore `absenceRequests` — NO list/approve UI, NO readers
```

### 1.2 Inventory by layer

| Layer | Piece | Role in W2 |
|-------|--------|------------|
| **Routes** | `/teacher/attendance/:halaqaId` | Teacher day register — **primary write UI** |
| | `/teacher/halaqa/:halaqaId` | Class detail — nav stub «فتح سجل الحضور» |
| | `/teacher/halaqa/:halaqaId/analytics` | Read aggregates |
| | `/parent` | Weekly report attendance metrics |
| | `/student/progress-report` | 30-day attendance slice |
| **UI** | `TeacherAttendancePage` | Day picker, P/A/L mark, save all |
| | `ParentHomePage` weekly card | attended / total / % |
| | `StudentProgressReportPage` | attendanceDays / absenceDays / % |
| | Class detail attendance tab | **Link only** |
| **Blocs** | `TeacherBloc` | Load day, SaveDayAttendance, unused RecordAttendanceEvent |
| | `ParentBloc` | GetWeeklyReport; unused SubmitAbsenceRequestEvent |
| | `ProgressReportBloc` | Load progress report |
| **Use cases** | `RecordAttendanceUseCase` | ✅ Upsert one student |
| | `GetHalaqaAttendanceForDateUseCase` | ✅ Day load |
| | `GetWeeklyReportUseCase` | ✅ Includes attendance |
| | `SubmitAbsenceRequestUseCase` | ✅ Write-only; **no UI** |
| **Repos / DS** | `TeacherRemoteDatasourceImpl.recordAttendance` | Upsert by day range |
| | `ParentRemoteDatasourceImpl.getWeeklyReport` | Week window query |
| | `ProgressReportRemoteDatasourceImpl` | 30-day query |
| **Models** | `AttendanceRecordEntity` / `Model` | Exact Firestore keys below |
| | `AttendanceStatus` | present / absent / late |
| | `AbsenceRequestEntity` | pending / approved / rejected — unused in UI |
| **Firestore** | `attendanceRecords` | SSOT marks |
| | `halaqat.studentIds` | Roster |
| | `absenceRequests` | Orphan write path |
| | `users` | Names on roster |
| **Dead / unused** | `RecordAttendanceEvent` optimistic path | No UI dispatch |
| | `HalaqaStudentSummaryEntity.todayAttendance` / `attendancePercent` / `isAtRisk` | Never populated for display |
| | Admin activity log UI | Backend only |
| | Supervisor attendance | **None** |

### 1.3 Firestore document shape (Verified)

**`attendanceRecords`**

| Field | Type | Notes |
|-------|------|-------|
| `studentId` | string | |
| `studentName` | string | Denormalized at write |
| `halaqaId` | string | |
| `date` | Timestamp | Normalized to local midnight on write |
| `status` | string | `'present'` \| `'absent'` \| `'late'` |
| `recordedBy` | string | Teacher uid |

**Logical key (Inference from code):** `(halaqaId, studentId, calendar day)` via range query — **not** a deterministic document ID.

**`absenceRequests`** (exists; out of minimal W2 unless approved)

| Field | Values |
|-------|--------|
| `studentId`, `requestedBy`, `date`, `reason` | |
| `status` | pending / approved / rejected |
| `reviewedBy` | optional |

### 1.4 Day / session semantics (Verified in code)

- Teacher UI normalizes to `DateTime(y,m,d)`; max today; min today−30 days.
- One upsert attempt per student per calendar day per halaqa.
- Halaqa **schedule slots** exist elsewhere for labels/meetings — **not linked** to `attendanceRecords` today.
- **No new collection required** to keep calendar-day register (reuse current model).

---

## 2. Real academy workflow (research)

Sources: Islamic maktab/halaqa platforms + online Qur’an academy ops + KSA-style استئذان patterns. Used to **frame decisions**, not invent Rafiq rules.

| Practice | Classification |
|----------|----------------|
| Teacher manual register is source of truth | **Verified** |
| Statuses: Present / Late / Absent (+ often Excused) | **Verified** |
| Parent notified on absence | **Verified** |
| Supervisor cares about unmarked registers + trends | **Verified** |
| Part-time halaqa ≈ one register per meeting date | **Verified** |
| Online: scheduled slot + advance notice for excuse/makeup | **Verified** |
| استئذان within ~2–3 days after absence alert (KSA schools) | **Verified** |
| Late counts as “attended” in weekly % | **Inference** (varies by academy) |
| Student “join Zoom” = attendance | **Inference — do not assume** |
| Auto-attendance from meeting duration | **Do not invent** without approval |
| Billing/makeup engines | **Out of W2** unless approved |

---

## 3. Figma (UI reference only)

- File: [Basma (Copy)](https://www.figma.com/design/dvYE9COnQwosOVL3KCJVcp/Basma--Copy-?node-id=0-1) — `dvYE9COnQwosOVL3KCJVcp`
- Role frames: Teacher `2:4394`, Parent `31:4117`, Supervisor `32:9680`, Student `41:4424`
- **Rule:** Figma may inspire layout/copy; **must not** dictate Firestore schema, status set, or late-counting policy.
- AI-generated Figma may duplicate screens — **prefer improving existing** `TeacherAttendancePage` / parent weekly / student progress report over new parallel UIs.

---

## 4. Actors & desired W2 outcomes

| Actor | Today | W2 target (proposed) |
|-------|-------|----------------------|
| **Teacher** | Can mark P/A/L and save for a day | Reliable mark/save (atomic), clear empty/error/reload, consistent reload after save |
| **Student** | Progress report 30-day stats | Same formula as parent policy (after D-late decision) |
| **Parent** | Weekly attended/total (present-only) | Honest, consistent definition of “attended”; no fake screens |
| **Supervisor** | No attendance surface | **Out of W2** unless product expands scope |
| **Admin** | Activity log API only | **Out of W2** unless product expands scope |

---

## 5. Workflow gaps

| ID | Gap | Why it matters | Reuse | Minimal add | Category |
|----|-----|----------------|-------|-------------|----------|
| **G1** | **Late counting inconsistent** | Parent weekly excludes `late`; student progress includes `late` as present-like | Same `attendanceRecords` | One shared rule / helper for “attended?” | **Product decision** (D1) |
| **G2** | **SaveDayAttendance not atomic** | Sequential upserts; first failure leaves partial day written | `recordAttendance` | Batch write or all-or-nothing transaction strategy | **Verified** tech debt |
| **G3** | **Upsert needs composite index** | Query `halaqaId + studentId + date` range | Existing upsert | Add index to `firestore.indexes.json` | **Verified** |
| **G4** | **Duplicate docs possible** | Auto-ID `.add()` if upsert query fails / races | Upsert path | Prefer deterministic doc id OR stronger unique constraint | **Inference** risk |
| **G5** | **Dead optimistic `RecordAttendanceEvent`** | Two mental models; unused | Batch save UI | Delete or wire — prefer delete to avoid dual paths | **Verified** |
| **G6** | **Class summary fields unused** | `todayAttendance` / at-risk never shown | Entity fields | Optional display after day load — only if useful | **Inference** |
| **G7** | **No absence notification** | Parents often expect alert when marked absent | W1 notification writer pattern | Optional writer on save when status=absent | **Product decision** (D2) |
| **G8** | **Absence request stack orphaned** | Write API + no UI + no approver | `absenceRequests` | **Defer** unless D3 chooses استئذان | **Product decision** (D3) |
| **G9** | **No “register submitted” signal** | Supervisor ops need unmarked days | Could derive: roster size vs records for date | Optional later | **Out of W2** unless D4 |
| **G10** | **Denominator honesty** | `totalSessions` = docs written, not scheduled meetings | Weekly report | Document as Verified current behavior; changing = product | **Product decision** (D5) if change |
| **G11** | **No `excused` status** | Common in industry; not in enum | Would need schema + UI | Only if D6 = Yes | **Product decision** (D6) |
| **G12** | **Session-slot linkage** | Schedule vs attendance not joined | Halaqa schedule | Keep calendar-day (reuse) unless D7 | **Product decision** (D7) |

---

## 6. Firestore impact (proposed for W2)

### Collections

| Collection | Ops | Justification |
|------------|-----|----------------|
| `attendanceRecords` | R/W (existing upsert) | SSOT — **no new collection** |
| `halaqat` | R | Roster |
| `users` | R | Names |
| `notifications` | C (optional) | Absence notify if D2 = Yes — reuse W1 schema |
| `absenceRequests` | — | **No W2 writes** unless D3 expands scope |
| `parentProfiles` | R | Children link (existing) |

### New fields?

| Proposal | Needed? | Notes |
|----------|---------|-------|
| `excused` status | Only if D6 = Yes | Enum + string value |
| `sessionId` / slot id | Only if D7 = Yes | Prefer **No** for W2 — reuse day key |
| `submittedAt` / `registerComplete` | Optional | Avoid unless supervisor slice approved |
| Deterministic doc id | Recommended hardening | e.g. `{halaqaId}_{studentId}_{yyyyMMdd}` — **no new field**, id strategy only |

### Indexes (must ship with W2)

| Query | Index |
|-------|-------|
| Upsert / day load: `halaqaId` + `studentId` + `date` | Composite (missing in repo today) |
| Day load by halaqa + date range | Composite `halaqaId` + `date` |
| Parent/student by `studentId` + `date` | Already in `firestore.indexes.json` |

---

## 7. Proposed slices (small, releasable, independently useful)

Order mirrors W1: prerequisites first; each slice analyze → format → commit → push → usable.

| Step | Name | Immediately usable? |
|------|------|---------------------|
| **Pre-Slice** | Align attendance policy helpers + indexes (after D1 approved) | Yes — consistent reads even before UI polish |
| **Slice 1** | Harden teacher day register (atomic/safer save, empty/error/retry, remove dead path) | Yes — teachers mark more safely |
| **Slice 2** | Parent weekly attendance honesty (labels + D1 rule) | Yes — parents see truthful week stats |
| **Slice 3** | Student progress report alignment to same rule | Yes — no contradiction across actors |
| **Slice 4** | Optional: absence notification writers (if D2 = Yes) | Yes — inbox already works |
| **Slice 5** | Workflow consistency audit (loading/empty/error/retry/refresh/permissions) | DoD |

### Explicitly **out of W2** unless re-approved

- Supervisor unmarked-register dashboard  
- Full استئذان approve/reject FSM (parent form + admin review)  
- Zoom/meet auto-attendance  
- Makeup / reschedule / billing  
- New Firestore collections  
- Dedicated parent “attendance history” module (weekly report + honesty first; history = later journey)  
- Changing W1 homework behavior  

### Optional later branch

- **W2-Excuse:** Parent استئذان + teacher/admin approve  
- **W2-Supervisor:** Missing registers + at-risk lists  

---

## 8. Risks

| Type | Risk | Mitigation |
|------|------|------------|
| **Technical** | Partial day save | Slice 1: batch / fail-closed messaging |
| **Technical** | Missing indexes → upsert creates duplicates | Ship indexes; prefer deterministic IDs |
| **Product** | Late vs present in % | **D1 must be approved** before Pre-Slice |
| **Product** | Parent expects excused | Defer D6 / W2-Excuse |
| **Security** | No rules in repo | Do not widen client writes; teacher Auth pattern only |
| **Architecture** | Parallel “attendance v2” feature | Forbidden — reuse `RecordAttendance*` + existing pages |
| **Migration** | Historical late docs | Policy flip only changes aggregation, not stored status |

---

## 9. Decision log (approval required)

| # | Decision | Category | Options / recommendation |
|---|----------|----------|---------------------------|
| **D1** | Does **`late` count as attended** for parent weekly + shared “attended” definition? | **Product decision** | **Approved A** — late = attended for **all** actors via `AttendancePolicy` |
| **D2** | Notify student/parent when marked **absent**? | **Product decision** | **Defer** — no notification writers in W2 |
| **D3** | Include **استئذان / absenceRequests** UI in W2? | **Product decision** | **No** — separate workflow later |
| **D4** | Supervisor attendance oversight in W2? | **Product decision** | **No** — Teacher → Student → Parent only |
| **D5** | Weekly `totalSessions` denominator | **Verified** current = count of attendance docs in week (not schedule). Change? | **Keep** — document in UI if needed |
| **D6** | Add **`excused`** status? | **Product decision** | **No** — reuse present/absent/late |
| **D7** | Bind attendance to **schedule slot id**? | **Product decision** | **No** — calendar day only |
| **D8** | Deterministic attendance doc IDs? | **Inference** / engineering | **Yes** — `{halaqaId}_{studentId}_{yyyyMMdd}`; no new fields |

### Decisions that are **not** product (reuse Verified code)

- Teacher statuses today: present / absent / late — **Verified**.  
- Upsert-by-day — **Verified** (Slice 1 upgrades to deterministic id + batch).  
- Parent sees attendance via weekly report (not dedicated screen) for W2 MVP — **Approved**.  
- Figma = UI reference only — standing rule.

---

## 10. Definition of Done (W2)

Per standing rules:

1. **Actors:** Teacher can complete day register reliably; Student + Parent see **the same attended definition** (D1 via `AttendancePolicy`).  
2. **No invented Islamic/ops content**; no fake attendance stats.  
3. **Reuse** existing pages/blocs/use cases — no parallel attendance stack.  
4. **Firestore:** no unjustified new collections/fields.  
5. **States:** loading / empty / error / retry / refresh on teacher register + parent/student read paths.  
6. **Indexes** documented and added for upsert/day queries.  
7. **analyze + format + commit + push** per slice.  
8. **Production validation** (same style as W1) before marking W2 Done.  
9. If a slice assumption is wrong: **stop**, update this doc, then continue.

---

## Approval gate

**Phase 0 approved (D1–D8).** Implementation: Pre-Slice → Slice 1 → 2 → 3 → audit → production validation.  
D2 notifications and D3 استئذان explicitly out of W2.
