# BASMA G0 — Cloud & Production Owner Decisions & Verification

**Date:** 2026-11-19  
**Phase:** G0 (evidence gathering / decision preparation only)  
**Branch:** `unify/basma-v1` @ `8ce64fe97440c33acefaf1e140022ddbe0075ab5`  
**Policy:** **No** deploy, billing change, live Firebase mutation, index create, keystore creation, project create/switch, ID selection, store publish, source/config edits, or Git mutations.

**Companion evidence (do not overwrite):**  
`docs/production/BASMA_RELEASE_BLOCKERS.md` · `BASMA_RB16_BUILD_CONFIG_REVIEW.md` · `BASMA_RB17_ANDROID_SIGNING_AUDIT.md` · `BASMA_RB02_RECITATION_INDEX_LOCAL_VERIFICATION.md` · `BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` (§13–§14 / BASMA-101) · `docs/production/RELEASE_PLATFORM_SETUP.md` · `BASMA_MASTER_ISSUE_REGISTER.md`

---

## Evidence classification legend

| Tag | Meaning |
|-----|---------|
| **VERIFIED** | Confirmed with named command/file evidence this pass or cited prior report |
| **LOCAL ONLY** | Present in repo / WT / emulator; not proven on Cloud |
| **UNKNOWN** | Not inspected or inconclusive |
| **OWNER DECISION** | Requires explicit owner choice / approval |

---

## 1. Executive summary

BASMA is **not** production-Cloud-ready. Local architecture, emulator suites, and fail-closed flavor guards are substantial; **live** Rules/Indexes/Functions/Storage on a **final** Firebase project, billing (Blaze), production app IDs, signing material, and store gates remain open.

| Area | Snapshot |
|------|----------|
| Confirmed Firebase project in CLI account | **`rafiq-academy` only** among BASMA aliases (**VERIFIED** via `firebase projects:list`) |
| Alias `rafiq-academy-staging` / `rafiq-academy-prod` | Referenced in `.firebaserc` / docs — **not** present in CLI project list → treat as **non-existent aliases** until owner creates/selects real IDs (**OWNER DECISION**) |
| Final production project | **OWNER DECISION** — owner has indicated a **different** project may become production later; **do not** assume `rafiq-academy` is final (RB-09) |
| Cloud Functions on `rafiq-academy` | Historically **unpublished** / callables 404; Blaze gated (BASMA-102) — **LOCAL ONLY** code + emulator; Cloud deploy **UNKNOWN** this pass (no new live list) |
| Indexes | Local JSON has required composites; device **FAILED_PRECONDITION** proves complaints index missing on live `rafiq-academy` (BASMA-101) |
| Android/iOS prod binaries | Config reviewed (RB-16/17); prod Firebase files & upload keystore **absent**; IDs provisional |
| Device lab | G1 **PARTIAL** (RB-18 still OPEN) |

**Bottom line:** G0 prepares an owner decision pack. Nothing in this phase authorizes deploy or signing-key creation.

---

## 2. Repository / Git state (this pass)

| Item | Value | Class |
|------|--------|-------|
| Branch | `unify/basma-v1` | **VERIFIED** |
| HEAD | `8ce64fe97440c33acefaf1e140022ddbe0075ab5` | **VERIFIED** (matches expected) |
| Staged | `0` | **VERIFIED** |
| Tracked modified | `196` | **VERIFIED** |
| Untracked | `69` | **VERIFIED** |
| G1 report present | `docs/engineering-audit/BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` incl. §14 BASMA-101 | **VERIFIED** |
| Mutations this phase | **None** except creating this G0 document | Policy |

Working-tree dirt (indexes WT + lib/tests/Functions/etc.) is **preserved**; not cleaned or staged.

---

## 3. Firebase project configuration inventory

### 3.1 Aliases vs existence

| Alias / ID | Where referenced | Exists in `firebase projects:list` (this account)? | Class |
|------------|------------------|------------------------------------------------------|--------|
| `rafiq-academy` | `.firebaserc` `dev`, `firebase.json` flutter defaults, `lib/firebase_options.dart`, root `google-services.json`, trial flavor, G1 Logcat | **Yes** (current) · project number `201515597019` | **VERIFIED** |
| `rafiq-academy-staging` | `.firebaserc` `staging`, RELEASE_PLATFORM_SETUP | **No** | **LOCAL ONLY** reference / **OWNER DECISION** to create |
| `rafiq-academy-prod` | `.firebaserc` `prod`, RELEASE_PLATFORM_SETUP assumed id | **No** | **LOCAL ONLY** reference / **OWNER DECISION** to create or rename |
| `demo-rafiq-rules` | Emulator-only / fake `google-services` for local flavors | N/A (emulator demo id) | **LOCAL ONLY** |
| Other owner-intended prod project | Owner verbal intent (different from current trial) | **Not identified** in CLI list under a BASMA name | **UNKNOWN** / **OWNER DECISION** |

