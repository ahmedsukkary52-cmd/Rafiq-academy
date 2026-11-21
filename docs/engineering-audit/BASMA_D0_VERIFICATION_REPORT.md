# BASMA D0 Verification Report

**Date:** 2026-11-16  
**Status: PASS WITH GAPS**  
**Scope:** Local verification + test harness only. No production behavior fixes. No Cloud deploy/mutate. No Quran/Mushaf access.

---

## 1. Pre-flight

- `git.exe` on this workstation: **Access denied** — branch/HEAD/diff via git CLI unavailable this session.
- Working tree preserved (no reset/clean/stash/checkout/commit/push).
- Relied on known tree `unify/basma-v1` + Stage A–C docs + direct file reads for reconciliation.

---

## 2. Reconciliation of key issues vs current code

| ID | Classification after D0 | Evidence |
|----|-------------------------|----------|
| BASMA-100 | **Confirmed Issue (cloud)**; **Repo rules OK on emulator** | D0 isolation 18/18 DENY/ALLOW as designed; live over-read remains until Rules deploy |
| BASMA-101 | **Existing Known / Blocked Verification (live)** | Not re-probed REST; indexes still unpublished per prior Trial notes |
| BASMA-102 | **Existing Known / Blocked** | No Functions deploy attempted; still blocked on Blaze |
| BASMA-103 | **Confirmed Issue (code)** | Unit test proves load-older → watchLimits `[30,60]`; D2 contract skipped |
| BASMA-104 | **Confirmed / Potential** (call-site dependent) | Code still allows null limit; Admin UI uses pageSize |
| BASMA-107 | **Confirmed Issue (code-read)** | Query matrix unchanged structurally |
| BASMA-108 | **Confirmed Issue (code-read)** | Layer skips not “fixed” in D0 (by design) |

No severity downgrade without evidence. BASMA-100 split clarified: **emulator PASS ≠ cloud PASS**.

---

## 3. What was implemented

| Deliverable | Path |
|-------------|------|
| Firestore isolation suite | `rules_test/d0_trial_isolation.firestore.rules.test.mjs` (18 tests) |
| Storage proof suite | `rules_test/d0_payment_proof.storage.rules.test.mjs` (4 tests) |
| npm scripts + aggregate wiring | `rules_test/package.json` |
| Chat BASMA-103 characterization + skip contract | `test/features/chat/chat_room_bloc_test.dart` (+3 tests, 1 skipped) |
| Docs | `BASMA_D0_*` under `docs/engineering-audit/` |

**Production chat/pagination behavior intentionally unchanged.**

---

## 4. Test results (commands + outcomes)

See [BASMA_D0_TEST_SUITE_INTEGRITY.md](BASMA_D0_TEST_SUITE_INTEGRITY.md) and [BASMA_D0_SECURITY_TEST_MATRIX.md](BASMA_D0_SECURITY_TEST_MATRIX.md).

Summary:

- Rules Firestore D0: **18/18 PASS**
- Rules Storage D0: **4/4 PASS**
- Chat bloc: **17 PASS + 1 SKIP**
- Analyze (chat bloc files): **No issues found**

---

## 5. Additional reliability gaps (documented only)

### Interaction reliability

- Chat send uses `sequential()` / outbox retry — covered by existing bloc tests.
- Broader dirty-state / double-submit across admin forms: **Not Tested** in D0 (inventory for later UX pass).

### Application lifecycle

- Resume / process death / splash restore: **Not Tested** (needs device lab — Stage D4).

### Performance evidence plan (for D4)

Profile mode on low/mid devices: build & raster ms, jank, memory, scroll, image decode, rebuild counts around `AppFloatingBottomNav` blur. No profile numbers claimed in D0.

---

## 6. Remaining issue buckets

| Bucket | Items |
|--------|-------|
| Release blockers | BASMA-100 live rules gap; BASMA-101 indexes; loose live data visibility for trial accounts |
| Backend enablement | BASMA-102 Blaze + Functions + `PRODUCTION_BACKEND_ENABLED` |
| Firebase efficiency | BASMA-103/104/107 |
| Performance & UX | BASMA-106; no profile metrics |
| Architecture | BASMA-108 |
| Deferred / owner | L10n/Dark (BASMA-109); prod project (BASMA-014); billing (BASMA-016) |

---

## 7. Recommendation

**Do not start D2 code fixes until D0 is accepted.**  
Next owner choice:

1. **D1** — approve Rules (+ Indexes) deploy to agreed project, then re-run denial matrix with live tokens.  
2. **D2** — implement chat cursor pagination (un-skip contract test) + query bounds.  
3. Or both sequenced D1 then D2.

---

## 8. Stop

D0 complete. Awaiting review before D1/D2/D3/D4.
