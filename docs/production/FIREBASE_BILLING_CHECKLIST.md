# Firebase Paid Features / Billing Checklist

**Purpose:** Identify Firebase services required by locked product decisions (especially D19 FCM, D20 chat media, Cloud Functions for invoices/overdue/sessions/conflict validation) before enabling Blaze on the academy account.

**Rules:**
- Do **not** invent prices.
- Verify Blaze requirement and pricing against current Firebase documentation at infrastructure verification time.
- Complete this checklist before enabling billing / migrating to the academy Firebase project.
- Linked from `PRODUCT_DECISIONS_LOCKED.md` (D19, D20) and `IMPLEMENTATION_PLAN.md` Wave H.

**Status:** **B-BILLING UNRESOLVED (2026-09-10; re-checked 2026-10-28)** — Verified columns empty. Production Functions / scheduled jobs / production FCM send remain gated. Emulator-only backend work is allowed. Values below are capability requirements, not cost quotes. The repository facts and the evidence still needed are listed under "Repository evidence" and "Evidence required to close B-BILLING" below; nothing there is a billing verification.

---

## How to use

For each row:
1. Confirm the service is required by a locked decision or Wave A–I unit.
2. Look up current Firebase docs: whether Blaze (pay-as-you-go) is required.
3. Note what usage creates cost (reads, writes, GB, invocations, etc.).
4. Note scale implications for hundreds vs thousands of students.
5. List what must be migrated to the academy’s Firebase account.
6. Set budget alerts / quotas — **do not guess dollar amounts**; configure alerts after verification.

---

## Checklist

| Firebase service | Required by | Blaze / pay-as-you-go required? | What usage creates cost | Scale implications | Migrate to academy account | Budget / alert considerations | Verified (date / doc URL) |
|------------------|-------------|-------------------------------|-------------------------|--------------------|----------------------------|-------------------------------|---------------------------|
| **Firestore** | Core app SSOT; sessions (D10); payments; chat metadata; notifications | **Verify** — Spark allows limited Firestore; production scale typically needs Blaze | Document reads/writes/deletes; storage; network | Unbounded Admin/chat listeners amplify cost (AUD-026/028/034) | Project, indexes, rules, data | Alert on read/write spikes; avoid full-collection gets | TBD |
| **Cloud Storage** | Payment proofs (D2); chat images/voice (D20); profile pictures; optional award images; audio uploads if flag later (AUD-060) | **Verify** — often Blaze for production apps | GB stored; GB downloaded; operations | Proofs never deleted today → storage grows; chat media grows with D20 | Buckets, rules, objects | Lifecycle policies after delete contract (D20 TBD); alert on storage GB | TBD |
| **Cloud Functions** | Invoice generation (D3); overdue job (D4); payment reminders (D5); FCM fan-out (D19); session materialization (D10); conflict validation (D9); optional Admin createUser (D1); quarantine Paymob leftovers (D2) | **Typically yes (Blaze)** — verify current docs | Invocations; compute time; networking | Scheduled jobs × academy size; chat/FCM fan-out per event | `functions/` source, secrets, region (`europe-west1` in freeze DI) | Alert on invocation errors & cost; remove unused Paymob if OUT | TBD |
| **Firebase Cloud Messaging (FCM)** | D19 real push; D17 live-eval notify; payment reminders (D5) | **Verify** — FCM itself often free at message level; **depends on** Functions/Auth/Blaze for backend send path | Message volume; Functions that send; device token storage in Firestore | Every parent/student device; broadcast storms | FCM config, Android/iOS apps, server keys / Admin SDK | Cap broadcast audiences; monitor failed tokens | TBD |
| **Firebase Authentication** | All roles; Admin provisioning (D1); no idle timeout (D22) | **Verify** Spark vs Blaze limits for MAU | MAU; SMS if ever used (not in scope) | Staff + parents + students | Auth users, providers | Export/import users carefully on migrate | TBD |
| **Firebase App Check** | AUD-062 / U-SEC-IDENTITY | **Verify** | Attestation traffic; abuse reduction (cost avoidance elsewhere) | All clients | App Check providers per platform | Enable after rules tightness | TBD |
| **Firestore indexes** | AUD-032/033; sessions queries; chat pagination | Usually included with Firestore | Index storage/build | More compound indexes as sessions/chat grow | `firestore.indexes.json` | Deploy with query changes | TBD |
| **Profile pictures Storage** | User avatars | Same as Storage | Upload/download | Per user | Paths + rules | Size limits in rules | TBD |
| **Chat images Storage** | D20 | Same as Storage | Upload/download; retention | High growth | Path layout TBD | Soft-delete contract before purge | TBD |
| **Chat voice messages Storage** | D20 | Same as Storage | Upload/download; larger objects | High growth | Path layout TBD | Duration/size caps | TBD |
| **Payment proof Storage** | D2 | Same as Storage | Upload; long retention (evidence) | Grows with invoices | Existing `payment_proofs/…` | Prefer no delete until retention policy | TBD |
| **Mushaf / recitation audio uploads** | Out while `audioUploadsEnabled=false` (AUD-060); checklist for **if/when** enabled | Same as Storage + possibly Functions | Audio GB | High | Only if product re-opens uploads | Keep gated until Blaze + rules ready | TBD |
| **Paymob Cloud Functions (legacy)** | D2 **OUT** — quarantine | N/A if removed | Would create cost if left deployed | Remove/disable on academy account | Do **not** migrate as active product | Confirm no live webhooks | TBD |
| **Hosting** (if used) | Not required by freeze Flutter mobile; verify if web admin later | Verify | Bandwidth | Optional | Only if needed | — | TBD |
| **Crashlytics / Analytics / Performance** | Optional ops | Verify | Event volume | Optional | Optional | — | TBD |
| **Secrets / env (Functions)** | Vodafone is in Firestore settings (D6); any third-party keys | — | — | — | Migrate secrets store | Never commit secrets | TBD |