**Do not assume** an alias string means a Firebase project exists.

### 3.2 Configuration files → project

| File / surface | Points to | Notes |
|----------------|-----------|--------|
| `.firebaserc` | aliases → `rafiq-academy` / `*-staging` / `*-prod` | Staging/prod targets not in CLI list |
| `firebase.json` | Flutter default `projectId: rafiq-academy`; rules/indexes/storage/functions paths | **LOCAL ONLY** wiring |
| `lib/firebase_options.dart` | `rafiq-academy` Android + iOS (`com.example.rafiqAcademy`) | **VERIFIED** file content |
| `android/app/google-services.json` | `rafiq-academy` · `com.example.rafiq_academy` | Real project config |
| `android/app/src/dev/google-services.json` | `demo-rafiq-rules` | Emulator fake |
| `android/app/src/staging/google-services.json` | `demo-rafiq-rules` · `com.basmaacademy.app.staging` | Emulator fake |
| `android/app/src/prod/google-services.json` | — | **Missing** |
| iOS `GoogleService-Info.plist` | — | **Absent** by design (Dart options) |
| `lib/core/firebase/app_flavor.dart` | Trial → must use `rafiq-academy`; prod **refuses** start until configured; local flavors emulator-only | Fail-closed **VERIFIED** in source |

### 3.3 Flavor ↔ Firebase intent

| Flavor | applicationId (Android) | Intended Firebase | Class |
|--------|-------------------------|-------------------|--------|
| `dev` | `com.example.rafiq_academy` (+ optional `.review`) | Emulator `demo-rafiq-rules` only | Guarded |
| `staging` | `com.basmaacademy.app.staging` | Emulator only | Guarded |
| `trial` | **Shares** `com.example.rafiq_academy` with dev | Live **`rafiq-academy`** (no emulator) | **VERIFIED** design |
| `prod` | Provisional `com.basmaacademy.app` | Final prod project — **not configured** | Blocks runnable prod Cloud |

**dev/trial ID collision:** cannot install side-by-side (RB-17). Product decision if distinct trial ID ever required — **OWNER DECISION** (non-blocking for local emulator work).

### 3.4 Resources that must be recreated/verified on the **final** project

When the owner names the final project, each of the following must be provisioned/verified **there** (not assumed copied from `rafiq-academy`):

1. Android apps for prod (and staging if used) matching final applicationIds  
2. iOS apps matching final bundle IDs  
3. `google-services.json` / Dart `FirebaseOptions` for prod (and staging if real)  
4. Firestore Rules + Indexes deploy  
5. Storage Rules deploy  
6. Cloud Functions (Node 22) + secrets + region `europe-west1` (+ documented `us-central1` exceptions RB-10)  
7. Auth providers / admin provisioning operators  
8. FCM / APNs credentials  
9. Billing Blaze + budgets  
10. SHA certificates from upload / Play App Signing keys  

---

## 4. Cloud readiness by service

### 4.1 Firestore Rules

| Layer | State | Class |
|-------|--------|-------|
| `firestore.rules` in repo | Present (~52 KB) | **LOCAL ONLY** |
| Emulator / rules tests | Extensive historical PASS (register: Firestore 276, D0 isolation, R1, etc.) | **LOCAL ONLY** |
| Live Rules on `rafiq-academy` | Historically over-read / gap (BASMA-100) — emulator ≠ Cloud | **UNKNOWN** exact current Cloud text; gap **OWNER**-gated |
| Live Rules on final prod project | No prod project confirmed | **UNKNOWN** |

**RB-03** remains **OPEN**.

### 4.2 Firestore Indexes

**WT inventory:** `firestore.indexes.json` ≈ **46** composites (**LOCAL ONLY**).  
**HEAD vs WT:** WT adds **+24 lines** — notably:

- `recitationRecords`: `halaqaId ASC` + `date DESC` (**RB-02**)  
- `payments`: `status` + `amount`; `status` + `amountPaidConfirmed` (finance aggregates; co-located with RB-02 work — out of RB-02 closure scope)

