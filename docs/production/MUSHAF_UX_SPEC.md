# MUSHAF UX SPEC — Design, UX & Logic Foundation (U-MUSHAF-0)

**Status:** SPECIFICATION ONLY — no production implementation in this wave  
**Date:** 2026-09-23 (visual-quality lock amended 2026-09-25)  
**Supersedes design direction in:** `docs/production/MUSHAF_UX_AUDIT.md` (audit remains historical inventory)  
**Product locks:** D23 (`PRODUCT_DECISIONS_LOCKED.md`), C15 (`SECURITY_DATA_CONTRACT_FREEZE.md`)  
**Architecture:** Clean Architecture + **Bloc** (not Cubit)

> **Existing project Figma is NOT the Mushaf design source of truth.**  
> Mushaf is an independent Quran-reading product surface.  
> Do not force dashboard/card/role-shell Figma into the reader.

> ### Anti-clone rule (non-negotiable)
>
> High-quality Quran apps such as **Tarteel** and other established readers may be used **only** as:
> - comfort / readability **benchmarks**
> - UX **principle** references (immersion, typography care, calm chrome)
>
> **Do NOT copy or recreate:**
> - Tarteel (or any other app) layouts, screens, or component arrangements  
> - branding, colors, logos, icons, assets  
> - proprietary visual identity or motion language  
> - proprietary features (AI coaching, Adaptive Mode chrome, etc.)
>
> **Goal:** an **original Rafiq Academy Mushaf** visual language — premium and calm — not a clone and not a generic Flutter `PageView` with text dumped on screen.

---

## 0. Visual Quality — First-Class Acceptance Criterion

**Visual quality is a first-class acceptance criterion** for every Mushaf implementation wave.

A wave is **not complete** if it only:

- compiles  
- passes unit/widget tests  
- “technically” meets functional requirements  

…but looks **weak, cluttered, generic, Material-default, dashboard-like, or uncomfortable for prolonged Quran reading**.

### 0.1 Quality bar

The shipped Mushaf must feel like a **polished, premium Quran-reading application**, comparable in *comfort, visual hierarchy, typography, spacing, calmness, navigation clarity, and interaction quality* to high-quality Quran readers — while remaining **visually original** to Rafiq Academy.

### 0.2 What “done” requires (visual review)

Before reporting any Mushaf wave finished, the implementer must visually review real devices / emulators as a **production product**, not only as a code task, and refine until the checklist below passes.

| Focus | Required outcome |
|---|---|
| Arabic typography & readability | Clear glyphs, comfortable diacritics, no cramped tashkeel |
| Quran text hierarchy | Text dominates; chrome is secondary and quiet |
| Line height & margins | Generous, even rhythm; no edge-clipped marks |
| Page density | Neither sparse nor cramped; readable page “breathing” |
| Visual rhythm between ayahs | Calm separators; no noisy chips/cards per ayah |
| RTL correctness | Start/end padding, directional controls, no LTR leftovers |
| Touch targets | Chrome controls ≥ ~44 dp; ayah tap still precise |
| Motion | Subtle chrome show/hide only; no decorative gimmicks |
| Immersion | Default state = reading; controls on demand |
| Audio controls | Elegant, compact mini-player — not a media dashboard |
| Navigation | Clean index/sheets — not a heavy drawer competing with text |
| Paper / Night | Distinct, comfortable reading surfaces (not app ThemeMode hack) |
| Loading / empty / error | Calm, Arabic, on-brand for a reader — not generic spinners only |
| Responsive | Comfortable on small / normal / large phones (tablet if supported) |

### 0.3 Explicit visual anti-patterns (reject as incomplete)

- Generic Flutter `PageView` + raw `Text` look  
- Excessive cards, heavy borders, multi-layer shadows  
- Oversized headers / permanent toolbars stealing the page  
- Crowded bottom panels covering half the mushaf  
- Default Material buttons/sliders left unstyled in the reading surface  
- Visually noisy chrome (badges, stats, emoji headers, English “Coming Soon”)  
- Role-dashboard Figma patterns forced onto the reader  
- **Any screen that a user could mistake for a clone of Tarteel or another Quran app**

### 0.4 Original visual language (Rafiq Academy)

Define Mushaf-local tokens (names illustrative; finalize in U-MUSHAF-2):

- **Paper:** warm ivory canvas, deep ink text, soft selection wash (academy teal at *low* alpha — accent, not a teal billboard)  
- **Night:** deep charcoal canvas, soft off-white ink, muted selection  
- **Chrome:** thin, low-contrast bars/sheets; typography from app UI font for labels only  
- **Motion:** 200–280 ms ease for chrome; no bounce/elastic gimmicks  

Academy brand may appear as a **quiet accent** (selection, play affordance) — never as a marketing gradient header over Quran text.

---

## 1. Product Vision

The Mushaf must feel:

