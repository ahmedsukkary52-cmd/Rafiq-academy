# Billing & Payment Contract — Monthly Family Bills

**Status:** Batch A (contract + pure calculation). No screens, rules, indexes,
callables or triggers implement this yet. Nothing here is deployed.
**Date:** 2026-10-16
**Related:** `PRODUCT_DECISIONS_LOCKED.md` (D2 + amendment D2-A1, D3, D4, D5,
D6), `SECURITY_DATA_CONTRACT_FREEZE.md` (C3, C4, C10, §4.7).

No real payment destinations, prices or personal data appear in this
document. Amounts below are illustrative minor units.

---

## 1. What is reused (existing, unchanged by Batch A)

| Concept | Where | Notes |
|---|---|---|
| Pricing | `pricingRules` (scope `student` → `halaqa` → `academy_default`), `academySettings/pricingDefaults` | Admin-only. Selection in `functions/src/billing/paymentHelpers.ts`. |
| Per-child invoice | `payments/inv_{studentId}_{yyyy-MM}` | Issued only by `issueInvoiceFromPricing` (`functions/src/admin/adminBilling.ts`); amount snapshot + `pricingRuleId/Version`; idempotent. Clients cannot write `payments`. |
| Proof submission | `submitPaymentProof` callable; Storage `payment_proofs/{parentId}/{paymentId}/{file}` | Server-issued `proofCycleId`, replay-safe, stale/reused images rejected. |
| Review | `reviewPaymentProof` callable | Admin any; Supervisor only for students on a halaqa they supervise (roster SSOT). Only `pending_review` is reviewable; idempotent per request id; one `auditLogs` entry per proof cycle; minor-unit arithmetic. |
| Overdue / access | `processPaymentOverdueGrace` (daily, Cairo time), `paymentAccess/{parentId}` | Stored overdue (D4); grace → suspension (D5). |
| Destinations | `academySettings/paymentPublic` (`vodafoneCashDestination`, `instapayDestination`) | Admin-configured business destinations; never personal contact data. |
| Notifications | `notifications/{id}` with `audience` = uid / role / `all` | Server-written docs; `audience: 'admin'` reaches admins. |

## 2. Locked provisional decisions

Approved 2026-10-16 for implementation; revisit only by explicit decision.

1. **Family bill is the payable unit.** One bill per parent per billing month
   lists every child due that month; one proof and one review settle all of its
   lines together. Per-child invoices remain for history, reporting and the
   overdue job; they are linked to the family bill, never duplicated.
2. **Family discount** is optional, configured by the admin **per parent**:
   either a fixed amount or a percentage off the **family total**, with an
   effective month. It applies only when **two or more** children are due in
   that month, and is snapshotted on the bill at issue time.
