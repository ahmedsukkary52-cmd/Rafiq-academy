# Teacher Home UI Audit

**Status:** Audit only — no code changes. Awaiting approval.  
**Date:** 2026-07-31  
**App surface:** `TeacherHomePage` + tabs (`TeacherDashboardTab`, `TeacherClassesPage`,
`TeacherMessagesTab`, `TeacherProfileTab`)  
**Approved Figma:
** [Basma (Copy)](https://www.figma.com/design/dvYE9COnQwosOVL3KCJVcp/Basma--Copy-?node-id=2-4394) —
file `dvYE9COnQwosOVL3KCJVcp`, role frame **`المعلم` `2:4394`**  
**Architecture rule:** Do not change architecture. Project uses **BLoC** (no Cubits exist).

---

## 0. Source-of-truth blocker (read first)

Visual inspection of every phone frame under Figma **`المعلم` (`2:4394`)** shows **student-role UI
**, not a teacher operational home:

| Evidence                    | Detail                                                                                                 |
|-----------------------------|--------------------------------------------------------------------------------------------------------|
| Bottom nav labels           | Figma: **مصحفي · حلقاتي · جوائزي · الرسائل · حسابي** (5 tabs)                                          |
| App teacher shell           | App: **الرئيسية · الحلقات · الرسائل · حسابي** (4 tabs; posts removed in H6)                            |
| Dashboard content (`1:432`) | Progress rings (حفظ / مراجعة / إتقان / ختمة) + surah cards → **student مصحفي**, not teacher day agenda |
| Product home in code        | Teal greeting header + stats + **«عمل اليوم»** agenda (W3) — **no matching frame** in `2:4394`         |

**Conclusion:** Frame `المعلم` is mislabeled or is an HTML-export dump of the student shell. There
is **no approved Teacher Home composition** in that frame that matches the shipped teacher product (
W3 day agenda).

Until product confirms either (A) a corrected teacher Figma, or (B) that the **app W3 dashboard is
the UI SSOT** and Figma `المعلم` is ignored for Home, pixel/IA match-Figma cannot be completed
honestly.

The rest of this audit still compares **what is in `2:4394`** vs **what the app ships**, screen by
screen.

---

## 1. Screenshot-by-screenshot comparison

Scope legend: **Home** = Teacher Home shell / tab content. **Out** = auth, deep flows, or non-home.

| #     | Figma node                             | Visual (from MCP screenshots)                                            | Home relevance                                                              | App counterpart                                                | Match                                               |
|-------|----------------------------------------|--------------------------------------------------------------------------|-----------------------------------------------------------------------------|----------------------------------------------------------------|-----------------------------------------------------|
| 01    | `1:311`                                | Splash / welcome (octagram mark, CTA, 5-tab chrome)                      | Out (auth/onboarding)                                                       | Shared splash / not teacher home                               | N/A for Home                                        |
| 02    | `1:354`                                | Login (tabs + fields + «نسيت كلمة المرور؟»)                              | Out                                                                         | Shared auth                                                    | N/A for Home                                        |
| 03    | `1:432`                                | «مصحفي» home: header, stats, 4 progress rings, surah list, **5-tab** nav | Claimed Teacher dashboard in prior inventory — actually student mushaf home | `TeacherDashboardTab`                                          | **None**                                            |
| 04    | `1:914`                                | «حلقاتي»: class cards, «ابدأ الحصة», student-style chrome                | Closest to Classes tab                                                      | `TeacherClassesPage`                                           | **Weak / wrong role**                               |
| 05    | `1:769`                                | «جوائزي» / rewards trophy UI                                             | No teacher Home tab                                                         | None (teacher awards are halaqa-scoped routes, not a Home tab) | Missing in teacher Home by design (H6) vs Figma tab |
| 06    | `1:632`                                | Awards / badges grid variant                                             | Same as above                                                               | None on Home                                                   | **Mismatch**                                        |
| 07    | `1:1314`                               | Messages empty                                                           | Messages tab                                                                | `TeacherMessagesTab` empty                                     | **Partial**                                         |
| 08    | `1:1188`                               | Messages list with threads                                               | Messages tab                                                                | `TeacherMessagesTab` list                                      | **Partial**                                         |
| 09    | `1:1056`                               | Messages empty / alternate                                               | Messages tab                                                                | Same                                                           | **Partial**                                         |
| 10    | `1:1658`                               | Profile «حسابي» rich (avatar, stats, menu rows)                          | Profile tab                                                                 | `TeacherProfileTab`                                            | **Partial / thinner in app**                        |
| 11    | `1:1500`                               | Profile edit form                                                        | Profile subflow                                                             | Not on Home profile (logout-only card)                         | **Missing**                                         |
| 12    | `1:1405`                               | Profile / settings dense                                                 | Profile subflow                                                             | Not implemented on teacher profile                             | **Missing**                                         |
| 13    | `1:2035`                               | MCP rate-limited — not re-captured this pass                             | Unknown                                                                     | —                                                              | **Unverified**                                      |
| 14    | `1:1871`                               | Chat thread                                                              | Messages deep link                                                          | `/teacher/chat/:id` (not Home body)                            | Out of Home body; nav OK if opened from list        |
| 15    | `1:1784`                               | Messages empty / chat empty                                              | Messages                                                                    | Empty state                                                    | **Partial**                                         |
| 16-19 | `1:2350`, `1:2250`, `1:2155`, `1:2479` | Rate-limited — not captured                                              | Unknown                                                                     | —                                                              | **Unverified**                                      |

### 1.1 Home tab — Dashboard (`TeacherDashboardTab` vs Figma `1:432`)

| Area            | Figma `1:432`                       | App                                            | Verdict                                |
|-----------------|-------------------------------------|------------------------------------------------|----------------------------------------|
| Identity        | Student-style name + mushaf context | «الأستاذ {name}», «معلم تحفيظ · {halaqa}»      | Mismatch                               |
| Greeting        | Not the W3 day line                 | «السلام عليكم» + «يوم {weekday} مبارك!»        | App-only (no Figma teacher equivalent) |
| Notifications   | Header icons (bell etc.)            | Bell → `/teacher/notifications` + unread badge | Concept OK; chrome differs             |
| Primary body    | Progress rings + surah cards        | Stats row + **عمل اليوم** agenda / closeout    | **Complete product mismatch**          |
| Stats           | Mushaf-oriented metrics             | `إجمالي الطلاب`, `الحلقات`                     | Different metrics                      |
| Bottom nav      | 5 tabs incl. مصحفي / جوائزي         | 4 tabs                                         | Mismatch                               |
| Pull-to-refresh | Not evidenced in static frame       | `RefreshIndicator` reloads halaqat+agenda      | App-only                               |

### 1.2 Classes tab (`TeacherClassesPage` vs Figma `1:914`)

| Area                | Figma                          | App                                            | Verdict                                                      |
|---------------------|--------------------------------|------------------------------------------------|--------------------------------------------------------------|
| Title               | حلقاتي                         | AppBar «حلقاتي»                                | OK label                                                     |
| Card actions        | «ابدأ الحصة»-style primary CTA | Chips: «عرض الحلقة», «تقييم»                   | Interaction model differs                                    |
| Attendance / assign | Not primary on this frame      | Via class detail / agenda deep links, not list | Different IA                                                 |
| Empty               | Not confirmed on this node     | «لا توجد حلقات مسندة إليك»                     | App has empty; Figma empty for teacher classes not confirmed |

### 1.3 Messages tab (`TeacherMessagesTab` vs `1:1314` / `1:1188` / `1:1056`)

| Area          | Figma                                 | App                                   | Verdict             |
|---------------|---------------------------------------|---------------------------------------|---------------------|
| List rows     | Rich chat list chrome                 | Material `ListTile` + avatar + unread | Visual mismatch     |
| Empty         | Illustrated empty                     | Icon + «لا توجد رسائل بعد»            | Partial             |
| Compose / FAB | Present on some Figma message screens | **No FAB / new conversation** on tab  | Missing interaction |
| Open thread   | Implied                               | `push('/teacher/chat/${conv.id}')`    | OK                  |

### 1.4 Profile tab (`TeacherProfileTab` vs `1:1658`+)

| Area                        | Figma                | App                                              | Verdict               |
|-----------------------------|----------------------|--------------------------------------------------|-----------------------|
| Header                      | Rich profile         | Teal header + avatar + name + role + phone/email | Partial               |
| Stats                       | Multiple rows / menu | 2 stat cards (طلاب / حلقات)                      | Thinner               |
| Settings / edit / AI / help | Dense menus in Figma | **Only logout** + «أكاديمية رفيق»                | Large missing surface |
| Logout                      | Likely in menu       | Explicit logout tile                             | Present               |

---

## 2. Every UI mismatch

1. **Role chrome:** Figma `المعلم` uses **student** 5-tab IA; app uses **teacher** 4-tab IA.
2. **No Figma frame for «عمل اليوم»** (agenda items, closeout, fraction «مكتمل X من Y»).
3. **Dashboard body:** Figma shows mushaf progress/surahs; app shows halaqa stats + agenda.
4. **Tab «جوائزي» / «مصحفي»** exist in Figma shell; **absent** from teacher Home (correct for H6
   product, wrong vs this Figma frame).
5. **Posts / announcements tab** appeared in older Figma inventories; **removed from app** (H6).
6. **Header:** App solid primary block + weekday greeting; Figma student header layout/icons differ.
7. **Stats double-count risk (product known):** app sums `studentIds.length` across halaqat — Figma
   does not define teacher unique-student metric.
8. **Classes list CTAs:** Figma «ابدأ الحصة» vs app «عرض الحلقة» / «تقييم».
9. **Messages:** Figma richer empty/list/FAB; app minimal list.
10. **Profile:** Figma multi-section account; app logout-centric.
11. **Typography / components:** App uses shared `AppColors` / Material icons; Figma HTML-export
    frames differ.
12. **Agenda inline spinner** uses raw `CircularProgressIndicator` vs shared `AppLoadingWidget`.
13. **Unverified frames `1:2035`, `1:2350`, `1:2250`, `1:2155`, `1:2479`:** Figma MCP rate limit.

---

## 3. Every missing interaction (vs Figma shell + expected Home)

| Missing in app Teacher Home                               | Source expectation                               |
|-----------------------------------------------------------|--------------------------------------------------|
| Bottom tab **مصحفي**                                      | Figma shell                                      |
| Bottom tab **جوائزي**                                     | Figma shell                                      |
| Mushaf progress rings / surah open from Home              | `1:432`                                          |
| «ابدأ الحصة» from classes list                            | `1:914`                                          |
| New message / compose FAB                                 | Messages frames                                  |
| Profile edit                                              | `1:1500`                                         |
| Profile settings / secondary menus                        | `1:1405` / rich `1:1658`                         |
| Tap on dashboard stat cards                               | Figma often tappable; app stats are display-only |
| Second header action (search / menu) beside notifications | Figma header icon cluster                        |

Product interactions **present in app** but **not in Figma `المعلم`**:

| App interaction                     | Notes                             |
|-------------------------------------|-----------------------------------|
| Agenda action → attendance          | `/teacher/attendance/:halaqaId`   |
| Agenda action → assign sheet        | `/teacher/halaqa/:id?assign=1`    |
| Agenda action → evaluations         | `/teacher/halaqa/:id/evaluations` |
| Pull-to-refresh dashboard           | Halaqat + agenda reload           |
| Agenda / halaqat error retry        | `AppErrorWidget` / TextButton     |
| Notification badge → teacher notifs | Wired                             |

---

## 4. Every wrong navigation

| Issue                                      | Detail                                                                                                                                   |
|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| **IA conflict**                            | Matching Figma bottom nav literally would navigate teachers into **student** destinations (مصحفي / جوائزي) — **wrong for teacher role**. |
| **Classes primary CTA**                    | Figma implies session-start; app opens class detail / evaluations — different entry.                                                     |
| **No wrong deep-link found inside agenda** | Attendance / assign / evals routes align with existing teacher workflows (not Figma).                                                    |
| **Messages**                               | List → `/teacher/chat/:id` is correct for teacher chat.                                                                                  |
| **Profile**                                | No navigation to settings/edit that Figma shows — dead-end vs design.                                                                    |
| **Removed orphans**                        | H6 removed analytics/calendar/content teacher routes from shell — do not reintroduce via Home nav without product re-approval.           |

---

## 5. Every incorrect state (loading / empty / error / success)

### Dashboard (`TeacherDashboardTab`)

| State                       | App behavior                              | vs Figma                               | Verdict                         |
|-----------------------------|-------------------------------------------|----------------------------------------|---------------------------------|
| Loading (halaqat)           | Full-screen `AppLoadingWidget`            | No branded teacher loading in `2:4394` | App OK; Figma unspecified       |
| Error (halaqat)             | `AppErrorWidget` + retry                  | Not in Figma                           | App OK; design gap              |
| Empty halaqat               | `_EmptyHalaqatCard` copy                  | No teacher empty in Figma              | App OK; design gap              |
| Agenda loading              | Small inline spinner                      | Unspecified                            | Acceptable; inconsistent widget |
| Agenda error                | Message + «إعادة المحاولة»                | Unspecified                            | App OK                          |
| Agenda success / incomplete | Cards + «لم يكتمل عمل اليوم» (+ fraction) | **Not in Figma**                       | Product-correct; Figma missing  |
| Closeout complete           | «اكتمل عمل اليوم» + check                 | **Not in Figma**                       | Product-correct; Figma missing  |
| Closeout no session         | «لا توجد حصص مجدوَلة اليوم»               | **Not in Figma**                       | Product-correct; Figma missing  |

### Classes

| State                          | App         | vs Figma                                                                         |
|--------------------------------|-------------|----------------------------------------------------------------------------------|
| Loading / error / empty / list | Implemented | Figma shows populated list only on `1:914`; empty/error not designed for teacher |

### Messages

| State           | App         | vs Figma                            |
|-----------------|-------------|-------------------------------------|
| Loading / error | Yes         | Unspecified / richer empty in Figma |
| Empty           | Minimal     | Figma illustrated empties richer    |
| Success list    | Basic tiles | Figma denser chrome                 |

### Profile

| State                     | App                  | vs Figma                  |
|---------------------------|----------------------|---------------------------|
| Halaqat loading for stats | Spinner strip        | Unspecified               |
| Halaqat error             | Text only (no retry) | **Weaker than dashboard** |
| Success                   | Stats + logout       | Figma has more sections   |
| Logout success            | Via `AuthBloc`       | Not shown in Figma Home   |

---

## 6. Widgets that should be deleted

| Widget / surface                          | Why                                                                                            |
|-------------------------------------------|------------------------------------------------------------------------------------------------|
| **None safely deletable for match Figma** | Figma Home body is student mushaf; deleting agenda would destroy approved W3 product behavior. |
| Do **not** re-add posts tab widgets       | H6 deliberately removed; keep deleted.                                                         |

**Recommendation:** Do **not** delete `_TodayAgendaSection` / closeout widgets to chase Figma
`1:432`.

---

## 7. Widgets that should be rebuilt

| Widget                                             | Rebuild reason                                                               |
|----------------------------------------------------|------------------------------------------------------------------------------|
| `_TeacherBottomNav`                                | Rebuild only after Figma teacher IA is corrected. Do not copy student 5-tab. |
| `_TeacherHeader`                                   | Rebuild to approved teacher header.                                          |
| `_TeacherStatsRow` / `_StatCard`                   | Rebuild metrics/layout once Figma defines teacher Home metrics.              |
| `_TodayAgendaSection` and children                 | **Keep behavior**; rebuild visuals when teacher agenda appears in Figma.     |
| `_EmptyHalaqatCard`                                | Rebuild empty illustration/copy to design system.                            |
| `TeacherClassesPage` `_HalaqaCard` / `_ActionChip` | Rebuild CTAs/layout to teacher classes Figma.                                |
| `TeacherMessagesTab` list + empty                  | Rebuild to messages visual system; add compose only if product wants it.     |
| `TeacherProfileTab` body                           | Rebuild beyond logout to match real teacher profile Figma.                   |

---

## 8. Existing BLoCs / UseCases to reuse (no architecture change)

**No Cubits in repo.** Reuse as-is:

| Layer                         | Reuse                                                                             |
|-------------------------------|-----------------------------------------------------------------------------------|
| `TeacherBloc`                 | `LoadTeacherHalaqatEvent`, `LoadTodayAgendaEvent`, halaqat + `todayAgenda*` state |
| `GetTeacherHalaqatUseCase`    | Halaqat list / counts                                                             |
| `GetTodayAgendaUseCase`       | Day agenda projection                                                             |
| `AuthBloc`                    | Name, uid, logout                                                                 |
| `NotificationsBloc`           | Unread badge                                                                      |
| `TeacherDayAgenda` read model | Agenda / closeout                                                                 |
| `ChatConversationsBloc`       | Messages tab                                                                      |
| `SelectHalaqaEvent`           | Classes → detail                                                                  |

Do not invent new Cubits/BLoCs/UseCases for a Home UI pass. Deep workflows stay behind existing
`TeacherBloc` UseCases; Home only deep-links.

---

## 9. Audit scope checklist

| Deliverable                         | Section              |
|-------------------------------------|----------------------|
| Screenshot-by-screenshot comparison | §1                   |
| Every UI mismatch                   | §2                   |
| Every missing interaction           | §3                   |
| Every wrong navigation              | §4                   |
| Every incorrect state               | §5                   |
| Widgets to delete                   | §6                   |
| Widgets to rebuild                  | §7                   |
| Cubits/UseCases reuse               | §8 (BLoC, no Cubits) |
| No architecture change / no code    | Honored              |

---

## 10. Approval gate

**Stop here.** No implementation until you approve one of:

1. **Provide / point to real Teacher Home Figma** (not student shell under `المعلم`), then re-audit
   pixels; or
2. **Declare app W3 Teacher Home as UI SSOT** and treat Figma `2:4394` as non-binding for Home; or
3. **Explicit hybrid:** keep W3 agenda IA; restyle chrome only to a named Figma node you designate.

Awaiting approval.
