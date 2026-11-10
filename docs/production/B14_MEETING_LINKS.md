# B14 — Halaqa meeting links

Status: backend, Firestore rules and the J.9 read-scope fix implemented and
verified on the Firestore emulator (`demo-rafiq-rules`) only. **Not deployed,
not released.** The privacy goal (only authorized users can read a Halaqa's
link) is not met in any real environment until every step in §8 is done.

## 1. Storage

| Location | Role | Shape |
|---|---|---|
| `halaqaMeetingLinks/{halaqaId}` | **Canonical, the only source** | Exactly `{ meetingLink, updatedAt }`. `updatedAt` is a server timestamp. No link means no document. |
| `halaqat/{halaqaId}.meetingLink` | **Legacy (J.9: never written)** | May still exist in old data until it is stripped (§8). |

No server path writes a link value into `halaqat` any more. The client reads
only the canonical document (`lib/shared/data/halaqa_meeting_link_firestore.dart`;
`test/shared/halaqa_meeting_link_repository_test.dart` asserts that no Halaqa
read model carries `meetingLink`).

## 2. Writes (server only)

No client can write either location (`firestore.rules`): the
`halaqaMeetingLinks` block denies every create, update and delete, `halaqat`
denies create, and the client `halaqat` update rule rejects any change to
`meetingLink`.

The only write paths are Cloud Functions using the Admin SDK:

- **`setHalaqaMeetingLink`** (callable, `europe-west1`):
  - Admin (active): set, update or explicitly clear the link of any Halaqa.
  - Supervisor (active, `halaqat.supervisorId == caller`): may only **add** a
    link while none is stored. A non-empty legacy copy counts as stored, so a
    Supervisor cannot replace a legacy link. Updating or clearing is
    Admin-only.
  - Everyone else: `permission-denied`. Role comes from `users/{uid}.role`,
    never from request data.
  - One transaction reads the Halaqa and the canonical document together
    (`getAll`), then writes the canonical document and one audit entry. If the
    Halaqa still carries a legacy `meetingLink` key, the same transaction
    deletes that key (and touches `updatedAt`); otherwise the Halaqa document
    is not written.
  - A request that matches the canonical document returns `unchanged` and
    writes nothing (a legacy copy, if any, is left for the strip).
- **`adminCreateHalaqa`**: creates the Halaqa without any `meetingLink`
  field; a valid link goes only to the canonical document in the same
  transaction, and without a link any stray canonical document is removed. A
  retry with the same `requestId` writes nothing.

Design note for approval: deleting the legacy key during an explicit change
(instead of leaving it) keeps the copy migration race-free — every writer that
runs while a legacy copy exists also writes the Halaqa document in the same
transaction, so the migration's transactional re-read can never resurrect a
link that was just cleared or replaced.

Both paths use the same validation (`validateMeetingLink`): outer whitespace is
trimmed; the link must be `https://`, at most 500 characters, printable ASCII
without inner whitespace, with a valid host, no user name or password, and no
contact information (phone numbers, WhatsApp or `tel:` links). The client
mirrors this policy in `lib/shared/domain/meeting_link_policy.dart`.

## 3. Clearing

Only an Admin can clear, and only explicitly (`clear: true`; an empty link is
rejected, never treated as a clear). Clearing deletes
`halaqaMeetingLinks/{halaqaId}` and, when present, the legacy key in the same
transaction.

## 4. Reads

### `halaqaMeetingLinks`

| Caller | Access |
|---|---|
| Active Admin | `get` and `list` |
| Active Supervisor assigned to the Halaqa | `get` only |
| Active Student on the Halaqa roster with an own `studentProfiles` document whose `lifecycle` is not archived | `get` only |
| Parent, Teacher, unassigned Supervisor, a user without a student profile, an archived Student, any inactive account, unauthenticated | Denied |

The archived check fails closed: any `lifecycle` string containing `archived`
counts as archived.

### `halaqat` (J.9)

Assignment comes from `halaqat.teacherId` / `halaqat.supervisorId` and the
roster from `halaqat.studentIds`. Every role needs an active profile
(`users/{uid}` exists and `isActive != false`).

