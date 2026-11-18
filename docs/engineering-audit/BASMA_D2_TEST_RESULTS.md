# BASMA D2 — Test Results

**Date:** 2026-11-18
**Branch:** `unify/basma-v1`
**HEAD:** `bb0a90585adb9ee684848cd547cb234cff2a47fa` (working tree dirty; D2 staged, uncommitted)

## Behavior under test

### Chat consistency (outside live window)

- Live listener remains fixed at newest **30**.
- Local edit/delete: optimistic `_byId` patch, then **single-id** `fetchMessagesByIds` revalidation for that message only (not the full older buffer).
- Live window wins on id overlap; request-id drops stale refreshes; close bumps the request id.
- Peer mutations of older messages are **not** realtime without a conversation-level signal (no unapproved backend contract).

### Recitation query modes

| Caller | Mode | Firestore shape |
|--------|------|-----------------|
| Readiness / today Home Feed facts / evaluations | `fullHistory` | `where(halaqaId)` + `orderBy(documentId)` pages until exhausted (includes missing `date`) |
| Non-today Home Feed display | `newestByDate` + `maxRecords: 40` | `where(halaqaId)` + `orderBy(date desc)` + `limit(40)` — docs **without** `date` omitted by Firestore |

### Index status (recitation `newestByDate`)

Required composite: `recitationRecords` / `halaqaId ASC` + `date DESC`.

- Present in **working tree** `firestore.indexes.json` (added vs HEAD).
- **Not staged** (file also mixes unrelated payment indexes).
- **Deployed Cloud status: not verified** (no live Firebase index list/deploy in this pass).
- Home Feed `newestByDate` is **not** release-ready until that index is isolated, reviewed, deployed, and confirmed in the target project.

### Read-cost notes

- **Theoretical:** non-today feed ≤ 40 document reads per halaqa per load; fullHistory reads = all matching docs (paged by 100).
- **Emulator (demo-rafiq-rules, measured):** bounded query returned 40 docs; documentId full walk returned 50/50 including missing-`date` rows. Emulator ≠ Cloud billing/indexes.

## Commands (latest verification pass)

See agent final report for exact `flutter test` / `flutter analyze` / emulator probe commands and exit codes.
