# B14 — Halaqa meeting links

Status: backend and Firestore rules implemented and verified on the Firestore
emulator (`demo-rafiq-rules`) only. **Not deployed, not released.** The privacy
goal (only authorized users can read a Halaqa's link) is not met until every
release step in §6 is done.

## 1. Storage

| Location | Role | Shape |
|---|---|---|
| `halaqaMeetingLinks/{halaqaId}` | **Canonical** | Exactly `{ meetingLink, updatedAt }`. `updatedAt` is a server timestamp. No link means no document. |
| `halaqat/{halaqaId}.meetingLink` | **Legacy**, kept temporarily for compatibility | String; `""` when there is no link. |

The canonical document is authoritative whenever it exists; the legacy field
is consulted only when it does not. Until the strip step (§6), every server
write updates both in the same transaction, so clients that still read the
Halaqa keep working.

## 2. Writes (server only)

No client can write either location (`firestore.rules`): the
`halaqaMeetingLinks` block denies every create, update and delete, and the
client `halaqat` update rule rejects any change to `meetingLink`.

The only write paths are Cloud Functions using the Admin SDK:

- **`setHalaqaMeetingLink`** (callable, `europe-west1`):
  - Admin (active): set, update or explicitly clear the link of any Halaqa.
  - Supervisor (active, `halaqat.supervisorId == caller`): may only **add** a
    link while none is stored in either location. Updating or clearing is
    Admin-only.
  - Everyone else: `permission-denied`. Role comes from `users/{uid}.role`,
    never from request data.
  - One transaction reads the Halaqa and the canonical document together
    (`getAll`), then writes the canonical document, the legacy field and one
    audit entry atomically.
  - A request that matches what is already stored returns `unchanged` and
    writes nothing.
- **`adminCreateHalaqa`**: when the request carries a valid link, writes the
  canonical document and the legacy field with the new Halaqa in the same
  transaction; without a link it stores `""` and removes any stray canonical
  document. A retry with the same `requestId` writes nothing.

Both paths use the same validation (`validateMeetingLink`): outer whitespace is
trimmed; the link must be `https://`, at most 500 characters, printable ASCII
without inner whitespace, with a valid host, no user name or password, and no
contact information (phone numbers, WhatsApp or `tel:` links). The client
mirrors this policy in `lib/shared/domain/meeting_link_policy.dart`.

## 3. Clearing

Only an Admin can clear, and only explicitly (`clear: true`; an empty link is
rejected, never treated as a clear). Clearing deletes
`halaqaMeetingLinks/{halaqaId}` and sets `halaqat.meetingLink` to `""` in the
same transaction.

## 4. Reads (`halaqaMeetingLinks`)

| Caller | Access |
|---|---|
| Active Admin | `get` and `list` |
| Active Supervisor assigned to the Halaqa | `get` only |
| Active Student on the Halaqa roster with an own `studentProfiles` document whose `lifecycle` is not archived | `get` only |
| Parent, Teacher, unassigned Supervisor, a user without a student profile, an archived Student, any inactive account, unauthenticated | Denied |

The archived check fails closed: any `lifecycle` string containing `archived`
counts as archived.

## 5. Audit

Every successful change writes one `auditLogs` entry with action
`halaqa_meeting_link_change` and metadata `{ halaqaId, operation }`, where
`operation` is `meeting_link_set`, `meeting_link_update` or
`meeting_link_clear`. Halaqa creation keeps its single `halaqa_create` entry.
Link values never appear in audit entries, error messages or error details.

## 6. Release is not complete

The legacy `halaqat.meetingLink` field is still readable by every signed-in
non-student (including Parents and Teachers) and by roster Students regardless
of lifecycle, because `halaqat` reads are not restricted per field. The
exposure remains until **all** of the following are done:

1. Data migration: copy existing legacy links into `halaqaMeetingLinks`
   (a reviewed script with dry run, guarded against live projects, run only
   with explicit approval). Not written yet.
2. Client read cutover: clients read the link from `halaqaMeetingLinks`
   instead of `halaqat`. Not done; the client still reads the legacy field.
3. Functions write the canonical document only, and the legacy field is
   stripped from every `halaqat` document. Not done.
4. Rules, Functions and clients deployed in the order in
   `PH02_DEPLOYMENT_ORDER.md` and verified on an appropriate environment
   (staging is not ready yet). Not done.
5. Links rotated where needed: any link that was readable through the legacy
   field before the strip should be treated as exposed and replaced. Not done.

## 7. Tests

- `functions/test/meeting_link_policy.test.mjs` (unit, part of `npm test`).
- `functions/test/meeting_link.emulator.test.mjs`
  (`npm --prefix functions run test:meeting-link:emulator` inside
  `emulators:exec --project demo-rafiq-rules --only firestore`).
- `rules_test/b14_meeting_links.rules.test.mjs` and the B14 test in
  `rules_test/ph02_backend_authority.rules.test.mjs` (Firestore emulator,
  `demo-rafiq-rules`).
