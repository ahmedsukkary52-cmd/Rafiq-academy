# BASMA Security Audit (Stage A)

**Date:** 2026-11-16  
**Reconciles:** [AUTH_SECURITY_AUDIT.md](../production/AUTH_SECURITY_AUDIT.md), [BASMA_MASTER_ISSUE_REGISTER.md](../../BASMA_MASTER_ISSUE_REGISTER.md), Trial REST/device evidence.  
**No Rules/Functions deploy. No cloud mutations in this stage.**

---

## 1. Verified facts

### 1.1 Repo rules model (source)

- [firestore.rules](../../firestore.rules): role helpers (`isAdmin`, `isTeacher`, …), membership/halaqa scoping, server-owned writes denied for roster/payments/attendance/evaluations/etc.
- [storage.rules](../../storage.rules): path/content-type oriented (emulator-tested per register).
- Emulator suites recorded in Master Register: Firestore 276/0, Storage 67/0, multiple callable/trigger suites — **emulator project `demo-rafiq-rules` only**.

**Taxonomy:** BASMA-001/002 = **Existing Known Issue — TESTED on emulator**; **Blocked Verification** for production equivalence until deploy + cloud re-test.

### 1.2 Live cloud `rafiq-academy` vs repo (Trial) — Confirmed Issues

From [ACADEMY_TRIAL_RUNTIME_DIAGNOSIS.md](../../_backups/ACADEMY_TRIAL_RUNTIME_DIAGNOSIS.md) and [ACADEMY_TRIAL_PRESHARE_DECISION.md](../../_backups/ACADEMY_TRIAL_PRESHARE_DECISION.md):

| Observation | Severity | Taxonomy |
|-------------|----------|----------|
| Trial student could read broad student/user listings (25 docs, mostly non-trial) | P0 | **Confirmed Issue** — live rules looser than repo |
| Trial parent could read admin `userPrivate` in REST checks | P0 | **Confirmed Issue** |
| Cross-student payment/profile reads succeeded unexpectedly vs repo intent | P0 | **Confirmed Issue** |
| `appConfig/clientVersion` PERMISSION_DENIED before login | P2 | Confirmed; non-blocking for home |
| Repo rules **not deployed** to Trial project | P0 gate | **Blocked Verification** of “secure prod” until owner approves deploy |

**Impact:** Academy trial accounts on shared live project can see non-trial academy data. This is a **release/security** finding, not a Flutter bug.

### 1.3 AuthZ architecture

- Sensitive writes intended via Cloud Functions + Admin SDK; client direct writes constrained by rules (register documents map).
- Live Trial: **zero Functions deployed** → callables HTTP 404; write workflows fail closed (good for integrity) but product incomplete.
- `PRODUCTION_BACKEND_ENABLED` gate exists in Functions (`productionGate`) — even after Blaze deploy, production enablement is a separate switch (**Existing Known** BASMA-005/014 class).

### 1.4 Client auth

- Email/password; inactive user messaging present (historical AUTH audit).
- Self-registration public UI removed (route redirects) — progress vs AUD-005.
- Role routing is client GoRouter — **not** a security boundary (AUD-036 class) — **Existing Known**.

### 1.5 Repo-rules Potential Risks (not Trial)

- Any active profile may **get** another `users` doc without exposed phone — email on `users` may be visible cross-member (**Potential Risk** in repo rules text).
- Admin client still allowed bounded writes on `pricingRules` / selected `academySettings` fields (**Confirmed** in rules; intentional product surface — verify allow-list stays tight).
- Storage: catch-all is deny; payment-proof delete remains false (likely intentional retention).

### 1.6 Secrets / logging

- Trial credentials live only under gitignored `_backups/ACADEMY_TRIAL_CREDENTIALS.txt` (Verified path policy).
- Grep this pass: ~24 `print`/`debugPrint` hits under `lib/` — **Potential Risk** of PII in debug builds; production obfuscation not verified.
- Callable emulator path uses Bearer token in headers but `debugPrint` logs URL/name/error, not the token string (spot check) — **no Confirmed token leak** in that file.
- No private key files opened in audit; Firebase options / google-services are expected client configs.

---

## 2. Measured results

- Emulator suite pass counts: as recorded in Master Issue Register (not re-executed this Stage A write pass).
- Live REST unauthorized-scope reads: documented in Trial backups (Confirmed).
- Functions list on `rafiq-academy`: empty (Cloud status update).

---

## 3. Inferred risks

- IDOR-style access on live project until rules deploy.
- Debug APK Trial shared externally increases exposure window (credentials + loose rules).
- Storage catch-all / undeleted proofs cost & retention — historical scalability notes.

---

## 4. Recommendations (Stage D / owner gates)

1. **P0 — Owner approval:** Deploy repo Firestore + Storage rules (+ indexes) to the intended Firebase project after diff review; immediately re-run denial tests with trial tokens.
2. **P0 — Owner approval:** Blaze + Functions deploy + `PRODUCTION_BACKEND_ENABLED` only with billing acceptance.
3. **P1:** Redact logging; forbid secrets in tracked files; rotate trial passwords if shared broadly.
4. **P1:** Security regression tests for the exact Trial over-read cases (student list, userPrivate, cross-student).

---

## 5. Unresolved questions

- Exact live ruleset text on `rafiq-academy` console (not exported this pass) — Blocked Verification without console dump.
- Whether Paymob quarantine remains complete on all branches — cite AUTH_CHAT / billing docs.
