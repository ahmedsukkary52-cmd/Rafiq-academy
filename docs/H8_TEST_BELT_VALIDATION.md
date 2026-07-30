# H8 — Test Belt Validation

**Status:** Implemented · awaiting product approval before any further work  
**Date:** 2026-07-31  
**Scope:** Slice H8 only (`docs/PRODUCTION_HARDENING_PHASE0.md`) — **A-H11** incremental  
**Out of scope:** H9 analyze polish, Category B release readiness, new product features, bloc widget tests, Firebase integration tests

---

## Intent

Close the highest-value critical-path test gaps so admit, attendance save, homework assign, استئذان review, and router allowlists cannot regress silently.

| Item | Delivery |
|------|----------|
| **A-H11** | Pure unit tests for admit / register / attendance save / assign / router guards; re-run existing استئذان review + submit |

---

## What shipped

| Area | Path |
|------|------|
| Router allowlist extract | `AppRouteAccess` in `lib/core/router/router_app.dart` |
| Router / escalation tests | `test/core/app_route_access_test.dart` |
| Admit UC | `test/features/admin/approve_new_student_usecase_test.dart` |
| Supervisor register UC | `test/features/supervisor/register_new_student_usecase_test.dart` |
| Attendance save UC | `test/features/teacher/save_day_attendance_usecase_test.dart` |
| Homework assign UC | `test/features/teacher/send_assignment_usecase_test.dart` |

### Explicitly unchanged

- No product behavior or Firestore write shapes
- Admin home remains Coming Soon (A-H9 quarantine still holds for non-admit writers)
- استئذان review/submit contracts remain as previously tested

---

## Regression suite (H8 belt)

| Suite | Result |
|-------|--------|
| `test/core/app_route_access_test.dart` | Pass |
| `test/features/admin/approve_new_student_usecase_test.dart` | Pass |
| `test/features/supervisor/register_new_student_usecase_test.dart` | Pass |
| `test/features/teacher/save_day_attendance_usecase_test.dart` | Pass |
| `test/features/teacher/send_assignment_usecase_test.dart` | Pass |
| `test/features/teacher/review_absence_request_usecase_test.dart` | Pass |
| `test/features/parent/submit_absence_request_usecase_test.dart` | Pass |

---

## Stop gate

**H8 complete for review.** See also `docs/PRODUCTION_HARDENING_COMPLETION_VALIDATION.md`.  
Do **not** begin H9, Category B, or new product work until product approves.
