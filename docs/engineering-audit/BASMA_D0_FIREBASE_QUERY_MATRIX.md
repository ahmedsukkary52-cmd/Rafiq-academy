# BASMA D0 Firebase Query Matrix

**Method:** code-read of current datasources (not runtime billing). Numbers are structural, not measured document counts.

| Query / API | Location | Limit | Pagination | Listener | N+1 | Functional? | Risk | Proposed fix (D2+) | Tests |
|-------------|----------|-------|------------|----------|-----|--------------|------|-------------------|-------|
| `watchMessages` | `chat_remote_datasource.dart` | required | growing `limit` via bloc | yes | no | yes | **Confirmed BASMA-103** | cursor older page + fixed live window | `chat_room_bloc_test` D0 characterization + skipped D2 contract |
| `watchConversations` | same | optional | none if omitted | yes | no | yes | **Confirmed BASMA-104/107** when callers omit pageSize | require pageSize at all call sites | add unit/grep guard in D2 |
| `watchAllConversations` | same | optional | keyset fetch exists | yes if null | no | admin inbox | UI uses limit 30; null branch remains | ban null limit | call-site test |
| Teacher recitation by halaqa | teacher datasource | **none** | no | get | no | history/analytics | **Confirmed BASMA-107** | date window + limit | datasource test |
| Admin registration requests | admin remote | scans all active students | no | get | yes profiles/emails | yes | **Confirmed BASMA-107** | query unassigned flag / CF | emulator + unit |
| `listUsersByRole` / `getAllTeachers` | admin remote | none | no | get | teachers N+1 profiles | directory | **Confirmed BASMA-107** | limit + cursor / search index | unit |
| Supervisor payments per student | supervisor/admin ops | often none | no | get | **yes** | review | **Confirmed BASMA-107** | batch `whereIn` / CF projection | unit |
| Parent `getPayments` | parent datasource | none | no | get | no | yes | Potential Risk | limit + cursor | unit |
| `listHalaqat` | admin | none | no | get | no | yes | Potential Risk | status filter + limit | unit |
| Notifications `readBy` arrayUnion | notifications | watch limit 50 | — | yes | doc growth | yes | Confirmed shape risk | per-user read state | rules + unit |
| Student achievements dual query | student datasource | often none | no | get | dual merge | yes | Potential Risk | limit both | unit |
| Admin payments ledger | admin | 20 | startAfter | get | no | yes | Improved vs AUD-034 | keep | existing |
| Admin finance aggregates | ledger summary | n/a | n/a | aggregate | no | yes | **BASMA-101** live indexes | deploy indexes (D1 gate) | REST after deploy |

## Listener disposal

- `ChatRoomBloc`: `@injectable` per room; `close()` cancels uploads; `restartable()` on watch. **Verified** by unit test cancel-on-close.
- Conversation tabs: depend on bloc lifecycle — **Potential Risk** if tabs keep singletons without cancel (not re-measured in D0).

## Cost note

No runtime read meters in D0. See Stage A assumed model in `BASMA_FIREBASE_EFFICIENCY_AUDIT.md`.
