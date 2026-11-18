# BASMA — Final Engineering Quality & Maintainability Audit

**Date:** 2026-11-18  
**Tree:** `unify/basma-v1` @ `bb0a905` + dirty worktree (staged D2 + large unstaged set)  
**Nature:** Discovery / evidence map — **not** a claim that BASMA is engineering-complete.  
**Related:** RB-18/DevTools status → `BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md` · Remediation order → `BASMA_ENGINEERING_QUALITY_REMEDIATION_PLAN.md`

**Evidence classes:** Confirmed · Suspected · Style/optional · Deferred (device/Cloud/owner)

### Checkpoint note (added 2026-11-18; audit body unchanged)

Later commits: D2 `daa8f85`, EQ DI `0889682`. This audit’s tree/HEAD lines above remain the **discovery-time** snapshot. RB-01 historical `+2486 ~3` still applies; suite **not** re-claimed green on `0889682`. RB-02…RB-19 (except documented CLOSED items) remain release blockers per `docs/production/BASMA_RELEASE_BLOCKERS.md`.

---

## 0. Executive map

| Area | Snapshot |
|------|----------|
| Features | **29** under `lib/features/` |
| Tests | **287** Dart files under `test/` |
| Architecture intent | Feature-first Clean Architecture (ADR-001) |
| Suite health | RB-01 **CLOSED** locally (`+2486 ~3`) — does **not** imply Cloud/device readiness |
| Release blockers | Most of RB-02…RB-19 still **OPEN** (see `BASMA_RELEASE_BLOCKERS.md`) |
| Quran/Mushaf | **Out of scope** for fixes here; independent review required |
| Device/DevTools this pass | Device briefly visible; **no** DevTools session (deferred) |

**Bottom line:** The codebase has a coherent intended architecture and a large test corpus, but **Confirmed** layer leaks, oversized presentation files, Cloud/security gates, and device-lab gaps mean BASMA is **not** ready to be called engineering-complete.

---

## 1. What was / was not exercised this pass

| Mode | Coverage |
|------|----------|
| Physical device | SM-A037F seen wirelessly; app installed; **not** smoked; **no** DevTools |
| Local widget/structure tests | D4 nav overflow + lazy lists **passed** |
| Full Flutter Suite | **Not re-run** (RB-01 closed) |
| Cloud deploy / Rules / Functions | **Not** executed |
| Quran/Mushaf deep review | Deferred (protected path) |

---

## 2. Architecture

### 2.1 Intended shape (Confirmed)

Presentation → Bloc/Cubit → Use case → Repository (domain) → Repository impl → Datasource → Firebase/Functions — documented in `BASMA_ARCHITECTURE_AUDIT.md` and still matching most mature features (auth, chat core, teacher/parent use-case chains).

### 2.2 Domain purity (Confirmed positive)

No `cloud_firestore` / `firebase_auth` imports under `lib/**/domain/**` in this pass’s search.

### 2.3 Clean Architecture leaks (Confirmed samples)

Presentation (or near-UI) touching Firebase / constructing repos directly — still present:

| # | Path | Issue |
|---|------|--------|
| 1 | `admin/.../admin_halaqa_details_page.dart` | Firestore from page |
| 2 | `admin/.../admin_broadcast_page.dart` | Firestore `count` from page |
| 3 | `admin/.../admin_settings_tab.dart` | `FirebaseAuth` password path in UI |
| 4 | `accounts/.../admin_account_access_card.dart` | Firestore + Functions from widget |
| 5 | `directory/.../admin_directory_page.dart` | Directory repo built in widget / no full bloc path |
| 6 | `auth/.../first_login_page.dart` | Callable/account path bypasses AuthBloc |
| 7 | `chat/.../chat_room.dart`, `chat_groups_provider.dart` | Storage/Functions wiring in presentation |
| 8 | `audio_library/.../audio_bloc.dart` | Bloc depends on FirebaseAuth + data services |
| 9 | `complaints/.../complaints_entry.dart` | Manual wiring; not generated DI |
| 10 | `assistant/.../assistant_home_page.dart`, `teacher_cover_banner.dart` | Firebase in presentation |
| 11 | Multiple admin tabs (teachers/students/reports/payments ledger) | Direct Firebase usage |

