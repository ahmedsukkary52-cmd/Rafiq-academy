# BASMA D4 — Security & Authorization Audit

**Phase:** D4 (bounded AuthZ re-verification after D3)  
**Date:** 2026-11-20  
**Branch:** `unify/basma-v1`  
**HEAD:** `8ce64fe97440c33acefaf1e140022ddbe0075ab5` (unchanged; no commit/push)  
**Emulator project:** `demo-rafiq-rules` only  
**Verdict:** **PASS WITH GAPS**

---

## 0. Naming note (owner / ChatGPT)

| Name | What it actually is |
|------|---------------------|
| `BASMA_D4_CLOSEOUT.md` | **Different** Batch D4 — Performance / lazy-list UI polish (2026-11-18) |
| **Security Closure Campaign** | Already closed 2026-11-20 in `BASMA_SECURITY_AND_CODE_REVIEW_DEEP_ASSESSMENT.md` §C1–C7 (**PASS WITH GAPS**) |
| **This document** | ChatGPT-sequenced “D4 Security & Authorization” — **re-verify + matrix**, not a restart of Security Closure |

D4 here **reuses** Security Closure / D0 / PH01 / chat AuthZ evidence and **re-runs** key Emulator suites on the current dirty tree. It does **not** reopen Cloud deploy, IAM, or Blaze.

---

## 1. Initial repository state

| Check | Result |
|-------|--------|
| Branch | `unify/basma-v1` |
| HEAD | `8ce64fe` |
| Working tree | Dirty (~321 short-status lines); D3 + prior owner/agent work preserved |
| Git mutations | None (no reset/clean/stash/checkout/rebase/merge/commit/push) |
| Production / deploy | **Not touched** |

---

## 2. Existing security reports reused

| Document | Reuse |
|----------|--------|
| `BASMA_SECURITY_AND_CODE_REVIEW_DEEP_ASSESSMENT.md` (Security Closure §C) | Callable AuthZ, OSV, dependency hygiene — **not re-opened** |
| `BASMA_D0_SECURITY_TEST_MATRIX.md` | Role isolation matrix baseline |
| `BASMA_SECURITY_AUDIT.md` / EQ-T1 security tooling | Standing gaps |
| `BASMA_CHAT_SYSTEM_AUDIT.md` | Chat + attachment lifecycle Emulator evidence |
| `BASMA_D2_FIREBASE_EFFICIENCY.md` / `BASMA_D3_CODE_QUALITY.md` | Adjacent context only |
| `BASMA_D4_CLOSEOUT.md` | **Not** security — performance batch |

---

## 3. Resources and authorization paths inspected

| Layer | Paths / focus |
|-------|----------------|
| Firestore Rules | `users`, `userPrivate`, `studentProfiles`, `parentProfiles`, `payments`, `paymentAccess`, `attendanceRecords`, `recitationRecords`, `conversations`/`messages`, `halaqaMeetingLinks`, `notifications`, homework rewards |
| Storage Rules | `payment_proofs/**`, `chat_media` / `chat_voice` / `chat_attachments`, profile/content/posts; default deny |
| Cloud Functions | Priority callables (`ensureAdminGroupConversation`, `materializeSession`, `adminEndHalaqaCover`); WA-11 chat AuthZ graph; Security Closure classification of high-risk wrappers |
| Identity | Role from `users/{uid}.role` + `hasActiveProfile` / `passwordChangeRequired`; client cannot change `role` (`roleUnchanged` + field deny-list) |
| Flutter | Not treated as enforcement — UI filters are not AuthZ |

---

## 4. Role authorization matrix (evidence-based)

Legend — **Enforcement:** R = Firestore/Storage Rules · F = Cloud Function · UI = Flutter only (insufficient alone).