| Trait | Meaning |
|---|---|
| Calm | Soft surfaces; no urgency chrome |
| Comfortable | Typography and contrast tuned for long sessions |
| Focused | One job: read (and optionally listen to) Quran |
| Arabic-first | All visible copy Arabic |
| RTL-first | Logical start/end; directional controls correct |
| Minimal | No dashboard cards, stats, or decorative noise |
| Immersive | Quran text dominates; chrome is secondary |
| Quran-first | Text is the primary visual element |

**Not a dashboard.** Memorization %, khatma, streaks, and plan locks belong on student progress surfaces — not inside the reader chrome.

**Forbidden in shipped UI:** English labels, “Coming Soon”, fake actions, fake success, mock playback, unsupported backend features.

---

## 2. Design Principles

1. **Visual quality first** — functional-but-ugly is incomplete (§0).  
2. **Text over chrome** — if chrome and text compete, text wins.  
3. **Original, not cloned** — benchmark quality; never recreate Tarteel or other apps’ UI.  
4. **Honesty** — only real actions (read, select ayah, choose reciter, play/pause/stop).  
5. **D23 continuity** — first open Al-Fatihah; later open last-read.  
6. **D11 ≠ D23** — last-read never derived from `overallProgressPercent` or evaluations.  
7. **App shell stays light** — Mushaf Paper/Night are reader-local only.  
8. **Preserve real audio** — keep everyayah + `just_audio` (or equivalent existing stack); no fake player.  
9. **Preserve real text** — keep alquran.cloud Uthmani text + cache unless a later wave migrates with parity tests.  
10. **Bloc boundaries** — no giant StatefulWidget owning data + audio + persistence + UI.  
11. **Small primitives** — Mushaf-specific presentation widgets; reuse shared tokens where they help, do not force `AppCard` dashboards into pages.  
12. **Animate with purpose** — chrome show/hide only; no decorative motion.

---

## 3. Reader Layout

### 3.1 Structure (conceptual)

```
┌─────────────────────────────────────┐
│ [chrome: top — visible when revealed]│  surah · page · back · more
├─────────────────────────────────────┤
│                                     │
│         Quran page canvas           │  margins · text · headers
│         (always primary)            │
│                                     │
├─────────────────────────────────────┤
│ [chrome: bottom — when revealed /    │  mini audio · ayah actions
│  when audio active]                 │
└─────────────────────────────────────┘
```

### 3.2 Page geometry (targets — tune in U-MUSHAF-2 with device QA)

| Token | Small phone | Normal | Large / tablet |
|---|---|---|---|
| Horizontal margin | 16–20 dp | 20–24 dp | 32–48 dp (cap text width ~560–640) |
| Vertical padding | 12–16 dp | 16–20 dp | 20–24 dp |
| Text width | full − margins | full − margins | centered max width |
| Page number | subtle, below or in chrome | same | same |

### 3.3 Surah header

- Shown when the first ayah of a surah appears on the page.  
- Calm, traditional, not a marketing card.  
- Includes surah name; optional type (مكية/مدنية) at low emphasis.

### 3.4 Basmala

- Standalone centered line for surah starts except الفاتحة and التوبة (match current correct Islamic convention already in code).  
- Same typeface family as body; slightly emphasized weight OK.

### 3.5 Page number

- Arabic-Indic digits.  
- Low contrast vs text; never compete with ayah glyphs.

### 3.6 Selected ayah

- Soft highlight background + weight increase (not color-only).  
- Optional underline/marker for a11y.  
- “Now playing” may use a second calm treatment if different from selection.

---

## 4. Typography

### 4.1 Current (verified)

- `GoogleFonts.amiri`, default size **22**, line height **1.6**  
- Loaded via `google_fonts` (network/cache), not a bundled Quran-specific binary  
- Works on Android/iOS but diacritic density at 1.6 is a **comfort risk**

### 4.2 Recommendation (do not random-swap fonts)

| Decision | Spec |
|---|---|
| **v1 typeface** | Keep **Amiri / Amiri Quran** family for continuity and open licensing via Google Fonts |
| **Evaluate in U-MUSHAF-2** | Bundled **KFGQPC Uthmanic HAFS** (or equivalent) only after license check + glyph QA on longest ayahs |
| **Default size** | Start ~22–24; user range ~18–32; persist preference |
| **Line height** | Target **1.85–2.1** for body (validate on device; raise if tashkeel clips) |
| **Letter spacing** | 0 for Quran body |
| **Fallback stack** | Amiri Quran → Amiri → Noto Naskh Arabic |
| **UI chrome font** | Existing app Arabic UI font (`AppTextStyles` / Noto Naskh) — not Quran body |

### 4.3 Performance

- Avoid rebuilding full-page `RichText` recognizers on every audio tick.  
- Prefer page-scoped spans; invalidate selection/playing styles surgically.  
- Cache parsed Quran entities after first load (existing SP cache OK for v1).

### 4.4 Platform notes

