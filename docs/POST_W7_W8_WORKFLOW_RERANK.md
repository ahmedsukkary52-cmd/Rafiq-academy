# Post-W7 · W8 Candidate Re-rank (Workflow Criteria Only)

**Date:** 2026-07-30  
**Scope:** Re-rank remaining candidates using the **same workflow criteria as W1–W7**.  
**Method:** Read-only. **No Phase 0. No code. No commits. No pushes.**  
**Predecessor:** `docs/POST_W7_PRODUCT_AUDIT.md` (messaging recommendation withdrawn under this bar)

### Workflow criteria (W1–W7 bar)

A candidate qualifies as the next **Wn** only if it is:

| Criterion                      | Meaning                                                                               |
|--------------------------------|---------------------------------------------------------------------------------------|
| **Complete academy operation** | Closes a real operational ritual (who does what → what fact is written → who sees it) |
| **Clear business owner**       | One role owns the write path; observers project                                       |
| **Single SSOT**                | One collection / policy owns the truth; no parallel status                            |
| **Reusable architecture**      | Extends W1–W7 facts/ports rather than inventing a side system                         |
| **Long-term product value**    | Remains valuable after the operated day is already closed                             |

### Explicitly excluded from this ranking

| Excluded                                                                            | Why                                                    |
|-------------------------------------------------------------------------------------|--------------------------------------------------------|
| Platform Epic **P-E1** (logout / identity reset)                                    | Trust platform, not a business ritual                  |
| Category B (rules, Storage, CI, B-R8, audio uploads gate)                           | Release / infra                                        |
| Messaging / chat surfaces                                                           | Communication **capability** (see §1)                  |
| Technical cleanups (`AssignmentPolicy`, day-normalize migrations, legacy composers) | Unless they are *inside* a larger operational workflow |
| Dashboards / polish that only re-present W1–W2 facts                                | Capability, not a new operation                        |

---

## 1. Why messaging is **not** W8

**Prior suggestion (Post-W7 audit):** Parent ↔ Supervisor Operational Messaging.

| Workflow criterion         | Messaging result                                                                                                                        |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Complete academy operation | **Fail** — moves talk, not an academy fact. No “operation completed” state beyond message delivery                                      |
| Clear business owner       | Ambiguous — conversation is bilateral; no single operational owner of an academy decision                                               |
| Single SSOT                | **Fail as workflow SSOT** — chat threads are not presence, homework, membership, or request truth; at best they *reference* those facts |
| Reusable architecture      | Reuses chat stack, but that stack is a **channel**, like notifications delivery — closer to W4/W5 *how* than to W1/W2/W7 *what*         |
| Long-term product value    | High as capability; **wrong shape** for Wn Phase 0                                                                                      |

**Classification:** Communication / delivery **capability** (same family as inbox fan-out), not a
W1–W7-style business workflow.

W4/W5 proved the right pattern for awareness: **domain fact → projection**. Messaging does not
produce a new domain fact class for academy operations. Parent chat UI may still ship later as a *
*platform or Category A capability** alongside a real Wn — it should not *be* Wn.

---

## 2. Comparison of remaining true-workflow candidates