**DI gaps (Confirmed from prior audit, still structurally true):** features such as `accounts`, `assistant`, `complaints`, `directory`, `onboarding`, `staff` lean on manual `sl<>` / Firebase in UI rather than full generated GetIt graphs.

### 2.4 State management consistency

Bloc/Cubit is the dominant pattern where features are mature. Inconsistent entrypoints (pages that skip blocs) are Confirmed above — not merely style.

---

## 3. SOLID & maintainability

### 3.1 God presentation files (Confirmed — line counts this pass)

| Lines | File |
|------:|------|
| 1512 | `parent_child_profile_page.dart` |
| 1346 | `teacher_evalutation_page.dart` (note filename typo) |
| 1337 | `supervisor_dashboard_tab.dart` |
| 1296 | `student_mushaf_page.dart` (**review separately**) |
| 1249 | `supervisor_students_tab.dart` / `teacher_class_detail_page.dart` |
| 1144+ | Several parent/teacher/admin chrome files |

**Impact:** SRP pressure, hard reviews, high regression risk. Split is High effort; prioritize by change frequency.

### 3.2 SOLID notes

| Principle | Assessment |
|-----------|------------|
| SRP | Violated in mega-pages (Confirmed) |
| OCP | Mixed — policy objects exist (meeting link, attendance); many UI branches still open-coded |
| LSP / ISP | Generally OK at repository interfaces; some fat datasources Suspected |
| DIP | Intended via DI; bypassed wherever UI talks to Firebase (Confirmed) |

---

## 4. Code quality signals

| Signal | Finding | Class |
|--------|---------|--------|
| Package name `rafiq_academy` | Dart package id — OK; not user-facing | Style |
| User-facing “Rafiq Academy” | Student settings subtitle | Confirmed → **fixed** this pass |
| `rafiq_launch_background` alias | Kept for stale Android refs | Low / intentional |
| TODO/FIXME in `lib/` | Sparse (`student_home`, mushaf dashboard) | Low |
| Eager `ListView(` in presentation | Still many (forms/small lists OK; some hot lists remain) | Mixed Confirmed/optional |
| Filename typo | `teacher_evalutation_page.dart` | Low (rename cost) |
| Duplicate payment/meeting logic | Shared modules exist; still cross-feature sprawl | Suspected / prior audits |

---

## 5. Logic & error handling

| Topic | Assessment |
|-------|------------|
| `Either` / `Failure` / `ServerException` | Established in mature features |
| Soft Firestore fallbacks | Parent soft-fallbacks were RB-01 regressions — callable-only restored (Confirmed historical) |
| Prod flavor routing | Fail-closed until Firebase configured (Confirmed) |
| Empty/`catch (_)` | Not exhaustively inventoried this pass — **Suspected** pockets in older UI |
| Race / concurrent loads | Chat/payment paging improved in D2; remaining races Suspected in mega-pages |

---

## 6. Tests

| Fact | Value |
|------|-------|
| Test Dart files | **287** |
| RB-01 full suite | Green with **3** environmental skips |
| Strengths | Flavor/signing/Firebase routing contracts; chat pagination; D2 paging; D4 structure |
| Gaps (Confirmed/Suspected) | Many Firebase-in-UI admin paths lack widget isolation tests; device E2E absent; Cloud rules denial on **live** project still open (BASMA-100) |
| Anti-pattern | Do not add no-op tests to inflate counts |

---

## 7. Performance & backend

| Item | Status |
|------|--------|
| D2 chat cursor / conversation limits | Implemented / tested (client) |
| D2 recitation `newestByDate` + index | Local index verified (RB-02); **Cloud pending** |
| D4 lazy lists + RepaintBoundary | Partial (directory/payments/registration/nav) |
| Remaining eager lists | Many `ListView(` still — triage needed before more conversions |
| N+1 / unbounded queries | Prior audits; Cloud cost still gated by G1–G4 |
| Stream disposal | Not fully re-audited this pass — Suspected in long-lived blocs |
| Backend authority | Production gate closed by default (RB-07) — correct until owner unlock |

---

## 8. Documentation & handoff