| Resource | Op | Student | Parent | Teacher | Supervisor | Admin | Condition / notes | Layer | Suite |
|----------|-----|---------|--------|---------|------------|-------|-------------------|-------|-------|
| `users` list (directory scan) | list | DENY* | DENY* | ALLOW staff scoped | ALLOW staff | ALLOW | *Non-staff may only list `role==admin` cards; no broad user dump | R | D0 isolation |
| `users/{id}` get | get | Self / active peer (no exposed phone) | Same | Same | Same | ALLOW | Self readable when deactivated | R | D0 / PH01 |
| `users` role / isActive | update | DENY escalate | DENY | DENY | DENY | Limited; role unchanged; status via callables | R+F | PH01 + rules L259–280 |
| `userPrivate/{id}` | get | Self or DENY | Self or DENY | — | — | ALLOW get; **list DENY** | Server-written email | R | D0 |
| `studentProfiles` | list | DENY | DENY | DENY | DENY | ALLOW | Get by id + roster/assignment | R | D0 |
| `studentProfiles` foreign halaqa | get | DENY | DENY (unless linked) | DENY | DENY (unless supervised) | ALLOW | Roster / parent link / supervisor-of-student | R | D0 |
| `parentProfiles` other | get | DENY | DENY | — | — | ALLOW | Self or admin | R | D0 |
| `payments` | read | DENY | Own `parentId` | DENY | Supervised student | ALLOW | Client write **false** | R+F | D0 |
| `payments` | write | DENY | DENY | DENY | DENY | DENY (client) | `submit`/`review` callables | F | D0 + billing suites |
| Payment proof Storage | create/read | DENY | Own path create; other DENY | DENY | (policy via rules) | read ALLOW; mutate DENY | Path `payment_proofs/{parentId}/…` | R | D0 storage |
| Attendance | write | DENY | DENY | DENY client | DENY client | DENY client | `recordSessionAttendance` CF | F+R | PH02 / wave-a |
| Recitation / eval | write | Pending submit (constrained) | DENY | Review pending in halaqa | — | — | Live eval via callable | R+F | PH01 / PH02 |
| Conversations / messages | read | Participant | Participant | Participant | Participant | Monitor ALLOW | Messages client write **false** | R+F | WA-11 + chat |
| Chat start (direct) | create | Graph-scoped | Graph-scoped | Graph-scoped | Graph-scoped | Admin paths | `createDirectConversation` | F | WA-11 **17/17** |
| Chat attachments | R/W | Member | Member | Member | Member | Admin | Storage membership + size/type | R | Chat attachment lifecycle (prior) |
| `halaqaMeetingLinks` | get | Roster student | — | Assigned teacher | Of halaqa | ALLOW | Client CUD **false** | R+F | b14 / meeting-link |
| Meeting link set | callable | DENY | DENY | DENY | Scoped | Scoped | `setHalaqaMeetingLink` | F | meeting-link emulator |
| Notifications | read | Audience match | Audience | Audience | Audience | ALLOW | Create admin-bounded | R | PH01 |
| Admin provisioning | callable | DENY | DENY | DENY | DENY | ALLOW | `requireAdmin` / role load | F | Security Closure + high-risk |
| Admin group chat ensure | callable | DENY | DENY | DENY | DENY | ALLOW | Rejects spoofed membership | F | Priority AuthZ **2/2** |
| Session materialize | callable | DENY | DENY | Assigned / cover | — | ALLOW | Scope assert | F | Priority AuthZ |

\*UI-only visibility is never accepted as the sole control.

---

## 5. Firestore Rules findings

| Class | Finding | Disposition |
|-------|---------|-------------|
| — | No **new** Critical/High Rules defect confirmed on current tree | — |
| Informational | Active callers can `get` other `users` docs (rules cannot field-mask); phone/email hygiene via `hasExposedPhone` / `userPrivate` | Known; documented in rules comments |
| Cloud gap | Trial live previously allowed parent→admin `userPrivate` while **repo emulator DENY** — cloud Rules drift until deploy | **Owner / Cloud** (not local fix) |
| Positive | Payments / messages / meeting links / roster / role fields fail closed for clients | Re-verified via D0 + PH01 |

---

## 6. Storage Rules findings

| Class | Finding | Disposition |
|-------|---------|-------------|
| — | Payment-proof isolation re-verified **4/4** | PASS |
| — | Chat paths membership-gated; default `/{allPaths=**}` deny | Prior + rules inspection |
| — | Full attachment lifecycle not re-run this pass (no new evidence); reuse Chat audit **6/6** | Documented reuse |

---

## 7. Cloud Functions authorization findings

