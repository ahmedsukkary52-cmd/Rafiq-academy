# W4 Slice 1 — Absence Awareness Workflow · Production Validation

**Status:** Pass  
**Date:** 2026-07-26  
**Design:** `docs/W4_PHASE0_DESIGN.md` · Pre-Slice: `docs/W4_PRESLICE_PRODUCTION_VALIDATION.md`  
**Scope:** Slice 1 only — attendance emits business events, first consumer projects them in-app, parent can observe. No FCM/SMS/email, no new collection, no Category B.

---

## 1. Workflow delivered

```text
Teacher finalizes the day register
  → attendanceRecords committed atomically (SSOT, unchanged semantics)
      → committed status transitions derived (explicit 'absent' only)
          → AcademyEvent published through AcademyEventSink
              → first consumer resolves parents and writes in-app messages
                  → parent sees an unread signal on ParentHome / inbox
```

The weekly report still reads `attendanceRecords` directly. Nothing downstream reads notifications to learn what happened.

---

## 2. Constraint compliance

| # | Slice 1 constraint | Implementation | Result |
|---|--------------------|----------------|--------|
| 1 | Event boundary preserved | `saveDayAttendance` returns `List<AcademyEvent>`; `TeacherRepositoryImpl` publishes through `AcademyEventSink`. The teacher feature imports no notification, FCM, SMS, or email symbol | Pass |
| 2 | Publication is transactional | Events are derived **after** `batch.commit()` from the same pre-read statuses and the same committed records. A failed or partial write throws before derivation, so nothing is published | Pass |
| 3 | Transitions only | `AttendanceAbsenceTransitions.project` emits on `→ absent` and `absent → present/late` only; unchanged states, `late`, unknown, and null emit nothing | Pass |
| 4 | Idempotent | Identical re-save finds `previous == absent`, derives zero events, and performs zero delivery writes. Per-recipient message IDs are deterministic (`{parentId}_{eventId}`), so even a replay cannot duplicate a card | Pass |
| 5 | Responsibility separation | Attendance owns facts; `ParentRepository.getParentIdsByStudentIds` owns relationships; `InAppAcademyEventSink` + `AbsenceSignalComposer` own presentation. Recipient lookup never enters the teacher feature | Pass |
| 6 | Workflow-first | Slice 1 ships the whole chain including the parent's ability to observe; the in-app channel is one consumer of the event | Pass |

---

## 3. What changed

| Layer | Change |
|-------|--------|
| Attendance (teacher) | `saveDayAttendance` returns committed academy events; repository publishes them; `AttendanceSaveResult` reports event count + publication state |
| Shared | `AttendanceAbsenceTransitions.previousStatusByStudent` — raw pre-save statuses, deterministic doc wins over legacy duplicate; `NoOpAcademyEventSink` removed |
| Delivery | `InAppAcademyEventSink` (first consumer), `AbsenceSignalComposer` (pure copy/identity), `NotificationsRemoteDatasource.upsertSignals` (deterministic IDs, batched) |
| Parent | `/parent/notifications` route, notification watcher on `ParentHomePage`, unread badge |
| Notifications | `attendance` type icon; null-safe `createdAt`; singleton bloc clears state on identity change |

`AttendanceRecordModel.wireStatus` exposes the exact persisted status string, so the projector never re-derives a status or inherits the model's unknown → absent read mapping.

---

## 4. Decisions honored

| ID | Decision | Implementation |
|----|----------|----------------|
| D-W4-1 | Every linked parent | One message per resolved parent, each with its own read state |
| D-W4-2 | Explicit `absent` only | `isExplicitAbsent`; `late` stays attended |
| D-W4-3 | Transition + deterministic identity | Projector + `{parentId}_{eventId}` |
| D-W4-4 | Correction updates the same signal | Same document ID; content replaced; `readBy` reset so it returns as unread |
| D-W4-6 | Historical edits signal too | Derivation uses the record's own date, not today |
| D-W4-7 | In-app only | Copy says nothing about phone push |
| D-W4-8 | Reuse `NotificationsPage` | Parent route + badge only; no second inbox |
| D-W4-9 | `absenceRequests` dormant | Untouched |
| D-W4-10 | Neutral Arabic copy | Verified by composer tests |

### D-W4-5 superseded (needs acknowledgement)

Phase 0 recommended **fail closed before any write** if recipient resolution errors. Slice 1 constraint 2 makes the attendance write the primary operation and requires events to describe a *successful* save, so resolution can no longer run before the commit without attendance depending on recipients (constraint 5).

**Implemented instead:** attendance commits first and stays valid; if publication fails the register is still saved and the teacher is told plainly — «تم حفظ الحضور، لكن تعذّر نشر تحديثات الغياب». It is surfaced, not silent.

**Architectural limitation (formalized Slice 2):** event delivery on this client path is **at-most-once**. An identical re-save correctly emits no events, so a failed publication is not repaired by retry. Classified as **Category B – Platform Hardening (B-R8)**; eventual outbox / server trigger / event queue — **not W4**. See `docs/W4_PHASE0_DESIGN.md` and `docs/POST_W3_PRODUCT_AUDIT.md` §5.2.

---

## 5. Gates

| Gate | Result |
|------|--------|
| `flutter test` | 88 tests pass |
| New Slice 1 tests | Composer (8), sink (6), repository publication (6), pre-save status mapping (4) |
| `flutter analyze` | No new issues; repository baseline unchanged |
| `dart format` | Clean |
| Firestore collections | `attendanceRecords`, `parentProfiles`, `notifications` — no new collection, no new attendance field |
| New composite index | None (`childrenIds arrayContainsAny` is single-field; the inbox query already existed) |

---

## 6. Deferred, unchanged

- OS push / SMS / email / WhatsApp — add a sink, do not touch attendance.
- `absenceRequests` (استئذان) lifecycle and any `excused` status.
- Category B Release Readiness. Note **B-R1**: the client writes notification `audience`; the missing security rules remain a release-readiness risk, not a W4 deliverable.
- Category A: UI roster vs raw `halaqa.studentIds` divergence (G13) — untouched, no second completeness flag invented.

**Stop:** awaiting approval before Slice 2.
