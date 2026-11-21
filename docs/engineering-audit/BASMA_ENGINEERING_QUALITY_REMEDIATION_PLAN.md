# BASMA — Engineering Quality Remediation Plan

**Date:** 2026-11-18  
**Companion audit:** `BASMA_FINAL_ENGINEERING_QUALITY_AUDIT.md`  
**Progress log:** `BASMA_ENGINEERING_QUALITY_REMEDIATION_PROGRESS.md`  
**Phase 1 status:** **CLOSED WITH DEFERRED FINDINGS** after EQ-B1–B6 — see `BASMA_FINAL_ENGINEERING_QUALITY_REVIEW.md` + `BASMA_REMAINING_WORK_ROADMAP.md`.  
**Principle:** Fix in dependency order; avoid overlapping mega-refactors; no owner-gated Cloud work without approval.

---

## 1. Ordering rules

1. Security / data integrity (owner gates) before cosmetic refactors.  
2. Fail-closed production paths before polish.  
3. One feature vertical at a time when extracting Firebase out of UI.  
4. Do not mix Quran/Mushaf review into architecture waves.  
5. Do not reopen RB-16/17 product decisions; execute owner key steps separately.  
6. Prefer tests that lock behavior before moving code.

---

## 2. Waves

### Wave 0 — Owner / external (blocks Critical)

| Item | Blockers | Owner? |
|------|----------|--------|
| Final Firebase project + Blaze | RB-09, RB-06, G3 | Yes |
| Deploy Rules/Indexes + live denial matrix | RB-03/04, RB-02 Cloud, BASMA-100, G1/G2 | Yes |
| Functions deploy + gate unlock | RB-05, RB-07, G4 | Yes |
| Upload keystore + Play App Signing | RB-17 | Yes |
| Physical device lab | RB-18, RB-D4-01..03 | Lab + optional |

**Engineering until then:** keep fail-closed clients; do not fake Cloud green.

### Wave 1 — Safe, local, no product decision (can start now)

| Item | Scope | Risk |
|------|-------|------|
| Branding string hygiene | Kill remaining user-facing “Rafiq*” copy via `AcademyBranding` | Low |
| Doc sync | Blockers + master register + remediation plan headers | Low |
| Contract tests | Extend only where behavior already intended | Low |
| Isolate payment vs recitation index docs | Process only; no forced git split without owner | Low |
| Deferred device protocol | Keep RB18 status current when lab runs | Low |

**Done:** settings subtitle branding; RB18 + quality audit docs; Phase 1 Batch 1 (see progress log).

### Wave 2 — Architecture extraction (High, feature-by-feature)

Priority order (impact × churn):

1. **Admin** Firebase-in-page surfaces (`halaqa_details`, `broadcast`, `settings_tab`, reports/payments ledger tabs).  
2. **Accounts / directory** widgets that build repos in UI.  
3. **Chat** presentation Storage/Functions wiring (`chat_room`, `chat_groups_provider`).  
4. **Assistant / complaints** manual entrypoints → DI.  
5. **Audio bloc** FirebaseAuth coupling.

**Method per feature:** usecase/repo already? route UI through it → add/adjust tests → delete direct Firebase from presentation.  
**Avoid:** big-bang move of all admin tabs in one PR.

### Wave 3 — Maintainability splits (High effort)

Split mega-pages only when touching them for Wave 2 or product work:

- `parent_child_profile_page`  
- `teacher_evalutation_page` (+ optional rename)  
- `supervisor_dashboard_tab` / `supervisor_students_tab`  
- Teacher class detail / attendance  

Extract widgets + cubits with golden/widget tests for the touched slice only.

### Wave 4 — Performance follow-through (Medium)

1. Triage remaining `ListView(` — convert only **hot scrolling** lists with evidence (mirror D4).  
2. Stream/subscription dispose audit on long-lived blocs.  
3. Profile-mode traces on device when RB-18 lab runs (RB-D4-03).

### Wave 5 — Explicitly deferred

- Design system / L10n / Dark (D5 product lock)  
- Quran/Mushaf independent review  
- Payment architecture changes  
- applicationId / bundle ID / Firebase project choice  

---

## 3. Suggested PR / change batches (non-overlapping)

| Batch | Contents | Depends |
|-------|----------|---------|
| EQ-A | Branding + docs only | — |
| EQ-B | One admin page Firebase extraction + tests | EQ-A optional |
| EQ-C | Directory/accounts extraction | EQ-B patterns |
| EQ-D | Chat presentation cleanup | Separate from admin |
| EQ-E | Mega-page split (one file) | Prefer after EQ-B on same feature |
| EQ-F | List builder triage (measured) | D4 patterns |
| EQ-G | Device lab evidence pack | Hardware |

---

## 4. Definition of done (quality wave)

A finding moves to VERIFIED only with:

- Named files changed + tests, **or**  
- Owner/Cloud evidence for gates, **or**  
- Explicit “accepted risk” in master register.

Local suite green alone does **not** close Critical Cloud items.

---

## 5. Immediate next engineering step (recommendation)

**EQ-B2:** Next admin Firebase-in-UI extraction (`admin_reports_page` or `admin_payments_ledger_page`) with DI Firestore + contract tests. Device lab remains parallel/deferred. Cloud Wave 0 stays owner-gated.
