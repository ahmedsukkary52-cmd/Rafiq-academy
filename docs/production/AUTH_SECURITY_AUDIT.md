# Auth / security / privacy audit

**Baseline:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Product direction (given):** Sensitive roles must not freely self-create academy identities if Admin provisions them.

This document records **current vs intended**. It does not choose a new policy.

---

## 1. Registration

| | Current | Intended (stated direction) |
|--|---------|-----------------------------|
| Who | Public `/register` | Admin provisions sensitive roles; students via admission |
| Role | Hardcoded `AppRoles.student` | Staff not self-serve (matches: UI cannot pick teacher) |
| Activation | `isActive: true` immediately | Pending / not established until W8 |
| Profile | Creates `studentProfiles` with zeroed progress | Membership not established (`halaqaId: null`) |
| Staff | Cannot self-register as teacher/supervisor/admin **in this form** | Admin-created — **but Admin UI cannot create them either** |

**Verdict:** Student self-create **is implemented and active**. Staff self-create **blocked in UI** (not by rules: a client could pass another `role` into `registerWithEmail` — datasource **honors the role argument**; only the page passes student). There is **no role allowlist** in the use case/datasource. **P0** if combined with open Firestore.

**Gap:** Admin provisioning of Teacher/Supervisor/Admin — **missing contract** (seed/Console only).

---

## 2. Login

- Email/password Firebase Auth.
- Loads `users/{uid}`; missing doc → error; `isActive != true` → «هذا الحساب موقوف، يرجى التواصل مع الإدارة».
- Firebase `user-disabled` mapped to «هذا الحساب موقوف».
- Timeouts 20s Auth / 15s Firestore.
- No MFA, no App Check, no phone-auth.

**Role mismatch:** Router sends user to `homeForRole(users.role)`. A user with `role=student` cannot open `/admin` **in GoRouter**. They can still read Admin collections **via SDK** (AUD-001).

---

## 3. Logout

- `LogoutUseCase` → `firebaseAuth.signOut`.
- H1: `clearSessionProjections` on `AuthUnauthenticated` clears singleton role blocs.
- Confirm dialog shared.
- **No idle timeout.** Persistence is Firebase default (stays logged in).

---

## 4. Password reset

**Current:** Login shows `'استعادة كلمة المرور — Coming Soon'`. No `sendPasswordResetEmail`, no reset page, no Cloud Function.  
**Intended:** unspecified in freeze; operationally required.  
**Status:** missing contract (AUD-017). The Coming Soon string is UI copy, not an Auth API.

---

## 5. Account activation / suspended / disabled

| Mechanism | Writer | Effect |
|-----------|--------|--------|
| `users.isActive` | Register true; W8 sets true; Admin **teacher** toggle; reject-registration false | Login blocked if false. Admin **students tab does not toggle** (AUD-099) — badge is display-only |
| Firebase Auth disabled | Not in app | `user-disabled` error |
| Payment suspension | **None** | — |
| Reason | **None** | Generic copy |

W8 membership **established** ≠ `isActive` alone (`AcademyMembershipInvariant` also needs roster + student role). Login **only** checks `isActive`. A self-registered student with `isActive true` and no roster **can log in**.

---

## 6. Role assignment

- Set at register (`student`) or seed.
- No in-app role change use case found (Admin does not promote parent → teacher).
- Rules use `users.role` **get()** per request — spoofable because **any signed-in user can update users** (`allow update: if self or admin` — self **can** change own `role` field unless field-denied — **rules do not freeze `role`**).

**P0 implication:** A student can `update` `users/{self}.role` to `admin` if rules deployed as in repo, then `isAdmin()` becomes true. Even without that, open collection writes already bypass Admin.

Verify: `match /users/{userId} allow update if request.auth.uid == userId || isAdmin()` — **no `role` unchanged constraint**.

---

## 7. Unauthorized routes

`AppRouteAccess.isAllowed`:

- Prefix match on role home.
- Splash/login always allowed when checking authenticated paths (unauthenticated redirect handles auth pages).
- Supervisor may open `/teacher/attendance/*` and `/teacher/halaqa/*`.
- Register allowed only when unauthenticated (redirect).
- `errorBuilder` Arabic unknown page.

**Not covered:** Parent `Navigator` pages (not in GoRouter). Supervisor extra pages under `/supervisor` home widget (IndexedStack + push) — allowed because they never change GoRouter path.

Deep link to `/admin/payments` as student → bounce to `/student`.

---

## 8. Firestore permissions (actual)

Tight:

- `academySettings` Admin only
- Conversations: participants or Admin read; create 1:1 or admin group; messages create sender+participant; message update/delete **false**
- Users delete Admin; create self uid

Open signed-in RW: almost everything else including **payments**, **attendance**, **users read all**.

See `firestore.rules` and AUD-001.

**Deploy:** `firebase.json` does not include rules (AUD-006). Live Console may differ — **unknown**.

---

## 9. Storage permissions

Proof path: owner write images <10MB; **any signed-in read**; no delete.  
Catch-all: any signed-in RW entire bucket.

Avatar/homework/award files are not isolated.

---

## 10. Admin-created identities vs self-signup

| Identity | How created in freeze |
|----------|------------------------|
| Student | Public register **or** seed **or** (if already Auth) W8 admit |
| Parent | Seed / Console — no register role |
| Teacher | Seed / Console — Admin page cannot create |
| Supervisor | Seed / Console |
| Admin | Seed / Console |

Supervisor “register” page **admits existing student id** into a halaqa — does not create Auth.

---

## 11. Parent relationships

Read `parentProfiles.childrenIds`. No writer. Event fan-out to parents uses `arrayContainsAny` on that field. Unlinked children: Parent UI empty; W4/W7 may not notify.

---

## 12. Session persistence

Firebase Auth persistence default. Shared device: logout clears blocs (H1) but does not lock the OS account. No PIN.

---

## 13. Chat privacy

- Policy in domain is **role-pair only** (AUD-098). Student UI binds halaqa teacher, but `GetOrCreateConversationUseCase` / `ChatPermissionPolicy.canChat` do **not** check halaqa roster or `childrenIds`. A crafted client that knows UIDs can open Teacher↔any-student or Parent↔any-teacher 1:1 if roles match.
- Rules enforce participant send; create allows any two `participantIds` (size ≤ 2) including self. Admin read-all.
- `users` read leaks phones into any client that hydrates participants.
- Auto-seed Parent chats creates documents (metadata) without a message.
- Groups other than admin internal **cannot** be created (size ≤ 2).

Blocked/deleted/suspended: no block-list. Deleted users: messages remain; participant names stale. Suspended: cannot login; rules still allow if a stolen token exists until Auth revoke.

---

## 14. Phone numbers — where exposed

| Surface | Exposed? |
|---------|----------|
| Firestore `users.phone` to any signed-in | **Yes** (rules) |
| Own account tabs | Yes (self) |
| `StudentProfilePage` (Teacher/Admin) | Yes |
| Chat participant model | Reads user doc (field available) |
| Parent household staff | Names/roles; confirm if phone mapped — household assembler uses staff contacts from halaqa ids |
| Proof destination | Empty (not an exposure; unusable) |

**Unnecessary cross-role:** any student can read every parent/teacher phone via SDK even if UI never shows a directory.

---

## 15. Profile images

- `profileImageUrl` on users; student `avatarId` catalog (`fox` default).
- Broken image: widgets vary (Asset avatar vs empty).
- Deleted Storage object: URL 403; catch-all still allows overwrite.
- Upload validation: proof has size/type; avatars not systematically validated in this audit.

---

## 16. Current vs intended (summary table)

| Topic | Current | Intended / direction | Gap type |
|-------|---------|----------------------|----------|
| Student signup | Open, active | Admin/admission | Defect vs direction |
| Staff signup | UI blocked; API role param exists | Admin provision | Missing Admin provision |
| Role field | Self-updatable in rules | Frozen by Admin | P0 rules |
| Data Authz | Signed-in RW | Per-role | P0 |
| Paid status | Client-writable | Supervisor/backend | P0 |
| Phones | Global read | Need-to-know | P0 privacy |
| Reset password | Login copy «Coming Soon»; no Auth API | Unspecified | Missing (AUD-017) |
| Student disable UI | Badge only on Admin students tab | If Admin manages students, a real toggle | Missing wiring (AUD-099) |
| Suspend reason | Missing | Stated payment story | Missing |
| App Check | Missing | Category B | Missing |
| Custom claims | Not used | Optional hardening | Rules use profile role |

---

## 17. Recommended verification (do not run exploits in production)

- Rules emulator: student updates `role` to `admin`.
- Student `get` on `payments` and another user’s `users.phone`.
- Parent `update` `payments/{id}` `status=paid`.
- Confirm Console rules vs repo (`firebase.json`).
- Rules emulator: student `getOrCreate` conversation with a teacher from another halaqa (AUD-098).

No exploit PoCs are included in this audit.
)