| Caller | `get` | `list` / query |
|---|---|---|
| Active Admin | any Halaqa | any query |
| Active Teacher | only where `teacherId == uid` | only `teacherId == uid` queries |
| Active Supervisor | only where `supervisorId == uid` | only `supervisorId == uid` queries |
| Active Student | only where `studentIds` contains the caller | only `studentIds array-contains uid` |
| Parent (J.10) | Denied | Denied |
| Inactive account, no `users` doc, unassigned or unrelated role, unauthenticated | Denied | Denied |

Parents read their children's Halaqat only through the `getParentChildHalaqat`
callable (`functions/src/halaqa/parentHalaqaFunctions.ts`). It requires an
active `parent` profile and a child listed in the caller's own
`parentProfiles/{uid}.childrenIds`, queries `studentIds array-contains
<child>` with the Admin SDK and returns only `{ id, name, teacherId,
supervisorId }` per Halaqa — never the roster, schedule or any link. Like every
callable it is behind `assertBackendAllowed`. If it fails, the parent household
keeps the `studentProfiles.halaqaName` it already has and omits staff contacts;
the absence-request Halaqa picker shows an error.

A Halaqa document that still carries a non-empty legacy `meetingLink` (any
non-`""` value) is readable with `get` by Admin only.

Known limits (rules cannot filter or project fields):

- **Queries cannot prove field absence**, so the legacy guard applies to `get`
  only. A scoped `list` still returns a legacy link if one is stored. Only
  stripping the legacy key (§8) closes list reads; this is pinned by a rules
  test.
- **Parent minimum data (J.10)**: rules cannot project fields, and before
  J.10 a Parent read the full document (other children's ids in `studentIds`,
  schedule, `createdBy`, and through `list` any legacy link). The callable
  above replaces those reads; it computes the projection per call (no stored
  copy, no trigger), so roster changes apply immediately.

### Related collections (J.9, tightened in J.10)

| Collection | J.9 | J.10 | Reason |
|---|---|---|---|
| `teacherProfiles` | active profile | Admin, or the active Teacher reading their own profile | Holds HR data (`weeklyQuota`, `performanceRating`, `halaqatIds`). Only the Admin teachers page uses it; the supervisor name lookup and chat participant fallback now use `studentProfiles` / `users` instead. |
| `calendarEvents` | active profile | `get`: Admin, or an active profile when the event has no `halaqaId` (academy-wide) or the caller is in that Halaqa's community (`canAccessHalaqaCommunity`). `list`: same, but only queries filtering `halaqaId == <id>` or `halaqaId == null` are provable; unfiltered lists are Admin-only. `create`: Admin (any event), or that Halaqa's active Teacher/Supervisor for an event with its `halaqaId`. | The only client caller is the supervisor calendar of an assigned Halaqa, which always filters by `halaqaId`. `list` reads `resource.data.halaqaId` without a default: with `get('halaqaId', null)` the emulator allowed an unfiltered list (other Halaqat's events) as "general". |
| `sessions` | Admin, the session's Teacher, or the Halaqa community with an active profile | unchanged | The client never reads sessions. |
| `reciters`, `surahAudios` | unchanged | unchanged | Public Quran audio catalogue, no personal data. |

Calendar general events: the client's general-events query is
`halaqaId isNull`, which matches an explicit `null` but not a missing field.
`CalendarModel.toCreateData` now always writes `halaqaId` (`null` for a
general event), so new general events are listed for every active role, and
rules tests prove other Halaqat's events stay hidden (`in`, `!=`, `not-in`,
`in [h, null]` and unfiltered lists are denied). Events already stored
without the field remain `get`-readable but are not listed; backfilling them
to `halaqaId: null` is a data change that needs owner approval (real data
not inspected).

## 5. Audit

Every successful change writes one `auditLogs` entry with action
`halaqa_meeting_link_change` and metadata `{ halaqaId, operation }`, where
`operation` is `meeting_link_set`, `meeting_link_update` or
`meeting_link_clear`. Halaqa creation keeps its single `halaqa_create` entry.
Link values never appear in audit entries, error messages or error details.