3. **Issuing** is an explicit, idempotent admin action ("issue bills for month
   X", server-side). A scheduled job may be added later and must call the same
   issuer.
4. **Verification scope for family bills:** a supervisor may verify only if
   they supervise **every** child on the bill; otherwise only the admin.
5. **Due date:** last day of the billing month (Cairo), then a **7-day grace
   period** (existing `pricingDefaults.gracePeriodDays` default).
   *Clarification 2026-10-17:* the bill becomes `overdue` on the due date. The
   grace period governs only the access stages (warning → grace →
   suspension), not the overdue status (§6; §11.8 item 6, rule 13).
6. **New students** start billing from the **month after** they become
   billable; there is no proration.
7. **Issued bills are immutable.** Amounts, lines and discount are never edited
   in place. Corrections use an audited **cancel-and-reissue** flow (later
   batch): the old bill becomes `cancelled` with a reason; a new bill is issued.
8. **Family bills support full verification or rejection only** — no partial
   payments. Partial review stays available for legacy single-child invoices.
9. **Percentage discounts round down** to the piaster.
10. **InstaPay destination type is admin-configurable**: mobile number,
    InstaPay address, or HTTPS link, each validated for the selected type.
11. **Payment rails:** Vodafone Cash or InstaPay (amendment D2-A1). No Paymob,
    no in-app wallet, no proof submission by phone/WhatsApp.

## 3. Money

- Persisted new amounts are **integer minor units** (`*Minor`, piasters,
  currency `EGP`). No floating-point arithmetic in the calculation.
- Existing `payments.amount` (decimal pounds) is unchanged; the review callable
  already converts it to minor units exactly. New per-child fields are added
  alongside it, never replacing it.
- Percentages are **basis points** (1 bp = 0.01 %, 1–10000).

## 4. Authoritative calculation

`functions/src/billing/familyBillCalculation.ts` → `calculateFamilyBill`. Pure,
no Firebase imports; the issuer (later batch) is its only production caller.
Flutter never recomputes totals; it displays the stored snapshot.

Input: children `{ studentId, due, feeMinor | null }`, optional discount rule.

| Rule | Behaviour |
|---|---|
| Child not due | Excluded from lines; listed in `excludedStudentIds`. |
| Due child, fee missing / ≤ 0 / non-integer | Whole bill fails `fee_not_configured` with those ids. Never billed at zero. |
| Nobody due | Fails `no_children_due`. |
| Duplicate studentId | Fails `invalid_input` (no double billing). |
| Invalid discount rule | Fails `invalid_discount` (never silently ignored). |
| Fewer than 2 due | No discount; `appliedDiscount = null`. |
| Fixed discount | `min(value, subtotal)`. |
| Percentage | `floor(subtotal × bp / 10000)`, capped at subtotal. |
| Allocation | Proportional to fees, floor + largest remainder (ties by input order). Line discount ≤ line fee. |
| Invariant | `Σ line.amountMinor == totalMinor == subtotalMinor − discountMinor`; violation throws. |

## 5. Data model (target; written by later batches)

### `familyBills/{parentId}_{yyyy-MM}` — server-written only

| Field | Meaning |
|---|---|
| `parentId`, `periodKey`, `currency` | Identity. |
| `lines[]` | `{ studentId, studentName, halaqaId, paymentId, feeMinor, discountMinor, amountMinor }` — name/halaqa snapshotted at issue for reporting (no contact data). |
| `subtotalMinor`, `discountMinor`, `totalMinor` | Snapshot from §4. |
| `discountRule` | `{ type: fixed, valueMinor }` or `{ type: percentage, basisPoints }`, or absent. |
| `dueDate`, `issuedAt`, `issuedBy` | Policy §2.5. `dueDate` is authoritative and never rewritten after issue. |
| `gracePeriodDaysAtIssue` | *(proposed)* Grace-period value in force when the bill was issued (snapshot of `pricingDefaults.gracePeriodDays`). Never rewritten when the global setting changes (§11.8 item 6, grace-period snapshot). |
| `status` | `due` → `overdue` → `paid`, or `cancelled`. |
| `reviewStatus` | absent → `pending_review` → `approved` / `rejected`. |
| `method` | `vodafone_cash` or `instapay`, chosen by the parent at submission. |
| proof fields | Same shape as `payments` (`proofCycleId`, `proofStoragePath`, `proofSubmittedAt`, …). |
| `reviewedBy`, `reviewedAt`, `reviewNotes` | Server-written on review. |
| `supervisorIds` | (planned) server-maintained, for rule-checked supervisor reads. |

Constants: `lib/shared/domain/family_bill_contract.dart`.

### Additions to existing documents (later batches)

- `payments/{id}`: `familyBillId`, `feeMinor`, `discountMinor`, `amountMinor`
  (existing fields untouched). Also *(proposed)* `gracePeriodDaysAtIssue`,
  written once by the issuer for newly issued invoices. The existing `dueDate`
  stays authoritative and is never rewritten. Existing invoices are not
  backfilled (§11.8 item 6, grace-period snapshot).
- `pricingRules`: entries with `scope: family_discount`, `scopeId: parentId`,
  `discountType`, `valueMinor` / `basisPoints`, `effectiveFrom` — one pricing
  system, no parallel collection.
- `academySettings/paymentPublic`: `instapayDestinationType`
  (`mobile` | `address` | `link`).

## 6. State transitions

| From | Event | Actor (trusted path) | To |
|---|---|---|---|
| — | Admin issues month | Admin → issuer callable | `status=due` |
| `due` | Cairo calendar due date reached (same rule as invoices, `shouldMarkPaymentOverdue`) | Daily job | `status=overdue` (access is not suspended by this alone; see below) |
| `due` / `overdue`, review absent or `rejected` | Parent submits proof (with method) | Parent → submission callable | `reviewStatus=pending_review`, new `proofCycleId` |
| `pending_review` | "تم الدفع بالفعل" (confirmed) | Authorized supervisor / admin → review callable | `status=paid`, `reviewStatus=approved`, `reviewedBy/At`, all linked invoices `paid` in the same transaction |
| `pending_review` | Reject with reason | Same | `reviewStatus=rejected` (amounts unchanged); parent may resubmit |
| `due` / `overdue` / `rejected` | Correction | Admin → cancel-and-reissue (audited) | old `cancelled`; new bill issued |
| `paid` | anything | — | terminal (no client path) |

Uploading proof never changes `status`. Only the review callable sets `paid`.

**Overdue status and access stages are separate (current requirement,
2026-10-17).**
- `overdue` starts on the Cairo calendar due date, for invoices and family
  bills alike.
- The grace period (the stored `gracePeriodDaysAtIssue`, §5) governs only the
  `paymentAccess` stages `reminded` → `due_warning` → `in_grace` →
  `suspended`. An `overdue` bill does not mean access is suspended
  immediately.
- *Superseded history:* the Batch A row read "Due date + grace passes →
  `overdue`". It was replaced to match the existing invoice rule.
- Making family-bill handling and the daily job use stored snapshots is a
  separate implementation stage (§11.8 item 6, rule 13).

## 7. Edge cases

| Case | Rule |
|---|---|
| Several children | One family bill, one line each; one proof. |
| Only some due | Only due children are lines (§4). |
| Family discount configured, one child due | Not applied. |
| Halaqa change mid-month | Issued bill unchanged (immutable); halaqa only affects which rule applies at issue and who may verify. |
| Admin changes price after issue | Future months only (D3). |
| Same proof uploaded twice | Submission replays the current cycle; no new cycle, no duplicate. |
| New proof after rejection | New cycle; reviews bound to the old cycle fail. |
| Same proof reviewed twice / retried | Only `pending_review` is reviewable; per-request idempotency replays the stored result; audit id per cycle blocks a second review. |
| Child already paid individually for the month | Excluded from the family bill (not due). |
| Supervisor covers only some children | Cannot verify; admin verifies. |

## 8. Report status (shared by parent view and admin report)

`lib/shared/domain/billing_report_status.dart` → `billingReportStatus`.
Derived only from stored `status` / `reviewStatus`; overdue never from a client
clock.

| Stored | Status |
|---|---|
| no bill, fee configured | `notYetDue` |
| no bill, no fee | `feeNotConfigured` |
| `paid` | `paid` (the only paid state) |
| `due` / `overdue` + `pending_review` | `awaitingVerification` |
| `due` / `overdue` + `rejected` | `rejected` |
| `due` / `overdue` + legacy `partial` | `partiallyPaid` |
| `due`, no review | `awaitingProof` |
| `overdue`, no review | `overdue` |
| `cancelled` | `cancelled` |
| anything else (e.g. `approved` without `paid`) | `unknown` — never paid |

## 9. Authority

| Write | Who |
|---|---|
| Fees, family discount | Admin (pricingRules, admin-only rules) |
| Bill / invoice amounts, lines, status | Backend only |
| Proof pointer, cycle, method | Submission callable (parent intent, server-checked ownership) |
| `paid`, `reviewedBy/At`, confirmed amounts | Review callable (server-derived reviewer) |
| Admin notification | Review callable, in the review transaction, deterministic id `payment_verified_{billId}_{cycleId}` |

## 10. Planned later work (not in Batch A)

- **B:** Admin fee + family-discount configuration UI; `instapayDestinationType`.
- **C:** `adminIssueMonthlyBills` callable (reuses the issuer + §4); parent bill view.
- **D:** Submission/review callables accept family bills + method; supervisor UI.
- **E:** Admin notification; month-scoped report queries.
- Rules: `familyBills` read (parent own / admin / supervisor of all lines), no
  client writes; `pricingRules` shape check for `family_discount`; Storage
  proof path for bill ids. Indexes: `payments(periodKey,status)`,
  `payments(parentId,periodKey)`, `familyBills(periodKey,status)`,
  `familyBills(supervisorIds,periodKey)`. Rules tests need an approved isolated
  emulator.

## 11. Proposed decisions — AWAITING OWNER CONFIRMATION

> **Status: PROPOSED, NOT APPROVED.** Nothing in this section is locked until
> the owner explicitly confirms it. No code implements it. Field names marked
> *(proposed)* do not exist yet; every other name is taken from the current
> code and is cited.
>
> History: these proposals answer the six open questions recorded at Batch A
> (2026-10-16): zero-fee students, missing fees, existing per-child invoices,
> definition of "billable", rejection while overdue, notification audience.

Test plan legend: **U** = pure Node unit test (`node --test`, no Firebase);
**E** = emulator test (only with separate approval of an isolated emulator,
never a live project); **F** = Flutter unit/widget test.

### 11.1 Zero-fee students (batch C) — APPROVED (2026-10-17; field names proposed)

**Decision.** A zero fee is valid only when an explicit, persisted, admin-approved
exemption exists. A missing pricing rule is never zero, and is never read as an
exemption.

**Owner confirmation (2026-10-17).**
- Exemptions are approved by admins only, consistent with the existing
  `pricingRules` permissions (admin-only read/write).
- Every exemption must carry explicit persisted evidence: the approver's
  identity, the approval timestamp, and a reason.
- Missing pricing is never interpreted as an exemption or as a zero fee.

**Evidence must be server-enforced — APPROVED 2026-10-17 (design only).**
Exemptions are created and approved **only** through a dedicated admin server
callable, *(proposed)* `adminApproveFeeExemption`.
- The callable checks the caller with `assertCallerIsAdmin` (active admin,
  `activeRoleOf`).
- It derives `approvedBy` from the authenticated request and `approvedAt` from
  the server clock. Neither is ever accepted from the client.
- It validates the reason: non-empty, bounded, rejected if it contains contact
  information.
- It validates scope (`student` only), the student, and the effective month.
- It writes the rule and one audit entry, *(proposed)* action
  `fee_exemption_approve`. It is idempotent per admin request id.
- Revoking or ending an exemption goes through the same callable path, with its
  own audit entry.

**Closing the direct-write bypass (required before the callable ships; not
done now).**
- Today the admin client writes `pricingRules` directly
  (`upsertPricingRule` in `admin_remote_datasource_impl.dart`, using `set`
  without merge). The `amount > 0` check exists only on the client, and the
  rules allow any admin write without a shape check.
- The rules change must deny client create/update/delete when any of these
  holds:
  - the incoming data contains `feeExempt`, `approvedBy`, `approvedAt` or
    `exemptionReason`;
  - the incoming `amount` is not a positive number;
  - the existing doc has `feeExempt == true`, so a client `set` can never
    overwrite or erase an exemption.
- Normal positive-price admin edits keep working.
- As defence in depth, the issuer honours an exemption only when every evidence
  field is present (see tests).
- Rules tests need an approved isolated emulator.

Neither the callable nor the rules change is implemented.

**Existing basis.** There is no exemption or free-place concept anywhere in code or
rules. `pricingRules` is admin-only read/write with no field shape check
(`firestore.rules` `match /pricingRules`). The issuer rejects any amount ≤ 0
(`assertPositiveAmount`, `functions/src/billing/paymentHelpers.ts`;
`issueInvoiceFromPricing` → `failed-precondition`).

**Proposed model.** Store the exemption in the same pricing system (no parallel
collection): a `pricingRules` entry with `scope: "student"`, `scopeId: studentId`,
`amount: 0` and *(proposed)* `feeExempt: true`, `exemptionReason` (short and
bounded; no personal or contact data), `approvedBy`, `approvedAt`. Existing
`active`, `version`, `effectiveFrom`, `effectiveTo` and the existing
student → halaqa → academy_default precedence (`selectApplicableRule`) apply.
Only student scope may be exempt.

**Rules once confirmed.**
- `amount === 0` with `feeExempt === true` → exempt line (`feeMinor = 0`,
  `amountMinor = 0`, *(proposed)* `exempt: true`, `pricingRuleId`).
- `amount === 0` without `feeExempt`, `feeExempt` on a non-student scope, or a
  negative amount → `fee_not_configured` (fail closed, as §11.2).
- No per-child `payments` invoice is created for an exempt child. A zero
  `due` invoice would be picked up by `processPaymentOverdueGrace` and could
  suspend the family, and `reviewPaymentProof` rejects invoices ≤ 0.
- All due children exempt → no family bill is issued; each child is reported as
  exempt.
- `calculateFamilyBill` (Batch A) gains an explicit exemption flag on its input
  in batch C. A zero fee without the flag stays a failure.

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| No rule at all | `fee_not_configured` | U |
| `amount: 0`, no `feeExempt` | `fee_not_configured` | U |
| `feeExempt: true`, `amount > 0` | invalid rule → `fee_not_configured` | U |
| `feeExempt` on halaqa / academy scope | ignored as invalid → fail closed | U |
| Exemption expired (`effectiveTo` < month) | falls back to the next rule; none → fail | U |
| Exempt + priced siblings | exempt line at 0; discount allocated only to priced lines | U |
| All due children exempt | no bill, no invoice; report shows exempt | U, E |
| Exempt child never reaches overdue/suspension | no invoice exists | E |
| Non-admin writes `feeExempt` | denied (existing admin-only rule) | E |
| Exemption missing `approvedBy`, `approvedAt` or `exemptionReason` | not an exemption → `fee_not_configured` | U |
| Client sends `approvedBy` / `approvedAt` to the callable | ignored; server values used | U |
| Admin client writes `feeExempt` or `amount: 0` directly to `pricingRules` | denied by rules | E |
| Admin client `set` over an existing exemption doc | denied by rules | E |
| Non-admin or deactivated admin calls the callable | `permission-denied` | E |
| Reason empty, too long, or containing contact info | `invalid-argument` | U |
| Same approval request retried | one rule, one audit entry | E |

### 11.2 Missing fees (batch C) — PROPOSED

**Decision.** Issuing stays blocked when any otherwise-billable child (§11.4)
has no configured fee. The affected child is returned and reported with a
clear reason. A child is never silently left off the bill.

**Existing basis.** `calculateFamilyBill` already fails with
`fee_not_configured` and the offending `studentIds` (§4). The per-child issuer
fails `failed-precondition` when no rule applies.

**Proposed behaviour.** The month issuer returns one result per parent:
`issued` / `existing` / `blocked`, where `blocked` carries a reason code and
student ids. Reason codes: `fee_not_configured`, the conflict codes of §11.3, and
`no_children_due`. A blocked parent gets no family bill and no new per-child
invoices for that month (one transaction, all or nothing). The admin report
lists blocked families with the student name and the reason. Student ids only
in logs; no amounts, no contact data. Re-running after the fee is configured
issues the bill normally (idempotent, §11.3).

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| One of three due children unpriced | parent `blocked`, that child listed, no writes | U, E |
| Unpriced child not billable (§11.4) | does not block | U |
| Fee configured, issuer re-run | bill issued; other parents unaffected | E |
| Malformed rule amount (string, NaN, decimals beyond piasters) | treated as missing | U |
| Report for a blocked family | "fee not configured" per child, never "paid" | F |

### 11.3 Existing per-child invoices (batch C) — PROPOSED

**Decision.** Invoice history is kept. An existing invoice is linked only after
checking that it is compatible. There is never a second collectible obligation
for the same student and month. Paid or conflicting invoices are never linked,
cancelled or replaced automatically; they are reported for explicit
reconciliation.

**Existing basis.** Invoices are `payments/inv_{studentId}_{yyyy-MM}`
(`invoiceDocId`). Fields used: `studentId`, `parentId`, `periodKey`, `amount`
(decimal pounds), `status` (`due` / `overdue` / `paid`; unpaid =
`isUnpaidPaymentStatus`), `reviewStatus` (`pending_review` / `approved` /
`rejected` / `partial`), `amountPaidConfirmed`, `proofCycleId`. Clients cannot
write `payments`. No code creates payment docs with random ids. Migrated or
seeded data might, so non-deterministic docs for the same student and month are
also looked up.

**Compatibility check** (per due child, inside the issuing transaction):

| Existing state | Outcome |
|---|---|
| No invoice for student+month | Create it through the existing issuer, linked (*(proposed)* `familyBillId`, `feeMinor`, `discountMinor`, `amountMinor`; existing fields unchanged). |
| `studentId`, `parentId`, `periodKey` match; `status` `due`/`overdue`; `reviewStatus` absent or `rejected`; `amountPaidConfirmed` absent or 0; minor-unit `amount` == computed `feeMinor`; `dueDate` on the same Cairo day as the bill's `dueDate`; no `familyBillId` | **Compatible** → link. History fields (`proofFileNameHistory`, prior `reviewNotes`, audit) untouched. |
| `status == "paid"` with matching student/parent/period | **Settled separately** → child is not a line (not due); reported as settled, not as a conflict. |
| `reviewStatus == "pending_review"` (proof in flight) | Conflict `invoice_proof_pending`. |
| `reviewStatus == "partial"` or `amountPaidConfirmed > 0` | Conflict `invoice_partially_paid`. |
| Amount differs from the computed fee | Conflict `invoice_amount_mismatch`. |
| Authoritative `dueDate` differs from the family bill's `dueDate` (Cairo calendar day), or is missing or malformed | Conflict `invoice_due_date_mismatch` (added 2026-10-17). The invoice's own `dueDate` and grace snapshot are preserved and never normalized; it is linked only after explicit admin resolution. |
| `parentId` differs (re-linked child) | Conflict `invoice_parent_mismatch`. |
| Already linked to another `familyBillId` | Conflict `invoice_linked_elsewhere`. |
| Another payment doc exists for the same student+month | Conflict `invoice_duplicate_for_period`. |
| Unknown `status` value | Conflict `invoice_status_unknown`. |

Any conflict blocks that parent's bill (as §11.2) and is reported with the code.
Resolving it is an explicit admin action (later batch, audited). After linking,
a per-child proof against a linked invoice is rejected (batch D). The family
bill is the only collectible.

**Idempotent retry.**
- The bill id is deterministic (`familyBills/{parentId}_{periodKey}`).
- If a bill already exists (any status except `cancelled`), a retry returns it
  unchanged: no recalculation, no re-linking, no duplicate audit entry, no
  second notification.
- The bill, all invoice creations and links, and the single audit entry commit
  in one transaction that re-reads every touched document. A conflicting
  concurrent run therefore aborts or replays and never partially applies.
- A month-wide run returns per-parent results. Re-running issues only the
  families that were previously blocked, plus new ones.

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| Each row of the compatibility table | outcome as listed | U (pure classifier) |
| Same issue request twice / concurrently | one bill, one audit, second returns `existing` | E |
| Crash between reads and commit | nothing written | E |
| Paid sibling + two unpaid | bill with two lines; discount threshold counts only due lines | U |
| Existing invoice due date differs from the bill's | `invoice_due_date_mismatch`; bill blocked; invoice `dueDate` unchanged | U, E |
| Newly created child invoice | gets the bill's `dueDate` and `gracePeriodDaysAtIssue` in the same transaction | E |
| Linked invoice: per-child proof submit | rejected (batch D) | E |
| Existing invoice history after link | history fields byte-identical | E |

### 11.4 Billable students (batch C) — PROPOSED

**Decision.** Only students with an approved, active academy enrollment are
billable, judged by the existing canonical fields. A student's first billable
month is the month after the month in which their enrollment was approved.
No new status field is invented.

**Existing canonical dimensions**
(`functions/src/lifecycle/studentLifecycleContract.ts`):

| Dimension | Field | Billable when |
|---|---|---|
| Identity | `users/{id}.role` | `role == "student"` |
| Admission | *(proposed)* `studentProfiles.admittedAt`, or an approved legacy resolution (§11.8 items 1, 8) | resolved; unresolved = not billable |
| Lifecycle | `studentProfiles/{id}.lifecycle` (+ *(proposed)* `unarchivedAt`) | `normalizeLifecycle(...) == "active"` (missing = active) |
| Membership (enrollment) | `halaqat.studentIds` (SSOT); written only by `admitStudentToHalaqa` / transfer | member of at least one halaqa |
| Family link | `parentProfiles/{parentId}.childrenIds` (D12) | listed under that parent |

**Not eligibility inputs (owner direction 2026-10-17):**
- `users.isActive` (login). A student whose login is disabled is billed like
  any other enrolled, active, admitted student.
- `paymentAccess`. A suspended family is still billed.

Neither creates an exemption, and neither resets `admittedAt`, `unarchivedAt`
or the billing start month. Current membership is an enrollment condition only;
it is never admission-date evidence.

*History:* the 2026-10-16 draft of this table required `isActive != false`.
That requirement was withdrawn on 2026-10-17 (§11.8 item 7).

**Approval date.** Approval means the student's first admission through
`admitStudentToHalaqa`, which is used by both admin and supervisor; the admin
registration approval calls it too. That callable stores no approval timestamp
on the student. The only persisted record is the `auditLogs` entry
(`action: student_admit`, metadata `studentId`, `halaqaId`). Second-halaqa
admissions and transfers write membership but are not a new approval.
`studentProfiles.createdAt` is the provisioning time, not approval, and must
not be used. Owner direction on the approval-date source: see §11.8 item 1.
Owner direction on unarchive: see §11.8 item 2. Login reactivation: see §11.8
item 7.

Months use Cairo time (`functions/src/billing/cairoTime.ts`), consistent with
the overdue job.

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| Approved 31 Oct 23:30 Cairo | first billable month = November (Cairo date is still Oct) | U |
| Approved 1 Nov 00:10 Cairo (31 Oct UTC) | first billable = December | U |
| Archived at issue time | not billable | U, E |
| Login disabled (`isActive: false`), otherwise eligible | billable; no exemption, no date reset | U |
| Login re-enabled | no change to dates or eligibility | U |
| Family payment-suspended | still billable; dates unchanged | U |
| Admission unresolved | not billable; reported "admission date unresolved" | U |
| Not in any halaqa (pending registration) | not billable | U |
| Two halaqas | billed once (one line per student) | U |
| Transferred mid-month | still billable; the issued bill is unchanged | U |
| Child linked to the parent after the month's bill was issued | not added; appears in the report as "billable but not on issued bill" → cancel-and-reissue | E |

### 11.5 Rejected proof after the due date (batch D/E) — PROPOSED

**Decision.** The proof's review state and the bill's due/overdue state are two
independent facts. They are stored in separate fields and shown together. A
rejection reason is never overwritten by the overdue state, and vice versa.

**Existing basis.** `payments` already separates `status` (`due` / `overdue` /
`paid`) from `reviewStatus`. The overdue job only treats `due` / `overdue`
as unpaid and does not touch `reviewStatus`. The rejection reason is
`reviewNotes`, written by `reviewPaymentProof`, which deletes it when a review
has no notes. Resubmission (`submitPaymentProof`) sets
`reviewStatus: pending_review` but leaves `reviewNotes`. Each proof cycle has
exactly one review audit entry (permanent history).

**Proposed contract.**
- `familyBills` uses the same two fields (§5).
- The overdue job never writes `reviewStatus`, `reviewNotes` or review fields.
- The review callable never writes `due` / `overdue`.
- For family bills a rejection requires a non-empty reason (contact-info guarded,
  as now).
- *(proposed)* `lastRejection { proofCycleId, reason, reviewedBy, reviewedAt }`
  keeps the latest rejection visible after resubmission. Full history stays in
  `auditLogs`.
- Reports and the parent view show **two** facts: payment state (due / overdue /
  paid / cancelled) and proof state (none / awaiting verification / rejected
  with reason / approved).
- `lib/shared/domain/billing_report_status.dart`: the single-value
  `billingReportStatus` (Batch A) folds `due` / `overdue` + `rejected` into
  `rejected`. It is kept unchanged for compatibility. The two-dimension
  `billingReportDimensions` was added after approval (§11.8 item 4); new report
  and parent views must use it.

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| Rejected, then the Cairo due date is reached | `status=overdue`, `reviewStatus=rejected`, reason intact; access stage still follows grace (§6) | U (job logic), E |
| Overdue, then rejected | same final state | U, E |
| Rejected → resubmitted | `pending_review`; `lastRejection` kept until the next review | E |
| Report row | shows "overdue" and "rejected: reason" together, never paid | F |
| Rejection without reason (family bill) | `invalid-argument` | U |

### 11.6 Review notifications (batch E) — PROPOSED

**Decision.** Every review outcome (approved or rejected), by a supervisor or an
admin, notifies all active admin accounts using the existing canonical checks.
No finance-admin role or recipient list.

**Existing basis.** Admin = `activeRoleOf(users/{uid}) == "admin"` (missing
`isActive` = active; `functions/src/authority/callerContext.ts`). Rules =
`hasRole('admin')`, which already requires an active profile. Notifications are
server-written docs (`writeInAppNotifications`) whose `audience` is a uid, a
role or `all`. The rules let a reader see a doc whose `audience` is their uid
or their role, and gate the role through `hasRole`. `readBy` is per reader.

**Proposed delivery.**
- **In-app:** one notification doc with `audience: "admin"` and the
  deterministic id `payment_verified_{billId}_{proofCycleId}` (§9), written in
  the review transaction. A retry overwrites the same doc and never duplicates
  it. A deactivated admin cannot read it, because `hasRole` checks activity at
  read time.
- **Push (if push is enabled for this type):** recipients = `users` where
  `role == "admin"`, then filtered in code with `activeRoleOf`. Querying
  `isActive == true` would drop legacy profiles with no `isActive` field. Push
  is sent after commit and is best effort: a push failure never fails or
  reverts the review.
- Content: decision, period, bill id and the reviewer's role. No amounts in the
  push body, no payment destinations, no contact data. Data payload goes
  through `assertSafeDataPayload`.
- Zero active admins: the in-app doc is still written. Push sends nothing and
  logs only a count.

**Edge cases and tests.**

| Case | Expected | Test |
|---|---|---|
| Supervisor approves | one admin-audience doc | E |
| Same review retried | same doc id, no second doc | E |
| Deactivated admin | cannot read it (rules); not in the push list | E, U |
| Admin with no `isActive` field | included | U |
| Teacher / parent reads the doc | denied | E |
| Push provider error | review still committed | U |

### 11.7 Consistency across flows (once confirmed)

| Fact | Parent | Supervisor | Admin |
|---|---|---|---|
| Bill lines, totals | own bill (snapshot only) | bills where they supervise every line (§2.4) | all |
| Exempt child | shown as exempt, no amount due | same | same + exemption rule |
| Blocked issue (missing fee / conflict) | no bill shown ("not yet issued") | not shown | report with reason codes |
| Payment state + proof state | both | both | both |
| Rejection reason | own | for bills they may verify | all |
| Notification | (existing parent notices only) | — | all active admins |

No flow computes totals on the client (§4, §9).

### 11.8 Owner decisions on the Batch A ambiguities (2026-10-16, updated 2026-10-17)

Status key:
- **APPROVED** — owner decision, binding for later batches.
- **APPROVED DIRECTION** — the owner set the direction (2026-10-17). The listed
  prerequisites (contract amendment, legacy handling) must be completed and
  approved before implementation.
- *(proposed)* — a field or action name that does not exist yet and is
  confirmed at implementation review.

Nothing below is implemented in runtime code, rules, indexes, callables,
screens or data. The one exception is item 4, a pure, unused Dart mapping plus
its tests.

**Implementation approvals (owner decision 2026-10-17).**
- Every implementation stage described in §11 needs its own separate
  approval.
- Approving a contract or design here does **not** authorize runtime code,
  Firestore Rules, indexes, callables, migrations, or data changes.
- Any Rules work that needs an emulator also needs separate approval of the
  isolated test plan. A live Firebase project is never a test target.

#### 1. Admission date — APPROVED DIRECTION (2026-10-17); legacy dates resolved only via item 8

**Direction.** Add a server-written *(proposed)* `studentProfiles.admittedAt`
timestamp. Existing students are not backfilled by guessing. Neither the field
nor any backfill is implemented yet.

**Inspection (code only; no data was read).**
- Admission is `admitStudentToHalaqa` (`functions/src/halaqa/membershipFunctions.ts`),
  used by the admin registration approval (`approveNewStudent`) and by the
  supervisor admission screen. It writes `halaqat.studentIds`, sets
  `studentProfiles.halaqaId` when no primary halaqa exists, and sets
  `users.isActive = true` only when an admin admits. No timestamp is stored
  on the student.
- The audit entry `student_admit` is written **inside** the admission
  transaction, so it is committed exactly when the membership is. The
  canonical envelope (`functions/src/audit/auditLogContract.ts`):
  - `timestamp`;
  - `targetType: halaqa`, with `targetId` = the halaqa id;
  - the student id only in `metadata.studentId`.
- The same action is also written for a second-halaqa admission. The earliest
  `student_admit` entry for a `metadata.studentId` is therefore only the
  earliest **audited** admission, not necessarily the first one (see below).
- `student_admit` is a PH-02 action. Documents written before WA-16 may carry
  legacy fields (`createdAt`, `actorUid`, old action names), which WA-16 does not
  rewrite. Admissions made before PH-02, by direct client writes, or by
  migration have no `student_admit` entry.
- `studentProfiles.createdAt` and `users.createdAt` are the provisioning time,
  not admission. They must not be used.

**Owner direction (2026-10-17).**
- `admittedAt` is a server-written timestamp of the student's **first actual
  admission**.
- It is never reset by a halaqa transfer, account (login) reactivation, or
  payment suspension.
- A legacy record is trustworthy only if it can be tied to the first admission,
  not merely to a later halaqa assignment.
- Where existing records cannot tell a first admission from a transfer or a
  second-halaqa admission, nothing is guessed.
- Students with unresolved legacy admission dates are never silently billed.

**Additional inspection (2026-10-17).**
- Transfers (`adminTransferStudent`) write a separate audit action,
  `student_transfer`, never `student_admit`. A transfer entry is therefore never
  admission evidence.
- `student_admit` metadata holds only `studentId` and `halaqaId`. It does not
  record whether the student already had a membership. So an entry cannot by
  itself show that it was the *first* admission: if the true first admission
  was never audited (before PH-02, a direct client write, or a migration), the
  earliest audited entry may be a second-halaqa admission.
- The callable already reads the student's existing memberships (the
  `memberships` list in the admission transaction) before adding the new halaqa.

