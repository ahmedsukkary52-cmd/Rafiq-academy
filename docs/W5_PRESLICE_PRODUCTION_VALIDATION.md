# W5 Pre-Slice — Production Validation

**Status:** Pass (pending product approval before Slice 1)  
**Date:** 2026-07-29  
**Scope:** Event / observer / delivery boundaries only — **no** teacher write migration

## Constraints verified

| Constraint | Result | Evidence |
|------------|--------|----------|
| `AcademyEvent` = domain fact, not notification command | **Pass** | `HomeworkAssigned`, `HomeworkReviewed`, absence events — no `Notify*` types |
| Academy owns what happened | **Pass** | `lib/shared/domain/academy_event.dart` |
| Observer layer owns who should know | **Pass** | `AcademyEventObservation` + `AcademyEventObserverResolver` / `DefaultAcademyEventObserverResolver` |
| Delivery owns how | **Pass** | `InAppAcademyEventSink` + `InAppAcademySignalComposer` + `NotificationSignalIds` |
| Channel delivery id left academy domain | **Pass** | `inAppDeliveryId` removed from `AcademyEventIds`; lives in `NotificationSignalIds` |
| Future observers can extend without changing emitters | **Pass** | Specs are extensible; homework emitters not touched in Pre-Slice |
| No teacher assign/review migration | **Pass** | Inline notification writes unchanged (Slice 1+) |
| Absence path still works through new boundaries | **Pass** | Sink → resolver → composer; tests green |

## Tests

- `test/shared/academy_event_observation_test.dart`
- `test/features/notifications/default_academy_event_observer_resolver_test.dart`
- `test/features/notifications/in_app_academy_signal_composer_test.dart`
- `test/features/notifications/in_app_academy_event_sink_test.dart`
- Existing W4 attendance transition / publication tests

## Explicitly not in Pre-Slice

- Migrating `sendAssignment` / `updateRecitationReview` off inline notifications
- Parent logout
- Wiring Supervisor / Analytics observers
- B-R8 client retries