| Index need | In HEAD? | In WT? | Cloud |
|------------|----------|--------|-------|
| Complaints `status ASC` + `createdAt DESC` (BASMA-101) | **Yes** | **Yes** | **Missing/unavailable** on live `rafiq-academy` (device **FAILED_PRECONDITION**) |
| Recitation `halaqaId ASC` + `date DESC` (RB-02) | **No** (added in WT) | **Yes** | **NOT VERIFIED** / PENDING |
| Payments status+amount / amountPaidConfirmed | **No** (WT) | **Yes** | **NOT VERIFIED**; finance UI `—` on device is **symptom**, cause **not** proven same session |
| Other composites in JSON | Mixed HEAD | Present | **UNKNOWN** on Cloud |

**Separation required:**

1. Committed in Git (HEAD) — includes complaints status+createdAt  
2. Only in working tree — RB-02 DESC + payment aggregate indexes  
3. Known in Cloud — **none newly verified** this pass; complaints proven **absent** on `rafiq-academy` by runtime  
4. Unknown Cloud — everything else  

**RB-02** remains **OPEN**. Do **not** claim local JSON = deployed.

### 4.3 Cloud Storage

| Layer | State | Class |
|-------|--------|-------|
| `storage.rules` | Present (~23 KB) | **LOCAL ONLY** |
| Emulator storage tests | Historical PASS (register) | **LOCAL ONLY** |
| Production deploy / historical data verify | Not done | **UNKNOWN** / **OWNER DECISION** |

**RB-04** remains **OPEN**.

### 4.4 Cloud Functions

| Topic | Evidence | Class |
|-------|----------|--------|
| Source | `functions/` Node **22**; client region **`europe-west1`** | **LOCAL ONLY** |
| Paymob | Commented / quarantined — **do not activate** | Policy |
| RB-10 | Two non-client paths on `us-central1` — CLOSED (documented) | Documented |
| Emulator | Multiple suites historically green (PH02, P0, chat, billing, meeting-link, …) | **LOCAL ONLY** |
| Secrets / `PRODUCTION_BACKEND_ENABLED` | Fail-closed until owner unlock (RB-07) | **OWNER DECISION** |
| Live deploy on `rafiq-academy` | Register: `functions:list` empty / callables 404; Blaze/`billingEnabled:false` (BASMA-102) | Historical **VERIFIED** claim in register; **not re-probed** this pass |
| Final project deploy | Blocked on RB-09 + RB-06 | **OWNER DECISION** |

**RB-05 / RB-06 / RB-07 / RB-08** remain **OPEN**.

### 4.5 Authentication & provisioning

| Topic | State | Class |
|-------|--------|-------|
| Model | Admin-controlled provisioning (locked product direction) | Documented |
| Personal email for every member | **Not** required — preserve | Product constraint |
| Prod Auth verification | Outstanding (RB-15 / BASMA-004) | **OWNER** + engineering after Cloud |
| Trial live Auth | App runs against `rafiq-academy` as trial | **VERIFIED** on device (G1) |

### 4.6 Billing / Blaze

Functions, scheduled jobs, and managed exports need **Blaze**. Checklist referenced in RELEASE_PLATFORM_SETUP / billing docs. **No** plan change this pass.

**RB-06 / BASMA-016** — **OWNER DECISION**.

---

## 5. Android / iOS production readiness

Cross-link: full detail in **RB-16** and **RB-17** reports (not duplicated here).

### 5.1 Android

| Topic | State | Class |
|-------|--------|-------|
| Version | `1.0.0+2` / `kAppBuildNumber = 2` | **VERIFIED** |
| Flavors | dev / staging / trial (WT) / prod | **LOCAL ONLY** (trial in WT) |
| Prod applicationId | Provisional `com.basmaacademy.app` | **OWNER DECISION** before keystore/Play |
| Prod `google-services.json` | Missing | Blocks prod Cloud binary |
| Upload signing | Fail-closed without key; Codemagic `basma_upload_key` name-only | **READY FOR OWNER KEY CREATION** after ID confirm (RB-17) |
| Keystore creation this phase | **Forbidden** until prod applicationId approved | Policy |
| R8 minify | Not enabled | Optional later |
| Play App Signing | Required at first upload | **OWNER DECISION** |

### 5.2 iOS

| Topic | State | Class |
|-------|--------|-------|
| Dev bundle | `com.example.rafiqAcademy` | Matches firebase_options |
| Prod bundle | Provisional `com.basmaacademy.app` | **OWNER DECISION** |
| `DEVELOPMENT_TEAM` / provisioning | Not set in reviewed pbxproj | **OWNER** / Apple |
| APNs | `aps-environment` development in entitlements | Prod export path undocumented as proven |
| Archive / Codemagic `ios-unsigned-check` | Not run on this Windows host | **UNKNOWN** / needs macOS |
| iPad support | Device family includes iPad in docs — confirm | **OWNER DECISION** |