**Rule once implemented (later batch, not Batch B unless approved).**
- `admitStudentToHalaqa` sets `admittedAt` (server timestamp) in the same
  transaction only when **both** hold:
  - `admittedAt` is absent;
  - the student had **no** existing membership before this admission.
- A second-halaqa admission, a transfer, or an admission of a legacy student who
  already has a membership never sets it. Such students stay unresolved and are
  never stamped with "now".
- The same transaction records *(proposed)* `metadata.firstAdmission: true` on
  that `student_admit` entry, so future audit evidence is self-describing.
- Nothing else writes `admittedAt`: not the login toggle, `paymentAccess`,
  lifecycle changes, or transfers. Clients can never write it; this needs a rules
  guard in a later approved batch.
- First billable month = the Cairo month after `admittedAt` (combined with item
  2 for reactivation).
- No `admittedAt` and no approved item 8 resolution → **not billable**. The
  student appears in the admin report as
  "admission date unresolved". This fails closed; a month is never guessed.

**Legacy admission evidence — owner direction (2026-10-17, second update).**
- The date admission auditing began is **not** guessed, and no rule depends on
  it.
- Account creation time (`users.createdAt`, `studentProfiles.createdAt`, the
  `user_provision` entry), current halaqa membership (`halaqat.studentIds`,
  `studentProfiles.halaqaId`) and login activity (`users.isActive`, sign-in
  history) are **never** admission evidence.
