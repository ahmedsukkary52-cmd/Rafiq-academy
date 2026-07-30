# W4 Slice 2 — Production Validation & Workflow Closure

**Status:** Pass  
**Date:** 2026-07-26  
**Design:** `docs/W4_PHASE0_DESIGN.md`  
**Predecessors:** Pre-Slice Pass · Slice 1 Pass  

**Scope:** Validate the absence-awareness workflow end to end; document Category B at-most-once publication; close Category A identity leak on logout. **No new delivery channels. No outbox. No Category B implementation.**

---

## Executive summary

| Area | Verdict |
|------|---------|
| Ownership: Attendance → Events → Sinks → UI | **Pass** |
| Transition / recipient / composition duplication | **Pass** — no second rule found; cross-refs tightened |
| At-most-once publication limitation | **Pass** — documented as **B-R8** (Category B); not solved in W4 |
| Logout / account switch inbox identity | **Pass** after Fix — `StopWatchingNotificationsEvent` on `AuthUnauthenticated` |
| Transition matrix (unit) | **Pass** |
| Recipient / multi-parent / no-parent (unit) | **Pass** |
| Sink + repository publication (unit) | **Pass** |
| Parent surface composition | **Pass** |
| W1 / W2 / W3 regression suite | **Pass** (88 → 88+ suite green) |
| Analyze / format | **Pass** (no new issues) |

---

## 1. Architectural limitation (must not be “fixed” in W4)

### Classification

| Field | Value |
|-------|-------|
| ID | **B-R8** |
| Category | **B — Platform Hardening / Release Readiness** |
| Name | At-most-once academy-event delivery after attendance save |
| In W4? | **No** |

### Verified chain

```text
attendance batch.commit succeeds
  → transitions derived from that successful operation
      → AcademyEventSink.publish fails (network / recipient / write)
          → AttendanceSaveResult.eventsPublished = false (teacher informed)
              → identical re-save → zero transitions (correct idempotency)
                  → publish never retried
```

Attendance behavior is correct. Delivery is **at-most-once**.

### Eventual platform solutions (not client)

- Transactional outbox
- Server-side trigger on `attendanceRecords`
- Event queue

**Rejected for W4:** client-side re-derive-on-retry, second “pending notification” collection invented in the app, or coupling attendance rollback to sink failure.

---

## 2. Ownership audit (Slice 2 constraint)

| Concern | Owner | Leak found? |
|---------|-------|-------------|
| Attendance facts / SSOT write | Teacher datasource + `attendanceRecords` | No |
| Status transitions → `AcademyEvent` | `AttendanceAbsenceTransitions` only | No |
| Publish port | `AcademyEventSink` | No |
| Parent relationships | `ParentRepository.getParentIdsByStudentIds` + `ParentRecipientResolver` | No |
| In-app presentation | `AbsenceSignalComposer` + `InAppAcademyEventSink` | No |
| Parent UI projection | `ParentHomePage` + shared `NotificationsPage` | No |

**Refactors applied (minimal):**

1. Logout clears singleton inbox (`StopWatchingNotificationsEvent`) — Category A G6, protects W4 parent surface.
2. Publication-failure snackbar made channel-neutral (does not name “أولياء الأمور” as if attendance knew the channel).
3. Docs: stale `isAbsentStatus` SSOT claim corrected; Phase 0 + audit B-R8 formalized.
4. Cross-reference comments between `uniqueDayStatuses` and `previousStatusByStudent` (same win rule, different shapes — not merged; fewer abstractions).

**Explicitly not refactored:** assignment/recitation inline notification writes in teacher datasource (pre-W4 dual path; out of absence workflow scope).

---

## 3. Scenario matrix

Legend: **Pass** / **Pass (code+unit)** / **Accept (B-R8)** / **Fail→Fixed**

### Transitions & idempotency

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| T1 | First save → explicit absent | `StudentAbsentRecorded` once | **Pass (code+unit)** |
| T2 | Identical re-save (still absent) | No events; no delivery write | **Pass (code+unit)** |
| T3 | Absent → present | `StudentAbsenceCorrected`; same delivery id | **Pass (code+unit)** |
| T4 | Absent → late | Correction; late wording | **Pass (code+unit)** |
| T5 | Late / present without prior absent | No absence event | **Pass (code+unit)** |
| T6 | Unknown / null never treated as absent | No false signal | **Pass (code+unit)** |
| T7 | Historical editable date | Event uses record date, not “today” | **Pass (code+unit)** |

### Recipients & delivery

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| R1 | No linked parent | Attendance saves; zero signals | **Pass (code+unit)** |
| R2 | One parent | One deterministic message | **Pass (code+unit)** |
| R3 | Multiple parents | One message each; separate read state | **Pass (code+unit)** |
| R4 | Multiple children in one batch | Resolve once; address only affected | **Pass (code+unit)** |
| R5 | Recipient lookup failure | Publish throws; register already saved; teacher warned | **Pass (code+unit)** |
| R6 | Publish failure then identical re-save | No automatic repair | **Accept (B-R8)** |

### Separation

| # | Check | Result |
|---|-------|--------|
| S1 | Teacher feature has no notification/FCM/SMS imports for absence path | **Pass** |
| S2 | Sink is only delivery join point for absence events | **Pass** |
| S3 | Weekly report still reads `attendanceRecords` | **Pass** |
| S4 | Future channel = new sink, not attendance change | **Pass** (design + DI port) |

### Parent surface

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| P1 | Parent home starts watcher with `AppRoles.parent` | **Pass** |
| P2 | Unread badge + `/parent/notifications` | **Pass** |
| P3 | Inbox loading / empty / error retry | Reuses `NotificationsPage` | **Pass** |
| P4 | Mark read / mark all read | Existing bloc path | **Pass** |
| P5 | Logout clears inbox identity | Stop event + stale snapshot ignore | **Fail→Fixed** |
| P6 | Account switch starts fresh watch | Identity-changed reset + restartable | **Pass** |

---

## 4. Gates

| Gate | Result |
|------|--------|
| `flutter test` | Pass |
| `flutter analyze` | No new issues vs baseline |
| `dart format` (touched) | Clean |
| New collections / attendance fields | None |
| Category B implementation | None (B-R8 documented only) |

---

## 5. Definition of Done (W4 product scope)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Attendance remains SSOT | **Pass** |
| 2 | Explicit absent transitions only | **Pass** |
| 3 | Idempotent re-save | **Pass** |
| 4 | Corrections update same signal | **Pass** |
| 5 | Attendance independent of delivery implementation | **Pass** |
| 6 | In-app channel only; weekly report unchanged | **Pass** |
| 7 | No-parent / multi-parent honest | **Pass** |
| 8 | No new collection | **Pass** |
| 9 | `absenceRequests` dormant | **Pass** |
| 10 | Platform Hardening not absorbed | **Pass** (B-R8 tracked) |
| 11 | Parent loading/empty/error/retry + account switch | **Pass** |
| 12 | Tests / analyze / format / docs / commit / push | **Pass** |

---

## 6. Stop

**Slice 2 = Pass.** W4 client workflow is complete.

Remaining: product owner acknowledgement that **B-R8** stays on the Release Readiness track and will not be patched with client-side delivery logic inside W4.
