# BASMA Final Engineering Report (Stage A–C)

**Date:** 2026-11-16  
**Mission:** Principal audit Stages A–C only. **No application code changes. No cloud deploy.**  
**Stop:** Awaiting owner approval for Stage D batches in [BASMA_REMEDIATION_PLAN.md](BASMA_REMEDIATION_PLAN.md).

---

## 1. Executive map — what is trustworthy

| Area | Trust level | Basis |
|------|-------------|-------|
| Flavor routing (dev/staging emulator-only; trial→rafiq-academy) | High | Source + Trial device |
| Emulator rules/callable suites (demo-rafiq-rules) | High for emulator | Master Register |
| Live cloud security ≡ repo rules | **None** | Trial over-reads Confirmed |
| Live cloud Functions workflows | **None** | Empty deploy / 404 |
| Read-only Trial demo UX | Medium | Device evidence; disclose gaps |
| Performance “smooth on all devices” | Unproven | No profile metrics |
| Coverage ≥90% | Unproven | Not measured |

---

## 2. Top Confirmed Issues (analytical priority)

1. **BASMA-100** Live Firestore authorization looser than repo (P0).
2. **BASMA-101** Required indexes not on live project (P0 UX + cost errors).
3. **BASMA-102** Cloud Functions unpublished / Blaze gated (P0 product workflows).
4. **BASMA-103** Chat “load older” grows snapshot limit (P1 efficiency).
5. **BASMA-107** Additional unbounded/N+1 reads (recitation history, registration scan, payment fan-out, conversation listens).
6. **BASMA-108** Presentation→Firestore layer skips (complaints/directory/accounts).
7. Historical open items remain in Master Register (AUD-### reconciliation unfinished for many IDs).

Enrichment sources merged after initial Stage A–C write: [Architecture inventory](a257f375-c599-4d2f-99f1-89561c220b39), [Firebase/Security inventory](05a5586a-e62b-4afb-8ba2-9221951668af), [Perf/UI/Tests inventory](b5e5c629-b260-4a4e-aa60-446cc96934bc).

---

## 3. Deliverables index

| Report | Path |
|--------|------|
| Architecture | [BASMA_ARCHITECTURE_AUDIT.md](BASMA_ARCHITECTURE_AUDIT.md) |
| Firebase efficiency | [BASMA_FIREBASE_EFFICIENCY_AUDIT.md](BASMA_FIREBASE_EFFICIENCY_AUDIT.md) |
| Performance / Icon / Splash | [BASMA_PERFORMANCE_AUDIT.md](BASMA_PERFORMANCE_AUDIT.md) |
| Security | [BASMA_SECURITY_AUDIT.md](BASMA_SECURITY_AUDIT.md) |
| Code quality | [BASMA_CODE_QUALITY_AUDIT.md](BASMA_CODE_QUALITY_AUDIT.md) |
| Test coverage | [BASMA_TEST_COVERAGE_AUDIT.md](BASMA_TEST_COVERAGE_AUDIT.md) |
| Integration | [BASMA_INTEGRATION_AUDIT.md](BASMA_INTEGRATION_AUDIT.md) |
| Remediation | [BASMA_REMEDIATION_PLAN.md](BASMA_REMEDIATION_PLAN.md) |
| Living register | [../../BASMA_MASTER_ISSUE_REGISTER.md](../../BASMA_MASTER_ISSUE_REGISTER.md) |

---

## 4. What we did not do (compliance)

- No Flutter/Functions feature code edits for this audit package.
- No Rules/Indexes/Functions deploy; no Blaze; no billing changes.
- No git mutating operations authorized.
- Quran/Mushaf protected paths not inspected (BASMA-018).
- Dark Mode / Localization not implemented.

---

## 5. Ask to owner (Stage D)

Approve one or more of: **D0** harness, **D1** rules deploy+verify, **D2** Firebase efficiency code, **D3** Functions enablement, **D4** UI performance — per [BASMA_REMEDIATION_PLAN.md](BASMA_REMEDIATION_PLAN.md) §3.

Until then, engineering map above is the source of truth for prioritization.