- *History:* the first 2026-10-17 draft used provisioning time to show that
  auditing was already in force. That condition is withdrawn.

**Consequence.** Without a known audit start date, an existing `student_admit`
entry cannot prove that no earlier, unaudited admission happened. Its metadata
also does not record whether it was a first admission. A legacy entry is
therefore at most an **upper bound** ("admitted no later than this date"),
never by itself a reliable first-admission date. Legacy `admittedAt` values are
never written automatically; each existing student is resolved through the
workflow in item 8. Only future admissions that record
*(proposed)* `metadata.firstAdmission: true` (rule above) are self-proving.

Never evidence:
- `student_transfer` entries;
- legacy-shaped entries (`createdAt` / `actorUid` / old action names);
- current membership or `studentProfiles.halaqaId`;
- `studentProfiles.createdAt`, `users.createdAt` or `user_provision` entries;
- `isActive` changes or any login activity.

**Future read-only audit (not run; needs separate approval).** It classifies
existing students and reports counts per class, plus student ids. No names,
contact data or amounts; it writes nothing.
- **Evidence quality:**
  - canonical `student_admit` entries present (upper bound only);
  - legacy-shaped entries only;
  - no admission entry.
- **Conflicts:**
  - several `student_admit` entries;
  - an entry whose `halaqaId` the student is not in and has no transfer away
    from;
  - an entry dated after a `student_transfer` for the same student;
  - an entry with a malformed `timestamp`.
- **Unresolved dates:** every student without an approved resolution (all
  existing students until item 8 is used).

The audit's output informs the administrative resolution. It never sets
`admittedAt` or a billing month.

**Tests (later).**
- U: set-once logic, including "existing membership → not set".
- U: a second-halaqa admission never sets the field.
- U: month derivation across the Cairo month boundary.
- U: evidence classifier with fakes, covering every evidence class, every
  conflict class, and each "never evidence" input (none may produce a date).
- E: concurrent admissions produce one value.
- E: clients cannot write `admittedAt`.
- E: transfer, login toggle and suspension leave it unchanged.

#### 2. Unarchive — APPROVED (2026-10-17): `unarchivedAt` and the WA-15 amendment (design only)

**Direction.** A student who was explicitly archived becomes billable from the
month after reactivation. Archived months are never invoiced automatically.
Payment suspension for arrears never resets the admission or billing start
date.

**Owner direction (2026-10-17).**
- The relevant WA-15 contract is explicitly amended **before** implementation.
- A server-controlled reactivation timestamp is stored when an archived student
  is restored.
- The first billable month is the month after the **latest applicable**
  admission or reactivation month.
- No invoices are created for archived months.
- Payment suspension and login-account deactivation/reactivation do not reset
  admission or billing dates.
- The field name and transition logic are chosen only after inspecting the
  existing lifecycle fields (done below).

**Inspection.**
- The lifecycle is `studentProfiles.lifecycle` (`active` | `archived`; missing =
  active), changed only by `adminSetStudentLifecycle`.
- The update is deliberately a single key (`buildLifecycleUpdate`), and
  `isolationHolds` asserts that no other profile field is written. The
  transition time exists only on the audit entry: `user_unarchive` /
  `user_archive`, `targetType: studentProfile`, `targetId` = the student id,
  `timestamp`.
- That audit entry is written **after** the lifecycle transaction commits. A
  crash between the two can leave a transition with no audit entry, so the
  audit alone is not a fully reliable billing input.
- Archiving does not remove halaqa membership, deactivate the account, or touch
  `paymentAccess`. Suspension lives in `paymentAccess/{parentId}` and is
  independent of the lifecycle.

**Proposed transition once confirmed.** A student is billable for month M only
if all of the following hold:
- lifecycle is `active` when the bill is issued;
- M is after the `admittedAt` month (item 1);
- if the student was ever reactivated, M is after the Cairo month of the latest
  reactivation.

**WA-15 decisions — APPROVED 2026-10-17 (contract/design only).**
- The field name `unarchivedAt` is approved.
- Amending the WA-15 contract and its isolation test before implementation is
  approved.
- This approves the contract and design change only. It does **not** approve
  runtime code or Firestore Rules changes, which need separate approval.
- Archival (`lifecycle`), login activation (`users.isActive`) and payment
  suspension (`paymentAccess`) stay distinct; the amendment must not couple them.

**Field and transition (approved design).**
- Existing lifecycle fields: only `studentProfiles.lifecycle`. No timestamp
  field exists, and the existing backfill (`student_lifecycle_backfill`) writes
  only `lifecycle`.
- Name (approved): `studentProfiles.unarchivedAt`. It matches the
  existing action `unarchive` and audit action `user_unarchive`. "Reactivated"
  is avoided because it would be confused with login reactivation
  (`users.isActive`, item 7).
- `adminSetStudentLifecycle` with action `unarchive` and outcome `transition`
  (`archived → active`) writes `{ lifecycle: "active", unarchivedAt:
  serverTimestamp }` in the **same transaction**. A `noop` (already active)
  writes nothing. `archive` never writes or clears `unarchivedAt`.
- Billing start: first billable month = the Cairo month after
  `max(admittedAt, unarchivedAt)`. With no `admittedAt` the student stays
  unresolved (item 1); `unarchivedAt` alone never makes a student billable.
- Never written by: `paymentAccess` changes, the login toggle, admissions,
  transfers.
- The issuer issues only the requested month and never catches up past months,
  so archived months are never invoiced.
- A bill issued before archiving stays as issued (immutable; cancel-and-reissue
  is an explicit admin choice).

**WA-15 amendment (approved; the text is written into the WA-15 documents
before implementation, not now).** `WAVE_A_IMPLEMENTATION_SPEC.md` WA-15 and
the code contract (`buildLifecycleUpdate` single-key map, `isolationHolds`, and
their tests) state that a lifecycle transition writes only `lifecycle`. The
amendment:
- allows exactly `{lifecycle, unarchivedAt}` on an `unarchive` transition, and
  exactly `{lifecycle}` on `archive`;
- keeps `isActive`, `role`, `halaqaId`, membership and payment fields
  forbidden;
- keeps the original text as history.

`SECURITY_DATA_CONTRACT_FREEZE.md` C14 needs a matching note. A later,
separately approved rules change must deny client writes to `unarchivedAt`.

**Students already unarchived — owner direction (2026-10-17).**
- An existing `user_unarchive` audit entry may be used **only** when it is
  demonstrably reliable.
- Missing timestamps are **never** filled with the current date.
- Cases without reliable evidence need explicit administrative resolution
  (item 8 workflow, with a first billable month).

A legacy `user_unarchive` entry is demonstrably reliable only if **all** of
the following hold:
1. It has the canonical envelope: `action: user_unarchive`,
   `targetType: studentProfile`, `targetId` equal to the student, a valid
   `timestamp`, `source: adminSetStudentLifecycle`, and metadata
   `previousLifecycle: archived`, `newLifecycle: active`.
2. It is the student's latest lifecycle audit entry.
3. Its immediately preceding lifecycle entry is a `user_archive` for the same
   student.
4. The student's current `lifecycle` is `active`.

Not reliable, so administrative resolution is required:
- the student is restored but has a `user_archive` with no later
  `user_unarchive`;
- legacy-shaped entries;
- entries out of order;
- a malformed timestamp.

Students never archived need nothing. Students currently archived get
`unarchivedAt` when they are restored after implementation.

Residual risk: because lifecycle audit entries are written after the
transaction, an unaudited later archive-and-unarchive pair cannot be ruled out
completely. The criteria above accept that risk (§11.9).

The future read-only audit (separate approval) may report counts for each
class. It writes nothing.

**Evidential weight — owner decision (2026-10-17, final).**
- The four-part test is useful but **not sufficient by itself**. It cannot
  guarantee that every historical lifecycle transition was recorded.
- A legacy `user_unarchive` entry that passes the test is **supporting
  evidence**, not conclusive proof, whenever an unaudited transition cannot be
  ruled out. Given how lifecycle audit entries are written (after the
  transaction), that is always the case for legacy data.
- Such an entry therefore never sets `unarchivedAt` or a billing month on its
  own. It is shown to the admin as evidence in the item 8 resolution.
- No timestamps are invented and no dates are backfilled automatically.
- Ambiguous cases stay unresolved, and are therefore not billable while
  restored-but-unresolved, until they are explicitly reconciled through item 8.

This supersedes the earlier sentence in item 8 that let a reliable entry be
applied through "a separately approved, audited migration". Legacy unarchive
evidence is applied only through an explicit admin resolution.

**Tests (later).**
- U: archived at issue time → not billable.
- U: unarchived in October → October not billable, November billable.
- U: `max(admittedAt, unarchivedAt)` uses the later month.
- U: an unarchive `noop` writes nothing.
- U: suspension and the login toggle change nothing in eligibility.
- U: the issuer never creates past months.
- U: the amended isolation test allows exactly `{lifecycle, unarchivedAt}`.
- E: lifecycle and timestamp are atomic.
- E: clients cannot write `unarchivedAt`.

#### 3. Exemptions and the family discount — APPROVED

- Exempt children do **not** count toward the two-children minimum for the
  family discount.