| Class | Finding | Disposition |
|-------|---------|-------------|
| — | Priority callables AuthZ still hold (`ensureAdminGroupConversation`, `materializeSession`) **2/2** | PASS |
| — | WA-11 chat relationship graph **17/17** unit | PASS |
| — | Security Closure already fixed `reactToChatMessage` deactivated AuthZ; classified HTTP wrappers | Not reopened |
| Gap | Not every exported callable has a dedicated HTTP negative in this D4 pass | **PASS WITH GAPS** — covered by Closure classification + Core tests |
| Gap | Live Cloud Functions deploy / AuthZ on `rafiq-academy` | **NOT VERIFIED** |

---

## 8. Authentication and identity findings

| Check | Result |
|-------|--------|
| Role source | Firestore `users.role` + active profile; not client-trusted claims for privilege |
| Self role escalation | Blocked (`roleUnchanged` + deny-list including `role`, `isActive`, `passwordChangeRequired`, …) |
| Provisioning | Callables only (`adminProvisionUser`, onboard, …) — client `users` create **false** |
| Deactivated | `hasActiveProfile` strips role powers; self get retained for disabled messaging |
| First login | `passwordChangeRequired` gates role helpers until complete |

---

## 9. Cross-role isolation results (this pass)

| Scenario | Expected | Actual | Layer | Evidence |
|----------|----------|--------|-------|----------|
| Student list all users | DENY | DENY | Rules | D0 **PASS** |
| Student other-family payment | DENY | DENY | Rules | D0 **PASS** |
| Parent admin `userPrivate` | DENY (repo) | DENY | Rules | D0 **PASS** |
| Teacher foreign student profile | DENY | DENY | Rules | D0 **PASS** |
| Teacher update payment | DENY | DENY | Rules | D0 **PASS** |
| Supervisor write payment | DENY | DENY | Rules | D0 **PASS** |
| Non-admin `ensureAdminGroupConversation` | DENY | DENY | Functions | Priority **PASS** |
| Spoofed admin group membership fields | Reject | Reject | Functions | Priority **PASS** |
| Out-of-scope `materializeSession` | DENY | DENY | Functions | Priority **PASS** |
| Chat without relationship graph | DENY | DENY | Functions (unit) | WA-11 **PASS** |
| Other parent payment proof | DENY | DENY | Storage | D0 storage **PASS** |

---

## 10. Sensitive data exposure findings

| Item | Class | Notes |
|------|-------|-------|
| `userPrivate` list | Controlled | Nobody lists; get self/admin |
| Callable error surfaces | Hardened in prior phases | Arabic / generic; D3 SnackBar sanitize helps clients |
| Debug logs | Residual `debugPrint` gated in D3 for callables / student pages | No secret values printed here |
| Rules comment: peer `users` email visibility | Informational | Until email fully leaves public user doc |

**No secret values or private PII printed in this report.**

---

## 11. Confirmed vulnerabilities (this D4 pass)

| Severity | Item | Status |
|----------|------|--------|
| Critical | None **new** on Emulator repo rules/functions | — |
| High | None **new** | — |
| Medium | Deactivated accounts retained `notifications` audience read/`readBy` (`isNotificationAudience` used `signedIn` only) | **Fixed** (Rules) |
| Medium | `studentSearch` readable by deactivated staff still in `visibleTo` | **Fixed** (Rules) |
| Medium | Self-update on `users` / profiles omitted `hasActiveProfile`; `pendingHalaqaAssignment` forgeable; `adminCreateHalaqa` could reactivate `staffStatus=deactivated` | **Fixed** (Rules + Functions) |
| Medium | Cloud Rules/Functions may lag repo (historical Trial drift) | **Open — Owner/Cloud** |
| Low / Info | Peer-readable `users` fields; incomplete HTTP-negative coverage for every callable | Documented |
| Informational | Naming collision with Performance D4 closeout | Clarified in §0 |

Evidence source for the three local Mediums: [D4 AuthZ matrix evidence](c4096e90-b92b-4552-82ae-3b1c8bff487f).

---

## 12. Fixes implemented