---

## Locked decisions → billing dependencies

| Decision | Billing-sensitive services |
|----------|----------------------------|
| D3 Invoice auto-generation | Cloud Functions + Firestore writes |
| D4 Overdue scheduled job | Cloud Functions (scheduler) + Firestore |
| D5 Payment reminders / grace | Functions + FCM + Firestore |
| D9 Conflict validation backend | Functions and/or transactional Firestore |
| D10 Session persistence | Firestore volume + indexes |
| D17 Live eval notify | Firestore notifications + FCM + Functions |
| D19 FCM | FCM + Functions + token docs |
| D20 Chat media | Storage + rules + download bandwidth |
| D1 Admin Auth provision (if callable) | Functions + Auth |

---

## Repository evidence (2026-10-28)

What the repository shows about billable usage. It narrows the rows above; it
does not verify any plan, price or console setting.

| Item | Evidence in the repository |
|---|---|
| Deployable Functions | 37 exports in `functions/src/index.ts` (callables, Firestore triggers, one scheduler), region `europe-west1` (`callable_region_contract.test.mjs`) |
| Scheduled jobs | One: `processPaymentOverdueGrace`, `every day 01:15` (`functions/src/billing/processOverdueGrace.ts`) — needs Cloud Scheduler |
| Paymob | `createPaymentIntention` and `paymobWebhook` are commented out of `index.ts`; `wa1`, `wa3_wa5`, `wa7`, `wa8` and `wa10` tests in `functions/test` fail if they are exported again |
| Secret Manager | Only the quarantined Paymob files use `defineSecret`; no deployable function needs a secret |
| Backend switch | Every gated callable and job stays closed until `PRODUCTION_BACKEND_ENABLED=true` is deployed (`functions/src/productionGate.ts`; `RELEASE_RUNBOOK_J10.md` §2) |
| Cloud Storage paths | `storage.rules`: `payment_proofs`, `profile_images`, `chat_media`, `chat_voice`, `chat_attachments`, `awards`, `posts`, `content`, `content_library`, `halaqa_activities`; `recitations` denies all access |
| Client SDKs | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging` only: no App Check, Crashlytics, Analytics or Performance in the client |
| Hosting | No `hosting` section in `firebase.json` |
| Backups | Managed Firestore exports (`RELEASE_RUNBOOK_J10.md` §3) need Blaze |

## Evidence required to close B-BILLING

Each item needs the evidence named, recorded with a date in this file (a
console screenshot or exported setting kept outside the repo is enough). The
repository cannot supply any of them.

| # | Item | Evidence |
|---|---|---|
| 1 | Target project | Which project the release uses (`rafiq-academy` for J.10 testing; the prod project once created, `RELEASE_PLATFORM_SETUP.md` §7) |
| 2 | Plan | Console → Usage and billing shows **Blaze** for that project, with the billing account owner named |
| 3 | Budget alerts | Billing → Budgets & alerts: a budget on that billing account with alert thresholds and recipients |
| 4 | Doc check per row | For each row still used (Firestore, Storage, Functions, FCM, Auth, indexes, Cloud Scheduler, managed export): the current Firebase/Google Cloud doc URL and the date read, in the Verified column |
| 5 | Paymob in the console | Functions list of the target project shows no `createPaymentIntention` / `paymobWebhook`, and no Paymob webhook points at it |
| 6 | Live rules diff | Live Firestore and Storage rules compared with the repo before the first deploy (`RELEASE_RUNBOOK_J10.md` §4 step 7) |
| 7 | FCM platforms | Android and iOS apps registered in the target project; APNs key uploaded for iOS |
| 8 | Owner sign-off | `PRODUCT_DECISIONS_LOCKED.md` reviewed against the deployable set above |

Only after 1–8 may the status line change to Verified and the backend
switch be enabled.

## Pre-Blaze gate (must pass before enabling pay-as-you-go)

- [ ] `PRODUCT_DECISIONS_LOCKED.md` reviewed
- [ ] Each row above has a **Verified** Firebase doc URL and date
- [ ] Console project for academy identified
- [ ] Diff Console rules vs repo planned (do not deploy open rules)
- [x] Paymob functions removed from the deployable source (D2) — repository evidence above
- [ ] Paymob functions confirmed absent from the target project's console (D2)
- [ ] Budget alerts configured after verification (no invented $)
- [x] Storage path layout for chat media drafted — `chat_media`, `chat_voice`, `chat_attachments` in `storage.rules`
- [ ] FCM platforms (Android/iOS) registered on academy project

---

## Explicit non-goals for this checklist

- Inventing monthly cost estimates
- Choosing Spark vs Blaze without verification
- Deploying Functions or enabling billing from the planning phase