- They contribute zero to the bill total and get no collectible invoice (§11.1).
- A missing fee (`fee_not_configured`, blocks issuing) stays distinct from an
  approved exemption (explicit rule, §11.1) in data, in the calculation result
  and in reports. The report keeps `BillingDueState.exempt` and
  `BillingDueState.feeNotConfigured` separate (item 4).

Batch C changes to `calculateFamilyBill`:
- an explicit exemption flag on each input;
- exempt lines excluded from the threshold count and from discount allocation;
- a zero fee without the flag still fails.

Tests:
- U: one priced + one exempt child → no discount.
- U: two priced + one exempt → discount on the priced lines only.
- U: all exempt → no bill.
- U: zero fee without the flag → `fee_not_configured`.

**Legacy data:** none (no exemptions exist today).

#### 4. Rejected and overdue reporting — APPROVED (contract mapping implemented)

**Done now** (pure Dart; not used by any screen or flow):
- `billingReportDimensions` in `lib/shared/domain/billing_report_status.dart`
  returns separate `BillingDueState` (`notYetIssued`, `feeNotConfigured`,
  `exempt`, `due`, `overdue`, `paid`, `cancelled`, `unknown`) and
  `BillingProofState` (`none`, `awaitingVerification`, `rejected`, `approved`,
  `partial`, `unknown`).
- It also returns the latest rejection reason, kept even when the proof state
  has moved on after a resubmission.
- `isPaid` is true only for a stored `paid` status. `needsAttention` flags
  unknown values and `approved` without `paid`.
- The single-value `billingReportStatus` and its tests are unchanged.
- Tests: 7 new cases in `test/shared/billing_report_status_test.dart`.

**Follow-up (later batches, not started):**
- persist *(proposed)* `lastRejection` on bills (§11.5);
- the review callable writes it;
- resubmission must not clear it;
- report and parent views use `billingReportDimensions`.

**Legacy data:** existing `payments.reviewNotes` is deleted by a review without
notes, and older rejections may have no reason. Reports show "no reason
recorded" and never invent one.

#### 5. Cancel and reissue — APPROVED

**Identification.**
- The initial bill is `familyBills/{parentId}_{periodKey}` (revision 1, no
  suffix; `FamilyBillContract.docId` is unchanged).
- Revisions are `{parentId}_{periodKey}_r2`, `_r3`, and so on.
- *(proposed)* fields:
  - `revision` (1, 2, …);
  - `supersedes` (previous bill id, absent on revision 1);
  - on the cancelled bill: `supersededBy`, `cancelledAt`, `cancelledBy`,
    `cancelReason`.

**Rules.**
- **One active bill.** The active bill for a parent and month is found by
  following `supersededBy` from the base id (deterministic, no query or index).
  Reissue cancels the current active bill and creates the next revision in
  **one transaction**, which re-reads the chain. A concurrent reissue therefore
  aborts and never yields two non-cancelled bills.
- **No automatic revisions.** The month issuer only ever creates the base id.
  If the base id exists in any state, including `cancelled`, it returns it as
  existing and never creates `_rN`. Only the explicit, audited admin reissue
  action creates revisions. It is idempotent per admin request id (same pattern
  as `paymentReviewRequests`), so a retried reissue replays the result instead
  of creating `_r3`.
- **History.** Cancelled bills are never deleted or edited apart from the
  cancel fields above. Their lines, proof pointers and review history stay.
  Each cancel-and-reissue writes one audit entry naming both ids. Linked
  invoices are re-pointed (`familyBillId`) to the new revision in the same
  transaction. The previous link remains on the cancelled bill's lines and in
  the audit entry.
- **Guards.** A `paid` bill cannot be cancelled (terminal, §6). A bill with
  `reviewStatus: pending_review` cannot be cancelled until the review is
  decided.

Tests:
- U: id format and chain resolution.
- E: concurrent reissue → one active bill.
- E: a retried reissue → the same revision.
- E: the issuer never creates `_rN`.
- E: a paid or pending bill cannot be cancelled.
- E: cancelled history intact.

**Legacy data:** none (`familyBills` does not exist yet).

#### 6. Partially paid legacy invoices — APPROVED; write-off, reversal (same release), settlement operations, settlement access and report mapping APPROVED as design (implementation not approved)

- An invoice with `reviewStatus: partial` or `amountPaidConfirmed > 0` blocks
  that family's bill (`invoice_partially_paid`, §11.3).
- The student can be included only after an explicit administrative
  reconciliation of the outstanding balance.
- Family bills get **no** partial-payment support in this phase.
- The original invoice (`amount`, `amountPaidConfirmed`, `remainingAmount`,
  `proofFileNameHistory`, `reviewNotes`) and its per-cycle audit entries are
  preserved.

**Existing reconciliation path.** `submitPaymentProof` accepts a new proof on
a `partial` invoice (it refuses only `paid` / `approved`). `reviewPaymentProof`
can then approve the remainder (`approve` → `status: paid`). After that the
student is "settled separately" for that month (§11.3) and is never a line.

**Owner direction (2026-10-17).**
- Partially paid invoices stay blocked from automatic family-bill linking until
  they are explicitly reconciled.
- No family partial-payment support.
- A future audited administrative write-off/settlement path is documented below.
  It is **not** implemented in Batch B unless separately approved.

**Owner direction (2026-10-17, second update).**
- A write-off is recorded in a **separate, audited settlement/write-off
  record**. A waived balance is **never** marked as paid.
- Reports must distinguish **paid**, **written off / waived**, **partially
  outstanding** and **overdue**.
- `adminSettleLegacyInvoice` stays design-only and outside the current
  implementation scope.

**Settlement operations contract — APPROVED 2026-10-17 (contract decision
only; implementation needs separate approval).** This block is authoritative
for every write-off and reversal in this contract. Where older wording in this
item names a different collection, a one-record-per-invoice id, or a pointer
written onto an earlier settlement record, this block supersedes it. Nothing
here exists in code, rules or the database; it is a proposed design.

1. **Release requirement.**
   - The first release of any write-off functionality (invoice or family bill)
     **must** include the corresponding reversal operation.
   - Neither invoice write-off nor family-bill write-off may be approved or
     released independently of its reversal.
2. **One unified collection** *(proposed)* `billingSettlements/{settlementId}`.
   - It holds every settlement operation, for both individual invoices and
     family bills.
   - It replaces the earlier draft names `paymentSettlements/{paymentId}`,
     `paymentSettlements/{paymentId}/reversals/{requestId}` and
     `familyBillSettlements/{billId}`.
   - Server-written only; no client writes; records are never updated or
     deleted after creation (immutable).
3. **Identity.**
   - Each operation gets its own unique, immutable id:
     `settlementId = "stl_" + requestId`, where `requestId` is the
     admin-generated idempotency key (`[A-Za-z0-9_-]{16,64}`, the same pattern
     as `paymentReviewRequests`).
   - There is **no** assumption of one record per invoice or bill. An entity
     can accumulate many operations over time, for example write-off →
     reversal → a later write-off, each as a separate record.
4. **Fields** (all set once, at creation):

   | Field | Meaning |
   |---|---|
   | `settlementId` | The document id. |
   | `entityType` | `invoice` or `family_bill`. |
   | `entityId` | The invoice id (`payments/{id}`) or family bill id (`familyBills/{id}`). |
   | `operationType` | `write_off` or `reversal`. |
   | `sequence` | 1, 2, 3, … per entity, from the entity's `settlementSequence` + 1 inside the transaction. Gives a total order. |
   | `relatesToSettlementId` | For `reversal`: the `write_off` it reverses (required). For a later `write_off`: the most recent `reversal` on the entity (required when one exists). Absent for a first write-off. |
   | `parentId`, `periodKey` | Family and month; `parentId` drives parent read access. |
   | `studentId` | Invoice operations only. |
   | `familyBillId` | For `family_bill`: equal to `entityId`. For `invoice`: absent; linked invoices are settled only through their family bill (rule 8). |
   | `affectedPaymentIds` | For `invoice`: `[entityId]`. For `family_bill`: **every** linked child invoice id. |
   | `previousStatus`, `resultingStatus` | Entity status before and after (for example `overdue` → `written_off`, or `written_off` → `due`). For a family bill, also *(proposed)* `childStatuses` `{paymentId: {previous, resulting}}`. |
   | `amountMinor` | `write_off`: the waived outstanding amount. `reversal`: the outstanding amount restored. Integer minor units. |
   | `reason` | Required; non-empty, bounded, contact-info guarded. |
   | `actorId`, `actorRole` | From the authenticated request (`assertCallerIsAdmin`); never from client input. `actorRole` is always `admin`. |
   | `createdAt` | Server timestamp. |
   | `requestId`, `requestFingerprint` | Idempotency key, plus a hash of the canonical request (rule 6) used to detect a reused key with a different request. |
   | `dueDateUsed`, `gracePeriodDaysUsed` | Reversal only: the stored values the recalculation used (grace-period snapshot), recorded for audit. For a family bill, also per child inside `childStatuses`. |
   | `auditLogId` | Deterministic id of the operation's audit entry (rule 7). |

5. **Server-written entity pointers.** These are on the invoice or family bill,
   never on settlement records:
   - `activeSettlementId` — the currently active `write_off` operation, or
     absent;
   - `settlementSequence` — the number of operations so far;
   - `lastSettlementId`.

   History lives only in `billingSettlements`; the pointers are just an index.
6. **Atomicity, retry and idempotency (clarified 2026-10-17).**
   - **Validate everything before writing.** Each write-off or reversal runs in
     one Firestore transaction. All reads and checks complete before any write:
     1. the request id format and the idempotency record
        `billingSettlements/stl_{requestId}`;
     2. the entity's current state (`status`, `reviewStatus`, not `cancelled`);
     3. the active write-off state (`activeSettlementId` absent for a
        `write_off`; equal to `relatesToSettlementId` for a `reversal`);
     4. for a family bill, **every** linked child invoice: its state, its
        `familyBillId`, its own `activeSettlementId`, and the absence of
        `paid` / `pending_review` / partial payment for a write-off;
     5. the stored values needed for recalculation (grace-period snapshot
        below).

     If any check fails, the transaction aborts with no writes.
   - **All or nothing.** The operation record, every status and pointer change
     on the entity (and on each linked child invoice), and the operation's
     audit entry commit together in that single transaction. Otherwise the
     operation fails with no partial financial state change.
     - The audit entry is written with `tx.set` under its deterministic id
       (rule 7), using the existing `buildAuditLogEntry` envelope, as
       `admitStudentToHalaqa` already does. It is never written by a separate,
       post-commit `writeAuditLog` call.
     - A failed attempt leaves no operation record, so the same request id can
       safely be retried.
   - **Canonical request.** The fingerprint `requestFingerprint` is a hash of
     the canonical request:
     - `entityType`, `entityId`, `operationType`;
     - `relatesToSettlementId` (for a reversal);
     - the reason, trimmed and Unicode-normalized.

     Server-derived values (amounts, actor, timestamps) are not part of it.
   - **Same request id, same canonical request** → the original stored result
     is returned, even if the entity changed afterwards. No duplicate
     settlement record, status change or audit entry.
   - **Same request id, different canonical request** → rejected
     (`failed-precondition`); nothing is written.
   - **A new legitimate operation must use a new request id.** For example, a
     later write-off after a reversal, or a corrected reason after a rejected
     attempt.
   - Concurrent requests for the same entity conflict on the entity document
     and are retried by Firestore. Only one can satisfy the preconditions.
   - Linked child invoices can be settled only through the family-bill
     operation (rule 8). An invoice-level request for an invoice with
     `familyBillId` set fails validation.
   - *History:* the earlier fingerprint covered only `entityType`, `entityId`,
     `operationType` and `relatesToSettlementId`. Adding the reason supersedes
     it.