| Doc | Drift? |
|-----|--------|
| `RELEASE_PLATFORM_SETUP.md` | Partially refreshed in RB-17; icon § still partly stale vs adaptive assets |
| `BASMA_REMEDIATION_PLAN.md` | Still valid as batch order; Stage D progressed beyond “plan only” header |
| Architecture audit 2026-11-16 | Leak list still largely accurate |
| Blockers register | Current source of truth for release gates |

**Handoff risk (Confirmed):** Dirty worktree (staged D2 + large unstaged) is hard for a new engineer without a written inventory of what is intentional vs WIP (mushaf styles, payment indexes mix, trial flavor, etc.).

---

## 9. Prioritized finding register (this audit)

### Critical

| ID | Finding | Evidence |
|----|---------|----------|
| Q-C1 | Live security rules gap (Trial over-read) | BASMA-100; emulator pass ≠ cloud |
| Q-C2 | Prod Cloud not configured / gate closed | RB-05…RB-09 |

### High

| ID | Finding | Evidence |
|----|---------|----------|
| Q-H1 | Presentation→Firebase layer leaks (admin/chat/accounts/…) | File list §2.3 |
| Q-H2 | Mega-pages (>1k LOC) maintainability | Line counts §3.1 |
| Q-H3 | RB-02 Cloud index not verified | RB-02 report |
| Q-H4 | Device lab / RB-18 not done | RB18 status doc |
| Q-H5 | Mushaf WT changes need separate review | Prior provenance report; not fixed here |

### Medium

| ID | Finding | Evidence |
|----|---------|----------|
| Q-M1 | Remaining eager lists after D4 | `ListView(` grep |
| Q-M2 | DI-incomplete features | Architecture audit §1.5 |
| Q-M3 | Doc drift (remediation header, icon section) | §8 |
| Q-M4 | Mixed payment indexes with RB-02 file | RB-02 isolation note |

### Low / optional

| ID | Finding |
|----|---------|
| Q-L1 | `teacher_evalutation_page.dart` typo |
| Q-L2 | Sparse TODOs |
| Q-L3 | iOS 68-byte LaunchImage placeholders |

---

## 10. Areas not deeply re-reviewed this pass

- Full Cloud Functions surface & emulator E2E matrix  
- Every feature’s nullability / race audit  
- Design system / L10n / Dark Mode (product-locked D5)  
- Quran/Mushaf behavior & WT style hunks (separate track)  
- Profile-mode performance numbers  

---

## 11. Inventory cross-check (read-only pass)

Additional Confirmed signals folded from a parallel inventory (same tree):

| Signal | Detail |
|--------|--------|
| Architecture boundary tests | Present: `test/architecture/dependency_boundaries_test.dart` |
| `Either` vs throw | ~20 repos use `Either`; homework/schedule/review_schedule/progress_report/app_update often bare `Future` |
| `catch (_)` density | ~110 in `lib/`; ~19 empty `catch (_) {}` (e.g. activities AuthBloc read, auth datasource, push presenter) |
| Thin test features | `onboarding` / `review_schedule` **0** feature tests; assistant/audio/calendar thin |
| Eager `ListView(` | ~70 vs ~14 `.builder` — D4 hot paths partially converted |
| Trial login copy | Still shows infra id `rafiq-academy` on login (operator/trial banner) — left as-is (not brand rename; documents live project) |
| Mild domain→Flutter | `awards` / `app_update` domain import `foundation.dart` only |

## 12. Safe fixes applied during this pass

| Fix | Test |
|-----|------|
| Student settings subtitle: remove user-facing “Rafiq Academy”; use `AcademyBranding.displayName` | `dart analyze` clean |
| `BASMA_D4_CLOSEOUT.md` RB-01 status sync | Doc-only (was wrongly listing RB-01 as OPEN) |

No architecture rewrites, no ID/Firebase/signing changes, no Quran/Mushaf edits.

---

## 13. Verdict

**BASMA is not engineering-complete.**  
Local suite green + substantial architecture are real strengths; Critical Cloud/security gates, High layer leaks, device lab, and release blockers remain. Proceed via the ordered remediation plan — do not conflate test green with production readiness.
