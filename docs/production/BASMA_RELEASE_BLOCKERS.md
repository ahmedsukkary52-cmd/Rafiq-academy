# BASMA Release Blockers Register

**Purpose:** Persistent tracking of issues that block a production release.  
**Local/emulator success does not clear Cloud or device-lab blockers.**  
**Statuses:** `OPEN` | `IN PROGRESS` | `BLOCKED` | `VERIFIED` | `CLOSED`

**Last updated:** 2026-11-18 (docs sync: D2 committed `daa8f85`, EQ DI committed `0889682`; RB statuses unchanged — RB-01 CLOSED; RB-02/16/17/18 + D4 device-lab OPEN; no Cloud/prod verification claimed)

---

## A. D2 — Flutter and app data

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-01 | Full Flutter Suite failures on full working tree | CLOSED | Before RB-01: `+2438 ~3 -43`, exit 1. After fixes: `flutter test` → **`+2486 ~3`, All tests passed, exit 0** (log `D:\Temp\rb01_full_suite_final.txt`). Root causes were unstaged WT regressions (parent soft-fallbacks, meeting-link normalize, payment confirm, GoRouter harness, branding/copy drift), not D2 staged set. |
| RB-02 | Firestore composite index `recitationRecords`: `halaqaId ASC` + `date DESC` verified in final Cloud project | OPEN | **Local definition verified** + **query compatibility verified** (teacher `newestByDate`: collection `recitationRecords`, `where halaqaId` + `orderBy date DESC` + limit; `queryScope: COLLECTION`). Index definition remains in **unstaged** `firestore.indexes.json` (not part of D2 `daa8f85` or EQ DI `0889682`). Payment indexes (`status+amount`, `status+amountPaidConfirmed`) co-located in same WT file — **out of RB-02 scope**. Evidence: `docs/engineering-audit/BASMA_RB02_RECITATION_INDEX_LOCAL_VERIFICATION.md`. Targeted tests historically +8 pass. **Cloud presence/deployment still PENDING** on final Firebase project (RB-09). Emulator ≠ Production. Status stays OPEN until named Cloud evidence. |
| RB-03 | Firestore Security Rules verified on production target | OPEN | Local file present; no production deploy/verify in D1/D3. Needs owner project + G1. |
| RB-04 | Cloud Storage Rules verified on production target | OPEN | Local file present; no production deploy/verify. Needs owner project + G1. |

## B. D3 — Cloud Functions and production

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-05 | Cloud Functions actually deployed | OPEN | D3 local/emulator only. No deploy. |
| RB-06 | Blaze / budget / spend limits decision | OPEN | External gate G3. Owner financial approval. |
| RB-07 | `PRODUCTION_BACKEND_ENABLED` remains closed until verified + approved | OPEN | Gate code enforces closed-by-default. Must stay unset until owner unlock. |
| RB-08 | Production env / secrets for final project | OPEN | Not approved for final project. |
| RB-09 | Final Firebase project selection and configuration | OPEN | Do not assume current `rafiq-academy` / aliases are final. Owner decision. |
| RB-10 | Region split: `adminMigrateHalaqaSlotIds` + `processPaymentOverdueGrace` on `us-central1` | CLOSED (documented) | Not client call paths. Do not reopen without new technical reason. See D3 region close-out. |

## C. B14 — Meeting Links

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-11 | Legacy meeting-link data migration on production | OPEN | Local migration tooling + emulator tests exist; no prod migration. |
| RB-12 | Remove legacy field dependency; canonical-only path verified in production | OPEN | Policy/code paths exist; production verification pending. |
| RB-13 | Supervisor meeting-link add remains disabled until security + migration conditions | OPEN | Product/security gate; do not enable without owner approval. |

## D. Business workflows

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-14 | Full payment cycle E2E: proof upload → review → approve → subscription update | OPEN | Emulator proof-cycle suite exists; production E2E not done. |
| RB-15 | Account creation + real role/permission distribution verified | OPEN | Emulator/account wrappers exist; production verification pending. |

## E. Android / iOS release preparation

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-16 | Android/iOS build configuration review | OPEN | **Formal local review complete** (`docs/engineering-audit/BASMA_RB16_BUILD_CONFIG_REVIEW.md`). Android flavors/guards/versioning reviewed; safe fix: main manifest declares `INTERNET`. Contract tests flavor/iOS +37 pass. **Still OPEN:** no prod `google-services.json`; upload keystore absent (RB-17); iOS Archive/unsigned CI not proven on macOS; Codemagic not run here; owner must confirm prod applicationId / iOS bundle ID / iPad. Not CLOSED. |
| RB-17 | Signing and final release versioning | OPEN | **Local audit complete** — verdict `READY FOR OWNER KEY CREATION` (`docs/engineering-audit/BASMA_RB17_ANDROID_SIGNING_AUDIT.md`). Prod release fail-closed without upload key (re-proven). Codemagic `android-prod-release` references `basma_upload_key` only (static). Root+android gitignore cover keystores. **Still OPEN:** owner must create/backup upload keystore, register `basma_upload_key` in Codemagic, enroll Play App Signing, confirm prod applicationId; no key created this pass. Not CLOSED. |
| RB-18 | Install and test on physical devices | OPEN | **2026-11-18:** SM-A037F briefly seen wirelessly; `com.example.rafiq_academy` installed (v1.0.0+2, debuggable); app not running; **no** DevTools session; physical smoke/matrix **deferred** (not a plan blocker). Local D4 tests pass. Evidence: `docs/engineering-audit/BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md`. Still OPEN. |
| RB-19 | Store / platform publish requirements | OPEN | Owner. |

### D4 leftovers (not release-hard alone, track with RB-16–18)

| ID | Item | Status | Evidence / notes |
|----|------|--------|------------------|
| RB-D4-01 | Icon visual QA matrix across launcher masks | OPEN | Adaptive + mipmaps present locally; **no** device screenshot matrix (`BASMA_RB18_DEVICE_AND_DEVTOOLS_STATUS.md`). |
| RB-D4-02 | Splash double-frame / Android 12+ visual verify | OPEN | `launch_background` + v31 splash attrs wired; device visual confirm pending. |
| RB-D4-03 | Profile-mode jank baselines on low-end device | OPEN | D4 code mitigations landed; **no** DevTools/profile traces this pass. |

---

## Closure rule

A blocker moves to `VERIFIED` / `CLOSED` only with **named evidence** (deploy log, Cloud console check, device matrix, or owner sign-off). Emulator pass alone is insufficient for Cloud/production items.

## D4 local progress (does **not** close Cloud blockers)

- `RepaintBoundary` around `AppFloatingBottomNav` blur (BASMA-106 partial).
- Lazy builders: admin directory (people + halaqat), supervisor payments list, admin registration requests.
- Targeted tests: `test/shared/app_floating_bottom_nav_d4_test.dart`, `test/shared/d4_lazy_list_structure_test.dart`.
