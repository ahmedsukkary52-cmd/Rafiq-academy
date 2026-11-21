# BASMA D3 — Code Quality & Architecture Audit

**Phase:** D3 (bounded remediation)  
**Date:** 2026-11-20  
**Branch:** `unify/basma-v1`  
**HEAD (unchanged):** `8ce64fe97440c33acefaf1e140022ddbe0075ab5`  
**Verdict:** **PASS WITH GAPS**

---

## 1. Initial repository state

| Check | Result |
|-------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe` (verified before and after edits) |
| Working tree | Dirty (~300+ paths at start; pre-existing owner/agent work preserved) |
| Git operations | No reset / clean / stash / checkout / rebase / merge / commit / push |
| Prior reports reused | `BASMA_ARCHITECTURE_AUDIT.md`, `BASMA_CODE_QUALITY_AUDIT.md`, `BASMA_D2_FIREBASE_EFFICIENCY.md`, chat audit |
| Evidence scans | [Bounded D3 scan](843626ba-f90a-4588-b131-4babcb67912c), [D3 evidence scan](d5ea661b-2a1c-4a5f-9af8-b2b5d5170572) (789 `lib/` files, read-only) |
| Conflicts with WT | None for files touched; currency label file was already present and was safely re-exported |

---

## 2. Scope and files inspected

### In scope (sampled + targeted)

| Area | Evidence method |
|------|-----------------|
| Clean Architecture (Presentation / Domain / Data) | Grep + file reads vs ADR-001; prior architecture leak table re-verified |
| Audio library feature | Full read of bloc/state/repo/datasource; remediations applied |
| Chat remote datasource error path | Targeted grep + fix |
| Admin domain reports | Domain import graph; currency leak fixed |
| Callable invoke logging | `lib/core/firebase/callable_invoke.dart` |
| Hardcoded Arabic strings | Spot samples across parent/teacher presentation |
| Fat presentation files | Line-count scan (`>1000` lines) |
| Secrets / credential files | Local glob + pattern search (no secret values printed) |
| Dependency health | Attempted `dart pub outdated` (tooling failure — see §8) |
| Static analysis | `flutter analyze` on modified paths |
| Regression tests | New + existing audio / `userFacingErrorText` tests |

### Explicitly not fully inspected

- Exhaustive remediation of all 15+ presentation→data leaks (catalogued by evidence scan; GetIt partially applied historically).
- Full localization / Dark Mode (deferred by product).
- Mushaf protected Quran content deep dive (per prior BASMA-018 policy).
- Mass `ServerException(e.toString())` rewrite across ~111 datasource sites (mitigated centrally by `ServerFailure` → `userFacingErrorText`).
- Production Firebase, deploys, IAM, dependency upgrades.

---

## 3. Confirmed findings by severity

### High

| ID | Finding | Evidence | Disposition |
|----|---------|----------|-------------|
| D3-H1 | Presentation → Firebase/Firestore in admin screens | `admin_halaqa_details_page.dart`, `admin_broadcast_page.dart`, `admin_payments_ledger_page.dart`, `admin_students_tab.dart`, `admin_teachers_page.dart` import `cloud_firestore` | **Deferred** — extraction needs DI/usecase migration; risk of behavior drift |
| D3-H2 | Presentation → Data in chat | `chat_room.dart`, `chat_groups_provider.dart`, `chat_person_search.dart`, `chat_group_info_page.dart` import `chat_groups_repository.dart` | **Deferred** — would require domain contract + GetIt regenerate |
| D3-H3 | Presentation → FirebaseAuth + Data services in audio | `audio_bloc.dart` depends on `FirebaseAuth`, `AudioPlayerService`, `mp3quran_catalog_service` | **Partial** — debug/`print` noise removed; Auth dependency kept (progress save needs uid; DI regenerate deferred) |
| D3-H4 | Domain → Data for `StaffStatus` | `admin/domain/admin_reports.dart` imports `../data/staff_lifecycle_repository.dart` | **Deferred** — moving enum touches admin data + many presentation call sites |

### Medium

| ID | Finding | Evidence | Disposition |
|----|---------|----------|-------------|
| D3-M1 | Debug `print` in audio hot path | `audio_bloc.dart`, `audio_state.dart`, `audio_library_repository_impl.dart` | **Fixed** |
| D3-M2 | English / raw dumps as `ServerException` in audio | `User not authenticated`; `e.toString()` in audio datasource | **Fixed** (Arabic `signedOutErrorText` + `userFacingErrorText`) |
| D3-M3 | Domain → Presentation currency import | `admin_reports.dart` imported `shared/presentation/academy_currency_label.dart` | **Fixed** — constant moved to `shared/domain/academy_currency.dart`; presentation re-exports |
| D3-M4 | Chat datasource raw `e.toString()` | `chat_remote_datasource.dart` mark-read + participant lookup | **Fixed** |
| D3-M5 | Callable `debugPrint` always on | `callable_invoke.dart` | **Fixed** — gated with `kDebugMode` |
| D3-M6 | Widespread `ServerException(e.toString())` + raw SnackBars | Datasources + pages that bypass `AppErrorWidget` ([D3 evidence scan](d5ea661b-2a1c-4a5f-9af8-b2b5d5170572)) | **Partial** — `AppSnackBar.showError` now sanitizes; raw `SnackBar(Text(...))` call sites remain |
| D3-M7 | Oversized presentation files (SRP) | **19** presentation files >1000 lines (scan); e.g. `parent_child_profile_page.dart` 1572 | **Deferred** — cosmetic/structural rewrite out of scope |
| D3-M8 | Empty `catch (_) {}` in recovery paths | 15 empty catches / 7 files (mushaf audio, audio bloc, notifications, auth sign-out, …) | **Documented** — teardown/soft-fail; admin/supervisor search silent-empty deferred |
| D3-M9 | AuthBloc read swallowed as login error | `create_halaqa_activity_sheet.dart:108-118` ([Bounded D3 scan](843626ba-f90a-4588-b131-4babcb67912c)) | **Fixed** — removed broad catch |
| D3-M10 | Homework/schedule usecases passed raw `e.toString()` | `homework_usecases.dart`, `get_weekly_sessions_usecase.dart` | **Fixed** — `ServerException` preserved; else `userFacingErrorText` |
| D3-M11 | Duplicate connection / session literals | accounts + directory repos; callable_invoke | **Fixed** — reuse `connectionErrorText` / `signedOutErrorText` |

### Low

| ID | Finding | Evidence | Disposition |
|----|---------|----------|-------------|
| D3-L1 | Typo’d filename retained | `teacher_evalutation_page.dart` | **Deferred** — rename needs route/import cascade |
| D3-L2 | `withOpacity` vs `withValues` | Prior Stage A count ~41 | **Deferred** — SDK-sensitive mass replace |
| D3-L3 | Unguarded `debugPrint` in student mushaf/recitation | `student_mushaf_page.dart`, `student_recitation_page.dart` | **Fixed** — gated with `kDebugMode` (0 raw `print(` remain under `lib/`) |
| D3-L4 | Hardcoded Arabic UI strings (no `.arb`) | Cross-role duplicates (`إعادة المحاولة` ×28, `تسجيل الخروج` ×7, …) | **Deferred** — full l10n gated |
| D3-L5 | Technical copy in user-facing index error | `missingIndexErrorText` mentioned Firestore | **Fixed** — non-technical Arabic |
| D3-L6 | Proven zero-reference dead code | Export shim, preview app, unused skeleton/typedef/route consts | **Fixed** (see §7 / §9); larger orphans deferred |

---

## 4. Architecture violations

Reconfirmed against ADR-001 (Presentation → Domain → Data):

1. **Domain is mostly clean of Firebase packages** — no `cloud_firestore` / `firebase_*` imports under `lib/features/**/domain/**` found this pass.
2. **Domain → Data leak remains** for `StaffStatus` (D3-H4).
3. **Domain → Presentation leak for currency** was real and is **closed** via `lib/shared/domain/academy_currency.dart`.
4. **Presentation → Data / Firebase** remains the dominant structural debt (admin screens, chat groups, audio bloc) — documented, not rewritten.
5. **DI gaps** (from architecture audit): some features still construct repos with `sl<FirebaseFirestore>()` outside generated GetIt — not re-audited exhaustively; treat as standing debt.

No new layers or speculative abstractions were introduced.

---

## 5. Duplication and complexity

| Topic | Evidence | Harmful? | Safest action |
|-------|----------|----------|---------------|
| Role load-error strings (`تعذر تحميل…` / `حدث خطأ`) | Parent + teacher (+ other roles) presentation | Mild — wording consistency | Keep feature-local until l10n; do not merge role-permission logic |
| Payment money formatting | Was presentation-owned constant used by domain reports | Yes (layer) | **Fixed** by domain ownership of `academyCurrencyLabel` |
| Fat pages >1000 lines | 13 presentation files | Maintainability | Defer extraction until feature work touches them |
| `ServerException(e.toString())` pattern | Many datasources | Partially mitigated by `ServerFailure` | Incremental replace when editing those files |
| Filename typo `evalutation` | Teacher feature | Low | Defer rename |

Authorization differences between student / parent / teacher / supervisor / admin were **not** collapsed.

---

## 6. Hardcoded-string findings

Classification (no mass localization):

1. **Repeated user-facing strings** — load failures (`تعذر تحميل الرسائل`, `تعذر تحميل الحلقات`, `حدث خطأ`) across role UIs.
2. **Important messages in Widgets** — feature screens own Arabic fallbacks next to `state.*Error` (acceptable under current conventions).
3. **Inconsistent wording** — same failure class sometimes `حدث خطأ` vs `تعذر تحميل…`.
4. **Technical leaks** — audio English `User not authenticated` **fixed**; raw Firebase dumps mitigated by `userFacingErrorText` / `ServerFailure`.
5. **Should centralize** — only cross-layer constants with clear ownership (currency) — **done**.
6. **Legitimate local constants** — audio playback error `'تعذر تحميل الصوت، تحقق من اتصال الإنترنت'` stays in bloc.

Arabic RTL meaning preserved for all changed user-facing copy.

---

## 7. Dead-code findings

| Candidate | Evidence | Action |
|-----------|----------|--------|
| Audio debug `print` statements | Present before D3; removed | **Removed** (0 `print(` under entire `lib/` per evidence scan) |
| `student_hadith_widget.dart` export shim | 0 importers | **Deleted** |
| `TeacherExcusesPreviewApp` | 0 importers | **Deleted** preview file |
| `ParentProfileHeaderSkeleton` | 0 instantiations | **Removed** |
| `MushafQuranBundle` typedef | 0 references | **Removed** |
| `AppRoutes.studentEvals` / `teacherStudent` | 0 references (nested paths used instead) | **Removed** constants |
| `StudentMushafDashboard`, DI-only usecases, `attachMirroredPostId` | Zero UI callers but guarded by tests / injectable codegen | **Deferred** |
| Unused pub dependencies | `dart pub outdated` failed (corrupted PubCache) | **No dependency removals** |
| Assets | Not inventory-audited | **Deferred** |

Policy followed: do not delete merely for lack of an obvious reference.

---

## 8. Secret / dependency inspection

**Detection only — no rotation, no IAM, no uploads, no secret values in this report.**

| Item | Category | Context | Classification |
|------|----------|---------|----------------|
| `lib/firebase_options.dart` `apiKey` fields | Public Firebase web/client config | FlutterFire generated options | **False positive / expected public** |
| `android/app/**/google-services.json` (dev/staging/main) | Public Android client config | Flavor google-services | **Expected public** |
| Plugin symlink example `google-services.json` / plists under `windows/flutter/ephemeral/.plugin_symlinks/**` | Third-party example configs | Pub cache symlinks | **Not app secrets** |
| `functions/test/migrate_guards.test.mjs` fake `private_key: "SECRET"` | Test fixture | Guard unit test only | **False positive** |
| Service-account JSON / `BEGIN PRIVATE KEY` in repo source | Private key material | Pattern search: **no matches** in app source | **None confirmed** |
| `dart pub outdated` | Dependency advisories | Failed: PubCache `url_launcher_linux-3.2.3/pubspec.yaml` missing `name` | **Blocked Verification** (local tooling) |

No confirmed private credential exposure requiring owner remediation was found in this local scan.

---

## 9. Fixes implemented

| Change | Files |
|--------|-------|
| Removed audio library `print` debug noise | `audio_bloc.dart`, `audio_state.dart`, `audio_library_repository_impl.dart` |
| Arabic signed-out exception + import | `audio_library_repository_impl.dart` |
| Sanitize audio datasource exceptions | `audio_library_remote_datasource_impl.dart` |
| Gate callable logging with `kDebugMode` | `callable_invoke.dart` |
| Sanitize chat mark-read / participant errors | `chat_remote_datasource.dart` |
| Move currency helpers to domain; presentation re-export | `shared/domain/academy_currency.dart` (new), `shared/presentation/academy_currency_label.dart`, `admin/domain/admin_reports.dart` |
| Regression tests | `test/features/audio_library/audio_library_error_mapping_test.dart` (new) |
| Unused import cleanup | `audio_event.dart` (removed unused `flutter/material.dart`) |
| Stop swallowing AuthBloc read as “must login” | `create_halaqa_activity_sheet.dart` |
| Homework / schedule usecases sanitize unknown errors | `homework_usecases.dart`, `get_weekly_sessions_usecase.dart` |
| Reuse `signedOutErrorText` / `connectionErrorText` | `callable_invoke.dart`, `academy_accounts_repository.dart`, `academy_directory_repository.dart` |
| Homework error-mapping regression | `test/features/homework/homework_error_mapping_test.dart` (new) |
| `AppSnackBar.showError` sanitizes via `userFacingErrorText` | `shared_widgets.dart` |
| Soften index-missing user copy (no “Firestore”) | `user_facing_error.dart` |
| Gate student mushaf/recitation `debugPrint` | `student_mushaf_page.dart`, `student_recitation_page.dart` |
| Remove proven dead symbols/files | hadith export shim, excuses preview, profile skeleton, mushaf typedef, unused route consts |
| SnackBar sanitization regression | `test/shared/app_snackbar_error_sanitization_test.dart` (new) |

---

## 10. Tests and verification

| Command | Result |
|---------|--------|
| `flutter test test/features/audio_library/audio_library_error_mapping_test.dart test/features/audio_library/audio_library_bloc_test.dart test/shared/user_facing_error_test.dart` | **15/15 passed** |
| Re-run `audio_library_error_mapping_test.dart` after format | **3/3 passed** |
| Follow-up: `homework_error_mapping_test` + audio + user_facing_error | **11/11 passed** |
| Evidence-scan follow-up: snackbar sanitization + user_facing + route_registry | **9/9 passed** |
| `flutter analyze` on modified audio / shared currency / admin_reports / callable_invoke / chat datasource | **No issues found** |
| Follow-up analyze (homework/schedule/teacher sheet/accounts/directory/callable) | **No issues found** |
| Evidence-scan follow-up analyze (shared_widgets, routes, mushaf event, student pages) | **6 info** only (`withOpacity` deprecated — pre-existing; no errors/warnings from D3 edits) |
| `dart format` on modified paths | Applied |

Broader full Flutter suite **not** re-run (focused evidence sufficient per D3 policy).

---

## 11. Intentionally deferred (with reasons)

1. **Admin / chat / accounts presentation → concrete data repositories** — confirmed again by [Bounded D3 scan](843626ba-f90a-4588-b131-4babcb67912c) (`admin_account_access_card`, `admin_reports_page`, `chat_room`); requires domain contracts + DI regenerate.
2. **Remove `FirebaseAuth` from `AudioLibraryBloc`** — needs uid ownership in repository/usecase + GetIt regenerate.
3. **Move `StaffStatus` into domain** — wide import surface.
4. **Mass `ServerException(e.toString())` cleanup** — already sanitized at `ServerFailure`; churn outweighs benefit.
5. **Full l10n / Dark Mode / design-system rewrite** — product deferred.
6. **Fat-page SRP extractions** — no feature change justifying rewrite.
7. **Rename `teacher_evalutation_*`** — rename cascade.
8. **Dependency upgrades / vulnerability remediations** — owner approval; `pub outdated` tooling broken locally.
9. **D2 reopen** — no new efficiency evidence requiring D2 rework.

---

## 12. Remaining risks and limitations

- Architecture leaks in admin/chat remain; future feature work should route through domain contracts.
- Empty catch blocks in audio/mushaf recovery can hide secondary failures (acceptable for stop/teardown today).
- Hardcoded Arabic strings remain the norm; inconsistent fallbacks will persist until l10n.
- Secret scan is local-pattern based, not a full SCA pipeline; PubCache corruption blocked `pub outdated`.
- Working tree was already dirty; D3 edits are additive and did not discard unrelated user changes.
- Coverage is **bounded**, not whole-repo exhaustive.

---

## Final verdict

# PASS WITH GAPS

Important confirmed in-scope defects were fixed or explicitly classified. Regression tests and analyze on touched paths passed. Structural Clean Architecture debt outside safe remediations remains documented. No production/cloud actions performed. D3 stops here.
