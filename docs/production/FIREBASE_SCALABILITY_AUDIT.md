# Firebase / scalability audit

**Baseline:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
Question: is the architecture reasonable for hundreds vs thousands of students, many halaqat, large chat/notification/payment/homework history?

---

## 1. What scales acceptably (tens → low hundreds)

- W8 admission **batch** writes (small).
- Attendance/eval **deterministic ids** (no duplicate explosion if clients use policy).
- `FirestoreInQuery` chunking for `whereIn` / `array-contains-any` (H5) on rosters and parent recipient resolution.
- Assignment latest scans with `AssignmentPolicy.latestScanLimit`.
- Notifications inbox `limit(50)` on some watches.
- Halaqa activities list `limit(50)` / responses `limit(200)`.
- Posts `limit(30)`.
- Admin **count()** aggregations for students/teachers/halaqat (good).
- Wallet pay **transaction** (if that rail stays).

These are fine for a **single academy demo** and likely **low hundreds of students** if listeners stay per-user.

---

## 2. Bottlenecks that fail toward thousands

### Unbounded listeners

| Listener | File | Risk |
|----------|------|------|
| All messages in a conversation | `chat_remote_datasource.watchMessages` | Large history → memory/cost |
| All conversations in project | `watchAllConversations` Admin | Grows with every 1:1 pair |
| Conversations for a uid | `arrayContains` + orderBy lastMessageAt | OK per user; Admin path is the problem |

### Unbounded / full-collection gets

| Query | File | Risk |
|-------|------|------|
| `payments.get()` | Admin finance + payment list | Every invoice every open |
| Awards `halaqaId` + `halaqaIds` two full queries then merge | Awards datasource | Grows with all historic grants |
| Calendar/content dual queries | Some datasources | Moderate |

### Client-side aggregation

- Admin finance reduce in Dart.
- Admin academy attendance% **not even computed** (hardcoded 0) — at least it does not scan attendance; it **lies** instead.
- Parent weekly report loads recitation+attendance windows then counts in Dart (OK if windowed).
- Supervisor roster merge across halaqat in memory.

### N+1 patterns

- Teacher student summaries: roster then profile progress map (chunked — OK).
- Chat `getParticipant` per user (on demand).
- Parent household `Future.wait` per child — **N children** parallel; OK for families, not for a parent with huge lists.

### Array / large documents

- `halaqat.studentIds` unbounded array — hundreds OK; **thousands in one halaqa** will hit 1MB and slow `arrayUnion`.
- `teacherProfiles.halaqatIds` small.
- Broadcast `readBy[]` — **does not scale** to all students marking read on one doc.
- Conversation `participants[]` duplicated on the conversation doc (OK for 1:1; admin group grows with admin count).

### Write races

- Proof vs review last-write-wins.
- Event publish after commit (duplicate protection via deterministic notification ids — **good** for W4/W5; **not** durable outbox).
- Chat send batch (good) but no client idempotency key beyond Firestore auto ids.
- Halaqa activity replies: read-modify-write `responseCount` / `respondentStudentIds` (AUD-101) — concurrent students can lose count.

### Missing transactions where needed

- Assign staff dual profile arrays.
- Activity `responseCount` increment (AUD-101).
- Progress counters (not written — so no race, just wrong).
- Invoice issue (does not exist).
- Overdue flip (does not exist).

### Indexes

Repo indexes incomplete vs Analytics + Parent payments (AUD-032, AUD-033). Failed queries look like errors, not empty states.

### Storage

- Proofs never deleted (`allow delete: if false`) — storage grows forever (may be intended evidence).
- Catch-all writes: abuse/cost.
- Recitation audio gated off — avoids Storage growth until flag flips, then no lifecycle.

### Functions / scheduled work

No cron for overdue, reminders, progress rollup, session materialization. All on clients.

---

## 3. Capacity scenarios

| Load | Verdict |
|------|---------|
| Hundreds of students, ~20 halaqat, small chat | **Operable** for W1–W8 if indexes deployed and rules tightened |
| Thousands of students | Admin finance and Admin chat oversight **fail**. `studentIds` arrays on large halaqat **risk**. Broadcast `readBy` **fails**. Client roster queries still chunked (OK). |
| Many teachers/supervisors | Directories unbounded gets — moderate |
| Large chat history | Room open **fails** without pagination |
| Large notification history | Some limits 50; broadcasts accumulate; no archive |
| Large payment history | Admin **O(n)** every dashboard open |
| Large homework/submissions | Assignment queries limited; recitation per student indexed; Analytics missing halaqa+date index |

---

## 4. Realtime vs get

Hot realtime: chat messages/conversations, notifications watch, auth state.  
Appropriate for chat/inbox. **Inappropriate** for Admin all-conversations.

Attendance/eval are mostly **get/batch**, not collection-wide snapshots — good.

---

## 5. Caching / stale reads

Default Firestore persistence. No explicit stale-while-revalidate UX. After teacher change, student chat may use assignment `assignedBy` fallback (logical stale, not cache).

Progress % is **permanently stale** (not a cache issue).

---

## 6. File metadata / validation

- Proof: size 10MB, image content-type in **rules**; Dart also checks size/extension.
- Audio: contentType `audio/mp4` when enabled; flag false.
- Awards images: path helper exists; rules catch-all.
- No virus scan / server-side proof review besides Supervisor eyes.

---

## 7. Architectural recommendations (docs only)

1. Never ship open signed-in RW (correctness and **cost** — any client can scan collections).
2. Paginate chat messages; stop Admin collection snapshots.
3. Maintain `financeTotals/{academy}` on payment write (backend).
4. Split large `studentIds` or cap halaqa size as a product rule.
5. Broadcast: per-user fan-out (already the W4 model) not `readBy` on one doc.
6. Add missing composite indexes to `firestore.indexes.json` and **deploy rules from json**.
7. Durable outbox if FCM added (H3 already said this).
8. Do not compute Quran progress as a full-collection job on clients; projector on eval commit.

---

## 8. Production readiness extras

| Item | Freeze |
|------|--------|
| CI | None |
| App Check | None |
| Rules in `firebase.json` | **Indexes only** |
| `firebase/` directory | **Missing** — `firestore.rules` / `storage.rules` live at repo root (AUD-006) |
| Emulator tests | None found |
| `debugLogDiagnostics` | true on GoRouter |
| Seed tools | `tool/demo_academy_dataset.dart`, `seed_firestore.dart`, `seed_teacher_flow.dart` — **no payments seed** |

---

## Cross-links

- Contracts: `DATA_CONTRACT_AUDIT.md`
- Authz: `AUTH_SECURITY_AUDIT.md`
- Issues: AUD-001, 002, 006, 026, 028, 032–035, 034, 065, 078, 101 in `MASTER_ISSUE_MATRIX.md`
)
