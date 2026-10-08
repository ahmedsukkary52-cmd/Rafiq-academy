# MUSHAF UX AUDIT — Design Direction (Audit Only)

**Status:** AUDIT (historical inventory)  
**Date:** 2026-09-23  
**Product locks:** D23 (PRODUCT_DECISIONS_LOCKED.md), C15 (SECURITY_DATA_CONTRACT_FREEZE.md)  
**Scope:** Documentation only — **no Mushaf production code was modified in this wave.**

> **Implementation specification (U-MUSHAF-0):** see **`docs/production/MUSHAF_UX_SPEC.md`**.  
> This audit remains the **verified current-state inventory**. The SPEC is the design/UX/logic source for implementation waves.  
> Where this audit’s “proposed direction” conflicts with the SPEC, **the SPEC wins**.  
> **Visual quality is a first-class acceptance criterion** (SPEC §0). Premium comfort is required; **do not clone Tarteel**.

> **Existing project Figma is not the Mushaf design source of truth.**  
> Mushaf UX/design is treated as an **independent product surface**.  
> Do not force dashboard/card/role-shell Figma patterns into the Quran reader.  
> External Quran apps (e.g. Tarteel and other established readers) may inform **UX principles only** — not layouts, branding, assets, or proprietary visuals.

---

## 1. Executive Summary

The current Mushaf is a **monolithic StatefulWidget** (`StudentMushafPage`, ~2,750 lines) plus a student-tab **dashboard** that mixes **memorization progress** into a “مصحفي” shell. Quran text is loaded from **alquran.cloud**, cached in **SharedPreferences**, and rendered as a **PageView of Uthmani pages** with tap-to-select ayahs and **everyayah.com** per-ayah audio.

**Verified gaps vs locked D23:**

| Locked requirement | Current behavior |
|---|---|
| First open → **Al-Fatihah** | Router + widget default **surah 67 (Al-Mulk)** when not `free=true` |
| Later open → **last-read** (per student) | Device-local `last_mushaf_page` (page int only); **ignored** on non-free routes that pass surah 67 |
| Last-read ≠ memorization | Last-read does not write progress (good), but **dashboard UI shows memorization stats** under “مصحفي” (confusing coupling) |
| Two polished visual modes | Local light paper / dark toggle only; not product-grade dual modes; dark not persisted |
| C15 `mushafReading/{studentId}` | **Not implemented** in client or Rules (docs only) |

**Primary UX pain:** reading chrome is heavy; entry points disagree on start location; “Coming Soon” clutter; dashboard looks like a progress product, not a reader; comfort typography is basic (Amiri @ 22 / height 1.6) without session-grade polish.

This document specifies an **implementation-ready** redesign direction for a future **U-MUSHAF** wave without changing code now.

---

## 2. Current Mushaf Architecture

### 2.1 Files inspected (primary)

| Path | Role |
|---|---|
| `lib/features/student/presentation/pages/student_mushaf_page.dart` | Full reader monolith (models, catalogs, load, PageView, audio, recording stubs, settings) |
| `lib/features/student/presentation/pages/student_mushaf_dashboard.dart` | Student bottom-nav tab “مصحفي” |
| `lib/features/student/presentation/pages/student_home_page.dart` | Entry: IndexedStack tab + profile “السورة الحالية” → mushaf |
| `lib/features/student/presentation/pages/student_recitation_page.dart` | Separate recitation/recording UI (pushed from mushaf “تسميع”) |
| `lib/features/student/presentation/pages/student_audio_library_page.dart` | Surah-level listening (mp3quran) — linked from dashboard, **not** wired to mushaf PageView |
| `lib/features/audio_library/data/datasources/mp3quran_catalog_service.dart` | Audio library catalog |
| `lib/core/router/router_app.dart` | `/student/mushaf` query: `surah`, `mode`, `free` |
| `docs/production/PRODUCT_DECISIONS_LOCKED.md` | D23 |
| `docs/production/SECURITY_DATA_CONTRACT_FREEZE.md` | C15 `mushafReading` |
| `docs/production/MASTER_ISSUE_MATRIX.md` | AUD-059 (default 67) |
| `docs/production/IMPLEMENTATION_PLAN.md` | U-MUSHAF wave notes |

### 2.2 Layers (verified)

