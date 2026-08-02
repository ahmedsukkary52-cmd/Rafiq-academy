# Teacher Dashboard (`1:432`) — Implementation Plan

**Status:** Plan only — no code. Awaiting approval.  
**Date:** 2026-08-01  
**Figma SSOT (this plan only):** [
`1:432` — 03 · TEACHER DASHBOARD](https://www.figma.com/design/dvYE9COnQwosOVL3KCJVcp/Basma--Copy-?node-id=1-432)  
**Local screenshot:** `docs/figma_teacher_refs/03_dashboard_1-432.png`  
**App files in scope:** `teacher_home_page.dart` (shell/nav only as it hosts Home),
`teacher_dashboard_tab.dart`  
**Constraint:** Match frame `1:432` only. Do not design other screens in this plan.  
**Architecture:** Clean Architecture + **BLoC** (project has **no Cubits**). No architecture change.

---

## 0. Open product decisions (approve before coding)

These affect commits; they are visible **on** `1:432` but conflict with current app policy:

| #  | Conflict                    | Figma `1:432`                                           | Current app                                                     | Plan default (needs your OK)                                                                                                                                                                                                                            |
|----|-----------------------------|---------------------------------------------------------|-----------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| D1 | Bottom nav count/labels     | 5 tabs: الرئيسية · الطلاب · المنشورات · الرسائل · حسابي | 4 tabs: الرئيسية · الحلقات · الرسائل · حسابي (H6 removed posts) | **Match Figma labels on shell.** `المنشورات` tab → keep index + disabled/Coming Soon until posts surface re-approved (do not invent posts feature in Home commits). `الطلاب` → switch to existing Classes tab index (same tab body as today’s الحلقات). |
| D2 | W3 «عمل اليوم» agenda list  | Not present as multi-action agenda cards                | `_TodayAgendaSection` + closeout                                | **Remove agenda list UI from Home.** Keep `GetTodayAgendaUseCase` / `TeacherBloc.todayAgenda` as **data source** for stats/session/assistant chips (see §6).                                                                                            |
| D3 | Admin announcement banner   | Static copy on frame                                    | Not in app                                                      | **Show only if a real announcement feed exists later.** Until then: **hide section** (no fake admin copy). Flag for separate slice.                                                                                                                     |
| D4 | «النشاطات الأخيرة»          | Three sample activity rows + الكل                       | Not on Home                                                     | **Hide until activity feed UseCase exists**, OR map to last N agenda-derived events if you approve a thin projection in a later commit. Default: **skeleton-ready empty → hide when empty**.                                                            |
| D5 | Search icon                 | Present in header                                       | Not wired                                                       | Icon visible; **onTap no-op or snackbar «قريباً»** until search frame approved (out of scope).                                                                                                                                                          |
| D6 | Room / قاعة on session card | Shown on Figma                                          | Halaqa entity may lack room                                     | Show room only if field exists; else omit subtitle part.                                                                                                                                                                                                |

---

## 1. Widget tree (match Figma `1:432`)

Target composition (names are proposed Flutter widgets; private `_` allowed):

```
TeacherHomePage
└─ Scaffold
   ├─ body: IndexedStack
   │  └─ [0] TeacherDashboardTab          ← frame 1:432 body
   │  └─ [1] TeacherClassesPage           ← tab الطلاب
   │  └─ [2] PostsPlaceholderTab|existing ← tab المنشورات (D1)
   │  └─ [3] TeacherMessagesTab
   │  └─ [4] TeacherProfileTab
   └─ bottomNavigationBar: TeacherBottomNav (5 items, الرئيسية selected)

TeacherDashboardTab
└─ RefreshIndicator
   └─ CustomScrollView
      ├─ SliverToBoxAdapter → TeacherHomeHeader
      │  ├─ Row (identity + actions)
      │  │  ├─ NotificationButton (badge)
      │  │  ├─ SearchButton (D5)
      │  │  └─ Column(name, role·halaqa) + AvatarInitial
      │  ├─ GreetingRow («السلام عليكم» + leaf + «يوم {weekday} مبارك!»)
      │  └─ HijriDatePill
      ├─ SliverToBoxAdapter → TeacherStatsGrid (2×2)
      │  ├─ StatTile(حصص اليوم)
      │  ├─ StatTile(إجمالي الطلاب)
      │  ├─ StatTile(مهام معلقة)
      │  └─ StatTile(رسائل جديدة)
      ├─ SliverToBoxAdapter → NextSessionCard | EmptySessionCard
      │  ├─ time row
      │  ├─ halaqa title
      │  ├─ meta (students · room?)
      │  └─ StartSessionButton («ابدأ الجلسة»)
      ├─ SliverToBoxAdapter → AdminAnnouncementBanner? (D3; omit if no data)
      ├─ SliverToBoxAdapter → RecentActivitySection? (D4; omit if empty)
      │  ├─ header (النشاطات الأخيرة + الكل)
      │  └─ ActivityTile × N
      └─ SliverToBoxAdapter → SmartAssistantCard
         ├─ badge مساعد ذكي
         ├─ title ما الذي تريد إنجازه اليوم؟
         ├─ subtitle اقتراحات مخصصة بناءً على جدولك
         └─ Wrap chips: رفع التقييمات | إرسال مهمة | طلاب في خطر
```

**Visual order (top → bottom), exact section list:**

1. Status chrome (system; ignore)
2. **Header** (teal) — avatar, name, role, search, notifications
3. **Greeting** — السلام عليكم + weekday blessing
4. **Hijri date pill**
5. **Stats grid** — 4 tiles
6. **Next session card** — dark card + ابدأ الجلسة
7. **Admin announcement** (optional / D3)
8. **Recent activities** (optional / D4)
9. **Smart assistant** card + 3 chips
10. **Bottom nav** (shell, not inside scroll)

---

## 2. Every interaction (on `1:432`)

| #   | Control              | Gesture | Behavior                                                                                        |
|-----|----------------------|---------|-------------------------------------------------------------------------------------------------|
| I1  | Notification bell    | tap     | Navigate to teacher notifications                                                               |
| I2  | Search               | tap     | D5: deferred / non-blocking                                                                     |
| I3  | Avatar / name        | tap     | Optional: switch to حسابي tab — **recommend yes** (Figma often implies profile)                 |
| I4  | Stat «حصص اليوم»     | tap     | Switch to الطلاب tab **or** scroll/focus session card — **recommend** open Classes tab          |
| I5  | Stat «إجمالي الطلاب» | tap     | Classes tab                                                                                     |
| I6  | Stat «مهام معلقة»    | tap     | Derive first pending agenda action → deep-link (attendance / assign / evals)                    |
| I7  | Stat «رسائل جديدة»   | tap     | Messages tab                                                                                    |
| I8  | «ابدأ الجلسة»        | tap     | Open class detail for **next today session** halaqa (`/teacher/halaqa/:id`)                     |
| I9  | Admin banner         | tap     | D3: none until feed exists                                                                      |
| I10 | «الكل» on activities | tap     | D4: deferred                                                                                    |
| I11 | Activity row         | tap     | D4: deep-link by activity type when feed exists                                                 |
| I12 | Chip «رفع التقييمات» | tap     | `/teacher/halaqa/:id/evaluations` for next pending-review halaqa (from agenda)                  |
| I13 | Chip «إرسال مهمة»    | tap     | `/teacher/halaqa/:id?assign=1` for next send-homework halaqa                                    |
| I14 | Chip «طلاب في خطر»   | tap     | Classes tab **or** analytics if re-enabled later — **recommend** Classes until risk list exists |
| I15 | Pull-to-refresh      | drag    | Reload halaqat + agenda + notifs/conversations counts                                           |
| I16 | Bottom: الرئيسية     | tap     | Stay on dashboard                                                                               |
| I17 | Bottom: الطلاب       | tap     | Classes page                                                                                    |
| I18 | Bottom: المنشورات    | tap     | D1 placeholder                                                                                  |
| I19 | Bottom: الرسائل      | tap     | Messages tab                                                                                    |
| I20 | Bottom: حسابي        | tap     | Profile tab                                                                                     |

---

## 3. Every navigation target

Targets named from **controls on `1:432`** + **existing app routes** (destinations not redesigned
here):

| From `1:432`                | Target                       | Route / mechanism                                    |
|-----------------------------|------------------------------|------------------------------------------------------|
| Bell                        | Notifications                | `AppRoutes.teacherNotifs` → `/teacher/notifications` |
| Search                      | —                            | None (D5)                                            |
| ابدأ الجلسة                 | Class detail                 | `/teacher/halaqa/:halaqaId`                          |
| Chip رفع التقييمات          | Evaluations                  | `/teacher/halaqa/:halaqaId/evaluations`              |
| Chip إرسال مهمة             | Assign sheet on class detail | `/teacher/halaqa/:halaqaId?assign=1`                 |
| مهام معلقة (if actionable)  | Attendance / assign / evals  | Existing agenda deep-links                           |
| الطلاب tab / student stats  | Classes list                 | `IndexedStack` index (Classes)                       |
| الرسائل tab / messages stat | Messages                     | `IndexedStack` index                                 |
| حسابي / avatar              | Profile                      | `IndexedStack` index                                 |
| المنشورات tab               | Placeholder                  | No live `PostsListPage` in tree (H6)                 |
| Activity / announcement     | —                            | Blocked on D3/D4                                     |

**Do not** navigate to student mushaf or invent new top-level routes in this plan.

---

## 4. Loading / empty / error / success states

| Surface                            | Loading                                                                                              | Empty                                                                                            | Error                                                     | Success                                                                   |
|------------------------------------|------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|-----------------------------------------------------------|---------------------------------------------------------------------------|
| **Whole dashboard** (halaqat gate) | Keep header chrome; body shimmer/skeleton for stats+session+assistant (prefer over full-screen wipe) | N/A                                                                                              | Full-body `AppErrorWidget` + retry (keep current pattern) | Sections below                                                            |
| **Stats grid**                     | 4 shimmer tiles                                                                                      | Show `0` values                                                                                  | Inherit parent error                                      | Live numbers                                                              |
| **حصص اليوم**                      | —                                                                                                    | `0` + EmptySessionCard                                                                           | —                                                         | Count of today’s sessions from agenda/`sessionsTodayCount`                |
| **إجمالي الطلاب**                  | —                                                                                                    | `0`                                                                                              | —                                                         | Sum/unique student ids (prefer **unique** if easy; document if still sum) |
| **مهام معلقة**                     | —                                                                                                    | `0`                                                                                              | —                                                         | Count pending agenda actions (flatten `TeacherDayAgenda.items`)           |
| **رسائل جديدة**                    | shimmer or `—`                                                                                       | `0`                                                                                              | Keep last known / `0`                                     | `ChatConversationsBloc` total unread                                      |
| **Next session card**              | shimmer card                                                                                         | **EmptySessionCard**: copy aligned to product («لا توجد حصص مجدوَلة اليوم») — maps Figma absence | Retry via parent                                          | Filled card + ابدأ الجلسة                                                 |
| **Admin banner**                   | —                                                                                                    | **Hide** (D3)                                                                                    | Hide                                                      | Show when data exists                                                     |
| **Recent activities**              | optional shimmer                                                                                     | **Hide section** (D4)                                                                            | Hide or inline retry later                                | List                                                                      |
| **Smart assistant**                | shimmer                                                                                              | Chips disabled/hidden if no pending actions; still show calm title                               | Inherit                                                   | Chips only for actions that exist today                                   |
| **Notifications badge**            | —                                                                                                    | No badge                                                                                         | —                                                         | Unread count                                                              |
| **Pull-to-refresh**                | indicator                                                                                            | —                                                                                                | snackbar/error state                                      | Updated sections                                                          |

**Figma does not draw** explicit empty/error variants on `1:432`; states above are implementation
necessities consistent with existing `SectionStatus` patterns.

---

## 5. Existing BLoCs / UseCases to reuse (no Cubits)

| Layer                                                            | Reuse for `1:432`                                                                          |
|------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| `AuthBloc`                                                       | Teacher name, uid, avatar initial                                                          |
| `TeacherBloc` + `LoadTeacherHalaqatEvent`                        | Halaqat list, student counts                                                               |
| `TeacherBloc` + `GetTodayAgendaUseCase` / `LoadTodayAgendaEvent` | `sessionsTodayCount`, next session, pending action counts, chip targets                    |
| `TeacherDayAgenda` / `TeacherAgendaAction`                       | Data only (not old agenda list UI)                                                         |
| `NotificationsBloc`                                              | Badge + refresh                                                                            |
| `ChatConversationsBloc`                                          | «رسائل جديدة» count (ensure watch started from Home like Messages tab)                     |
| `SelectHalaqaEvent`                                              | Before class detail navigation                                                             |
| Shared                                                           | `NotificationBadge`, `AppLoadingWidget`, `AppErrorWidget`, `AppColors`, `formatTimeHm12Ar` |

**Not required for visual match (defer):** new Cubit, new BLoC, posts UseCase, announcements
UseCase, activity-feed UseCase, AI backend.

---

## 6. Widgets to **delete** (from current Home/dashboard)

| Widget / surface                       | File                         | Why                                                           |
|----------------------------------------|------------------------------|---------------------------------------------------------------|
| `_TodayAgendaSection`                  | `teacher_dashboard_tab.dart` | Not on Figma `1:432`                                          |
| `_AgendaHeader` («عمل اليوم»)          | same                         | Replaced by session + assistant                               |
| `_AgendaItemCard` / `_AgendaActionRow` | same                         | Not on frame                                                  |
| `_CloseoutCard` / `_CloseoutSummary`   | same                         | Not on frame (closeout copy may inform EmptySessionCard only) |
| `_AgendaCard` (if unused after)        | same                         | Cleanup                                                       |
| `_TeacherStatsRow` 2-tile layout       | same                         | Replace with 2×2 grid (labels change: not «الحلقات»)          |
| Current `_TeacherHeader` layout gaps   | same                         | Rebuild: add search, Hijri pill, greeting order per Figma     |
| `_TeacherBottomNav` 4-tab set          | `teacher_home_page.dart`     | Rebuild to 5-tab Figma set (D1)                               |

**Domain/UseCase:** do **not** delete `GetTodayAgendaUseCase` — still feeds stats/session/chips.

---

## 7. Widgets that can **stay** (adapt, don’t rewrite from zero)

| Stay / adapt                                                          | Notes                                                      |
|-----------------------------------------------------------------------|------------------------------------------------------------|
| `TeacherHomePage` + `IndexedStack`                                    | Extend children/nav only                                   |
| `TeacherDashboardTab` shell + `RefreshIndicator` + `CustomScrollView` | Keep pattern                                               |
| `_TeacherHeader` → evolve into `TeacherHomeHeader`                    | Keep notif wiring                                          |
| `_StatCard` → evolve into grid `StatTile`                             | Same visual atom, new layout/labels                        |
| `_EmptyHalaqatCard` idea → `EmptySessionCard`                         | Retarget copy to «no session today» vs no halaqat assigned |
| `TeacherClassesPage` / `TeacherMessagesTab` / `TeacherProfileTab`     | Unchanged bodies in this plan                              |
| Halaqat load/error/retry                                              | Keep                                                       |

---

## 8. Implementation plan — small commits

Each commit is shippable UI/wiring; no drive-by refactors.

| Commit                                 | Title (intent)                               | Scope                                                                                                                                                   |
|----------------------------------------|----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| **C1**                                 | align teacher bottom nav to Figma Home shell | `teacher_home_page.dart`: 5 tabs labels/icons; map الطلاب→Classes; المنشورات→minimal placeholder page (empty state only); keep Messages/Profile indices |
| **C2**                                 | rebuild Teacher Home header to match `1:432` | Header: avatar, name, role, search (D5), notif badge, greeting, Hijri pill; no body section changes yet                                                 |
| **C3**                                 | replace stats row with 2×2 Figma grid        | Wire: sessionsToday, students, pendingActions, unread messages; taps I4–I7                                                                              |
| **C4**                                 | add Next Session card; remove agenda list UI | Delete `_TodayAgendaSection` tree; add session card + empty; `ابدأ الجلسة` → halaqa detail; keep agenda UseCase for data                                |
| **C5**                                 | add Smart Assistant card chips               | Map chips to agenda actions / Classes; hide inert chips when no pending work                                                                            |
| **C6**                                 | polish states + refresh                      | Section skeletons; pull-to-refresh includes chat unread; error/empty parity                                                                             |
| **C7** *(optional, separate approval)* | announcements + recent activity              | Only if D3/D4 approved with a real data source                                                                                                          |

**Out of C1–C6:** redesigning Classes/Messages/Profile/Attendance pixels; implementing posts; Hijri
library choice (use existing util if any, else simple formatter stub behind interface).

---

## 9. Acceptance checklist (for `1:432` only)

- [ ] Visual sections 2–6 and 9–10 present in order
- [ ] No «عمل اليوم» multi-row agenda on Home
- [ ] Four stats labels match Figma Arabic
- [ ] Session card + ابدأ الجلسة when a today session exists
- [ ] Smart assistant present
- [ ] Bottom nav 5 items match Figma labels
- [ ] Bell → notifications
- [ ] No new architecture; BLoCs reused
- [ ] No commit/push until this plan is approved

---

## 10. Approval gate

**Stop.** Please approve or amend:

1. D1–D6 defaults
2. Commit sequence C1–C6 (C7 deferred)
3. Confirmation that W3 agenda **UI** may leave Home while agenda **UseCase** remains

Awaiting approval before any code.
