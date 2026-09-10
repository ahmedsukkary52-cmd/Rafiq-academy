# Wave A Batch WA-0 → WA-2 — Implementation Status

**Batch scope:** WA-0, WA-1, WA-2 only.  
**Date:** 2026-09-10  
**Deploy / commit / push:** **not performed** (local + emulator-ready only).

---

## WA-0 — Billing verification gate (C12)

| Item | Result |
|------|--------|
| Checklist `FIREBASE_BILLING_CHECKLIST.md` | **Not Verified** — every Verified column remains TBD |
| Pre-Blaze gate boxes | **Unchecked** |
| B-BILLING | **BLOCKER** for production Cloud Functions / scheduled jobs / production FCM send |
| Repo Functions | Present under `functions/` (legacy Paymob + new `adminProvisionUser`) |
| `firebase.json` | Now references rules for local/versioning; **no production deploy from this batch** |
| Production activation | **DISABLED** — see `functions/src/productionGate.ts` |

**Allowed offline:** implement/test callables against Firebase Emulator.  
**Forbidden until Verified:** `firebase deploy` of Functions/Rules, Blaze enablement, production FCM send, scheduled overdue/invoice jobs.

---

## WA-1 — Auth provisioning + close public register (C1 / D1)

| Item | Status |
|------|--------|
| Public `/register` route + login CTA | **Removed/disabled** |
| Client `createUserWithEmailAndPassword` product path | **Disabled** (throws) |
| Callable `adminProvisionUser` | **Implemented** (emulator-ready; production gated) |
| Role SSOT `users.role` | Server-assigned on provision |
| `userPrivate/{uid}.phone` | Server-written; not on public `users` write path |
| Admission (`AcademyAdmissionFirestore`) | **Unchanged** client writes; Rules allow **Admin/Supervisor interim** `studentIds` only; **follow-up:** membership CF (next batch) |
| Audit log on provision | Writes `auditLogs` when provision succeeds |

---

## WA-2 — Authorization foundation

| Boundary | Status |
|----------|--------|
| `users.role` immutable for clients | Rules deny |
| Phone: Admin + self via `userPrivate`; others denied | Rules + strip phone from `users` writes |
| Docs with legacy non-empty `users.phone` | Readable only by Admin/self until `adminMigrateUserPhones` |
| `parentProfiles.childrenIds` client write | Deny |
| `halaqat.studentIds` | Deny except Admin/Supervisor interim |
| Payment privileged fields / `paymentAccess` client write | Deny |
| `academySettings/paymentPublic` Parent read / Admin write | Rules |
| `academySettings/communication` Admin only | Rules |
| Wallet / Paymob production entry | Quarantined (D2 OUT) |
| Storage catch-all | Replaced with path rules (C10 minimum) |

### Self-phone TBD

Freeze recommends own-read. This batch **allows** `request.auth.uid == userId` read on `userPrivate/{uid}`. Absolute Admin-only self-phone was **not** invented as a product change.

### Follow-ups (not this batch)

- Membership / `childrenIds` Cloud Function (admission server-side)
- Full paymentAccess state machine (WA-3+)
- Invoice generation, overdue jobs, sessions, FCM send, studentSearch, etc.

---

## Review pass (2026-09-10) — fixes applied

| Fix | Why |
|-----|-----|
| Billing gate ignores `ALLOW_EMULATOR_BACKEND` | Prevent accidental production bypass via env |
| `adminMigrateUserPhones` preserves existing `userPrivate.phone` | No overwrite with stale legacy |
| Migration deletes `users.phone` only after private has phone | No phone loss / no premature delete |
| Migration writes audit summary | C16 |
| Profile Rules deny client `phone` fields | Close D16 bypass via studentProfiles |
| Parent proof Rules deny `reviewNotes` presence | Close forged reviewer notes |
| Storage chat paths require conversation participant (+ Admin) | Close arbitrary media R/W |
| Student profile mapper no longer hydrates `users.phone` | Defense in depth |
| Demo seed tool documented as non-production Auth | createUser remains tool-only |

**Still required before live Rules activation:** run `adminMigrateUserPhones` on real data (Admin, after B-BILLING / emulator gate as applicable). Until then, docs with legacy non-empty `users.phone` remain Admin/self-readable only.

---

## Contradictions noted (not guessed away)

1. Admission still mutates `halaqat.studentIds` from Admin/Supervisor clients — Rules allow interim staff write; freeze wants CF. Documented, not redesigned here.
2. Legacy `users.phone` remains on documents until migration callable is run against data.