| Fix | File |
|-----|------|
| `isNotificationAudience` requires `hasActiveProfile()` | `firestore.rules` |
| `studentSearch` non-admin reads require `hasActiveProfile()` | `firestore.rules` |
| Self `users` update requires active profile + expanded server-field denylist | `firestore.rules` |
| Self `parentProfiles` / `teacherProfiles` update requires active profile | `firestore.rules` |
| Parent `payments` read requires active profile | `firestore.rules` |
| `adminCreateHalaqa` rejects `staffStatus` deactivated/archived/deleted | `functions/src/halaqa/halaqaScheduleFunctions.ts` |
| D4 deactivation regression tests | `rules_test/deactivated_access.firestore.rules.test.mjs` |
| Deactivated+pending teacher create denial | `functions/test/high_impact_halaqa_creation_wrapper.emulator.test.mjs` |

No Rules/Functions weakening. No schema or role-policy product changes.

---

## 13. Exact regression tests and results

| Command | Emulator | Pass | Fail | Verifies |
|---------|----------|------|------|----------|
| `npx firebase emulators:exec --project demo-rafiq-rules --only firestore "npm --prefix rules_test run test:d0:isolation"` | Yes | **18** | 0 | Cross-role Firestore isolation |
| `npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage "npm --prefix rules_test run test:d0:storage"` | Yes | **4** | 0 | Payment-proof Storage AuthZ |
| `npx firebase emulators:exec --project demo-rafiq-rules --only firestore "npm --prefix rules_test run test:ph01"` | Yes | **57** | 0 | PH01 AuthZ / economy / privacy |
| `npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore,functions "node --test --test-concurrency=1 functions/test/priority_callable_authz.emulator.test.mjs"` | Yes | **2** | 0 | Admin group + materialize HTTP AuthZ |
| `node --test functions/test/wa11_chat_authorization.test.mjs` | No (unit) | **17** | 0 | Chat relationship graph |
| `npm --prefix functions run test:wave-a` (incidental full wave) | No | **651** | 0 (1 skip) | Broad Functions contracts |
| High-risk wrappers suite (`auth,firestore,storage,functions`) | Yes | **4** | 0 | `adminEndHalaqaCover` + sensitive wrappers |
| Chat attachment lifecycle | Reused prior | **6/6** | 0 | Not re-run (no new evidence) |
| `npm --prefix rules_test run test:deactivated` (Firestore) | Yes | **19** | 0 | Includes 4 new D4 deactivation-boundary tests |
| `high_impact_halaqa_creation_wrapper.emulator.test.mjs` | Yes | **2** | 0 | Includes deactivated+pending refusal |

---

## 14. Unverified areas and tooling limitations

- Production / Trial **live** Rules & Functions AuthZ (**Cloud NOT VERIFIED**).
- Full Storage + Functions combined matrix for every path.
- Exhaustive HTTP negative for all ~50+ callables in one D4 pass.
- Emulator hub port contention when suites overlap (`Could not start emulator hub`).
- Firebase tools update-check noise / first D0 attempt exit 2 (retry succeeded).
- Custom claims (not used as privilege SSOT in this architecture).

---

## 15. Owner decisions required

1. Deploy repo Firestore + Storage Rules to cloud when ready (closes Trial drift class).
2. Deploy Functions with production gate still fail-closed until intentionally opened.
3. Firebase ownership / billing / Blaze strategy (G0) — out of D4.
4. Whether peer-visible fields on `users` need further migration into `userPrivate`.

---

## 16. Deferred work

- Full HTTP AuthZ expansion for remaining thin wrappers (low marginal value after Closure).
- Re-run chat attachment lifecycle without new evidence (policy: reuse).
- OSV transitive bumps (axios quarantined path) — owner approval.
- Performance Batch D4 device icon/splash (unrelated RB-D4-*).

---

## 17. Final verdict

# PASS WITH GAPS

Important role/resource paths were inspected and re-tested on `demo-rafiq-rules`. Three Medium deactivation-boundary Rules/Functions defects from the evidence scan were **fixed** with regressions. No Critical/High remains open locally. Remaining gaps are **Cloud deploy verification**, incomplete callable HTTP coverage, and owner product/cloud decisions. No Production or Cloud mutations occurred.

**Stop after D4.** Do not auto-start another audit phase.
