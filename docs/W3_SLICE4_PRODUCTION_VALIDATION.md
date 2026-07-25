# W3 Slice 4 — Day Closeout · Production Validation

**Status:** Pass
**Date:** 2026-07-26
**Design:** `docs/W3_SLICE4_PHASE0_DESIGN.md` (approved, D-C1..D-C5 = recommended A)
**Parent:** `docs/W3_PHASE0_DESIGN.md`
**Predecessors:** Pre-Slice + Slice 1 + Slice 2 + Slice 3 production-validated (Pass)

---

## 0. What shipped

A **pure projection** of the already-computed `TeacherDayAgenda` into a three-way
day-closeout signal, plus its calm presentation on the existing dashboard agenda
section. No new I/O, no new persistence, no new business rules.

| Artifact | Change |
|----------|--------|
| `TeacherDayCloseout` + `DayCloseoutStatus` | New read-model value object derived **only** from `TeacherDayAgenda.items` and `sessionsTodayCount` |
| `TeacherDayAgenda.closeout` getter | Pure function: counts only, no readiness math of its own |
| `_CloseoutCard` (dashboard) | Honest idle/done card for `noSession` / `complete` |
| `_CloseoutSummary` (dashboard) | Calm "لم يكتمل عمل اليوم" line + optional `مكتمل X من Y حلقات` above existing agenda cards |
| `teacher_day_closeout_test.dart` | Projection matrix tests |

---

## 1. Constraint compliance (approved gate)

| Constraint | Result | Evidence |
|-----------|--------|----------|
| Pure projection of W1/W2/W3 state | Pass | `closeout` reads only `items` + `sessionsTodayCount` |
| No new business rules | Pass | Status is `if total==0 / items.isEmpty / else`; no readiness logic |
| No new completion criteria | Pass | "Complete" == agenda already dropped all actions (existing rule) |
| No new Firestore reads/writes | Pass | Getter is in-memory; no repository/datasource touched |
| No new persistence | Pass | No fields, no docs, no cache (D8/D10) |
| No new queries or indexes | Pass | `firestore.indexes.json` unchanged |
| No duplicated agenda logic | Pass | Consumes `GetTodayAgendaUseCase` output verbatim |
| No duplicated readiness calculations | Pass | Per-pillar readiness stays inside agenda `items.pendingActions` |
| Derived from already-computed `TeacherDayAgenda` | Pass | Single input object |

## 2. Invariants (single source of truth)

| Invariant | Owner (unchanged) |
|-----------|-------------------|
| Readiness | `GetTodayAgendaUseCase` → `TeacherDayAgenda.items` |
| Attendance completion | `AttendancePolicy.isRegisterComplete` (W2) |
| Homework readiness | `getLatestAssignmentDueDate` + `isSameCalendarDay` (W1/Slice 2) |
| Pending reviews | `RecitationRecordEntity.isPendingReview` (W1) |
| Closeout | **Presentation only** of the above |

Every closeout state is a direct consequence of existing agenda data:

```text
sessionsTodayCount == 0        → noSession
sessionsTodayCount > 0 & empty → complete   (completed = total)
items.isNotEmpty               → incomplete (completed = total - items.length)
```

## 3. Non-functional checks

| Check | Result | Notes |
|-------|--------|-------|
| No additional dashboard rebuilds | Pass | `buildWhen` already gates on `todayAgenda*`; closeout is a getter on the same object — no new listeners/streams |
| No unnecessary Firestore reads | Pass | Zero data-layer changes; agenda still refreshes via existing `LoadTodayAgendaEvent` hooks |
| No duplicated aggregation logic | Pass | Count arithmetic lives once, in the getter |
| No navigation regressions | Pass | Incomplete state reuses existing agenda deep-links (Slices 1–3); closeout adds no routes |
| No W1/W2/W3 regressions | Pass | Full suite green (see §4) |

## 4. Gates

| Gate | Result |
|------|--------|
| `flutter analyze` (touched files) | Clean — only 2 pre-existing `withOpacity` infos in untouched `_TeacherHeader` |
| Tests | 48/48 pass (7 new closeout matrix cases) |
| `dart format` | Clean (0 changed) |

## 5. Wording (D9 / D-C5)

| State | Copy |
|-------|------|
| No session | «لا توجد حصص مجدوَلة اليوم» (kept) |
| Complete | «اكتمل عمل اليوم» (soft closeout reframe) |
| Incomplete | «لم يكتمل عمل اليوم» |
| Incomplete detail (total > 1) | «مكتمل {done} من {total} حلقات» |

No blame, no motivational slogans, no charts/badges/progress bars.

## 6. Notes / minor decisions

- **Fraction shown only for multi-halaqa days** (`totalHalaqat > 1`) to avoid the
  odd single-halaqa phrasing «مكتمل 0 من 1»; a single halaqa already reads its
  status from the one agenda card. Neutral and within D-C2-A.
- `completedHalaqat` is clamped to `[0, total]` defensively; `items` can never
  exceed today's halaqat, but the projection stays total-safe.

**Conclusion:** Slice 4 passes production validation. With Pre-Slice + Slices 1–4
validated, **W3 is complete**.