| Layer | Present for Mushaf reading? |
|---|---|
| Presentation | Yes — StatefulWidget monolith |
| Bloc / events / states | **No** mushaf-specific Bloc |
| Domain entities / use cases | **No** |
| Repository | **No** for Quran text / last-read |
| Firebase `mushafReading` | **Contract only** (C15) — no Dart usage |
| Local persistence | SharedPreferences: `cached_entire_quran`, `last_mushaf_page` |
| Audio | `just_audio` + everyayah URLs in-page; mp3quran in separate feature |

### 2.3 In-file models (not shared domain)

- `SurahMeta` — static catalog (name, juz, type, versesCount); **juz unused in UI**
- `AyahModel` — number, numberInSurah, text, page, surahNumber
- `MushafMode` — `reading` | `recitation`
- Static `_allSurahNames`, `_reciters` (everyayah directories)

### 2.4 External data

- Quran text: `GET https://api.alquran.cloud/v1/quran/quran-uthmani`
- Ayah audio: `https://everyayah.com/data/{reciter}/{sss}{aaa}.mp3`
- Cache: entire Quran JSON string in SP (no TTL)

---

## 3. Current User Flow

```
Student opens app
  └─ Bottom tab «مصحفي» → StudentMushafDashboard
        ├─ Shows memorization % + completedJuz as «الختمة»
        ├─ CTA → /student/audio (library)
        ├─ CTA → /student/mushaf?free=true  («مصحف حر كامل»)
        └─ Placeholder «خطة الحفظ — Coming Soon»

  └─ Profile «السورة الحالية» → /student/mushaf (NO query)
        └─ Router defaults surahNumber = 67

StudentMushafPage
  ├─ Load: SP cache OR network → parse all surahs → group by page 1–604
  ├─ Initial jump:
  │     if !free && surah in map → that surah start (often 67)
  │     else if last_mushaf_page → that page
  │     else → page 1
  ├─ PageView swipe → _saveLastPage(page)
  ├─ Tap ayah → select + show bottom playback panel
  ├─ Surah picker sheet → jump
  ├─ Dark toggle (session-only)
  ├─ «تسميع» tab → pushes StudentRecitationPage (does NOT set MushafMode.recitation)
  └─ Menu: favorites/bookmark/share = Coming Soon; font size sheet exists
```

**Homework path (related, not mushaf reader):** homework → `StudentRecitationPage` with upload gated by `audioUploadsEnabled`.

---

## 4. Current UX Findings (high level)

| Finding | Type |
|---|---|
| Default open = Al-Mulk (67), not Al-Fatihah | **Verified bug vs D23** (AUD-059) |
| Last-read only honored in `free` mode | **Verified product mismatch** |
| Last-read is device page int, not per-student Firestore | **Verified gap vs C15** |
| Dashboard titled “مصحفي” but drives memorization metrics | **Observed UX confusion** (D11≠D23 violated in *presentation*, not data writes) |
| Heavy always-on AppBar + mode selector + optional bottom panel | **Reading comfort / chrome** |
| English “Coming Soon” on Arabic reader menus | **Honesty / polish** |
| No juz navigation despite catalog juz field | **Discoverability gap** |
| Dark mode not persisted; not C15 `visualMode` | **Incomplete D23 dual-mode** |
| Audio skip icons appear swapped for RTL | **Likely interaction bug** (code maps skip_next → previous) |
| ~2.7k-line monolith | **Maintainability risk** for redesign |

---

## 5. Reading Comfort Findings

**Verified implementation:**

- Font: `GoogleFonts.amiri`, default size **22**, line height **1.6**
- Page frame: light paper `0xFFF5F0E1` / dark gray when `_isDarkMode`
- Flow text: `TextAlign.justify`, RTL, ornamental ayah markers + Arabic digits
- Surah header decorative widget on first ayah of surah
- Font size adjustable via settings sheet (not persisted)

**Problems:**

1. **Chrome competes with text** — AppBar (primary/teal), mode selector, and panels reduce reading viewport.
2. **Line height 1.6 may clip dense diacritics** on Amiri for long ayahs (needs device validation; treat as high-risk comfort item).
3. **No dedicated Quranic font packaging** (Amiri via Google Fonts vs bundling Amiri Quran / Uthmani HAFS with fallbacks — industry guidance favors explicit Quran script stacks).
4. **Margins / page density** are ad-hoc Padding inside page frame — not a calibrated “mushaf page” system.
5. **Dashboard emoji header (`📖`)** and gradient marketing chrome feel unlike a serious reader.
6. **Session length** — no immersive/fullscreen reading mode that auto-hides chrome.

