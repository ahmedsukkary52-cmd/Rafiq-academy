# BASMA — Remaining Work Roadmap

**Date:** 2026-11-18  
**Companion review:** `BASMA_FINAL_ENGINEERING_QUALITY_REVIEW.md`  
**Phase 1 EQ:** CLOSED WITH DEFERRED FINDINGS  
**Current HEAD (checkpoint sync):** `0889682` on `unify/basma-v1`  
**Committed checkpoints:** D2 `daa8f85` · EQ DI campaign `0889682`  
**Principle:** Cohesive end-to-end phases; risk × impact; do not mix Cloud owner gates with local maintainability.

**Evidence notes (current):** Focused EQ DI verification was **93 tests on the full working tree** (not an isolated commit-only tree). Full Flutter Suite last reported **`+2486 ~3`** at RB-01 close — **not re-run** on `0889682`. EQ-M-06 (manual GetIt vs Injectable codegen) remains **deferred**. RB-01 **CLOSED**; RB-02 / RB-16 / RB-17 / RB-18 and D4 device-lab items remain **OPEN**. Production Firebase verification and owner-gated decisions remain **pending**.

---

## 1. Deduplicated prioritized inventory

Canonical IDs below supersede overlapping names from the final quality audit §2.3 samples, EQ-P1-* map, and release blockers. Historical BASMA-* / RB-* IDs are linked, not erased.

### P0 — Release / production safety (owner-gated unless noted)

| ID | Title | Category | Evidence / paths | Impact | Owner? | Disposition |
|----|-------|----------|------------------|--------|--------|-------------|
| RB-09 / BASMA-014 | Final Firebase project + config | Release | Blockers doc | Wrong project = wrong data/billing | **Yes** | Defer to owner Wave 0 |
| RB-06 / BASMA-016 | Blaze / budget | Release | Billing checklist | No Functions without plan | **Yes** | Defer |
| RB-03/04 / BASMA-001/002 | Prod Rules verify | Release | Local emulator TESTED only | AuthZ holes on live | **Yes** | Defer deploy |
| RB-02 Cloud | Recitation index on final project | Release | Local WT verified; Cloud pending | Teacher feed query fails | **Yes** | Deploy after project pick |
| BASMA-101 | Live indexes (complaints/payments/…) | Release | Trial FAILED_PRECONDITION | Admin finance broken live | **Yes** | Deploy indexes |
| RB-05 / BASMA-102 | Functions deploy | Release | `functions:list` empty historically | App callables 404 | **Yes** | Defer |
| RB-07 | `PRODUCTION_BACKEND_ENABLED` | Release | Fail-closed gate | Accidental prod open | **Yes** | Keep closed |
| RB-17 / BASMA-015 | Upload keystore + Play signing | Release | READY FOR OWNER KEY CREATION | Cannot ship signed AAB | **Yes** | Owner creates key |
| RB-16 remainder | Prod google-services / Archive proof | Release | Local review done | Store build incomplete | **Yes** | Owner + CI |
| BASMA-100 | Trial live rules over-read | Release/Security | Cloud confirmed historically | Data exposure risk | **Yes** | Rules deploy |
| RB-14 | Payment cycle prod E2E | Release | Emulator only | Billing integrity | **Yes** | After Cloud |

### P1 — High engineering / release-adjacent (local or lab)

| ID | Title | Category | Evidence | Impact | Disposition |
|----|-------|----------|----------|--------|-------------|
| RB-18 / EQ-P-02 | Device smoke + DevTools | Device | Brief wireless sighting only | Unknown runtime UX/jank | Schedule lab |
| RB-D4-01..03 | Icon/splash/profile matrix | Device | D4 code landed | Launcher/splash risk | With RB-18 |
| EQ-T-03 | Callable wrapper coverage gap | Test/Cloud | 30 core-only | AuthZ gaps unknown | Emulator campaign |
| EQ-T-04 | Re-prove Full Suite on dirty tree | Test | RB-01 historical | Regressions possible | Before release claim |
| EQ-M-04 | Access-card `_defaultParents` Firestore | Architecture | Extracted to `AcademyAccountsRepository.listLinkedParentsForStudent` (EQ-2) | — | **Done** |
| RB-11–13 | Meeting-link migration / enable | Product/Security | Emulator tested; prod pending | Wrong link data | Owner |

