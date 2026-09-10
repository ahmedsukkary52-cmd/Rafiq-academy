# Shared UI / RTL / localization / theme / responsive / states audit

**Baseline:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Priority:** High (requested). No fixes in this audit.

Shared primitives live in `lib/shared/theme/app_theme.dart` and `lib/shared/widgets/shared_widgets.dart` (`AppButton`, `AppTextField`, `AppCard`, snackbars). **Role shells do not use a single app chrome.** Equivalent Figma jobs are re-implemented per role.

---

## 1. Design-system inventory

| Primitive | Shared? | Notes |
|-----------|---------|-------|
| Colors / radii / icon sizes | `AppColors`, `AppSizes` | Tokens exist; often bypassed |
| Typography helpers | `AppTextStyles` (Cairo + **light** colors baked in) | Dark-unsafe |
| ThemeData light/dark | `AppTheme.theme` / `darkTheme` | Applied in `MaterialApp.router` |
| Buttons | `AppButton` + many raw `ElevatedButton`/`TextButton` | Spinner always white |
| Inputs | `AppTextField` + many raw `TextField`/`InputDecoration` | Admin create halaqa uses raw fields |
| Cards | `AppCard` + custom containers | |
| Bottom nav | **Five copies** | AUD-041 |
| Subpage header | **Three+ copies** | AUD-042 |
| Avatars | `ParentUserAvatar` vs student header vs chat | Different sizes/fallbacks |
| Empty/error | Ad hoc per page | Shared `AppErrorWidget` exists in `shared_widgets.dart` and is **underused** |
| Shimmer/skeleton | **Five** Pulse copies (Admin / Parent / Supervisor / Teacher-excuse / role-home variants) | Student often `CircularProgressIndicator` |
| Chips | Theme chipTheme + custom status chips | Teacher excuse chips vs payment chips |
| Search | Per-list `TextField`, not shared | Supervisor students, teacher classes, parent messages |
| Dialogs / sheets | Mix `AlertDialog`, custom sheets, `showModalBottomSheet` | Assign sheet, create activity, Admin rating dialogs |
| Section headers | Each role’s Figma cards | Teacher `teacher_home_figma_cards.dart` forces RTL |

`HalaqaActivitiesMockStore` is **not** a visual component but a leftover UI-first store still under `lib/shared/presentation`.

---

## 2. Cross-role comparison (same job)

### AppBar / Header

| Role | Pattern | Back control | Background |
|------|---------|--------------|------------|
| Admin subpages | `AdminSubpageScaffold` Material `AppBar` | `Icons.arrow_forward_ios_rounded` in a square (intended RTL back) | `AppColors.surface` |
| Supervisor subpages | Custom column header | `Icons.chevron_right_rounded` circle | `AppColors.surface` |
| Parent subpages | Custom header | Custom circle; header bg often `Color(0xFFF5FAFB)` **hardcoded** | Not `AppColors.background` |
| Teacher | **No** shared subpage scaffold. Figma stacked headers / sometimes AppBar | Mixed | Gradient / teal tokens |
| Student | Mix AppBar (`SettingsPage`) and custom home header (`StudentHeaderWidget`) | AppBar default / custom | Light tokens |
| Auth | Teal `AppColors.primary` banner, NotoNaskh titles | `Icons.arrow_back_rounded` **white** | Primary (not theme surface) |

**Inconsistent:** height, padding (Admin `right: 12` vs Parent `fromLTRB(16,8,16,12)`), title size, subtitle support.

### Bottom navigation

| Role | Tabs | Implementation |
|------|------|----------------|
| Admin | 5: home, students, hub, wallet, settings | `AdminBottomNav` |
| Supervisor | 5: home, students, messages, reports, account | `_SupervisorBottomNav` |
| Teacher | 5: home, students, awards, messages, account | `_TeacherBottomNav` (H6 still lists 4) |
| Parent | 5: home, children, messages, payments, account | `_ParentBottomNav` |
| Student | 5: الرئيسية، مصحفي، elevated star (badges), خريطتي، حسابي — **no** `*HomeNav` class | Inline `_tabs` / `_StudentBottomNav` |

Shared: `AppSizes.bottomNavHeight = 64`, selected `AppColors.primary`.  
Unshared: icon sets, label overflow on ~320px, shadow, `SafeArea` wrapping.

### Cards / lists / chips

Teacher class cards, Supervisor student rows, Parent child cards, Admin hub tiles, Student progress donut — same data (name, %, avatar) with different radii (`radiusL` vs ad hoc 12), progress as linear vs donut vs mini bar.

Payment status chips: Parent `parent_display.dart` vs Supervisor payments vs Admin finance filters — duplicated Arabic labels (`متأخر`, `مدفوع`).

### Empty / error / loading

