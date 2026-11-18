# BASMA — Final Engineering Quality Review

**Date:** 2026-11-18  
**Branch:** `unify/basma-v1` @ `bb0a905` + dirty worktree  
**Nature:** Consolidated assessment after Engineering Quality Phase 1 (EQ-B1–B6). **Not** an implementation pass.  
**Phase 1 disposition:** **CLOSED WITH DEFERRED FINDINGS**  
**Companion roadmap:** `BASMA_REMAINING_WORK_ROADMAP.md`  
**Progress log:** `BASMA_ENGINEERING_QUALITY_REMEDIATION_PROGRESS.md`  
**Original audit:** `BASMA_FINAL_ENGINEERING_QUALITY_AUDIT.md`

### Checkpoint note (added 2026-11-18; does not rewrite review-time evidence)

After this review was written, checkpoints landed: **D2 `daa8f85`**, **EQ DI `0889682`**. Phase 1 disposition remains **CLOSED WITH DEFERRED FINDINGS**. EQ-M-06 deferred. RB-01 remains historically **CLOSED** (`+2486 ~3`); Full Suite **not re-run** on `0889682`. RB-02 / RB-16 / RB-17 / RB-18 / D4 device-lab remain **OPEN**. Focused EQ DI verification was **93** tests on the **full working tree** (not isolated commit-only). See roadmap + progress log for current sequence (DOC → G0/G1 → …).

---

## 1. Overall conclusion

BASMA has a coherent feature-first Clean Architecture intent, a large local Flutter test corpus, and **verified local remediation** of the highest-confidence presentation→Firebase / missing-GetIt samples identified for Phase 1.

That does **not** mean the codebase is fully SOLID, free of architecture leaks, production-ready, or engineering-complete.

| Claim | Verdict |
|-------|---------|
| Phase 1 EQ remediation (safe local DI/extraction samples) | **Closed with deferred findings** |
| Overall engineering quality “done” | **No** |
| Release / Cloud readiness | **No** — most RB-02…RB-19 remain OPEN |
| Full Flutter Suite currently green on this dirty tree | **Historically verified** at RB-01 close (`+2486 ~3`); **not re-run** this review |
| Device / DevTools proof | **Absent** (RB-18 deferred) |

**Bottom line:** Treat Phase 1 as a completed **bounded maintainability campaign**. Remaining work splits cleanly into (A) owner-gated release blockers and (B) scheduled architecture/test/performance backlog — do not conflate them.

---

## 2. Evidence basis (what was / was not re-verified)

| Source | Used how |
|--------|----------|
| `BASMA_ENGINEERING_QUALITY_REMEDIATION_PROGRESS.md` | Batch-by-batch reported tests/analyze |
| Working-tree spot checks (2026-11-18) | Confirmed B1–B6 artifacts still present |
| `BASMA_RELEASE_BLOCKERS.md` | Authoritative RB statuses |
| Final quality audit + remediation plan | Original finding map |
| Master issue register | Cross-link / status sync |
| Full Suite / emulator / Cloud / device | **Not** re-executed this review |

Uncertainties that would require a targeted re-run (not done here): whether RB-01 suite remains green after post–RB-01 dirty-tree growth (EQ batches + other unstaged work). Assessment treats RB-01 as historically closed; do not claim current-suite green without a new full run.

---

## 3. Phase 1 B1–B6 verification summary

Working-tree presence checked for key symbols/files. Reported tests/analyze are from each batch’s progress log (not re-executed wholesale).

### EQ-B1 — Admin Firestore extraction + Auth read reliability

| | |
|--|--|
| **Original** | Broadcast/halaqa used Firestore from presentation; activities swallowed Auth read errors |
| **Fix** | `countBroadcastAudienceForRole` / `loadAdminHalaqaDocument` + DI Firestore; activities rethrow unless ProviderNotFound |
| **Still present?** | **Yes** — data helpers + page wiring; activities catch pattern present |
| **Reported tests** | Broadcast/ops architecture tests green (batch log) |
| **Limitations** | Presentation still imports data helpers for defaults (project pattern); other admin Firebase sites remain |
| **Status** | **Complete** |

### EQ-B2 — Payments ledger session + labels

| | |
|--|--|
| **Original** | Ledger page owned paging/filter/summary machine + presentation |
| **Fix** | `AdminPaymentsLedgerSession` + label helpers; page thinned |
| **Still present?** | **Yes** |
| **Reported tests** | Ledger widget 16 + session 7; analyze clean |
| **Limitations** | Details page load still inline; reports not touched |
| **Status** | **Complete** |

### EQ-B3 — Settings password Auth extraction