7. **Audit.**
   - Exactly one audit entry per operation, written in the same transaction
     under the deterministic id `settlement_{settlementId}`. Retries can never
     duplicate it.
   - *(proposed)* actions: `invoice_write_off`, `invoice_write_off_reverse`,
     `family_bill_write_off`, `family_bill_write_off_reverse`.
   - The entry links `settlementId`, `entityType`, `entityId`,
     `affectedPaymentIds` and `relatesToSettlementId`.
8. **Repeat operations.**
   - A `write_off` requires `activeSettlementId` to be absent. A new write-off
     is never permitted while a previous write-off is still active.
   - A later write-off is allowed only after a valid `reversal` of the earlier
     one, and with **fresh authorization**: a new admin request, a new
     `requestId` and a new reason. Re-sending an old `requestId` only replays
     the old result.
   - A `reversal` requires `activeSettlementId` equal to its
     `relatesToSettlementId`. A write-off can be reversed once; a reversal is
     never reversed.
   - An invoice linked to a family bill (`familyBillId` set) cannot be written
     off or reversed on its own. Only the family-bill operation can change it,
     which keeps bill and child histories consistent.
9. **History.** Earlier write-offs and reversals are never overwritten or
   deleted. The active state is derived from the entity's
   `activeSettlementId`, never by editing old records.
10. **Access.** No settlement operation (write-off or reversal) ever reinstates
    or suspends payment access. Restoring access stays the separate explicit
    admin action `adminReinstatePaymentAccess`. Suspension stays with the daily
    job.
11. **`written_off` is never `paid`.** No write-off and no reversal ever sets or
    implies `status: paid`.
12. **Security rules** for `billingSettlements` must be designed and separately
    approved before implementation, with an approved isolated emulator test
    plan.
    - **Admin:** reads settlement details.
    - **Parent:** reads only records whose `parentId` is their own uid, i.e.
      their own family's invoices and bills.
    - **Supervisor and student:** no direct read.
    - **Supervisor reports:** may expose only an authorized minimal status, with
      no amounts, reasons or approver identity.
    - Existing invoice-read permissions are not changed by this contract.
13. **Due-date and grace-period snapshot — APPROVED 2026-10-17 (contract
    decision only).**
    - **Stored at issue.** Every newly issued invoice (`payments`) and family
      bill (`familyBills`) keeps its authoritative `dueDate` and *(proposed)*
      `gracePeriodDaysAtIssue`: the value of `pricingDefaults.gracePeriodDays`
      in force when it was issued (§5). Both are written once by the issuer
      and never rewritten.
    - **Child invoices of a family bill (current requirement, 2026-10-17).**
      - A child invoice **newly created** by the family-bill issuer, in the
        same transaction and under this contract, gets the bill's `dueDate`
        and `gracePeriodDaysAtIssue`.
      - A **pre-existing** invoice is linked only if its authoritative
        `dueDate` equals the family bill's `dueDate` (same Cairo calendar day),
        among the other checks in §11.3. A mismatch is the compatibility
        conflict `invoice_due_date_mismatch`.
        - The invoice is not linked, the due date is not normalized, and the
          family's bill is blocked until an admin explicitly resolves the
          conflict.
        - When linked, the invoice keeps its own stored `dueDate` and its own
          snapshot; linking never rewrites them.
      - Each child invoice's state is always recalculated from **its own**
        stored values. The bill's state is recalculated from the bill's stored
        values.
      - An invoice linked to a family bill can be settled (written off or
        reversed) only through the family-bill operation (rule 8).
    - **No silent rewrites.** Changing the global `gracePeriodDays`, or any
      other setting, never rewrites `dueDate`, `gracePeriodDaysAtIssue`,
      amounts or `status` on issued bills or invoices.
    - **Overdue status versus access stages (current requirement,
      2026-10-17).** These are two distinct rules.
      - **Overdue status.** An invoice's `status` becomes `overdue` on its
        Cairo calendar due date: the current rule, `shouldMarkPaymentOverdue`
        / `cairoDaysPastDue >= 0`. A family bill's `status` and its overdue
        reporting follow the **same** due-date rule. The grace period does not
        delay `overdue`.
      - **Access stages.** The grace period governs only the `paymentAccess`
        stages (`reminded` → `due_warning` → `in_grace` → `suspended`,
        `accessStatusForUnpaidInvoice`). `overdue` does **not** mean access
        is suspended immediately. Suspension happens only when the access
        computation reaches `suspended` after the grace period.
      - Both use the Cairo calendar (`cairoYmd` / `cairoDaysPastDue`), the
        existing timezone rule of the daily job.
    - **Reversal recalculation** uses only the entity's stored `dueDate`, for
      the overdue status, and stored `gracePeriodDaysAtIssue`, for the
      reported access stage and `financialSuspensionReasonRemains`. It never
      uses the current global setting.
      - The reversal records `dueDateUsed` and `gracePeriodDaysUsed` (rule 4).
        It never writes `paymentAccess` (rule 10).
    - **Legacy compatibility (current requirement, 2026-10-17).** Existing
      invoices have `dueDate` but no `gracePeriodDaysAtIssue`. Nothing is
      invented or backfilled, and the current global value is never assumed
      to be the historical one.
      - **Until a compatibility policy is separately approved and
        implemented, write-off *and* reversal refuse any record that lacks a
        required authoritative value:** a missing or malformed `dueDate`, or a
        missing `gracePeriodDaysAtIssue`. This applies to invoices and to
        family bills, including every linked child.
      - **Before the first write-off release**, that policy must be defined
        and approved. It is a release prerequisite. Its content is not
        decided here, and it must not guess historical values.
      - Existing invoice history (amounts, `dueDate`, `status`, proof fields,
        `proofFileNameHistory`, `reviewNotes`, review audit entries) is
        preserved. No amount, due date, grace period or status of an existing
        invoice is silently changed.
      - **Legacy partially paid invoices** (`reviewStatus: partial` or
        `amountPaidConfirmed > 0`) require explicit reconciliation before any
        family-bill linking (§11.3, `invoice_partially_paid`) and before any
        write-off (item 6). They also fall under the snapshot refusal above.
    - **Daily job alignment (proposed future implementation; separate
      approval).**
      - The existing job reads the **current** global `gracePeriodDays` for
        every unpaid invoice (`loadGracePeriodDays` in
        `processOverdueGrace.ts`). Making it use `gracePeriodDaysAtIssue` where
        it exists is required for consistency with "no silent rewrites".
      - That is a separate implementation stage needing approval. This contract
        does not change the job or any runtime behaviour. Until then, the job
        behaves as it does today.

**Future write-off / settlement path (design only; not approved for any batch).**
- Admin-only callable *(proposed)* `adminSettleLegacyInvoice`:
  - the caller is checked with `assertCallerIsAdmin`;
  - idempotent per admin request id (same pattern as `paymentReviewRequests`);
  - accepts only an invoice with `reviewStatus: partial` or
    `amountPaidConfirmed > 0`, and `status` `due` / `overdue`;
  - refuses `pending_review` (a proof is being reviewed);
  - requires a non-empty reason, which is checked for contact information;
  - derives the approver and time from the request and the server clock.
- **Separate record:** a `billingSettlements` operation record with
  `entityType: invoice` and `operationType: write_off` (Settlement operations
  contract, rules 2–4). It also records *(proposed)*
  `confirmedPaidMinorAtOperation`.
  - Server-written only; clients get no write access.
  - Read access: see "Settlement record access" below.
  - One record per operation, not per invoice (rule 3).
  - *History:* the earlier draft `paymentSettlements/{paymentId}`, with one
    record per invoice, is superseded.
- Refused when the invoice is linked to a family bill (`familyBillId` set);
  such invoices are settled only through the family-bill operation (rule 8).
- **Invoice:** the original fields (`amount`, `amountPaidConfirmed`,
  `remainingAmount`, proof fields, `proofFileNameHistory`, `reviewNotes`) are
  never modified. `status` never becomes `paid`. In the same transaction the
  invoice gets the server-written pointers `activeSettlementId`,
  `settlementSequence` and `lastSettlementId` (rule 5), and moves to
  `status: "written_off"` (decision below).
- One audit entry, *(proposed)* action `invoice_write_off`, under the
  deterministic id of rule 7. Amounts appear only in the admin-only audit
  metadata and the settlement record, never in console logs.
- After settlement the child counts as settled for that month (§11.3) and can
  be on later months' family bills.

**Full write-off — APPROVED 2026-10-17 (design only; implementation needs
separate approval).**
- *(proposed)* invoice `status: "written_off"` is a distinct value for a
  **fully** waived outstanding balance. It never means paid: `isPaid` stays
  false, and it is never counted as collected money.
- **Partial write-offs are not supported** in this phase. A write-off always
  covers the entire outstanding remainder.
- **Atomic, server-authorized transition.** Only the server operation
  (`adminSettleLegacyInvoice`, admin-only) may perform it. In one Firestore
  transaction it:
  1. checks the idempotency record (rule 6);
  2. re-reads the invoice and checks the preconditions above, including that
     `activeSettlementId` is absent and `familyBillId` is not set (rules 6 and
     8), before any write;
  3. creates the `billingSettlements` write-off record;
  4. moves the invoice to `written_off` and sets the pointers of rule 5;
  5. writes the audit entry with its deterministic id.

  Retries replay the stored result. A failure leaves nothing partially written.
  Invoice history fields are never changed. Clients can never set
  `written_off`; `payments` already denies all client writes.
- **Transitions:** only `due` / `overdue` → `written_off`. `written_off` is
  terminal: no client path, never → `paid`, and never back to `due` /
  `overdue` except through the audited reversal described below. Reversal
  ships in the same release as write-off (rule 1); implementation of both
  needs separate approval.
- **Overdue job and payment access must handle it explicitly.**
  - `isUnpaidPaymentStatus` and the job's query
    (`where("status", "in", ["due", "overdue"])` in
    `processOverdueGrace.ts`) already exclude any other status. A
    `written_off` invoice is therefore never marked overdue and never drives
    suspension.
  - The implementation must still add explicit tests and a named constant, so
    a future change to the unpaid set cannot silently re-include it.
  - **Existing behaviour that matters:** `resolveAccessTransition`
    (`overdueGraceLogic.ts`) never automatically reinstates a family that is
    `suspended`, `in_grace` or `due_warning`, even when nothing is unpaid. The
    reason becomes `awaiting_admin_reinstate` (D5; reinstatement is
    `adminReinstatePaymentAccess`).
  - **Reinstatement is separate — owner direction 2026-10-17.** A write-off
    never reinstates a suspended family automatically. Financial settlement and
    access reinstatement stay two separate administrative actions.
    - After the write-off commits, the operation recalculates the parent's
      outstanding balance: the remaining `due` / `overdue` invoices, and later
      also family bills. It does this with the existing pure access computation
      (`computeParentAccessTarget`).
    - It returns, and the admin report shows, whether the **financial
      suspension reason remains**: *(proposed)* `remainingUnpaidCount` and
      `financialSuspensionReasonRemains`.
    - It writes nothing to `paymentAccess`.
    - When an admin decides to restore access, they use the existing explicit
      workflow, `adminReinstatePaymentAccess`, with its own `payment_reinstate`
      audit entry.
    - Until then, the existing daily job keeps the family locked and records
      `reason: awaiting_admin_reinstate` (existing `resolveAccessTransition`
      behaviour, unchanged).
  - **Unrelated suspension reasons are preserved.** The write-off never
    writes `paymentAccess.status` or `paymentAccess.reason`. Today
    `paymentAccess` holds a single `status` and a single `reason` string, and
    every reason is financial (`invoice_<status>`, `no_unpaid_invoices`,
    `awaiting_admin_reinstate`, admin reinstate notes). There is no list of
    reasons. See §11.9 for what happens if non-financial reasons are ever added.
  - *History:* the previous 2026-10-17 text had the write-off reinstate access
    in the same transaction. That is withdrawn.