### P2 — Architecture / maintainability / tests

| ID | Title | Category | Evidence | Disposition |
|----|-------|----------|----------|-------------|
| EQ-M-01 | Admin reports DI / responsibility | Architecture | Repo GetIt done (EQ-4); AdminBloc+PDF still coupled | **DI Done**; PDF/bloc deferred |
| EQ-M-02 | Complaints GetIt registration | Architecture | Registered + entry resolves `sl<>` (EQ-3) | **Done** |
| EQ-M-03 | Assistant DI | Architecture | CoverDuty GetIt + banner gate (EQ-3) | **Done** |
| EQ-M-05 | Audio bloc Auth coupling | Architecture | Final audit §2.3 #8 | Later |
| EQ-M-06 | Injectable regen for manual GetIt | Architecture | Manual GetIt + committed D2 generated config coexist | **Deferred** (do not regen lightly) |
| EQ-M-07 | Mega-page splits | Maintainability | 1.1k–1.5k line pages | Only when touching |
| EQ-P-01 | Eager ListView triage (measured) | Performance | Perf audit + D4 precedent | Measured only |
| EQ-T-01 | onboarding / review_schedule tests | Test | Coverage audit | Schedule |
| EQ-P1-04 remainder | Reports DI closed; PDF/bloc open | Same as EQ-M-01 | Progress map EQ-4 | DI Done; keep PDF deferred |

### P3 — Optional / polish / deferred product

| ID | Title | Disposition |
|----|-------|-------------|
| EQ-M-08 | Rename `teacher_evalutation_page` | Defer |
| EQ-P-03 / BASMA-109 | L10n / dark / design system | Product lock D5 |
| EQ-T-02 / BASMA-105 | Coverage % campaign | Optional |
| Branding infra copy `rafiq-academy` | Intentional ops | Close as accepted |

---

## 2. Proposed phases (cohesive, not tiny ping-pong)

### Phase G0 — Owner Wave 0 (blocks production claims)

**Objective:** Make Cloud and signing real.  
**IDs:** RB-09, RB-06, RB-03/04, BASMA-100/101/102, RB-02 Cloud, RB-05, RB-07, RB-17, RB-16 remainder.  
**Why together:** Same owner decisions; local coding cannot close them.  
**Evidence:** Deploy logs, console checks, named project, keystore registration.  
**Owner decisions:** Required for all.  
**Risk:** Premature `PRODUCTION_BACKEND_ENABLED` unlock.

### Phase G1 — Device & DevTools lab

**Objective:** Close RB-18 + RB-D4 visual/perf gaps.  
**IDs:** RB-18, RB-D4-01..03, EQ-P-02.  
**Depends on:** Installable debug/release build; optional after G0 for prod build.  
**Evidence:** Device matrix notes, screenshots, profile traces.  
**Owner:** Lab access / devices.

### Phase EQ-2 — Finish local accounts presentation Firestore seam — **DONE 2026-11-18**

**Objective:** Extract `_defaultParents` behind accounts repository + DI.  
**IDs:** EQ-M-04.  
**Evidence:** `listLinkedParentsForStudent` + access-card wiring; tests 11 passed; analyze clean. See progress log EQ-2.

### Phase EQ-3 — Complaints + assistant DI sample — **DONE 2026-11-18**

**Objective:** Register existing repos; presentation resolves `sl<>` (B4/B5 pattern).  
**IDs:** EQ-M-02, EQ-M-03.  
**Evidence:** `registerComplaintsAndAssistantRepositories`; 22 tests passed; analyze clean. See progress log EQ-3.

### Phase EQ-4 — Admin reports DI (careful) — **DONE 2026-11-18**

**Objective:** Register `AdminReportsRepository`; presentation resolves `sl<>` **without** rewriting PDF/export.  
**IDs:** EQ-M-01 / EQ-P1-04 remainder (DI slice).  
**Evidence:** `registerAdminReportsRepository` + `defaultAdminReportsRepository`; 18 tests passed; analyze clean. AdminBloc+PDF coupling **deferred**. See progress log EQ-4.