- Android: verify Amiri shaping on API 26+.  
- iOS: verify no clipped marks under Safe Area.  
- Small screens: prefer slightly larger line height over denser pages.  
- Large screens: cap measure width so lines do not become unreadably long.

---

## 5. Paper Mode

**Purpose:** Default calm daytime reading surface.

| Element | Spec |
|---|---|
| Canvas | Warm paper (e.g. soft ivory — similar spirit to current `0xFFF5F0E1`, refined) |
| Text | Near-black / deep ink for strong readability |
| Highlight | Soft green/teal wash at low alpha (tokenized) |
| Chrome | Light translucent or solid matching paper family |
| Contrast | Prefer readable ink on paper over decorative gold borders |

Not a global Material dark theme inversion.

---

## 6. Night Mode

**Purpose:** Dedicated Mushaf low-glare reading. **Not** app-wide dark theme.

| Element | Spec |
|---|---|
| Canvas | Deep charcoal / near-black (OLED-friendly) |
| Text | Soft off-white (not pure #FFF glare) |
| Highlight | Muted primary wash |
| Chrome | Dark surface; white/light icons |
| Persistence | Store as `visualMode` with last-read (C15) or local prefs until C15 live |
| Shell | Student bottom nav / rest of app remains light when user exits reader |

Toggle lives in reader chrome/settings only.

---

## 7. Reader Chrome (Immersive)

### 7.1 Default (immersive)

- Quran page fills body.  
- Minimal or hidden top/bottom chrome.  
- Optional ultra-subtle page indicator only if needed for orientation.

### 7.2 Reveal

- Tap empty canvas / non-ayah gutter **or** single tap that does not conflict with ayah select policy (see §8).  
- Smooth short fade/slide (~200–280 ms).  
- Top: back, surah name, page, overflow (index, settings, mode).  
- Bottom: ayah actions + mini player when relevant.

### 7.3 Hide

- Tap again, or timeout after idle while not interacting with controls (optional; if used, ≥3–5 s and cancel on touch).  
- While audio UI needs attention (loading/error), keep bottom chrome visible.

### 7.4 Must not

- Permanent mode selector strip stealing vertical space (current قراءة/تسميع bar should not dominate).  
- “تسميع” homework recording inside immersive chrome while uploads disabled — keep homework recitation as separate route.

---

## 8. Ayah Interaction

### 8.1 Preserved real capabilities

- Tap ayah → select  
- Choose Sheikh/reciter (existing everyayah list)  
- Play selected ayah via real network audio  
- Pause (existing)  
- Stop (specify explicit stop = pause + seek zero / clear prepared — if stop not distinct today, define as pause + reset position)

### 8.2 Behaviors

| Event | Behavior |
|---|---|
| Tap ayah A (none selected) | Select A; reveal bottom actions; prepare audio for A |
| Tap ayah A again | Keep selection; toggle chrome **or** play/pause if audio UI focused — prefer: second tap on same ayah = play/pause when audio ready |
| Tap ayah B while A selected | Select B; stop/replace audio prep for B; update highlight |
| Audio playing, tap B | Stop/fade A; select B; user starts play intentionally (do not auto-play unless product later opts in — **default: no auto-play on select**) |
| Audio finishes | Stay on selected ayah; playing → idle; optional advance-to-next is **deferred** unless already implemented |
| Navigate to another page | Clear or keep selection only if ayah still on page; stop audio if selected ayah leaves viewport |
| Long-press | **Deferred** (no bookmarks in v1) |

### 8.3 Removed from primary UI until real

Favorites, bookmark, share “Coming Soon” rows.

---

## 9. Audio UX

### 9.1 Stack to preserve

- `just_audio` player  
- everyayah.com per-ayah URLs with existing reciter subdirectory map  
- Network gate via existing `NetworkInfo`

### 9.2 Compact mini-player

Visible when chrome revealed **or** while playing/loading/error:

- Reciter name (tappable → sheet)  
- Play / Pause / Stop  
- Current surah:ayah label (Arabic)  
- Compact progress (optional thin slider)  
- Loading spinner on play control  
- Error text Arabic + retry  

**Not:** full-screen audio dashboard, large reciter grids always open, mp3quran full-surah player embedded in page (library stays separate entry).

### 9.3 Completion

- Mark idle; keep selection.  
- Do not invent continuous surah autoplay in v1 unless already proven stable (current skip next/prev may remain as explicit user actions).

### 9.4 RTL controls

- Prev/next must match reading direction (fix current inverted icon mapping). Done in U-MUSHAF-4 (Appendix F.2).

### 9.5 Out of scope for audio UX v1

- Upload recording from Mushaf  
- Merging mp3quran library into ayah player  
- Offline audio cache (unless trivial later)

---

## 10. Listening Mode Decision

### Decision: **KEEP (optional) — ship in U-MUSHAF-5, not foundation**

### Rationale (architecture complexity)

| Criterion | Assessment |
|---|---|
| Simple? | Yes — presentation flag `listeningFocus == true` |
| Stable? | Yes if audio Bloc owns playback and reader Bloc owns focus flag |
| Compatible? | Yes — no backend; hide/de-emphasize `PageView` text layer |
| Breaks audio? | No if mini-player remains mounted |
| Breaks navigation? | No if page controller still exists under focus overlay |
| State risk? | Low if single source of truth for selected ayah/page |
| Performance? | Low — avoiding rebuild of recognizers while hidden |

### UX definition (when implemented)

| Aspect | Spec |
|---|---|
| Start | User enables “وضع الاستماع” from audio chrome while playing or before play |
| Visible | Mini-player, surah:ayah label, exit control; optional dim paper/night canvas |
| Hidden | Quran glyph page (or heavily de-emphasized) |
| Exit | Explicit “إظهار المصحف” / tap exit; also exit on stop if desired |
| Audio finish | Return to reader focus **or** stay in listening until exit — **prefer return to reader with ayah still selected** |
| Last-read | Continues to track current ayah/page while listening (position still advances if user skips) |
| Not | Tarteel clone; AI coaching; auto-hide without user consent |

### If blocked in implementation

Mark **DEFERRED** only if audio Bloc extraction slips; do not block U-MUSHAF-1…4 on Listening Mode.

---

## 11. Navigation

### 11.1 Goals

Compact, immersive-safe access to:

- Surah jump (required v1)  
- Page jump (required v1 — go to page number)  
- Juz jump (phase: U-MUSHAF-3 optional if cheap; else U-MUSHAF-5)  
- Current location always knowable when chrome visible  
- Return to last-read (chip when user navigated away in-session)

### 11.2 Pattern

- **No** permanent huge drawer.  
- **Sheet:** “فهرس” with search field + list ( سور ). Tabs or segments: سور | أجزاء (if juz enabled) | صفحة.  
- Entry from chrome overflow or book icon.  
- Swipe pages remains primary continuous navigation.

### 11.3 Entry points (product)

| Entry | Behavior |
|---|---|
| Student «مصحفي» | Prefer **open reader directly** (or thin launcher with one primary CTA “فتح المصحف”) — not a progress dashboard |
| Profile “السورة الحالية” | Open **last-read** (or Al-Fatihah if none) — not surah 67 |
| Router `/student/mushaf` | Honor D23; remove default 67 |
| `?free=true` | Deprecate or alias to same reader (no special last-read bypass) |
| Audio library `/student/audio` | Remains separate listening catalog |

### 11.4 Homework «تسميع»

Keep `StudentRecitationPage` as separate flow from homework/mushaf practice — outside immersive reader v1.

---

## 12. Last Read Contract

### 12.1 Reject as final production

`SharedPreferences last_mushaf_page` (device-global page int) is **interim only**.

### 12.2 Recommended production model (aligns with locked C15)

**Collection:** `mushafReading/{studentId}` (owner R/W only)

| Field | Required | Notes |
|---|---|---|
| `surahNumber` | ✔ | 1 = Al-Fatihah when missing / first open |
| `ayahNumber` | ✔ | Within surah |
| `pageNumber` | ✔ recommended | Mushaf page 1–604 for fast restore |
| `updatedAt` | ✔ | Server timestamp preferred; last-write-wins multi-device |
| `visualMode` | optional | `paper` \| `night` |

**Separation:** Never write D11 progress fields from this path.

### 12.3 Client behavior

| Concern | Spec |
|---|---|
| Ownership | Authenticated student uid only |
| First open | No doc / empty → surah 1, ayah 1, page 1 |
| Write frequency | Debounce ~400–800 ms on page/ayah change; flush on dispose / app pause |
| Offline | Local cache mirror (SP or Hive) of last known position; sync when online |
| Conflict | Last-write-wins on `updatedAt` (C15) |
| Rules | Must be added in implementation wave (currently **not** in `firestore.rules`) |
| Migration | On first C15 write, seed from SP `last_mushaf_page` if present |

### 12.4 This U-MUSHAF-0 task

Specifies contract only — **does not implement** server sync here. Implementation belongs in **U-MUSHAF-3**.

---

## 13. Loading / Error States

| State | UX |
|---|---|
| Initial Quran load | Calm reading-oriented placeholder (soft paper shimmer / centered Arabic “جاري تحميل المصحف”) — not a marketing spinner splash |
| Page swipe | No full-screen flash; keep adjacent pages warm if possible |
| Audio loading | Spinner on play control only |
| Quran error | Arabic message + «إعادة المحاولة» |
| Audio error | Arabic inline error; keep ayah selected |
| Empty | Should not happen if parse OK; if empty, truthful Arabic empty + retry |
| Offline text | Prefer SP cache; if none, error with retry |

No fake success.

---

## 14. Accessibility

- User font size control with min/max.  
- Contrast sufficient in Paper and Night.  
- Touch targets ≥ 44×44 for chrome controls.  
- Selected ayah not color-only (weight / marker).  
- Semantics: announce surah and page on change when chrome visible (progressive).  
- RTL: `Directionality`, directional icons, start/end padding.  
- Screen reader: ayah as selectable text units where feasible without breaking calligraphy layout (best-effort; don’t destroy visual mushaf for TalkBack).

---

## 15. Responsive Behavior

| Class | Behavior |
|---|---|
| Small phones | Larger effective line height; tighter chrome; full-width text |
| Normal phones | Default tokens §3 |
| Large phones | Slightly larger margins |
| Tablets (if supported) | Max content width; centered column; do not stretch ayahs edge-to-edge |

Avoid hardcoded one-device dimensions. Use MediaQuery / LayoutBuilder breakpoints.

Landscape: **best-effort** reflow; portrait is primary. Full landscape mushaf layout is **deferred** unless product mandates.

---

## 16. Architecture Boundaries

### 16.1 Mandate

Clean Architecture + **Bloc** (not Cubit). Replace monolith gradually across waves.

### 16.2 Suggested modules (lean)

```
features/mushaf/   (or features/student/mushaf/)
  domain/
    entities/          # Ayah, SurahMeta, MushafPosition, VisualMode
    repositories/      # QuranTextRepository, MushafReadingRepository
    usecases/          # LoadQuranText, Get/SaveMushafPosition
  data/
    datasources/       # AlQuranCloud + SP cache; Firestore mushafReading
    repositories/
  presentation/
    bloc/              # MushafBloc (reader) + MushafAudioBloc (or nested)
    pages/             # MushafReaderPage
    widgets/           # Page canvas, chrome, mini player, index sheet
```

### 16.3 Responsibility split

| Concern | Owner |
|---|---|
| Quran JSON fetch/cache/parse | Data + LoadQuranText use case |
| Current page / surah / ayah / selection | MushafBloc |
| Last-read load/save | MushafReadingRepository via use cases |
| Navigation jumps | MushafBloc events |
| Audio URL, play/pause/stop, loading/error | MushafAudioBloc (talks to just_audio) |
| Visual mode paper/night | MushafBloc (+ persist) |
| Listening focus | MushafBloc flag driven by UI; audio remains in AudioBloc |
| Presentation | Widgets only |

### 16.4 Reuse vs replace (from audit)

| Item | Action |
|---|---|
| alquran.cloud + SP `cached_entire_quran` | **Reuse** v1 |
| everyayah + reciter map + just_audio | **Reuse** |
| Page grouping 1–604 logic | **Extract** from monolith → domain/data |
| Surah catalog | **Extract** |
| `last_mushaf_page` | **Replace** with C15 (+ local mirror) |
| Router default 67 / free mode split | **Remove/replace** with D23 |
| Dashboard memorization header | **Remove** from mushaf entry |
| Coming Soon menu items | **Remove** |
| Inline recording / upload Coming Soon | **Defer** / keep off reader |
| StudentRecitationPage | **Preserve** as separate homework/practice |
| Audio library (mp3quran) | **Preserve** separate |
| Shared AppBackButton, tokens | **Reuse** for chrome |
| AppCard / stats grids | **Do not** force into page canvas |

### 16.5 Anti-patterns

- One universal DashboardWidget for Mushaf  
- Business logic in widgets  
- Cubit  
- Fake repositories  
- Coupling last-read to StudentBloc profile progress

---

## 17. Testing Strategy

### Reader

- First open (no position) → Al-Fatihah (1:1 / page 1)  
- Returning user → restored surah/ayah/page  
- Last-read independent of `overallProgressPercent`  
- Page swipe / surah jump / page jump  
- Selected ayah highlight  

### Audio

- Reciter selection  
- Play / pause / stop  
- Loading / completion / error  
- RTL prev/next semantics  

### Listening Mode (when built)

- Enter / exit  
- Audio still works  
- Position consistent  
- Reader state intact after exit  

### Modes

- Paper / Night switch preserves position  
- Mode persistence  

### RTL

- Text direction, chrome, icons, selection  

### States

- Initial load, error+retry, offline cache path  

Prefer unit + widget + focused bloc tests; goldens optional only if project already stable for them.

---

## 18. Implementation Waves

| Wave | Goal | Deliverables |
|---|---|---|
| **U-MUSHAF-1** | Architecture + Reader Foundation | Feature folder, Bloc shells, extract load/parse, thin reader page host, kill surah-67 default path; **visual baseline must not look like a raw PageView dump** |
| **U-MUSHAF-2** | Reading Surface + Typography | Paper canvas, margins, Amiri sizing/line-height, surah header/basmala polish; **§0 visual review required** |
| **U-MUSHAF-3** | Navigation + Last Read | Index sheet, D23 open rules, C15 + Rules + local mirror; **index UI must stay calm / non-dashboard** |
| **U-MUSHAF-4** | Ayah Interaction + Audio | Selection rules, elegant mini-player, reciter sheet, RTL control fix; **§0 review on audio chrome** |
| **U-MUSHAF-5** | Paper/Night + Immersive + Listening | Mode polish, tap-to-reveal chrome, optional Listening Mode; **premium immersion check** |
| **U-MUSHAF-6** | Tests + Production Closure | Full §17 suite + **explicit visual QA sign-off (§0)**; no Coming Soon; anti-clone check |

**Do not implement these waves in U-MUSHAF-0.**

**Wave exit rule:** If functional tests pass but §0 visual bar fails → **refine UI before marking the wave finished.**

---

## 19. Deferred / Out of Scope

- Project Figma-driven Mushaf visuals  
- **Cloning or approximating Tarteel (or any other Quran app) UI / branding / layout**  
- Global app dark theme  
- Bookmarks / favorites / share  
- Translation / transliteration layers  
- AI recitation coaching  
- Auto-play continuous full surah (unless later approved)  
- Offline audio caching  
- Enabling mushaf audio uploads  
- Juz index if it risks U-MUSHAF-3 scope (move to 5)  
- Landscape-optimized mushaf  
- Adventure/map, Admin V1, password recovery  
- Changing D11 progress formulas  
- English / LTR  

---

## 20. Acceptance Criteria (for future implementation closure)

### Functional

1. First-ever open lands on **Al-Fatihah**.  
2. Later opens restore **last-read** (C15 + offline mirror).  
3. Last-read **never** uses memorization progress.  
4. User can read pages, select ayah, choose reciter, play real audio.  
5. Paper and Night modes work; app shell stays light.  
6. Immersive chrome tap-to-reveal works without covering text unnecessarily.  
7. No Coming Soon / fake actions in primary menus.  
8. Arabic + RTL only in Mushaf UI.  
9. Architecture uses Bloc + clean boundaries (no remaining god-widget as SSOT).  
10. Tests in §17 pass for shipped scope.  
11. Listening Mode either shipped per §10 or explicitly deferred in release notes.  
12. Independent of project Figma dashboards.

### Visual (first-class — mandatory)

13. **§0 visual quality bar passes** on real device/emulator review.  
14. Does **not** look like a generic Flutter PageView + text dump.  
15. Does **not** look like a clone or near-clone of Tarteel or other Quran apps.  
16. Typography, margins, ayah rhythm, chrome, audio controls, and Paper/Night feel **premium and calm** for prolonged reading.  
17. If functional criteria pass but visual criteria fail → wave is **not finished**.

---

## Appendix A — Locked decisions applied

| ID | Application in this spec |
|---|---|
| D23 first open | Al-Fatihah |
| D23 last-read | C15 position model |
| D23 ≠ D11 | Explicit separation + UI IA |
| D23 two modes | Paper + Night (reader-local) |
| C15 | Production last-read contract |
| App light theme | Night does not globalize |

---

## Appendix B — Remaining product-owner decisions

Locked for V1 (see PRODUCT_DECISIONS_LOCKED / U-MUSHAF-1):

1. **Mushaf tab IA:** Opens reader directly (no launcher).  
2. **Auto-advance after playback:** OFF.  
3. **Font:** Amiri V1; Uthmani evaluation deferred.  
4. **Juz index:** Wave 3+, not U-MUSHAF-1.  
5. **Listening Mode:** Explicit opt-in later; does not auto-activate on play.

---

## Appendix C — U-MUSHAF-1 implementation note

**Status:** Architecture + reader foundation shipped (this wave).

| Concern | Implementation |
|---|---|
| Feature folder | `lib/features/mushaf/` — domain / data / presentation |
| MushafBloc | Owns init, Quran text load, page nav, selected ayah, last-read resolve/persist, chrome/night flags. **Not** audio. |
| MushafAudioBloc | Owns play / pause / stop / reciter / errors (everyayah + just_audio). Auto-advance OFF. Listening Mode not activated. |
| Last-read (C15) | `mushafReading/{studentId}` via `MushafReadingRepository`. Device mirror is per-student (see Appendix E); the unscoped `last_mushaf_page` is no longer read. |
| First open | No valid C15 (or invalid) → Al-Fatihah (`MushafPosition.alFatihah`). |
| Resume | Valid persisted position → that page. |
| Entry | Student tab + `/student/mushaf` → `MushafBlocScope` + `MushafReaderHost` (reader directly). Surah-67 default removed. |
| Progress isolation | Reading position never writes `overallProgressPercent` / memorization / revision / evaluation. |
| Deferred | Index/Juz (3), audio chrome polish (4), Listening Mode (5). Dashboard file may remain unused. |

**Legacy SP (superseded by U-MUSHAF-3):** U-MUSHAF-1 read the device-global `last_mushaf_page` when the C15 doc was missing. That key is not student-scoped, so on a shared device student B could resume student A's page. U-MUSHAF-3 removed that read path — see Appendix E.

---

## Appendix D — U-MUSHAF-2 implementation / visual QA

**Status:** Premium reader surface shipped.

| Concern | Implementation |
|---|---|
| Tokens | `MushafReaderTokens` — Paper ivory + Night charcoal; quiet teal accent; not app ThemeMode |
| Typography | Amiri body ~23 default, line height ~2.05; chrome uses Noto Naskh; letter-spacing 0 |
| Layout | Immersive `Stack`: full-bleed Quran canvas; thin sliding top chrome; restrained bottom audio |
| Chrome | Tap canvas toggles chrome; surah · page · night · index · overflow (settings / تسميع) |
| Paper / Night | Reader-local; local prefs key `mushaf_reader_night_mode` |
| Surah header | Calm dividers + Amiri title — no bordered card |
| Loading / Error | Arabic paper-like lines; Arabic error + retry |
| Auto-advance | Remains OFF after ayah playback completes |

**Visual QA:** Quran is hero; chrome subordinate; Paper calm; Night low-glare; no dashboard cards/stats/Coming Soon; RTL natural; original Rafiq tokens (not a clone of other Quran apps).

---

## Appendix E — U-MUSHAF-3 navigation + last-read

**Status:** Surah / juz / page navigation and student-scoped last-read shipped.

### E.1 Data sources

| Concern | Source |
|---|---|
| Surah identity (114 Arabic names, مكية/مدنية, ayah counts) | `QuranSurahCatalog` (static; ayah total 6236, 86 Meccan) |
| Surah start page | First ayah `page` of each surah in the alquran.cloud `quran-uthmani` payload |
| Juz start page | First ayah whose `juz` field equals N in the same payload |
| Juz labels | `QuranJuzLabels` (الجزء الأول … الجزء الثلاثون) |

No page tables are hand-written. `MushafNavigationIndex.fromBundle` drops start pages that are out of 1–604, or (for juz) not strictly increasing, instead of guessing. A payload without `juz` shows «بيانات الأجزاء غير متاحة حالياً». Validated against the live payload: 604 contiguous pages, 114 surahs with matching ayah counts, 30 juz start pages equal the Madani set (1, 22, 42 … 582).

### E.2 Navigation surface

- Entry: chrome list icon (tooltip «التنقّل») or a tap on the chrome surah title.
- A custom bottom sheet using reader tokens (Paper/Night). Width capped at 640, top radius 22, handle; not a Material list dialog.
- Order: header (current page · juz) → «آخر موضع قراءة» row → «الانتقال إلى صفحة» field → quiet السور / الأجزاء tabs → surah search → lazy fixed-extent list.
- Surah search: normalized with the shared `ArabicSearchNormalizer`; also accepts «سورة …» and surah numbers in Latin or Arabic-Indic digits. Empty state: «لا توجد سورة بهذا الاسم».
- Page field: accepts Latin / Arabic-Indic / Persian digits. Invalid input shows «أدخل رقم صفحة من ١ إلى ٦٠٤» and never crashes. Swipe paging is unchanged (PageView 1–604).
- Distant targets use `jumpToPage` (no long animated scroll).

### E.3 Last-read (C15) behavior

| Case | Result |
|---|---|
| No C15 doc | Al-Fatihah (no write until the reader moves) |
| Valid doc | Resume there (not rewritten on open) |
| Malformed / out-of-range doc | Al-Fatihah |
| Firestore read throws (offline) | Per-student device mirror `mushaf_last_read_v1_<studentId>` if present, else error → Al-Fatihah |
| Legacy `last_mushaf_page` | Never read; removed on the next write |
| Student switch in the singleton bloc | Pending debounced write is flushed with the **old** student id; position resets; stale in-flight opens are discarded |
| Writes | 500 ms debounce; duplicate positions skipped; the persist event carries its own `studentId` |

«آخر موضع قراءة» in the sheet is the C15 position resolved at open. After any explicit jump (surah, juz, page field, or resume), it becomes the page the reader just left, so one tap returns there. Swipes do not change it. It is never derived from memorization progress.

### E.4 Visual QA (captured with real payload data)

First open (Paper, Al-Fatihah); resumed (Night, page 42); sheet Paper and Night; juz tab with the current juz highlighted; page-field error plus empty search; search result; 320 px narrow; 1024 px wide (capped sheet); loading/error states. Verified: RTL chevrons, single-line header at 320 px, Quran remains the backdrop, no dashboard cards / Coming Soon.

### E.5 Deferred

Hizb / rub' / manzil; auto-scroll the list to the current surah (top controls are kept in view instead); bookmarks; Listening Mode. (Audio migration to `MushafAudioBloc` shipped in U-MUSHAF-4; see Appendix F.)

---

## Appendix F — U-MUSHAF-4 audio UX

**Status:** Reader playback runs on `MushafAudioBloc`. The page no longer owns a playback `AudioPlayer`.

### F.1 Architecture

| Layer | Responsibility |
|---|---|
| `MushafReciters` (domain) | Verified reciters and everyayah URLs; rejects ayahs outside the surah's ayah count |
| `MushafAudioEngine` (domain interface) | One-track player: load / play / pause / stop / seek, state + error + position streams |
| `JustAudioMushafEngine` (data, `@LazySingleton`) | `just_audio` implementation; the `AudioPlayer` is created on first use; `play()` is not awaited (its future only completes when playback stops) |
| `MushafAudioBloc` (`@lazySingleton`) | Status (idle / loading / playing / paused / error), target ayah, reciter, repeat-ayah |
| `MushafBloc` | Unchanged owner of content, page, selection and last-read. Audio never writes C15 or memorization |

Concurrency: every command that supersedes a load bumps a request token; late network checks and loads compare the token and are discarded. Handlers emit their new state before awaiting `engine.stop()`, so a slow stop can never overwrite a newer command. Both blocs are app singletons provided with `.value`; the reader sends `Stop(clearTarget: true)` on dispose so audio never outlives the page.

### F.2 Interaction

- Tapping an ayah selects it and sets the audio target. No network request is made on selection; audio for a different ayah stops.
- Nothing is selected on first open; play with no selection starts the first ayah of the visible page.
- Bar controls (RTL order): ayah + status, options, previous, play/pause, next, close. Previous uses `skip_next_rounded` and next uses `skip_previous_rounded`, because media icons are not mirrored by Flutter; previous therefore points to the reading start (right).
- Previous / next select the neighbouring ayah and play it; crossing a page boundary moves the reader page via `MushafSelectAyahEvent`.
- Primary control: play → pause; while loading, a spinner inside the button and a tap cancels the load; after an error, retry.
- Completion: idle, selection kept. Repeat-ayah (options sheet) replays the same ayah. Auto-advance stays OFF.
- Close: stop, clear the target and the selection. Last-read is untouched.
- Visibility: shown while an ayah is selected and chrome is visible, and kept visible while loading or playing even if chrome is hidden.
- Seek slider and mute were removed from the bar. A 2 px progress line fills in reading direction.
- Below 420 px the ayah/status line sits above the controls so error text is never truncated. While an ayah is selected, the page reserves bottom scroll room so its last lines can be lifted above the bar.
- The bar is a scoped `BlocBuilder`; a test asserts the page surface is not rebuilt by play / progress / pause.

### F.3 Reciters

Each everyayah folder was checked (1:1 and 114:6 must return audio):

| Reciter (Arabic label) | Folder | Result |
|---|---|---|
| محمد صديق المنشاوي (default) | `Minshawy_Murattal_128kbps` | Kept |
| محمود خليل الحصري | `Husary_128kbps` | Kept |
| مشاري العفاسي | `Alafasy_128kbps` | Kept |
| عبد الباسط | `Abdul_Basit_Murattal_128kbps` | Removed (404) |
| العجمي | `Ahmad_Al_Ajmi_64kbps` | Removed (404) |
| المعيقلي | `Maher_AlMuaiqly_128kbps` | Removed (404) |

Working folders exist for the three removed reciters (for example `Abdul_Basit_Murattal_192kbps`, `Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net`, `MaherAlMuaiqly128kbps`), but they were not added; restoring them needs product-owner approval. Switching reciter while playing stops playback and does not auto-reload; switching while idle makes no request.

### F.4 States and messages

| State | Status line | Primary control |
|---|---|---|
| Idle | Reciter name (+ «تكرار الآية» when on) | تشغيل التلاوة |
| Loading / buffering | «جارٍ تحميل التلاوة…» | Spinner, tap cancels (إلغاء التحميل) |
| Playing | Reciter name | إيقاف مؤقت |
| Paused | «متوقفة مؤقتاً · …» | متابعة التلاوة |
| Offline | «التلاوة تحتاج اتصالاً بالإنترنت» | إعادة المحاولة |
| Load failed | «تعذر تحميل التلاوة» | إعادة المحاولة |
| Interrupted mid-play | «انقطعت التلاوة» | إعادة المحاولة |

Reader tokens gained `error` (quiet, not alarm red) and `onAccent`. The Paper accent was darkened slightly (`#1F8F83`) so the white play icon keeps ≥3:1 contrast. Tests assert the contrast ratios for Paper and Night.

### F.5 Visual QA (real payload)

First open (no selection, no bar); selected idle; loading; playing with progress; paused; offline error with retry; playing with chrome hidden; closed; Night resume at page 50; Night playing; last lines scrolled above the bar; options sheet (Night, 1024 px); reciter switch while playing; navigation sheet over the bar; 320 px error; 1024 px playing. Also fixed: the chrome back button now uses `arrow_back_ios_new_rounded`, which auto-mirrors to → in RTL.

### F.6 Deferred

Persisting the reciter choice; seek and playback speed; background / lock-screen audio controls; offline caching; restoring the three removed reciters with verified folders; migrating the recitation-mode recorder (kept as-is, now created lazily); Listening Mode (U-MUSHAF-5).

---

**End of Mushaf UX specification.**