| Candidate                                                                                  | Complete operation?                                            | Clear owner?                                         | Single SSOT?                                                                                          | Reuse W1–W7?                                              | Long-term value                                  | Backend ready?                                                                     | Verdict                                            |
|--------------------------------------------------------------------------------------------|----------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|--------------------------------------------------|------------------------------------------------------------------------------------|----------------------------------------------------|
| **Student onboarding / halaqa membership** (pending → approve/activate → roster + profile) | **Yes** — who may study where is unfinished                    | Admin / supervisor (product must pick primary owner) | **Yes shape** — `users.isActive`, `halaqat.studentIds`, `studentProfiles.halaqaId` (today fragmented) | High — roster feeds W1–W3 readiness, attendance, homework | **High** — every later ritual assumes membership | Partial — admin approve exists, UI Coming Soon; supervisor link is thin/incomplete | **Best W8**                                        |
| **Awards / encouragement coherence**                                                       | Thin — grant exists; types/schema/parent visibility incomplete | Teacher (+ supervisor issue path)                    | `achievements` collection, but **dual write schemas**                                                 | Medium                                                    | Medium (motivation)                              | Mostly ready                                                                       | Coherence / polish-heavy; weak as next *operation* |
| **Payments / fees lifecycle**                                                              | **Yes** commercially                                           | Parent pay + admin reconcile                         | `payments` collection                                                                                 | Low–medium                                                | High business                                    | **No** — initiate unavailable / CF commented                                       | True workflow, **blocked**                         |
| **استئذان outcome inbox events (D-W7-6 A)**                                                | No — extends W7 delivery                                       | N/A                                                  | Would project existing request docs                                                                   | High                                                      | Medium                                           | Ready for thin events                                                              | **Category A companion**, not Wn                   |
| **Content library as ops** (publish → consume)                                             | Capability loop                                                | Teacher publish                                      | Content docs + Storage                                                                                | Low                                                       | Medium                                           | Partial; Storage-adjacent                                                          | Capability / polish                                |
| **Academy calendar / term events**                                                         | Thin CRUD                                                      | Unclear vs schedule SSOT                             | `calendarEvents`                                                                                      | Low (W3 already uses `halaqat.schedule`)                  | Low–medium                                       | Ready but orphan                                                                   | Capability                                         |
| **Progress / analytics depth**                                                             | No new ritual                                                  | N/A                                                  | Reads W1/W2                                                                                           | High                                                      | Medium                                           | Ready                                                                              | Dashboard polish                                   |
| **Makeup / catch-up after absence**                                                        | Would be a real ritual                                         | Teacher                                              | Would need careful join to attendance + homework                                                      | High *if* designed                                        | High                                             | **No seed** — invents ownership                                                    | Premature; risk of second SSOT next to W2/W7       |
| **Student audio submit**                                                                   | Capability unlock                                              | Student                                              | Existing homework/recitation path                                                                     | High                                                      | High when unblocked                              | **Blocked (B)**                                                                    | Infra-gated capability                             |

---

## 3. Recommended next true academy workflow (W8)

### W8 — Student Onboarding / Halaqa Membership Lifecycle

**One sentence:** Take a student from “not yet a member of an operated halaqa” to “active roster
member whose profile and halaqa membership agree,” with one owned approve/link path and no parallel
membership truths.

**Why this clears the W1–W7 bar:**

1. **Complete academy operation.** Membership is the precondition every W1–W7 ritual assumes. Today
   admin `approveNewStudent` can activate + attach, but the admin surface is Coming Soon; supervisor
   “register” only partially mutates roster/profile. The operation is half-built, not imaginary.
2. **Clear business owner.** Product can lock a single writer (recommended direction: **admin owns
   activate/approve**; supervisor may *request* or *link* only under that policy — exact split is
   Phase 0). Observers (teacher roster, parent children link) project.
3. **Single SSOT.** The truth is already intended to live in user activation +
   `halaqat.studentIds` + `studentProfiles.halaqaId`. W8’s job is to make that one coherent write
   path — not invent a second membership collection.
4. **Reusable architecture.** Correct membership is what W3 readiness, W2 registers, W1 assignments,
   and W7 child authorization ultimately depend on. Fixes upstream of operated day.
5. **Long-term product value.** An academy that can teach, mark, excuse, and oversee still fails if
   “who belongs in which halaqa” is manual, inconsistent, or UI-orphaned.

**Why not awards as W8:** Encouragement already has grant paths; the pain is schema/terminology
coherence and missing parent projection — valuable Category A / polish, weaker as the next
*operation*.  
**Why not payments as W8:** True workflow, Category-B-blocked.  
**Why not makeup as W8:** No product seed; high risk of inventing recovery SSOT beside attendance +
استئذان.

**Explicitly still not W8:** messaging, P-E1, rules/CI/Storage, AssignmentPolicy-only cleanups,
admin “console” as a bag of screens without a membership ritual.

---

## 4. Stop gate

Await approval that:

1. Messaging is classified as a **capability**, not W8.
2. **W8 = Student Onboarding / Halaqa Membership Lifecycle** (or an explicit alternate that still
   meets the workflow bar).
3. Phase 0 may start only after that approval.

**No Phase 0. No code. No commits. No pushes.**