---

## 6. Navigation Findings

| Capability | Status |
|---|---|
| Page swipe (1–604) | Implemented |
| Surah picker bottom sheet | Implemented |
| Juz / hizb picker | **Missing** (juz in catalog only) |
| Current location | AppBar: `{surah} - صفحة {n}` |
| Page number | Arabic digits in AppBar |
| Last-read restore | Broken for primary non-free entry |
| Accidental navigation | Swipe pages always active; no “lock page” |
| Jump from profile “current surah” | Opens mushaf at **67**, not plan surah |

**Problems:**

- Two entry semantics (`free` vs default) confuse product story (“حر” vs normal).
- Surah list is long; no search/filter in picker (discoverability).
- No “Go to last-read” explicit affordance when user jumped elsewhere.
- Profile card implies curriculum surah but routes to wrong default.

---

## 7. Verse Interaction Findings

**Verified:**

- Tap ayah → select index, highlight background, bold text, open bottom panel, prepare audio
- Screen tap toggles bottom panel visibility
- Recognizers rebuilt after parse

**Problems:**

1. Selection highlight + bold is subtle; unclear what actions exist beyond audio.
2. Menu actions (favorite/bookmark/share) are **fake Coming Soon** — discoverable dead ends.
3. Continuous tap targets on dense text → accidental selection while scrolling/swiping.
4. No long-press / contextual sheet for “play / copy / bookmark” (bookmarks not real yet).
5. Recitation mode enum vs “تسميع” tab **disagree** — tab leaves the page entirely.

---

## 8. Audio Findings

### 8.1 In-reader audio (everyayah) — **real**

- Play/pause, seek, speed (1–2×), loop ayah, mute, prev/next ayah, reciter chips
- Network gate + snackbars
- Panel tied to selected ayah

**Issues:**

- Panel is large and sticky when shown — occludes text
- Skip icons likely inverted for RTL
- Current ayah during continuous play of next ayah — depends on skip logic; no strong “follow along” page auto-scroll guarantee documented in code path beyond selection
- Offline: text may be cached; audio requires network

### 8.2 Audio library (mp3quran) — **separate product surface**

- Full surah listening from dashboard
- Not synchronized with mushaf page / last-read / selected ayah

### 8.3 Recording / upload — **stub / gated**

- Inline recording panel when `MushafMode.recitation` (rarely used via UI)
- Upload labeled Coming Soon / capability flag false
- Homework path has separate upload rules

**Do not invent new audio backend in redesign unless product re-opens uploads.**

---

## 9. Last-Read Findings

| Aspect | Verified |
|---|---|
| Storage | `SharedPreferences` `last_mushaf_page` (int) |
| Update timing | Every `PageView.onPageChanged` |
| Race | Unawaited writes possible on fast swipes; last write wins locally |
| Restore | Only when free mode OR surah jump not applied |
| Per-student | **No** — device-global key |
| Multi-device | **No** |
| Fields | Page only — **not** surah/ayah as C15 |
| Coupling to D11 | Does **not** write memorization fields (good) |
| UI coupling | Dashboard displays D11 metrics next to mushaf entry (bad messaging) |

**C15 target (locked contract, unimplemented):**  
`mushafReading/{studentId}`: `surahNumber`, `ayahNumber`, optional `pageNumber`, `updatedAt`, optional `visualMode`.

---

## 10. Loading / Error Findings

| State | Current |
|---|---|
| Initial load | Center spinner |
| Error | Icon + Arabic message + retry |
| Empty pages list | `SizedBox.shrink()` — weak |
| Malformed JSON | Falls into catch → error string |
| Cache corruption | Not specially handled |
| Audio offline | Snackbar; no offline audio cache |

Uses ad-hoc UI — not `AppEmptyState` / `AppErrorWidget` (acceptable for specialized reader, but consistency optional).

---

## 11. Responsive Findings

**Verified from code structure (not device lab):**

- `PageView` + `Expanded` — adapts to phone heights
- Font size user-adjustable helps small phones
- Safe area: AppBar / sheets use SafeArea in places; page content padding is fixed-ish
- Landscape: no dedicated layout; justify text will reflow (mushaf “page” metaphor weakens)
- Very long ayahs: RichText flow may wrap awkwardly; no max-width / tablet layout

