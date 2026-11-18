# BASMA D2 — Firebase Query & N+1 Remediation

**Method:** code changes + call-site audit against D0 matrix. No Cloud billing measurement.
**Updated:** single-id chat revalidation + `newestByDate` Home Feed bound.

## Summary table

| Area | Change | Bound / pattern | Full data reachable? | Deferred? |
|------|--------|-----------------|----------------------|-----------|
| Chat messages | Cursor older + fixed live 30; edit/delete revalidates **one** id outside live | Yes | Yes (load older) | Peer older mutations need conversation signal |
| Conversation inbox | Default `pageSize=40` in bloc (+ call sites in WT) | Yes | Yes (LoadMoreConversations) | Null API unused by app |
| Admin inbox | Already `pageSize=30` | Kept | Yes | No |
| Teacher halaqa recitation (evaluations) | `fullHistory`: documentId pages until exhausted + client date-desc | Peak query bounded | Yes — includes docs **without** `date` | Optional on-screen load-more |
| Teacher home feed (non-today) | `newestByDate` + `maxRecords: 40` | One bounded query | Display-only; missing-`date` omitted | Requires `halaqaId+date DESC` index deployed |
| Teacher home feed (today) / day readiness | `fullHistory` via `loadHalaqaDayFacts` | Full history for pending count | Yes | Denorm pending count = product decision |
| Admin `getAllTeachers` | Chunked `whereIn` profiles | Latency/reads | Full teacher user scan | Directory cursor search |
| Admin registration requests | Chunked parallel profile reads | Latency | Still scans all active students | `needsHalaqaAssignment` denorm/CF |
| Supervisor payments | Pages of 40/student by **document id** until exhausted + concurrency 8 | Peak query bounded | Yes — includes docs **without** `dueDate` | Rules force per-student |
| Parent payments | Unchanged (never limited) | — | Yes (totals OK) | Optional UI cursor |
| Student achievements | Not in D2 staged set | — | Yes in HEAD | Cursor UI optional |
| `listHalaqat` | Unchanged | — | Yes for admin list | UI pagination |
| Notifications `readBy` | Unchanged | — | N/A | Per-user read state schema |

## Indexes (repo only)

| Index | Needed by | In HEAD? | In WT `firestore.indexes.json`? | Staged? | Cloud deployed verified? |
|-------|-----------|----------|----------------------------------|---------|--------------------------|
| `recitationRecords`: `halaqaId ASC` + `date DESC` | `newestByDate` Home Feed | **No** | **Yes** (mixed with payment indexes) | **No** | **No** (not checked; live ops forbidden) |
| `recitationRecords`: documentId walk | `fullHistory` | N/A (documentId) | N/A | N/A | N/A |
| `payments`: `studentId` + `dueDate` | legacy; payments D2 uses documentId | Yes | Yes | No (mixed file) | Not re-verified this pass |

**Release implication:** Non-today Home Feed `newestByDate` must not be treated as Cloud-ready until the DESC composite is isolated, reviewed, deployed, and confirmed in the target project.

## Recitation read-cost note

Distinguish **theoretical query result counts** from **emulator observations**:

| Path | Theoretical | Emulator (demo-rafiq-rules, measured once) |
|------|-------------|--------------------------------------------|
| `newestByDate` limit 40 | ≤ 40 document reads / halaqa / load | Returned **40** docs from a 50-doc set (5 missing-`date` excluded by `orderBy(date)`) |
| `fullHistory` 50 docs | = number of matching docs (pages of 100) | Returned **50** including missing-`date` |

Missing-`date` behavior is explicit: included in `fullHistory`; omitted from `newestByDate` (display-only; never used for `pendingReviewCount`).

## External dependencies

1. Registration denorm / CF.
2. Owner: isolate + deploy + verify `halaqaId ASC + date DESC` for `recitationRecords`.
3. Optional achievements / parent payment cursor UX.
4. Notifications per-user read receipts.

## Permissions

- Supervisor payments still scope to supervised roster.
- No client write authority changes.