## 6. Migration script (`functions/scripts/migrate-meeting-links.mjs`)

Emulator-only (`demo-rafiq-rules`, pinned non-default ports, egress guard, hub
check); there is no mode for a real project.

- **Copy** (default): creates missing canonical documents from valid legacy
  values with `tx.create` only. Apply needs
  `--apply --confirm meeting-link-migration:demo-rafiq-rules`.
- **Strip** (`--strip-legacy`, J.9): dry run by default. Apply needs
  `--strip-legacy --apply --confirm meeting-link-strip:demo-rafiq-rules`; the
  copy token is refused. In one transaction per Halaqa it re-reads the Halaqa
  and its canonical document and deletes only the `meetingLink` key, and only
  when the legacy value is empty or a well-formed canonical document exists.
  A valid legacy link without a canonical document (`needsCopy`), an invalid
  or non-string legacy value, and a malformed canonical document are reported
  for review and never stripped. The report lists counts and capped Halaqa ids
  only (`legacyKeysRemaining` is the post-run residue). The decision is taken
  again inside the transaction: if the canonical document was deleted or
  became malformed after the scan, the Halaqa is reported under
  `changedDuringRun` (`needsCopy` / `canonicalMalformed`) and keeps its
  legacy key (emulator tests: stale strip scan, strip vs canonical
  delete/corruption, strip vs Admin set/clear).
- **Superseded legacy values**: when a well-formed canonical document exists,
  strip removes the legacy key even if its value differs from the canonical
  link or is invalid. Those Halaqat are counted as `supersededLegacy`, listed
  in `review.supersededLegacyIds` and included in `needsReview`: the old value
  is lost on strip (recoverable only from a backup) and was exposed, so it
  informs rotation.
- **Concurrent runs**: each Halaqa is copied (`tx.create`) or stripped in its
  own transaction, so parallel runs never double-create or over-strip
  (emulator test: two copy runs, then two strip runs).
- **Ambiguous outcome** (commit applied but the acknowledgement lost): the
  record is counted as a failure (exit 4) and `legacyKeysRemaining` may
  over-count; a re-run is idempotent and reports the true state (emulator
  test). Always re-run the dry run after any failure.

Running either mode against a real project requires a separate, approved
runner; this script must not be pointed at one.

Before that, `functions/scripts/migration-inspect-release-data.mjs` reports
both dry runs plus the calendar `halaqaId` / `date` categories from an export
loaded into the emulator, read-only (`RELEASE_RUNBOOK_J10.md` §3).

## 7. Firebase Auth — owner checklist (not verifiable from the repo)

What the repo proves:

- The client has no sign-up or anonymous sign-in code (no
  `createUserWithEmailAndPassword`, `signInAnonymously` or federated
  sign-in in `lib/`); it signs in with email and password and can request a
  password reset.
- Accounts are created only by `adminProvisionUser` (Admin SDK `createUser`).
- `users/{uid}` has `allow create: if false`, so a self-created Auth account
  has no profile and, after J.9, reads no Halaqa, link, session, calendar or
  teacher profile.
- There is no blocking function (`beforeUserCreated`), and `firebase.json`
  only configures the Auth emulator port.

What the owner must verify in the Firebase console for each real project
before production (the actual settings are unknown here):

1. Email/Password provider: "Enable create (sign-up)" / user self-registration
   is **disabled** if accounts must only come from `adminProvisionUser`.
2. Anonymous sign-in is **disabled**.
3. No other provider (Google, phone, etc.) is enabled unless intended.
4. Email enumeration protection is enabled.
5. Authorized domains list contains only expected domains.

A `beforeUserCreated` blocking function would enforce this in code but needs
Identity Platform (GCIP) and an approved decision; it is not added.

## 8. Deployment order (design only — nothing here has been executed)

