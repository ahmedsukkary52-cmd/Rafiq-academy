# H6 — Surface Cleanup Validation

**Status:** Approved (product)  
**Date:** 2026-07-31  
**Scope:** Slice H6 only (`docs/PRODUCTION_HARDENING_PHASE0.md`) — **A-H8**, **A-H9**, **A-H16**, **A-H17**  
**Out of scope:** H7 awards schema, wiring posts/analytics/calendar as product features, admin console UI, supervisor report inbox, Category B

---

## Intent

Delete or quarantine orphan / misleading presentation surfaces without changing W1–W8 behavior.

| Item | Delivery |
|------|----------|
| **A-H8** | Removed orphan routes (student history, teacher analytics/calendar/content); deleted unregistered `ChatConversationsPage` |
| **A-H9** | Documented AdminBloc non-admit writers as quarantined; admin home must not wire them |
| **A-H16** | Hid supervisor “رفع تقرير” UI; write stack remains ops-only (no in-app reader) |
| **A-H17** | Removed teacher posts placeholder tab; `PostsListPage` stays unwired / quarantined |

---

## Preserved W1–W8 surfaces

| Surface | Status |
|---------|--------|
| Teacher day / halaqa / attendance / evaluations / awards / chat | Live |
| Student content library (`/student/content`) | Live (not an orphan) |
| Live chat (`TeacherMessagesTab` / `StudentChatPage` / `ChatRoomPage`) | Live |
| Supervisor day board, achievement issue, W8 register student | Live |
| Admin home free of stats/finance/complaints/broadcast UI | Preserved (A-H9 quarantine) |
| Parent استئذان / notifications | Live |
| Academy event sink pipeline | Untouched |

---

## What shipped

| Change | Path / note |
|--------|-------------|
| Orphan routes removed | `lib/core/router/router_app.dart` |
| Inventory + contracts | `lib/shared/hardening/h6_surface_cleanup.dart` |
| ChatConversationsPage deleted | Was never registered |
| TeacherPostsTab deleted | Removed from teacher bottom nav |
| Supervisor report UI removed | `supervisor_home_page.dart` |
| Quarantine banners | `PostsListPage`, `AnalyticsDashboardPage`, `CalendarPage`, `AdminBloc`, `AdminHomePage`, `submitReport` |
| DI hygiene | `RegisterNewStudentUseCase` config restored to `SupervisorRepository` (pre-existing mismatch vs committed usecase) |
| Feature trees kept (DI) | analytics / calendar / posts / ChatConversationsBloc for live chat — not product-wired |

---

## Regression tests

| Suite | Result |
|-------|--------|
| `test/shared/h6_surface_cleanup_test.dart` | Pass |
| `test/features/admin/admin_ops_broadcast_test.dart` | Pass (H3 quarantine still locked) |

---

## Stop gate

**H6 approved.** H7 (awards schema coherence) may proceed.