| Role | Loading | Empty | Error + retry |
|------|---------|-------|----------------|
| Admin | `admin_loading_skeletons.dart` on several tabs | Ad hoc text | Some refresh; not universal |
| Supervisor | `supervisor_loading_skeletons.dart` | Copy in lists | Mixed |
| Parent | `parent_loading_skeletons.dart` | Children empty if no ids | Snackbar + SectionStatus.error |
| Teacher | Home Figma placeholders; excuse skeletons | Designed empty CTAs | Mixed |
| Student | Often `CircularProgressIndicator`; `AppErrorWidget` rarely | Arabic empty strings | Weak retry |

Button spinner ≠ page loading (`AppButton.isLoading` vs page indicator) — not used consistently on Admin create / Supervisor admit.

---

## 3. Duplication register

| Duplicated | Where | Inconsistency |
|------------|-------|----------------|
| Bottom nav chrome | 5 files | Icons, labels, 4 vs 5 teacher tabs vs H6 |
| Subpage scaffold | Admin / Parent / Supervisor | Back icon, bg color, AppBar vs column. **Teacher has none** (AUD-042) |
| Notification badge | `NotificationBadge` | `Positioned(right: -4)` — physical right, not `end`; RTL-fragile |
| User avatar | Parent widget vs student vs chat | Size, fallback, phone overlay |
| Logout | `confirm_logout.dart` shared **and** per-account tabs | |
| Settings rows (dark mode, language, font) | Teacher profile, Supervisor account, Student settings, Parent profile | Language dead; font only some roles |
| Directionality.rtl wrapper | Almost every shell **and** inner Figma cards | Nested RTL |
| Status chips | Payments, excuses, attendance | Colors from AppColors vs raw |
| Money labels | `parentMoneyLabel` vs Admin `admin_format` | |
| Eastern digits | Teacher/parent helpers; student often raw | AUD-093 |
| Network/error snackbars | `AppSnackBar` vs raw `SnackBar` | |

---

## 4. RTL / LTR

### What the app actually does

- `MaterialApp.router` sets **no** `locale`, **no** `builder` Directionality.
- Flutter default locale follows device; **widgets force `TextDirection.rtl`**.
- Calendar uses `locale: 'ar'`.
- Day-name parser accepts English weekday strings as **data**, not UI locale.

### Semantic back

| Control | RTL semantic risk |
|---------|-------------------|
| `Icons.arrow_back` / `arrow_back_rounded` | Framework **mirrors** in RTL → visual forward-of-Arabic if Directionality is RTL. Usually correct as “back”. |
| `Icons.arrow_back_ios` / `arrow_back_ios_new` | Also directional; mixed usage. |
| `Icons.arrow_forward_ios_rounded` as Admin **leading back** | Author intended RTL “point to the end of reading” as back. If an ancestor is LTR, this **points the wrong way**. Nested `Directionality` makes this fragile. |
| `Icons.chevron_right_rounded` Supervisor back | Same: relies on forced RTL. |
| Mushaf `arrow_back` / `arrow_forward` | May mean **page turn in mushaf order**, not navigator back — **do not blindly flip**. Classify as **content-directional**, not nav-directional. |

### Classification

**Directional (should follow locale, not hardcoded RTL):** nav back, list chevrons, “see all” arrows, TabBar, Row start/end padding that was physically swapped.

**Non-directional (must not flip):** wallet, groups, awards, language, headphones, moon (dark mode), check, error, star.

**Forced RTL Rows** inside already-RTL shells: double-application risk if locale ever becomes EN.

**LTR English:** **not implementable** without removing hardcoded `TextDirection.rtl` and introducing localizations. Dead «اللغة» rows (AUD-045).

---

## 5. Localization (AR + EN)

| Check | Result |
|-------|--------|
| ARB / intl | **None** |
| Hardcoded UI | Essentially **all** screens Arabic string literals |
| English UI | Auth errors have no EN; some code comments EN; day labels parse EN |
| Mixed AR/EN | Recitation types in code EN enums, stored grades Arabic; notification types English keys; UI Arabic |
| Terminology | «حلقة» vs class vs session vs حصة; «استئذان» (Parent) vs «الاعتذار» (Teacher) vs «الاعتذارات» (Supervisor) vs English `excuses` (AUD-102); payments «اشتراكات» vs «مدفوعات» |
| Pluralization | Manual concatenations (`'$n يوم'`) — no plural rules |
| Dates | `formatDateDmy`, `time_format.dart`; calendar `ar` |
| Numbers | Mix western and eastern digit helpers |
| Validation / errors | Arabic (`معرّف ولي الأمر مطلوب`, NetworkFailure default) |
| Notifications | Composer Arabic titles |
| Empty / buttons / nav | Arabic |
| Overflow after language switch | **Cannot switch.** Long Arabic names already overflow-risk. EN would need new layout pass. |

---

## 6. Dark / light

