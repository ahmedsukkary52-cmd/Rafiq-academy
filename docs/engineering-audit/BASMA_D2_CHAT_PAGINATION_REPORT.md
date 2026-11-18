# BASMA D2 — Chat Pagination (BASMA-103)

**Status:** Implemented locally (unit-tested). Not cloud-verified.

## Original problem

`ChatRoomBloc` “load older” grew the live Firestore listener limit (`30 → 60 → …`) and restarted `watchMessages`, re-reading already-loaded newest messages (read amplification).

## Root cause

Single growing-limit listener was used for both the live window and history. There was no cursor/page API for older messages.

## Design (after)

1. **Live window (fixed):** `watchMessages(limit: ChatRoomState.pageSize)` — always 30; never grows.
2. **Older page (one-shot):** `fetchMessagesBefore(beforeMessageId, limit)` using `orderBy('sentAt', descending).startAfterDocument(cursor).limit(n)`, returned ascending.
3. **Merge buffer:** `_byId` holds live + older; live ids win on conflict; messages that fall out of the live window remain in the buffer.
4. **Ordering:** `sentAt` ascending, then `id` ascending (deterministic ties).
5. **Lifecycle:** `droppable()` on load-older; `_olderRequestId` ignores stale responses after close/supersede; `close()` clears buffer and bumps request id; `restartable()` retained on live watch.

## Before → after

| Behavior | Before | After |
|----------|--------|-------|
| Load older | `limit += 30`, restart watch | Cursor `fetchMessagesBefore` |
| Live watch limits observed | `[30, 60, …]` | Always `[30]` |
| Re-read newest page | Yes | No |
| `hasMore` | `messages.length >= limit` | Explicit `hasMoreOlder` |

## Files

- `lib/features/chat/data/datasources/chat_remote_datasource.dart` — `fetchMessagesBefore`
- `lib/features/chat/domain/repositories/chat_repository.dart` + `chat_repository_impl.dart`
- `lib/features/chat/domain/usecases/chat_usecases.dart` — `FetchOlderMessagesUseCase`
- `lib/features/chat/presentation/bloc/chat_room_*.dart`
- `lib/core/di/injection_container.config.dart` — register use case + bloc ctor
- Tests: `test/features/chat/chat_room_bloc_test.dart`, `chat_repository_watch_test.dart`

## Indexes / schema

- Message cursor uses `startAfterDocument` on `sentAt` ordering — no new composite required beyond existing `sentAt` order.
- **No schema / Cloud Function / migration.**

## Consistency outside the live window

- Local edit/delete: optimistic `_byId` patch, then **single-id** `fetchMessagesByIds` revalidation (not a full older-buffer getAll).
- Ids still in the live window are updated by the fixed-30 snapshot; live wins on overlap.
- Peer mutations of older messages are **not** realtime without a conversation-level change signal (no unapproved backend contract).

## Residual risks

- In-memory `_byId` grows for the open room session (acceptable; cleared on close).
- Peer edit/delete of older-only messages can stay stale until the room is reopened or that id is revalidated locally.
- Scroll anchoring remains UI-owned (`chat_room.dart`); not redesigned.

---

### Checkpoint note (added 2026-11-18)

Chat pagination remediation later included in D2 commit **`daa8f85`**. Residual risks above still apply.
