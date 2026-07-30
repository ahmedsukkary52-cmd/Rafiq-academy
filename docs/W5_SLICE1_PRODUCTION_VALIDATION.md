# W5 Slice 1 — Production Validation

**Status:** Pass (pending product approval before Slice 2)  
**Date:** 2026-07-29  
**Scope:** Replace inline homework-assign notification writes with `HomeworkAssigned` academy facts

## Constraints verified

| Constraint | Result | Evidence |
|------------|--------|----------|
| Inline assign notification writes removed | **Pass** | `sendAssignment` batch writes only `assignments` docs |
| Publish only `AcademyEvent`s | **Pass** | Datasource returns `List<HomeworkAssigned>`; repository publishes via `AcademyEventSink` |
| Exactly one publication path | **Pass** | Assign + attendance both use `_publishAfterCommit` → `AcademyEventSink` (fan-out); no second notify writer on assign |
| Student UX wording preserved | **Pass** | Subject-student observer gets legacy «تكليف جديد: … — افتح واجباتي» |
| Parent becomes eligible observer | **Pass** | Observation policy: subject student + linked parents |
| Event payload fact-only | **Pass** | `HomeworkAssigned` has ids/actor/due/ranges — no display name |
| Publisher unaware of handlers | **Pass** | `FanOutAcademyEventSink`; emitters depend on `AcademyEventSink` only |
| Observer independence | **Pass** | Fan-out runs handlers independently; one failure does not stop others |
| B-R8 unchanged | **Pass** | Publish failure → `hasUnpublishedEvents`; SSOT not rolled back |

## Explicitly not in Slice 1

- Migrating `updateRecitationReview` inline notification (Slice 2)
- Parent logout
- Wiring Supervisor/Analytics handlers
- Client retries for B-R8
