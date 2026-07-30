# H2 — Day & Homework SSOT Validation

**Status:** Implemented · awaiting product approval before H3  
**Date:** 2026-07-30  
**Scope:** Slice H2 only (`docs/PRODUCTION_HARDENING_PHASE0.md`)  
**Out of scope:** H3+, Category B, new product workflows

---

## Intent

One calendar-day owner and one latest-assignment owner for W1/W3/W5/W6, without changing product behavior.

| Item | Delivery |
|------|----------|
| **A-H2** | `AssignmentPolicy` — shared latest-due query fields + `limit(1)` |
| **A-H3** | Hot paths use `AttendancePolicy.dayStart` / `isSameCalendarDay` |
| **A-H12** | Single `AssignmentHomeworkFieldsEnsure` (legacy seed; write-on-read retained for parity) |
| **A-H13** | `HalaqaWeeklySessionsMapper` moved to schedule **domain** |
| **A-H14** | Shared `loadHalaqaDayReadiness` for teacher agenda + supervisor board |

---

## What shipped

### Shared owners

| Owner | Path |
|-------|------|
| AssignmentPolicy | `lib/shared/domain/assignment_policy.dart` |
| AttendancePolicy (existing) | hot-path call sites migrated |
| AssignmentHomeworkFieldsEnsure | `lib/shared/data/assignment_homework_fields_ensure.dart` |
| HalaqaWeeklySessionsMapper | `lib/features/schedule/domain/mappers/` |
| loadHalaqaDayReadiness | `lib/shared/domain/load_halaqa_day_readiness.dart` |

### Call sites updated

- Student / homework / teacher datasources → `AssignmentPolicy` + shared ensure
- `GetTodayAgendaUseCase` / `GetSupervisorDayBoardUseCase` → domain mapper + shared readiness loader
- Teacher attendance / assign sheet, parent week start, notifications date labels, student schedule labels → `AttendancePolicy`

### Explicitly unchanged product behavior

- Projector gap order and empty-roster homework skip
- Latest assignment = `orderBy(dueDate, desc).limit(1)` (student- or halaqa-scoped)
- Legacy empty-`tasks` docs still repaired via merge-write on get/watch
- Teacher agenda still hides complete items; supervisor board still lists all + teacher names
- Due-date end-of-day `23:59:59` for assign sheet unchanged

---

## Regression tests

| Suite | Result |
|-------|--------|
| `test/shared/h2_day_homework_ssot_test.dart` | Pass |
| `test/shared/load_halaqa_day_readiness_test.dart` | Pass |
| `test/shared/halaqa_day_readiness_test.dart` | Pass |
| `test/features/teacher/get_today_agenda_usecase_test.dart` | Pass |
| `test/features/supervisor/get_supervisor_day_board_usecase_test.dart` | Pass |
| `test/features/schedule/halaqa_weekly_sessions_mapper_test.dart` | Pass |
| `test/shared/attendance_policy_register_complete_test.dart` | Pass |
| `test/features/teacher/teacher_day_closeout_test.dart` | Pass |
| `test/features/supervisor/supervisor_day_board_presentation_test.dart` | Pass |

---

## Stop gate

**H2 complete for review.** Do **not** start H3 until product approves.