| | |
|--|--|
| **Original** | Auth password path lived in settings presentation |
| **Fix** | `changeOwnPasswordWithAuth` in data; thin DI default |
| **Still present?** | **Yes** — no `FirebaseAuth.instance` in that path |
| **Reported tests** | 9 passed (settings + unit); analyze clean |
| **Limitations** | Pre-existing unstaged UI hunks on same file |
| **Status** | **Complete** |

### EQ-B4 — Directory / accounts GetIt registration

| | |
|--|--|
| **Original** | Concrete directory/accounts repos constructed in UI |
| **Fix** | Manual `registerDirectoryAndAccountsRepositories()`; resolve via `sl<>` |
| **Still present?** | **Yes** in `injection_container.dart` |
| **Reported tests** | 33 targeted (directory + onboard); analyze info-only on unrelated prefer_const |
| **Limitations** | Manual GetIt (not injectable codegen); complaints/assistant untouched |
| **Status** | **Complete** (sample scope) |

### EQ-B5 — Chat groups Storage/Functions boundary

| | |
|--|--|
| **Original** | Presentation built `ChatGroupsRepository` from Storage/Functions |
| **Fix** | `registerChatGroupsRepository()`; provider → `sl<ChatGroupsRepository>()` |
| **Still present?** | **Yes** — provider has no Firebase client imports |
| **Reported tests** | 28 chat DI/messaging/room/watch; analyze clean |
| **Limitations** | Message path already injectable; groups were sibling repo. Staged D2 chat hunks separate |
| **Status** | **Complete** |

### EQ-B6 — Remaining accounts constructors + chat accounts inject

| | |
|--|--|
| **Original** | `first_login` / access card constructed accounts; chat `searchPeople` per-call ctor |
| **Fix** | Presentation → `sl<>`; `ChatGroupsRepository.accounts` injected |
| **Still present?** | **Yes** — only composition-root ctor of `AcademyAccountsRepository(` in lib |
| **Reported tests** | 22 combined + 4 boundary; analyze clean |
| **Limitations** | `_defaultParents` still `sl<FirebaseFirestore>()` in access card |
| **Status** | **Complete** |

**Phase 1 classification (unchanged):** CLOSED WITH DEFERRED FINDINGS — not overall engineering-quality completion.

---

## 4. Audit §2.3 leak map — current disposition

| # | Historical sample | Disposition after Phase 1 |
|---|-------------------|---------------------------|
| 1 | `admin_halaqa_details_page` | **Fixed** (B1) — still uses data helper + DI |
| 2 | `admin_broadcast_page` | **Fixed** (B1) |
| 3 | `admin_settings_tab` password | **Fixed** (B3) |
| 4 | `admin_account_access_card` | **Partially fixed** — accounts reset via GetIt; parent Firestore load remains |
| 5 | `admin_directory_page` | **Partially fixed** — repo via GetIt; no full bloc/usecase graph |
| 6 | `first_login_page` | **Partially fixed** — accounts via GetIt; still bypasses AuthBloc for complete-first-login (intentional seam) |
| 7 | `chat_room` / `chat_groups_provider` | **Fixed** for groups repo construction (B5) |
| 8 | `audio_library` bloc Auth coupling | **Still confirmed** — not in Phase 1 |
| 9 | `complaints_entry` | **Still confirmed** — constructs with `sl` Firebase clients |
| 10 | `assistant_home` / cover banner | **Still confirmed** |
| 11 | Other admin tabs / reports | **Still confirmed** for reports; ledger improved (B2) |

---

## 5. Remaining findings by category

### A. Release blockers (not engineering-quality “nice-to-haves”)

From `BASMA_RELEASE_BLOCKERS.md` (authoritative). Emulator ≠ production.

| ID | Status (doc) | Notes |
|----|--------------|-------|
| RB-01 | **CLOSED** | Historical full suite green; not re-run this review |
| RB-02 | **OPEN** | Local recitation index verified in WT; Cloud deploy pending |
| RB-03 / RB-04 | **OPEN** | Rules on prod target |
| RB-05–RB-09 | **OPEN** | Functions, Blaze, gate, secrets, final project |
| RB-10 | CLOSED (documented) | Region split |
| RB-11–RB-13 | **OPEN** | Meeting-link migration / enablement |
| RB-14–RB-15 | **OPEN** | Payment / account prod E2E |
| RB-16 | **OPEN** | Local build review done; prod artifacts/CI proof pending |
| RB-17 | **OPEN** | Ready for owner key creation; no key created |
| RB-18 | **OPEN** | Device briefly seen; no smoke/DevTools |
| RB-19 | **OPEN** | Store publish |
| RB-D4-01..03 | **OPEN** | Icon/splash/profile device evidence |