**RB-16 / RB-17** remain **OPEN**.

---

## 6. Runtime findings (incl. BASMA-101)

### 6.1 Confirmed — complaints index (BASMA-101 slice)

| Item | Value |
|------|--------|
| Device | SM-A037F · trial/debug package · project `rafiq-academy` |
| Query | `complaints` · `whereIn status ∈ {open, in_progress}` · `orderBy createdAt DESC` · `limit 20` |
| Source | `AdminRemoteDatasourceImpl.getComplaints()` |
| Required index | `status ASC` + `createdAt DESC` (COLLECTION) |
| In local JSON / HEAD | **Yes** |
| Cloud | Runtime **FAILED_PRECONDITION** — index required → treat as **not available** on live project |
| Confidence | **Confirmed** (G1 §14) |

### 6.2 Related symptoms (cause not fully isolated this phase)

| Symptom | Class |
|---------|--------|
| Admin Home banner “unable to load some data”; financial tiles `—` | **Observed** on device; may include payments aggregate indexes / Functions 404 / Rules — **not** proven identical to complaints line |
| Historical trial over-reads (BASMA-100) | Confirmed historically; Cloud Rules deploy pending |
| Callables 404 when Functions unpublished (BASMA-102) | Historical register evidence |

### 6.3 Do not deploy from G0

No index, Rules, Storage, or Functions deploy is authorized by this document.

---

## 7. Owner decision register

| ID | Topic | Current evidence | Options (if any) | Implications | Owner approval? | Blocks |
|----|-------|------------------|------------------|--------------|-----------------|--------|
| **G0-D01** | Final Firebase project identity | Only `rafiq-academy` exists in CLI; staging/prod aliases missing; owner wants possible separate prod | Keep trial on `rafiq-academy`; create new prod id; or promote another existing project | All Cloud deploys & app configs target this id | **Yes** | Prod prep + deploy |
| **G0-D02** | Blaze / budget / spend limits | Functions need Blaze; checklist unresolved | Enable Blaze + alerts; defer | Cost; unlocks Functions | **Yes** | Functions deploy |
| **G0-D03** | Firestore Rules deploy target | Local rules + emulator PASS; live gaps (BASMA-100) | Deploy to trial only; deploy to final prod; dual | AuthZ surface | **Yes** | RB-03 / security claims |
| **G0-D04** | Firestore Indexes deploy | Local JSON; complaints missing in Cloud; RB-02 WT-only | Deploy HEAD indexes; deploy WT+HEAD; phased | Fixes BASMA-101 / RB-02 when Enabled | **Yes** | Runtime queries |
| **G0-D05** | Storage Rules deploy | Local + emulator | Same as Rules target project | Media/proof paths | **Yes** | RB-04 |
| **G0-D06** | Functions deploy + secrets | Code LOCAL; historically unpublished | After Blaze + project | Callables live | **Yes** | RB-05/08 |
| **G0-D07** | Unlock `PRODUCTION_BACKEND_ENABLED` | Fail-closed | Keep closed until verified | Accidental prod open risk | **Yes** | RB-07 |
| **G0-D08** | Android prod applicationId | Provisional `com.basmaacademy.app` | Confirm or change **before** first Play upload / keystore | Permanent after Play | **Yes** | Keystore + Play + Firebase Android app |
| **G0-D09** | iOS prod bundle ID | Provisional copy of Android id | Confirm or change before App Store record | Permanent after record | **Yes** | Apple + Firebase iOS app |
| **G0-D10** | Create Android upload keystore | RB-17 ready **after** D08 | Create outside repo; Codemagic `basma_upload_key` | Signing | **Yes** — **after** D08 | RB-17 / prod AAB |
| **G0-D11** | Play App Signing | Not enrolled | Enroll at first upload | Google holds app signing key | **Yes** | Store Android |
| **G0-D12** | Apple Developer / Codemagic iOS signing | Team unset; unsigned path unproven | Provision team, certs, CM | iOS ship | **Yes** | iOS release |
| **G0-D13** | iPad support | Family includes iPad in docs | iPhone-only vs iPad | Screenshots / layout | **Yes** | Store iOS |
| **G0-D14** | Meeting-link supervisor enable + prod migration | Emulator tested; flags disabled | Enable after security+migration | Data/security | **Yes** | RB-11–13 |
| **G0-D15** | Store publication / privacy / listing | RB-19 OPEN | Separate go/no-go | Public release | **Yes** | RB-19 |
| **G0-D16** | Distinct trial applicationId (optional) | Shares dev ID | Keep shared; or new id | Side-by-side installs | Optional | Convenience only |