1. **Minimum app version**: the first build containing the J.10 client
   (parent `getParentChildHalaqat`, supervisor/chat name lookups without
   `teacherProfiles`, canonical link reads). Older builds against the new
   rules: the Parent household screen fails (`halaqat` denied), the
   supervisor day board and teachers page fail (`teacherProfiles` denied),
   pre-B14 builds show no meeting link and cannot save one, and pre-B14
   calendar creates are denied (`createdBy` empty). The B10 gate
   (`appConfig/clientVersion.minimumBuildNumber`) blocks them once set to
   `2`: earlier builds have `kAppBuildNumber = 1`, J.10 has `2`. Builds made
   before the gate must be replaced by hand (`RELEASE_RUNBOOK_J10.md` §1).
2. **Compatibility check**: confirm clients at or above that version, these
   rules and these Functions are compatible (rules tests and the emulator
   suites in §9).
3. **Deploy Functions, then rules**, per an approved plan in
   `PH02_DEPLOYMENT_ORDER.md`. Functions first stops new legacy writes and
   publishes `getParentChildHalaqat`; the backend switch
   (`PRODUCTION_BACKEND_ENABLED`) must already allow callables, otherwise
   parent Halaqa names fall back to the profile and staff contacts disappear.
   The rules then make legacy-carrying documents Admin-only for `get` (fail
   closed) and remove Parent access to `halaqat`. App releases older than the
   J.10 client still query `halaqat` as a Parent and lose Halaqa/staff
   details once these rules are live; the minimum app version (step 1) must
   be the first J.10 release (owner action).
   Window until step 4 finishes: Teacher, Supervisor and Student screens that
   `get` a Halaqa still carrying a legacy link fail, while scoped `list`
   queries still return that link. Keep the window short, or (owner
   decision) run step 4 before deploying the rules — then the window is
   instead "no canonical-link reads until the rules are live".
4. **Copy then strip** in one named environment, with explicit approval and
   an approved real-project runner, after a verified Firestore export of
   `halaqat` and `halaqaMeetingLinks`: copy dry run → review → copy apply →
   strip dry run → review (`needsCopy`, invalid, malformed,
   `supersededLegacy`) → strip apply. Stop on any failure count, a non-zero
   `changedDuringRun`, or review ids nobody has accepted.
5. **Verify** no `halaqat` document carries `meetingLink`
   (`legacyKeysRemaining == 0`, re-run the strip dry run) and that every
   expected canonical document exists.
6. **Rotate** meeting links that were stored in the legacy field and readable
   by Parents, Teachers or unassigned staff before the strip, where needed.

## 9. Tests

- `functions/test/meeting_link_policy.test.mjs` (unit, part of `npm test`).
- `functions/test/migrate_meeting_links.test.mjs` (unit + CLI refusals,
  including strip mode).
- `functions/test/meeting_link.emulator.test.mjs` and
  `functions/test/migrate_meeting_links.emulator.test.mjs` (inside
  `emulators:exec --project demo-rafiq-rules --only firestore`; the migration
  suite needs `MEETING_LINK_MIGRATION_EMULATOR=1` and pinned ports).
- `rules_test/b14_meeting_links.rules.test.mjs` (now part of
  `npm --prefix rules_test run test:all:firestore`) and the J.9/J.10 Halaqa,
  calendar, teacher-profile and legacy-write tests in
  `rules_test/ph02_backend_authority.rules.test.mjs`.
- `functions/test/parent_child_halaqat_callable.test.mjs` (unit) and
  `functions/test/parent_child_halaqat.emulator.test.mjs` (Firestore emulator).
- `test/features/parent/parent_child_halaqat_callable_adapter_test.dart`.
- `functions/test/migration_inspect_release_data.test.mjs` (unit) and
  `functions/test/migration_inspect_release_data.emulator.test.mjs` (same
  environment as the migration emulator suite).

J.10: no writer of `halaqat.meetingLink` remains. Functions create and update
`halaqat` with explicit fields and only ever delete the key;
`lib/shared/data/academy_halaqa_firestore.dart` (unused client create) no
longer writes it; the emulator-only seeders `tool/seed_teacher_flow.dart` and
`tool/demo_academy_dataset.dart` write the link to `halaqaMeetingLinks`. Client
`create` / `update` / `set` / merge of `halaqat` with a link is denied for every
role (rules tests).