### B. High-priority engineering defects (behavior / integrity / security exposure risk)

| ID | Title | Evidence | Notes |
|----|-------|----------|-------|
| EQ-R-01 | Live Cloud unpublished / trial over-reads | BASMA-100/101/102 | **Owner-gated**; same as Wave 0 |
| EQ-R-02 | Payment / subscription prod cycle unverified | RB-14, BASMA-005 | Not a local refactor item |
| EQ-R-03 | Access-card parent load via presentation Firestore | `_defaultParents` | Incorrect-app risk on emulator flavors if mis-wired; smaller than Cloud P0 |

Most “high” Phase 1 items that were **local and safe** were addressed. Remaining true P0s are overwhelmingly **Cloud/owner**.

### C. Architecture & maintainability backlog

| ID | Title | Priority | Disposition |
|----|-------|----------|-------------|
| EQ-M-01 | Register `AdminReportsRepository` / thin reports UI (keep AdminBloc+PDF) | P2 | **DI Done (EQ-4)**; AdminBloc+PDF still deferred |
| EQ-M-02 | Complaints entry → GetIt-registered repo | P2 | **Done (EQ-3)** |
| EQ-M-03 | Assistant home / cover → DI | P2 | **Done (EQ-3)** |
| EQ-M-04 | Access-card `_defaultParents` → data helper | P2 | **Done (EQ-2)** |
| EQ-M-05 | Audio bloc FirebaseAuth coupling | P2 | Schedule later |
| EQ-M-06 | Manual GetIt vs injectable codegen consistency | P2 | When staged `injection_container.config.dart` safely regenerable |
| EQ-M-07 | Mega-page splits (parent profile, teacher eval, supervisor tabs) | P2/P3 | Only when product-touching |
| EQ-M-08 | Filename `teacher_evalutation_page` | P3 | Optional rename |
| EQ-M-09 | Directory without full bloc/usecase | P3 | Acceptable composition-root pattern for now |

### D. Test & observability gaps

| ID | Title | Priority |
|----|-------|----------|
| EQ-T-01 | onboarding / review_schedule feature tests thin/zero | P2 |
| EQ-T-02 | Coverage % unknown (BASMA-105) | P3 |
| EQ-T-03 | Emulator ≠ Cloud; 30 callable wrappers core-only | P1 (release-adjacent) |
| EQ-T-04 | Full Suite not re-proven after EQ dirty-tree growth | P2 |

### E. Performance / device / polish

| ID | Title | Priority |
|----|-------|----------|
| EQ-P-01 | Remaining eager ListView hot paths (measured) | P2 |
| EQ-P-02 | RB-18 / DevTools / RB-D4 matrix | P1 release-adjacent |
| EQ-P-03 | L10n / dark / design system | P3 deferred product |

### F. Explicitly out of scope / accepted

- Quran/Mushaf protected review (BASMA-018).
- Payment architecture rewrite.
- Product/account-provisioning strategy changes.
- Independent final Firebase project selection.

---

## 6. What Phase 1 did **not** fix (clearly)

- Any Cloud deploy or production Rules/Indexes/Functions proof.
- Admin reports/PDF responsibility split (DI registration later done in `0889682`; PDF/AdminBloc still deferred).
- Staff full DI graphs / remaining presentation seams (complaints/assistant DI later included in `0889682`).
- Mega-page SRP splits.
- Device lab / profile jank baselines.
- Regenerating injectable config (EQ-M-06 deferred; D2 config already committed in `daa8f85`).

---

## 7. Git state at review time (read-only)

| Item | Value |
|------|--------|
| HEAD | `bb0a90585adb9ee684848cd547cb234cff2a47fa` |
| Branch | `unify/basma-v1` |
| Staged file count | **39** |
| Status rows (approx.) | **320** |
| Git mutations this task | **None** |

**Historical note:** Values above are the review-time snapshot. They are **not** current HEAD. Later checkpoints: D2 `daa8f85`, EQ DI `0889682` (see checkpoint note at top). The former 39 staged files were **not** committed as one unit; D2 was isolated first.

---

## 8. Recommended reading order next

1. This review (assessment) + top checkpoint note.  
2. `BASMA_REMAINING_WORK_ROADMAP.md` (phases + next task).  
3. `docs/production/BASMA_RELEASE_BLOCKERS.md` (release P0).  
4. Progress log for batch evidence detail.  
5. `BASMA_MASTER_ISSUE_REGISTER.md` (register sync).