- Preferences: `AppPreferencesController` SharedPreferences `dark_mode_enabled`.
- `themeMode` wired in `MyApp`.
- `AppTheme.darkTheme` defines dark scaffold `0xFF12121C`, `AppColors.darkCard`.

**Breaks dark:**

- Role `Scaffold(backgroundColor: AppColors.background)` light grey.
- `AppTextStyles` navy text.
- Parent header `0xFFF5FAFB`.
- Auth `Colors.white` on primary (OK on teal, fails if used on dark cards).
- Student mushaf / audio library many `Colors.white` / `Colors.black`.
- Charts/donuts use `AppColors.surfaceGrey` track.
- Shimmers typically light greys.
- `AppButton` white spinner.

**Hardcoded colors:** `AppTheme` itself is token source (OK) plus dozens of `Color(0x…)` in feature pages (not OK).

Disabled / error / warning / success tokens exist (`AppColors.error` etc.) but many screens use `Colors.red` / raw.

---

## 7. Responsive / overflow (static)

Not device-run in this audit. Risky patterns:

| Pattern | Where | ~320 risk |
|---------|-------|-----------|
| 5-item bottom nav labels | All shells | Truncation / overflow |
| `Row` + unbounded `Text` names | Rosters, chat titles, Admin tiles | Overflow |
| Fixed donut 80×80 | `StudentProgressWidget` | OK small; label row may overflow |
| `AppButton` height 52 full width | Forms | OK; keyboard on Admin create + dropdowns |
| Grid/hub tiles | Admin management | Tablet unused; phones wrap poorly if long labels |
| Mushaf pager | Student | Complex; many fixed sizes |
| Dialog `AlertDialog` + TextField | Admin teachers | Keyboard inset |
| Long Arabic teacher notes | Parent reports | No maxLines some paths |
| Large money amounts | Parent/Admin | |

`MediaQuery` textScaler from font size setting **increases** overflow risk on large font + 320 width.

---

## 8. Loading / empty / error / retry (major screens)

| Screen | Loading | Success | Empty | Error | Retry |
|--------|---------|---------|-------|-------|-------|
| Login | Button/page loading via AuthLoading | Redirect | N/A | Snackbar | Resubmit |
| Register | Same | Auth | N/A | Snackbar | Resubmit |
| Student home | Bloc status / indicators | Profile widgets | Zeros look like data | Weak | Pull not universal |
| Teacher home | Feed use case | Figma cards | Designed empty CTAs | Mixed | Reload on init |
| Teacher attendance | Page load | Register | Empty roster vacuously complete | Failure Left | Recreate page |
| Teacher eval | Service block reasons | Sheet | noSessionToday copy | Block, not always retry | |
| Parent home | SectionStatus + skeletons | Tabs | No children | wallet/payments errors | Reload init |
| Parent payments | List | History | No invoices | Index miss / network | Unclear |
| Supervisor board | Day board UC | Cards | No halaqat | Error | Reload |
| Supervisor payments | List | Sorted pending first | Empty | Error | |
| Admin dashboard | Stats | Cards with **0** | Looks populated | Error | Refresh event |
| Admin finance | Full get | Totals | Empty sums 0 | Error | |
| Chat room | Stream | Messages | Empty thread | Send fail local | Resend new doc |
| Notifications | Watch 50 | List | Empty | Error | Restart watch |

Indefinite loading risk: Auth splash while `AuthLoading`; chat student gateway if teacher unresolved; Firestore listeners without timeout.

---

## 9. Network / error taxonomy

| Kind | Distinguished in UI? |
|------|----------------------|
| No connectivity | Yes — if checker returns false (`NetworkFailure` Arabic default) |
| Checker timeout | Treated as **online** (5s) — good vs false “No Internet” |
| Firebase timeout | Auth maps; others often `e.toString()` |
| Firebase unavailable | Auth maps `unavailable`; others ServerFailure |
| Permission denied | Auth login maps; repositories usually ServerFailure |
| Validation | `ValidationFailure` some use cases |
| Not found | Payment “الدفعة غير موجودة” in some paths; else generic |
| Conflict | استئذان already decided; payment already paid — specific ServerException |
| Unknown | `UnexpectedFailure` / catch-all |

**Collapse to No Internet:** happens when `isConnected` is false **before** the Firebase call. Aggressive check is **mitigated** by timeout→true, but still blocks if checker returns false while Firebase would work (captive portal / checker endpoints blocked).

No stale-while-revalidate pattern except Firestore cache default. Partial failure: event publish best-effort after SSOT (teacher may see unpublished warning).

---

## 10. Recommended direction (documentation only)

Unify: one `AppScaffold` / `AppSubpageHeader` / `AppBottomNav` / `AppStateView` (loading/empty/error/retry) / semantic `BackButton`. Drive direction from locale. Stop baking light colors into `AppTextStyles`. Do **not** flip mushaf page arrows as nav.

No code in this audit.
)