### Phase EQ-DI — Strict DI campaign commit — **DONE 2026-11-18**

**Objective:** Checkpoint EQ-B1–B6 + EQ-2/3/4 DI (hub, helpers, consumers, boundary tests) without D4/UX/supervisor-onboard/PDF/docs collateral.  
**Commit:** `0889682`. Parent: D2 `daa8f85`.  
**Evidence:** Focused **93** tests on the **full working tree** before commit (not isolated commit-only tree). See progress log checkpoint note.

### Phase DOC — Documentation & issue-register sync — **IN PROGRESS**

**Objective:** Align roadmap, register, EQ progress/review, and release-blocker notes with committed D2/EQ hashes and current OPEN blockers.  
**Does not** close Cloud/device/signing items.

### Phase T1 — Suite & coverage hygiene

**Objective:** Re-run Full Suite on release candidate tree; fill EQ-T-01 gaps selectively.  
**IDs:** EQ-T-04, EQ-T-01, optional EQ-T-02.  
**Depends on:** Stable WT or checkpointed branch.  
**Evidence:** Suite log with counts. Last historical Full Suite: RB-01 `+2486 ~3` (not re-run on `0889682`).

### Phase P1 — Measured performance follow-through

**Objective:** Convert only proven hot lists; profile on device when G1 available.  
**IDs:** EQ-P-01, RB-D4-03.  
**Depends on:** G1 for real jank proof.

### Phase SEC — Security & code-review tooling

**Objective:** Inventory and execute security/code-review tooling (after Cloud/device evidence path is clear).  
**Does not** replace owner production verification.

### Phase REL — Final release-readiness review

**Objective:** Consolidated go/no-go against `BASMA_RELEASE_BLOCKERS.md` after G0/G1 evidence.  
**Major UI review** follows release-preparation work (agreed ordering preserved).

### Explicitly deferred product / protected

Payment architecture rewrite · Quran/Mushaf review · L10n/dark · mega-page splits without product touch · store RB-19 until G0+G1 · EQ-M-06 injectable regen until explicitly approved.

---

## 3. Recommended sequence (current)

1. **Phase DOC** — finish docs-only checkpoint (this sync).  
2. **Phase G0** — Cloud/production owner decisions and verification (when owner ready).  
3. **Phase G1** — Device / DevTools diagnostics (when lab ready; may run in parallel with G0 based on availability).  
4. Remaining local EQ — **EQ-M-05**, **T1**, measured **P1** as needed.  
5. **Phase SEC** — security and code-review tooling inventory + execution.  
6. **Phase REL** — final release-readiness review.  
7. **Major UI review** — after release-preparation work (not before G0/G1 evidence path).

**Immediate next (after DOC commit):** **G0** or **G1** by owner/lab availability. Local follow-on if neither: **EQ-M-05** or **T1**. Do **not** start PDF/AdminBloc redesign unless separately approved.

---

## 4. Owner decisions required (checklist)

- [ ] Final Firebase project identity (RB-09)  
- [ ] Blaze / budget (RB-06)  
- [ ] Approve Rules + Indexes deploy (incl. recitation DESC / RB-02 Cloud)  
- [ ] Approve Functions deploy + gate unlock process (RB-05/07)  
- [ ] Create/backup upload keystore; Codemagic `basma_upload_key`; Play App Signing (RB-17)  
- [ ] Confirm prod applicationId / iOS bundle / iPad (RB-16)  
- [ ] Meeting-link migration/enable policy (RB-11–13)  
- [ ] Store listing / RB-19  
- [ ] Whether Quran/Mushaf review is scheduled separately  

---

## 5. Git checkpoint note (updated)

D2 and the strict EQ DI campaign are **committed** (`daa8f85`, `0889682`). Remaining WT includes supervisor onboard product, D4/UI collateral, PDF branding, indexes, Functions/flavor work, and untracked docs — do not treat as one commit. Do **not** regenerate `injection_container.config.dart` without a dedicated assessment (EQ-M-06 deferred).
