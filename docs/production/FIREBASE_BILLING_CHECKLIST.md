# Firebase Paid Features / Billing Checklist

**Purpose:** Identify Firebase services required by locked product decisions (especially D19 FCM, D20 chat media, Cloud Functions for invoices/overdue/sessions/conflict validation) before enabling Blaze on the academy account.

**Rules:**
- Do **not** invent prices.
- Verify Blaze requirement and pricing against current Firebase documentation at infrastructure verification time.
- Complete this checklist before enabling billing / migrating to the academy Firebase project.
- Linked from `PRODUCT_DECISIONS_LOCKED.md` (D19, D20) and `IMPLEMENTATION_PLAN.md` Wave H.

**Status:** **B-BILLING UNRESOLVED (2026-09-10)** — Verified columns empty. Production Functions / scheduled jobs / production FCM send remain gated. Emulator-only backend work is allowed. Values below are capability requirements, not cost quotes.

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

## Pre-Blaze gate (must pass before enabling pay-as-you-go)

- [ ] `PRODUCT_DECISIONS_LOCKED.md` reviewed
- [ ] Each row above has a **Verified** Firebase doc URL and date
- [ ] Console project for academy identified
- [ ] Diff Console rules vs repo planned (do not deploy open rules)
- [ ] Paymob functions confirmed disabled/removed (D2)
- [ ] Budget alerts configured after verification (no invented $)
- [ ] Storage path layout for chat media drafted (Infrastructure TBD → then fill)
- [ ] FCM platforms (Android/iOS) registered on academy project

---

## Explicit non-goals for this checklist

- Inventing monthly cost estimates
- Choosing Spark vs Blaze without verification
- Deploying Functions or enabling billing from the planning phase
