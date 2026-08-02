# Teacher Home Implementation Plan

**Status:** Awaiting approval — no code until approved.  
**Date:** 2026-08-01  
**UI SSOT:** Figma Teacher Dashboard frame [
`1:432`](https://www.figma.com/design/dvYE9COnQwosOVL3KCJVcp/Basma--Copy-?node-id=1-432) + attached
screenshot (`docs/figma_teacher_refs/03_dashboard_1-432.png`).  
**Scope:** Teacher Home Dashboard UI only (Phases 1–7 below).  
**Out of scope:** Attendance, Students detail flows, Awards, Homework, Messages body, Profile body,
other roles, architecture/Firestore/UseCase changes.

---

## 1. Files to edit

| File                                                                         | Why                                                                                                                                                                                                                            |
|------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `lib/features/teacher/presentation/pages/teacher_dashboard_tab.dart`         | Full UI rebuild to match Figma (Phases 1–6). Remove W3 agenda **presentation** only.                                                                                                                                           |
| `lib/features/teacher/presentation/pages/teacher_home_page.dart`             | Phase 7 bottom nav (5 tabs + IndexedStack children). Wire existing tab pages; Coming Soon for missing tab(s).                                                                                                                  |
| `lib/features/teacher/presentation/pages/teacher_posts_coming_soon_tab.dart` | **New** (minimal). Placeholder body for tab المنشورات — local to Teacher Home shell only.                                                                                                                                      |
| `lib/features/teacher/presentation/widgets/teacher_home_*.dart`              | **Optional new** private/section widgets if `teacher_dashboard_tab.dart` grows too large (header, stats grid, session card, announcement, activities, assistant). Prefer one file first; split only if needed for readability. |

**Explicitly not edited (unless a compile import forces a one-line path fix):**

- `teacher_classes_page.dart`, `teacher_messages_tab.dart`, `teacher_profile_tab.dart` (bodies
  unchanged; only selected as tabs)
- `teacher_attendance_page.dart`, `teacher_class_detail_page.dart`, `teacher_evalutation_page.dart`
- `teacher_bloc.dart` / events / state / UseCases / repositories / Firestore (preserve behavior)
- `router_app.dart` — **prefer no router changes**; Coming Soon is an IndexedStack child, not a new
  GoRoute

---

## 2. Widgets to replace

| Current widget (in `teacher_dashboard_tab.dart` / shell)                                                                                | Action                                                                                                 |
|-----------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| `_TeacherHeader`                                                                                                                        | Replace with Figma header (gradient, search, notif, avatar, name, subtitle, greeting, day, Hijri chip) |
| `_TeacherStatsRow` (2 tiles: طلاب / حلقات)                                                                                              | Replace with 2×2 Figma stats (طلاب / حصص اليوم / رسائل جديدة / مهام معلقة)                             |
| `_StatCard` (old layout)                                                                                                                | Replace with Figma stat tile layout                                                                    |
| `_TodayAgendaSection` + `_AgendaHeader` + `_AgendaItemCard` + `_AgendaActionRow` + `_CloseoutCard` + `_CloseoutSummary` + `_AgendaCard` | **Delete from Home UI** (presentation only)                                                            |
| `_EmptyHalaqatCard`                                                                                                                     | Replace with session empty / no-halaqat presentation aligned to Figma (not agenda closeout list)       |
| `_TeacherBottomNav` (4 tabs: الرئيسية / الحلقات / الرسائل / حسابي)                                                                      | Replace with 5-tab Figma set                                                                           |

---

## 3. Widgets to reuse

| Widget / util                                        | Use on Home                                                                |
|------------------------------------------------------|----------------------------------------------------------------------------|
| `NotificationBadge`                                  | Bell unread                                                                |
| `UserAvatar` (if fits Figma circle)                  | Header avatar; else initial-letter container matching Figma                |
| `AppLoadingWidget` / `AppErrorWidget`                | Gate states while halaqat load/fail                                        |
| `AppColors` / `AppTextStyles` / `AppSizes`           | Theme tokens; extend locally only where Figma needs navy/gold not in theme |
| `formatTimeHm12Ar`                                   | Session time on dark card                                                  |
| `hijri` package (`HijriCalendar`) already in project | Hijri chip text (presentation formatting only)                             |
| `RefreshIndicator` + `CustomScrollView` pattern      | Keep interaction pattern                                                   |

**Reuse as tab bodies (unchanged internals):**

- `TeacherClassesPage` → tab الطلاب
- `TeacherMessagesTab` → tab الرسائل
- `TeacherProfileTab` → tab حسابي

---

## 4. BLoCs affected

| BLoC                    | Role on Home                                                        | Change type                                                                                     |
|-------------------------|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| `TeacherBloc`           | Halaqat + `todayAgenda` for stats, next session, pending-task count | **Read only** — keep `LoadTeacherHalaqatEvent` / `LoadTodayAgendaEvent`; do not remove UseCases |
| `AuthBloc`              | Name / photo / uid                                                  | **Read only**                                                                                   |
| `NotificationsBloc`     | Unread badge; `StartWatchingNotificationsEvent` already from Home   | **Read only** (ensure still started)                                                            |
| `ChatConversationsBloc` | «رسائل جديدة» count                                                 | **Read only** — start watch from Home if not already (same event Messages tab uses)             |

**No Cubits. No new BLoC for Phases 1–7** unless a tiny ephemeral `ValueNotifier` is needed for tab
index (already on `TeacherHomePage` State).

**Business logic preserved:**

- `GetTeacherHalaqatUseCase`
- `GetTodayAgendaUseCase` / `TeacherDayAgenda` (data for session + pending tasks; **not** rendered
  as W3 agenda list)
- Repositories + Firestore contracts untouched

---

## 5. Routes touched

| Route / target                                       | When                                  | Notes                                                 |
|------------------------------------------------------|---------------------------------------|-------------------------------------------------------|
| `/teacher`                                           | Unchanged entry                       | Still `TeacherHomePage`                               |
| `/teacher/notifications` (`AppRoutes.teacherNotifs`) | Phase 1 bell tap                      | Existing — wire only                                  |
| `/teacher/halaqa/:halaqaId`                          | Phase 3 «ابدأ الجلسة»                 | Existing — wire only when a today session exists      |
| IndexedStack tab switch                              | Phase 2/7 taps (طلاب / رسائل / حسابي) | Not GoRouter                                          |
| Coming Soon (in-shell)                               | Tab المنشورات                         | **No new GoRoute**                                    |
| Search button                                        | Phase 1                               | Placeholder (`SnackBar` «قريباً» or no-op) — no route |
| AI chips (Phase 6)                                   | Placeholders only                     | No navigation / no AI                                 |

**Not starting in this task:** attendance, evaluations, assign (`?assign=1`), awards, chat thread,
student profile routes.

---

## 6. Phase checklist (build order)

| Phase | Deliverable                                                                                   | Data                                                                                                                                                             |
|-------|-----------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **1** | Gradient header + notif + search + avatar + name + subtitle + greeting + weekday + Hijri chip | `AuthBloc` + first halaqa name for subtitle; Hijri from `hijri`                                                                                                  |
| **2** | Four stat cards                                                                               | Students from halaqat; sessions from `todayAgenda.sessionsTodayCount`; messages from chat unread; pending from flattened agenda actions — else `0` / placeholder |
| **3** | Dark today’s session card + Start Session; **remove agenda list UI**                          | Next today session from agenda/halaqat; room omitted if field missing; empty → designed empty, no fake session                                                   |
| **4** | Yellow announcement                                                                           | **Hide if no real announcement source**; no fake copy                                                                                                            |
| **5** | Recent activities                                                                             | Exact Figma layout; **designed empty if none**; no fabricated rows (no activity UseCase yet → empty)                                                             |
| **6** | AI Assistant card                                                                             | UI only; buttons placeholders                                                                                                                                    |
| **7** | Bottom nav: الرئيسية · الطلاب · المنشورات · الرسائل · حسابي                                   | Classes / Coming Soon / Messages / Profile                                                                                                                       |

---

## 7. Approval gate

Approve this plan to unlock coding in phase order (1→7).

**Will not:** modify other pages’ internals, delete agenda UseCases, add Cubits, commit/push without
ask, or implement non-Home workflows.