**Assumption:** Primary target = phone portrait RTL. Landscape = best-effort unless product requires otherwise (**open question**).

---

## 12. External Inspiration / References

**Access:** Web search available for public UX articles. **No cloning.** Project Figma **not** used as Mushaf target.

### Principles extracted (inspiration only)

Sources include public Tarteel help/blog content and open Quran-app UX writing (e.g. Quranic font / last-read / theme discussions):

1. **Text is the product** — chrome minimizes; controls contextual.
2. **Quran-specific fonts + generous line height** for diacritics; validate on densest ayahs.
3. **Last-read is automatic**; bookmarks are intentional (when product adds them).
4. **Reading themes** (paper / night / sepia) independent of app shell theme.
5. **Optional adaptive layout vs traditional page layout** as modes — maps to D23 “two polished modes” without copying Tarteel Adaptive Mode UI.
6. **Audio follow-along highlight** when playback is active.
7. **RTL-first** logical edges throughout.

### Explicitly not copied

Exact layouts, brand colors, icons, assets, proprietary AI features, social, or Tarteel Adaptive Mode chrome.

---

## 13. Current vs Desired Comparison

| Area | CURRENT | PROBLEM | DESIRED | CONSTRAINT |
|---|---|---|---|---|
| First open | Surah 67 | Violates D23 | Al-Fatihah | D23 locked |
| Resume | SP page; ignored on default route | Unpredictable | Per-student last-read | C15 schema |
| Progress UI | Memorization on mushaf tab | Conceptual mix | Reader entry ≠ progress dashboard | D11 ≠ D23 |
| Chrome | Always-on AppBar + modes | Distraction | Immersive reading; chrome on tap | Arabic RTL, light app shell |
| Modes | Light/dark toggle | Incomplete | Two polished **reading** visual styles (+ optional night) | App shell stays light; mushaf may night |
| Verse | Tap select + audio | Dead Coming Soon actions | Clear select + real actions only | No fake CTAs |
| Audio | everyayah panel | Heavy; RTL skip bug | Compact contextual player | Existing everyayah OK; no new backend required |
| Architecture | Monolith | Hard to evolve | Presentation modules + optional Bloc | Clean Architecture preferred |
| Data | API + SP cache | No C15 | Keep text source; add C15 last-read | Don’t break Quran model without need |

---

## 14. Proposed Mushaf UX Direction

### 14.1 Reading surface
Immersive Quran page as the hero. Soft paper (or night) canvas. Minimal permanent chrome. Tap center → toggle chrome visibility.

### 14.2 Typography
- Bundle/prefer a **Quran-capable** Arabic stack (e.g. Amiri Quran / Uthmani HAFS with fallbacks).
- Default size tuned for phone; persistent user font size.
- Line height calibrated for tashkeel (≥ ~1.8–2.0 candidate — **validate on device**).
- Generous horizontal margins; avoid edge-clipped glyphs.

### 14.3 Page / verse spacing
Consistent page padding token set **local to Mushaf** (not dashboard `AppSizes` cards). Clear ayah separators without noisy chips.

### 14.4 Header / navigation
- Collapsible top bar: surah name + page.
- Surah picker with search.
- Optional juz index (phase 2 if not blocking).
- Explicit “آخر قراءة” when not at last-read.

### 14.5 Verse interaction
- Tap = select + lightweight action bar (Play; later Bookmark only if real).
- Remove Coming Soon items from primary menus until implemented.
- Distinct selected + “now playing” styles.

### 14.6 Audio controls
- Compact bottom sheet / mini player; auto-hide when idle.
- Fix RTL prev/next semantics.
- Reciter selection retained.
- Do not merge mp3quran library into the page chrome by default (keep as separate “استماع” entry).

### 14.7 Reading / night mode
- **Mode A:** Day / paper mushaf (default).
- **Mode B:** Night / low-glare reading (independent of app ThemeMode).
- Persist via C15 `visualMode` when C15 is implemented.
- App shell remains light (D15/D23).

### 14.8 Surah / page navigation
Page swipe retained; surah jump retained; add search; consider page-number go-to.

### 14.9 Last-read indicator
Silent auto-save; optional subtle “استكمال القراءة” on dashboard entry; never show as memorization %.

### 14.10 Settings
Font size (+ later line spacing if needed); visual mode; default reciter. Persist locally and/or C15.