- **Tests (later, if approved):**
  - U: `isUnpaidPaymentStatus("written_off") === false`;
  - U: the access computation ignores `written_off`;
  - E: a write-off of the family's last unpaid invoice leaves `paymentAccess`
    unchanged and returns `financialSuspensionReasonRemains: false`;
  - E: a write-off with other unpaid invoices returns
    `financialSuspensionReasonRemains: true`;
  - E: after the write-off, the next job run keeps a suspended family locked
    with `awaiting_admin_reinstate`;
  - E: only `adminReinstatePaymentAccess` restores access;
  - E: atomicity under a forced failure;
  - E: clients cannot set `written_off`;
  - U: a partial amount is rejected.

**Settlement record access — APPROVED 2026-10-17 (design only; rules need
separate approval).** Applies to the unified `billingSettlements` collection
(Settlement operations contract, rule 12), for both invoice and family-bill
records.
- **Admin:** may read settlement records needed for administration and audit.
- **Parent:** may read only settlements whose `parentId` is their own uid,
  meaning settlements for their own family's invoices and bills. The rule
  checks `resource.data.parentId == uid()`, the same ownership pattern as
  `payments`. Queries must filter by `parentId`.
- **Supervisor and student:** no access to settlement records.
- **Supervisor visibility — owner direction 2026-10-17.**
  - Existing invoice-read permissions are **not** changed as part of the
    billing implementation without a separate review. The current `payments`
    read rule (admin, owning parent, supervisor of the student) stays as it is.
  - The minimum access needed for authorized payment-proof review is preserved:
    a supervisor reviewing a proof must still read that invoice
    (`reviewPaymentProof`, §1).
  - General supervisor *reports* may show only a minimal settlement status
    (for example "settled", "written off" or "outstanding"). No amounts, no
    write-off reasons, no approver details. That report view is built from
    status values only and never reads `billingSettlements`.
  - Any future reduction of existing invoice-read permissions needs a separate
    compatibility review covering proof review, the supervisor payment list,
    and existing tests.
- No client writes. Records are never deleted.
- **Tests (later, E, isolated emulator only with an approved plan):**
  - the parent reads their own settlement and is denied another family's;
  - supervisors, students and teachers are denied;
  - an admin reads all;
  - all client writes are denied.

**Write-off reversal — APPROVED 2026-10-17 as a contract decision; required in
the first write-off release; implementation needs separate approval.**
- **Release requirement (rule 1).** The reversal ships in the **same release**
  as write-off. Neither invoice nor family-bill write-off is approved or
  released without it.
- **Operation:** a separate, explicit, audited, admin-only operation,
  *(proposed)* `adminReverseWriteOff`, covering both `entityType: invoice` and
  `entityType: family_bill`.
  - It requires authorization (`assertCallerIsAdmin`) and a non-empty,
    bounded, contact-info-guarded reason.
  - It is retry-safe through rule 6 (`stl_{requestId}`, fingerprint check).
- **Never deletes or overwrites** the original write-off record or its audit
  entry; both are kept permanently. In one transaction it:
  1. completes every validation of rule 6 before any write: idempotency
     record, entity state, linked child-invoice states, and the stored values
     of rule 13;
  2. verifies that the entity's `activeSettlementId` equals the write-off being
     reversed (rule 8), and for a family bill that every child's
     `activeSettlementId` equals it too;
  3. creates a **new** `billingSettlements` record with
     `operationType: reversal` and `relatesToSettlementId` set to the original
     write-off. No field of the original record is changed;
  4. returns the entity (and, for a family bill, every linked child invoice)
     from `written_off` to the recalculated unpaid status;
  5. clears `activeSettlementId`, increments `settlementSequence` and sets
     `lastSettlementId` on the entity (and the linked children);
  6. writes one audit entry with its deterministic id (rule 7).
- **Recalculation (current requirement, rule 13):**
  - The outstanding balance is recalculated from preserved data: invoice
    `amount` and `amountPaidConfirmed`; family bill `totalMinor` and lines.
  - The overdue state is recomputed from the entity's **stored** `dueDate` and
    **stored** `gracePeriodDaysAtIssue`, never from the current global setting.
    It uses the same status rule and Cairo calendar as the daily overdue job
    for that entity type.
  - For a family bill, the bill uses its stored values, and each linked child
    invoice uses its own stored values.
  - A record lacking a required stored value is refused, pending a future
    compatibility policy.
  - A client-supplied state is never accepted.
  - *Superseded history:* the previous text read the global
    `pricingDefaults.gracePeriodDays` at reversal time and returned the entity
    to `overdue` only after due date plus grace. Both are withdrawn: the first
    by rule 13, the second because it did not match the invoice status rule of
    the existing job.
- **Access (rule 10).** A reversal never reinstates and never suspends payment
  access directly. Suspension follows from the daily job. Restoring access
  stays the separate explicit `adminReinstatePaymentAccess` action.
- **After a reversal**, a later write-off is a new operation with a new id,
  new authorization and a new reason (rule 8). The reversed write-off and the
  reversal stay as history.
- *History:* the earlier draft stored reversals at
  `paymentSettlements/{paymentId}/reversals/{requestId}` and wrote
  `reversedAt` / `reversalId` onto the original settlement. Both are superseded
  by the immutable operation records above. The earlier "release gating —
  undecided" note is resolved by rule 1.
- **Tests (later, if approved):**
  - U: fingerprint replay and mismatch;
  - E: a retried reversal yields one record and one audit entry;
  - E: the original write-off record is byte-identical after a reversal;
  - U: status recomputation from the stored `dueDate` around the Cairo due-day
    boundary;
  - U: the stored `gracePeriodDaysAtIssue` is used even after the global setting
    changed;
  - E: a reversal is refused for a record without a stored snapshot;
  - E: a family-bill reversal recalculates each child from its own stored
    values;
  - E: same request id with a different reason is rejected, and nothing is
    written;
  - E: a forced failure mid-transaction leaves no record, status change or
    audit entry;
  - E: access is unchanged by a reversal;
  - E: a second reversal of the same write-off is refused;
  - E: write-off → reversal → write-off yields three records with
    `sequence` 1, 2, 3.

**Family-bill write-off — FUTURE (design only; not implemented). It ships only
together with its reversal (rule 1).**
- **Operation:** an explicit administrative settlement for a **fully** waived
  family bill, *(proposed)* `adminWriteOffFamilyBill`.
  - Admin-only; reason required; approver and time from the server.
  - Retry-safe through rule 6.
  - Partial write-offs of family bills are not supported.
- **Preconditions:**
  - The bill is active, not `cancelled`, and its `status` is `due` /
    `overdue`.
  - **Not** allowed while `reviewStatus: pending_review`. The pending proof
    must first be resolved (approved or rejected) through the existing
    authorized review workflow.
  - No linked child invoice is `paid`, `pending_review` or partially paid
    (§11.3). Otherwise the write-off is refused with a conflict code.
- **One transaction:**
  - Creates one `billingSettlements` record with `entityType: family_bill`,
    `entityId = familyBillId`, `operationType: write_off`,
    `affectedPaymentIds` listing **every** linked child invoice, and
    `childStatuses` (rule 4). *History:* the draft
    `familyBillSettlements/{billId}` is superseded.
  - Requires `activeSettlementId` to be absent on the bill and on every linked
    child invoice (rule 8). All checks of rule 6, including every child's
    state, complete before any write.
  - Moves the family bill to `status: written_off`, with the pointers of rule
    5.
  - Moves every linked child invoice to `status: written_off`, with the same
    `activeSettlementId` and `familyBillId` kept. Linked child invoices are
    **never** marked `paid`.
  - Writes one audit entry (rule 7) linking the bill, the settlement, every
    child invoice id, and the period.
  - Bill lines, amounts, proof history and `lastRejection` stay unchanged.
- **Consistency and links:**
  - The family bill, the settlement record, the child invoices and the audit
    entry all reference each other.
  - Reports show the bill and each line as written off, never paid.
- **No duplicate obligations:**
  - A written-off bill remains the single obligation for that family and
    period. Its status is terminal except through the audited reversal, which
    restores the same bill and never creates a new one.
  - The month issuer treats it as existing (item 5 rules) and never issues
    another bill.
  - The children's invoices are closed, so no second collectible obligation
    exists for any of them.
- **Distinct from cancel-and-reissue (item 5):**
  - Cancellation means "this bill was wrong" and is followed by a new revision.
  - Write-off means "this correct bill is waived" and is followed by no new
    bill.
  - A written-off bill cannot be cancelled or reissued.
  - A cancelled bill cannot be written off.
- **Reinstatement:** same rule as for invoices. It does not reinstate access.
  It returns `financialSuspensionReasonRemains`, and the admin uses
  `adminReinstatePaymentAccess` separately.
- **Reversal:** handled by `adminReverseWriteOff` with
  `entityType: family_bill` (see "Write-off reversal"). In one transaction it
  restores the bill and every invoice in the original record's
  `affectedPaymentIds`. It recalculates the bill from the bill's stored values
  and each child from its own stored `dueDate` / `gracePeriodDaysAtIssue`
  (rule 13). If any child lacks a required value, the whole reversal is
  refused; nothing is partially restored. It never reinstates access, and it
  ships in the same release (rule 1).
- **Tests (later, if approved):**
  - E: refusal while a proof is pending;
  - E: refusal with paid or partly paid lines;
  - E: atomic update of the bill, every child invoice and the settlement;
  - U: no linked invoice becomes `paid`;
  - E: the issuer never creates a second bill for the period;
  - E: a written-off bill cannot be cancelled or reissued;
  - E: access is unchanged by the write-off.

**Reporting requirement.** Report dimensions must show these as distinct:
- **paid** — `status: paid`, money confirmed;
- **written off / waived** — `status: written_off` with an active write-off
  (`activeSettlementId` set); never paid. A reversed write-off is history only
  and does not make an entity written off;
- **partially outstanding** — `reviewStatus: partial` or
  `amountPaidConfirmed > 0`, still `due` / `overdue`, no active write-off;
- **overdue** — `status: overdue`, which can combine with partially
  outstanding.

`billingReportDimensions` (Batch A) already separates overdue from partial,
but has no written-off state.

**Report mapping — APPROVED 2026-10-17 (future code change; not made now).**
- Adding `written_off` to the billing report mapping (*(proposed)*
  `BillingDueState.writtenOff`, from stored `status: "written_off"`) is
  approved. It happens only once settlement records and the server transition
  exist.
