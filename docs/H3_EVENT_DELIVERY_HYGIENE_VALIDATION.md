# H3 — Event Delivery Hygiene Validation

**Status:** Implemented · awaiting product approval before H4  
**Date:** 2026-07-31  
**Scope:** Slice H3 only (`docs/PRODUCTION_HARDENING_PHASE0.md`)  
**Out of scope:** H4+, B-FCM productization, durable outbox (B-R8), new product notifications

---

## Intent

One academy-event sink story before FCM; isolate non-academy writers; remove false FCM readiness — without changing W1–W8 delivery behavior.

| Item | Delivery |
|------|----------|
| **A-H4** | Confirmed single sink story; docs/comments frozen (legacy composers already deleted in W5) |
| **A-H15** | Admin broadcast quarantined as ops channel (`AdminOpsBroadcast`) — **not** routed through sink |
| **A-H19** | `FirebaseMessaging` removed from DI (package kept for future B-FCM) |

---

## Canonical academy pipeline (unchanged)

```text
TeacherRepositoryImpl._publishAfterCommit
  → FanOutAcademyEventSink
    → InAppAcademyEventHandler (name: in_app)
      → InAppAcademySignalComposer
      → NotificationsRemoteDatasource.upsertSignals
```

DI: `DiModule.academyEventSink` registers **only** `[InAppAcademyEventHandler]`.

---

## What shipped

| Change | Path / note |
|--------|-------------|
| Sole-sink DI docs | `lib/core/di/di_module.dart` |
| A-H19 | Removed `FirebaseMessaging` provider from `DiModule` + generated config |
| A-H15 quarantine | `lib/features/admin/domain/admin_ops_broadcast.dart` + datasource uses it |
| Comment hygiene | `HomeworkReviewed` live-path note; fan-out / in-app handler docs |
| Phase 0 inventory | A-H4 evidence corrected (legacy types already gone) |

### Explicitly unchanged

- Teacher publish-after-commit behavior and unpublished degradation
- Composer copy / deterministic signal ids
- Admin broadcast write shape (`audience` / `readBy` / `type: general` / `.add`)
- No FCM handlers, tokens, or OS push
- No new AcademyEvent kinds

---

## Regression tests

| Suite | Result |
|-------|--------|
| `test/shared/h3_event_delivery_hygiene_test.dart` | Pass |
| `test/features/admin/admin_ops_broadcast_test.dart` | Pass |
| `test/shared/fan_out_academy_event_sink_test.dart` | Pass |
| `test/features/teacher/attendance_event_publication_test.dart` | Pass |
| `test/features/notifications/in_app_academy_signal_composer_test.dart` | Pass |
| `test/shared/academy_event_observation_test.dart` | Pass |
| `test/shared/academy_event_publication_test.dart` | Pass |
| `test/features/parent/default_academy_event_observer_resolver_test.dart` | Pass |

---

## Stop gate

**H3 complete for review.** Do **not** start H4 until product approves.