### 14.11 States
Loading skeleton appropriate for page; error + retry; empty only if data truly empty; offline text-from-cache messaging.

### 14.12 Accessibility / readability
Large tap targets for chrome; Dynamic Type consideration within mushaf settings; high contrast night mode; test longest ayahs and elderly users’ font sizes.

---

## 15. Proposed Information Architecture

```
Student «مصحفي» tab
  ├─ Reader entry (primary) → Mushaf Reader (resume last-read / Al-Fatihah)
  ├─ Optional: Audio library entry (existing)
  └─ Memorization progress → Student Progress surfaces (NOT inside reader chrome)

Mushaf Reader
  ├─ Always: Quran page content
  ├─ On tap: top location bar + bottom tools
  ├─ Sheets: Surah index, Settings, Reciter
  ├─ Verse select: mini actions (Play…)
  └─ Exit: pop / back to student shell
```

**Remove from mushaf tab header:** framing memorization % / khatma as the primary story of “مصحفي”.

---

## 16. Interaction Model

| Always visible | After tap / gesture | Sheet / overlay | Verse contextual |
|---|---|---|---|
| Quran text page | Top: surah + page + back | Surah index (search) | Play / pause |
| | Bottom: mini audio if playing | Settings (font, mode, reciter) | (Future) bookmark if real |
| | | | |

**Navigation:**

- Horizontal page turn = mushaf pages  
- Surah index = jump to first page of surah  
- Open reader = restore C15 last-read; if none → surah 1 ayah 1 / page 1  
- “تسميع” for homework remains a **separate** flow (StudentRecitationPage / homework) — do not overload reader with upload UX while uploads disabled  

**Return to last-read:** automatic on open; optional chip if user navigated away in-session.

---

## 17. Accessibility / Readability Requirements

1. RTL Directionality locked on reader.
2. Font size persistence (min/max bounds).
3. Contrast AA-ish for paper and night themes.
4. No essential info only in color.
5. Screen-reader: announce surah/page on change (future enhancement — note as non-blocking).
6. Avoid English “Coming Soon” in Arabic UI.
7. Safe areas respected in immersive mode.

---

## 18. Architecture Impact Classification

| Proposed change | Class | Notes |
|---|---|---|
| Immersive chrome, typography, themes, empty/error polish | **A — UI-only** | Presentation rewrite |
| Fix default Al-Fatihah + honor last-read on all entries | **B — existing can support** | Router + init logic; then C15 |
| Persist font size / dark locally | **B** | SharedPreferences |
| Implement C15 `mushafReading` client + Rules | **C — small contract** | Contract already locked; Rules + repo/use case needed |
| Split monolith into widgets + optional MushafCubit/Bloc | **B** | Refactor, same behavior |
| Fix audio RTL controls / mini player | **B** | Existing just_audio |
| Wire mp3quran into page follow-along | **D / out of scope** | New product glue — avoid unless required |
| Bookmarks / favorites / share | **D** unless scoped | New data; keep out of v1 redesign |
| Online mushaf image pages (PDF/png mushaf) | **D** | New assets pipeline — not required |
| Change Quran text API / schema | **Avoid** | Keep alquran.cloud or migrate carefully later |
| Memorization plan lock on surahs | **Out of scope** | Dashboard TODO; not reader comfort |

---

## 19. Future Implementation Requirements

Suggested **U-MUSHAF** implementation order:

1. **Correctness (D23/C15):** Al-Fatihah default; implement `mushafReading`; remove surah-67 default; unify entry points; stop ignoring last-read.
2. **Honesty:** Remove Coming Soon dead actions; split memorization stats off mushaf entry chrome.
3. **Reader chrome redesign:** Immersive reading; tap-to-reveal controls; Mushaf-specific theme tokens.
4. **Typography pass:** Font stack, sizes, line height, margins; device QA on dense ayahs.
5. **Audio polish:** Mini player; RTL controls; playing highlight; keep everyayah.
6. **Architecture cleanup:** Extract widgets; introduce presentation Bloc/Cubit; repository for Quran cache + C15.
7. **Optional phase-2:** Juz index, bookmarks (real), surah search polish, landscape layout.

**Do not** redesign Mushaf from role Figma. **Do not** expand into adventure map / Admin / password.

---

## 20. Future Test Requirements

Minimum suite for implementation wave:

| ID | Requirement |
|---|---|
| T1 | First open (no C15 doc) → Al-Fatihah (surah 1 / page 1) |
| T2 | After page change + reopen → restores last-read |
| T3 | Last-read document does not mutate memorization progress fields |
| T4 | Dashboard/progress widgets still use D11 fields independently |
| T5 | Page swipe updates persisted position |
| T6 | Surah jump works and updates last-read |
| T7 | Verse selection highlights correct ayah |
| T8 | Audio play/pause for selected ayah (existing everyayah) |
| T9 | Night/reading mode toggles and persists if C15 `visualMode` used |
| T10 | Arabic RTL: no LTR chrome regressions; prev/next audio correct |
| T11 | Loading → success path |
| T12 | Network failure → error + retry |
| T13 | Cached Quran loads offline for text |
| T14 | State restoration after process kill (C15 or local) |
| T15 | Router entries (`/mushaf`, `?free=`, profile link) all honor D23 |

Prefer unit/widget over goldens unless goldens already standardized.

---

## 21. Explicit Out-of-Scope Items

- Implementing the redesign in this audit wave  
- Copying project Figma dashboards into Mushaf  
- Cloning Tarteel / other apps’ UI  
- Student Adventure/Map  
- Admin V1  
- Password recovery  
- Mushaf social / gamification / streaks inside reader  
- Enabling audio uploads / new Storage pipelines  
- Translation / transliteration layers (unless later product decision)  
- AI recitation coaching  
- Changing Firebase progress contracts (D11)  
- Multi-tenancy / English LTR / app-wide dark theme  

---

## 22. Open Questions / Decisions Required

1. **Two polished modes (D23):** Confirm definition = (A) Paper vs Night, or (A) Traditional page metaphor vs Adaptive reflow? *(Recommendation: Paper vs Night for v1; adaptive reflow later.)*
2. **Mushaf tab IA:** Keep a dashboard wrapper or open **directly into reader**?
3. **Audio library:** Remain separate entry only, or deep-link “listen to this surah” from reader settings?
4. **Bookmarks:** In v1 or explicitly deferred?
5. **Juz navigation:** v1 or phase-2?
6. **Landscape:** Support or portrait-lock?
7. **Quran font packaging:** Google Fonts Amiri vs bundled Uthmani font files (licensing + size)?
8. **C15 write frequency:** every page change vs debounced vs on dispose?
9. **Profile “السورة الحالية”:** Should it open plan surah, last-read, or Al-Fatihah?
10. **Recitation tab:** Keep push to `StudentRecitationPage` or fold a lighter practice mode later?

---

## 23. Recommended Next Implementation Wave Structure

| Wave | Goal | Depends |
|---|---|---|
| **U-MUSHAF-0** | Spec freeze answers to §22 + C15 Rules stub if missing | This audit |
| **U-MUSHAF-1** | D23 correctness (Al-Fatihah + C15 last-read + entry unification) | U-MUSHAF-0 |
| **U-MUSHAF-2** | Immersive reader UI + typography + night mode | U-MUSHAF-1 |
| **U-MUSHAF-3** | Audio mini-player polish + RTL fixes | U-MUSHAF-2 |
| **U-MUSHAF-4** | Architecture extraction + full regression suite (§20) | U-MUSHAF-2/3 |
| **U-MUSHAF-5** | Optional bookmarks/juz/search enhancements | Product approval |

---

## Appendix A — Legend

| Tag | Meaning |
|---|---|
| **Verified** | Confirmed in current code/docs |
| **Observed problem** | UX issue inferred from verified behavior |
| **Proposed** | Design direction for future implementation |
| **Inspiration** | External principle, not a clone mandate |
| **Assumption** | Not device-lab verified |
| **Open** | Needs product owner decision |

---

## Appendix B — Key code anchors (verified)

- Router default surah **67**: `router_app.dart` mushaf GoRoute  
- Last page SP + init jump: `student_mushaf_page.dart` `_loadSurahData` / `_saveLastPage`  
- Amiri 22 / height 1.6: `_buildMushafFlowText`  
- Coming Soon menu: `_showSurahActionsMenu`  
- C15 contract: `SECURITY_DATA_CONTRACT_FREEZE.md` §15  
- D23 lock: `PRODUCT_DECISIONS_LOCKED.md` §D23  

---

**End of audit.**  
**No Mushaf production code changed.**  
**Next step:** Product answers to §22, then U-MUSHAF-1 implementation wave.
