# BASMA D0 Security Test Matrix

**Project under test:** repo rules via emulator `demo-rafiq-rules` only.  
**Does not prove** live `rafiq-academy` security (BASMA-100 deploy gate).

Suite: `rules_test/d0_trial_isolation.firestore.rules.test.mjs`  
Command: `npx firebase emulators:exec --project demo-rafiq-rules --only firestore "npm --prefix rules_test run test:d0:isolation"`  
**Result (2026-11-16):** 18 passed, 0 failed.

Storage suite: `rules_test/d0_payment_proof.storage.rules.test.mjs`  
Command: `npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage "npm --prefix rules_test run test:d0:storage"`  
**Result:** 4 passed, 0 failed.

| Role | Resource | Operation | Expected | Test | Result |
|------|----------|-----------|----------|------|--------|
| Student | `users` collection | list | DENY | D0 student cannot list all users | PASS |
| Student | `studentProfiles` | list | DENY | D0 student cannot list studentProfiles | PASS |
| Student | `studentProfiles/otherHalaqa` | get | DENY | D0 student cannot get another halaqa student profile | PASS |
| Student | `studentProfiles` roster mate | get | ALLOW | D0 student may get roster-mate profile | PASS |
| Student | `payments` own/other | get | DENY both | D0 student cannot read another family payment | PASS |
| Student | `userPrivate/admin` | get | DENY | D0 student cannot read admin userPrivate | PASS |
| Parent | `userPrivate/admin` | get | DENY | D0 parent cannot read admin userPrivate | PASS |
| Parent | `parentProfiles/other` | get | DENY | D0 parent cannot read another parent profile graph | PASS |
| Parent | `payments` own / other | get | ALLOW / DENY | D0 parent can read own payment and not other | PASS |
| Parent | `academySettings/paymentPublic` | get | ALLOW | D0 parent can read paymentPublic | PASS |
| Parent | `academySettings/main`, `pricingRules` | get | DENY | same test | PASS |
| Teacher | `studentProfiles` | list | DENY | D0 teacher cannot list studentProfiles | PASS |
| Teacher | roster / foreign student | get | ALLOW / DENY | D0 teacher of h1 … | PASS |
| Teacher | `pricingRules`, `academySettings` | write | DENY | D0 teacher cannot write … | PASS |
| Teacher | `payments` | update | DENY | D0 teacher cannot update payment docs | PASS |
| Supervisor | supervised payment | get / update | ALLOW / DENY | D0 supervisor can read … not write | PASS |
| Admin | `pricingRules` | read/write | ALLOW | D0 admin can read/write pricingRules | PASS |
| Admin | `paymentPublic` | write allow-list | ALLOW strict / DENY extra keys | D0 admin paymentPublic write is field-bounded | PASS |
| Admin | `userPrivate` | get / list | ALLOW get / DENY list | D0 admin may get userPrivate; nobody lists | PASS |
| Parent | payment proof object | create | ALLOW | D0 parent may create own payment proof jpeg | PASS |
| Other parent | same proof | read/create | DENY | D0 other parent cannot read or overwrite | PASS |
| Student/Teacher | payment proof | read | DENY | D0 student and teacher cannot read | PASS |
| Admin | payment proof | read / update / delete | ALLOW read / DENY mutate | D0 admin may read proof; client update/delete denied | PASS |

## Classification vs Trial

| Trial live finding | Repo emulator | Meaning |
|--------------------|---------------|---------|
| Parent read admin `userPrivate` | DENY (PASS) | **Confirmed Issue remains on cloud only** until Rules deploy |
| Student broad user list | DENY list (PASS) | Same |
| Student read other payment | DENY (PASS) | Same |
