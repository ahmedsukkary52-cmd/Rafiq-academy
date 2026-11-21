# BASMA Integration Audit (Stage A)

**Date:** 2026-11-16  
**Evidence:** Router source + Trial device/REST ([ACADEMY_TRIAL_RUNTIME_DIAGNOSIS.md](../../_backups/ACADEMY_TRIAL_RUNTIME_DIAGNOSIS.md), [ACADEMY_TRIAL_PRESHARE_DECISION.md](../../_backups/ACADEMY_TRIAL_PRESHARE_DECISION.md)).  
**Cloud Functions on `rafiq-academy`:** unpublished (Confirmed).

---

## 1. Connection checklist legend

For each journey: Route → UI → State → UseCase → Repo → Datasource → Backend → AuthZ → Mapping → Loading/Empty/Error → Cross-screen update.

Statuses: **PASS** (runtime evidence) | **PARTIAL** | **FAIL** | **BLOCKED** | **NOT TESTED**

---

## 2. Role journeys (Trial cloud)

### Admin

| Journey | Status | Notes |
|---------|--------|-------|
| Login | PASS | Device + REST |
| Home stats / students list | PASS | Live + seed halaqat |
| Complaints widget | FAIL | Index FAILED_PRECONDITION |
| Finance summary | FAIL | Aggregate index |
| Create account / staff ops | BLOCKED | Callable 404 |
| Chat inbox send | BLOCKED | Callable 404; read may work |

### Supervisor

| Journey | Status | Notes |
|---------|--------|-------|
| Login + home | PASS | |
| At-risk / absence tile | PARTIAL/FAIL | Index failure → unreliable 0 |
| Writes / enrollment callables | BLOCKED | 404 |

### Teacher

| Journey | Status | Notes |
|---------|--------|-------|
| Login + halaqa home | PASS | cloudtrial morning |
| Cover query background | FAIL (non-blocking) | Index |
| Record attendance / eval / chat send | BLOCKED | 404 |

### Parent

| Journey | Status | Notes |
|---------|--------|-------|
| Login + children | PASS | |
| Payments month invoice | PASS after seed patch | periodKey 2026-11 |
| Child schedule/halaqat callables | BLOCKED | 404 |
| Send chat | BLOCKED | 404 |

### Student

| Journey | Status | Notes |
|---------|--------|-------|
| Login + home (01/02) | PASS | |
| Homework display | PASS | 02 patched |
| Complete homework | BLOCKED | 404 |
| Mushaf deep paths | NOT TESTED | BASMA-018 protected |

---

## 3. Cross-role data integrity

- Seed graph for `cloudtrial-*` is coherent for read demos (Confirmed).
- Live rules allow trial roles to observe non-trial academy data (**Security Confirmed**) — integration “isolation” **FAIL** on cloud until rules deploy.

---

## 4. Recommendations

1. Treat cloud Trial as **read-demo** only until Functions+Rules+Indexes owner-approved.
2. Emulator full cross-role write journeys remain the correct verification bed for Stage D logic fixes.

---

## 5. Unresolved questions

- Assistant teacher cover UX end-to-end.
- Payment proof upload on Trial (Storage rules live unknown).
