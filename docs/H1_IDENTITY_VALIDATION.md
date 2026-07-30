# H1 — Identity (P-E1 + A-H1) Validation

**Status:** Implemented · awaiting product approval before H2  
**Date:** 2026-07-30  
**Scope:** Slice H1 only (`docs/PRODUCTION_HARDENING_PHASE0.md`)  
**Out of scope:** H2+, Category B release work, new product workflows

---

## Intent

Safe multi-role handoff on shared devices after W1–W8:

| Item | Delivery |
|------|----------|
| **P-E1** | Parent / supervisor / admin can log out (parity with student/teacher) |
| **A-H1** | `@singleton` role & capability projections reset on logout |

---

## What shipped

### P-E1 — Logout UI

| Shell | Entry |
|-------|--------|
| Parent | AppBar logout → confirm dialog → `LogoutEvent` |
| Supervisor | AppBar logout → confirm dialog → `LogoutEvent` |
| Admin | AppBar logout → confirm dialog → `LogoutEvent` |
| Student / Teacher | Unchanged (already present) |

Shared helper: `lib/shared/widgets/confirm_logout.dart`

### A-H1 — Projection reset

On `AuthUnauthenticated` (transition into), `main.dart` calls `clearSessionProjections`:

| Bloc | Clear event |
|------|-------------|
| NotificationsBloc | `StopWatchingNotificationsEvent` (existing) |
| StudentBloc | `ClearStudentSessionEvent` (+ generation guard on assignment stream) |
| TeacherBloc | `ClearTeacherSessionEvent` |
| ParentBloc | `ClearParentSessionEvent` |
| SupervisorBloc | `ClearSupervisorSessionEvent` (also clears `_supervisorId`) |
| AdminBloc | `ClearAdminSessionEvent` |
| ChatConversationsBloc | `ClearChatConversationsSessionEvent` (+ uid/generation guards) |
| PostsBloc | `ClearPostsSessionEvent` (+ generation guards on posts/comments streams) |

Central wiring: `lib/core/session/clear_session_projections.dart`

---

## Explicitly unchanged

- Auth Firebase sign-out path (`LogoutUseCase` / repository)
- W1–W8 product invariants and admit flows
- Router guards / role routing
- No H2 day/homework SSOT work

---

## Validation checklist

| Check | Expected |
|-------|----------|
| Parent / supervisor / admin AppBar shows logout | Visible |
| Confirm → logout | Lands on unauthenticated / login |
| Cancel confirm | Stays authenticated |
| After parent logout, login as student | Student shell does not show prior parent children/report state |
| After teacher logout, login as different teacher | No prior halaqat/roster bleed |
| After any role logout | Notification badge/list empty until new watch |
| Student/teacher logout still works | Unchanged UX |

---

## Stop gate

**H1 complete for review.** Do **not** start H2 until product approves.