---

## 8. Recommended deployment dependency order

Adjust only with documented reason:

1. **Confirm final Firebase project** (G0-D01) and Firestore location (permanent).  
2. **Confirm Blaze / budget** (G0-D02).  
3. **Finalize production Android / iOS IDs** (G0-D08 / D09) and iPad (G0-D13).  
4. **Provision** production (and optional staging) Firebase **apps** + download configs / Dart options.  
5. **Review** Rules + index manifests (commit WT index intent separately if approved).  
6. **Approve & deploy** Rules / Indexes / Storage to the **chosen** project (G0-D03–D05). Wait indexes **Enabled**.  
7. **Configure secrets** & deploy Functions (G0-D06); keep **`PRODUCTION_BACKEND_ENABLED` closed** until smoke (G0-D07).  
8. **Verify** Auth + admin provisioning on target (RB-15).  
9. **Create Android upload keystore** only after applicationId approval (G0-D10); register CM + Firebase SHA.  
10. **Play App Signing** + iOS signing / CI (G0-D11–D12).  
11. **Read-only** production smoke (extend G1/RB-18 carefully — no destructive writes).  
12. **Rollback / incident** notes.  
13. **Store publication** separately (G0-D15).

**Why this order:** Project + billing before any deploy; app IDs before keystore/Firebase app registration; indexes/Rules before claiming client query health; Functions after billing; production backend flag last; store last.

---

## 9. Safe next steps **without** owner Cloud decisions

These may proceed in parallel and do **not** require Blaze/deploy/keystore:

| Track | Examples |
|-------|----------|
| Local EQ | EQ-M-05, T1 suite hygiene, measured P1 when lab allows |
| Docs | Keep blockers/roadmap/register aligned after owner answers |
| Emulator | Continue Functions/rules tests on `demo-rafiq-rules` |
| Device lab | Expand **read-only** RB-18 smoke when phone stable (no new install required if policy allows) |
| WT hygiene planning | Plan (not execute) separate commits for indexes WT vs product code — still owner-gated for Cloud |
| Security tooling inventory | Phase SEC prep (no prod unlock) |

---

## 10. Explicitly blocked pending owner approval

| Blocked action |
|----------------|
| Firebase project create/switch/alias resolve for staging/prod |
| Blaze enable / billing changes |
| Deploy Rules, Indexes, Storage, Functions |
| Create Cloud indexes (incl. complaints / RB-02) |
| Set `PRODUCTION_BACKEND_ENABLED=true` |
| Create upload keystore / certificates |
| Choose or lock production applicationId / bundle ID |
| Play / App Store publish |
| Live migrations / seeders / Paymob activation |
| Claiming production readiness or Cloud verification complete |

---

## 11. Cross-links (authoritative detail elsewhere)

| Topic | Document |
|-------|----------|
| Release blocker statuses | `docs/production/BASMA_RELEASE_BLOCKERS.md` |
| Build flavors / CI | `docs/engineering-audit/BASMA_RB16_BUILD_CONFIG_REVIEW.md` |
| Signing | `docs/engineering-audit/BASMA_RB17_ANDROID_SIGNING_AUDIT.md` |
| Recitation index local proof | `docs/engineering-audit/BASMA_RB02_RECITATION_INDEX_LOCAL_VERIFICATION.md` |
| Device + BASMA-101 query | `docs/engineering-audit/BASMA_G1_DEVICE_AND_DEVTOOLS_DIAGNOSTICS.md` |
| Platform setup narrative | `docs/production/RELEASE_PLATFORM_SETUP.md` (separate review; may be dirty WT) |
| Issue register | `BASMA_MASTER_ISSUE_REGISTER.md` |
| Roadmap sequence | `docs/engineering-audit/BASMA_REMAINING_WORK_ROADMAP.md` |

---

## 12. G0 verdict

**G0 assessment complete as decision prep.**  

- **Confirmed project:** `rafiq-academy` (trial/dev Cloud).  
- **Final prod project:** **OWNER DECISION** (aliases staging/prod **not** seen as real projects).  
- **Cloud services:** LOCAL/emulator strong; **production deploy path blocked**.  
- **BASMA-101 complaints index:** confirmed missing on live trial project; definition already in Git.  
- **Android/iOS:** local review done; IDs/signing/Firebase prod files blocked on owner.  

**No live Cloud mutation and no Git state-changing operation occurred in this phase** (aside from adding this untracked report file).

**Stop for owner review** before any deploy, billing, keystore, or ID lock.
