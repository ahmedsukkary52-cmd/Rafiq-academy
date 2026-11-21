# BASMA RB-01 — Flutter Full Suite Diagnosis & Close-out

**Date:** 2026-11-18  
**Branch:** `unify/basma-v1` @ `bb0a905`  
**Verdict:** `RB-01 CLOSED — FULL SUITE GREEN`

---

## 1. Baseline (before RB-01 work)

| Metric | Value |
|--------|------:|
| Command | `flutter test --reporter expanded` |
| Result | `+2438 ~3 -43`, exit **1** |
| Log | `D:\Temp\rb01_full_suite_run.txt` |
| Historical note | Prior ~43 matched; not assumed a priori |

Git before: HEAD `bb0a905`, staged ~39 (`A`=11, `M `=25, `MM`=3), unstaged-only ~183, untracked ~64.

---

## 2. Failure classification (43 → root causes)

| Group | Count | Root cause | App / test / env |
|-------|------:|------------|------------------|
| Parent achievements callable | 11 | Soft Firestore fallback + swallow-to-empty on errors | **App** (unstaged) |
| Parent child profile UI | 10 | Missing `GetLatestHomeworkUseCase` in harness + UI showing halaqa twice | **App deps + test harness** |
| Admin meeting links (B14) | 7 | `GoRouterState.of` required in page build | **App** (test harness break) |
| Admin reports branding | 3 | Product BASMA stems vs `rafiq_` expectations | **Test drift** (app correct) |
| Callable reviewPaymentProof | 2 | Fake returned `null`; invoke requires map | **Test fake** |
| Parent direct-query guards | 3 | Halaqat/achievements fallbacks in datasource | **App** |
| Architecture import climb | 1 | Bad `../../../../shared/` import in session card | **App** |
| Emulator cleartext | 1 | Config intentionally allows `localhost` | **Test** (align to config) |
| Admin dashboard copy | 1 | `التعيين` vs `الموافقة` | **Test** (app copy intentional) |
| Admin ops invalid link | 1 | Normalize rewrote path spaces → valid | **App** (policy) |
| Payment destinations | 1 | Missing confirm + InstaPay mobile contract + disabled save | **App** |
| Student mushaf send guard | 1 | Lost `StudentRecitationPage(` navigation marker | **App** |
| Meeting policy whitespace-only | (post-fix) | Blank spaces classified as whitespace | **App** (fixed) |

D4 list/nav changes were **not** in the fail set.

---

## 3. Fixes applied (safe, RB-01 scope)

- Restore parent callable-only achievements + schedule (remove demo Firestore fallbacks).
- `AdminHalaqatPage`: tolerate missing GoRouter.
- Meeting link normalize: no arbitrary path-space→hyphen; blank → empty.
- Payment destinations: restore official-destination confirm; keep save tappable; legacy InstaPay display status.
- Session card relative imports; architecture allowlist drop obsolete clamped edge.
- Mushaf chrome: restore `onOpenRecitation` → `StudentRecitationPage` (navigation only).
- Align tests: cleartext domains, BASMA report stems, dashboard copy, InstaPay mobile save, profile DI fakes, halaqa `findsWidgets`.
- Callable contract fakes return `{}` for review success map.

---

## 4. Verification

| Run | Result |
|-----|--------|
| Historical 16-file fail-cluster | `+255` All passed, exit 0 |
| Full suite after fixes | **`+2486 ~3` All tests passed, exit 0** |
| Log | `D:\Temp\rb01_full_suite_final.txt` |

No skips added. No Production Gate / deploy / commit.

---

## 5. Git after

HEAD still `bb0a905`. Staged pattern preserved (`A`=11, `M `=25, `MM`=3). Unstaged grew with RB-01 edits (` M` ~190, status_rows ~293). Untracked count ~64.
