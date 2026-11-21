# BASMA Remediation Plan (Stage C)

**Date:** 2026-11-16  
**Status:** PLAN ONLY — **no Stage D execution** until owner approval.  
**Supersedes narrative for next engineering waves** while preserving R1 history in [BASMA_MASTER_REMEDIATION_PLAN.md](../../BASMA_MASTER_REMEDIATION_PLAN.md).

---

## 1. Ordering principles

Prioritize by: (1) security/data integrity, (2) incorrect business logic, (3) Firebase cost/correctness, (4) measured performance, (5) architecture/duplication, (6) design system / icon-splash-responsive, (7) polish.  
Not by raw finding count. Respect dependencies and external gates (Blaze, Rules deploy, product locks).

---

## 2. External gates (owner)

| Gate | Blocks | Approval needed |
|------|--------|-----------------|
| G1 Deploy Firestore/Storage Rules to target project | Live over-read (BASMA-100) | Explicit |
| G2 Deploy Indexes | Admin complaints/finance, cover, absence | Explicit |
| G3 Enable Blaze / billing | Functions artifact registry | Explicit financial |
| G4 Deploy Functions + set `PRODUCTION_BACKEND_ENABLED` | All callable workflows | Explicit |
| G5 Prod Firebase project config | `prod` flavor | Explicit (BASMA-014) |

---

## 3. Proposed Stage D batches (for later approval)

### Batch D0 — Verification harness (local only)

- Re-run selected emulator security denial tests mirroring Trial over-reads.
- Add failing tests for chat growing-limit vs cursor (red then green in D2).
- **Effort:** S–M · **Risk:** Low · **No cloud**

### Batch D1 — Security alignment (depends G1)

- Deploy reviewed rules/indexes to agreed project (staging/trial).
- Re-test Trial over-read matrix → must deny.
- Logging redaction PRs.
- **Effort:** M · **Risk:** High if wrong rules — require diff review

### Batch D2 — Firebase efficiency (code)

- Chat: true older-page cursor; keep small realtime window (BASMA-103).
- Force `pageSize` on all `watchConversations` / ban `watchAllConversations` without limit (BASMA-104).
- Bound teacher `getHalaqaRecitationRecords`; fix admin registration scan; bound supervisor payment N+1 (BASMA-107).
- Confirm payments list pagination + safe aggregates post-G2.
- **Effort:** M–L · **Risk:** Medium (chat + roster UX)

### Batch D3 — Backend enablement (depends G3+G4)

- Deploy Functions; enable production gate only after B-BILLING checklist.
- E2E attendance, chat send, homework complete, parent schedule on emulator then trial.
- **Effort:** L · **Risk:** High operational

### Batch D4 — Performance / UI polish

- Hot ListView.builder conversions with evidence.
- Icon/splash/responsive QA matrix + overflow goldens.
- Motion tokens optional P3.
- **Effort:** M–L · **Risk:** Low–Medium visual

### Batch D5 — Design system / L10n / Dark

- **Deferred** unless owner reopens product lock.

---

## 4. Effort bands

- S ≤ 1 day · M 2–5 days · L > 1 week (one senior engineer, excluding approval wait)

---

## 5. Explicit non-goals until approved

- No Quran/Mushaf changes.
- No Paymob reactivation.
- No destructive git / worktree merges without inventory review.
- No client write bypass of callables.

---

## 6. Success criteria for a future Stage D exit

- Live rules match repo intent on denial tests (Measured).
- Callables available on intended project (Measured).
- Chat older load does not re-download full window (Measured reads).
- Performance claims backed by profile mode or device traces.
- Master Issue Register updated to VERIFIED with evidence links.
