# BASMA RB-02 — Recitation Index Local Verification

**Date:** 2026-11-18  
**Blocker:** `RB-02` — Firestore composite index `recitationRecords` / `halaqaId ASC` + `date DESC` verified in final Cloud project  
**Scope of this report:** Local definition + query compatibility only. **Does not** claim Cloud presence or deploy.

---

## 1. Status split (required)

| Layer | Result |
|-------|--------|
| Local definition verified | **YES** — present in WT `firestore.indexes.json`, valid JSON, no duplicate of this composite |
| Query compatibility verified | **YES** — matches teacher `newestByDate` collection query |
| Cloud presence / deployment | **PENDING** — not checked; deploy forbidden in this task |
| Emulator proves Cloud index? | **NO** — emulator ≠ production index catalog |

**RB-02 register status must remain `OPEN` until Cloud evidence on the final Firebase project.**

---

## 2. Actual query that needs this index (RB-02)

**Source:** `lib/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart`  
**API:** `getHalaqaRecitationRecords(..., mode: RecitationRecordsQueryMode.newestByDate)`  
**Callers (product):** non-today Teacher Home Feed display window (`maxRecords: 40` per D2 docs).

| Aspect | Value |
|--------|--------|
| Collection path | top-level `recitationRecords` via `.collection(FirestoreCollections.recitationRecords)` |
| Query type | **Collection query** (not `collectionGroup`) |
| Filters | `where('halaqaId', isEqualTo: halaqaId)` |
| Order | `orderBy('date', descending: true)` |
| Bound | `.limit(limit)` — `newestByDate` requires positive `maxRecords` |
| Required composite | `halaqaId ASC` + `date DESC` |
| `queryScope` in indexes file | `COLLECTION` (correct for this query shape) |

Contract notes (`RecitationRecordsQueryMode` / `HalaqaRecitationPaging`):

- `newestByDate` is **display-only**; Firestore omits docs missing `date`.
- Today / readiness / pending counts use `fullHistory` (`where halaqaId` + `orderBy(documentId)` pages) — **does not** need this DESC composite.

---

## 3. Index definition — before (HEAD) vs after (WT)

### Before — `HEAD` (`bb0a905`) `firestore.indexes.json`

`recitationRecords` composites present:

- `studentId ASC` + `date DESC`
- `studentId ASC` + `date ASC`
- `halaqaId ASC` + `date ASC`
- `halaqaId ASC` + `studentId ASC` + `date ASC`

**Missing:** `halaqaId ASC` + `date DESC`.

### After — working tree (unstaged)

Same as HEAD, **plus**:

```json
{
  "collectionGroup": "recitationRecords",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "halaqaId", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "DESCENDING" }
  ]
}
```

Note: Firebase indexes JSON uses the `collectionGroup` key even for single-collection indexes; with `queryScope: COLLECTION` this applies to collection queries on `recitationRecords`, matching the app code (no `collectionGroup()` calls found for this collection).

---

## 4. Isolation from Payment Indexes

### Unstaged diff of `firestore.indexes.json` (same file, two independent hunks)

1. **RB-02 hunk:** add `recitationRecords` / `halaqaId ASC` + `date DESC`.
2. **Out-of-scope hunk:** add `payments` / `status ASC` + `amount ASC` and `payments` / `status ASC` + `amountPaidConfirmed ASC`.

### What was done for isolation

- **Logical / documentary isolation only.**
- Payment index definitions were **not deleted, edited, or reformatted**.
- No partial `git add`, force-stage, or staging reorder (would change Git staging state — forbidden).
- File remains **unstaged** (` M`); staged set unchanged.

### Why physical Git unbundling was not executed

Splitting the two hunks into separate Git states requires either:

- removing/reverting the payment hunks (forbidden — would lose existing unstaged changes), or
- partial staging of only the recitation hunk (forbidden — changes staging).

Therefore RB-02 treats payment indexes as **co-located but out of scope**; owner/deploy review must not treat them as part of RB-02 close-out.

---

## 5. Other `recitationRecords` queries (inventory; not RB-02 close criteria)

All observed reads use `.collection('recitationRecords')` — **no** `collectionGroup('recitationRecords')`.

| Location | Shape | Index need (local) | Covered in WT indexes? |
|----------|-------|--------------------|------------------------|
| Teacher `newestByDate` | `halaqaId` eq + `date` DESC + limit | **RB-02** DESC composite | **Yes (WT add)** |
| Teacher `fullHistory` | `halaqaId` eq + `documentId` order + pages | documentId path | N/A composite |
| Teacher student summaries | `halaqaId` eq only | single-field | auto |
| Student list | `studentId` eq + `date` DESC + limit | studentId+date DESC | Yes (HEAD) |
| Parent / progress ranges | `studentId` eq + `date` range | studentId+date ASC | Yes (HEAD) |
| Analytics ranges | `halaqaId` eq + `date` range | halaqaId+date ASC | Yes (HEAD) |

No duplicate or conflicting definition of the RB-02 composite was found.

---

## 6. Local verification performed

| Check | Result |
|-------|--------|
| `JSON.parse(firestore.indexes.json)` | OK |
| Indexes array + `fieldOverrides: []` | OK |
| Duplicate full index keys | none |
| RB-02 target present + `COLLECTION` | OK |
| Payment extras left intact | 2 definitions unchanged by this task |
| Targeted Flutter tests | see run log in close-out / agent report |

**Not claimed:** Cloud console listing, `firebase deploy --only firestore:indexes`, production `FAILED_PRECONDITION` absence.

---

## 7. What still needs the final Firebase project (owner)

1. Confirm final project id (see RB-09) — do not assume `rafiq-academy`.
2. Deploy **or** console-verify the RB-02 composite exists/enabled on that project.
3. Named evidence for blockers: deploy log **or** Cloud console screenshot/export showing `recitationRecords` / `halaqaId ASC` + `date DESC`.
4. Optionally exercise non-today Teacher Home Feed against that project after index Ready.
5. Keep payment index deploy/review on a **separate** change ticket (not RB-02).

---

## 8. Files touched by the RB-02 documentation pass

- `docs/engineering-audit/BASMA_RB02_RECITATION_INDEX_LOCAL_VERIFICATION.md` (this file)
- `docs/production/BASMA_RELEASE_BLOCKERS.md` (RB-02 evidence notes only; status stays `OPEN`)

`firestore.indexes.json` content for RB-02 was **already present** in WT before this documentation pass; this task did not rewrite payment hunks.