- The invoice/due state stays separate from the proof/review state.
- Neither a write-off nor an approved proof (`reviewStatus: approved`) is ever a
  successful payment. `isPaid` stays true only for stored `status: paid`.
- Until then, the current mapping reports an unrecognised `written_off` status
  as `unknown` (needs attention), never as paid.

**Legacy-data handling (unresolved).** Until a write-off path is separately
approved, the only reconciliation is the existing new-proof-then-approve flow.
Partially paid invoices stay blocked from family-bill linking.

Tests:
- U: classifier blocks partial invoices.
- E: after the remainder is approved, the next issue run treats the child as
  settled.
- E: no field of the original invoice changes during issuing.
- Later, if approved:
  - U/E: settlement idempotency (one record per operation; a retry with the
    same `requestId` creates nothing new);
  - U/E: refusal of `pending_review`;
  - U/E: original invoice fields unchanged and `status` never `paid`;
  - U/E: one audit entry per settlement;
  - U/E: the overdue job never suspends for a written-off invoice;
  - F: the report shows written off, distinct from paid, partially outstanding
    and overdue.

#### 7. Login account reactivation — APPROVED (2026-10-17)

- Re-enabling a login account alone (`users.isActive` back to `true`) is never a
  new admission and never resets billing eligibility. It never writes
  `admittedAt` or `unarchivedAt`.
- Login activation (`users.isActive`), student archival
  (`studentProfiles.lifecycle`) and payment suspension (`paymentAccess`) stay
  separate concepts, consistent with C14 / WA-15, which already forbids
  conflating them.

**Inspection.**
- Today `users.isActive` is toggled by admin client writes
  (`admin_remote_datasource_impl.dart`). Registration rejection also sets it to
  `false`. These writes store no server timestamp and no audit entry.
- `admitStudentToHalaqa` sets `isActive = true` when an admin admits. Only the
  admission itself (item 1), not the `isActive` write, may set `admittedAt`.

**Billing effect — owner direction (2026-10-17, second update).**
- Billing eligibility does **not** depend solely on whether the login account
  is enabled. `users.isActive` is not an eligibility input; §11.4 was updated
  to match.
- Eligibility uses the canonical admission/enrollment states (`admittedAt` or
  an approved resolution, plus `halaqat.studentIds` membership) and the
  archival lifecycle (`lifecycle`, `unarchivedAt`).
- Payment suspension and login deactivation never create an exemption and never
  reset billing dates.
- Unresolved admission stays non-billable until it is resolved (item 8).

*History:* the first 2026-10-17 text excluded students whose login was disabled
at issue time; that rule is withdrawn.

Tests (later):
- U: `isActive` false → true leaves `admittedAt` / `unarchivedAt` untouched and
  adds no delay.
- U: login disabled, otherwise eligible → billed.
- U: the eligibility function treats login, lifecycle and payment suspension
  independently.

#### 8. Resolving legacy admission dates — PROPOSED (design only; not approved for implementation)

**Owner direction (2026-10-17).**
- A dedicated admin workflow resolves students whose first admission date
  cannot be established reliably (item 1) or whose unarchive date is not
  reliable (item 2).
- Each resolution needs an explicit first billable month, a reason,
  server-recorded approver identity and time, and an audit entry.
- Unresolved students are never silently billed.
- The workflow stays design-only until separately approved.

**Proposed design.**
- Admin-only callable *(proposed)* `adminResolveBillingStart`:
  - `assertCallerIsAdmin`;
  - idempotent per admin request id.
- **Input:** `studentId`, `kind` (`admission` | `unarchive`),
  `firstBillablePeriodKey` (`yyyy-MM`), `reason`, `requestId`. Approver and
  time are never accepted from the client.
- **Validation:**
  - the student exists with `role == "student"`;
  - the period key is well formed;
  - the reason is non-empty, bounded and contact-info guarded;
  - `kind: admission` only when `admittedAt` is absent and no resolution exists;
  - `kind: unarchive` only when the student is currently active, has a
    `user_archive` history, and lacks a reliable `unarchivedAt`.
- **Record:** *(proposed)* `billingStartResolutions/{studentId}_{kind}`.
  - Server-written only; read by admins only.
  - Fields: `studentId`, `kind`, `firstBillablePeriodKey`, `reason`,
    `resolvedBy` (from the request), `resolvedAt` (server clock), `requestId`,
    and `evidenceSummary`. The summary holds class codes from the read-only
    audit (item 1), never raw personal data.
  - The admin enters a **billing month**, not a fabricated admission
    timestamp. `admittedAt` is never written by this workflow. Billing start =
    the later of the resolved month and the months derived from item 1 and
    item 2.
- **Audit:** one entry per resolution, *(proposed)* action
  `billing_start_resolve`. A correction is a new audited resolution that
  supersedes the old one; the old record is kept as history.
- **Report:** students without `admittedAt` and without a resolution appear as
  "admission date unresolved" and are excluded from issuing.
- **Use of legacy unarchive entries:** an entry that passes the item 2 test is
  supporting evidence only. It is shown in `evidenceSummary` and applied only
  through an explicit admin resolution here, never by migration and never
  implicitly at issue time. *History:* the earlier text also allowed a
  separately approved migration; withdrawn on 2026-10-17 (item 2, evidential
  weight).

**Tests (later, if approved).**
- U: validation of each input.
- U: approver and time are always server values.
- U: billing start = the later applicable month.
- E: a non-admin or deactivated admin is denied.
- E: a retry yields one record and one audit entry.
- E: clients cannot write resolution records.
- U: an unresolved student is never issued a bill.

### 11.9 Remaining ambiguities (updated 2026-10-17, seventh update)

Resolved on 2026-10-17 and kept here as history:
- reactivation timestamp → server-written `unarchivedAt`; WA-15 amendment
  approved as design (item 2);
- login reactivation never restarts billing, and login is not an eligibility
  input (item 7, §11.4);
- exemptions are admin-only with persisted evidence, created only through a
  server callable (§11.1);
- the audit start date is not guessed; account creation, membership and login
  are never admission evidence (item 1);
- legacy admission and unarchive dates are resolved only through an audited
  admin workflow (item 8, design only);
- a write-off is a separate settlement record, never paid (item 6, design
  only);
- full write-off uses the distinct invoice status `written_off`; partial
  write-offs are not supported (item 6);
- settlement records: admin all, parent own only, no supervisor or student
  access (item 6);
- legacy unarchive entries are supporting evidence only; ambiguous cases stay
  unresolved until reconciled (item 2);
- every implementation stage needs separate approval; Rules work also needs an
  approved isolated test plan (§11.8 header);
- `written_off` will be added to the report mapping once the server transition
  exists; neither a write-off nor an approved proof is ever a payment (item 6).

Also resolved on 2026-10-17 (fourth update):
- a write-off never reinstates access; reinstatement stays the separate
  `adminReinstatePaymentAccess` action, and the write-off reports whether the
  financial reason remains (item 6);
- existing supervisor invoice-read permissions stay unchanged without a
  separate compatibility review; supervisor reports show a minimal status only
  (item 6);
- write-off reversal is designed as a future audited operation that preserves
  history (item 6);
- a full family-bill write-off is supported as a design, distinct from
  cancel-and-reissue (item 6).

Also resolved on 2026-10-17 (fifth update; contract decisions only):
- reversal **must** ship in the same release as any write-off. Invoice and
  family-bill write-off are never approved or released without it (item 6,
  Settlement operations contract, rule 1);
- settlement identity: one immutable record per operation,
  `billingSettlements/stl_{requestId}`, allowing write-off → reversal → a later
  write-off. Operations link to each other through `relatesToSettlementId`;
  retries replay the result through a `requestFingerprint` check; there is one
  deterministic audit entry per operation; a new write-off needs no active
  write-off plus fresh authorization (rules 3–9);
- one unified proposed collection, `billingSettlements`, for invoices and
  family bills, with `entityType`, `entityId`, `affectedPaymentIds` and
  `childStatuses`. It supersedes the draft names `paymentSettlements` and
  `familyBillSettlements`. Its rules need separate design and approval
  (rule 12).

Also resolved on 2026-10-17 (sixth update; contract decisions only):
- grace period for recalculation: each issued invoice and family bill stores
  its authoritative `dueDate` and `gracePeriodDaysAtIssue`; reversal uses the
  stored values, never the current global setting; no backfill of legacy
  records (Settlement operations contract, rule 13);
- atomicity and idempotency: all validation (request id, entity state, active
  write-off, every linked child) happens before any write; the operation
  record, status and pointer changes, and the audit entry commit together or
  not at all; same id with the same canonical request replays; same id with a
  different canonical request is rejected; new operations use new ids (rule 6).

Also resolved on 2026-10-17 (seventh update; contract decisions only):
- **legacy compatibility:**
  - write-off and reversal refuse records without the required authoritative
    values until a compatibility policy is separately approved and
    implemented;
  - that policy must be defined before the first write-off release;
  - no historical values are invented or backfilled, and no existing amount,
    due date, grace period or status is silently changed;
  - legacy partially paid invoices need reconciliation before any linking or
    write-off (rule 13);
- **overdue status:** `overdue` starts on the Cairo calendar due date for
  invoices and family bills alike. The grace period governs only the access
  stages, and `overdue` is not immediate suspension (§2 decision 5, §6,
  rule 13). The §6 "due date + grace" row is superseded;
- **family-bill and child dates:**
  - a pre-existing invoice whose due date differs from the bill's is the
    conflict `invoice_due_date_mismatch`; it is never normalized or linked
    automatically (§11.3);
  - newly created child invoices take the bill's `dueDate` and snapshot in
    the same transaction;
  - linked invoices are settled only through the family-bill operation
    (rule 13, rule 8).

Pending prerequisites (decided requirements, not open questions):
- **Legacy compatibility policy.** Its content must be defined and approved
  before the first write-off release (rule 13). Until then, write-off and
  reversal refuse records without stored values, which includes all existing
  invoices.
- **Daily job alignment.** Using the stored `gracePeriodDaysAtIssue` in the
  daily job is a separate implementation stage awaiting approval. The job is
  unchanged by this contract.

Still open:
1. **`written_off` on family bills.** `FamilyBillContract` (Batch A) lists the
   statuses `due`, `overdue`, `paid` and `cancelled`. Adding `written_off`
   there, and to `billingReportDimensions`, is a code follow-up for the
   approved write-off stage. It is not done now.
2. **Future non-financial suspension reasons** (item 6). This is a separate,
   future concern, not part of the billing contract work. `paymentAccess` has
   one `reason` string, and `adminReinstatePaymentAccess` overwrites `status`
   and `reason`. If non-financial suspension reasons are ever introduced, that
   model and the reinstatement workflow must change so one reason cannot clear
   another. Not needed today, because every current reason is financial.
3. **Implementation approvals** (§11.8 header). None are granted. Pending
   stages:
   - the daily-job snapshot alignment;
   - the legacy compatibility policy and its implementation;
   - the WA-15 amendment (code and test);
   - the `admittedAt` and `unarchivedAt` writes;
   - the exemption callable and the `pricingRules` rules hardening;
   - the resolution workflow (item 8);
   - the read-only audit;
   - the write-off release: `adminSettleLegacyInvoice`, `adminWriteOffFamilyBill`
     and `adminReverseWriteOff` together, with `written_off`;
   - the `billingSettlements` rules;
   - the report mapping change.
