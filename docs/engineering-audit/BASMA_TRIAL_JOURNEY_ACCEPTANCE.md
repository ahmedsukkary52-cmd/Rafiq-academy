# BASMA — Trial Journey Acceptance (Product Phase)

**Date:** 2026-11-20 (Flutter UI verification pass)  
**Branch / HEAD inspected:** `unify/basma-v1` @ `8ce64fe` (dirty working tree preserved; no git mutations)  
**Prior security campaign:** PASS WITH GAPS — **not re-run.**  
**Backend Emulator campaign (prior pass):** **142/142** Node tests on `demo-rafiq-rules` — **not re-run** (no regression reason).

---

## Evidence layers (do not conflate)

| Layer | Status this program |
|-------|---------------------|
| Backend Emulator (Functions/Firestore/Storage cores + HTTP callables) | **PASS** — 142 tests (prior pass) |
| Flutter widget / fake-bloc UI | **PASS** for scoped surfaces below (this pass + prior +15) |
| Flutter ↔ Emulator `integration_test` | **BLOCKED** — unsafe without Firebase init change (`INTEGRATION_TEST_PREREQUISITES.md`) |
| Physical device | **NOT TESTED** |
| Cloud / production project | **BLOCKED** — owner / Blaze / academy Google account |

---

## 1. Already verified — intentionally not repeated

- Payment lifecycle Emulator: Admin invoice → parent proof → supervisor approve → paid.
- Messaging callable Emulator journeys.
- Supervisor-scoped backend ops + B14 meeting-link policy cores.
- Attendance / recitation (evaluation) PH02 cores.
- Security Closure PASS WITH GAPS.
- Prior product UI fixes (+15 Flutter): issue-invoice UI, teacher group inbox, student no-halaqa card, payment banner copy.

## 2. UI areas inspected (this bounded pass)

| Area | What was checked | Outcome |
|------|------------------|---------|
| Parent payments (`ParentSubscriptionsPage`) | Error/retry, empty month, due / pending-review / paid cards, filter | Widget coverage added; **no product defect** |
| Teacher attendance | Empty roster, load error/retry, save CTA gated until complete; pending-absence loading layout | **1 layout defect fixed** |
| Teacher pending-absence strip | Loading skeleton inside Column | Defect + regression |
| Supervisor meeting-link UI | Existing B14 tests: add remains **disabled** by default | Re-confirmed **pass** |
| Supervisor payment review UI | Existing page/bloc tests (not re-expanded) | Already covered |
| Recitation evaluation UI | Spot-check; gate/usecase tests exist; no new high-impact UI defect found | No code change |

**Not built:** Flutter ↔ Emulator bootstrap (explicitly out of scope / unsafe).

## 3. Confirmed defect fixed

| ID | User impact | Fix |
|----|-------------|-----|
| P-ATT-01 | Opening Teacher Attendance while pending استئذان requests load could throw **unbounded ListView height** (layout failure / yellow-black overflow in debug) | `TeacherRosterRowsSkeleton.shrinkWrap` + pending section uses `shrinkWrap: true` |

No other high-impact local UI defect confirmed in this pass.

## 4. New / focused tests and exact results

```text
flutter test \
  test/features/parent/parent_subscriptions_page_test.dart \
  test/features/teacher/teacher_attendance_page_test.dart \
  test/features/teacher/teacher_pending_absence_section_test.dart \
  test/features/supervisor/supervisor_meeting_link_test.dart
→ All tests passed! (+20)
```

Files added/updated:

- `test/features/parent/parent_subscriptions_page_test.dart` (new)
- `test/features/teacher/teacher_attendance_page_test.dart` (new)
- `test/features/teacher/teacher_pending_absence_section_test.dart` (new)
- `lib/features/teacher/presentation/widgets/teacher_loading_skeletons.dart`
- `lib/features/teacher/presentation/widgets/teacher_pending_absence_section.dart`

**Not re-run:** 142 Emulator Node suites; full Flutter suite.

## 5. Journey acceptance table

Statuses: `PASS` | `FAIL` | `PARTIAL` | `NOT TESTED` | `BLOCKED`

| Journey | Navigation/UI | Backend persistence | Cross-role result | Permissions | Error handling | Automated Emulator E2E | Flutter widget | Device | Cloud | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Student | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL (no-halaqa) | NOT TESTED | BLOCKED | **PARTIAL** |
| Teacher | PARTIAL → improved attendance empty/error/save gate | PASS | PARTIAL | PASS (cores) | PASS | PASS (cores) | PARTIAL (+attendance UI) | NOT TESTED | BLOCKED | **PARTIAL** |
| Parent | PARTIAL → payments list states widget-verified | PASS | PASS (backend) | PASS (HTTP) | PASS | PASS (backend) | PARTIAL (+subscriptions UI) | NOT TESTED | BLOCKED | **PARTIAL** |
| Payment + approval | PASS (Admin issue UI + Parent list states) | PASS | PASS | PASS | PASS | **PASS** | PARTIAL (no Flutter↔Emulator chain) | NOT TESTED | BLOCKED | **PARTIAL** |
| Messaging | PARTIAL → teacher/supervisor Plus related-people + attachment path fix | PASS | PASS | PASS | PASS | **PASS** | PARTIAL (+chat audit 60 Flutter) | NOT TESTED | BLOCKED | **PARTIAL** — see `BASMA_CHAT_SYSTEM_AUDIT.md` (**PASS WITH GAPS**) |
| Supervisor | PARTIAL (meeting-link add stays off; payment review UI exists) | PASS | PASS | PASS | PASS | **PASS** | PARTIAL (meeting-link tests) | NOT TESTED | BLOCKED | **PARTIAL** |
| Attendance / recitation | PARTIAL (attendance UI states + layout fix; eval UI not newly widget-covered) | PASS | PASS | PASS | PASS | **PASS** | PARTIAL | NOT TESTED | BLOCKED | **PARTIAL** |

Overall journey remains **PARTIAL** until device and/or safe Flutter↔Emulator integration exist. Backend PASS alone is not overall PASS.

## 6. Remaining external blockers

| Blocker | Cause |
|---------|-------|
| Academy Google account / project ownership | Required for Cloud |
| Blaze / billing | Owner |
| Deploy Rules / Indexes / Functions | Cloud pause |
| Flutter ↔ Emulator integration_test | Would require Firebase init / entry-point change — unsafe per prerequisites |
| Physical device smoke (RB-18) | Supervised lab; no destructive actions |
| Upload keystore / app IDs (RB-17) | Owner |
| D5 suspension shell | Owner product decision |

## 7. Trial-preparation readiness

**Verdict: NOT ready for Trial preparation.**

**Local coding safe stopping point:** Important locally testable Parent payment UI states, Teacher attendance empty/error/save-gate UI, and Supervisor meeting-link disablement are checked; the one confirmed high-impact attendance layout defect is fixed and regression-tested. Remaining gaps require **academy/owner approval**, **Cloud**, or **supervised device access** — not another broad review campaign.

---

## Appendix — prior Emulator evidence (unchanged)

```text
# Payment HTTP lifecycle — 10/10
# Messaging + B14 — 23/23
# PH02 + proof-cycle — 109/109
# Total Node Emulator — 142/142
# Prior Flutter UI regressions — +15
```
